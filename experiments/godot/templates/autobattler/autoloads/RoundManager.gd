# =============================================================================
# RoundManager.gd — Autoload (Singleton)
# =============================================================================
# Game state and the PREP -> BATTLE -> RESULT loop.
#
#   PREP     shop, bench, board; the enemy lineup of the round is already
#            shown on the top half, so the player can answer it
#   BATTLE   BattleSimulator advanced in fixed steps of STEP seconds (x the
#            battle speed); its events are forwarded through battle_event
#   RESULT   banner for result_delay seconds, then the next round
#   GAME_OVER / VICTORY   terminal, new_game() restarts
#
# ECONOMY at the start of every round after the first:
#   income = income_base + interest + win_bonus (if the last battle was won)
#   interest = min(floor(gold / interest_step), interest_cap): 1 gold per
#   10 saved, at most 5. Unit price = tier; selling refunds its full value.
# LEVEL: the number of units allowed on the board. Buying a level costs
#   level_costs (4, 6, 8, 10, 12 for levels 4 to 8) and improves the shop
#   odds (UnitDatabase).
# MERGE: three units of the same type and star become one of the next star,
#   kept where one of them stood on the board if any. Buying is allowed with
#   a full bench when the new unit completes a merge.
# DEFEAT DAMAGE: damage_base + damage_per_survivor x enemy units left +
#   damage_per_stage x stage (stage = 1 for rounds 1-5, 2 for 6-10...).
# =============================================================================

extends Node

enum Phase { PREP, BATTLE, RESULT, GAME_OVER, VICTORY }

signal phase_changed(phase: Phase)
signal gold_changed(value: int)
signal hp_changed(value: int, delta: int)
signal level_changed(level: int)
signal board_changed()
signal shop_changed()
signal unit_merged(unit: Unit)
signal battle_started(sim: BattleSimulator)
signal battle_event(event: Dictionary)
signal battle_finished(won: bool, damage: int)
signal feedback(key: String)

const STEP: float = 1.0 / 30.0

var phase: Phase = Phase.PREP
var round_number: int = 0
var hp: int = 30
var gold: int = 0
var level: int = 3
var board: Board = null
var shop: Array[String] = []
var enemy_lineup: Array[Dictionary] = []
var sim: BattleSimulator = null
var battle_speed: float = 1.0
var last_won: bool = false
var stats: Dictionary = {}
var _seed: int = 0
var _accumulator: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	set_process(false)

# =============================================================================
# GAME FLOW
# =============================================================================

func new_game() -> void:
	_seed = randi()
	_rng.seed = _seed
	round_number = 0
	hp = ConfigManager.get_int("player_hp_start", 30)
	gold = 0
	level = ConfigManager.get_int("start_level", 3)
	last_won = false
	stats = {"wins": 0, "losses": 0, "merges": 0, "best_star": 1}
	board = Board.new(ConfigManager.get_int("board_cols", 7), ConfigManager.get_int("board_rows", 4), ConfigManager.get_int("bench_size", 8))
	level_changed.emit(level)
	hp_changed.emit(hp, 0)
	_start_prep()

func _start_prep() -> void:
	round_number += 1
	var interest: int = mini(int(gold / float(ConfigManager.get_int("interest_step", 10))), ConfigManager.get_int("interest_cap", 5))
	gold += ConfigManager.get_int("income_base", 5) + (interest if round_number > 1 else 0)
	if last_won and round_number > 1:
		gold += ConfigManager.get_int("win_bonus", 1)
	enemy_lineup = EnemyFactory.build(round_number, _seed)
	_roll_shop()
	phase = Phase.PREP
	gold_changed.emit(gold)
	board_changed.emit()
	phase_changed.emit(phase)

func stage() -> int:
	return int(ceil(round_number / 5.0))

## JSON numbers are floats (10.0): compare as integers, has(10) would miss them.
func is_boss_round(r: int) -> bool:
	return boss_index(r) >= 0

static func boss_index(r: int) -> int:
	var rounds: Array = ConfigManager.get_array("boss_rounds")
	for i in rounds.size():
		if int(rounds[i]) == r:
			return i
	return -1

func start_battle() -> bool:
	if phase != Phase.PREP:
		return false
	if board.board_count() == 0:
		feedback.emit("no_board_units")
		return false
	var rows: int = board.rows
	var players: Array[Unit] = []
	for c in board.cells:
		var unit: Unit = board.cells[c] as Unit
		unit.prepare_for_battle(0, Vector2i(c.x, rows + c.y))
		players.append(unit)
	var enemies: Array[Unit] = []
	for entry in enemy_lineup:
		var enemy: Unit = entry["unit"] as Unit
		enemy.prepare_for_battle(1, entry["cell"] as Vector2i)
		enemies.append(enemy)
	sim = BattleSimulator.new()
	sim.setup(players, enemies, board.cols, rows * 2, _seed + round_number * 7919)
	_accumulator = 0.0
	phase = Phase.BATTLE
	phase_changed.emit(phase)
	battle_started.emit(sim)
	set_process(true)
	return true

func _process(delta: float) -> void:
	if phase != Phase.BATTLE or sim == null:
		set_process(false)
		return
	_accumulator += minf(delta, 0.1) * battle_speed
	while _accumulator >= STEP and not sim.finished:
		_accumulator -= STEP
		sim.step(STEP)
		for event in sim.events:
			battle_event.emit(event)
		sim.events.clear()
	if sim.finished:
		set_process(false)
		_finish_battle()

func _finish_battle() -> void:
	var won: bool = sim.winner == 0
	var damage: int = 0
	if won:
		stats["wins"] = int(stats["wins"]) + 1
	else:
		stats["losses"] = int(stats["losses"]) + 1
		damage = (ConfigManager.get_int("damage_base", 2) + ConfigManager.get_int("damage_per_survivor", 1) * sim.survivors(1).size()
			+ ConfigManager.get_int("damage_per_stage", 1) * stage())
		hp = maxi(hp - damage, 0)
		hp_changed.emit(hp, -damage)
	last_won = won
	phase = Phase.RESULT
	phase_changed.emit(phase)
	battle_finished.emit(won, damage)
	await get_tree().create_timer(ConfigManager.get_float("result_delay", 2.2)).timeout
	if phase != Phase.RESULT:
		return
	if hp <= 0:
		phase = Phase.GAME_OVER
	elif round_number >= ConfigManager.get_int("rounds_total", 15):
		phase = Phase.VICTORY
	if phase != Phase.RESULT:
		phase_changed.emit(phase)
		return
	_start_prep()

func set_battle_speed(speed: float) -> void:
	battle_speed = speed

# =============================================================================
# SHOP, LEVEL, BENCH AND BOARD
# =============================================================================

func _roll_shop() -> void:
	shop.clear()
	for i in ConfigManager.get_int("shop_size", 5):
		shop.append(UnitDatabase.random_id_for_level(level, _rng))
	shop_changed.emit()

func reroll() -> bool:
	var cost: int = ConfigManager.get_int("reroll_cost", 2)
	if phase != Phase.PREP or gold < cost:
		feedback.emit("not_enough_gold")
		return false
	_spend(cost)
	_roll_shop()
	return true

func level_cost() -> int:
	var costs: Array = ConfigManager.get_array("level_costs")
	var index: int = level - ConfigManager.get_int("start_level", 3)
	return int(costs[index]) if index >= 0 and index < costs.size() else -1

func level_up() -> bool:
	var cost: int = level_cost()
	if phase != Phase.PREP or cost < 0 or level >= ConfigManager.get_int("max_level", 8):
		return false
	if gold < cost:
		feedback.emit("not_enough_gold")
		return false
	_spend(cost)
	level += 1
	level_changed.emit(level)
	return true

func buy(shop_index: int) -> bool:
	if phase != Phase.PREP or shop_index < 0 or shop_index >= shop.size() or shop[shop_index].is_empty():
		return false
	var type_id: String = shop[shop_index]
	var cost: int = int(UnitDatabase.unit_data(type_id).get("tier", 1))
	if gold < cost:
		feedback.emit("not_enough_gold")
		return false
	var slot: int = board.first_free_bench()
	if slot < 0 and _copies(type_id, 1).size() < ConfigManager.get_int("merge_count", 3) - 1:
		feedback.emit("bench_full")
		return false
	var unit := Unit.new()
	unit.setup(UnitDatabase.unit_data(type_id), 1)
	_spend(cost)
	shop[shop_index] = ""
	if slot >= 0:
		board.bench[slot] = unit
	_merge_from(unit)
	shop_changed.emit()
	board_changed.emit()
	return true

func sell(unit: Unit) -> bool:
	if phase != Phase.PREP or not board.remove(unit):
		return false
	gold += unit.sell_value()
	gold_changed.emit(gold)
	board_changed.emit()
	return true

## Moves a unit (drag and drop). Refuses to exceed the level on the board.
func move_unit(unit: Unit, to: Dictionary) -> bool:
	if phase != Phase.PREP or not board.is_valid(to):
		return false
	var from: Dictionary = board.location_of(unit)
	if from.is_empty():
		return false
	var entering: bool = from["zone"] == "bench" and to["zone"] == "board" and board.unit_at(to) == null
	if entering and board.board_count() >= level:
		feedback.emit("board_full")
		return false
	board.move(unit, to)
	board_changed.emit()
	return true

func _spend(amount: int) -> void:
	gold -= amount
	gold_changed.emit(gold)

func _copies(type_id: String, star: int) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in board.all_units():
		if unit.type_id == type_id and unit.star == star:
			result.append(unit)
	return result

## The new unit may not be on the bench (full bench): it then takes the
## place of one of its copies.
func _merge_from(unit: Unit) -> void:
	var needed: int = ConfigManager.get_int("merge_count", 3)
	var copies: Array[Unit] = _copies(unit.type_id, unit.star)
	if not copies.has(unit):
		copies.append(unit)
	if copies.size() < needed:
		return
	var keep: Unit = copies[0]
	for copy in copies:
		if board.location_of(copy).get("zone", "") == "board":
			keep = copy
			break
	var removed: int = 0
	for copy in copies:
		if copy != keep and removed < needed - 1:
			board.remove(copy)
			removed += 1
	if board.location_of(keep).is_empty():
		var slot: int = board.first_free_bench()
		if slot >= 0:
			board.bench[slot] = keep
	keep.star += 1
	stats["merges"] = int(stats["merges"]) + 1
	stats["best_star"] = maxi(int(stats["best_star"]), keep.star)
	unit_merged.emit(keep)
	_merge_from(keep)

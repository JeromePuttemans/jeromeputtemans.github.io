# =============================================================================
# RoundManager.gd — Autoload (Singleton)
# =============================================================================
# Owns the game state and drives the PREP → BATTLE → RESULT → PREP loop.
#
# STATE MACHINE:
#   PREP    — player buys/places/sells units, opens the shop
#   BATTLE  — one attack executed per Timer tick (no pre-computation batch)
#   RESULT  — outcome applied to player HP; 1.5 s pause then next PREP
#   GAME_OVER / VICTORY — terminal states (restart via new_game())
#
# WHY ONE ATTACK PER TICK (not BattleSimulator.run()):
#   run() is a synchronous while loop on the main thread.
#   With high-HP units it can iterate 200+ times before returning,
#   blocking Godot's event loop long enough to trigger the "not responding"
#   freeze popup. Instead, _on_battle_tick() does exactly one step and
#   returns, keeping each Timer callback well under 1 ms.
#
# ECONOMY:
#   Each round the player receives gold_per_round + interest.
#   Interest = min(gold_held / 10, interest_cap).
# =============================================================================

extends Node

enum Phase { PREP, BATTLE, RESULT, GAME_OVER, VICTORY }

signal phase_changed(new_phase: Phase)
signal board_changed()
signal gold_changed(value: int)
signal hp_changed(value: int)
signal battle_event(event: BattleSimulator.BattleEvent)
signal game_over()
signal game_won()

var phase:         Phase = Phase.PREP
var current_round: int   = 0
var player_hp:     int   = 0
var player_gold:   int   = 0

var board:     Board = null
var shop_pool: Array = []   # Array[String] type_ids currently offered

# --- Live battle state (mutated tick by tick, never pre-computed) ---
var _battle_players:   Array = []  # Array[Unit] — surviving player units
var _battle_enemies:   Array = []  # Array[Unit] — surviving enemy units
var _turn_index:       int   = 0   # Round-robin position in the initiative order
var _base_player_dmg:  int   = 2   # HP to subtract on defeat (from config)
var _battle_timer:     Timer = null

# =============================================================================
# PUBLIC API
# =============================================================================

func new_game() -> void:
	current_round = 0
	player_hp     = ConfigManager.get_int("player_hp_start", 20)
	player_gold   = 0
	board = Board.new(
		ConfigManager.get_int("board_cols", 4),
		ConfigManager.get_int("board_rows", 2),
		ConfigManager.get_int("bench_size", 8)
	)
	_start_prep_phase()

## Attempts to buy a unit. Returns false if not enough gold or bench full.
func buy_unit(type_id: String) -> bool:
	var cost = ConfigManager.get_int("unit_buy_cost", 3)
	if player_gold < cost:
		return false
	if board.is_bench_full():
		return false
	var data = UnitDatabase.get_type(type_id)
	if data.is_empty():
		return false
	var unit = Unit.new()
	unit.setup_from_data(data)
	var slot = board.first_empty_bench_slot()
	board.bench_slots[slot] = unit
	player_gold -= cost
	emit_signal("gold_changed", player_gold)
	emit_signal("board_changed")
	return true

## Sells a unit (bench or board). Returns false if not found.
func sell_unit(unit: Unit) -> bool:
	if not board.remove_unit(unit):
		return false
	player_gold += ConfigManager.get_int("unit_sell_value", 1)
	emit_signal("gold_changed", player_gold)
	emit_signal("board_changed")
	return true

## Moves a bench unit to the board. Returns false if board is full.
func place_unit(unit: Unit) -> bool:
	if board.is_board_full():
		return false
	var ok = board.move_bench_to_board(unit)
	if ok:
		emit_signal("board_changed")
	return ok

## Moves a board unit back to bench. Returns false if bench is full.
func return_unit_to_bench(unit: Unit) -> bool:
	if board.is_bench_full():
		return false
	var ok = board.move_board_to_bench(unit)
	if ok:
		emit_signal("board_changed")
	return ok

## Rerolls the shop. Returns false if not enough gold.
func refresh_shop() -> bool:
	var cost = ConfigManager.get_int("shop_refresh_cost", 2)
	if player_gold < cost:
		return false
	player_gold -= cost
	_roll_shop()
	emit_signal("gold_changed", player_gold)
	return true

## Called by the Ready button — starts the battle phase.
## Returns false if board has no units.
func start_battle() -> bool:
	if phase != Phase.PREP:
		return false
	if board.get_board_units().is_empty():
		return false
	_run_battle()
	return true

# =============================================================================
# PRIVATE — PHASE TRANSITIONS
# =============================================================================

func _start_prep_phase() -> void:
	current_round += 1
	var income   = ConfigManager.get_int("gold_per_round", 5)
	var interest = min(player_gold / 10, ConfigManager.get_int("interest_cap", 3))
	player_gold += income + interest
	_roll_shop()
	phase = Phase.PREP
	emit_signal("gold_changed",  player_gold)
	emit_signal("hp_changed",    player_hp)
	emit_signal("board_changed")
	emit_signal("phase_changed", phase)

func _run_battle() -> void:
	phase = Phase.BATTLE
	emit_signal("phase_changed", phase)

	# Build enemy team scaled to the current round
	var ids      = UnitDatabase.get_all_ids()
	var min_e    = ConfigManager.get_int("enemy_team_size_min", 2)
	var max_e    = ConfigManager.get_int("enemy_team_size_max", 4)
	var total    = ConfigManager.get_int("rounds_total", 8)
	var progress = float(current_round - 1) / max(total - 1, 1)
	var count    = min_e + int(round(progress * (max_e - min_e)))
	_battle_enemies = []
	for _i in count:
		var type_id = ids[randi() % ids.size()]
		var data    = UnitDatabase.get_type(type_id)
		var unit    = Unit.new()
		unit.setup_from_data(data)
		_battle_enemies.append(unit)

	# Shallow copies — we erase dead units; the originals stay on the board
	_battle_players  = board.get_board_units().duplicate()
	_base_player_dmg = ConfigManager.get_int("base_damage_to_player", 2)
	_turn_index      = 0

	# Reset all units to full HP for this battle
	for u in _battle_players:
		u.reset_for_battle()
	for u in _battle_enemies:
		u.reset_for_battle()

	# Create the timer once and reuse it
	if _battle_timer == null:
		_battle_timer          = Timer.new()
		_battle_timer.one_shot = false
		_battle_timer.timeout.connect(_on_battle_tick)
		add_child(_battle_timer)

	var delay_ms = ConfigManager.get_int("battle_tick_delay_ms", 150)
	_battle_timer.wait_time = delay_ms / 1000.0
	_battle_timer.start()

## Called every tick — executes exactly ONE attack and returns immediately.
## No loops, no blocking. Godot's main thread stays free between ticks.
func _on_battle_tick() -> void:
	# Check termination first
	if _battle_players.is_empty() or _battle_enemies.is_empty():
		_battle_timer.stop()
		_finish_battle()
		return

	# Build initiative order (only living units)
	var order = BattleSimulator.build_order(_battle_players, _battle_enemies)
	if order.is_empty():
		_battle_timer.stop()
		_finish_battle()
		return

	# Wrap index to account for units that died in a previous tick
	_turn_index = _turn_index % order.size()
	var entry         = order[_turn_index]
	var attacker: Unit      = entry["unit"]
	var attacker_team: String = entry["team"]
	_turn_index += 1

	# Pick lowest-HP target on the opposing side
	var targets: Array = _battle_enemies if attacker_team == "player" else _battle_players
	var target: Unit   = BattleSimulator.pick_target(targets)
	if target == null:
		return

	# Resolve one attack
	var damage: int = target.take_damage(attacker.attack)

	var ev_atk      = BattleSimulator.BattleEvent.new()
	ev_atk.type     = "attack"
	ev_atk.attacker = attacker.display_name
	ev_atk.target   = target.display_name
	ev_atk.damage   = damage
	emit_signal("battle_event", ev_atk)

	# Handle death
	if not target.is_alive():
		var ev_death  = BattleSimulator.BattleEvent.new()
		ev_death.type = "death"
		ev_death.name = target.display_name
		emit_signal("battle_event", ev_death)

		if attacker_team == "player":
			_battle_enemies.erase(target)
		else:
			_battle_players.erase(target)

		# Reset index so it stays valid after the array shrinks
		_turn_index = 0

		# Re-check termination immediately after a death
		if _battle_players.is_empty() or _battle_enemies.is_empty():
			_battle_timer.stop()
			_finish_battle()

## Emits the result event and transitions to RESULT phase.
func _finish_battle() -> void:
	var ev_result          = BattleSimulator.BattleEvent.new()
	ev_result.type         = "result"

	if _battle_players.size() > 0 and _battle_enemies.is_empty():
		ev_result.result           = "player_win"
		ev_result.player_hp_damage = 0
	elif _battle_enemies.size() > 0 and _battle_players.is_empty():
		ev_result.result           = "enemy_win"
		ev_result.player_hp_damage = _base_player_dmg
	else:
		ev_result.result           = "draw"
		ev_result.player_hp_damage = 0

	player_hp -= ev_result.player_hp_damage
	emit_signal("battle_event", ev_result)
	emit_signal("hp_changed",   player_hp)
	_start_result_phase()

func _start_result_phase() -> void:
	phase = Phase.RESULT
	emit_signal("phase_changed", phase)

	if player_hp <= 0:
		phase = Phase.GAME_OVER
		emit_signal("phase_changed", phase)
		emit_signal("game_over")
		return

	var total = ConfigManager.get_int("rounds_total", 8)
	if current_round >= total:
		phase = Phase.VICTORY
		emit_signal("phase_changed", phase)
		emit_signal("game_won")
		return

	# Guard after await: if the game was restarted during this pause,
	# phase will no longer be RESULT — do not advance the new game.
	await get_tree().create_timer(1.5).timeout
	if phase != Phase.RESULT:
		return
	_start_prep_phase()

# =============================================================================
# PRIVATE — SHOP
# =============================================================================

func _roll_shop() -> void:
	var size = ConfigManager.get_int("shop_size", 5)
	var ids  = UnitDatabase.get_all_ids()
	shop_pool.clear()
	for _i in size:
		shop_pool.append(ids[randi() % ids.size()])

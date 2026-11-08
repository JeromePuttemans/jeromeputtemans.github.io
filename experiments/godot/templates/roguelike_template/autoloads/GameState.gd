# =============================================================================
# GameState.gd (Autoload, Singleton)
# =============================================================================
# Central game state and turn-processing state machine. No rendering here:
# views listen to the signals below.
#
# STATE MACHINE:
#   PLAYER -> (player acts) -> ENEMY -> (every enemy acts) -> PLAYER
#   Any phase -> GAME_OVER (player HP reaches 0)
#   PLAYER    -> VICTORY   (player takes the exit portal of the last floor)
#
# WHAT COSTS A TURN:
#   move, attack (bump into an enemy), wait, use an item.
#   Free: bumping into a wall, dropping an item, taking the stairs.
#
# TWO KINDS OF SIGNALS:
#   state signals   run_started, dungeon_ready, turn_ended, stats_changed, message_added,
#                   player_died, player_won: the HUD refreshes from them.
#   event signals   entity_moved, entity_attacked, entity_died,
#                   projectile_fired, enemy_alerted, item_picked, item_used,
#                   spell_hit, player_leveled, wall_bumped: one per thing
#                   that HAPPENED. DungeonView turns them into animations,
#                   particles, sounds and shakes. The logic resolves
#                   instantly; the view catches up visually.
#
# RANDOMNESS: one RandomNumberGenerator (rng) for generation, combat and AI.
# new_game(seed) with a fixed seed replays the same run: useful to reproduce
# a bug or to test balance with a bot.
# =============================================================================

extends Node

enum Phase { PLAYER, ENEMY, GAME_OVER, VICTORY }

signal run_started()
signal dungeon_ready()
signal turn_ended()
signal stats_changed()
signal message_added(text: String, kind: String)
signal player_died()
signal player_won()
signal entity_moved(entity: Entity, from: Vector2i, to: Vector2i)
signal entity_attacked(attacker: Entity, target: Entity, damage: int, crit: bool)
signal entity_died(entity: Entity)
signal projectile_fired(from: Vector2i, to: Vector2i, color: Color)
signal enemy_alerted(enemy: EnemyEntity)
signal item_picked(item: Dictionary, pos: Vector2i)
signal item_used(item: Dictionary, targets: Array)
signal spell_hit(target: Entity, damage: int)
signal player_leveled(level: int)
signal wall_bumped(direction: Vector2i)

var phase:         Phase = Phase.PLAYER
var current_floor: int   = 1
var total_floors:  int   = 1
var turn:          int   = 0
var kills:         int   = 0
var death_killer:  EnemyEntity = null   # null after a death by starvation

var player:  PlayerEntity = null
var dungeon: DungeonData  = null
var enemies: Array[EnemyEntity] = []
# Spatial index for O(1) enemy lookups by position.
# Invariant: always mirrors `enemies` (updated by every move and death).
var enemy_positions: Dictionary = {}   # { Vector2i: EnemyEntity }
var visible: Array = []                # 2D bool [x][y], current FOV
var rng := RandomNumberGenerator.new()

var _hunger_warned: bool = false
var _starve_warned: bool = false

# =============================================================================
# PUBLIC API
# =============================================================================

## Starts a new run. seed_value < 0 picks a random seed.
func new_game(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	total_floors   = ConfigManager.get_int("total_floors", 1)
	current_floor  = 1
	turn           = 0
	kills          = 0
	death_killer   = null
	_hunger_warned = false
	_starve_warned = false
	player = PlayerEntity.new()
	run_started.emit()
	_generate_floor()
	log_msg(StringManager.t("welcome", {total = total_floors}), "info")

## One player action. direction = movement delta, Vector2i.ZERO = wait.
func player_action(direction: Vector2i) -> void:
	if phase != Phase.PLAYER:
		return
	if direction != Vector2i.ZERO:
		var target_pos: Vector2i = player.grid_pos + direction
		if enemy_positions.has(target_pos):
			_player_attack(enemy_positions[target_pos] as EnemyEntity)
		elif dungeon.is_walkable(target_pos):
			var from: Vector2i = player.grid_pos
			player.grid_pos = target_pos
			entity_moved.emit(player, from, target_pos)
			_on_player_enter(target_pos)
		else:
			wall_bumped.emit(direction)
			return   # wall bump: free, enemies do not act
	_end_player_turn()

## Uses the inventory item in `slot` (costs a turn if the item is consumed).
func use_item(slot: int) -> void:
	if phase != Phase.PLAYER or slot < 0 or slot >= player.inventory.size():
		return
	var item: Dictionary = player.inventory[slot]
	var result: Dictionary = _apply_consumable(item)
	if not bool(result["used"]):
		return
	player.inventory.remove_at(slot)
	item_used.emit(item, result["targets"] as Array)
	_end_player_turn()

## Drops the inventory item in `slot` on the player's tile (free action).
func drop_item(slot: int) -> void:
	if phase != Phase.PLAYER or slot < 0 or slot >= player.inventory.size():
		return
	var pos: Vector2i = player.grid_pos
	if dungeon.items.has(pos) or dungeon.get_tile(pos) == DungeonData.TileType.STAIRS_DOWN:
		log_msg(StringManager.t("drop_blocked"), "warn")
		return
	var item: Dictionary = player.inventory[slot]
	player.inventory.remove_at(slot)
	dungeon.items[pos] = item
	log_msg(StringManager.t("dropped", {name = ItemDatabase.display_name(item)}), "info")
	stats_changed.emit()
	turn_ended.emit()

## Takes the stairs (or the exit portal on the last floor).
func descend() -> void:
	if phase != Phase.PLAYER or dungeon.get_tile(player.grid_pos) != DungeonData.TileType.STAIRS_DOWN:
		return
	if dungeon.is_last_floor:
		phase = Phase.VICTORY
		player_won.emit()
		return
	current_floor += 1
	_generate_floor()
	var theme: Dictionary = ConfigManager.get_floor_theme(current_floor)
	log_msg(StringManager.t("descend_msg", {value = current_floor,
		name = StringManager.t(str(theme.get("name_key", "")))}), "level")
	if dungeon.is_last_floor:
		log_msg(StringManager.t("boss_floor"), "warn")

func log_msg(text: String, kind: String = "info") -> void:
	message_added.emit(text, kind)

## Localised enemy name with its article ("the orc", "l'orc").
func enemy_name(enemy: EnemyEntity, capitalized: bool = false) -> String:
	var n: String = StringManager.t_or("enemy_" + enemy.id, enemy.display_name)
	return StringManager.capitalize_first(n) if capitalized else n

func is_on_stairs() -> bool:
	return dungeon != null and dungeon.get_tile(player.grid_pos) == DungeonData.TileType.STAIRS_DOWN

# =============================================================================
# FLOOR GENERATION
# =============================================================================

func _generate_floor() -> void:
	enemies.clear()
	enemy_positions.clear()
	dungeon = DungeonGenerator.generate(ConfigManager.get_raw(), current_floor, total_floors,
		rng, EnemyDatabase.pick_for_floor, ItemDatabase.pick_for_floor, EnemyDatabase.get_boss_id())
	player.grid_pos = dungeon.player_start
	for spawn in dungeon.enemy_spawns:
		var type_data: Dictionary = EnemyDatabase.get_type(str(spawn["type_id"]))
		if type_data.is_empty():
			continue
		var enemy := EnemyEntity.new()
		enemy.setup_from_data(type_data)
		enemy.scale_for_floor(current_floor)
		enemy.grid_pos = spawn["pos"] as Vector2i
		enemies.append(enemy)
		enemy_positions[enemy.grid_pos] = enemy
	for spawn in dungeon.item_spawns:
		var item: Dictionary = ItemDatabase.get_type(str(spawn["item_id"]))
		if not item.is_empty():
			dungeon.items[spawn["pos"] as Vector2i] = item
	_refresh_fov()
	phase = Phase.PLAYER
	dungeon_ready.emit()
	stats_changed.emit()

# =============================================================================
# PLAYER
# =============================================================================

func _player_attack(enemy: EnemyEntity) -> void:
	var r: Dictionary = CombatSystem.resolve(player.attack, enemy, player.crit_chance, rng)
	var dmg: int = int(r["damage"])
	entity_attacked.emit(player, enemy, dmg, bool(r["crit"]))
	var key: String = "player_crit" if bool(r["crit"]) else "player_attacks"
	log_msg(StringManager.t(key, {target = enemy_name(enemy), damage = dmg}), "combat")
	if not enemy.is_alive():
		_kill_enemy(enemy)
	else:
		enemy.alerted = true   # being hit wakes an enemy up
		enemy.alert_turns = ConfigManager.get_int("alert_memory_turns", 0)

func _kill_enemy(enemy: EnemyEntity) -> void:
	kills += 1
	enemy_positions.erase(enemy.grid_pos)
	enemies.erase(enemy)
	entity_died.emit(enemy)
	log_msg(StringManager.t("enemy_died", {Name = enemy_name(enemy, true), xp = enemy.xp_value}), "loot")
	_gain_xp(enemy.xp_value)

func _gain_xp(amount: int) -> void:
	player.xp += amount
	while player.xp >= player.xp_next:
		player.xp -= player.xp_next
		player.level += 1
		var hp_gain: int = ConfigManager.get_int("level_hp_gain", 0)
		player.hp_max += hp_gain
		player.heal(hp_gain + int(player.hp_max * ConfigManager.get_float("level_heal_ratio", 0.0)))
		# Even levels raise ATK, levels divisible by 3 raise DEF (level 6: both).
		# DEF grows slower on purpose: stacked DEF reduces every enemy hit to the
		# minimum of 1 and removes all danger.
		var stats: Array[String] = []
		if player.level % 2 == 0:
			player.attack += 1
			stats.append(StringManager.t("stat_attack"))
		if player.level % 3 == 0:
			player.defense += 1
			stats.append(StringManager.t("stat_defense"))
		player.xp_next = PlayerEntity.xp_needed(player.level)
		player_leveled.emit(player.level)
		var key: String = "level_up" if not stats.is_empty() else "level_up_hp"
		log_msg(StringManager.t(key, {value = player.level, hp = hp_gain,
			stat = " +1, ".join(stats)}), "level")

func _on_player_enter(pos: Vector2i) -> void:
	if dungeon.items.has(pos):
		_try_pickup(pos)
	if dungeon.get_tile(pos) == DungeonData.TileType.STAIRS_DOWN:
		log_msg(StringManager.t("exit_here" if dungeon.is_last_floor else "stairs_here"), "hint")

func _try_pickup(pos: Vector2i) -> void:
	var item: Dictionary = dungeon.items[pos]
	var item_name: String = ItemDatabase.display_name(item)
	if bool(item.get("instant", false)):
		dungeon.items.erase(pos)
		_apply_upgrade(item)
		item_picked.emit(item, pos)
	elif player.inventory_full():
		log_msg(StringManager.t("inventory_full", {name = item_name}), "warn")
	else:
		dungeon.items.erase(pos)
		player.inventory.append(item)
		item_picked.emit(item, pos)
		log_msg(StringManager.t("picked_up", {name = item_name}), "loot")

func _apply_upgrade(item: Dictionary) -> void:
	var value: int = int(item.get("value", 0))
	match str(item.get("effect", "")):
		"attack":
			player.attack += value
			log_msg(StringManager.t("upgrade_attack", {value = value}), "level")
		"defense":
			player.defense += value
			log_msg(StringManager.t("upgrade_defense", {value = value}), "level")
		"max_hp":
			player.hp_max += value
			player.heal(value)
			log_msg(StringManager.t("upgrade_max_hp", {value = value}), "level")

## Applies a consumable. Returns {used: bool, targets: Array[Vector2i]}.
## An item that would have no effect is NOT consumed (full HP potion,
## thunder with no enemy in range): the player never wastes a turn by mistake.
func _apply_consumable(item: Dictionary) -> Dictionary:
	var value: float = float(item.get("value", 0))
	var targets: Array = []
	match str(item.get("effect", "")):
		"heal_ratio":
			if player.hp >= player.hp_max:
				log_msg(StringManager.t("full_health"), "warn")
				return {used = false, targets = targets}
			var healed: int = player.heal(maxi(1, int(round(player.hp_max * value))))
			log_msg(StringManager.t("used_potion", {value = healed}), "heal")
		"energy":
			if player.energy >= player.energy_max:
				log_msg(StringManager.t("not_hungry"), "warn")
				return {used = false, targets = targets}
			var before: int = player.energy
			player.energy = mini(player.energy_max, player.energy + int(value))
			log_msg(StringManager.t("used_ration", {value = player.energy - before}), "heal")
		"thunder":
			var radius: int = int(item.get("radius", 0))
			var hit: Array[EnemyEntity] = []
			for e in enemies:
				if visible[e.grid_pos.x][e.grid_pos.y] and AISystem.chebyshev(e.grid_pos, player.grid_pos) <= radius:
					hit.append(e)
			if hit.is_empty():
				log_msg(StringManager.t("thunder_none", {radius = radius}), "warn")
				return {used = false, targets = targets}
			log_msg(StringManager.t("used_thunder", {count = hit.size()}), "combat")
			for e in hit:
				targets.append(e.grid_pos)
				e.take_damage(int(value))   # magic ignores defense
				spell_hit.emit(e, int(value))
				if not e.is_alive():
					_kill_enemy(e)
				else:
					e.alerted = true
					e.alert_turns = ConfigManager.get_int("alert_memory_turns", 0)
		"blink":
			var from: Vector2i = player.grid_pos
			player.grid_pos = _blink_destination(int(value))
			entity_moved.emit(player, from, player.grid_pos)
			targets.append(from)
			log_msg(StringManager.t("used_blink"), "info")
			_on_player_enter(player.grid_pos)
		"reveal":
			dungeon.reveal_all()
			log_msg(StringManager.t("used_map"), "info")
		_:
			return {used = false, targets = targets}
	return {used = true, targets = targets}

## Random free floor cell at least `min_dist` from every enemy; if none
## exists, the free cell that maximises the distance to the nearest enemy.
func _blink_destination(min_dist: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	var best: Vector2i = player.grid_pos
	var best_d: int = -1
	for x in dungeon.width:
		for y in dungeon.height:
			var p := Vector2i(x, y)
			if dungeon.get_tile(p) != DungeonData.TileType.FLOOR or enemy_positions.has(p) or dungeon.items.has(p):
				continue
			var nearest: int = 1 << 20
			for e in enemies:
				nearest = mini(nearest, AISystem.chebyshev(p, e.grid_pos))
			if nearest >= min_dist:
				candidates.append(p)
			if nearest > best_d:
				best_d = nearest
				best = p
	if candidates.is_empty():
		return best
	return candidates[rng.randi_range(0, candidates.size() - 1)]

# =============================================================================
# TURN PROCESSING
# =============================================================================

func _end_player_turn() -> void:
	turn += 1
	_tick_needs()
	if not player.is_alive():
		_player_death(null)
		turn_ended.emit()
		return
	_refresh_fov()
	_process_enemy_turns()
	stats_changed.emit()
	turn_ended.emit()

## Food clock. Energy drops by 1 every `energy_drain_every` turns.
## Above 0: +1 HP every `hp_regen_every` turns (resting heals, but costs food).
## At 0: -1 HP every `starve_damage_every` turns, no regeneration.
func _tick_needs() -> void:
	if turn % maxi(ConfigManager.get_int("energy_drain_every", 1), 1) == 0 and player.energy > 0:
		player.energy -= 1
	if player.energy > 0:
		_starve_warned = false
		if turn % maxi(ConfigManager.get_int("hp_regen_every", 1), 1) == 0:
			player.heal(1)
		var hungry: bool = player.energy <= ConfigManager.get_int("hungry_threshold", 0)
		if hungry and not _hunger_warned:
			_hunger_warned = true
			log_msg(StringManager.t("hungry"), "warn")
		elif not hungry:
			_hunger_warned = false
	else:
		if not _starve_warned:
			_starve_warned = true
			log_msg(StringManager.t("starving"), "damage")
		if turn % maxi(ConfigManager.get_int("starve_damage_every", 1), 1) == 0:
			player.take_damage(1)

func _process_enemy_turns() -> void:
	phase = Phase.ENEMY
	var dmap: DijkstraMap = DijkstraMap.compute(dungeon, player.grid_pos, 40)
	for enemy in enemies.duplicate():
		if not enemy.is_alive():
			continue
		enemy.action_points += enemy.speed
		while enemy.action_points >= 1.0:
			enemy.action_points -= 1.0
			_enemy_act(enemy, dmap)
			if phase == Phase.GAME_OVER:
				return
	phase = Phase.PLAYER

## Awareness first, then the AISystem decision.
## An enemy that just noticed the player spends its action on the "!":
## the player always gets one turn to react to a new threat.
func _enemy_act(enemy: EnemyEntity, dmap: DijkstraMap) -> void:
	var dist: int = AISystem.chebyshev(enemy.grid_pos, player.grid_pos)
	var sees: bool = bool(visible[enemy.grid_pos.x][enemy.grid_pos.y]) and dist <= enemy.chase_range
	var memory: int = ConfigManager.get_int("alert_memory_turns", 0)
	if sees:
		if not enemy.alerted:
			enemy.alerted = true
			enemy.alert_turns = memory
			enemy_alerted.emit(enemy)
			log_msg(StringManager.t("enemy_notices", {Name = enemy_name(enemy, true)}), "warn")
			return
		enemy.alert_turns = memory
	elif enemy.alerted:
		enemy.alert_turns -= 1
		if enemy.alert_turns <= 0:
			enemy.alerted = false
			return
	else:
		return

	var action: Dictionary = AISystem.decide(enemy, player, dungeon, enemy_positions, dmap, sees, rng)
	match str(action["type"]):
		"attack":
			_enemy_attack(enemy, enemy.attack, "enemy_attacks")
		"shoot":
			projectile_fired.emit(enemy.grid_pos, player.grid_pos, enemy.color)
			_enemy_attack(enemy, enemy.ranged_attack, "enemy_shoots")
		"move":
			var from: Vector2i = enemy.grid_pos
			enemy_positions.erase(from)
			enemy.grid_pos = action["pos"] as Vector2i
			enemy_positions[enemy.grid_pos] = enemy
			entity_moved.emit(enemy, from, enemy.grid_pos)

func _enemy_attack(enemy: EnemyEntity, attack: int, msg_key: String) -> void:
	var r: Dictionary = CombatSystem.resolve(attack, player, 0.0, rng)
	entity_attacked.emit(enemy, player, int(r["damage"]), false)
	log_msg(StringManager.t(msg_key, {Name = enemy_name(enemy, true), damage = int(r["damage"])}), "damage")
	if not player.is_alive():
		_player_death(enemy)

func _player_death(killer: EnemyEntity) -> void:
	phase = Phase.GAME_OVER
	death_killer = killer
	player_died.emit()

## Cause of death, built on demand so it follows a language switch.
func death_text() -> String:
	if death_killer != null:
		return StringManager.t("death_cause", {Name = enemy_name(death_killer, true), floor = current_floor})
	return StringManager.t("death_starved", {floor = current_floor})

func _refresh_fov() -> void:
	visible = FOVSystem.compute(dungeon, player.grid_pos, ConfigManager.get_int("fov_radius", 8))
	for x in dungeon.width:
		for y in dungeon.height:
			if visible[x][y]:
				dungeon.explored[x][y] = true

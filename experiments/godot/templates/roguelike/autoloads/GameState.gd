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
#   move, attack (bump into an enemy), break a barrel (bump into it), wait,
#   use an item, throw a dagger.
#   Free: bumping into a wall, dropping an item, taking the stairs.
#
# THE KEY: the stairs of every floor are closed by a grille. On floors 1 to
#   N-1 a key thief carries the key: he wanders between rooms, runs away as
#   soon as he sees you (down a safety map that leads to escape routes),
#   gets out of breath after thief_flee_steps steps and must rest
#   thief_tired_turns turns, the only time daggers cannot miss him (he
#   dodges thief_dodge_chance of them while running). Three ways to find
#   him: you hear his keys when
#   he is within key_hear_distance steps (direction shown around you, and
#   in the log the first time), he leaves fresh footprints, and throwing
#   daggers reaches him from afar. He drops the key when he dies; walking
#   onto the stairs with it opens the grille. On the last floor the Warden
#   carries the key of the portal.
#
# TWO KINDS OF SIGNALS:
#   state signals   run_started, dungeon_ready, turn_ended, stats_changed, message_added,
#                   player_died, player_won: the HUD refreshes from them.
#   event signals   entity_moved, entity_attacked, entity_died,
#                   projectile_fired, enemy_alerted, item_picked, item_used,
#                   spell_hit, player_leveled, wall_bumped, key_dropped,
#                   key_picked, stairs_unlocked, stairs_refused,
#                   dagger_thrown, dagger_dodged, barrel_broken, enemy_split,
#                   bones_crushed, skeleton_rose, thief_panicked,
#                   thief_tired, keys_heard: one per thing
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
signal key_dropped(pos: Vector2i)
signal key_picked(pos: Vector2i)
signal stairs_unlocked(pos: Vector2i)
signal stairs_refused(pos: Vector2i)
signal dagger_thrown(from: Vector2i, to: Vector2i)
signal dagger_dodged(enemy: EnemyEntity)
signal barrel_broken(pos: Vector2i)
signal enemy_split(child: EnemyEntity, from: Vector2i)
signal bones_crushed(pos: Vector2i)
signal skeleton_rose(enemy: EnemyEntity)
signal thief_panicked(thief: EnemyEntity)
signal thief_tired(thief: EnemyEntity)
signal keys_heard(strength: float)

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
var thief: EnemyEntity = null          # the key thief of this floor, while alive
var key_hint := Vector2.ZERO           # direction of the jingling keys (zero = not heard)
var key_hint_strength: float = 0.0     # 1 next to you, 0 at the limit of hearing
var keys_found: int = 0
var daggers_thrown: int = 0

var _hunger_warned: bool = false
var _starve_warned: bool = false
var _heard_once: bool = false
var _jingle_turn: int = 0

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
	keys_found     = 0
	daggers_thrown = 0
	death_killer   = null
	_hunger_warned = false
	_starve_warned = false
	player = PlayerEntity.new()
	run_started.emit()
	log_msg(StringManager.t("welcome", {total = total_floors}), "info")
	_generate_floor()
	log_msg(StringManager.t("key_thief"), "hint")

## One player action. direction = movement delta, Vector2i.ZERO = wait.
func player_action(direction: Vector2i) -> void:
	if phase != Phase.PLAYER:
		return
	if direction != Vector2i.ZERO:
		if direction.x != 0:
			player.facing = signi(direction.x)
		var target_pos: Vector2i = player.grid_pos + direction
		if enemy_positions.has(target_pos):
			_player_attack(enemy_positions[target_pos] as EnemyEntity)
		elif dungeon.barrels.has(target_pos):
			_break_barrel(target_pos)
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

## Throws a dagger at the enemy on `target_pos`, or at the best visible
## target in range when no position is given (the thief first, then the
## nearest enemy). The dagger falls where it hits and can be picked up.
func throw_dagger(target_pos: Vector2i = Vector2i(-1, -1)) -> void:
	if phase != Phase.PLAYER:
		return
	if player.daggers <= 0:
		log_msg(StringManager.t("no_daggers"), "warn")
		return
	var target: EnemyEntity = null
	if dungeon.in_bounds(target_pos):
		if enemy_positions.has(target_pos) and _can_throw_at(enemy_positions[target_pos] as EnemyEntity):
			target = enemy_positions[target_pos] as EnemyEntity
	else:
		target = best_throw_target()
	if target == null:
		log_msg(StringManager.t("no_target", {range = ConfigManager.get_int("dagger_range", 6)}), "warn")
		return
	player.daggers -= 1
	daggers_thrown += 1
	if target.grid_pos.x != player.grid_pos.x:
		player.facing = signi(target.grid_pos.x - player.grid_pos.x)
	dagger_thrown.emit(player.grid_pos, target.grid_pos)
	# the thief dodges daggers while he still has his breath
	if target.ai == "thief" and target.tired <= 0 and rng.randf() < ConfigManager.get_float("thief_dodge_chance", 0.0):
		dagger_dodged.emit(target)
		log_msg(StringManager.t("thief_dodges"), "warn")
		_drop_item_near(target.grid_pos, ItemDatabase.get_type("dagger"))
		target.alerted = true
		_end_player_turn()
		return
	var attack: int = maxi(1, player.attack + ConfigManager.get_int("dagger_attack_bonus", 0))
	var r: Dictionary = CombatSystem.resolve(attack, target, player.crit_chance, rng)
	var dmg: int = int(r["damage"])
	entity_attacked.emit(player, target, dmg, bool(r["crit"]))
	log_msg(StringManager.t("dagger_hits", {target = enemy_name(target), damage = dmg}), "combat")
	_drop_item_near(target.grid_pos, ItemDatabase.get_type("dagger"))
	if not target.is_alive():
		_kill_enemy(target)
	else:
		_after_hit(target)
	_end_player_turn()

## True if a dagger can reach `e`: visible, within dagger_range, clear line.
func can_throw_at(e: EnemyEntity) -> bool:
	return _can_throw_at(e)

func _can_throw_at(e: EnemyEntity) -> bool:
	return bool(visible[e.grid_pos.x][e.grid_pos.y]) \
		and AISystem.chebyshev(e.grid_pos, player.grid_pos) <= ConfigManager.get_int("dagger_range", 6) \
		and FOVSystem.has_los(dungeon, player.grid_pos, e.grid_pos)

## The target an automatic throw picks: the thief if reachable, otherwise
## the nearest enemy (the weakest one on a tie). null if none.
func best_throw_target() -> EnemyEntity:
	if thief != null and thief.is_alive() and _can_throw_at(thief):
		return thief
	var best: EnemyEntity = null
	var best_d: int = 1 << 20
	for e in enemies:
		if not _can_throw_at(e):
			continue
		var d: int = AISystem.chebyshev(e.grid_pos, player.grid_pos)
		if d < best_d or (d == best_d and best != null and e.hp < best.hp):
			best_d = d
			best = e
	return best

## Puts an item on `pos`, or on the nearest free floor cell around it.
func _drop_item_near(pos: Vector2i, item: Dictionary) -> Vector2i:
	if item.is_empty():
		return Vector2i(-1, -1)
	for radius in 4:
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var p: Vector2i = pos + Vector2i(dx, dy)
				if dungeon.get_tile(p) == DungeonData.TileType.FLOOR and not dungeon.items.has(p) and not dungeon.barrels.has(p):
					dungeon.items[p] = item
					return p
	return Vector2i(-1, -1)

## Takes the stairs (or the exit portal on the last floor), once unlocked.
func descend() -> void:
	if phase != Phase.PLAYER or dungeon.get_tile(player.grid_pos) != DungeonData.TileType.STAIRS_DOWN:
		return
	if dungeon.stairs_locked:
		log_msg(StringManager.t("grille_locked_portal" if dungeon.is_last_floor else "grille_locked"), "warn")
		stairs_refused.emit(player.grid_pos)
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
	log_msg(StringManager.t("key_warden" if dungeon.is_last_floor else "key_thief"), "hint")

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
	thief = null
	key_hint = Vector2.ZERO
	key_hint_strength = 0.0
	_heard_once = false
	player.has_key = false
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
		if enemy.ai == "thief":
			thief = enemy
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
		_after_hit(enemy)

## A hit that did not kill: the enemy wakes up; a slime splits in two.
func _after_hit(enemy: EnemyEntity) -> void:
	enemy.alerted = true
	enemy.alert_turns = ConfigManager.get_int("alert_memory_turns", 0)
	if enemy.splits and enemy.hp >= ConfigManager.get_int("slime_split_min_hp", 4):
		_split(enemy)

## Half of the slime's HP goes into a new slime on a free neighbouring cell.
func _split(enemy: EnemyEntity) -> void:
	var cells: Array[Vector2i] = []
	for dir in DijkstraMap.DIRS:
		var p: Vector2i = enemy.grid_pos + dir
		if dungeon.is_walkable(p) and not enemy_positions.has(p) and p != player.grid_pos:
			cells.append(p)
	if cells.is_empty():
		return
	var child := EnemyEntity.new()
	child.setup_from_data(enemy.type_data)
	var half: int = floori(enemy.hp / 2.0)
	child.hp_max = maxi(half, 1)
	child.hp = half
	child.attack = enemy.attack
	child.defense = enemy.defense
	child.xp_value = maxi(1, floori(enemy.xp_value / 2.0))
	child.alerted = true
	child.alert_turns = enemy.alert_turns
	child.facing = enemy.facing
	child.grid_pos = cells[rng.randi_range(0, cells.size() - 1)]
	enemy.hp -= half
	enemy.hp_max = maxi(enemy.hp_max - half, enemy.hp)
	enemies.append(child)
	enemy_positions[child.grid_pos] = child
	enemy_split.emit(child, enemy.grid_pos)
	log_msg(StringManager.t("slime_splits"), "warn")

func _kill_enemy(enemy: EnemyEntity) -> void:
	kills += 1
	enemy_positions.erase(enemy.grid_pos)
	enemies.erase(enemy)
	entity_died.emit(enemy)
	log_msg(StringManager.t("enemy_died", {Name = enemy_name(enemy, true), xp = enemy.xp_value}), "loot")
	if enemy.key_carrier:
		var at: Vector2i = _drop_item_near(enemy.grid_pos, ItemDatabase.get_type("key"))
		key_dropped.emit(at)
		log_msg(StringManager.t("key_dropped"), "loot")
	if enemy == thief:
		thief = null
		key_hint = Vector2.ZERO
		key_hint_strength = 0.0
	if enemy.revives:
		dungeon.bone_piles[enemy.grid_pos] = {turns = ConfigManager.get_int("skeleton_revive_turns", 7), data = enemy.type_data}
		log_msg(StringManager.t("bones_fall"), "hint")
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
	if dungeon.bone_piles.has(pos):
		dungeon.bone_piles.erase(pos)
		bones_crushed.emit(pos)
		log_msg(StringManager.t("bones_crushed"), "info")
	if dungeon.get_tile(pos) == DungeonData.TileType.STAIRS_DOWN:
		if dungeon.stairs_locked and player.has_key:
			player.has_key = false
			dungeon.stairs_locked = false
			stairs_unlocked.emit(pos)
			log_msg(StringManager.t("grille_opens_portal" if dungeon.is_last_floor else "grille_opens"), "level")
		if dungeon.stairs_locked:
			log_msg(StringManager.t("grille_locked_portal" if dungeon.is_last_floor else "grille_locked"), "warn")
		else:
			log_msg(StringManager.t("exit_here" if dungeon.is_last_floor else "stairs_here"), "hint")

## Bumping into a barrel breaks it; there may be something inside.
func _break_barrel(pos: Vector2i) -> void:
	dungeon.barrels.erase(pos)
	barrel_broken.emit(pos)
	if rng.randf() < ConfigManager.get_float("barrel_loot_chance", 0.4) and not dungeon.items.has(pos):
		var roll: float = rng.randf()
		var id: String = "ration"
		if roll >= 0.85:
			id = ItemDatabase.pick_for_floor(current_floor, rng)
		elif roll >= 0.6:
			id = "dagger"
		elif roll >= 0.45:
			id = "potion"
		var item: Dictionary = ItemDatabase.get_type(id)
		if not item.is_empty():
			dungeon.items[pos] = item
			log_msg(StringManager.t("barrel_loot", {name = ItemDatabase.display_name(item)}), "loot")
			return
	log_msg(StringManager.t("barrel_empty"), "info")

func _try_pickup(pos: Vector2i) -> void:
	var item: Dictionary = dungeon.items[pos]
	var item_name: String = ItemDatabase.display_name(item)
	var effect: String = str(item.get("effect", ""))
	if effect == "dagger":
		if player.daggers >= player.daggers_max:
			log_msg(StringManager.t("daggers_full", {max = player.daggers_max}), "warn")
			return
		dungeon.items.erase(pos)
		player.daggers += 1
		item_picked.emit(item, pos)
		log_msg(StringManager.t("picked_dagger", {value = player.daggers, max = player.daggers_max}), "loot")
	elif effect == "key":
		dungeon.items.erase(pos)
		player.has_key = true
		keys_found += 1
		key_picked.emit(pos)
		log_msg(StringManager.t("key_picked_portal" if dungeon.is_last_floor else "key_picked"), "level")
	elif bool(item.get("instant", false)):
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
					_after_hit(e)
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
	var dmap: DijkstraMap = DijkstraMap.compute(dungeon, player.grid_pos, 1 << 20)
	var flee_map: DijkstraMap = null
	for enemy in enemies.duplicate():
		if not enemy.is_alive() or not enemies.has(enemy):
			continue
		enemy.action_points += enemy.speed
		while enemy.action_points >= 1.0:
			enemy.action_points -= 1.0
			if enemy.ai == "thief":
				if flee_map == null:
					flee_map = DijkstraMap.flee(dmap)
				_thief_act(enemy, flee_map)
			else:
				_enemy_act(enemy, dmap)
			if phase == Phase.GAME_OVER:
				return
	_tick_bones()
	_update_key_hint(dmap)
	if turn % 10 == 0:
		_prune_footprints()
	phase = Phase.PLAYER

func _prune_footprints() -> void:
	var life: int = ConfigManager.get_int("footprint_turns", 40)
	for pos in dungeon.footprints.keys():
		if turn - int((dungeon.footprints[pos] as Dictionary).get("turn", 0)) > life:
			dungeon.footprints.erase(pos)

func _move_enemy(enemy: EnemyEntity, to: Vector2i) -> void:
	var from: Vector2i = enemy.grid_pos
	enemy_positions.erase(from)
	enemy.grid_pos = to
	enemy_positions[to] = enemy
	if to.x != from.x:
		enemy.facing = signi(to.x - from.x)
	if enemy.ai == "thief":
		dungeon.footprints[from] = {turn = turn, dir = to - from}
	entity_moved.emit(enemy, from, to)

## The key thief. Tired: rests (strikes back if cornered next to you).
## Sees you: runs down the safety map; out of breath after thief_flee_steps
## steps. Otherwise wanders from room to room, pausing now and then.
func _thief_act(t: EnemyEntity, flee_map: DijkstraMap) -> void:
	var dist: int = AISystem.chebyshev(t.grid_pos, player.grid_pos)
	var sees: bool = bool(visible[t.grid_pos.x][t.grid_pos.y]) and dist <= ConfigManager.get_int("thief_flee_range", 7)
	if t.tired > 0:
		t.tired -= 1
		if dist <= 1:
			_enemy_attack(t, t.attack, "enemy_attacks")
		return
	if sees:
		if not t.fleeing:
			t.fleeing = true
			thief_panicked.emit(t)
			log_msg(StringManager.t("thief_flees"), "warn")
		if t.flee_steps >= ConfigManager.get_int("thief_flee_steps", 9):
			t.fleeing = false
			t.flee_steps = 0
			t.tired = ConfigManager.get_int("thief_tired_turns", 4)
			thief_tired.emit(t)
			log_msg(StringManager.t("thief_tired"), "hint")
			return
		var step: Vector2i = flee_map.step_toward(t.grid_pos, enemy_positions, player.grid_pos)
		if step != t.grid_pos:
			_move_enemy(t, step)
			t.flee_steps += 1
		elif dist <= 1:
			_enemy_attack(t, t.attack, "enemy_attacks")
		return
	t.fleeing = false
	t.flee_steps = maxi(t.flee_steps - 1, 0)
	if rng.randf() < 0.4:
		return
	if t.wander_map == null or t.grid_pos == t.wander_target or t.wander_map.get_dist(t.grid_pos) < 0:
		var room: Rect2i = dungeon.rooms[rng.randi_range(0, dungeon.rooms.size() - 1)]
		t.wander_target = room.position + room.size / 2
		t.wander_map = DijkstraMap.compute(dungeon, t.wander_target, 1 << 20)
	var wstep: Vector2i = t.wander_map.step_toward(t.grid_pos, enemy_positions, player.grid_pos)
	if wstep == t.grid_pos:
		t.wander_map = null
	else:
		_move_enemy(t, wstep)

## Fallen skeletons rise again after skeleton_revive_turns turns, unless
## the player walks over their bones first (that crushes them).
func _tick_bones() -> void:
	for pos_v in dungeon.bone_piles.keys():
		var pos: Vector2i = pos_v as Vector2i
		var pile: Dictionary = dungeon.bone_piles[pos]
		pile["turns"] = int(pile["turns"]) - 1
		if int(pile["turns"]) > 0:
			continue
		if pos == player.grid_pos or enemy_positions.has(pos):
			pile["turns"] = 1
			continue
		dungeon.bone_piles.erase(pos)
		var e := EnemyEntity.new()
		e.setup_from_data(pile["data"] as Dictionary)
		e.scale_for_floor(current_floor)
		e.hp = maxi(1, ceili(e.hp_max * ConfigManager.get_float("skeleton_revive_ratio", 0.6)))
		e.revives = false
		e.alerted = true
		e.alert_turns = ConfigManager.get_int("alert_memory_turns", 0)
		e.grid_pos = pos
		enemies.append(e)
		enemy_positions[pos] = e
		skeleton_rose.emit(e)
		log_msg(StringManager.t("skeleton_rises"), "warn")

## The thief's keys can be heard within key_hear_distance steps (walking
## distance, so walls muffle them): direction and loudness for the view,
## and a line in the log the first time on the floor.
func _update_key_hint(dmap: DijkstraMap) -> void:
	key_hint = Vector2.ZERO
	key_hint_strength = 0.0
	if thief == null or not thief.is_alive() or bool(visible[thief.grid_pos.x][thief.grid_pos.y]):
		return
	var d: int = dmap.get_dist(thief.grid_pos)
	var hear: int = ConfigManager.get_int("key_hear_distance", 18)
	if d < 0 or d > hear:
		return
	key_hint = Vector2(thief.grid_pos - player.grid_pos).normalized()
	key_hint_strength = 1.0 - float(d) / float(hear + 1)
	if not _heard_once:
		_heard_once = true
		log_msg(StringManager.t("keys_heard", {dir = StringManager.t("dir_" + compass(key_hint))}), "hint")
	if turn - _jingle_turn >= 3:
		_jingle_turn = turn
		keys_heard.emit(key_hint_strength)

## "n", "ne", "e"... for a direction on screen (north is up).
static func compass(v: Vector2) -> String:
	var names: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
	var a: float = fposmod(v.angle(), TAU)
	return names[roundi(a / (TAU / 8.0)) % 8]

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
	if str(action["type"]) != "move" and player.grid_pos.x != enemy.grid_pos.x:
		enemy.facing = signi(player.grid_pos.x - enemy.grid_pos.x)
	match str(action["type"]):
		"attack":
			_enemy_attack(enemy, enemy.attack, "enemy_attacks")
		"shoot":
			projectile_fired.emit(enemy.grid_pos, player.grid_pos, enemy.color)
			_enemy_attack(enemy, enemy.ranged_attack, "enemy_shoots")
		"move":
			_move_enemy(enemy, action["pos"] as Vector2i)

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

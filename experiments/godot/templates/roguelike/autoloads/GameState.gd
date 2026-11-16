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
#   move, attack (bump into an enemy), dash, break a barrel or light a keg
#   (bump into it), wait, use an item, throw a dagger.
#   Free: bumping into a wall, dropping an item, taking the stairs, trying
#   to dash while it recharges.
#
# THE KEY: the stairs of every floor are closed by a grille. On floors 1 to
#   N-1 a key thief carries the key: he wanders between rooms, runs away as
#   soon as he sees you (down a safety map that leads to escape routes),
#   gets out of breath after thief_flee_steps steps and must rest
#   thief_tired_turns turns, the only time daggers cannot miss him (he
#   dodges thief_dodge_chance of them while running; a charge never misses).
#   Three ways to find him: you hear his keys when he is within
#   key_hear_distance steps (direction shown around you, and in the log the
#   first time), he leaves fresh footprints, and throwing daggers reaches him
#   from afar. He drops the key when he dies; walking onto the stairs with it
#   opens the grille. On the last floor the Warden carries the key of the
#   portal.
#
# DYNAMIC COMBAT:
#   dash       Shift + direction: up to dash_range cells in a line, then a
#              charge on the enemy in the way (bonus damage, +1 per cell
#              run, the target is pushed back and stunned). Recharges in
#              dash_cooldown turns.
#   knockback  a charge, a critical hit or a blast pushes the target one
#              cell. Pushed into a wall, a barrel or another enemy: impact,
#              both take impact_damage and are stunned. Into a powder keg:
#              it explodes. Massive enemies (troll, Warden) do not move.
#   dangers    heavy blows and arrows are announced one turn ahead: the
#              cells they will strike are listed in `dangers` (drawn in red)
#              and resolved at the start of the next enemy turn, on whoever
#              stands there, enemies included. Pushing or stunning the
#              attacker cancels its blow.
#   kegs       bump a powder keg to light it (keg_fuse_turns), bump it again
#              to send it sliding; a dagger or an impact sets it off at once.
#              The blast hurts everything within keg_radius, you included,
#              and sets off other kegs.
#   elan       every kill adds a stack (up to elan_max) and heals the stack
#              count in HP; every elan_damage_every stacks add +1 damage.
#              It drops after elan_window turns without hitting anything.
#
# TWO KINDS OF SIGNALS:
#   state signals   run_started, dungeon_ready, turn_ended, stats_changed,
#                   message_added, player_died, player_won: the HUD
#                   refreshes from them.
#   event signals   one per thing that HAPPENED (entity_moved,
#                   entity_attacked, player_dashed, enemy_knocked,
#                   keg_exploded...). DungeonView turns them into
#                   animations, particles, sounds and shakes. The logic
#                   resolves instantly; the view catches up visually.
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
signal entity_hurt(target: Entity, damage: int, kind: String)   # impact, blast, friendly fire
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
signal player_dashed(from: Vector2i, to: Vector2i)
signal enemy_knocked(enemy: EnemyEntity, from: Vector2i, to: Vector2i)
signal impact(enemy: EnemyEntity, at: Vector2i)
signal enemy_stunned(enemy: EnemyEntity)
signal danger_marked(danger: Dictionary)
signal danger_struck(danger: Dictionary)
signal attack_interrupted(enemy: EnemyEntity)
signal heavy_dodged(enemy: EnemyEntity)
signal keg_lit(pos: Vector2i)
signal keg_slid(from: Vector2i, to: Vector2i)
signal keg_exploded(pos: Vector2i, radius: int)
signal elan_changed(value: int, gained: bool)
signal warden_enraged(enemy: EnemyEntity)

var phase:         Phase = Phase.PLAYER
var current_floor: int   = 1
var total_floors:  int   = 1
var turn:          int   = 0
var kills:         int   = 0
var death_killer:  EnemyEntity = null   # null after a death by starvation or blast
var death_cause:   String = ""          # "enemy", "starved", "blast"

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
var best_elan: int = 0
# Announced attacks: {owner: EnemyEntity, kind: "cleave"|"slam"|"arrow",
# cells: Array[Vector2i], mult: float}. Resolved at the next enemy turn.
var dangers: Array[Dictionary] = []

var _hunger_warned: bool = false
var _starve_warned: bool = false
var _heard_once: bool = false
var _jingle_turn: int = 0
var _hit_this_turn: bool = false

const RING: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]

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
	best_elan      = 0
	death_killer   = null
	death_cause    = ""
	_hunger_warned = false
	_starve_warned = false
	_hit_this_turn = false
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
			_bump_barrel(target_pos, direction)
		elif dungeon.is_walkable(target_pos):
			var from: Vector2i = player.grid_pos
			player.grid_pos = target_pos
			entity_moved.emit(player, from, target_pos)
			_on_player_enter(target_pos)
		else:
			wall_bumped.emit(direction)
			return   # wall bump: free, enemies do not act
	_end_player_turn()

## Dash: up to dash_range cells in a straight line. Stops before a wall, a
## barrel or an enemy. An enemy in the way (or right next to you) takes a
## charge; a barrel at the end is broken, a keg lit or sent sliding. Things
## on the cells you run over are picked up. Costs a turn, then recharges.
func player_dash(direction: Vector2i) -> void:
	if phase != Phase.PLAYER or direction == Vector2i.ZERO:
		return
	if player.dash_cd > 0:
		log_msg(StringManager.t("dash_not_ready", {turns = player.dash_cd}), "warn")
		return
	if direction.x != 0:
		player.facing = signi(direction.x)
	var from: Vector2i = player.grid_pos
	var pos: Vector2i = from
	var steps: int = 0
	var target: EnemyEntity = null
	var barrel := Vector2i(-1, -1)
	for i in ConfigManager.get_int("dash_range", 3):
		var nxt: Vector2i = pos + direction
		if enemy_positions.has(nxt):
			target = enemy_positions[nxt] as EnemyEntity
			break
		if dungeon.barrels.has(nxt):
			barrel = nxt
			break
		if not dungeon.is_walkable(nxt):
			break
		pos = nxt
		steps += 1
	if steps == 0 and target == null and barrel.x < 0:
		wall_bumped.emit(direction)
		return
	player.dash_cd = ConfigManager.get_int("dash_cooldown", 6)
	if steps > 0:
		player.grid_pos = pos
		player_dashed.emit(from, pos)
		for i in range(1, steps):
			_on_player_enter(from + direction * i, true)
		_on_player_enter(pos)
	if target != null:
		_player_attack(target, steps)
	elif barrel.x >= 0:
		_bump_barrel(barrel, direction)
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

## Throws a dagger at the enemy (or powder keg) on `target_pos`, or at the
## best visible target in range when no position is given (the thief first,
## then the nearest enemy). The dagger falls where it hits and can be picked
## up. A keg hit by a dagger explodes at once.
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
		elif dungeon.is_keg(target_pos) and can_throw_at_cell(target_pos):
			_throw_at_keg(target_pos)
			return
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
	var attack: int = maxi(1, player.attack + elan_bonus() + ConfigManager.get_int("dagger_attack_bonus", 0))
	var r: Dictionary = CombatSystem.resolve(attack, target, player.crit_chance, rng)
	var dmg: int = int(r["damage"])
	_hit_this_turn = true
	entity_attacked.emit(player, target, dmg, bool(r["crit"]))
	log_msg(StringManager.t("dagger_hits", {target = enemy_name(target), damage = dmg}), "combat")
	_drop_item_near(target.grid_pos, ItemDatabase.get_type("dagger"))
	if not target.is_alive():
		_kill_enemy(target)
	else:
		_after_hit(target)
		if bool(r["crit"]):
			_knockback(target, (target.grid_pos - player.grid_pos).sign())
	_end_player_turn()

func _throw_at_keg(pos: Vector2i) -> void:
	player.daggers -= 1
	daggers_thrown += 1
	if pos.x != player.grid_pos.x:
		player.facing = signi(pos.x - player.grid_pos.x)
	dagger_thrown.emit(player.grid_pos, pos)
	_explode_kegs([pos])
	_drop_item_near(pos, ItemDatabase.get_type("dagger"))
	_end_player_turn()

## True if a dagger can reach `e`: visible, within dagger_range, clear line.
func can_throw_at(e: EnemyEntity) -> bool:
	return _can_throw_at(e)

func _can_throw_at(e: EnemyEntity) -> bool:
	return can_throw_at_cell(e.grid_pos)

func can_throw_at_cell(p: Vector2i) -> bool:
	return bool(visible[p.x][p.y]) \
		and AISystem.chebyshev(p, player.grid_pos) <= ConfigManager.get_int("dagger_range", 6) \
		and FOVSystem.has_los(dungeon, player.grid_pos, p)

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

## Bonus damage from the elan stacks.
func elan_bonus() -> int:
	if player == null:
		return 0
	return floori(player.elan / float(maxi(ConfigManager.get_int("elan_damage_every", 2), 1)))

## Damage of a powder keg blast on this floor.
func keg_damage() -> int:
	return ConfigManager.get_int("keg_damage", 8) + int(ConfigManager.get_float("keg_damage_per_floor", 0.0) * (current_floor - 1))

## Damage of an impact (pushed into an obstacle) on this floor.
func impact_damage() -> int:
	return ConfigManager.get_int("impact_damage", 3) + int(ConfigManager.get_float("impact_damage_per_floor", 0.0) * (current_floor - 1))

## The announced attack of `e`, or an empty dictionary.
func danger_of(e: EnemyEntity) -> Dictionary:
	for dz in dangers:
		if dz["owner"] == e:
			return dz
	return {}

## True if a cell will be struck at the next enemy turn (heavy blow, arrow
## line, or within the blast of a keg about to explode).
func is_cell_threatened(p: Vector2i) -> bool:
	for dz in dangers:
		if (dz["cells"] as Array).has(p):
			return true
	var r: int = ConfigManager.get_int("keg_radius", 1)
	for k in dungeon.fuses.keys():
		if int(dungeon.fuses[k]) <= 1 and AISystem.chebyshev(k as Vector2i, p) <= r:
			return true
	return false

# =============================================================================
# FLOOR GENERATION
# =============================================================================

func _generate_floor() -> void:
	enemies.clear()
	enemy_positions.clear()
	dangers.clear()
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

## Melee hit. charge_steps >= 0: a dash charge after that many cells, with
## ATK + dash_attack_bonus + charge_steps; the target is stunned and pushed.
## A critical hit pushes too.
func _player_attack(enemy: EnemyEntity, charge_steps: int = -1) -> void:
	var charging: bool = charge_steps >= 0
	var dir: Vector2i = (enemy.grid_pos - player.grid_pos).sign()
	var atk: int = player.attack + elan_bonus()
	if charging:
		atk += ConfigManager.get_int("dash_attack_bonus", 1) + charge_steps
	var r: Dictionary = CombatSystem.resolve(atk, enemy, player.crit_chance, rng)
	var dmg: int = int(r["damage"])
	var crit: bool = bool(r["crit"])
	_hit_this_turn = true
	entity_attacked.emit(player, enemy, dmg, crit)
	var key: String = "player_charge" if charging else ("player_crit" if crit else "player_attacks")
	log_msg(StringManager.t(key, {target = enemy_name(enemy), damage = dmg}), "combat")
	if not enemy.is_alive():
		_kill_enemy(enemy)
		return
	_after_hit(enemy)
	if charging:
		_stun(enemy)
	if charging or crit:
		_knockback(enemy, dir)

## A hit that did not kill: the enemy wakes up; a slime splits in two; the
## Warden enrages below half HP.
func _after_hit(enemy: EnemyEntity) -> void:
	enemy.alerted = true
	enemy.alert_turns = ConfigManager.get_int("alert_memory_turns", 0)
	if enemy.splits and enemy.hp >= ConfigManager.get_int("slime_split_min_hp", 4):
		_split(enemy)
	if enemy.is_boss and not enemy.enraged and enemy.hp * 2 <= enemy.hp_max:
		enemy.enraged = true
		warden_enraged.emit(enemy)
		log_msg(StringManager.t("warden_enraged"), "warn")

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

## Stuns an enemy (it skips its next stun_turns actions) and cancels the
## blow it was winding up.
func _stun(e: EnemyEntity) -> void:
	if not enemies.has(e):
		return
	e.stunned = maxi(e.stunned, ConfigManager.get_int("stun_turns", 1))
	_interrupt(e)
	enemy_stunned.emit(e)

## Pushes `e` one cell along `dir`. A free cell: it slides there. A wall, a
## barrel or another enemy: impact, both take impact_damage and are stunned.
## A powder keg: it explodes. Massive enemies are not moved.
func _knockback(e: EnemyEntity, dir: Vector2i) -> void:
	if e.massive or dir == Vector2i.ZERO or not enemies.has(e):
		return
	var from: Vector2i = e.grid_pos
	var to: Vector2i = from + dir
	_interrupt(e)
	if dungeon.is_keg(to):
		impact.emit(e, to)
		_explode_kegs([to])
		return
	if dungeon.is_walkable(to) and not enemy_positions.has(to) and to != player.grid_pos:
		enemy_positions.erase(from)
		e.grid_pos = to
		enemy_positions[to] = e
		enemy_knocked.emit(e, from, to)
		return
	if to == player.grid_pos:
		return
	var dmg: int = impact_damage()
	var victims: Array[EnemyEntity] = [e]
	if enemy_positions.has(to):
		victims.append(enemy_positions[to] as EnemyEntity)
	impact.emit(e, to)
	log_msg(StringManager.t("impact_msg", {Name = enemy_name(e, true), damage = dmg}), "combat")
	if dungeon.barrels.has(to):
		_break_barrel(to)
	_hit_this_turn = true
	for v in victims:
		if not enemies.has(v):
			continue
		v.take_damage(dmg)
		entity_hurt.emit(v, dmg, "impact")
		if not v.is_alive():
			_kill_enemy(v)
		else:
			_after_hit(v)
			_stun(v)

## Removes the blow `e` was winding up, if any.
func _interrupt(e: EnemyEntity) -> void:
	var had: bool = false
	for i in range(dangers.size() - 1, -1, -1):
		if dangers[i]["owner"] == e:
			had = true
			dangers.remove_at(i)
	e.aiming = false
	if had:
		attack_interrupted.emit(e)
		log_msg(StringManager.t("attack_interrupted", {target = enemy_name(e)}), "combat")

func _kill_enemy(enemy: EnemyEntity) -> void:
	if not enemies.has(enemy):
		return
	kills += 1
	enemy_positions.erase(enemy.grid_pos)
	enemies.erase(enemy)
	for i in range(dangers.size() - 1, -1, -1):
		if dangers[i]["owner"] == enemy:
			dangers.remove_at(i)
	entity_died.emit(enemy)
	var healed: int = _gain_elan()
	if healed > 0:
		log_msg(StringManager.t("enemy_died_heal", {Name = enemy_name(enemy, true), xp = enemy.xp_value, hp = healed}), "loot")
	else:
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

## One more elan stack; heals the stack count. Returns the HP healed.
func _gain_elan() -> int:
	if player == null or not player.is_alive():
		return 0
	player.elan = mini(player.elan + 1, ConfigManager.get_int("elan_max", 5))
	player.elan_timer = ConfigManager.get_int("elan_window", 4)
	best_elan = maxi(best_elan, player.elan)
	_hit_this_turn = true
	elan_changed.emit(player.elan, true)
	return player.heal(player.elan * ConfigManager.get_int("elan_heal_per_stack", 1))

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

## The player arrives on `pos`. passing = a cell run over during a dash:
## items are picked up and bones crushed, the stairs say nothing.
func _on_player_enter(pos: Vector2i, passing: bool = false) -> void:
	if dungeon.items.has(pos):
		_try_pickup(pos)
	if dungeon.bone_piles.has(pos):
		dungeon.bone_piles.erase(pos)
		bones_crushed.emit(pos)
		log_msg(StringManager.t("bones_crushed"), "info")
	if passing:
		return
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

## Bumping into a barrel breaks it; into a keg lights it, or sends it
## sliding when it is already lit.
func _bump_barrel(pos: Vector2i, dir: Vector2i) -> void:
	if not dungeon.is_keg(pos):
		_break_barrel(pos)
	elif dungeon.fuses.has(pos):
		_slide_keg(pos, dir)
	else:
		dungeon.fuses[pos] = ConfigManager.get_int("keg_fuse_turns", 3)
		keg_lit.emit(pos)
		log_msg(StringManager.t("keg_lit", {turns = dungeon.fuses[pos]}), "warn")

## A lit keg slides up to keg_slide cells and stops before an obstacle;
## stopped by an enemy, it explodes on contact.
func _slide_keg(pos: Vector2i, dir: Vector2i) -> void:
	var fuse: int = int(dungeon.fuses[pos])
	var at: Vector2i = pos
	var hit_enemy: bool = false
	for i in ConfigManager.get_int("keg_slide", 4):
		var nxt: Vector2i = at + dir
		if enemy_positions.has(nxt):
			hit_enemy = true
			break
		if not dungeon.is_walkable(nxt) or nxt == player.grid_pos or dungeon.items.has(nxt):
			break
		at = nxt
	if at == pos and not hit_enemy:
		log_msg(StringManager.t("keg_stuck"), "info")
		return
	dungeon.barrels.erase(pos)
	dungeon.fuses.erase(pos)
	dungeon.barrels[at] = "keg"
	dungeon.fuses[at] = fuse
	keg_slid.emit(pos, at)
	log_msg(StringManager.t("keg_kicked"), "info")
	if hit_enemy:
		_explode_kegs([at])

## Explodes the kegs at `cells`, then every keg caught in a blast (chain).
## Each blast deals keg_damage to everything within keg_radius, the player
## included, ignoring defense; survivors are pushed away; plain barrels in
## the blast break.
func _explode_kegs(cells: Array) -> void:
	var queue: Array[Vector2i] = []
	for c in cells:
		queue.append(c as Vector2i)
	var r: int = ConfigManager.get_int("keg_radius", 1)
	var dmg: int = keg_damage()
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if not dungeon.is_keg(c):
			continue
		dungeon.barrels.erase(c)
		dungeon.fuses.erase(c)
		keg_exploded.emit(c, r)
		log_msg(StringManager.t("keg_explodes"), "warn")
		if AISystem.chebyshev(player.grid_pos, c) <= r:
			player.take_damage(dmg)
			entity_hurt.emit(player, dmg, "blast")
			log_msg(StringManager.t("blast_hits_you", {damage = dmg}), "damage")
			if not player.is_alive():
				_player_death(null, "blast")
				return
		for e in enemies.duplicate():
			if not enemies.has(e) or AISystem.chebyshev(e.grid_pos, c) > r:
				continue
			e.take_damage(dmg)
			entity_hurt.emit(e, dmg, "blast")
			_hit_this_turn = true
			if not e.is_alive():
				_kill_enemy(e)
			else:
				_after_hit(e)
				_knockback(e, (e.grid_pos - c).sign())
				if phase == Phase.GAME_OVER:
					return
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var p: Vector2i = c + Vector2i(dx, dy)
				if dungeon.is_keg(p):
					queue.append(p)
				elif dungeon.barrels.has(p):
					_break_barrel(p)

## A plain barrel breaks; there may be something inside.
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
			_hit_this_turn = true
			for e in hit:
				if not enemies.has(e):
					continue
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
			if dungeon.get_tile(p) != DungeonData.TileType.FLOOR or enemy_positions.has(p) or dungeon.items.has(p) or dungeon.barrels.has(p):
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
	if phase == Phase.GAME_OVER:   # killed by your own blast during your action
		stats_changed.emit()
		turn_ended.emit()
		return
	turn += 1
	if player.dash_cd > 0:
		player.dash_cd -= 1
	_tick_elan()
	_tick_needs()
	if not player.is_alive():
		_player_death(null, "starved")
		turn_ended.emit()
		return
	_refresh_fov()
	_process_enemy_turns()
	stats_changed.emit()
	turn_ended.emit()

## Elan: kept while you keep hitting; drops after elan_window turns without.
func _tick_elan() -> void:
	if player.elan > 0:
		if _hit_this_turn:
			player.elan_timer = ConfigManager.get_int("elan_window", 4)
		else:
			player.elan_timer -= 1
			if player.elan_timer <= 0:
				player.elan = 0
				elan_changed.emit(0, false)
				log_msg(StringManager.t("elan_lost"), "info")
	_hit_this_turn = false

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

## The enemy turn: first the blows announced last turn land and the lit
## fuses burn, then every enemy acts (action points), then the bones and
## the jingling keys.
func _process_enemy_turns() -> void:
	phase = Phase.ENEMY
	_resolve_dangers()
	if phase == Phase.GAME_OVER:
		return
	_tick_fuses()
	if phase == Phase.GAME_OVER:
		return
	var dmap: DijkstraMap = DijkstraMap.compute(dungeon, player.grid_pos, 1 << 20)
	var flee_map: DijkstraMap = null
	for enemy in enemies.duplicate():
		if not enemy.is_alive() or not enemies.has(enemy):
			continue
		if enemy.struck:   # recovers from the heavy blow it just landed
			enemy.struck = false
			continue
		enemy.action_points += enemy.speed
		while enemy.action_points >= 1.0 and enemies.has(enemy):
			enemy.action_points -= 1.0
			if enemy.stunned > 0:
				enemy.stunned -= 1
				continue
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

## Lit fuses burn down; kegs at zero explode.
func _tick_fuses() -> void:
	var boom: Array = []
	for p in dungeon.fuses.keys():
		dungeon.fuses[p] = int(dungeon.fuses[p]) - 1
		if int(dungeon.fuses[p]) <= 0:
			boom.append(p)
	if not boom.is_empty():
		_explode_kegs(boom)

## The blows announced last turn land, on whoever stands in their cells.
func _resolve_dangers() -> void:
	var list: Array[Dictionary] = dangers.duplicate()
	dangers.clear()
	for dz in list:
		var owner: EnemyEntity = dz["owner"] as EnemyEntity
		if owner == null or not enemies.has(owner):
			continue
		if str(dz["kind"]) == "arrow":
			_resolve_arrow(owner, dz)
		else:
			owner.struck = true
			_resolve_heavy(owner, dz)
		if phase == Phase.GAME_OVER:
			return

## The arrow flies along the marked line and hits the first creature on it
## (another enemy too), or sets off a keg; otherwise it is lost.
func _resolve_arrow(owner: EnemyEntity, dz: Dictionary) -> void:
	var cells: Array = dz["cells"]
	if cells.is_empty():
		return
	var end: Vector2i = cells[cells.size() - 1]
	var hit: Entity = null
	var keg := Vector2i(-1, -1)
	for c in cells:
		var p: Vector2i = c as Vector2i
		if p == player.grid_pos:
			hit = player
			end = p
			break
		if enemy_positions.has(p) and enemy_positions[p] != owner:
			hit = enemy_positions[p] as Entity
			end = p
			break
		if dungeon.is_keg(p):
			keg = p
			end = p
			break
	if end.x != owner.grid_pos.x:
		owner.facing = signi(end.x - owner.grid_pos.x)
	projectile_fired.emit(owner.grid_pos, end, owner.color)
	danger_struck.emit(dz)
	if hit == player:
		_enemy_attack(owner, owner.ranged_attack, "enemy_shoots")
	elif hit != null:
		var victim: EnemyEntity = hit as EnemyEntity
		var r: Dictionary = CombatSystem.resolve(owner.ranged_attack, victim, 0.0, rng)
		entity_hurt.emit(victim, int(r["damage"]), "friendly")
		log_msg(StringManager.t("friendly_arrow", {name = enemy_name(owner), target = enemy_name(victim), damage = int(r["damage"])}), "combat")
		if not victim.is_alive():
			_kill_enemy(victim)
		else:
			_after_hit(victim)
	elif keg.x >= 0:
		_explode_kegs([keg])

## A heavy blow lands on its cells: the player, other enemies, barrels.
func _resolve_heavy(owner: EnemyEntity, dz: Dictionary) -> void:
	danger_struck.emit(dz)
	var atk: int = int(round(owner.attack * float(dz["mult"])))
	var hit_player: bool = false
	var victims: Array[EnemyEntity] = []
	var kegs: Array = []
	for c in dz["cells"]:
		var p: Vector2i = c as Vector2i
		if p == player.grid_pos:
			hit_player = true
		elif enemy_positions.has(p) and enemy_positions[p] != owner:
			victims.append(enemy_positions[p] as EnemyEntity)
		if dungeon.is_keg(p):
			kegs.append(p)
		elif dungeon.barrels.has(p):
			_break_barrel(p)
	if hit_player:
		_enemy_attack(owner, atk, "enemy_heavy_hits")
		if phase == Phase.GAME_OVER:
			return
	else:
		heavy_dodged.emit(owner)
		log_msg(StringManager.t("heavy_dodged", {target = enemy_name(owner)}), "hint")
	for v in victims:
		if not enemies.has(v):
			continue
		var r: Dictionary = CombatSystem.resolve(atk, v, 0.0, rng)
		entity_hurt.emit(v, int(r["damage"]), "friendly")
		log_msg(StringManager.t("friendly_heavy", {Name = enemy_name(owner, true), target = enemy_name(v), damage = int(r["damage"])}), "combat")
		if not v.is_alive():
			_kill_enemy(v)
		else:
			_after_hit(v)
	if not kegs.is_empty():
		_explode_kegs(kegs)

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
	if not danger_of(enemy).is_empty():
		return   # a blow is already on its way
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

	enemy.heavy_charge += 1
	var action: Dictionary = AISystem.decide(enemy, player, dungeon, enemy_positions, dmap, sees, rng)
	var kind: String = str(action["type"])
	if kind != "move" and player.grid_pos.x != enemy.grid_pos.x:
		enemy.facing = signi(player.grid_pos.x - enemy.grid_pos.x)
	if kind != "aim":
		enemy.aiming = false
	match kind:
		"attack":
			_enemy_attack(enemy, enemy.attack, "enemy_attacks")
		"windup":
			_windup(enemy)
		"aim":
			_aim(enemy)
		"move":
			_move_enemy(enemy, action["pos"] as Vector2i)

## Heavy blow announced: the cells it will strike at the next enemy turn.
##   cleave  the three cells in front of the enemy, toward the player
##   slam    every cell around it, radius 1 (2 once enraged)
func _windup(e: EnemyEntity) -> void:
	var cells: Array[Vector2i] = []
	if e.heavy == "slam":
		var r: int = 2 if e.enraged else 1
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var p: Vector2i = e.grid_pos + Vector2i(dx, dy)
				if p != e.grid_pos and dungeon.is_open(p):
					cells.append(p)
	else:
		var d: Vector2i = (player.grid_pos - e.grid_pos).sign()
		var i: int = RING.find(d)
		for k in [0, 1, -1]:
			var p: Vector2i = e.grid_pos + RING[posmod(i + k, 8)]
			if dungeon.is_open(p):
				cells.append(p)
	e.heavy_charge = 0
	var dz: Dictionary = {owner = e, kind = e.heavy, cells = cells, mult = e.heavy_mult}
	dangers.append(dz)
	danger_marked.emit(dz)
	log_msg(StringManager.t("warden_winds_up" if e.heavy == "slam" else "enemy_winds_up", {Name = enemy_name(e, true)}), "warn")

## Aimed shot: the line from the archer through the player, out to its
## range, cut by the first wall. The arrow flies along it next turn.
func _aim(e: EnemyEntity) -> void:
	var delta: Vector2i = player.grid_pos - e.grid_pos
	var k: float = float(e.attack_range) / float(maxi(AISystem.chebyshev(player.grid_pos, e.grid_pos), 1))
	var end: Vector2i = e.grid_pos + Vector2i(roundi(delta.x * k), roundi(delta.y * k))
	var cells: Array[Vector2i] = []
	var line: Array = FOVSystem.line(e.grid_pos, end)
	for i in range(1, line.size()):
		var p: Vector2i = line[i] as Vector2i
		if dungeon.get_tile(p) == DungeonData.TileType.WALL:
			break
		cells.append(p)
	if cells.is_empty():
		return
	var dz: Dictionary = {owner = e, kind = "arrow", cells = cells, mult = 1.0}
	dangers.append(dz)
	danger_marked.emit(dz)
	if not e.aiming:
		log_msg(StringManager.t("archer_aims", {Name = enemy_name(e, true)}), "warn")
	e.aiming = true

func _enemy_attack(enemy: EnemyEntity, attack: int, msg_key: String) -> void:
	var r: Dictionary = CombatSystem.resolve(attack, player, 0.0, rng)
	entity_attacked.emit(enemy, player, int(r["damage"]), false)
	log_msg(StringManager.t(msg_key, {Name = enemy_name(enemy, true), damage = int(r["damage"])}), "damage")
	if not player.is_alive():
		_player_death(enemy, "enemy")

func _player_death(killer: EnemyEntity, cause: String) -> void:
	phase = Phase.GAME_OVER
	death_killer = killer
	death_cause = cause
	player_died.emit()

## Cause of death, built on demand so it follows a language switch.
func death_text() -> String:
	if death_killer != null:
		return StringManager.t("death_cause", {Name = enemy_name(death_killer, true), floor = current_floor})
	if death_cause == "blast":
		return StringManager.t("death_blast", {floor = current_floor})
	return StringManager.t("death_starved", {floor = current_floor})

func _refresh_fov() -> void:
	visible = FOVSystem.compute(dungeon, player.grid_pos, ConfigManager.get_int("fov_radius", 8))
	for x in dungeon.width:
		for y in dungeon.height:
			if visible[x][y]:
				dungeon.explored[x][y] = true

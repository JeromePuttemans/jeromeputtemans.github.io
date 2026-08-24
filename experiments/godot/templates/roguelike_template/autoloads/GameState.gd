# =============================================================================
# GameState.gd — Autoload (Singleton)
# =============================================================================
# Central game state and turn-processing state machine.
#
# STATE MACHINE:
#   PLAYER → (player acts) → ENEMY → (all enemies act) → PLAYER
#   Any phase → GAME_OVER (player HP reaches 0)
#   Any phase → VICTORY   (player descends past the final floor)
#
# SIGNAL GRAPH (unidirectional, no UI dependency in this file):
#   dungeon_ready  → DungeonView, HUD, MessageLog
#   turn_ended     → DungeonView, HUD
#   message_added  → MessageLog
#   player_died    → Overlay (game over screen)
#   player_won     → Overlay (victory screen)
# =============================================================================

extends Node

enum Phase { PLAYER, ENEMY, GAME_OVER, VICTORY }

signal dungeon_ready()
signal turn_ended()
signal message_added(text: String)
signal player_died()
signal player_won()

var phase: Phase = Phase.PLAYER
var current_floor: int = 1

var player: PlayerEntity = null
var dungeon: DungeonData = null
var enemies: Array       = []   # Array[EnemyEntity]
# Spatial index for O(1) enemy lookups by position.
# Must stay in sync with the enemies array at all times.
var enemy_positions: Dictionary = {}   # { Vector2i: EnemyEntity }
var visible: Array = []                # 2D bool [x][y], current FOV

# =============================================================================
# PUBLIC API
# =============================================================================

## Starts a brand-new game. Creates the player and generates floor 1.
func new_game() -> void:
	current_floor = 1
	player = PlayerEntity.new()
	_generate_floor()

## Advances to the next floor (or triggers VICTORY if past the last floor).
## Called internally when the player steps on STAIRS_DOWN.
func next_floor() -> void:
	current_floor += 1
	if current_floor > ConfigManager.get_int("total_floors", 5):
		phase = Phase.VICTORY
		emit_signal("player_won")
		return
	_generate_floor()
	log_msg(StringManager.t("descend_msg"))

## Processes one player action.
## direction: movement delta (Vector2i.ZERO = wait, passing the turn).
## Returns immediately if it is not the player's turn.
func player_action(direction: Vector2i) -> void:
	if phase != Phase.PLAYER:
		return

	if direction == Vector2i.ZERO:
		pass  # Wait: player does nothing but enemies still act

	elif enemy_positions.has(player.grid_pos + direction):
		# Bump-to-attack: moving into an enemy's cell triggers combat
		var target: EnemyEntity = enemy_positions[player.grid_pos + direction]
		var dmg = CombatSystem.resolve_attack(player.attack, target)
		log_msg(StringManager.t("player_attacks", {target = target.display_name, damage = dmg}))
		if not target.is_alive():
			log_msg(StringManager.t("enemy_died", {name = target.display_name}))
			_remove_enemy(target)

	elif dungeon.is_walkable(player.grid_pos + direction):
		player.grid_pos += direction
		# Check for stair descent
		if dungeon.get_tile(player.grid_pos) == DungeonData.TileType.STAIRS_DOWN:
			next_floor()
			emit_signal("turn_ended")
			return

	else:
		return  # Wall bump: do not consume the turn

	_refresh_fov()
	_process_enemy_turns()

	emit_signal("turn_ended")

## Appends a message to the game log.
func log_msg(text: String) -> void:
	emit_signal("message_added", text)

# =============================================================================
# PRIVATE — FLOOR GENERATION
# =============================================================================

func _generate_floor() -> void:
	enemies.clear()
	enemy_positions.clear()

	dungeon = DungeonGenerator.generate(ConfigManager.get_raw(), EnemyDatabase.get_all())
	player.grid_pos = dungeon.player_start

	for spawn in dungeon.enemy_spawns:
		var type_data = EnemyDatabase.get_type(spawn["type_id"])
		if type_data.is_empty():
			continue
		var enemy = EnemyEntity.new()
		enemy.setup_from_data(type_data)
		enemy.grid_pos = spawn["pos"]
		enemies.append(enemy)
		enemy_positions[enemy.grid_pos] = enemy

	_refresh_fov()
	phase = Phase.PLAYER
	emit_signal("dungeon_ready")

# =============================================================================
# PRIVATE — TURN PROCESSING
# =============================================================================

func _process_enemy_turns() -> void:
	phase = Phase.ENEMY

	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var action = AISystem.get_action(enemy, player, dungeon, enemy_positions)
		match action["type"]:
			"move":
				# Update spatial index before and after the move
				enemy_positions.erase(enemy.grid_pos)
				enemy.grid_pos = action["pos"]
				enemy_positions[enemy.grid_pos] = enemy
			"attack":
				var dmg = CombatSystem.resolve_attack(enemy.attack, player)
				log_msg(StringManager.t("enemy_attacks", {name = enemy.display_name, damage = dmg}))
				if not player.is_alive():
					phase = Phase.GAME_OVER
					emit_signal("player_died")
					return  # Stop processing further enemies

	phase = Phase.PLAYER

func _refresh_fov() -> void:
	visible = FOVSystem.compute(dungeon, player.grid_pos, ConfigManager.get_int("fov_radius", 8))
	# Merge newly visible tiles into the persistent explored map
	for x in dungeon.width:
		for y in dungeon.height:
			if visible[x][y]:
				dungeon.explored[x][y] = true

func _remove_enemy(enemy: EnemyEntity) -> void:
	enemy_positions.erase(enemy.grid_pos)
	enemies.erase(enemy)

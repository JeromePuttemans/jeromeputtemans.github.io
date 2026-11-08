extends Node3D

# Player: Handles player movement, bomb usage, and interaction with cubes.
# Assumes the player is a child of MainScene alongside GridManager and HUD.

# Signals
signal moved(to_position)
signal bomb_used
signal hp_changed(amount)
signal fragments_changed(amount)
signal cubes_created_changed(amount)

# References
var grid_manager : Node3D
var game_manager : Node3D

# State
var current_position : Vector3i = Vector3i.ZERO
var is_moving : bool = false
var movement_speed : float = 0.1  # seconds per tile

# Input mapping (ZQSD for horizontal, A/E for vertical, Space for bomb)
# Using string-based key constants that work in Godot 4
const MOVE_FRONT = "z"
const MOVE_BACK = "s"
const MOVE_LEFT = "q"
const MOVE_RIGHT = "d"
const MOVE_DOWN = "a"
const MOVE_UP = "e"
const BOMB_KEY = "space"

# Direction vectors for movement
const VEC_FRONT = Vector3i(0, 0, -1)
const VEC_BACK = Vector3i(0, 0, 1)
const VEC_LEFT = Vector3i(-1, 0, 0)
const VEC_RIGHT = Vector3i(1, 0, 0)
const VEC_DOWN = Vector3i(0, -1, 0)
const VEC_UP = Vector3i(0, 1, 0)

func _ready() -> void:
	# Get references to managers
	grid_manager = get_node_or_null("../GridManager")
	game_manager = get_node_or_null("/root/GameManager")
	
	if not grid_manager:
		push_error("GridManager not found! Ensure Player is child of MainScene.")
	if not game_manager:
		push_error("GameManager not found! Ensure it's autoloaded.")
	
	# Start at teleporter position
	var teleporter_pos = grid_manager.get_teleporter_position()
	current_position = teleporter_pos
	global_position = teleporter_pos  # Assuming 1 unit = 1 cube size
	
	# Connect to game manager signals
	if game_manager:
		game_manager.connect("hp_changed", Callable(self, "_on_game_manager_hp_changed"))
		game_manager.connect("fragments_changed", Callable(self, "_on_game_manager_fragments_changed"))
	
	# Initial HUD update
	_update_hud()

func _unready() -> void:
	if game_manager:
		game_manager.disconnect("hp_changed", Callable(self, "_on_game_manager_hp_changed"))
		game_manager.disconnect("fragments_changed", Callable(self, "_on_game_manager_fragments_changed"))

func _input(event: InputEvent) -> void:
	if is_moving:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Z: _attempt_move(VEC_FRONT)  # Z key
			KEY_S: _attempt_move(VEC_BACK)   # S key
			KEY_Q: _attempt_move(VEC_LEFT)   # Q key
			KEY_D: _attempt_move(VEC_RIGHT)  # D key
			KEY_A: _attempt_move(VEC_DOWN)   # A key
			KEY_E: _attempt_move(VEC_UP)     # E key
			KEY_SPACE: _use_bomb()           # Space key

func _attempt_move(direction: Vector3i) -> void:
	var target_pos = current_position + direction
	
	# Check if movement is allowed via GridManager
	if grid_manager.can_move_from_to(current_position, target_pos):
		# Start movement
		is_moving = true
		var tween = create_tween()
		tween.tween_property(self, "global_position", target_pos, movement_speed)
		tween.tween_callback(Callable(self, "_on_movement_finished"))
		tween.set_trans(Tween.TRANS_LINEAR)
		tween.set_ease(Tween.EASE_IN_OUT)
		
		# Update position after tween completes (we'll set it in callback)
		# But we need to update current_position immediately for cube interaction?
		# We'll update current_position now to reflect the new grid position
		current_position = target_pos
		
		# Check if cube exists at new position; if not, generate one
		if not grid_manager.has_cube_at(current_position):
			grid_manager.place_random_cube_at(current_position)
		
		# Handle cube interactions (resource/destructor)
		_handle_cube_interaction()
		
		# Emit movement signal
		emit_signal("moved", current_position)
	else:
		# Movement blocked - optional feedback
		pass

func _on_movement_finished() -> void:
	is_moving = false
	# Ensure exact position (avoid floating point errors)
	global_position = current_position
	_update_hud()

func _handle_cube_interaction() -> void:
	var cube_data = grid_manager.get_cube_data(current_position)
	if not cube_data:
		return
	
	match cube_data["type"]:
		grid_manager.RESOURCE_TYPE:
			# Give 10 HP and 1 fragment
			game_manager.modify_hp(10)
			game_manager.add_fragments(1)
			# Convert to neutral after collection
			grid_manager.set_cube_type(current_position, grid_manager.NEUTRAL_TYPE)
			emit_signal("cubes_created_changed", -1)  # One less special cube
		grid_manager.DESTRUCTOR_TYPE:
			# Take 20 HP
			game_manager.modify_hp(-20)
			# Convert to neutral after hazard
			grid_manager.set_cube_type(current_position, grid_manager.NEUTRAL_TYPE)
			emit_signal("cubes_created_changed", -1)
		default:
			# Neutral, teleporter, or energy ball - no effect
			pass

func _use_bomb() -> void:
	if not game_manager:
		return
	
	var hp_cost = game_manager.bomb_cost_hp
	if game_manager.current_hp >= hp_cost:
		game_manager.modify_hp(-hp_cost)
		grid_manager.place_bomb_at(current_position)
		emit_signal("bomb_used")
		# Bomb might have destroyed cubes - update HUD for cubes created
		emit_signal("cubes_created_changed", 0)  # Trigger HUD refresh
	else:
		# Not enough HP - optional feedback (flash screen, sound)
		pass

func _on_game_manager_hp_changed(current_hp: int, max_hp: int) -> void:
	_update_hud()

func _on_game_manager_fragments_changed(fragments: int) -> void:
	_update_hud()

func _update_hud() -> void:
	var hud = get_node_or_null("../HUD")
	if hud:
		hud.update_display(
			game_manager.current_hp,
			game_manager.max_hp,
			game_manager.fragments,
			grid_manager.get_cube_count()  # Assuming GridManager has this method
		)

# Helper methods for external calls (if needed)
func get_grid_position() -> Vector3i:
	return current_position

func set_grid_position(pos: Vector3i) -> void:
	current_position = pos
	global_position = pos
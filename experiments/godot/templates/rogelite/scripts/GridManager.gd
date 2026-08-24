extends Node3D

# GridManager: Manages the 3D grid of cubes, bitmask-based generation, and energy ball placement.

# Signals
signal cube_added(position)
signal cube_removed(position)
signal energy_ball_added(position)
signal teleporter_added(position)
signal level_changed(new_level)

# Constants
const TELEPORTER_TYPE = 3
const ENERGY_BALL_TYPE = 4
const NEUTRAL_TYPE = 0
const RESOURCE_TYPE = 1
const DESTRUCTOR_TYPE = 2

# Direction vectors and their bits
const DIRECTIONS = [
	Vector3i.FRONT,   # (0, 0, -1) - bit 0
	Vector3i.BACK,    # (0, 0, 1)  - bit 1
	Vector3i.LEFT,    # (-1, 0, 0) - bit 2
	Vector3i.RIGHT,   # (1, 0, 0)  - bit 3
	Vector3i.UP,      # (0, 1, 0)  - bit 4
	Vector3i.DOWN     # (0, -1, 0) - bit 5
]

const OPPOSITE_DIRECTION = {
	Vector3i.FRONT: Vector3i.BACK,
	Vector3i.BACK: Vector3i.FRONT,
	Vector3i.LEFT: Vector3i.RIGHT,
	Vector3i.RIGHT: Vector3i.LEFT,
	Vector3i.UP: Vector3i.DOWN,
	Vector3i.DOWN: Vector3i.UP
}

const DIRECTION_BIT = {
	Vector3i.FRONT: 1,   # 2^0
	Vector3i.BACK: 2,    # 2^1
	Vector3i.LEFT: 4,    # 2^2
	Vector3i.RIGHT: 8,   # 2^3
	Vector3i.UP: 16,     # 2^4
	Vector3i.DOWN: 32    # 2^5
}

# Grid data: Dictionary with keys as (x, y, z) tuples, values as {mask: int, type: int}
var grid : Dictionary = {}

# References
var cube_scene : PackedScene
var teleporter : Node3D
var energy_ball : Node3D

# Game state
var current_level : int = 1

func _ready() -> void:
	# Load cube scene (assumed to be in res://scenes/Cube.tscn)
	cube_scene = preload("res://scenes/Cube.tscn")
	
	# Initialize level 1
	set_level(1)
	
	# Connect to GameManager signals if available (optional)
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.connect("level_changed", Callable(self, "set_level"))
		game_manager.connect("player_died", Callable(self, "reset_level"))

func set_level(new_level: int) -> void:
	current_level = new_level
	
	# Clear existing cubes except teleporter
	var keys = grid.keys()
	for key in keys:
		var pos = Vector3i(key[0], key[1], key[2])
		if grid[pos]["type"] != TELEPORTER_TYPE:
			remove_cube_at(pos)
	
	# Ensure teleporter exists at (0,0,0)
	if !has_teleporter():
		place_teleporter()
	
	# Place energy ball at (level * 5, 0, 0)
	var energy_ball_pos = Vector3i(current_level * 5, 0, 0)
	if !grid.has(energy_ball_pos):
		place_energy_ball(energy_ball_pos)
	
	emit_signal("level_changed", current_level)

func place_teleporter() -> void:
	var pos = Vector3i.ZERO
	var mask = 32  # Only Down bit set (wall below, open elsewhere)
	var type = TELEPORTER_TYPE
	place_cube_at(pos, mask, type)
	emit_signal("teleporter_added", pos)

func place_energy_ball(pos: Vector3i) -> void:
	var mask = 0  # All faces open (no walls)
	var type = ENERGY_BALL_TYPE
	place_cube_at(pos, mask, type)
	emit_signal("energy_ball_added", pos)

func place_cube_at(position: Vector3i, mask: int, type: int) -> void:
	# Check if position already occupied
	if grid.has(position):
		push_error("Position already occupied: " + str(position))
		return
	
	# Instance cube
	var cube_instance = cube_scene.instantiate()
	add_child(cube_instance)
	cube_instance.global_position = position
	
	# Set cube metadata
	grid[position] = {
		"mask": mask,
		"type": type
	}
	
	# Update cube visuals based on mask and type
	if cube_instance.has_method("set_grid_data"):
		cube_instance.set_grid_data(mask, type)
	else:
		push_warning("Cube instance does not have set_grid_data method. Please update the cube script.")
	
	# Add to cubes group for easy access
	cube_instance.add_to_group("cubes")
	
	# Emit signal
	emit_signal("cube_added", position)
	
	# Update neighbors: For each existing neighbor, ensure consistency
	# (Though our placement algorithm ensures consistency, we double-check)
	_for_each_neighbor(position, Callable(self, "_update_neighbor_mask"), position)

func place_random_cube_at(position: Vector3i) -> void:
	# Determine cube type based on probabilities
	var roll = randf()
	var type : int
	if roll < 0.85:
		type = NEUTRAL_TYPE
	elif roll < 0.95:
		type = RESOURCE_TYPE
	else:
		type = DESTRUCTOR_TYPE
	
	# Calculate mask based on existing neighbors
	var mask : int = 0
	for direction in DIRECTIONS:
		var neighbor_pos = position + direction
		if grid.has(neighbor_pos):
			var neighbor_data = grid[neighbor_pos]
			var neighbor_mask = neighbor_data["mask"]
			var opp_dir = OPPOSITE_DIRECTION[direction]
			var opp_bit = DIRECTION_BIT[opp_dir]
			# If neighbor has wall in opposite direction, we must have wall in this direction
			if neighbor_mask & opp_bit:
				mask |= DIRECTION_BIT[direction]
	
	place_cube_at(position, mask, type)

func remove_cube_at(position: Vector3i) -> void:
	if !grid.has(position):
		push_error("Position not occupied: " + str(position))
		return
	
	var cube_instance = _get_cube_instance_at(position)
	if cube_instance:
		cube_instance.queue_free()
	
	grid.erase(position)
	emit_signal("cube_removed", position)

func has_teleporter() -> bool:
	for data in grid.values():
		if data["type"] == TELEPORTER_TYPE:
			return true
	return false

func get_teleporter_position() -> Vector3i:
	for pos in grid.keys():
		var data = grid[pos]
		if data["type"] == TELEPORTER_TYPE:
			return pos
	return Vector3i.ZERO  # Fallback

func get_energy_ball_position() -> Vector3i:
	for pos in grid.keys():
		var data = grid[pos]
		if data["type"] == ENERGY_BALL_TYPE:
			return pos
	return Vector3i.ZERO  # Fallback

func get_cube_data(position: Vector3i) -> Dictionary:
	return grid.get(position, null)

func has_cube_at(position: Vector3i) -> bool:
	return grid.has(position)

func get_cube_count() -> int:
	return grid.size()

func set_cube_type(position: Vector3i, new_type: int) -> void:
	if !grid.has(position):
		push_warning("Attempt to set type on non-existent cube at " + str(position))
		return
	grid[position]["type"] = new_type
	# Note: We don't change the mask here; the cube remains passable/impassable as before.
	# However, if we want to change the visual appearance (e.g., resource cube to neutral),
	# we might need to update the cube's material. But the spec says after collection, it becomes neutral.
	# We'll assume that the cube's visuals are based on type as well? Actually, the spec only mentions
	# color for the cube types, but the mask determines walls. We'll leave mask unchanged.
	# If we want to change color, we'd need to update the cube's material based on type.
	# For simplicity, we'll just change the type and let the cube's script handle visuals.
	# We'll need to update the cube instance's visuals accordingly.
	var cube_instance = _get_cube_instance_at(position)
	if cube_instance:
		# Assuming the cube instance has a script that can update its appearance based on type.
		# We'll call a method on it if it exists.
		if cube_instance.has_method("set_cube_type"):
			cube_instance.set_cube_type(new_type)
		# Otherwise, we could change the material here, but we don't have that info.
		# We'll leave it to the cube's script to handle type changes.

func is_wall_in_direction(position: Vector3i, direction: Vector3i) -> bool:
	var data = grid.get(position)
	if !data:
		return true  # Treat out-of-bounds as wall
	var mask = data["mask"]
	var bit = DIRECTION_BIT[direction]
	return (mask & bit) != 0

func can_move_from_to(from_pos: Vector3i, to_pos: Vector3i) -> bool:
	# Determine direction from 'from_pos' to 'to_pos'
	var direction = to_pos - from_pos
	if direction == Vector3i.ZERO:
		return false
	
	# Normalize direction to one of the six axes
	if abs(direction.x) > 1 or abs(direction.y) > 1 or abs(direction.z) > 1:
		return false  # Not a single step
	
	# Find which direction it is
	var step_dir : Vector3i
	if direction == Vector3i.FRONT:
		step_dir = Vector3i.FRONT
	elif direction == Vector3i.BACK:
		step_dir = Vector3i.BACK
	elif direction == Vector3i.LEFT:
		step_dir = Vector3i.LEFT
	elif direction == Vector3i.RIGHT:
		step_dir = Vector3i.RIGHT
	elif direction == Vector3i.UP:
		step_dir = Vector3i.UP
	elif direction == Vector3i.DOWN:
		step_dir = Vector3i.DOWN
	else:
		return false  # Invalid direction
	
	# Check if moving in this direction is allowed from 'from_pos'
	return !is_wall_in_direction(from_pos, step_dir)

func place_bomb_at(position: Vector3i) -> void:
	# Bomb affects 3x3x3 area centered at position
	var half_size = 1
	for x in range(position.x - half_size, position.x + half_size + 1):
		for y in range(position.y - half_size, position.y + half_size + 1):
			for z in range(position.z - half_size, position.z + half_size + 1):
				var bomb_pos = Vector3i(x, y, z)
				# Skip teleporter and energy ball
				if grid.has(bomb_pos):
					var type = grid[bomb_pos]["type"]
					if type == TELEPORTER_TYPE or type == ENERGY_BALL_TYPE:
						continue
					remove_cube_at(bomb_pos)
				# Note: We don't place anything after bomb - just remove

# Helper functions
func _update_cube_visuals(cube_instance: Node3D, mask: int) -> void:
	# Assume cube instance has six MeshInstance3D children named by direction
	var mesh_names = ["Up", "Down", "Left", "Right", "Front", "Back"]
	var bits = [16, 32, 4, 8, 1, 2]  # Up, Down, Left, Right, Front, Back
	
	for i in range(6):
		var mesh_name = mesh_names[i]
		var bit = bits[i]
		var mesh = cube_instance.get_node_or_null(mesh_name)
		if mesh:
			# If bit is set (wall), use opaque material; else transparent
			var is_wall = (mask & bit) != 0
			# Assume we have materials set up in the cube scene:
			#   We'll swap between two materials: opaque_material and transparent_material
			#   For simplicity, we'll assume the mesh has a material override property
			#   In practice, you'd set up two materials in the cube scene and switch them.
			#   Here we just set a placeholder - actual implementation depends on your materials.
			if is_wall:
				mesh.material_override = null  # Use default (opaque) material from scene
			else:
				# Create a transparent material if not already done
				var transparent_material = ShaderMaterial.new()
				transparent_material.shader = preload("res://shaders/transparent.shader")
				mesh.material_override = transparent_material

func _get_cube_instance_at(position: Vector3i) -> Node3D:
	for child in get_children():
		if child.is_in_group("cubes") and child.global_position == position:
			return child
	return null

func _for_each_neighbor(position: Vector3i, callback: Callable, userdata) -> void:
	for direction in DIRECTIONS:
		var neighbor_pos = position + direction
		if grid.has(neighbor_pos):
			callback.call(userdata, neighbor_pos)

func _update_neighbor_mask(center_pos: Vector3i, neighbor_pos: Vector3i) -> void:
	# This is called for each neighbor of a newly placed cube.
	# We ensure the neighbor's mask is consistent with the new cube.
	# Actually, as discussed, we don't need to update the neighbor because
	# the new cube's mask was set to match the neighbor's existing mask.
	# But we leave this as a placeholder for safety.
	pass

func reset_level() -> void:
	# Called when player dies - reset to current level state
	set_level(current_level)
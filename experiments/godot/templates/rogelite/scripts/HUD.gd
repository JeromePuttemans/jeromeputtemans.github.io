extends CanvasLayer

# HUD: Displays HP, Fragments, Cubes created, and a compass pointing to the objective (Energy Ball or Teleporter).

# References
var hp_label : Label
var fragments_label : Label
var cubes_label : Label
var compass_arrow : TextureRect  # Assuming we have an arrow texture pointing up by default

var player : Node3D
var grid_manager : Node3D
var game_manager : Node3D

# For compass: we'll calculate angle from player to target in XZ plane
var target_position : Vector3i = Vector3i.ZERO

func _ready() -> void:
	# Get references to UI elements (adjust node names as per your scene)
	hp_label = $HPLabel
	fragments_label = $FragmentsLabel
	cubes_label = $CubesLabel
	compass_arrow = $CompassArrow
	
	# Get references to gameplay nodes
	player = get_node_or_null("../Player")
	grid_manager = get_node_or_null("../GridManager")
	game_manager = get_node_or_null("/root/GameManager")
	
	if not player:
		push_error("Player node not found! Ensure HUD is child of MainScene alongside Player.")
	if not grid_manager:
		push_error("GridManager not found!")
	if not game_manager:
		push_error("GameManager not found! Ensure it's autoloaded.")
	
	# Connect to signals for updates
	if game_manager:
		game_manager.connect("hp_changed", Callable(self, "_on_hp_changed"))
		game_manager.connect("fragments_changed", Callable(self, "_on_fragments_changed"))
	
	if grid_manager:
		# We'll update cubes count periodically or via signal; let's use a timer for simplicity
		# Alternatively, GridManager can emit a signal when cube count changes.
		pass
	
	# Initial update
	_update_display()

func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	_update_hp_label(current_hp, max_hp)

func _on_fragments_changed(fragments: int) -> void:
	_update_fragments_label(fragments)

func _process(delta: float) -> void:
	# Update cubes count and compass every frame (could be optimized with signals)
	_update_cubes_label()
	_update_compass()

func _update_display() -> void:
	_update_hp_label(game_manager.current_hp, game_manager.max_hp)
	_update_fragments_label(game_manager.fragments)
	_update_cubes_label()
	_update_compass()

func _update_hp_label(current_hp: int, max_hp: int) -> void:
	if hp_label:
		hp_label.text = "HP: %d/%d" % [current_hp, max_hp]

func _update_fragments_label(fragments: int) -> void:
	if fragments_label:
		fragments_label.text = "Fragments: %d" % fragments

func _update_cubes_label() -> void:
	if cubes_label and grid_manager:
		var total_cubes = grid_manager.get_cube_count()  # We'll implement this method in GridManager
		cubes_label.text = "Cubes: %d" % total_cubes

func _update_compass() -> void:
	if !compass_arrow or !player or !grid_manager:
		return
	
	# Determine target: Energy Ball if exists, else Teleporter
	var energy_ball_pos = grid_manager.get_energy_ball_position()
	var teleporter_pos = grid_manager.get_teleporter_position()
	
	# If energy ball exists (always should for current level), target it
	if energy_ball_pos != Vector3i.ZERO:  # Assuming we return ZERO if not found? Better to have a boolean.
		target_position = energy_ball_pos
	else:
		target_position = teleporter_pos
	
	# Get player position (as Vector3i)
	var player_pos : Vector3i
	if player:
		player_pos = Vector3i(
			round(player.global_position.x),
			round(player.global_position.y),
			round(player.global_position.z)
		)
	else:
		return
	
	# Calculate direction vector in XZ plane (ignore Y)
	var dir_x = target_position.x - player_pos.x
	var dir_z = target_position.z - player_pos.z
	
	# If player is at target, hide arrow or show something else? We'll just not rotate.
	if dir_x == 0 and dir_z == 0:
		compass_arrow.visible = false
		return
	
	compass_arrow.visible = true
	
	# Calculate angle in radians for the direction from player to target in XZ plane.
	# We want the arrow (pointing up by default) to point to the target.
	# In Godot 2D (for the HUD), rotation is in degrees clockwise.
	# We'll compute the angle that the arrow should have so that when rotated, it points to the target.
	#
	# We'll assume the arrow texture points upwards (which we want to correspond to world -Z direction).
	# So we need to rotate the arrow by the angle between world -Z and the vector (dir_x, 0, dir_z).
	#
	# Steps:
	# 1. Compute the angle of the vector (dir_x, dir_z) in the XZ plane.
	# 2. The arrow's initial rotation is 0 (pointing up, which we align with world -Z).
	# 3. We want the arrow to point in the direction of the vector (dir_x, dir_z).
	#    Note: In the XZ plane, if we consider:
	#       +X = right, +Z = forward (but in Godot 3D, forward is -Z, so we adjust).
	#    Actually, let's think in terms of the screen: we want the arrow to point to the target on a 2D map.
	#    We'll treat the XZ plane as a 2D plane where X is right and Z is down (since in Godot 2D, Y increases downward).
	#    However, for simplicity, we can use the following:
	#       angle = atan2(dir_x, dir_z)  [because when dir_x=0 and dir_z=-1 (target in front), we want angle=0?]
	#    Let's test:
	#       Target in front: (0, -1) -> atan2(0, -1) = pi (or -pi) -> not 0.
	#    Instead, we want:
	#       angle = atan2(dir_x, -dir_z)  [because when dir_x=0, dir_z=-1 (target in front) -> -dir_z=1 -> atan2(0,1)=0]
	#    Then:
	#       Target right: (1, 0) -> atan2(1, -0)= atan2(1,0)= pi/2 -> 90 degrees (arrow points right) -> good.
	#       Target behind: (0, 1) -> atan2(0, -1)= atan2(0,-1)= -pi/2 -> 270 degrees (or -90) -> arrow points down? Actually, -90 in clockwise rotation is 270, which points up? Let's think.
	#    We'll adjust by converting to degrees and then setting the rotation.
	#
	#    We'll use: angle_rad = atan2(dir_x, -dir_z)
	#    Then convert to degrees.
	#
	var angle_rad : float = atan2(dir_x, -dir_z)
	var angle_deg : float = rad_to_deg(angle_rad)
	# Convert to 0-360
	if angle_deg < 0:
		angle_deg += 360
	
	compass_arrow.rotation = angle_deg

# Helper to get cube count from GridManager (we'll add this method to GridManager)
# But for now, we'll assume GridManager has a method get_cube_count()
# If not, we can compute it here by counting the grid dictionary.
func _get_cube_count_fallback() -> int:
	if grid_manager:
		var grid_dict = grid_manager.get_grid()  # We'd need to expose the grid dictionary
		return grid_dict.size()
	return 0
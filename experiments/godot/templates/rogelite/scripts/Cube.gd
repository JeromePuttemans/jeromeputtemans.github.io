extends StaticBody3D

# Cube: Represents a single cube in the grid with 6 faces (MeshInstance3D).
# Each face can be opaque (wall) or transparent (open) based on the bitmask.
# The cube also has a type (neutral, resource, destructor, teleporter, energy_ball) for visual coloring.

# References to the face meshes
var mesh_up : MeshInstance3D
var mesh_down : MeshInstance3D
var mesh_left : MeshInstance3D
var mesh_right : MeshInstance3D
var mesh_front : MeshInstance3D
var mesh_back : MeshInstance3D

# Materials
var opaque_material : BaseMaterial3D
var transparent_material : BaseMaterial3D

# Cube type (for coloring)
var cube_type : int = 0  # 0: neutral, 1: resource, 2: destructor, 3: teleporter, 4: energy_ball

# Type colors (as albedo tint)
const TYPE_COLORS = [
	Color(0.7, 0.7, 0.7, 1.0),  # Neutral: Gray
	Color(0.0, 0.8, 0.0, 1.0),  # Resource: Emerald
	Color(0.8, 0.0, 0.0, 1.0),  # Destructor: Red
	Color(0.0, 0.0, 0.8, 1.0),  # Teleporter: Blue
	Color(0.8, 0.8, 0.0, 1.0)   # Energy Ball: Yellow
]

func _ready() -> void:
	# Get references to the face meshes (assumed to be direct children named by direction)
	mesh_up = $Up
	mesh_down = $Down
	mesh_left = $Left
	mesh_right = $Right
	mesh_front = $Front
	mesh_back = $Back
	
	# Create transparent material (StandardMaterial3D with alpha)
	if not transparent_material:
		transparent_material = StandardMaterial3D.new()
		transparent_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		transparent_material.albedo_color = Color(1.0, 1.0, 1.0, 0.5)  # White with 50% alpha
		# In Godot 4, we use the 'depth_draw' property for depth testing
		transparent_material.depth_draw = BaseMaterial3D.DEPTH_DRAW_ALPHA_PREPASS
	
	# Create opaque material (default StandardMaterial3D)
	if not opaque_material:
		opaque_material = StandardMaterial3D.new()
		opaque_material.albedo_color = Color(0.8, 0.8, 0.8, 1.0)  # Light gray
		opaque_material.depth_draw = BaseMaterial3D.DEPTH_DRAW_OPAQUE
	
	# Initialize all faces as opaque (walls) - will be updated by set_grid_data
	update_faces_from_mask(0)  # Start with all walls closed

func set_grid_data(mask: int, type: int) -> void:
	# Update the cube's appearance based on mask and type
	cube_type = type
	update_faces_from_mask(mask)
	update_type_color()

func update_faces_from_mask(mask: int) -> void:
	# Define the mapping from direction to mesh and bit
	var faces = [
		{"mesh": mesh_up, "bit": 16},   # Up
		{"mesh": mesh_down, "bit": 32}, # Down
		{"mesh": mesh_left, "bit": 4},  # Left
		{"mesh": mesh_right, "bit": 8}, # Right
		{"mesh": mesh_front, "bit": 1}, # Front
		{"mesh": mesh_back, "bit": 2}   # Back
	]
	
	for face in faces:
		if face["mesh"]:
			var is_wall = (mask & face["bit"]) != 0
			if is_wall:
				face["mesh"].material_override = opaque_material
			else:
				face["mesh"].material_override = transparent_material

func update_type_color() -> void:
	# Apply type color to all faces (multiply with base color)
	var base_color = TYPE_COLORS[cube_type] if cube_type < TYPE_COLORS.size() else Color.WHITE
	var faces = [mesh_up, mesh_down, mesh_left, mesh_right, mesh_front, mesh_back]
	for mesh in faces:
		if mesh and mesh.material_override:
			# Modulate the material's albedo color with the type color
			if mesh.material_override is StandardMaterial3D:
				# We'll multiply the base material color by the type color
				var material = mesh.material_override as StandardMaterial3D
				material.albedo_color = material.albedo_color * base_color
				# Preserve the alpha value (from opaque or transparent material)
				var alpha = material.albedo_color.a
				material.albedo_color = Color(
					material.albedo_color.r,
					material.albedo_color.g,
					material.albedo_color.b,
					alpha
				)

# Helper to get the current mask (if needed externally)
func get_mask() -> int:
	# This would require storing the mask; we'll assume it's managed by GridManager
	return 0  # Placeholder
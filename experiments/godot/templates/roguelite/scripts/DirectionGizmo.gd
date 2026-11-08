class_name DirectionGizmo
extends Node3D

# DirectionGizmo: the six direction arrows and the golden goal arrow around
# the player, as real 3D meshes (child of the player, so it follows moves).
#
# The arrows have a size in world units, so the camera perspective treats
# them like the rooms: an arrow pointing at the camera looks short, an arrow
# lying across the view looks long, and orbiting turns them consistently
# with the maze.
#   open passage: green arrow reaching through the opening into the next room
#   wall:         short faint red arrow stopping before the wall (at 0.5)
# Materials go through the transparent pass with a higher render priority
# than the rooms: the glass walls are drawn first and never tint the arrows.
# The opaque-looking arrows still write depth, so they hide each other
# correctly. The key letters and the goal distance are 2D text drawn by the
# HUD at the projected *_LABEL points.
# The golden arrow hides when the goal is closer than GOAL_MIN_DIST: the core
# or the teleporter is then in plain sight, and the arrow would overlap it.

const OPEN_LABEL: float = 0.95
const BLOCKED_LABEL: float = 0.62
const GOAL_LABEL: float = 1.62
const GOAL_MIN_DIST: float = 1.9   # beyond diagonal neighbours (1.41, 1.73)
const COL_OPEN := Color(0.35, 0.95, 0.55)
const COL_BLOCKED := Color(1.0, 0.35, 0.35)
const COL_GOAL := Color("ffd34d")
const PRIORITY: int = 10

var hud: RogueHUD = null
var _open: Array[Node3D] = []
var _blocked: Array[Node3D] = []
var _goal: Node3D = null

func _ready() -> void:
	var open_mat := _mat(COL_OPEN, 0.55, 1.0)
	var blocked_mat := _mat(COL_BLOCKED, 0.3, 0.4)
	for dir in GridManager.DIRS:
		var b: Basis = basis_to(Vector3(dir))
		var open: Node3D = _arrow(0.27, 0.79, 0.03, 0.08, 0.17, open_mat)
		open.basis = b
		add_child(open)
		_open.append(open)
		var blocked: Node3D = _arrow(0.27, 0.46, 0.025, 0.065, 0.11, blocked_mat)
		blocked.basis = b
		add_child(blocked)
		_blocked.append(blocked)
	_goal = _arrow(0.95, 1.42, 0.035, 0.1, 0.22, _mat(COL_GOAL, 0.8, 1.0))
	add_child(_goal)
	visible = false

func _process(_delta: float) -> void:
	visible = GameManager.can_act() and hud != null and hud.grid != null
	if not visible:
		return
	var cell: Vector3i = hud.player.cell
	for i in GridManager.DIRS.size():
		var open: bool = hud.grid.can_move(cell, GridManager.DIRS[i])
		_open[i].visible = open
		_blocked[i].visible = not open
	var to_goal: Vector3 = Vector3(hud.goal_cell()) - global_position
	_goal.visible = to_goal.length() > GOAL_MIN_DIST
	if _goal.visible:
		_goal.basis = basis_to(to_goal)

## Rotation that turns the local +Y axis (the arrows' axis) toward `dir`.
static func basis_to(dir: Vector3) -> Basis:
	var d: Vector3 = dir.normalized()
	var axis: Vector3 = Vector3.UP.cross(d)
	if axis.length_squared() < 1e-6:
		return Basis.IDENTITY if d.y > 0.0 else Basis(Vector3.RIGHT, PI)
	return Basis(axis.normalized(), Vector3.UP.angle_to(d))

## Arrow along local +Y: shaft from `start`, cone ending at `tip`.
static func _arrow(start: float, tip: float, shaft_r: float, head_r: float, head_len: float, mat: Material) -> Node3D:
	var arm := Node3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = shaft_r
	shaft_mesh.bottom_radius = shaft_r
	shaft_mesh.height = tip - head_len - start
	shaft_mesh.radial_segments = 12
	shaft_mesh.rings = 0
	var shaft := MeshInstance3D.new()
	shaft.mesh = shaft_mesh
	shaft.position.y = start + shaft_mesh.height * 0.5
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = head_r
	head_mesh.height = head_len
	head_mesh.radial_segments = 16
	head_mesh.rings = 0
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	head.position.y = tip - head_len * 0.5
	for mi in [shaft, head]:
		var m: MeshInstance3D = mi as MeshInstance3D
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arm.add_child(m)
	return arm

static func _mat(color: Color, emission: float, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = emission
	m.roughness = 0.4
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS if alpha >= 1.0 else BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	m.render_priority = PRIORITY
	m.disable_fog = true
	return m

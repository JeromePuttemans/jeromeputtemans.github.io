# =============================================================================
# CameraRig.gd — First-person camera and the astrolabe in hand
# =============================================================================
# The rig is a top-level node, outside physics interpolation: it follows the
# body's interpolated position every rendered frame and turns at once with
# the mouse, so looking around has no latency at any refresh rate. The body
# reads the rig's yaw to move.
# FEEL: head bob locked to the steps (a dip at each footfall, a slight
#   sway), a spring dip on landing scaled by the impact, a small kick on
#   jumping, a roll when strafing, a wider field of view when running, and
#   a short shake for big events (the gnomon rising).
# ASTROLABE: a brass ring held at the bottom right, its needle pointing at
#   the hour (7:00 on the left, 17:00 on the right), its sun bead glowing
#   while the hour moves. Drawn without depth test so it never sinks into
#   walls; it sways against the mouse and bobs with the steps.
# =============================================================================

class_name CameraRig
extends Node3D

var player: Player = null
var sun: Sun = null
var camera: Camera3D = null
var look_enabled: bool = false
var follow: bool = true
var yaw: float = 0.0
var pitch: float = 0.0
var sensitivity: float = 0.12
var invert_y: bool = false

var _eye: float = 1.6
var _bob_amount: float = 0.05
var _fov: float = 74.0
var _sprint_fov: float = 80.0
var _land_dip: float = 0.16
var _pad_speed: float = 2.6
var _dip: float = 0.0
var _dip_velocity: float = 0.0
var _roll: float = 0.0
var _shake: float = 0.0
var _bob_weight: float = 0.0
var _astrolabe: Node3D = null
var _needle: Node3D = null
var _bead: MeshInstance3D = null
var _bead_material: StandardMaterial3D = null
var _sway := Vector2.ZERO
var _raise: float = 0.0

func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_eye = ConfigManager.get_float("eye_height", 1.6)
	_bob_amount = ConfigManager.get_float("bob_amount", 0.05)
	_fov = ConfigManager.get_float("fov", 74.0)
	_sprint_fov = ConfigManager.get_float("sprint_fov", 80.0)
	_land_dip = ConfigManager.get_float("land_dip", 0.16)
	_pad_speed = ConfigManager.get_float("pad_look_speed", 2.6)
	sensitivity = float(SaveManager.get_setting("sensitivity", ConfigManager.get_float("mouse_sensitivity", 0.12)))
	invert_y = bool(SaveManager.get_setting("invert_y", false))
	camera = Camera3D.new()
	camera.fov = _fov
	camera.near = 0.05
	camera.far = 1600.0
	add_child(camera)
	_build_astrolabe()

func set_view(new_yaw: float, new_pitch: float) -> void:
	yaw = new_yaw
	pitch = new_pitch
	_apply_rotation()

func _unhandled_input(event: InputEvent) -> void:
	if not look_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion: Vector2 = (event as InputEventMouseMotion).relative
		yaw -= motion.x * sensitivity * 0.01
		pitch -= motion.y * sensitivity * 0.01 * (-1.0 if invert_y else 1.0)
		pitch = clampf(pitch, -1.5, 1.5)
		_sway += motion * 0.0004
		_apply_rotation()

func land(impact: float) -> void:
	_dip_velocity -= clampf(impact * 0.11, 0.0, 2.2) * _land_dip / 0.16

func jump_kick() -> void:
	_dip_velocity += 0.35

func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _apply_rotation() -> void:
	rotation = Vector3(pitch, yaw, _roll)

func set_astrolabe_visible(value: bool) -> void:
	_astrolabe.visible = value

func _process(delta: float) -> void:
	if player == null or not follow:
		return
	if look_enabled:
		var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if stick.length() > 0.2:
			yaw -= stick.x * _pad_speed * delta
			pitch = clampf(pitch - stick.y * _pad_speed * 0.7 * delta * (-1.0 if invert_y else 1.0), -1.5, 1.5)
	var base: Vector3 = player.get_global_transform_interpolated().origin
	var grounded: bool = player.is_on_floor()
	var walk: float = clampf(player.horizontal_speed / 5.0, 0.0, 1.5)
	_bob_weight = lerpf(_bob_weight, walk if grounded else 0.0, 1.0 - exp(-10.0 * delta))
	var bob_y: float = -absf(sin(player.step_phase)) * _bob_amount * _bob_weight
	var bob_x: float = sin(player.step_phase) * _bob_amount * 0.5 * _bob_weight
	# Spring integrated in small fixed steps: a single step of a slow frame
	# (under 10 images per second) would make it diverge.
	var steps: int = ceili(delta / 0.008)
	var h: float = delta / maxf(float(steps), 1.0)
	for i in steps:
		_dip_velocity += (-_dip * 140.0 - _dip_velocity * 15.0) * h
		_dip += _dip_velocity * h
	_dip = clampf(_dip, -0.6, 0.4)
	_roll = lerpf(_roll, -player.strafe * 0.025, 1.0 - exp(-8.0 * delta))
	_shake = maxf(_shake - delta * 1.2, 0.0)
	var shake := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * _shake * 0.12
	_apply_rotation()
	position = base + Vector3(0.0, _eye + bob_y + _dip, 0.0) + basis.x * bob_x + shake
	var target_fov: float = _sprint_fov if (player.sprinting and player.horizontal_speed > 5.5) else _fov
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-6.0 * delta))
	_update_astrolabe(delta, bob_y, bob_x)

# --- astrolabe -------------------------------------------------------------------

func _overlay(color: Color, emission: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.7
	m.roughness = 0.3
	m.no_depth_test = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = 100
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

func _build_astrolabe() -> void:
	_astrolabe = Node3D.new()
	camera.add_child(_astrolabe)
	var brass := _overlay(Color(0.85, 0.62, 0.3), 0.15)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.085
	torus.outer_radius = 0.1
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = brass
	ring.rotation.x = PI * 0.5
	_astrolabe.add_child(ring)
	var face := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.085
	disc.bottom_radius = 0.085
	disc.height = 0.004
	disc.radial_segments = 24
	face.mesh = disc
	face.material_override = _overlay(Color(0.1, 0.08, 0.2, 0.82), 0.0)
	face.rotation.x = PI * 0.5
	face.position.z = -0.004
	_astrolabe.add_child(face)
	for i in 11:
		var tick := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.003, 0.012 if i % 5 == 0 else 0.007, 0.003)
		tick.mesh = box
		tick.material_override = brass
		var a: float = _hour_angle(7.0 + i)
		tick.position = Vector3(sin(a), cos(a), 0.0) * 0.072
		tick.rotation.z = -a
		_astrolabe.add_child(tick)
	_needle = Node3D.new()
	_astrolabe.add_child(_needle)
	var needle_mesh := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.004, 0.06, 0.003)
	needle_mesh.mesh = bar
	needle_mesh.material_override = brass
	needle_mesh.position = Vector3(0.0, 0.03, 0.002)
	_needle.add_child(needle_mesh)
	_bead = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.009
	sphere.height = 0.018
	_bead.mesh = sphere
	_bead_material = _overlay(Color(1.0, 0.78, 0.35), 2.0)
	_bead.material_override = _bead_material
	_bead.position = Vector3(0.0, 0.066, 0.004)
	_needle.add_child(_bead)
	var hub := MeshInstance3D.new()
	var cap := SphereMesh.new()
	cap.radius = 0.008
	cap.height = 0.016
	hub.mesh = cap
	hub.material_override = brass
	_astrolabe.add_child(hub)

## 7:00 points left and up, noon straight up, 17:00 right and up.
func _hour_angle(h: float) -> float:
	return (h - 12.0) / 5.0 * deg_to_rad(75.0)

func _update_astrolabe(delta: float, bob_y: float, bob_x: float) -> void:
	if _astrolabe == null or sun == null:
		return
	var moving: float = clampf(absf(sun.speed) * 1.5, 0.0, 1.0)
	_raise = lerpf(_raise, moving, 1.0 - exp(-8.0 * delta))
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-7.0 * delta))
	_astrolabe.position = Vector3(0.3 - _sway.x * 0.3 + bob_x * 0.5, -0.24 + _raise * 0.04 + bob_y * 0.6 + _sway.y * 0.3, -0.62)
	_astrolabe.rotation = Vector3(-0.2 + _raise * 0.18, -0.4 + _raise * 0.25, 0.1)
	_needle.rotation.z = -_hour_angle(sun.hour)
	_bead_material.emission_energy_multiplier = 1.5 + _raise * 4.0

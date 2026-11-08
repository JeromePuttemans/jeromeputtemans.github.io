extends Node3D

# Main: 3D environment, camera, run flow.
#
# CAMERA: a rig node follows the player with exponential smoothing; the
#   camera sits on the rig's +Z axis, the rig being pitched and yawed. The
#   default yaw keeps the three world axes visually distinct on screen
#   (front/back, left/right and up/down never overlap), which matters in a
#   3D grid. Orbit: drag with any mouse button (yaw free, pitch clamped),
#   wheel: zoom, R: back to the default angle. The yaw is passed to the
#   player every frame, so movement keys stay relative to the view.
# FLOW: intro screen (a maze is already displayed behind it) -> new run ->
#   level_started regenerates the maze -> core delivered: upgrade choice
#   (HUD), then the next level_started -> run_ended shows the end screen ->
#   Enter or the button starts a new run.

@onready var grid: GridManager = $GridManager
@onready var player: PlayerPawn = $Player
@onready var rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var hud: RogueHUD = $HUD

const CAMERA_PITCH: float = -38.0
const CAMERA_YAW: float = 32.0
const ZOOM_MIN: float = 5.0
const ZOOM_MAX: float = 16.0
const ORBIT_SPEED: float = 0.35      # degrees per pixel dragged
const PITCH_MIN: float = -85.0
const PITCH_MAX: float = -12.0

var _zoom: float = 9.0
var _shake: float = 0.0
var _yaw: float = CAMERA_YAW
var _pitch: float = CAMERA_PITCH
var _dragging: bool = false

func _ready() -> void:
	_build_environment()
	RoomCube.set_far_opacity(GameManager.far_opacity)
	GameManager.settings_changed.connect(_on_settings_changed)
	rig.rotation_degrees = Vector3(CAMERA_PITCH, CAMERA_YAW, 0.0)
	camera.position = Vector3(0, 0, _zoom)
	hud.bind(camera, player, grid)
	var gizmo := DirectionGizmo.new()
	gizmo.hud = hud
	player.add_child(gizmo)
	GameManager.level_started.connect(_on_level_started)
	hud.start_requested.connect(_start_run)
	player.bombed.connect(func(_c: Vector3i) -> void: _shake = 0.35)
	player.bumped.connect(func(_d: Vector3i) -> void: _shake = maxf(_shake, 0.08))
	grid.setup_level(1)   # maze shown behind the intro screen
	player.reset_to(grid.teleporter_pos)
	grid.update_focus(player.cell)

func _start_run() -> void:
	hud.hide_overlays()
	Sfx.play("click", 0.0)
	GameManager.new_run()

## Options sliders: new far materials alpha, then the near / far split again
## (the radius may have changed too).
func _on_settings_changed() -> void:
	RoomCube.set_far_opacity(GameManager.far_opacity)
	grid.update_focus(player.cell)

func _on_level_started(_level: int) -> void:
	grid.setup_level(GameManager.level)
	player.reset_to(grid.teleporter_pos)
	grid.update_focus(player.cell)
	rig.position = player.position

func _process(delta: float) -> void:
	# A button released over the HUD never reaches _unhandled_input
	if _dragging and Input.get_mouse_button_mask() == 0:
		_dragging = false
	rig.rotation_degrees = Vector3(_pitch, _yaw, 0.0)
	player.view_yaw = deg_to_rad(_yaw)
	rig.position = rig.position.lerp(player.position, 1.0 - exp(-8.0 * delta))
	camera.position.z = lerpf(camera.position.z, _zoom, 1.0 - exp(-10.0 * delta))
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 1.5, 0.0)
		var amp: float = _shake * _shake * 0.6
		var t: float = Time.get_ticks_msec() * 0.001
		camera.h_offset = sin(t * 53.0) * amp
		camera.v_offset = sin(t * 61.0 + 1.3) * amp
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(_zoom - 0.8, ZOOM_MIN)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(_zoom + 0.8, ZOOM_MAX)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = mb.pressed
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		_yaw -= motion.relative.x * ORBIT_SPEED
		_pitch = clampf(_pitch - motion.relative.y * ORBIT_SPEED, PITCH_MIN, PITCH_MAX)
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_R:
		_yaw = CAMERA_YAW + wrapf(_yaw - CAMERA_YAW, -180.0, 180.0)   # shortest way back
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "_yaw", CAMERA_YAW, 0.35)
		tw.tween_property(self, "_pitch", CAMERA_PITCH, 0.35)
	elif not GameManager.running and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		_start_run()

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.75)
	env.ambient_light_energy = 0.7
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.1)
	env.fog_density = 0.035
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 0.8
	add_child(sun)

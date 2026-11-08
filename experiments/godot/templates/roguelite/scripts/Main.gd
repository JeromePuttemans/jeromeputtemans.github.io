extends Node3D

# Main: 3D environment, camera, run flow.
#
# CAMERA: a rig node follows the player with exponential smoothing; the
#   camera sits on the rig's +Z axis, the rig being pitched and yawed. The
#   yaw keeps the three world axes visually distinct on screen (front/back,
#   left/right and up/down never overlap), which matters in a 3D grid.
#   Mouse wheel: zoom.
# FLOW: intro screen (a maze is already displayed behind it) -> new run ->
#   level_started regenerates the maze -> run_ended shows the end screen and
#   the upgrade shop -> Enter or the button starts a new run.

@onready var grid: GridManager = $GridManager
@onready var player: PlayerPawn = $Player
@onready var rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var hud: RogueHUD = $HUD

const CAMERA_PITCH: float = -38.0
const CAMERA_YAW: float = 32.0
const ZOOM_MIN: float = 5.0
const ZOOM_MAX: float = 16.0

var _zoom: float = 9.0
var _shake: float = 0.0

func _ready() -> void:
	_build_environment()
	rig.rotation_degrees = Vector3(CAMERA_PITCH, CAMERA_YAW, 0.0)
	camera.position = Vector3(0, 0, _zoom)
	hud.bind(camera, player, grid)
	GameManager.level_started.connect(_on_level_started)
	hud.start_requested.connect(_start_run)
	player.bombed.connect(func(_c: Vector3i) -> void: _shake = 0.35)
	player.bumped.connect(func(_d: Vector3i) -> void: _shake = maxf(_shake, 0.08))
	grid.setup_level(1)   # maze shown behind the intro screen
	player.reset_to(grid.teleporter_pos)

func _start_run() -> void:
	hud.hide_overlays()
	Sfx.play("click", 0.0)
	GameManager.new_run()

func _on_level_started(_level: int) -> void:
	grid.setup_level(GameManager.level)
	player.reset_to(grid.teleporter_pos)
	rig.position = player.position

func _process(delta: float) -> void:
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
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(_zoom - 0.8, ZOOM_MIN)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(_zoom + 0.8, ZOOM_MAX)
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and not GameManager.running:
		if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
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

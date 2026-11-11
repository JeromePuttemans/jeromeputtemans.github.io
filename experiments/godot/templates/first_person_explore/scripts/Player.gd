# =============================================================================
# Player.gd — First-person body (CharacterBody3D)
# =============================================================================
# CAPSULE: 0.35 m radius, 1.75 m tall. Collision mask: layer 1 (islands,
#   stones, props) and layer 2 (shadows), the latter dropped while the feet
#   are inside a cloud's shade.
# MOVE: the horizontal velocity moves towards (stick x speed) with
#   ground_accel, or slows with ground_decel when the stick is released;
#   in the air, air_accel / air_decel keep control light. walk_speed, or
#   sprint_speed with the run key.
# JUMP: jump_velocity upwards, gravity, stronger (fall_gravity_mult) once
#   falling; releasing the key early cuts the rise (jump_cut). A jump is
#   still allowed coyote_time after leaving a ledge, and a press is
#   remembered jump_buffer before landing. With the default values: 1.4 m
#   high, about 3.5 m long walking and 5 m running.
# SHADOWS: standing on a shadow when the sun moves, the body is carried
#   with it (ShadowSystem.carry), unless an island lies under the feet too;
#   the shadow shapes are rebuilt first.
# SIGNALS: steps (every step_length metres on the ground, with the surface
#   under the feet: grass, stone or shadow), jumps, landings with their
#   impact speed, and fell_out once below the void depth.
# =============================================================================

class_name Player
extends CharacterBody3D

signal jumped()
signal landed(impact: float, surface: String)
signal stepped(surface: String)
signal fell_out()

var rig: Node3D = null
var shadows: ShadowSystem = null
var sun: Sun = null
var void_y: float = -16.0
var ground_at: Callable                # island under some feet, "" over the void
var control_enabled: bool = false
var floor_surface: String = ""
var floor_island: String = ""
var floor_caster: int = -1
var step_phase: float = 0.0
var horizontal_speed: float = 0.0
var sprinting: bool = false
var strafe: float = 0.0

var _walk: float = 5.0
var _sprint: float = 7.5
var _ground_accel: float = 45.0
var _ground_decel: float = 55.0
var _air_accel: float = 14.0
var _air_decel: float = 3.0
var _gravity: float = 22.0
var _fall_mult: float = 1.25
var _jump_velocity: float = 7.8
var _jump_cut: float = 0.5
var _coyote_time: float = 0.12
var _buffer_time: float = 0.12
var _max_fall: float = 40.0
var _step_length: float = 2.1

var _coyote: float = 0.0
var _buffer: float = 0.0
var _jump_prev: bool = false
var _rising: bool = false
var _was_on_floor: bool = true
var _air_speed: float = 0.0
var _step_distance: float = 0.0
var _sun_prev := Vector3.UP
var _out: bool = false

func _ready() -> void:
	_walk = ConfigManager.get_float("walk_speed", 5.0)
	_sprint = ConfigManager.get_float("sprint_speed", 7.5)
	_ground_accel = ConfigManager.get_float("ground_accel", 45.0)
	_ground_decel = ConfigManager.get_float("ground_decel", 55.0)
	_air_accel = ConfigManager.get_float("air_accel", 14.0)
	_air_decel = ConfigManager.get_float("air_decel", 3.0)
	_gravity = ConfigManager.get_float("gravity", 22.0)
	_fall_mult = ConfigManager.get_float("fall_gravity_mult", 1.25)
	_jump_velocity = ConfigManager.get_float("jump_velocity", 7.8)
	_jump_cut = ConfigManager.get_float("jump_cut", 0.5)
	_coyote_time = ConfigManager.get_float("coyote_time", 0.12)
	_buffer_time = ConfigManager.get_float("jump_buffer", 0.12)
	_max_fall = ConfigManager.get_float("max_fall_speed", 40.0)
	_step_length = ConfigManager.get_float("step_length", 2.1)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	var col := CollisionShape3D.new()
	col.shape = capsule
	col.position.y = 0.875
	add_child(col)
	collision_layer = 0
	set_collision_layer_value(3, true)
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(ShadowSystem.SHADOW_LAYER, true)
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true

func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_out = false
	_was_on_floor = true
	_sun_prev = sun.direction() if sun != null else Vector3.UP
	reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	if shadows == null:
		return
	set_collision_mask_value(ShadowSystem.SHADOW_LAYER, not shadows.is_clouded(global_position))
	var sun_dir: Vector3 = sun.direction()
	var over_island: bool = ground_at.is_valid() and str(ground_at.call(global_position)) != ""
	if floor_caster >= 0 and not over_island and not sun_dir.is_equal_approx(_sun_prev):
		var shift: Vector3 = shadows.carry(global_position, floor_caster, _sun_prev, sun_dir)
		if shift.length() < 4.0:
			global_position += shift
	_sun_prev = sun_dir
	shadows.set_sun(sun_dir)
	shadows.rebuild_if_needed()
	var input := Vector2.ZERO
	var jump_down: bool = false
	var run_down: bool = false
	if control_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		jump_down = Input.is_action_pressed("jump")
		run_down = Input.is_action_pressed("sprint")
	strafe = input.x
	var yaw: float = rig.rotation.y if rig != null else rotation.y
	var wish: Vector3 = Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	var moving: bool = input.length() > 0.1
	sprinting = run_down and moving and input.y < 0.3
	var target_speed: float = _sprint if sprinting else _walk
	var on_floor: bool = is_on_floor()
	var accel: float
	if on_floor:
		accel = _ground_accel if moving else _ground_decel
	else:
		accel = _air_accel if moving else _air_decel
	var hv := Vector2(velocity.x, velocity.z).move_toward(Vector2(wish.x, wish.z) * target_speed, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.y
	if on_floor:
		_coyote = _coyote_time
	else:
		_coyote -= delta
	if jump_down and not _jump_prev:
		_buffer = _buffer_time
	else:
		_buffer -= delta
	_jump_prev = jump_down
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = _jump_velocity
		_buffer = 0.0
		_coyote = 0.0
		_rising = true
		on_floor = false
		jumped.emit()
	if not on_floor:
		velocity.y -= _gravity * (_fall_mult if velocity.y < 0.0 else 1.0) * delta
		if _rising and not jump_down and velocity.y > 0.0:
			velocity.y *= _jump_cut
			_rising = false
		if velocity.y <= 0.0:
			_rising = false
		velocity.y = maxf(velocity.y, -_max_fall)
		_air_speed = velocity.y
	elif velocity.y <= 0.0:
		velocity.y = -1.0    # keeps contact, so the floor is reported every frame
	move_and_slide()
	_read_floor()
	horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if is_on_floor():
		if not _was_on_floor:
			landed.emit(-_air_speed, floor_surface)
			_air_speed = 0.0
		if horizontal_speed > 0.4:
			_step_distance += horizontal_speed * delta
			step_phase += horizontal_speed * delta / _step_length * PI
			if _step_distance >= _step_length:
				_step_distance -= _step_length
				stepped.emit(floor_surface)
		else:
			_step_distance = _step_length * 0.6
	_was_on_floor = is_on_floor()
	if not _out and global_position.y < void_y:
		_out = true
		fell_out.emit()

## Surface under the feet: an island wins over a shadow lying on it.
func _read_floor() -> void:
	floor_surface = ""
	floor_island = ""
	floor_caster = -1
	if not is_on_floor():
		return
	var shadow_index: int = -1
	for i in get_slide_collision_count():
		var hit: KinematicCollision3D = get_slide_collision(i)
		if hit.get_normal().dot(Vector3.UP) < 0.6:
			continue
		var collider: Object = hit.get_collider()
		if collider == null:
			continue
		var surface: String = str(collider.get_meta("surface", "stone"))
		if surface == "shadow":
			shadow_index = int(collider.get_meta("caster", -1))
			if floor_surface == "":
				floor_surface = "shadow"
		else:
			floor_surface = surface
			floor_island = str(collider.get_meta("island", ""))
	if floor_surface == "shadow":
		floor_caster = shadow_index

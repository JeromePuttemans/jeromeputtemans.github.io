# =============================================================================
# Player.gd — Brindille: movement, jumps and game feel
# =============================================================================
# The player is a plain Node2D, its position is the bottom centre of a
# 24 x 32 px box. Level.step() calls step() once per physics tick (60 Hz) and
# the box is moved against the tile grid by Level.sweep_x / sweep_y, axis by
# axis: no physics engine, the same inputs always give the same result.
#
# MOVEMENT (values in data/config.json)
#   Running   velocity.x moves toward input x run_speed with an acceleration
#             that depends on the situation: ground_accel, turn_accel when
#             reversing, ground_decel without input, air_accel / air_decel.
#   Jump      velocity.y = -jump_velocity. Releasing the button while rising
#             multiplies velocity.y by jump_cut once: tap for a hop, hold
#             for the full height.
#   Gravity   x fall_gravity_multiplier when falling (snappy arcs), x
#             apex_gravity_multiplier near the top while the button is held
#             (a short hang time to aim the landing), capped at
#             max_fall_speed, or fast_fall_speed when holding down.
#   Coyote    the ground jump stays available coyote_time s after leaving a
#             ledge.
#   Buffer    a jump pressed jump_buffer_time s too early fires on landing.
#   Corners   hitting a ceiling corner by up to corner_correction px while
#             rising nudges the box sideways instead of stopping the jump.
#   Walls     pressing toward a wall in the air slides down at
#             wall_slide_speed; jumping pushes away (wall_jump_velocity_x)
#             and briefly reduces the control toward the wall (wall_jump_lock).
#   Air jump  air_jumps extra jumps, refilled on the ground, on walls, by
#             springs and by stomping an enemy.
#   Planks    down + jump drops through a plank (one-way platform).
# =============================================================================

class_name Player
extends Node2D

signal jumped(kind: String)
signal landed(impact: float)

const SIZE := Vector2(24.0, 32.0)

var level: Level = null
var velocity := Vector2.ZERO
var facing: int = 1
var grounded: bool = false
var dead: bool = false
var frozen: bool = false
var platform: MovingPlatform = null
var prev_bottom: float = 0.0
var air_jumps_left: int = 0
var wall_dir: int = 0
var sliding: bool = false

var _run_speed: float
var _ground_accel: float
var _ground_decel: float
var _turn_accel: float
var _air_accel: float
var _air_decel: float
var _gravity: float
var _fall_mult: float
var _apex_mult: float
var _apex_threshold: float
var _max_fall: float
var _fast_fall: float
var _fast_fall_mult: float
var _jump_velocity: float
var _jump_cut: float
var _air_jumps: int
var _air_jump_velocity: float
var _coyote_time: float
var _buffer_time: float
var _corner: int
var _slide_speed: float
var _wall_jump_x: float
var _wall_jump_y: float
var _wall_lock_time: float
var _wall_coyote_time: float
var _drop_time: float

var _coyote: float = 0.0
var _buffer: float = 0.0
var _wall_coyote: float = 0.0
var _wall_coyote_dir: int = 0
var _wall_lock: float = 0.0
var _drop_timer: float = 0.0
var _can_cut: bool = false
var _jump_was_held: bool = false

# Visual state, updated every rendered frame
var _scale := Vector2.ONE
var _scale_velocity := Vector2.ZERO
var _spin: float = 0.0
var _run_phase: float = 0.0
var _blink: float = 0.0
var _blink_timer: float = 2.5
var _leaf: float = 0.0
var _appear: float = 1.0
var _slide_dust: float = 0.0
var _step_dust: float = 0.0
var _exit_target := Vector2.ZERO
var _exit_t: float = -1.0

func _ready() -> void:
	_run_speed = ConfigManager.get_float("run_speed", 300.0)
	_ground_accel = ConfigManager.get_float("ground_accel", 2600.0)
	_ground_decel = ConfigManager.get_float("ground_decel", 3000.0)
	_turn_accel = ConfigManager.get_float("turn_accel", 4200.0)
	_air_accel = ConfigManager.get_float("air_accel", 1900.0)
	_air_decel = ConfigManager.get_float("air_decel", 800.0)
	_gravity = ConfigManager.get_float("gravity", 2220.0)
	_fall_mult = ConfigManager.get_float("fall_gravity_multiplier", 1.65)
	_apex_mult = ConfigManager.get_float("apex_gravity_multiplier", 0.5)
	_apex_threshold = ConfigManager.get_float("apex_threshold", 90.0)
	_max_fall = ConfigManager.get_float("max_fall_speed", 860.0)
	_fast_fall = ConfigManager.get_float("fast_fall_speed", 1150.0)
	_fast_fall_mult = ConfigManager.get_float("fast_fall_multiplier", 1.4)
	_jump_velocity = ConfigManager.get_float("jump_velocity", 800.0)
	_jump_cut = ConfigManager.get_float("jump_cut", 0.45)
	_air_jumps = ConfigManager.get_int("air_jumps", 1)
	_air_jump_velocity = ConfigManager.get_float("air_jump_velocity", 700.0)
	_coyote_time = ConfigManager.get_float("coyote_time", 0.1)
	_buffer_time = ConfigManager.get_float("jump_buffer_time", 0.12)
	_corner = ConfigManager.get_int("corner_correction", 12)
	_slide_speed = ConfigManager.get_float("wall_slide_speed", 150.0)
	_wall_jump_x = ConfigManager.get_float("wall_jump_velocity_x", 330.0)
	_wall_jump_y = ConfigManager.get_float("wall_jump_velocity_y", 760.0)
	_wall_lock_time = ConfigManager.get_float("wall_jump_lock", 0.16)
	_wall_coyote_time = ConfigManager.get_float("wall_coyote_time", 0.08)
	_drop_time = ConfigManager.get_float("drop_through_time", 0.22)
	air_jumps_left = _air_jumps
	# A button still held from the menu must not jump on the first frame
	_jump_was_held = Input.is_action_pressed("jump")

func box() -> Rect2:
	return Rect2(position.x - SIZE.x * 0.5, position.y - SIZE.y, SIZE.x, SIZE.y)

## Slightly smaller than the collision box: hazards forgive a few pixels.
func hurt_box() -> Rect2:
	return box().grow(-4.0)

func center() -> Vector2:
	return position - Vector2(0.0, SIZE.y * 0.5)

# =============================================================================
# SIMULATION (one physics tick)
# =============================================================================

func step(delta: float) -> void:
	# The press is detected as an edge of the held state in this tick: same
	# result for keyboard, pad or injected input, frame for frame.
	var jump_held: bool = Input.is_action_pressed("jump")
	var jump_pressed: bool = jump_held and not _jump_was_held
	_jump_was_held = jump_held
	if dead or frozen:
		return
	var input_x: float = Input.get_axis("move_left", "move_right")
	input_x = signf(input_x) if absf(input_x) > 0.3 else 0.0
	var down: bool = Input.is_action_pressed("move_down")
	if jump_pressed:
		_buffer = _buffer_time
	else:
		_buffer -= delta
	_coyote -= delta
	_wall_coyote -= delta
	_wall_lock -= delta
	_drop_timer -= delta
	_horizontal(input_x, delta)
	_jumps(input_x, down)
	_apply_gravity(input_x, down, jump_held, delta)
	_move(delta)
	_after_move(input_x)

func _horizontal(input_x: float, delta: float) -> void:
	var accel: float
	if grounded:
		if input_x == 0.0:
			accel = _ground_decel
		elif velocity.x != 0.0 and signf(input_x) != signf(velocity.x):
			accel = _turn_accel
		else:
			accel = _ground_accel
	else:
		accel = _air_accel if input_x != 0.0 else _air_decel
		if _wall_lock > 0.0:
			accel *= 0.25
		# Keep the extra speed of a launch when still pushing the same way
		if absf(velocity.x) > _run_speed and signf(velocity.x) == signf(input_x):
			accel = _air_decel * 0.5
	velocity.x = move_toward(velocity.x, input_x * _run_speed, accel * delta)
	if input_x != 0.0 and _wall_lock <= 0.0:
		facing = int(input_x)

func _jumps(input_x: float, down: bool) -> void:
	if _buffer <= 0.0:
		return
	if grounded or _coyote > 0.0:
		if down and grounded and _on_droppable():
			_drop_timer = _drop_time
			_buffer = 0.0
			_coyote = 0.0
			grounded = false
			platform = null
			return
		_jump(_jump_velocity, "ground")
		return
	if wall_dir != 0 or _wall_coyote > 0.0:
		var dir: int = wall_dir if wall_dir != 0 else _wall_coyote_dir
		velocity.x = -dir * _wall_jump_x
		facing = -dir
		_wall_lock = _wall_lock_time
		air_jumps_left = _air_jumps
		_jump(_wall_jump_y, "wall")
		return
	if air_jumps_left > 0:
		air_jumps_left -= 1
		if input_x != 0.0 and signf(input_x) != signf(velocity.x):
			velocity.x = input_x * _run_speed * 0.85
		_spin = -TAU * facing
		_jump(_air_jump_velocity, "air")

func _jump(speed: float, kind: String) -> void:
	velocity.y = -speed
	if platform != null:
		velocity.x += platform.velocity.x * 0.5
		velocity.y += minf(platform.velocity.y, 0.0)
	grounded = false
	platform = null
	_coyote = 0.0
	_wall_coyote = 0.0
	_buffer = 0.0
	_can_cut = true
	_set_squash(Vector2(0.7, 1.32))
	jumped.emit(kind)

func _apply_gravity(input_x: float, down: bool, jump_held: bool, delta: float) -> void:
	if not jump_held and _can_cut and velocity.y < 0.0:
		velocity.y *= _jump_cut
		_can_cut = false
	if velocity.y >= 0.0:
		_can_cut = false
	var g: float = _gravity
	var max_fall: float = _max_fall
	sliding = not grounded and wall_dir != 0 and input_x == float(wall_dir) and velocity.y > 0.0
	if not grounded and jump_held and absf(velocity.y) < _apex_threshold:
		g *= _apex_mult
	elif velocity.y > 0.0:
		g *= _fall_mult
	if down and velocity.y > 0.0 and not sliding:
		g *= _fast_fall_mult
		max_fall = _fast_fall
	if sliding:
		max_fall = _slide_speed
	velocity.y += g * delta
	if velocity.y > max_fall:
		velocity.y = move_toward(velocity.y, max_fall, 5000.0 * delta) if sliding else max_fall

func _move(delta: float) -> void:
	prev_bottom = position.y
	var b: Rect2 = box()
	var dx: float = velocity.x * delta
	var moved_x: float = level.sweep_x(b, dx)
	position.x += moved_x
	if absf(moved_x - dx) > 0.001:
		velocity.x = 0.0
	b = box()
	var dy: float = velocity.y * delta
	var ignore_oneway: bool = _drop_timer > 0.0
	var result: Dictionary = level.sweep_y(b, dy, ignore_oneway)
	if dy < 0.0 and bool(result["hit"]):
		result = _corner_correct(b, dy, result)
	position.y += float(result["dy"])
	var was_grounded: bool = grounded
	grounded = false
	platform = null
	if not bool(result["hit"]):
		return
	if dy > 0.0:
		grounded = true
		platform = result.get("platform") as MovingPlatform
		if not was_grounded:
			_on_land(velocity.y)
		velocity.y = 0.0
	else:
		velocity.y = 0.0
		_can_cut = false
		_set_squash(Vector2(1.15, 0.88))

## Rising into a ceiling corner: slide sideways up to _corner px if that frees
## the way, trying the facing side first.
func _corner_correct(b: Rect2, dy: float, result: Dictionary) -> Dictionary:
	for k in range(1, _corner + 1):
		for s in [facing, -facing]:
			var shifted: Rect2 = b
			shifted.position.x += float(s * k)
			if level.box_hits_solid(shifted):
				continue
			var test: Dictionary = level.sweep_y(shifted, dy, true)
			if not bool(test["hit"]):
				position.x += float(s * k)
				return test
	return result

func _after_move(_input_x: float) -> void:
	if grounded:
		_coyote = _coyote_time
		air_jumps_left = _air_jumps
		_wall_lock = 0.0
	wall_dir = 0
	if not grounded:
		var b: Rect2 = box()
		if level.touches_wall(b, 1):
			wall_dir = 1
		elif level.touches_wall(b, -1):
			wall_dir = -1
	if wall_dir != 0:
		_wall_coyote = _wall_coyote_time
		_wall_coyote_dir = wall_dir

func _on_droppable() -> bool:
	if platform != null:
		return true
	return level.standing_on_oneway(box())

func _on_land(impact: float) -> void:
	var strength: float = clampf(impact / _max_fall, 0.0, 1.0)
	_set_squash(Vector2(1.0 + 0.4 * strength, 1.0 - 0.35 * strength))
	_spin = 0.0
	landed.emit(impact)

# =============================================================================
# EXTERNAL EVENTS
# =============================================================================

## Springs and stomps. cut_allowed lets a released button shorten the bounce.
func bounce(speed: float, cut_allowed: bool) -> void:
	velocity.y = -speed
	grounded = false
	platform = null
	_coyote = 0.0
	_can_cut = cut_allowed
	air_jumps_left = _air_jumps
	_set_squash(Vector2(0.68, 1.36))

func die() -> void:
	dead = true
	velocity = Vector2.ZERO
	queue_redraw()

func respawn(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	dead = false
	frozen = false
	grounded = false
	platform = null
	air_jumps_left = _air_jumps
	_buffer = 0.0
	_coyote = 0.0
	_spin = 0.0
	_appear = 0.0
	_scale = Vector2.ONE
	reset_physics_interpolation()

## Exit reached: the drawing slides into the arch and fades out.
func enter_exit(target: Vector2) -> void:
	frozen = true
	velocity = Vector2.ZERO
	_exit_target = target
	_exit_t = 0.0

func is_jump_held() -> bool:
	return Input.is_action_pressed("jump")

func _set_squash(target: Vector2) -> void:
	_scale = target
	_scale_velocity = Vector2.ZERO

# =============================================================================
# ANIMATION AND DRAWING (every rendered frame)
# =============================================================================

func _process(delta: float) -> void:
	# Damped spring back to scale 1: slight overshoot reads as elasticity
	var force: Vector2 = (Vector2.ONE - _scale) * 420.0 - _scale_velocity * 20.0
	_scale_velocity += force * delta
	_scale += _scale_velocity * delta
	_spin = move_toward(_spin, 0.0, TAU * 3.2 * delta)
	_appear = minf(_appear + delta * 4.0, 1.0)
	if _exit_t >= 0.0:
		_exit_t = minf(_exit_t + delta * 1.4, 1.0)
	if grounded and absf(velocity.x) > 20.0:
		_run_phase += delta * absf(velocity.x) * 0.055
	else:
		_run_phase = lerpf(_run_phase, roundf(_run_phase / PI) * PI, minf(delta * 10.0, 1.0))
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = randf_range(2.0, 4.5)
		_blink = 1.0
	_blink = maxf(_blink - delta * 7.0, 0.0)
	var leaf_target: float = clampf(-velocity.x * 0.0016 + velocity.y * 0.0006 * facing, -0.9, 0.9)
	_leaf = lerpf(_leaf, leaf_target, minf(delta * 9.0, 1.0)) + sin(Time.get_ticks_msec() * 0.004) * 0.004
	_emit_dust(delta)
	queue_redraw()

func _emit_dust(delta: float) -> void:
	if level == null or dead or frozen:
		return
	if sliding:
		_slide_dust -= delta
		if _slide_dust <= 0.0:
			_slide_dust = 0.06
			level.effects.dust(position + Vector2(wall_dir * SIZE.x * 0.5, -SIZE.y * 0.6), 1, Vector2(-wall_dir * 30.0, -20.0))
	if grounded and absf(velocity.x) > _run_speed * 0.6:
		_step_dust -= delta
		if _step_dust <= 0.0:
			_step_dust = 0.13
			level.effects.dust(position + Vector2(-signf(velocity.x) * 8.0, -2.0), 1, Vector2(-velocity.x * 0.15, -25.0))

func _draw() -> void:
	if dead:
		return
	var pose: Dictionary = PlayerArt.default_pose()
	var s: Vector2 = _scale
	if sliding:
		s = Vector2(s.x * 0.86, s.y * 1.06)
	var appear: float = ease(_appear, 0.4)
	pose["scale"] = s * (0.2 + 0.8 * appear)
	pose["angle"] = clampf(velocity.x / _run_speed, -1.2, 1.2) * 0.07 + _spin
	pose["facing"] = -wall_dir if sliding else facing
	pose["look"] = Vector2(clampf(velocity.x / _run_speed, -1.0, 1.0) * 1.4, clampf(velocity.y / 700.0, -1.0, 1.0) * 1.6)
	pose["blink"] = _blink
	pose["run"] = _run_phase
	pose["air"] = not grounded
	pose["leaf"] = _leaf
	pose["alpha"] = appear
	var offset := Vector2(wall_dir * 2.0, 0.0) if sliding else Vector2.ZERO
	if _exit_t >= 0.0:
		var k: float = ease(_exit_t, 0.6)
		offset = (_exit_target - position) * k
		pose["scale"] = (pose["scale"] as Vector2) * (1.0 - 0.7 * k)
		pose["alpha"] = 1.0 - k
		pose["angle"] = k * TAU * 0.5
	PlayerArt.draw(self, offset, pose)

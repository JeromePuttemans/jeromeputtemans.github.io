# =============================================================================
# Player.gd: First-person body (CharacterBody3D)
# =============================================================================
# CAPSULE: 0.35 m radius, 1.75 m tall. Collision mask: layer 1 (platforms,
#   stones, architecture) and layer 2 (shadows), the latter dropped while
#   the feet are inside a cloud's shade.
# MOVE: the horizontal velocity moves towards (stick x speed) with
#   ground_accel, or slows with ground_decel when the stick is released.
#   walk_speed, or sprint_speed while the dash key is held. In the air,
#   a speed above the run speed is kept (air_drag slowly wears it down)
#   and only its direction is steered: dashes and launches carry.
# JUMP: jump_velocity upwards, gravity, stronger (fall_gravity_mult) once
#   falling; releasing the key early cuts the rise (jump_cut). A jump is
#   still allowed coyote_time after leaving a ledge, and a press is
#   remembered jump_buffer before landing.
# DASH: a press of the dash key throws the body flat at dash_speed for
#   dash_time, in the stick direction (or the view direction), on the
#   ground or in the air; gravity is suspended meanwhile. One charge,
#   given back on touching any floor (after dash_cooldown) or by a shard.
# LEDGE GRAB: in the air, moving towards a ledge whose top lies between
#   0.3 m and mantle_reach above the feet, with room to stand on it, the
#   body climbs onto it in mantle_time. Thin shadows can be grabbed too.
#   The grab does not wait for the top of the jump: waiting let the head
#   bump under a hanging shadow before its edge came within reach.
# SHADOWS: standing on a shadow that moves (sun or kinetic stone), the
#   body is carried with it (ShadowSystem.carry), unless a platform lies
#   under the feet too. Jumping or stepping off keeps the shadow's speed
#   (up to carry_inherit_max): a launch.
# SIGNALS: steps (every step_length metres on the ground, with the surface
#   under the feet), jumps, dashes, ledge grabs, launches, landings with
#   their impact speed, and fell_out once below the void depth.
# =============================================================================

class_name Player
extends CharacterBody3D

signal jumped()
signal dashed()
signal dash_refilled()
signal mantled()
signal launched(speed: float)
signal landed(impact: float, surface: String)
signal stepped(surface: String)
signal fell_out()

const HEIGHT: float = 1.75
const RADIUS: float = 0.35

var rig: Node3D = null
var shadows: ShadowSystem = null
var sun: Sun = null
var void_y: float = -16.0
var ground_at: Callable                # platform under some feet, "" over the void
var control_enabled: bool = false
var floor_surface: String = ""
var floor_island: String = ""
var floor_caster: int = -1
var step_phase: float = 0.0
var horizontal_speed: float = 0.0
var sprinting: bool = false
var strafe: float = 0.0
var dash_ready: bool = true
var dashing: bool = false
var carry_velocity := Vector3.ZERO     # speed of the shadow under the feet
var bot_dash_press: bool = false       # test bot: one dash press next frame

var _walk: float = 6.5
var _sprint: float = 8.5
var _ground_accel: float = 55.0
var _ground_decel: float = 60.0
var _air_accel: float = 16.0
var _air_decel: float = 3.0
var _air_drag: float = 4.0
var _gravity: float = 22.0
var _fall_mult: float = 1.25
var _jump_velocity: float = 7.8
var _jump_cut: float = 0.5
var _coyote_time: float = 0.1
var _buffer_time: float = 0.12
var _max_fall: float = 40.0
var _step_length: float = 2.3
var _dash_speed: float = 16.0
var _dash_time: float = 0.14
var _dash_exit: float = 8.5
var _dash_cooldown: float = 0.25
var _mantle_reach: float = 1.1
var _mantle_time: float = 0.22
var _inherit_max: float = 12.0

var _coyote: float = 0.0
var _buffer: float = 0.0
var _jump_prev: bool = false
var _dash_prev: bool = false
var _rising: bool = false
var _was_on_floor: bool = true
var _air_speed: float = 0.0
var _step_distance: float = 0.0
var _sun_prev := Vector3.UP
var _out: bool = false
var _dash_left: float = 0.0
var _dash_dir := Vector3.ZERO
var _dash_wait: float = 0.0
var _mantle_left: float = 0.0
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_dir := Vector3.ZERO
var _mantle_caster: int = -1

func _ready() -> void:
	_walk = ConfigManager.get_float("walk_speed", 6.5)
	_sprint = ConfigManager.get_float("sprint_speed", 8.5)
	_ground_accel = ConfigManager.get_float("ground_accel", 55.0)
	_ground_decel = ConfigManager.get_float("ground_decel", 60.0)
	_air_accel = ConfigManager.get_float("air_accel", 16.0)
	_air_decel = ConfigManager.get_float("air_decel", 3.0)
	_air_drag = ConfigManager.get_float("air_drag", 4.0)
	_gravity = ConfigManager.get_float("gravity", 22.0)
	_fall_mult = ConfigManager.get_float("fall_gravity_mult", 1.25)
	_jump_velocity = ConfigManager.get_float("jump_velocity", 7.8)
	_jump_cut = ConfigManager.get_float("jump_cut", 0.5)
	_coyote_time = ConfigManager.get_float("coyote_time", 0.1)
	_buffer_time = ConfigManager.get_float("jump_buffer", 0.12)
	_max_fall = ConfigManager.get_float("max_fall_speed", 40.0)
	_step_length = ConfigManager.get_float("step_length", 2.3)
	_dash_speed = ConfigManager.get_float("dash_speed", 16.0)
	_dash_time = ConfigManager.get_float("dash_time", 0.14)
	_dash_exit = ConfigManager.get_float("dash_exit_speed", 8.5)
	_dash_cooldown = ConfigManager.get_float("dash_cooldown", 0.25)
	_mantle_reach = ConfigManager.get_float("mantle_reach", 1.1)
	_mantle_time = ConfigManager.get_float("mantle_time", 0.22)
	_inherit_max = ConfigManager.get_float("carry_inherit_max", 12.0)
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	var col := CollisionShape3D.new()
	col.shape = capsule
	col.position.y = HEIGHT * 0.5
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
	carry_velocity = Vector3.ZERO
	_out = false
	_was_on_floor = true
	_dash_left = 0.0
	_mantle_left = 0.0
	dashing = false
	dash_ready = true
	_sun_prev = sun.direction() if sun != null else Vector3.UP
	reset_physics_interpolation()

## A shard gives the dash back at once, even in mid-air.
func refill_dash() -> void:
	if not dash_ready:
		dash_ready = true
		_dash_wait = 0.0
		dash_refilled.emit()

func is_mantling() -> bool:
	return _mantle_left > 0.0

func _physics_process(delta: float) -> void:
	if shadows == null:
		return
	set_collision_mask_value(ShadowSystem.SHADOW_LAYER, not shadows.is_clouded(global_position))
	if _mantle_left > 0.0:
		_step_mantle(delta)
		return
	_carry(delta)
	var input := Vector2.ZERO
	var jump_down: bool = false
	var dash_down: bool = false
	if control_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		jump_down = Input.is_action_pressed("jump")
		dash_down = Input.is_action_pressed("dash") or bot_dash_press
	bot_dash_press = false
	var dash_pressed: bool = dash_down and not _dash_prev
	_dash_prev = dash_down
	strafe = input.x
	var yaw: float = rig.rotation.y if rig != null else rotation.y
	var wish: Vector3 = Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	var moving: bool = input.length() > 0.1
	sprinting = dash_down and moving and input.y < 0.3
	var target_speed: float = _sprint if sprinting else _walk
	var on_floor: bool = is_on_floor()
	_dash_wait -= delta
	if on_floor and not dash_ready and _dash_wait <= 0.0 and not dashing:
		dash_ready = true
		dash_refilled.emit()
	if dash_pressed and dash_ready and control_enabled:
		_start_dash(wish if moving else Basis(Vector3.UP, yaw) * Vector3.FORWARD)
	var hv := Vector2(velocity.x, velocity.z)
	if dashing:
		_dash_left -= delta
		hv = Vector2(_dash_dir.x, _dash_dir.z) * _dash_speed
		velocity.y = 0.0
		if _dash_left <= 0.0:
			_end_dash()
			hv = hv.limit_length(_dash_exit)
	elif on_floor:
		hv = hv.move_toward(Vector2(wish.x, wish.z) * target_speed, (_ground_accel if moving else _ground_decel) * delta)
	else:
		hv = _air_steer(hv, Vector2(wish.x, wish.z), target_speed, moving, delta)
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
		if dashing:
			_end_dash()
			var limited := Vector2(velocity.x, velocity.z).limit_length(_dash_exit)
			velocity.x = limited.x
			velocity.z = limited.y
		velocity.y = _jump_velocity
		_buffer = 0.0
		_coyote = 0.0
		_rising = true
		on_floor = false
		_inherit()
		jumped.emit()
	if not on_floor and not dashing:
		velocity.y -= _gravity * (_fall_mult if velocity.y < 0.0 else 1.0) * delta
		if _rising and not jump_down and velocity.y > 0.0:
			velocity.y *= _jump_cut
			_rising = false
		if velocity.y <= 0.0:
			_rising = false
		velocity.y = maxf(velocity.y, -_max_fall)
		_air_speed = velocity.y
	elif on_floor and velocity.y <= 0.0:
		velocity.y = -1.0    # keeps contact, so the floor is reported every frame
	var caster_before: int = floor_caster
	move_and_slide()
	_read_floor()
	if caster_before >= 0 and not is_on_floor() and velocity.y <= 0.0:
		_inherit()          # stepped off a moving shadow: keep its speed
	if not is_on_floor() and control_enabled and moving:
		_try_mantle(wish.normalized())
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

## Air control: below the run speed, accelerate towards the stick; above
## it (after a dash or a launch), keep the speed, wear it down slowly and
## only turn it towards the stick.
func _air_steer(hv: Vector2, wish: Vector2, target_speed: float, moving: bool, delta: float) -> Vector2:
	var speed: float = hv.length()
	if speed > target_speed + 0.05:
		var dir: Vector2 = hv / speed
		speed = maxf(speed - _air_drag * delta, target_speed)
		if moving:
			var turn: float = clampf(_air_accel * delta / maxf(speed, 1.0), 0.0, 1.0)
			dir = dir.lerp(wish.normalized(), turn).normalized()
			if wish.dot(dir) < -0.3:
				speed = maxf(speed - _air_accel * delta, target_speed)
		return dir * speed
	return hv.move_toward(wish * target_speed, (_air_accel if moving else _air_decel) * delta)

func _start_dash(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	_dash_dir = dir.normalized()
	_dash_left = _dash_time
	dashing = true
	dash_ready = false
	_dash_wait = _dash_cooldown
	_rising = false
	velocity.y = 0.0
	dashed.emit()

func _end_dash() -> void:
	dashing = false
	_dash_left = 0.0

## Moving shadow under the feet: follow it, and remember its speed.
func _carry(delta: float) -> void:
	var sun_dir: Vector3 = sun.direction()
	var over_island: bool = ground_at.is_valid() and str(ground_at.call(global_position)) != ""
	var shift := Vector3.ZERO
	if floor_caster >= 0 and not over_island and (not sun_dir.is_equal_approx(_sun_prev) or shadows.moved(floor_caster)):
		shift = shadows.carry(global_position, floor_caster, _sun_prev, sun_dir)
		if shift.length() < 4.0:
			global_position += shift
		else:
			shift = Vector3.ZERO
	var measured: Vector3 = shift / maxf(delta, 0.0001)
	carry_velocity = carry_velocity.lerp(measured, 0.5) if floor_caster >= 0 else carry_velocity.lerp(Vector3.ZERO, 0.2)
	_sun_prev = sun_dir
	shadows.set_sun(sun_dir)
	shadows.rebuild_if_needed()

## Adds the speed of the shadow just left (a launch).
func _inherit() -> void:
	var push: Vector3 = carry_velocity
	push.y = 0.0
	carry_velocity = Vector3.ZERO
	if push.length() < 1.0:
		return
	push = push.limit_length(_inherit_max)
	velocity.x += push.x
	velocity.z += push.z
	launched.emit(push.length())

## Looks for a ledge just ahead whose top is within reach, with room to
## stand on it and room to rise beside it.
func _try_mantle(dir: Vector3) -> void:
	if dir.length() < 0.5:
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var feet: Vector3 = global_position
	for dist in [0.55, 0.8]:
		var ahead: Vector3 = feet + dir * float(dist)
		var query := PhysicsRayQueryParameters3D.create(ahead + Vector3(0.0, _mantle_reach + 0.05, 0.0), ahead + Vector3(0.0, 0.3, 0.0), collision_mask)
		query.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		if (hit["normal"] as Vector3).y < 0.7:
			continue
		var collider: Object = hit["collider"]
		if collider != null and bool(collider.get_meta("no_mantle", false)):
			continue
		var top: Vector3 = hit["position"]
		# land well past the edge: 0.2 m past the probe left the round bottom
		# of the capsule on the edge, and the body slid back off the block
		var target := Vector3(ahead.x, top.y + 0.02, ahead.z) + dir * 0.45
		if not _fits(target) or not _fits(Vector3(feet.x, top.y + 0.05, feet.z)):
			continue
		_mantle_from = feet
		_mantle_to = target
		_mantle_dir = dir
		_mantle_caster = int(collider.get_meta("caster", -1)) if collider != null else -1
		_mantle_left = _mantle_time
		velocity = Vector3.ZERO
		_end_dash()
		mantled.emit()
		return

func _fits(feet: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS - 0.02
	capsule.height = HEIGHT - 0.04
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3(0.0, HEIGHT * 0.5 + 0.02, 0.0))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

## The climb: up beside the ledge first, then forward onto it.
func _step_mantle(delta: float) -> void:
	_mantle_left -= delta
	var sun_dir: Vector3 = sun.direction()
	if _mantle_caster >= 0:
		# the ledge is a moving shadow: the climb follows it
		var shift: Vector3 = shadows.carry(_mantle_to, _mantle_caster, _sun_prev, sun_dir)
		if shift.length() < 4.0:
			_mantle_to += shift
			_mantle_from += shift
	_sun_prev = sun_dir
	shadows.set_sun(sun_dir)
	shadows.rebuild_if_needed()
	var t: float = clampf(1.0 - _mantle_left / _mantle_time, 0.0, 1.0)
	var up: float = smoothstep(0.0, 0.55, t)
	var forward: float = smoothstep(0.45, 1.0, t)
	var p: Vector3 = _mantle_from
	p.y = lerpf(_mantle_from.y, _mantle_to.y, up)
	p.x = lerpf(_mantle_from.x, _mantle_to.x, forward)
	p.z = lerpf(_mantle_from.z, _mantle_to.z, forward)
	global_position = p
	horizontal_speed = 0.0
	if _mantle_left <= 0.0:
		global_position = _mantle_to
		velocity = _mantle_dir * _walk * 0.8
		velocity.y = -1.0
		_was_on_floor = true
		_air_speed = 0.0
		_sun_prev = sun.direction()
		dash_ready = true

## Surface under the feet: a platform wins over a shadow lying on it.
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

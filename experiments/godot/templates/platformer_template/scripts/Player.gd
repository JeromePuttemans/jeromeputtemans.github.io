# =============================================================================
# Player.gd — CharacterBody2D: movement, variable-height jump, stomp logic.
# =============================================================================
# All runtime values are loaded from ConfigManager in _ready().
# Variable declarations use 0.0 so the JSON is the single source of truth.
#
# JUMP SYSTEM:
#   1. Variable-height jump  — releasing early multiplies velocity.y by
#      (1 / short_hop_multiplier), truncating the arc.
#   2. Coyote time           — jump stays available for coyote_time seconds
#      after walking off a ledge.
#   3. Jump buffer           — a jump pressed up to jump_buffer_time seconds
#      before landing is stored and fires on the first grounded frame.
#
# ENEMY INTERACTION:
#   collision normal.y < -0.65 while falling → stomp (enemy dies, player bounces)
#   any other enemy contact                  → GameState.player_die()
# =============================================================================

class_name Player
extends CharacterBody2D

const SIZE := Vector2(28, 44)

const LAYER_PLAYER  = 2
const LAYER_ENEMIES = 4

# All set to 0.0 — real values loaded from config.json in _ready()
var _speed:       float = 0.0
var _gravity:     float = 0.0
var _jump_vel:    float = 0.0
var _fall_mult:   float = 0.0
var _sh_mult:     float = 0.0
var _bounce_vel:  float = 0.0
var _coyote_time: float = 0.0
var _buffer_time: float = 0.0

# Runtime timers (always start at 0)
var _coyote_timer: float = 0.0
var _buffer_timer: float = 0.0

var start_position: Vector2 = Vector2.ZERO
var camera: Camera2D = null

var _facing: int  = 1
var _dead:   bool = false

func _ready() -> void:
	# Single source of truth: config.json
	# Fallback is 0.0 so a missing key causes visible inactivity, not silent wrong values
	_speed       = ConfigManager.get_float("player_speed",           0.0)
	_gravity     = ConfigManager.get_float("gravity",                0.0)
	_jump_vel    = ConfigManager.get_float("jump_velocity",          0.0)
	_fall_mult   = ConfigManager.get_float("fall_gravity_multiplier",0.0)
	_sh_mult     = ConfigManager.get_float("short_hop_multiplier",   0.0)
	_bounce_vel  = ConfigManager.get_float("bounce_velocity",        0.0)
	_coyote_time = ConfigManager.get_float("coyote_time",            0.0)
	_buffer_time = ConfigManager.get_float("jump_buffer_time",       0.0)

	collision_layer = LAYER_PLAYER
	collision_mask  = 1 | LAYER_ENEMIES

	var shape  = RectangleShape2D.new()
	shape.size = SIZE
	var coll   = CollisionShape2D.new()
	coll.shape = shape
	add_child(coll)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed   = ConfigManager.get_float("camera_smoothing", 0.0)
	camera.drag_horizontal_enabled    = false
	camera.drag_vertical_enabled      = false
	add_child(camera)
	camera.make_current()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_apply_gravity(delta)
	_handle_coyote(delta)
	_handle_jump_buffer(delta)
	_handle_jump_input()
	_handle_horizontal()
	move_and_slide()
	_check_enemy_collisions()

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var mult = _fall_mult if velocity.y > 0.0 else 1.0
	velocity.y += _gravity * mult * delta

func _handle_coyote(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = _coyote_time
	else:
		_coyote_timer -= delta

func _handle_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		_buffer_timer = _buffer_time
	else:
		_buffer_timer -= delta

func _handle_jump_input() -> void:
	if _buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y    = _jump_vel
		_coyote_timer = 0.0
		_buffer_timer = 0.0
		return
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= (1.0 / _sh_mult)

func _handle_horizontal() -> void:
	var dir = Input.get_axis("move_left", "move_right")
	velocity.x = dir * _speed
	if dir != 0.0:
		_facing = int(sign(dir))
	queue_redraw()

func _check_enemy_collisions() -> void:
	for i in get_slide_collision_count():
		var col  = get_slide_collision(i)
		var body = col.get_collider()
		if not (body is Enemy):
			continue
		if col.get_normal().y < -0.65 and velocity.y >= 0.0:
			body.die()
			velocity.y = _bounce_vel
			GameState.add_score(ConfigManager.get_int("enemy_kill_score", 0))
		else:
			_die()

func _die() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector2.ZERO
	GameState.player_die()

func respawn() -> void:
	_dead    = false
	velocity = Vector2.ZERO
	position = start_position
	queue_redraw()

func _draw() -> void:
	var color = Color(0.25, 0.55, 1.0) if not _dead else Color(0.6, 0.6, 0.6, 0.5)
	draw_rect(Rect2(-SIZE * 0.5, SIZE), color)
	var eye_y = -SIZE.y * 0.25
	var eye_x = _facing * SIZE.x * 0.2
	draw_circle(Vector2(eye_x, eye_y), 3.5, Color.WHITE)

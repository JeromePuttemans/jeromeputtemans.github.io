extends CharacterBody2D

class_name Player

# ── Signals ───────────────────────────────────────────────────────────────────
signal player_died

# ── Constants ─────────────────────────────────────────────────────────────────
const PLAYER_COLOR: Color = Color(0.0, 0.898, 1.0)          # #00e5ff cyan
const AURA_COLOR_BASE: Color = Color(0.0, 0.898, 1.0, 0.12) # semi-transparent cyan
const AURA_RINGS: int = 3
const TRIANGLE_SIZE: float = 18.0
const FIRE_INTERVAL: float = 0.15
const VIEWPORT_MARGIN: float = 20.0

# ── State ─────────────────────────────────────────────────────────────────────
var _speed: float = 220.0
var _gravity_radius: float = 180.0
var _bullet_speed: float = 400.0
var _fire_timer: float = 0.0
var _is_alive: bool = true
var _game_manager: Node = null
var _bullets_container: Node2D = null
var _bullet_script: Script = null

# ── Collision shape (created by code) ─────────────────────────────────────────
var _collision_shape: CollisionShape2D = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_game_manager = get_node_or_null("/root/Main")
	if is_instance_valid(_game_manager):
		_speed = _game_manager.get_setting("player_speed", 220.0) as float
		_gravity_radius = _game_manager.get_setting("gravity_radius", 180) as float
		_bullet_speed = _game_manager.get_setting("bullet_speed", 400.0) as float
		_bullets_container = _game_manager.get_bullets_container()

	_bullet_script = load("res://scripts/entities/bullet.gd") as Script

	# Collision shape
	_collision_shape = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 8.0
	_collision_shape.shape = shape
	add_child(_collision_shape)

	# Collision layers: player on layer 1, detects layer 3 (enemy bullets) and layer 4 (enemies)
	collision_layer = 2
	collision_mask = 8 | 16   # enemy bullets (layer 4) + enemies (layer 5)

	# Initial position: center-bottom of viewport
	var vp: Viewport = get_viewport()
	if is_instance_valid(vp):
		var vp_size: Vector2 = vp.get_visible_rect().size
		position = Vector2(vp_size.x * 0.5, vp_size.y * 0.8)

func _physics_process(delta: float) -> void:
	if not _is_alive:
		return
	if not is_instance_valid(_game_manager):
		return
	if _game_manager.get_current_state() != _game_manager.GameState.PLAYING:
		velocity = Vector2.ZERO
		return

	_handle_movement(delta)
	_handle_shooting(delta)
	_clamp_to_viewport()
	move_and_slide()
	queue_redraw()

func _handle_movement(_delta: float) -> void:
	var input_dir: Vector2 = Vector2.ZERO
	input_dir.x = Input.get_axis("ui_left", "ui_right")
	input_dir.y = Input.get_axis("ui_up", "ui_down")
	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()
	velocity = input_dir * _speed

func _handle_shooting(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = FIRE_INTERVAL
		_spawn_bullet()

func _spawn_bullet() -> void:
	if not is_instance_valid(_bullets_container):
		return
	if not is_instance_valid(_bullet_script):
		return
	var bullet: Area2D = Area2D.new()
	bullet.set_script(_bullet_script)
	bullet.position = global_position + Vector2(0.0, -TRIANGLE_SIZE)
	_bullets_container.add_child(bullet)
	# setup() callable after add_child — node is in scene tree
	(bullet as PlayerBullet).setup(_bullet_speed)

func _clamp_to_viewport() -> void:
	var vp: Viewport = get_viewport()
	if not is_instance_valid(vp):
		return
	var vp_size: Vector2 = vp.get_visible_rect().size
	position.x = clamp(position.x, VIEWPORT_MARGIN, vp_size.x - VIEWPORT_MARGIN)
	position.y = clamp(position.y, VIEWPORT_MARGIN, vp_size.y - VIEWPORT_MARGIN)

func _draw() -> void:
	if not _is_alive:
		return
	# Draw gravitational aura (concentric rings)
	for ring_index in range(AURA_RINGS):
		var ring_float: float = float(ring_index + 1)
		var ring_radius: float = _gravity_radius * ring_float / float(AURA_RINGS)
		var alpha: float = 0.15 - ring_float * 0.04
		var ring_color: Color = Color(AURA_COLOR_BASE.r, AURA_COLOR_BASE.g, AURA_COLOR_BASE.b, max(alpha, 0.02))
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, ring_color, 1.5)

	# Draw player triangle (pointing up)
	var tip: Vector2 = Vector2(0.0, -TRIANGLE_SIZE)
	var left: Vector2 = Vector2(-TRIANGLE_SIZE * 0.7, TRIANGLE_SIZE * 0.6)
	var right: Vector2 = Vector2(TRIANGLE_SIZE * 0.7, TRIANGLE_SIZE * 0.6)
	var points: PackedVector2Array = PackedVector2Array([tip, left, right])
	draw_colored_polygon(points, PLAYER_COLOR)

# ── Death handling ────────────────────────────────────────────────────────────
func die() -> void:
	if not _is_alive:
		return
	_is_alive = false
	velocity = Vector2.ZERO
	queue_redraw()
	player_died.emit()

func reset_player() -> void:
	_is_alive = true
	_fire_timer = 0.0
	velocity = Vector2.ZERO
	var vp: Viewport = get_viewport()
	if is_instance_valid(vp):
		var vp_size: Vector2 = vp.get_visible_rect().size
		position = Vector2(vp_size.x * 0.5, vp_size.y * 0.8)
	queue_redraw()

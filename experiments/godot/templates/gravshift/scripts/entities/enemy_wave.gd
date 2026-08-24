extends CharacterBody2D

class_name EnemyWave

# ── Signals ───────────────────────────────────────────────────────────────────
signal enemy_destroyed

# ── Constants ─────────────────────────────────────────────────────────────────
const ENEMY_COLOR: Color = Color(1.0, 0.267, 0.267)  # #ff4444 red
const CHEVRON_SIZE: float = 14.0
const BASE_SPEED_Y: float = 65.0
const WAVE_AMPLITUDE: float = 80.0
const WAVE_FREQUENCY: float = 1.8
const SHOOT_INTERVAL: float = 3.0

# ── State ─────────────────────────────────────────────────────────────────────
var _gravity_deviation: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _start_x: float = 0.0
var _is_active: bool = true
var _game_manager: Node = null
var _enemy_bullets_container: Node2D = null
var _enemy_bullet_script: Script = null
var _enemy_bullet_speed: float = 180.0
var _shoot_timer: float = 0.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_start_x = position.x
	_game_manager = get_node_or_null("/root/Main")
	if is_instance_valid(_game_manager):
		_enemy_bullets_container = _game_manager.get_enemy_bullets_container()
		_enemy_bullet_speed = _game_manager.get_setting("enemy_bullet_speed", 180.0) as float

	_enemy_bullet_script = load("res://scripts/entities/enemy_bullet.gd") as Script

	# Collision shape
	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CapsuleShape2D = CapsuleShape2D.new()
	shape.radius = CHEVRON_SIZE * 0.5
	shape.height = CHEVRON_SIZE
	col.shape = shape
	add_child(col)

	collision_layer = 8
	collision_mask = 4

	# Hitbox Area2D for player collision
	var hitbox: Area2D = Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 16
	hitbox.collision_mask = 2
	var hb_shape: CollisionShape2D = CollisionShape2D.new()
	var hb_circle: CircleShape2D = CircleShape2D.new()
	hb_circle.radius = CHEVRON_SIZE * 0.6
	hb_shape.shape = hb_circle
	hitbox.add_child(hb_shape)
	add_child(hitbox)
	hitbox.body_entered.connect(_on_hitbox_body_entered)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	_shoot_timer = rng.randf_range(0.8, SHOOT_INTERVAL)
	# Random phase offset so enemies don't oscillate in sync
	_elapsed = rng.randf_range(0.0, TAU)

func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	_elapsed += delta

	# Oscillation: horizontal sine wave centered on spawn X
	var wave_x: float = _start_x + sin(_elapsed * WAVE_FREQUENCY) * WAVE_AMPLITUDE
	var wave_vx: float = cos(_elapsed * WAVE_FREQUENCY) * WAVE_AMPLITUDE * WAVE_FREQUENCY

	# Combine base oscillation with gravity deviation
	velocity = Vector2(wave_vx, BASE_SPEED_Y) + _gravity_deviation * BASE_SPEED_Y
	_gravity_deviation = _gravity_deviation.lerp(Vector2.ZERO, 3.0 * delta)

	# Override x position directly for clean sine (add deviation on top)
	position.x = wave_x + _gravity_deviation.x * 20.0
	position.y += BASE_SPEED_Y * delta + _gravity_deviation.y * BASE_SPEED_Y * delta

	queue_redraw()

	# Shooting
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = SHOOT_INTERVAL
		_fire()

	# Self-destroy when off-screen
	var vp: Viewport = get_viewport()
	if is_instance_valid(vp):
		if position.y > vp.get_visible_rect().size.y + 64.0:
			_is_active = false
			enemy_destroyed.emit()
			queue_free()

func _draw() -> void:
	# Draw chevron shape (V pointing down — distinct from linear enemy diamond)
	var top_left: Vector2 = Vector2(-CHEVRON_SIZE, -CHEVRON_SIZE * 0.5)
	var top_right: Vector2 = Vector2(CHEVRON_SIZE, -CHEVRON_SIZE * 0.5)
	var bottom: Vector2 = Vector2(0.0, CHEVRON_SIZE)
	var points: PackedVector2Array = PackedVector2Array([top_left, top_right, bottom])
	draw_colored_polygon(points, ENEMY_COLOR)

func apply_gravity_deviation(deviation: Vector2) -> void:
	_gravity_deviation += deviation

func take_hit() -> void:
	if not _is_active:
		return
	_is_active = false
	enemy_destroyed.emit()
	queue_free()

func _fire() -> void:
	if not is_instance_valid(_enemy_bullets_container):
		return
	if not is_instance_valid(_enemy_bullet_script):
		return
	var direction: Vector2 = Vector2(0.0, 1.0).normalized()
	var bullet: Area2D = Area2D.new()
	bullet.set_script(_enemy_bullet_script)
	bullet.position = global_position + Vector2(0.0, CHEVRON_SIZE)
	_enemy_bullets_container.add_child(bullet)
	(bullet as EnemyBullet).setup(direction, _enemy_bullet_speed)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).die()

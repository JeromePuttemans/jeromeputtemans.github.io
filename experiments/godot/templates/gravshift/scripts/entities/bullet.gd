extends Area2D

class_name PlayerBullet

# ── Constants ─────────────────────────────────────────────────────────────────
const BULLET_COLOR: Color = Color(0.0, 0.898, 1.0)  # #00e5ff cyan
const BULLET_WIDTH: float = 3.0
const BULLET_HEIGHT: float = 12.0

# ── State ─────────────────────────────────────────────────────────────────────
var _speed: float = 400.0
var _collision_shape: CollisionShape2D = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_collision_shape = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(BULLET_WIDTH, BULLET_HEIGHT)
	_collision_shape.shape = shape
	add_child(_collision_shape)

	# Bullet on layer 3, detects enemies on layer 4
	collision_layer = 4
	collision_mask = 8

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func setup(speed: float) -> void:
	_speed = speed

func _physics_process(delta: float) -> void:
	position.y -= _speed * delta
	# Auto-destroy when off-screen
	if position.y < -50.0:
		queue_free()

func _draw() -> void:
	# Draw elongated rectangle (bullet trail appearance)
	draw_rect(Rect2(-BULLET_WIDTH * 0.5, -BULLET_HEIGHT * 0.5, BULLET_WIDTH, BULLET_HEIGHT), BULLET_COLOR)

func _on_area_entered(_area: Area2D) -> void:
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	# Hit an enemy — both types expose take_hit()
	if body is EnemyLinear:
		(body as EnemyLinear).take_hit()
	elif body is EnemyWave:
		(body as EnemyWave).take_hit()
	queue_free()

extends Area2D

class_name EnemyBullet

# ── Constants ─────────────────────────────────────────────────────────────────
const BULLET_COLOR: Color = Color(1.0, 0.267, 0.267)  # #ff4444 red
const BULLET_WIDTH: float = 4.0
const BULLET_HEIGHT: float = 10.0

# ── State ─────────────────────────────────────────────────────────────────────
var _direction: Vector2 = Vector2(0.0, 1.0)
var _speed: float = 180.0
var _collision_shape: CollisionShape2D = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_collision_shape = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(BULLET_WIDTH, BULLET_HEIGHT)
	_collision_shape.shape = shape
	add_child(_collision_shape)

	# Enemy bullet on layer 8 (bit 4), detects player on layer 2 (bit 1)
	collision_layer = 32
	collision_mask = 2

	body_entered.connect(_on_body_entered)

func setup(direction: Vector2, speed: float) -> void:
	_direction = direction.normalized()
	_speed = speed

func _physics_process(delta: float) -> void:
	position += _direction * _speed * delta
	queue_redraw()

	# Auto-destroy off-screen
	var vp: Viewport = get_viewport()
	if is_instance_valid(vp):
		var vp_rect: Rect2 = vp.get_visible_rect()
		if (position.y > vp_rect.size.y + 32.0
			or position.y < -32.0
			or position.x < -32.0
			or position.x > vp_rect.size.x + 32.0):
			queue_free()

func _draw() -> void:
	# Elongated rectangle — clearly a projectile, distinct from player bullets
	var half_w: float = BULLET_WIDTH * 0.5
	var half_h: float = BULLET_HEIGHT * 0.5
	draw_rect(Rect2(-half_w, -half_h, BULLET_WIDTH, BULLET_HEIGHT), BULLET_COLOR)
	# Bright tip for directionality (head = direction)
	draw_circle(_direction * half_h, 2.5, BULLET_COLOR)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).die()
	queue_free()

extends Node2D

# Bullet: one player shot. Built by player.gd inside World/Bullets.
# While it exists, it slows the ship down (player.gd counts the children of
# World/Bullets). It disappears when it hits an enemy (combat.gd), leaves the
# screen on the right, or at the end of its lifetime (safety net).

var velocity: Vector2 = Vector2.ZERO
var radius: float = 5.0
var _life: float = 1.6
var _screen_width: float = 1280.0

func setup(bullet_velocity: Vector2, lifetime: float, bullet_radius: float, screen_width: float) -> void:
	velocity = bullet_velocity
	_life = lifetime
	radius = bullet_radius
	_screen_width = screen_width

func _ready() -> void:
	use_parent_material = true   # additive blending from the Bullets container

func _physics_process(delta: float) -> void:
	position += velocity * delta
	_life -= delta
	if _life <= 0.0 or position.x > _screen_width + 30.0:
		queue_free()

func _draw() -> void:
	draw_line(Vector2(-18.0, 0.0), Vector2(6.0, 0.0), Color(1.0, 0.85, 0.45, 0.35), 7.0)
	draw_line(Vector2(-12.0, 0.0), Vector2(7.0, 0.0), Color(1.0, 0.97, 0.85), 2.5)

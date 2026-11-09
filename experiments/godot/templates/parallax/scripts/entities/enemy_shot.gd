extends Node2D

# EnemyShot: a glowing orb fired by gunners and tanks (built by spawner.gd in
# World/Shots). Moves in a straight line, one hit on the ship costs one hull
# point (combat.gd). Freed once off-screen.

var velocity: Vector2 = Vector2.ZERO
var radius: float = 6.0
var _time: float = 0.0
var _screen: Vector2 = Vector2(1280.0, 720.0)

func setup(shot_velocity: Vector2, shot_radius: float, screen: Vector2) -> void:
	velocity = shot_velocity
	radius = shot_radius
	_screen = screen

func _ready() -> void:
	use_parent_material = true

func _physics_process(delta: float) -> void:
	_time += delta
	position += velocity * delta
	var margin: float = 40.0
	if position.x < -margin or position.x > _screen.x + margin or position.y < -margin or position.y > _screen.y + margin:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var pulse: float = 1.0 + 0.15 * sin(_time * 18.0)
	draw_circle(Vector2.ZERO, radius * 2.2 * pulse, Color(1.0, 0.35, 0.6, 0.18))
	draw_circle(Vector2.ZERO, radius * 1.2, Color(1.0, 0.45, 0.7, 0.8))
	draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 0.92, 0.96))

extends EnemyBase

# Drone: light (mass 1), chases the ship. The well drags it easily: into the
# orbit, or into other enemies at speed (crash damage).

func _ready() -> void:
	sides = 4

func _behave(delta: float) -> void:
	steer((ship() - position).normalized() * speed, 260.0, delta)

func _shape(c: Color) -> void:
	var a: float = _time * 3.0
	polygon(ngon(4, radius, a), c, 2.5)
	polygon(ngon(4, radius * 0.45, -a * 1.5), Color(c, 0.8), 1.5, false)
	draw_circle(Vector2.ZERO, 3.0, c)

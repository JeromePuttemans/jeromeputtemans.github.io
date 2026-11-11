extends EnemyBase

# Drone: light (mass 1), chases the ship. The well drags it easily: into the
# orbit, or into other enemies at speed (crash damage).

func _behave(delta: float) -> void:
	steer((ship() - position).normalized() * speed, 260.0, delta)

func _shape(c: Color) -> void:
	var a: float = _time * 3.0
	var pts: Array = []
	for k in 4:
		pts.append(Vector2.RIGHT.rotated(a + TAU * k / 4.0) * radius)
	polygon(pts, c, 2.5)
	draw_circle(Vector2.ZERO, 3.0, c)

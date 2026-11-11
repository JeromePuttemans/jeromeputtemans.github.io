extends EnemyBase

# Brute: heavy (mass 9, the well barely moves it) and armoured, walks toward
# the ship and fires three HEAVY orbs that gravity cannot catch.

func _behave(delta: float) -> void:
	steer((ship() - position).normalized() * speed, 120.0, delta)
	if fire_ready(delta):
		var dir: Vector2 = (ship() - position).normalized()
		for k in [-0.3, 0.0, 0.3]:
			shoot(dir.rotated(k), true)
		gm.call("sfx", "heavy_shot", 1.0, 0.05)

func _shape(c: Color) -> void:
	var a: float = _time * 0.6
	var pts: Array = []
	for k in 8:
		var r: float = radius if k % 2 == 0 else radius * 0.78
		pts.append(Vector2.RIGHT.rotated(a + TAU * k / 8.0) * r)
	polygon(pts, c, 3.5)
	var inner: Array = []
	for k in 4:
		inner.append(Vector2.RIGHT.rotated(-a * 2.0 + TAU * k / 4.0) * radius * 0.45)
	polygon(inner, c, 2.5)

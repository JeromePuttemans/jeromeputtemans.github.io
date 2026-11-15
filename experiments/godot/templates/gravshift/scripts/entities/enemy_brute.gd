extends EnemyBase

# Brute: heavy (mass 9, the well barely moves it) and armoured, walks toward
# the ship and fires three HEAVY orbs that gravity cannot catch. Its core
# swells red during the last 0.8 s of the reload.

func _ready() -> void:
	sides = 8

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
	polygon(ngon(4, radius * 0.45, -a * 2.0), c, 2.5)
	var interval: float = float(data.get("fire_interval", 2.6))
	var warm: float = clampf((charge() - 1.0 + 0.8 / interval) / (0.8 / interval), 0.0, 1.0)
	Effects.put(self, Vector2.ZERO, 8.0 + 22.0 * warm, Color(1.0, 0.2, 0.25, 0.4 + 0.5 * warm))
	draw_circle(Vector2.ZERO, 4.0 + 4.0 * warm, Color(1.0, 0.6, 0.6))

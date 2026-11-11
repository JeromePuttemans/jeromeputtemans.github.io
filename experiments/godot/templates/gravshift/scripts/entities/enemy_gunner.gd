extends EnemyBase

# Gunner: keeps about 300 px from the ship while circling it, and fires a
# fan of three aimed pellets every fire_interval seconds: ammunition for
# the well.

const RANGE: float = 300.0

func _behave(delta: float) -> void:
	var to_ship: Vector2 = ship() - position
	var dist: float = to_ship.length()
	var dir: Vector2 = to_ship / maxf(dist, 1.0)
	var radial: float = clampf((dist - RANGE) / 120.0, -1.0, 1.0)
	var side: Vector2 = Vector2(-dir.y, dir.x) * (1.0 if uid % 2 == 0 else -1.0)
	steer((dir * radial + side * 0.6).normalized() * speed, 300.0, delta)
	if fire_ready(delta):
		for k in [-0.18, 0.0, 0.18]:
			shoot(dir.rotated(k), false)
		gm.call("sfx", "enemy_shot", 1.0, 0.1)

func _shape(c: Color) -> void:
	var dir: Vector2 = (ship() - position).normalized()
	var a: float = dir.angle()
	var pts: Array = [Vector2.RIGHT.rotated(a) * radius, Vector2.RIGHT.rotated(a + 2.4) * radius, Vector2.RIGHT.rotated(a + PI) * radius * 0.4, Vector2.RIGHT.rotated(a - 2.4) * radius]
	polygon(pts, c, 2.5)
	draw_line(Vector2.ZERO, dir * radius * 1.3, c, 2.0)

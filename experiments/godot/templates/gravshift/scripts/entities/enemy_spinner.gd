extends EnemyBase

# Spinner: settles on an anchor point and sprays a three-armed spiral of
# pellets. Dangerous, but a full orbit of ammunition for a brave ship.

var _anchor: Vector2 = Vector2.ZERO
var _spiral: float = 0.0

func _behave(delta: float) -> void:
	if _anchor == Vector2.ZERO:
		var arena: Rect2 = gm.call("arena_rect") as Rect2
		_anchor = Vector2(randf_range(arena.position.x + 200.0, arena.end.x - 200.0), randf_range(arena.position.y + 120.0, arena.end.y * 0.5))
	steer((_anchor - position).limit_length(speed), 160.0, delta)
	if fire_ready(delta):
		_spiral += 0.32
		for k in 3:
			shoot(Vector2.RIGHT.rotated(_spiral + TAU * k / 3.0), false)

func _shape(c: Color) -> void:
	var a: float = _time * 2.0
	var pts: Array = []
	for k in 6:
		pts.append(Vector2.RIGHT.rotated(a + TAU * k / 6.0) * radius)
	polygon(pts, c, 2.5)
	for k in 3:
		var arm: float = -a * 1.5 + TAU * k / 3.0
		draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(arm) * radius * 0.8, c, 2.0)

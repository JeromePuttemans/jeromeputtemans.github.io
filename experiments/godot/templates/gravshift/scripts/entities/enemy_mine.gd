extends EnemyBase

# Mine: drifts slowly; when destroyed, or when its fuse runs out, it bursts
# into a ring of twelve pellets. Shot from afar it is a gift for the well.

var _fuse: float = 6.0
var burst_done: bool = false

func _behave(delta: float) -> void:
	if vel.length() < speed:
		steer((ship() - position).normalized() * speed, 40.0, delta)
	if entered:
		_fuse -= delta
		if _fuse <= 0.0 and alive:
			alive = false
			gm.call("enemy_destroyed", self, false)

func burst() -> void:
	if burst_done:
		return
	burst_done = true
	var offset: float = randf() * TAU
	for k in 12:
		shoot(Vector2.RIGHT.rotated(offset + TAU * k / 12.0), false)

func _shape(c: Color) -> void:
	var blink: float = 1.0 if _fuse > 1.5 else (0.3 + 0.7 * absf(sin(_time * 18.0)))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(c, blink), 2.5)
	for k in 6:
		var a: float = _time + TAU * k / 6.0
		draw_line(Vector2.RIGHT.rotated(a) * radius, Vector2.RIGHT.rotated(a) * (radius + 6.0), c, 2.0)
	draw_circle(Vector2.ZERO, 3.0 + 2.0 * blink, c)

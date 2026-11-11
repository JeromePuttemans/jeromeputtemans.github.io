extends EnemyBase

# Guardian (sector 5): sweeps the top of the arena behind three rotating
# shield arcs that stop the ship's shots (slings included: aim through the
# gaps, or let the homing find them). Fires rings with two gaps and aimed
# heavy orbs; below half health it adds a spiral and calls drones.

const SHIELD_ARCS: int = 3
const ARC_SPAN: float = 1.1

var _ring_t: float = 1.5
var _heavy_t: float = 3.0
var _spiral_t: float = 0.0
var _spiral: float = 0.0
var _call_t: float = 6.0

func _ready() -> void:
	boss = true

func phase2() -> bool:
	return hp < max_hp * 0.5

func _behave(delta: float) -> void:
	var arena: Rect2 = gm.call("arena_rect") as Rect2
	var target := Vector2(arena.get_center().x + sin(_time * 0.45) * arena.size.x * 0.3, arena.position.y + 170.0 + sin(_time * 0.9) * 30.0)
	steer((target - position).limit_length(speed * 2.0), 200.0, delta)
	if not entered:
		return
	_ring_t -= delta
	if _ring_t <= 0.0:
		_ring_t = 1.7 if not phase2() else 1.3
		var gap: int = randi() % 22
		for k in 22:
			if k == gap or k == (gap + 1) % 22 or k == (gap + 11) % 22 or k == (gap + 12) % 22:
				continue
			shoot(Vector2.RIGHT.rotated(TAU * k / 22.0 + _time), false)
		gm.call("sfx", "enemy_shot", 0.8, 0.05)
	_heavy_t -= delta
	if _heavy_t <= 0.0:
		_heavy_t = 3.2
		var dir: Vector2 = (ship() - position).normalized()
		for k in [-0.22, 0.0, 0.22]:
			shoot(dir.rotated(k), true)
		gm.call("sfx", "heavy_shot", 0.9, 0.05)
	if phase2():
		_spiral_t -= delta
		if _spiral_t <= 0.0:
			_spiral_t = 0.14
			_spiral += 0.27
			shoot(Vector2.RIGHT.rotated(_spiral), false)
			shoot(Vector2.RIGHT.rotated(_spiral + PI), false)
		_call_t -= delta
		if _call_t <= 0.0:
			_call_t = 7.0
			gm.call("spawn_enemy_at", "drone", position + Vector2(-60.0, 40.0))
			gm.call("spawn_enemy_at", "drone", position + Vector2(60.0, 40.0))

## True when the point lies on one of the rotating shield arcs.
func blocks_shot(p: Vector2) -> bool:
	var d: Vector2 = p - position
	var dist: float = d.length()
	if dist < radius + 6.0 or dist > radius + 30.0:
		return false
	var a: float = d.angle()
	for k in SHIELD_ARCS:
		var start: float = _time * 0.8 + TAU * k / SHIELD_ARCS
		if absf(wrapf(a - start - ARC_SPAN * 0.5, -PI, PI)) < ARC_SPAN * 0.5:
			return true
	return false

func _shape(c: Color) -> void:
	var pts: Array = []
	for k in 6:
		pts.append(Vector2.RIGHT.rotated(TAU * k / 6.0 + _time * 0.3) * radius)
	polygon(pts, c, 4.0)
	var inner: Array = []
	for k in 6:
		inner.append(Vector2.RIGHT.rotated(TAU * k / 6.0 - _time * 0.6) * radius * 0.55)
	polygon(inner, c, 3.0)
	draw_circle(Vector2.ZERO, 10.0 + sin(_time * 5.0) * 3.0, c)
	for k in SHIELD_ARCS:
		var start: float = _time * 0.8 + TAU * k / SHIELD_ARCS
		draw_arc(Vector2.ZERO, radius + 18.0, start, start + ARC_SPAN, 16, Color(0.6, 0.95, 1.0, 0.9), 6.0)

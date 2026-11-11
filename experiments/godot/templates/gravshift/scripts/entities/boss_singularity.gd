extends EnemyBase

# Singularity (sector 10): a counter-well. It pulls the SHIP toward its
# core everywhere in the arena (ship_pull, stronger in each phase), so
# standing still means drifting into it. Its pellets are food for the
# well; the fight is won by flinging its own fire back at it.
#   phase 1 (above 2/3 health)   two counter-rotating spirals
#   phase 2 (above 1/3)          rings and aimed heavy orbs
#   phase 3                      everything, plus mines and drones

const PULL: Array[float] = [130.0, 190.0, 250.0]

var _spiral_t: float = 0.0
var _spiral: float = 0.0
var _ring_t: float = 1.0
var _heavy_t: float = 2.5
var _call_t: float = 5.0

func _ready() -> void:
	boss = true

func phase() -> int:
	var r: float = hp / max_hp
	return 0 if r > 0.66 else (1 if r > 0.33 else 2)

## Acceleration applied to the ship by the counter-well.
func ship_pull(ship_pos: Vector2) -> Vector2:
	if not entered:
		return Vector2.ZERO
	var d: Vector2 = position - ship_pos
	var dist: float = maxf(d.length(), 1.0)
	return d / dist * PULL[phase()] * clampf(500.0 / dist, 0.4, 1.4)

func _behave(delta: float) -> void:
	var arena: Rect2 = gm.call("arena_rect") as Rect2
	var target := arena.get_center() + Vector2(sin(_time * 0.3) * 200.0, -40.0 + sin(_time * 0.5) * 60.0)
	steer((target - position).limit_length(speed * 2.0), 100.0, delta)
	if not entered:
		return
	var p: int = phase()
	if p != 1:
		_spiral_t -= delta
		if _spiral_t <= 0.0:
			_spiral_t = 0.11
			_spiral += 0.21
			for k in 2:
				shoot(Vector2.RIGHT.rotated(_spiral + PI * k), false)
				shoot(Vector2.RIGHT.rotated(-_spiral * 0.8 + PI * k + 0.5), false)
	if p >= 1:
		_ring_t -= delta
		if _ring_t <= 0.0:
			_ring_t = 1.8
			for k in 18:
				shoot(Vector2.RIGHT.rotated(TAU * k / 18.0 + _time), false)
			gm.call("sfx", "enemy_shot", 0.7, 0.05)
		_heavy_t -= delta
		if _heavy_t <= 0.0:
			_heavy_t = 3.4
			var dir: Vector2 = (ship() - position).normalized()
			for k in [-0.25, 0.0, 0.25]:
				shoot(dir.rotated(k), true)
			gm.call("sfx", "heavy_shot", 0.8, 0.05)
	if p == 2:
		_call_t -= delta
		if _call_t <= 0.0:
			_call_t = 6.0
			gm.call("spawn_enemy_at", "mine", position + Vector2(0.0, 80.0))
			gm.call("spawn_enemy_at", "drone", position + Vector2(-90.0, 0.0))
			gm.call("spawn_enemy_at", "drone", position + Vector2(90.0, 0.0))

func _shape(c: Color) -> void:
	for k in 4:
		var r: float = radius * (1.0 + k * 0.35)
		var start: float = _time * (1.2 - k * 0.2) * (1.0 if k % 2 == 0 else -1.0)
		draw_arc(Vector2.ZERO, r, start, start + PI * 1.3, 40, Color(c, 0.75 - k * 0.15), 5.0 - k)
	for k in 10:
		var a: float = _time * 1.5 + TAU * k / 10.0
		var p: Vector2 = Vector2.RIGHT.rotated(a) * radius * (1.25 + 0.15 * sin(_time * 3.0 + k))
		draw_circle(p, 3.0, Color(1.0, 0.8, 1.0, 0.8))
	draw_circle(Vector2.ZERO, radius * 0.55, Color(0.02, 0.0, 0.04))
	draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 40, c.lightened(0.3), 3.0)

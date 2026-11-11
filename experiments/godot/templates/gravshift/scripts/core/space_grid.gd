extends Node2D

# SpaceGrid: the background grid that space-time bends around gravity.
#
# MODEL: every intersection is a point of mass tied to its rest position by
#   a spring: force = (rest - position) x SPRING - velocity x DAMPING.
#   Attractors (the ship's well, the singularity) pull the points toward
#   them, strongest near the centre and fading to zero at their radius;
#   impulse() kicks them outward (explosions, the fling shockwave). The
#   springs bring everything back, with a little wobble.
# DRAWING: behind the grid, three slow nebula glows and a field of
#   twinkling stars; then one polyline per row and per column, each vertex
#   coloured by its displacement, so the deformation glows where gravity is
#   strong.

const SPACING: float = 40.0
const SPRING: float = 38.0
const DAMPING: float = 6.0
const MAX_OFFSET: float = 34.0

var attractors: Array[Dictionary] = []
var base_color: Color = Color(0.16, 0.22, 0.5, 0.32)
var hot_color: Color = Color(0.3, 0.95, 1.0, 0.8)

var _stars: Array[Vector4] = []   # x, y, size, twinkle phase
var _time: float = 0.0
var _cols: int = 0
var _rows: int = 0
var _rest := PackedVector2Array()
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()

func setup(size: Vector2) -> void:
	_cols = int(size.x / SPACING) + 3
	_rows = int(size.y / SPACING) + 3
	_rest.resize(_cols * _rows)
	_pos.resize(_cols * _rows)
	_vel.resize(_cols * _rows)
	for y in _rows:
		for x in _cols:
			var p := Vector2((x - 1) * SPACING, (y - 1) * SPACING)
			var i: int = y * _cols + x
			_rest[i] = p
			_pos[i] = p
			_vel[i] = Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_stars.clear()
	for k in 150:
		_stars.append(Vector4(rng.randf() * size.x, rng.randf() * size.y, rng.randf_range(0.6, 1.8), rng.randf() * TAU))

func impulse(center: Vector2, strength: float, radius: float) -> void:
	for i in _pos.size():
		var d: Vector2 = _pos[i] - center
		var dist: float = d.length()
		if dist < radius and dist > 0.5:
			_vel[i] = _vel[i] + d / dist * strength * (1.0 - dist / radius)

func step(delta: float) -> void:
	var dt: float = minf(delta, 1.0 / 30.0)
	_time += delta
	for i in _pos.size():
		var p: Vector2 = _pos[i]
		var force: Vector2 = (_rest[i] - p) * SPRING - _vel[i] * DAMPING
		for a in attractors:
			var d: Vector2 = (a["pos"] as Vector2) - p
			var dist: float = d.length()
			var radius: float = float(a["radius"])
			if dist < radius and dist > 1.0:
				force += d / dist * float(a["strength"]) * (1.0 - dist / radius)
		var v: Vector2 = _vel[i] + force * dt
		p += v * dt
		var off: Vector2 = p - _rest[i]
		if off.length() > MAX_OFFSET:
			p = _rest[i] + off.normalized() * MAX_OFFSET
		_vel[i] = v
		_pos[i] = p
	queue_redraw()

func _color(i: int) -> Color:
	var k: float = clampf(_pos[i].distance_to(_rest[i]) / 22.0, 0.0, 1.0)
	return base_color.lerp(hot_color, k)

func _draw() -> void:
	var nebulas: Array = [
		[Vector2(260.0, 180.0), 520.0, Color(0.25, 0.1, 0.55, 0.13)],
		[Vector2(1040.0, 560.0), 600.0, Color(0.05, 0.3, 0.55, 0.12)],
		[Vector2(760.0, 120.0), 420.0, Color(0.5, 0.1, 0.4, 0.07)],
	]
	for n in nebulas:
		var drift := Vector2(sin(_time * 0.05 + n[1]), cos(_time * 0.04 + n[1])) * 30.0
		Effects.put(self, (n[0] as Vector2) + drift, float(n[1]), n[2] as Color)
	for s in _stars:
		var a: float = 0.25 + 0.35 * (0.5 + 0.5 * sin(_time * (0.8 + s.z) + s.w))
		draw_rect(Rect2(s.x, s.y, s.z, s.z), Color(0.75, 0.85, 1.0, a))
	for y in _rows:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for x in _cols:
			var i: int = y * _cols + x
			pts.append(_pos[i])
			cols.append(_color(i))
		draw_polyline_colors(pts, cols, 1.2)
	for x in _cols:
		var pts2 := PackedVector2Array()
		var cols2 := PackedColorArray()
		for y in _rows:
			var i2: int = y * _cols + x
			pts2.append(_pos[i2])
			cols2.append(_color(i2))
		draw_polyline_colors(pts2, cols2, 1.2)

# =============================================================================
# PathMarkers.gd (Node2D): animated path readability layer.
# =============================================================================
# - Chevrons scroll along the path in the walking direction: the route is
#   readable at a glance, even before the first enemy appears.
#   Algorithm: the polyline is measured once (cumulative segment lengths).
#   Each frame, chevrons are placed every CHEVRON_SPACING px starting at
#   (time x speed) mod spacing; point_at(distance) walks the segments to turn
#   a distance along the path into a position + direction.
# - The spawn portal (first waypoint) swirls.
# - The base crystal (last waypoint) bobs, shifts from cyan to red as lives
#   drop, and flashes + emits a shockwave whenever an enemy gets through.
# =============================================================================

class_name PathMarkers
extends Node2D

const CHEVRON_SPACING: float = 46.0
const CHEVRON_SPEED:   float = 28.0
const COLOR_PORTAL      := Color("a46bff")
const COLOR_CRYSTAL_OK  := Color("5fe1ff")
const COLOR_CRYSTAL_BAD := Color("ff4d5e")

var _points:  Array[Vector2] = []
var _cumul:   Array[float]   = []   # cumulative length at each point
var _total:   float = 0.0
var _tile:    float = 0.0
var _time:    float = 0.0
var _hit:     float = 0.0           # base hit flash, 1 -> 0
var _lives_ratio: float = 1.0

func _ready() -> void:
	GameState.life_lost.connect(_on_life_lost)
	GameState.lives_changed.connect(_on_lives_changed)

func setup(points: Array[Vector2], tile: float) -> void:
	_points.assign(points)
	_tile = tile
	_cumul.clear()
	_total = 0.0
	for i in _points.size():
		if i > 0:
			_total += _points[i].distance_to(_points[i - 1])
		_cumul.append(_total)
	_hit = 0.0
	_lives_ratio = 1.0

func _on_life_lost(_amount: int) -> void:
	_hit = 1.0

func _on_lives_changed(value: int) -> void:
	var start: int = maxi(ConfigManager.get_int("starting_lives", 0), 1)
	_lives_ratio = clampf(float(value) / float(start), 0.0, 1.0)

func _process(delta: float) -> void:
	_time += delta
	_hit = maxf(_hit - delta * 2.2, 0.0)
	queue_redraw()

## Position and direction at a given distance along the path.
func point_at(distance: float) -> Array:
	for i in range(1, _points.size()):
		if distance <= _cumul[i]:
			var seg: float = _cumul[i] - _cumul[i - 1]
			var k: float = (distance - _cumul[i - 1]) / seg if seg > 0.0 else 0.0
			var dir: Vector2 = (_points[i] - _points[i - 1]).normalized()
			return [_points[i - 1].lerp(_points[i], k), dir]
	return [_points[_points.size() - 1], Vector2.RIGHT]

func _draw() -> void:
	if _points.size() < 2:
		return
	_draw_chevrons()
	_draw_portal(_points[0])
	_draw_base(_points[_points.size() - 1])

func _draw_chevrons() -> void:
	var d: float = fmod(_time * CHEVRON_SPEED, CHEVRON_SPACING)
	var margin: float = _tile * 0.7
	while d < _total:
		if d > margin and d < _total - margin:
			var at: Array = point_at(d)
			var pos: Vector2 = at[0] as Vector2
			var dir: Vector2 = at[1] as Vector2
			var perp := Vector2(-dir.y, dir.x)
			var fade: float = minf(minf(d - margin, _total - margin - d) / 40.0, 1.0)
			var col := Color(1.0, 0.97, 0.88, 0.28 * fade)
			draw_line(pos - dir * 4.0 + perp * 6.0, pos + dir * 3.0, col, 2.5, true)
			draw_line(pos - dir * 4.0 - perp * 6.0, pos + dir * 3.0, col, 2.5, true)
		d += CHEVRON_SPACING

func _draw_portal(center: Vector2) -> void:
	var r: float = _tile * 0.34
	var pulse: float = 1.0 + sin(_time * 3.0) * 0.05
	draw_circle(center, r * 1.25 * pulse, Color(COLOR_PORTAL, 0.18))
	draw_circle(center, r * pulse, Color("1d1233"))
	for i in 3:
		var rr: float = r * (0.45 + i * 0.22) * pulse
		var start: float = _time * (2.2 - i * 0.6) * (1.0 if i % 2 == 0 else -1.0) + i
		draw_arc(center, rr, start, start + PI * 1.2, 20, COLOR_PORTAL.lightened(i * 0.15), 2.5, true)
		draw_arc(center, rr, start + PI, start + PI * 1.6, 12, Color(COLOR_PORTAL, 0.5), 2.0, true)
	draw_circle(center, r * 0.18, COLOR_PORTAL.lightened(0.5))

func _draw_base(center: Vector2) -> void:
	var r: float = _tile * 0.42
	# Shadow + hexagonal stone pedestal (side then top for depth)
	draw_set_transform(center + Vector2(0, r * 0.45), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, r * 1.1, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var side := _hexagon(center + Vector2(0, 5), r)
	var top := _hexagon(center, r)
	draw_colored_polygon(side, Color("4d5563"))
	draw_colored_polygon(top, Color("7d8796"))
	var outline := top.duplicate()
	outline.append(top[0])
	draw_polyline(outline, Color("5a6270"), 2.0, true)

	# Crystal: color follows remaining lives, white flash on hit
	var col: Color = COLOR_CRYSTAL_BAD.lerp(COLOR_CRYSTAL_OK, _lives_ratio)
	if _lives_ratio < 0.3:
		col = col.lerp(Color.WHITE, (sin(_time * 10.0) * 0.5 + 0.5) * 0.25)
	col = col.lerp(Color.WHITE, _hit * 0.8)
	var bob: float = sin(_time * 2.2) * 3.0
	var c := center + Vector2(0, -r * 0.45 + bob)
	var h: float = _tile * 0.3
	var w: float = _tile * 0.15
	draw_circle(c, h * (1.1 + sin(_time * 3.0) * 0.08), Color(col, 0.22))
	var gem := PackedVector2Array([c + Vector2(0, -h), c + Vector2(w, -h * 0.15),
		c + Vector2(0, h * 0.75), c + Vector2(-w, -h * 0.15)])
	draw_colored_polygon(gem, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(w, -h * 0.15),
		c + Vector2(0, h * 0.75)]), col.darkened(0.25))
	draw_line(c + Vector2(-w * 0.45, -h * 0.35), c + Vector2(0, -h * 0.85), Color(1, 1, 1, 0.7), 2.0, true)

	if _hit > 0.0:
		var k: float = 1.0 - _hit
		draw_arc(center, r * (0.8 + k * 1.6), 0.0, TAU, 32, Color(COLOR_CRYSTAL_BAD, _hit), 4.0 * _hit + 1.0, true)

func _hexagon(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a: float = PI / 6.0 + i * PI / 3.0
		pts.append(center + Vector2(cos(a), sin(a) * 0.72) * r)
	return pts

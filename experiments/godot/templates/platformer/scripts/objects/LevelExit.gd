# =============================================================================
# LevelExit.gd — Arch of light ('E') that ends the level
# =============================================================================
# Swirling motes orbit the opening; open() floods it with light while the
# player fades out, then Level emits finished.
# =============================================================================

class_name LevelExit
extends Node2D

var _time: float = 0.0
var _open: float = 0.0
var _opening: bool = false

func box() -> Rect2:
	return Rect2(position.x - 20.0, position.y - 72.0, 40.0, 72.0)

func open() -> void:
	_opening = true

func _process(delta: float) -> void:
	_time += delta
	if _opening:
		_open = minf(_open + delta * 1.6, 1.0)
	queue_redraw()

func _draw() -> void:
	var stone := Color("6f6a7d")
	var dark := Color("3d3948")
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	for i in 17:
		var a: float = PI + PI * float(i) / 16.0
		inner.append(Vector2(cos(a) * 26.0, -58.0 + sin(a) * 26.0))
		outer.append(Vector2(cos(a) * 38.0, -58.0 + sin(a) * 38.0))
	var opening := PackedVector2Array([Vector2(-26.0, 0.0)])
	opening.append_array(inner)
	opening.append(Vector2(26.0, 0.0))
	Pickups.glow(self, Vector2(0.0, -46.0), 90.0 + _open * 120.0, Color("fff2b0"), 1.0 + _open * 2.0)
	draw_colored_polygon(opening, Color(1.0, 0.95, 0.75, 0.55 + 0.45 * _open))
	for i in 10:
		var a: float = _time * (1.2 + i * 0.13) + i * 1.7
		var r: float = 8.0 + fmod(i * 7.3 + _time * 6.0, 18.0)
		var p := Vector2(cos(a) * r, -46.0 + sin(a) * r * 1.4)
		draw_circle(p, 2.0, Color(1.0, 1.0, 0.9, 0.85))
	var ring := PackedVector2Array()
	ring.append_array(outer)
	for i in range(inner.size() - 1, -1, -1):
		ring.append(inner[i])
	draw_colored_polygon(ring, stone)
	draw_rect(Rect2(-38.0, -58.0, 12.0, 58.0), stone)
	draw_rect(Rect2(26.0, -58.0, 12.0, 58.0), stone)
	for y in [-12.0, -30.0, -48.0]:
		draw_line(Vector2(-38.0, y), Vector2(-26.0, y), dark, 2.0)
		draw_line(Vector2(26.0, y), Vector2(38.0, y), dark, 2.0)
	draw_polyline(outer, dark, 2.0)
	draw_rect(Rect2(-42.0, -4.0, 84.0, 4.0), dark)
	for side in [-1.0, 1.0]:
		var base := Vector2(side * 32.0, -60.0)
		for k in 3:
			var leaf_at: Vector2 = base + Vector2(side * 4.0, -k * 14.0 + 8.0)
			PlayerArt.ellipse(self, leaf_at, 7.0, 4.0, Color("4fb534"))

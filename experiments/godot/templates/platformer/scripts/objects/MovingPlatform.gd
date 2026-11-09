# =============================================================================
# MovingPlatform.gd — Platform travelling back and forth
# =============================================================================
# Defined in "movers": {x, y, w, dx, dy, period, phase} in tiles and seconds.
# The position follows (1 - cos) / 2, an ease in and out: the platform
# slows down at both ends, which makes it easy to board. Like a plank it
# only stops a box falling on its top; Level moves the player standing on
# it by the same delta before the player's own step.
# =============================================================================

class_name MovingPlatform
extends Node2D

const THICKNESS: float = 16.0

var rect := Rect2()
var delta := Vector2.ZERO
var velocity := Vector2.ZERO
var carry_tolerance: float = 8.0
var _origin := Vector2.ZERO
var _travel := Vector2.ZERO
var _period: float = 4.0
var _phase: float = 0.0
var _time: float = 0.0
var _color := Color("8a5a33")

func setup(m: Dictionary, data: LevelData) -> void:
	var t: float = LevelData.TILE
	_origin = Vector2(float(m.get("x", 0)) * t, float(m.get("y", 0)) * t)
	_travel = Vector2(float(m.get("dx", 0)) * t, float(m.get("dy", 0)) * t)
	_period = maxf(float(m.get("period", 4.0)), 0.5)
	_phase = float(m.get("phase", 0.0))
	rect = Rect2(_origin, Vector2(float(m.get("w", 3)) * t, THICKNESS))
	_color = data.theme_color("plank", _color)
	carry_tolerance = 4.0 + _travel.length() * PI / _period / 60.0
	position = _target()
	rect.position = position

func _target() -> Vector2:
	var k: float = (1.0 - cos(TAU * (_time / _period + _phase))) * 0.5
	return _origin + _travel * k

func step(dt: float) -> void:
	_time += dt
	var p: Vector2 = _target()
	delta = p - position
	velocity = delta / dt
	position = p
	rect.position = p

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var w: float = rect.size.x
	draw_rect(Rect2(0.0, 0.0, w, THICKNESS), _color.darkened(0.35))
	draw_rect(Rect2(0.0, 0.0, w, THICKNESS - 4.0), _color)
	draw_rect(Rect2(0.0, 0.0, w, 3.0), _color.lightened(0.25))
	var x: float = 20.0
	while x < w - 4.0:
		draw_line(Vector2(x, 3.0), Vector2(x, THICKNESS - 4.0), _color.darkened(0.25), 1.5)
		x += 40.0
	for side in [6.0, w - 6.0]:
		draw_circle(Vector2(side, THICKNESS * 0.45), 2.5, Color("d9c79a"))
	var gear_x: float = w * 0.5
	var spin: float = _time * 3.0
	for i in 6:
		var a: float = spin + TAU * i / 6.0
		draw_line(Vector2(gear_x, THICKNESS + 6.0), Vector2(gear_x, THICKNESS + 6.0) + Vector2(cos(a), sin(a)) * 7.0, Color("6d6d80"), 3.0)
	draw_circle(Vector2(gear_x, THICKNESS + 6.0), 4.0, Color("4a4a58"))

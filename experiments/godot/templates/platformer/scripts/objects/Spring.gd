# =============================================================================
# Spring.gd — Bounce pad ('s'): launches at spring_velocity
# =============================================================================
# Triggered by a player falling or standing on its pad. The launch ignores
# the jump button (no cut), so the height is always the same: about nine
# tiles with the default values.
# =============================================================================

class_name Spring
extends Node2D

var _press: float = 0.0
var _wobble: float = 0.0

func top_box() -> Rect2:
	return Rect2(position.x - 17.0, position.y - 18.0, 34.0, 18.0)

func use() -> void:
	_press = 1.0
	_wobble = 1.0

func _process(delta: float) -> void:
	_press = maxf(_press - delta * 7.0, 0.0)
	_wobble = maxf(_wobble - delta * 2.5, 0.0)
	queue_redraw()

func _draw() -> void:
	var squash: float = _press
	var stretch: float = sin((1.0 - _wobble) * 18.0) * _wobble * 5.0
	var top_y: float = -16.0 + squash * 9.0 - stretch
	draw_rect(Rect2(-16.0, -5.0, 32.0, 5.0), Color("4a4a58"))
	draw_rect(Rect2(-16.0, -5.0, 32.0, 2.0), Color("6d6d80"))
	var coil := Color("c9ccd6")
	var turns: int = 3
	var prev := Vector2(-9.0, -5.0)
	for i in range(1, turns * 2 + 1):
		var y: float = lerpf(-5.0, top_y + 3.0, float(i) / float(turns * 2))
		var p := Vector2(9.0 if i % 2 == 1 else -9.0, y)
		draw_line(prev, p, coil, 3.0)
		prev = p
	draw_rect(Rect2(-18.0, top_y - 3.0, 36.0, 7.0), Color("8a1f2d"))
	draw_rect(Rect2(-18.0, top_y - 3.0, 36.0, 3.0), Color("e8505b"))
	draw_rect(Rect2(-12.0, top_y - 2.0, 6.0, 1.5), Color(1.0, 1.0, 1.0, 0.6))

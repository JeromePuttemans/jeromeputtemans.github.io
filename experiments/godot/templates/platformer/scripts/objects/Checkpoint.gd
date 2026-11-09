# =============================================================================
# Checkpoint.gd — Lantern ('K'): lighting it moves the respawn point here
# =============================================================================
# Only the last lantern touched stays lit. Its flame flickers with two sines
# of unrelated frequencies, which never visibly loop.
# =============================================================================

class_name Checkpoint
extends Node2D

var lit: bool = false
var _time: float = 0.0
var _flash: float = 0.0

func box() -> Rect2:
	return Rect2(position.x - 22.0, position.y - 84.0, 44.0, 84.0)

func light() -> void:
	lit = true
	_flash = 1.0

func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta * 2.0, 0.0)
	queue_redraw()

func _draw() -> void:
	var wood := Color("5b3a24")
	draw_rect(Rect2(-3.0, -62.0, 6.0, 62.0), wood)
	draw_rect(Rect2(-3.0, -62.0, 2.0, 62.0), wood.lightened(0.2))
	draw_rect(Rect2(-9.0, -2.0, 18.0, 4.0), wood.darkened(0.2))
	draw_line(Vector2(0.0, -62.0), Vector2(12.0, -62.0), wood, 3.0)
	var hook := Vector2(12.0, -60.0)
	var swing: float = sin(_time * 1.7) * 0.06
	draw_set_transform(hook, swing, Vector2.ONE)
	var flicker: float = 0.8 + 0.12 * sin(_time * 13.0) + 0.08 * sin(_time * 7.3)
	if lit:
		Pickups.glow(self, Vector2(0.0, 14.0), 70.0 + _flash * 50.0, Color("ffb347"), flicker * 1.6 + _flash)
	draw_line(Vector2(0.0, 0.0), Vector2(0.0, 4.0), Color("2a2a2a"), 1.5)
	var frame := Color("2f2a24")
	draw_rect(Rect2(-8.0, 3.0, 16.0, 4.0), frame)
	var glass := Color(1.0, 0.85, 0.45, 0.9) if lit else Color(0.55, 0.6, 0.65, 0.5)
	draw_rect(Rect2(-7.0, 7.0, 14.0, 15.0), glass)
	if lit:
		var h: float = 9.0 * flicker
		draw_colored_polygon(PackedVector2Array([Vector2(-3.0, 19.0), Vector2(0.0, 19.0 - h), Vector2(3.0, 19.0)]), Color("fff2c0"))
	draw_rect(Rect2(-8.0, 7.0, 2.0, 15.0), frame)
	draw_rect(Rect2(6.0, 7.0, 2.0, 15.0), frame)
	draw_rect(Rect2(-8.0, 22.0, 16.0, 4.0), frame)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

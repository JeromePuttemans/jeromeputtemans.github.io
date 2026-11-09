# =============================================================================
# Transition.gd — Iris wipe between screens and levels
# =============================================================================
# A ring as thick as the screen is drawn around a circle of radius
# openness x the screen diagonal: shrinking the circle closes the iris on
# its centre, growing it opens the iris. One draw_arc, no shader.
# =============================================================================

class_name Transition
extends Control

const COLOR: Color = Color(0.04, 0.06, 0.04)

var openness: float = 1.0:
	set(value):
		openness = value
		queue_redraw()
var focus_point := Vector2(-1.0, -1.0)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func close(duration: float = 0.35) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(self, "openness", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished

func open(duration: float = 0.45) -> void:
	var tween := create_tween()
	tween.tween_property(self, "openness", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if openness >= 0.999:
		return
	var center: Vector2 = size * 0.5 if focus_point.x < 0.0 else focus_point
	var reach: float = (size + Vector2(abs(center.x - size.x * 0.5), abs(center.y - size.y * 0.5)) * 2.0).length()
	if openness <= 0.001:
		draw_rect(Rect2(Vector2.ZERO, size), COLOR)
		return
	var radius: float = reach * openness
	var thickness: float = reach * 1.2
	draw_arc(center, radius + thickness * 0.5, 0.0, TAU, 96, COLOR, thickness)

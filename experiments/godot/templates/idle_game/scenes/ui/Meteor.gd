# =============================================================================
# Meteor.gd — The clickable meteor (BoostManager event)
# =============================================================================
# Crosses the screen on a gentle arc in `lifetime` seconds, from one side to
# the other, with a glowing tail. Rain meteors are cyan, eruption meteors
# orange. A click catches it (BoostManager.catch_meteor) and emits caught;
# when the time runs out, Main calls fade_out().
# =============================================================================

extends Control

signal caught(at: Vector2, kind: String, amount: float)

const SIZE: float = 64.0
const TAIL_POINTS: int = 14

var kind: String = "rain"
var _lifetime: float = 7.0
var _age: float = 0.0
var _start: Vector2 = Vector2.ZERO
var _end: Vector2 = Vector2.ZERO
var _arc: float = 0.0
var _trail := PackedVector2Array()
var _fading: bool = false

func setup(meteor_kind: String, lifetime: float, area: Vector2) -> void:
	kind = meteor_kind
	_lifetime = lifetime
	var from_left: bool = randf() < 0.5
	_start = Vector2(-SIZE if from_left else area.x + SIZE, randf_range(area.y * 0.15, area.y * 0.55))
	_end = Vector2(area.x + SIZE if from_left else -SIZE, randf_range(area.y * 0.25, area.y * 0.75))
	_arc = randf_range(-90.0, 90.0)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_place()

func fade_out() -> void:
	_fading = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if _fading or button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	var amount: float = BoostManager.catch_meteor()
	caught.emit(get_global_rect().get_center(), kind, amount)
	queue_free()

func _process(delta: float) -> void:
	_age += delta
	_place()
	queue_redraw()

func _place() -> void:
	var t: float = clampf(_age / maxf(_lifetime, 0.1), 0.0, 1.0)
	var point: Vector2 = _start.lerp(_end, t) + Vector2(0.0, -sin(t * PI) * _arc)
	position = point - size * 0.5
	_trail.insert(0, point)
	if _trail.size() > TAIL_POINTS:
		_trail.resize(TAIL_POINTS)

func _draw() -> void:
	var color: Color = UiTheme.CRYSTAL if kind == "rain" else UiTheme.HEAT
	var center: Vector2 = size * 0.5
	var origin: Vector2 = position + center
	for i in range(_trail.size() - 1):
		var t: float = 1.0 - float(i) / TAIL_POINTS
		draw_line(_trail[i] - origin + center, _trail[i + 1] - origin + center, Color(color, 0.5 * t), 10.0 * t + 1.0, true)
	var pulse: float = 1.0 + 0.12 * sin(_age * 10.0)
	draw_circle(center, 26.0 * pulse, Color(color, 0.18))
	UiTheme.draw_gem(self, center, 16.0 * pulse, 6, color, _age * 3.0)

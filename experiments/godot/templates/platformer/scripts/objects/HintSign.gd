# =============================================================================
# HintSign.gd — Wooden sign ('1' to '9') with a hint bubble
# =============================================================================
# The text comes from strings_<lang>.json under the key sign_<level>_<n>.
# The bubble fades in while the player stands within 70 px.
# =============================================================================

class_name HintSign
extends Node2D

var text_key: String = ""
var _near: bool = false
var _alpha: float = 0.0
var _bubble: PanelContainer = null
var _label: Label = null

func _ready() -> void:
	_bubble = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.96, 0.88, 0.96)
	style.border_color = Color("5b3a24")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble.z_index = 40
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color("3a2616"))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(250.0, 0.0)
	_bubble.add_child(_label)
	add_child(_bubble)
	_bubble.modulate.a = 0.0
	StringManager.language_changed.connect(func(_l: String) -> void: _refresh())
	_refresh()

func _refresh() -> void:
	_label.text = StringManager.t(text_key)
	_bubble.reset_size()

func set_near(value: bool) -> void:
	_near = value

func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, 1.0 if _near else 0.0, delta * 5.0)
	_bubble.modulate.a = _alpha
	var size: Vector2 = _bubble.get_combined_minimum_size()
	_bubble.size = size
	_bubble.position = Vector2(-size.x * 0.5, -70.0 - size.y - (1.0 - _alpha) * 8.0)
	queue_redraw()

func _draw() -> void:
	var wood := Color("8a5a33")
	draw_rect(Rect2(-3.0, -30.0, 6.0, 30.0), wood.darkened(0.25))
	draw_rect(Rect2(-18.0, -50.0, 36.0, 24.0), wood.darkened(0.35))
	draw_rect(Rect2(-16.0, -48.0, 32.0, 20.0), wood)
	draw_line(Vector2(-16.0, -41.0), Vector2(16.0, -41.0), wood.darkened(0.15), 1.0)
	draw_line(Vector2(-16.0, -34.0), Vector2(16.0, -34.0), wood.darkened(0.15), 1.0)
	var bob: float = sin(Time.get_ticks_msec() * 0.005) * 1.5 if not _near else 0.0
	var mark := Color("fff4d6")
	draw_arc(Vector2(0.0, -42.0 + bob), 4.0, PI, TAU + 0.6, 10, mark, 2.5)
	draw_line(Vector2(1.5, -38.5 + bob), Vector2(0.0, -35.5 + bob), mark, 2.5)
	draw_circle(Vector2(0.0, -31.5 + bob), 1.6, mark)

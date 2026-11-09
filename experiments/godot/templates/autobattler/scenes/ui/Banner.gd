# =============================================================================
# Banner.gd — Big announcement over the arena (battle, victory, defeat)
# =============================================================================
# show_banner(title, subtitle, color, duration): the title pops in with an
# overshoot, holds, then fades out. Never catches the mouse.
# =============================================================================

extends Control

var _title: Label
var _subtitle: Label
var _tween: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = UiTheme.label("", 46, UiTheme.GOLD)
	_subtitle = UiTheme.label("", 18, UiTheme.TEXT)
	for label in [_title, _subtitle]:
		var l: Label = label as Label
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		l.add_theme_constant_override("outline_size", 8)
		box.add_child(l)

func show_banner(title: String, subtitle: String, color: Color, duration: float) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_title.add_theme_color_override("font_color", color)
	_subtitle.visible = not subtitle.is_empty()
	pivot_offset = size * 0.5
	if _tween != null:
		_tween.kill()
	scale = Vector2(0.6, 0.6)
	modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.chain().tween_interval(duration)
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.35)

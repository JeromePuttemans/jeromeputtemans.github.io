# =============================================================================
# UiTheme.gd — Mondrian buttons and labels
# =============================================================================
# Buttons are off-white fields inside thick black lines; the focused one
# turns yellow. Every button sounds on focus and on press, so menus work
# with the keyboard, a pad or the mouse.
# =============================================================================

class_name UiTheme
extends RefCounted

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", Pieces.LINE)
	theme.set_stylebox("normal", "Button", box(Pieces.PALETTE[Pieces.Col.WHITE]))
	theme.set_stylebox("hover", "Button", box(Pieces.PALETTE[Pieces.Col.YELLOW]))
	theme.set_stylebox("focus", "Button", box(Pieces.PALETTE[Pieces.Col.YELLOW]))
	theme.set_stylebox("pressed", "Button", box(Pieces.PALETTE[Pieces.Col.RED]))
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		theme.set_color(state, "Button", Pieces.LINE)
	theme.set_color("font_pressed_color", "Button", Pieces.PALETTE[Pieces.Col.WHITE])
	return theme

static func box(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Pieces.LINE
	s.set_border_width_all(6)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func label(text: String, size: int, color: Color = Pieces.LINE) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func button(text: String, callback: Callable, width: float = 300.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 54.0)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func() -> void:
		Sfx.play("ui")
		callback.call())
	b.focus_entered.connect(func() -> void: Sfx.play("ui_move"))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	return b

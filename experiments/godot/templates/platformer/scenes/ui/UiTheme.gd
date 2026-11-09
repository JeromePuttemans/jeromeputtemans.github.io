# =============================================================================
# UiTheme.gd — Palette, theme and small builders shared by the interface
# =============================================================================
# Forest palette: dark moss panels, cream text, gold for records and focus.
# Every button plays a sound on focus and on press, and shows a gold border
# when focused, so the whole interface works with the keyboard or a pad.
# =============================================================================

class_name UiTheme
extends RefCounted

const PANEL: Color = Color(0.1, 0.14, 0.1, 0.93)
const PANEL_LIGHT: Color = Color(0.15, 0.2, 0.14, 0.96)
const BORDER: Color = Color(0.36, 0.5, 0.28)
const TEXT: Color = Color(0.96, 0.93, 0.85)
const MUTED: Color = Color(0.7, 0.72, 0.62)
const GOLD: Color = Color(1.0, 0.81, 0.3)
const LEAF: Color = Color(0.56, 0.82, 0.31)
const BAD: Color = Color(0.91, 0.36, 0.38)
const SHADOW: Color = Color(0.05, 0.07, 0.04, 0.85)

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 10, 14))
	theme.set_stylebox("normal", "Button", box(Color(0.17, 0.23, 0.16), Color(0.3, 0.42, 0.25), 8, 14))
	theme.set_stylebox("hover", "Button", box(Color(0.22, 0.3, 0.2), Color(0.5, 0.66, 0.38), 8, 14))
	theme.set_stylebox("pressed", "Button", box(Color(0.12, 0.17, 0.11), GOLD, 8, 14))
	theme.set_stylebox("disabled", "Button", box(Color(0.12, 0.14, 0.12, 0.8), Color(0.22, 0.26, 0.2), 8, 14))
	var focus := box(Color(0, 0, 0, 0), GOLD, 8, 14)
	focus.set_border_width_all(3)
	focus.draw_center = false
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.52, 0.46))
	return theme

static func box(bg: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.6
	style.content_margin_bottom = margin * 0.6
	return style

static func label(text: String, font_size: int, color: Color = TEXT, outline: int = 0) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	if outline > 0:
		result.add_theme_constant_override("outline_size", outline)
		result.add_theme_color_override("font_outline_color", SHADOW)
	return result

static func button(text: String, callback: Callable, min_width: float = 280.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 46.0)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func() -> void:
		Sfx.play("ui")
		callback.call())
	b.focus_entered.connect(func() -> void: Sfx.play("ui_move"))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	return b

## Full-screen dark veil behind menus.
static func veil(alpha: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0.03, 0.05, 0.03, alpha)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect

static func center_box() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

# =============================================================================
# UiTheme.gd — Palette, theme and small builders shared by the interface
# =============================================================================
# Dusk palette: deep indigo panels (the colour of the solid shadows), cream
# text, gold for focus, records and the sun. Every button plays a sound on
# focus and on press and shows a gold border when focused.
# =============================================================================

class_name UiTheme
extends RefCounted

const PANEL: Color = Color(0.07, 0.06, 0.16, 0.9)
const BORDER: Color = Color(0.36, 0.3, 0.55)
const TEXT: Color = Color(0.97, 0.94, 0.86)
const MUTED: Color = Color(0.72, 0.7, 0.8)
const GOLD: Color = Color(1.0, 0.8, 0.4)
const OUTLINE: Color = Color(0.04, 0.03, 0.1, 0.85)

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 12, 18))
	theme.set_stylebox("normal", "Button", box(Color(0.13, 0.11, 0.25), Color(0.3, 0.26, 0.48), 8, 14))
	theme.set_stylebox("hover", "Button", box(Color(0.18, 0.15, 0.33), Color(0.55, 0.47, 0.75), 8, 14))
	theme.set_stylebox("pressed", "Button", box(Color(0.09, 0.08, 0.18), GOLD, 8, 14))
	var focus := box(Color(0, 0, 0, 0), GOLD, 8, 14)
	focus.set_border_width_all(3)
	focus.draw_center = false
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", GOLD)
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
		result.add_theme_color_override("font_outline_color", OUTLINE)
	return result

static func button(text: String, callback: Callable, min_width: float = 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 44.0)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(func() -> void:
		Sfx.play("ui")
		callback.call())
	b.focus_entered.connect(func() -> void: Sfx.play("ui_move"))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	return b

static func veil(alpha: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0.03, 0.02, 0.08, alpha)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect

static func center_box() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## "9 h 30" / "9:30", minutes rounded to five.
static func hour_text(h: float) -> String:
	var minutes: int = int(round(h * 60.0 / 5.0)) * 5
	return StringManager.t("hour_format", {h = floori(minutes / 60.0), m = "%02d" % (minutes % 60)})

## Fills {back}, {fwd} and {move} with the keys of the player's keyboard.
static func keys(text: String) -> String:
	return text.replace("{back}", InputSetup.key_name(KEY_Q)).replace("{fwd}", InputSetup.key_name(KEY_E)).replace("{move}", InputSetup.move_keys())

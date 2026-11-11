# =============================================================================
# UiTheme.gd — Neon palette, theme and small builders shared by the UI
# =============================================================================
# Every button plays a sound on focus and press and shows a cyan border
# when focused, so the menus work with the keyboard or a pad.
# Texts use Latin-1 characters only (the web build has no font fallback).
# =============================================================================

class_name UiTheme
extends RefCounted

const PANEL: Color = Color(0.03, 0.04, 0.1, 0.94)
const BORDER: Color = Color(0.25, 0.35, 0.7)
const TEXT: Color = Color(0.92, 0.95, 1.0)
const MUTED: Color = Color(0.55, 0.62, 0.8)
const CYAN: Color = Color(0.44, 0.95, 1.0)
const MAGENTA: Color = Color(1.0, 0.42, 0.78)
const GOLD: Color = Color(1.0, 0.82, 0.3)
const RED: Color = Color(1.0, 0.3, 0.38)
const SHADOW: Color = Color(0.0, 0.0, 0.06, 0.9)

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 6, 16))
	theme.set_stylebox("normal", "Button", box(Color(0.06, 0.08, 0.18), Color(0.2, 0.28, 0.55), 4, 14))
	theme.set_stylebox("hover", "Button", box(Color(0.09, 0.12, 0.26), Color(0.35, 0.5, 0.9), 4, 14))
	theme.set_stylebox("pressed", "Button", box(Color(0.04, 0.05, 0.12), CYAN, 4, 14))
	theme.set_stylebox("disabled", "Button", box(Color(0.05, 0.06, 0.12, 0.8), Color(0.15, 0.18, 0.3), 4, 14))
	var focus := box(Color(0, 0, 0, 0), CYAN, 4, 14)
	focus.set_border_width_all(2)
	focus.draw_center = false
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", CYAN)
	theme.set_color("font_pressed_color", "Button", CYAN)
	theme.set_color("font_disabled_color", "Button", Color(0.4, 0.45, 0.6))
	return theme

static func box(bg: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
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

static func button(text: String, callback: Callable, min_width: float = 300.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 44.0)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(func() -> void:
		Sfx.play("ui")
		callback.call())
	b.focus_entered.connect(func() -> void: Sfx.play("ui_move"))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	return b

static func veil(alpha: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0.0, 0.01, 0.05, alpha)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect

static func center_box() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Small ship silhouette for the lives counter.
static func draw_ship(canvas: CanvasItem, at: Vector2, scale: float, color: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, -12), Vector2(4, -4), Vector2(12, 6), Vector2(4, 4), Vector2(0, 8), Vector2(-4, 4), Vector2(-12, 6), Vector2(-4, -4)])
	for i in pts.size():
		pts[i] = at + pts[i] * scale
	canvas.draw_colored_polygon(pts, color)

## Bomb icon: a ringed orb.
static func draw_bomb(canvas: CanvasItem, at: Vector2, scale: float, color: Color) -> void:
	canvas.draw_circle(at, 7.0 * scale, color.darkened(0.4))
	canvas.draw_circle(at, 5.0 * scale, color)
	canvas.draw_arc(at, 9.5 * scale, -0.6, 3.6, 16, color, 1.5)

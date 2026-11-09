# =============================================================================
# UiTheme.gd — Colours, theme and shared drawing helpers
# =============================================================================
# One place for the visual identity: a deep night palette, the cyan of the
# crystal, gold for prisms and highlights. build() returns the Theme applied
# to the root control; draw_gem() draws the faceted polygon used for producer
# icons, orbiters and upgrade tiles (sides = 3 for the first producer, up to
# 10 for the last: the shapes grow rounder with the tiers).
# Only Latin-1 characters are used in texts: the web build has no system font
# fallback, a missing glyph would show as a box.
# =============================================================================

class_name UiTheme
extends RefCounted

const BG_TOP: Color = Color(0.043, 0.047, 0.11)
const BG_BOTTOM: Color = Color(0.11, 0.06, 0.2)
const PANEL: Color = Color(0.075, 0.08, 0.15, 0.9)
const PANEL_LIGHT: Color = Color(0.11, 0.12, 0.21, 0.95)
const BORDER: Color = Color(0.2, 0.22, 0.36)
const TEXT: Color = Color(0.91, 0.93, 0.98)
const MUTED: Color = Color(0.55, 0.59, 0.72)
const CRYSTAL: Color = Color(0.44, 0.89, 1.0)
const GOLD: Color = Color(1.0, 0.83, 0.3)
const GOOD: Color = Color(0.42, 0.88, 0.54)
const BAD: Color = Color(1.0, 0.42, 0.42)
const HEAT: Color = Color(1.0, 0.6, 0.24)
const PRISM: Color = Color(0.79, 0.64, 1.0)

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 10, 12))
	theme.set_stylebox("normal", "Button", box(Color(0.13, 0.15, 0.26), Color(0.24, 0.27, 0.43), 8, 10))
	theme.set_stylebox("hover", "Button", box(Color(0.17, 0.2, 0.34), Color(0.36, 0.42, 0.66), 8, 10))
	theme.set_stylebox("pressed", "Button", box(Color(0.09, 0.1, 0.18), CRYSTAL, 8, 10))
	theme.set_stylebox("disabled", "Button", box(Color(0.09, 0.1, 0.16), Color(0.16, 0.18, 0.28), 8, 10))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", CRYSTAL)
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.53, 0.65))
	theme.set_stylebox("panel", "TooltipPanel", box(PANEL_LIGHT, BORDER, 6, 8))
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

## Faceted gem: a regular polygon, a darker rim, light facets from the centre.
static func draw_gem(canvas: CanvasItem, center: Vector2, radius: float, sides: int, color: Color, angle: float) -> void:
	var points := PackedVector2Array()
	for i in sides:
		points.append(center + Vector2.RIGHT.rotated(angle + TAU * i / sides - PI * 0.5) * radius)
	canvas.draw_colored_polygon(points, Color(color.darkened(0.55), color.a))
	for i in sides:
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % sides]
		var shade: float = 0.25 + 0.45 * (0.5 + 0.5 * cos(TAU * i / sides + angle * 2.0))
		canvas.draw_colored_polygon(PackedVector2Array([center, a, b]), Color(color.darkened(0.5 - shade * 0.5), color.a * 0.9))
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, Color(color.lightened(0.35), color.a), maxf(radius * 0.08, 1.0), true)
	canvas.draw_circle(center + Vector2(-radius * 0.22, -radius * 0.3), radius * 0.16, Color(1.0, 1.0, 1.0, 0.45 * color.a))

static func label(text: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

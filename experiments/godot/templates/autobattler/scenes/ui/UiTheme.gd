# =============================================================================
# UiTheme.gd — Palette, theme and small helpers shared by the interface
# =============================================================================
# Only Latin-1 characters appear in texts: the web build has no system font
# fallback, a missing glyph (a star, an arrow) would show as a box. Stars and
# icons are therefore drawn, never typed.
# =============================================================================

class_name UiTheme
extends RefCounted

const BG_TOP: Color = Color(0.07, 0.07, 0.11)
const BG_BOTTOM: Color = Color(0.12, 0.09, 0.14)
const PANEL: Color = Color(0.1, 0.1, 0.15, 0.94)
const PANEL_LIGHT: Color = Color(0.15, 0.15, 0.22, 0.97)
const BORDER: Color = Color(0.26, 0.26, 0.36)
const TEXT: Color = Color(0.93, 0.92, 0.9)
const MUTED: Color = Color(0.6, 0.6, 0.68)
const GOLD: Color = Color(1.0, 0.8, 0.3)
const GOOD: Color = Color(0.45, 0.88, 0.5)
const BAD: Color = Color(1.0, 0.4, 0.38)
const PLAYER: Color = Color(0.4, 0.75, 1.0)
const ENEMY: Color = Color(1.0, 0.38, 0.35)
const MANA: Color = Color(0.45, 0.6, 1.0)
const TIER_COLORS: Array[Color] = [Color(0.6, 0.6, 0.65), Color(0.66, 0.7, 0.78), Color(0.38, 0.85, 0.52), Color(0.4, 0.68, 1.0)]

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 8, 10))
	theme.set_stylebox("normal", "Button", box(Color(0.17, 0.17, 0.25), Color(0.3, 0.3, 0.42), 7, 10))
	theme.set_stylebox("hover", "Button", box(Color(0.22, 0.22, 0.32), Color(0.45, 0.45, 0.62), 7, 10))
	theme.set_stylebox("pressed", "Button", box(Color(0.12, 0.12, 0.18), GOLD, 7, 10))
	theme.set_stylebox("disabled", "Button", box(Color(0.12, 0.12, 0.17), Color(0.2, 0.2, 0.28), 7, 10))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.58))
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

static func label(text: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

static func tier_color(tier: int) -> Color:
	return TIER_COLORS[clampi(tier, 0, TIER_COLORS.size() - 1)]

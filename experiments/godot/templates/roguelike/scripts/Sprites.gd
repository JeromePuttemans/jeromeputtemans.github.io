# =============================================================================
# Sprites.gd: vector drawing helpers that complement the pixel art.
# =============================================================================
# Actors, items and tiles are pixel art (PixelArt.gd, TileArt.gd). What
# stays vector here:
#   bold_font    the embolden variant of the default font (HUD titles)
#   draw_portal  the swirling exit of the last floor, animated every frame
# =============================================================================

class_name Sprites
extends RefCounted

static var _bold: FontVariation = null

static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.9
	return _bold

static func _fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)

static func draw_portal(ci: CanvasItem, center: Vector2, r: float, time: float, alpha: float = 1.0) -> void:
	var col := Color("7fe3ff")
	ci.draw_circle(center, r * 1.15, _fade(Color(col, 0.2), alpha))
	ci.draw_circle(center, r * 0.9, _fade(Color("0f2433"), alpha))
	for i in 3:
		var rr: float = r * (0.35 + i * 0.22)
		var start: float = time * (2.4 - i * 0.6) * (1.0 if i % 2 == 0 else -1.0) + i
		ci.draw_arc(center, rr, start, start + PI * 1.3, 16, _fade(col.lightened(i * 0.15), alpha), 2.5, true)
	ci.draw_circle(center, r * 0.16, _fade(Color.WHITE, alpha))

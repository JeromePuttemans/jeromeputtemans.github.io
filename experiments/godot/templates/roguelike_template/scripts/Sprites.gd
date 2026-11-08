# =============================================================================
# Sprites.gd: static drawing helpers shared by the map and the HUD.
# =============================================================================
# No textures: every visual is built from circles, polygons and a font glyph,
# drawn on any CanvasItem (DungeonView, inventory slots, look panel).
# Keeping these in one place guarantees that an item looks the same on the
# ground and in the inventory.
#
#   draw_token   actors: shadow + colored disc + letter glyph (roguelike
#                tradition: r = rat, o = orc, T = troll, @ = you)
#   draw_item    potion, ration, scroll, gem, shield, heart
#   draw_stairs  steps going down
#   draw_portal  swirling exit of the last floor
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

## Actor token. flash 0..1 whitens the body (hit feedback).
static func draw_token(ci: CanvasItem, center: Vector2, r: float, color: Color, glyph: String,
		flash: float, alpha: float = 1.0) -> void:
	if r <= 1.0:
		return
	ci.draw_set_transform(center + Vector2(0, r * 0.78), 0.0, Vector2(1.0, 0.42))
	ci.draw_circle(Vector2.ZERO, r * 0.95, Color(0, 0, 0, 0.35 * alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body: Color = color.darkened(0.2).lerp(Color.WHITE, flash)
	ci.draw_circle(center, r, _fade(color.darkened(0.55).lerp(Color.WHITE, flash), alpha))
	ci.draw_circle(center, r - 2.0, _fade(body, alpha))
	ci.draw_arc(center, r - 4.0, PI * 1.05, PI * 1.6, 8, _fade(Color(1, 1, 1, 0.35), alpha), 2.0, true)
	var fs: int = int(r * 1.25)
	var at := Vector2(center.x - r, center.y + fs * 0.36)
	var font: Font = bold_font()
	ci.draw_string_outline(font, at, glyph, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, 4, _fade(Color(0, 0, 0, 0.55), alpha))
	ci.draw_string(font, at, glyph, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, _fade(Color(1, 1, 1, 0.95), alpha))

## Item icon centered on `center`, fitting in a square of side `size`.
static func draw_item(ci: CanvasItem, shape: String, color: Color, center: Vector2, size: float,
		alpha: float = 1.0) -> void:
	var s: float = size * 0.5
	var dark: Color = _fade(color.darkened(0.45), alpha)
	var main: Color = _fade(color, alpha)
	var light: Color = _fade(color.lightened(0.45), alpha)
	match shape:
		"potion":
			ci.draw_rect(Rect2(center + Vector2(-s * 0.18, -s * 0.85), Vector2(s * 0.36, s * 0.45)), _fade(Color("c9d4e0"), alpha))
			ci.draw_rect(Rect2(center + Vector2(-s * 0.24, -s * 0.98), Vector2(s * 0.48, s * 0.2)), _fade(Color("8a6a48"), alpha))
			ci.draw_circle(center + Vector2(0, s * 0.2), s * 0.62, dark)
			ci.draw_circle(center + Vector2(0, s * 0.2), s * 0.52, main)
			ci.draw_circle(center + Vector2(-s * 0.2, s * 0.02), s * 0.14, light)
		"ration":
			var pts := PackedVector2Array()
			for i in 16:
				var a: float = i * TAU / 16.0
				pts.append(center + Vector2(cos(a) * s * 0.8, sin(a) * s * 0.5))
			ci.draw_colored_polygon(pts, dark)
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(center + (p - center) * 0.82 + Vector2(0, -s * 0.06))
			ci.draw_colored_polygon(inner, main)
			for k in 3:
				ci.draw_line(center + Vector2(-s * 0.4 + k * s * 0.4, -s * 0.25), center + Vector2(-s * 0.3 + k * s * 0.4, s * 0.1), dark, 2.0, true)
		"scroll":
			ci.draw_rect(Rect2(center + Vector2(-s * 0.55, -s * 0.6), Vector2(s * 1.1, s * 1.2)), _fade(Color("efe2bf"), alpha))
			ci.draw_rect(Rect2(center + Vector2(-s * 0.7, -s * 0.75), Vector2(s * 1.4, s * 0.24)), _fade(Color("c9b88f"), alpha))
			ci.draw_rect(Rect2(center + Vector2(-s * 0.7, s * 0.52), Vector2(s * 1.4, s * 0.24)), _fade(Color("c9b88f"), alpha))
			ci.draw_circle(center + Vector2(0, 0), s * 0.26, main)
			for k in 2:
				var y: float = -s * 0.32 + k * s * 0.64
				ci.draw_line(center + Vector2(-s * 0.4, y), center + Vector2(s * 0.4, y), _fade(Color("9c8b66"), alpha), 1.5)
		"gem":
			var gem := PackedVector2Array([center + Vector2(0, -s * 0.9), center + Vector2(s * 0.7, -s * 0.2),
				center + Vector2(0, s * 0.9), center + Vector2(-s * 0.7, -s * 0.2)])
			ci.draw_colored_polygon(gem, main)
			ci.draw_colored_polygon(PackedVector2Array([gem[0], gem[1], gem[2]]), dark)
			ci.draw_line(center + Vector2(-s * 0.3, -s * 0.3), center + Vector2(0, -s * 0.7), light, 2.0, true)
		"shield":
			var sh := PackedVector2Array([center + Vector2(-s * 0.7, -s * 0.75), center + Vector2(s * 0.7, -s * 0.75),
				center + Vector2(s * 0.62, s * 0.15), center + Vector2(0, s * 0.9), center + Vector2(-s * 0.62, s * 0.15)])
			ci.draw_colored_polygon(sh, dark)
			var inner_sh := PackedVector2Array()
			for p in sh:
				inner_sh.append(center + (p - center) * 0.75)
			ci.draw_colored_polygon(inner_sh, main)
			ci.draw_line(center + Vector2(0, -s * 0.55), center + Vector2(0, s * 0.6), light, 2.0, true)
		"heart":
			ci.draw_circle(center + Vector2(-s * 0.36, -s * 0.2), s * 0.42, main)
			ci.draw_circle(center + Vector2(s * 0.36, -s * 0.2), s * 0.42, main)
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 0.76, -s * 0.05),
				center + Vector2(s * 0.76, -s * 0.05), center + Vector2(0, s * 0.85)]), main)
			ci.draw_circle(center + Vector2(-s * 0.42, -s * 0.32), s * 0.13, light)
		_:
			ci.draw_circle(center, s * 0.6, main)

## Steps going down inside `rect`.
static func draw_stairs(ci: CanvasItem, rect: Rect2, color: Color, alpha: float = 1.0) -> void:
	var steps: int = 4
	var h: float = rect.size.y / (steps + 1)
	for i in steps:
		var inset: float = rect.size.x * 0.08 * i
		var r := Rect2(rect.position.x + inset + 3.0, rect.position.y + h * (i + 0.5),
			rect.size.x - inset * 2.0 - 6.0, h * 0.8)
		ci.draw_rect(r, _fade(color.darkened(0.12 * i), alpha))
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), _fade(color.lightened(0.3), alpha))

## Swirling exit portal.
static func draw_portal(ci: CanvasItem, center: Vector2, r: float, time: float, alpha: float = 1.0) -> void:
	var col := Color("7fe3ff")
	ci.draw_circle(center, r * 1.15, _fade(Color(col, 0.2), alpha))
	ci.draw_circle(center, r * 0.9, _fade(Color("0f2433"), alpha))
	for i in 3:
		var rr: float = r * (0.35 + i * 0.22)
		var start: float = time * (2.4 - i * 0.6) * (1.0 if i % 2 == 0 else -1.0) + i
		ci.draw_arc(center, rr, start, start + PI * 1.3, 16, _fade(col.lightened(i * 0.15), alpha), 2.5, true)
	ci.draw_circle(center, r * 0.16, _fade(Color.WHITE, alpha))

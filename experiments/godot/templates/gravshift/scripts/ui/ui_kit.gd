class_name UiKit
extends RefCounted

# UiKit: drawing helpers shared by the HUD, the screens and the floating
# texts, so every panel, bar and title has the same look.
#   FONTS    the engine's built-in font (the project has no font file),
#            emboldened through FontVariation: regular, bold, heavy (titles,
#            wider letter spacing).
#   TEXT     outlined text, aligned left, centred or right of a point.
#   PANEL    a dark translucent plate with two cut corners and a thin border.
#   BAR      a gauge with an optional tick every n-th of its length.
#   ICONS    one small animated drawing per upgrade (cards, HUD, pause).

const INK: Color = Color(0.0, 0.01, 0.06, 0.88)
const CYAN: Color = Color(0.45, 0.95, 1.0)
const DIM: Color = Color(0.55, 0.65, 0.88)
const PALE: Color = Color(0.85, 0.92, 1.0)
const GOLD: Color = Color(1.0, 0.84, 0.45)
const DANGER: Color = Color(1.0, 0.35, 0.42)

static var _bold: FontVariation = null
static var _heavy: FontVariation = null

static func regular() -> Font:
	return ThemeDB.fallback_font

static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.55
	return _bold

static func heavy() -> Font:
	if _heavy == null:
		_heavy = FontVariation.new()
		_heavy.base_font = ThemeDB.fallback_font
		_heavy.variation_embolden = 1.1
		_heavy.spacing_glyph = 3
	return _heavy

static func width(label: String, size: int, font: Font = null) -> float:
	var f: Font = font if font != null else regular()
	return f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## Outlined text; align 0 = starts at `at`, 0.5 = centred on it, 1 = ends at it.
static func text(ci: CanvasItem, at: Vector2, label: String, size: int, color: Color,
		align: float = 0.0, font: Font = null, outline: int = 4) -> void:
	var f: Font = font if font != null else regular()
	var p: Vector2 = at - Vector2(width(label, size, f) * align, 0.0)
	if outline > 0:
		ci.draw_string_outline(f, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(INK, INK.a * color.a))
	ci.draw_string(f, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

## Splits a label into lines no wider than `max_width`.
static func wrap(label: String, max_width: float, size: int, font: Font = null) -> PackedStringArray:
	var lines := PackedStringArray()
	var line: String = ""
	for word in label.split(" "):
		var test: String = word if line.is_empty() else line + " " + word
		if width(test, size, font) > max_width and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = test
	if not line.is_empty():
		lines.append(line)
	return lines

## Dark plate with the top-left and bottom-right corners cut.
static func panel(ci: CanvasItem, r: Rect2, border: Color, fill: Color = Color(0.02, 0.04, 0.11, 0.72), cut: float = 10.0, line: float = 1.5) -> void:
	var pts := PackedVector2Array([
		r.position + Vector2(cut, 0.0), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y - cut),
		r.end - Vector2(cut, 0.0), Vector2(r.position.x, r.end.y), r.position + Vector2(0.0, cut)])
	ci.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	ci.draw_polyline(pts, border, line)

## Gauge: background, fill, optional ticks (one every 1 / ticks of the length).
static func bar(ci: CanvasItem, r: Rect2, ratio: float, fill: Color, ticks: int = 0, back: Color = Color(0.05, 0.08, 0.18, 0.9)) -> void:
	ci.draw_rect(r.grow(2.0), Color(0.0, 0.0, 0.04, 0.8))
	ci.draw_rect(r, back)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y)), fill)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), maxf(r.size.y * 0.35, 1.0))), Color(1.0, 1.0, 1.0, 0.18))
	for k in range(1, ticks):
		var x: float = r.position.x + r.size.x * k / ticks
		ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0.0, 0.0, 0.05, 0.75), 2.0)

## Small animated drawing of an upgrade, about 60 px wide at s = 1.
static func upgrade_icon(ci: CanvasItem, id: String, at: Vector2, s: float, c: Color, time: float) -> void:
	match id:
		"orbit":
			ci.draw_arc(at, 28.0 * s, 0.0, TAU, 32, Color(c, 0.6), 2.0 * s)
			ci.draw_circle(at, 6.0 * s, c)
			for k in 8:
				ci.draw_circle(at + Vector2.RIGHT.rotated(time * 2.0 + TAU * k / 8.0) * 28.0 * s, 4.0 * s, c)
		"horizon":
			for k in 3:
				var rr: float = (12.0 + k * 9.0 + fmod(time * 8.0, 9.0)) * s
				ci.draw_arc(at, rr, 0.0, TAU, 32, Color(c, 1.0 - k * 0.3), 2.0 * s)
			ci.draw_circle(at, 5.0 * s, c)
		"sling":
			for k in 3:
				var off := Vector2(-20.0 + k * 20.0, 10.0 - k * 10.0) * s
				ci.draw_line(at + off - Vector2(18.0, 0.0) * s, at + off, Color(c, 0.5), 3.0 * s)
				ci.draw_circle(at + off, 5.0 * s, c)
		"tank":
			ci.draw_rect(Rect2(at - Vector2(14.0, 26.0) * s, Vector2(28.0, 52.0) * s), c, false, 2.5 * s)
			var lvl: float = 0.55 + 0.35 * sin(time * 2.0)
			ci.draw_rect(Rect2(at + Vector2(-10.0, 22.0 - 44.0 * lvl) * s, Vector2(20.0, 44.0 * lvl) * s), c)
		"twin":
			for sx in [-12.0, 12.0]:
				ci.draw_line(at + Vector2(sx, 20.0) * s, at + Vector2(sx, -24.0) * s, c, 3.0 * s)
				var y: float = fmod(time * 60.0 + sx, 40.0)
				ci.draw_circle(at + Vector2(sx, 18.0 - y) * s, 3.0 * s, c)
		"hull":
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -26) * s, at + Vector2(22, 0) * s, at + Vector2(0, 26) * s, at + Vector2(-22, 0) * s]), Color(c, 0.35))
			ci.draw_polyline(PackedVector2Array([at + Vector2(0, -26) * s, at + Vector2(22, 0) * s, at + Vector2(0, 26) * s, at + Vector2(-22, 0) * s, at + Vector2(0, -26) * s]), c, 2.5 * s)
			ci.draw_rect(Rect2(at - Vector2(2.5, 10.0) * s, Vector2(5.0, 20.0) * s), c)
			ci.draw_rect(Rect2(at - Vector2(10.0, 2.5) * s, Vector2(20.0, 5.0) * s), c)
		"shrapnel":
			ci.draw_circle(at, 6.0 * s, c)
			for k in 8:
				var a: float = TAU * k / 8.0
				var grow: float = fmod(time * 1.5, 1.0)
				ci.draw_line(at + Vector2.RIGHT.rotated(a) * (8.0 + 10.0 * grow) * s, at + Vector2.RIGHT.rotated(a) * (18.0 + 10.0 * grow) * s, Color(c, 1.0 - grow * 0.7), 2.5 * s)
		"pierce":
			ci.draw_arc(at + Vector2(-10.0, 0.0) * s, 10.0 * s, 0.0, TAU, 20, Color(c, 0.6), 2.0 * s)
			ci.draw_arc(at + Vector2(14.0, 0.0) * s, 10.0 * s, 0.0, TAU, 20, Color(c, 0.6), 2.0 * s)
			var x: float = lerpf(-32.0, 32.0, fmod(time * 0.8, 1.0))
			ci.draw_line(at + Vector2(-32.0, 0.0) * s, at + Vector2(x, 0.0) * s, c, 3.0 * s)
			ci.draw_circle(at + Vector2(x, 0.0) * s, 4.0 * s, c)
		"grinder":
			for k in 6:
				var a2: float = -time * 3.0 + TAU * k / 6.0
				ci.draw_line(at + Vector2.RIGHT.rotated(a2) * 8.0 * s, at + Vector2.RIGHT.rotated(a2) * 28.0 * s, c, 3.0 * s)
			ci.draw_arc(at, 8.0 * s, 0.0, TAU, 16, c, 2.0 * s)
		"recoil":
			for k in 3:
				var rr2: float = fmod(time * 30.0 + k * 10.0, 30.0)
				ci.draw_arc(at, rr2 * s, 0.0, TAU, 32, Color(c, 1.0 - rr2 / 30.0), 2.0 * s)
		"magnet":
			ci.draw_arc(at + Vector2(0.0, -2.0) * s, 16.0 * s, 0.0, PI, 20, c, 6.0 * s)
			ci.draw_line(at + Vector2(-16.0, -2.0) * s, at + Vector2(-16.0, -18.0) * s, c, 6.0 * s)
			ci.draw_line(at + Vector2(16.0, -2.0) * s, at + Vector2(16.0, -18.0) * s, c, 6.0 * s)
			for k in 3:
				var y2: float = fmod(time * 40.0 + k * 13.0, 40.0)
				ci.draw_circle(at + Vector2(-14.0 + k * 14.0, -60.0 + y2) * s, 2.5 * s, Color(c, y2 / 40.0))
		"supernova":
			var pulse: float = 1.0 + 0.15 * sin(time * 5.0)
			for k in 10:
				var a3: float = TAU * k / 10.0 + time * 0.6
				var r3: float = (24.0 if k % 2 == 0 else 14.0) * pulse
				ci.draw_line(at + Vector2.RIGHT.rotated(a3) * 6.0 * s, at + Vector2.RIGHT.rotated(a3) * r3 * s, c, 2.5 * s)
			ci.draw_circle(at, 7.0 * s, c)

# =============================================================================
# Background.gd — Sky, sun, ambience and parallax silhouettes
# =============================================================================
# Lives in a CanvasLayer behind the level and reads the camera from the
# viewport canvas transform, so it needs no reference to the camera (and it
# follows the interpolated camera exactly).
#
# PARALLAX: a layer with factor f scrolls at f x the camera speed: far
# layers (small f) barely move, near ones move almost with the level. The
# silhouette height at screen column sx is a function of the world-space
# coordinate cam.x * f + sx, so the shapes are stable and endless.
# Vertically, layers sink when the camera climbs (factor * 0.5).
#
# Styles: hills, mountains, pines, canopy, mesas, crystals.
# Ambience: clouds (drift), stars (twinkle), motes (floating glows).
# =============================================================================

class_name Background
extends Node2D

var theme: Dictionary = {}
var level_height: float = 720.0
var auto_scroll: bool = false
var _scroll: float = 0.0
var _time: float = 0.0

func set_theme(data: Dictionary, height_px: float) -> void:
	theme = data
	level_height = height_px
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if auto_scroll:
		_scroll += delta * 40.0
	queue_redraw()

func _color(key: String, fallback: Color) -> Color:
	return Color(str(theme[key])) if theme.has(key) else fallback

func _camera() -> Vector2:
	if auto_scroll:
		return Vector2(_scroll, level_height - get_viewport_rect().size.y)
	return -get_viewport().get_canvas_transform().origin

func _draw() -> void:
	var view: Vector2 = get_viewport_rect().size
	var cam: Vector2 = _camera()
	var top: Color = _color("sky_top", Color("7ec8e3"))
	var bottom: Color = _color("sky_bottom", Color("fce8c8"))
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(view.x, 0.0), view, Vector2(0.0, view.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	var ambience: String = str(theme.get("ambience", "clouds"))
	if ambience == "stars":
		_draw_stars(view, cam)
	if theme.has("sun"):
		var sun: Array = theme["sun"] as Array
		var at := Vector2(float(sun[0]) * view.x - cam.x * 0.02, float(sun[1]) * view.y)
		var c: Color = _color("sun_color", Color("fff3c4"))
		Pickups.glow(self, at, 160.0, c, 1.6)
		draw_circle(at, 46.0, c)
	if ambience == "clouds":
		_draw_clouds(view, cam)
	var layers: Array = theme.get("layers", []) as Array
	for layer in layers:
		_draw_layer(layer as Dictionary, view, cam)
	if ambience == "motes":
		_draw_motes(view, cam)

func _vertical_offset(cam: Vector2, view: Vector2, factor: float) -> float:
	return (cam.y - (level_height - view.y)) * factor * 0.5

func _draw_layer(layer: Dictionary, view: Vector2, cam: Vector2) -> void:
	var factor: float = float(layer.get("factor", 0.3))
	var color := Color(str(layer.get("color", "5e9a6e")))
	var base: float = float(layer.get("base", 0.7)) * view.y - _vertical_offset(cam, view, factor)
	var amp: float = float(layer.get("amp", 120.0))
	var seed_value: float = float(layer.get("seed", 1.0))
	var style: String = str(layer.get("style", "hills"))
	var shift: float = cam.x * factor
	match style:
		"mesas":
			_draw_mesas(view, shift, base, amp, seed_value, color)
			return
		"crystals":
			_draw_crystals(view, shift, base, amp, seed_value, color)
			return
	var points := PackedVector2Array()
	var step: float = 12.0
	var sx: float = -step
	while sx <= view.x + step:
		var wx: float = sx + shift
		points.append(Vector2(sx, minf(base - _height(style, wx, amp, seed_value), view.y + 4.0)))
		sx += step
	points.append(Vector2(view.x + step, view.y + 10.0))
	points.append(Vector2(-step, view.y + 10.0))
	draw_colored_polygon(points, color)
	if style == "pines":
		_draw_pines(view, shift, base, amp, seed_value, color)
	elif style == "canopy":
		_draw_trunks(view, shift, base, amp, seed_value, color)

func _height(style: String, wx: float, amp: float, s: float) -> float:
	match style:
		"mountains":
			var a: float = absf(fmod(wx * 0.0021 + s, 1.0) - 0.5) * 2.0
			var b: float = absf(fmod(wx * 0.0053 + s * 1.7, 1.0) - 0.5) * 2.0
			return amp * (0.25 + 0.55 * (1.0 - a) + 0.2 * (1.0 - b))
		"canopy":
			return amp * (0.6 + 0.2 * sin(wx * 0.013 + s) + 0.2 * sin(wx * 0.031 + s * 3.0))
	return amp * (0.5 + 0.3 * sin(wx * 0.0041 + s) + 0.2 * sin(wx * 0.0113 + s * 2.0))

func _draw_pines(view: Vector2, shift: float, base: float, amp: float, s: float, color: Color) -> void:
	var spacing: float = 34.0
	var first: int = floori((shift - 40.0) / spacing)
	var last: int = ceili((shift + view.x + 40.0) / spacing)
	for i in range(first, last + 1):
		var h: int = TileChunk.cell_hash(i, int(s * 10.0))
		if h % 3 == 0:
			continue
		var wx: float = i * spacing + float(h % 14)
		var sx: float = wx - shift
		var ground: float = base - _height("pines", wx, amp, s)
		var tall: float = 40.0 + float(h % 50)
		draw_colored_polygon(PackedVector2Array([Vector2(sx - tall * 0.22, ground + 4.0), Vector2(sx, ground - tall), Vector2(sx + tall * 0.22, ground + 4.0)]), color)

func _draw_trunks(view: Vector2, shift: float, base: float, amp: float, s: float, color: Color) -> void:
	var spacing: float = 140.0
	var first: int = floori((shift - 100.0) / spacing)
	var last: int = ceili((shift + view.x + 100.0) / spacing)
	for i in range(first, last + 1):
		var h: int = TileChunk.cell_hash(i, int(s * 7.0))
		var wx: float = i * spacing + float(h % 60)
		var sx: float = wx - shift
		var width: float = 14.0 + float(h % 18)
		var top_y: float = base - _height("canopy", wx, amp, s) + 10.0
		draw_rect(Rect2(sx - width * 0.5, top_y, width, view.y - top_y + 10.0), color)
		draw_rect(Rect2(sx - width * 0.5 - 30.0, top_y + 60.0 + float(h % 80), 32.0, 6.0), color)

func _draw_mesas(view: Vector2, shift: float, base: float, amp: float, s: float, color: Color) -> void:
	var seg: float = 230.0
	var first: int = floori((shift - seg) / seg)
	var last: int = ceili((shift + view.x + seg) / seg)
	for i in range(first, last + 1):
		var h: int = TileChunk.cell_hash(i, int(s * 13.0))
		if h % 4 == 0:
			continue
		var x0: float = i * seg - shift + float(h % 50)
		var width: float = 120.0 + float((h >> 4) % 140)
		var height: float = amp * (0.45 + float((h >> 8) % 55) / 100.0)
		var top_y: float = base - height
		draw_colored_polygon(PackedVector2Array([Vector2(x0, view.y + 10.0), Vector2(x0 + 18.0, top_y + 10.0), Vector2(x0 + 26.0, top_y),
			Vector2(x0 + width - 26.0, top_y), Vector2(x0 + width - 18.0, top_y + 10.0), Vector2(x0 + width, view.y + 10.0)]), color)
		draw_rect(Rect2(x0 + 26.0, top_y + height * 0.35, width - 52.0, 4.0), color.darkened(0.12))
	draw_rect(Rect2(0.0, base, view.x, view.y - base + 10.0), color)

func _draw_crystals(view: Vector2, shift: float, base: float, amp: float, s: float, color: Color) -> void:
	var spacing: float = 70.0
	var first: int = floori((shift - spacing) / spacing)
	var last: int = ceili((shift + view.x + spacing) / spacing)
	for i in range(first, last + 1):
		var h: int = TileChunk.cell_hash(i, int(s * 17.0))
		var sx: float = i * spacing - shift + float(h % 30)
		var width: float = 16.0 + float(h % 22)
		var up: float = amp * (0.3 + float((h >> 5) % 70) / 100.0)
		var down: float = amp * (0.2 + float((h >> 9) % 60) / 100.0)
		draw_colored_polygon(PackedVector2Array([Vector2(sx - width * 0.5, view.y + 10.0), Vector2(sx, base - up), Vector2(sx + width * 0.5, view.y + 10.0)]), color)
		if h % 2 == 0:
			var ceiling: float = base - view.y * 0.62
			draw_colored_polygon(PackedVector2Array([Vector2(sx - width * 0.4 + 30.0, ceiling - 200.0), Vector2(sx + width * 0.4 + 30.0, ceiling - 200.0), Vector2(sx + 30.0, ceiling + down)]), color)
	draw_rect(Rect2(0.0, base, view.x, view.y - base + 10.0), color)

func _draw_clouds(view: Vector2, cam: Vector2) -> void:
	var c := Color(1.0, 1.0, 1.0, 0.55)
	var spacing: float = 420.0
	var shift: float = cam.x * 0.06 - _time * 8.0
	var first: int = floori((shift - spacing) / spacing)
	var last: int = ceili((shift + view.x + spacing) / spacing)
	for i in range(first, last + 1):
		var h: int = TileChunk.cell_hash(i, 99)
		var sx: float = i * spacing - shift + float(h % 120)
		var sy: float = 50.0 + float((h >> 4) % 170) - _vertical_offset(cam, view, 0.06)
		var size: float = 0.7 + float((h >> 9) % 50) / 100.0
		for k in 4:
			var off := Vector2((k - 1.5) * 34.0 * size, -absf(k - 1.5) * -8.0 * size)
			PlayerArt.ellipse(self, Vector2(sx, sy) + off, 34.0 * size, 20.0 * size, c)

func _draw_stars(view: Vector2, cam: Vector2) -> void:
	for i in 90:
		var h: int = TileChunk.cell_hash(i, 7)
		var sx: float = fposmod(float(h % 4000) - cam.x * 0.02, view.x)
		var sy: float = float((h >> 6) % 1000) / 1000.0 * view.y * 0.75
		var tw: float = 0.5 + 0.5 * sin(_time * (1.0 + float(h % 5)) + float(i))
		draw_circle(Vector2(sx, sy), 1.0 + float(h % 3) * 0.5, Color(1.0, 1.0, 0.95, 0.35 + 0.5 * tw))

func _draw_motes(view: Vector2, cam: Vector2) -> void:
	var c: Color = _color("mote_color", Color("e6f58a"))
	for i in 28:
		var h: int = TileChunk.cell_hash(i, 31)
		var sx: float = fposmod(float(h % 3000) - cam.x * 0.4 + sin(_time * 0.5 + i) * 30.0, view.x + 40.0) - 20.0
		var sy: float = fposmod(float((h >> 7) % 1000) / 1000.0 * view.y - _time * (6.0 + float(h % 9)) - cam.y * 0.2, view.y)
		var pulse: float = 0.5 + 0.5 * sin(_time * 2.0 + i)
		Pickups.glow(self, Vector2(sx, sy), 12.0, c, 0.6 + pulse)
		draw_circle(Vector2(sx, sy), 1.6, Color(c, 0.5 + 0.5 * pulse))

# =============================================================================
# PixelArt.gd: pixel-art sprites built from data/sprites.json.
# =============================================================================
# Each sprite is a 16 x 16 grid of characters, one per pixel: "." is
# transparent, every other character is a colour of the sprite's palette
# ("k" is the shared dark outline). At first use every frame becomes an
# ImageTexture, plus a white silhouette of the same shape used for the hit
# flash. The map draws them at twice their size with nearest filtering, so
# every pixel stays a crisp 2 x 2 square.
#
# FRAMES: a sprite with one frame gets a second one generated for the idle
# animation: everything above the feet sinks by one pixel (breathing).
# Sprites with two hand-drawn frames (bat wings, slime, torch flame) use them.
#
# TINT: a sprite may name one palette character as "tint" (the scroll's
# seal): "scroll@7cc4ff" draws it with that character in #7cc4ff, so the
# three scrolls share one drawing and differ by their item colour.
# =============================================================================

class_name PixelArt
extends RefCounted

const PATH: String = "res://data/sprites.json"

static var _defs: Dictionary = {}
static var _tex: Dictionary = {}      # id -> Array[Texture2D]
static var _white: Dictionary = {}    # id -> Array[Texture2D]
static var _outline: Color = Color("1b1424")
static var _top: Dictionary = {}      # id -> first non-empty row (0..15)

static func _load() -> void:
	if not _defs.is_empty():
		return
	var text: String = FileAccess.get_file_as_string(PATH)
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("PixelArt: cannot parse " + PATH)
		return
	var data: Dictionary = json.get_data() as Dictionary
	_defs = data.get("sprites", {}) as Dictionary
	_outline = Color("#" + str(data.get("outline", "1b1424")))

## Textures of a sprite, built at first use. "scroll@7cc4ff" is the sprite
## "scroll" with its tint character (the "tint" field, here the seal)
## painted in that colour: one drawing, one variant per item colour.
static func _frames(id: String) -> Array:
	_load()
	if _tex.has(id):
		return _tex[id] as Array
	var base: String = id
	var tint_hex: String = ""
	if id.contains("@"):
		base = id.get_slice("@", 0)
		tint_hex = id.get_slice("@", 1)
	if not _defs.has(base):
		return []
	var spr: Dictionary = _defs[base]
	var pal: Dictionary = {"k": _outline}
	for ch in (spr.get("palette", {}) as Dictionary):
		pal[ch] = Color("#" + str(spr["palette"][ch]))
	if not tint_hex.is_empty() and spr.has("tint"):
		var tint := Color("#" + tint_hex)
		pal[str(spr["tint"])] = tint
		if spr.has("tint_light"):
			pal[str(spr["tint_light"])] = tint.lightened(0.4)
	var rows_list: Array = (spr.get("frames", []) as Array).duplicate()
	var top: int = 16
	for rows in rows_list:
		for y in (rows as Array).size():
			if str(rows[y]).replace(".", "") != "":
				top = mini(top, y)
				break
	_top[id] = top
	if rows_list.size() == 1:
		rows_list.append(_breathe(rows_list[0] as Array))
	var textures: Array[Texture2D] = []
	var whites: Array[Texture2D] = []
	for rows in rows_list:
		textures.append(_make(rows as Array, pal, false))
		whites.append(_make(rows as Array, pal, true))
	_tex[id] = textures
	_white[id] = whites
	return textures

## Sprite id of an item on the map or in the inventory (tinted if the
## drawing has a tint character, e.g. the three scrolls).
static func item_sprite(item: Dictionary) -> String:
	_load()
	var id: String = str(item.get("sprite", ""))
	if (_defs.get(id, {}) as Dictionary).has("tint"):
		return id + "@" + str(item.get("color", "ffffff"))
	return id

## Second idle frame: the rows above the feet move down one pixel.
static func _breathe(rows: Array) -> Array:
	var out: Array = rows.duplicate()
	var feet: int = 3
	var top: int = 0
	for y in rows.size():
		if str(rows[y]).replace(".", "") != "":
			top = y
			break
	for y in range(rows.size() - feet - 1, top, -1):
		out[y] = rows[y - 1]
	out[top] = "................"
	return out

static func _make(rows: Array, pal: Dictionary, white: bool) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in mini(rows.size(), 16):
		var row: String = str(rows[y])
		for x in mini(row.length(), 16):
			var ch: String = row[x]
			if ch == "." or not pal.has(ch):
				continue
			img.set_pixel(x, y, Color.WHITE if white else pal[ch] as Color)
	return ImageTexture.create_from_image(img)

static func has(id: String) -> bool:
	return not _frames(id).is_empty()

static func frame_count(id: String) -> int:
	return _frames(id).size()

## Share of the sprite height that is empty above the drawing (0..1): a
## slime is short, its health bar sits lower than an orc's.
static func headroom(id: String) -> float:
	_frames(id)
	return float(_top.get(id, 0)) / 16.0

## Display scale of the sprite relative to a tile (troll and boss are bigger).
static func scale_of(id: String) -> float:
	_load()
	return float((_defs.get(id.get_slice("@", 0), {}) as Dictionary).get("scale", 1.0))

static func texture(id: String, frame: int = 0) -> Texture2D:
	var list: Array = _frames(id)
	if list.is_empty():
		return null
	return list[posmod(frame, list.size())] as Texture2D

## Draws the sprite with its feet at `foot` (bottom centre), `size` pixels
## wide. flip mirrors it (facing left); flash 0..1 whitens it (hit).
static func draw(ci: CanvasItem, id: String, foot: Vector2, size: float, frame: int = 0,
		flip: bool = false, modulate: Color = Color.WHITE, flash: float = 0.0) -> void:
	var list: Array = _frames(id)
	if list.is_empty():
		return
	var tex: Texture2D = list[posmod(frame, list.size())] as Texture2D
	var rect := Rect2(foot - Vector2(size * 0.5, size), Vector2(size, size))
	if flip:
		# a negative width mirrors the texture inside the same rectangle
		rect = Rect2(rect.position, Vector2(-size, size))
	ci.draw_texture_rect(tex, rect, false, modulate)
	if flash > 0.01:
		var wtex: Texture2D = (_white[id] as Array)[posmod(frame, list.size())] as Texture2D
		ci.draw_texture_rect(wtex, rect, false, Color(1, 1, 1, flash * modulate.a))

## Draws only the silhouette of the sprite, filled with `color` (dash
## afterimages, the red glow of an enemy winding up a blow).
static func draw_silhouette(ci: CanvasItem, id: String, foot: Vector2, size: float, frame: int,
		flip: bool, color: Color) -> void:
	var list: Array = _frames(id)
	if list.is_empty():
		return
	var rect := Rect2(foot - Vector2(size * 0.5, size), Vector2(size, size))
	if flip:
		rect = Rect2(rect.position, Vector2(-size, size))
	ci.draw_texture_rect((_white[id] as Array)[posmod(frame, list.size())] as Texture2D, rect, false, color)

## Draws the sprite centred in `rect` (inventory slots, look box).
static func draw_icon(ci: CanvasItem, id: String, rect: Rect2, frame: int = 0, modulate: Color = Color.WHITE) -> void:
	var tex: Texture2D = texture(id, frame)
	if tex == null:
		return
	var s: float = floorf(minf(rect.size.x, rect.size.y) / 16.0) * 16.0
	if s < 16.0:
		s = minf(rect.size.x, rect.size.y)
	var r := Rect2(rect.get_center() - Vector2(s, s) * 0.5, Vector2(s, s))
	ci.draw_texture_rect(tex, r, false, modulate)

# =============================================================================
# TileArt.gd: pixel-art floor and wall textures, generated per floor theme.
# =============================================================================
# Every texture is 16 x 16 pixels (drawn at 32 x 32), painted with the four
# colours of the floor theme (config.json, floor_themes):
#   floor_0..3  flagstones: two or three stones split by dark mortar, speckles
#               and the odd crack; four variants picked per cell by a hash, so
#               the floor never shows a visible repeat
#   wall_top    the top of a wall block, seen from above: darker than the
#               floor, with a light and a dark rim
#   wall_front  a wall with floor below it: a strip of top, then rows of
#               bricks in staggered courses, shaded towards the bottom
# Generated once per floor (seeded by the floor number): same floor, same
# look.
# =============================================================================

class_name TileArt
extends RefCounted

var textures: Dictionary = {}

func build(theme: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var floor_a: Color = Color("#" + str(theme.get("floor", "394057")))
	var floor_b: Color = Color("#" + str(theme.get("floor_alt", "3d445c")))
	var wall: Color = Color("#" + str(theme.get("wall", "4b5468")))
	var wall_top: Color = Color("#" + str(theme.get("wall_top", "68728a")))
	for i in 4:
		textures["floor_%d" % i] = _floor(floor_a.lerp(floor_b, i / 3.0).lightened(0.1), rng, i)
	textures["wall_top"] = _wall_top(wall_top, wall, rng)
	textures["wall_front"] = _wall_front(wall_top, wall, rng)

func get_texture(id: String) -> Texture2D:
	return textures.get(id) as Texture2D

func _floor(base: Color, rng: RandomNumberGenerator, variant: int) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var mortar: Color = base.darkened(0.38)
	var split_x: int = rng.randi_range(5, 10)
	var split_y: int = rng.randi_range(6, 10)
	var vertical_first: bool = variant % 2 == 0
	for y in 16:
		for x in 16:
			var c: Color = base
			var stone: int = 0
			if vertical_first:
				stone = 0 if x < split_x else (1 if y < split_y else 2)
			else:
				stone = 0 if y < split_y else (1 if x < split_x else 2)
			c = c.lightened(0.04 * stone) if stone != 1 else c.darkened(0.03)
			var n: float = rng.randf()
			if n < 0.08:
				c = c.darkened(0.12)
			elif n < 0.13:
				c = c.lightened(0.08)
			img.set_pixel(x, y, c)
	for i in 16:
		img.set_pixel(i, 0, mortar)
		img.set_pixel(0, i, mortar)
		if vertical_first:
			img.set_pixel(split_x, i, mortar)
			if i > split_x:
				img.set_pixel(i, split_y, mortar)
		else:
			img.set_pixel(i, split_y, mortar)
			if i > split_y:
				img.set_pixel(split_x, i, mortar)
	if variant == 3:
		var cx: int = rng.randi_range(3, 12)
		var cy: int = rng.randi_range(3, 12)
		for k in 5:
			img.set_pixel(clampi(cx + k, 1, 15), clampi(cy + (k % 2), 1, 15), mortar.darkened(0.2))
	return ImageTexture.create_from_image(img)

func _wall_top(top: Color, side: Color, rng: RandomNumberGenerator) -> Texture2D:
	# The top of the wall mass is darker than the floor, framed by a light
	# rim (top, left) and a dark one (bottom, right): it reads as a block.
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var base: Color = side.darkened(0.52).lerp(top, 0.08)
	for y in 16:
		for x in 16:
			var c: Color = base
			if x == 0 or y == 0:
				c = side.darkened(0.22)
			elif x == 15 or y == 15:
				c = side.darkened(0.72)
			else:
				var n: float = rng.randf()
				if n < 0.08:
					c = base.darkened(0.25)
				elif n < 0.12:
					c = base.lightened(0.1)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _wall_front(top: Color, side: Color, rng: RandomNumberGenerator) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var top_h: int = 5
	for y in 16:
		for x in 16:
			var c: Color
			if y < top_h:
				c = top if y > 0 else top.lightened(0.15)
				if y == top_h - 1:
					c = top.darkened(0.25)
			else:
				var course: int = floori((y - top_h) / 4.0)
				var offset: int = 4 if course % 2 == 0 else 0
				var mortar: bool = (y - top_h) % 4 == 3 or (x + offset) % 8 == 7
				var depth: float = float(y - top_h) / float(16 - top_h)
				c = side.darkened(0.1 + depth * 0.25)
				if mortar:
					c = side.darkened(0.55)
				elif rng.randf() < 0.1:
					c = c.lightened(0.06)
				elif (y - top_h) % 4 == 0:
					c = c.lightened(0.08)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

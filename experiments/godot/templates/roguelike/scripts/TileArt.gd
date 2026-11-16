# =============================================================================
# TileArt.gd: pixel-art floor and wall textures, generated per floor theme.
# =============================================================================
# Every texture is 16 x 16 pixels (drawn at 32 x 32), painted with the four
# base colours of the floor theme (config.json, floor_themes). Colours stay
# fairly light and neutral: the mood (cool shadows, warm pools of torch
# light) comes from the lighting in DungeonView, which multiplies them.
#
#   floor_0..7   irregular flagstones: the cell is split into one to four
#                rectangles of random sizes (_layout), separated by a dark
#                joint. Stones are bevelled (light top-left edge, dark
#                bottom-right), rounded and chipped at the corners, nicked
#                along the edges, speckled; variant 4 has a crack, 6 a
#                missing stone (bare earth), 7 some moss. A first try with a
#                Voronoi diagram gave long diagonal joints that read as
#                hatching rather than paving (2026-11-16).
#   wall_low_*   the lower half of a wall face (a wall with floor below):
#                staggered terracotta bricks, a dark plinth at the bottom
#   wall_high_*  the upper half of the face, drawn on the wall cell above:
#                the capstone seen from the front, then bricks. Together
#                they make walls two cells tall, as in a 3/4 view.
#   wall_single_* a face whose cell above is open (a one-cell-thick wall):
#                capstone, bricks and plinth in one cell
#   wall_cap_*   the top of a wall seen from above (side walls, corners):
#                capstone blocks, darker than the front
# Generated once per floor (seeded by the floor number): same floor, same
# look. variant_for() picks a stable variant per cell from a hash.
# =============================================================================

class_name TileArt
extends RefCounted

const FLOOR_VARIANTS: int = 8
const SHADOW := Color(0.10, 0.07, 0.17)   # joints and mortar lean to violet

var textures: Dictionary = {}

func build(theme: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var floor_a: Color = Color("#" + str(theme.get("floor", "6c8c8e")))
	var floor_b: Color = Color("#" + str(theme.get("floor_alt", "5f7f84")))
	var brick: Color = Color("#" + str(theme.get("wall", "a65c47")))
	var cap: Color = Color("#" + str(theme.get("wall_top", "5e8985")))
	textures.clear()
	for i in FLOOR_VARIANTS:
		textures["floor_%d" % i] = _floor(floor_a, floor_b, rng, i)
	for i in 3:
		textures["wall_low_%d" % i] = _wall_face(brick, cap, rng, false, true)
		textures["wall_cap_%d" % i] = _wall_cap(cap, rng)
	for i in 2:
		textures["wall_high_%d" % i] = _wall_face(brick, cap, rng, true, false)
		textures["wall_single_%d" % i] = _wall_face(brick, cap, rng, true, true)

func get_texture(id: String) -> Texture2D:
	return textures.get(id) as Texture2D

## Stable variant for a cell: weights favour plain two- and three-stone
## tiles; cracks, missing stones and moss stay rare.
static func variant_for(p: Vector2i, count: int, salt: int = 0) -> int:
	var h: int = absi((p.x * 73856093) ^ (p.y * 19349663) ^ (salt * 83492791)) % 100
	if count != FLOOR_VARIANTS:
		return h % count
	var weights: Array[int] = [20, 20, 20, 12, 8, 6, 5, 9]
	var acc: int = 0
	for i in weights.size():
		acc += weights[i]
		if h < acc:
			return i
	return 0

# ---------------------------------------------------------------------------
# Floor
# ---------------------------------------------------------------------------

## Stone layouts: the 15 x 15 area right of and below the joint row and
## column is split into rectangles ([x, y, w, h], joints between them).
func _layout(variant: int, rng: RandomNumberGenerator) -> Array:
	var a: int = rng.randi_range(6, 9)
	var b: int = rng.randi_range(6, 9)
	var c: int = rng.randi_range(5, 10)
	match variant:
		0:
			return [[1, 1, 15, 15]]
		1:
			return [[1, 1, a - 1, 15], [a + 1, 1, 15 - a, 15]]
		2:
			return [[1, 1, 15, a - 1], [1, a + 1, 15, 15 - a]]
		3, 6:
			return [[1, 1, a - 1, 15], [a + 1, 1, 15 - a, b - 1], [a + 1, b + 1, 15 - a, 15 - b]]
		4:
			return [[1, 1, 15, a - 1], [1, a + 1, c - 1, 15 - a], [c + 1, a + 1, 15 - c, 15 - a]]
		5:
			return [[1, 1, a - 1, b - 1], [a + 1, 1, 15 - a, b - 1], [1, b + 1, c - 1, 15 - b], [c + 1, b + 1, 15 - c, 15 - b]]
		_:
			return [[1, 1, 15, a - 1], [1, a + 1, 15, 15 - a]] if rng.randf() < 0.5 else [[1, 1, a - 1, 15], [a + 1, 1, 15 - a, 15]]

func _floor(base_a: Color, base_b: Color, rng: RandomNumberGenerator, variant: int) -> Texture2D:
	var rects: Array = _layout(variant, rng)
	var n: int = rects.size()
	var shades: Array[Color] = []
	for i in n:
		var c: Color = base_a.lerp(base_b, rng.randf())
		shades.append(c.lightened(rng.randf_range(0.0, 0.09)) if rng.randf() < 0.5 else c.darkened(rng.randf_range(0.0, 0.09)))
	# owner[y][x]: stone index, or -1 for a joint
	var owner: Array = []
	for y in 16:
		var row: Array[int] = []
		row.resize(16)
		row.fill(-1)
		owner.append(row)
	for i in n:
		var r: Array = rects[i]
		for y in range(int(r[1]), int(r[1]) + int(r[3])):
			for x in range(int(r[0]), int(r[0]) + int(r[2])):
				if x < 16 and y < 16:
					owner[y][x] = i
	# rounded, chipped corners and a few nicks along the edges
	var chipped: Array = owner.duplicate(true)
	for y in range(1, 16):
		for x in range(1, 16):
			if int(owner[y][x]) < 0:
				continue
			var up: bool = _joint(owner, x, y - 1)
			var dn: bool = _joint(owner, x, y + 1)
			var lf: bool = _joint(owner, x - 1, y)
			var rt: bool = _joint(owner, x + 1, y)
			if (up and lf) or (up and rt) or (dn and lf) or (dn and rt):
				if rng.randf() < 0.85:
					chipped[y][x] = -1
			elif (up or dn or lf or rt) and rng.randf() < 0.07:
				chipped[y][x] = -1
	owner = chipped
	var missing: int = rng.randi_range(0, n - 1) if variant == 6 else -1
	var joint: Color = base_a.darkened(0.58).lerp(SHADOW, 0.4)
	var dirt := Color(0.21, 0.17, 0.22)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var id: int = int(owner[y][x])
			if id < 0:
				img.set_pixel(x, y, joint if rng.randf() > 0.12 else joint.lightened(0.12))
				continue
			if id == missing:
				var g: float = rng.randf()
				img.set_pixel(x, y, dirt.lightened(0.25) if g < 0.14 else (dirt.darkened(0.2) if g < 0.3 else dirt))
				continue
			var c: Color = shades[id]
			if _joint(owner, x, y - 1):
				c = c.lightened(0.14)
			elif _joint(owner, x - 1, y):
				c = c.lightened(0.07)
			if _joint(owner, x, y + 1):
				c = c.darkened(0.2)
			elif _joint(owner, x + 1, y):
				c = c.darkened(0.1)
			var s: float = rng.randf()
			if s < 0.06:
				c = c.darkened(0.1)
			elif s < 0.1:
				c = c.lightened(0.06)
			if variant == 7 and (_joint(owner, x, y - 1) or _joint(owner, x - 1, y) or _joint(owner, x + 1, y)) and rng.randf() < 0.55:
				c = c.lerp(Color(0.38, 0.55, 0.32), 0.55)
			img.set_pixel(x, y, c)
	if variant == 4:   # a jagged crack across the largest stone
		var x: int = rng.randi_range(4, 7)
		var y: int = rng.randi_range(3, 6)
		for k in 7:
			if x < 16 and y < 16 and int(owner[y][x]) >= 0:
				img.set_pixel(x, y, joint.darkened(0.15))
			x += 1
			y += rng.randi_range(0, 1)
	return ImageTexture.create_from_image(img)

## Joint test with the cell edges counted as joints (the neighbour tiles
## start with a joint row and column: bevels stay consistent across tiles).
func _joint(owner: Array, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x > 15 or y > 15:
		return true
	return int(owner[y][x]) < 0

# ---------------------------------------------------------------------------
# Walls
# ---------------------------------------------------------------------------

## A wall face. with_cap: the capstone seen from the front on the top 4
## rows (upper half or one-cell wall). plinth: a dark base on the bottom 2
## rows (the wall meets the floor).
func _wall_face(brick: Color, cap: Color, rng: RandomNumberGenerator, with_cap: bool, plinth: bool) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var mortar: Color = brick.darkened(0.6).lerp(SHADOW, 0.35)
	var y0: int = 5 if with_cap else 0
	var y1: int = 14 if plinth else 16
	var shift: int = rng.randi_range(0, 6)
	var shades: Dictionary = {}
	for y in range(y0, y1):
		var course: int = floori((y - y0) / 4.0)
		var r: int = (y - y0) % 4
		var off: int = shift + (3 if course % 2 == 1 else 0)
		for x in 16:
			var bx: int = floori((x + off) / 7.0)
			var key: int = course * 10 + bx
			if not shades.has(key):
				var v: float = rng.randf()
				var c: Color = brick.lightened(rng.randf_range(0.0, 0.1)) if v < 0.5 else brick.darkened(rng.randf_range(0.0, 0.12))
				if v > 0.9:
					c = brick.darkened(0.25).lerp(SHADOW, 0.15)   # a scorched brick
				shades[key] = c
			var col: Color
			if r == 3 or (x + off) % 7 == 6:
				col = mortar
			else:
				col = shades[key] as Color
				if r == 0:
					col = col.lightened(0.12)
				elif r == 2:
					col = col.darkened(0.08)
				if rng.randf() < 0.05:
					col = col.darkened(0.18)
			img.set_pixel(x, y, col)
	if with_cap:
		# rows 0-3: top of the capstone seen at an angle; row 4: its front
		# edge; row 5: the shadow of the lip on the first course of bricks
		var seam: int = rng.randi_range(3, 12)
		for x in 16:
			var on_seam: bool = x == seam or x == (seam + 8) % 16
			img.set_pixel(x, 0, cap.lightened(0.24))
			for yy in range(1, 4):
				var c1: Color = cap.lightened(0.08 - yy * 0.03) if not on_seam else cap.darkened(0.38)
				img.set_pixel(x, yy, c1.darkened(0.08) if rng.randf() < 0.15 else c1)
			img.set_pixel(x, 4, cap.darkened(0.42).lerp(SHADOW, 0.25))
			if y0 + 1 < y1:
				img.set_pixel(x, 5, img.get_pixel(x, 5).darkened(0.35))
	if plinth:
		for x in 16:
			img.set_pixel(x, 14, brick.darkened(0.42).lerp(SHADOW, 0.2))
			img.set_pixel(x, 15, brick.darkened(0.62).lerp(SHADOW, 0.35))
	return ImageTexture.create_from_image(img)

## Top of a wall seen from above: long capstone courses, bevelled.
## The cap must never read as paving. A first version used the theme
## colour almost as is, in 8 x 8 blocks: under the blue-green ambient it had
## the brightness, the hue and the pattern of the floor, and the two looked
## alike (feedback, 2026-11-16). Now it is darker and more saturated than
## the floor, laid in long horizontal courses; DungeonView adds a dark edge
## and a lit rim where it meets the floor (_draw_cap_edges).
func _wall_cap(cap: Color, rng: RandomNumberGenerator) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var base := Color.from_hsv(cap.h, minf(cap.s * 1.4 + 0.05, 1.0), cap.v * 0.6)
	var joint: Color = base.darkened(0.6).lerp(SHADOW, 0.4)
	# three courses: rows 0-4, 5-10, 11-15, the last row of each is the joint
	var course_end: Array[int] = [4, 10, 15]
	var course_start: Array[int] = [0, 5, 11]
	for k in 3:
		var seam: int = rng.randi_range(4, 11)
		var shade_a: Color = base.lightened(rng.randf_range(0.0, 0.07))
		var shade_b: Color = base.darkened(rng.randf_range(0.0, 0.09))
		for y in range(course_start[k], course_end[k] + 1):
			for x in 16:
				var c: Color = shade_a if x < seam else shade_b
				if y == course_end[k] or x == seam:
					c = joint
				elif y == course_start[k]:
					c = c.lightened(0.15)
				elif y == course_end[k] - 1:
					c = c.darkened(0.14)
				elif x == 0 or x == seam + 1:
					c = c.lightened(0.06)
				elif rng.randf() < 0.06:
					c = c.darkened(0.12)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

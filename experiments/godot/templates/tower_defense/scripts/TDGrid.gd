# =============================================================================
# TDGrid.gd (Node2D): tile grid, placement state, static map rendering.
# =============================================================================
# TILE TYPES (from maps.json "grid" rows):
#   'B': buildable, towers may be placed here
#   'P': path, enemies walk here, towers cannot be placed
#   'X': blocked, rocks drawn as a decorative obstacle
#
# COORDINATE SYSTEM (map space = this node's local space):
#   grid_to_world(col, row) -> Vector2 pixel center of that cell
#   world_to_grid(pos)      -> Vector2i(col, row), or (-1, -1) if out of bounds
#
# PLACEMENT STATE:
#   _towers[row][col] holds the Tower node or null: O(1) validation and
#   retrieval without scanning the scene tree.
#
# RENDERING:
#   Everything here is static, so _draw() runs once per setup(), never per
#   frame. Animated map elements (path arrows, portal, base) live in
#   PathMarkers.gd, hover / ghost / range rings in PlacementPreview.gd.
#   Decorations (grass tufts, flowers, pebbles, rocks) are generated with a
#   RandomNumberGenerator seeded by the map id: same map, same look, every run.
# =============================================================================

class_name TDGrid
extends Node2D

var cols:      int   = 0
var rows:      int   = 0
var tile_size: int   = 0
var map_id:    int   = 0
var waypoints: Array[Vector2] = []   # map-space centers, in path order

var _grid:   Array = []   # Array[Array[String]]
var _towers: Array = []   # Array[Array[Tower or null]]
var _decor:  Array[Dictionary] = []

const COLOR_GRASS_A    := Color("5c9d4b")
const COLOR_GRASS_B    := Color("57964a")
const COLOR_TUFT_DARK  := Color("4a8540")
const COLOR_TUFT_LIGHT := Color("78b85f")
const COLOR_DIRT       := Color("d9b47c")
const COLOR_DIRT_EDGE  := Color("bf965f")
const COLOR_DIRT_LINE  := Color("8a673c")
const COLOR_PEBBLE     := Color("c29a66")
const COLOR_ROCK       := Color("8c95a2")
const COLOR_ROCK_DARK  := Color("666e7b")
const COLOR_ROCK_LIGHT := Color("b4bdc9")
const COLOR_FRAME      := Color("2c3a2a")
const FLOWER_COLORS: Array[Color] = [Color("f4e36b"), Color("f29bbd"), Color("ffffff")]

func setup(map_data: Dictionary) -> void:
	tile_size = ConfigManager.get_int("tile_size", 0)
	cols      = int(map_data.get("cols", 0))
	rows      = int(map_data.get("rows", 0))
	map_id    = int(map_data.get("id", 0))

	var raw_rows: Array = map_data.get("grid", []) as Array
	_grid   = []
	_towers = []
	for r in rows:
		var row_str: String = str(raw_rows[r]) if r < raw_rows.size() else ""
		var row_tiles: Array = []
		var row_tow:   Array = []
		for c in cols:
			row_tiles.append(row_str[c] if c < row_str.length() else "B")
			row_tow.append(null)
		_grid.append(row_tiles)
		_towers.append(row_tow)

	waypoints.clear()
	for wp_v in map_data.get("waypoints", []) as Array:
		var wp: Array = wp_v as Array
		waypoints.append(grid_to_world(int(wp[0]), int(wp[1])))

	_generate_decor()
	queue_redraw()

func map_size() -> Vector2:
	return Vector2(cols * tile_size, rows * tile_size)

func grid_to_world(col: int, row: int) -> Vector2:
	return Vector2(col * tile_size + tile_size * 0.5, row * tile_size + tile_size * 0.5)

func world_to_grid(pos: Vector2) -> Vector2i:
	if pos.x < 0.0 or pos.y < 0.0:
		return Vector2i(-1, -1)
	var c: int = int(pos.x / tile_size)
	var r: int = int(pos.y / tile_size)
	if c >= cols or r >= rows:
		return Vector2i(-1, -1)
	return Vector2i(c, r)

func tile_at(col: int, row: int) -> String:
	if col < 0 or col >= cols or row < 0 or row >= rows:
		return ""
	return str(_grid[row][col])

func is_buildable(col: int, row: int) -> bool:
	return tile_at(col, row) == "B" and _towers[row][col] == null

func place_tower(col: int, row: int, tower: Tower) -> void:
	_towers[row][col] = tower

func remove_tower(col: int, row: int) -> void:
	_towers[row][col] = null

func get_tower_at(col: int, row: int) -> Tower:
	if tile_at(col, row) == "":
		return null
	return _towers[row][col] as Tower

# ---------------------------------------------------------------------------
# Decorations: generated once, deterministic per map
# ---------------------------------------------------------------------------

func _generate_decor() -> void:
	_decor.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337 + map_id
	var t: float = float(tile_size)
	for r in rows:
		for c in cols:
			var origin := Vector2(c * t, r * t)
			match tile_at(c, r):
				"B":
					for i in rng.randi_range(1, 3):
						_decor.append({kind = "tuft", pos = origin + Vector2(rng.randf_range(8, t - 8), rng.randf_range(10, t - 6)), s = rng.randf_range(0.7, 1.2)})
					if rng.randf() < 0.18:
						_decor.append({kind = "flower", pos = origin + Vector2(rng.randf_range(10, t - 10), rng.randf_range(10, t - 10)), col = rng.randi_range(0, FLOWER_COLORS.size() - 1)})
				"P":
					for i in rng.randi_range(0, 2):
						_decor.append({kind = "pebble", pos = origin + Vector2(rng.randf_range(10, t - 10), rng.randf_range(10, t - 10)), s = rng.randf_range(1.5, 3.0)})
				"X":
					_decor.append({kind = "rock", pos = origin + Vector2(t * 0.5 + rng.randf_range(-4, 4), t * 0.55), s = rng.randf_range(0.85, 1.05), seed = rng.randi()})
					if rng.randf() < 0.6:
						_decor.append({kind = "rock", pos = origin + Vector2(rng.randf_range(12, t - 12), t * 0.78), s = rng.randf_range(0.35, 0.5), seed = rng.randi()})

# ---------------------------------------------------------------------------
# Draw (static, runs once per setup)
# ---------------------------------------------------------------------------

func _draw() -> void:
	var t: float = float(tile_size)
	var size: Vector2 = map_size()
	# Drop shadow + frame: the map reads as a small diorama on the table
	draw_rect(Rect2(Vector2(-8, -2), size + Vector2(16, 20)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(Vector2(-6, -6), size + Vector2(12, 12)), COLOR_FRAME)

	for r in rows:
		for c in cols:
			var rect := Rect2(c * t, r * t, t, t)
			var tile: String = tile_at(c, r)
			if tile == "P":
				draw_rect(rect, COLOR_DIRT)
			else:
				draw_rect(rect, COLOR_GRASS_A if (r + c) % 2 == 0 else COLOR_GRASS_B)

	_draw_path_edges(t)
	for d in _decor:
		_draw_decor(d)

func _draw_path_edges(t: float) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for r in rows:
		for c in cols:
			if tile_at(c, r) != "P":
				continue
			for d in dirs:
				var nc: int = c + d.x
				var nr: int = r + d.y
				var outside: bool = nc < 0 or nc >= cols or nr < 0 or nr >= rows
				if outside or tile_at(nc, nr) == "P":
					continue   # open side (neighbour path or map entry / exit)
				var x0: float = c * t
				var y0: float = r * t
				var edge: Rect2
				var line_a: Vector2
				var line_b: Vector2
				if d.x == 1:
					edge = Rect2(x0 + t - 6, y0, 6, t)
					line_a = Vector2(x0 + t, y0)
					line_b = Vector2(x0 + t, y0 + t)
				elif d.x == -1:
					edge = Rect2(x0, y0, 6, t)
					line_a = Vector2(x0, y0)
					line_b = Vector2(x0, y0 + t)
				elif d.y == 1:
					edge = Rect2(x0, y0 + t - 6, t, 6)
					line_a = Vector2(x0, y0 + t)
					line_b = Vector2(x0 + t, y0 + t)
				else:
					edge = Rect2(x0, y0, t, 6)
					line_a = Vector2(x0, y0)
					line_b = Vector2(x0 + t, y0)
				draw_rect(edge, COLOR_DIRT_EDGE)
				draw_line(line_a, line_b, COLOR_DIRT_LINE, 2.0)

func _draw_decor(d: Dictionary) -> void:
	var pos: Vector2 = d["pos"] as Vector2
	match str(d["kind"]):
		"tuft":
			var s: float = float(d["s"])
			for i in 3:
				var off: float = (i - 1) * 3.0 * s
				var col: Color = COLOR_TUFT_DARK if i != 1 else COLOR_TUFT_LIGHT
				draw_line(pos + Vector2(off, 0), pos + Vector2(off * 1.8, -6.0 * s), col, 1.6, true)
		"flower":
			var col: Color = FLOWER_COLORS[int(d["col"])]
			for i in 4:
				draw_circle(pos + Vector2.from_angle(i * PI * 0.5) * 2.4, 2.0, col)
			draw_circle(pos, 1.6, Color("e9a23b"))
		"pebble":
			var s: float = float(d["s"])
			draw_circle(pos + Vector2(0.6, 0.8), s, COLOR_DIRT_LINE.lightened(0.2))
			draw_circle(pos, s, COLOR_PEBBLE)
		"rock":
			_draw_rock(pos, float(d["s"]) * tile_size * 0.42, int(d["seed"]))

func _draw_rock(center: Vector2, radius: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts := PackedVector2Array()
	var n: int = 9
	for i in n:
		var a: float = PI + float(i) / float(n - 1) * PI   # upper half-dome
		pts.append(center + Vector2(cos(a), sin(a) * 0.85) * radius * rng.randf_range(0.82, 1.08))
	pts.append(center + Vector2(radius * 0.95, radius * 0.25))
	pts.append(center + Vector2(-radius * 0.95, radius * 0.25))
	# Shadow
	draw_set_transform(center + Vector2(3, radius * 0.25), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, radius * 1.05, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_colored_polygon(pts, COLOR_ROCK)
	# Darker lower band and light top facet give volume without textures
	draw_line(pts[pts.size() - 1], pts[pts.size() - 2], COLOR_ROCK_DARK, 3.0)
	draw_circle(center + Vector2(-radius * 0.3, -radius * 0.45), radius * 0.22, COLOR_ROCK_LIGHT)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, COLOR_ROCK_DARK, 1.5, true)

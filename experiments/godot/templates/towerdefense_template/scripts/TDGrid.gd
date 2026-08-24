# =============================================================================
# GridMap.gd — Node2D: draws the tile grid and manages placement state.
# =============================================================================
# TILE TYPES (from maps.json "grid" rows):
#   'B' — buildable: towers may be placed here
#   'P' — path: enemies walk here, towers cannot be placed
#
# COORDINATE SYSTEM:
#   grid_to_world(col, row) → Vector2 pixel center of that cell
#   world_to_grid(pos)      → Vector2i(col, row), or (-1,-1) if out of bounds
#
# The tower placement state is stored in _occupied[col][row]: bool.
# A separate _towers[col][row] holds a reference to the Tower node so it can
# be retrieved for selling without iterating the whole scene tree.
# =============================================================================

class_name TDGrid
extends Node2D

var cols:      int        = 0
var rows:      int        = 0
var tile_size: int        = 0
var _grid:     Array      = []   # Array[Array[String]] — 'B' or 'P'
var _occupied: Array      = []   # Array[Array[bool]]
var _towers:   Array      = []   # Array[Array[Tower|null]]
var waypoints: Array      = []   # Array[Vector2] world positions

# Visual colors — drawn via _draw(), no textures required
const COLOR_BUILDABLE := Color(0.20, 0.45, 0.20, 1.0)
const COLOR_PATH      := Color(0.72, 0.60, 0.35, 1.0)
const COLOR_GRID_LINE := Color(0.0, 0.0, 0.0, 0.18)
const COLOR_HOVER     := Color(1.0, 1.0, 1.0, 0.18)

var _hover_cell: Vector2i = Vector2i(-1, -1)

func setup(map_data: Dictionary) -> void:
	tile_size = ConfigManager.get_int("tile_size", 0)
	cols      = map_data.get("cols", 0)
	rows      = map_data.get("rows", 0)

	# Parse the string-row grid
	var raw_rows: Array = map_data.get("grid", [])
	_grid     = []
	_occupied = []
	_towers   = []
	for r in rows:
		var row_str: String = raw_rows[r] if r < raw_rows.size() else ""
		var row_tiles: Array = []
		var row_occ:   Array = []
		var row_tow:   Array = []
		for c in cols:
			row_tiles.append(row_str[c] if c < row_str.length() else "B")
			row_occ.append(false)
			row_tow.append(null)
		_grid.append(row_tiles)
		_occupied.append(row_occ)
		_towers.append(row_tow)

	# Convert waypoint grid coords → world pixel centers
	waypoints = []
	for wp in map_data.get("waypoints", []):
		waypoints.append(grid_to_world(wp[0], wp[1]))

	queue_redraw()

func grid_to_world(col: int, row: int) -> Vector2:
	return Vector2(col * tile_size + tile_size * 0.5,
				   row * tile_size + tile_size * 0.5)

func world_to_grid(pos: Vector2) -> Vector2i:
	var c = int(pos.x / tile_size)
	var r = int(pos.y / tile_size)
	if c < 0 or c >= cols or r < 0 or r >= rows:
		return Vector2i(-1, -1)
	return Vector2i(c, r)

func is_buildable(col: int, row: int) -> bool:
	if col < 0 or col >= cols or row < 0 or row >= rows:
		return false
	return _grid[row][col] == "B" and not _occupied[row][col]

func place_tower(col: int, row: int, tower: Tower) -> void:
	_occupied[row][col] = true
	_towers[row][col]   = tower
	queue_redraw()

func remove_tower(col: int, row: int) -> void:
	_occupied[row][col] = false
	_towers[row][col]   = null
	queue_redraw()

func get_tower_at(col: int, row: int):
	if col < 0 or col >= cols or row < 0 or row >= rows:
		return null
	return _towers[row][col]

func set_hover(cell: Vector2i) -> void:
	if cell == _hover_cell:
		return
	_hover_cell = cell
	queue_redraw()

func _draw() -> void:
	for r in rows:
		for c in cols:
			var rect = Rect2(c * tile_size, r * tile_size, tile_size, tile_size)
			var tile = _grid[r][c]
			draw_rect(rect, COLOR_PATH if tile == "P" else COLOR_BUILDABLE)
			draw_rect(rect, COLOR_GRID_LINE, false, 1.0)

	# Exit marker — draw a green flag on the last waypoint tile
	if not waypoints.is_empty():
		var last = waypoints[-1]
		var ex   = last.x - tile_size * 0.5
		var ey   = last.y - tile_size * 0.5
		# Flag pole
		draw_rect(Rect2(ex + tile_size*0.45, ey + tile_size*0.1,
						 4, tile_size*0.8), Color(0.9,0.9,0.9))
		# Flag triangle
		draw_colored_polygon(PackedVector2Array([
			Vector2(ex + tile_size*0.49, ey + tile_size*0.1),
			Vector2(ex + tile_size*0.49, ey + tile_size*0.42),
			Vector2(ex + tile_size*0.82, ey + tile_size*0.26)
		]), Color(0.2, 0.9, 0.3))

	# Hover highlight
	if _hover_cell.x >= 0:
		var hr = Rect2(_hover_cell.x * tile_size, _hover_cell.y * tile_size,
					   tile_size, tile_size)
		draw_rect(hr, COLOR_HOVER)

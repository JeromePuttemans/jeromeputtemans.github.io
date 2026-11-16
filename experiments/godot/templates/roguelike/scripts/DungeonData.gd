# =============================================================================
# DungeonData.gd: pure data class for one dungeon floor.
# =============================================================================
# Holds the tile grid plus per-floor metadata (rooms, spawn points, items on
# the ground, exploration state). Created by DungeonGenerator; consumed by
# GameState, FOVSystem, DijkstraMap and the views.
#
# TILE TYPES:
#   WALL        impassable, blocks FOV rays
#   FLOOR       passable, transparent to FOV
#   STAIRS_DOWN passable; on the last floor it is the exit portal
# =============================================================================

class_name DungeonData
extends RefCounted

enum TileType { WALL, FLOOR, STAIRS_DOWN }

var width:  int = 0
var height: int = 0

# grid[x][y] holds a TileType (column-major: x = column, y = row)
var grid: Array = []

# explored[x][y] is true once the player has seen the tile.
# Persists across turns within a floor; reset with each new floor.
var explored: Array = []

var rooms:         Array[Rect2i]     = []
var player_start:  Vector2i          = Vector2i.ZERO
var stairs_pos:    Vector2i          = Vector2i.ZERO
var enemy_spawns:  Array[Dictionary] = []   # {pos: Vector2i, type_id: String}
var item_spawns:   Array[Dictionary] = []   # {pos: Vector2i, item_id: String}
var items:         Dictionary        = {}   # Vector2i -> item definition (Dictionary)
var floor_number:  int               = 1
var is_last_floor: bool              = false
var stairs_locked: bool              = true    # opened by the floor's key
var barrels:       Dictionary        = {}      # Vector2i -> "barrel" or "keg"; block walking, not sight
var fuses:         Dictionary        = {}      # Vector2i -> turns left: lit powder kegs
var torches:       Array[Vector2i]   = []      # wall cells holding a torch (light)
var candles:       Array[Vector2i]   = []      # floor cells with candles (light, walkable)
var runes:         Array[Vector2i]   = []      # glowing floor runes (coloured light, walkable)
var banners:       Dictionary        = {}      # wall cell -> true: banner hung on the wall face
var decor:         Dictionary        = {}      # Vector2i -> "bones" or "rubble" (looks only)
var footprints:    Dictionary        = {}      # Vector2i -> {turn, dir}: the thief's tracks
var bone_piles:    Dictionary        = {}      # Vector2i -> {turns, data, hp}: fallen skeletons

func _init(w: int, h: int) -> void:
	width  = w
	height = h
	for _x in w:
		var tile_col: Array = []
		tile_col.resize(h)
		tile_col.fill(TileType.WALL)
		grid.append(tile_col)
		var exp_col: Array = []
		exp_col.resize(h)
		exp_col.fill(false)
		explored.append(exp_col)

## Tile at the given position, or WALL if out of bounds.
func get_tile(pos: Vector2i) -> TileType:
	if not in_bounds(pos):
		return TileType.WALL
	return grid[pos.x][pos.y] as TileType

func set_tile(pos: Vector2i, type: TileType) -> void:
	if in_bounds(pos):
		grid[pos.x][pos.y] = type

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

## A tile is walkable if it is not a wall (floor or stairs) and holds no
## barrel.
func is_walkable(pos: Vector2i) -> bool:
	return get_tile(pos) != TileType.WALL and not barrels.has(pos)

## True for a powder keg (a barrel that explodes).
func is_keg(pos: Vector2i) -> bool:
	return str(barrels.get(pos, "")) == "keg"

## Like is_walkable, but a barrel counts as floor (vision, wall faces).
func is_open(pos: Vector2i) -> bool:
	return get_tile(pos) != TileType.WALL

## True for a wall that touches at least one walkable tile (8 neighbours).
## Only these walls are drawn: the rest is solid rock, left black.
func is_wall_face(pos: Vector2i) -> bool:
	if get_tile(pos) != TileType.WALL:
		return false
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if (dx != 0 or dy != 0) and is_open(pos + Vector2i(dx, dy)):
				return true
	return false

## Marks every floor tile and every wall face as explored (map scroll).
func reveal_all() -> void:
	for x in width:
		for y in height:
			var p := Vector2i(x, y)
			if is_open(p) or is_wall_face(p):
				explored[x][y] = true

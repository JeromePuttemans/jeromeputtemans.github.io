# =============================================================================
# DungeonData.gd — Pure data class for the dungeon grid.
# =============================================================================
# Holds the tile grid plus per-floor metadata (rooms, spawn points, FOV state).
# Created by DungeonGenerator; consumed by GameState, FOVSystem, DungeonView.
#
# TILE TYPES:
#   WALL        — impassable, blocks FOV rays
#   FLOOR       — passable, transparent to FOV
#   STAIRS_DOWN — passable, triggers floor descent when stepped on
# =============================================================================

class_name DungeonData
extends RefCounted

enum TileType { WALL, FLOOR, STAIRS_DOWN }

var width: int
var height: int

# grid[x][y] → TileType  (column-major, x = column, y = row)
var grid: Array

# explored[x][y] → bool (true once the player has seen this tile)
# Persists across turns within a floor; reset when a new floor is generated.
var explored: Array

var rooms: Array          # Array[Rect2i]
var player_start: Vector2i
var stairs_pos: Vector2i
var enemy_spawns: Array   # Array[{pos: Vector2i, type_id: String}]

func _init(w: int, h: int) -> void:
	width  = w
	height = h
	grid     = []
	explored = []
	for _x in w:
		var tile_col: Array = []
		tile_col.resize(h)
		tile_col.fill(TileType.WALL)
		grid.append(tile_col)

		var exp_col: Array = []
		exp_col.resize(h)
		exp_col.fill(false)
		explored.append(exp_col)

## Returns the tile at the given position, or WALL if out of bounds.
func get_tile(pos: Vector2i) -> TileType:
	if not in_bounds(pos):
		return TileType.WALL
	return grid[pos.x][pos.y]

func set_tile(pos: Vector2i, type: TileType) -> void:
	if in_bounds(pos):
		grid[pos.x][pos.y] = type

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

## A tile is walkable if it is not a wall (floor or stairs).
func is_walkable(pos: Vector2i) -> bool:
	var t = get_tile(pos)
	return t == TileType.FLOOR or t == TileType.STAIRS_DOWN

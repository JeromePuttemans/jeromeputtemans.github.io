# =============================================================================
# FOVSystem.gd — Field-of-vision computation via raycasting.
# =============================================================================
# ALGORITHM: Bresenham raycasting.
#
# For every tile within Euclidean distance `radius` of the origin:
#   1. Cast a ray from origin to the tile using Bresenham's line.
#   2. Walk the line cell by cell (skipping origin and target).
#   3. If any intermediate cell is a WALL, the target is not visible.
#   4. Otherwise the target is visible — even if it IS a wall (you see its face).
#
# Complexity: O(r²) targets × O(r) ray steps = O(r³).
# With r=8: ~200 targets × 8 steps ≈ 1600 ops per turn — negligible.
#
# Known limitation: raycasting allows "corner peeking" through diagonal
# wall pairs. Shadowcasting algorithms eliminate this but are more complex.
# For a template, raycasting provides a clear and teachable tradeoff.
# =============================================================================

class_name FOVSystem
extends RefCounted

## Returns a 2D bool array [x][y] where true = currently visible.
## Matching dimensions: result[dungeon.width][dungeon.height].
static func compute(dungeon: DungeonData, origin: Vector2i, radius: int) -> Array:
	var result: Array = []
	for x in dungeon.width:
		var col: Array = []
		col.resize(dungeon.height)
		col.fill(false)
		result.append(col)

	# The origin tile is always visible
	result[origin.x][origin.y] = true

	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			# Euclidean radius check (produces a circular FOV, not a square)
			if dx * dx + dy * dy > radius * radius:
				continue
			var target = origin + Vector2i(dx, dy)
			if not dungeon.in_bounds(target):
				continue
			if _has_los(dungeon, origin, target):
				result[target.x][target.y] = true

	return result

## Returns true if there is a clear line of sight from `from` to `to`.
## Checks all intermediate cells; the target cell itself is always considered
## visible (you can see a wall face even though you cannot walk through it).
static func _has_los(dungeon: DungeonData, from: Vector2i, to: Vector2i) -> bool:
	var line = _bresenham(from, to)
	# range(1, size-1) skips origin (index 0) and target (last index)
	for i in range(1, line.size() - 1):
		if dungeon.get_tile(line[i]) == DungeonData.TileType.WALL:
			return false
	return true

## Returns the list of integer grid cells along the line from `from` to `to`
## using Bresenham's line algorithm (always includes both endpoints).
static func _bresenham(from: Vector2i, to: Vector2i) -> Array:
	var pts: Array = []
	var x0 = from.x
	var y0 = from.y
	var x1 = to.x
	var y1 = to.y
	var dx =  abs(x1 - x0)
	var dy = -abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy

	while true:
		pts.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x0  += sx
		if e2 <= dx:
			err += dx
			y0  += sy

	return pts

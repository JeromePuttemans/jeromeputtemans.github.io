# =============================================================================
# DijkstraMap.gd: breadth-first distance field, shared by every enemy.
# =============================================================================
# ALGORITHM ("Dijkstra map", popularised by Brogue):
#   Start from the player's cell with distance 0 and run a breadth-first
#   search over walkable tiles, 8 directions, each step costing 1 (the
#   Chebyshev metric used by movement). Every reachable cell gets its walking
#   distance to the player.
#
#   To chase the player, an enemy simply steps to the neighbour with the
#   smallest distance. One BFS per turn, O(width x height), serves ALL
#   enemies, whereas one A* per enemy would cost O(enemies x path).
#   Enemies go around walls and corridors instead of pushing straight
#   against them, and other enemies are skipped as blocked cells, so a
#   crowd spreads out to surround the player.
#
#   max_dist bounds the search: cells further away keep -1 (unreachable),
#   and enemies there have no reason to move anyway.
# =============================================================================

class_name DijkstraMap
extends RefCounted

# Orthogonal directions first: on equal distance, enemies prefer straight
# steps, which reads as less erratic movement.
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var width:  int = 0
var height: int = 0
var dist:   PackedInt32Array = PackedInt32Array()

static func compute(dungeon: DungeonData, origin: Vector2i, max_dist: int) -> DijkstraMap:
	var m := DijkstraMap.new()
	m.width = dungeon.width
	m.height = dungeon.height
	m.dist.resize(m.width * m.height)
	m.dist.fill(-1)
	if not dungeon.in_bounds(origin):
		return m
	var queue: Array[Vector2i] = [origin]
	m.dist[origin.y * m.width + origin.x] = 0
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var d: int = m.dist[cur.y * m.width + cur.x]
		if d >= max_dist:
			continue
		for dir in DIRS:
			var n: Vector2i = cur + dir
			if not dungeon.is_walkable(n):
				continue
			var idx: int = n.y * m.width + n.x
			if m.dist[idx] != -1:
				continue
			m.dist[idx] = d + 1
			queue.append(n)
	return m

func get_dist(pos: Vector2i) -> int:
	if pos.x < 0 or pos.y < 0 or pos.x >= width or pos.y >= height:
		return -1
	return dist[pos.y * width + pos.x]

## Neighbour of `pos` that gets closest to the origin, skipping `blocked`
## cells (other enemies) and `target` (the player's own cell: reaching it
## is an attack, not a move). Returns `pos` itself if no step improves.
func step_toward(pos: Vector2i, blocked: Dictionary, target: Vector2i) -> Vector2i:
	var here: int = get_dist(pos)
	var best: Vector2i = pos
	var best_d: int = here if here >= 0 else 1 << 30
	for dir in DIRS:
		var n: Vector2i = pos + dir
		if n == target or blocked.has(n):
			continue
		var d: int = get_dist(n)
		if d >= 0 and d < best_d:
			best_d = d
			best = n
	return best

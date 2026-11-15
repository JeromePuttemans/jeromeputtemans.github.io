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

## Safety map for a fleeing creature (Brogue's technique): every reachable
## cell starts at -1.2 x its distance to the player, then values relax so
## that no cell is more than one step above a neighbour. Walking down this
## map leads away from the player but towards open escape routes instead of
## the nearest dead end (a plain "maximise the distance" runs into corners).
## Values are shifted to stay positive; unreachable cells keep -1.
static func flee(from_map: DijkstraMap) -> DijkstraMap:
	var m := DijkstraMap.new()
	m.width = from_map.width
	m.height = from_map.height
	m.dist.resize(m.width * m.height)
	m.dist.fill(-1)
	var top: int = 0
	for d in from_map.dist:
		top = maxi(top, d)
	var shift: int = int(ceil(top * 1.2)) + 2
	var buckets: Dictionary = {}
	for i in from_map.dist.size():
		var d: int = from_map.dist[i]
		if d < 0:
			continue
		var v: int = shift - int(round(d * 1.2))
		m.dist[i] = v
		if not buckets.has(v):
			buckets[v] = []
		(buckets[v] as Array).append(i)
	var keys: Array = buckets.keys()
	keys.sort()
	var level: int = 0
	var max_level: int = shift + top + 2
	if keys.is_empty():
		return m
	level = int(keys[0])
	while level <= max_level:
		if buckets.has(level):
			var list: Array = buckets[level]
			var k: int = 0
			while k < list.size():
				var i: int = int(list[k])
				k += 1
				if m.dist[i] != level:
					continue
				var p := Vector2i(i % m.width, floori(float(i) / m.width))
				for dir in DIRS:
					var n: Vector2i = p + dir
					if n.x < 0 or n.y < 0 or n.x >= m.width or n.y >= m.height:
						continue
					var j: int = n.y * m.width + n.x
					if m.dist[j] > level + 1:
						m.dist[j] = level + 1
						if not buckets.has(level + 1):
							buckets[level + 1] = []
						(buckets[level + 1] as Array).append(j)
		level += 1
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

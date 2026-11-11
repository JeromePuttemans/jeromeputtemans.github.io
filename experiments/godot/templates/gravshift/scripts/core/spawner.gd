extends Node

# Spawner: plays the sectors of settings.json "waves".
# A sector is a list of groups {type, count, edge, delay, interval}: the
# group starts after delay seconds and sends count enemies, one every
# interval seconds, from the given edge of the arena:
#   top, bottom, left, right   anywhere along that edge
#   sides                      left and right in turn
#   corners                    one of the four corners
#   random                     any edge
# A sector with "boss" spawns that boss from the top at once. The sector
# ends when everything has been sent and nothing is left alive.

var gm: Node = null
var waves: Array = []
var wave_index: int = -1
var _queue: Array[Dictionary] = []
var _time: float = 0.0

func total() -> int:
	return waves.size()

func start_wave(index: int) -> void:
	wave_index = index
	_queue.clear()
	_time = 0.0
	var wave: Dictionary = waves[index] as Dictionary
	if wave.has("boss"):
		var arena: Rect2 = gm.call("arena_rect") as Rect2
		gm.call("spawn_enemy_at", str(wave["boss"]), Vector2(arena.get_center().x, arena.position.y - 90.0))
	for group in wave.get("groups", []) as Array:
		var g: Dictionary = group as Dictionary
		for k in int(g.get("count", 1)):
			_queue.append({t = float(g.get("delay", 0.0)) + k * float(g.get("interval", 0.5)), type = str(g.get("type", "drone")), edge = str(g.get("edge", "random")), n = k})
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))

func step(delta: float) -> void:
	_time += delta
	while not _queue.is_empty() and float(_queue[0]["t"]) <= _time:
		var job: Dictionary = _queue.pop_front()
		gm.call("spawn_enemy_at", str(job["type"]), _edge_point(str(job["edge"]), int(job["n"])))

func done_spawning() -> bool:
	return _queue.is_empty()

func remaining() -> int:
	return _queue.size()

func _edge_point(edge: String, n: int) -> Vector2:
	var a: Rect2 = gm.call("arena_rect") as Rect2
	var m: float = 50.0
	match edge:
		"top":
			return Vector2(randf_range(a.position.x + 80.0, a.end.x - 80.0), a.position.y - m)
		"bottom":
			return Vector2(randf_range(a.position.x + 80.0, a.end.x - 80.0), a.end.y + m)
		"left":
			return Vector2(a.position.x - m, randf_range(a.position.y + 80.0, a.end.y - 80.0))
		"right":
			return Vector2(a.end.x + m, randf_range(a.position.y + 80.0, a.end.y - 80.0))
		"sides":
			return _edge_point("left" if n % 2 == 0 else "right", n)
		"corners":
			var corners: Array[Vector2] = [a.position - Vector2(m, m), Vector2(a.end.x + m, a.position.y - m), a.end + Vector2(m, m), Vector2(a.position.x - m, a.end.y + m)]
			return corners[n % 4]
	var edges: Array[String] = ["top", "bottom", "left", "right"]
	return _edge_point(edges[randi() % 4], n)

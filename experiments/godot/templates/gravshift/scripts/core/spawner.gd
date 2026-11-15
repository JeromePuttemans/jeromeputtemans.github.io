extends Node

# Spawner: plays the sectors of settings.json "waves".
# A sector is a list of groups {type, count, edge, delay, interval, flock}:
# the group starts after delay seconds and sends count enemies, one every
# interval seconds, from the given edge of the arena:
#   top, bottom, left, right   anywhere along that edge
#   sides                      left and right in turn
#   corners                    one of the four corners
#   random                     any edge
# flock: true makes the whole group enter at one point of that edge
# (within 40 px): the Swarm arrives as a flock.
# WARNING: every entry point is chosen WARN_AHEAD s early and announced
# (game_manager.spawn_warning: a chevron on the edge), so nothing enters
# unannounced; the whole schedule is shifted by WARN_AHEAD for that.
# A sector with "boss" spawns that boss from the top at once. The sector
# ends when everything has been sent and nothing is left alive.

const WARN_AHEAD: float = 0.9

var gm: Node = null
var waves: Array = []
var wave_index: int = -1
var sector_size: int = 0
var _queue: Array[Dictionary] = []
var _time: float = 0.0

func total() -> int:
	return waves.size()

func start_wave(index: int) -> void:
	wave_index = index
	_queue.clear()
	_time = 0.0
	sector_size = 0
	var wave: Dictionary = waves[index] as Dictionary
	if wave.has("boss"):
		var arena: Rect2 = gm.call("arena_rect") as Rect2
		gm.call("spawn_enemy_at", str(wave["boss"]), Vector2(arena.get_center().x, arena.position.y - 90.0))
		sector_size += 1
	for group in wave.get("groups", []) as Array:
		var g: Dictionary = group as Dictionary
		var edge: String = str(g.get("edge", "random"))
		var flock: bool = bool(g.get("flock", false))
		var anchor: Vector2 = _edge_point(edge, 0)
		for k in int(g.get("count", 1)):
			_queue.append({t = WARN_AHEAD + float(g.get("delay", 0.0)) + k * float(g.get("interval", 0.5)), type = str(g.get("type", "drone")), edge = edge, n = k, flock = flock, anchor = anchor, warned = false, at = Vector2.ZERO})
			sector_size += 1
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))

func step(delta: float) -> void:
	_time += delta
	for job in _queue:
		if float(job["t"]) - WARN_AHEAD > _time:
			break
		if not bool(job["warned"]):
			job["warned"] = true
			var at: Vector2 = _edge_point(str(job["edge"]), int(job["n"]))
			if bool(job["flock"]):
				at = (job["anchor"] as Vector2) + Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
			job["at"] = at
			gm.call("spawn_warning", at, str(job["type"]))
	while not _queue.is_empty() and float(_queue[0]["t"]) <= _time:
		var job2: Dictionary = _queue.pop_front()
		gm.call("spawn_enemy_at", str(job2["type"]), job2["at"] as Vector2)

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

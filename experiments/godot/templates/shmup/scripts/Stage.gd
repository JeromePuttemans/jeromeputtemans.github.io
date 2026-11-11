# =============================================================================
# Stage.gd — Runs the timeline of data/stage.json
# =============================================================================
# Each event has a time t (seconds of stage clock) and one action:
#   enemy + path   a formation of count ships following a named path, one
#                  every "every" s; mirror flips the path left-right, dx
#                  shifts it (field fraction), pair spawns both sides
#   enemy + at     a ship that comes down to the point at [x, y]
#   enemy + x      a ship entering from the top at x (drift, dive)
#   warning        the WARNING banner and siren before a boss
#   boss           spawns a boss; the stage clock stops while it lives
# The clock also stops while the player is respawning, so a loss of life
# never makes the player miss a formation.
# =============================================================================

class_name Stage
extends Node

var game: Game = null
var clock: float = 0.0
var length: float = 1.0
var marks: Array[float] = []
var _events: Array = []
var _paths: Dictionary = {}
var _index: int = 0
var _pending: Array[Dictionary] = []

func setup(data: Dictionary) -> void:
	_events = (data.get("events", []) as Array).duplicate()
	_events.sort_custom(func(a: Variant, b: Variant) -> bool: return float((a as Dictionary)["t"]) < float((b as Dictionary)["t"]))
	_paths = data.get("paths", {}) as Dictionary
	length = float((_events[_events.size() - 1] as Dictionary)["t"]) if not _events.is_empty() else 1.0
	clock = 0.0
	_index = 0
	_pending.clear()
	marks.clear()
	for e in _events:
		if (e as Dictionary).has("boss"):
			marks.append(float((e as Dictionary)["t"]) / length)

func progress() -> float:
	return clampf(clock / length, 0.0, 1.0)

func finished() -> bool:
	return _index >= _events.size() and _pending.is_empty()

func step(delta: float) -> void:
	if game.boss != null or not game.player.alive:
		return
	clock += delta
	while _index < _events.size() and float((_events[_index] as Dictionary)["t"]) <= clock:
		_run(_events[_index] as Dictionary)
		_index += 1
	for i in range(_pending.size() - 1, -1, -1):
		var job: Dictionary = _pending[i]
		if float(job["at"]) <= clock:
			_pending.remove_at(i)
			_spawn_on_path(job["event"] as Dictionary, bool(job["mirror"]))

func _run(e: Dictionary) -> void:
	if e.has("warning"):
		game.warning()
		return
	if e.has("boss"):
		game.spawn_boss(str(e["boss"]))
		return
	if not e.has("enemy"):
		return
	if e.has("path"):
		var count: int = int(e.get("count", 1))
		var every: float = float(e.get("every", 0.3))
		var sides: Array[bool] = [bool(e.get("mirror", false))]
		if bool(e.get("pair", false)):
			sides = [false, true]
		for k in count:
			for side in sides:
				if k == 0:
					_spawn_on_path(e, side)
				else:
					_pending.append({at = clock + k * every, event = e, mirror = side})
		return
	var at: Array = e.get("at", [float(e.get("x", 0.5)), 0.2]) as Array
	game.spawn_enemy(str(e["enemy"]), {target = Vector2(float(at[0]) * game.field.x, float(at[1]) * game.field.y)})

func _spawn_on_path(e: Dictionary, mirror: bool) -> void:
	var raw: Array = _paths.get(str(e["path"]), []) as Array
	var points := PackedVector2Array()
	var dx: float = float(e.get("dx", 0.0))
	for pt in raw:
		var x: float = float((pt as Array)[0]) + dx
		if mirror:
			x = 1.0 - x
		points.append(Vector2(x * game.field.x, float((pt as Array)[1]) * game.field.y))
	game.spawn_enemy(str(e["enemy"]), {path = points})

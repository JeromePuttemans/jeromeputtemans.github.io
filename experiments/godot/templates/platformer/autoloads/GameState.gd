# =============================================================================
# GameState.gd — Autoload (Singleton): the run in progress
# =============================================================================
# Holds the levels (parsed once from data/levels.json) and the state of the
# level being played: clock, falls, fireflies and acorns taken, respawn
# point. The UI listens to its signals, Level and Main call its methods.
#
# PHASES: MENU (title, level select) -> PLAYING <-> PAUSED -> COMPLETE
#   (results screen) -> PLAYING (next level) or FINAL (after the last one).
# =============================================================================

extends Node

enum Phase { MENU, PLAYING, PAUSED, COMPLETE, FINAL }

signal phase_changed(phase: Phase)
signal level_started(index: int)
signal pickups_changed()
signal deaths_changed(count: int)

var levels: Array[LevelData] = []
var phase: Phase = Phase.MENU
var level_index: int = 0
var time: float = 0.0
var deaths: int = 0
var fireflies: Dictionary = {}
var acorns: Dictionary = {}
var checkpoint := Vector2.ZERO
var _clock_running: bool = false

func _ready() -> void:
	var raw: Variant = ConfigManager.load_json("res://data/levels.json")
	if raw is Array:
		for entry in raw as Array:
			levels.append(LevelData.from_dict(entry as Dictionary))

func current() -> LevelData:
	return levels[level_index]

func set_phase(value: Phase) -> void:
	phase = value
	phase_changed.emit(phase)

func begin_level(index: int) -> void:
	level_index = clampi(index, 0, levels.size() - 1)
	time = 0.0
	deaths = 0
	fireflies.clear()
	acorns.clear()
	_clock_running = true
	set_phase(Phase.PLAYING)
	level_started.emit(level_index)
	pickups_changed.emit()
	deaths_changed.emit(deaths)

func add_time(delta: float) -> void:
	if _clock_running:
		time += delta

func stop_clock() -> void:
	_clock_running = false

func collect_firefly(index: int) -> void:
	fireflies[index] = true
	pickups_changed.emit()

func collect_acorn(index: int) -> void:
	acorns[index] = true
	pickups_changed.emit()

func add_death() -> void:
	deaths += 1
	deaths_changed.emit(deaths)

## Builds the results of the level, merges them into the save.
func finish_level() -> Dictionary:
	var data: LevelData = current()
	var found: Array = acorns.keys()
	var previous: Dictionary = SaveManager.record(data.id)
	var result: Dictionary = {
		index = level_index, time = time, deaths = deaths,
		fireflies = fireflies.size(), firefly_total = data.firefly_total,
		acorns = found, acorn_total = data.acorn_total,
		previous_best = float(previous.get("best_time", -1.0)),
	}
	result["new_record"] = SaveManager.store_result(data.id, levels.size(), result) and previous.has("best_time")
	result["first_clear"] = not previous.has("best_time")
	set_phase(Phase.COMPLETE)
	return result

func is_last_level() -> bool:
	return level_index >= levels.size() - 1

static func format_time(seconds: float) -> String:
	var total: int = int(seconds * 100.0)
	return "%d:%02d.%02d" % [floori(total / 6000.0), floori(total / 100.0) % 60, total % 100]

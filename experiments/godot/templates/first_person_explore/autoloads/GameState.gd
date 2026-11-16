# =============================================================================
# GameState.gd: Autoload (Singleton) holding the run in progress
# =============================================================================
# Progress of the run (shards, seals, raised gnomon, falls, dashes,
# launches, clock, last platform visited, hour, the time of the first
# arrival on each platform) and the one-shot tips. Main and the world call
# its methods; the HUD listens to its signals. The run is saved on every
# meaningful event (new platform, shard, seal), so closing the browser tab
# loses at most the walk since the last platform.
#
# PHASES: MENU (title) -> PLAYING <-> PAUSED -> ENDING (sunset, no control)
#   -> END (results) -> MENU.
# =============================================================================

extends Node

enum Phase { MENU, PLAYING, PAUSED, ENDING, END }

signal phase_changed(phase: Phase)
signal shards_changed(count: int)
signal seals_changed()
signal tip_requested(key: String)
signal banner_requested(title: String, subtitle: String)
signal split_reached(island: String, time: float)

var phase: Phase = Phase.MENU
var shards: Array[int] = []
var seals_taken: Array[String] = []
var seals_placed: Array[String] = []
var gnomon_raised: bool = false
var falls: int = 0
var dashes: int = 0
var launches: int = 0
var time: float = 0.0
var checkpoint: String = ""
var hour: float = 12.0
var tips_seen: Array[String] = []
var visited: Array[String] = []
var splits: Dictionary = {}          # island -> time of the first arrival
var shard_total: int = 0

func set_phase(value: Phase) -> void:
	phase = value
	phase_changed.emit(phase)

func new_run(start_island: String, start_hour: float) -> void:
	shards.clear()
	seals_taken.clear()
	seals_placed.clear()
	gnomon_raised = false
	falls = 0
	dashes = 0
	launches = 0
	time = 0.0
	splits = {}
	checkpoint = start_island
	hour = start_hour
	tips_seen.clear()
	visited.clear()
	shards_changed.emit(0)
	seals_changed.emit()

func load_run(d: Dictionary) -> void:
	new_run(str(d.get("checkpoint", "")), float(d.get("hour", 12.0)))
	for s in d.get("shards", []) as Array:
		shards.append(int(s))
	for s in d.get("seals_taken", []) as Array:
		seals_taken.append(str(s))
	for s in d.get("seals_placed", []) as Array:
		seals_placed.append(str(s))
	for s in d.get("tips_seen", []) as Array:
		tips_seen.append(str(s))
	for s in d.get("visited", []) as Array:
		visited.append(str(s))
	gnomon_raised = bool(d.get("gnomon_raised", false))
	falls = int(d.get("falls", 0))
	dashes = int(d.get("dashes", 0))
	launches = int(d.get("launches", 0))
	if d.get("splits") is Dictionary:
		splits = (d["splits"] as Dictionary).duplicate()
	time = float(d.get("time", 0.0))
	shards_changed.emit(shards.size())
	seals_changed.emit()

func to_dict() -> Dictionary:
	return {
		shards = shards, seals_taken = seals_taken, seals_placed = seals_placed,
		gnomon_raised = gnomon_raised, falls = falls, dashes = dashes, launches = launches,
		time = time, checkpoint = checkpoint, hour = hour, tips_seen = tips_seen,
		visited = visited, splits = splits,
	}

func save_run() -> void:
	SaveManager.store_run(to_dict())

func add_time(delta: float) -> void:
	if phase == Phase.PLAYING:
		time += delta

func collect_shard(index: int) -> void:
	if shards.has(index):
		return
	shards.append(index)
	shards_changed.emit(shards.size())
	save_run()

func take_seal(id: String) -> void:
	if seals_taken.has(id):
		return
	seals_taken.append(id)
	seals_changed.emit()
	save_run()

func place_seal(id: String) -> void:
	if seals_placed.has(id):
		return
	seals_placed.append(id)
	seals_changed.emit()
	save_run()

## Seals carried but not yet set in their socket.
func seals_to_place() -> Array[String]:
	var out: Array[String] = []
	for id in seals_taken:
		if not seals_placed.has(id):
			out.append(id)
	return out

func add_fall() -> void:
	falls += 1

## Shows a tip once per run. {placeholders} are filled by the HUD.
func show_tip(key: String) -> void:
	if key == "" or tips_seen.has(key):
		return
	tips_seen.append(key)
	tip_requested.emit(key)

func banner(title: String, subtitle: String = "") -> void:
	banner_requested.emit(title, subtitle)

## Returns true the first time a platform is visited in this run, and
## records the time of that first arrival (the split).
func visit(island: String) -> bool:
	checkpoint = island
	if visited.has(island):
		return false
	visited.append(island)
	if visited.size() > 1:
		splits[island] = time
		split_reached.emit(island, time)
	return true

static func format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%d:%02d" % [floori(total / 60.0), total % 60]

## "1:04.3": the clock of the HUD, to the tenth of a second.
static func format_precise(seconds: float) -> String:
	var tenths: int = int(seconds * 10.0)
	return "%d:%02d.%d" % [floori(tenths / 600.0), floori(tenths / 10.0) % 60, tenths % 10]

## "-0:03.2" / "+0:12.0": a split compared with the best run.
static func format_delta(seconds: float) -> String:
	var sign_text: String = "-" if seconds < 0.0 else "+"
	return sign_text + format_precise(absf(seconds))

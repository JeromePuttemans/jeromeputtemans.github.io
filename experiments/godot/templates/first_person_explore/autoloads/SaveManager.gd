# =============================================================================
# SaveManager.gd — Autoload (Singleton): progress and settings on disk
# =============================================================================
# user://gnomon_save.json (in the browser: IndexedDB of the site, shared by
# every game of the origin, hence the unique file name):
#   version    SAVE_VERSION; another version starts a fresh save
#   run        the run in progress (GameState.to_dict()), or {} when none
#   best       best finished run: time, shards
#   settings   language, muted, sensitivity, invert_y
# =============================================================================

extends Node

const PATH: String = "user://gnomon_save.json"
const SAVE_VERSION: int = 1

var data: Dictionary = {}

func _ready() -> void:
	data = _fresh()
	if not FileAccess.file_exists(PATH):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(PATH)) != OK or not (json.data is Dictionary):
		return
	var loaded: Dictionary = json.data as Dictionary
	if int(loaded.get("version", 0)) != SAVE_VERSION:
		return
	for key in ["run", "best", "settings"]:
		if loaded.get(key) is Dictionary:
			data[key] = loaded[key]

func _fresh() -> Dictionary:
	return {version = SAVE_VERSION, run = {}, best = {}, settings = {}}

func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))

func get_setting(key: String, default: Variant) -> Variant:
	return (data["settings"] as Dictionary).get(key, default)

func set_setting(key: String, value: Variant) -> void:
	(data["settings"] as Dictionary)[key] = value
	save()

func has_run() -> bool:
	return not (data["run"] as Dictionary).is_empty()

func get_run() -> Dictionary:
	return data["run"] as Dictionary

func store_run(run: Dictionary) -> void:
	data["run"] = run
	save()

func clear_run() -> void:
	data["run"] = {}
	save()

func best() -> Dictionary:
	return data["best"] as Dictionary

## Keeps the faster finished run (ties: more shards). Returns true if new.
func store_best(time: float, shards: int) -> bool:
	var b: Dictionary = best()
	var better: bool = b.is_empty() or time < float(b.get("time", INF)) or (is_equal_approx(time, float(b.get("time", INF))) and shards > int(b.get("shards", 0)))
	if better:
		data["best"] = {time = time, shards = shards}
	save()
	return better

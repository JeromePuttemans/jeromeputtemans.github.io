# =============================================================================
# SaveManager.gd — Autoload (Singleton): progress and settings on disk
# =============================================================================
# user://brindille_save.json (in the browser: IndexedDB of the site, shared
# by every game of the origin, hence the unique file name):
#   version    SAVE_VERSION; another version starts a fresh save
#   unlocked   number of levels that can be played
#   levels     per level id: best_time, best_deaths, fireflies (best count),
#              acorns (found at least once, union of all runs), done
#   settings   language, muted
# =============================================================================

extends Node

const PATH: String = "user://brindille_save.json"
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
	data = loaded

func _fresh() -> Dictionary:
	return {version = SAVE_VERSION, unlocked = 1, levels = {}, settings = {}}

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

func unlocked() -> int:
	return int(data.get("unlocked", 1))

func record(level_id: int) -> Dictionary:
	return (data["levels"] as Dictionary).get(str(level_id), {}) as Dictionary

func acorn_found(level_id: int, index: int) -> bool:
	var acorns: Array = record(level_id).get("acorns", []) as Array
	return acorns.has(index) or acorns.has(float(index))

func acorns_found(level_id: int) -> int:
	return (record(level_id).get("acorns", []) as Array).size()

## Merges a finished run into the record. Returns true for a new best time.
func store_result(level_id: int, level_count: int, result: Dictionary) -> bool:
	var levels: Dictionary = data["levels"] as Dictionary
	var rec: Dictionary = record(level_id).duplicate()
	var time: float = float(result["time"])
	var new_best: bool = not rec.has("best_time") or time < float(rec["best_time"])
	if new_best:
		rec["best_time"] = time
	rec["best_deaths"] = mini(int(rec.get("best_deaths", 999999)), int(result["deaths"]))
	rec["fireflies"] = maxi(int(rec.get("fireflies", 0)), int(result["fireflies"]))
	var acorns: Array = []
	for a in rec.get("acorns", []) as Array:
		acorns.append(int(a))
	for a in result["acorns"] as Array:
		if not acorns.has(int(a)):
			acorns.append(int(a))
	acorns.sort()
	rec["acorns"] = acorns
	rec["done"] = true
	levels[str(level_id)] = rec
	data["unlocked"] = clampi(maxi(unlocked(), int(result["index"]) + 2), 1, level_count)
	save()
	return new_best

func reset_progress() -> void:
	var settings: Dictionary = data["settings"] as Dictionary
	data = _fresh()
	data["settings"] = settings
	save()

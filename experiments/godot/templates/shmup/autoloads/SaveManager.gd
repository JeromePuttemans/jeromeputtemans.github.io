# =============================================================================
# SaveManager.gd — Autoload (Singleton): best scores and settings on disk
# =============================================================================
# user://aurore_save.json (in a browser: the IndexedDB of the site, shared by
# every game of the origin, hence the unique file name):
#   version   SAVE_VERSION; another version starts a fresh save
#   scores    per difficulty, the TOP_COUNT best runs, best first:
#             {score, chain (best multiplier), cleared, graze}
#   settings  language, muted
# =============================================================================

extends Node

const PATH: String = "user://aurore_save.json"
const SAVE_VERSION: int = 1
const TOP_COUNT: int = 5

var data: Dictionary = {}

func _ready() -> void:
	data = _fresh()
	if not FileAccess.file_exists(PATH):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(PATH)) != OK or not (json.data is Dictionary):
		return
	var loaded: Dictionary = json.data as Dictionary
	if int(loaded.get("version", 0)) == SAVE_VERSION:
		data = loaded

func _fresh() -> Dictionary:
	return {version = SAVE_VERSION, scores = {normal = [], hard = []}, settings = {}}

func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))

func get_setting(key: String, default: Variant) -> Variant:
	return (data["settings"] as Dictionary).get(key, default)

func set_setting(key: String, value: Variant) -> void:
	(data["settings"] as Dictionary)[key] = value
	save()

func scores(difficulty: String) -> Array:
	var table: Dictionary = data["scores"] as Dictionary
	if not table.has(difficulty):
		table[difficulty] = []
	return table[difficulty] as Array

func best(difficulty: String) -> int:
	var list: Array = scores(difficulty)
	return int((list[0] as Dictionary).get("score", 0)) if not list.is_empty() else 0

## Inserts a run in the table. Returns its rank (0 = best) or -1 if it does
## not enter the top.
func submit(difficulty: String, entry: Dictionary) -> int:
	var list: Array = scores(difficulty)
	var rank: int = list.size()
	for i in list.size():
		if int(entry["score"]) > int((list[i] as Dictionary).get("score", 0)):
			rank = i
			break
	if rank >= TOP_COUNT:
		return -1
	list.insert(rank, entry)
	while list.size() > TOP_COUNT:
		list.pop_back()
	save()
	return rank

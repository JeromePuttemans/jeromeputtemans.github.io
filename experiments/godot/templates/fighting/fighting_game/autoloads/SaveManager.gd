# =============================================================================
# SaveManager.gd — Autoload (Singleton): arcade clears and settings
# =============================================================================
# user://rouages_save.json (in a browser: the IndexedDB of the site, shared
# by every game of the origin, hence the unique file name):
#   version   SAVE_VERSION; another version starts a fresh save
#   cleared   "<fighter>": highest arcade difficulty cleared (0..2), absent
#             when never cleared
#   settings  language, muted
# =============================================================================

extends Node

const PATH: String = "user://rouages_save.json"
const SAVE_VERSION: int = 1

var data: Dictionary = {}

func _ready() -> void:
	data = {version = SAVE_VERSION, cleared = {}, settings = {}}
	if not FileAccess.file_exists(PATH):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(PATH)) != OK or not (json.data is Dictionary):
		return
	var loaded: Dictionary = json.data as Dictionary
	if int(loaded.get("version", 0)) == SAVE_VERSION:
		data = loaded

func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))

func get_setting(key: String, default: Variant) -> Variant:
	return (data["settings"] as Dictionary).get(key, default)

func set_setting(key: String, value: Variant) -> void:
	(data["settings"] as Dictionary)[key] = value
	save()

func cleared_level(fighter: String) -> int:
	return int((data["cleared"] as Dictionary).get(fighter, -1))

func record_clear(fighter: String, difficulty: int) -> void:
	var table: Dictionary = data["cleared"] as Dictionary
	table[fighter] = maxi(int(table.get(fighter, -1)), difficulty)
	save()

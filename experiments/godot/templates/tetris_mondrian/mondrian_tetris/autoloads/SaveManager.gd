# =============================================================================
# SaveManager.gd — Autoload (Singleton): records, gallery and settings
# =============================================================================
# user://composition_save.json (in the browser: IndexedDB of the site, shared
# by every game of the origin, hence the unique file name):
#   version    SAVE_VERSION; another version starts a fresh save
#   best       best score and its lines
#   count      finished games, which numbers the compositions
#   gallery    the last GALLERY_SIZE finished boards, newest first:
#              {n, score, lines, level, blocks: [[x, y, w, h, colour], ...]}
#   settings   language, muted, music
# =============================================================================

extends Node

const PATH: String = "user://composition_save.json"
const SAVE_VERSION: int = 1
const GALLERY_SIZE: int = 8

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
	return {version = SAVE_VERSION, best = {score = 0, lines = 0}, count = 0, gallery = [], settings = {}}

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

func best_score() -> int:
	return int((data["best"] as Dictionary).get("score", 0))

func gallery() -> Array:
	return data["gallery"] as Array

## Records a finished game. Returns {n: composition number, record: bool}.
func store_game(score: int, lines: int, level: int, blocks: Array) -> Dictionary:
	data["count"] = int(data.get("count", 0)) + 1
	var n: int = int(data["count"])
	var record: bool = score > best_score()
	if record:
		data["best"] = {score = score, lines = lines}
	var g: Array = gallery()
	g.push_front({n = n, score = score, lines = lines, level = level, blocks = blocks})
	while g.size() > GALLERY_SIZE:
		g.pop_back()
	save()
	return {n = n, record = record}

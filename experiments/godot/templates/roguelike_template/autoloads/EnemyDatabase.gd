# =============================================================================
# EnemyDatabase.gd — Autoload (Singleton)
# =============================================================================
# Loads data/enemies.json and exposes enemy type definitions by id.
# DungeonGenerator and GameState use this to spawn enemies.
# =============================================================================

extends Node

const ENEMIES_PATH = "res://data/enemies.json"
var _types: Dictionary = {}   # { id: Dictionary }

func _ready() -> void:
	_load()

func _load() -> void:
	if not FileAccess.file_exists(ENEMIES_PATH):
		push_error("EnemyDatabase: file not found → " + ENEMIES_PATH)
		return
	var file = FileAccess.open(ENEMIES_PATH, FileAccess.READ)
	if not file:
		push_error("EnemyDatabase: cannot open → " + ENEMIES_PATH)
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("EnemyDatabase: JSON parse error at line %d" % json.get_error_line())
		return
	for entry in json.get_data():
		_types[entry.get("id", "")] = entry

## Returns the raw data dictionary for a given enemy type id.
## Returns an empty dict if the id is unknown.
func get_type(id: String) -> Dictionary:
	return _types.get(id, {})

## Returns all enemy type data as an Array of Dictionaries.
func get_all() -> Array:
	return _types.values()

# =============================================================================
# UnitDatabase.gd — Autoload (Singleton)
# =============================================================================
# Loads data/units.json and exposes unit type definitions by id.
# ShopPanel and RoundManager use this to build unit instances and enemy teams.
# =============================================================================

extends Node

const UNITS_PATH = "res://data/units.json"
var _types: Dictionary = {}   # { id: Dictionary }

func _ready() -> void:
	_load()

func _load() -> void:
	if not FileAccess.file_exists(UNITS_PATH):
		push_error("UnitDatabase: not found → " + UNITS_PATH)
		return
	var file = FileAccess.open(UNITS_PATH, FileAccess.READ)
	if not file:
		push_error("UnitDatabase: cannot open → " + UNITS_PATH)
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("UnitDatabase: parse error at line %d" % json.get_error_line())
		return
	for entry in json.get_data():
		_types[entry.get("id", "")] = entry

## Returns the raw Dictionary for a given type id, or {} if unknown.
func get_type(id: String) -> Dictionary:
	return _types.get(id, {})

## Returns all type ids as an Array of Strings.
func get_all_ids() -> Array:
	return _types.keys()

## Returns all type definitions as an Array of Dictionaries.
func get_all() -> Array:
	return _types.values()

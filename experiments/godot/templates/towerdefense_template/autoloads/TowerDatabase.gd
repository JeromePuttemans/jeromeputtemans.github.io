# =============================================================================
# TowerDatabase.gd — Autoload (Singleton)
# =============================================================================
# Loads data/towers.json on startup.
# Provides get_type(id) and get_all() for the shop panel and tower logic.
# =============================================================================

extends Node

const PATH = "res://data/towers.json"
var _types: Dictionary = {}   # id -> Dictionary

func _ready() -> void:
	if not FileAccess.file_exists(PATH):
		push_error("TowerDatabase: not found — " + PATH)
		return
	var f = FileAccess.open(PATH, FileAccess.READ)
	if not f:
		return
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("TowerDatabase: parse error at line %d" % j.get_error_line())
		return
	for entry in j.get_data():
		_types[entry["id"]] = entry

func get_type(id: String) -> Dictionary:
	return _types.get(id, {})

func get_all() -> Array:
	return _types.values()

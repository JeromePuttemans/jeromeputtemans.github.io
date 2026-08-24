# =============================================================================
# EnemyDatabase.gd — Autoload (Singleton)
# =============================================================================
# Loads data/enemies.json on startup.
# =============================================================================

extends Node

const PATH = "res://data/enemies.json"
var _types: Dictionary = {}

func _ready() -> void:
	if not FileAccess.file_exists(PATH):
		push_error("EnemyDatabase: not found — " + PATH)
		return
	var f = FileAccess.open(PATH, FileAccess.READ)
	if not f:
		return
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("EnemyDatabase: parse error at line %d" % j.get_error_line())
		return
	for entry in j.get_data():
		_types[entry["id"]] = entry

func get_type(id: String) -> Dictionary:
	return _types.get(id, {})

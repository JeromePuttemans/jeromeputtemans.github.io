# =============================================================================
# EnemyDatabase.gd — Autoload #4
# Loads data/enemies.json. Provides get_type(id) → Dictionary.
# =============================================================================
extends Node

const PATH = "res://data/enemies.json"
var _types: Dictionary = {}

func _ready() -> void:
	var f = FileAccess.open(PATH, FileAccess.READ)
	if not f: push_error("EnemyDatabase: " + PATH); return
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("EnemyDatabase: parse error"); return
	for e in j.get_data():
		_types[e["id"]] = e

func get_type(id: String) -> Dictionary:
	return _types.get(id, {})

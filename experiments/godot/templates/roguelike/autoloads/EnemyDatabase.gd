# =============================================================================
# EnemyDatabase.gd (Autoload, Singleton)
# =============================================================================
# Loads data/enemies.json and exposes enemy type definitions.
#
# SPAWN TABLE BY DEPTH:
#   Each type declares min_floor, max_floor and weight. pick_for_floor() keeps
#   the types allowed on that floor and draws one with probability
#   weight / sum(weights). Example on floor 1: rat (5) and bat (3) are
#   allowed, so a rat is drawn 5 times out of 8. Trolls (min_floor 3) can
#   never appear on floor 1.
#   The boss ("boss": true) is never drawn: DungeonGenerator places it.
# =============================================================================

extends Node

const ENEMIES_PATH: String = "res://data/enemies.json"
var _types: Dictionary = {}   # { id: Dictionary }

func _ready() -> void:
	_load()

func _load() -> void:
	if not FileAccess.file_exists(ENEMIES_PATH):
		push_error("EnemyDatabase: file not found: " + ENEMIES_PATH)
		return
	var file: FileAccess = FileAccess.open(ENEMIES_PATH, FileAccess.READ)
	if file == null:
		push_error("EnemyDatabase: cannot open " + ENEMIES_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("EnemyDatabase: JSON parse error at line %d" % json.get_error_line())
		return
	for entry_v in json.get_data() as Array:
		var entry: Dictionary = entry_v as Dictionary
		_types[str(entry.get("id", ""))] = entry

## Raw definition of an enemy type, or an empty Dictionary if unknown.
func get_type(id: String) -> Dictionary:
	return _types.get(id, {}) as Dictionary

func get_all() -> Array:
	return _types.values()

## Weighted random type allowed on this floor ("" if none).
func pick_for_floor(floor_number: int, rng: RandomNumberGenerator) -> String:
	var pool: Array[Dictionary] = []
	var total: float = 0.0
	for t_v in _types.values():
		var t: Dictionary = t_v as Dictionary
		if bool(t.get("boss", false)):
			continue
		if floor_number < int(t.get("min_floor", 1)) or floor_number > int(t.get("max_floor", 99)):
			continue
		var w: float = float(t.get("weight", 1))
		if w <= 0.0:
			continue
		pool.append(t)
		total += w
	if pool.is_empty():
		return ""
	var roll: float = rng.randf() * total
	for t in pool:
		roll -= float(t.get("weight", 1))
		if roll <= 0.0:
			return str(t.get("id", ""))
	return str(pool[pool.size() - 1].get("id", ""))

## Id of the boss type, or "" if the data has none.
func get_boss_id() -> String:
	for t_v in _types.values():
		var t: Dictionary = t_v as Dictionary
		if bool(t.get("boss", false)):
			return str(t.get("id", ""))
	return ""

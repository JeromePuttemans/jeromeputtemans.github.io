# =============================================================================
# ItemDatabase.gd (Autoload, Singleton)
# =============================================================================
# Loads data/items.json. Same weighted, depth-aware draw as EnemyDatabase
# (min_floor + weight), plus helpers that build the localised name and
# description of an item from its data (values are injected in the text, so
# changing "value" in items.json updates the description automatically).
#
# Two families of items:
#   instant: true   upgrades applied on pickup (ATK, DEF, max HP)
#   instant: false  consumables stored in the inventory (limited slots)
# =============================================================================

extends Node

const ITEMS_PATH: String = "res://data/items.json"
var _types: Dictionary = {}

func _ready() -> void:
	if not FileAccess.file_exists(ITEMS_PATH):
		push_error("ItemDatabase: file not found: " + ITEMS_PATH)
		return
	var file: FileAccess = FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("ItemDatabase: JSON parse error at line %d" % json.get_error_line())
		return
	for entry_v in json.get_data() as Array:
		var entry: Dictionary = entry_v as Dictionary
		_types[str(entry.get("id", ""))] = entry

func get_type(id: String) -> Dictionary:
	return _types.get(id, {}) as Dictionary

func pick_for_floor(floor_number: int, rng: RandomNumberGenerator) -> String:
	var pool: Array[Dictionary] = []
	var total: float = 0.0
	for t_v in _types.values():
		var t: Dictionary = t_v as Dictionary
		if floor_number < int(t.get("min_floor", 1)):
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

func display_name(item: Dictionary) -> String:
	var id: String = str(item.get("id", ""))
	return StringManager.t_or("item_%s_name" % id, id)

func description(item: Dictionary) -> String:
	var id: String = str(item.get("id", ""))
	var value: float = float(item.get("value", 0))
	return StringManager.t("item_%s_desc" % id, {
		value  = int(value),
		pct    = int(round(value * 100.0)),
		radius = int(item.get("radius", 0))})

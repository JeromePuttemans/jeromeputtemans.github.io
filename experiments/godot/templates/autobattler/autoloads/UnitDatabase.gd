# =============================================================================
# UnitDatabase.gd — Autoload (Singleton)
# =============================================================================
# Loads data/units.json (12 shop units and the boss) and data/traits.json
# (the 7 synergies), and draws random units with the shop odds.
#
# SHOP ODDS: config.shop_odds gives, for each player level, the chance (in %)
# of each tier: at level 3, 75 % tier 1 and 25 % tier 2; at level 8, 15 %,
# 40 % and 45 %. A tier is drawn first, then a unit of that tier.
# =============================================================================

extends Node

var _units: Dictionary = {}    # id -> data
var _order: Array[String] = []
var _traits: Dictionary = {}   # id -> data
var _trait_order: Array[String] = []

func _ready() -> void:
	var units: Variant = ConfigManager.load_json("res://data/units.json")
	for entry_v in units as Array if units is Array else []:
		var entry: Dictionary = entry_v as Dictionary
		_units[str(entry["id"])] = entry
		_order.append(str(entry["id"]))
	var traits: Variant = ConfigManager.load_json("res://data/traits.json")
	for entry_v in traits as Array if traits is Array else []:
		var entry: Dictionary = entry_v as Dictionary
		_traits[str(entry["id"])] = entry
		_trait_order.append(str(entry["id"]))

func unit_data(id: String) -> Dictionary:
	return _units.get(id, {}) as Dictionary

func trait_data(id: String) -> Dictionary:
	return _traits.get(id, {}) as Dictionary

func trait_ids() -> Array[String]:
	return _trait_order

func trait_color(id: String) -> Color:
	return Color.from_string(str(trait_data(id).get("color", "#ffffff")), Color.WHITE)

func shop_ids() -> Array[String]:
	var result: Array[String] = []
	for id in _order:
		if not bool((_units[id] as Dictionary).get("boss", false)):
			result.append(id)
	return result

func boss_id() -> String:
	for id in _order:
		if bool((_units[id] as Dictionary).get("boss", false)):
			return id
	return ""

func ids_of_tier(tier: int) -> Array[String]:
	var result: Array[String] = []
	for id in shop_ids():
		if int((_units[id] as Dictionary).get("tier", 1)) == tier:
			result.append(id)
	return result

## Tier odds (in %) for a player level, from config.shop_odds.
func odds_for_level(level: int) -> Array:
	var odds: Dictionary = ConfigManager.get_dict("shop_odds")
	var key: String = str(clampi(level, 3, 8))
	return odds.get(key, [100, 0, 0]) as Array

func random_id_for_level(level: int, rng: RandomNumberGenerator) -> String:
	var odds: Array = odds_for_level(level)
	var roll: float = rng.randf() * 100.0
	var tier: int = 1
	for i in odds.size():
		roll -= float(odds[i])
		if roll < 0.0:
			tier = i + 1
			break
	var pool: Array[String] = ids_of_tier(tier)
	if pool.is_empty():
		pool = ids_of_tier(1)
	return pool[rng.randi() % pool.size()]

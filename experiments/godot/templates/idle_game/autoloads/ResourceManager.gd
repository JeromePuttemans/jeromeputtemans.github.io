# =============================================================================
# ResourceManager.gd — Autoload (Singleton)
# =============================================================================
# State of every resource listed in config.json ("shards" by default).
# Each resource keeps three amounts:
#   current          what the player can spend
#   total_produced   everything produced during this run (reset by a
#                    crystallization); unlocks RESOURCE_TOTAL upgrades
#   lifetime         everything ever produced, never reset; decides how many
#                    prisms a crystallization gives
# resource_changed fires on every change (every frame while producing): the
# UI listens to it instead of polling.
# =============================================================================

extends Node

signal resource_changed(resource_id: String, new_value: float)
signal total_produced_changed(resource_id: String, total: float)

var resources: Dictionary = {}   # id -> {current, total_produced, lifetime}
var main_resource: String = "shards"

func _ready() -> void:
	main_resource = ConfigManager.get_string("main_resource", "shards")
	for id_v in ConfigManager.get_array("resources"):
		_register(str(id_v))
	if not resources.has(main_resource):
		_register(main_resource)

func _register(id: String) -> void:
	resources[id] = {"current": 0.0, "total_produced": 0.0, "lifetime": 0.0}

# =============================================================================
# PUBLIC API
# =============================================================================

func add(resource_id: String, amount: float) -> void:
	if amount <= 0.0 or not resources.has(resource_id):
		return
	var entry: Dictionary = resources[resource_id]
	entry["current"] = float(entry["current"]) + amount
	entry["total_produced"] = float(entry["total_produced"]) + amount
	entry["lifetime"] = float(entry["lifetime"]) + amount
	resource_changed.emit(resource_id, float(entry["current"]))
	total_produced_changed.emit(resource_id, float(entry["total_produced"]))

func spend(resource_id: String, amount: float) -> bool:
	if amount <= 0.0 or not can_afford(resource_id, amount):
		return false
	var entry: Dictionary = resources[resource_id]
	entry["current"] = float(entry["current"]) - amount
	resource_changed.emit(resource_id, float(entry["current"]))
	return true

func can_afford(resource_id: String, amount: float) -> bool:
	return get_amount(resource_id) >= amount

func get_amount(resource_id: String) -> float:
	return float((resources.get(resource_id, {}) as Dictionary).get("current", 0.0))

func get_total_produced(resource_id: String) -> float:
	return float((resources.get(resource_id, {}) as Dictionary).get("total_produced", 0.0))

func get_lifetime(resource_id: String) -> float:
	return float((resources.get(resource_id, {}) as Dictionary).get("lifetime", 0.0))

## Crystallization: current and run totals back to 0, lifetime kept.
func reset_run() -> void:
	for id in resources:
		var entry: Dictionary = resources[id]
		entry["current"] = 0.0
		entry["total_produced"] = 0.0
	resource_changed.emit(main_resource, 0.0)

## Hard reset: everything back to 0, lifetime included.
func reset_all() -> void:
	for id in resources:
		_register(str(id))
	resource_changed.emit(main_resource, 0.0)

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	return resources.duplicate(true)

func from_dict(data: Dictionary) -> void:
	for key in data:
		if resources.has(key) and data[key] is Dictionary:
			var saved: Dictionary = data[key] as Dictionary
			resources[key] = {
				"current": float(saved.get("current", 0.0)),
				"total_produced": float(saved.get("total_produced", 0.0)),
				"lifetime": float(saved.get("lifetime", saved.get("total_produced", 0.0)))}
	resource_changed.emit(main_resource, get_amount(main_resource))

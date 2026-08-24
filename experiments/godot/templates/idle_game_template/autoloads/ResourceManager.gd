# =============================================================================
# ResourceManager.gd — Autoload (Singleton)
# =============================================================================
# Manages the state of all game resources.
# Resource IDs and initial list come from ConfigManager (data/config.json).
# No resource name is hardcoded here.
# =============================================================================

extends Node

signal resource_changed(resource_id: String, new_value: float)
signal total_produced_changed(resource_id: String, total: float)

# Structure: { "resource_id": { "current": float, "total_produced": float } }
var resources: Dictionary = {}

## Shortcut to the primary resource ID — avoids repeating ConfigManager calls.
var main_resource: String

func _ready() -> void:
	main_resource = ConfigManager.main_resource
	for id in ConfigManager.resources:
		_register_resource(id)

func _register_resource(id: String, initial_value: float = 0.0) -> void:
	resources[id] = {"current": initial_value, "total_produced": 0.0}

# =============================================================================
# PUBLIC API
# =============================================================================

func add(resource_id: String, amount: float) -> void:
	if amount <= 0.0:
		push_warning("ResourceManager.add: invalid amount (%s) for '%s'" % [amount, resource_id])
		return
	if not resources.has(resource_id):
		push_error("ResourceManager.add: unknown resource → " + resource_id)
		return
	resources[resource_id]["current"]        += amount
	resources[resource_id]["total_produced"] += amount
	emit_signal("resource_changed",       resource_id, resources[resource_id]["current"])
	emit_signal("total_produced_changed", resource_id, resources[resource_id]["total_produced"])

func spend(resource_id: String, amount: float) -> bool:
	if amount <= 0.0:
		push_warning("ResourceManager.spend: invalid amount (%s) for '%s'" % [amount, resource_id])
		return false
	if not can_afford(resource_id, amount):
		return false
	resources[resource_id]["current"] -= amount
	emit_signal("resource_changed", resource_id, resources[resource_id]["current"])
	return true

func can_afford(resource_id: String, amount: float) -> bool:
	return resources.get(resource_id, {}).get("current", 0.0) >= amount

func get_amount(resource_id: String) -> float:
	return resources.get(resource_id, {}).get("current", 0.0)

func get_total_produced(resource_id: String) -> float:
	return resources.get(resource_id, {}).get("total_produced", 0.0)

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	return resources.duplicate(true)

func from_dict(data: Dictionary) -> void:
	for key in data:
		if resources.has(key):
			resources[key] = data[key]
	# Re-emit so UI refreshes after a load
	emit_signal("resource_changed", main_resource, get_amount(main_resource))

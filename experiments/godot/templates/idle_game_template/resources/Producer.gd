# =============================================================================
# Producer.gd — Data class for a passive resource generator
# =============================================================================
# All default values are intentionally neutral (0 / 1.0).
# Real values are always injected from data/producers.json by ProducerManager.
# =============================================================================

class_name Producer
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var base_cost: float = 0.0
# Neutral default = 1.0 (no exponential growth). Real value comes from JSON.
# Formula: current_cost = base_cost * cost_growth_rate ^ owned
@export var cost_growth_rate: float = 1.0
@export var base_production: float = 0.0

var owned: int = 0
var multiplier: float = 1.0

func get_current_cost() -> float:
	return base_cost * pow(cost_growth_rate, owned)

## Bulk buy cost using geometric series sum: base * (r^n - 1) / (r - 1)
func get_bulk_cost(amount: int) -> float:
	if cost_growth_rate == 1.0:
		return base_cost * amount
	return base_cost * pow(cost_growth_rate, owned) \
		* (pow(cost_growth_rate, amount) - 1.0) / (cost_growth_rate - 1.0)

func get_rps() -> float:
	return base_production * owned * multiplier

func to_dict() -> Dictionary:
	return {"id": id, "owned": owned, "multiplier": multiplier}

func from_dict(data: Dictionary) -> void:
	owned      = data.get("owned", 0)
	multiplier = data.get("multiplier", 1.0)

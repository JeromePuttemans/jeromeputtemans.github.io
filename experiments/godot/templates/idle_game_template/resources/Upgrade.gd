# =============================================================================
# Upgrade.gd — Data class for a one-time improvement
# =============================================================================
# All default values are intentionally neutral (0 / 1.0).
# Real values are always injected from data/upgrades.json by ProducerManager.
# =============================================================================

class_name Upgrade
extends Resource

enum UnlockType { OWNED_COUNT, RESOURCE_TOTAL }
enum EffectType  { MULTIPLY_PRODUCER, MULTIPLY_ALL, MULTIPLY_CLICK }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var cost: float = 0.0

@export var unlock_type: UnlockType = UnlockType.OWNED_COUNT
@export var unlock_producer_id: String = ""
@export var unlock_threshold: float = 0.0

@export var effect_type: EffectType = EffectType.MULTIPLY_PRODUCER
@export var effect_producer_id: String = ""
@export var effect_multiplier: float = 1.0  # Neutral: no effect

var is_purchased: bool = false

func is_unlocked(producers: Dictionary, total_resources: float) -> bool:
	match unlock_type:
		UnlockType.OWNED_COUNT:
			var producer = producers.get(unlock_producer_id)
			if producer:
				return producer.owned >= unlock_threshold
		UnlockType.RESOURCE_TOTAL:
			return total_resources >= unlock_threshold
	return false

func to_dict() -> Dictionary:
	return {"id": id, "is_purchased": is_purchased}

func from_dict(data: Dictionary) -> void:
	is_purchased = data.get("is_purchased", false)

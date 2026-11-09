# =============================================================================
# Upgrade.gd — Data class for a one-time improvement
# =============================================================================
# Values are injected from data/upgrades.json by ProducerManager.
#
# UNLOCK
#   OWNED_COUNT     unlock_producer_id owned >= unlock_threshold
#   RESOURCE_TOTAL  shards produced during this run >= unlock_threshold
# EFFECT (effect_value)
#   MULTIPLY_PRODUCER  production of effect_producer_id x value
#   MULTIPLY_ALL       production of every producer x value
#   MULTIPLY_CLICK     base value of a click x value
#   CLICK_RPS_SHARE    each click also gives value x production per second
#                      (0.02 = 2 % of the production per second)
# NAME: StringManager.t(name_key, {producer = name of name_producer}), so the
#   32 producer upgrades share four name patterns ("{producer}: tuning"...).
# =============================================================================

class_name Upgrade
extends Resource

enum UnlockType { OWNED_COUNT, RESOURCE_TOTAL }
enum EffectType { MULTIPLY_PRODUCER, MULTIPLY_ALL, MULTIPLY_CLICK, CLICK_RPS_SHARE }

@export var id: String = ""
@export var name_key: String = ""
@export var name_producer: String = ""
@export var cost: float = 0.0
@export var unlock_type: UnlockType = UnlockType.OWNED_COUNT
@export var unlock_producer_id: String = ""
@export var unlock_threshold: float = 0.0
@export var effect_type: EffectType = EffectType.MULTIPLY_PRODUCER
@export var effect_producer_id: String = ""
@export var effect_value: float = 1.0

var is_purchased: bool = false

func is_unlocked(producers: Dictionary, run_total: float) -> bool:
	match unlock_type:
		UnlockType.OWNED_COUNT:
			var producer: Producer = producers.get(unlock_producer_id) as Producer
			return producer != null and producer.owned >= unlock_threshold
		UnlockType.RESOURCE_TOTAL:
			return run_total >= unlock_threshold
	return false

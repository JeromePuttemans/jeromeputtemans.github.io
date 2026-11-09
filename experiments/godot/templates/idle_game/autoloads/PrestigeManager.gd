# =============================================================================
# PrestigeManager.gd — Autoload (Singleton)
# =============================================================================
# Crystallization (the prestige of the genre): the player restarts from zero
# in exchange for prisms, a permanent bonus.
#
#   prisms earned in total = floor((lifetime / prestige_threshold) ^ prestige_exponent)
#   gain now               = that number - prisms already owned
#   bonus                  = +prestige_bonus_per_prism per prism (10 %),
#                            applied to production and clicks
#
# With a threshold of 1 M shards and an exponent of 1/3 (cube root): 1 M
# produced in total gives 1 prism, 8 M give 2, 1 billion give 10, 1 000
# billion give 100. The root makes each prism harder to get than the last:
# production grows exponentially, so a square root let the bonus snowball
# (a second run gave a hundred times more prisms than the first). lifetime is
# never reset, so prisms cannot be farmed by repeating short runs.
# =============================================================================

extends Node

signal prestige_done(gained: int, total: int)

var prisms: int = 0
var prestige_count: int = 0

func multiplier() -> float:
	return 1.0 + prisms * ConfigManager.get_float("prestige_bonus_per_prism", 0.1)

func prisms_for(lifetime: float) -> int:
	var threshold: float = maxf(ConfigManager.get_float("prestige_threshold", 1.0e6), 1.0)
	var exponent: float = ConfigManager.get_float("prestige_exponent", 0.3333333)
	# The small epsilon keeps exact thresholds (8 M -> 2 prisms) from rounding down
	return int(floor(pow(maxf(lifetime, 0.0) / threshold, exponent) + 0.000001))

func pending_gain() -> int:
	return maxi(prisms_for(ResourceManager.get_lifetime(ResourceManager.main_resource)) - prisms, 0)

func can_prestige() -> bool:
	return pending_gain() >= 1

## Lifetime total needed for one more prism than the pending gain.
func next_prism_at() -> float:
	var next_total: int = prisms + pending_gain() + 1
	var exponent: float = ConfigManager.get_float("prestige_exponent", 0.3333333)
	return ConfigManager.get_float("prestige_threshold", 1.0e6) * pow(float(next_total), 1.0 / exponent)

func prestige() -> bool:
	var gain: int = pending_gain()
	if gain < 1:
		return false
	prisms += gain
	prestige_count += 1
	ResourceManager.reset_run()
	ProducerManager.reset_run()
	BoostManager.reset()
	prestige_done.emit(gain, prisms)
	return true

func reset_all() -> void:
	prisms = 0
	prestige_count = 0

func to_dict() -> Dictionary:
	return {"prisms": prisms, "prestige_count": prestige_count}

func from_dict(data: Dictionary) -> void:
	prisms = int(data.get("prisms", 0))
	prestige_count = int(data.get("prestige_count", 0))

# =============================================================================
# Producer.gd — Data class for a passive resource generator
# =============================================================================
# Values are injected from data/producers.json by ProducerManager.
#
# COST CURVE: current_cost = base_cost * cost_growth_rate ^ owned
#   Buying N units at once is a geometric series:
#   bulk_cost = base_cost * r^owned * (r^N - 1) / (r - 1)
#   and the largest N affordable with a budget B solves that equation for N:
#   N = floor(log(1 + B * (r - 1) / current_cost) / log(r))
#
# PRODUCTION: base_production * owned * multiplier * milestone_multiplier
#   multiplier           product of the purchased upgrades for this producer
#   milestone_multiplier x2 for every milestone reached (10, 25, 50... owned),
#                        recomputed by ProducerManager after each purchase
# =============================================================================

class_name Producer
extends Resource

@export var id: String = ""
@export var base_cost: float = 0.0
@export var cost_growth_rate: float = 1.0
@export var base_production: float = 0.0
@export var color: Color = Color.WHITE
@export var sides: int = 3

var owned: int = 0
var multiplier: float = 1.0
var milestone_multiplier: float = 1.0

func get_current_cost() -> float:
	return base_cost * pow(cost_growth_rate, owned)

func get_bulk_cost(amount: int) -> float:
	if amount <= 0:
		return 0.0
	if is_equal_approx(cost_growth_rate, 1.0):
		return base_cost * amount
	return get_current_cost() * (pow(cost_growth_rate, amount) - 1.0) / (cost_growth_rate - 1.0)

## Largest number of units affordable with `budget` (0 if not even one).
func max_affordable(budget: float) -> int:
	var cost: float = get_current_cost()
	if budget < cost or cost <= 0.0:
		return 0
	if is_equal_approx(cost_growth_rate, 1.0):
		return int(budget / cost)
	var count: int = int(floor(log(1.0 + budget * (cost_growth_rate - 1.0) / cost) / log(cost_growth_rate)))
	# Float rounding can overshoot by one unit near the boundary
	while count > 0 and get_bulk_cost(count) > budget:
		count -= 1
	return count

## Production per second of one unit, with every multiplier of this producer.
func get_unit_rps() -> float:
	return base_production * multiplier * milestone_multiplier

func get_rps() -> float:
	return get_unit_rps() * owned

## First milestone strictly above the owned count, or -1 when all are reached.
func next_milestone(milestones: Array) -> int:
	for m in milestones:
		if int(m) > owned:
			return int(m)
	return -1

## Previous milestone (or 0), for the progress bar towards the next one.
func previous_milestone(milestones: Array) -> int:
	var previous: int = 0
	for m in milestones:
		if int(m) <= owned:
			previous = int(m)
	return previous

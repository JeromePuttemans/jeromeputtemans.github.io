# =============================================================================
# ProducerManager.gd — Autoload (Singleton)
# =============================================================================
# Producers, upgrades, milestones and the production stack.
#
# PRODUCTION STACK (shards per second):
#   base_rps  = sum(producer rps) x global_multiplier x prestige multiplier
#   total_rps = base_rps x boost multiplier (overheat, eruption)
#   producer rps = base_production x owned x upgrades x milestones
# CLICK VALUE:
#   (click_base_value x click_multiplier + click_rps_share x base_rps)
#   x prestige multiplier x overheat multiplier
#   click_rps_share comes from the "echo" upgrades: a click also gives a
#   share of the production per second, so clicking stays useful late.
# MILESTONES: every time a producer reaches a count of config.milestones
#   (10, 25, 50...), its production doubles (milestone_reached).
# REVEAL: a producer appears in the list once the shards produced this run
#   reach reveal_ratio x its base cost (half), or once one is owned. The next
#   hidden one is shown as a locked silhouette.
# SAVE: only owned counts and purchased upgrades are saved; multipliers are
#   recomputed by replaying the purchased upgrades (derived values are never
#   stored, so a load can never double them).
# =============================================================================

extends Node

signal producer_purchased(producer: Producer, amount: int)
signal upgrade_purchased(upgrade: Upgrade)
signal upgrade_unlocked(upgrade: Upgrade)
signal milestone_reached(producer: Producer, milestone: int)
signal producer_revealed(producer: Producer)

const BUY_MODES: Array[int] = [1, 10, 100, -1]   # -1 = as many as affordable

var producers: Dictionary = {}     # id -> Producer, in data order
var producer_order: Array[String] = []
var upgrades: Dictionary = {}      # id -> Upgrade
var upgrade_order: Array[String] = []
var click_multiplier: float = 1.0
var click_rps_share: float = 0.0
var global_multiplier: float = 1.0

var _signaled_upgrades: Dictionary = {}
var _revealed: Dictionary = {}

func _ready() -> void:
	_load_producers()
	_load_upgrades()
	ResourceManager.total_produced_changed.connect(_on_total_produced_changed)

# =============================================================================
# DATA LOADING
# =============================================================================

func _load_producers() -> void:
	var raw: Variant = ConfigManager.load_json("res://data/producers.json")
	if not raw is Array:
		return
	for entry_v in raw as Array:
		var entry: Dictionary = entry_v as Dictionary
		var p := Producer.new()
		p.id = str(entry.get("id", ""))
		p.base_cost = float(entry.get("base_cost", 0.0))
		p.cost_growth_rate = float(entry.get("cost_growth_rate", 1.0))
		p.base_production = float(entry.get("base_production", 0.0))
		p.color = Color.from_string(str(entry.get("color", "#ffffff")), Color.WHITE)
		p.sides = int(entry.get("sides", 3))
		if p.id.is_empty():
			continue
		producers[p.id] = p
		producer_order.append(p.id)

func _load_upgrades() -> void:
	var raw: Variant = ConfigManager.load_json("res://data/upgrades.json")
	if not raw is Array:
		return
	for entry_v in raw as Array:
		var entry: Dictionary = entry_v as Dictionary
		var u := Upgrade.new()
		u.id = str(entry.get("id", ""))
		u.name_key = str(entry.get("name_key", ""))
		u.name_producer = str(entry.get("name_producer", ""))
		u.cost = float(entry.get("cost", 0.0))
		u.unlock_type = Upgrade.UnlockType.RESOURCE_TOTAL if entry.get("unlock_type", "") == "RESOURCE_TOTAL" else Upgrade.UnlockType.OWNED_COUNT
		u.unlock_producer_id = str(entry.get("unlock_producer_id", ""))
		u.unlock_threshold = float(entry.get("unlock_threshold", 0.0))
		u.effect_type = _parse_effect(str(entry.get("effect_type", "")))
		u.effect_producer_id = str(entry.get("effect_producer_id", ""))
		u.effect_value = float(entry.get("effect_value", 1.0))
		if u.id.is_empty():
			continue
		upgrades[u.id] = u
		upgrade_order.append(u.id)

func _parse_effect(text: String) -> Upgrade.EffectType:
	match text:
		"MULTIPLY_ALL":
			return Upgrade.EffectType.MULTIPLY_ALL
		"MULTIPLY_CLICK":
			return Upgrade.EffectType.MULTIPLY_CLICK
		"CLICK_RPS_SHARE":
			return Upgrade.EffectType.CLICK_RPS_SHARE
	return Upgrade.EffectType.MULTIPLY_PRODUCER

# =============================================================================
# PRODUCTION
# =============================================================================

func get_base_rps() -> float:
	var total: float = 0.0
	for p in producers.values():
		total += (p as Producer).get_rps()
	return total * global_multiplier * PrestigeManager.multiplier()

func get_total_rps() -> float:
	return get_base_rps() * BoostManager.production_multiplier()

## Shards per second of one producer type, as it counts in the total.
func get_producer_rps(producer: Producer) -> float:
	return producer.get_rps() * global_multiplier * PrestigeManager.multiplier() * BoostManager.production_multiplier()

func click_value() -> float:
	var base: float = ConfigManager.get_float("click_base_value", 1.0) * click_multiplier
	return (base + click_rps_share * get_base_rps()) * PrestigeManager.multiplier() * BoostManager.click_multiplier()

func tick(delta: float) -> void:
	var amount: float = get_total_rps() * delta
	if amount > 0.0:
		ResourceManager.add(ResourceManager.main_resource, amount)

# =============================================================================
# PURCHASES
# =============================================================================

## Units bought with a buy mode (1, 10, 100 or -1 = max), at least 1 so the
## card always shows the price of the next unit.
func amount_for_mode(producer: Producer, mode: int) -> int:
	if mode > 0:
		return mode
	return maxi(producer.max_affordable(ResourceManager.get_amount(ResourceManager.main_resource)), 1)

func buy_producer(producer_id: String, mode: int) -> int:
	var producer: Producer = producers.get(producer_id) as Producer
	if producer == null:
		return 0
	var amount: int = amount_for_mode(producer, mode)
	if not ResourceManager.spend(ResourceManager.main_resource, producer.get_bulk_cost(amount)):
		return 0
	var before: int = producer.owned
	producer.owned += amount
	_update_milestones(producer, before)
	_reveal(producer)
	producer_purchased.emit(producer, amount)
	_check_unlocks()
	return amount

func _update_milestones(producer: Producer, before: int) -> void:
	var mult: float = ConfigManager.get_float("milestone_multiplier", 2.0)
	var reached: int = 0
	for m_v in ConfigManager.get_array("milestones"):
		var m: int = int(m_v)
		if producer.owned >= m:
			reached += 1
			if before < m:
				milestone_reached.emit(producer, m)
	producer.milestone_multiplier = pow(mult, reached)

func buy_upgrade(upgrade_id: String) -> bool:
	var upgrade: Upgrade = upgrades.get(upgrade_id) as Upgrade
	if upgrade == null or upgrade.is_purchased:
		return false
	if not upgrade.is_unlocked(producers, ResourceManager.get_total_produced(ResourceManager.main_resource)):
		return false
	if not ResourceManager.spend(ResourceManager.main_resource, upgrade.cost):
		return false
	upgrade.is_purchased = true
	_apply_upgrade(upgrade)
	upgrade_purchased.emit(upgrade)
	return true

func _apply_upgrade(upgrade: Upgrade) -> void:
	match upgrade.effect_type:
		Upgrade.EffectType.MULTIPLY_PRODUCER:
			var target: Producer = producers.get(upgrade.effect_producer_id) as Producer
			if target != null:
				target.multiplier *= upgrade.effect_value
		Upgrade.EffectType.MULTIPLY_ALL:
			global_multiplier *= upgrade.effect_value
		Upgrade.EffectType.MULTIPLY_CLICK:
			click_multiplier *= upgrade.effect_value
		Upgrade.EffectType.CLICK_RPS_SHARE:
			click_rps_share += upgrade.effect_value

## Unlocked and not yet purchased, cheapest first (the shop order).
func available_upgrades() -> Array[Upgrade]:
	var result: Array[Upgrade] = []
	var run_total: float = ResourceManager.get_total_produced(ResourceManager.main_resource)
	for id in upgrade_order:
		var upgrade: Upgrade = upgrades[id] as Upgrade
		if not upgrade.is_purchased and upgrade.is_unlocked(producers, run_total):
			result.append(upgrade)
	result.sort_custom(func(a: Upgrade, b: Upgrade) -> bool: return a.cost < b.cost)
	return result

func _check_unlocks() -> void:
	var run_total: float = ResourceManager.get_total_produced(ResourceManager.main_resource)
	for id in upgrade_order:
		var upgrade: Upgrade = upgrades[id] as Upgrade
		if upgrade.is_purchased or _signaled_upgrades.has(id):
			continue
		if upgrade.is_unlocked(producers, run_total):
			_signaled_upgrades[id] = true
			upgrade_unlocked.emit(upgrade)

func _on_total_produced_changed(_resource_id: String, total: float) -> void:
	_check_unlocks()
	var ratio: float = ConfigManager.get_float("reveal_ratio", 0.5)
	for id in producer_order:
		var producer: Producer = producers[id] as Producer
		if not _revealed.has(id) and total >= producer.base_cost * ratio:
			_reveal(producer)

func _reveal(producer: Producer) -> void:
	if _revealed.has(producer.id):
		return
	_revealed[producer.id] = true
	producer_revealed.emit(producer)

func is_revealed(producer: Producer) -> bool:
	return _revealed.has(producer.id)

# =============================================================================
# RESET AND SERIALIZATION
# =============================================================================

## Crystallization: producers, upgrades and their effects back to zero.
func reset_run() -> void:
	for p in producers.values():
		var producer: Producer = p as Producer
		producer.owned = 0
		producer.multiplier = 1.0
		producer.milestone_multiplier = 1.0
	for u in upgrades.values():
		(u as Upgrade).is_purchased = false
	click_multiplier = 1.0
	click_rps_share = 0.0
	global_multiplier = 1.0
	_signaled_upgrades.clear()
	_revealed.clear()

func to_dict() -> Dictionary:
	var owned: Dictionary = {}
	for id in producers:
		owned[id] = (producers[id] as Producer).owned
	var purchased: Array = []
	for id in upgrades:
		if (upgrades[id] as Upgrade).is_purchased:
			purchased.append(id)
	return {"owned": owned, "upgrades": purchased}

func from_dict(data: Dictionary) -> void:
	reset_run()
	var owned: Dictionary = data.get("owned", {}) as Dictionary
	for id in owned:
		if producers.has(id):
			var producer: Producer = producers[id] as Producer
			producer.owned = int(owned[id])
			_update_milestones(producer, producer.owned)
			if producer.owned > 0:
				_revealed[id] = true
	for id_v in data.get("upgrades", []) as Array:
		var id: String = str(id_v)
		if upgrades.has(id):
			var upgrade: Upgrade = upgrades[id] as Upgrade
			upgrade.is_purchased = true
			_apply_upgrade(upgrade)
			_signaled_upgrades[id] = true

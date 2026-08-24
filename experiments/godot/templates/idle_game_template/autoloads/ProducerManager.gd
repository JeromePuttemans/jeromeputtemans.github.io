# =============================================================================
# ProducerManager.gd — Autoload (Singleton)
# =============================================================================
# Manages all producers, upgrades, and total RPS.
# Game data is loaded from data/producers.json and data/upgrades.json.
# The resource ID used for transactions comes from ResourceManager.main_resource.
# =============================================================================

extends Node

signal producer_purchased(producer: Producer)
signal upgrade_purchased(upgrade: Upgrade)
signal upgrade_unlocked(upgrade: Upgrade)

var producers: Dictionary = {}
var upgrades: Dictionary = {}
var click_multiplier: float = 1.0

var _already_signaled_upgrades: Dictionary = {}

func _ready() -> void:
	_load_producers()
	_load_upgrades()
	ResourceManager.total_produced_changed.connect(_on_total_produced_changed)

# =============================================================================
# DATA LOADING
# =============================================================================

func _load_producers() -> void:
	var raw = _parse_json_file("res://data/producers.json")
	if raw == null:
		return
	for entry in raw:
		var p = Producer.new()
		p.id               = entry.get("id", "")
		p.display_name     = entry.get("display_name", "")
		p.description      = entry.get("description", "")
		p.base_cost        = float(entry.get("base_cost", 0.0))
		p.cost_growth_rate = float(entry.get("cost_growth_rate", 1.0))
		p.base_production  = float(entry.get("base_production", 0.0))
		if p.id.is_empty():
			push_warning("ProducerManager: skipping producer with empty id")
			continue
		producers[p.id] = p

func _load_upgrades() -> void:
	var raw = _parse_json_file("res://data/upgrades.json")
	if raw == null:
		return
	for entry in raw:
		var u = Upgrade.new()
		u.id                 = entry.get("id", "")
		u.display_name       = entry.get("display_name", "")
		u.description        = entry.get("description", "")
		u.cost               = float(entry.get("cost", 0.0))
		u.unlock_producer_id = entry.get("unlock_producer_id", "")
		u.unlock_threshold   = float(entry.get("unlock_threshold", 0.0))
		u.effect_producer_id = entry.get("effect_producer_id", "")
		u.effect_multiplier  = float(entry.get("effect_multiplier", 1.0))
		u.unlock_type        = _parse_unlock_type(entry.get("unlock_type", "OWNED_COUNT"))
		u.effect_type        = _parse_effect_type(entry.get("effect_type", "MULTIPLY_PRODUCER"))
		if u.id.is_empty():
			push_warning("ProducerManager: skipping upgrade with empty id")
			continue
		upgrades[u.id] = u

func _parse_json_file(path: String):
	if not FileAccess.file_exists(path):
		push_error("ProducerManager: file not found → " + path)
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ProducerManager: cannot open → " + path)
		return null
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("ProducerManager: JSON parse error in %s at line %d" % [path, json.get_error_line()])
		return null
	return json.get_data()

func _parse_unlock_type(s: String) -> Upgrade.UnlockType:
	match s:
		"RESOURCE_TOTAL": return Upgrade.UnlockType.RESOURCE_TOTAL
		_:                return Upgrade.UnlockType.OWNED_COUNT

func _parse_effect_type(s: String) -> Upgrade.EffectType:
	match s:
		"MULTIPLY_ALL":   return Upgrade.EffectType.MULTIPLY_ALL
		"MULTIPLY_CLICK": return Upgrade.EffectType.MULTIPLY_CLICK
		_:                return Upgrade.EffectType.MULTIPLY_PRODUCER

# =============================================================================
# PURCHASE LOGIC
# =============================================================================

func buy_producer(producer_id: String) -> bool:
	var producer = producers.get(producer_id)
	if not producer:
		return false
	if not ResourceManager.spend(ResourceManager.main_resource, producer.get_current_cost()):
		return false
	producer.owned += 1
	emit_signal("producer_purchased", producer)
	_check_upgrade_unlocks()
	return true

func buy_upgrade(upgrade_id: String) -> bool:
	var upgrade = upgrades.get(upgrade_id)
	if not upgrade or upgrade.is_purchased:
		return false
	if not upgrade.is_unlocked(producers, ResourceManager.get_total_produced(ResourceManager.main_resource)):
		return false
	if not ResourceManager.spend(ResourceManager.main_resource, upgrade.cost):
		return false
	upgrade.is_purchased = true
	_apply_upgrade(upgrade)
	emit_signal("upgrade_purchased", upgrade)
	return true

func _apply_upgrade(upgrade: Upgrade) -> void:
	match upgrade.effect_type:
		Upgrade.EffectType.MULTIPLY_PRODUCER:
			var target = producers.get(upgrade.effect_producer_id)
			if target:
				target.multiplier *= upgrade.effect_multiplier
		Upgrade.EffectType.MULTIPLY_ALL:
			for p in producers.values():
				p.multiplier *= upgrade.effect_multiplier
		Upgrade.EffectType.MULTIPLY_CLICK:
			click_multiplier *= upgrade.effect_multiplier

func _check_upgrade_unlocks() -> void:
	for upgrade in upgrades.values():
		if upgrade.is_purchased or _already_signaled_upgrades.has(upgrade.id):
			continue
		if upgrade.is_unlocked(producers, ResourceManager.get_total_produced(ResourceManager.main_resource)):
			_already_signaled_upgrades[upgrade.id] = true
			emit_signal("upgrade_unlocked", upgrade)

func _on_total_produced_changed(_resource_id: String, _total: float) -> void:
	_check_upgrade_unlocks()

# =============================================================================
# RPS
# =============================================================================

func get_total_rps() -> float:
	var total = 0.0
	for producer in producers.values():
		total += producer.get_rps()
	return total

func tick(delta: float) -> void:
	var total = get_total_rps() * delta
	if total > 0.0:
		ResourceManager.add(ResourceManager.main_resource, total)

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	var data = {"producers": {}, "upgrades": {}, "click_multiplier": click_multiplier}
	for id in producers:
		data["producers"][id] = producers[id].to_dict()
	for id in upgrades:
		data["upgrades"][id] = upgrades[id].to_dict()
	return data

func from_dict(data: Dictionary) -> void:
	for p in producers.values():
		p.owned = 0
		p.multiplier = 1.0
	click_multiplier = 1.0
	_already_signaled_upgrades.clear()

	for id in data.get("producers", {}):
		if producers.has(id):
			producers[id].owned = data["producers"][id].get("owned", 0)

	for id in data.get("upgrades", {}):
		if upgrades.has(id):
			upgrades[id].is_purchased = data["upgrades"][id].get("is_purchased", false)
			if upgrades[id].is_purchased:
				_apply_upgrade(upgrades[id])
				_already_signaled_upgrades[id] = true

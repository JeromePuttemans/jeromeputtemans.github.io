# =============================================================================
# TraitSystem.gd — Synergies: counting traits and applying their bonuses
# =============================================================================
# Every unit has a class (guardian, blade, arcane, ranger) and an origin
# (ember, frost, grove). A trait counts the DIFFERENT unit types on the board
# that carry it: two copies of the same unit count once, so building a
# synergy asks for variety.
#
# Each trait has thresholds (2 and 3 for classes, 2 and 4 for origins) and
# one effect per threshold. Effects add up: with 3 guardians, both the
# "2 guardians" and the "3 guardians" effects apply.
#   scope trait    units carrying the trait
#   scope team     every unit of the team
#   scope enemies  every unit of the opposing team (frost slows them)
# Stats: armor (flat), crit (chance), mana_start (share of the mana bar),
# attack_speed and damage (+x %), enemy_attack_speed (-x %), regen (share
# of max hp healed per second).
# The enemy team gets its own synergies the same way.
# =============================================================================

class_name TraitSystem
extends RefCounted

## trait id -> number of different unit types carrying it.
static func count(units: Array[Unit]) -> Dictionary:
	var seen: Dictionary = {}
	var result: Dictionary = {}
	for unit in units:
		if seen.has(unit.type_id):
			continue
		seen[unit.type_id] = true
		for t in unit.traits:
			result[t] = int(result.get(t, 0)) + 1
	return result

## Number of thresholds reached (0 = inactive).
static func level_for(trait_id: String, amount: int) -> int:
	var level: int = 0
	for threshold in UnitDatabase.trait_data(trait_id).get("thresholds", []) as Array:
		if amount >= int(threshold):
			level += 1
	return level

static func apply(team: Array[Unit], enemies: Array[Unit]) -> void:
	var counts: Dictionary = count(team)
	for trait_id in counts:
		var level: int = level_for(str(trait_id), int(counts[trait_id]))
		var effects: Array = UnitDatabase.trait_data(str(trait_id)).get("effects", []) as Array
		for i in mini(level, effects.size()):
			_apply_effect(str(trait_id), effects[i] as Dictionary, team, enemies)
	for unit in team:
		unit.mana = minf(unit.mana, unit.mana_max)

static func _apply_effect(trait_id: String, effect: Dictionary, team: Array[Unit], enemies: Array[Unit]) -> void:
	var scope: String = str(effect.get("scope", "trait"))
	var targets: Array[Unit] = enemies if scope == "enemies" else team
	for unit in targets:
		if scope == "trait" and not unit.traits.has(trait_id):
			continue
		_add_stat(unit, str(effect.get("stat", "")), float(effect.get("value", 0.0)))

static func _add_stat(unit: Unit, stat: String, value: float) -> void:
	match stat:
		"armor":
			unit.armor += value
		"crit":
			unit.crit += value
		"mana_start":
			unit.mana += unit.mana_max * value
		"attack_speed", "enemy_attack_speed":
			unit.attack_speed *= 1.0 + value
		"damage":
			unit.damage_bonus += value
		"regen":
			unit.regen += value

# =============================================================================
# BattleSimulator.gd — The battle, step by step on the arena grid
# =============================================================================
# The arena is cols x (2 x rows) cells: the enemy holds the top half, the
# player the bottom half. RoundManager calls step(dt) with fixed steps; each
# step appends what happened to `events` (move, attack, projectile, damage,
# heal, shield, ability, death, end) for the views to animate. The simulation
# never waits for the animations: it is plain data, testable without a scene.
#
# EACH UNIT, EVERY STEP
#   stunned            does nothing until the stun ends
#   moving             finishes its step to the next cell
#   target             nearest living enemy (Chebyshev distance: diagonals
#                      count as 1), then lowest hp, then lowest id
#   in range           attacks every 1 / attack_speed seconds; with a full
#                      mana bar it casts its ability instead
#   out of range       steps to the free neighbour cell closest to its target
#                      (the cell is reserved at once, so two units never
#                      share a cell); if none gets closer, it waits
# DAMAGE: attack x (1 + damage bonus) x crit (x2) x 100 / (100 + armor).
#   A shield absorbs damage first. Melee hits land at once; ranged attacks
#   fly as projectiles and hit after distance / projectile_speed seconds
#   (a target that dies meanwhile is simply missed).
# MANA: +mana_per_attack per attack, +mana_per_hit per hit taken.
# END: one side has no unit left, or battle_timeout seconds pass (counted as
#   a defeat for the player: the enemy holds the arena).
# =============================================================================

class_name BattleSimulator
extends RefCounted

const NEIGHBOURS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

var cols: int = 7
var rows: int = 8
var units: Array[Unit] = []
var events: Array[Dictionary] = []
var time: float = 0.0
var finished: bool = false
var winner: int = -1
var _occupied: Dictionary = {}   # Vector2i -> Unit
var _projectiles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _timeout: float = 40.0
var _move_time: float = 0.42
var _mana_per_attack: float = 10.0
var _mana_per_hit: float = 5.0
var _crit_multiplier: float = 2.0
var _projectile_speed: float = 9.0

func setup(players: Array[Unit], enemies: Array[Unit], arena_cols: int, arena_rows: int, seed_value: int) -> void:
	cols = arena_cols
	rows = arena_rows
	_rng.seed = seed_value
	_timeout = ConfigManager.get_float("battle_timeout", 40.0)
	_move_time = ConfigManager.get_float("move_time", 0.42)
	_mana_per_attack = ConfigManager.get_float("mana_per_attack", 10.0)
	_mana_per_hit = ConfigManager.get_float("mana_per_hit", 5.0)
	_crit_multiplier = ConfigManager.get_float("crit_multiplier", 2.0)
	_projectile_speed = ConfigManager.get_float("projectile_speed", 9.0)
	units.clear()
	units.append_array(players)
	units.append_array(enemies)
	TraitSystem.apply(players, enemies)
	TraitSystem.apply(enemies, players)
	for unit in units:
		_occupied[unit.cell] = unit
		unit.attack_cooldown = _rng.randf_range(0.1, 0.5)   # no perfectly synchronised first strike

func step(dt: float) -> void:
	if finished:
		return
	time += dt
	_update_projectiles(dt)
	for unit in units:
		if unit.alive:
			_update_unit(unit, dt)
	_check_end()

# =============================================================================
# UNIT BEHAVIOUR
# =============================================================================

func _update_unit(unit: Unit, dt: float) -> void:
	if unit.regen > 0.0:
		unit.hp = minf(unit.hp + unit.hp_max * unit.regen * dt, unit.hp_max)
	if unit.stun_left > 0.0:
		unit.stun_left -= dt
		return
	if unit.move_left > 0.0:
		unit.move_left -= dt
		return
	unit.attack_cooldown -= dt
	var target: Unit = _pick_target(unit)
	if target == null:
		return
	if distance(unit.cell, target.cell) <= unit.range_cells:
		if unit.attack_cooldown <= 0.0:
			unit.attack_cooldown = 1.0 / maxf(unit.attack_speed, 0.1)
			if unit.mana_max > 0.0 and unit.mana >= unit.mana_max:
				unit.mana = 0.0
				_cast(unit, target)
			else:
				_basic_attack(unit, target)
	else:
		_step_toward(unit, target)

static func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _enemies_of(unit: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for other in units:
		if other.alive and other.team != unit.team:
			result.append(other)
	return result

func _allies_of(unit: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	for other in units:
		if other.alive and other.team == unit.team:
			result.append(other)
	return result

func _pick_target(unit: Unit) -> Unit:
	var best: Unit = null
	var best_key: Vector3 = Vector3(INF, INF, INF)
	for enemy in _enemies_of(unit):
		var key := Vector3(distance(unit.cell, enemy.cell), enemy.hp, enemy.instance_id)
		if key < best_key:
			best_key = key
			best = enemy
	return best

func _step_toward(unit: Unit, target: Unit) -> void:
	var current: int = distance(unit.cell, target.cell)
	var best_cell: Vector2i = unit.cell
	var best_score: float = current * 100.0 + Vector2(unit.cell - target.cell).length_squared()
	for offset in NEIGHBOURS:
		var next: Vector2i = unit.cell + offset
		if next.x < 0 or next.y < 0 or next.x >= cols or next.y >= rows or _occupied.has(next):
			continue
		var score: float = distance(next, target.cell) * 100.0 + Vector2(next - target.cell).length_squared()
		if score < best_score:
			best_score = score
			best_cell = next
	if best_cell == unit.cell:
		return
	_occupied.erase(unit.cell)
	unit.move_from = unit.cell
	unit.cell = best_cell
	_occupied[best_cell] = unit
	unit.move_duration = _move_time
	unit.move_left = _move_time

func _basic_attack(unit: Unit, target: Unit) -> void:
	unit.mana = minf(unit.mana + _mana_per_attack * unit.mana_gain, unit.mana_max)
	var amount: float = unit.attack * (1.0 + unit.damage_bonus)
	if unit.range_cells > 1:
		_launch(unit, target, amount, true, "projectile")
	else:
		events.append({"type": "attack", "unit": unit, "target": target})
		_deal(unit, target, amount, true, "attack")

func _launch(unit: Unit, target: Unit, amount: float, can_crit: bool, kind: String) -> void:
	var travel: float = Vector2(unit.cell - target.cell).length() / maxf(_projectile_speed, 0.1)
	_projectiles.append({"unit": unit, "target": target, "amount": amount, "crit": can_crit, "left": travel, "kind": kind})
	events.append({"type": "projectile", "unit": unit, "target": target, "duration": travel, "kind": kind})

func _update_projectiles(dt: float) -> void:
	for i in range(_projectiles.size() - 1, -1, -1):
		var p: Dictionary = _projectiles[i]
		p["left"] = float(p["left"]) - dt
		if float(p["left"]) > 0.0:
			continue
		_projectiles.remove_at(i)
		var target: Unit = p["target"] as Unit
		if target.alive:
			_deal(p["unit"] as Unit, target, float(p["amount"]), bool(p["crit"]), str(p["kind"]))

## Applies damage after crit, armor and shield. Returns the damage dealt.
func _deal(source: Unit, target: Unit, amount: float, can_crit: bool, kind: String) -> float:
	if not target.alive:
		return 0.0
	var critical: bool = can_crit and _rng.randf() < source.crit
	var damage: float = amount * (_crit_multiplier if critical else 1.0) * 100.0 / (100.0 + maxf(target.armor, 0.0))
	var absorbed: float = minf(target.shield, damage)
	target.shield -= absorbed
	target.hp -= damage - absorbed
	source.damage_dealt += damage
	target.mana = minf(target.mana + _mana_per_hit * target.mana_gain, target.mana_max)
	events.append({"type": "damage", "unit": target, "source": source, "amount": damage, "crit": critical, "kind": kind})
	if target.hp <= 0.0:
		_kill(target)
	return damage

func _heal(unit: Unit, amount: float) -> void:
	unit.hp = minf(unit.hp + amount, unit.hp_max)
	events.append({"type": "heal", "unit": unit, "amount": amount})

func _add_shield(unit: Unit, amount: float) -> void:
	unit.shield += amount
	events.append({"type": "shield", "unit": unit, "amount": amount})

func _kill(unit: Unit) -> void:
	unit.alive = false
	unit.hp = 0.0
	_occupied.erase(unit.cell)
	events.append({"type": "death", "unit": unit})

# =============================================================================
# ABILITIES (data/units.json, "ability": {type, value, ...})
# =============================================================================

func _cast(unit: Unit, target: Unit) -> void:
	var ability: Dictionary = unit.ability()
	var kind: String = str(ability.get("type", "strike"))
	var value: float = float(ability.get("value", 1.0))
	var power: float = value * unit.ability_factor() * (1.0 + unit.damage_bonus) * unit.stat_scale
	var hit_cells: Array[Vector2i] = []
	match kind:
		"strike":
			_deal(unit, target, unit.attack * value * (1.0 + unit.damage_bonus), true, "ability")
		"shield_self":
			_add_shield(unit, value * unit.ability_factor() * unit.stat_scale)
		"shield_team":
			for ally in _allies_of(unit):
				_add_shield(ally, value * unit.ability_factor() * unit.stat_scale)
		"heal_ally":
			_heal(_weakest_ally(unit), value * unit.ability_factor() * unit.stat_scale)
		"volley":
			for enemy in _nearest_enemies(unit, int(ability.get("count", 2))):
				_launch(unit, enemy, unit.attack * value * (1.0 + unit.damage_bonus), true, "volley")
		"aoe", "nova":
			hit_cells = _area(target.cell)
			for enemy in _enemies_in(unit, hit_cells):
				_deal(unit, enemy, power, false, "ability")
				if kind == "nova":
					enemy.stun_left = maxf(enemy.stun_left, float(ability.get("duration", 1.0)))
		"stun":
			_deal(unit, target, power, false, "ability")
			target.stun_left = maxf(target.stun_left, float(ability.get("duration", 1.0)))
		"whirl", "slam":
			hit_cells = _area(unit.cell)
			for enemy in _enemies_in(unit, hit_cells):
				_deal(unit, enemy, power, false, "ability")
				if kind == "slam":
					enemy.stun_left = maxf(enemy.stun_left, float(ability.get("duration", 1.0)))
		"dash":
			var prey: Unit = _weakest_enemy(unit)
			_dash_next_to(unit, prey)
			_deal(unit, prey, unit.attack * value * (1.0 + unit.damage_bonus), true, "ability")
			target = prey
	events.append({"type": "ability", "unit": unit, "target": target, "ability": kind, "cells": hit_cells})

func _area(center: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [center]
	for offset in NEIGHBOURS:
		result.append(center + offset)
	return result

func _enemies_in(unit: Unit, cells: Array[Vector2i]) -> Array[Unit]:
	var result: Array[Unit] = []
	for enemy in _enemies_of(unit):
		if cells.has(enemy.cell):
			result.append(enemy)
	return result

func _nearest_enemies(unit: Unit, count: int) -> Array[Unit]:
	var enemies: Array[Unit] = _enemies_of(unit)
	enemies.sort_custom(func(a: Unit, b: Unit) -> bool:
		return distance(unit.cell, a.cell) < distance(unit.cell, b.cell) or (distance(unit.cell, a.cell) == distance(unit.cell, b.cell) and a.instance_id < b.instance_id))
	return enemies.slice(0, count)

func _weakest_ally(unit: Unit) -> Unit:
	var best: Unit = unit
	for ally in _allies_of(unit):
		if ally.hp / ally.hp_max < best.hp / best.hp_max:
			best = ally
	return best

func _weakest_enemy(unit: Unit) -> Unit:
	var best: Unit = null
	for enemy in _enemies_of(unit):
		if best == null or enemy.hp < best.hp:
			best = enemy
	return best

func _dash_next_to(unit: Unit, prey: Unit) -> void:
	var best_cell: Vector2i = unit.cell
	var best_distance: int = distance(unit.cell, prey.cell)
	for offset in NEIGHBOURS:
		var next: Vector2i = prey.cell + offset
		if next.x < 0 or next.y < 0 or next.x >= cols or next.y >= rows or _occupied.has(next):
			continue
		if best_distance > 1 or distance(next, unit.cell) < distance(best_cell, unit.cell):
			best_cell = next
			best_distance = 1
	if best_cell == unit.cell:
		return
	_occupied.erase(unit.cell)
	unit.move_from = unit.cell
	unit.cell = best_cell
	_occupied[best_cell] = unit
	unit.move_duration = 0.15
	unit.move_left = 0.15

func _check_end() -> void:
	var players_left: bool = false
	var enemies_left: bool = false
	for unit in units:
		if unit.alive:
			if unit.team == 0:
				players_left = true
			else:
				enemies_left = true
	if players_left and enemies_left and time < _timeout:
		return
	finished = true
	winner = 0 if players_left and not enemies_left else 1
	events.append({"type": "end", "winner": winner, "timeout": players_left and enemies_left})

## Enemy units still standing (they hurt the player after a defeat).
func survivors(side: int) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in units:
		if unit.alive and unit.team == side:
			result.append(unit)
	return result

# =============================================================================
# BattleSimulator.gd — Shared combat helpers used by RoundManager.
# =============================================================================
# There is NO run() method here. The battle loop lives entirely in
# RoundManager._on_battle_tick(), which executes one attack per Timer
# callback and immediately returns control to Godot's main loop.
#
# This file provides:
#   BattleEvent   — lightweight value object for one combat action
#   build_order() — sorts all living units by initiative (speed desc, id asc)
#   pick_target() — returns the lowest-HP unit from an array
# =============================================================================

class_name BattleSimulator
extends RefCounted

# ---------------------------------------------------------------------------
# BattleEvent — one combat action, emitted by RoundManager tick by tick.
# ---------------------------------------------------------------------------
class BattleEvent:
	var type:             String = ""  # "attack" | "death" | "result"
	var attacker:         String = ""  # display_name (attack events)
	var target:           String = ""  # display_name (attack events)
	var damage:           int    = 0   # damage dealt (attack events)
	var name:             String = ""  # display_name (death events)
	var result:           String = ""  # "player_win"|"enemy_win"|"draw" (result)
	var player_hp_damage: int    = 0   # HP deducted from player (result)

# ---------------------------------------------------------------------------
# Static helpers
# ---------------------------------------------------------------------------

## Returns all living units merged and sorted by speed desc, instance_id asc.
## Called once per tick by RoundManager — O(n log n) on at most ~8 units.
static func build_order(players: Array, enemies: Array) -> Array:
	var order: Array = []
	for u in players:
		order.append({"unit": u, "team": "player"})
	for u in enemies:
		order.append({"unit": u, "team": "enemy"})
	order.sort_custom(func(a, b):
		if a["unit"].speed != b["unit"].speed:
			return a["unit"].speed > b["unit"].speed
		return a["unit"].instance_id < b["unit"].instance_id
	)
	return order

## Returns the living unit with the lowest current HP. Null if array is empty.
static func pick_target(units: Array) -> Variant:
	if units.is_empty():
		return null
	var best: Unit = units[0]
	for u in units:
		if u.hp_current < best.hp_current:
			best = u
	return best

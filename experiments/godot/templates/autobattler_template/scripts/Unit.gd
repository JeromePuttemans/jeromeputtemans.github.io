# =============================================================================
# Unit.gd — Pure data class representing one unit on the board or bench.
# =============================================================================
# Units are RefCounted objects — no Node, no scene dependency.
# BoardView reads their data to draw them; RoundManager and BattleSimulator
# read and mutate them during battle.
#
# INSTANCE ID:
#   Each Unit receives a unique integer id at creation so the UI can track
#   individual units even when multiple instances share the same type_id.
# =============================================================================

class_name Unit
extends RefCounted

# Monotonically increasing counter; shared across all Unit instances.
static var _next_id: int = 0

var instance_id: int     = 0
var type_id:     String  = ""
var display_name: String = ""
var glyph:       String  = "?"
var color:       Color   = Color.WHITE

# Base stats (read from UnitDatabase, never modified)
var hp_max:  int = 1
var attack:  int = 1
var defense: int = 0
var speed:   int = 1   # Lower acts first in battle (initiative order)

# Combat state — reset to base values at the start of each battle
var hp_current: int = 1

func _init() -> void:
	instance_id   = _next_id
	_next_id     += 1

## Populates this Unit from a raw type Dictionary loaded from units.json.
func setup_from_data(data: Dictionary) -> void:
	type_id      = data.get("id",           "unknown")
	display_name = data.get("display_name", "Unit")
	glyph        = data.get("glyph",        "?")
	hp_max       = data.get("hp",           1)
	attack       = data.get("attack",       1)
	defense      = data.get("defense",      0)
	speed        = data.get("speed",        1)
	hp_current   = hp_max

	var hex: String = data.get("color", "ffffff")
	color = Color("#" + hex if not hex.begins_with("#") else hex)

## Resets combat state so the unit enters each battle at full strength.
func reset_for_battle() -> void:
	hp_current = hp_max

func is_alive() -> bool:
	return hp_current > 0

## Applies incoming damage reduced by defense (minimum 1 always lands).
## Returns the actual damage dealt.
func take_damage(raw_attack: int) -> int:
	var damage = max(1, raw_attack - defense)
	hp_current = max(0, hp_current - damage)
	return damage

# =============================================================================
# Entity.gd — Base data class for any actor on the dungeon grid.
# =============================================================================
# Entities are pure data objects (RefCounted), NOT scene nodes.
# DungeonView renders them from their data; game systems move them.
#
# This is a lightweight ECS-inspired pattern:
#   Data  → Entity objects  (processed by CombatSystem, AISystem, etc.)
#   View  → DungeonView._draw()  (reads Entity data, draws nothing itself)
# =============================================================================

class_name Entity
extends RefCounted

var id: String           = ""
var display_name: String = ""
var glyph: String        = "?"    # Single character for ASCII rendering
var color: Color         = Color.WHITE
var grid_pos: Vector2i   = Vector2i.ZERO

var hp: int      = 1
var hp_max: int  = 1
var attack: int  = 1
var defense: int = 0

func is_alive() -> bool:
	return hp > 0

## Applies incoming damage reduced by defense.
## A minimum of 1 damage always lands so combat always progresses.
## Returns the actual damage dealt.
func take_damage(raw_attack: int) -> int:
	var damage = max(1, raw_attack - defense)
	hp = max(0, hp - damage)
	return damage

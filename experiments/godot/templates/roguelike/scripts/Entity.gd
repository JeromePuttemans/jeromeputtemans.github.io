# =============================================================================
# Entity.gd: base data class for any actor on the dungeon grid.
# =============================================================================
# Entities are pure data objects (RefCounted), NOT scene nodes.
# DungeonView renders them from their data; game systems move them.
#
# Lightweight ECS-inspired split:
#   Data  -> Entity objects  (changed by GameState, CombatSystem, AISystem)
#   View  -> DungeonView     (reads Entity data, animates, never writes it)
# =============================================================================

class_name Entity
extends RefCounted

var id:           String   = ""
var display_name: String   = ""
var sprite:       String   = ""     # pixel-art sprite id (data/sprites.json)
var color:        Color    = Color.WHITE   # particles, texts, minimap
var facing:       int      = 1      # 1 = right, -1 = left (sprite mirrored)
var grid_pos:     Vector2i = Vector2i.ZERO

var hp:      int = 1
var hp_max:  int = 1
var attack:  int = 1
var defense: int = 0

func is_alive() -> bool:
	return hp > 0

## Removes HP (damage already computed by CombatSystem). Returns it.
func take_damage(damage: int) -> int:
	hp = maxi(0, hp - damage)
	return damage

## Restores up to `amount` HP without exceeding hp_max. Returns HP gained.
func heal(amount: int) -> int:
	var before: int = hp
	hp = mini(hp_max, hp + amount)
	return hp - before

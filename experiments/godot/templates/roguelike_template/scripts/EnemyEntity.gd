# =============================================================================
# EnemyEntity.gd — Enemy actor data.
# =============================================================================
# Populated from a Dictionary loaded from data/enemies.json.
# Each instance is fully independent — modifying one does not affect others
# of the same type (no shared mutable state between instances).
# =============================================================================

class_name EnemyEntity
extends Entity

# Chebyshev distance at which this enemy begins chasing the player.
var chase_range: int = 6

func setup_from_data(data: Dictionary) -> void:
	id           = data.get("id", "unknown")
	display_name = data.get("display_name", "Enemy")
	glyph        = data.get("glyph", "e")
	hp_max       = data.get("hp", 5)
	hp           = hp_max
	attack       = data.get("attack", 2)
	defense      = data.get("defense", 0)
	chase_range  = data.get("chase_range", 6)

	var hex: String = data.get("color", "e05050")
	color = Color("#" + hex if not hex.begins_with("#") else hex)

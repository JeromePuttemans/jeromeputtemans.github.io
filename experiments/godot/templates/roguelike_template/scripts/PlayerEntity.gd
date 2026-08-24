# =============================================================================
# PlayerEntity.gd — Player actor data.
# =============================================================================
# Stats are read from ConfigManager (data/config.json), making them tunable
# without touching code. Created once by GameState.new_game() and persists
# across floors (HP carries over — losing HP is meaningful).
# =============================================================================

class_name PlayerEntity
extends Entity

func _init() -> void:
	id           = "player"
	display_name = "Player"
	glyph        = "@"
	color        = Color.WHITE
	hp_max       = ConfigManager.get_int("player_hp_max", 30)
	hp           = hp_max
	attack       = ConfigManager.get_int("player_attack",  5)
	defense      = ConfigManager.get_int("player_defense", 2)

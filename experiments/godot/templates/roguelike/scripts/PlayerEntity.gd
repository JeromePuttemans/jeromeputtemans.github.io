# =============================================================================
# PlayerEntity.gd: player actor data.
# =============================================================================
# Stats are read from data/config.json. Created once per run by
# GameState.new_game() and kept across floors: HP, energy, level and
# inventory carry over, so every loss matters (permadeath).
#
# LEVELS:
#   XP needed to go from level L to L+1 = xp_base + xp_growth x (L - 1)
#   (10, 18, 26, 34... with the default config). XP restarts at 0 after each
#   level-up, which keeps the HUD bar readable.
#
# ENERGY: food clock, see GameState._tick_needs().
# =============================================================================

class_name PlayerEntity
extends Entity

var level:          int   = 1
var xp:             int   = 0
var xp_next:        int   = 0
var energy:         int   = 0
var energy_max:     int   = 0
var crit_chance:    float = 0.0
var inventory:      Array[Dictionary] = []
var inventory_size: int   = 0
var has_key:        bool  = false   # the floor's key, used up by the stairs grille
var daggers:        int   = 0       # throwing daggers carried
var daggers_max:    int   = 0
var dash_cd:        int   = 0       # turns before the next dash (0 = ready)
var elan:           int   = 0       # momentum stacks, one per kill in a row
var elan_timer:     int   = 0       # turns without hitting before elan drops

func _init() -> void:
	id             = "player"
	display_name   = "Player"
	sprite         = "player"
	color          = Color("e8665a")
	hp_max         = ConfigManager.get_int("player_hp_max", 1)
	hp             = hp_max
	attack         = ConfigManager.get_int("player_attack", 1)
	defense        = ConfigManager.get_int("player_defense", 0)
	crit_chance    = ConfigManager.get_float("player_crit_chance", 0.0)
	energy_max     = ConfigManager.get_int("energy_max", 0)
	energy         = energy_max
	inventory_size = ConfigManager.get_int("inventory_size", 0)
	daggers        = ConfigManager.get_int("daggers_start", 0)
	daggers_max    = ConfigManager.get_int("daggers_max", 0)
	xp_next        = xp_needed(level)

static func xp_needed(lvl: int) -> int:
	return ConfigManager.get_int("xp_base", 10) + ConfigManager.get_int("xp_growth", 0) * (lvl - 1)

func inventory_full() -> bool:
	return inventory.size() >= inventory_size

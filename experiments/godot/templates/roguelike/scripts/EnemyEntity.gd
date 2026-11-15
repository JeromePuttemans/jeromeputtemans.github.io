# =============================================================================
# EnemyEntity.gd: enemy actor data.
# =============================================================================
# Populated from data/enemies.json. Each instance is independent.
#
# SPEED AND ACTION POINTS:
#   Every enemy turn, action_points += speed, then the enemy acts while
#   action_points >= 1. speed 1 acts every turn, speed 2 twice per turn
#   (bats), speed 0.5 every other turn (trolls: you can outrun them).
#   One rule handles every speed without special cases.
#
# SPECIAL TRAITS (enemies.json): key_carrier (the thief, the Warden),
#   split (slime), revive (skeleton); handled by GameState.
#
# AWARENESS:
#   alerted becomes true when the enemy sees the player (or gets hit).
#   alert_turns counts down while the player is out of sight; at 0 the enemy
#   gives up and goes back to sleep.
# =============================================================================

class_name EnemyEntity
extends Entity

var xp_value:      int    = 0
var speed:         float  = 1.0
var ai:            String = "melee"   # melee, erratic, ranged
var chase_range:   int    = 6
var attack_range:  int    = 0         # ranged only
var ranged_attack: int    = 0         # ranged only
var is_boss:       bool   = false
var key_carrier:   bool   = false     # drops the floor's key when it dies
var splits:        bool   = false     # slime: splits in two when hit
var revives:       bool   = false     # skeleton: rises again from its bones
var type_data:     Dictionary = {}

# Thief state (ai "thief"): wanders, flees once it sees the player, runs
# out of breath after thief_flee_steps steps and rests thief_tired_turns.
var fleeing:       bool   = false
var flee_steps:    int    = 0
var tired:         int    = 0
var wander_target: Vector2i = Vector2i(-1, -1)
var wander_map:    DijkstraMap = null

var alerted:       bool   = false
var alert_turns:   int    = 0
var action_points: float  = 0.0

func setup_from_data(data: Dictionary) -> void:
	type_data     = data
	id            = str(data.get("id", "unknown"))
	display_name  = str(data.get("display_name", "Enemy"))
	sprite        = str(data.get("sprite", id))
	hp_max        = int(data.get("hp", 5))
	hp            = hp_max
	attack        = int(data.get("attack", 2))
	defense       = int(data.get("defense", 0))
	xp_value      = int(data.get("xp", 1))
	speed         = float(data.get("speed", 1.0))
	ai            = str(data.get("ai", "melee"))
	chase_range   = int(data.get("chase_range", 6))
	attack_range  = int(data.get("range", 0))
	ranged_attack = int(data.get("ranged_attack", attack))
	is_boss       = bool(data.get("boss", false))
	key_carrier   = bool(data.get("key_carrier", false))
	splits        = bool(data.get("split", false))
	revives       = bool(data.get("revive", false))
	var hex: String = str(data.get("color", "e05050"))
	color = Color("#" + hex if not hex.begins_with("#") else hex)

## Depth scaling, so a type stays relevant on every floor where it appears:
##   HP x (1 + enemy_hp_per_floor x (floor - 1)), ATK + floor((floor - 1) x enemy_attack_per_floor)
## Example, orc on floor 5: HP 14 x 1.48 = 21, ATK 5 + 4 = 9.
## The boss is tuned directly in enemies.json and is not scaled.
func scale_for_floor(floor_number: int) -> void:
	if is_boss or floor_number <= 1:
		return
	var depth: int = floor_number - 1
	hp_max = int(round(hp_max * (1.0 + ConfigManager.get_float("enemy_hp_per_floor", 0.0) * depth)))
	hp = hp_max
	var bonus: int = int(floor(depth * ConfigManager.get_float("enemy_attack_per_floor", 0.0)))
	attack += bonus
	ranged_attack += bonus

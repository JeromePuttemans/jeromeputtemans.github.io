# =============================================================================
# Unit.gd — One unit: its type, star level and battle state
# =============================================================================
# A Unit is a RefCounted object (no Node): the board, the bench, the battle
# simulator and the views all share the same instances.
#
# STARS: three identical units of the same star merge into one of the next
#   star (RoundManager). Each star multiplies hp and attack by
#   star_stat_multiplier (1.8) and ability values by star_ability_multiplier
#   (1.5): a 2-star unit has 1.8 x the hp of a 1-star, a 3-star 3.24 x.
# BATTLE STATE: prepare_for_battle() copies the base stats into the battle
#   fields; TraitSystem then adds the synergy bonuses. The battle fields are
#   rewritten at every battle, so a unit always starts fresh.
# =============================================================================

class_name Unit
extends RefCounted

static var _next_id: int = 0

var instance_id: int = 0
var type_id: String = ""
var tier: int = 1
var traits: Array[String] = []
var star: int = 1
var is_boss: bool = false
var stat_scale: float = 1.0   # enemies grow a little stronger every round
var data: Dictionary = {}

# Battle state (rewritten by prepare_for_battle and TraitSystem)
var team: int = 0             # 0 = player, 1 = enemy
var cell: Vector2i = Vector2i.ZERO
var move_from: Vector2i = Vector2i.ZERO
var move_left: float = 0.0
var move_duration: float = 1.0
var alive: bool = true
var hp_max: float = 1.0
var hp: float = 1.0
var attack: float = 1.0
var attack_speed: float = 1.0
var range_cells: int = 1
var armor: float = 0.0
var mana_max: float = 0.0
var mana: float = 0.0
var mana_gain: float = 1.0
var crit: float = 0.0
var damage_bonus: float = 0.0
var regen: float = 0.0
var shield: float = 0.0
var stun_left: float = 0.0
var attack_cooldown: float = 0.0
var damage_dealt: float = 0.0

func _init() -> void:
	instance_id = _next_id
	_next_id += 1

func setup(unit_data: Dictionary, star_level: int) -> void:
	data = unit_data
	type_id = str(data.get("id", ""))
	tier = int(data.get("tier", 1))
	is_boss = bool(data.get("boss", false))
	star = star_level
	traits.clear()
	for t in data.get("traits", []) as Array:
		traits.append(str(t))

func star_factor() -> float:
	return pow(ConfigManager.get_float("star_stat_multiplier", 1.8), star - 1)

func ability_factor() -> float:
	return pow(ConfigManager.get_float("star_ability_multiplier", 1.5), star - 1)

func base_hp() -> float:
	return float(data.get("hp", 1)) * star_factor() * stat_scale

func base_attack() -> float:
	return float(data.get("attack", 1)) * star_factor() * stat_scale

func base_range() -> int:
	return int(data.get("range", 1))

func is_ranged() -> bool:
	return base_range() > 1

func ability() -> Dictionary:
	return data.get("ability", {}) as Dictionary

## Gold value: 1 copy of a tier-2 unit is worth 2, a 2-star (3 copies) 6.
func sell_value() -> int:
	return tier * int(pow(3.0, star - 1))

func prepare_for_battle(side: int, start_cell: Vector2i) -> void:
	team = side
	cell = start_cell
	move_from = start_cell
	move_left = 0.0
	alive = true
	hp_max = base_hp()
	attack = base_attack()
	attack_speed = float(data.get("attack_speed", 1.0))
	range_cells = base_range()
	armor = float(data.get("armor", 0))
	mana_max = float(data.get("mana", 0))
	mana = 0.0
	mana_gain = 1.0
	crit = 0.0
	damage_bonus = 0.0
	regen = 0.0
	shield = 0.0
	stun_left = 0.0
	damage_dealt = 0.0
	hp = hp_max

## Visual position between two cells while moving (0 = start, 1 = arrived).
func move_progress() -> float:
	if move_left <= 0.0:
		return 1.0
	return 1.0 - move_left / maxf(move_duration, 0.001)

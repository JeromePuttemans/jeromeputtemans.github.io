# =============================================================================
# GameState.gd — Autoload (Singleton): the session in progress
# =============================================================================
# Mode (arcade, versus, training), the chosen fighters, the CPU difficulty
# and the arcade ladder. The roster is parsed once from data/fighters.json.
# ARCADE: the player meets the two other automatons, then a mirror match
# against a double one level stronger.
# =============================================================================

extends Node

var roster: Dictionary = {}
var order: Array[String] = []
var mode: String = "arcade"
var p1: String = "brio"
var p2: String = "colosse"
var difficulty: int = 1
var ladder: Array[String] = []
var ladder_index: int = 0

func _ready() -> void:
	var raw: Variant = ConfigManager.load_json("res://data/fighters.json")
	roster = raw as Dictionary if raw is Dictionary else {}
	for id in ConfigManager.get_array("roster"):
		order.append(str(id))

func start_arcade(fighter: String, level: int) -> void:
	mode = "arcade"
	p1 = fighter
	difficulty = level
	ladder.clear()
	for id in order:
		if id != fighter:
			ladder.append(id)
	ladder.shuffle()
	ladder.append(fighter)
	ladder_index = 0
	p2 = ladder[0]

func arcade_level() -> int:
	var final: bool = ladder_index == ladder.size() - 1
	return mini(difficulty + (1 if final else 0), 3)

func arcade_next() -> bool:
	ladder_index += 1
	if ladder_index >= ladder.size():
		return false
	p2 = ladder[ladder_index]
	return true

func stage_for(fighter: String) -> String:
	return str(ConfigManager.get_dict("stages").get(fighter, "atelier"))

func fighter_name(id: String) -> String:
	return StringManager.t(str((roster.get(id, {}) as Dictionary).get("name", id)))

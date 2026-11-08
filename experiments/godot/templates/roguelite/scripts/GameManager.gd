extends Node

# GameManager (Autoload): run state + persistent meta-progression.
#
# RUN (lost on death):  level, energy, core_collected, rooms explored,
#                       fragments earned during the run.
# META (saved in user://roguelite_save.json, kept between runs):
#                       fragments, upgrade levels, best level reached.
#
# A run ends when energy reaches 0, or when the player is walled in without
# enough energy for a bomb. Fragments earned are kept: they buy permanent
# upgrades (max energy, cheaper bomb, more energy crystals), which makes the
# next run go deeper. That loop is what makes it a roguelite.

signal energy_changed(current: int, maximum: int)
signal fragments_changed(total: int)
signal level_started(level: int)
signal core_collected_changed(collected: bool)
signal level_completed(level: int, bonus: int)
signal message(text: String, kind: String)
signal run_started()
signal run_ended(reason: String)
signal upgrades_changed()

const CONFIG_PATH: String = "res://data/config.json"
const SAVE_PATH: String = "user://roguelite_save.json"
const UPGRADE_IDS: Array[String] = ["energy", "bomb", "prospect"]

var cfg: Dictionary = {}

# Meta-progression
var fragments: int = 0
var best_level: int = 0
var upgrades: Dictionary = {"energy": 0, "bomb": 0, "prospect": 0}

# Current run
var running: bool = false
var level: int = 1
var energy: int = 0
var energy_max: int = 0
var core_collected: bool = false
var rooms_explored: int = 0
var run_fragments: int = 0
var end_reason: String = ""

func _ready() -> void:
	_load_config()
	load_game()

# ---------------------------------------------------------------------------
# Tuning values (config.json + upgrades + depth)
# ---------------------------------------------------------------------------

func num(key: String) -> float:
	return float(cfg.get(key, 0.0))

func bomb_cost() -> int:
	return maxi(int(num("bomb_cost_min")), int(num("bomb_cost_base")) - int(upgrades["bomb"]))

func resource_chance() -> float:
	return num("resource_chance_base") + num("resource_chance_per_upgrade") * int(upgrades["prospect"])

func trap_chance() -> float:
	return num("trap_chance_base") + num("trap_chance_per_level") * (level - 1)

func wall_chance() -> float:
	return minf(num("wall_chance_max"), num("wall_chance_base") + num("wall_chance_per_level") * (level - 1))

func core_distance() -> int:
	return int(num("core_distance_base")) + int(num("core_distance_per_level")) * (level - 1)

# ---------------------------------------------------------------------------
# Run flow
# ---------------------------------------------------------------------------

func new_run() -> void:
	running = true
	level = 1
	run_fragments = 0
	rooms_explored = 0
	end_reason = ""
	energy_max = int(num("energy_base")) + int(num("energy_per_upgrade")) * int(upgrades["energy"])
	run_started.emit()
	_start_level()

func _start_level() -> void:
	energy = energy_max
	core_collected = false
	energy_changed.emit(energy, energy_max)
	core_collected_changed.emit(false)
	level_started.emit(level)

func spend_energy(amount: int) -> void:
	energy = maxi(energy - amount, 0)
	energy_changed.emit(energy, energy_max)

func add_energy(amount: int) -> void:
	energy = mini(energy + amount, energy_max)
	energy_changed.emit(energy, energy_max)

func add_fragments(amount: int) -> void:
	fragments += amount
	run_fragments += amount
	fragments_changed.emit(fragments)
	save_game()

func collect_core() -> void:
	core_collected = true
	core_collected_changed.emit(true)

func complete_level() -> void:
	var bonus: int = int(num("level_fragments")) * level
	add_fragments(bonus)
	level_completed.emit(level, bonus)
	level += 1
	best_level = maxi(best_level, level)
	save_game()
	_start_level()

func end_run(reason: String) -> void:
	if not running:
		return
	running = false
	end_reason = reason
	best_level = maxi(best_level, level)
	save_game()
	run_ended.emit(reason)

func say(text: String, kind: String = "info") -> void:
	message.emit(text, kind)

# ---------------------------------------------------------------------------
# Upgrades (bought between runs)
# ---------------------------------------------------------------------------

func upgrade_cost(id: String) -> int:
	var lvl: int = int(upgrades.get(id, 0))
	var costs: Array = cfg.get("upgrade_costs", []) as Array
	if lvl >= int(num("upgrade_max_level")) or lvl >= costs.size():
		return -1
	return int(costs[lvl])

func buy_upgrade(id: String) -> bool:
	var cost: int = upgrade_cost(id)
	if cost < 0 or fragments < cost:
		return false
	fragments -= cost
	upgrades[id] = int(upgrades[id]) + 1
	fragments_changed.emit(fragments)
	upgrades_changed.emit()
	save_game()
	return true

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func save_game() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({fragments = fragments, best_level = best_level, upgrades = upgrades}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return
	var d: Dictionary = data as Dictionary
	fragments = int(d.get("fragments", 0))
	best_level = int(d.get("best_level", 0))
	var ups: Dictionary = d.get("upgrades", {}) as Dictionary
	for id in UPGRADE_IDS:
		upgrades[id] = int(ups.get(id, 0))

func _load_config() -> void:
	var f: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		push_error("GameManager: cannot open " + CONFIG_PATH)
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		cfg = data as Dictionary

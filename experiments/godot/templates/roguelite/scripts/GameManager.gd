extends Node

# GameManager (Autoload): run state + persistent meta-progression.
#
# RUN (lost on death):  level, energy, core_collected, rooms explored.
# META (saved in user://roguelite_save.json, kept between runs):
#                       upgrade levels, best level reached, settings.
#
# Each core brought back to the teleporter completes the level and offers
# ONE free upgrade (max energy, cheaper bomb, more energy crystals): the
# level waits (awaiting_choice) until the player picks one. Upgrades are
# permanent, so the next run goes deeper. That loop is what makes it a
# roguelite. Dying offers nothing: the end screen only sums up the run.
# Once every upgrade is maxed, levels chain without a choice.
# SAVE VERSION: saves carry "version". Version 1 (no field) comes from the
# former design, where upgrades were bought with fragments: those levels do
# not fit the free pick per core, so they are reset to 0 on load. A save
# with every upgrade bought would otherwise skip the choice from the first
# delivered core. Best level and settings are kept.
# A run ends when energy reaches 0, or when the player is walled in without
# enough energy for a bomb.

signal energy_changed(current: int, maximum: int)
signal level_started(level: int)
signal core_collected_changed(collected: bool)
signal level_completed(level: int)
signal upgrade_offered()
signal message(text: String, kind: String)
signal run_started()
signal run_ended(reason: String)
signal upgrades_changed()
signal settings_changed()

const CONFIG_PATH: String = "res://data/config.json"
const SAVE_PATH: String = "user://roguelite_save.json"
const SAVE_VERSION: int = 2
const UPGRADE_IDS: Array[String] = ["energy", "bomb", "prospect"]

var cfg: Dictionary = {}

# Meta-progression
var best_level: int = 0
var upgrades: Dictionary = {"energy": 0, "bomb": 0, "prospect": 0}
# Settings, saved with the progression: focus radius (in moves), opacity of
# distant rooms, keyboard layout mode (kept by the Keyboard autoload:
# "auto", "azerty", "qwerty")
const FOCUS_RADIUS_MIN: int = 1
const FOCUS_RADIUS_MAX: int = 10
var focus_radius: int = 3
var far_opacity: float = 0.15

# Current run
var running: bool = false
var awaiting_choice: bool = false   # core delivered, upgrade not picked yet
var level: int = 1
var energy: int = 0
var energy_max: int = 0
var core_collected: bool = false
var rooms_explored: int = 0
var end_reason: String = ""

func _ready() -> void:
	_load_config()
	focus_radius = int(num("focus_radius_default"))
	far_opacity = num("far_opacity_default")
	load_game()

# ---------------------------------------------------------------------------
# Tuning values (config.json + upgrades + depth)
# ---------------------------------------------------------------------------

func num(key: String) -> float:
	return float(cfg.get(key, 0.0))

## What an upgrade gives at a given level: max energy, bomb cost, or chance
## (in percent) that a new room holds an energy crystal. The choice cards
## show it for the current and the next level ("20 -> 24").
func upgrade_value(id: String, lvl: int) -> int:
	match id:
		"energy":
			return int(num("energy_base")) + int(num("energy_per_upgrade")) * lvl
		"bomb":
			return maxi(int(num("bomb_cost_min")), int(num("bomb_cost_base")) - lvl)
		"prospect":
			return int(round((num("resource_chance_base") + num("resource_chance_per_upgrade") * lvl) * 100.0))
	return 0

## Highest level of an upgrade. The Detonator stops when the bomb reaches
## its minimum cost (6 - 4 = 2 with the default config): a fifth level
## would change nothing.
func upgrade_max(id: String) -> int:
	if id == "bomb":
		return maxi(int(num("bomb_cost_base")) - int(num("bomb_cost_min")), 0)
	return int(num("upgrade_max_level"))

func upgrade_available(id: String) -> bool:
	return int(upgrades.get(id, 0)) < upgrade_max(id)

func any_upgrade_available() -> bool:
	for id in UPGRADE_IDS:
		if upgrade_available(id):
			return true
	return false

func bomb_cost() -> int:
	return upgrade_value("bomb", int(upgrades["bomb"]))

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

## True while the player may move or bomb.
func can_act() -> bool:
	return running and not awaiting_choice

func new_run() -> void:
	running = true
	awaiting_choice = false
	level = 1
	rooms_explored = 0
	end_reason = ""
	run_started.emit()
	_start_level()

## Energy refilled, at the max given by the Reserve level (which may have
## just changed with the upgrade picked).
func _start_level() -> void:
	energy_max = upgrade_value("energy", int(upgrades["energy"]))
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

func collect_core() -> void:
	core_collected = true
	core_collected_changed.emit(true)

func complete_level() -> void:
	level_completed.emit(level)
	level += 1
	best_level = maxi(best_level, level)
	save_game()
	if any_upgrade_available():
		awaiting_choice = true
		upgrade_offered.emit()
	else:
		say(Strings.t("msg_all_maxed"), "info")
		_start_level()

## The player's pick after a delivered core; the next level starts.
func choose_upgrade(id: String) -> bool:
	if not awaiting_choice or not upgrade_available(id):
		return false
	upgrades[id] = int(upgrades[id]) + 1
	awaiting_choice = false
	upgrades_changed.emit()
	save_game()
	_start_level()
	return true

func end_run(reason: String) -> void:
	if not running:
		return
	running = false
	awaiting_choice = false
	end_reason = reason
	best_level = maxi(best_level, level)
	save_game()
	run_ended.emit(reason)

func say(text: String, kind: String = "info") -> void:
	message.emit(text, kind)

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

func set_focus_radius(value: int) -> void:
	focus_radius = clampi(value, FOCUS_RADIUS_MIN, FOCUS_RADIUS_MAX)
	settings_changed.emit()
	save_game()

func set_far_opacity(value: float) -> void:
	far_opacity = clampf(value, 0.0, 1.0)
	settings_changed.emit()
	save_game()

func set_keyboard_mode(mode: String) -> void:
	Keyboard.set_mode(mode)
	save_game()

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func save_game() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({version = SAVE_VERSION, best_level = best_level, upgrades = upgrades,
		focus_radius = focus_radius, far_opacity = far_opacity, keyboard = Keyboard.mode}))

## A version 1 save (former fragment shop) keeps everything but its upgrades.
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
	best_level = int(d.get("best_level", 0))
	focus_radius = clampi(int(d.get("focus_radius", focus_radius)), FOCUS_RADIUS_MIN, FOCUS_RADIUS_MAX)
	far_opacity = clampf(float(d.get("far_opacity", far_opacity)), 0.0, 1.0)
	Keyboard.set_mode(str(d.get("keyboard", "auto")))
	if int(d.get("version", 1)) < SAVE_VERSION:
		save_game()   # upgrades stay at 0: written now in the new format
		return
	var ups: Dictionary = d.get("upgrades", {}) as Dictionary
	for id in UPGRADE_IDS:
		upgrades[id] = clampi(int(ups.get(id, 0)), 0, upgrade_max(id))

func _load_config() -> void:
	var f: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		push_error("GameManager: cannot open " + CONFIG_PATH)
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		cfg = data as Dictionary

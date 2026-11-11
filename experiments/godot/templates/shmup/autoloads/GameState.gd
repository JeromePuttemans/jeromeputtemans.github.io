# =============================================================================
# GameState.gd — Autoload (Singleton): the run in progress
# =============================================================================
# Score, lives, bombs, power, chain multiplier and graze count. The side
# panels listen to the signals, Game calls the methods.
#
# CHAIN: every kill raises the multiplier (chain_step_small for small
#   enemies, chain_step_large for large ones, chain_graze_step per grazed
#   bullet) up to chain_max, and restarts a chain_time countdown. When the
#   countdown runs out, the multiplier falls by chain_decay per second until
#   the next kill. A lost life resets it to 1. Points from kills, gems and
#   phase bonuses are multiplied by it.
# EXTENDS: an extra life at each score of extend_scores.
# =============================================================================

extends Node

enum Phase { MENU, PLAYING, PAUSED, RESULT }

signal phase_changed(phase: Phase)
signal score_changed(score: int)
signal lives_changed(lives: int)
signal bombs_changed(bombs: int)
signal power_changed(level: int)
signal chain_changed(multiplier: float)
signal graze_changed(count: int)
signal extended()

var phase: Phase = Phase.MENU
var difficulty: String = "normal"
var score: int = 0
var lives: int = 3
var bombs: int = 2
var power: int = 1
var chain: float = 1.0
var chain_timer: float = 0.0
var graze: int = 0
var best_chain: float = 1.0
var misses: int = 0
var bombs_used: int = 0
var kills: int = 0
var _next_extend: int = 0

func set_phase(value: Phase) -> void:
	phase = value
	phase_changed.emit(phase)

func new_run(diff: String) -> void:
	difficulty = diff
	score = 0
	lives = ConfigManager.get_int("lives", 3)
	bombs = ConfigManager.get_int("bombs_per_life", 2)
	power = ConfigManager.get_int("power_start", 1)
	chain = 1.0
	chain_timer = 0.0
	graze = 0
	best_chain = 1.0
	misses = 0
	bombs_used = 0
	kills = 0
	_next_extend = 0
	score_changed.emit(score)
	lives_changed.emit(lives)
	bombs_changed.emit(bombs)
	power_changed.emit(power)
	chain_changed.emit(chain)
	graze_changed.emit(graze)

## Difficulty factor: bullet_speed, fire_rate or enemy_hp.
func diff(key: String) -> float:
	var table: Dictionary = ConfigManager.get_dict("difficulty").get(difficulty, {}) as Dictionary
	return float(table.get(key, 1.0))

## Adds base x multiplier (rounded to 10). Returns the points given.
func add_points(base: int, use_chain: bool = true) -> int:
	var points: int = base
	if use_chain:
		points = int(round(base * chain / 10.0)) * 10
	score += points
	score_changed.emit(score)
	_check_extend()
	return points

func add_kill(large: bool) -> void:
	kills += 1
	_raise_chain(ConfigManager.get_float("chain_step_large" if large else "chain_step_small", 0.1))

func add_graze() -> void:
	graze += 1
	graze_changed.emit(graze)
	_raise_chain(ConfigManager.get_float("chain_graze_step", 0.02))

func _raise_chain(step: float) -> void:
	chain = minf(chain + step, ConfigManager.get_float("chain_max", 8.0))
	best_chain = maxf(best_chain, chain)
	chain_timer = ConfigManager.get_float("chain_time", 2.0)
	chain_changed.emit(chain)

func tick(delta: float) -> void:
	if chain_timer > 0.0:
		chain_timer -= delta
	elif chain > 1.0:
		chain = maxf(chain - ConfigManager.get_float("chain_decay", 1.0) * delta, 1.0)
		chain_changed.emit(chain)

func chain_ratio() -> float:
	return clampf(chain_timer / ConfigManager.get_float("chain_time", 2.0), 0.0, 1.0)

## Returns true when the run is over.
func lose_life() -> bool:
	misses += 1
	lives -= 1
	chain = 1.0
	chain_timer = 0.0
	chain_changed.emit(chain)
	lives_changed.emit(maxi(lives, 0))
	if lives <= 0:
		return true
	bombs = maxi(bombs, ConfigManager.get_int("bombs_per_life", 2))
	bombs_changed.emit(bombs)
	return false

func use_bomb() -> bool:
	if bombs <= 0:
		return false
	bombs -= 1
	bombs_used += 1
	bombs_changed.emit(bombs)
	return true

func add_bomb() -> void:
	bombs = mini(bombs + 1, ConfigManager.get_int("bombs_max", 5))
	bombs_changed.emit(bombs)

func add_life() -> void:
	lives = mini(lives + 1, ConfigManager.get_int("lives_max", 6))
	lives_changed.emit(lives)
	extended.emit()

func set_power(level: int) -> void:
	power = clampi(level, 1, ConfigManager.get_int("power_max", 4))
	power_changed.emit(power)

func _check_extend() -> void:
	var steps: Array = ConfigManager.get_array("extend_scores")
	while _next_extend < steps.size() and score >= int(steps[_next_extend]):
		_next_extend += 1
		add_life()

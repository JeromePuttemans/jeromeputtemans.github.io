# =============================================================================
# GameState.gd — Autoload (Singleton)
# =============================================================================
# Central authority for gold, lives, score, wave index and game phase.
# No scene logic lives here — Main.gd reacts to signals.
#
# PHASE MACHINE:
#   BUILD    — player places towers between waves
#   WAVE     — enemies are spawning / in the field
#   GAME_OVER / VICTORY — terminal states, restart via new_game()
# =============================================================================

extends Node

enum Phase { BUILD, WAVE, GAME_OVER, VICTORY }

signal gold_changed(value: int)
signal lives_changed(value: int)
signal score_changed(value: int)
signal phase_changed(new_phase: Phase)
signal wave_started(wave_index: int)
signal game_over()
signal game_won()

var gold:        int   = 0
var lives:       int   = 0
var score:       int   = 0
var wave_index:  int   = 0   # 0-based; total waves set from waves.json
var total_waves: int   = 0
var phase:       Phase = Phase.BUILD

func new_game() -> void:
	gold       = ConfigManager.get_int("starting_gold",  0)
	lives      = ConfigManager.get_int("starting_lives", 0)
	score      = 0
	wave_index = 0
	phase      = Phase.BUILD
	emit_signal("gold_changed",   gold)
	emit_signal("lives_changed",  lives)
	emit_signal("score_changed",  score)
	emit_signal("phase_changed",  phase)

func add_gold(amount: int) -> void:
	gold += amount
	emit_signal("gold_changed", gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	emit_signal("gold_changed", gold)
	return true

func add_score(points: int) -> void:
	score += points
	emit_signal("score_changed", score)

## Called when an enemy reaches the exit.
func enemy_reached_exit() -> void:
	if phase != Phase.WAVE:
		return
	var dmg = ConfigManager.get_int("enemy_reach_damage", 0)
	lives -= dmg
	emit_signal("lives_changed", lives)
	if lives <= 0:
		lives = 0
		phase = Phase.GAME_OVER
		emit_signal("phase_changed", phase)
		emit_signal("game_over")

## Called by WaveManager when the last enemy of a wave is defeated.
func wave_cleared() -> void:
	if phase != Phase.WAVE:
		return
	wave_index += 1
	if wave_index >= total_waves:
		phase = Phase.VICTORY
		emit_signal("phase_changed", phase)
		emit_signal("game_won")
	else:
		phase = Phase.BUILD
		emit_signal("phase_changed", phase)

## Called by the Start Wave button / auto-timer.
func begin_wave() -> void:
	if phase != Phase.BUILD:
		return
	phase = Phase.WAVE
	emit_signal("phase_changed", phase)
	emit_signal("wave_started", wave_index)

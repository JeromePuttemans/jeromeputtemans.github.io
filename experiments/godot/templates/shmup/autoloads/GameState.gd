# =============================================================================
# GameState.gd — Autoload #3
# Score, lives, wave, phase. No scene logic.
# PHASES: READY → PLAYING → WAVE_CLEAR → BOSS → GAME_OVER / VICTORY
# =============================================================================
extends Node

enum Phase { READY, PLAYING, WAVE_CLEAR, GAME_OVER, VICTORY }

signal score_changed(v: int)
signal lives_changed(v: int)
signal phase_changed(p: Phase)
signal wave_changed(n: int)

var score:       int   = 0
var high_score:  int   = 0
var lives:       int   = 0
var wave:        int   = 0
var total_waves: int   = 0
var phase:       Phase = Phase.READY

func new_game() -> void:
	score = 0
	lives = ConfigManager.get_int("player_hp", 0)
	wave  = 0
	phase = Phase.READY
	emit_signal("score_changed", score)
	emit_signal("lives_changed", lives)
	emit_signal("phase_changed", phase)
	emit_signal("wave_changed",  wave)

func add_score(points: int) -> void:
	score += points
	if score > high_score:
		high_score = score
	emit_signal("score_changed", score)

func lose_life() -> void:
	lives -= 1
	if lives < 0: lives = 0
	emit_signal("lives_changed", lives)
	if lives <= 0:
		set_phase(Phase.GAME_OVER)

func set_phase(p: Phase) -> void:
	phase = p
	emit_signal("phase_changed", p)

func next_wave() -> void:
	wave += 1
	emit_signal("wave_changed", wave)
	if wave > total_waves:
		set_phase(Phase.VICTORY)
	else:
		set_phase(Phase.PLAYING)

# =============================================================================
# GameState.gd — Autoload (Singleton)
# =============================================================================
# Central authority for score, lives, current level and game phase.
# The game loop (Main.gd) connects to the signals emitted here and acts on
# them — no UI or Node logic lives inside GameState itself.
#
# PHASE MACHINE:
#   PLAYING  — normal play
#   DEAD     — player hit; respawn timer running in Main.gd
#   GAME_OVER — lives exhausted
#   WIN       — all levels cleared
# =============================================================================

extends Node

enum Phase { PLAYING, DEAD, GAME_OVER, WIN }

signal score_changed(value: int)
signal lives_changed(value: int)
signal phase_changed(new_phase: Phase)
signal player_died()
signal level_complete()
signal game_over()
signal game_won()

var score:         int   = 0
var lives:         int   = 3
var current_level: int   = 0   # 0-based index into the levels array
var total_levels:  int   = 0   # set by Main after loading levels.json
var phase:         Phase = Phase.PLAYING

## Resets all state for a fresh game start.
func new_game() -> void:
	score         = 0
	lives         = ConfigManager.get_int("max_lives", 0)
	current_level = 0
	phase         = Phase.PLAYING
	emit_signal("score_changed", score)
	emit_signal("lives_changed", lives)
	emit_signal("phase_changed", phase)

## Called by Player on collision with an enemy (non-stomp contact).
func player_die() -> void:
	if phase != Phase.PLAYING:
		return
	lives -= 1
	emit_signal("lives_changed", lives)
	if lives <= 0:
		phase = Phase.GAME_OVER
		emit_signal("phase_changed", phase)
		emit_signal("game_over")
	else:
		phase = Phase.DEAD
		emit_signal("phase_changed", phase)
		emit_signal("player_died")

## Called by Exit when the player reaches it.
func complete_level() -> void:
	if phase != Phase.PLAYING:
		return
	current_level += 1
	if current_level >= total_levels:
		phase = Phase.WIN
		emit_signal("phase_changed", phase)
		emit_signal("game_won")
	else:
		emit_signal("level_complete")

## Adds points to the score and notifies listeners.
func add_score(points: int) -> void:
	score += points
	emit_signal("score_changed", score)

## Resets phase to PLAYING after a respawn.
## Must be called by Main before rebuilding the level so the death guard
## in player_die() does not block the next death event.
func resume_playing() -> void:
	if phase != Phase.DEAD:
		return
	phase = Phase.PLAYING
	emit_signal("phase_changed", phase)

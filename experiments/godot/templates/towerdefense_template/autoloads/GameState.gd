# =============================================================================
# GameState.gd (Autoload, Singleton)
# =============================================================================
# Central authority for gold, lives, score, wave index, countdown and phase.
# No scene logic lives here: Main.gd, the HUD and the world react to signals.
#
# PHASE MACHINE:
#   BUILD:     between waves. A countdown (next_wave_timer) starts the next
#              wave automatically once the first wave has been played.
#   WAVE:      enemies are spawning / in the field.
#   GAME_OVER / VICTORY: terminal states, restart via new_game().
#
#   Building, upgrading and selling are allowed in BUILD *and* WAVE: the phase
#   only drives the wave flow, never the player's agency.
#
# ECONOMY:
#   kill reward        -> gold (+ score x10)
#   wave cleared       -> wave_clear_bonus_base + step x wave_index
#   early call         -> remaining countdown seconds x early_call_gold_per_sec
#   victory            -> remaining lives x 100 score
# =============================================================================

extends Node

enum Phase { BUILD, WAVE, GAME_OVER, VICTORY }

signal gold_changed(value: int)
signal lives_changed(value: int)
signal score_changed(value: int)
signal phase_changed(new_phase: Phase)
signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int, bonus: int)
signal life_lost(amount: int)
signal early_bonus_awarded(amount: int)
signal game_over()
signal game_won()

var gold:            int   = 0
var lives:           int   = 0
var score:           int   = 0
var kills:           int   = 0
var wave_index:      int   = 0      # 0-based index of the next / current wave
var total_waves:     int   = 0      # set by WaveManager from waves.json
var phase:           Phase = Phase.BUILD
var next_wave_timer: float = -1.0   # < 0 : no countdown running

func new_game() -> void:
	gold            = ConfigManager.get_int("starting_gold", 0)
	lives           = ConfigManager.get_int("starting_lives", 0)
	score           = 0
	kills           = 0
	wave_index      = 0
	next_wave_timer = -1.0
	phase           = Phase.BUILD
	gold_changed.emit(gold)
	lives_changed.emit(lives)
	score_changed.emit(score)
	phase_changed.emit(phase)

# ---------------------------------------------------------------------------
# Economy
# ---------------------------------------------------------------------------

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func can_afford(amount: int) -> bool:
	return gold >= amount

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)

## Called by an Enemy when it dies from tower damage.
func register_kill(reward: int) -> void:
	kills += 1
	add_gold(reward)
	add_score(reward * 10)

func is_playing() -> bool:
	return phase == Phase.BUILD or phase == Phase.WAVE

# ---------------------------------------------------------------------------
# Lives
# ---------------------------------------------------------------------------

## Called by an Enemy when it reaches the base. Must run BEFORE the enemy
## notifies the WaveManager, otherwise the last leaking enemy of a wave would
## clear the wave first and its damage would be ignored.
func enemy_reached_exit(damage: int) -> void:
	if phase != Phase.WAVE:
		return
	lives = maxi(lives - damage, 0)
	lives_changed.emit(lives)
	life_lost.emit(damage)
	if lives <= 0:
		_set_phase(Phase.GAME_OVER)
		game_over.emit()

# ---------------------------------------------------------------------------
# Wave flow
# ---------------------------------------------------------------------------

## Called by WaveManager every frame: drives the auto-start countdown.
func tick_countdown(delta: float) -> void:
	if phase != Phase.BUILD or next_wave_timer < 0.0:
		return
	next_wave_timer -= delta
	if next_wave_timer <= 0.0:
		next_wave_timer = -1.0
		begin_wave()

## Gold the player would earn by calling the next wave right now.
func early_bonus_preview() -> int:
	if phase != Phase.BUILD or next_wave_timer <= 0.0:
		return 0
	return int(next_wave_timer * ConfigManager.get_float("early_call_gold_per_sec", 0.0))

## Player action (button / Space): starts the next wave, with early bonus.
func call_wave() -> void:
	if phase != Phase.BUILD:
		return
	var bonus: int = early_bonus_preview()
	if bonus > 0:
		add_gold(bonus)
		early_bonus_awarded.emit(bonus)
	begin_wave()

func begin_wave() -> void:
	if phase != Phase.BUILD:
		return
	next_wave_timer = -1.0
	_set_phase(Phase.WAVE)
	wave_started.emit(wave_index)

## Called by WaveManager when the last enemy of a wave is gone.
func on_wave_completed() -> void:
	if phase != Phase.WAVE:
		return
	var cleared: int = wave_index
	var bonus: int = ConfigManager.get_int("wave_clear_bonus_base", 0) \
		+ ConfigManager.get_int("wave_clear_bonus_step", 0) * cleared
	wave_index += 1
	add_gold(bonus)
	add_score(bonus * 10)
	wave_cleared.emit(cleared, bonus)
	if wave_index >= total_waves:
		add_score(lives * 100)
		_set_phase(Phase.VICTORY)
		game_won.emit()
	else:
		next_wave_timer = ConfigManager.get_float("wave_between_delay", 0.0)
		_set_phase(Phase.BUILD)

func _set_phase(p: Phase) -> void:
	phase = p
	phase_changed.emit(phase)

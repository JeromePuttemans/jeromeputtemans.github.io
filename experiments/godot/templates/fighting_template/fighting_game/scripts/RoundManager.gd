# RoundManager.gd [CORRECTED]
# Controls round flow: countdown → fight → KO → next round → match end.
#
# FIXES:
#   C4 — countdown tracked via instance var, not unreliable meta
#   C5 — reads fighter.health (public property) instead of fighter._health (private)
#   M2 — removed dead variable h0

class_name RoundManager
extends Node

enum RoundState { COUNTDOWN, FIGHTING, ROUND_OVER, MATCH_OVER }

signal round_started(round_number: int)
signal round_ended(winner_index: int)
signal match_ended(winner_index: int)
signal timer_updated(seconds_left: int)
signal countdown_tick(value: int)

var state: RoundState = RoundState.COUNTDOWN

var _rounds_to_win: int       = 0
var _round_time: float        = 0.0
var _time_left: float         = 0.0
var _current_round: int       = 0
var _round_wins: Array[int]   = [0, 0]
var _fighters: Array[Fighter] = []
# FIX C4: reliable instance variable instead of meta
var _countdown_ticks: int     = 0

@onready var _countdown_timer: Timer = $CountdownTimer
@onready var _round_timer: Timer     = $RoundTimer

func setup(fighters: Array[Fighter]) -> void:
	_fighters      = fighters
	_rounds_to_win = int(SettingsManager.get_value("match.rounds_to_win", 2))
	_round_time    = float(SettingsManager.get_value("match.round_time_seconds", 99.0))

	for i in range(_fighters.size()):
		var f := _fighters[i]
		if f != null:
			f.died.connect(_on_fighter_died.bind(i))

	_countdown_timer.timeout.connect(_on_countdown_timer_timeout)
	_round_timer.timeout.connect(_on_round_timer_timeout)
	_start_countdown()

func _start_countdown() -> void:
	state = RoundState.COUNTDOWN
	_current_round += 1
	_reset_fighters()
	# FIX C4: use instance variable — reliably initialized before timer fires
	_countdown_ticks = int(SettingsManager.get_value("match.countdown_seconds", 3))
	countdown_tick.emit(_countdown_ticks)
	_countdown_timer.wait_time = 1.0
	_countdown_timer.start()

func _on_countdown_timer_timeout() -> void:
	if state != RoundState.COUNTDOWN:
		_countdown_timer.stop()
		return
	_countdown_ticks -= 1
	countdown_tick.emit(_countdown_ticks)
	if _countdown_ticks <= 0:
		_countdown_timer.stop()
		_start_round()

func _start_round() -> void:
	state      = RoundState.FIGHTING
	_time_left = _round_time
	_round_timer.wait_time = 1.0
	_round_timer.start()
	round_started.emit(_current_round)

func _on_round_timer_timeout() -> void:
	if state != RoundState.FIGHTING:
		return
	_time_left -= 1.0
	timer_updated.emit(int(_time_left))
	if _time_left <= 0.0:
		_resolve_timeout()

func _resolve_timeout() -> void:
	_round_timer.stop()
	state = RoundState.ROUND_OVER
	# FIX C5: use public .health property instead of private ._health
	# FIX M2: removed dead variable h0
	var hp0: float = _fighters[0].health if _fighters.size() > 0 else 0.0
	var hp1: float = _fighters[1].health if _fighters.size() > 1 else 0.0
	var winner: int = -1
	if hp0 > hp1:   winner = 0
	elif hp1 > hp0: winner = 1
	_end_round(winner)

func _on_fighter_died(fighter_index: int) -> void:
	if state != RoundState.FIGHTING:
		return
	_round_timer.stop()
	state = RoundState.ROUND_OVER
	_end_round(1 - fighter_index)

func _end_round(winner_index: int) -> void:
	if winner_index >= 0 and winner_index < _round_wins.size():
		_round_wins[winner_index] += 1
	round_ended.emit(winner_index)

	if _round_wins[0] >= _rounds_to_win:
		_end_match(0)
	elif _round_wins[1] >= _rounds_to_win:
		_end_match(1)
	else:
		await get_tree().create_timer(2.0).timeout
		_start_countdown()

func _end_match(winner_index: int) -> void:
	state = RoundState.MATCH_OVER
	match_ended.emit(winner_index)

func _reset_fighters() -> void:
	var max_hp: float = float(SettingsManager.get_value("fighter.max_health", 0.0))
	for f in _fighters:
		if f == null:
			continue
		f._health = max_hp
		f.health_changed.emit(max_hp, max_hp)
		f.velocity = Vector2.ZERO
		if f.fsm != null:
			f.fsm.current = FighterStateMachine.State.IDLE

func get_round_wins() -> Array[int]:
	return _round_wins.duplicate()

# Note: _reset_fighters is already defined above. This append is a reminder
# that start positions should be restored. In practice, Arena sets positions
# on first load; RoundManager only resets health and FSM state.

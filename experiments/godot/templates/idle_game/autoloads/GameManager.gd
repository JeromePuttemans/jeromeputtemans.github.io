# =============================================================================
# GameManager.gd — Autoload (Singleton)
# =============================================================================
# The game loop, clicks, offline progress, autosave and statistics.
#
# TICK: every frame, production += total_rps x delta (framerate independent:
#   the deltas of one second always add up to 1).
# CLICK: a click on the crystal gives click_value(); with crit_chance (5 %)
#   it is a critical strike worth crit_multiplier (x5). Each click heats the
#   crystal (BoostManager).
# OFFLINE: at startup, the time since the last save (at most offline_cap_hours)
#   x base production x offline_factor (half) is credited. When the absence
#   lasts at least offline_min_seconds, offline_report is filled for the
#   "welcome back" window of the UI.
# SAVE: every auto_save_interval_seconds, when the window closes or loses
#   focus (a browser tab hidden, for instance), and after a crystallization.
# =============================================================================

extends Node

signal clicked(amount: float, critical: bool)

var buy_mode: int = 1
var last_critical: bool = false
var offline_report: Dictionary = {}   # {seconds, amount} when worth showing
var stats: Dictionary = {"clicks": 0, "crits": 0, "meteors": 0, "frenzies": 0, "play_time": 0.0}
var _autosave_left: float = 0.0

func _ready() -> void:
	BoostManager.frenzy_started.connect(func(_d: float) -> void: stats["frenzies"] = int(stats["frenzies"]) + 1)
	BoostManager.meteor_caught.connect(func(_k: String, _a: float) -> void: stats["meteors"] = int(stats["meteors"]) + 1)
	PrestigeManager.prestige_done.connect(func(_g: int, _t: int) -> void: SaveManager.save_game())
	var timestamp: float = SaveManager.load_game()
	if timestamp > 0.0:
		_apply_offline(Time.get_unix_time_from_system() - timestamp)
	_autosave_left = ConfigManager.get_float("auto_save_interval_seconds", 15.0)

func _apply_offline(seconds_away: float) -> void:
	var seconds: float = clampf(seconds_away, 0.0, ConfigManager.get_float("offline_cap_hours", 8.0) * 3600.0)
	var amount: float = seconds * ProducerManager.get_base_rps() * ConfigManager.get_float("offline_factor", 0.5)
	if amount > 0.0:
		ResourceManager.add(ResourceManager.main_resource, amount)
	if seconds_away >= ConfigManager.get_float("offline_min_seconds", 60.0) and amount > 0.0:
		offline_report = {"seconds": seconds_away, "capped": seconds < seconds_away, "amount": amount}

func _process(delta: float) -> void:
	BoostManager.tick(delta)
	ProducerManager.tick(delta)
	stats["play_time"] = float(stats["play_time"]) + delta
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = ConfigManager.get_float("auto_save_interval_seconds", 15.0)
		SaveManager.save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		SaveManager.save_game()

## A click on the crystal. Returns the shards gained.
func click() -> float:
	var critical: bool = randf() < ConfigManager.get_float("crit_chance", 0.05)
	var amount: float = ProducerManager.click_value()
	if critical:
		amount *= ConfigManager.get_float("crit_multiplier", 5.0)
		stats["crits"] = int(stats["crits"]) + 1
	stats["clicks"] = int(stats["clicks"]) + 1
	last_critical = critical
	ResourceManager.add(ResourceManager.main_resource, amount)
	BoostManager.add_heat()
	clicked.emit(amount, critical)
	return amount

func set_buy_mode(mode: int) -> void:
	buy_mode = mode

## Erases everything, prisms included, and the save file.
func hard_reset() -> void:
	SaveManager.delete_save()
	ResourceManager.reset_all()
	ProducerManager.reset_run()
	PrestigeManager.reset_all()
	BoostManager.reset()
	for key in stats:
		stats[key] = 0.0 if key == "play_time" else 0
	offline_report = {}
	SaveManager.save_game()

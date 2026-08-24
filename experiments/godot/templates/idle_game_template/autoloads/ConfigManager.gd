# =============================================================================
# ConfigManager.gd — Autoload (Singleton)
# =============================================================================
# Loads and exposes all game settings from data/config.json.
# Must be the first autoload — all other managers depend on it.
#
# Adding a new setting: add it to config.json and expose a typed getter here.
# No other file should hardcode a game constant.
# =============================================================================

extends Node

const CONFIG_PATH = "res://data/config.json"

var _config: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("ConfigManager: file not found → " + CONFIG_PATH)
		return
	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		push_error("ConfigManager: cannot open → " + CONFIG_PATH)
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("ConfigManager: JSON parse error at line %d" % json.get_error_line())
		return
	_config = json.get_data()

# =============================================================================
# TYPED GETTERS
# Fallback values are intentionally neutral (no production, no progress)
# so that a missing config.json causes visible inactivity rather than
# silently wrong gameplay.
# =============================================================================

## The primary resource identifier used across all managers and UI.
var main_resource: String:
	get: return _config.get("main_resource", "gold")

## All resource IDs to register at startup.
var resources: Array:
	get: return _config.get("resources", ["gold"])

## How often the game auto-saves (seconds).
var auto_save_interval: float:
	get: return float(_config.get("auto_save_interval_seconds", 30.0))

## Maximum offline time credited to the player (converted to seconds).
var offline_cap_seconds: float:
	get: return float(_config.get("offline_cap_hours", 0.0)) * 3600.0

## Fraction of normal RPS applied to offline production (0.0–1.0).
var offline_factor: float:
	get: return float(_config.get("offline_factor", 0.0))

## Base gold earned per manual click (before upgrade multipliers).
var click_base_value: float:
	get: return float(_config.get("click_base_value", 1.0))

# =============================================================================
# GENERIC TYPED GETTERS
# Used by StringManager and any future system that reads arbitrary config keys.
# =============================================================================

func get_int(key: String, default: int = 0) -> int:
	return int(_config.get(key, default))

func get_float(key: String, default: float = 0.0) -> float:
	return float(_config.get(key, default))

func get_string(key: String, default: String = "") -> String:
	return str(_config.get(key, default))

## Returns the full raw config Dictionary for batch access.
func get_raw() -> Dictionary:
	return _config

# =============================================================================
# ConfigManager.gd — Autoload (Singleton)
# =============================================================================
# Loads data/config.json and exposes typed getters.
# Must be FIRST in the autoload list.
# Fallback values in calling code must always be 0 / 0.0, never real values.
# =============================================================================

extends Node

const CONFIG_PATH = "res://data/config.json"
var _cfg: Dictionary = {}

func _ready() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("ConfigManager: file not found — " + CONFIG_PATH)
		return
	var f = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not f:
		push_error("ConfigManager: cannot open — " + CONFIG_PATH)
		return
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("ConfigManager: JSON parse error at line %d" % j.get_error_line())
		return
	_cfg = j.get_data()

func get_int(key: String, default: int = 0) -> int:
	return int(_cfg.get(key, default))

func get_float(key: String, default: float = 0.0) -> float:
	return float(_cfg.get(key, default))

func get_string(key: String, default: String = "") -> String:
	return str(_cfg.get(key, default))

func get_raw() -> Dictionary:
	return _cfg

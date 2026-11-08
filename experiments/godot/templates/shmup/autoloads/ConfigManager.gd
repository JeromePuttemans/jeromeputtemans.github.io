# =============================================================================
# ConfigManager.gd — Autoload #1
# Loads data/config.json. All fallback values in calling code must be 0/0.0.
# =============================================================================
extends Node

const PATH = "res://data/config.json"
var _cfg: Dictionary = {}

func _ready() -> void:
	var f = FileAccess.open(PATH, FileAccess.READ)
	if not f:
		push_error("ConfigManager: cannot open " + PATH); return
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("ConfigManager: parse error line %d" % j.get_error_line()); return
	_cfg = j.get_data()

func get_int(key: String, default: int = 0) -> int:
	return int(_cfg.get(key, default))

func get_float(key: String, default: float = 0.0) -> float:
	return float(_cfg.get(key, default))

func get_string(key: String, default: String = "") -> String:
	return str(_cfg.get(key, default))

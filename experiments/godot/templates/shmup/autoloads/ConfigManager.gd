# =============================================================================
# ConfigManager.gd — Autoload (Singleton)
# =============================================================================
# Loads data/config.json and exposes typed getters. First in the autoload
# list: every other singleton reads its values from here.
# =============================================================================

extends Node

const CONFIG_PATH: String = "res://data/config.json"

var _config: Dictionary = {}

func _ready() -> void:
	_config = load_json(CONFIG_PATH) as Dictionary

static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("ConfigManager: not found " + path)
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("ConfigManager: JSON error in %s at line %d" % [path, json.get_error_line()])
		return {}
	return json.data

func get_int(key: String, default: int = 0) -> int:
	return int(_config.get(key, default))

func get_float(key: String, default: float = 0.0) -> float:
	return float(_config.get(key, default))

func get_string(key: String, default: String = "") -> String:
	return str(_config.get(key, default))

func get_bool(key: String, default: bool = false) -> bool:
	return bool(_config.get(key, default))

func get_array(key: String) -> Array:
	var value: Variant = _config.get(key, [])
	return value as Array if value is Array else []

func get_dict(key: String) -> Dictionary:
	var value: Variant = _config.get(key, {})
	return value as Dictionary if value is Dictionary else {}

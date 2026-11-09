# =============================================================================
# ConfigManager.gd — Autoload (Singleton)
# =============================================================================
# Loads data/config.json and exposes typed getters. First autoload: every
# other manager reads its tuning values here, so no game constant is written
# in a script.
# Fallback values are neutral (no production, no bonus): a missing key shows
# up as visible inactivity rather than silently wrong gameplay.
# =============================================================================

extends Node

const CONFIG_PATH: String = "res://data/config.json"

var _config: Dictionary = {}

func _ready() -> void:
	var data: Variant = load_json(CONFIG_PATH)
	if data is Dictionary:
		_config = data as Dictionary
	else:
		push_error("ConfigManager: cannot read " + CONFIG_PATH)

func get_float(key: String, fallback: float = 0.0) -> float:
	return float(_config.get(key, fallback))

func get_int(key: String, fallback: int = 0) -> int:
	return int(_config.get(key, fallback))

func get_string(key: String, fallback: String = "") -> String:
	return str(_config.get(key, fallback))

func get_array(key: String) -> Array:
	var value: Variant = _config.get(key, [])
	return value as Array if value is Array else []

## Reads and parses a JSON file; null (with an error) when it fails.
static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("JSON file not found: " + path)
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open: " + path)
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("JSON error in %s at line %d" % [path, json.get_error_line()])
		return null
	return json.get_data()

# =============================================================================
# ConfigManager.gd — Autoload (Singleton)
# =============================================================================
# Loads data/config.json and exposes typed getters.
# Must be FIRST in the autoload list — all other singletons depend on it.
# Fallback values are intentionally neutral (0 / "" / BLACK) so a missing
# config causes visible inactivity rather than silently wrong behaviour.
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

func get_int(key: String, default: int = 0) -> int:
	return int(_config.get(key, default))

func get_float(key: String, default: float = 0.0) -> float:
	return float(_config.get(key, default))

func get_string(key: String, default: String = "") -> String:
	return str(_config.get(key, default))

func get_color(key: String, default: Color = Color.BLACK) -> Color:
	var hex: String = _config.get("colors", {}).get(key, "")
	if hex.is_empty():
		return default
	return Color("#" + hex if not hex.begins_with("#") else hex)

## Returns the full raw config Dictionary for batch access (e.g. BattleSimulator).
func get_raw() -> Dictionary:
	return _config

# =============================================================================
# ConfigManager.gd (Autoload, Singleton)
# =============================================================================
# Loads data/config.json and exposes typed getters.
# Must be declared FIRST in the autoload list: every other singleton reads it.
# =============================================================================

extends Node

const CONFIG_PATH: String = "res://data/config.json"
var _config: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("ConfigManager: file not found: " + CONFIG_PATH)
		return
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("ConfigManager: cannot open " + CONFIG_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("ConfigManager: JSON parse error at line %d" % json.get_error_line())
		return
	_config = json.get_data() as Dictionary

# --- Typed getters -----------------------------------------------------------
# Fallback values are neutral: a missing key causes visible inactivity
# rather than silently plausible values.

func get_int(key: String, default: int = 0) -> int:
	return int(_config.get(key, default))

func get_float(key: String, default: float = 0.0) -> float:
	return float(_config.get(key, default))

func get_string(key: String, default: String = "") -> String:
	return str(_config.get(key, default))

## Raw value for arrays / dictionaries (e.g. floor_themes).
func get_value(key: String, default: Variant = null) -> Variant:
	return _config.get(key, default)

## Theme of a floor (1-based); the last theme repeats for deeper floors.
func get_floor_theme(floor_number: int) -> Dictionary:
	var themes: Array = get_value("floor_themes", []) as Array
	if themes.is_empty():
		return {}
	return themes[clampi(floor_number - 1, 0, themes.size() - 1)] as Dictionary

## Full config Dictionary, for systems that read many keys at once
## (DungeonGenerator).
func get_raw() -> Dictionary:
	return _config

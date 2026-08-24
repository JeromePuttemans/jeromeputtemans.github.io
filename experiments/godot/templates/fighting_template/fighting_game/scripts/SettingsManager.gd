# SettingsManager.gd
# Autoload singleton — loads and validates settings.json at startup.
# All game systems read parameters from here via SettingsManager.get_value().

extends Node

const SETTINGS_PATH := "res://settings.json"
const SCHEMA_VERSION := 1

var _data: Dictionary = {}
var _loaded: bool = false

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_settings()

# ── Public API ───────────────────────────────────────────────────────────────

## Returns a nested value by dot-separated path, e.g. "fighter.walk_speed".
## Falls back to `default` when the key is absent (neutral fallback: 0 / 0.0 / "").
func get_value(path: String, default = null):
	if not _loaded:
		push_warning("SettingsManager: settings not loaded, returning default for '%s'" % path)
		return default

	var keys := path.split(".")
	var current = _data
	for key in keys:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			push_warning("SettingsManager: key '%s' not found, using default." % path)
			return default
	return current

func is_loaded() -> bool:
	return _loaded

# ── Private ──────────────────────────────────────────────────────────────────

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		push_error("SettingsManager: '%s' not found — using empty config." % SETTINGS_PATH)
		_data = {}
		_loaded = false
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("SettingsManager: cannot open '%s' (error %d)." % [SETTINGS_PATH, FileAccess.get_open_error()])
		_loaded = false
		return

	var raw := file.get_as_text()
	file.close()

	# Security: validate JSON before trusting it
	var json := JSON.new()
	var err := json.parse(raw)
	if err != OK:
		push_error("SettingsManager: JSON parse error at line %d — %s" % [json.get_error_line(), json.get_error_message()])
		_loaded = false
		return

	var parsed = json.get_data()
	if not parsed is Dictionary:
		push_error("SettingsManager: root JSON element must be an Object (Dictionary).")
		_loaded = false
		return

	_data = parsed
	_loaded = true
	print("SettingsManager: loaded '%s' successfully." % SETTINGS_PATH)

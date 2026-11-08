# =============================================================================
# StringManager.gd — Autoload (Singleton)
# =============================================================================
# Loads data/strings_<lang>.json and provides {placeholder} substitution.
# Every UI node displaying text must connect to language_changed and refresh.
# Adding a language: copy strings_en.json, translate values, add code to the
# cycle list in HUD._on_lang_pressed(). No other change required here.
# =============================================================================

extends Node

signal language_changed(new_lang: String)

const STRINGS_DIR   = "res://data/"
const FALLBACK_LANG = "en"

var _current_lang: String = FALLBACK_LANG
var _strings:      Dictionary = {}
var _fallback:     Dictionary = {}

func _ready() -> void:
	_fallback     = _load_file(FALLBACK_LANG)
	_strings      = _fallback
	_current_lang = FALLBACK_LANG
	var default_lang = ConfigManager.get_string("default_language", FALLBACK_LANG)
	if default_lang != FALLBACK_LANG:
		set_language(default_lang)

func set_language(lang: String) -> void:
	if lang == _current_lang:
		return
	var loaded = _load_file(lang)
	if loaded.is_empty():
		push_warning("StringManager: '%s' unavailable, keeping '%s'." % [lang, _current_lang])
		return
	_current_lang = lang
	_strings      = loaded
	emit_signal("language_changed", lang)

func get_language() -> String:
	return _current_lang

## Returns the localised string with {placeholder} substitution.
## Falls back to EN for missing keys; renders "[key]" if missing in both.
func t(key: String, replacements: Dictionary = {}) -> String:
	var s: String = _strings.get(key, _fallback.get(key, "[%s]" % key))
	for k in replacements:
		s = s.replace("{%s}" % k, str(replacements[k]))
	return s

func _load_file(lang: String) -> Dictionary:
	var path = STRINGS_DIR + "strings_" + lang + ".json"
	if not FileAccess.file_exists(path):
		push_error("StringManager: not found → " + path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("StringManager: cannot open → " + path)
		return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("StringManager: parse error in %s at line %d" % [path, json.get_error_line()])
		return {}
	return json.get_data()

# =============================================================================
# StringManager.gd — Autoload (Singleton)
# =============================================================================
# Loads data/strings_<lang>.json and provides {placeholder} substitution.
# Adding a language: copy strings_en.json, translate values, add the code to
# the language cycle in HUD.gd. No other change required here.
# =============================================================================

extends Node

signal language_changed(new_lang: String)

const STRINGS_DIR   = "res://data/"
const FALLBACK_LANG = "en"

var _lang:     String     = FALLBACK_LANG
var _strings:  Dictionary = {}
var _fallback: Dictionary = {}

func _ready() -> void:
	_fallback = _load_file(FALLBACK_LANG)
	_strings  = _fallback
	var default = ConfigManager.get_string("default_language", FALLBACK_LANG)
	if default != FALLBACK_LANG:
		set_language(default)

func set_language(lang: String) -> void:
	if lang == _lang:
		return
	var loaded = _load_file(lang)
	if loaded.is_empty():
		push_warning("StringManager: '%s' unavailable, keeping '%s'" % [lang, _lang])
		return
	_lang    = lang
	_strings = loaded
	emit_signal("language_changed", lang)

func get_language() -> String:
	return _lang

## Returns localised string with {key} substitution.
## Falls back to EN for missing keys; renders "[key]" if absent in both.
func t(key: String, replacements: Dictionary = {}) -> String:
	var s: String = _strings.get(key, _fallback.get(key, "[%s]" % key))
	for k in replacements:
		s = s.replace("{%s}" % k, str(replacements[k]))
	return s

func _load_file(lang: String) -> Dictionary:
	var path = STRINGS_DIR + "strings_" + lang + ".json"
	if not FileAccess.file_exists(path):
		push_error("StringManager: not found — " + path)
		return {}
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("StringManager: parse error in %s at line %d" % [path, j.get_error_line()])
		return {}
	return j.get_data()

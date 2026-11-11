# =============================================================================
# StringManager.gd — Autoload (Singleton)
# =============================================================================
# Loads data/strings_<lang>.json and replaces {placeholders}. The language
# is kept in the save. Every node showing text listens to language_changed.
# Texts use Latin-1 characters only: the web build has no font fallback and
# any other glyph (arrows, stars) would show as a box.
# =============================================================================

extends Node

signal language_changed(new_lang: String)

const LANGUAGES: Array[String] = ["fr", "en"]
const FALLBACK_LANG: String = "en"

var _current_lang: String = FALLBACK_LANG
var _strings: Dictionary = {}
var _fallback: Dictionary = {}

func _ready() -> void:
	_fallback = _load_file(FALLBACK_LANG)
	_strings = _fallback
	var lang: String = str(SaveManager.get_setting("language", ConfigManager.get_string("default_language", "fr")))
	set_language(lang)

func set_language(lang: String) -> void:
	if lang == _current_lang and not _strings.is_empty():
		return
	var loaded: Dictionary = _load_file(lang)
	if loaded.is_empty():
		return
	_current_lang = lang
	_strings = loaded
	if str(SaveManager.get_setting("language", "")) != lang:
		SaveManager.set_setting("language", lang)
	language_changed.emit(lang)

func cycle_language() -> void:
	var index: int = LANGUAGES.find(_current_lang)
	set_language(LANGUAGES[(index + 1) % LANGUAGES.size()])

func get_language() -> String:
	return _current_lang

## Localised string with {placeholder} substitution; EN for missing keys.
func t(key: String, replacements: Dictionary = {}) -> String:
	var s: String = str(_strings.get(key, _fallback.get(key, "[%s]" % key)))
	for k in replacements:
		s = s.replace("{%s}" % k, str(replacements[k]))
	return s

func _load_file(lang: String) -> Dictionary:
	var path: String = "res://data/strings_%s.json" % lang
	var data: Variant = ConfigManager.load_json(path)
	return data as Dictionary if data is Dictionary else {}

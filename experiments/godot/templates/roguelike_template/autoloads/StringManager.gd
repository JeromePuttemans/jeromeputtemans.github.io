# =============================================================================
# StringManager.gd — Autoload (Singleton)
# =============================================================================
# Loads language files from data/strings_<lang>.json and provides
# {placeholder} substitution.
#
# Adding a new language:
#   1. Create data/strings_<code>.json with all keys translated.
#   2. Call StringManager.set_language("<code>") at startup or on user action.
#      No other change is required.
#
# Usage:
#   StringManager.t("hp_label", {current = 18, max = 30})  → "HP: 18/30"
#   StringManager.set_language("fr")
#   StringManager.t("hp_label", {current = 18, max = 30})  → "PV : 18/30"
#
# UI components that display text must connect to language_changed and
# call their own refresh method to update all labels instantly.
# =============================================================================

extends Node

## Emitted after a successful language switch.
## Every UI component using StringManager.t() must connect here and re-render.
signal language_changed(new_lang: String)

const STRINGS_DIR  = "res://data/"
const FALLBACK_LANG = "en"

var _current_lang: String = FALLBACK_LANG
var _strings: Dictionary  = {}
var _fallback: Dictionary = {}   # Always EN — used when a key is missing in current lang

func _ready() -> void:
	# Load EN as the fallback first — guarantees all keys are always resolvable
	_fallback = _load_file(FALLBACK_LANG)
	_strings  = _fallback
	_current_lang = FALLBACK_LANG

	var default_lang = ConfigManager.get_string("default_language", FALLBACK_LANG)
	if default_lang != FALLBACK_LANG:
		set_language(default_lang)

## Switches the active language and emits language_changed.
## Does nothing (with a warning) if the language file cannot be loaded.
func set_language(lang: String) -> void:
	if lang == _current_lang:
		return
	var loaded = _load_file(lang)
	if loaded.is_empty():
		push_warning("StringManager: language '%s' not available, keeping '%s'." % [lang, _current_lang])
		return
	_current_lang = lang
	_strings      = loaded
	emit_signal("language_changed", lang)

## Returns the current language code (e.g. "en", "fr").
func get_language() -> String:
	return _current_lang

## Returns the localized string for `key` with {placeholder} substitution.
## Falls back to EN if the key is absent from the current language file.
## Renders "[key]" if absent from both, making gaps immediately visible.
func t(key: String, replacements: Dictionary = {}) -> String:
	var s: String = _strings.get(key, _fallback.get(key, "[%s]" % key))
	for placeholder in replacements:
		s = s.replace("{%s}" % placeholder, str(replacements[placeholder]))
	return s

# =============================================================================
# PRIVATE
# =============================================================================

func _load_file(lang: String) -> Dictionary:
	var path = STRINGS_DIR + "strings_" + lang + ".json"
	if not FileAccess.file_exists(path):
		push_error("StringManager: file not found → " + path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("StringManager: cannot open → " + path)
		return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("StringManager: JSON parse error in %s at line %d" % [path, json.get_error_line()])
		return {}
	return json.get_data()

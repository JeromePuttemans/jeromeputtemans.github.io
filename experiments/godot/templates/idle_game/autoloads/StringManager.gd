# =============================================================================
# StringManager.gd — Autoload (Singleton)
# =============================================================================
# UI texts from data/strings_<lang>.json, with {placeholder} substitution.
#
#   StringManager.t("cost_label", {value = "1.5K"})  -> "Cost: 1.5K"
#
# The starting language is config.default_language; "auto" picks French when
# the system (or browser) language is French, English otherwise. The saved
# choice of the player overrides it (SaveManager calls set_language).
# Every UI component that shows text connects to language_changed and
# re-renders. A key missing in the current language falls back to English;
# missing in both, it shows as [key] so the gap is visible.
# =============================================================================

extends Node

signal language_changed(new_lang: String)

const STRINGS_DIR: String = "res://data/"
const FALLBACK_LANG: String = "en"
const LANGUAGES: Array[String] = ["fr", "en"]

var _current_lang: String = FALLBACK_LANG
var _strings: Dictionary = {}
var _fallback: Dictionary = {}

func _ready() -> void:
	_fallback = _load_file(FALLBACK_LANG)
	_strings = _fallback
	var wanted: String = ConfigManager.get_string("default_language", "auto")
	if wanted == "auto":
		wanted = "fr" if OS.get_locale_language() == "fr" else FALLBACK_LANG
	set_language(wanted)

func set_language(lang: String) -> void:
	if lang == _current_lang and not _strings.is_empty():
		return
	var loaded: Dictionary = _load_file(lang)
	if loaded.is_empty():
		push_warning("StringManager: language '%s' not available." % lang)
		return
	_current_lang = lang
	_strings = loaded
	language_changed.emit(lang)

func cycle_language() -> void:
	var index: int = LANGUAGES.find(_current_lang)
	set_language(LANGUAGES[(index + 1) % LANGUAGES.size()])

func get_language() -> String:
	return _current_lang

func t(key: String, replacements: Dictionary = {}) -> String:
	var text: String = str(_strings.get(key, _fallback.get(key, "[%s]" % key)))
	for placeholder in replacements:
		text = text.replace("{%s}" % placeholder, str(replacements[placeholder]))
	return text

## Name of a producer in the current language.
func producer_name(producer_id: String) -> String:
	return t("producer_%s_name" % producer_id)

func _load_file(lang: String) -> Dictionary:
	var data: Variant = ConfigManager.load_json(STRINGS_DIR + "strings_" + lang + ".json")
	return data as Dictionary if data is Dictionary else {}

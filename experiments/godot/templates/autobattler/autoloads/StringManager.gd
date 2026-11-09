# =============================================================================
# StringManager.gd — Autoload (Singleton)
# =============================================================================
# UI texts from data/strings_<lang>.json, with {placeholder} substitution:
#   StringManager.t("gold_label", {value = 12})  -> "Gold: 12"
# config.default_language "auto" picks French when the system (or browser)
# language is French, English otherwise. Every UI component that shows text
# listens to language_changed. A key missing in the current language falls
# back to English; missing in both, it shows as [key].
# =============================================================================

extends Node

signal language_changed(new_lang: String)

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
		return
	_current_lang = lang
	_strings = loaded
	language_changed.emit(lang)

func cycle_language() -> void:
	set_language(LANGUAGES[(LANGUAGES.find(_current_lang) + 1) % LANGUAGES.size()])

func get_language() -> String:
	return _current_lang

func t(key: String, replacements: Dictionary = {}) -> String:
	var text: String = str(_strings.get(key, _fallback.get(key, "[%s]" % key)))
	for placeholder in replacements:
		text = text.replace("{%s}" % placeholder, str(replacements[placeholder]))
	return text

func unit_name(type_id: String) -> String:
	return t("unit_" + type_id)

func trait_name(trait_id: String) -> String:
	return t("trait_" + trait_id)

func _load_file(lang: String) -> Dictionary:
	var data: Variant = ConfigManager.load_json("res://data/strings_" + lang + ".json")
	return data as Dictionary if data is Dictionary else {}

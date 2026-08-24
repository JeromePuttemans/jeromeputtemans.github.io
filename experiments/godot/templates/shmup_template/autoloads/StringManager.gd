# =============================================================================
# StringManager.gd — Autoload #2
# Localisation with {placeholder} substitution. EN + FR included.
# =============================================================================
extends Node

signal language_changed(lang: String)

const DIR           = "res://data/"
const FALLBACK_LANG = "en"

var _lang:     String     = FALLBACK_LANG
var _strings:  Dictionary = {}
var _fallback: Dictionary = {}

func _ready() -> void:
	_fallback = _load("en")
	_strings  = _fallback
	var def = ConfigManager.get_string("default_language", FALLBACK_LANG)
	if def != FALLBACK_LANG:
		set_language(def)

func set_language(lang: String) -> void:
	if lang == _lang:
		return
	var d = _load(lang)
	if d.is_empty():
		push_warning("StringManager: '%s' not found" % lang); return
	_lang = lang; _strings = d
	emit_signal("language_changed", lang)

func get_language() -> String:
	return _lang

func t(key: String, rep: Dictionary = {}) -> String:
	var s: String = _strings.get(key, _fallback.get(key, "[%s]" % key))
	for k in rep:
		s = s.replace("{%s}" % k, str(rep[k]))
	return s

func _load(lang: String) -> Dictionary:
	var path = DIR + "strings_" + lang + ".json"
	if not FileAccess.file_exists(path):
		push_error("StringManager: not found — " + path); return {}
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return {}
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("StringManager: parse error in " + path); return {}
	return j.get_data()

# TranslationLoader.gd
# Autoload — loads translations from res://translations/translations.json
# and registers them with Godot's TranslationServer.
# Same validation pattern as SettingsManager: parse → type-check → register.

extends Node

const TRANSLATIONS_PATH := "res://translations/translations.json"

func _ready() -> void:
	var locales := _load_json()
	if locales.is_empty():
		push_warning("TranslationLoader: no translations loaded — UI will show raw keys.")
		return

	for locale_code in locales:
		var entries = locales[locale_code]
		if not entries is Dictionary:
			push_warning("TranslationLoader: locale '%s' is not a Dictionary, skipped." % locale_code)
			continue
		_register_locale(locale_code, entries)

	# Use system language, fall back to English
	TranslationServer.set_locale(OS.get_locale_language())

func _load_json() -> Dictionary:
	if not FileAccess.file_exists(TRANSLATIONS_PATH):
		push_error("TranslationLoader: '%s' not found." % TRANSLATIONS_PATH)
		return {}

	var file := FileAccess.open(TRANSLATIONS_PATH, FileAccess.READ)
	if file == null:
		push_error("TranslationLoader: cannot open '%s' (error %d)." % [
			TRANSLATIONS_PATH, FileAccess.get_open_error()])
		return {}

	var raw  := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err  := json.parse(raw)
	if err != OK:
		push_error("TranslationLoader: JSON parse error at line %d — %s" % [
			json.get_error_line(), json.get_error_message()])
		return {}

	var data = json.get_data()
	if not data is Dictionary:
		push_error("TranslationLoader: root element must be an Object (locale → keys).")
		return {}

	return data

func _register_locale(locale_code: String, entries: Dictionary) -> void:
	var t := Translation.new()
	t.locale = locale_code
	for key in entries:
		var value = entries[key]
		if value is String:
			t.add_message(key, value)
		else:
			push_warning("TranslationLoader: key '%s' in locale '%s' is not a String, skipped." % [
				key, locale_code])
	TranslationServer.add_translation(t)

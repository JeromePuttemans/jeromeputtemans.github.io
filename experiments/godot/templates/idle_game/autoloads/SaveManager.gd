# =============================================================================
# SaveManager.gd — Autoload (Singleton)
# =============================================================================
# JSON save of the irreducible state only:
#   resources (current, run total, lifetime), owned producers, purchased
#   upgrades, prisms, statistics, settings (language, buy mode), timestamp.
# Multipliers and production are derived, never saved: they are recomputed
# from the purchases on load.
#
# VERSION: saves carry "version". A file from the former template (version 1,
# gold economy) does not fit this economy and is ignored: the game starts
# fresh. The file name differs from the former one anyway.
#
# Location of user://: %APPDATA%/Godot/app_userdata/<project name>/ on
# Windows; in the browser, the local storage of the site.
# =============================================================================

extends Node

signal game_saved()

const SAVE_PATH: String = "user://idle_crystal_save.json"
const SAVE_VERSION: int = 2

func save_game() -> void:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"resources": ResourceManager.to_dict(),
		"producers": ProducerManager.to_dict(),
		"prestige": PrestigeManager.to_dict(),
		"stats": GameManager.stats.duplicate(),
		"settings": {"language": StringManager.get_language(), "buy_mode": GameManager.buy_mode}}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write %s (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data, "\t"))
	game_saved.emit()

## Restores the saved state. Returns the save timestamp, or -1 without a
## usable save (then nothing is touched).
func load_game() -> float:
	if not FileAccess.file_exists(SAVE_PATH):
		return -1.0
	var data: Variant = ConfigManager.load_json(SAVE_PATH)
	if not data is Dictionary:
		return -1.0
	var save: Dictionary = data as Dictionary
	if int(save.get("version", 1)) != SAVE_VERSION:
		return -1.0
	ResourceManager.from_dict(save.get("resources", {}) as Dictionary)
	PrestigeManager.from_dict(save.get("prestige", {}) as Dictionary)
	ProducerManager.from_dict(save.get("producers", {}) as Dictionary)
	var stats: Dictionary = save.get("stats", {}) as Dictionary
	for key in stats:
		GameManager.stats[key] = stats[key]
	var settings: Dictionary = save.get("settings", {}) as Dictionary
	StringManager.set_language(str(settings.get("language", StringManager.get_language())))
	GameManager.buy_mode = int(settings.get("buy_mode", 1))
	return float(save.get("timestamp", -1.0))

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

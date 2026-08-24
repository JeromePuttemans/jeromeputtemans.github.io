# =============================================================================
# SaveManager.gd — Autoload (Singleton)
# =============================================================================
# Handles serialization and deserialization of the full game state.
#
# FORMAT: JSON via FileAccess — human-readable, universally portable.
# Alternatives: ConfigFile (simpler, Godot-native), binary (faster, opaque).
#
# Save file location ("user://"):
#   Windows : %APPDATA%/Godot/app_userdata/<project_name>/
#   Linux   : ~/.local/share/godot/app_userdata/<project_name>/
#   macOS   : ~/Library/Application Support/Godot/app_userdata/<project_name>/
# =============================================================================

extends Node

const SAVE_PATH = "user://savegame.json"

signal game_saved()
signal game_loaded()

## Serializes the full game state and writes it to disk.
func save_game() -> void:
	var save_data = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"resources": ResourceManager.to_dict(),
		"producers": ProducerManager.to_dict()
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		emit_signal("game_saved")
		print("Game saved.")
	else:
		push_error("SaveManager: cannot write to %s (error: %d)" % [SAVE_PATH, FileAccess.get_open_error()])

## Loads the save file and restores game state.
## Returns the save timestamp on success, or -1.0 on failure.
## Returning the timestamp allows GameManager to compute offline progress.
func load_game() -> float:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found, starting fresh.")
		return -1.0

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("SaveManager: cannot read " + SAVE_PATH)
		return -1.0

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		# Do NOT touch any manager — avoid a partially corrupt state.
		push_error("SaveManager: invalid JSON at line %d — save ignored." % json.get_error_line())
		return -1.0

	var save_data = json.get_data()
	if not save_data is Dictionary:
		push_error("SaveManager: unexpected save format.")
		return -1.0

	ResourceManager.from_dict(save_data.get("resources", {}))
	ProducerManager.from_dict(save_data.get("producers", {}))

	emit_signal("game_loaded")
	print("Game loaded.")
	return save_data.get("timestamp", -1.0)

## Deletes the save file. Useful for a "New Game" button.
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("savegame.json")
			print("Save deleted.")
		else:
			push_error("SaveManager: cannot access user://")

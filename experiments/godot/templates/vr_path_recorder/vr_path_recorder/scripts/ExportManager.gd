class_name ExportManager
extends Node

# ─── Main entry point ─────────────────────────────────────────

## Saves both JSON and GLB for the current session.
## Returns the session name (e.g. "session_003") for UI display.
func save_session(
		path_left:   Array,
		path_right:  Array,
		tube_left:   TubeRenderer,
		tube_right:  TubeRenderer
) -> String:

	var num          := _next_session_number()
	var session_name := "session_%03d" % num

	_save_json(session_name, path_left, path_right)
	_save_glb(session_name, tube_left, tube_right)

	print("[ExportManager] Session saved: %s" % session_name)
	return session_name

# ─── JSON ─────────────────────────────────────────────────────

func _save_json(
		session_name: String,
		path_left:    Array,
		path_right:   Array
) -> void:

	var data := {
		"session":     session_name,
		"exported_at": Time.get_datetime_string_from_system(),
		"sample_rate": 30,
		"left":        path_left,
		"right":       path_right
	}

	var path := "user://%s.json" % session_name
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[ExportManager] Cannot write JSON: %s" % path)
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[ExportManager] JSON → %s" % path)

# ─── GLB ──────────────────────────────────────────────────────

func _save_glb(
		session_name: String,
		tube_left:    TubeRenderer,
		tube_right:   TubeRenderer
) -> void:

	# Build a temporary scene with copies of all mesh children
	var root      := Node3D.new()
	root.name      = session_name

	_copy_meshes_into(root, tube_left,  "left")
	_copy_meshes_into(root, tube_right, "right")

	# Export via GLTFDocument (works at runtime on Android)
	var doc   := GLTFDocument.new()
	var state := GLTFState.new()

	var err := doc.append_from_scene(root, state)
	if err != OK:
		push_error("[ExportManager] GLTFDocument.append_from_scene error: %d" % err)
		root.queue_free()
		return

	var buffer := doc.generate_buffer(state)
	var path   := "user://%s.glb" % session_name
	var file   := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		push_error("[ExportManager] Cannot write GLB: %s" % path)
		root.queue_free()
		return

	file.store_buffer(buffer)
	file.close()
	print("[ExportManager] GLB  → %s" % path)

	root.queue_free()

# ─── Helpers ──────────────────────────────────────────────────

## Copies all non-null MeshInstance3D children from a TubeRenderer
## into the destination node, prefixing names with `side`.
func _copy_meshes_into(dest: Node3D, tube: TubeRenderer, side: String) -> void:
	for child in tube.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var copy        := child.duplicate() as MeshInstance3D
			copy.name        = "%s_%s" % [side, child.name]
			dest.add_child(copy)
			copy.owner       = dest

## Returns the next unused session index (1-based).
func _next_session_number() -> int:
	var i := 1
	while FileAccess.file_exists("user://session_%03d.json" % i):
		i += 1
	return i

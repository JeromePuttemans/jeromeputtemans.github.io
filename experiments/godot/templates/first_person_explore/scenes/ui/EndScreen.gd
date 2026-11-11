# =============================================================================
# EndScreen.gd — Results after the sunset
# =============================================================================
# Fades in over the starry sky: title, a line of epilogue, then the time,
# the shards and the falls, one after the other, and "New record" when the
# run beats the best one. A click goes back to the title screen.
# =============================================================================

class_name EndScreen
extends Control

signal closed()

var _lines: Array[Label] = []
var _time: float = 0.0
var _hint: Label = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_results(result: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_lines.clear()
	add_child(UiTheme.veil(0.55))
	var centre := UiTheme.center_box()
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(column)
	var texts: Array = [
		[StringManager.t("end_title"), 54, UiTheme.TEXT],
		[StringManager.t("end_text"), 21, UiTheme.MUTED],
		["", 10, UiTheme.TEXT],
		[StringManager.t("end_time", {time = GameState.format_time(float(result["time"]))}), 24, UiTheme.TEXT],
		[StringManager.t("end_shards", {n = int(result["shards"]), total = int(result["total"])}), 24, UiTheme.GOLD],
		[StringManager.t("end_falls", {n = int(result["falls"])}), 24, UiTheme.TEXT],
	]
	if bool(result.get("record", false)):
		texts.append([StringManager.t("end_record"), 26, UiTheme.GOLD])
	for t in texts:
		var l := UiTheme.label(str(t[0]), int(t[1]), t[2] as Color, 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		column.add_child(l)
		_lines.append(l)
	_hint = UiTheme.label(StringManager.t("end_hint"), 18, UiTheme.MUTED, 5)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate.a = 0.0
	column.add_child(_hint)
	_time = 0.0
	visible = true

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for i in _lines.size():
		_lines[i].modulate.a = clampf((_time - 0.4 - i * 0.45) * 2.0, 0.0, 1.0)
	if _hint != null:
		_hint.modulate.a = clampf(_time - 0.6 - _lines.size() * 0.45, 0.0, 1.0) * (0.65 + 0.35 * sin(_time * 3.0))

func _gui_input(event: InputEvent) -> void:
	if _time > 1.5 and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		Sfx.play("ui")
		closed.emit()

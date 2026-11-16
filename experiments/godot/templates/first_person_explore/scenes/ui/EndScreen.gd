# =============================================================================
# EndScreen.gd: Results after the sunset
# =============================================================================
# A sheet fades in over the starry sky: title, a line of epilogue, the rank
# in a large letter, then the table of the run (time, shards, falls,
# dashes, launches) one row after the other, and "New record" when the run
# beats the best one. A click goes back to the title screen.
# RANK: from the time compared with par_time (config.json): S under par,
# A under 1.6 x par, B under 2.5 x par, C beyond; finding every shard
# raises the rank by one step.
# =============================================================================

class_name EndScreen
extends Control

signal closed()

var _items: Array[Control] = []
var _time: float = 0.0
var _hint: Label = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

static func rank_for(time: float, shards: int, total: int) -> String:
	var par: float = ConfigManager.get_float("par_time", 300.0)
	var ranks: Array[String] = ["S", "A", "B", "C"]
	var index: int = 3
	if time <= par:
		index = 0
	elif time <= par * 1.6:
		index = 1
	elif time <= par * 2.5:
		index = 2
	if shards >= total and index > 0:
		index -= 1
	return ranks[index]

func show_results(result: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_items.clear()
	add_child(UiTheme.veil(0.25))
	var centre := UiTheme.center_box()
	add_child(centre)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var title := UiTheme.label(StringManager.t("end_title"), 34, UiTheme.INK, 0, 2)
	column.add_child(title)
	_items.append(title)
	var line := UiTheme.rule(60.0, UiTheme.ACCENT, 2.0)
	column.add_child(line)
	_items.append(line)
	var text := UiTheme.label(StringManager.t("end_text"), 16, UiTheme.MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(520.0, 0.0)
	column.add_child(text)
	_items.append(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 34)
	column.add_child(row)
	_items.append(row)
	var rank_box := VBoxContainer.new()
	rank_box.add_theme_constant_override("separation", 0)
	row.add_child(rank_box)
	rank_box.add_child(UiTheme.label(StringManager.t("end_rank"), 13, UiTheme.MUTED, 0, 4))
	var rank := UiTheme.label(rank_for(float(result["time"]), int(result["shards"]), int(result["total"])), 96, UiTheme.ACCENT, 0, 0)
	rank_box.add_child(rank)
	var table := GridContainer.new()
	table.columns = 2
	table.add_theme_constant_override("h_separation", 30)
	table.add_theme_constant_override("v_separation", 6)
	table.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(table)
	var rows: Array = [
		[StringManager.t("end_time"), GameState.format_precise(float(result["time"]))],
		[StringManager.t("end_shards"), "%d / %d" % [int(result["shards"]), int(result["total"])]],
		[StringManager.t("end_falls"), str(int(result["falls"]))],
		[StringManager.t("end_dashes"), str(int(result["dashes"]))],
		[StringManager.t("end_launches"), str(int(result["launches"]))],
	]
	for r in rows:
		table.add_child(UiTheme.label(str(r[0]).to_upper(), 13, UiTheme.MUTED, 0, 3))
		table.add_child(UiTheme.label(str(r[1]), 20, UiTheme.INK, 0, 1))
	if bool(result.get("record", false)):
		var record := UiTheme.label(StringManager.t("end_record").to_upper(), 15, UiTheme.ACCENT, 0, 4)
		column.add_child(record)
		_items.append(record)
	_hint = UiTheme.label(StringManager.t("end_hint"), 14, UiTheme.MUTED, 0, 1)
	column.add_child(_hint)
	for item in _items:
		item.modulate.a = 0.0
	_hint.modulate.a = 0.0
	_time = 0.0
	visible = true

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for i in _items.size():
		_items[i].modulate.a = clampf((_time - 0.3 - i * 0.35) * 2.0, 0.0, 1.0)
	if _hint != null:
		_hint.modulate.a = clampf(_time - 0.6 - _items.size() * 0.35, 0.0, 1.0) * (0.6 + 0.4 * sin(_time * 3.0))

func _gui_input(event: InputEvent) -> void:
	if _time > 1.5 and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		Sfx.play("ui")
		closed.emit()

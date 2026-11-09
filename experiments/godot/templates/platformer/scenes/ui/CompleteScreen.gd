# =============================================================================
# CompleteScreen.gd — Results of a finished level
# =============================================================================
# Time (with the previous record or a "new record" badge), fireflies,
# golden acorns of this run, falls. The rows appear one after the other.
# =============================================================================

class_name CompleteScreen
extends Control

signal next_requested()
signal replay_requested()
signal menu_requested()

var _column: VBoxContainer
var _rows: VBoxContainer
var _title: Label
var _sub: Label
var _next: Button
var _replay: Button
var _menu: Button
var _result: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.veil(0.5))
	var center := UiTheme.center_box()
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460.0, 0.0)
	center.add_child(panel)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 12)
	panel.add_child(_column)
	_title = UiTheme.label("", 38, UiTheme.GOLD, 8)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_title)
	_sub = UiTheme.label("", 18, UiTheme.MUTED)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_sub)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	_column.add_child(_rows)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	var holder := CenterContainer.new()
	holder.add_child(buttons)
	_column.add_child(holder)
	_next = UiTheme.button("", func() -> void: next_requested.emit())
	buttons.add_child(_next)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	buttons.add_child(row)
	_replay = UiTheme.button("", func() -> void: replay_requested.emit(), 135.0)
	row.add_child(_replay)
	_menu = UiTheme.button("", func() -> void: menu_requested.emit(), 135.0)
	row.add_child(_menu)
	StringManager.language_changed.connect(func(_l: String) -> void:
		if visible:
			_fill(false))

func show_result(result: Dictionary) -> void:
	_result = result
	_fill(true)
	if bool(result.get("new_record", false)):
		Sfx.play("record")
	# A jump still held when the level ends must not skip the results
	for b in [_next, _replay, _menu]:
		b.disabled = true
	await get_tree().create_timer(0.7).timeout
	for b in [_next, _replay, _menu]:
		b.disabled = false
	_next.grab_focus()

func _fill(animate: bool) -> void:
	var data: LevelData = GameState.levels[int(_result["index"])]
	_title.text = StringManager.t("complete_title")
	_sub.text = StringManager.t("hud_level", {n = int(_result["index"]) + 1, name = StringManager.t(data.name_key)})
	_next.text = StringManager.t("complete_final") if GameState.is_last_level() else StringManager.t("complete_next")
	_replay.text = StringManager.t("complete_replay")
	_menu.text = StringManager.t("complete_menu")
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var time_text: String = GameState.format_time(float(_result["time"]))
	var note: String = ""
	var note_color: Color = UiTheme.MUTED
	if bool(_result["new_record"]):
		note = StringManager.t("new_record")
		note_color = UiTheme.GOLD
	elif float(_result["previous_best"]) >= 0.0:
		note = StringManager.t("record", {time = GameState.format_time(float(_result["previous_best"]))})
	_add_row(Icon.make("clock", 26.0), StringManager.t("stat_time"), time_text, note, note_color)
	var flies: int = int(_result["fireflies"])
	var total: int = int(_result["firefly_total"])
	_add_row(Icon.make("firefly", 26.0), StringManager.t("stat_fireflies"), "%d / %d" % [flies, total], StringManager.t("all_found") if flies == total else "", UiTheme.GOLD)
	var acorn_box := HBoxContainer.new()
	acorn_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for a in int(_result["acorn_total"]):
		acorn_box.add_child(Icon.make("acorn", 26.0, (_result["acorns"] as Array).has(a)))
	_add_row(Icon.make("acorn", 26.0), StringManager.t("stat_acorns"), "", "", UiTheme.MUTED, acorn_box)
	var deaths: int = int(_result["deaths"])
	_add_row(Icon.make("fall", 26.0), StringManager.t("stat_deaths"), str(deaths), StringManager.t("no_fall") if deaths == 0 else "", UiTheme.LEAF)
	if animate:
		var i: int = 0
		for row in _rows.get_children():
			var r: Control = row as Control
			r.modulate.a = 0.0
			var tween := create_tween()
			tween.tween_interval(0.15 + i * 0.18)
			tween.tween_property(r, "modulate:a", 1.0, 0.25)
			i += 1

func _add_row(icon: Icon, title: String, value: String, note: String, note_color: Color, extra: Control = null) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var name_label := UiTheme.label(title, 19, UiTheme.MUTED)
	name_label.custom_minimum_size = Vector2(150.0, 0.0)
	row.add_child(name_label)
	if extra != null:
		row.add_child(extra)
	else:
		row.add_child(UiTheme.label(value, 22, UiTheme.TEXT))
	if not note.is_empty():
		var n := UiTheme.label(note, 16, note_color)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(n)
	_rows.add_child(row)

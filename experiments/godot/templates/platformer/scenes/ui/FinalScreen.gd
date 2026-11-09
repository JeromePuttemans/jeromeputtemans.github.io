# =============================================================================
# FinalScreen.gd — End of the journey: the records of every level
# =============================================================================

class_name FinalScreen
extends Control

signal menu_requested()

var _title: Label
var _text: Label
var _grid: GridContainer
var _menu: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.veil(0.55))
	var center := UiTheme.center_box()
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	_title = UiTheme.label("", 44, UiTheme.GOLD, 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_text = UiTheme.label("", 18, UiTheme.TEXT)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(560.0, 0.0)
	column.add_child(_text)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 28)
	_grid.add_theme_constant_override("v_separation", 8)
	var holder := CenterContainer.new()
	holder.add_child(_grid)
	column.add_child(holder)
	var button_holder := CenterContainer.new()
	_menu = UiTheme.button("", func() -> void: menu_requested.emit())
	button_holder.add_child(_menu)
	column.add_child(button_holder)
	StringManager.language_changed.connect(func(_l: String) -> void:
		if visible:
			refresh())

func refresh() -> void:
	_title.text = StringManager.t("final_title")
	_text.text = StringManager.t("final_text")
	_menu.text = StringManager.t("complete_menu")
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for key in ["final_level", "stat_time", "stat_fireflies", "stat_acorns"]:
		_grid.add_child(UiTheme.label(StringManager.t(key), 16, UiTheme.MUTED))
	var total_time: float = 0.0
	var flies: int = 0
	var flies_total: int = 0
	var acorns: int = 0
	var acorns_total: int = 0
	for i in GameState.levels.size():
		var data: LevelData = GameState.levels[i]
		var rec: Dictionary = SaveManager.record(data.id)
		var best: float = float(rec.get("best_time", 0.0))
		total_time += best
		flies += int(rec.get("fireflies", 0))
		flies_total += data.firefly_total
		acorns += SaveManager.acorns_found(data.id)
		acorns_total += data.acorn_total
		_grid.add_child(UiTheme.label("%d. %s" % [i + 1, StringManager.t(data.name_key)], 18, UiTheme.TEXT))
		_grid.add_child(UiTheme.label(GameState.format_time(best) if rec.has("best_time") else "-", 18, UiTheme.TEXT))
		_grid.add_child(UiTheme.label("%d / %d" % [int(rec.get("fireflies", 0)), data.firefly_total], 18, UiTheme.TEXT))
		_grid.add_child(UiTheme.label("%d / %d" % [SaveManager.acorns_found(data.id), data.acorn_total], 18, UiTheme.TEXT))
	_grid.add_child(UiTheme.label(StringManager.t("final_total"), 19, UiTheme.GOLD))
	_grid.add_child(UiTheme.label(GameState.format_time(total_time), 19, UiTheme.GOLD))
	_grid.add_child(UiTheme.label("%d / %d" % [flies, flies_total], 19, UiTheme.GOLD))
	_grid.add_child(UiTheme.label("%d / %d" % [acorns, acorns_total], 19, UiTheme.GOLD))

func focus_default() -> void:
	refresh()
	_menu.grab_focus()

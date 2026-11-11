# =============================================================================
# Menus.gd — Pause menu, move list and results screen
# =============================================================================

class_name Menus
extends RefCounted

## Pause: resume, move list, restart, character select, main menu.
class Pause extends Control:
	signal chosen(action: String)
	var _buttons: Dictionary = {}
	var _title: Label
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(UiTheme.veil(0.6))
		var center := UiTheme.center_box()
		add_child(center)
		var panel := PanelContainer.new()
		center.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		panel.add_child(column)
		_title = UiTheme.label("", 38, UiTheme.BRASS, 6)
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(_title)
		for action in ["resume", "moves", "restart", "select", "menu"]:
			var b := UiTheme.button("", func() -> void: chosen.emit(action))
			column.add_child(b)
			_buttons[action] = b
		StringManager.language_changed.connect(func(_l: String) -> void: refresh())
		refresh()
	func refresh() -> void:
		_title.text = StringManager.t("pause_title")
		for action in _buttons:
			(_buttons[action] as Button).text = StringManager.t("pause_" + str(action))
	func focus_default() -> void:
		refresh()
		(_buttons["resume"] as Button).grab_focus()

## Move list of one fighter: specials, super, throw, dash, combos, guard.
class MoveList extends Control:
	signal closed()
	var fighter_id: String = "brio"
	var _title: Label
	var _grid: GridContainer
	var _back: Button
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(UiTheme.veil(0.75))
		var center := UiTheme.center_box()
		add_child(center)
		var panel := PanelContainer.new()
		center.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 12)
		panel.add_child(column)
		_title = UiTheme.label("", 30, UiTheme.BRASS, 5)
		column.add_child(_title)
		_grid = GridContainer.new()
		_grid.columns = 3
		_grid.add_theme_constant_override("h_separation", 22)
		_grid.add_theme_constant_override("v_separation", 8)
		column.add_child(_grid)
		var holder := CenterContainer.new()
		_back = UiTheme.button("", func() -> void: closed.emit(), 220.0)
		holder.add_child(_back)
		column.add_child(holder)
	func open(id: String) -> void:
		fighter_id = id
		_title.text = StringManager.t("moves_title", {name = GameState.fighter_name(id)})
		_back.text = StringManager.t("back")
		for child in _grid.get_children():
			_grid.remove_child(child)
			child.queue_free()
		for key in ["n", "f", "d", "b", "super"]:
			_row(StringManager.t("cmd_" + key), StringManager.t("move_%s_%s" % [id, key]), StringManager.t("desc_%s_%s" % [id, key]))
		_row(StringManager.t("cmd_throw"), "", StringManager.t("desc_throw"))
		_row(StringManager.t("cmd_combo"), "", StringManager.t("desc_combo"))
		_row(StringManager.t("cmd_dash"), "", StringManager.t("desc_dash"))
		_row(StringManager.t("cmd_guard"), "", StringManager.t("desc_guard"))
		_back.grab_focus()
	func _row(command: String, move_name: String, description: String) -> void:
		_grid.add_child(UiTheme.label(command, 17, UiTheme.BRASS))
		_grid.add_child(UiTheme.label(move_name, 17, UiTheme.TEXT))
		var d := UiTheme.label(description, 15, UiTheme.MUTED)
		_grid.add_child(d)

## End of a match: winner, arcade progress, next fight or rematch.
class Results extends Control:
	signal chosen(action: String)
	var _title: Label
	var _sub: Label
	var _portrait: UiTheme.Portrait
	var _buttons: VBoxContainer
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(UiTheme.veil(0.7))
		var center := UiTheme.center_box()
		add_child(center)
		var frame := PanelContainer.new()
		center.add_child(frame)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 30)
		frame.add_child(row)
		_portrait = UiTheme.Portrait.new()
		_portrait.custom_minimum_size = Vector2(260.0, 380.0)
		_portrait.pose_name = "victory"
		_portrait.size_factor = 1.4
		row.add_child(_portrait)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 12)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(column)
		_title = UiTheme.label("", 52, UiTheme.BRASS, 8)
		column.add_child(_title)
		_sub = UiTheme.label("", 20, UiTheme.TEXT, 4)
		_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sub.custom_minimum_size = Vector2(420.0, 0.0)
		column.add_child(_sub)
		_buttons = VBoxContainer.new()
		_buttons.add_theme_constant_override("separation", 10)
		column.add_child(_buttons)
	func show_result(winner: int) -> void:
		for child in _buttons.get_children():
			_buttons.remove_child(child)
			child.queue_free()
		var winner_id: String = GameState.p1 if winner == 0 else GameState.p2
		_portrait.fighter_id = winner_id
		var actions: Array[String] = []
		match GameState.mode:
			"arcade":
				var total: int = GameState.ladder.size()
				if winner == 0:
					if GameState.ladder_index >= total - 1:
						_title.text = StringManager.t("arcade_clear")
						_sub.text = StringManager.t("arcade_clear_text", {name = GameState.fighter_name(GameState.p1), d = StringManager.t("diff_%d" % GameState.difficulty)})
						SaveManager.record_clear(GameState.p1, GameState.difficulty)
						actions = ["select", "menu"]
					else:
						_title.text = StringManager.t("result_win")
						_sub.text = StringManager.t("ladder", {n = GameState.ladder_index + 1, total = total})
						actions = ["next", "select", "menu"]
				else:
					_title.text = StringManager.t("result_lose")
					_sub.text = StringManager.t("ladder", {n = GameState.ladder_index + 1, total = total})
					actions = ["retry", "select", "menu"]
			_:
				_title.text = StringManager.t("result_win")
				_sub.text = StringManager.t("result_versus", {name = GameState.fighter_name(winner_id)})
				actions = ["rematch", "select", "menu"]
		_title.add_theme_color_override("font_color", UiTheme.RED if (GameState.mode == "arcade" and winner != 0) else UiTheme.BRASS)
		var labels: Dictionary = {next = "next_fight", retry = "retry", rematch = "rematch", select = "to_select", menu = "to_menu"}
		var first: Button = null
		for action in actions:
			var b := UiTheme.button(StringManager.t(str(labels[action])), func() -> void: chosen.emit(action))
			_buttons.add_child(b)
			if first == null:
				first = b
		for b in _buttons.get_children():
			(b as Button).disabled = true
		await get_tree().create_timer(0.8).timeout
		for b in _buttons.get_children():
			(b as Button).disabled = false
		if first != null:
			first.grab_focus()

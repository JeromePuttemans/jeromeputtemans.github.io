# =============================================================================
# ResultScreen.gd — End of the run: bonuses, total, rank in the table
# =============================================================================
# When the stage is cleared, three bonuses are added: lives left x
# bonus_life, bombs left x bonus_bomb, and bonus_no_miss without any life
# lost. The rows appear one by one and the total counts up, then the run is
# submitted to the best scores of its difficulty.
# =============================================================================

class_name ResultScreen
extends Control

signal retry_requested()
signal menu_requested()

var _title: Label
var _rows: VBoxContainer
var _total: Label
var _total_name: Label
var _rank: Label
var _stats: Label
var _retry: Button
var _menu: Button
var _tally_from: float = 0.0
var _tally_to: float = 0.0
var _tally_time: float = -1.0
var _tick: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.veil(0.55))
	var center := UiTheme.center_box()
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500.0, 0.0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_title = UiTheme.label("", 36, UiTheme.GOLD, 6)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	column.add_child(_rows)
	var total_row := HBoxContainer.new()
	column.add_child(total_row)
	_total_name = UiTheme.label("", 24, UiTheme.TEXT)
	_total_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(_total_name)
	_total = UiTheme.label("", 30, UiTheme.CYAN, 5)
	total_row.add_child(_total)
	_rank = UiTheme.label("", 18, UiTheme.GOLD)
	_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_rank)
	_stats = UiTheme.label("", 15, UiTheme.MUTED)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_stats)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	_retry = UiTheme.button("", func() -> void: retry_requested.emit(), 200.0)
	buttons.add_child(_retry)
	_menu = UiTheme.button("", func() -> void: menu_requested.emit(), 200.0)
	buttons.add_child(_menu)

func show_result(cleared: bool) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_title.text = StringManager.t("result_clear" if cleared else "result_over")
	_title.add_theme_color_override("font_color", UiTheme.GOLD if cleared else UiTheme.RED)
	var base: int = GameState.score
	_add_row(StringManager.t("row_score"), base)
	var bonus: int = 0
	if cleared:
		var lives_left: int = maxi(GameState.lives - 1, 0)
		var lives_bonus: int = lives_left * ConfigManager.get_int("bonus_life", 50000)
		var bombs_bonus: int = GameState.bombs * ConfigManager.get_int("bonus_bomb", 20000)
		_add_row(StringManager.t("row_lives", {n = lives_left}), lives_bonus)
		_add_row(StringManager.t("row_bombs", {n = GameState.bombs}), bombs_bonus)
		bonus = lives_bonus + bombs_bonus
		if GameState.misses == 0:
			var no_miss: int = ConfigManager.get_int("bonus_no_miss", 100000)
			_add_row(StringManager.t("row_no_miss"), no_miss)
			bonus += no_miss
	if bonus > 0:
		GameState.add_points(bonus, false)
	_total_name.text = StringManager.t("row_total")
	_tally_from = base
	_tally_to = GameState.score
	_tally_time = 0.0
	_total.text = SidePanels.group_digits(base)
	var rank: int = SaveManager.submit(GameState.difficulty, {score = GameState.score, chain = snappedf(GameState.best_chain, 0.1), cleared = cleared, graze = GameState.graze})
	if rank == 0:
		_rank.text = StringManager.t("rank_new")
		Sfx.play("clear")
	elif rank > 0:
		_rank.text = StringManager.t("rank_n", {n = rank + 1})
	else:
		_rank.text = StringManager.t("rank_none")
	_stats.text = "%s     %s     %s" % [StringManager.t("stat_chain", {v = "%.1f" % GameState.best_chain}), StringManager.t("stat_graze", {n = GameState.graze}), StringManager.t("stat_kills", {n = GameState.kills})]
	_retry.text = StringManager.t("retry")
	_menu.text = StringManager.t("menu")
	var i: int = 0
	for row in _rows.get_children():
		(row as Control).modulate.a = 0.0
		create_tween().tween_property(row, "modulate:a", 1.0, 0.25).set_delay(0.2 + i * 0.25)
		i += 1
	_retry.disabled = true
	_menu.disabled = true
	await get_tree().create_timer(0.9).timeout
	_retry.disabled = false
	_menu.disabled = false
	_retry.grab_focus()

func _add_row(text: String, value: int) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := UiTheme.label(text, 19, UiTheme.MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiTheme.label(SidePanels.group_digits(value), 21, UiTheme.TEXT))
	_rows.add_child(row)

func _process(delta: float) -> void:
	if _tally_time < 0.0 or not visible:
		return
	_tally_time += delta
	var t: float = clampf((_tally_time - 0.9) / 1.0, 0.0, 1.0)
	var value: int = int(lerpf(_tally_from, _tally_to, t))
	_total.text = SidePanels.group_digits(value)
	if t > 0.0 and t < 1.0:
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.06
			Sfx.play("tally")
	if t >= 1.0:
		_tally_time = -1.0

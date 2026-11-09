# =============================================================================
# EndScreen.gd — Victory or defeat, the run summary and a restart button
# =============================================================================

extends Control

signal restart_requested()

var _title: Label
var _stats: Label
var _button: Button

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_LIGHT, UiTheme.GOLD.darkened(0.3), 12, 28))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	_title = UiTheme.label("", 48, UiTheme.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_stats = UiTheme.label("", 17, UiTheme.TEXT)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_stats)
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size = Vector2(260.0, 48.0)
	_button.add_theme_font_size_override("font_size", 18)
	_button.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(_button)

func open(victory: bool) -> void:
	_title.text = StringManager.t("victory_title" if victory else "defeat_title")
	_title.add_theme_color_override("font_color", UiTheme.GOLD if victory else UiTheme.BAD)
	var stats: Dictionary = RoundManager.stats
	_stats.text = StringManager.t("end_stats", {round = RoundManager.round_number, total = ConfigManager.get_int("rounds_total", 15),
		wins = int(stats.get("wins", 0)), losses = int(stats.get("losses", 0)), merges = int(stats.get("merges", 0)),
		star = int(stats.get("best_star", 1)), hp = RoundManager.hp})
	_button.text = StringManager.t("restart_button")
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)

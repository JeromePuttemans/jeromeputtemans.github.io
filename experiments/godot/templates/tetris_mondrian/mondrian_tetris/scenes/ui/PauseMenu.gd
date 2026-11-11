# =============================================================================
# PauseMenu.gd — Pause: resume, restart, title screen
# =============================================================================

class_name PauseMenu
extends Control

signal resume_requested()
signal restart_requested()
signal title_requested()

var _title: Label = null
var _buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var veil := ColorRect.new()
	veil.color = Color(0.05, 0.05, 0.05, 0.6)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	var style := UiTheme.box(Pieces.PALETTE[Pieces.Col.WHITE])
	style.set_border_width_all(12)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 24
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_title = UiTheme.label("", 44)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	for cb in [func() -> void: resume_requested.emit(), func() -> void: restart_requested.emit(), func() -> void: title_requested.emit()]:
		var b := UiTheme.button("", cb)
		column.add_child(b)
		_buttons.append(b)

func open() -> void:
	_title.text = StringManager.t("pause_title")
	_buttons[0].text = StringManager.t("pause_resume")
	_buttons[1].text = StringManager.t("pause_restart")
	_buttons[2].text = StringManager.t("pause_title_screen")
	visible = true
	_buttons[0].grab_focus()

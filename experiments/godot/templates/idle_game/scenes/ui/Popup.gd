# =============================================================================
# Popup.gd — Modal window (welcome back, crystallize, reset)
# =============================================================================
# open(title, body, buttons) dims the screen, blocks the clicks below and
# shows a panel that pops in. Each button is {text, action: Callable,
# accent: bool}; any button closes the window before running its action.
# =============================================================================

extends Control

var _panel: PanelContainer
var _title: Label
var _body: Label
var _buttons: HBoxContainer

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.05, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_LIGHT, UiTheme.CRYSTAL.darkened(0.3), 14, 24))
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_panel.add_child(box)
	_title = UiTheme.label("", 26, UiTheme.CRYSTAL)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_body = UiTheme.label("", 16, UiTheme.TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(520.0, 0.0)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_body)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 14)
	box.add_child(_buttons)

func is_open() -> bool:
	return visible

func open(title: String, body: String, buttons: Array[Dictionary]) -> void:
	_title.text = title
	_body.text = body
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	for spec in buttons:
		_buttons.add_child(_make_button(spec))
	visible = true
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.85, 0.85)
	_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.25)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.15)

func close() -> void:
	visible = false

func _make_button(spec: Dictionary) -> Button:
	var button := Button.new()
	button.text = str(spec.get("text", ""))
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(170.0, 42.0)
	button.add_theme_font_size_override("font_size", 16)
	if bool(spec.get("accent", false)):
		button.add_theme_stylebox_override("normal", UiTheme.box(Color(0.12, 0.3, 0.38), UiTheme.CRYSTAL, 8, 10))
		button.add_theme_stylebox_override("hover", UiTheme.box(Color(0.15, 0.4, 0.5), UiTheme.CRYSTAL.lightened(0.3), 8, 10))
	var action: Callable = spec.get("action", Callable()) as Callable
	button.pressed.connect(func() -> void:
		close()
		Sfx.play("ui")
		if action.is_valid():
			action.call())
	return button

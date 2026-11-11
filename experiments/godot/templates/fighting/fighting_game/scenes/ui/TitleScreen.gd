# =============================================================================
# TitleScreen.gd — Logo, two automatons facing off, menu, controls
# =============================================================================

class_name TitleScreen
extends Control

signal mode_chosen(mode: String)

var _time: float = 0.0
var _arcade: Button
var _versus: Button
var _training: Button
var _sound: Button
var _lang: Button
var _sub: Label
var _controls: Label
var _font: Font = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	for side in [0, 1]:
		var p := UiTheme.Portrait.new()
		p.fighter_id = "brio" if side == 0 else "colosse"
		p.facing = 1 if side == 0 else -1
		p.size_factor = 1.7
		p.custom_minimum_size = Vector2(300.0, 420.0)
		p.size = Vector2(300.0, 420.0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if side == 0 else Control.PRESET_BOTTOM_RIGHT)
		p.position = Vector2(60.0 if side == 0 else -360.0, -460.0)
		add_child(p)
	var center := UiTheme.center_box()
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 170.0)
	column.add_child(spacer)
	_sub = UiTheme.label("", 20, UiTheme.BRASS, 5)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_sub)
	var holder := CenterContainer.new()
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	holder.add_child(buttons)
	column.add_child(holder)
	_arcade = UiTheme.button("", func() -> void: mode_chosen.emit("arcade"))
	buttons.add_child(_arcade)
	_versus = UiTheme.button("", func() -> void: mode_chosen.emit("versus"))
	buttons.add_child(_versus)
	_training = UiTheme.button("", func() -> void: mode_chosen.emit("training"))
	buttons.add_child(_training)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	buttons.add_child(row)
	_sound = UiTheme.button("", _on_sound, 145.0)
	row.add_child(_sound)
	_lang = UiTheme.button("", func() -> void: StringManager.cycle_language(), 145.0)
	row.add_child(_lang)
	_controls = UiTheme.label("", 14, UiTheme.MUTED, 4)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_controls)
	StringManager.language_changed.connect(func(_l: String) -> void: refresh())
	refresh()

func refresh() -> void:
	_sub.text = StringManager.t("subtitle")
	_arcade.text = StringManager.t("menu_arcade")
	_versus.text = StringManager.t("menu_versus")
	_training.text = StringManager.t("menu_training")
	_sound.text = StringManager.t("sound_off") if Sfx.muted else StringManager.t("sound_on")
	_lang.text = StringManager.t("language_button")
	_controls.text = StringManager.t("title_controls")

func focus_default() -> void:
	refresh()
	_arcade.grab_focus()

func _on_sound() -> void:
	Sfx.set_muted(not Sfx.muted)
	refresh()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var c0 := Color("1a120c")
	var c1 := Color("3a2416")
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]), PackedColorArray([c0, c0, c1, c1]))
	UiTheme.gear(self, Vector2(size.x * 0.5 - 330.0, 150.0), 120.0, 14, _time * 0.25, Color("4a3220"))
	UiTheme.gear(self, Vector2(size.x * 0.5 + 360.0, 120.0), 90.0, 11, -_time * 0.33, Color("4a3220"))
	UiTheme.gear(self, Vector2(size.x * 0.5 + 250.0, 250.0), 60.0, 8, _time * 0.5, Color("553a24"))
	UiTheme.gear(self, Vector2(size.x * 0.5 - 200.0, 270.0), 50.0, 8, -_time * 0.6, Color("553a24"))
	draw_rect(Rect2(0.0, size.y - 70.0, size.x, 70.0), Color("2a1a10"))
	draw_line(Vector2(0.0, size.y - 70.0), Vector2(size.x, size.y - 70.0), Color("6a4a2a"), 3.0)
	var title: String = StringManager.t("title")
	var fs: int = 110
	var w: float = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2((size.x - w) * 0.5, 175.0)
	draw_string_outline(_font, p + Vector2(0.0, 6.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 16, Color(0.0, 0.0, 0.0, 0.6))
	draw_string_outline(_font, p, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color("2a1608"))
	draw_string(_font, p, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.BRASS)
	draw_line(Vector2(p.x, p.y + 18.0), Vector2(p.x + w, p.y + 18.0), Color(UiTheme.BRASS, 0.6), 3.0)

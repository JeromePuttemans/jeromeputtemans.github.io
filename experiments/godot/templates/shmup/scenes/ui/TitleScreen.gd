# =============================================================================
# TitleScreen.gd — Title, difficulty choice, best scores and controls
# =============================================================================

class_name TitleScreen
extends Control

signal play_requested(difficulty: String)

## The title drawn with a pulsing glow and an underline.
class Logo extends Control:
	var text: String = ""
	var _time: float = 0.0
	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()
	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 96
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var p := Vector2((size.x - w) * 0.5, size.y * 0.75)
		Tex.put(self, Tex.glow(), Vector2(size.x * 0.5, size.y * 0.5), w * 0.65, Color(0.3, 0.6, 1.0, 0.2 + 0.08 * sin(_time * 2.0)))
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 14, Color(0.02, 0.05, 0.2, 0.9))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiTheme.CYAN)
		draw_line(Vector2(p.x, p.y + 14.0), Vector2(p.x + w, p.y + 14.0), Color(UiTheme.MAGENTA, 0.7), 2.0)

var _logo: Logo
var _subtitle: Label
var _normal: Button
var _hard: Button
var _sound: Button
var _lang: Button
var _controls: Label
var _scores_title: Label
var _scores: GridContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.veil(0.45))
	var center := UiTheme.center_box()
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	center.add_child(row)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	_logo = Logo.new()
	_logo.custom_minimum_size = Vector2(520.0, 130.0)
	column.add_child(_logo)
	_subtitle = UiTheme.label("", 17, UiTheme.TEXT, 5)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	var holder := CenterContainer.new()
	holder.add_child(buttons)
	column.add_child(holder)
	_normal = UiTheme.button("", func() -> void: play_requested.emit("normal"))
	buttons.add_child(_normal)
	_hard = UiTheme.button("", func() -> void: play_requested.emit("hard"))
	buttons.add_child(_hard)
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 10)
	buttons.add_child(options)
	_sound = UiTheme.button("", _on_sound, 145.0)
	options.add_child(_sound)
	_lang = UiTheme.button("", func() -> void: StringManager.cycle_language(), 145.0)
	options.add_child(_lang)
	_controls = UiTheme.label("", 15, UiTheme.MUTED, 4)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_controls)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(panel)
	var score_box := VBoxContainer.new()
	score_box.add_theme_constant_override("separation", 10)
	panel.add_child(score_box)
	_scores_title = UiTheme.label("", 20, UiTheme.GOLD)
	score_box.add_child(_scores_title)
	_scores = GridContainer.new()
	_scores.columns = 2
	_scores.add_theme_constant_override("h_separation", 20)
	_scores.add_theme_constant_override("v_separation", 4)
	score_box.add_child(_scores)
	StringManager.language_changed.connect(func(_l: String) -> void: refresh())
	refresh()

func refresh() -> void:
	_logo.text = StringManager.t("title")
	_subtitle.text = StringManager.t("subtitle")
	_normal.text = StringManager.t("menu_normal")
	_hard.text = StringManager.t("menu_hard")
	_sound.text = StringManager.t("sound_off") if Sfx.muted else StringManager.t("sound_on")
	_lang.text = StringManager.t("language_button")
	_controls.text = StringManager.t("controls")
	_scores_title.text = StringManager.t("scores_title")
	for child in _scores.get_children():
		_scores.remove_child(child)
		child.queue_free()
	for diff in ["normal", "hard"]:
		_scores.add_child(UiTheme.label(StringManager.t("difficulty_" + diff), 15, UiTheme.RED if diff == "hard" else UiTheme.CYAN))
		_scores.add_child(Control.new())
		var list: Array = SaveManager.scores(diff)
		if list.is_empty():
			_scores.add_child(UiTheme.label(StringManager.t("scores_empty"), 15, UiTheme.MUTED))
			_scores.add_child(Control.new())
		for i in list.size():
			var entry: Dictionary = list[i] as Dictionary
			_scores.add_child(UiTheme.label("%d.  %s" % [i + 1, SidePanels.group_digits(int(entry.get("score", 0)))], 16, UiTheme.TEXT))
			var mark: String = "x%.1f" % float(entry.get("chain", 1.0))
			_scores.add_child(UiTheme.label(mark + ("  *" if bool(entry.get("cleared", false)) else ""), 14, UiTheme.GOLD if bool(entry.get("cleared", false)) else UiTheme.MUTED))

func focus_default() -> void:
	refresh()
	_normal.grab_focus()

func _on_sound() -> void:
	Sfx.set_muted(not Sfx.muted)
	refresh()

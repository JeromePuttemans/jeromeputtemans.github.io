# =============================================================================
# TitleScreen.gd — Title, Brindille idling, main menu and controls
# =============================================================================
# "Play" starts the first level on a fresh save, "Continue" the furthest
# unlocked level otherwise.
# =============================================================================

class_name TitleScreen
extends Control

signal play_requested(index: int)
signal levels_requested()

## Brindille, three times bigger, idling and hopping now and then.
class Mascot extends Control:
	var _time: float = 0.0
	var _hop: float = -1.0
	var _blink: float = 0.0
	var _next_blink: float = 1.5
	func _process(delta: float) -> void:
		_time += delta
		_next_blink -= delta
		if _next_blink <= 0.0:
			_next_blink = randf_range(2.0, 4.0)
			_blink = 1.0
		_blink = maxf(_blink - delta * 7.0, 0.0)
		if _hop < 0.0 and fmod(_time, 3.2) < delta:
			_hop = 0.0
		if _hop >= 0.0:
			_hop += delta
			if _hop > 0.55:
				_hop = -1.0
		queue_redraw()
	func _draw() -> void:
		var pose: Dictionary = PlayerArt.default_pose()
		var lift: float = 0.0
		var squash := Vector2(1.0 + 0.03 * sin(_time * 3.0), 1.0 - 0.03 * sin(_time * 3.0))
		if _hop >= 0.0:
			var t: float = _hop / 0.55
			lift = sin(t * PI) * 34.0
			squash = Vector2(0.88, 1.14) if t < 0.5 else Vector2(1.0, 1.0)
			pose["air"] = true
			pose["angle"] = sin(t * TAU) * 0.15
		pose["scale"] = squash
		pose["blink"] = _blink
		pose["leaf"] = sin(_time * 1.7) * 0.25
		pose["look"] = Vector2(sin(_time * 0.6) * 1.2, 0.3)
		var feet := Vector2(size.x * 0.5, size.y - 6.0)
		PlayerArt.ellipse(self, feet + Vector2(0.0, 2.0), 44.0 - lift * 0.4, 7.0, Color(0.0, 0.0, 0.0, 0.25))
		PlayerArt.draw(self, feet - Vector2(0.0, lift), pose, 3.0)

var _title: Label
var _subtitle: Label
var _play: Button
var _levels: Button
var _sound: Button
var _lang: Button
var _footer: Label
var _version: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := UiTheme.center_box()
	add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	_title = UiTheme.label("", 92, Color("f6f1d8"), 16)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_subtitle = UiTheme.label("", 20, UiTheme.TEXT, 6)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)
	var mascot := Mascot.new()
	mascot.custom_minimum_size = Vector2(200.0, 150.0)
	mascot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(mascot)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var holder := CenterContainer.new()
	holder.add_child(buttons)
	column.add_child(holder)
	_play = UiTheme.button("", _on_play)
	buttons.add_child(_play)
	_levels = UiTheme.button("", func() -> void: levels_requested.emit())
	buttons.add_child(_levels)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	buttons.add_child(row)
	_sound = UiTheme.button("", _on_sound, 135.0)
	row.add_child(_sound)
	_lang = UiTheme.button("", func() -> void: StringManager.cycle_language(), 135.0)
	row.add_child(_lang)
	_footer = UiTheme.label("", 15, UiTheme.TEXT, 5)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_footer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_footer.position.y -= 18.0
	add_child(_footer)
	StringManager.language_changed.connect(func(_l: String) -> void: refresh())
	refresh()

func refresh() -> void:
	_title.text = StringManager.t("title")
	_subtitle.text = StringManager.t("subtitle")
	var furthest: int = SaveManager.unlocked()
	_play.text = StringManager.t("menu_play") if furthest <= 1 and SaveManager.record(1).is_empty() else StringManager.t("menu_continue", {n = furthest})
	_levels.text = StringManager.t("menu_levels")
	_sound.text = StringManager.t("sound_off") if Sfx.muted else StringManager.t("sound_on")
	_lang.text = StringManager.t("language_button")
	_footer.text = StringManager.t("controls")

func focus_default() -> void:
	refresh()
	_play.grab_focus()

func _on_play() -> void:
	play_requested.emit(clampi(SaveManager.unlocked() - 1, 0, GameState.levels.size() - 1))

func _on_sound() -> void:
	Sfx.set_muted(not Sfx.muted)
	refresh()

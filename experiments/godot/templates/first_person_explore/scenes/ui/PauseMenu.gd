# =============================================================================
# PauseMenu.gd — Pause with the settings
# =============================================================================
# Opens with Esc (the browser also frees the mouse with Esc: losing the
# mouse lock while playing opens this menu too). Resume locks the mouse
# again, which the browser only allows in answer to a click or a key.
# Settings (kept in the save): mouse sensitivity in steps of 0.02, inverted
# vertical axis, sound, language.
# =============================================================================

class_name PauseMenu
extends Control

signal resume_requested()
signal title_requested()
signal settings_changed()

var _stats: Label = null
var _title: Label = null
var _resume: Button = null
var _sens: Button = null
var _invert: Button = null
var _sound: Button = null
var _language: Button = null
var _quit: Button = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UiTheme.veil(0.55))
	var centre := UiTheme.center_box()
	add_child(centre)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	_title = UiTheme.label("", 40, UiTheme.TEXT, 6)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_stats = UiTheme.label("", 17, UiTheme.MUTED)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_stats)
	_resume = UiTheme.button("", func() -> void: resume_requested.emit())
	column.add_child(_resume)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var minus := UiTheme.button("-", func() -> void: _change_sensitivity(-0.02), 44.0)
	_sens = UiTheme.button("", func() -> void: pass, 220.0)
	var plus := UiTheme.button("+", func() -> void: _change_sensitivity(0.02), 44.0)
	row.add_child(minus)
	row.add_child(_sens)
	row.add_child(plus)
	column.add_child(row)
	_invert = UiTheme.button("", func() -> void:
		SaveManager.set_setting("invert_y", not bool(SaveManager.get_setting("invert_y", false)))
		settings_changed.emit()
		refresh())
	column.add_child(_invert)
	_sound = UiTheme.button("", func() -> void:
		Sfx.set_muted(not Sfx.muted)
		refresh())
	column.add_child(_sound)
	_language = UiTheme.button("", func() -> void:
		StringManager.cycle_language()
		refresh())
	column.add_child(_language)
	_quit = UiTheme.button("", func() -> void: title_requested.emit())
	column.add_child(_quit)
	refresh()

func open() -> void:
	refresh()
	visible = true
	_resume.grab_focus()

func _change_sensitivity(step: float) -> void:
	var value: float = clampf(float(SaveManager.get_setting("sensitivity", ConfigManager.get_float("mouse_sensitivity", 0.12))) + step, 0.02, 0.4)
	SaveManager.set_setting("sensitivity", snappedf(value, 0.01))
	settings_changed.emit()
	refresh()

func refresh() -> void:
	_title.text = StringManager.t("pause_title")
	_stats.text = StringManager.t("pause_stats", {shards = GameState.shards.size(), total = GameState.shard_total, seals = GameState.seals_placed.size(), time = GameState.format_time(GameState.time)})
	_resume.text = StringManager.t("pause_resume")
	_sens.text = StringManager.t("pause_sensitivity", {v = "%.2f" % float(SaveManager.get_setting("sensitivity", ConfigManager.get_float("mouse_sensitivity", 0.12)))})
	_invert.text = StringManager.t("pause_invert", {v = StringManager.t("yes" if bool(SaveManager.get_setting("invert_y", false)) else "no")})
	_sound.text = StringManager.t("pause_sound", {v = StringManager.t("sound_off" if Sfx.muted else "sound_on")})
	_language.text = StringManager.t("pause_language")
	_quit.text = StringManager.t("pause_title_screen")

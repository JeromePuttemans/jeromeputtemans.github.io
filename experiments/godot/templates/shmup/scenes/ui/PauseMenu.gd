# =============================================================================
# PauseMenu.gd — Resume, restart, sound, language, main menu
# =============================================================================
# Runs while the tree is paused (Main sets PROCESS_MODE_ALWAYS on the UI).
# =============================================================================

class_name PauseMenu
extends Control

signal resume_requested()
signal restart_requested()
signal menu_requested()

var _title: Label
var _resume: Button
var _restart: Button
var _sound: Button
var _lang: Button
var _menu: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.veil(0.6))
	var center := UiTheme.center_box()
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_title = UiTheme.label("", 38, UiTheme.CYAN, 6)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_resume = UiTheme.button("", func() -> void: resume_requested.emit())
	column.add_child(_resume)
	_restart = UiTheme.button("", func() -> void: restart_requested.emit())
	column.add_child(_restart)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	_sound = UiTheme.button("", _on_sound, 145.0)
	row.add_child(_sound)
	_lang = UiTheme.button("", func() -> void: StringManager.cycle_language(), 145.0)
	row.add_child(_lang)
	_menu = UiTheme.button("", func() -> void: menu_requested.emit())
	column.add_child(_menu)
	StringManager.language_changed.connect(func(_l: String) -> void: refresh())
	refresh()

func refresh() -> void:
	_title.text = StringManager.t("pause_title")
	_resume.text = StringManager.t("pause_resume")
	_restart.text = StringManager.t("pause_restart")
	_sound.text = StringManager.t("sound_off") if Sfx.muted else StringManager.t("sound_on")
	_lang.text = StringManager.t("language_button")
	_menu.text = StringManager.t("pause_menu")

func focus_default() -> void:
	refresh()
	_resume.grab_focus()

func _on_sound() -> void:
	Sfx.set_muted(not Sfx.muted)
	refresh()

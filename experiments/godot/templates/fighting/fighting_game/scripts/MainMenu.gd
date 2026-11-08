# MainMenu.gd
# Simple main menu: title + play/quit.

extends Control

@onready var btn_play: Button = $VBoxContainer/BtnPlay
@onready var btn_quit: Button = $VBoxContainer/BtnQuit
@onready var title_label: Label = $VBoxContainer/TitleLabel

func _ready() -> void:
	var title: String = SettingsManager.get_value("game.title", "GDFighter")
	title_label.text = title
	btn_play.text = tr("MENU_PLAY")
	btn_quit.text = tr("MENU_QUIT")

	btn_play.pressed.connect(_on_play_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_play.grab_focus()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Arena.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

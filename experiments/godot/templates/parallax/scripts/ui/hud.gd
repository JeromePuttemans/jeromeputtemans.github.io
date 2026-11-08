extends Control
# HUD — built by code in game_manager.gd. Creates its own child nodes in _ready.

const SPEED_BAR_MAX_WIDTH: float = 100.0
const COLOR_SPEED_FULL: Color = Color(0.91, 0.91, 1.0, 0.9)
const COLOR_SPEED_LOW: Color = Color(1.0, 0.8, 0.0, 0.9)
const COLOR_SPEED_CRITICAL: Color = Color(1.0, 0.267, 0.333, 0.9)

var _score_label: Label = null
var _speed_bar: ColorRect = null
var _game_manager: Node = null
var _player_node: CharacterBody2D = null
var _strings: Dictionary = {}
var _visible_during_play: bool = false

func _ready() -> void:
	_build_hud_nodes()
	_load_strings()
	_find_dependencies()
	_connect_signals()
	if is_instance_valid(_game_manager):
		_on_game_state_changed(_game_manager.current_state)

func _build_hud_nodes() -> void:
	_score_label = Label.new()
	_score_label.name = "ScoreLabel"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.add_theme_font_size_override("font_size", 20)
	_score_label.add_theme_color_override("font_color", Color(0.91, 0.91, 1.0, 0.85))
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_score_label.offset_left = -180.0
	_score_label.offset_top = 10.0
	_score_label.offset_right = -10.0
	_score_label.offset_bottom = 45.0
	add_child(_score_label)

	var bar_bg := ColorRect.new()
	bar_bg.name = "SpeedBarBackground"
	bar_bg.color = Color(0.1, 0.1, 0.2, 0.8)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	bar_bg.offset_left = 10.0; bar_bg.offset_top = 10.0
	bar_bg.offset_right = 114.0; bar_bg.offset_bottom = 26.0
	add_child(bar_bg)

	_speed_bar = ColorRect.new()
	_speed_bar.name = "SpeedBar"
	_speed_bar.color = COLOR_SPEED_FULL
	_speed_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_speed_bar.offset_left = 12.0; _speed_bar.offset_top = 12.0
	_speed_bar.offset_right = 112.0; _speed_bar.offset_bottom = 24.0
	add_child(_speed_bar)

	var speed_lbl := Label.new()
	speed_lbl.name = "SpeedLabel"
	speed_lbl.text = "VITESSE"
	speed_lbl.add_theme_font_size_override("font_size", 14)
	speed_lbl.add_theme_color_override("font_color", Color(0.91, 0.91, 1.0, 0.5))
	speed_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	speed_lbl.offset_left = 10.0; speed_lbl.offset_top = 28.0
	speed_lbl.offset_right = 115.0; speed_lbl.offset_bottom = 48.0
	add_child(speed_lbl)

func _load_strings() -> void:
	var file: FileAccess = FileAccess.open("res://datas/strings_fr.json", FileAccess.READ)
	if file:
		var json: JSON = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data: Dictionary = json.data as Dictionary
			var gp: Dictionary = data.get("gameplay", {}) as Dictionary
			_strings["score"]      = gp.get("score", "SURVIE") as String
			_strings["score_unit"] = gp.get("score_unit", "sec") as String
		file.close()
	else:
		_strings["score"]      = "SURVIE"
		_strings["score_unit"] = "sec"

func _find_dependencies() -> void:
	var main_node: Node = get_tree().root.get_node_or_null("Main")
	if is_instance_valid(main_node):
		_game_manager = main_node as Node
		_player_node  = main_node.get_node_or_null("World/Player") as CharacterBody2D

func _connect_signals() -> void:
	if is_instance_valid(_game_manager) and _game_manager.has_signal("game_state_changed"):
		_game_manager.game_state_changed.connect(_on_game_state_changed)
	if is_instance_valid(_game_manager) and _game_manager.has_signal("score_updated"):
		_game_manager.score_updated.connect(_on_score_updated)
	if is_instance_valid(_player_node) and _player_node.has_signal("player_speed_changed"):
		_player_node.player_speed_changed.connect(_on_player_speed_changed)

func _on_game_state_changed(state: int) -> void:
	_visible_during_play = (state == 1)
	visible = _visible_during_play

func _on_score_updated(seconds: float) -> void:
	if not is_instance_valid(_score_label):
		return
	var sc: String = _strings.get("score", "SURVIE") as String
	var un: String = _strings.get("score_unit", "sec") as String
	_score_label.text = sc + " : " + str(int(seconds)) + " " + un

func _on_player_speed_changed(ratio: float) -> void:
	if not is_instance_valid(_speed_bar):
		return
	var bar_width: float = SPEED_BAR_MAX_WIDTH * ratio
	_speed_bar.offset_right = _speed_bar.offset_left + bar_width
	if ratio > 0.5:
		_speed_bar.color = COLOR_SPEED_FULL.lerp(COLOR_SPEED_LOW, 1.0 - ((ratio - 0.5) * 2.0))
	else:
		_speed_bar.color = COLOR_SPEED_LOW.lerp(COLOR_SPEED_CRITICAL, 1.0 - (ratio * 2.0))

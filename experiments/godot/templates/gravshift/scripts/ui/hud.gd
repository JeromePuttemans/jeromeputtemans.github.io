extends Control

# ── Constants ─────────────────────────────────────────────────────────────────
const NEUTRAL_COLOR: Color = Color(0.91, 0.91, 0.91)       # #e8e8e8
const CYAN_COLOR: Color = Color(0.0, 0.898, 1.0)           # #00e5ff
const FONT_SIZE_TITLE: int = 48
const FONT_SIZE_LARGE: int = 28
const FONT_SIZE_NORMAL: int = 20
const FONT_SIZE_SMALL: int = 16

# ── Node references (built by _ready) ────────────────────────────────────────
var _wave_label: Label = null
var _title_screen: Control = null
var _title_label: Label = null
var _best_label: Label = null
var _press_start_label: Label = null
var _game_over_screen: Control = null
var _result_label: Label = null
var _wave_reached_label: Label = null
var _wave_transition_label: Label = null

# ── State ─────────────────────────────────────────────────────────────────────
var _game_manager: Node = null
var _current_wave: int = 0
var _best_wave: int = 0

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_game_manager = get_node_or_null("/root/Main")
	_build_ui()

func _build_ui() -> void:
	# Wave label (top-left, always visible during play)
	_wave_label = Label.new()
	_wave_label.name = "WaveLabel"
	_wave_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	_wave_label.add_theme_color_override("font_color", NEUTRAL_COLOR)
	_wave_label.position = Vector2(20.0, 20.0)
	_wave_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_label.visible = false
	add_child(_wave_label)

	# Title screen overlay
	_title_screen = Control.new()
	_title_screen.name = "TitleScreen"
	_title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_screen)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "GRAVSHIFT"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	_title_label.add_theme_color_override("font_color", NEUTRAL_COLOR)
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title_label.position.y = -100.0
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_screen.add_child(_title_label)

	_best_label = Label.new()
	_best_label.name = "BestLabel"
	_best_label.text = "BEST : —"
	_best_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	_best_label.add_theme_color_override("font_color", NEUTRAL_COLOR)
	_best_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_best_label.position.y = -20.0
	_best_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_screen.add_child(_best_label)

	_press_start_label = Label.new()
	_press_start_label.name = "PressStartLabel"
	_press_start_label.text = "APPUIE SUR ESPACE"
	_press_start_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	_press_start_label.add_theme_color_override("font_color", NEUTRAL_COLOR)
	_press_start_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_press_start_label.position.y = -60.0
	_press_start_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_screen.add_child(_press_start_label)

	# Game Over / Win screen overlay
	_game_over_screen = Control.new()
	_game_over_screen.name = "GameOverScreen"
	_game_over_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over_screen.visible = false
	add_child(_game_over_screen)

	_result_label = Label.new()
	_result_label.name = "ResultLabel"
	_result_label.add_theme_font_size_override("font_size", FONT_SIZE_LARGE)
	_result_label.add_theme_color_override("font_color", NEUTRAL_COLOR)
	_result_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_result_label.position.y = -80.0
	_result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over_screen.add_child(_result_label)

	_wave_reached_label = Label.new()
	_wave_reached_label.name = "WaveReachedLabel"
	_wave_reached_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	_wave_reached_label.add_theme_color_override("font_color", NEUTRAL_COLOR)
	_wave_reached_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_wave_reached_label.position.y = -20.0
	_wave_reached_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over_screen.add_child(_wave_reached_label)

	var return_label: Label = Label.new()
	return_label.name = "ReturnLabel"
	return_label.text = "APPUIE SUR ESPACE"
	return_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	return_label.add_theme_color_override("font_color", NEUTRAL_COLOR)
	return_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	return_label.position.y = -60.0
	return_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over_screen.add_child(return_label)

	# Wave transition label (shown in Transitions layer, built here for reference)
	_wave_transition_label = Label.new()
	_wave_transition_label.name = "TransitionLabel"
	_wave_transition_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	_wave_transition_label.add_theme_color_override("font_color", CYAN_COLOR)
	_wave_transition_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_wave_transition_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wave_transition_label)
	_wave_transition_label.visible = false

	# Apply string localisation
	_apply_strings()

func _apply_strings() -> void:
	if not is_instance_valid(_game_manager):
		return
	var press_text: String = _game_manager.get_string("gameplay", "press_start", "Appuie sur Espace")
	if is_instance_valid(_press_start_label):
		_press_start_label.text = press_text.to_upper()

# ── Signal handlers (called by game_manager after connection + sync) ──────────
func _on_game_state_changed(state: int) -> void:
	var gm: Node = _game_manager
	if not is_instance_valid(gm):
		return

	var is_title: bool = (state == gm.GameState.TITLE)
	var is_playing: bool = (state == gm.GameState.PLAYING)
	var is_transition: bool = (state == gm.GameState.WAVE_TRANSITION)
	var is_game_over: bool = (state == gm.GameState.GAME_OVER)
	var is_win: bool = (state == gm.GameState.WIN)

	if is_instance_valid(_title_screen):
		_title_screen.visible = is_title
	if is_instance_valid(_game_over_screen):
		_game_over_screen.visible = (is_game_over or is_win)
	if is_instance_valid(_wave_label):
		_wave_label.visible = (is_playing or is_transition)
	if is_instance_valid(_wave_transition_label):
		_wave_transition_label.visible = false  # controlled by show_wave_transition

	if is_game_over:
		var death_text: String = gm.get_string("feedback", "player_death", "Détruit. Recommencer ?")
		if is_instance_valid(_result_label):
			_result_label.text = death_text
		if is_instance_valid(_wave_reached_label):
			var wave_str: String = gm.get_string("gameplay", "wave", "Vague")
			_wave_reached_label.text = wave_str + " atteinte : " + str(_current_wave)

	if is_win:
		var win_text: String = gm.get_string("feedback", "run_complete", "Secteur sécurisé.")
		if is_instance_valid(_result_label):
			_result_label.text = win_text
		if is_instance_valid(_wave_reached_label):
			var wave_str: String = gm.get_string("gameplay", "wave", "Vague")
			_wave_reached_label.text = wave_str + " complète : " + str(_current_wave)

func _on_wave_started(wave_number: int) -> void:
	_current_wave = wave_number
	if is_instance_valid(_wave_label) and is_instance_valid(_game_manager):
		var wave_str: String = _game_manager.get_string("gameplay", "wave", "Vague")
		_wave_label.text = wave_str + " " + str(wave_number)

func _on_best_wave_updated(best: int) -> void:
	_best_wave = best
	if is_instance_valid(_best_label) and is_instance_valid(_game_manager):
		var best_str: String = _game_manager.get_string("gameplay", "best", "Meilleur")
		if best <= 0:
			_best_label.text = best_str.to_upper() + " : —"
		else:
			var wave_str: String = _game_manager.get_string("gameplay", "wave", "Vague")
			_best_label.text = best_str.to_upper() + " : " + wave_str + " " + str(best)

func _on_twist_activated() -> void:
	# Visual pulse on wave label to signal the field is active (optional feedback)
	if is_instance_valid(_wave_label):
		_wave_label.add_theme_color_override("font_color", CYAN_COLOR)

func show_wave_transition(next_wave: int) -> void:
	if is_instance_valid(_wave_transition_label) and is_instance_valid(_game_manager):
		var wave_str: String = _game_manager.get_string("gameplay", "wave", "Vague")
		var clear_str: String = _game_manager.get_string("feedback", "wave_clear", "Vague franchie.")
		_wave_transition_label.text = clear_str + "\n" + wave_str + " " + str(next_wave)
		_wave_transition_label.visible = true

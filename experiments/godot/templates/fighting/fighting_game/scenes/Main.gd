# =============================================================================
# Main.gd — Screens and the match in progress
# =============================================================================
#   Match (world)                  stage, fighters, effects, camera
#   HUD (CanvasLayer 5)            bars, timer, gauges, announcements
#   Screens (CanvasLayer 10)       title, character select, pause, move
#                                  list, results
#   Transition (CanvasLayer 20)    iris wipe
# Main runs while the tree is paused, so it reads the pause key. Leaving
# the browser tab pauses a fight in progress.
# =============================================================================

extends Node

const DUMMY_MODES: Array[String] = ["stand", "block", "random", "crouch", "jump"]

var _match: Match = null
var _hud: Hud
var _announcer: Announcer
var _title: TitleScreen
var _select: CharacterSelect
var _pause: Menus.Pause
var _moves: Menus.MoveList
var _results: Menus.Results
var _transition: Transition
var _busy: bool = false
var _dummy: Inputs.Dummy = null
var _paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.register(false)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	var hud_root := _root()
	hud_layer.add_child(hud_root)
	_hud = Hud.new()
	hud_root.add_child(_hud)
	_announcer = Announcer.new()
	hud_root.add_child(_announcer)
	var screens := CanvasLayer.new()
	screens.layer = 10
	add_child(screens)
	var root := _root()
	screens.add_child(root)
	_title = TitleScreen.new()
	root.add_child(_title)
	_select = CharacterSelect.new()
	root.add_child(_select)
	_pause = Menus.Pause.new()
	root.add_child(_pause)
	_moves = Menus.MoveList.new()
	root.add_child(_moves)
	_results = Menus.Results.new()
	root.add_child(_results)
	var top := CanvasLayer.new()
	top.layer = 20
	add_child(top)
	_transition = Transition.new()
	top.add_child(_transition)
	_title.mode_chosen.connect(_on_mode)
	_select.confirmed.connect(_on_selected)
	_select.back_requested.connect(func() -> void: _go(_show_title))
	_pause.chosen.connect(_on_pause_action)
	_moves.closed.connect(func() -> void:
		_moves.visible = false
		_pause.visible = true
		_pause.focus_default())
	_results.chosen.connect(_on_result_action)
	_show_title()
	_transition.openness = 0.0
	_transition.open(0.7)

func _root() -> Control:
	var r := Control.new()
	r.theme = UiTheme.build()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _hide_all() -> void:
	_title.visible = false
	_select.visible = false
	_pause.visible = false
	_moves.visible = false
	_results.visible = false
	_hud.visible = false
	_announcer.clear()

func _go(screen: Callable) -> void:
	if _busy:
		return
	_busy = true
	await _transition.close()
	get_tree().paused = false
	_paused = false
	screen.call()
	await _transition.open()
	_busy = false

# =============================================================================
# SCREENS
# =============================================================================

func _show_title() -> void:
	_hide_all()
	_free_match()
	InputSetup.register(false)
	_title.visible = true
	_title.focus_default()

func _on_mode(mode: String) -> void:
	GameState.mode = mode
	_go(_show_select)

func _show_select() -> void:
	_hide_all()
	_free_match()
	InputSetup.register(GameState.mode == "versus")
	_select.visible = true
	_select.open(GameState.mode)

func _on_selected(p1: String, p2: String, difficulty: int) -> void:
	if GameState.mode == "arcade":
		GameState.start_arcade(p1, difficulty)
	else:
		GameState.p1 = p1
		GameState.p2 = p2
	_go(_start_match)

func _start_match() -> void:
	_hide_all()
	_free_match()
	InputSetup.register(GameState.mode == "versus")
	var p1_input: Object = Inputs.Human.new("p1_")
	var p2_input: Object
	match GameState.mode:
		"versus":
			p2_input = Inputs.Human.new("p2_")
		"training":
			_dummy = Inputs.Dummy.new()
			p2_input = _dummy
		_:
			var levels: Array = ConfigManager.get_array("ai")
			p2_input = AIInput.new(levels[clampi(GameState.arcade_level(), 0, levels.size() - 1)] as Dictionary)
	_match = Match.new()
	_match.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_match)
	_match.setup(GameState.p1, GameState.p2, GameState.roster, [p1_input, p2_input], GameState.stage_for(GameState.p2), GameState.mode == "training")
	_match.announce.connect(func(key: String, style: String) -> void: _announcer.show_text(key, style))
	_match.match_over.connect(_on_match_over)
	_hud.match_node = _match
	_hud.reset()
	_hud.visible = true

func _free_match() -> void:
	if _match != null:
		_match.queue_free()
		_match = null
		_hud.match_node = null

func _on_match_over(winner: int) -> void:
	_results.visible = true
	_results.show_result(winner)

func _on_result_action(action: String) -> void:
	match action:
		"next":
			GameState.arcade_next()
			_go(_start_match)
		"retry", "rematch":
			_go(_start_match)
		"select":
			_go(_show_select)
		_:
			_go(_show_title)

# =============================================================================
# PAUSE AND TRAINING KEYS
# =============================================================================

func _pause_game() -> void:
	if _match == null or _paused or _busy or _results.visible:
		return
	_paused = true
	get_tree().paused = true
	Sfx.play("pause")
	_pause.visible = true
	_pause.focus_default()

func _resume() -> void:
	_paused = false
	_pause.visible = false
	_moves.visible = false
	get_tree().paused = false

func _on_pause_action(action: String) -> void:
	match action:
		"resume":
			_resume()
		"moves":
			_pause.visible = false
			_moves.visible = true
			_moves.open(GameState.p1)
		"restart":
			_go(_start_match)
		"select":
			_go(_show_select)
		"menu":
			_go(_show_title)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _match != null and not _results.visible:
		if _paused:
			if _moves.visible:
				_moves.closed.emit()
			else:
				_resume()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_TAB and _dummy != null and _match != null and _match.training:
		var i: int = DUMMY_MODES.find(_dummy.mode)
		_dummy.mode = DUMMY_MODES[(i + 1) % DUMMY_MODES.size()]
		_match.dummy_mode = _dummy.mode
		Sfx.play("ui_move")
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause_game()

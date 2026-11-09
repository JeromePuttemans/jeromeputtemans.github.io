# =============================================================================
# Main.gd — Builds the scene tree and runs the screens
# =============================================================================
#   Background (CanvasLayer -10)   sky and parallax of the current level
#   World                          the Level being played (pausable)
#   UI (CanvasLayer 10)            vignette, HUD, title, level select,
#                                  pause, results, final screen
#   Transition (CanvasLayer 20)    iris wipe
#
# Main runs while the tree is paused, so it can read the pause key and the
# menus keep working. Leaving the browser tab pauses a level in progress.
# =============================================================================

extends Node

var _world: Node2D
var _level: Level = null
var _background: Background
var _vignette: TextureRect
var _hud: Hud
var _title: TitleScreen
var _select: LevelSelect
var _pause: PauseMenu
var _complete: CompleteScreen
var _final: FinalScreen
var _transition: Transition
var _busy: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.register()
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	bg_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bg_layer)
	_background = Background.new()
	bg_layer.add_child(_background)
	_world = Node2D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var root := Control.new()
	root.theme = UiTheme.build()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	_vignette = _make_vignette()
	root.add_child(_vignette)
	_hud = Hud.new()
	root.add_child(_hud)
	_title = TitleScreen.new()
	root.add_child(_title)
	_select = LevelSelect.new()
	root.add_child(_select)
	_pause = PauseMenu.new()
	root.add_child(_pause)
	_complete = CompleteScreen.new()
	root.add_child(_complete)
	_final = FinalScreen.new()
	root.add_child(_final)
	var top := CanvasLayer.new()
	top.layer = 20
	add_child(top)
	_transition = Transition.new()
	top.add_child(_transition)
	_title.play_requested.connect(_start_level)
	_title.levels_requested.connect(_show_select)
	_select.level_chosen.connect(_start_level)
	_select.back_requested.connect(_show_title)
	_pause.resume_requested.connect(_resume)
	_pause.restart_requested.connect(func() -> void: _start_level(GameState.level_index))
	_pause.menu_requested.connect(_back_to_menu)
	_complete.next_requested.connect(_next_level)
	_complete.replay_requested.connect(func() -> void: _start_level(GameState.level_index))
	_complete.menu_requested.connect(_back_to_menu)
	_final.menu_requested.connect(_back_to_menu)
	_transition.openness = 0.0
	_show_title()
	_transition.open(0.7)

func _make_vignette() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.02, 0.03, 0.05, 0.9)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.width = 256
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

# =============================================================================
# SCREENS
# =============================================================================

func _hide_screens() -> void:
	_title.visible = false
	_select.visible = false
	_pause.visible = false
	_complete.visible = false
	_final.visible = false

func _show_title() -> void:
	_hide_screens()
	_free_level()
	_hud.visible = false
	var theme_level: LevelData = GameState.levels[clampi(SaveManager.unlocked() - 1, 0, GameState.levels.size() - 1)]
	_background.set_theme(theme_level.theme, 720.0)
	_background.auto_scroll = true
	_vignette.modulate.a = 0.35
	GameState.set_phase(GameState.Phase.MENU)
	_title.visible = true
	_title.focus_default()

func _show_select() -> void:
	_hide_screens()
	_select.visible = true
	_select.focus_default()

func _back_to_menu() -> void:
	if _busy:
		return
	_busy = true
	await _transition.close()
	get_tree().paused = false
	_show_title()
	await _transition.open()
	_busy = false

func _start_level(index: int) -> void:
	if _busy:
		return
	_busy = true
	_transition.focus_point = Vector2(-1.0, -1.0)
	await _transition.close()
	get_tree().paused = false
	_hide_screens()
	_free_level()
	var data: LevelData = GameState.levels[index]
	GameState.begin_level(index)
	_level = Level.new()
	_world.add_child(_level)
	_level.build(data)
	_level.finished.connect(_on_level_finished)
	_background.auto_scroll = false
	_background.set_theme(data.theme, data.height * LevelData.TILE)
	_vignette.modulate.a = float(data.theme.get("vignette", 0.35))
	_hud.visible = true
	await _transition.open()
	_busy = false

func _free_level() -> void:
	if _level != null:
		_level.queue_free()
		_level = null

func _on_level_finished() -> void:
	var result: Dictionary = GameState.finish_level()
	_complete.visible = true
	_complete.show_result(result)

func _next_level() -> void:
	if GameState.is_last_level():
		_complete.visible = false
		GameState.set_phase(GameState.Phase.FINAL)
		_final.visible = true
		_final.focus_default()
		return
	_start_level(GameState.level_index + 1)

func _pause_game() -> void:
	if GameState.phase != GameState.Phase.PLAYING or _busy:
		return
	get_tree().paused = true
	GameState.set_phase(GameState.Phase.PAUSED)
	Sfx.play("pause")
	_pause.visible = true
	_pause.focus_default()

func _resume() -> void:
	if GameState.phase != GameState.Phase.PAUSED:
		return
	_pause.visible = false
	get_tree().paused = false
	GameState.set_phase(GameState.Phase.PLAYING)

# =============================================================================
# INPUT
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameState.phase == GameState.Phase.PLAYING:
			_pause_game()
		elif GameState.phase == GameState.Phase.PAUSED:
			_resume()
		elif _select.visible:
			_show_title()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart") and GameState.phase == GameState.Phase.PLAYING and _level != null:
		_level.restart_from_checkpoint()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _select.visible:
		_show_title()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause_game()

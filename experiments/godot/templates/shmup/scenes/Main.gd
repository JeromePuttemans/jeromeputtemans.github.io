# =============================================================================
# Main.gd — Builds the scene tree and runs the screens
# =============================================================================
#   Game                           the play field, centred in the window
#   HUD (CanvasLayer 5)            side panels, boss bar, banners
#   Screens (CanvasLayer 10)       title, pause, results
#   Transition (CanvasLayer 20)    iris wipe
# The field keeps its size (540 x 720); a wider window gives wider side
# panels. Main runs while the tree is paused, so it reads the pause key;
# leaving the browser tab pauses a run in progress.
# =============================================================================

extends Node

var _game: Game
var _panels: SidePanels
var _boss_bar: BossBar
var _banner: Banner
var _title: TitleScreen
var _pause: PauseMenu
var _result: ResultScreen
var _transition: Transition
var _busy: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.register()
	_game = Game.new()
	_game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_game)
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	var hud_root := _root_control()
	hud.add_child(hud_root)
	_panels = SidePanels.new()
	_panels.game = _game
	hud_root.add_child(_panels)
	_boss_bar = BossBar.new()
	_boss_bar.game = _game
	hud_root.add_child(_boss_bar)
	_banner = Banner.new()
	hud_root.add_child(_banner)
	var screens := CanvasLayer.new()
	screens.layer = 10
	add_child(screens)
	var screen_root := _root_control()
	screens.add_child(screen_root)
	_title = TitleScreen.new()
	screen_root.add_child(_title)
	_pause = PauseMenu.new()
	screen_root.add_child(_pause)
	_result = ResultScreen.new()
	screen_root.add_child(_result)
	var top := CanvasLayer.new()
	top.layer = 20
	add_child(top)
	_transition = Transition.new()
	top.add_child(_transition)
	_title.play_requested.connect(_start)
	_pause.resume_requested.connect(_resume)
	_pause.restart_requested.connect(func() -> void: _start(GameState.difficulty))
	_pause.menu_requested.connect(_back_to_menu)
	_result.retry_requested.connect(func() -> void: _start(GameState.difficulty))
	_result.menu_requested.connect(_back_to_menu)
	_game.finished.connect(_on_finished)
	_game.banner.connect(_on_banner)
	GameState.extended.connect(func() -> void:
		Sfx.play("extend")
		_banner.show_banner(StringManager.t("extend"), "", "extend"))
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_title()
	_transition.openness = 0.0
	_transition.open(0.7)

func _root_control() -> Control:
	var root := Control.new()
	root.theme = UiTheme.build()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return root

func _layout() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var left: float = roundf((view.x - _game.field.x) * 0.5)
	var top: float = roundf(maxf(view.y - _game.field.y, 0.0) * 0.5)
	_game.position = Vector2(left, top)
	_panels.field_left = left
	_panels.field_width = _game.field.x
	_boss_bar.position = Vector2(left, top)
	_boss_bar.size = Vector2(_game.field.x, 60.0)
	_banner.position = Vector2(left, top)
	_banner.size = _game.field

# =============================================================================
# SCREENS
# =============================================================================

func _hide_screens() -> void:
	_title.visible = false
	_pause.visible = false
	_result.visible = false

func _show_title() -> void:
	_hide_screens()
	_game.stop()
	_banner.clear()
	GameState.set_phase(GameState.Phase.MENU)
	_title.visible = true
	_title.focus_default()

func _start(difficulty: String) -> void:
	if _busy:
		return
	_busy = true
	await _transition.close()
	get_tree().paused = false
	_hide_screens()
	_banner.clear()
	_game.start(difficulty)
	await _transition.open()
	_busy = false

func _back_to_menu() -> void:
	if _busy:
		return
	_busy = true
	await _transition.close()
	get_tree().paused = false
	_show_title()
	await _transition.open()
	_busy = false

func _on_finished(cleared: bool) -> void:
	GameState.set_phase(GameState.Phase.RESULT)
	_result.visible = true
	_result.show_result(cleared)

func _on_banner(key: String, style: String) -> void:
	var sub: String = ""
	if key == "warning":
		sub = StringManager.t("warning_sub")
	elif key == "stage_start":
		sub = StringManager.t("stage_start_sub")
	_banner.show_banner(StringManager.t(key), sub, style)

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameState.phase == GameState.Phase.PLAYING:
			_pause_game()
		elif GameState.phase == GameState.Phase.PAUSED:
			_resume()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause_game()

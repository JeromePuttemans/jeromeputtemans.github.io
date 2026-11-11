# =============================================================================
# Main.gd — Root of the game: builds the screens and switches between them
# =============================================================================
# STATES: TITLE (composition painting itself, menu, slow boogie)
#   -> PLAYING <-> PAUSED -> OVER (the board hung as a painting, recorded
#   in the gallery) -> PLAYING again, GALLERY or TITLE.
# Everything is built by code; main.tscn only holds this node.
# =============================================================================

extends Node2D

enum State { TITLE, PLAYING, PAUSED, OVER, GALLERY }

var game: Game = null
var title: TitleScreen = null
var pause_menu: PauseMenu = null
var end_screen: EndScreen = null
var gallery: Gallery = null
var state: State = State.TITLE
var _gallery_back: State = State.TITLE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.register_actions()
	game = Game.new()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.finished.connect(_on_finished)
	add_child(game)
	var ui := CanvasLayer.new()
	add_child(ui)
	var theme: Theme = UiTheme.build()
	title = TitleScreen.new()
	title.theme = theme
	title.play_requested.connect(_play)
	title.gallery_requested.connect(func() -> void: _open_gallery(State.TITLE))
	ui.add_child(title)
	pause_menu = PauseMenu.new()
	pause_menu.theme = theme
	pause_menu.visible = false
	pause_menu.resume_requested.connect(_resume)
	pause_menu.restart_requested.connect(func() -> void:
		_unpause()
		_play())
	pause_menu.title_requested.connect(func() -> void:
		_unpause()
		_show_title())
	ui.add_child(pause_menu)
	end_screen = EndScreen.new()
	end_screen.theme = theme
	end_screen.visible = false
	end_screen.again_requested.connect(_play)
	end_screen.gallery_requested.connect(func() -> void: _open_gallery(State.OVER))
	end_screen.title_requested.connect(_show_title)
	ui.add_child(end_screen)
	gallery = Gallery.new()
	gallery.theme = theme
	gallery.visible = false
	gallery.closed.connect(_close_gallery)
	ui.add_child(gallery)
	_show_title()

func _hide_all() -> void:
	title.visible = false
	pause_menu.visible = false
	end_screen.visible = false
	gallery.visible = false

func _show_title() -> void:
	state = State.TITLE
	_hide_all()
	game.stop()
	game.visible = false
	title.open()
	Sfx.start_music(1)
	Sfx.set_level(-2)

func _play() -> void:
	state = State.PLAYING
	_hide_all()
	game.visible = true
	game.start()

func _pause() -> void:
	state = State.PAUSED
	get_tree().paused = true
	Sfx.stop_music()
	pause_menu.open()

func _unpause() -> void:
	get_tree().paused = false
	pause_menu.visible = false

func _resume() -> void:
	_unpause()
	state = State.PLAYING
	Sfx.resume_music()

func _on_finished(snapshot: Array, stats: Dictionary) -> void:
	var info: Dictionary = SaveManager.store_game(int(stats["score"]), int(stats["lines"]), int(stats["level"]), snapshot)
	state = State.OVER
	_hide_all()
	game.visible = false
	end_screen.show_result(snapshot, stats, info, game.board.cols, game.board.rows)
	if bool(info["record"]):
		Sfx.arpeggio(8, 0, 0.08, 0.0)

func _open_gallery(back: State) -> void:
	_gallery_back = back
	state = State.GALLERY
	_hide_all()
	gallery.open(ConfigManager.get_int("cols", 12), ConfigManager.get_int("rows", 20))

func _close_gallery() -> void:
	gallery.visible = false
	if _gallery_back == State.OVER:
		state = State.OVER
		end_screen.visible = true
	else:
		_show_title()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if state == State.PLAYING and game.active:
			_pause()
			get_viewport().set_input_as_handled()
		elif state == State.PAUSED:
			_resume()
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAYING and game.active:
		_pause()

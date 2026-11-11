# =============================================================================
# TitleScreen.gd — Title over a slow flight around the archipelago
# =============================================================================
# The world turns behind the title while the sun sweeps the day, so the
# shadows can be seen stretching and swinging before the first step.
# A click starts (or continues) the run: the browser only lets a page lock
# the mouse in answer to a click, hence the click rather than a key.
# N starts a new run, L switches the language, M the sound.
# =============================================================================

class_name TitleScreen
extends Control

signal start_requested(new_game: bool)

var _title: Label = null
var _tagline: Label = null
var _click: Label = null
var _new_game: Label = null
var _best: Label = null
var _controls: Label = null
var _options: Label = null
var _time: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.03, 0.02, 0.1, 0.75))
	gradient.set_color(1, Color(0.03, 0.02, 0.1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 4
	shade.texture = tex
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 820.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var column := VBoxContainer.new()
	column.position = Vector2(80.0, 150.0)
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_title = UiTheme.label("", 104, UiTheme.TEXT, 14)
	column.add_child(_title)
	_tagline = UiTheme.label("", 28, UiTheme.GOLD, 6)
	column.add_child(_tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 50.0)
	column.add_child(gap)
	_click = UiTheme.label("", 30, UiTheme.TEXT, 8)
	column.add_child(_click)
	_new_game = UiTheme.label("", 19, UiTheme.MUTED, 5)
	column.add_child(_new_game)
	_best = UiTheme.label("", 19, UiTheme.GOLD, 5)
	column.add_child(_best)
	_controls = UiTheme.label("", 16, UiTheme.MUTED, 5)
	_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_controls.offset_left = 80.0
	_controls.offset_top = -78.0
	add_child(_controls)
	_options = UiTheme.label("", 16, UiTheme.MUTED, 5)
	_options.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_options.offset_left = 80.0
	_options.offset_top = -50.0
	add_child(_options)
	StringManager.language_changed.connect(func(_l: String) -> void: refresh())
	refresh()

func refresh() -> void:
	_title.text = StringManager.t("title")
	_tagline.text = StringManager.t("tagline")
	var has_run: bool = SaveManager.has_run()
	_click.text = StringManager.t("title_click_continue" if has_run else "title_click_new")
	_new_game.text = StringManager.t("title_new_game")
	_new_game.visible = has_run
	var best: Dictionary = SaveManager.best()
	_best.visible = not best.is_empty()
	if not best.is_empty():
		_best.text = StringManager.t("title_best", {time = GameState.format_time(float(best["time"])), shards = int(best["shards"]), total = GameState.shard_total})
	_controls.text = UiTheme.keys(StringManager.t("title_controls"))
	_options.text = StringManager.t("title_options", {sound = StringManager.t("sound_off" if Sfx.muted else "sound_on")})

func _process(delta: float) -> void:
	_time += delta
	_click.modulate.a = 0.6 + 0.4 * sin(_time * 3.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Sfx.play("ui")
		start_requested.emit(false)

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key: Key = (event as InputEventKey).physical_keycode
	if key == KEY_N and SaveManager.has_run():
		Sfx.play("ui")
		start_requested.emit(true)
	elif key == KEY_L:
		StringManager.cycle_language()
		Sfx.play("ui_move")
	elif key == KEY_M:
		Sfx.set_muted(not Sfx.muted)
		Sfx.play("ui_move")
		refresh()
	elif key == KEY_ENTER or key == KEY_SPACE:
		Sfx.play("ui")
		start_requested.emit(false)

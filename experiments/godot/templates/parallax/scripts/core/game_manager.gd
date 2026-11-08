extends Node2D
# Node name: GameManager (this script runs on the Main node which acts as GameManager)

# ── Game state ─────────────────────────────────────────────────────────────────

enum GameState { TITLE, PLAYING, GAME_OVER, WIN }

signal game_state_changed(state: int)
signal score_updated(seconds: float)
signal twist_activated

# ── Node references (set by _build_scene, never @onready) ─────────────────────

var _world: Node2D = null
var _spawner: Node = null
var _bullets: Node2D = null
var _player: CharacterBody2D = null
var _hud: Control = null
var _title_screen: Control = null
var _game_over_screen: Control = null
var _score_label_gameover: Label = null
var _new_best_label: Label = null
var _best_score_title_label: Label = null
var _press_start_label: Label = null
var _restart_label: Label = null
var _game_over_main_label: Label = null

# ── Runtime state ──────────────────────────────────────────────────────────────

var current_state: int = GameState.TITLE
var _survival_time: float = 0.0
var _session_best: float = 0.0
var _can_restart: bool = true
var _strings: Dictionary = {}

# ── Bootstrap ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_strings()
	_build_scene()
	_connect_player_signals()
	_set_state(GameState.TITLE)

# ── Scene construction — entire hierarchy built by code ────────────────────────

func _build_scene() -> void:
	_build_world()
	_build_ui()
	_build_transitions()
	_apply_strings_to_ui()

func _build_world() -> void:
	_world = Node2D.new()
	_world.name = "World"

	_spawner = Node.new()
	_spawner.name = "Spawner"
	_spawner.set_script(load("res://scripts/core/spawner.gd"))
	_world.add_child(_spawner)

	_bullets = Node2D.new()
	_bullets.name = "Bullets"
	_world.add_child(_bullets)

	_player = _build_player()
	_world.add_child(_player)

	add_child(_world)

func _build_player() -> CharacterBody2D:
	var player: CharacterBody2D = CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(200.0, 360.0)
	player.collision_layer = 1
	player.collision_mask = 0

	var body: Polygon2D = Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([Vector2(-14, 10), Vector2(-14, -10), Vector2(16, 0)])
	body.color = Color(0.91, 0.91, 1.0, 1.0)
	player.add_child(body)

	var trail: Line2D = Line2D.new()
	trail.name = "Trail"
	trail.points = PackedVector2Array([Vector2(-14, 0), Vector2(-50, 0)])
	trail.width = 3.0
	trail.default_color = Color(0.91, 0.91, 1.0, 0.6)
	player.add_child(trail)

	var hitbox: Area2D = Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	var hitbox_col: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 10.0
	hitbox_col.shape = circle
	hitbox.add_child(hitbox_col)
	player.add_child(hitbox)

	var fire_timer: Timer = Timer.new()
	fire_timer.name = "FireCooldown"
	fire_timer.wait_time = 0.12
	fire_timer.one_shot = false
	player.add_child(fire_timer)

	# Script is set last — _ready() fires only when player enters the tree,
	# at which point all children already exist and @onready resolves correctly
	player.set_script(load("res://scripts/entities/player.gd"))
	return player

func _build_ui() -> void:
	var ui: CanvasLayer = CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 1

	_hud = Control.new()
	_hud.name = "HUD"
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var score_label: Label = _make_label("ScoreLabel", "SURVIE : 0 sec",
		20, Color(0.91, 0.91, 1.0, 0.85))
	score_label.set_anchor_and_offset(SIDE_LEFT, 1.0, -180.0)
	score_label.set_anchor_and_offset(SIDE_RIGHT, 1.0, -10.0)
	score_label.set_anchor_and_offset(SIDE_TOP, 0.0, 10.0)
	score_label.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 45.0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_child(score_label)

	var speed_bg: ColorRect = ColorRect.new()
	speed_bg.name = "SpeedBarBackground"
	speed_bg.position = Vector2(10.0, 10.0)
	speed_bg.size = Vector2(104.0, 16.0)
	speed_bg.color = Color(0.1, 0.1, 0.2, 0.8)
	speed_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(speed_bg)

	var speed_bar: ColorRect = ColorRect.new()
	speed_bar.name = "SpeedBar"
	speed_bar.position = Vector2(12.0, 12.0)
	speed_bar.size = Vector2(100.0, 12.0)
	speed_bar.color = Color(0.91, 0.91, 1.0, 0.9)
	speed_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(speed_bar)

	var speed_lbl: Label = _make_label("SpeedLabel", "VITESSE", 14, Color(0.91, 0.91, 1.0, 0.5))
	speed_lbl.position = Vector2(10.0, 28.0)
	_hud.add_child(speed_lbl)

	# Script set after children are added
	_hud.set_script(load("res://scripts/ui/hud.gd"))
	ui.add_child(_hud)
	add_child(ui)

func _build_transitions() -> void:
	var transitions: CanvasLayer = CanvasLayer.new()
	transitions.name = "Transitions"
	transitions.layer = 10

	_title_screen = _build_title_screen()
	transitions.add_child(_title_screen)

	_game_over_screen = _build_game_over_screen()
	transitions.add_child(_game_over_screen)

	add_child(transitions)

func _build_title_screen() -> Control:
	var screen: Control = Control.new()
	screen.name = "TitleScreen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.024, 0.024, 0.059, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(bg)

	var title: Label = _make_label("TitleLabel", "PARALLAX", 72, Color(0.91, 0.91, 1.0, 1.0))
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.offset_left = -200.0
	title.offset_top = -80.0
	title.offset_right = 200.0
	title.offset_bottom = -20.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(title)

	_press_start_label = _make_label("PressStartLabel", "ESPACE pour jouer",
		24, Color(0.91, 0.91, 1.0, 0.8))
	_press_start_label.set_anchors_preset(Control.PRESET_CENTER)
	_press_start_label.offset_left = -150.0
	_press_start_label.offset_top = 10.0
	_press_start_label.offset_right = 150.0
	_press_start_label.offset_bottom = 50.0
	_press_start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(_press_start_label)

	_best_score_title_label = _make_label("BestScoreLabel", "", 20, Color(1.0, 0.8, 0.0, 0.9))
	_best_score_title_label.set_anchor_and_offset(SIDE_LEFT, 0.0, 0.0)
	_best_score_title_label.set_anchor_and_offset(SIDE_RIGHT, 1.0, 0.0)
	_best_score_title_label.set_anchor_and_offset(SIDE_TOP, 1.0, -50.0)
	_best_score_title_label.set_anchor_and_offset(SIDE_BOTTOM, 1.0, 0.0)
	_best_score_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(_best_score_title_label)

	return screen

func _build_game_over_screen() -> Control:
	var screen: Control = Control.new()
	screen.name = "GameOverScreen"
	screen.visible = false
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.024, 0.024, 0.059, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(bg)

	_game_over_main_label = _make_label("GameOverLabel", "DÉTRUIT", 56,
		Color(1.0, 0.267, 0.333, 1.0))
	_game_over_main_label.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_main_label.offset_left = -150.0
	_game_over_main_label.offset_top = -80.0
	_game_over_main_label.offset_right = 150.0
	_game_over_main_label.offset_bottom = -30.0
	_game_over_main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(_game_over_main_label)

	_score_label_gameover = _make_label("ScoreLabel", "SURVIE : 0 sec", 28,
		Color(0.91, 0.91, 1.0, 1.0))
	_score_label_gameover.set_anchors_preset(Control.PRESET_CENTER)
	_score_label_gameover.offset_left = -150.0
	_score_label_gameover.offset_top = -10.0
	_score_label_gameover.offset_right = 150.0
	_score_label_gameover.offset_bottom = 30.0
	_score_label_gameover.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(_score_label_gameover)

	_new_best_label = _make_label("NewBestLabel", "", 22, Color(1.0, 0.8, 0.0, 1.0))
	_new_best_label.set_anchors_preset(Control.PRESET_CENTER)
	_new_best_label.offset_left = -150.0
	_new_best_label.offset_top = 40.0
	_new_best_label.offset_right = 150.0
	_new_best_label.offset_bottom = 75.0
	_new_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(_new_best_label)

	_restart_label = _make_label("RestartLabel", "ESPACE pour jouer", 20,
		Color(0.91, 0.91, 1.0, 0.7))
	_restart_label.set_anchors_preset(Control.PRESET_CENTER)
	_restart_label.offset_left = -150.0
	_restart_label.offset_top = 90.0
	_restart_label.offset_right = 150.0
	_restart_label.offset_bottom = 125.0
	_restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(_restart_label)

	return screen

# ── Label factory ──────────────────────────────────────────────────────────────

func _make_label(node_name: String, text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

# ── Signal wiring ──────────────────────────────────────────────────────────────

func _connect_player_signals() -> void:
	if is_instance_valid(_player):
		_player.player_died.connect(_on_player_died)
		_player.twist_activated.connect(_on_twist_activated)

# ── Input ──────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if current_state == GameState.TITLE:
			_set_state(GameState.PLAYING)
		elif current_state == GameState.GAME_OVER and _can_restart:
			_set_state(GameState.TITLE)

# ── State machine ──────────────────────────────────────────────────────────────

func _set_state(new_state: int) -> void:
	current_state = new_state
	game_state_changed.emit(current_state)
	match current_state:
		GameState.TITLE:    _on_enter_title()
		GameState.PLAYING:  _on_enter_playing()
		GameState.GAME_OVER: _on_enter_game_over()

func _on_enter_title() -> void:
	if is_instance_valid(_title_screen):   _title_screen.visible = true
	if is_instance_valid(_game_over_screen): _game_over_screen.visible = false
	_update_best_score_display()
	if is_instance_valid(_player):   _player.visible = false
	if is_instance_valid(_spawner):  _spawner.call("stop_spawning")
	_clear_bullets()

func _on_enter_playing() -> void:
	_survival_time = 0.0
	if is_instance_valid(_title_screen):    _title_screen.visible = false
	if is_instance_valid(_game_over_screen): _game_over_screen.visible = false
	_can_restart = false
	if is_instance_valid(_player):
		_player.call("reset_player")
		_player.visible = true
	if is_instance_valid(_spawner): _spawner.call("start_spawning")
	score_updated.emit(_survival_time)

func _on_enter_game_over() -> void:
	if is_instance_valid(_game_over_screen): _game_over_screen.visible = false
	var is_new_best: bool = _survival_time > _session_best
	if is_new_best:
		_session_best = _survival_time
	if is_instance_valid(_spawner): _spawner.call("stop_spawning")
	_update_game_over_display(is_new_best)
	await get_tree().create_timer(0.8).timeout
	if current_state == GameState.GAME_OVER:
		if is_instance_valid(_game_over_screen): _game_over_screen.visible = true
		_can_restart = true

# ── Process ────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return
	_survival_time += delta
	score_updated.emit(_survival_time)

# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_player_died() -> void:
	_set_state(GameState.GAME_OVER)

func _on_twist_activated() -> void:
	twist_activated.emit()

# ── UI helpers ─────────────────────────────────────────────────────────────────

func _update_game_over_display(is_new_best: bool) -> void:
	var score_text: String = _strings.get("score", "SURVIE") as String
	var unit_text: String = _strings.get("score_unit", "sec") as String
	if is_instance_valid(_score_label_gameover):
		_score_label_gameover.text = score_text + " : " + str(int(_survival_time)) + " " + unit_text
	if is_instance_valid(_game_over_main_label):
		_game_over_main_label.text = _strings.get("game_over", "DÉTRUIT") as String
	if is_instance_valid(_new_best_label):
		_new_best_label.text = _strings.get("new_best", "NOUVEAU RECORD") as String if is_new_best else ""

func _update_best_score_display() -> void:
	if not is_instance_valid(_best_score_title_label): return
	if _session_best > 0.0:
		var best: String = _strings.get("best", "MEILLEUR") as String
		var unit: String = _strings.get("score_unit", "sec") as String
		_best_score_title_label.text = best + " : " + str(int(_session_best)) + " " + unit
	else:
		_best_score_title_label.text = ""

func _apply_strings_to_ui() -> void:
	var press: String = _strings.get("press_start", "ESPACE pour jouer") as String
	if is_instance_valid(_press_start_label): _press_start_label.text = press
	if is_instance_valid(_restart_label):     _restart_label.text = press

func _load_strings() -> void:
	var file: FileAccess = FileAccess.open("res://datas/strings_fr.json", FileAccess.READ)
	if file:
		var json: JSON = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data: Dictionary = json.data as Dictionary
			var g: Dictionary = data.get("gameplay", {}) as Dictionary
			var f: Dictionary = data.get("feedback", {}) as Dictionary
			_strings["score"]       = g.get("score", "SURVIE") as String
			_strings["score_unit"]  = g.get("score_unit", "sec") as String
			_strings["best"]        = g.get("best", "MEILLEUR") as String
			_strings["press_start"] = g.get("press_start", "ESPACE pour jouer") as String
			_strings["game_over"]   = f.get("game_over", "DÉTRUIT") as String
			_strings["new_best"]    = f.get("new_best", "NOUVEAU RECORD") as String
		file.close()
	else:
		_strings = {"score":"SURVIE","score_unit":"sec","best":"MEILLEUR",
			"press_start":"ESPACE pour jouer","game_over":"DÉTRUIT","new_best":"NOUVEAU RECORD"}

func _clear_bullets() -> void:
	if not is_instance_valid(_bullets): return
	for child_v in _bullets.get_children():
		var child: Node = child_v as Node
		if is_instance_valid(child): child.queue_free()

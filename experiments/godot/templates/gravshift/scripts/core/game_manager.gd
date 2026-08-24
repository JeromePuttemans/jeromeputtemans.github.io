extends Node2D

# ── Signals ───────────────────────────────────────────────────────────────────
signal game_state_changed(state: int)
signal wave_started(wave_number: int)
signal best_wave_updated(best: int)

# ── Enums ─────────────────────────────────────────────────────────────────────
enum GameState {
	TITLE,
	PLAYING,
	WAVE_TRANSITION,
	PAUSED,
	GAME_OVER,
	WIN
}

# ── Constants ─────────────────────────────────────────────────────────────────
const WAVE_TRANSITION_DURATION: float = 1.5
const STAR_COUNT: int = 30
const STAR_COLOR: Color = Color(0.91, 0.91, 0.91, 0.6)
const BACKGROUND_COLOR: Color = Color(0.031, 0.031, 0.094)

# ── Settings (loaded from datas/settings.json) ────────────────────────────────
var _settings: Dictionary = {}
var _strings: Dictionary = {}

# ── State ─────────────────────────────────────────────────────────────────────
var current_state: int = GameState.TITLE
var _current_wave: int = 0
var _best_wave: int = 0

# ── Scene references (built by _build_scene) ─────────────────────────────────
var _world: Node2D = null
var _bullets_container: Node2D = null
var _enemies_container: Node2D = null
var _enemy_bullets_container: Node2D = null
var _player: CharacterBody2D = null
var _ui_layer: CanvasLayer = null
var _hud: Control = null
var _transitions_layer: CanvasLayer = null
var _wave_transition_control: Control = null
var _spawner: Node = null
var _gravity_field: Node = null
var _transition_timer: Timer = null
var _background: ColorRect = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_settings()
	_load_strings()
	_build_scene()
	_connect_signals()
	_set_state(GameState.TITLE)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if (current_state == GameState.TITLE
			or current_state == GameState.GAME_OVER
			or current_state == GameState.WIN):
			_start_game()

# ── Settings loading ──────────────────────────────────────────────────────────
func _load_settings() -> void:
	var path: String = "res://datas/settings.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_settings = {}
		return
	var text: String = file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if result == null:
		_settings = {}
		return
	_settings = result as Dictionary

func _load_strings() -> void:
	# Load French strings by default
	var path: String = "res://datas/strings_fr.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_strings = {}
		return
	var text: String = file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if result == null:
		_strings = {}
		return
	_strings = result as Dictionary

func get_setting(key: String, fallback: Variant) -> Variant:
	var gameplay: Dictionary = _settings.get("gameplay", {}) as Dictionary
	return gameplay.get(key, fallback)

func get_string(category: String, key: String, fallback: String) -> String:
	var cat: Dictionary = _strings.get(category, {}) as Dictionary
	return cat.get(key, fallback) as String

# ── Scene construction (PATTERN 25 — all hierarchy built by code) ─────────────
func _build_scene() -> void:
	# Background
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = BACKGROUND_COLOR
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	# Stars (static decorative points)
	var stars_node: Node2D = Node2D.new()
	stars_node.name = "Stars"
	_background.add_child(stars_node)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for _i in range(STAR_COUNT):
		var star: ColorRect = ColorRect.new()
		star.color = STAR_COLOR
		star.size = Vector2(2.0, 2.0)
		star.position = Vector2(
			rng.randf_range(0.0, 1920.0),
			rng.randf_range(0.0, 1080.0)
		)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background.add_child(star)

	# World container
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	# Bullets container
	_bullets_container = Node2D.new()
	_bullets_container.name = "Bullets"
	_world.add_child(_bullets_container)

	# Enemies container
	_enemies_container = Node2D.new()
	_enemies_container.name = "Enemies"
	_world.add_child(_enemies_container)

	# Enemy bullets container
	_enemy_bullets_container = Node2D.new()
	_enemy_bullets_container.name = "EnemyBullets"
	_world.add_child(_enemy_bullets_container)

	# Player
	var player_script: Script = load("res://scripts/entities/player.gd") as Script
	_player = CharacterBody2D.new()
	_player.name = "Player"
	_player.set_script(player_script)
	_world.add_child(_player)

	# Spawner
	var spawner_script: Script = load("res://scripts/core/spawner.gd") as Script
	_spawner = Node.new()
	_spawner.name = "Spawner"
	_spawner.set_script(spawner_script)
	add_child(_spawner)

	# Gravity field
	var gravity_script: Script = load("res://scripts/core/gravity_field.gd") as Script
	_gravity_field = Node.new()
	_gravity_field.name = "GravityField"
	_gravity_field.set_script(gravity_script)
	add_child(_gravity_field)

	# UI layer
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	_ui_layer.layer = 1
	add_child(_ui_layer)

	# HUD
	var hud_script: Script = load("res://scripts/ui/hud.gd") as Script
	_hud = Control.new()
	_hud.name = "HUD"
	_hud.set_script(hud_script)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_hud)

	# Transitions layer
	_transitions_layer = CanvasLayer.new()
	_transitions_layer.name = "Transitions"
	_transitions_layer.layer = 2
	add_child(_transitions_layer)

	# Wave transition control
	_wave_transition_control = Control.new()
	_wave_transition_control.name = "WaveTransition"
	_wave_transition_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wave_transition_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_transition_control.visible = false
	_transitions_layer.add_child(_wave_transition_control)

	# Transition timer
	_transition_timer = Timer.new()
	_transition_timer.name = "TransitionTimer"
	_transition_timer.one_shot = true
	_transition_timer.wait_time = WAVE_TRANSITION_DURATION
	add_child(_transition_timer)

# ── Signal connections ────────────────────────────────────────────────────────
func _connect_signals() -> void:
	# Spawner signals — connected after add_child, sync initial state manually
	if is_instance_valid(_spawner):
		var spawner_ref: Spawner = _spawner as Spawner
		if is_instance_valid(spawner_ref):
			spawner_ref.wave_cleared.connect(_on_wave_cleared)
			spawner_ref.enemy_destroyed.connect(_on_enemy_destroyed)

	# Player signals — cast to Player after add_child (script is active)
	if is_instance_valid(_player):
		var player_ref: Player = _player as Player
		if is_instance_valid(player_ref):
			player_ref.player_died.connect(_on_player_died)

	# Gravity field signals
	if is_instance_valid(_gravity_field):
		var gf_ref: GravityField = _gravity_field as GravityField
		if is_instance_valid(gf_ref):
			gf_ref.twist_activated.connect(_on_twist_activated)
			gf_ref.twist_activated.connect(_hud._on_twist_activated)

	# Transition timer
	_transition_timer.timeout.connect(_on_transition_timer_timeout)

	# HUD listens to game_manager signals — sync after connect
	game_state_changed.connect(_hud._on_game_state_changed)
	wave_started.connect(_hud._on_wave_started)
	best_wave_updated.connect(_hud._on_best_wave_updated)

	# Sync initial state (signals may have been missed before connection)
	_hud._on_game_state_changed(current_state)
	_hud._on_best_wave_updated(_best_wave)

# ── State machine ─────────────────────────────────────────────────────────────
func _set_state(new_state: int) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)

func _start_game() -> void:
	_current_wave = 0
	_spawner.call("reset")
	(_player as Player).reset_player()
	if is_instance_valid(_gravity_field):
		_gravity_field.call("reset_twist_state")
	_set_state(GameState.PLAYING)
	_launch_next_wave()

func _launch_next_wave() -> void:
	_current_wave += 1
	wave_started.emit(_current_wave)
	_spawner.call("spawn_wave", _current_wave)

func _on_wave_cleared() -> void:
	var wave_count: int = get_setting("wave_count", 3) as int
	if _current_wave >= wave_count:
		_update_best_wave(_current_wave)
		_set_state(GameState.WIN)
	else:
		_update_best_wave(_current_wave)
		_set_state(GameState.WAVE_TRANSITION)
		_wave_transition_control.visible = true
		_hud.call("show_wave_transition", _current_wave + 1)  # dynamic call — HUD typed as Control
		_transition_timer.start()

func _on_transition_timer_timeout() -> void:
	_wave_transition_control.visible = false
	_set_state(GameState.PLAYING)
	_launch_next_wave()

func _on_player_died() -> void:
	_update_best_wave(_current_wave)
	_set_state(GameState.GAME_OVER)

func _on_twist_activated() -> void:
	# Relay from gravity field — already forwarded to HUD via direct connect
	pass

func _on_enemy_destroyed() -> void:
	# Bookkeeping delegated to spawner — no action needed here
	pass

func _update_best_wave(reached: int) -> void:
	if reached > _best_wave:
		_best_wave = reached
		best_wave_updated.emit(_best_wave)

# ── Public accessors for child scripts ───────────────────────────────────────
func get_player() -> CharacterBody2D:
	return _player

func get_bullets_container() -> Node2D:
	return _bullets_container

func get_enemies_container() -> Node2D:
	return _enemies_container

func get_enemy_bullets_container() -> Node2D:
	return _enemy_bullets_container

func get_current_state() -> int:
	return current_state

extends Node2D

# GameManager (root node of main.tscn): builds the whole scene by code, runs
# the state machine, the score, the sectors and the save file.
#
# STATES: TITLE -> PLAYING <-> PAUSED, PLAYING -> GAME_OVER -> PLAYING (Space)
#   or TITLE (Esc). When the ship dies, the game stays in PLAYING for
#   DEATH_DELAY seconds of slow motion (_dying), then enters GAME_OVER.
# SCORE: survival_points_per_second, plus each enemy's points x multiplier.
#   Every kill extends the chain; the chain breaks after chain_window seconds
#   without a kill or when the hull is hit. multiplier = 1 + chain /
#   chain_per_multiplier, capped at multiplier_max.
# SECTORS: one every sector_duration seconds. Each sector speeds the current
#   up (scroll_speed_per_sector, capped at scroll_speed_max) and lets the
#   spawner send denser waves and new enemy kinds.
# FEEDBACK: shake and particles (effects.gd), hit-stop (Engine.time_scale
#   briefly near 0 on hull hits and big kills), void proximity beeps.
# SAVE: best score and language in user://parallax_save.json.

enum GameState { TITLE, PLAYING, PAUSED, GAME_OVER, WIN }

signal game_state_changed(state: int)
signal score_changed(score: int, multiplier: int, chain_ratio: float, elapsed: float)
signal sector_changed(sector: int)
signal danger_changed(intensity: float)
signal language_changed()
signal twist_activated()

const SAVE_PATH: String = "user://parallax_save.json"
const SETTINGS_PATH: String = "res://datas/settings.json"
const DEATH_DELAY: float = 1.1
const DEATH_TIME_SCALE: float = 0.3
const RESTART_GUARD: float = 0.5
const LANGUAGES: Array[String] = ["fr", "en"]

var current_state: int = GameState.TITLE
var best_score: int = 0
var last_result: Dictionary = {}
var settings: Dictionary = {}
var gameplay: Dictionary = {}

var _strings: Dictionary = {}
var _language: String = "fr"
var _screen: Vector2 = Vector2(1280.0, 720.0)
var _sfx: Node = null
var _world: Node2D = null
var _starfield: Node2D = null
var _containers: Dictionary = {}
var _player: Node2D = null
var _spawner: Node = null
var _combat: Node = null
var _effects: Node2D = null
var _hud: Control = null
var _screens: Control = null

var _elapsed: float = 0.0
var _survival_points: float = 0.0
var _score: int = 0
var _chain: int = 0
var _chain_left: float = 0.0
var _max_chain: int = 1
var _sector: int = 1
var _shots: int = 0
var _hits: int = 0
var _kills: int = 0
var _dying: bool = false
var _slow_motion: bool = false
var _twist_tip_shown: bool = false
var _warn_left: float = 0.0
var _can_restart: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_load_strings()
	_load_save()
	InputManager.configure()
	_build_scene()
	_connect_signals()
	_set_state(GameState.TITLE)

# ---------------------------------------------------------------------------
# Scene construction (everything is built by code, see CONVENTION.md)
# ---------------------------------------------------------------------------

func _build_scene() -> void:
	_screen = get_viewport_rect().size
	_sfx = _make(Node.new(), "SfxManager", "res://scripts/core/sfx_manager.gd", self)
	var audio: Dictionary = settings.get("audio", {}) as Dictionary
	_sfx.call("set_volume", float(audio.get("master_volume", 1.0)) * float(audio.get("sfx_volume", 0.8)))
	_build_world()
	_build_ui()
	_build_transitions()

func _build_world() -> void:
	_world = Node2D.new()
	_world.name = "World"
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	_starfield = _make(Node2D.new(), "Starfield", "res://scripts/core/starfield.gd", _world) as Node2D
	_build_containers()
	_player = _make(Node2D.new(), "Player", "res://scripts/entities/player.gd", _world) as Node2D
	_spawner = _make(Node.new(), "Spawner", "res://scripts/core/spawner.gd", _world)
	_combat = _make(Node.new(), "Combat", "res://scripts/core/combat.gd", _world)
	_combat.process_physics_priority = 10   # after every entity has moved
	_effects = _make(Node2D.new(), "Effects", "res://scripts/core/effects.gd", _world) as Node2D
	_player.call("configure", gameplay, _containers["bullets"], _screen)
	_player.visible = false
	_spawner.call("configure", gameplay, _containers, _player, _screen)
	_combat.call("configure", _player, _containers, gameplay)

## Pickups, Enemies, Shots, Bullets: drawn in this order, bullets and orbs
## with additive blending (they glow over everything else).
func _build_containers() -> void:
	for key in ["pickups", "enemies", "shots", "bullets"]:
		var container := Node2D.new()
		container.name = (key as String).capitalize()
		if key == "shots" or key == "bullets":
			var additive := CanvasItemMaterial.new()
			additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			container.material = additive
		_world.add_child(container)
		_containers[key] = container

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 1
	add_child(ui)
	_hud = _make(Control.new(), "HUD", "res://scripts/ui/hud.gd", ui) as Control
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.call("bind", self, _player, float(gameplay.get("player_speed_base", 300.0)))

func _build_transitions() -> void:
	var transitions := CanvasLayer.new()
	transitions.name = "Transitions"
	transitions.layer = 10
	add_child(transitions)
	_screens = _make(Control.new(), "Screens", "res://scripts/ui/screens.gd", transitions) as Control
	_screens.call("bind", self)

## Script attached before add_child(): _ready() runs with the script in place.
func _make(node: Node, node_name: String, script_path: String, parent: Node) -> Node:
	node.name = node_name
	node.set_script(load(script_path))
	parent.add_child(node)
	return node

func _connect_signals() -> void:
	_player.player_fired.connect(_on_player_fired)
	_player.player_died.connect(_on_player_died)
	_player.player_purged.connect(_on_player_purged)
	_player.twist_activated.connect(_on_twist_activated)
	_combat.enemy_destroyed.connect(_on_enemy_destroyed)
	_combat.enemy_damaged.connect(_on_enemy_damaged)
	_combat.player_struck.connect(_on_player_struck)
	_combat.pickup_collected.connect(_on_pickup_collected)

# ---------------------------------------------------------------------------
# State machine and input
# ---------------------------------------------------------------------------

func _set_state(state: int) -> void:
	current_state = state
	get_tree().paused = state == GameState.PAUSED
	game_state_changed.emit(state)

func _unhandled_input(event: InputEvent) -> void:
	match current_state:
		GameState.TITLE:
			if event.is_action_pressed("start"):
				start_run()
			elif event.is_action_pressed("language"):
				_toggle_language()
		GameState.PLAYING:
			if event.is_action_pressed("pause") and not _dying:
				_set_state(GameState.PAUSED)
				_sfx.call("play", "click", 0.0, 0.0)
		GameState.PAUSED:
			if event.is_action_pressed("pause"):
				_set_state(GameState.PLAYING)
				_sfx.call("play", "click", 0.0, 0.0)
		GameState.GAME_OVER:
			if not _can_restart:
				return
			if event.is_action_pressed("start"):
				start_run()
			elif event.is_action_pressed("to_title"):
				_go_to_title()

func start_run() -> void:
	_clear_world()
	_reset_run()
	_player.call("reset_player", Vector2(_screen.x * 0.25, _screen.y * 0.5))
	_apply_current_speed()
	_spawner.call("start")
	_combat.set("active", true)
	_set_state(GameState.PLAYING)
	sector_changed.emit(_sector)
	_emit_score()
	_sfx.call("play", "start", 0.0, 0.0)

func _reset_run() -> void:
	_elapsed = 0.0
	_survival_points = 0.0
	_score = 0
	_chain = 0
	_chain_left = 0.0
	_max_chain = 1
	_sector = 1
	_shots = 0
	_hits = 0
	_kills = 0
	_dying = false
	_can_restart = false
	Engine.time_scale = 1.0
	_slow_motion = false

func _go_to_title() -> void:
	_clear_world()
	_player.visible = false
	_player.set("alive", false)
	_set_state(GameState.TITLE)
	_sfx.call("play", "click", 0.0, 0.0)

func _clear_world() -> void:
	_spawner.call("stop")
	_spawner.call("clear")
	_combat.set("active", false)
	var bullets: Node2D = _containers["bullets"] as Node2D
	for child_v in bullets.get_children():
		var child: Node = child_v as Node
		bullets.remove_child(child)
		child.queue_free()
	_effects.call("clear")
	_effects.call("set_void_intensity", 0.0)

# ---------------------------------------------------------------------------
# Run update
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_screen = get_viewport_rect().size
	if current_state != GameState.PLAYING:
		return
	if is_instance_valid(_player) and _player.visible:
		_starfield.call("set_focus", _player.position.y)
	if _dying:
		return
	_elapsed += delta
	_survival_points += float(gameplay.get("survival_points_per_second", 10)) * delta
	_update_chain(delta)
	_update_sector()
	_update_danger(delta)
	_emit_score()

func _update_chain(delta: float) -> void:
	if _chain_left <= 0.0:
		return
	_chain_left -= delta
	if _chain_left <= 0.0:
		_chain = 0

func _update_sector() -> void:
	var sector: int = 1 + int(_elapsed / float(gameplay.get("sector_duration", 40.0)))
	if sector <= _sector:
		return
	_sector = sector
	_apply_current_speed()
	_spawner.call("set_sector", _sector)
	sector_changed.emit(_sector)
	_sfx.call("play", "sector", 0.0, 0.0)
	_effects.call("ring", _player.position, Color(1.0, 0.8, 0.0), 300.0, 0.8, 4.0)

func _apply_current_speed() -> void:
	var base: float = float(gameplay.get("scroll_speed", 90.0))
	var step: float = float(gameplay.get("scroll_speed_per_sector", 10.0))
	var speed: float = minf(float(gameplay.get("scroll_speed_max", 150.0)), base + step * (_sector - 1))
	_player.set("current_speed", speed)
	_starfield.call("set_current_speed", speed)

func _update_danger(delta: float) -> void:
	var width: float = float(gameplay.get("danger_zone_width", 260.0))
	var intensity: float = clampf(1.0 - _player.position.x / width, 0.0, 1.0)
	_effects.call("set_void_intensity", intensity)
	danger_changed.emit(intensity)
	_warn_left -= delta
	if intensity > 0.3 and _warn_left <= 0.0:
		_sfx.call("play", "warn", 0.0, -4.0 + 6.0 * intensity)
		_warn_left = lerpf(0.6, 0.12, intensity)

func multiplier() -> int:
	var per: int = maxi(int(gameplay.get("chain_per_multiplier", 4)), 1)
	return mini(1 + int(float(_chain) / float(per)), int(gameplay.get("multiplier_max", 8)))

func _emit_score() -> void:
	var total: int = _score + int(_survival_points)
	var window: float = maxf(float(gameplay.get("chain_window", 2.5)), 0.01)
	score_changed.emit(total, multiplier(), clampf(_chain_left / window, 0.0, 1.0) if _chain > 0 else 0.0, _elapsed)

# ---------------------------------------------------------------------------
# Gameplay events
# ---------------------------------------------------------------------------

func _on_player_fired() -> void:
	_shots += 1
	_sfx.call("play", "shoot", 0.08, -3.0)

func _on_enemy_destroyed(enemy: EnemyBase) -> void:
	_hits += 1
	_kills += 1
	_chain += 1
	_max_chain = maxi(_max_chain, multiplier())
	_chain_left = float(gameplay.get("chain_window", 2.5))
	var gained: int = enemy.points * multiplier()
	_score += gained
	var big: bool = enemy.radius >= 25.0
	_effects.call("explosion", enemy.position, enemy.call("_body_color"), 2.4 if big else 1.0)
	_effects.call("float_text", enemy.position + Vector2(0.0, -20.0), "+%d" % gained, Color(1.0, 0.85, 0.3), 22 if big else 16)
	_effects.call("add_trauma", 0.55 if big else 0.18)
	_sfx.call("play", "kill_big" if big else "kill", 0.1, 0.0)
	if big:
		_hit_stop(0.09, 0.05)
		_maybe_drop_repair(enemy)

func _maybe_drop_repair(enemy: EnemyBase) -> void:
	if randf() < float(enemy.config.get("repair_drop_chance", 0.0)):
		_spawner.call("spawn_pickup", enemy.position, float(_player.get("current_speed")) * 0.6)

func _on_enemy_damaged(enemy: EnemyBase, impact: Vector2) -> void:
	_hits += 1
	_effects.call("sparks", impact, enemy.call("_body_color"), Vector2.LEFT)
	_sfx.call("play", "hit", 0.12, -2.0)

func _on_player_struck(impact: Vector2) -> void:
	_chain = 0
	_chain_left = 0.0
	_effects.call("explosion", impact, Color(1.0, 0.4, 0.4), 0.8)
	_effects.call("add_trauma", 0.7)
	_sfx.call("play", "hurt", 0.05, 0.0)
	_hit_stop(0.12, 0.04)

func _on_player_purged(bullet_positions: PackedVector2Array) -> void:
	for at in bullet_positions:
		_effects.call("burst", at, Color(0.45, 0.9, 1.0), 4, 160.0, 2.5, 0.3)
	_effects.call("ring", _player.position, Color(0.45, 0.9, 1.0), 120.0, 0.45, 3.0)
	_effects.call("float_text", _player.position + Vector2(0.0, -34.0), t("purge"), Color(0.45, 0.9, 1.0), 18)
	_effects.call("add_trauma", 0.2)
	_sfx.call("play", "purge", 0.03, 0.0)

func _on_pickup_collected(_kind: String, at: Vector2) -> void:
	_sfx.call("play", "pickup", 0.0, 0.0)
	_effects.call("burst", at, Color(0.35, 1.0, 0.55), 14, 200.0, 3.0, 0.5)
	if bool(_player.call("repair")):
		_effects.call("float_text", at + Vector2(0.0, -24.0), t("repair"), Color(0.35, 1.0, 0.55), 18)
		return
	var bonus: int = int(gameplay.get("repair_points_when_full", 500)) * multiplier()
	_score += bonus
	_effects.call("float_text", at + Vector2(0.0, -24.0), tf("bonus", {value = bonus}), Color(0.35, 1.0, 0.55), 18)

func _on_twist_activated() -> void:
	if _twist_tip_shown:
		return
	_twist_tip_shown = true
	twist_activated.emit()

func _on_player_died(cause: String) -> void:
	_dying = true
	_combat.set("active", false)
	_spawner.call("stop")
	_effects.call("explosion", _player.position, Color(0.91, 0.91, 1.0), 3.0)
	_effects.call("add_trauma", 1.0)
	_effects.call("set_void_intensity", 0.0)
	_sfx.call("play", "kill_big", 0.0, 2.0)
	_sfx.call("play", "gameover", 0.0, 0.0)
	_finish_run(cause)
	_slow_motion = true
	Engine.time_scale = DEATH_TIME_SCALE
	await get_tree().create_timer(DEATH_DELAY, true, false, true).timeout
	Engine.time_scale = 1.0
	_slow_motion = false
	if current_state == GameState.PLAYING and _dying:
		_set_state(GameState.GAME_OVER)
		await get_tree().create_timer(RESTART_GUARD, true, false, true).timeout
		_can_restart = true

func _finish_run(cause: String) -> void:
	var total: int = _score + int(_survival_points)
	var new_best: bool = total > best_score
	if new_best:
		best_score = total
		_save()
	var accuracy: int = int(round(100.0 * float(_hits) / float(_shots))) if _shots > 0 else 0
	last_result = {score = total, best = best_score, new_best = new_best, cause = cause, time = _elapsed,
		sector = _sector, kills = _kills, accuracy = mini(accuracy, 100), max_chain = _max_chain}

func _hit_stop(duration: float, time_scale: float) -> void:
	if _slow_motion:
		return
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if not _slow_motion:
		Engine.time_scale = 1.0

# ---------------------------------------------------------------------------
# Texts and formatting (used by hud.gd and screens.gd)
# ---------------------------------------------------------------------------

## Text for a key, searched in the feedback, gameplay then ui sections: the
## specific sections first, so feedback.game_over ("DESTROYED") wins over the
## generic ui.game_over. A missing key shows as [key].
func t(key: String) -> String:
	var table: Dictionary = _strings.get(_language, {}) as Dictionary
	for section in ["feedback", "gameplay", "ui"]:
		var entries: Dictionary = table.get(section, {}) as Dictionary
		if entries.has(key):
			return entries[key] as String
	return "[%s]" % key

func tf(key: String, params: Dictionary) -> String:
	var text: String = t(key)
	for param in params:
		text = text.replace("{%s}" % param, str(params[param]))
	return text

## 12400 -> "12 400" (French) or "12,400" (English).
func format_score(score: int) -> String:
	var digits: String = str(absi(score))
	var separator: String = " " if _language == "fr" else ","
	var result: String = ""
	while digits.length() > 3:
		result = separator + digits.substr(digits.length() - 3) + result
		digits = digits.substr(0, digits.length() - 3)
	return digits + result

func format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%d:%02d" % [int(total / 60.0), total % 60]

func _toggle_language() -> void:
	_language = LANGUAGES[(LANGUAGES.find(_language) + 1) % LANGUAGES.size()]
	_save()
	language_changed.emit()
	_sfx.call("play", "click", 0.0, 0.0)

# ---------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------

func _load_settings() -> void:
	var data: Variant = _read_json(SETTINGS_PATH)
	if data is Dictionary:
		settings = data as Dictionary
		gameplay = settings.get("gameplay", {}) as Dictionary

func _load_strings() -> void:
	for language in LANGUAGES:
		var data: Variant = _read_json("res://datas/strings_%s.json" % language)
		_strings[language] = data if data is Dictionary else {}
	var meta: Dictionary = settings.get("meta", {}) as Dictionary
	_language = "fr" if OS.get_locale_language() == "fr" else "en"
	if not LANGUAGES.has(_language):
		_language = meta.get("language", "fr") as String

func _load_save() -> void:
	var data: Variant = _read_json(SAVE_PATH)
	if not data is Dictionary:
		return
	var save: Dictionary = data as Dictionary
	best_score = int(save.get("best_score", 0))
	var language: String = save.get("language", _language) as String
	if LANGUAGES.has(language):
		_language = language

func _save() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({best_score = best_score, language = _language}))

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

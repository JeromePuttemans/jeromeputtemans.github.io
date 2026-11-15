extends Node2D

# GameManager (root node of main.tscn): builds the whole scene by code, runs
# the state machine, the menus, the score, the sectors, the upgrades and the
# save.
#
# TREE
#   World (Node2D, shaken)       grid, pickups, enemies, bullets, shots,
#                                well, ship, effects
#   PostFX (CanvasLayer 1)       full-screen distortion shader (post_fx.gd)
#   UI (CanvasLayer 2)           HUD
#   Transitions (CanvasLayer 3)  title, help, pause, upgrade and end screens
# STATES: TITLE -> PLAYING <-> PAUSED, PLAYING -> UPGRADE (between sectors)
#   -> PLAYING, PLAYING -> GAME_OVER or WIN. TITLE, PAUSED, GAME_OVER and WIN
#   show a menu (MENUS): up and down move, Space or Enter confirm, the mouse
#   hovers and clicks. Each screen ignores the keys for a short time after
#   it opens (INPUT_LOCK), so a Space held for the well does not pick an
#   upgrade or restart the run by accident.
# FRAME (PLAYING): ship -> well -> enemies -> bullets -> shots -> pickups ->
#   combat -> spawner -> end of sector. Delta is capped at 1/30 s; a hit
#   freezes the game for a few hundredths (hitstop); the boss explodes in
#   slow motion.
# SCORE: enemy points x multiplier. Every kill extends the chain and resets
#   its timer; multiplier = 1 + chain / chain_per_multiplier, at most
#   multiplier_max. After chain_window s without a kill the multiplier drops
#   one level; a hit on the hull breaks the whole chain.
#   A release that kills n >= 2 enemies adds multikill_bonus x n x n.
#   Shards and grazes also score (shard_points, graze_points) x multiplier.
#   A sling hitting a boss tears a shard off it (boss_shard_chance), so the
#   Nova also charges during the boss fights.
# NOVA: shards and grazes fill the gauge (gravity_field.gd); the nova key
#   starts it when full. The ship is untouchable during the Nova and for
#   0.6 s after.
# SAVE: best score, best sector, language, sound and music in
#   user://gravshift_save.json.

enum GameState { TITLE, PLAYING, PAUSED, UPGRADE, GAME_OVER, WIN }

signal game_state_changed(state: int)

const SAVE_PATH: String = "user://gravshift_save.json"
const SETTINGS_PATH: String = "res://datas/settings.json"
const LANGUAGES: Array[String] = ["fr", "en"]
const ARENA_SIZE: Vector2 = Vector2(1280.0, 720.0)
const MENUS: Dictionary = {
	0: ["play", "help", "language", "sound", "music"],
	2: ["resume", "quit"],
	4: ["retry", "title"],
	5: ["retry", "title"],
}
const INPUT_LOCK: Dictionary = {3: 0.45, 4: 1.0, 5: 1.0}

const ENEMY_SCRIPTS: Dictionary = {
	"drone": preload("res://scripts/entities/enemy_drone.gd"),
	"gunner": preload("res://scripts/entities/enemy_gunner.gd"),
	"spinner": preload("res://scripts/entities/enemy_spinner.gd"),
	"lancer": preload("res://scripts/entities/enemy_lancer.gd"),
	"brute": preload("res://scripts/entities/enemy_brute.gd"),
	"mine": preload("res://scripts/entities/enemy_mine.gd"),
	"swarm": preload("res://scripts/entities/enemy_swarm.gd"),
	"siphon": preload("res://scripts/entities/enemy_siphon.gd"),
	"guardian": preload("res://scripts/entities/boss_guardian.gd"),
	"singularity": preload("res://scripts/entities/boss_singularity.gd"),
}
const Upgrades = preload("res://scripts/core/upgrades.gd")

var current_state: int = GameState.TITLE
var settings: Dictionary = {}
var gameplay: Dictionary = {}
var score: int = 0
var best_score: int = 0
var best_wave: int = 0
var chain: int = 0
var chain_left: float = 0.0
var wave_number: int = 0
var boss: EnemyBase = null
var offer: Array[String] = []
var offer_index: int = 0
var levels: Dictionary = {}
var best_volley: int = 0
var new_best: bool = false
var muted: bool = false
var music_muted: bool = false
var menu_index: int = 0
var help_open: bool = false
var state_time: float = 0.0
var kills: int = 0
var grazes: int = 0
var novas: int = 0
var run_time: float = 0.0
var sector_report: Dictionary = {}
var gains: Array[Dictionary] = []

var _strings: Dictionary = {}
var _language: String = "fr"
var _input: Node = null
var _sfx: Node = null
var _music: Node = null
var _world: Node2D = null
var _grid: Node2D = null
var _pickups: Node2D = null
var _enemy_layer: Node2D = null
var _bullets: Node2D = null
var _shots: Node2D = null
var _well: GravityField = null
var _ship: Node2D = null
var _effects: Effects = null
var _post: PostFX = null
var _spawner: Node = null
var _combat: Node = null
var _hud: Control = null
var _screens: Control = null
var _enemies: Array[EnemyBase] = []
var _next_uid: int = 1
var _trauma: float = 0.0
var _hitstop: float = 0.0
var _slowmo: float = 0.0
var _volley_kills: int = 0
var _volley_timer: float = -1.0
var _end_timer: float = -1.0
var _clear_timer: float = -1.0
var _title_time: float = 0.0
var _tip_shown: bool = false
var _nova_tip_shown: bool = false
var _swallowed: int = 0
var _shard_streak: int = 0
var _shard_timer: float = 0.0
var _heartbeat: float = 0.0
var _recent_warnings: Array[Dictionary] = []
var _sector_score: int = 0
var _sector_captured: int = 0
var _sector_kills: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings = _load_json(SETTINGS_PATH)
	gameplay = settings.get("gameplay", {}) as Dictionary
	_load_save()
	_load_strings()
	_build_scene()
	_set_state(GameState.TITLE)

# =============================================================================
# SCENE CONSTRUCTION
# =============================================================================

func _build_scene() -> void:
	_input = preload("res://scripts/core/input_manager.gd").new()
	_input.name = "InputManager"
	add_child(_input)
	_sfx = preload("res://scripts/core/sfx_manager.gd").new()
	_sfx.name = "SfxManager"
	add_child(_sfx)
	_sfx.set("muted", muted)
	_music = preload("res://scripts/core/music.gd").new()
	_music.name = "Music"
	add_child(_music)
	_music.set("muted", music_muted)
	_music.set("volume_db", float(gameplay.get("music_volume_db", -15.0)))
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_grid = preload("res://scripts/core/space_grid.gd").new()
	_grid.name = "SpaceGrid"
	_world.add_child(_grid)
	_grid.call("setup", ARENA_SIZE)
	_pickups = preload("res://scripts/core/pickups.gd").new()
	_pickups.name = "Pickups"
	_pickups.set("gm", self)
	_world.add_child(_pickups)
	_pickups.call("setup", gameplay)
	_enemy_layer = Node2D.new()
	_enemy_layer.name = "Enemies"
	_world.add_child(_enemy_layer)
	_shots = preload("res://scripts/core/shots.gd").new()
	_shots.name = "Shots"
	_world.add_child(_shots)
	_bullets = preload("res://scripts/core/bullet_field.gd").new()
	_bullets.name = "EnemyBullets"
	_world.add_child(_bullets)
	_well = GravityField.new()
	_well.name = "GravityField"
	_well.gm = self
	_well.material = Effects.additive_material()
	_world.add_child(_well)
	_well.setup(gameplay)
	_well.twist_activated.connect(_on_twist)
	_ship = preload("res://scripts/entities/player.gd").new()
	_ship.name = "Player"
	_ship.set("gm", self)
	_world.add_child(_ship)
	_ship.call("setup", gameplay)
	_effects = Effects.new()
	_effects.name = "Effects"
	_effects.screen_size = ARENA_SIZE
	_world.add_child(_effects)
	_spawner = preload("res://scripts/core/spawner.gd").new()
	_spawner.name = "Spawner"
	_spawner.set("gm", self)
	_spawner.set("waves", settings.get("waves", []))
	add_child(_spawner)
	_combat = preload("res://scripts/core/combat.gd").new()
	_combat.name = "Combat"
	_combat.set("gm", self)
	add_child(_combat)
	_combat.call("setup", gameplay)
	var post_layer := CanvasLayer.new()
	post_layer.name = "PostFX"
	post_layer.layer = 1
	add_child(post_layer)
	_post = PostFX.new()
	_post.name = "Distortion"
	_post.arena = ARENA_SIZE
	post_layer.add_child(_post)
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 2
	add_child(ui)
	_hud = preload("res://scripts/ui/hud.gd").new()
	_hud.name = "HUD"
	_hud.set("gm", self)
	ui.add_child(_hud)
	var transitions := CanvasLayer.new()
	transitions.name = "Transitions"
	transitions.layer = 3
	add_child(transitions)
	_screens = preload("res://scripts/ui/screens.gd").new()
	_screens.name = "Screens"
	_screens.set("gm", self)
	transitions.add_child(_screens)
	game_state_changed.connect(Callable(_hud, "on_state_changed"))
	game_state_changed.connect(Callable(_screens, "on_state_changed"))

# =============================================================================
# STATES
# =============================================================================

func _set_state(state: int) -> void:
	current_state = state
	state_time = 0.0
	menu_index = 0
	help_open = false
	get_tree().paused = state == GameState.PAUSED
	_ship.visible = state != GameState.TITLE
	_well.visible = state != GameState.TITLE
	_music.call("set_muffled", state == GameState.PAUSED or state == GameState.UPGRADE)
	if state == GameState.TITLE:
		_grid.call("set_sector", 1)
	game_state_changed.emit(state)

func _start_run() -> void:
	_clear_field()
	score = 0
	chain = 0
	chain_left = 0.0
	wave_number = 0
	best_volley = 0
	kills = 0
	grazes = 0
	novas = 0
	run_time = 0.0
	new_best = false
	gains.clear()
	levels.clear()
	_well.reset()
	_ship.call("reset")
	_pickups.set("magnet_mult", 1.0)
	_ship.position = ARENA_SIZE * Vector2(0.5, 0.72)
	_end_timer = -1.0
	_clear_timer = -1.0
	_slowmo = 0.0
	_hitstop = 0.0
	_set_state(GameState.PLAYING)
	_next_wave()

func _next_wave() -> void:
	wave_number += 1
	var wave: Dictionary = (settings.get("waves", []) as Array)[wave_number - 1] as Dictionary
	_spawner.call("start_wave", wave_number - 1)
	_grid.call("set_sector", wave_number)
	_sector_score = score
	_sector_captured = _well.captured_total
	_sector_kills = kills
	if wave.has("boss"):
		var kind: String = str(wave["boss"])
		_hud.call("banner", text("feedback", "warning"), text("gameplay", "boss_" + kind), text("gameplay", "boss_%s_sub" % kind), Color(1.0, 0.4, 0.55), 3.4)
		sfx("warning")
	else:
		var sub: String = text("help", "capture") if wave_number == 1 and not _tip_shown else ""
		_hud.call("banner", text("feedback", "sector_start", {n = wave_number}), "", sub, Color(0.5, 0.95, 1.0), 2.4 if sub.is_empty() else 4.0)
		sfx("wave_start")

func _clear_field() -> void:
	for e in _enemies:
		e.queue_free()
	_enemies.clear()
	boss = null
	_bullets.call("clear_all")
	_shots.call("clear_all")
	_pickups.call("clear_all")
	_effects.clear()
	_post.clear()
	_recent_warnings.clear()

func _wave_cleared() -> void:
	_bullets.call("clear_all")
	best_wave = maxi(best_wave, wave_number)
	if wave_number >= int(_spawner.call("total")):
		_finish(true)
		return
	sfx("wave_clear")
	sector_report = {kills = kills - _sector_kills, captured = _well.captured_total - _sector_captured, points = score - _sector_score}
	offer = Upgrades.offer(settings.get("upgrades", []) as Array, levels, 3)
	offer_index = 0
	if offer.is_empty():
		_next_wave()
		return
	_set_state(GameState.UPGRADE)

func _choose_upgrade(index: int) -> void:
	if index < 0 or index >= offer.size():
		return
	_screens.call("on_chosen", index)
	Upgrades.apply(offer[index], _well, _ship, _pickups, levels)
	sfx("upgrade")
	_set_state(GameState.PLAYING)
	_next_wave()

func _finish(won: bool) -> void:
	best_wave = maxi(best_wave, wave_number if won else wave_number - 1)
	new_best = score > best_score
	if new_best:
		best_score = score
	_save()
	_set_state(GameState.WIN if won else GameState.GAME_OVER)

# =============================================================================
# MENUS
# =============================================================================

func menu_items() -> Array:
	if current_state == GameState.TITLE and help_open:
		return []
	return MENUS.get(current_state, []) as Array

func menu_label(id: String) -> String:
	var on: String = text("ui", "state_on")
	var off: String = text("ui", "state_off")
	match id:
		"language":
			return text("ui", "menu_language")
		"sound":
			return text("ui", "menu_sound", {state = off if muted else on})
		"music":
			return text("ui", "menu_music", {state = off if music_muted else on})
	return text("ui", "menu_" + id)

func menu_activate(id: String) -> void:
	match id:
		"play", "retry":
			sfx("ui_select")
			_start_run()
		"help":
			sfx("ui_select")
			help_open = true
		"language":
			_cycle_language()
		"sound":
			_toggle_sound()
		"music":
			_toggle_music()
		"resume":
			sfx("ui_select")
			_set_state(GameState.PLAYING)
		"quit", "title":
			sfx("ui_back")
			_clear_field()
			_set_state(GameState.TITLE)

func input_locked() -> bool:
	return state_time < float(INPUT_LOCK.get(current_state, 0.0))

## Mouse on a menu line (screens.gd).
func menu_hover(index: int) -> void:
	if index != menu_index:
		menu_index = index
		sfx("ui_move", 1.0, 0.0)

func menu_click(index: int) -> void:
	var items: Array = menu_items()
	if input_locked() or index < 0 or index >= items.size():
		return
	menu_index = index
	menu_activate(str(items[index]))

func close_help() -> void:
	if help_open:
		help_open = false
		sfx("ui_back")

# =============================================================================
# FRAME
# =============================================================================

func _process(delta: float) -> void:
	var real: float = minf(delta, 1.0 / 30.0)
	state_time += real
	_trauma = maxf(_trauma - float(gameplay.get("shake_decay", 2.4)) * real, 0.0)
	var amount: float = _trauma * _trauma * float(gameplay.get("shake_pixels", 14.0))
	_world.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount
	_update_grid_attractors()
	_music.set("intensity", _music_intensity())
	if current_state == GameState.PAUSED:
		return
	_post.step(real)
	_grid.call("step", real)
	_effects.step(real)
	for g in gains:
		g["t"] = float(g["t"]) + real
	while not gains.is_empty() and float(gains[0]["t"]) > 1.6:
		gains.pop_front()
	if current_state == GameState.TITLE:
		_title_time += real
		return
	if current_state != GameState.PLAYING:
		return
	if _hitstop > 0.0:
		_hitstop -= real
		return
	var dt: float = real
	if _slowmo > 0.0:
		_slowmo -= real
		dt *= 0.3
	_step_play(dt, real)

func _step_play(dt: float, real: float) -> void:
	run_time += dt
	var pull := Vector2.ZERO
	if boss != null and boss.alive and boss.has_method("ship_pull"):
		pull = boss.call("ship_pull", _ship.position) as Vector2
	var alive: bool = bool(_ship.get("alive"))
	if alive and bool(_input.call("nova_pressed")):
		_try_nova()
	_ship.call("step", dt, _input.call("move_vector") if alive else Vector2.ZERO, _well.active, pull, _well.nova_active())
	_well.global_position = _ship.global_position
	_well.step(dt, bool(_input.call("well_held")) and alive, alive)
	for i in range(_enemies.size() - 1, -1, -1):
		var e: EnemyBase = _enemies[i]
		if e.alive:
			e.step(dt)
		if not e.alive or e.position.distance_to(ARENA_SIZE * 0.5) > 1600.0:
			_enemies.remove_at(i)
			e.queue_free()
	_bullets.call("step", dt, _well, gravity_sinks())
	_shots.call("step", dt, _enemies)
	_pickups.call("step", dt, _ship.position, _well.active, _well.pull_radius(), alive)
	if _well.nova_active():
		_effects.inflow(_ship.position, Color(0.78, 0.62, 1.0), 3, 420.0)
	if alive:
		_combat.call("step", dt)
	_spawner.call("step", dt)
	if chain_left > 0.0:
		chain_left -= dt
		if chain_left <= 0.0:
			_decay_chain()
	if _volley_timer >= 0.0:
		_volley_timer -= dt
		if _volley_timer < 0.0:
			_close_volley()
	if _shard_timer > 0.0:
		_shard_timer -= dt
		if _shard_timer <= 0.0:
			_shard_streak = 0
	_update_danger(real, alive)
	if _end_timer >= 0.0:
		_end_timer -= real
		if _end_timer < 0.0:
			_finish(false)
		return
	if _clear_timer >= 0.0:
		_clear_timer -= real
		if _clear_timer < 0.0:
			_wave_cleared()
		return
	if bool(_spawner.call("done_spawning")) and _enemies.is_empty():
		_clear_timer = 1.4
		if wave_number < int(_spawner.call("total")):
			_hud.call("banner", text("feedback", "wave_clear"), "", "", Color(0.6, 1.0, 0.75), 1.4)

## Last hull point: the screen edges pulse red with a heartbeat.
func _update_danger(real: float, alive: bool) -> void:
	if alive and int(_ship.get("hp")) == 1:
		_heartbeat -= real
		if _heartbeat <= 0.0:
			_heartbeat = 1.1
			sfx("heartbeat", 1.0, 0.0)
		var beat: float = 1.1 - _heartbeat
		_post.danger = 0.35 + 0.65 * exp(-beat * 6.0)
	else:
		_post.danger = maxf(_post.danger - real * 2.0, 0.0)

func _music_intensity() -> float:
	match current_state:
		GameState.PLAYING:
			if boss != null and boss.alive:
				return 1.0
			if not bool(_ship.get("alive")):
				return 0.0
			return clampf(0.35 + int(_bullets.call("count")) / 90.0 + _enemies.size() / 24.0, 0.35, 1.0)
		GameState.PAUSED, GameState.UPGRADE:
			return 0.55
	return 0.0

func _update_grid_attractors() -> void:
	var list: Array[Dictionary] = []
	if current_state == GameState.TITLE or current_state == GameState.GAME_OVER or current_state == GameState.WIN:
		var c: Vector2 = ARENA_SIZE * 0.5 + Vector2(cos(_title_time * 0.5) * 300.0, sin(_title_time * 0.7) * 160.0)
		list.append({pos = c, strength = 1800.0, radius = 260.0})
	elif bool(_ship.get("alive")):
		if _well.nova_active():
			list.append({pos = _ship.position, strength = 6500.0, radius = 560.0})
		else:
			var strength: float = 3200.0 if _well.active else 500.0
			list.append({pos = _ship.position, strength = strength, radius = _well.pull_radius() * 1.1})
	for e in _enemies:
		if e.alive and e.kind == "siphon" and e.entered:
			list.append({pos = e.position, strength = 1500.0, radius = 150.0})
	if boss != null and boss.alive and boss.kind == "singularity":
		list.append({pos = boss.position, strength = 3600.0, radius = 520.0})
	_grid.set("attractors", list)

# =============================================================================
# CALLS FROM THE SUBSYSTEMS
# =============================================================================

func arena_rect() -> Rect2:
	return Rect2(Vector2.ZERO, ARENA_SIZE)

func ship_position() -> Vector2:
	return _ship.position

func ship_node() -> Node2D:
	return _ship

func shots_node() -> Node:
	return _shots

func bullets_node() -> Node:
	return _bullets

func well_node() -> GravityField:
	return _well

func live_enemies() -> Array:
	var out: Array = []
	for e in _enemies:
		if e.alive and e.entered:
			out.append(e)
	return out

## Enemy gravity wells that pull the free pellets (the Siphon).
func gravity_sinks() -> Array:
	var out: Array = []
	for e in _enemies:
		if e.alive and e.has_method("sink"):
			var s: Dictionary = e.call("sink") as Dictionary
			if not s.is_empty():
				out.append(s)
	return out

func nearest_enemy(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for e in _enemies:
		if e.alive and e.entered:
			var d: float = e.position.distance_squared_to(from)
			if d < best_d:
				best_d = d
				best = e
	return best

func well_pull(pos: Vector2, mass: float) -> Vector2:
	return _well.pull_on(pos, mass)

func bullet_speed(heavy: bool) -> float:
	return float(gameplay.get("heavy_bullet_speed" if heavy else "enemy_bullet_speed", 180.0))

func spawn_bullet(at: Vector2, velocity: Vector2, heavy: bool) -> void:
	_bullets.call("spawn", at, velocity, 1 if heavy else 0)

func spawn_enemy_at(kind: String, at: Vector2) -> void:
	var table: Dictionary = settings.get("enemies", {}) as Dictionary
	if not table.has(kind) or not ENEMY_SCRIPTS.has(kind):
		return
	var e: EnemyBase = (ENEMY_SCRIPTS[kind] as GDScript).new() as EnemyBase
	e.setup(_next_uid, kind, table[kind] as Dictionary, self)
	_next_uid += 1
	e.position = at
	_enemy_layer.add_child(e)
	_enemies.append(e)
	if e.boss:
		boss = e

## An enemy is about to enter at `at` (spawner.gd, 0.9 s ahead).
func spawn_warning(at: Vector2, kind: String) -> void:
	for w in _recent_warnings:
		if (w["pos"] as Vector2).distance_to(at) < 70.0 and state_time - float(w["t"]) < 0.8:
			return
	_recent_warnings.append({pos = at, t = state_time})
	if _recent_warnings.size() > 12:
		_recent_warnings.pop_front()
	var table: Dictionary = settings.get("enemies", {}) as Dictionary
	var color := Color(str((table.get(kind, {}) as Dictionary).get("color", "ffffff")))
	_effects.warning(at, color, 0.9)
	sfx("warp", 1.0, 0.1)

func sfx(sound: String, pitch: float = 1.0, jitter: float = 0.05) -> void:
	_sfx.call("play", sound, pitch, jitter, 0.0)

func fx_burst(at: Vector2, color: Color, count: int, speed: float) -> void:
	_effects.burst(at, color, count, speed, 3.0, 0.35)

func hitstop(duration: float) -> void:
	_hitstop = maxf(_hitstop, duration)

func add_score(points: int) -> void:
	score += points
	gains.append({v = points, t = 0.0})
	if gains.size() > 5:
		gains.pop_front()

func enemy_hit(e: EnemyBase, damage: float, by_sling: bool, at: Vector2) -> void:
	if not e.alive:
		return
	var dir: Vector2 = (e.position - at).normalized()
	_effects.directed(at, e.color, 3, -dir, 0.8, 220.0)
	e.knock(dir * (30.0 + 25.0 * damage))
	sfx("hit", 1.0, 0.12)
	if e.boss and by_sling and randf() < float(gameplay.get("boss_shard_chance", 0.15)):
		_pickups.call("spawn", at, 0, 1, 160.0)
	if by_sling and _well.shrapnel and damage > 1.0:
		_effects.ring(at, Color(0.5, 0.95, 1.0), 50.0, 0.25, 2.0)
		for other in _enemies:
			if other != e and other.alive and other.entered and other.position.distance_to(at) < 55.0 + other.radius:
				if other.damage(1.0):
					enemy_destroyed(other, true)
	if e.damage(damage):
		if by_sling:
			_volley_kills += 1
		enemy_destroyed(e, true)

func crash(a: EnemyBase, b: EnemyBase, damage: float, at: Vector2) -> void:
	sfx("crash", 1.0, 0.1)
	_effects.burst(at, Color(1.0, 0.95, 0.8), 10, 260.0, 3.0, 0.3)
	_effects.text(at + Vector2(0.0, -20.0), text("feedback", "crash"), Color(1.0, 0.85, 0.5), 14, 0.7)
	add_trauma(0.12)
	hitstop(0.025)
	if a.damage(damage):
		enemy_destroyed(a, true)
	if b.damage(damage):
		enemy_destroyed(b, true)

## A destroyed enemy: explosion, debris, shards, score (if the ship made
## it), the burst of a mine or a siphon.
func enemy_destroyed(e: EnemyBase, by_ship: bool) -> void:
	e.alive = false
	var big: bool = e.boss or e.radius >= 25.0
	_effects.explosion(e.position, e.radius, e.color)
	_effects.shatter(e.position, e.radius, e.color, e.sides)
	_grid.call("impulse", e.position, 900.0 if big else 400.0, e.radius * 5.0)
	sfx("boom" if big else "pop", 1.0, 0.12)
	add_trauma(0.6 if e.boss else (0.25 if big else 0.08))
	if big:
		_post.ripple(e.position, 0.012, 1.0, 0.35)
		hitstop(0.035)
	if e.has_method("burst"):
		e.call("burst")
	kills += 1
	if by_ship:
		var before: int = multiplier()
		chain += 1
		chain_left = float(gameplay.get("chain_window", 2.5))
		var points: int = e.points * multiplier()
		add_score(points)
		_effects.text(e.position, str(points), Color(1.0, 0.9, 0.55) if not big else Color(1.0, 0.7, 0.3), 14 if not big else 22, 0.8)
		if multiplier() > before:
			sfx("chain_up", 1.0 + 0.06 * multiplier(), 0.0)
		var shards: int = int(gameplay.get("boss_shards", 40)) if e.boss else clampi(roundi(float(e.points) / float(gameplay.get("shards_per_points", 40))), 1, int(gameplay.get("shards_max", 14)))
		_pickups.call("spawn", e.position, 0, shards, 140.0 + e.radius * 3.0)
		if randf() < float(gameplay.get("repair_drop_chance", 0.06)) and int(_ship.get("hp")) < int(_ship.get("hp_max")):
			_pickups.call("spawn", e.position, 1, 1, 60.0)
	if e.boss:
		_slowmo = 1.4
		_effects.flash(Color(1.0, 0.9, 1.0), 0.8)
		_post.ripple(e.position, 0.04, 0.8, 0.9)
		_post.aberrate(0.015)
		sfx("boss_death")
		for p in _bullets.call("clear_all") as PackedVector2Array:
			_effects.burst(p, Color(1.0, 0.6, 0.3), 1, 60.0, 3.0, 0.3)
		boss = null

## A pickup reached the ship (pickups.gd): 0 = shard, 1 = repair.
func collect_pickup(kind: int, at: Vector2) -> void:
	if kind == 1:
		_repair(at)
		return
	add_score(int(gameplay.get("shard_points", 10)) * multiplier())
	_well.add_nova(float(gameplay.get("shard_nova", 1.4)))
	_shard_streak += 1
	_shard_timer = 0.35
	sfx("shard", 1.0 + minf(_shard_streak, 24) * 0.035, 0.0)
	_effects.burst(at, Color(0.5, 0.9, 1.0), 2, 60.0, 2.0, 0.2)

## A bullet left the graze ring around the ship without hitting it.
func on_graze(at: Vector2, kind: int) -> void:
	grazes += 1
	var heavy: bool = kind == 1
	add_score(int(gameplay.get("graze_points", 25)) * multiplier())
	_well.add_nova(float(gameplay.get("graze_nova_heavy" if heavy else "graze_nova_pellet", 1.5)))
	_effects.directed(at, Color(1.0, 1.0, 1.0), 4 if heavy else 2, (at - _ship.position).normalized(), 0.6, 180.0)
	if heavy:
		_effects.text(at + Vector2(0.0, -14.0), text("feedback", "graze"), Color(0.85, 0.95, 1.0), 13, 0.6)
	sfx("graze", 1.2 if heavy else 1.0, 0.08)

func on_nova_ready() -> void:
	sfx("nova_ready", 1.0, 0.0)
	var label: String = text("feedback", "nova_ready") if _nova_tip_shown else text("feedback", "nova_tip")
	_nova_tip_shown = true
	_effects.text(_ship.position + Vector2(0.0, -60.0), label, Color(0.85, 0.75, 1.0), 18, 2.0)

func _try_nova() -> void:
	if not _well.start_nova():
		return
	novas += 1
	_swallowed = 0
	var duration: float = float(gameplay.get("nova_duration", 1.2)) * _well.nova_length
	_ship.set("invulnerable", maxf(float(_ship.get("invulnerable")), duration + 0.6))
	_ship.call("pulse", 1.0)
	sfx("nova_charge", 1.0, 0.0)
	_effects.ring(_ship.position, Color(0.78, 0.62, 1.0), 520.0, duration, 4.0, true)
	_effects.flash(Color(0.6, 0.45, 1.0), 0.35)
	_effects.text(_ship.position + Vector2(0.0, -70.0), text("feedback", "nova"), Color(0.9, 0.8, 1.0), 30, 1.0)
	_post.ripple(_ship.position, -0.02, 0.9, 0.5)
	_post.aberrate(0.008)
	add_trauma(0.3)
	hitstop(0.05)

## A heavy orb swallowed by the Nova.
func on_swallow(at: Vector2) -> void:
	_swallowed += 1
	_effects.burst(at, Color(1.0, 0.4, 0.5), 5, 120.0, 3.0, 0.3)
	sfx("swallow", 1.0 + minf(_swallowed, 10) * 0.05, 0.0)

## An enemy touching the ship during the Nova is crushed.
func nova_crush(e: EnemyBase) -> void:
	if not e.alive:
		return
	sfx("crash", 0.8, 0.1)
	enemy_destroyed(e, true)

func boss_phase(b: EnemyBase, n: int) -> void:
	_hud.call("banner", text("feedback", "phase", {n = n}), text("gameplay", "boss_" + b.kind), "", Color(1.0, 0.45, 0.8), 1.8)
	sfx("phase")
	_effects.flash(Color(1.0, 0.6, 0.9), 0.4)
	_effects.ring(b.position, b.color, b.radius * 5.0, 0.6, 5.0)
	_post.ripple(b.position, 0.03, 0.9, 0.8)
	_post.aberrate(0.01)
	add_trauma(0.45)
	hitstop(0.12)

func _repair(at: Vector2) -> void:
	_ship.set("hp", mini(int(_ship.get("hp")) + 1, int(_ship.get("hp_max"))))
	_effects.text(at + Vector2(0.0, -24.0), text("feedback", "repair"), Color(0.5, 1.0, 0.6), 18, 1.2)
	_effects.ring(_ship.position, Color(0.4, 1.0, 0.55), 60.0, 0.4, 3.0)
	sfx("repair")

func multiplier() -> int:
	var step: float = float(maxi(int(gameplay.get("chain_per_multiplier", 5)), 1))
	return mini(1 + int(floorf(chain / step)), int(gameplay.get("multiplier_max", 8)))

## The chain timer ran out: the multiplier loses one level (the chain is
## kept at the start of that level, with a fresh timer) until it is back to x1.
func _decay_chain() -> void:
	var step: int = maxi(int(gameplay.get("chain_per_multiplier", 5)), 1)
	var level: int = mini(int(floorf(float(chain) / step)), int(gameplay.get("multiplier_max", 8)) - 1)
	chain = maxi(level - 1, 0) * step
	chain_left = float(gameplay.get("chain_window", 2.5)) if chain > 0 else 0.0

func chain_ratio() -> float:
	return clampf(chain_left / float(gameplay.get("chain_window", 2.5)), 0.0, 1.0)

func ship_hit() -> void:
	chain = 0
	chain_left = 0.0
	add_trauma(0.7)
	hitstop(0.08)
	_effects.flash(Color(1.0, 0.3, 0.3), 0.5)
	_effects.burst(_ship.position, Color(0.4, 0.9, 1.0), 20, 300.0, 3.0, 0.5)
	_post.aberrate(0.011)
	_post.ripple(_ship.position, 0.015, 1.2, 0.3)
	if bool(_ship.call("hit")):
		sfx("death")
		_effects.explosion(_ship.position, 40.0, Color(0.4, 0.9, 1.0))
		_effects.shatter(_ship.position, 16.0, Color(0.45, 0.95, 1.0), 6)
		_grid.call("impulse", _ship.position, 1400.0, 300.0)
		_post.ripple(_ship.position, 0.035, 0.7, 0.8)
		_slowmo = 1.0
		_end_timer = 1.6
	else:
		sfx("player_hit")
		_bullets.call("shockwave", _ship.position, 160.0, 320.0)
		if int(_ship.get("hp")) == 1:
			_heartbeat = 0.6
			_effects.text(_ship.position + Vector2(0.0, -50.0), text("feedback", "last_hull"), Color(1.0, 0.45, 0.45), 16, 1.6)

func on_release(at: Vector2, flung: int, radius: float, collapse: bool, from_nova: bool) -> void:
	_bullets.call("shockwave", at, radius, 300.0)
	for e in _enemies:
		if e.alive and not e.boss:
			var d: Vector2 = e.position - at
			var dist: float = d.length()
			if dist < radius and dist > 1.0:
				e.vel += d / dist * (520.0 if from_nova else 320.0) / e.mass
				if _well.recoil > 1.0 or from_nova:
					e.stun = 1.0
	_grid.call("impulse", at, (1600.0 if from_nova else 700.0) + flung * 40.0, radius * 2.0)
	_effects.ring(at, Color(0.78, 0.62, 1.0) if from_nova else Color(0.4, 0.95, 1.0), radius, 0.45 if from_nova else 0.35, 6.0 if from_nova else 4.0)
	_ship.call("pulse", 1.0 if from_nova else minf(0.3 + flung * 0.04, 0.8))
	if from_nova:
		sfx("nova_blast", 1.0, 0.0)
		_post.ripple(at, 0.04, 1.1, 0.95)
		_post.aberrate(0.009)
		_effects.flash(Color(0.85, 0.75, 1.0), 0.45)
		_effects.burst(at, Color(0.8, 0.7, 1.0), 40, 520.0, 4.0, 0.6)
		add_trauma(0.55)
		hitstop(0.06)
		if _swallowed > 0:
			_effects.text(at + Vector2(0.0, -80.0), text("feedback", "swallowed", {n = _swallowed}), Color(1.0, 0.6, 0.7), 18, 1.4)
	elif flung > 0:
		sfx("fling", 1.0 + minf(flung, 20) * 0.01, 0.0)
		_post.ripple(at, 0.008 + minf(flung, 20) * 0.0007, 1.3, 0.4)
		add_trauma(0.08 + flung * 0.012)
	else:
		sfx("shock", 1.0, 0.05)
		_post.ripple(at, 0.006, 1.4, 0.25)
	if flung > 0:
		_volley_kills = 0
		_volley_timer = 1.3
	if collapse:
		sfx("collapse")
		_effects.text(at + Vector2(0.0, -50.0), text("feedback", "collapse"), Color(1.0, 0.5, 0.4), 16, 1.0)

func _close_volley() -> void:
	if _volley_kills >= 2:
		var bonus: int = int(gameplay.get("multikill_bonus", 60)) * _volley_kills * _volley_kills
		add_score(bonus)
		best_volley = maxi(best_volley, _volley_kills)
		_effects.text(_ship.position + Vector2(0.0, -60.0), text("feedback", "multikill", {n = _volley_kills}) + "  +" + str(bonus), Color(0.5, 1.0, 1.0), 22, 1.4)
		if _volley_kills >= 5:
			_post.aberrate(0.006)
	_volley_kills = 0

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _on_twist() -> void:
	_tip_shown = true
	_effects.text(_ship.position + Vector2(0.0, -70.0), text("feedback", "twist_tip"), Color(0.6, 1.0, 1.0), 18, 2.5)

# =============================================================================
# INPUT
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if not event.is_pressed() or event.is_echo():
		return
	if input_locked():
		return
	match current_state:
		GameState.TITLE:
			if help_open:
				if event.is_action_pressed("pause") or event.is_action_pressed("confirm"):
					close_help()
				return
			if _menu_nav(event):
				return
			if _is_key(event, KEY_L):
				_cycle_language()
			elif _is_key(event, KEY_M):
				_toggle_sound()
		GameState.PLAYING:
			if event.is_action_pressed("pause"):
				sfx("ui_select")
				_set_state(GameState.PAUSED)
		GameState.PAUSED:
			if event.is_action_pressed("pause"):
				sfx("ui_select")
				_set_state(GameState.PLAYING)
			elif _is_key(event, KEY_Q):
				menu_activate("quit")
			else:
				_menu_nav(event)
		GameState.UPGRADE:
			if event.is_action_pressed("move_left"):
				offer_index = posmod(offer_index - 1, offer.size())
				sfx("ui_move")
			elif event.is_action_pressed("move_right"):
				offer_index = posmod(offer_index + 1, offer.size())
				sfx("ui_move")
			elif event.is_action_pressed("confirm"):
				_choose_upgrade(offer_index)
			elif event is InputEventKey:
				var k: int = (event as InputEventKey).physical_keycode
				if k >= KEY_1 and k <= KEY_3:
					_choose_upgrade(k - KEY_1)
		GameState.GAME_OVER, GameState.WIN:
			if event.is_action_pressed("pause"):
				menu_activate("title")
			else:
				_menu_nav(event)

## Up, down and confirm on the current menu; true when the event was used.
func _menu_nav(event: InputEvent) -> bool:
	var items: Array = menu_items()
	if items.is_empty():
		return false
	if event.is_action_pressed("move_up"):
		menu_index = posmod(menu_index - 1, items.size())
		sfx("ui_move")
		return true
	if event.is_action_pressed("move_down"):
		menu_index = posmod(menu_index + 1, items.size())
		sfx("ui_move")
		return true
	if event.is_action_pressed("confirm"):
		menu_activate(str(items[clampi(menu_index, 0, items.size() - 1)]))
		return true
	return false

func _is_key(event: InputEvent, key: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).physical_keycode == key

func choose_from_click(index: int) -> void:
	if current_state == GameState.UPGRADE and not input_locked():
		_choose_upgrade(index)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and current_state == GameState.PLAYING:
		_set_state(GameState.PAUSED)

# =============================================================================
# STRINGS, SETTINGS, SAVE
# =============================================================================

func text(section: String, key: String, replacements: Dictionary = {}) -> String:
	var table: Dictionary = (_strings.get(section, {}) as Dictionary)
	var s: String = str(table.get(key, "[%s.%s]" % [section, key]))
	for k in replacements:
		s = s.replace("{%s}" % k, str(replacements[k]))
	return s

func language() -> String:
	return _language

func _cycle_language() -> void:
	_language = LANGUAGES[(LANGUAGES.find(_language) + 1) % LANGUAGES.size()]
	_load_strings()
	_save()
	sfx("ui_move")

func _toggle_sound() -> void:
	muted = not muted
	_sfx.set("muted", muted)
	_save()
	sfx("ui_move")

func _toggle_music() -> void:
	music_muted = not music_muted
	_music.set("muted", music_muted)
	_save()
	sfx("ui_move")

func _load_strings() -> void:
	_strings = _load_json("res://datas/strings_%s.json" % _language)

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("GameManager: missing " + path)
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		push_error("GameManager: invalid JSON " + path)
		return {}
	return json.data as Dictionary

func _load_save() -> void:
	_language = str((settings.get("meta", {}) as Dictionary).get("language", "fr"))
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(SAVE_PATH)) != OK or not (json.data is Dictionary):
		return
	var data: Dictionary = json.data as Dictionary
	best_score = int(data.get("best_score", 0))
	best_wave = int(data.get("best_wave", 0))
	_language = str(data.get("language", _language))
	muted = bool(data.get("muted", false))
	music_muted = bool(data.get("music_muted", false))

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({best_score = best_score, best_wave = best_wave, language = _language, muted = muted, music_muted = music_muted}))

# =============================================================================
# READ-ONLY ACCESS FOR THE UI
# =============================================================================

func ship_hp() -> int:
	return int(_ship.get("hp"))

func ship_hp_max() -> int:
	return int(_ship.get("hp_max"))

func ship_alive() -> bool:
	return bool(_ship.get("alive"))

func total_waves() -> int:
	return int(_spawner.call("total"))

func enemies_left() -> int:
	return _enemies.size() + int(_spawner.call("remaining"))

## Share of the current sector already destroyed (0..1).
func sector_progress() -> float:
	var size: int = int(_spawner.get("sector_size"))
	if size <= 0:
		return 0.0
	return clampf(1.0 - float(enemies_left()) / size, 0.0, 1.0)

func captured_total() -> int:
	return _well.captured_total

func is_boss_wave(n: int) -> bool:
	var waves: Array = settings.get("waves", []) as Array
	return n >= 1 and n <= waves.size() and (waves[n - 1] as Dictionary).has("boss")

## Letter for the final score (settings.json "ranks", highest first).
func rank() -> String:
	for entry in settings.get("ranks", []) as Array:
		var pair: Array = entry as Array
		if score >= int(pair[1]):
			return str(pair[0])
	return "D"

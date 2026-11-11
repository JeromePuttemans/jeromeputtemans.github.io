# =============================================================================
# Game.gd — The play field: runs a stage, collisions, score, bombs, bosses
# =============================================================================
# One frame (delta capped at 1/30 s, times the slow-motion factor):
#   stage timeline -> player -> shots -> enemies -> enemy bullets -> bomb
#   -> shots vs enemies -> bullets and ships vs player -> items.
#
# COLLISIONS are circle tests on squared distances: shot vs enemy radius,
# bullet vs the player's small hitbox (see Bullets.gd), enemy body vs
# hitbox. Shots move in two halves per frame when the frame is long, so a
# fast shot cannot jump over a small enemy.
#
# GAME FEEL
#   hitstop      the field freezes a few hundredths of a second on large
#                kills and on a lost life, the impact reads as heavy
#   slow motion  the boss explodes at 35 % speed for 1.6 s
#   shake        trauma (0..1) per impact; offset = random x trauma^2 x
#                camera_shake px applied to the field content
#   cancel       a large enemy's bullets, all bullets at a broken boss
#                phase and everything the bomb touches turn into shards
# =============================================================================

class_name Game
extends Node2D

signal finished(cleared: bool)
signal boss_changed(boss: Enemy)
signal banner(key: String, style: String)

var field := Vector2(540.0, 720.0)
var content: Node2D = null
var background: Background = null
var bullets: Bullets = null
var shots: Shots = null
var items: Items = null
var effects: Effects = null
var popups: Popups = null
var player: Player = null
var stage: Stage = null
var enemies: Array[Enemy] = []
var boss: Enemy = null
var running: bool = false

var _enemy_types: Dictionary = {}
var _stage_data: Dictionary = {}
var _entities: Node2D = null
var _next_id: int = 1
var _freeze: float = 0.0
var _slow: float = 0.0
var _trauma: float = 0.0
var _bomb_time: float = 0.0
var _bomb_center := Vector2.ZERO
var _attract: float = 0.0
var _respawn_timer: float = -1.0
var _end_timer: float = -1.0
var _end_cleared: bool = false
var _gem_streak: int = 0
var _gem_timer: float = 0.0
var _hit_sound: float = 0.0
var _boss_blasts: Array[Dictionary] = []

func _ready() -> void:
	field = Vector2(ConfigManager.get_float("field_width", 540.0), ConfigManager.get_float("field_height", 720.0))
	var raw: Variant = ConfigManager.load_json("res://data/enemies.json")
	_enemy_types = raw as Dictionary if raw is Dictionary else {}
	raw = ConfigManager.load_json("res://data/stage.json")
	_stage_data = raw as Dictionary if raw is Dictionary else {}
	content = Node2D.new()
	add_child(content)
	background = Background.new()
	background.field = field
	background.palettes = _stage_data.get("palettes", []) as Array
	content.add_child(background)
	items = Items.new()
	items.field = field
	content.add_child(items)
	_entities = Node2D.new()
	content.add_child(_entities)
	shots = Shots.new()
	shots.field = field
	content.add_child(shots)
	player = Player.new()
	player.game = self
	player.field = field
	player.position = Vector2(field.x * 0.5, field.y - 100.0)
	player.visible = false
	content.add_child(player)
	bullets = Bullets.new()
	bullets.field = field
	content.add_child(bullets)
	effects = Effects.new()
	effects.field = field
	content.add_child(effects)
	popups = Popups.new()
	content.add_child(popups)
	stage = Stage.new()
	stage.game = self
	add_child(stage)

# =============================================================================
# RUN CONTROL
# =============================================================================

func start(difficulty: String) -> void:
	GameState.new_run(difficulty)
	_clear_field()
	player.visible = true
	player.respawn()
	player.invulnerable = 1.5
	stage.setup(_stage_data)
	background.progress = 0.0
	background.warp = 1.0
	running = true
	_end_timer = -1.0
	_respawn_timer = -1.0
	GameState.set_phase(GameState.Phase.PLAYING)
	banner.emit("stage_start", "info")

func stop() -> void:
	running = false
	_clear_field()
	player.visible = false
	background.warp = 1.0

func _clear_field() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	if boss != null:
		boss = null
		boss_changed.emit(null)
	bullets.cancel_all()
	shots.clear()
	items.clear()
	effects.clear()
	popups.clear()
	_boss_blasts.clear()
	_bomb_time = 0.0
	_attract = 0.0
	_slow = 0.0
	_freeze = 0.0
	_trauma = 0.0

# =============================================================================
# FRAME
# =============================================================================

func _process(delta: float) -> void:
	var real: float = minf(delta, 1.0 / 30.0)
	_trauma = maxf(_trauma - ConfigManager.get_float("shake_decay", 2.2) * real, 0.0)
	var amount: float = _trauma * _trauma * ConfigManager.get_float("camera_shake", 12.0)
	content.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount
	background.warp = move_toward(background.warp, 1.0, real * 1.5)
	if not running:
		return
	if _freeze > 0.0:
		_freeze -= real
		return
	var scale: float = 1.0
	if _slow > 0.0:
		_slow -= real
		scale = 0.35
	var dt: float = real * scale
	if Input.is_action_just_pressed("bomb"):
		_try_bomb()
	stage.step(dt)
	player.step(dt)
	var halves: int = 3 if dt > 1.0 / 50.0 else 2
	for k in halves:
		shots.step(dt / halves)
		_collide_shots()
	for i in range(enemies.size() - 1, -1, -1):
		var e: Enemy = enemies[i]
		e.step(dt)
		if e.removed:
			enemies.remove_at(i)
			e.queue_free()
	bullets.step(dt)
	_step_bomb(dt)
	_collide_player()
	_step_items(dt)
	_step_boss_blasts(dt)
	GameState.tick(dt)
	background.progress = stage.progress()
	_hit_sound -= dt
	_gem_timer -= dt
	if _gem_timer <= 0.0:
		_gem_streak = 0
	_attract = maxf(_attract - dt, 0.0)
	if _respawn_timer >= 0.0:
		_respawn_timer -= real
		if _respawn_timer < 0.0:
			player.respawn()
	if _end_timer >= 0.0:
		_end_timer -= real
		if _end_timer < 0.0:
			running = false
			finished.emit(_end_cleared)

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func hitstop(seconds: float) -> void:
	_freeze = maxf(_freeze, seconds)

# =============================================================================
# SPAWNING
# =============================================================================

func spawn_enemy(type_id: String, params: Dictionary) -> Enemy:
	if not _enemy_types.has(type_id):
		push_warning("Game: unknown enemy " + type_id)
		return null
	var e := Enemy.new()
	e.game = self
	e.setup(type_id, _enemy_types[type_id] as Dictionary, _next_id)
	_next_id += 1
	if params.has("path"):
		e.set_path(params["path"] as PackedVector2Array)
	else:
		e.set_target(params.get("target", Vector2(field.x * 0.5, field.y * 0.2)) as Vector2)
	_entities.add_child(e)
	enemies.append(e)
	return e

func spawn_boss(type_id: String) -> void:
	var e: Enemy = spawn_enemy(type_id, {target = Vector2(field.x * 0.5, field.y * 0.2)})
	if e == null:
		return
	e.position = Vector2(field.x * 0.5, -90.0)
	boss = e
	boss_changed.emit(boss)

func warning() -> void:
	banner.emit("warning", "warning")
	Sfx.play("warning")
	background.warp = 3.5

func on_boss_ready(e: Enemy) -> void:
	banner.emit(str(e.data.get("name", "")), "boss")

# =============================================================================
# COLLISIONS
# =============================================================================

func _collide_shots() -> void:
	var i: int = shots.count() - 1
	while i >= 0:
		var p: Vector2 = shots.position_of(i)
		for e in enemies:
			if not e.alive or not e.entered:
				continue
			var r: float = e.radius + Shots.RADIUS
			if p.distance_squared_to(e.position) < r * r:
				var damage: float = shots.damage_of(i)
				shots.remove(i)
				effects.directed(p, Color(0.6, 0.9, 1.0) if e.invulnerable <= 0.0 else Color(0.6, 0.6, 0.7), 2, Vector2.UP, 0.9, 260.0)
				if _hit_sound <= 0.0:
					_hit_sound = 0.05
					Sfx.play("hit", 1.0, 0.1, -4.0)
				if e.damage(damage) and not e.is_boss:
					_kill(e)
				break
		i -= 1

func _collide_player() -> void:
	if not player.alive or player.entering > 0.0:
		return
	var core: Vector2 = player.core()
	var result: Dictionary = bullets.check_player(core, player.hitbox, player.graze_radius)
	var grazes: Array = result["grazes"] as Array
	for g in grazes:
		GameState.add_graze()
		GameState.add_points(ConfigManager.get_int("graze_value", 20))
		effects.directed(g as Vector2, Color(1.0, 1.0, 1.0), 2, ((g as Vector2) - core).normalized(), 0.6, 200.0)
	if not grazes.is_empty():
		Sfx.play("graze", 1.0 + randf_range(-0.05, 0.1), 0.0, -2.0)
	if player.invulnerable > 0.0 or _bomb_time > 0.0:
		return
	if bool(result["hit"]):
		_player_hit()
		return
	for e in enemies:
		if not e.alive or not e.entered:
			continue
		var r: float = e.radius * 0.6 + player.hitbox
		if core.distance_squared_to(e.position) < r * r:
			_player_hit()
			return

func _player_hit() -> void:
	var at: Vector2 = player.core()
	player.die()
	effects.explosion(at, 30.0, Color("6ff2ff"))
	effects.spark(at, Color(1.0, 0.6, 0.3), 30, 420.0, 0.8, 4.0)
	effects.flash(Color(1.0, 0.4, 0.4), 0.6)
	Sfx.play("death")
	add_trauma(0.85)
	hitstop(0.12)
	bullets.cancel_all()
	if GameState.power > 1:
		GameState.set_power(GameState.power - 1)
		items.spawn(at, Items.Kind.POWER, 0.6)
	if GameState.lose_life():
		_end(false, 2.4)
	else:
		_respawn_timer = 1.1

# =============================================================================
# KILLS, BOSSES, BOMB
# =============================================================================

func _kill(e: Enemy) -> void:
	e.removed = true
	var data: Dictionary = e.data
	var points: int = GameState.add_points(int(data.get("score", 100)))
	GameState.add_kill(e.large)
	popups.add(e.position + Vector2(0.0, -10.0), str(points), Color(1.0, 0.92, 0.6) if not e.large else Color(1.0, 0.75, 0.3), 13 if not e.large else 18)
	effects.explosion(e.position, e.radius, e.color())
	for k in int(data.get("gems", 1)):
		items.spawn(e.position, Items.Kind.GEM, 1.0 + k * 0.05)
	for drop in data.get("drops", []) as Array:
		match str(drop):
			"power":
				items.spawn(e.position, Items.Kind.POWER, 0.3)
			"bomb":
				items.spawn(e.position, Items.Kind.BOMB, 0.3)
			"life":
				items.spawn(e.position, Items.Kind.LIFE, 0.3)
	if data.has("revenge") and player.alive:
		var em := Emitter.new(data["revenge"] as Dictionary, e.id)
		em.step(10.0, e.position, player.core(), bullets)
	if e.large:
		Sfx.play("boom")
		add_trauma(0.3)
		hitstop(0.04)
		_cancel(bullets.cancel_owner(e.id), false)
	else:
		Sfx.play("pop", 1.0, 0.12)
		add_trauma(0.06)

## Turns bullet positions into shards. attract pulls every item to the ship.
func _cancel(positions: PackedVector2Array, attract: bool) -> void:
	if positions.is_empty():
		return
	var step: int = maxi(1, positions.size() / 120)
	for i in range(0, positions.size(), step):
		items.spawn(positions[i], Items.Kind.SHARD, 0.35)
		effects.spark(positions[i], Color(0.55, 0.85, 1.0), 1, 60.0, 0.3, 3.0)
	if positions.size() > 6:
		Sfx.play("cancel")
	if attract:
		_attract = 2.0

func on_boss_phase_end(e: Enemy, timed_out: bool) -> void:
	_cancel(bullets.cancel_all(), true)
	effects.explosion(e.position, 50.0, e.color())
	add_trauma(0.5)
	hitstop(0.08)
	var last: bool = e.phase_index + 1 >= e.phase_count()
	if not timed_out:
		var bonus: int = GameState.add_points(int(e.data.get("phase_bonus", 20000)) * (e.phase_index + 1))
		popups.add(e.position + Vector2(0.0, 60.0), StringManager.t("phase_bonus", {points = bonus}), Color(1.0, 0.85, 0.4), 20, 1.6)
	else:
		popups.add(e.position + Vector2(0.0, 60.0), StringManager.t("phase_timeout"), Color(0.75, 0.8, 0.9), 18, 1.4)
	if last:
		_boss_destroyed(e, timed_out)
	else:
		Sfx.play("phase")
		e.next_phase()

## A boss whose last phase timed out still explodes, without its score.
func _boss_destroyed(e: Enemy, timed_out: bool) -> void:
	e.next_phase()
	if not timed_out:
		var points: int = GameState.add_points(int(e.data.get("score", 100000)))
		GameState.add_kill(true)
		popups.add(e.position, str(points), Color(1.0, 0.8, 0.3), 26, 2.0)
	Sfx.play("boss_death")
	_slow = 1.6
	effects.flash(Color(1.0, 0.9, 0.8), 0.9)
	add_trauma(1.0)
	for k in 9:
		_boss_blasts.append({t = k * 0.14, pos = e.position + Vector2(randf_range(-70.0, 70.0), randf_range(-50.0, 50.0)), color = e.color()})
	for k in 24:
		items.spawn(e.position + Vector2(randf_range(-40.0, 40.0), randf_range(-30.0, 30.0)), Items.Kind.GEM, 1.6)
	for drop in e.data.get("drops", []) as Array:
		items.spawn(e.position, Items.Kind.POWER if str(drop) == "power" else (Items.Kind.BOMB if str(drop) == "bomb" else Items.Kind.LIFE), 0.5)
	_attract = 3.0
	e.removed = true
	boss = null
	boss_changed.emit(null)
	if bool(e.data.get("final", false)):
		_end(true, 4.0)

func _step_boss_blasts(dt: float) -> void:
	for i in range(_boss_blasts.size() - 1, -1, -1):
		var b: Dictionary = _boss_blasts[i]
		b["t"] = float(b["t"]) - dt
		if float(b["t"]) <= 0.0:
			effects.explosion(b["pos"] as Vector2, randf_range(30.0, 55.0), b["color"] as Color)
			Sfx.play("boom", randf_range(0.8, 1.1), 0.0)
			add_trauma(0.25)
			_boss_blasts.remove_at(i)

func _try_bomb() -> void:
	if not player.alive or player.entering > 0.0 or _bomb_time > 0.0:
		return
	if not GameState.use_bomb():
		return
	_bomb_time = ConfigManager.get_float("bomb_duration", 1.2)
	_bomb_center = player.core()
	player.invulnerable = maxf(player.invulnerable, ConfigManager.get_float("bomb_invulnerability", 2.5))
	Sfx.play("bomb")
	effects.flash(Color(0.7, 0.9, 1.0), 0.8)
	effects.ring(_bomb_center, Color(0.6, 0.95, 1.0), 900.0, 1.0, 14.0)
	effects.ring(_bomb_center, Color(1.0, 0.7, 1.0), 700.0, 0.8, 8.0)
	add_trauma(0.6)
	_attract = 2.5

func _step_bomb(dt: float) -> void:
	if _bomb_time <= 0.0:
		return
	var duration: float = ConfigManager.get_float("bomb_duration", 1.2)
	_bomb_time -= dt
	var radius: float = 1000.0 * clampf(1.0 - _bomb_time / duration, 0.0, 1.0) * 1.6
	_cancel(bullets.cancel_in_circle(_bomb_center, radius), true)
	var dps: float = ConfigManager.get_float("bomb_damage", 40.0)
	for e in enemies:
		if e.alive and e.entered and e.position.distance_to(_bomb_center) < radius:
			if e.damage(dps * dt * (0.4 if e.is_boss else 1.0)) and not e.is_boss:
				_kill(e)

# =============================================================================
# ITEMS AND END
# =============================================================================

func _step_items(dt: float) -> void:
	var magnet: float = ConfigManager.get_float("magnet_radius_focus" if player.focus else "magnet_radius", 70.0)
	var got: Array[Dictionary] = items.step(dt, player.core(), player.alive and player.entering <= 0.0, magnet, ConfigManager.get_float("collect_line", 190.0), _attract > 0.0)
	for item in got:
		var at: Vector2 = item["at"]
		match int(item["kind"]):
			Items.Kind.GEM, Items.Kind.SHARD:
				var gem: bool = int(item["kind"]) == Items.Kind.GEM
				GameState.add_points(ConfigManager.get_int("gem_value" if gem else "shard_value", 100))
				_gem_streak += 1
				_gem_timer = 0.3
				Sfx.play("gem", 1.0 + minf(_gem_streak, 24) * 0.025, 0.0, -3.0 if gem else -8.0)
			Items.Kind.POWER:
				if GameState.power < ConfigManager.get_int("power_max", 4):
					GameState.set_power(GameState.power + 1)
					popups.add(at, StringManager.t("power_up"), Color(1.0, 0.5, 0.6), 18, 1.2)
				else:
					var points: int = GameState.add_points(ConfigManager.get_int("power_bonus", 5000))
					popups.add(at, str(points), Color(1.0, 0.5, 0.6), 16)
				Sfx.play("power")
				effects.ring(at, Color(1.0, 0.4, 0.5), 40.0, 0.4, 3.0)
			Items.Kind.BOMB:
				GameState.add_bomb()
				popups.add(at, StringManager.t("bomb_up"), Color(0.5, 1.0, 0.6), 18, 1.2)
				Sfx.play("power")
			Items.Kind.LIFE:
				GameState.add_life()
				Sfx.play("extend")

func _end(cleared: bool, delay: float) -> void:
	if _end_timer >= 0.0:
		return
	_end_cleared = cleared
	_end_timer = delay
	if cleared:
		banner.emit("stage_clear", "clear")
		Sfx.play("clear")

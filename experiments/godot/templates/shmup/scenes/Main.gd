# =============================================================================
# Main.gd — Root scene controller.
# =============================================================================
# PERFORMANCE NOTES:
#   - BulletPool is now a single Node2D renderer (no Node per bullet).
#     Collision uses pool.get_bullet(i) — direct Dictionary access, no copy.
#   - _enemies: Array cached locally; updated on spawn/death — no get_children()
#     allocation in the hot collision loop.
#   - _active_indices reuses BulletPool's pre-allocated cache Array.
#
# SCREEN SHAKE — trauma system (Steve Swink Ch.8):
#   trauma² drives offset. Squared curve makes small traumas invisible
#   while full trauma is very strong. Applied to World node only.
#
# HITSTOP:
#   Engine.time_scale=0 for N frames counted in PROCESS_MODE_ALWAYS.
# =============================================================================

extends Node2D

@onready var world:      Node2D    = $World
@onready var enemies_nd: Node2D    = $World/Enemies
@onready var fx_nd:      Node2D    = $World/FX
@onready var player:     Player    = $World/Player
@onready var overlay:    ColorRect = $UI/Overlay
@onready var ov_title:   Label     = $UI/Overlay/VBox/Title
@onready var ov_sub:     Label     = $UI/Overlay/VBox/Sub
@onready var banner:     Label     = $UI/Banner

# Bullet pools — single-node renderers
var _player_pool: BulletPool = null
var _enemy_pool:  BulletPool = null

# Enemy cache — avoids get_children() every frame
var _enemies: Array = []   # Array[ShmupEnemy]

var _wave_mgr:      WaveManager = null
var _between_timer: float = 0.0
var _waiting_next:  bool  = false
var _banner_timer:  float = 0.0

# Screen shake
var _trauma:          float = 0.0
var _shake_decay:     float = 0.0
var _shake_max:       float = 0.0
var _shake_max_roll:  float = 0.0

# Hitstop
var _hitstop_frames: int = 0

const PLAYER_HIT_RADIUS = 10.0
const BULLET_HIT_RADIUS  = 5.0
const PR_SQ = PLAYER_HIT_RADIUS * PLAYER_HIT_RADIUS
const BR_SQ = BULLET_HIT_RADIUS * BULLET_HIT_RADIUS

var _play_w: float = 0.0
var _play_h: float = 0.0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

	_play_w         = ConfigManager.get_float("viewport_play_width",  0.0)
	_play_h         = ConfigManager.get_float("viewport_play_height", 0.0)
	_shake_decay    = ConfigManager.get_float("shake_decay",          0.0)
	_shake_max      = ConfigManager.get_float("shake_max_offset",     0.0)
	_shake_max_roll = ConfigManager.get_float("shake_max_roll",       0.0)

	_build_pools()
	_connect_player()
	_build_wave_manager()
	_build_starfield()

	StringManager.language_changed.connect(_on_language_changed)
	GameState.phase_changed.connect(_on_phase_changed)

	overlay.visible = false
	banner.visible  = false
	GameState.new_game()
	_start_next_wave()

func _build_pools() -> void:
	_player_pool      = BulletPool.new()
	_player_pool.name = "PlayerBullets"
	world.add_child(_player_pool)
	_player_pool.setup(ConfigManager.get_int("player_bullet_pool", 0))

	_enemy_pool       = BulletPool.new()
	_enemy_pool.name  = "EnemyBullets"
	world.add_child(_enemy_pool)
	_enemy_pool.setup(ConfigManager.get_int("enemy_bullet_pool", 0))

func _connect_player() -> void:
	player.shoot.connect(_on_player_shoot)
	player.died.connect(_on_player_died)

func _build_wave_manager() -> void:
	_wave_mgr             = WaveManager.new()
	_wave_mgr.player_ref  = player
	_wave_mgr.play_w      = _play_w
	add_child(_wave_mgr)
	_wave_mgr.spawn_enemy.connect(_on_spawn_enemy)
	_wave_mgr.wave_complete.connect(_on_wave_complete)

func _build_starfield() -> void:
	var sf = StarField.new()
	sf.name = "StarField"
	world.add_child(sf)
	world.move_child(sf, 0)
	sf.setup()
	# Remove tscn placeholder
	var placeholder = world.get_node_or_null("StarField")
	if placeholder != null and placeholder != sf:
		placeholder.free()

# =============================================================================
# _process — PROCESS_MODE_ALWAYS (runs during hitstop)
# =============================================================================
func _process(delta: float) -> void:
	# Hitstop counter
	if _hitstop_frames > 0:
		_hitstop_frames -= 1
		if _hitstop_frames == 0:
			Engine.time_scale = 1.0

	# Screen shake decay + apply
	_trauma       = max(_trauma - _shake_decay * delta, 0.0)
	var sq        = _trauma * _trauma
	world.position = Vector2(
		randf_range(-1.0, 1.0) * _shake_max    * sq,
		randf_range(-1.0, 1.0) * _shake_max    * sq
	)
	world.rotation = randf_range(-1.0, 1.0) * _shake_max_roll * sq

	# Banner auto-hide
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			banner.visible = false

	# Wave-between countdown
	if _waiting_next:
		_between_timer -= delta
		if _between_timer <= 0.0:
			_waiting_next = false
			_start_next_wave()
		return

	if GameState.phase != GameState.Phase.PLAYING:
		return

	_check_collisions()

# =============================================================================
# Collision — uses cached _enemies Array and pool's index-based API
# =============================================================================
func _check_collisions() -> void:
	if not is_instance_valid(player) or not player.is_alive():
		return

	var player_pos = player.global_position
	# Offset by world position because bullets are in World space
	# (BulletPool sits at origin inside World, which is offset by shake)
	# We compare in World-local space: subtract world.position from player_pos.
	var local_player = player_pos - world.position

	# --- Enemy bullets → player ---
	if not player.is_invincible():
		for i in _enemy_pool.get_active_indices():
			var b = _enemy_pool.get_bullet(i)
			if b.pos.distance_squared_to(local_player) < PR_SQ + BR_SQ:
				_enemy_pool.release(i)
				player.hit()
				add_trauma(ConfigManager.get_float("trauma_player_hit", 0.0))
				_hitstop(ConfigManager.get_int("hitstop_player", 0))
				_spawn_explosion(player_pos, 18.0, Color(0.4, 0.7, 1.0))
				break

	# --- Player bullets → enemies ---
	var p_indices = _player_pool.get_active_indices()
	# Iterate backward so we can modify without index issues
	var ei = _enemies.size() - 1
	while ei >= 0:
		var enemy = _enemies[ei]
		ei -= 1
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var local_enemy = enemy.global_position - world.position
		var e_sq = (enemy._size * 0.85) * (enemy._size * 0.85)
		for i in p_indices:
			var b = _player_pool.get_bullet(i)
			if not b.active:
				continue
			if b.pos.distance_squared_to(local_enemy) < e_sq + BR_SQ:
				_player_pool.release(i)
				enemy.take_damage(1)
				if not enemy.is_alive():
					add_trauma(ConfigManager.get_float("trauma_enemy_death", 0.0))
					_hitstop(ConfigManager.get_int("hitstop_enemy", 0))
					_spawn_explosion(enemy.global_position, enemy._size * 1.4, enemy._color)
					_spawn_score_label(enemy.global_position, enemy.get_score())
					GameState.add_score(enemy.get_score())
				break

	# --- Player ship vs enemy (ram) ---
	if not player.is_invincible():
		for enemy in _enemies:
			if not is_instance_valid(enemy) or not enemy.is_alive():
				continue
			var local_enemy = enemy.global_position - world.position
			var e_sq = (enemy._size * 0.7) * (enemy._size * 0.7)
			if local_player.distance_squared_to(local_enemy) < PR_SQ + e_sq:
				player.hit()
				add_trauma(ConfigManager.get_float("trauma_player_hit", 0.0))
				_hitstop(ConfigManager.get_int("hitstop_player", 0))
				break

# =============================================================================
# Signals
# =============================================================================
func _on_player_shoot(pos: Vector2, vel: Vector2) -> void:
	# BulletPool sits at world origin — convert global pos to pool local
	var local = pos - world.position
	_player_pool.acquire(local, vel, Color(0.5, 0.9, 1.0), 4.5)
	add_trauma(ConfigManager.get_float("trauma_shoot", 0.0))

func _on_spawn_enemy(enemy: ShmupEnemy) -> void:
	enemies_nd.add_child(enemy)
	enemy.fire_bullet.connect(_on_enemy_fire)
	enemy.died.connect(_on_enemy_cache_remove.bind(enemy))
	_enemies.append(enemy)

func _on_enemy_cache_remove(enemy: ShmupEnemy) -> void:
	_enemies.erase(enemy)

func _on_enemy_fire(pos: Vector2, vel: Vector2, col: Color) -> void:
	var local = pos - world.position
	_enemy_pool.acquire(local, vel, col, 5.0)

func _on_player_died() -> void:
	_spawn_explosion(player.global_position, 28.0, Color(0.4, 0.7, 1.0))
	add_trauma(ConfigManager.get_float("trauma_boss_death", 0.0))

func _on_wave_complete(_n: int) -> void:
	if GameState.phase == GameState.Phase.PLAYING:
		GameState.set_phase(GameState.Phase.WAVE_CLEAR)

func _on_phase_changed(p: GameState.Phase) -> void:
	match p:
		GameState.Phase.WAVE_CLEAR:
			_show_banner(StringManager.t("wave_clear", {n = GameState.wave}), 2.2)
			_waiting_next  = true
			_between_timer = 3.0
		GameState.Phase.GAME_OVER:
			ov_title.text   = StringManager.t("game_over_title")
			ov_sub.text     = StringManager.t("game_over_sub")
			overlay.visible = true
		GameState.Phase.VICTORY:
			ov_title.text   = StringManager.t("victory_title")
			ov_sub.text     = StringManager.t("victory_sub")
			overlay.visible = true

func _on_language_changed(_lang: String) -> void:
	if not overlay.visible: return
	match GameState.phase:
		GameState.Phase.GAME_OVER:
			ov_title.text = StringManager.t("game_over_title")
			ov_sub.text   = StringManager.t("game_over_sub")
		GameState.Phase.VICTORY:
			ov_title.text = StringManager.t("victory_title")
			ov_sub.text   = StringManager.t("victory_sub")

# =============================================================================
# Wave flow
# =============================================================================
func _start_next_wave() -> void:
	GameState.next_wave()
	if GameState.phase != GameState.Phase.PLAYING:
		return
	var w = GameState.wave
	if w == GameState.total_waves:
		_show_banner(StringManager.t("boss_incoming"), 2.0)
	else:
		_show_banner(StringManager.t("wave_label",
			{current = w, total = GameState.total_waves}), 1.8)
	_wave_mgr.start_wave(w - 1)

# =============================================================================
# Game feel helpers
# =============================================================================
func add_trauma(amount: float) -> void:
	_trauma = min(_trauma + amount, 1.0)

func _hitstop(frames: int) -> void:
	if frames <= 0: return
	_hitstop_frames   = frames
	Engine.time_scale = 0.0

func _spawn_explosion(pos: Vector2, radius: float, col: Color) -> void:
	var ex = Explosion.new()
	fx_nd.add_child(ex)
	ex.global_position = pos
	ex.setup(radius, col)

func _spawn_score_label(pos: Vector2, score: int) -> void:
	if score <= 0: return
	var lbl = FloatingLabel.new()
	fx_nd.add_child(lbl)
	lbl.global_position = pos
	lbl.setup("+%d" % score, Color(1.0, 0.9, 0.3))

func _show_banner(text: String, duration: float) -> void:
	banner.text    = text
	banner.visible = true
	_banner_timer  = duration

# =============================================================================
# Restart
# =============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		var p = GameState.phase
		if p == GameState.Phase.GAME_OVER or p == GameState.Phase.VICTORY:
			_restart()

func _restart() -> void:
	overlay.visible = false
	for c in enemies_nd.get_children(): c.free()
	for c in fx_nd.get_children():      c.free()
	_enemies.clear()
	# Release all pooled bullets
	for i in _player_pool._bullets.size(): _player_pool.release(i)
	for i in _enemy_pool._bullets.size():  _enemy_pool.release(i)

	# Rebuild player if destroyed
	if not is_instance_valid(player) or not player.is_alive():
		var np     = Player.new()
		np.name    = "Player"
		world.add_child(np)
		np.global_position = Vector2(_play_w * 0.5, _play_h * 0.82)
		np.shoot.connect(_on_player_shoot)
		np.died.connect(_on_player_died)
		player               = np
		_wave_mgr.player_ref = np

	Engine.time_scale   = 1.0
	_trauma             = 0.0
	_hitstop_frames     = 0
	world.position      = Vector2.ZERO
	world.rotation      = 0.0

	GameState.new_game()
	_waiting_next = false
	_start_next_wave()

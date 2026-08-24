# Fighter.gd [CORRECTED v2 — procedural visuals, no AnimatedSprite2D]
# Uses FighterVisual (Node2D + _draw) instead of AnimatedSprite2D.
# All collision shapes are defined in code — no external assets needed.

class_name Fighter
extends CharacterBody2D

signal health_changed(new_health: float, max_health: float)
signal died()
signal hit_landed(move_id: String, target: Fighter)
signal state_changed(state: FighterStateMachine.State)

@export var player_index: int  = 0
@export var face_direction: int = 1
const PLAYER_COLORS: Array[Color] = [Color(0.2, 0.55, 1.0), Color(1.0, 0.35, 0.2)]

# Child nodes — created in code so the .tscn stays minimal
var visual: FighterVisual
var attack_hitbox: Area2D
var hurtbox: Area2D
var body_shape: CollisionShape2D
var frame_data_timer: Timer
var hitstun_timer: Timer
var dash_timer: Timer
var dash_cooldown_timer: Timer

var fsm: FighterStateMachine
var input_buf: InputBuffer
var _opponent: Fighter = null
var _arena: Arena      = null

# Cached settings
var _walk_speed: float     = 0.0
var _jump_velocity: float  = 0.0
var _gravity: float        = 0.0
var _dash_speed: float     = 0.0
var _dash_duration: float  = 0.0
var _hitstun_dur: float    = 0.0
var _blockstun_dur: float  = 0.0
var _max_health: float     = 0.0
var _startup_frames: int   = 0
var _active_frames: int    = 0
var _recovery_frames: int  = 0
var _move_data: Dictionary = {}

var _health: float            = 0.0
var _current_move: String     = ""
var _frame_phase: String      = ""
var _hitstop_remaining: float = 0.0
var _can_dash: bool           = true
var _just_jumped: bool        = false

var combo_count: int          = 0
var _combo_reset_timer: float = 0.0
const COMBO_RESET_TIME        := 1.2

var health: float:
	get: return _health

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_settings()
	_build_nodes()
	_setup_fsm()
	_setup_input()
	_connect_signals()
	_health = _max_health

func _physics_process(delta: float) -> void:
	if _hitstop_remaining > 0.0:
		_hitstop_remaining -= delta
		return
	_update_combo_timer(delta)
	_apply_gravity(delta)
	_process_state(delta)
	move_and_slide()
	_clamp_to_stage()
	_update_facing()
	_update_visual()

# ── Node construction (no external assets required) ──────────────────────────

func _build_nodes() -> void:
	# ── Body collision ────────────────────────────────────────────────────────
	body_shape = CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.height = 80.0
	cap.radius = 22.0
	body_shape.shape = cap
	body_shape.position = Vector2(0, -40)
	add_child(body_shape)

	# ── Visual (stick figure) ─────────────────────────────────────────────────
	visual = FighterVisual.new()
	visual.base_color  = PLAYER_COLORS[clampi(player_index, 0, PLAYER_COLORS.size() - 1)]
	visual.position    = Vector2(0, -90)   # top of capsule
	add_child(visual)

	# ── Hurtbox (receives attacks) ────────────────────────────────────────────
	hurtbox = Area2D.new()
	hurtbox.name              = "Hurtbox"
	hurtbox.collision_layer   = 0
	hurtbox.collision_mask    = 4
	var hurtbox_shape         = CollisionShape2D.new()
	var hb_rect               = RectangleShape2D.new()
	hb_rect.size              = Vector2(44, 88)
	hurtbox_shape.shape       = hb_rect
	hurtbox_shape.position    = Vector2(0, -44)
	hurtbox.add_child(hurtbox_shape)
	add_child(hurtbox)

	# ── AttackHitbox (deals damage, active only during attack frames) ─────────
	attack_hitbox = Area2D.new()
	attack_hitbox.name             = "AttackHitbox"
	attack_hitbox.collision_layer  = 4
	attack_hitbox.collision_mask   = 0
	attack_hitbox.monitoring       = false
	attack_hitbox.monitorable      = false
	attack_hitbox.add_to_group("attack_hitboxes")
	var atk_shape                  = CollisionShape2D.new()
	var atk_rect                   = RectangleShape2D.new()
	atk_rect.size                  = Vector2(60, 30)
	atk_shape.shape                = atk_rect
	atk_shape.position             = Vector2(50, -44)  # offset forward; flipped by scale
	attack_hitbox.add_child(atk_shape)
	add_child(attack_hitbox)

	# ── Timers ────────────────────────────────────────────────────────────────
	frame_data_timer    = _make_timer(true)
	hitstun_timer       = _make_timer(true)
	dash_timer          = _make_timer(true)
	dash_cooldown_timer = _make_timer(true)

func _make_timer(one_shot: bool) -> Timer:
	var t := Timer.new()
	t.one_shot = one_shot
	add_child(t)
	return t

# ── Public API ────────────────────────────────────────────────────────────────

func set_opponent(opponent: Fighter) -> void:
	_opponent = opponent

func set_arena(arena: Arena) -> void:
	_arena = arena

func apply_hitstop(duration: float) -> void:
	_hitstop_remaining = maxf(_hitstop_remaining, duration)

func receive_hit(move_id: String, attacker: Fighter) -> void:
	var move: Dictionary = _move_data.get(move_id, {})
	var damage: float    = float(move.get("damage",   0))
	var knockback: float = float(move.get("knockback", 0.0))
	var hitstop: float   = float(move.get("hitstop",  0.0))

	if fsm.current == FighterStateMachine.State.BLOCK and fsm.is_grounded():
		_enter_blockstun()
		_apply_knockback(knockback * 0.3, attacker)
		apply_hitstop(hitstop * 0.5)
		if visual != null: visual.flash_hit()
		return

	_health = clampf(_health - damage, 0.0, _max_health)
	health_changed.emit(_health, _max_health)
	_apply_knockback(knockback, attacker)
	_enter_hitstun()
	apply_hitstop(hitstop)
	if visual != null: visual.flash_hit()
	_screen_shake()

	if _health <= 0.0:
		_enter_ko()

# ── Settings ──────────────────────────────────────────────────────────────────

func _load_settings() -> void:
	_walk_speed      = float(SettingsManager.get_value("fighter.walk_speed",           0.0))
	_jump_velocity   = float(SettingsManager.get_value("fighter.jump_velocity",        0.0))
	_gravity         = float(SettingsManager.get_value("fighter.gravity",              0.0))
	_dash_speed      = float(SettingsManager.get_value("fighter.dash_speed",           0.0))
	_dash_duration   = float(SettingsManager.get_value("fighter.dash_duration",        0.0))
	_hitstun_dur     = float(SettingsManager.get_value("fighter.hitstun_duration",     0.0))
	_blockstun_dur   = float(SettingsManager.get_value("fighter.blockstun_duration",   0.0))
	_max_health      = float(SettingsManager.get_value("fighter.max_health",           0.0))
	_startup_frames  = int(SettingsManager.get_value("fighter.attack_startup_frames",  0))
	_active_frames   = int(SettingsManager.get_value("fighter.attack_active_frames",   0))
	_recovery_frames = int(SettingsManager.get_value("fighter.attack_recovery_frames", 0))
	var moves_raw = SettingsManager.get_value("moves", {})
	_move_data = moves_raw if moves_raw is Dictionary else {}

# ── FSM & Input ───────────────────────────────────────────────────────────────

func _setup_fsm() -> void:
	fsm = FighterStateMachine.new("p%d" % (player_index + 1))
	fsm.state_changed.connect(_on_state_changed)

func _setup_input() -> void:
	input_buf = InputBuffer.new("p%d" % (player_index + 1))

func _connect_signals() -> void:
	frame_data_timer.timeout.connect(_on_frame_data_timeout)
	hitstun_timer.timeout.connect(_on_hitstun_timeout)
	dash_timer.timeout.connect(_on_dash_timeout)
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timeout)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)

# ── State processing ──────────────────────────────────────────────────────────

func _process_state(_delta: float) -> void:
	input_buf.record()
	match fsm.current:
		FighterStateMachine.State.IDLE, FighterStateMachine.State.WALK:
			_process_ground_movement()
			_process_attack_input()
			_process_block_input()
			_process_dash_input()
			_process_jump_input()
		FighterStateMachine.State.JUMP:
			_process_air_movement()
			_process_attack_input()
		FighterStateMachine.State.BLOCK:
			if not input_buf.is_pressed("block"):
				fsm.transition_to(FighterStateMachine.State.IDLE)
		FighterStateMachine.State.DASH:
			velocity.x = _dash_speed * float(face_direction)

func _process_ground_movement() -> void:
	var dir := 0
	if input_buf.is_pressed("right"): dir += 1
	if input_buf.is_pressed("left"):  dir -= 1
	velocity.x = float(dir) * _walk_speed if dir != 0 else 0.0
	if dir != 0:
		fsm.transition_to(FighterStateMachine.State.WALK)
	else:
		fsm.transition_to(FighterStateMachine.State.IDLE)

func _process_air_movement() -> void:
	var dir := 0
	if input_buf.is_pressed("right"): dir += 1
	if input_buf.is_pressed("left"):  dir -= 1
	velocity.x = float(dir) * _walk_speed * 0.8

func _process_jump_input() -> void:
	if input_buf.was_just_pressed("up") and is_on_floor():
		velocity.y   = _jump_velocity
		_just_jumped = true
		fsm.transition_to(FighterStateMachine.State.JUMP)

func _process_block_input() -> void:
	if input_buf.is_pressed("block") and is_on_floor():
		fsm.transition_to(FighterStateMachine.State.BLOCK)

func _process_dash_input() -> void:
	if not _can_dash or not is_on_floor():
		return
	if input_buf.was_just_pressed("special"):
		_start_dash()

func _process_attack_input() -> void:
	if not fsm.is_actionable():
		return
	if input_buf.was_just_pressed("light_punch"):
		_start_attack("light_punch")
	elif input_buf.was_just_pressed("heavy_punch"):
		_start_attack("heavy_punch")
	elif input_buf.was_just_pressed("light_kick"):
		_start_attack("light_kick")
	elif input_buf.was_just_pressed("heavy_kick"):
		_start_attack("heavy_kick")
	elif input_buf.was_just_pressed("special") and is_on_floor():
		_start_attack("special_hadouken")

# ── Attack frame data ─────────────────────────────────────────────────────────

func _start_attack(move_id: String) -> void:
	if not fsm.transition_to(FighterStateMachine.State.ATTACK):
		return
	_current_move = move_id
	_frame_phase  = "startup"
	attack_hitbox.set_deferred("monitoring", false)
	attack_hitbox.set_deferred("monitorable", false)
	if visual != null: visual.squash_attack()
	var fps: float = maxf(float(SettingsManager.get_value("game.target_fps", 60)), 1.0)
	frame_data_timer.start(float(_startup_frames) / fps)

func _on_frame_data_timeout() -> void:
	var fps: float = maxf(float(SettingsManager.get_value("game.target_fps", 60)), 1.0)
	match _frame_phase:
		"startup":
			_frame_phase = "active"
			attack_hitbox.set_deferred("monitoring", true)
			attack_hitbox.set_deferred("monitorable", true)
			frame_data_timer.start(float(_active_frames) / fps)
		"active":
			_frame_phase = "recovery"
			attack_hitbox.set_deferred("monitoring", false)
			attack_hitbox.set_deferred("monitorable", false)
			frame_data_timer.start(float(_recovery_frames) / fps)
		"recovery":
			_frame_phase  = ""
			_current_move = ""
			fsm.transition_to(FighterStateMachine.State.IDLE)

# ── Hit detection ─────────────────────────────────────────────────────────────

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("attack_hitboxes"):
		return
	var attacker := area.get_parent() as Fighter
	if attacker == null:
		return
	if attacker == self:
		return
	receive_hit(attacker._current_move, attacker)
	attacker.hit_landed.emit(attacker._current_move, self)
	attacker.combo_count += 1
	attacker._combo_reset_timer = COMBO_RESET_TIME

# ── Stun & KO ─────────────────────────────────────────────────────────────────

func _enter_hitstun() -> void:
	fsm.transition_to(FighterStateMachine.State.HITSTUN)
	velocity.x = 0.0
	attack_hitbox.set_deferred("monitoring", false)
	attack_hitbox.set_deferred("monitorable", false)
	hitstun_timer.start(_hitstun_dur)

func _enter_blockstun() -> void:
	fsm.transition_to(FighterStateMachine.State.BLOCKSTUN)
	hitstun_timer.start(_blockstun_dur)

func _enter_ko() -> void:
	fsm.transition_to(FighterStateMachine.State.KO)
	velocity = Vector2.ZERO
	died.emit()

func _on_hitstun_timeout() -> void:
	if fsm.current in [FighterStateMachine.State.HITSTUN, FighterStateMachine.State.BLOCKSTUN]:
		fsm.transition_to(FighterStateMachine.State.IDLE)

# ── Dash ──────────────────────────────────────────────────────────────────────

func _start_dash() -> void:
	if not fsm.transition_to(FighterStateMachine.State.DASH):
		return
	_can_dash  = false
	velocity.x = _dash_speed * float(face_direction)
	dash_timer.start(_dash_duration)

func _on_dash_timeout() -> void:
	velocity.x = 0.0
	fsm.transition_to(FighterStateMachine.State.IDLE)
	var cooldown: float = float(SettingsManager.get_value("fighter.dash_cooldown", 0.0))
	dash_cooldown_timer.start(cooldown)

func _on_dash_cooldown_timeout() -> void:
	_can_dash = true

# ── Physics ───────────────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta
		_just_jumped = false
	else:
		if fsm.current == FighterStateMachine.State.JUMP and not _just_jumped:
			fsm.transition_to(FighterStateMachine.State.IDLE)

func _apply_knockback(force: float, attacker: Fighter) -> void:
	var dir: int = sign(global_position.x - attacker.global_position.x)
	if dir == 0:
		dir = -attacker.face_direction
	velocity.x = force * float(dir)

func _clamp_to_stage() -> void:
	var hw: float = get_viewport_rect().size.x * 0.5
	global_position.x = clampf(global_position.x, -hw + 40.0, hw - 40.0)

# ── Visual updates ────────────────────────────────────────────────────────────

func _update_facing() -> void:
	if _opponent != null:
		face_direction = int(sign(_opponent.global_position.x - global_position.x))
		if face_direction == 0:
			face_direction = 1
	# Mirror the attack hitbox offset with the facing direction
	if attack_hitbox != null and attack_hitbox.get_child_count() > 0:
		var s := attack_hitbox.get_child(0) as CollisionShape2D
		if s != null:
			s.position.x = abs(s.position.x) * float(face_direction)

func _update_visual() -> void:
	if visual == null:
		return
	visual.set_state(fsm.current, face_direction)

func _screen_shake() -> void:
	if _arena != null:
		_arena.trigger_shake()

func _update_combo_timer(delta: float) -> void:
	if combo_count > 0:
		_combo_reset_timer -= delta
		if _combo_reset_timer <= 0.0:
			combo_count = 0

func _on_state_changed(_old: FighterStateMachine.State, new_state: FighterStateMachine.State) -> void:
	state_changed.emit(new_state)

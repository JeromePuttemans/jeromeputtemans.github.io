extends CharacterBody2D

# ── Signals ────────────────────────────────────────────────────────────────────

signal player_died
signal player_speed_changed(ratio: float)
signal twist_activated

# ── Constants ──────────────────────────────────────────────────────────────────

const BULLET_SCENE: String = "res://scenes/entities/bullet.tscn"
const COLOR_NEUTRAL: Color  = Color(0.91, 0.91, 1.0, 1.0)
const COLOR_DANGER: Color   = Color(1.0, 0.8, 0.0, 1.0)
const COLOR_CRITICAL: Color = Color(1.0, 0.267, 0.333, 1.0)
const TRAIL_LENGTH_FULL: float = 36.0
const TRAIL_LENGTH_MIN: float  = 8.0

# ── Settings ───────────────────────────────────────────────────────────────────

var _speed_base: float   = 220.0
var _speed_min: float    = 60.0
var _fire_penalty: float = 8.0
var _bullet_speed: float = 500.0
var _scroll_speed: float = 80.0

# ── Node references (children exist before _ready — set by game_manager builder) ──

@onready var _body: Polygon2D       = $Body
@onready var _trail: Line2D         = $Trail
@onready var _hitbox: Area2D        = $Hitbox
@onready var _fire_timer: Timer     = $FireCooldown

# ── Runtime state ──────────────────────────────────────────────────────────────

var _active_bullet_count: int = 0
var _is_alive: bool = false
var _twist_has_fired: bool = false
var _bullets_parent: Node2D = null
var _bullet_scene: PackedScene = null
var _spawn_position: Vector2 = Vector2(200.0, 360.0)
var _viewport_size: Vector2 = Vector2(1280.0, 720.0)

# ── Initialisation ─────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("player")
	_load_settings()
	_bullet_scene = load(BULLET_SCENE) as PackedScene
	# Bullets container is a sibling of Player inside World
	var world: Node2D = get_parent() as Node2D
	if is_instance_valid(world):
		_bullets_parent = world.get_node_or_null("Bullets") as Node2D
	_fire_timer.timeout.connect(_on_fire_timer_timeout)
	# Collision via Area2D child — body_entered only exists on Area2D, not CharacterBody2D
	_hitbox.body_entered.connect(_on_hitbox_body_entered)
	_spawn_position = position
	var vp: Viewport = get_viewport()
	if is_instance_valid(vp):
		_viewport_size = vp.get_visible_rect().size
	_is_alive = false
	visible = false

func _load_settings() -> void:
	var file: FileAccess = FileAccess.open("res://datas/settings.json", FileAccess.READ)
	if file:
		var json: JSON = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data: Dictionary = json.data as Dictionary
			var g: Dictionary = data.get("gameplay", {}) as Dictionary
			_speed_base   = g.get("player_speed_base", 220.0) as float
			_speed_min    = g.get("player_speed_min", 60.0) as float
			_fire_penalty = g.get("fire_speed_penalty", 8.0) as float
			_bullet_speed = g.get("bullet_speed", 500.0) as float
			_scroll_speed = g.get("scroll_speed", 80.0) as float
		file.close()

# ── Public API ─────────────────────────────────────────────────────────────────

func reset_player() -> void:
	position = _spawn_position
	velocity = Vector2.ZERO
	_active_bullet_count = 0
	_twist_has_fired = false
	_is_alive = true
	var vp: Viewport = get_viewport()
	if is_instance_valid(vp):
		_viewport_size = vp.get_visible_rect().size
	_update_visuals(1.0)

func register_bullet_destroyed() -> void:
	_active_bullet_count = maxi(0, _active_bullet_count - 1)

func die() -> void:
	_die()

# ── Process ────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not _is_alive:
		return
	_handle_movement(delta)
	_handle_death_by_scroll()

func _handle_movement(_delta: float) -> void:
	var current_speed: float = _compute_current_speed()
	var speed_ratio: float = (current_speed - _speed_min) / maxf(_speed_base - _speed_min, 1.0)

	var direction: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("ui_right"): direction.x += 1.0
	if Input.is_action_pressed("ui_left"):  direction.x -= 1.0
	if Input.is_action_pressed("ui_down"):  direction.y += 1.0
	if Input.is_action_pressed("ui_up"):    direction.y -= 1.0

	if direction.length_squared() > 0.0:
		velocity = direction.normalized() * current_speed
	else:
		velocity = Vector2.ZERO

	# Scroll force: constant leftward push in pixels/sec
	velocity.x -= _scroll_speed

	move_and_slide()

	# Clamp vertical to viewport
	position.y = clampf(position.y, 20.0, _viewport_size.y - 20.0)

	_update_visuals(speed_ratio)
	player_speed_changed.emit(speed_ratio)

	# Fire: Space key during play
	if Input.is_key_pressed(KEY_SPACE) and _fire_timer.is_stopped():
		_fire_timer.start()
		_fire_bullet()

func _compute_current_speed() -> float:
	var penalty: float = float(_active_bullet_count) * _fire_penalty
	return maxf(_speed_min, _speed_base - penalty)

func _handle_death_by_scroll() -> void:
	if position.x < -10.0:
		_die()

func _update_visuals(speed_ratio: float) -> void:
	var body_color: Color
	if speed_ratio > 0.5:
		body_color = COLOR_NEUTRAL.lerp(COLOR_DANGER, 1.0 - ((speed_ratio - 0.5) * 2.0))
	else:
		body_color = COLOR_DANGER.lerp(COLOR_CRITICAL, 1.0 - (speed_ratio * 2.0))
	if is_instance_valid(_body):
		_body.color = body_color
	var trail_len: float = lerpf(TRAIL_LENGTH_MIN, TRAIL_LENGTH_FULL, speed_ratio)
	if is_instance_valid(_trail):
		_trail.points = PackedVector2Array([Vector2(-14.0, 0.0), Vector2(-14.0 - trail_len, 0.0)])
		_trail.default_color = body_color.lerp(Color(1.0, 1.0, 1.0, 0.0), 0.4)

# ── Firing ─────────────────────────────────────────────────────────────────────

func _fire_bullet() -> void:
	if not is_instance_valid(_bullet_scene): return
	if not is_instance_valid(_bullets_parent): return
	if not _twist_has_fired:
		_twist_has_fired = true
		twist_activated.emit()
	var bullet: Node2D = _bullet_scene.instantiate() as Node2D
	if not is_instance_valid(bullet): return
	bullet.position = position + Vector2(18.0, 0.0)
	bullet.set("player_ref", self)
	bullet.set("bullet_speed", _bullet_speed)
	_bullets_parent.call_deferred("add_child", bullet)
	_active_bullet_count += 1

func _on_fire_timer_timeout() -> void:
	if Input.is_key_pressed(KEY_SPACE) and _is_alive:
		_fire_bullet()
	else:
		_fire_timer.stop()

# ── Collision & death ──────────────────────────────────────────────────────────

func _on_hitbox_body_entered(_body_arg: Node2D) -> void:
	if not _is_alive: return
	_die()

func _die() -> void:
	if not _is_alive: return
	_is_alive = false
	visible = false
	_fire_timer.stop()
	player_died.emit()

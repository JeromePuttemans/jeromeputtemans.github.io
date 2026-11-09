extends Node2D

# Player: movement against the current, drag from the bullets in flight,
# firing, purge, hull and invulnerability. Built by game_manager.gd in World,
# drawn in _draw().
#
# THE TWIST: speed = max(player_speed_min, player_speed_base
#   - fire_speed_penalty x bullets in flight). A bullet stays in flight until
#   it hits an enemy or leaves the screen on the right: a shot fired from the
#   left half travels longer, so it slows the ship longer, and an accurate
#   shot frees its share of speed at once.
# THE CURRENT pushes the ship left at current_speed. When speed drops below
#   it, even holding right drifts the ship toward the void (x < 0), which
#   destroys it. twist_activated is emitted the first time this happens in a
#   run, while firing: the moment the player discovers the rule.
# PURGE erases every bullet in flight (speed back at once) plus a short boost,
#   then needs purge_cooldown seconds.
# MOVEMENT eases toward the target velocity (player_acceleration) and the ship
#   tilts with its vertical speed. Tethers drawn to each bullet in flight show
#   what is holding the ship back.

signal player_fired()
signal player_hull_changed(hull: int, hull_max: int)
signal player_died(cause: String)
signal player_purged(bullet_positions: PackedVector2Array)
signal player_status_changed(speed: float, current_speed: float, purge_ratio: float)
signal twist_activated()

const COLOR_FAST: Color = Color(0.91, 0.91, 1.0)
const COLOR_SLOW: Color = Color(1.0, 0.8, 0.0)
const COLOR_CRITICAL: Color = Color(1.0, 0.267, 0.333)
const NOSE: Vector2 = Vector2(18.0, 0.0)
const MUZZLE_TIME: float = 0.05
const TILT: float = 0.28

var current_speed: float = 90.0
var alive: bool = false
var hull: int = 3
var hull_max: int = 3
var radius: float = 9.0
var _settings: Dictionary = {}
var _bullets: Node2D = null
var _screen: Vector2 = Vector2(1280.0, 720.0)
var _velocity: Vector2 = Vector2.ZERO
var _fire_cooldown: float = 0.0
var _purge_cooldown: float = 0.0
var _boost_left: float = 0.0
var _invulnerable_left: float = 0.0
var _muzzle_left: float = 0.0
var _twist_shown: bool = false
var _time: float = 0.0
var _speed_ratio: float = 1.0

## Called by game_manager.gd after add_child(): stores data only.
func configure(gameplay: Dictionary, bullets: Node2D, screen: Vector2) -> void:
	_settings = gameplay
	_bullets = bullets
	_screen = screen
	hull_max = int(_setting("player_hp", 3))
	radius = float(_setting("player_radius", 9.0))

func reset_player(start: Vector2) -> void:
	position = start
	rotation = 0.0
	_velocity = Vector2.ZERO
	hull = hull_max
	_fire_cooldown = 0.0
	_purge_cooldown = 0.0
	_boost_left = 0.0
	_invulnerable_left = 0.0
	_twist_shown = false
	alive = true
	visible = true
	player_hull_changed.emit(hull, hull_max)

func bullets_in_flight() -> int:
	return _bullets.get_child_count() if is_instance_valid(_bullets) else 0

func compute_speed() -> float:
	var base: float = float(_setting("player_speed_base", 300.0))
	var penalty: float = float(_setting("fire_speed_penalty", 20.0)) * bullets_in_flight()
	var speed: float = maxf(float(_setting("player_speed_min", 60.0)), base - penalty)
	if _boost_left > 0.0:
		speed *= float(_setting("purge_boost", 1.6))
	return speed

## Returns true when the hit is applied (not invulnerable, still alive).
func take_hit() -> bool:
	if not alive or _invulnerable_left > 0.0:
		return false
	hull -= 1
	_invulnerable_left = float(_setting("invulnerability_time", 1.5))
	player_hull_changed.emit(hull, hull_max)
	if hull <= 0:
		_die("destroyed")
	return true

func repair() -> bool:
	if hull >= hull_max:
		return false
	hull += 1
	player_hull_changed.emit(hull, hull_max)
	return true

func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0

# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_time += delta
	if not alive:
		return
	_tick_timers(delta)
	var speed: float = compute_speed()
	_move(delta, speed)
	_try_fire()
	_try_purge()
	_check_twist(speed)
	var purge_ratio: float = 1.0 - _purge_cooldown / maxf(float(_setting("purge_cooldown", 4.0)), 0.01)
	player_status_changed.emit(speed, current_speed, purge_ratio)
	if position.x < 0.0:
		_die("void")
	queue_redraw()

func _tick_timers(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	_purge_cooldown = maxf(_purge_cooldown - delta, 0.0)
	_boost_left = maxf(_boost_left - delta, 0.0)
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	_muzzle_left = maxf(_muzzle_left - delta, 0.0)

func _move(delta: float, speed: float) -> void:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target: Vector2 = input * speed - Vector2(current_speed, 0.0)
	_velocity = _velocity.move_toward(target, float(_setting("player_acceleration", 2600.0)) * delta)
	position += _velocity * delta
	var margin_y: float = float(_setting("vertical_margin", 34.0))
	position.x = minf(position.x, _screen.x - float(_setting("right_margin", 70.0)))
	position.y = clampf(position.y, margin_y, _screen.y - margin_y)
	rotation = lerpf(rotation, clampf(_velocity.y / maxf(speed, 1.0), -1.0, 1.0) * TILT, 1.0 - exp(-12.0 * delta))
	var base: float = float(_setting("player_speed_base", 300.0))
	var minimum: float = float(_setting("player_speed_min", 60.0))
	_speed_ratio = clampf((minf(speed, base) - minimum) / maxf(base - minimum, 1.0), 0.0, 1.0)

func _try_fire() -> void:
	if not Input.is_action_pressed("fire") or _fire_cooldown > 0.0 or not is_instance_valid(_bullets):
		return
	_fire_cooldown = float(_setting("fire_interval", 0.1))
	_muzzle_left = MUZZLE_TIME
	var bullet := Node2D.new()
	bullet.position = position + NOSE.rotated(rotation)
	bullet.set_script(load("res://scripts/entities/bullet.gd"))
	_bullets.add_child(bullet)
	var velocity := Vector2(float(_setting("bullet_speed", 900.0)), 0.0)
	bullet.call("setup", velocity, float(_setting("bullet_lifetime", 1.6)), float(_setting("bullet_radius", 5.0)), _screen.x)
	player_fired.emit()

func _try_purge() -> void:
	if not Input.is_action_just_pressed("purge") or _purge_cooldown > 0.0 or not is_instance_valid(_bullets):
		return
	var positions := PackedVector2Array()
	for child_v in _bullets.get_children():
		var bullet: Node2D = child_v as Node2D
		positions.append(bullet.position)
		_bullets.remove_child(bullet)
		bullet.queue_free()
	_purge_cooldown = float(_setting("purge_cooldown", 4.0))
	_boost_left = float(_setting("purge_boost_time", 0.5))
	player_purged.emit(positions)

func _check_twist(speed: float) -> void:
	if _twist_shown or speed >= current_speed or not Input.is_action_pressed("fire"):
		return
	_twist_shown = true
	twist_activated.emit()

func _die(cause: String) -> void:
	if not alive:
		return
	alive = false
	visible = false
	player_died.emit(cause)

func _setting(key: String, fallback: Variant) -> Variant:
	return _settings.get(key, fallback)

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _ship_color() -> Color:
	if _speed_ratio > 0.5:
		return COLOR_SLOW.lerp(COLOR_FAST, (_speed_ratio - 0.5) * 2.0)
	return COLOR_CRITICAL.lerp(COLOR_SLOW, _speed_ratio * 2.0)

func _draw() -> void:
	if _invulnerable_left > 0.0 and fmod(_time, 0.14) < 0.07:
		return
	var color: Color = _ship_color()
	_draw_tethers(color)
	_draw_flame(color)
	_draw_hull(color)
	if _muzzle_left > 0.0:
		draw_circle(NOSE + Vector2(4.0, 0.0), 6.0, Color(1.0, 0.95, 0.7, 0.8))

func _draw_tethers(color: Color) -> void:
	if not is_instance_valid(_bullets):
		return
	var strength: float = 0.08 + 0.3 * (1.0 - _speed_ratio)
	for child_v in _bullets.get_children():
		var bullet: Node2D = child_v as Node2D
		var local: Vector2 = to_local(bullet.global_position)
		draw_line(Vector2.ZERO, local, Color(color, strength * clampf(1.0 - local.length() / 1200.0, 0.2, 1.0)), 1.0)

func _draw_flame(color: Color) -> void:
	var flicker: float = 0.8 + 0.2 * sin(_time * 50.0)
	var length: float = (10.0 + 26.0 * _speed_ratio) * flicker
	if _boost_left > 0.0:
		length *= 1.8
	var flame := PackedVector2Array([Vector2(-8.0, -5.0), Vector2(-8.0 - length, 0.0), Vector2(-8.0, 5.0)])
	draw_colored_polygon(flame, Color(color.lerp(Color(0.4, 0.9, 1.0), _speed_ratio), 0.75))
	var core := PackedVector2Array([Vector2(-8.0, -2.5), Vector2(-8.0 - length * 0.55, 0.0), Vector2(-8.0, 2.5)])
	draw_colored_polygon(core, Color(1.0, 1.0, 1.0, 0.85))

func _draw_hull(color: Color) -> void:
	var body := PackedVector2Array([NOSE, Vector2(-12.0, -11.0), Vector2(-7.0, 0.0), Vector2(-12.0, 11.0)])
	draw_circle(Vector2.ZERO, 22.0, Color(color, 0.06))
	draw_colored_polygon(body, Color(color * 0.35, 1.0))
	var outline: PackedVector2Array = body.duplicate()
	outline.append(NOSE)
	draw_polyline(outline, color, 2.0)
	draw_circle(Vector2(3.0, 0.0), 2.6, color.lightened(0.4))

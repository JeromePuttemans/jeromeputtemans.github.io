# =============================================================================
# Player.gd — Node2D: player ship.
# =============================================================================
# MOVEMENT (Steve Swink — Chapter 4: Game Feel):
#   Input direction is applied to a _velocity vector. _velocity lerps toward
#   (input * max_speed) each frame using player_lerp as the weight.
#   This gives a subtle acceleration/deceleration that reads as "weight" without
#   sacrificing responsiveness. Lerp weight ~14 feels snappy but organic.
#
# SQUASH & STRETCH:
#   When moving left, the ship stretches horizontally and squashes vertically,
#   and vice versa. Scale is computed from velocity.x normalized to max_speed.
#   This gives visual momentum feedback per Steve Swink's "spatial anticipation".
#
# EXHAUST TRAIL:
#   A ring buffer of past positions is drawn as small fading circles behind
#   the two engine nozzle positions (offset left/right of center).
#
# IFRAMES (invincibility frames):
#   After being hit, _iframe_t counts down. During this period the player
#   cannot be hit again. The ship blinks using sin(time * blink_rate) > 0
#   for the visible/invisible toggle, communicating the protected state clearly.
#
# SHOOTING:
#   A _fire_timer counts down; when it reaches 0 and shoot is held, a bullet
#   is fired and the timer resets. The shoot signal carries position + velocity.
# =============================================================================
class_name Player
extends Node2D

signal shoot(pos: Vector2, vel: Vector2)
signal died()

const TRAIL_LEN  = 12
const NOZZLE_OFF = 10.0   # horizontal offset of engine nozzles from center

var _max_speed:    float = 0.0
var _lerp_w:       float = 0.0
var _fire_rate:    float = 0.0
var _bullet_speed: float = 0.0
var _velocity:     Vector2 = Vector2.ZERO
var _fire_timer:   float   = 0.0
var _iframe_t:     float   = 0.0
var _iframe_dur:   float   = 0.0
var _blink_rate:   float   = 0.0
var _alive:        bool    = true
var _removed:      bool    = false
var _time:         float   = 0.0

var _play_w:  float = 0.0
var _play_h:  float = 0.0

# Trail ring buffers (two nozzles)
var _trail_l: Array = []
var _trail_r: Array = []

func _ready() -> void:
	_max_speed    = ConfigManager.get_float("player_speed",        0.0)
	_lerp_w       = ConfigManager.get_float("player_lerp",         0.0)
	_fire_rate    = ConfigManager.get_float("player_fire_rate",    0.0)
	_bullet_speed = ConfigManager.get_float("player_bullet_speed", 0.0)
	_iframe_dur   = ConfigManager.get_float("iframe_duration",     0.0)
	_blink_rate   = ConfigManager.get_float("iframe_blink_rate",   0.0)
	_play_w       = ConfigManager.get_float("viewport_play_width",  0.0)
	_play_h       = ConfigManager.get_float("viewport_play_height", 0.0)

func _process(delta: float) -> void:
	if not _alive:
		return
	_time += delta

	# --- Input ---
	var dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_action_pressed("move_right"):
		dir.x += 1.0
	if Input.is_action_pressed("ui_left")  or Input.is_action_pressed("move_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("ui_up")    or Input.is_action_pressed("move_up"):
		dir.y -= 1.0
	if Input.is_action_pressed("ui_down")  or Input.is_action_pressed("move_down"):
		dir.y += 1.0
	if dir.length() > 1.0:
		dir = dir.normalized()

	# Lerp velocity for "weighted" feel
	_velocity = _velocity.lerp(dir * _max_speed, _lerp_w * delta)

	# Clamp to play area
	position += _velocity * delta
	position.x = clamp(position.x, 18.0, _play_w - 18.0)
	position.y = clamp(position.y, 18.0, _play_h - 18.0)

	# --- Iframes countdown ---
	_iframe_t = max(_iframe_t - delta, 0.0)

	# --- Shooting ---
	_fire_timer = max(_fire_timer - delta, 0.0)
	var shoot_held = (Input.is_action_pressed("shoot") or
					  Input.is_action_pressed("ui_accept"))
	if shoot_held and _fire_timer <= 0.0:
		_fire_timer = 1.0 / _fire_rate
		var bvel    = Vector2(0, -_bullet_speed)
		emit_signal("shoot", global_position + Vector2(-8, -18), bvel)
		emit_signal("shoot", global_position + Vector2( 8, -18), bvel)

	# --- Exhaust trail ---
	_trail_l.push_front(global_position + Vector2(-NOZZLE_OFF, 14))
	_trail_r.push_front(global_position + Vector2( NOZZLE_OFF, 14))
	if _trail_l.size() > TRAIL_LEN: _trail_l.pop_back()
	if _trail_r.size() > TRAIL_LEN: _trail_r.pop_back()

	queue_redraw()

## Called by Main when a collision is detected.
func hit() -> void:
	if not _alive or _iframe_t > 0.0 or _removed:
		return
	_iframe_t = _iframe_dur
	GameState.lose_life()
	if GameState.lives <= 0:
		_alive   = false
		_removed = true
		emit_signal("died")
		queue_free()

func is_alive() -> bool:
	return _alive

func is_invincible() -> bool:
	return _iframe_t > 0.0

func _draw() -> void:
	if not _alive:
		return

	# Iframe blink — skip draw on "off" blink frames
	if _iframe_t > 0.0:
		var blink = sin(_time * _blink_rate * TAU) > 0.0
		if not blink:
			return

	# Squash/stretch based on horizontal velocity
	var sx  = 1.0 + (_velocity.x / _max_speed) * 0.22
	var sy  = 1.0 - abs(_velocity.x / _max_speed) * 0.12
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))

	# Hull — triangle pointing up
	var hull = PackedVector2Array([
		Vector2(0,   -20),
		Vector2(-14,  16),
		Vector2( 14,  16),
	])
	draw_colored_polygon(hull, Color(0.3, 0.7, 1.0))

	# Cockpit
	draw_circle(Vector2(0, -6), 5.0, Color(0.8, 0.95, 1.0, 0.85))

	# Wings
	var wing_l = PackedVector2Array([Vector2(-14,16), Vector2(-22,22), Vector2(-6,18)])
	var wing_r = PackedVector2Array([Vector2( 14,16), Vector2( 22,22), Vector2(  6,18)])
	draw_colored_polygon(wing_l, Color(0.2, 0.55, 0.85))
	draw_colored_polygon(wing_r, Color(0.2, 0.55, 0.85))

	# Reset transform before drawing trails (they use global-to-local)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Exhaust trails
	for i in _trail_l.size():
		var alpha = (1.0 - float(i) / TRAIL_LEN) * 0.7
		var r     = (1.0 - float(i) / TRAIL_LEN) * 4.0
		var lp    = to_local(_trail_l[i])
		var rp    = to_local(_trail_r[i])
		var flicker = 0.6 + sin(_time * 18.0 + i) * 0.4
		var col   = Color(0.4, 0.7, 1.0, alpha * flicker)
		if r > 0.5:
			draw_circle(lp, r, col)
			draw_circle(rp, r, col)

	# Engine glow
	var glow_a = 0.55 + sin(_time * 12.0) * 0.3
	draw_circle(Vector2(-NOZZLE_OFF, 14), 5.0, Color(0.4, 0.7, 1.0, glow_a))
	draw_circle(Vector2( NOZZLE_OFF, 14), 5.0, Color(0.4, 0.7, 1.0, glow_a))

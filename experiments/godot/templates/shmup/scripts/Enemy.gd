# =============================================================================
# Enemy.gd — Node2D: enemy ship.
# =============================================================================
# OPTIMISATIONS vs original:
#   - Hexagon vertices pre-computed in setup() → stored as _hull_pts.
#     _draw() no longer allocates a PackedVector2Array per frame.
#   - HP bar only drawn when hp < hp_max (skip until first hit).
#   - Engine glow uses pre-computed _glow_offset, not inline Vector2 each draw.
#   - _removed flag prevents double-signal on simultaneous hit + off-screen.
# =============================================================================
class_name ShmupEnemy
extends Node2D

signal died(enemy: ShmupEnemy)
signal fire_bullet(pos: Vector2, vel: Vector2, color: Color)

var hp:            int    = 0
var hp_max:        int    = 0
var _speed:        float  = 0.0
var _move:         String = "straight"
var _shoot:        String = "none"
var _fire_rate:    float  = 0.0
var _color:        Color  = Color.RED
var _bullet_col:   Color  = Color.RED
var _size:         float  = 0.0
var _score_key:    String = ""
var _removed:      bool   = false

# Pre-computed geometry (set once in setup, reused every _draw)
var _hull_pts:     PackedVector2Array
var _cockpit_r:    float = 0.0
var _cockpit_off:  Vector2
var _glow_off:     Vector2
var _bar_x:        float = 0.0
var _bar_y:        float = 0.0
var _bar_w:        float = 0.0

var _time:         float = 0.0
var _fire_timer:   float = 0.0
var _flash_t:      float = 0.0
const FLASH_DUR           = 0.12

var _dive_started: bool   = false
var _dive_target:  float  = 0.0

var player_ref:    Node2D = null

var _play_w:       float  = 0.0
var _play_h:       float  = 0.0
var _bullet_speed: float  = 0.0

func setup(data: Dictionary) -> void:
	hp            = data.get("hp",         0)
	hp_max        = hp
	_speed        = float(data.get("speed",     0))
	_move         = data.get("move",        "straight")
	_shoot        = data.get("shoot",       "none")
	_fire_rate    = float(data.get("fire_rate", 0))
	_color        = Color("#" + data.get("color",        "e74c3c"))
	_bullet_col   = Color("#" + data.get("bullet_color", "ff6b6b"))
	_size         = float(data.get("size", 16))
	_score_key    = data.get("score_key", "")
	_play_w       = ConfigManager.get_float("viewport_play_width",  0.0)
	_play_h       = ConfigManager.get_float("viewport_play_height", 0.0)
	_bullet_speed = ConfigManager.get_float("enemy_bullet_speed",   0.0)
	_fire_timer   = 1.0 / max(_fire_rate, 0.01)

	# Pre-compute hex hull (6 vertices, pointy-top)
	_hull_pts = PackedVector2Array()
	for i in 6:
		var a = TAU * i / 6.0 - PI * 0.5
		_hull_pts.append(Vector2(cos(a), sin(a)) * _size)

	# Pre-compute small geometry
	_cockpit_r   = _size * 0.22
	_cockpit_off = Vector2(0.0, _size * 0.25)
	_glow_off    = Vector2(0.0, _size * 0.6)

	# HP bar geometry
	_bar_w = _size * 2.2
	_bar_x = -_bar_w * 0.5
	_bar_y = -_size - 9.0

func _process(delta: float) -> void:
	_time    += delta
	_flash_t  = max(_flash_t - delta, 0.0)

	match _move:
		"straight":
			position.y += _speed * delta
		"sine":
			position.y += _speed * delta
			position.x += sin(_time * 2.8) * _speed * 0.55 * delta
		"dive":
			if not _dive_started:
				_dive_started = true
				_dive_target  = player_ref.position.x if player_ref else _play_w * 0.5
			var dx = _dive_target - position.x
			position.x += clamp(dx, -_speed * delta * 1.4, _speed * delta * 1.4)
			position.y += _speed * delta
		"boss":
			position.x = _play_w * 0.5 + sin(_time * 0.9) * _play_w * 0.36
			position.y += _speed * delta * 0.08

	if position.y > _play_h + _size + 20:
		_silent_remove()
		return

	if _fire_rate > 0.0:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire_timer = 1.0 / _fire_rate
			_do_shoot()

	queue_redraw()

func _do_shoot() -> void:
	match _shoot:
		"single":
			_emit_bullet(Vector2(0, 1))
		"spread3":
			for deg in [-20.0, 0.0, 20.0]:
				_emit_bullet(Vector2(0, 1).rotated(deg_to_rad(deg)))
		"ring8":
			for i in 8:
				_emit_bullet(Vector2(0, 1).rotated(TAU * i / 8.0))
		"aimed":
			var dir = (player_ref.position - position).normalized() if player_ref \
					  else Vector2(0, 1)
			_emit_bullet(dir)

func _emit_bullet(dir: Vector2) -> void:
	emit_signal("fire_bullet", global_position, dir * _bullet_speed, _bullet_col)

func get_score() -> int:
	return ConfigManager.get_int(_score_key, 0) if not _score_key.is_empty() else 0

func take_damage(amount: int) -> void:
	if _removed: return
	hp -= amount
	_flash_t = FLASH_DUR
	if hp <= 0:
		_removed = true
		emit_signal("died", self)
		queue_free()
	else:
		queue_redraw()

func is_alive() -> bool:
	return not _removed

func _silent_remove() -> void:
	if not _removed:
		_removed = true
		_alive   = false
		emit_signal("died", self)
		queue_free()

var _alive: bool = true

func _draw() -> void:
	var flash = _flash_t / FLASH_DUR
	var col   = _color.lerp(Color.WHITE, flash)

	# HP bar — only when damaged
	if hp < hp_max:
		draw_rect(Rect2(_bar_x, _bar_y, _bar_w, 4), Color(0.15, 0.15, 0.15))
		draw_rect(Rect2(_bar_x, _bar_y, _bar_w * float(hp) / float(hp_max), 4),
			Color(0.2, 0.9, 0.3))

	# Hull (pre-computed vertices)
	draw_colored_polygon(_hull_pts, col)

	# Cockpit
	draw_circle(_cockpit_off, _cockpit_r, col.darkened(0.4))

	# Engine glow (flicker via sin)
	var ga = 0.5 + sin(_time * 10.0) * 0.25
	draw_circle(_glow_off, _size * 0.28, Color(1.0, 0.6, 0.1, ga))

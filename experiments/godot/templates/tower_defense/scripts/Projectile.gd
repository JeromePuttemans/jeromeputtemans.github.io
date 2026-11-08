# =============================================================================
# Projectile.gd (Node2D): homing bullet or ballistic shell.
# =============================================================================
# BULLET (Gatling), homing:
#   Each frame the bullet moves toward the target's current position at
#   `speed` px/s. If the target dies on the way, the bullet keeps flying to the
#   last known position and fizzles there: no shot disappears in mid-air, the
#   player always sees where it went.
#
# SHELL (Mortar), ballistic and ground-targeted:
#   The shell flies from start to a fixed aim point (the target's predicted
#   position) in `flight` seconds. Ground position = lerp(start, aim, k) and
#   height = 4 x arc x k x (1 - k), a parabola peaking at k = 0.5. The shell is
#   drawn at (ground - height) above its shadow, so the arc reads as 3D.
#   An impact marker grows on the ground during the flight: the area of
#   effect is visible before the explosion. On landing, every enemy within
#   splash radius takes damage (brute-force O(n) scan, fine for these counts).
# =============================================================================

class_name Projectile
extends Node2D

enum Kind { BULLET, SHELL }

const HIT_RADIUS: float = 8.0
const TRAIL_LEN:  int   = 6

var _kind:   Kind   = Kind.BULLET
var _damage: int    = 0
var _color:  Color  = Color.WHITE

# Bullet
var _target:      Enemy   = null
var _speed:       float   = 0.0
var _last_target: Vector2 = Vector2.ZERO
var _trail:       Array[Vector2] = []

# Shell
var _start:        Vector2 = Vector2.ZERO
var _aim:          Vector2 = Vector2.ZERO
var _flight:       float   = 1.0
var _t:            float   = 0.0
var _height:       float   = 0.0
var _arc:          float   = 0.0
var _splash:       float   = 0.0
var _enemies_node: Node2D  = null

func setup_bullet(origin: Vector2, target: Enemy, damage: int, speed: float, color: Color) -> void:
	_kind        = Kind.BULLET
	global_position = origin
	_target      = target
	_damage      = damage
	_speed       = speed
	_color       = color
	_last_target = target.global_position

func setup_shell(origin: Vector2, aim: Vector2, flight: float, damage: int, splash: float,
		color: Color, enemies_node: Node2D) -> void:
	_kind   = Kind.SHELL
	global_position = origin
	_start  = origin
	_aim    = aim
	_flight = maxf(flight, 0.05)
	_damage = damage
	_splash = splash
	_color  = color
	_enemies_node = enemies_node
	_arc    = clampf(origin.distance_to(aim) * 0.35, 40.0, 110.0)

func _process(delta: float) -> void:
	if _kind == Kind.BULLET:
		_update_bullet(delta)
	else:
		_update_shell(delta)
	queue_redraw()

# ---------------------------------------------------------------------------
# Bullet
# ---------------------------------------------------------------------------

func _target_valid() -> bool:
	return is_instance_valid(_target) and _target.is_alive()

func _update_bullet(delta: float) -> void:
	if _target_valid():
		_last_target = _target.global_position
	_trail.append(global_position)
	if _trail.size() > TRAIL_LEN:
		_trail.pop_front()
	var to_target: Vector2 = _last_target - global_position
	var dist: float = to_target.length()
	var step: float = _speed * delta
	if dist <= maxf(step, HIT_RADIUS):
		if _target_valid():
			_target.take_damage(_damage)
			Fx.burst(_last_target, _color.lightened(0.4), 4, 90.0, 2.0, 0.18)
			Sfx.play("hit", 0.15, -8.0)
		else:
			Fx.burst(_last_target, Color(0.8, 0.8, 0.8, 0.7), 3, 40.0, 2.0, 0.2)
		queue_free()
		return
	global_position += to_target / dist * step

# ---------------------------------------------------------------------------
# Shell
# ---------------------------------------------------------------------------

func _update_shell(delta: float) -> void:
	_t += delta
	var k: float = clampf(_t / _flight, 0.0, 1.0)
	global_position = _start.lerp(_aim, k)
	_height = 4.0 * _arc * k * (1.0 - k)
	if k >= 1.0:
		_explode()
		queue_free()

func _explode() -> void:
	if _enemies_node != null:
		var r_sq: float = _splash * _splash
		for child in _enemies_node.get_children():
			var e: Enemy = child as Enemy
			if e != null and e.is_alive() and e.global_position.distance_squared_to(_aim) <= r_sq:
				e.take_damage(_damage)
	Fx.ring(_aim, Color(1.0, 0.85, 0.5), _splash, 0.35, 4.0)
	Fx.burst(_aim, _color.lightened(0.2), 16, 220.0, 4.0, 0.45)
	Fx.burst(_aim, Color(1.0, 0.95, 0.6), 8, 140.0, 3.0, 0.25)
	Fx.burst(_aim, Color(0.35, 0.33, 0.3, 0.7), 8, 60.0, 7.0, 0.8)
	Sfx.play("boom", 0.1, -2.0)
	ShakeCamera.add_trauma(0.14)

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _draw() -> void:
	if _kind == Kind.BULLET:
		for i in _trail.size():
			var k: float = float(i + 1) / float(_trail.size() + 1)
			draw_circle(to_local(_trail[i]), 2.5 * k, Color(_color.lightened(0.3), 0.5 * k))
		draw_circle(Vector2.ZERO, 5.0, Color(_color, 0.35))
		draw_circle(Vector2.ZERO, 3.0, _color.lightened(0.6))
		return

	var k: float = clampf(_t / _flight, 0.0, 1.0)
	# Impact marker on the ground (area of effect), growing with the flight
	var aim_local: Vector2 = to_local(_aim)
	draw_circle(aim_local, _splash * k, Color(1.0, 0.45, 0.3, 0.10 + 0.12 * k))
	draw_arc(aim_local, _splash, 0.0, TAU, 32, Color(1.0, 0.55, 0.35, 0.25 + 0.5 * k), 1.5, true)
	# Shadow shrinks as the shell climbs
	var shadow_scale: float = 1.0 - _height / (_arc * 1.6)
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 6.0 * shadow_scale, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Shell, bigger at the top of the arc
	var shell_pos := Vector2(0, -_height)
	var size: float = 5.5 + _height / _arc * 2.5
	draw_circle(shell_pos, size, Color("2d2a26"))
	draw_circle(shell_pos + Vector2(-size * 0.3, -size * 0.3), size * 0.35, Color("6b655d"))
	draw_circle(shell_pos + Vector2(size * 0.6, -size * 0.6), 2.0, Color(1.0, 0.8, 0.3, 0.9))

# =============================================================================
# Bullets.gd — Every enemy bullet, in packed arrays, drawn by one node
# =============================================================================
# A bullet is a slot in parallel arrays (position, velocity, acceleration,
# speed limits, turn rate, kind, colour, owner, grazed flag, age). Removing
# one swaps the last slot into its place: no allocation, no node per bullet.
#
# MOTION per frame: the velocity turns by turn x dt radians (curved arms of
# spirals), its length moves by accel x dt within [min_speed, max_speed]
# (bullets that burst out then slow down), then position += velocity x dt.
#
# KINDS and radius: pellet 4, orb 6, rice 4 (elongated), large 11. The hit
# test uses HIT_SCALE x radius + the player's hitbox: bullets look bigger
# than they hurt, which is what makes dense patterns readable and fair.
#
# GRAZE: a bullet passing within graze_radius + its radius of the player's
# centre without touching counts once (grazed flag).
#
# CANCEL: bullets can be removed all at once, by owner (a large enemy's own
# bullets when it dies) or inside a growing circle (the bomb shockwave);
# the positions are returned so Game can turn them into gems.
# =============================================================================

class_name Bullets
extends Node2D

enum Kind { PELLET, ORB, RICE, LARGE }

const RADIUS: Array[float] = [4.0, 6.0, 4.0, 11.0]
const HIT_SCALE: float = 0.7
const MARGIN: float = 40.0

var field := Vector2(540.0, 720.0)
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _accel := PackedFloat32Array()
var _min_speed := PackedFloat32Array()
var _max_speed := PackedFloat32Array()
var _turn := PackedFloat32Array()
var _kind := PackedInt32Array()
var _color := PackedColorArray()
var _owner := PackedInt32Array()
var _grazed := PackedByteArray()
var _age := PackedFloat32Array()

func count() -> int:
	return _pos.size()

func spawn(at: Vector2, velocity: Vector2, kind: int, color: Color, owner: int,
		accel: float = 0.0, min_speed: float = 0.0, max_speed: float = 10000.0, turn: float = 0.0) -> void:
	_pos.append(at)
	_vel.append(velocity)
	_accel.append(accel)
	_min_speed.append(min_speed)
	_max_speed.append(max_speed)
	_turn.append(turn)
	_kind.append(kind)
	_color.append(color)
	_owner.append(owner)
	_grazed.append(0)
	_age.append(0.0)

func step(delta: float) -> void:
	var i: int = 0
	while i < _pos.size():
		_age[i] = _age[i] + delta
		var v: Vector2 = _vel[i]
		if _turn[i] != 0.0:
			v = v.rotated(_turn[i] * delta)
		if _accel[i] != 0.0:
			var speed: float = clampf(v.length() + _accel[i] * delta, _min_speed[i], _max_speed[i])
			v = v.normalized() * speed
		_vel[i] = v
		var p: Vector2 = _pos[i] + v * delta
		_pos[i] = p
		if p.x < -MARGIN or p.x > field.x + MARGIN or p.y < -MARGIN or p.y > field.y + MARGIN:
			_remove(i)
			continue
		i += 1
	queue_redraw()

## {hit: bool, at: Vector2, grazes: Array of positions}
func check_player(at: Vector2, hitbox: float, graze_radius: float) -> Dictionary:
	var grazes: Array[Vector2] = []
	for i in _pos.size():
		var r: float = RADIUS[_kind[i]]
		var d2: float = _pos[i].distance_squared_to(at)
		var hit_r: float = r * HIT_SCALE + hitbox
		if d2 < hit_r * hit_r:
			var where: Vector2 = _pos[i]
			_remove(i)
			return {hit = true, at = where, grazes = grazes}
		if _grazed[i] == 0:
			var g: float = graze_radius + r
			if d2 < g * g:
				_grazed[i] = 1
				grazes.append(_pos[i])
	return {hit = false, at = Vector2.ZERO, grazes = grazes}

func cancel_all() -> PackedVector2Array:
	var out := _pos.duplicate()
	_clear_arrays()
	return out

func cancel_owner(owner: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var i: int = _pos.size() - 1
	while i >= 0:
		if _owner[i] == owner:
			out.append(_pos[i])
			_remove(i)
		i -= 1
	return out

func cancel_in_circle(center: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r2: float = radius * radius
	var i: int = _pos.size() - 1
	while i >= 0:
		if _pos[i].distance_squared_to(center) < r2:
			out.append(_pos[i])
			_remove(i)
		i -= 1
	return out

func _remove(i: int) -> void:
	var last: int = _pos.size() - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_accel[i] = _accel[last]
		_min_speed[i] = _min_speed[last]
		_max_speed[i] = _max_speed[last]
		_turn[i] = _turn[last]
		_kind[i] = _kind[last]
		_color[i] = _color[last]
		_owner[i] = _owner[last]
		_grazed[i] = _grazed[last]
		_age[i] = _age[last]
	_pos.resize(last)
	_vel.resize(last)
	_accel.resize(last)
	_min_speed.resize(last)
	_max_speed.resize(last)
	_turn.resize(last)
	_kind.resize(last)
	_color.resize(last)
	_owner.resize(last)
	_grazed.resize(last)
	_age.resize(last)

## Packed arrays are copied on write: each one is resized by name.
func _clear_arrays() -> void:
	_pos.resize(0)
	_vel.resize(0)
	_accel.resize(0)
	_min_speed.resize(0)
	_max_speed.resize(0)
	_turn.resize(0)
	_kind.resize(0)
	_color.resize(0)
	_owner.resize(0)
	_grazed.resize(0)
	_age.resize(0)

func _draw() -> void:
	var glow: Texture2D = Tex.glow()
	var disc: Texture2D = Tex.disc()
	var n: int = _pos.size()
	# Three passes so each one is a single batch: halo, coloured body, white core
	for i in n:
		var r: float = RADIUS[_kind[i]] * _pop(i)
		Tex.put(self, glow, _pos[i], r * 2.4, Color(_color[i], 0.35))
	for i in n:
		var r: float = RADIUS[_kind[i]] * _pop(i)
		if _kind[i] == Kind.RICE:
			var dir: Vector2 = _vel[i].normalized() * r * 0.75
			Tex.put(self, disc, _pos[i] - dir, r * 0.85, _color[i])
			Tex.put(self, disc, _pos[i] + dir, r * 0.85, _color[i])
		else:
			Tex.put(self, disc, _pos[i], r, _color[i])
	for i in n:
		var r: float = RADIUS[_kind[i]] * _pop(i)
		if _kind[i] == Kind.RICE:
			Tex.put(self, disc, _pos[i], r * 0.5, Color(1.0, 1.0, 1.0, 0.95))
		else:
			Tex.put(self, disc, _pos[i], r * 0.55, Color(1.0, 1.0, 1.0, 0.95))

## New bullets appear 60 % bigger and shrink to size in 0.1 s.
func _pop(i: int) -> float:
	var a: float = _age[i]
	return 1.0 + 0.6 * maxf(1.0 - a / 0.1, 0.0)

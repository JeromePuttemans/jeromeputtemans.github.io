extends Node2D

# Shots: the ship's projectiles, in packed arrays.
#   BOLT   automatic fire, weak, slightly homing
#   SLING  a captured bullet flung back at release, strong and homing
# HOMING: every frame the velocity turns toward the nearest enemy within
#   HOMING_RANGE by at most homing x delta radians: the shot curves on its
#   way but cannot make a U-turn. PIERCE lets a sling go through that many
#   extra enemies; "explosive" slings burst on impact (upgrade).

enum Kind { BOLT, SLING }

const HOMING_RANGE: float = 380.0
const LIFETIME: float = 1.8

var arena := Rect2(0.0, 0.0, 1280.0, 720.0)
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _damage := PackedFloat32Array()
var _kind := PackedInt32Array()
var _pierce := PackedInt32Array()
var _homing := PackedFloat32Array()
var _life := PackedFloat32Array()
var _last_hit := PackedInt32Array()

func _ready() -> void:
	material = Effects.additive_material()

func count() -> int:
	return _pos.size()

func spawn(at: Vector2, velocity: Vector2, damage: float, kind: int, pierce: int, homing: float) -> void:
	_pos.append(at)
	_vel.append(velocity)
	_damage.append(damage)
	_kind.append(kind)
	_pierce.append(pierce)
	_homing.append(homing)
	_life.append(LIFETIME)
	_last_hit.append(-1)

func step(delta: float, enemies: Array) -> void:
	var i: int = 0
	while i < _pos.size():
		_life[i] = _life[i] - delta
		var p: Vector2 = _pos[i]
		var v: Vector2 = _vel[i]
		var target: Node2D = _nearest(p, enemies, int(_last_hit[i]))
		if target != null:
			var want: float = (target.global_position - p).angle()
			var turn: float = clampf(wrapf(want - v.angle(), -PI, PI), -_homing[i] * delta, _homing[i] * delta)
			v = v.rotated(turn)
		p += v * delta
		_pos[i] = p
		_vel[i] = v
		if _life[i] <= 0.0 or not arena.grow(40.0).has_point(p):
			remove(i)
			continue
		i += 1
	queue_redraw()

func _nearest(p: Vector2, enemies: Array, skip_id: int) -> Node2D:
	var best: Node2D = null
	var best_d: float = HOMING_RANGE * HOMING_RANGE
	for e in enemies:
		var en: Node2D = e as Node2D
		if not bool(en.get("alive")) or int(en.get("uid")) == skip_id:
			continue
		var d: float = en.global_position.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = en
	return best

func position_of(i: int) -> Vector2:
	return _pos[i]

func damage_of(i: int) -> float:
	return _damage[i]

func kind_of(i: int) -> int:
	return _kind[i]

## Called when shot i hits enemy uid: returns true if the shot is used up.
func consume(i: int, uid: int) -> bool:
	if _pierce[i] > 0 and _last_hit[i] != uid:
		_pierce[i] = _pierce[i] - 1
		_last_hit[i] = uid
		return false
	return true

func last_hit(i: int) -> int:
	return _last_hit[i]

func remove(i: int) -> void:
	var last: int = _pos.size() - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_damage[i] = _damage[last]
		_kind[i] = _kind[last]
		_pierce[i] = _pierce[last]
		_homing[i] = _homing[last]
		_life[i] = _life[last]
		_last_hit[i] = _last_hit[last]
	_pos.resize(last)
	_vel.resize(last)
	_damage.resize(last)
	_kind.resize(last)
	_pierce.resize(last)
	_homing.resize(last)
	_life.resize(last)
	_last_hit.resize(last)

func clear_all() -> void:
	while not _pos.is_empty():
		remove(_pos.size() - 1)

func _draw() -> void:
	for i in _pos.size():
		var dir: Vector2 = _vel[i].normalized()
		if _kind[i] == Kind.BOLT:
			draw_line(_pos[i] - dir * 14.0, _pos[i], Color(0.35, 0.85, 1.0, 0.7), 2.5)
			draw_circle(_pos[i], 2.2, Color(0.8, 0.97, 1.0))
		else:
			Effects.put(self, _pos[i], 16.0, Color(0.3, 0.9, 1.0, 0.6))
			for k in 4:
				draw_circle(_pos[i] - dir * k * 7.0, 5.0 - k * 1.0, Color(0.5, 0.95, 1.0, 0.9 - k * 0.2))
			draw_circle(_pos[i], 2.5, Color.WHITE)

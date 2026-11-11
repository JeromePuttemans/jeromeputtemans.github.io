# =============================================================================
# Shots.gd — The player's shots, in packed arrays, drawn by one node
# =============================================================================
# Two kinds: WIDE (normal mode, cyan, spread) and LANCE (focus mode, pink,
# narrow, more damage). Game tests them against the enemies after each
# step; a shot that hits is removed and leaves a spark.
# =============================================================================

class_name Shots
extends Node2D

enum Kind { WIDE, LANCE }

const RADIUS: float = 7.0

var field := Vector2(540.0, 720.0)
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _damage := PackedFloat32Array()
var _kind := PackedInt32Array()

func count() -> int:
	return _pos.size()

func spawn(at: Vector2, velocity: Vector2, damage: float, kind: int) -> void:
	_pos.append(at)
	_vel.append(velocity)
	_damage.append(damage)
	_kind.append(kind)

func step(delta: float) -> void:
	var i: int = 0
	while i < _pos.size():
		var p: Vector2 = _pos[i] + _vel[i] * delta
		_pos[i] = p
		if p.y < -30.0 or p.x < -30.0 or p.x > field.x + 30.0:
			remove(i)
			continue
		i += 1
	queue_redraw()

func position_of(i: int) -> Vector2:
	return _pos[i]

func damage_of(i: int) -> float:
	return _damage[i]

func kind_of(i: int) -> int:
	return _kind[i]

func remove(i: int) -> void:
	var last: int = _pos.size() - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_damage[i] = _damage[last]
		_kind[i] = _kind[last]
	_pos.resize(last)
	_vel.resize(last)
	_damage.resize(last)
	_kind.resize(last)

func clear() -> void:
	_pos.resize(0)
	_vel.resize(0)
	_damage.resize(0)
	_kind.resize(0)

## Player shots are drawn faint and thin on purpose: the enemy bullets must
## stay readable through a full-power volley.
func _draw() -> void:
	var glow: Texture2D = Tex.glow()
	var disc: Texture2D = Tex.disc()
	var n: int = _pos.size()
	for i in n:
		var c: Color = Color(0.4, 0.9, 1.0, 0.12) if _kind[i] == Kind.WIDE else Color(1.0, 0.45, 0.8, 0.14)
		Tex.put(self, glow, _pos[i] + Vector2(0.0, 8.0), 9.0, c)
	for i in n:
		var dir: Vector2 = _vel[i].normalized()
		var c2: Color = Color(0.55, 0.95, 1.0) if _kind[i] == Kind.WIDE else Color(1.0, 0.6, 0.88)
		for k in 3:
			Tex.put(self, disc, _pos[i] - dir * (k * 6.0), 2.6 - k * 0.6, Color(c2, 0.55 - k * 0.15))

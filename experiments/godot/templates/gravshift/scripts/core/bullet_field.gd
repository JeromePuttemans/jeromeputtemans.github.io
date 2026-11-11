extends Node2D

# BulletField: every enemy bullet, in packed arrays, drawn by one node.
#
# KINDS
#   PELLET  orange, small: the well can pull it and put it in orbit
#   HEAVY   crimson with spikes: gravity does not touch it, dodge it
# PULL: while the well is open, a pellet inside pull_radius accelerates
#   toward the ship by bullet_pull x (1 - distance / pull_radius); inside
#   capture_radius it leaves the field and joins the orbit (if the orbit
#   has room: a full orbit lets bullets through, and they hurt).
# HIT TEST: a bullet touches the ship when the distance is below its radius
#   x 0.7 + the ship's radius: bullets look bigger than they hurt.

enum Kind { PELLET, HEAVY }

const RADIUS: Array[float] = [5.0, 11.0]
const MARGIN: float = 60.0

var arena := Rect2(0.0, 0.0, 1280.0, 720.0)
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _kind := PackedInt32Array()
var _age := PackedFloat32Array()
var _time: float = 0.0

func _ready() -> void:
	material = Effects.additive_material()

func count() -> int:
	return _pos.size()

func spawn(at: Vector2, velocity: Vector2, kind: int) -> void:
	_pos.append(at)
	_vel.append(velocity)
	_kind.append(kind)
	_age.append(0.0)

## Moves the bullets; pellets near an open well are pulled and captured.
func step(delta: float, well: Node) -> void:
	_time += delta
	var open: bool = bool(well.get("active"))
	var center: Vector2 = well.get("global_position")
	var pull_r: float = float(well.call("pull_radius"))
	var capture_r: float = float(well.call("capture_radius"))
	var pull: float = float(well.call("bullet_pull"))
	var i: int = 0
	while i < _pos.size():
		_age[i] = _age[i] + delta
		var p: Vector2 = _pos[i]
		var v: Vector2 = _vel[i]
		if open and _kind[i] == Kind.PELLET:
			var d: Vector2 = center - p
			var dist: float = d.length()
			if dist < pull_r and dist > 1.0:
				v += d / dist * pull * (1.0 - dist / pull_r) * delta
				if v.length() > 480.0:
					v = v.normalized() * 480.0
				if dist < capture_r and bool(well.call("can_capture")):
					well.call("capture", p, v)
					_remove(i)
					continue
		p += v * delta
		_pos[i] = p
		_vel[i] = v
		if not arena.grow(MARGIN).has_point(p):
			_remove(i)
			continue
		i += 1
	queue_redraw()

## True when a bullet touches the ship (the bullet is removed).
func check_player(core: Vector2, radius: float) -> bool:
	for i in _pos.size():
		var r: float = RADIUS[_kind[i]] * 0.7 + radius
		if _pos[i].distance_squared_to(core) < r * r:
			_remove(i)
			return true
	return false

## Pushes the bullets inside radius outward at speed (release shockwave).
func shockwave(center: Vector2, radius: float, speed: float) -> int:
	var pushed: int = 0
	for i in _pos.size():
		var d: Vector2 = _pos[i] - center
		var dist: float = d.length()
		if dist < radius and dist > 0.5:
			_vel[i] = d / dist * maxf(speed, _vel[i].length())
			pushed += 1
	return pushed

func clear_all() -> PackedVector2Array:
	var out := _pos.duplicate()
	_pos.resize(0)
	_vel.resize(0)
	_kind.resize(0)
	_age.resize(0)
	return out

func _remove(i: int) -> void:
	var last: int = _pos.size() - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_kind[i] = _kind[last]
		_age[i] = _age[last]
	_pos.resize(last)
	_vel.resize(last)
	_kind.resize(last)
	_age.resize(last)

func _draw() -> void:
	for i in _pos.size():
		var pop: float = 1.0 + 0.6 * maxf(1.0 - _age[i] / 0.1, 0.0)
		if _kind[i] == Kind.PELLET:
			Effects.put(self, _pos[i], 14.0 * pop, Color(1.0, 0.5, 0.15, 0.55))
			draw_circle(_pos[i], 4.5 * pop, Color(1.0, 0.62, 0.25))
			draw_circle(_pos[i], 2.2 * pop, Color(1.0, 0.95, 0.8))
		else:
			Effects.put(self, _pos[i], 26.0 * pop, Color(1.0, 0.1, 0.2, 0.6))
			var spin: float = _time * 6.0 + float(i)
			for k in 6:
				var a: float = spin + TAU * k / 6.0
				draw_line(_pos[i] + Vector2.RIGHT.rotated(a) * 8.0, _pos[i] + Vector2.RIGHT.rotated(a) * 14.0 * pop, Color(1.0, 0.25, 0.3), 2.0)
			draw_circle(_pos[i], 9.0 * pop, Color(0.9, 0.1, 0.18))
			draw_circle(_pos[i], 4.5 * pop, Color(1.0, 0.7, 0.7))

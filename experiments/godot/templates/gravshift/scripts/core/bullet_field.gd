extends Node2D

# BulletField: every enemy bullet, in packed arrays, drawn by one node.
#
# KINDS
#   PELLET  orange, small: the well can pull it and put it in orbit
#   HEAVY   crimson with spikes: gravity does not touch it, dodge it (only
#           the Nova swallows it)
# PULL: while the well is open, a pellet inside pull_radius accelerates
#   toward the ship by bullet_pull x (1 - distance / pull_radius); inside
#   capture_radius it leaves the field and joins the orbit (if the orbit
#   has room: a full orbit lets bullets through, and they hurt).
#   During the Nova the pull radius covers the arena, and heavy orbs within
#   nova_swallow_radius are pulled too and destroyed at the capture radius.
# SINKS: enemy gravity wells (the Siphon) pull the free pellets near them
#   the same way and absorb them.
# HIT TEST: a bullet touches the ship when the distance is below its radius
#   x 0.7 + the ship's radius: bullets look bigger than they hurt.
# GRAZE: a bullet that enters the ring graze_radius px beyond that distance
#   and leaves it again without hitting counts once as a graze.

enum Kind { PELLET, HEAVY }

const RADIUS: Array[float] = [5.0, 11.0]
const MARGIN: float = 60.0

var arena := Rect2(0.0, 0.0, 1280.0, 720.0)
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _kind := PackedInt32Array()
var _age := PackedFloat32Array()
var _graze := PackedByteArray()    # 0 = never close, 1 = inside the ring, 2 = counted
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
	_graze.append(0)

## Moves the bullets; pellets near an open well are pulled and captured,
## pellets near an enemy sink are absorbed by it.
func step(delta: float, well: GravityField, sinks: Array) -> void:
	_time += delta
	var open: bool = well.active
	var nova: bool = well.nova_active()
	var center: Vector2 = well.global_position
	var pull_r: float = well.pull_radius()
	var capture_r: float = well.capture_radius()
	var pull: float = well.bullet_pull()
	var swallow_r: float = well.swallow_radius()
	var max_speed: float = 950.0 if nova else 480.0
	var i: int = 0
	while i < _pos.size():
		_age[i] = _age[i] + delta
		var p: Vector2 = _pos[i]
		var v: Vector2 = _vel[i]
		var d: Vector2 = center - p
		var dist: float = d.length()
		var pulled: bool = false
		if open and dist > 1.0 and (_kind[i] == Kind.PELLET or (nova and dist < swallow_r)):
			if dist < pull_r:
				pulled = true
				v += d / dist * pull * (1.0 - dist / pull_r) * delta
				if v.length() > max_speed:
					v = v.normalized() * max_speed
				if dist < capture_r:
					if _kind[i] == Kind.HEAVY:
						well.swallow(p)
						_remove(i)
						continue
					if well.can_capture():
						well.capture(p, v)
						_remove(i)
						continue
		var absorbed: bool = false
		if not pulled and _kind[i] == Kind.PELLET:
			for s in sinks:
				var sink: Dictionary = s as Dictionary
				var ds: Vector2 = (sink["pos"] as Vector2) - p
				var dist_s: float = ds.length()
				var reach: float = float(sink["radius"])
				if dist_s < reach and dist_s > 1.0:
					v += ds / dist_s * float(sink["pull"]) * (1.0 - dist_s / reach) * delta
					v = v.limit_length(420.0)
					if dist_s < float(sink["absorb"]):
						(sink["node"] as Node).call("absorb", p)
						absorbed = true
					break
		if absorbed:
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

## Bullets that just left the graze ring without hitting: Vector3(x, y, kind).
## Pellets count only when pellets_too (the well is closed: an open well
## would have caught them).
func graze(core: Vector2, radius: float, ring: float, pellets_too: bool) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in _pos.size():
		if _graze[i] == 2:
			continue
		var outer: float = RADIUS[_kind[i]] * 0.7 + radius + ring
		var inside: bool = _pos[i].distance_squared_to(core) < outer * outer
		if inside and _graze[i] == 0:
			_graze[i] = 1
		elif not inside and _graze[i] == 1:
			_graze[i] = 2
			if _kind[i] == Kind.HEAVY or pellets_too:
				out.append(Vector3(_pos[i].x, _pos[i].y, _kind[i]))
	return out

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
	_graze.resize(0)
	return out

func _remove(i: int) -> void:
	var last: int = _pos.size() - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_kind[i] = _kind[last]
		_age[i] = _age[last]
		_graze[i] = _graze[last]
	_pos.resize(last)
	_vel.resize(last)
	_kind.resize(last)
	_age.resize(last)
	_graze.resize(last)

func _draw() -> void:
	for i in _pos.size():
		var pop: float = 1.0 + 0.6 * maxf(1.0 - _age[i] / 0.1, 0.0)
		var p: Vector2 = _pos[i]
		if _kind[i] == Kind.PELLET:
			var tail: Vector2 = p - _vel[i].normalized() * 7.0
			draw_circle(tail, 2.6, Color(1.0, 0.45, 0.1, 0.35))
			Effects.put(self, p, 14.0 * pop, Color(1.0, 0.5, 0.15, 0.55))
			draw_circle(p, 4.5 * pop, Color(1.0, 0.62, 0.25))
			draw_circle(p, 2.2 * pop, Color(1.0, 0.95, 0.8))
		else:
			Effects.put(self, p, 26.0 * pop, Color(1.0, 0.1, 0.2, 0.6))
			var spin: float = _time * 6.0 + float(i)
			for k in 6:
				var a: float = spin + TAU * k / 6.0
				draw_line(p + Vector2.RIGHT.rotated(a) * 8.0, p + Vector2.RIGHT.rotated(a) * 14.0 * pop, Color(1.0, 0.25, 0.3), 2.0)
			draw_circle(p, 9.0 * pop, Color(0.9, 0.1, 0.18))
			draw_circle(p, 4.5 * pop, Color(1.0, 0.7, 0.7))

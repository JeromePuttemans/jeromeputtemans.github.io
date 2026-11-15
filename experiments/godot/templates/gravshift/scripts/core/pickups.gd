extends Node2D

# Pickups: what destroyed enemies leave behind, in packed arrays.
#   SHARD   small blue diamond. A destroyed enemy drops one per
#           shards_per_points points (at most shards_max; a boss drops
#           boss_shards). Collected: shard_points x multiplier points and
#           shard_nova Nova charge.
#   REPAIR  green cross (repair_drop_chance per kill while the hull is not
#           full): one hull point.
# MAGNET: a pickup inside shard_magnet px of the ship (x2 with the magnet
#   upgrade), or inside 1.3 x the pull radius while the well is open, is
#   drawn to the ship at shard_pull px/s², harder the closer it gets.
#   Elsewhere it drifts and slows down. It disappears after shard_life s
#   (repair_life for a repair), blinking for its last 1.5 s.
# Colour language: cool colours (cyan, green) are yours to take, warm
# colours (orange, red) are the enemy's.

enum Kind { SHARD, REPAIR }

const COLLECT_RADIUS: float = 20.0

var gm: Node = null
var magnet_mult: float = 1.0
var arena := Rect2(0.0, 0.0, 1280.0, 720.0)

var _g: Dictionary = {}
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _kind := PackedInt32Array()
var _phase := PackedFloat32Array()
var _time: float = 0.0

func setup(gameplay: Dictionary) -> void:
	_g = gameplay
	material = Effects.additive_material()

func count() -> int:
	return _pos.size()

func spawn(at: Vector2, kind: int, amount: int, speed: float) -> void:
	for i in amount:
		_pos.append(at + Vector2.RIGHT.rotated(randf() * TAU) * randf() * 6.0)
		_vel.append(Vector2.RIGHT.rotated(randf() * TAU) * speed * randf_range(0.35, 1.0))
		_life.append(float(_g.get("repair_life" if kind == Kind.REPAIR else "shard_life", 7.0)) * randf_range(0.9, 1.1))
		_kind.append(kind)
		_phase.append(randf() * TAU)

func step(delta: float, ship: Vector2, well_open: bool, well_radius: float, alive: bool) -> void:
	_time += delta
	var magnet: float = float(_g.get("shard_magnet", 120.0)) * magnet_mult
	if well_open:
		magnet = maxf(magnet, well_radius * 1.3)
	var pull: float = float(_g.get("shard_pull", 2400.0))
	var inner: Rect2 = arena.grow(-8.0)
	var i: int = 0
	while i < _pos.size():
		_life[i] = _life[i] - delta
		if _life[i] <= 0.0:
			_remove(i)
			continue
		var p: Vector2 = _pos[i]
		var v: Vector2 = _vel[i]
		var d: Vector2 = ship - p
		var dist: float = d.length()
		if alive and dist < magnet and dist > 0.5:
			v += d / dist * pull * (0.35 + 0.65 * (1.0 - dist / magnet)) * delta
			v = v.limit_length(900.0)
		else:
			v *= 1.0 - minf(2.6 * delta, 1.0)
		p += v * delta
		if p.x < inner.position.x or p.x > inner.end.x:
			v.x = -v.x * 0.5
			p.x = clampf(p.x, inner.position.x, inner.end.x)
		if p.y < inner.position.y or p.y > inner.end.y:
			v.y = -v.y * 0.5
			p.y = clampf(p.y, inner.position.y, inner.end.y)
		if alive and p.distance_squared_to(ship) < COLLECT_RADIUS * COLLECT_RADIUS:
			gm.call("collect_pickup", _kind[i], p)
			_remove(i)
			continue
		_pos[i] = p
		_vel[i] = v
		i += 1
	queue_redraw()

func clear_all() -> void:
	_pos.resize(0)
	_vel.resize(0)
	_life.resize(0)
	_kind.resize(0)
	_phase.resize(0)

func _remove(i: int) -> void:
	var last: int = _pos.size() - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_life[i] = _life[last]
		_kind[i] = _kind[last]
		_phase[i] = _phase[last]
	_pos.resize(last)
	_vel.resize(last)
	_life.resize(last)
	_kind.resize(last)
	_phase.resize(last)

func _draw() -> void:
	for i in _pos.size():
		var alpha: float = 1.0
		if _life[i] < 1.5 and fmod(_time * 10.0, 1.0) < 0.45:
			alpha = 0.25
		var p: Vector2 = _pos[i]
		if _kind[i] == Kind.SHARD:
			var a: float = _time * 4.0 + _phase[i]
			var s: float = 4.5 + 0.8 * sin(_time * 9.0 + _phase[i])
			Effects.put(self, p, 13.0, Color(0.3, 0.8, 1.0, 0.45 * alpha))
			var f := Vector2.RIGHT.rotated(a) * s
			var g := Vector2.RIGHT.rotated(a + PI * 0.5) * s * 0.55
			draw_colored_polygon(PackedVector2Array([p + f, p + g, p - f, p - g]), Color(0.65, 0.95, 1.0, alpha))
		else:
			var bob: Vector2 = Vector2(0.0, sin(_time * 4.0 + _phase[i]) * 2.0)
			var c := Color(0.45, 1.0, 0.55, alpha)
			Effects.put(self, p + bob, 26.0, Color(0.2, 1.0, 0.4, 0.5 * alpha))
			draw_arc(p + bob, 12.0, _time * 2.0, _time * 2.0 + TAU * 0.8, 20, Color(c, 0.7 * alpha), 1.5)
			draw_rect(Rect2(p + bob - Vector2(2.5, 7.0), Vector2(5.0, 14.0)), c)
			draw_rect(Rect2(p + bob - Vector2(7.0, 2.5), Vector2(14.0, 5.0)), c)

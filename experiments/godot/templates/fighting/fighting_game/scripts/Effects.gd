# =============================================================================
# Effects.gd — Hit sparks, block shields, dust, flashes
# =============================================================================
# Two instances live in a Match: one with additive blending (sparks and
# flashes add up like light) and one with normal blending (dust clouds).
# Particles: packed arrays (position, velocity, life, size, colour, kind),
# a dead one is replaced by the last one.
#   hit()     a star of streaks along the attack direction, a glow, a ring
#   block()   a blue hexagon shield and a few sparks
#   counter() a larger orange burst      armor()  a white ripple
#   quake()   a shockwave running along the floor
# =============================================================================

class_name Effects
extends Node2D

enum Kind { SPARK, STREAK, DUST }

var additive: bool = true
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _color := PackedColorArray()
var _kind := PackedInt32Array()
var _shapes: Array[Dictionary] = []
var _flash: float = 0.0
var _flash_color := Color.WHITE

func _ready() -> void:
	z_index = 20 if additive else 5
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

func hit(at: Vector2, dir: int, heavy: bool, tint: Color) -> void:
	var count: int = 14 if heavy else 8
	for i in count:
		var a: float = randf_range(-0.9, 0.9)
		var v := Vector2(dir, 0.0).rotated(a) * randf_range(4.0, 11.0 if heavy else 7.0)
		_spawn(at, v, randf_range(0.12, 0.25), randf_range(2.0, 4.0), Color(1.0, 0.95, 0.75), Kind.STREAK)
	for i in (8 if heavy else 4):
		_spawn(at, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(1.0, 4.0), 0.3, randf_range(4.0, 8.0), tint, Kind.SPARK)
	_shapes.append({kind = "star", pos = at, life = 0.14, max_life = 0.14, size = 70.0 if heavy else 46.0, dir = dir, color = Color(1.0, 0.95, 0.8)})
	_shapes.append({kind = "ring", pos = at, life = 0.25, max_life = 0.25, size = 60.0 if heavy else 36.0, color = tint})

func block(at: Vector2, facing: int) -> void:
	_shapes.append({kind = "shield", pos = at, life = 0.2, max_life = 0.2, size = 36.0, dir = facing, color = Color(0.45, 0.75, 1.0)})
	for i in 5:
		_spawn(at, Vector2(-facing, 0.0).rotated(randf_range(-1.2, 1.2)) * randf_range(2.0, 6.0), 0.2, 3.0, Color(0.6, 0.85, 1.0), Kind.STREAK)

func counter(at: Vector2) -> void:
	_shapes.append({kind = "ring", pos = at, life = 0.4, max_life = 0.4, size = 110.0, color = Color(1.0, 0.6, 0.25)})
	for i in 20:
		_spawn(at, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(3.0, 10.0), 0.4, randf_range(3.0, 6.0), Color(1.0, 0.7, 0.3), Kind.STREAK)

func armor(at: Vector2) -> void:
	_shapes.append({kind = "ring", pos = at, life = 0.3, max_life = 0.3, size = 50.0, color = Color(1.0, 1.0, 1.0)})

func quake(at: Vector2) -> void:
	_shapes.append({kind = "quake", pos = at, life = 0.9, max_life = 0.9, size = 1800.0, color = Color(1.0, 0.55, 0.2)})
	for i in 40:
		_spawn(at + Vector2(randf_range(-900.0, 900.0), 0.0), Vector2(0.0, -randf_range(2.0, 9.0)), randf_range(0.4, 0.9), randf_range(4.0, 9.0), Color(1.0, 0.6, 0.25), Kind.SPARK)

func super_flash(at: Vector2, color: Color) -> void:
	_shapes.append({kind = "burst", pos = at, life = 0.6, max_life = 0.6, size = 160.0, color = color})
	flash(color, 0.35)

func dust(at: Vector2, count: int) -> void:
	for i in count:
		var v := Vector2(randf_range(-3.0, 3.0), randf_range(-1.5, -0.2))
		_spawn(at + Vector2(randf_range(-20.0, 20.0), -4.0), v, randf_range(0.35, 0.6), randf_range(6.0, 12.0), Color(0.75, 0.68, 0.6, 0.5), Kind.DUST)

func flash(color: Color, strength: float) -> void:
	_flash_color = color
	_flash = maxf(_flash, strength)

func _spawn(at: Vector2, v: Vector2, life: float, size: float, color: Color, kind: Kind) -> void:
	_pos.append(at)
	_vel.append(v)
	_life.append(life)
	_max_life.append(life)
	_size.append(size)
	_color.append(color)
	_kind.append(kind)

func _process(delta: float) -> void:
	var i: int = 0
	while i < _pos.size():
		_life[i] = _life[i] - delta
		if _life[i] <= 0.0:
			var last: int = _pos.size() - 1
			_pos[i] = _pos[last]
			_vel[i] = _vel[last]
			_life[i] = _life[last]
			_max_life[i] = _max_life[last]
			_size[i] = _size[last]
			_color[i] = _color[last]
			_kind[i] = _kind[last]
			_pos.resize(last)
			_vel.resize(last)
			_life.resize(last)
			_max_life.resize(last)
			_size.resize(last)
			_color.resize(last)
			_kind.resize(last)
			continue
		_pos[i] = _pos[i] + _vel[i] * delta * 60.0
		_vel[i] = _vel[i] * (1.0 - minf(4.0 * delta, 1.0))
		if _kind[i] == Kind.DUST:
			_size[i] = _size[i] + delta * 18.0
		i += 1
	for k in range(_shapes.size() - 1, -1, -1):
		var s: Dictionary = _shapes[k]
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) <= 0.0:
			_shapes.remove_at(k)
	_flash = maxf(_flash - delta * 3.0, 0.0)
	queue_redraw()

func _draw() -> void:
	var glow: Texture2D = Fx.glow()
	for i in _pos.size():
		var t: float = _life[i] / _max_life[i]
		match _kind[i]:
			Kind.STREAK:
				var tail: Vector2 = _pos[i] - _vel[i].normalized() * _size[i] * 5.0 * t
				draw_line(tail, _pos[i], Color(_color[i], t), _size[i] * t)
			Kind.DUST:
				draw_circle(_pos[i], _size[i], Color(_color[i], _color[i].a * t))
			_:
				Fx.put(self, glow, _pos[i], _size[i] * 2.0, Color(_color[i], t))
	for s in _shapes:
		var t: float = float(s["life"]) / float(s["max_life"])
		var c: Color = s["color"]
		var at: Vector2 = s["pos"]
		var size: float = float(s["size"])
		match str(s["kind"]):
			"star":
				Fx.put(self, glow, at, size * 1.4, Color(c, t))
				for k in 6:
					var a: float = TAU * k / 6.0 + 0.3
					var length: float = size * (0.6 + 0.4 * float(k % 2)) * (1.2 - t * 0.4)
					draw_colored_polygon(PackedVector2Array([at + Vector2.RIGHT.rotated(a - 0.12) * 6.0, at + Vector2.RIGHT.rotated(a) * length, at + Vector2.RIGHT.rotated(a + 0.12) * 6.0]), Color(c, t))
			"ring":
				draw_arc(at, size * (1.0 - t * 0.7), 0.0, TAU, 40, Color(c, t), 4.0 * t + 1.0)
			"shield":
				var hex := PackedVector2Array()
				for k in 7:
					hex.append(at + Vector2.RIGHT.rotated(TAU * k / 6.0 + PI / 6.0) * size * (1.2 - t * 0.2))
				draw_polyline(hex, Color(c, t), 3.0)
				Fx.put(self, glow, at, size * 1.6, Color(c, t * 0.6))
			"quake":
				var reach: float = size * (1.0 - t)
				for side in [-1.0, 1.0]:
					var x: float = at.x + side * reach * 0.5
					Fx.put(self, glow, Vector2(x, at.y - 10.0), 80.0, Color(c, t))
					draw_line(Vector2(at.x, at.y - 2.0), Vector2(x, at.y - 2.0), Color(c, t * 0.8), 6.0)
			"burst":
				Fx.put(self, glow, at, size * (2.0 - t), Color(c, t * 0.8))
				for k in 12:
					var a2: float = TAU * k / 12.0
					draw_line(at + Vector2.RIGHT.rotated(a2) * size * 0.3 * (2.0 - t), at + Vector2.RIGHT.rotated(a2) * size * (2.2 - t), Color(c, t * 0.6), 3.0)
	if _flash > 0.0 and additive:
		var view: Rect2 = get_viewport().get_visible_rect()
		var inv: Transform2D = get_global_transform_with_canvas().affine_inverse()
		var top_left: Vector2 = inv * view.position
		var bottom_right: Vector2 = inv * view.end
		draw_rect(Rect2(top_left, bottom_right - top_left), Color(_flash_color, _flash * 0.5))

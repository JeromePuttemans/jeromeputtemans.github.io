# =============================================================================
# Effects.gd — Particles, rings and floating texts, drawn above the level
# =============================================================================
# Particles live in packed arrays (position, velocity, life, size, colour,
# gravity, kind) and a dead one is replaced by the last one: hundreds stay
# cheap and nothing is allocated per particle. Kinds:
#   DUST     soft circles that slow down and fade (steps, jumps, landings)
#   LEAF     small spinning leaves with gravity (death, air jump)
#   SPARK    star-shaped glints (pickups, lanterns)
#   BLOB     solid drops (stomps, seeds)
# =============================================================================

class_name Effects
extends Node2D

enum Kind { DUST, LEAF, SPARK, BLOB }

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _color := PackedColorArray()
var _gravity := PackedFloat32Array()
var _kind := PackedInt32Array()
var _rings: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _font: Font = null

func _ready() -> void:
	z_index = 30
	_font = ThemeDB.fallback_font

func _process(delta: float) -> void:
	_update_particles(delta)
	for i in range(_rings.size() - 1, -1, -1):
		var r: Dictionary = _rings[i]
		r["life"] = float(r["life"]) - delta
		if float(r["life"]) <= 0.0:
			_rings.remove_at(i)
	for i in range(_texts.size() - 1, -1, -1):
		var t: Dictionary = _texts[i]
		t["life"] = float(t["life"]) - delta
		t["pos"] = (t["pos"] as Vector2) + Vector2(0.0, -34.0 * delta)
		if float(t["life"]) <= 0.0:
			_texts.remove_at(i)
	queue_redraw()

# =============================================================================
# API
# =============================================================================

func dust(at: Vector2, count: int, drift: Vector2) -> void:
	for i in count:
		var v: Vector2 = drift + Vector2(randf_range(-60.0, 60.0), randf_range(-30.0, 5.0))
		_spawn(at + Vector2(randf_range(-6.0, 6.0), 0.0), v, randf_range(0.3, 0.5), randf_range(3.0, 6.0), Color(1.0, 0.98, 0.92, 0.7), -40.0, Kind.DUST)

func leaves(at: Vector2, count: int) -> void:
	for i in count:
		var v := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80.0, 260.0) + Vector2(0.0, -120.0)
		var c: Color = PlayerArt.LEAF if i % 3 else PlayerArt.BODY
		_spawn(at, v, randf_range(0.6, 1.0), randf_range(4.0, 6.5), c, 600.0, Kind.LEAF)

func sparkle(at: Vector2, color: Color, count: int) -> void:
	for i in count:
		var v := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 170.0)
		_spawn(at, v, randf_range(0.35, 0.7), randf_range(3.0, 6.0), color, 60.0, Kind.SPARK)

func burst(at: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		var v := Vector2.RIGHT.rotated(randf() * TAU) * speed * randf_range(0.3, 1.0) + Vector2(0.0, -80.0)
		_spawn(at, v, randf_range(0.3, 0.6), randf_range(2.5, 5.0), color, 700.0, Kind.BLOB)

func ring(at: Vector2, color: Color, radius: float, life: float, width: float) -> void:
	_rings.append({pos = at, radius = radius, life = life, max_life = life, color = color, width = width})

func float_text(at: Vector2, text: String, color: Color, font_size: int) -> void:
	_texts.append({pos = at, text = text, color = color, size = font_size, life = 1.3})

# =============================================================================
# SIMULATION AND DRAWING
# =============================================================================

func _spawn(at: Vector2, velocity: Vector2, life: float, size: float, color: Color, gravity: float, kind: Kind) -> void:
	_pos.append(at)
	_vel.append(velocity)
	_life.append(life)
	_max_life.append(life)
	_size.append(size)
	_color.append(color)
	_gravity.append(gravity)
	_kind.append(kind)

func _update_particles(delta: float) -> void:
	var i: int = 0
	while i < _pos.size():
		_life[i] = _life[i] - delta
		if _life[i] <= 0.0:
			_remove(i)
			continue
		var drag: float = 4.0 if _kind[i] == Kind.DUST or _kind[i] == Kind.SPARK else 1.2
		_vel[i] = _vel[i] * (1.0 - minf(drag * delta, 1.0)) + Vector2(0.0, _gravity[i] * delta)
		_pos[i] = _pos[i] + _vel[i] * delta
		i += 1

func _remove(i: int) -> void:
	var last: int = _pos.size() - 1
	_pos[i] = _pos[last]
	_vel[i] = _vel[last]
	_life[i] = _life[last]
	_max_life[i] = _max_life[last]
	_size[i] = _size[last]
	_color[i] = _color[last]
	_gravity[i] = _gravity[last]
	_kind[i] = _kind[last]
	_pos.resize(last)
	_vel.resize(last)
	_life.resize(last)
	_max_life.resize(last)
	_size.resize(last)
	_color.resize(last)
	_gravity.resize(last)
	_kind.resize(last)

func _draw() -> void:
	for i in _pos.size():
		var t: float = _life[i] / _max_life[i]
		var c: Color = _color[i]
		match _kind[i]:
			Kind.DUST:
				draw_circle(_pos[i], _size[i] * (1.6 - t * 0.6), Color(c, c.a * t))
			Kind.LEAF:
				var angle: float = _life[i] * 9.0 + float(i)
				draw_set_transform(_pos[i], angle, Vector2.ONE)
				PlayerArt.ellipse(self, Vector2.ZERO, _size[i], _size[i] * 0.45, Color(c, minf(t * 2.0, 1.0)))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			Kind.SPARK:
				var s: float = _size[i] * t
				var col := Color(c, minf(t * 1.5, 1.0))
				draw_line(_pos[i] - Vector2(s, 0.0), _pos[i] + Vector2(s, 0.0), col, 1.5)
				draw_line(_pos[i] - Vector2(0.0, s), _pos[i] + Vector2(0.0, s), col, 1.5)
				draw_circle(_pos[i], s * 0.35, col)
			_:
				draw_circle(_pos[i], _size[i] * (0.5 + 0.5 * t), Color(c, minf(t * 2.0, 1.0)))
	for r in _rings:
		var t: float = float(r["life"]) / float(r["max_life"])
		var radius: float = float(r["radius"]) * (1.0 - t * 0.8)
		var c: Color = r["color"] as Color
		draw_arc(r["pos"] as Vector2, radius, 0.0, TAU, 40, Color(c, c.a * t), float(r["width"]) * (0.4 + t))
	for text in _texts:
		var t: float = minf(float(text["life"]) / 0.4, 1.0)
		var size: int = int(text["size"])
		var label: String = text["text"] as String
		var width: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var p: Vector2 = (text["pos"] as Vector2) - Vector2(width * 0.5, 0.0)
		draw_string_outline(_font, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.1, 0.07, 0.04, 0.8 * t))
		draw_string(_font, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(text["color"] as Color, t))

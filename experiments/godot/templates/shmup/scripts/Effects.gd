# =============================================================================
# Effects.gd — Light effects with additive blending: sparks, flashes, rings
# =============================================================================
# Additive blending adds the colours of what is drawn to what is behind:
# overlapping sparks get brighter, like light, and dark parts vanish.
# Particles are packed arrays drawn with the shared glow texture (one batch).
# =============================================================================

class_name Effects
extends Node2D

var field := Vector2(540.0, 720.0)
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _color := PackedColorArray()
var _rings: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _screen_flash: float = 0.0
var _screen_color := Color.WHITE

func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

func spark(at: Vector2, color: Color, count: int, speed: float, life: float, size: float) -> void:
	for i in count:
		var dir: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
		_spawn(at, dir * speed * randf_range(0.25, 1.0), life * randf_range(0.6, 1.0), size * randf_range(0.6, 1.3), color)

func directed(at: Vector2, color: Color, count: int, direction: Vector2, spread: float, speed: float) -> void:
	for i in count:
		var dir: Vector2 = direction.rotated(randf_range(-spread, spread))
		_spawn(at, dir * speed * randf_range(0.4, 1.0), randf_range(0.12, 0.25), randf_range(2.0, 3.5), color)

func explosion(at: Vector2, radius: float, color: Color) -> void:
	_flashes.append({pos = at, radius = radius * 2.6, life = 0.18, max_life = 0.18, color = color.lightened(0.4)})
	spark(at, color, int(10 + radius * 0.8), 120.0 + radius * 9.0, 0.55, 3.0 + radius * 0.08)
	spark(at, Color(1.0, 0.95, 0.8), int(6 + radius * 0.3), 80.0 + radius * 5.0, 0.35, 2.5)
	ring(at, color, radius * 2.2, 0.35, 3.0)

func ring(at: Vector2, color: Color, radius: float, life: float, width: float) -> void:
	_rings.append({pos = at, radius = radius, life = life, max_life = life, color = color, width = width})

func flash(color: Color, strength: float) -> void:
	_screen_color = color
	_screen_flash = maxf(_screen_flash, strength)

func clear() -> void:
	_pos.resize(0)
	_vel.resize(0)
	_life.resize(0)
	_max_life.resize(0)
	_size.resize(0)
	_color.resize(0)
	_rings.clear()
	_flashes.clear()
	_screen_flash = 0.0

func _spawn(at: Vector2, velocity: Vector2, life: float, size: float, color: Color) -> void:
	_pos.append(at)
	_vel.append(velocity)
	_life.append(life)
	_max_life.append(life)
	_size.append(size)
	_color.append(color)

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
			_pos.resize(last)
			_vel.resize(last)
			_life.resize(last)
			_max_life.resize(last)
			_size.resize(last)
			_color.resize(last)
			continue
		_vel[i] = _vel[i] * (1.0 - minf(3.5 * delta, 1.0))
		_pos[i] = _pos[i] + _vel[i] * delta
		i += 1
	for list in [_rings, _flashes]:
		for k in range(list.size() - 1, -1, -1):
			var e: Dictionary = list[k]
			e["life"] = float(e["life"]) - delta
			if float(e["life"]) <= 0.0:
				list.remove_at(k)
	_screen_flash = maxf(_screen_flash - delta * 3.0, 0.0)
	queue_redraw()

func _draw() -> void:
	var glow: Texture2D = Tex.glow()
	for f in _flashes:
		var t: float = float(f["life"]) / float(f["max_life"])
		Tex.put(self, glow, f["pos"] as Vector2, float(f["radius"]) * (1.2 - t * 0.2), Color(f["color"] as Color, t))
	for i in _pos.size():
		var t: float = _life[i] / _max_life[i]
		Tex.put(self, glow, _pos[i], _size[i] * (1.0 + t), Color(_color[i], t))
	for r in _rings:
		var t: float = float(r["life"]) / float(r["max_life"])
		var radius: float = float(r["radius"]) * (1.0 - t * t * 0.85)
		var c: Color = r["color"] as Color
		draw_arc(r["pos"] as Vector2, radius, 0.0, TAU, 56, Color(c, c.a * t), float(r["width"]) * (0.5 + t))
	if _screen_flash > 0.0:
		draw_rect(Rect2(Vector2(-40, -40), field + Vector2(80, 80)), Color(_screen_color, _screen_flash * 0.6))

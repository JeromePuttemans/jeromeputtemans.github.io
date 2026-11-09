extends Node2D

# Effects: particles, shock rings, floating texts, the void edge and the
# screen shake. Child of World, drawn above the entities with additive
# blending (bright colours add up, like light).
#
# PARTICLES are stored in packed arrays (position, velocity, life, size,
#   colour) and removed by swapping with the last one: hundreds stay cheap.
# SHAKE uses "trauma": each impact adds trauma (0..1), the offset applied to
#   World is random * trauma^2 * SHAKE_PIXELS, and trauma decays over time.
#   Squaring keeps small hits subtle and big ones violent.
# VOID EDGE: red bands and a jagged energy line at x = 0, always faintly
#   visible, brighter as the ship gets close (set_void_intensity, 0..1).

const SHAKE_PIXELS: float = 16.0
const SHAKE_DECAY: float = 1.8
const VOID_BANDS: int = 9
const VOID_BAND_WIDTH: float = 10.0
const VOID_COLOR: Color = Color(1.0, 0.18, 0.25)

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _color := PackedColorArray()
var _rings: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _trauma: float = 0.0
var _void_intensity: float = 0.0
var _time: float = 0.0
var _world: Node2D = null
var _font: Font = null

func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	_world = get_parent() as Node2D
	_font = ThemeDB.fallback_font

func _process(delta: float) -> void:
	_time += delta
	_update_particles(delta)
	_update_rings(delta)
	_update_texts(delta)
	_update_shake(delta)
	queue_redraw()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func burst(at: Vector2, color: Color, count: int, speed: float, size: float, life: float) -> void:
	for i in count:
		var direction: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
		_spawn(at, direction * speed * randf_range(0.3, 1.0), life * randf_range(0.6, 1.0), size * randf_range(0.6, 1.2), color)

func explosion(at: Vector2, color: Color, scale_factor: float) -> void:
	burst(at, color, int(18 * scale_factor), 260.0 * sqrt(scale_factor), 3.5, 0.6)
	burst(at, Color(1.0, 0.95, 0.85), int(8 * scale_factor), 140.0, 2.5, 0.35)
	ring(at, color, 40.0 * scale_factor, 0.35, 3.0)

func sparks(at: Vector2, color: Color, direction: Vector2) -> void:
	for i in 5:
		var spread: Vector2 = direction.rotated(randf_range(-0.9, 0.9))
		_spawn(at, spread * randf_range(120.0, 320.0), randf_range(0.12, 0.25), 2.0, color)

func ring(at: Vector2, color: Color, radius: float, life: float, width: float) -> void:
	_rings.append({pos = at, radius = radius, life = life, max_life = life, color = color, width = width})

func float_text(at: Vector2, text: String, color: Color, font_size: int) -> void:
	_texts.append({pos = at, text = text, color = color, size = font_size, life = 0.9})

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func set_void_intensity(value: float) -> void:
	_void_intensity = clampf(value, 0.0, 1.0)

func clear() -> void:
	_pos.clear()
	_vel.clear()
	_life.clear()
	_max_life.clear()
	_size.clear()
	_color.clear()
	_rings.clear()
	_texts.clear()

# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------

func _spawn(at: Vector2, velocity: Vector2, life: float, size: float, color: Color) -> void:
	_pos.append(at)
	_vel.append(velocity)
	_life.append(life)
	_max_life.append(life)
	_size.append(size)
	_color.append(color)

func _update_particles(delta: float) -> void:
	var i: int = 0
	while i < _pos.size():
		_life[i] = _life[i] - delta
		if _life[i] <= 0.0:
			_remove_particle(i)
			continue
		_vel[i] = _vel[i] * (1.0 - minf(3.0 * delta, 1.0))
		_pos[i] = _pos[i] + _vel[i] * delta
		i += 1

func _remove_particle(i: int) -> void:
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

func _update_rings(delta: float) -> void:
	for i in range(_rings.size() - 1, -1, -1):
		var r: Dictionary = _rings[i]
		r["life"] = float(r["life"]) - delta
		if float(r["life"]) <= 0.0:
			_rings.remove_at(i)

func _update_texts(delta: float) -> void:
	for i in range(_texts.size() - 1, -1, -1):
		var t: Dictionary = _texts[i]
		t["life"] = float(t["life"]) - delta
		t["pos"] = (t["pos"] as Vector2) + Vector2(0.0, -40.0 * delta)
		if float(t["life"]) <= 0.0:
			_texts.remove_at(i)

func _update_shake(delta: float) -> void:
	_trauma = maxf(_trauma - SHAKE_DECAY * delta, 0.0)
	if not is_instance_valid(_world):
		return
	var amount: float = _trauma * _trauma * SHAKE_PIXELS
	_world.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	_draw_void()
	for i in _pos.size():
		var t: float = _life[i] / _max_life[i]
		draw_circle(_pos[i], _size[i] * (0.4 + 0.6 * t), Color(_color[i], t))
	for r in _rings:
		var t: float = float(r["life"]) / float(r["max_life"])
		var radius: float = float(r["radius"]) * (1.0 - t * 0.85)
		draw_arc(r["pos"] as Vector2, radius, 0.0, TAU, 40, Color(r["color"] as Color, t), float(r["width"]) * (0.5 + t))
	for text in _texts:
		var t: float = minf(float(text["life"]) / 0.4, 1.0)
		var size: int = int(text["size"])
		var label: String = text["text"] as String
		var width: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(_font, (text["pos"] as Vector2) - Vector2(width * 0.5, 0.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(text["color"] as Color, t))

func _draw_void() -> void:
	var height: float = get_viewport_rect().size.y
	var strength: float = 0.12 + 0.88 * _void_intensity
	var origin: Vector2 = -position - (_world.position if is_instance_valid(_world) else Vector2.ZERO)
	for band in VOID_BANDS:
		var fade: float = 1.0 - float(band) / float(VOID_BANDS)
		var rect := Rect2(origin + Vector2(band * VOID_BAND_WIDTH, 0.0), Vector2(VOID_BAND_WIDTH, height))
		draw_rect(rect, Color(VOID_COLOR, 0.32 * strength * fade * fade))
	var line := PackedVector2Array()
	var steps: int = int(height / 18.0) + 2
	for i in steps:
		var y: float = i * 18.0
		var jitter: float = sin(y * 0.11 + _time * 9.0) * cos(y * 0.07 - _time * 5.0)
		line.append(origin + Vector2(3.0 + jitter * (2.0 + 9.0 * _void_intensity), y))
	draw_polyline(line, Color(VOID_COLOR, 0.35 + 0.65 * strength), 1.5 + 2.5 * _void_intensity)

class_name Effects
extends Node2D

# Effects: particles, rings, screen flashes and floating texts.
# Drawn with additive blending: overlapping light adds up, which gives the
# neon look; texts live in a child node with normal blending so they stay
# readable. Particles are packed arrays drawn with one shared glow texture
# (the renderer batches them); a dead particle is replaced by the last one.

class Texts extends Node2D:
	var items: Array[Dictionary] = []
	var font: Font = null
	func _ready() -> void:
		font = ThemeDB.fallback_font
	func _process(delta: float) -> void:
		for i in range(items.size() - 1, -1, -1):
			var it: Dictionary = items[i]
			it["life"] = float(it["life"]) - delta
			it["pos"] = (it["pos"] as Vector2) + Vector2(0.0, -32.0 * delta)
			if float(it["life"]) <= 0.0:
				items.remove_at(i)
		queue_redraw()
	func _draw() -> void:
		for it in items:
			var t: float = float(it["life"]) / float(it["max"])
			var alpha: float = minf(t * 3.0, 1.0)
			var size: int = int(int(it["size"]) * (1.0 + 0.4 * maxf((t - 0.8) / 0.2, 0.0)))
			var text: String = it["text"]
			var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var p: Vector2 = (it["pos"] as Vector2) - Vector2(w * 0.5, 0.0)
			draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.0, 0.0, 0.05, 0.85 * alpha))
			draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(it["color"] as Color, alpha))

static var _glow: Texture2D = null

var screen_size: Vector2 = Vector2(1280.0, 720.0)
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _color := PackedColorArray()
var _rings: Array[Dictionary] = []
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE
var _texts: Texts = null

static func glow_texture() -> Texture2D:
	if _glow == null:
		var n: int = 64
		var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d: float = Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(clampf(1.0 - d, 0.0, 1.0), 2.0)))
		_glow = ImageTexture.create_from_image(image)
	return _glow

static func put(canvas: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
	canvas.draw_texture_rect(glow_texture(), Rect2(at.x - radius, at.y - radius, radius * 2.0, radius * 2.0), false, color)

static func additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat

func _ready() -> void:
	material = additive_material()
	_texts = Texts.new()
	_texts.z_index = 5
	add_child(_texts)

func burst(at: Vector2, color: Color, count: int, speed: float, size: float, life: float) -> void:
	for i in count:
		var v: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * speed * randf_range(0.25, 1.0)
		_spawn(at, v, life * randf_range(0.6, 1.0), size * randf_range(0.6, 1.3), color)

func directed(at: Vector2, color: Color, count: int, direction: Vector2, spread: float, speed: float) -> void:
	for i in count:
		var v: Vector2 = direction.rotated(randf_range(-spread, spread)) * speed * randf_range(0.4, 1.0)
		_spawn(at, v, randf_range(0.15, 0.3), randf_range(2.0, 3.5), color)

func explosion(at: Vector2, radius: float, color: Color) -> void:
	burst(at, color, int(10 + radius * 0.9), 120.0 + radius * 8.0, 3.0 + radius * 0.1, 0.6)
	burst(at, Color(1.0, 0.95, 0.85), int(5 + radius * 0.3), 90.0 + radius * 4.0, 2.5, 0.35)
	ring(at, color, radius * 2.4, 0.4, 3.0)
	_rings.append({pos = at, radius = radius * 1.6, life = 0.15, max_life = 0.15, color = color.lightened(0.4), width = 0.0, glow = true})

func ring(at: Vector2, color: Color, radius: float, life: float, width: float) -> void:
	_rings.append({pos = at, radius = radius, life = life, max_life = life, color = color, width = width, glow = false})

func flash(color: Color, strength: float) -> void:
	_flash_color = color
	_flash = maxf(_flash, strength)

func text(at: Vector2, label: String, color: Color, size: int = 16, life: float = 0.9) -> void:
	if _texts.items.size() > 30:
		_texts.items.remove_at(0)
	_texts.items.append({pos = at, text = label, color = color, size = size, life = life, max = life})

func clear() -> void:
	_pos.resize(0)
	_vel.resize(0)
	_life.resize(0)
	_max_life.resize(0)
	_size.resize(0)
	_color.resize(0)
	_rings.clear()
	_texts.items.clear()
	_flash = 0.0

func _spawn(at: Vector2, v: Vector2, life: float, size: float, color: Color) -> void:
	_pos.append(at)
	_vel.append(v)
	_life.append(life)
	_max_life.append(life)
	_size.append(size)
	_color.append(color)

func step(delta: float) -> void:
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
		_vel[i] = _vel[i] * (1.0 - minf(3.2 * delta, 1.0))
		_pos[i] = _pos[i] + _vel[i] * delta
		i += 1
	for k in range(_rings.size() - 1, -1, -1):
		var r: Dictionary = _rings[k]
		r["life"] = float(r["life"]) - delta
		if float(r["life"]) <= 0.0:
			_rings.remove_at(k)
	_flash = maxf(_flash - delta * 3.0, 0.0)
	queue_redraw()

func _draw() -> void:
	for i in _pos.size():
		var t: float = _life[i] / _max_life[i]
		put(self, _pos[i], _size[i] * (1.0 + t), Color(_color[i], t))
	for r in _rings:
		var t: float = float(r["life"]) / float(r["max_life"])
		var c: Color = r["color"]
		if bool(r["glow"]):
			put(self, r["pos"] as Vector2, float(r["radius"]) * (1.2 - t * 0.2), Color(c, t))
			continue
		var radius: float = float(r["radius"]) * (1.0 - t * t * 0.85)
		draw_arc(r["pos"] as Vector2, radius, 0.0, TAU, 56, Color(c, c.a * t), float(r["width"]) * (0.5 + t))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2(-60.0, -60.0), screen_size + Vector2(120.0, 120.0)), Color(_flash_color, _flash * 0.5))

class_name Effects
extends Node2D

# Effects: particles, debris, rings, edge warnings, screen flashes and
# floating texts.
# Drawn with additive blending: overlapping light adds up, which gives the
# neon look; texts live in a child node with normal blending so they stay
# readable. Particles are packed arrays drawn with one shared glow texture
# (the renderer batches them); a dead particle is replaced by the last one.
#   PARTICLES  glowing dots that slow down and fade
#   DEBRIS     line segments that fly apart and spin: a destroyed enemy
#              breaks into the pieces of its outline
#   RINGS      expanding (or, implode = true, collapsing) circles
#   WARNINGS   a chevron on the arena edge, pointing inward, where an enemy
#              is about to enter (spawner.gd announces it 0.9 s ahead)
#   TEXTS      pop in at 1.5 x their size, settle, drift up and fade

class Texts extends Node2D:
	var items: Array[Dictionary] = []
	func _process(delta: float) -> void:
		for i in range(items.size() - 1, -1, -1):
			var it: Dictionary = items[i]
			it["life"] = float(it["life"]) - delta
			it["pos"] = (it["pos"] as Vector2) + Vector2(0.0, -28.0 * delta)
			if float(it["life"]) <= 0.0:
				items.remove_at(i)
		queue_redraw()
	func _draw() -> void:
		var font: Font = UiKit.bold()
		for it in items:
			var t: float = float(it["life"]) / float(it["max"])
			var age: float = float(it["max"]) - float(it["life"])
			var alpha: float = minf(t * 3.0, 1.0)
			var pop: float = 1.0 + 0.5 * maxf(1.0 - age / 0.12, 0.0)
			var size: int = int(int(it["size"]) * pop)
			UiKit.text(self, it["pos"] as Vector2, str(it["text"]), size, Color(it["color"] as Color, alpha), 0.5, font, 4)

static var _glow: Texture2D = null

var screen_size: Vector2 = Vector2(1280.0, 720.0)
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _color := PackedColorArray()
var _d_pos := PackedVector2Array()
var _d_vel := PackedVector2Array()
var _d_ang := PackedFloat32Array()
var _d_spin := PackedFloat32Array()
var _d_len := PackedFloat32Array()
var _d_life := PackedFloat32Array()
var _d_max := PackedFloat32Array()
var _d_color := PackedColorArray()
var _rings: Array[Dictionary] = []
var _warnings: Array[Dictionary] = []
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE
var _time: float = 0.0
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

## Particles streaming from a ring of radius `from` toward `at` (the Nova).
func inflow(at: Vector2, color: Color, count: int, from: float) -> void:
	for i in count:
		var a: float = randf() * TAU
		var start: Vector2 = at + Vector2.RIGHT.rotated(a) * from * randf_range(0.6, 1.0)
		var v: Vector2 = (at - start) * randf_range(1.6, 2.4)
		_spawn(start, v, randf_range(0.3, 0.5), randf_range(2.0, 3.5), color)

func explosion(at: Vector2, radius: float, color: Color) -> void:
	burst(at, color, int(10 + radius * 0.9), 120.0 + radius * 8.0, 3.0 + radius * 0.1, 0.6)
	burst(at, Color(1.0, 0.95, 0.85), int(5 + radius * 0.3), 90.0 + radius * 4.0, 2.5, 0.35)
	ring(at, color, radius * 2.4, 0.4, 3.0)
	_rings.append({pos = at, radius = radius * 1.6, life = 0.15, max_life = 0.15, color = color.lightened(0.4), width = 0.0, glow = true, implode = false})

## Breaks an outline of `sides` edges into spinning line segments.
func shatter(at: Vector2, radius: float, color: Color, sides: int) -> void:
	var pieces: int = clampi(sides * 2, 6, 18)
	var piece_len: float = TAU * radius / pieces * 1.1
	for k in pieces:
		var a: float = TAU * k / pieces + randf_range(-0.15, 0.15)
		_d_pos.append(at + Vector2.RIGHT.rotated(a) * radius * 0.85)
		_d_vel.append(Vector2.RIGHT.rotated(a + randf_range(-0.5, 0.5)) * randf_range(70.0, 200.0) * (1.0 + radius / 50.0))
		_d_ang.append(a + PI * 0.5)
		_d_spin.append(randf_range(-11.0, 11.0))
		_d_len.append(piece_len * randf_range(0.6, 1.1))
		var life: float = randf_range(0.45, 0.85)
		_d_life.append(life)
		_d_max.append(life)
		_d_color.append(color.lightened(0.25))

func ring(at: Vector2, color: Color, radius: float, life: float, width: float, implode: bool = false) -> void:
	_rings.append({pos = at, radius = radius, life = life, max_life = life, color = color, width = width, glow = false, implode = implode})

## Chevron on the edge where an enemy is about to enter.
func warning(at: Vector2, color: Color, life: float) -> void:
	var inner: Rect2 = Rect2(Vector2.ZERO, screen_size).grow(-20.0)
	var p: Vector2 = at.clamp(inner.position, inner.end)
	var dir: Vector2 = (screen_size * 0.5 - p).normalized()
	if at.x < inner.position.x:
		dir = Vector2.RIGHT
	elif at.x > inner.end.x:
		dir = Vector2.LEFT
	elif at.y < inner.position.y:
		dir = Vector2.DOWN
	elif at.y > inner.end.y:
		dir = Vector2.UP
	_warnings.append({pos = p, dir = dir, life = life, max_life = life, color = color})

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
	_d_pos.resize(0)
	_d_vel.resize(0)
	_d_ang.resize(0)
	_d_spin.resize(0)
	_d_len.resize(0)
	_d_life.resize(0)
	_d_max.resize(0)
	_d_color.resize(0)
	_rings.clear()
	_warnings.clear()
	_texts.items.clear()
	_flash = 0.0

func _spawn(at: Vector2, v: Vector2, life: float, size: float, color: Color) -> void:
	if _pos.size() > 1400:
		return
	_pos.append(at)
	_vel.append(v)
	_life.append(life)
	_max_life.append(life)
	_size.append(size)
	_color.append(color)

func step(delta: float) -> void:
	_time += delta
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
	var j: int = 0
	while j < _d_pos.size():
		_d_life[j] = _d_life[j] - delta
		if _d_life[j] <= 0.0:
			var last2: int = _d_pos.size() - 1
			_d_pos[j] = _d_pos[last2]
			_d_vel[j] = _d_vel[last2]
			_d_ang[j] = _d_ang[last2]
			_d_spin[j] = _d_spin[last2]
			_d_len[j] = _d_len[last2]
			_d_life[j] = _d_life[last2]
			_d_max[j] = _d_max[last2]
			_d_color[j] = _d_color[last2]
			_d_pos.resize(last2)
			_d_vel.resize(last2)
			_d_ang.resize(last2)
			_d_spin.resize(last2)
			_d_len.resize(last2)
			_d_life.resize(last2)
			_d_max.resize(last2)
			_d_color.resize(last2)
			continue
		_d_vel[j] = _d_vel[j] * (1.0 - minf(2.2 * delta, 1.0))
		_d_pos[j] = _d_pos[j] + _d_vel[j] * delta
		_d_ang[j] = _d_ang[j] + _d_spin[j] * delta
		j += 1
	for k in range(_rings.size() - 1, -1, -1):
		var r: Dictionary = _rings[k]
		r["life"] = float(r["life"]) - delta
		if float(r["life"]) <= 0.0:
			_rings.remove_at(k)
	for w in range(_warnings.size() - 1, -1, -1):
		var wd: Dictionary = _warnings[w]
		wd["life"] = float(wd["life"]) - delta
		if float(wd["life"]) <= 0.0:
			_warnings.remove_at(w)
	_flash = maxf(_flash - delta * 3.0, 0.0)
	queue_redraw()

func _draw() -> void:
	for i in _pos.size():
		var t: float = _life[i] / _max_life[i]
		put(self, _pos[i], _size[i] * (1.0 + t), Color(_color[i], t))
	for j in _d_pos.size():
		var t2: float = _d_life[j] / _d_max[j]
		var half: Vector2 = Vector2.RIGHT.rotated(_d_ang[j]) * _d_len[j] * 0.5
		draw_line(_d_pos[j] - half, _d_pos[j] + half, Color(_d_color[j], t2), 2.0)
	for r in _rings:
		var t3: float = float(r["life"]) / float(r["max_life"])
		var c: Color = r["color"]
		if bool(r["glow"]):
			put(self, r["pos"] as Vector2, float(r["radius"]) * (1.2 - t3 * 0.2), Color(c, t3))
			continue
		var radius: float = float(r["radius"]) * (t3 if bool(r["implode"]) else (1.0 - t3 * t3 * 0.85))
		var alpha: float = (1.0 - t3) if bool(r["implode"]) else t3
		draw_arc(r["pos"] as Vector2, radius, 0.0, TAU, 56, Color(c, c.a * alpha), float(r["width"]) * (0.5 + t3))
	for w in _warnings:
		var t4: float = float(w["life"]) / float(w["max_life"])
		var pulse: float = 0.45 + 0.55 * absf(sin(_time * 9.0))
		var dir: Vector2 = w["dir"] as Vector2
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var p: Vector2 = (w["pos"] as Vector2) + dir * (1.0 - t4) * 10.0
		var col: Color = Color(w["color"] as Color, pulse * minf((1.0 - t4) * 4.0, 1.0))
		for k in 2:
			var tip: Vector2 = p + dir * (8.0 + k * 9.0)
			draw_polyline(PackedVector2Array([tip - dir * 8.0 + side * 9.0, tip, tip - dir * 8.0 - side * 9.0]), col, 3.0)
		put(self, p, 22.0, Color(w["color"] as Color, 0.25 * pulse))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2(-60.0, -60.0), screen_size + Vector2(120.0, 120.0)), Color(_flash_color, _flash * 0.5))

# =============================================================================
# Effects2D.gd — Flying squares and floating numbers
# =============================================================================
# Particles are little Mondrian squares (a colour with a black outline)
# thrown outwards, turning, falling with gravity. Popups are bold numbers
# rising and fading. Both live in packed lists drawn in one _draw().
# =============================================================================

class_name Effects2D
extends Node2D

var _squares: Array[Dictionary] = []   # pos, vel, size, color, life, max, spin, angle
var _texts: Array[Dictionary] = []     # pos, text, color, size, life, max
var _font: Font = null

func _ready() -> void:
	_font = ThemeDB.fallback_font

func burst(pos: Vector2, color: Color, count: int, speed: float, size: float = 12.0, life: float = 0.8, up: float = 0.0) -> void:
	for i in count:
		var a: float = randf() * TAU
		var v: Vector2 = Vector2(cos(a), sin(a)) * randf_range(speed * 0.35, speed) + Vector2(0.0, -up)
		_squares.append({pos = pos, vel = v, size = size * randf_range(0.6, 1.3), color = color, life = life * randf_range(0.7, 1.2), max = life, spin = randf_range(-9.0, 9.0), angle = randf() * TAU})

func popup(pos: Vector2, text: String, color: Color, size: int = 26, life: float = 0.9) -> void:
	_texts.append({pos = pos, text = text, color = color, size = size, life = life, max = life})

func clear() -> void:
	_squares.clear()
	_texts.clear()

func _process(delta: float) -> void:
	for i in range(_squares.size() - 1, -1, -1):
		var s: Dictionary = _squares[i]
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) <= 0.0:
			_squares.remove_at(i)
			continue
		s["vel"] = (s["vel"] as Vector2) * (1.0 - 1.8 * delta) + Vector2(0.0, 900.0 * delta)
		s["pos"] = (s["pos"] as Vector2) + (s["vel"] as Vector2) * delta
		s["angle"] = float(s["angle"]) + float(s["spin"]) * delta
	for i in range(_texts.size() - 1, -1, -1):
		var t: Dictionary = _texts[i]
		t["life"] = float(t["life"]) - delta
		if float(t["life"]) <= 0.0:
			_texts.remove_at(i)
			continue
		t["pos"] = (t["pos"] as Vector2) + Vector2(0.0, -46.0 * delta)
	queue_redraw()

func _draw() -> void:
	for s in _squares:
		var k: float = clampf(float(s["life"]) / float(s["max"]), 0.0, 1.0)
		var size: float = float(s["size"]) * (0.4 + 0.6 * k)
		draw_set_transform(s["pos"], float(s["angle"]), Vector2.ONE)
		var r := Rect2(Vector2(-size, -size) * 0.5, Vector2(size, size))
		draw_rect(r.grow(2.0), Color(0.08, 0.08, 0.08, k))
		var c: Color = s["color"]
		draw_rect(r, Color(c.r, c.g, c.b, k))
	draw_set_transform(Vector2.ZERO)
	for t in _texts:
		var k: float = clampf(float(t["life"]) / float(t["max"]), 0.0, 1.0)
		var text: String = t["text"]
		var size: int = int(t["size"])
		var scale: float = 1.0 + 0.35 * clampf((float(t["life"]) - float(t["max"]) + 0.12) / 0.12, 0.0, 1.0)
		var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_set_transform(t["pos"], 0.0, Vector2.ONE * scale)
		var p := Vector2(-w * 0.5, 0.0)
		draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7, Color(0.08, 0.08, 0.08, k))
		var c: Color = t["color"]
		draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(c.r, c.g, c.b, k))
	draw_set_transform(Vector2.ZERO)

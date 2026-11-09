# =============================================================================
# FxLayer.gd — Floating numbers, sparkle bursts and screen flashes
# =============================================================================
# Drawn above the interface, never catching the mouse. Floating texts rise
# and fade (a slight random drift keeps fast strikes readable); bursts are
# sparkles thrown outward that slow down; flash() briefly lights the whole
# screen (overheat, crystallization).
# =============================================================================

extends Control

const MAX_TEXTS: int = 40

var _texts: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _flash_color: Color = Color.TRANSPARENT
var _flash: float = 0.0
var _font: Font = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

func float_text(at: Vector2, text: String, color: Color, font_size: int) -> void:
	if _texts.size() >= MAX_TEXTS:
		_texts.remove_at(0)
	_texts.append({pos = at - get_global_rect().position, text = text, color = color, size = font_size,
		life = 1.0, drift = randf_range(-30.0, 30.0)})

func burst(at: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		var direction: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
		_sparks.append({pos = at - get_global_rect().position, vel = direction * speed * randf_range(0.3, 1.0),
			life = randf_range(0.4, 0.8), color = color.lightened(randf() * 0.3), size = randf_range(1.5, 3.5)})

func flash(color: Color, strength: float) -> void:
	_flash_color = color
	_flash = strength

func _process(delta: float) -> void:
	for i in range(_texts.size() - 1, -1, -1):
		var t: Dictionary = _texts[i]
		t["life"] = float(t["life"]) - delta
		t["pos"] = (t["pos"] as Vector2) + Vector2(float(t["drift"]) * delta, -70.0 * delta)
		if float(t["life"]) <= 0.0:
			_texts.remove_at(i)
	for i in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		s["life"] = float(s["life"]) - delta
		s["vel"] = (s["vel"] as Vector2) * (1.0 - minf(4.0 * delta, 1.0))
		s["pos"] = (s["pos"] as Vector2) + (s["vel"] as Vector2) * delta
		if float(s["life"]) <= 0.0:
			_sparks.remove_at(i)
	_flash = maxf(_flash - delta * 1.5, 0.0)
	queue_redraw()

func _draw() -> void:
	for s in _sparks:
		var alpha: float = clampf(float(s["life"]) * 2.0, 0.0, 1.0)
		draw_circle(s["pos"] as Vector2, float(s["size"]), Color(s["color"] as Color, alpha))
	for t in _texts:
		var life: float = float(t["life"])
		var alpha: float = clampf(life * 2.5, 0.0, 1.0)
		var text: String = t["text"] as String
		var font_size: int = int(float(t["size"]) * (1.0 + 0.25 * clampf((life - 0.85) * 6.0, 0.0, 1.0)))
		var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var pos: Vector2 = (t["pos"] as Vector2) - Vector2(width * 0.5, 0.0)
		draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0.0, 0.0, 0.0, 0.6 * alpha))
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(t["color"] as Color, alpha))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(_flash_color, _flash * 0.35))

# =============================================================================
# Popups.gd — Floating score texts (normal blending, readable on any colour)
# =============================================================================

class_name Popups
extends Node2D

const MAX_TEXTS: int = 24

var _texts: Array[Dictionary] = []
var _font: Font = null

func _ready() -> void:
	_font = ThemeDB.fallback_font

func add(at: Vector2, text: String, color: Color, size: int = 14, life: float = 0.8) -> void:
	if _texts.size() >= MAX_TEXTS:
		_texts.remove_at(0)
	_texts.append({pos = at, text = text, color = color, size = size, life = life, max_life = life})

func clear() -> void:
	_texts.clear()

func _process(delta: float) -> void:
	for i in range(_texts.size() - 1, -1, -1):
		var t: Dictionary = _texts[i]
		t["life"] = float(t["life"]) - delta
		t["pos"] = (t["pos"] as Vector2) + Vector2(0.0, -30.0 * delta)
		if float(t["life"]) <= 0.0:
			_texts.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for t in _texts:
		var k: float = float(t["life"]) / float(t["max_life"])
		var alpha: float = minf(k * 3.0, 1.0)
		var pop: float = 1.0 + 0.4 * maxf((k - 0.8) / 0.2, 0.0)
		var size: int = int(int(t["size"]) * pop)
		var text: String = t["text"] as String
		var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var p: Vector2 = (t["pos"] as Vector2) - Vector2(width * 0.5, 0.0)
		draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.0, 0.0, 0.05, 0.85 * alpha))
		draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(t["color"] as Color, alpha))

# =============================================================================
# WorldLabels.gd — Short texts above the fighters: COUNTER, ARMOR, TECH...
# =============================================================================

class_name WorldLabels
extends Node2D

var _items: Array[Dictionary] = []
var _font: Font = null

func _ready() -> void:
	z_index = 30
	_font = ThemeDB.fallback_font

func add(at: Vector2, text: String, color: Color, size: int = 22) -> void:
	_items.append({pos = at, text = text, color = color, size = size, life = 1.0})

func _process(delta: float) -> void:
	for i in range(_items.size() - 1, -1, -1):
		var it: Dictionary = _items[i]
		it["life"] = float(it["life"]) - delta
		it["pos"] = (it["pos"] as Vector2) + Vector2(0.0, -26.0 * delta)
		if float(it["life"]) <= 0.0:
			_items.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for it in _items:
		var t: float = float(it["life"])
		var alpha: float = minf(t * 3.0, 1.0)
		var pop: float = 1.0 + 0.5 * maxf((t - 0.85) / 0.15, 0.0)
		var size: int = int(int(it["size"]) * pop)
		var text: String = it["text"]
		var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var p: Vector2 = (it["pos"] as Vector2) - Vector2(w * 0.5, 0.0)
		draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.05, 0.03, 0.02, alpha))
		draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(it["color"] as Color, alpha))

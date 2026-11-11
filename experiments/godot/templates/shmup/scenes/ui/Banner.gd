# =============================================================================
# Banner.gd — Big announcements over the field
# =============================================================================
# Styles: info (launch), warning (red, blinking, scrolling hazard stripes),
# boss (boss name), clear (sector cleared), extend (extra life). The text
# zooms in from 140 % and fades out at the end.
# =============================================================================

class_name Banner
extends Control

const STYLES: Dictionary = {
	"info": {color = Color(0.44, 0.95, 1.0), time = 2.2, size = 42},
	"warning": {color = Color(1.0, 0.3, 0.38), time = 3.4, size = 56},
	"boss": {color = Color(1.0, 0.55, 0.78), time = 2.2, size = 40},
	"clear": {color = Color(1.0, 0.82, 0.3), time = 3.6, size = 46},
	"extend": {color = Color(1.0, 0.5, 0.85), time = 1.8, size = 32},
}

var _text: String = ""
var _sub: String = ""
var _style: String = "info"
var _life: float = 0.0
var _max_life: float = 1.0
var _font: Font = null
var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

func show_banner(text: String, sub: String, style: String) -> void:
	_text = text
	_sub = sub
	_style = style if STYLES.has(style) else "info"
	_max_life = float((STYLES[_style] as Dictionary)["time"])
	_life = _max_life

func clear() -> void:
	_life = 0.0

func _process(delta: float) -> void:
	_time += delta
	_life = maxf(_life - delta, 0.0)
	queue_redraw()

func _draw() -> void:
	if _life <= 0.0:
		return
	var st: Dictionary = STYLES[_style] as Dictionary
	var color: Color = st["color"]
	var t: float = 1.0 - _life / _max_life
	var alpha: float = minf(t / 0.12, 1.0) * minf(_life / 0.4, 1.0)
	var zoom: float = 1.0 + 0.4 * maxf(1.0 - t / 0.15, 0.0)
	var cy: float = size.y * 0.42
	if _style == "warning":
		var blink: float = 0.55 + 0.45 * absf(sin(_time * 6.0))
		alpha *= blink
		for band in [-60.0, 50.0]:
			draw_rect(Rect2(0.0, cy + band, size.x, 14.0), Color(color, 0.25 * alpha))
			var x: float = -40.0 + fmod(_time * 120.0, 40.0)
			while x < size.x:
				draw_colored_polygon(PackedVector2Array([Vector2(x, cy + band + 14.0), Vector2(x + 14.0, cy + band), Vector2(x + 26.0, cy + band), Vector2(x + 12.0, cy + band + 14.0)]), Color(color, 0.7 * alpha))
				x += 40.0
	else:
		draw_rect(Rect2(0.0, cy - 46.0, size.x, 80.0), Color(0.0, 0.0, 0.05, 0.35 * alpha))
	var font_size: int = int(float(st["size"]) * zoom)
	var w: float = _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var p := Vector2((size.x - w) * 0.5, cy + font_size * 0.3)
	draw_string_outline(_font, p, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Color(0.0, 0.0, 0.05, 0.9 * alpha))
	draw_string(_font, p, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, alpha))
	if not _sub.is_empty():
		var sw: float = _font.get_string_size(_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var sp := Vector2((size.x - sw) * 0.5, cy + font_size * 0.3 + 32.0)
		draw_string_outline(_font, sp, _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0.0, 0.0, 0.05, 0.9 * alpha))
		draw_string(_font, sp, _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.93, 1.0, alpha))

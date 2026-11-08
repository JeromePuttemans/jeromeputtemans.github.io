# =============================================================================
# FloatingLabel.gd — Node2D: score number that floats upward and fades.
# Spawned by Main when an enemy is killed.
# =============================================================================
class_name FloatingLabel
extends Node2D

var _text:     String = ""
var _color:    Color  = Color.YELLOW
var _speed:    float  = 0.0
var _duration: float  = 0.0
var _t:        float  = 0.0

func setup(text: String, color: Color) -> void:
	_text     = text
	_color    = color
	_speed    = ConfigManager.get_float("float_label_speed",    0.0)
	_duration = ConfigManager.get_float("float_label_duration", 0.0)
	_t        = 0.0

func _process(delta: float) -> void:
	_t        += delta / _duration
	position.y -= _speed * delta
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var alpha = (1.0 - _t) * (1.0 - _t)   # ease-out fade
	var scale = 1.0 + (1.0 - _t) * 0.3    # slight pop scale
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale, scale))
	draw_string(ThemeDB.fallback_font, Vector2(-20, 0), _text,
		HORIZONTAL_ALIGNMENT_CENTER, 40,
		14, Color(_color.r, _color.g, _color.b, alpha))

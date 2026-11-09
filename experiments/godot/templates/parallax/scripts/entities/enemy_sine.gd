extends EnemyBase

# Weaver (pink triangle): crosses the screen on a sine wave (amplitude and
# frequency in settings.json). Harder to line up: firing at it from far away
# wastes bullets, so it rewards waiting until it is close.

var _base_y: float = 0.0
var _wave_phase: float = 0.0

func _on_setup() -> void:
	_base_y = position.y
	_wave_phase = randf() * TAU

func _move(delta: float) -> void:
	position.x -= speed * delta
	var amplitude: float = float(config.get("amplitude", 90.0))
	var frequency: float = float(config.get("frequency", 0.7))
	position.y = _base_y + sin(_age * TAU * frequency + _wave_phase) * amplitude

func _shape() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-radius, 0.0), Vector2(radius * 0.8, -radius * 0.85),
		Vector2(radius * 0.35, 0.0), Vector2(radius * 0.8, radius * 0.85)])

func _body_color() -> Color:
	return Color(1.0, 0.36, 0.55)

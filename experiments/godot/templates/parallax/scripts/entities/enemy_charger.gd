extends EnemyBase

# Lancer (orange arrowhead): enters, stops near the right edge, aims at the
# ship for aim_time while a blinking line shows its path, then dashes along
# that line at dash_speed. The aim locks LOCK_BEFORE seconds before the dash:
# moving away at the last moment dodges it.

enum Phase { ENTER, AIM, DASH }

const LOCK_BEFORE: float = 0.25
const TELEGRAPH_LENGTH: float = 1400.0

var _phase: Phase = Phase.ENTER
var _stop_x: float = 1000.0
var _aim_left: float = 0.9
var _dash_direction: Vector2 = Vector2.LEFT

func _on_setup() -> void:
	_stop_x = _screen.x * float(config.get("stop_x_ratio", 0.82)) + randf_range(-40.0, 40.0)

func _move(delta: float) -> void:
	match _phase:
		Phase.ENTER:
			position.x -= speed * delta
			if position.x <= _stop_x:
				_phase = Phase.AIM
				_aim_left = float(config.get("aim_time", 0.9))
				_play("charge")
		Phase.AIM:
			_aim_left -= delta
			if _aim_left > LOCK_BEFORE:
				_dash_direction = _aim_direction()
			if _aim_left <= 0.0:
				_phase = Phase.DASH
		Phase.DASH:
			position += _dash_direction * float(config.get("dash_speed", 640.0)) * delta

func _shape() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(radius * 1.1, 0.0), Vector2(-radius * 0.8, -radius * 0.8),
		Vector2(-radius * 0.35, 0.0), Vector2(-radius * 0.8, radius * 0.8)])
	var angle: float = _dash_direction.angle()
	for i in pts.size():
		pts[i] = pts[i].rotated(angle)
	return pts

func _body_color() -> Color:
	return Color(1.0, 0.55, 0.2)

func _draw_details(color: Color) -> void:
	if _phase != Phase.AIM:
		return
	var blink: float = 0.5 + 0.5 * sin(_age * (18.0 if _aim_left < LOCK_BEFORE else 9.0))
	var end: Vector2 = _dash_direction * TELEGRAPH_LENGTH
	draw_line(_dash_direction * radius, end, Color(color, 0.12 + 0.3 * blink), 2.0)

extends EnemyBase

# Sentinel (magenta square): enters, hovers near the right edge and fires an
# aimed orb every fire_interval seconds for stay_time seconds, then leaves
# through the left side. Its core brightens just before each shot.
# Sitting on the right edge, it is cheap to shoot at: bullets fired near it
# do not stay long in flight.

enum Phase { ENTER, HOVER, LEAVE }

const FIRST_SHOT_DELAY: float = 0.8
const CHARGE_TIME: float = 0.4
const LEAVE_SPEED_FACTOR: float = 0.6

var _phase: Phase = Phase.ENTER
var _stop_x: float = 1080.0
var _base_y: float = 0.0
var _fire_left: float = 0.0
var _stay_left: float = 0.0

func _on_setup() -> void:
	_stop_x = _screen.x * float(config.get("stop_x_ratio", 0.84)) + randf_range(-50.0, 30.0)

func _move(delta: float) -> void:
	match _phase:
		Phase.ENTER:
			position.x -= speed * delta
			if position.x <= _stop_x:
				_phase = Phase.HOVER
				_base_y = position.y
				_fire_left = FIRST_SHOT_DELAY
				_stay_left = float(config.get("stay_time", 9.0))
		Phase.HOVER:
			_hover(delta)
		Phase.LEAVE:
			position.x -= speed * LEAVE_SPEED_FACTOR * delta

func _hover(delta: float) -> void:
	position.y = _base_y + sin(_age * 1.6) * 30.0
	_fire_left -= delta
	if _fire_left <= 0.0:
		_fire_at_target(0.0)
		_play("enemy_shot")
		_fire_left = float(config.get("fire_interval", 1.5))
	_stay_left -= delta
	if _stay_left <= 0.0:
		_phase = Phase.LEAVE

func _shape() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 4:
		pts.append(Vector2.RIGHT.rotated(_age * 1.5 + i * PI * 0.5) * radius)
	return pts

func _body_color() -> Color:
	return Color(0.95, 0.3, 0.85)

func _draw_details(color: Color) -> void:
	var charge: float = 0.0
	if _phase == Phase.HOVER:
		charge = clampf(1.0 - _fire_left / CHARGE_TIME, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius * (0.3 + 0.2 * charge), Color(color.lightened(0.6), 0.6 + 0.4 * charge))

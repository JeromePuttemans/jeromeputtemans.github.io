extends EnemyBase

# Bastion (large crimson hexagon): slow and tough (14 hp), fires a spread of
# three orbs toward the ship every fire_interval seconds once on screen.
# Destroying it may drop a repair pickup (repair_drop_chance). A ring shows
# its remaining hp. Killing it takes a long burst: the ship slows down while
# the bullets fly, which is the dilemma of the game in a single enemy.

var _fire_left: float = 1.5

func _move(delta: float) -> void:
	position.x -= speed * delta
	if position.x > _screen.x - radius:
		return
	_fire_left -= delta
	if _fire_left <= 0.0:
		var spread: float = deg_to_rad(float(config.get("spread_degrees", 18.0)))
		for i in 3:
			_fire_at_target(spread * (i - 1))
		_play("enemy_shot")
		_fire_left = float(config.get("fire_interval", 2.6))

func _shape() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(Vector2.RIGHT.rotated(i * TAU / 6.0 + PI / 6.0) * radius)
	return pts

func _body_color() -> Color:
	return Color(0.9, 0.15, 0.3)

func _draw_details(color: Color) -> void:
	var inner := PackedVector2Array()
	for i in 7:
		inner.append(Vector2.RIGHT.rotated(i * TAU / 6.0 + _age * 0.8) * radius * 0.5)
	draw_polyline(inner, Color(color.lightened(0.4), 0.8), 2.0)
	draw_circle(Vector2.ZERO, radius * 0.18, color.lightened(0.6))

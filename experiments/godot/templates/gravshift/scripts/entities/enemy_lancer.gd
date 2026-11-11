extends EnemyBase

# Lancer: approaches, aims for 0.6 s (a line shows the charge), then dashes
# in a straight line. The well bends the dash: a lancer can be steered into
# its friends.

enum Phase { APPROACH, AIM, DASH, RECOVER }

var _phase: Phase = Phase.APPROACH
var _phase_t: float = 0.0
var _dir: Vector2 = Vector2.DOWN

func _behave(delta: float) -> void:
	_phase_t += delta
	match _phase:
		Phase.APPROACH:
			var to_ship: Vector2 = ship() - position
			steer(to_ship.normalized() * 140.0, 300.0, delta)
			if entered and to_ship.length() < 380.0:
				_switch(Phase.AIM)
		Phase.AIM:
			steer(Vector2.ZERO, 600.0, delta)
			_dir = (ship() - position).normalized()
			if _phase_t > 0.6:
				vel = _dir * speed
				_switch(Phase.DASH)
		Phase.DASH:
			if _phase_t > 0.75:
				_switch(Phase.RECOVER)
		Phase.RECOVER:
			steer(Vector2.ZERO, 500.0, delta)
			if _phase_t > 0.7:
				_switch(Phase.APPROACH)

func _switch(p: Phase) -> void:
	_phase = p
	_phase_t = 0.0

func _shape(c: Color) -> void:
	var a: float = (vel.angle() if vel.length() > 20.0 else _dir.angle())
	var pts: Array = [Vector2.RIGHT.rotated(a) * radius * 1.4, Vector2.RIGHT.rotated(a + 2.6) * radius, Vector2.RIGHT.rotated(a - 2.6) * radius]
	polygon(pts, c, 2.5)
	if _phase == Phase.AIM:
		var blink: float = 0.4 + 0.6 * absf(sin(_phase_t * 20.0))
		draw_line(Vector2.ZERO, _dir * 420.0, Color(c, 0.35 * blink), 2.0)

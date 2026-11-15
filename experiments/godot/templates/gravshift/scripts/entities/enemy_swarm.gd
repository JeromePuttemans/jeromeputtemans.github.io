extends EnemyBase

# Swarm: small fragile darts (1 hit point, mass 0.5) that arrive in flocks.
# Each one circles the ship at about 190 px for 2 to 3.5 s, then dives
# straight at it for 0.9 s, then circles again. Circling, they are an easy
# catch for the open well: the whole flock is dragged into the orbit or
# into each other.

const CIRCLE_RADIUS: float = 190.0

var _phase_t: float = 0.0
var _diving: bool = false
var _turn: float = 1.0

func _ready() -> void:
	sides = 3
	_phase_t = randf_range(2.0, 3.5)
	_turn = 1.0 if uid % 2 == 0 else -1.0

func _behave(delta: float) -> void:
	var to_ship: Vector2 = ship() - position
	var dist: float = maxf(to_ship.length(), 1.0)
	var dir: Vector2 = to_ship / dist
	_phase_t -= delta
	if _diving:
		steer(dir * speed * 1.6, 520.0, delta)
		if _phase_t <= 0.0:
			_diving = false
			_phase_t = randf_range(2.0, 3.2)
	else:
		var tangent: Vector2 = Vector2(-dir.y, dir.x) * _turn
		var radial: float = clampf((dist - CIRCLE_RADIUS) / 80.0, -1.0, 1.0)
		steer((dir * radial + tangent).normalized() * speed, 420.0, delta)
		if _phase_t <= 0.0 and entered:
			_diving = true
			_phase_t = 0.9

func _shape(c: Color) -> void:
	var a: float = vel.angle() if vel.length() > 10.0 else 0.0
	var f := Vector2.RIGHT.rotated(a)
	var s := Vector2(-f.y, f.x)
	polygon([f * radius * 1.4, -f * radius * 0.8 + s * radius * 0.9, -f * radius * 0.35, -f * radius * 0.8 - s * radius * 0.9], c, 2.0)
	if _diving:
		draw_line(-f * radius * 0.4, -f * radius * 2.2, Color(c, 0.5), 2.0)

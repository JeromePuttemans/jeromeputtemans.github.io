# =============================================================================
# Emitter.gd — One bullet pattern of an enemy, described in data/enemies.json
# =============================================================================
# Common keys: type, interval (s between volleys), delay (before the first),
#   speed, bullet (pellet | orb | rice | large), color, count, burst
#   (volleys fired in a row, burst_gap s apart), accel / min_speed /
#   max_speed (px/s^2 and limits), turn (deg/s, curves the bullets),
#   offset ([x, y] from the enemy centre).
# Types:
#   aimed    count bullets in a fan of spread degrees centred on the player
#   fan      the same fan in a fixed direction (deg, 90 = straight down)
#   ring     count bullets around 360 deg, turned by rotate deg each volley
#   spiral   arms bullets around 360 deg, turned by step deg each volley:
#            fired fast, it draws rotating arms
#   burst    count bullets at random angles within spread around the player
#            and random speeds between 0.6 and 1.0 x speed
#   wall     a ring with a gap of gap degrees aimed at the player
# Difficulty: speeds x bullet_speed, interval / fire_rate (GameState.diff).
# =============================================================================

class_name Emitter
extends RefCounted

const KINDS: Dictionary = {"pellet": Bullets.Kind.PELLET, "orb": Bullets.Kind.ORB, "rice": Bullets.Kind.RICE, "large": Bullets.Kind.LARGE}

var p: Dictionary = {}
var owner_id: int = 0
var _timer: float = 0.0
var _angle: float = 0.0
var _burst_left: int = 0
var _burst_timer: float = 0.0
var _speed_scale: float = 1.0
var _rate_scale: float = 1.0

func _init(pattern: Dictionary, owner: int) -> void:
	p = pattern
	owner_id = owner
	_timer = float(p.get("delay", 0.5))
	_angle = deg_to_rad(float(p.get("start", 0.0)))
	_speed_scale = GameState.diff("bullet_speed")
	_rate_scale = GameState.diff("fire_rate")

## Returns true when a volley was fired this step.
func step(delta: float, origin: Vector2, target: Vector2, bullets: Bullets) -> bool:
	var fired: bool = false
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_left -= 1
			_burst_timer = float(p.get("burst_gap", 0.08))
			_volley(origin, target, bullets)
			fired = true
	_timer -= delta
	if _timer <= 0.0:
		_timer += float(p.get("interval", 1.5)) / _rate_scale
		_volley(origin, target, bullets)
		_burst_left = int(p.get("burst", 1)) - 1
		_burst_timer = float(p.get("burst_gap", 0.08))
		fired = true
	return fired

func _volley(origin: Vector2, target: Vector2, bullets: Bullets) -> void:
	var off: Array = p.get("offset", [0, 0]) as Array
	var at: Vector2 = origin + Vector2(float(off[0]), float(off[1]))
	var speed: float = float(p.get("speed", 160.0)) * _speed_scale
	var count: int = int(p.get("count", 1))
	var aim: float = (target - at).angle()
	match str(p.get("type", "aimed")):
		"aimed":
			_fan(bullets, at, aim, count, deg_to_rad(float(p.get("spread", 0.0))), speed)
		"fan":
			_fan(bullets, at, deg_to_rad(float(p.get("direction", 90.0))), count, deg_to_rad(float(p.get("spread", 30.0))), speed)
		"ring":
			for i in count:
				_shoot(bullets, at, _angle + TAU * i / count, speed)
			_angle += deg_to_rad(float(p.get("rotate", 0.0)))
		"spiral":
			var arms: int = int(p.get("arms", 3))
			for i in arms:
				_shoot(bullets, at, _angle + TAU * i / arms, speed)
			_angle += deg_to_rad(float(p.get("step", 12.0)))
		"burst":
			var spread: float = deg_to_rad(float(p.get("spread", 60.0)))
			for i in count:
				_shoot(bullets, at, aim + randf_range(-spread, spread) * 0.5, speed * randf_range(0.6, 1.0))
		"wall":
			var gap: float = deg_to_rad(float(p.get("gap", 40.0)))
			for i in count:
				var a: float = aim + gap * 0.5 + (TAU - gap) * (float(i) + 0.5) / count
				_shoot(bullets, at, a, speed)

func _fan(bullets: Bullets, at: Vector2, center: float, count: int, spread: float, speed: float) -> void:
	if count <= 1:
		_shoot(bullets, at, center, speed)
		return
	for i in count:
		_shoot(bullets, at, center - spread * 0.5 + spread * i / (count - 1), speed)

func _shoot(bullets: Bullets, at: Vector2, angle: float, speed: float) -> void:
	var kind: int = int(KINDS.get(str(p.get("bullet", "pellet")), Bullets.Kind.PELLET))
	var color := Color(str(p.get("color", "ff6b8a")))
	var accel: float = float(p.get("accel", 0.0)) * _speed_scale
	var min_speed: float = float(p.get("min_speed", 0.0)) * _speed_scale
	var max_speed: float = float(p.get("max_speed", 10000.0)) * _speed_scale
	var turn: float = deg_to_rad(float(p.get("turn", 0.0)))
	bullets.spawn(at, Vector2.RIGHT.rotated(angle) * speed, kind, color, owner_id, accel, min_speed, max_speed, turn)

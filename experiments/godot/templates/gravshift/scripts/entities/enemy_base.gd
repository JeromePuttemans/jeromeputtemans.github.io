class_name EnemyBase
extends Node2D

# EnemyBase: shared behaviour of every enemy (values from settings.json
# "enemies"). Each frame: the subclass chooses a desired velocity
# (_behave), the gravity well adds its pull divided by the enemy's mass,
# then the enemy moves. Enemies spawn outside the arena; once inside they
# bounce off its edges. A stunned enemy (recoil upgrade) only drifts.
# A hit pushes the enemy back (knock, divided by its mass) and flashes it
# white.
# LOOK: a soft halo, a dark filled body and a bright outline, drawn with
# normal blending: enemies read as solid objects over the grid, while the
# bullets and the well glow (additive). `sides` is the number of edges of
# the outline, which effects.gd breaks into debris when the enemy dies.

var gm: Node = null
var uid: int = 0
var kind: String = ""
var hp: float = 1.0
var max_hp: float = 1.0
var mass: float = 1.0
var radius: float = 14.0
var speed: float = 100.0
var points: int = 50
var color: Color = Color.WHITE
var vel: Vector2 = Vector2.ZERO
var alive: bool = true
var entered: bool = false
var boss: bool = false
var stun: float = 0.0
var sides: int = 6
var data: Dictionary = {}

var _flash: float = 0.0
var _time: float = 0.0
var _fire: float = 0.0
var _hp_shown: float = 1.0

func setup(id: int, enemy_kind: String, enemy_data: Dictionary, game: Node) -> void:
	uid = id
	kind = enemy_kind
	data = enemy_data
	gm = game
	max_hp = float(enemy_data.get("hp", 3))
	hp = max_hp
	_hp_shown = max_hp
	mass = float(enemy_data.get("mass", 1.0))
	radius = float(enemy_data.get("radius", 14))
	speed = float(enemy_data.get("speed", 100))
	points = int(enemy_data.get("points", 50))
	color = Color(str(enemy_data.get("color", "ffffff")))
	_fire = float(enemy_data.get("fire_interval", 2.0)) * randf_range(0.6, 1.2)

func step(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta * 8.0, 0.0)
	_hp_shown = move_toward(_hp_shown, hp, max_hp * delta * 1.5)
	if stun > 0.0:
		stun -= delta
		vel *= 1.0 - minf(2.0 * delta, 1.0)
	else:
		_behave(delta)
	vel += (gm.call("well_pull", position, mass) as Vector2) * delta
	position += vel * delta
	var arena: Rect2 = gm.call("arena_rect") as Rect2
	var inner: Rect2 = arena.grow(-radius)
	if not entered:
		if inner.has_point(position):
			entered = true
		return
	if position.x < inner.position.x or position.x > inner.end.x:
		vel.x = -vel.x * 0.6
		position.x = clampf(position.x, inner.position.x, inner.end.x)
	if position.y < inner.position.y or position.y > inner.end.y:
		vel.y = -vel.y * 0.6
		position.y = clampf(position.y, inner.position.y, inner.end.y)

func _behave(_delta: float) -> void:
	pass

## Returns true when this damage destroyed the enemy.
func damage(amount: float) -> bool:
	if not alive:
		return false
	hp -= amount
	_flash = 1.0
	if hp <= 0.0:
		alive = false
		return true
	return false

## Pushes the enemy (impulse in px/s for a mass of 1).
func knock(impulse: Vector2) -> void:
	vel += (impulse / mass).limit_length(260.0)

func steer(desired: Vector2, accel: float, delta: float) -> void:
	vel = vel.move_toward(desired, accel * delta)

func ship() -> Vector2:
	return gm.call("ship_position") as Vector2

func fire_ready(delta: float) -> bool:
	_fire -= delta
	if _fire > 0.0 or not entered:
		return false
	_fire += float(data.get("fire_interval", 2.0))
	return true

## Share of the reload done (0 just after a shot, 1 when about to fire).
func charge() -> float:
	return clampf(1.0 - _fire / float(data.get("fire_interval", 2.0)), 0.0, 1.0)

func shoot(direction: Vector2, heavy: bool) -> void:
	var s: float = gm.call("bullet_speed", heavy) as float
	gm.call("spawn_bullet", position + direction * radius, direction * s, heavy)

func tint() -> Color:
	return color.lerp(Color.WHITE, _flash * 0.8)

func body_color() -> Color:
	return Color(color.darkened(0.84), 0.95).lerp(Color(1.0, 1.0, 1.0, 0.95), _flash * 0.75)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	Effects.put(self, Vector2.ZERO, radius * 2.6, Color(color, 0.28 + 0.35 * _flash))
	_shape(tint())
	if stun > 0.0:
		for k in 3:
			var a: float = _time * 6.0 + TAU * k / 3.0
			draw_circle(Vector2.RIGHT.rotated(a) * (radius + 6.0), 2.0, Color(0.6, 0.95, 1.0, 0.8))
	if not boss and hp < max_hp and max_hp > 3.0:
		var w: float = radius * 1.8
		var r := Rect2(-w * 0.5, -radius - 11.0, w, 3.0)
		draw_rect(r.grow(1.0), Color(0.0, 0.0, 0.05, 0.85))
		draw_rect(Rect2(r.position, Vector2(w * maxf(_hp_shown, 0.0) / max_hp, 3.0)), Color(1.0, 1.0, 1.0, 0.7))
		draw_rect(Rect2(r.position, Vector2(w * maxf(hp, 0.0) / max_hp, 3.0)), color)

func _shape(_c: Color) -> void:
	pass

## Closed outline, filled with the dark body colour unless fill is false.
func polygon(points_list: Array, c: Color, width: float, fill: bool = true) -> void:
	var pts := PackedVector2Array()
	for p in points_list:
		pts.append(p as Vector2)
	if fill:
		draw_colored_polygon(pts, body_color())
	pts.append(points_list[0] as Vector2)
	draw_polyline(pts, c, width)

## Regular polygon of n sides, radius r, rotated by a.
func ngon(n: int, r: float, a: float) -> Array:
	var pts: Array = []
	for k in n:
		pts.append(Vector2.RIGHT.rotated(a + TAU * k / n) * r)
	return pts

class_name EnemyBase
extends Node2D

# EnemyBase: shared behaviour of every enemy (values from settings.json
# "enemies"). Each frame: the subclass chooses a desired velocity
# (_behave), the gravity well adds its pull divided by the enemy's mass,
# then the enemy moves. Enemies spawn outside the arena; once inside they
# bounce off its edges. A stunned enemy (recoil upgrade) only drifts.

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
var data: Dictionary = {}

var _flash: float = 0.0
var _time: float = 0.0
var _fire: float = 0.0

func setup(id: int, enemy_kind: String, enemy_data: Dictionary, game: Node) -> void:
	uid = id
	kind = enemy_kind
	data = enemy_data
	gm = game
	max_hp = float(enemy_data.get("hp", 3))
	hp = max_hp
	mass = float(enemy_data.get("mass", 1.0))
	radius = float(enemy_data.get("radius", 14))
	speed = float(enemy_data.get("speed", 100))
	points = int(enemy_data.get("points", 50))
	color = Color(str(enemy_data.get("color", "ffffff")))
	_fire = float(enemy_data.get("fire_interval", 2.0)) * randf_range(0.6, 1.2)
	material = Effects.additive_material()

func step(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta * 8.0, 0.0)
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

func shoot(direction: Vector2, heavy: bool) -> void:
	var s: float = gm.call("bullet_speed", heavy) as float
	gm.call("spawn_bullet", position + direction * radius, direction * s, heavy)

func tint() -> Color:
	return color.lerp(Color.WHITE, _flash * 0.8)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	Effects.put(self, Vector2.ZERO, radius * 2.4, Color(color, 0.35 + 0.4 * _flash))
	_shape(tint())
	if not boss and hp < max_hp and max_hp > 3.0:
		var w: float = radius * 1.8
		draw_rect(Rect2(-w * 0.5, -radius - 10.0, w, 3.0), Color(0.2, 0.2, 0.3, 0.8))
		draw_rect(Rect2(-w * 0.5, -radius - 10.0, w * maxf(hp, 0.0) / max_hp, 3.0), color)

func _shape(_c: Color) -> void:
	pass

func polygon(points_list: Array, c: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for p in points_list:
		pts.append(p as Vector2)
	pts.append(points_list[0] as Vector2)
	draw_polyline(pts, c, width)

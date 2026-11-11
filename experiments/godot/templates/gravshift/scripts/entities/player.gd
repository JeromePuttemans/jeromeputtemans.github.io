extends Node2D

# Player: the ship. Accelerates toward the stick direction (player_speed,
# player_acceleration), slower while the well is open (well_speed_factor).
# The singularity's counter-well adds its own pull (extra_pull).
# AUTO-FIRE: every fire_interval seconds a slightly homing bolt toward the
# nearest enemy (more bolts with the twin cannon upgrade). The ship's nose
# follows its target.

var gm: Node = null
var vel: Vector2 = Vector2.ZERO
var alive: bool = true
var hp: int = 3
var hp_max: int = 3
var invulnerable: float = 0.0
var twin: int = 0
var fire_rate: float = 1.0
var radius: float = 7.0

var _g: Dictionary = {}
var _fire_t: float = 0.0
var _facing: float = -PI * 0.5
var _time: float = 0.0
var _trail: Array[Vector2] = []
var _well_open: bool = false

func setup(gameplay: Dictionary) -> void:
	_g = gameplay
	radius = float(gameplay.get("player_radius", 7.0))
	reset()

func reset() -> void:
	hp = int(_g.get("player_hp", 3))
	hp_max = hp
	alive = true
	invulnerable = 1.0
	vel = Vector2.ZERO
	twin = 0
	fire_rate = 1.0
	_trail.clear()

func step(delta: float, move: Vector2, well_open: bool, extra_pull: Vector2) -> void:
	_time += delta
	_well_open = well_open
	invulnerable = maxf(invulnerable - delta, 0.0)
	if not alive:
		return
	var speed: float = float(_g.get("player_speed", 330.0)) * (float(_g.get("well_speed_factor", 0.6)) if well_open else 1.0)
	vel = vel.move_toward(move * speed, float(_g.get("player_acceleration", 2600.0)) * delta)
	vel += extra_pull * delta
	position += vel * delta
	var arena: Rect2 = (gm.call("arena_rect") as Rect2).grow(-14.0)
	position = position.clamp(arena.position, arena.end)
	var target: Node2D = gm.call("nearest_enemy", position) as Node2D
	var want: float = (target.position - position).angle() if target != null else (vel.angle() if vel.length() > 30.0 else _facing)
	_facing = lerp_angle(_facing, want, minf(delta * 12.0, 1.0))
	_fire_t -= delta * fire_rate
	if _fire_t <= 0.0:
		_fire_t = float(_g.get("fire_interval", 0.2))
		_fire(target)
	_trail.push_front(position)
	while _trail.size() > 10:
		_trail.pop_back()

func _fire(target: Node2D) -> void:
	if target == null:
		return
	var dir: Vector2 = (target.position - position).normalized()
	var speed: float = float(_g.get("bullet_speed", 820.0))
	var damage: float = float(_g.get("bullet_damage", 1.0))
	var homing: float = float(_g.get("bullet_homing", 5.0))
	var shots: Node = gm.call("shots_node") as Node
	shots.call("spawn", position + dir * 14.0, dir * speed, damage, 0, 0, homing)
	for k in twin:
		var side: float = 0.22 * (floorf(k / 2.0) + 1.0) * (1.0 if k % 2 == 0 else -1.0)
		shots.call("spawn", position + dir * 10.0, dir.rotated(side) * speed, damage, 0, 0, homing)
	gm.call("sfx", "shot", 1.0, 0.08)

## Returns true when the hull is destroyed.
func hit() -> bool:
	hp -= 1
	invulnerable = float(_g.get("invulnerability_time", 1.6))
	if hp <= 0:
		hp = 0
		alive = false
		return true
	return false

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not alive:
		return
	for i in _trail.size():
		var p: Vector2 = _trail[i] - position
		draw_circle(p, 5.0 * (1.0 - float(i) / _trail.size()), Color(0.3, 0.8, 1.0, 0.25 * (1.0 - float(i) / _trail.size())))
	var alpha: float = 1.0
	if invulnerable > 0.0 and fmod(_time * 12.0, 1.0) < 0.5:
		alpha = 0.3
	var glow: float = 0.55 if _well_open else 0.35
	Effects.put(self, Vector2.ZERO, 34.0, Color(0.2, 0.8, 1.0, glow * alpha))
	var f := Vector2.RIGHT.rotated(_facing)
	var s := Vector2(-f.y, f.x)
	var nose: Vector2 = f * 17.0
	var left: Vector2 = -f * 11.0 + s * 12.0
	var right: Vector2 = -f * 11.0 - s * 12.0
	var notch: Vector2 = -f * 5.0
	var c := Color(0.45, 0.95, 1.0, alpha)
	draw_colored_polygon(PackedVector2Array([nose, left, notch, right]), Color(0.05, 0.2, 0.3, alpha))
	draw_polyline(PackedVector2Array([nose, left, notch, right, nose]), c, 2.5)
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 1.0, alpha))
	var flame: float = 6.0 + vel.length() * 0.03 + sin(_time * 40.0) * 2.0
	draw_line(notch, notch - f * flame, Color(1.0, 0.6, 0.3, 0.8 * alpha), 3.0)

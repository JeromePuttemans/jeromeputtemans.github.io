extends Node2D

# Player: the ship. Accelerates toward the stick direction (player_speed,
# player_acceleration), slower while the well is open (well_speed_factor).
# The singularity's counter-well adds its own pull (extra_pull).
# AUTO-FIRE: every fire_interval seconds a slightly homing bolt toward the
# nearest enemy (more bolts with the twin cannon upgrade). The ship's nose
# follows its target.
# LOOK: the wings bank with the sideways speed (the inner wing shortens),
# the hull squashes on a release (pulse), a ribbon trail follows the ship
# and two flames grow with its speed. The white core is the hitbox
# (player_radius): its ring is drawn while the well is open, when the
# player is busy weaving through bullets.

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
var _nova: bool = false
var _bank: float = 0.0
var _squash: float = 0.0
var _muzzle: float = 0.0

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
	_bank = 0.0
	_squash = 0.0
	_trail.clear()

## Squash the hull for a moment (release, Nova).
func pulse(amount: float) -> void:
	_squash = maxf(_squash, amount)

func step(delta: float, move: Vector2, well_open: bool, extra_pull: Vector2, nova: bool) -> void:
	_time += delta
	_well_open = well_open
	_nova = nova
	_squash = maxf(_squash - delta * 4.0, 0.0)
	_muzzle = maxf(_muzzle - delta * 10.0, 0.0)
	invulnerable = maxf(invulnerable - delta, 0.0)
	if not alive:
		return
	var top: float = float(_g.get("player_speed", 330.0))
	var speed: float = top * (float(_g.get("well_speed_factor", 0.6)) if well_open else 1.0)
	vel = vel.move_toward(move * speed, float(_g.get("player_acceleration", 2600.0)) * delta)
	vel += extra_pull * delta
	position += vel * delta
	var arena: Rect2 = (gm.call("arena_rect") as Rect2).grow(-14.0)
	position = position.clamp(arena.position, arena.end)
	var target: Node2D = gm.call("nearest_enemy", position) as Node2D
	var want: float = (target.position - position).angle() if target != null else (vel.angle() if vel.length() > 30.0 else _facing)
	_facing = lerp_angle(_facing, want, minf(delta * 12.0, 1.0))
	var f := Vector2.RIGHT.rotated(_facing)
	var lateral: float = vel.dot(Vector2(-f.y, f.x)) / top
	_bank = lerpf(_bank, clampf(lateral, -1.0, 1.0), minf(delta * 8.0, 1.0))
	_fire_t -= delta * fire_rate
	if _fire_t <= 0.0:
		_fire_t = float(_g.get("fire_interval", 0.2))
		_fire(target)
	_trail.push_front(position)
	while _trail.size() > 14:
		_trail.pop_back()

func _fire(target: Node2D) -> void:
	if target == null:
		return
	var dir: Vector2 = (target.position - position).normalized()
	var speed: float = float(_g.get("bullet_speed", 820.0))
	var damage: float = float(_g.get("bullet_damage", 1.0))
	var homing: float = float(_g.get("bullet_homing", 5.0))
	var shots: Node = gm.call("shots_node") as Node
	shots.call("spawn", position + dir * 16.0, dir * speed, damage, 0, 0, homing)
	for k in twin:
		var side: float = 0.22 * (floorf(k / 2.0) + 1.0) * (1.0 if k % 2 == 0 else -1.0)
		shots.call("spawn", position + dir * 10.0, dir.rotated(side) * speed, damage, 0, 0, homing)
	_muzzle = 1.0
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
	var hull_color: Color = Color(0.78, 0.62, 1.0) if _nova else Color(0.45, 0.95, 1.0)
	if _trail.size() > 2:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in _trail.size():
			pts.append(_trail[i] - position)
			cols.append(Color(hull_color, 0.32 * (1.0 - float(i) / _trail.size())))
		draw_polyline_colors(pts, cols, 7.0)
		draw_polyline_colors(pts, cols, 2.5)
	var alpha: float = 1.0
	if invulnerable > 0.0 and not _nova and fmod(_time * 12.0, 1.0) < 0.5:
		alpha = 0.35
	var glow: float = 0.6 if (_well_open or _nova) else 0.35
	Effects.put(self, Vector2.ZERO, 36.0 + 10.0 * _squash, Color(hull_color, glow * alpha))
	var f := Vector2.RIGHT.rotated(_facing)
	var s := Vector2(-f.y, f.x)
	var squash: float = 1.0 - 0.25 * _squash
	var widen: float = 1.0 + 0.3 * _squash
	var left_w: float = 13.0 * (1.0 - 0.35 * _bank) * widen
	var right_w: float = 13.0 * (1.0 + 0.35 * _bank) * widen
	var nose: Vector2 = f * 18.0 * squash
	var left: Vector2 = -f * 10.0 * squash + s * left_w
	var right: Vector2 = -f * 10.0 * squash - s * right_w
	var notch: Vector2 = -f * 4.0 * squash
	var c := Color(hull_color, alpha)
	var speed_k: float = clampf(vel.length() / 330.0, 0.0, 1.0)
	for side in [-1.0, 1.0]:
		var base: Vector2 = notch * 0.6 + s * side * 4.5
		var flame: float = 5.0 + speed_k * 9.0 + sin(_time * 45.0 + side) * 2.0
		draw_line(base, base - f * flame, Color(1.0, 0.65, 0.3, 0.85 * alpha), 3.0)
		draw_line(base, base - f * flame * 0.5, Color(1.0, 0.95, 0.8, alpha), 1.5)
	draw_colored_polygon(PackedVector2Array([nose, left, notch, right]), Color(0.03, 0.15, 0.24, 0.95 * alpha))
	draw_polyline(PackedVector2Array([nose, left, notch, right, nose]), c, 2.5)
	draw_line(nose * 0.75, notch * 0.2, Color(hull_color, 0.6 * alpha), 1.5)
	draw_line(left * 0.85, left * 0.55 + f * 3.0, Color(hull_color, 0.7 * alpha), 1.5)
	draw_line(right * 0.85, right * 0.55 + f * 3.0, Color(hull_color, 0.7 * alpha), 1.5)
	if _muzzle > 0.0:
		Effects.put(self, nose, 8.0 * _muzzle, Color(0.7, 0.95, 1.0, 0.8 * _muzzle))
	draw_circle(Vector2.ZERO, 3.2, Color(1.0, 1.0, 1.0, alpha))
	if _well_open:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.45 * alpha), 1.0)

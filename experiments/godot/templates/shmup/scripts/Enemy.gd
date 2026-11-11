# =============================================================================
# Enemy.gd — Enemy ship or boss, described in data/enemies.json
# =============================================================================
# MOVES
#   path    follows a curve of stage.json "paths" at a constant speed: the
#           control points (field fractions) are joined by a Catmull-Rom
#           spline, sampled into a polyline, and the ship advances along
#           its cumulated length. Leaves the game at the end of the path.
#   hover   comes down to its "at" point, stays hover_time s while swaying
#           a little, then flies off the top.
#   drift   goes straight down slowly, with a slight sideways sine.
#   dive    comes down to a third of the field, aims for 0.5 s, then
#           dashes toward where the player was.
#   boss    comes down to the top centre, then moves per phase: sway,
#           center or figure8.
# Patterns only fire while the ship is in the upper 75 % of the field, so
# nothing shoots point-blank from the bottom edge.
#
# BOSS PHASES: each phase has its own hp, time limit and patterns. When its
# hp runs out (or its time does), Game breaks the phase: bullets turn into
# gems, the boss is invulnerable for PHASE_PAUSE s, then the next phase
# starts. The last phase destroys the boss.
# =============================================================================

class_name Enemy
extends Node2D

const PHASE_PAUSE: float = 1.8

var game: Game = null
var id: int = 0
var kind: String = ""
var data: Dictionary = {}
var hp: float = 1.0
var max_hp: float = 1.0
var radius: float = 14.0
var large: bool = false
var alive: bool = true
var removed: bool = false
var is_boss: bool = false
var phase_index: int = 0
var phase_time: float = 0.0
var invulnerable: float = 0.0
var entered: bool = false

var _move: String = "path"
var _speed: float = 100.0
var _emitters: Array[Emitter] = []
var _time: float = 0.0
var _flash: float = 0.0
var _path := PackedVector2Array()
var _lengths := PackedFloat32Array()
var _travel: float = 0.0
var _target := Vector2.ZERO
var _state: int = 0
var _state_time: float = 0.0
var _dash := Vector2.ZERO
var _origin := Vector2.ZERO
var _color := Color.WHITE
var _shape: String = "dart"
var _facing: float = PI * 0.5

func setup(type_id: String, type_data: Dictionary, owner_id: int) -> void:
	kind = type_id
	data = type_data
	id = owner_id
	radius = float(data.get("radius", 14.0))
	large = bool(data.get("large", false))
	_move = str(data.get("move", "path"))
	_speed = float(data.get("speed", 120.0))
	_color = Color(str(data.get("color", "ff5f6d")))
	_shape = str(data.get("shape", "dart"))
	is_boss = data.has("phases")
	if is_boss:
		_start_phase(0)
		invulnerable = 0.0
	else:
		max_hp = float(data.get("hp", 3)) * GameState.diff("enemy_hp")
		hp = max_hp
		_build_emitters(data.get("patterns", []) as Array)

func _build_emitters(patterns: Array) -> void:
	_emitters.clear()
	for pattern in patterns:
		_emitters.append(Emitter.new(pattern as Dictionary, id))

## Path in field pixels (already mirrored and offset by Stage).
func set_path(points: PackedVector2Array) -> void:
	_path = _sample_spline(points)
	_lengths.resize(_path.size())
	var total: float = 0.0
	for i in _path.size():
		if i > 0:
			total += _path[i].distance_to(_path[i - 1])
		_lengths[i] = total
	position = _path[0]

func set_target(at: Vector2) -> void:
	_target = at
	position = Vector2(at.x, -radius - 20.0)
	_origin = position

static func _sample_spline(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = points.size()
	if n < 2:
		return points
	for i in n - 1:
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, n - 1)]
		for k in 12:
			var t: float = k / 12.0
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(points[n - 1])
	return out

# =============================================================================
# STEP
# =============================================================================

func step(delta: float) -> void:
	_time += delta
	_state_time += delta
	_flash = maxf(_flash - delta, 0.0)
	invulnerable = maxf(invulnerable - delta, 0.0)
	if not alive:
		return
	var before: Vector2 = position
	match _move:
		"path":
			_step_path(delta)
		"hover":
			_step_hover(delta)
		"drift":
			position.y += _speed * delta
			position.x = _origin.x + sin(_time * 1.3) * 18.0
			if position.y > game.field.y + radius + 30.0:
				removed = true
		"dive":
			_step_dive(delta)
		"boss":
			_step_boss(delta)
	if position.distance_squared_to(before) > 0.01:
		_facing = lerp_angle(_facing, (position - before).angle(), minf(delta * 8.0, 1.0))
	if not entered and position.y > radius:
		entered = true
	if is_boss:
		_step_phase(delta)
	if _can_fire():
		var target: Vector2 = game.player.core()
		for emitter in _emitters:
			if emitter.step(delta, position, target, game.bullets):
				Sfx.play("volley", 1.0 + randf_range(-0.1, 0.1), 0.0, -6.0)

func _can_fire() -> bool:
	if invulnerable > 0.0 or (is_boss and _state == 0):
		return false
	if position.y < 4.0 or position.y > game.field.y * 0.75 or position.x < 0.0 or position.x > game.field.x:
		return false
	return game.player.alive

func _step_path(delta: float) -> void:
	_travel += _speed * delta
	var total: float = _lengths[_lengths.size() - 1]
	if _travel >= total:
		removed = true
		return
	var i: int = _lengths.bsearch(_travel)
	i = clampi(i, 1, _lengths.size() - 1)
	var seg: float = _lengths[i] - _lengths[i - 1]
	var t: float = (_travel - _lengths[i - 1]) / seg if seg > 0.0 else 0.0
	position = _path[i - 1].lerp(_path[i], t)

func _step_hover(delta: float) -> void:
	match _state:
		0:
			position = position.lerp(_target, minf(delta * 2.2, 1.0))
			if position.distance_to(_target) < 4.0:
				_state = 1
				_state_time = 0.0
		1:
			position = _target + Vector2(sin(_state_time * 1.1) * 14.0, sin(_state_time * 2.0) * 5.0)
			if _state_time > float(data.get("hover_time", 5.0)):
				_state = 2
		2:
			position.y -= _speed * delta * minf(_state_time, 2.0)
			if position.y < -radius - 30.0:
				removed = true

func _step_dive(delta: float) -> void:
	match _state:
		0:
			position.y += _speed * 0.8 * delta
			if position.y > game.field.y * 0.3:
				_state = 1
				_state_time = 0.0
		1:
			if _state_time > 0.5:
				_state = 2
				_dash = (game.player.core() - position).normalized()
				if _dash.y < 0.3:
					_dash = Vector2(_dash.x, 0.3).normalized()
		2:
			position += _dash * _speed * 1.8 * delta
			if position.y > game.field.y + 40.0 or position.x < -40.0 or position.x > game.field.x + 40.0:
				removed = true

func _step_boss(delta: float) -> void:
	var home := Vector2(game.field.x * 0.5, game.field.y * 0.2)
	if _state == 0:
		position = position.lerp(home, minf(delta * 1.2, 1.0))
		if position.distance_to(home) < 3.0:
			_state = 1
			_state_time = 0.0
			game.on_boss_ready(self)
		return
	var phase: Dictionary = _phase()
	var target: Vector2 = home
	var t: float = _state_time
	match str(phase.get("move", "sway")):
		"sway":
			target = home + Vector2(sin(t * 0.55) * game.field.x * 0.28, sin(t * 1.1) * 18.0)
		"center":
			target = home + Vector2(sin(t * 0.8) * 10.0, sin(t * 1.6) * 8.0)
		"figure8":
			target = home + Vector2(sin(t * 0.5) * game.field.x * 0.3, sin(t * 1.0) * 60.0 + 30.0)
	position = position.lerp(target, minf(delta * 2.5, 1.0))

# =============================================================================
# DAMAGE AND PHASES
# =============================================================================

## Returns true when this hit destroyed the enemy or broke a boss phase.
func damage(amount: float) -> bool:
	if not alive or invulnerable > 0.0 or (is_boss and _state == 0):
		return false
	hp -= amount
	_flash = 0.06
	if hp > 0.0:
		return false
	if is_boss:
		game.on_boss_phase_end(self, false)
		return true
	alive = false
	return true

func _phase() -> Dictionary:
	var phases: Array = data["phases"] as Array
	return phases[clampi(phase_index, 0, phases.size() - 1)] as Dictionary

func phase_count() -> int:
	return (data["phases"] as Array).size()

func _step_phase(delta: float) -> void:
	if _state == 0 or invulnerable > 0.0:
		return
	phase_time -= delta
	if phase_time <= 0.0:
		game.on_boss_phase_end(self, true)

func _start_phase(index: int) -> void:
	phase_index = index
	var phase: Dictionary = _phase()
	max_hp = float(phase.get("hp", 500)) * GameState.diff("enemy_hp")
	hp = max_hp
	phase_time = float(phase.get("time", 30.0))
	invulnerable = PHASE_PAUSE
	_state_time = 0.0
	_build_emitters(phase.get("patterns", []) as Array)

## Called by Game after a broken phase. Returns false after the last one.
func next_phase() -> bool:
	if phase_index + 1 >= phase_count():
		alive = false
		return false
	_start_phase(phase_index + 1)
	return true

func color() -> Color:
	return _color

# =============================================================================
# DRAWING
# =============================================================================

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c: Color = _color.lerp(Color.WHITE, 0.75) if _flash > 0.0 else _color
	var dark: Color = c.darkened(0.45)
	match _shape:
		"dart":
			draw_set_transform(Vector2.ZERO, _facing - PI * 0.5, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([Vector2(0, 16), Vector2(12, -8), Vector2(4, -4), Vector2(0, -12), Vector2(-4, -4), Vector2(-12, -8)]), dark)
			draw_colored_polygon(PackedVector2Array([Vector2(0, 13), Vector2(8, -5), Vector2(0, -8), Vector2(-8, -5)]), c)
			draw_circle(Vector2(0, 2), 3.0, Color(1.0, 0.9, 0.6))
		"wasp":
			var flap: float = absf(sin(_time * 24.0))
			draw_colored_polygon(PackedVector2Array([Vector2(-4, -2), Vector2(-20, -10 - flap * 6), Vector2(-16, 4)]), Color(c.lightened(0.4), 0.7))
			draw_colored_polygon(PackedVector2Array([Vector2(4, -2), Vector2(20, -10 - flap * 6), Vector2(16, 4)]), Color(c.lightened(0.4), 0.7))
			draw_circle(Vector2.ZERO, 11.0, dark)
			draw_circle(Vector2.ZERO, 8.5, c)
			draw_circle(Vector2(0, 4), 3.5, Color(0.2, 0.05, 0.1))
		"lancer":
			draw_set_transform(Vector2.ZERO, _facing - PI * 0.5, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([Vector2(0, 24), Vector2(6, -6), Vector2(14, -14), Vector2(0, -8), Vector2(-14, -14), Vector2(-6, -6)]), dark)
			draw_colored_polygon(PackedVector2Array([Vector2(0, 20), Vector2(3, -4), Vector2(-3, -4)]), c)
			if _state == 1:
				draw_circle(Vector2(0, 20), 4.0 + sin(_time * 40.0) * 2.0, Color(1.0, 0.9, 0.5))
		"mine":
			var spin: float = _time * 2.0
			for k in 8:
				var a: float = spin + TAU * k / 8.0
				draw_line(Vector2.RIGHT.rotated(a) * 8.0, Vector2.RIGHT.rotated(a) * 17.0, dark, 3.0)
			draw_circle(Vector2.ZERO, 11.0, dark)
			draw_circle(Vector2.ZERO, 8.0, c)
			draw_circle(Vector2.ZERO, 3.0 + absf(sin(_time * 5.0)) * 2.0, Color(1.0, 0.95, 0.7))
		"gunship":
			_draw_gunship(c, dark)
		"carrier":
			_draw_carrier(c, dark)
		"sentinel":
			_draw_sentinel(c, dark)
		"crown":
			_draw_crown(c, dark)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not is_boss and large and hp < max_hp:
		var w: float = radius * 1.6
		draw_rect(Rect2(-w * 0.5, -radius - 10.0, w, 3.0), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-w * 0.5, -radius - 10.0, w * maxf(hp, 0.0) / max_hp, 3.0), Color(1.0, 0.85, 0.4))
	if invulnerable > 0.0 and is_boss and _state == 1:
		draw_arc(Vector2.ZERO, radius + 10.0 + sin(_time * 8.0) * 3.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.35), 2.0)

func _draw_gunship(c: Color, dark: Color) -> void:
	var hull := PackedVector2Array()
	for k in 6:
		hull.append(Vector2.RIGHT.rotated(TAU * k / 6.0 + PI / 6.0) * 22.0)
	draw_colored_polygon(hull, dark)
	var inner := PackedVector2Array()
	for k in 6:
		inner.append(Vector2.RIGHT.rotated(TAU * k / 6.0 + PI / 6.0) * 16.0)
	draw_colored_polygon(inner, c)
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(side * 26.0 - 5.0, -6.0, 10.0, 18.0), dark)
		draw_rect(Rect2(side * 26.0 - 3.0, 8.0, 6.0, 8.0), c.lightened(0.3))
	draw_circle(Vector2.ZERO, 7.0, Color(0.1, 0.05, 0.2))
	draw_circle(Vector2(0, 2), 4.0 + sin(_time * 6.0), Color(1.0, 0.8, 1.0))

func _draw_carrier(c: Color, dark: Color) -> void:
	draw_rect(Rect2(-34.0, -14.0, 68.0, 28.0), dark)
	draw_rect(Rect2(-30.0, -10.0, 60.0, 20.0), c)
	draw_colored_polygon(PackedVector2Array([Vector2(-34, -14), Vector2(-44, 0), Vector2(-34, 14)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(34, -14), Vector2(44, 0), Vector2(34, 14)]), dark)
	for k in 3:
		var lit: bool = int(_time * 4.0) % 3 == k
		draw_circle(Vector2(-16.0 + k * 16.0, 0.0), 4.0, Color(1.0, 0.9, 0.3) if lit else Color(0.4, 0.3, 0.1))
	draw_rect(Rect2(-6.0, 14.0, 12.0, 8.0), dark)

func _draw_sentinel(c: Color, dark: Color) -> void:
	var spin: float = _time * 0.8
	draw_circle(Vector2.ZERO, 46.0, Color(dark, 0.6))
	for k in 6:
		var a: float = spin + TAU * k / 6.0
		var p: Vector2 = Vector2.RIGHT.rotated(a) * 44.0
		draw_colored_polygon(PackedVector2Array([p + Vector2.RIGHT.rotated(a) * 14.0, p + Vector2.RIGHT.rotated(a + 2.2) * 9.0, p + Vector2.RIGHT.rotated(a - 2.2) * 9.0]), c)
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 48, c, 5.0)
	draw_circle(Vector2.ZERO, 24.0, dark)
	draw_circle(Vector2.ZERO, 16.0, c.lightened(0.2))
	draw_circle(Vector2.ZERO, 8.0 + sin(_time * 5.0) * 2.0, Color(1.0, 1.0, 0.9))

func _draw_crown(c: Color, dark: Color) -> void:
	var breathe: float = sin(_time * 2.0) * 3.0
	for side in [-1.0, 1.0]:
		var wing := PackedVector2Array([Vector2(side * 30, -20), Vector2(side * (92 + breathe), -36), Vector2(side * (104 + breathe), 6), Vector2(side * 70, 30), Vector2(side * 30, 22)])
		draw_colored_polygon(wing, dark)
		var inner := PackedVector2Array([Vector2(side * 36, -12), Vector2(side * (86 + breathe), -26), Vector2(side * (94 + breathe), 2), Vector2(side * 66, 20), Vector2(side * 36, 14)])
		draw_colored_polygon(inner, c)
		for k in 3:
			draw_circle(Vector2(side * (50 + k * 16), -6 + k * 4), 4.0, Color(1.0, 0.85, 0.5))
	var body := PackedVector2Array([Vector2(0, -56), Vector2(22, -40), Vector2(36, -6), Vector2(26, 38), Vector2(0, 50), Vector2(-26, 38), Vector2(-36, -6), Vector2(-22, -40)])
	draw_colored_polygon(body, dark)
	var top := PackedVector2Array([Vector2(0, -48), Vector2(16, -36), Vector2(28, -6), Vector2(20, 30), Vector2(0, 40), Vector2(-20, 30), Vector2(-28, -6), Vector2(-16, -36)])
	draw_colored_polygon(top, c)
	for k in 5:
		var x: float = -20.0 + k * 10.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, -44 + absf(k - 2) * 4), Vector2(x, -62 + absf(k - 2) * 6), Vector2(x + 4, -44 + absf(k - 2) * 4)]), Color(1.0, 0.8, 0.35))
	draw_circle(Vector2(0, 4), 14.0, Color(0.15, 0.02, 0.06))
	draw_circle(Vector2(0, 4), 9.0 + sin(_time * 4.0) * 2.0, Color(1.0, 0.4, 0.5))
	draw_circle(Vector2(0, 4), 4.0, Color(1.0, 0.95, 0.9))

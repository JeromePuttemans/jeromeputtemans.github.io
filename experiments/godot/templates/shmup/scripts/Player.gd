# =============================================================================
# Player.gd — The Aurore fighter: movement, automatic fire, options
# =============================================================================
# MOVEMENT is immediate (no acceleration): in a bullet pattern, the ship
# must stop exactly where the player lets go. 8 directions at player_speed,
# or player_focus_speed while the focus key is held.
#
# HITBOX: a player_hitbox px circle at the cockpit, shown in focus mode.
#   The ship drawing is ten times larger: bullets that touch the wings do
#   not count. GRAZE: graze_radius around the same centre.
#
# FIRE is automatic, one volley every shot_interval s:
#   normal mode (WIDE)  2 straight streams, then angled streams with power
#   focus mode (LANCE)  streams gathered in front, focus_shot_damage each
# OPTIONS: orbs that follow the ship from power 2 (2 orbs) and 4 (4 orbs);
#   they spread wide in normal mode and tuck in front in focus mode.
# =============================================================================

class_name Player
extends Node2D

const HULL_COLOR: Color = Color("d7e6ff")
const WING_COLOR: Color = Color("3d7bd9")
const ACCENT: Color = Color("6ff2ff")

var game: Game = null
var alive: bool = true
var entering: float = 0.0
var focus: bool = false
var invulnerable: float = 0.0
var velocity := Vector2.ZERO
var field := Vector2(540.0, 720.0)

var _speed: float = 330.0
var _focus_speed: float = 150.0
var _interval: float = 0.066
var _shot_speed: float = 950.0
var _damage: float = 1.0
var _focus_damage: float = 1.6
var _fire_timer: float = 0.0
var _bank: float = 0.0
var _time: float = 0.0
var _options: Array[Vector2] = []
var _focus_blend: float = 0.0
var hitbox: float = 3.5
var graze_radius: float = 26.0

func _ready() -> void:
	_speed = ConfigManager.get_float("player_speed", 330.0)
	_focus_speed = ConfigManager.get_float("player_focus_speed", 150.0)
	_interval = ConfigManager.get_float("shot_interval", 0.066)
	_shot_speed = ConfigManager.get_float("shot_speed", 950.0)
	_damage = ConfigManager.get_float("shot_damage", 1.0)
	_focus_damage = ConfigManager.get_float("focus_shot_damage", 1.6)
	hitbox = ConfigManager.get_float("player_hitbox", 3.5)
	graze_radius = ConfigManager.get_float("graze_radius", 26.0)
	for i in 4:
		_options.append(position)

func core() -> Vector2:
	return position + Vector2(0.0, -2.0)

func step(delta: float) -> void:
	_time += delta
	invulnerable = maxf(invulnerable - delta, 0.0)
	if not alive:
		return
	if entering > 0.0:
		entering = maxf(entering - delta, 0.0)
		position.y = lerpf(position.y, field.y - 100.0, minf(delta * 5.0, 1.0))
		_update_options(delta)
		return
	var dir := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	if dir.length() > 1.0:
		dir = dir.normalized()
	var was_focus: bool = focus
	focus = Input.is_action_pressed("focus")
	if focus and not was_focus:
		Sfx.play("focus")
	velocity = dir * (_focus_speed if focus else _speed)
	position += velocity * delta
	position.x = clampf(position.x, 14.0, field.x - 14.0)
	position.y = clampf(position.y, 24.0, field.y - 22.0)
	_bank = lerpf(_bank, dir.x, minf(delta * 10.0, 1.0))
	_focus_blend = move_toward(_focus_blend, 1.0 if focus else 0.0, delta * 6.0)
	_update_options(delta)
	_fire_timer -= delta
	while _fire_timer <= 0.0:
		_fire_timer += _interval
		_fire()

func _option_count() -> int:
	var level: int = GameState.power
	if level >= 4:
		return 4
	return 2 if level >= 2 else 0

func _option_target(i: int) -> Vector2:
	var side: float = -1.0 if i % 2 == 0 else 1.0
	var outer: bool = i >= 2
	var wide := Vector2(side * (56.0 if outer else 34.0), 18.0 if outer else 6.0)
	var tight := Vector2(side * (30.0 if outer else 16.0), -6.0 if outer else -16.0)
	return position + wide.lerp(tight, _focus_blend)

func _update_options(delta: float) -> void:
	for i in 4:
		_options[i] = _options[i].lerp(_option_target(i), minf(delta * 16.0, 1.0))

func _fire() -> void:
	var shots: Shots = game.shots
	var level: int = GameState.power
	var up := Vector2(0.0, -_shot_speed)
	if focus:
		shots.spawn(position + Vector2(-5.0, -18.0), up, _focus_damage, Shots.Kind.LANCE)
		shots.spawn(position + Vector2(5.0, -18.0), up, _focus_damage, Shots.Kind.LANCE)
		if level >= 3:
			shots.spawn(position + Vector2(-12.0, -10.0), up, _focus_damage, Shots.Kind.LANCE)
			shots.spawn(position + Vector2(12.0, -10.0), up, _focus_damage, Shots.Kind.LANCE)
		for i in _option_count():
			var target_x: float = position.x + (-6.0 if i % 2 == 0 else 6.0)
			var dir := Vector2(target_x - _options[i].x, -260.0).normalized()
			shots.spawn(_options[i] + Vector2(0.0, -8.0), dir * _shot_speed, _focus_damage * 0.75, Shots.Kind.LANCE)
	else:
		shots.spawn(position + Vector2(-6.0, -18.0), up, _damage, Shots.Kind.WIDE)
		shots.spawn(position + Vector2(6.0, -18.0), up, _damage, Shots.Kind.WIDE)
		var angles: Array[float] = []
		if level >= 2:
			angles.append(10.0)
		if level >= 3:
			angles.append(22.0)
		for a in angles:
			for side in [-1.0, 1.0]:
				shots.spawn(position + Vector2(side * 10.0, -10.0), up.rotated(deg_to_rad(a * side)), _damage, Shots.Kind.WIDE)
		for i in _option_count():
			var side2: float = -1.0 if i % 2 == 0 else 1.0
			shots.spawn(_options[i] + Vector2(0.0, -8.0), up.rotated(deg_to_rad(side2 * (4.0 if i < 2 else 9.0))), _damage, Shots.Kind.WIDE)
	Sfx.play("shot", 1.0, 0.08)

func die() -> void:
	alive = false
	velocity = Vector2.ZERO
	queue_redraw()

func respawn() -> void:
	alive = true
	position = Vector2(field.x * 0.5, field.y + 40.0)
	entering = 0.9
	invulnerable = ConfigManager.get_float("respawn_invulnerability", 2.5)
	_bank = 0.0
	for i in 4:
		_options[i] = position

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not alive:
		return
	var alpha: float = 1.0
	if invulnerable > 0.0 and fmod(_time * 12.0, 1.0) < 0.5:
		alpha = 0.35
	_draw_options(alpha)
	_draw_flames(alpha)
	var squeeze: float = 1.0 - absf(_bank) * 0.22
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(squeeze, 1.0))
	var tilt: float = _bank * 3.0
	var wing_l := PackedVector2Array([Vector2(-6, -2), Vector2(-26, 10 + tilt), Vector2(-24, 17 + tilt), Vector2(-7, 11)])
	var wing_r := PackedVector2Array([Vector2(6, -2), Vector2(26, 10 - tilt), Vector2(24, 17 - tilt), Vector2(7, 11)])
	draw_colored_polygon(wing_l, Color(WING_COLOR.darkened(0.15 + 0.2 * maxf(_bank, 0.0)), alpha))
	draw_colored_polygon(wing_r, Color(WING_COLOR.darkened(0.15 + 0.2 * maxf(-_bank, 0.0)), alpha))
	draw_line(Vector2(-7, 0), Vector2(-25, 11 + tilt), Color(ACCENT, 0.8 * alpha), 1.5)
	draw_line(Vector2(7, 0), Vector2(25, 11 - tilt), Color(ACCENT, 0.8 * alpha), 1.5)
	var hull := PackedVector2Array([Vector2(0, -24), Vector2(6, -9), Vector2(8, 6), Vector2(4, 15), Vector2(-4, 15), Vector2(-8, 6), Vector2(-6, -9)])
	draw_colored_polygon(hull, Color(HULL_COLOR.darkened(0.25), alpha))
	var top := PackedVector2Array([Vector2(0, -24), Vector2(4, -9), Vector2(5, 6), Vector2(0, 12), Vector2(-5, 6), Vector2(-4, -9)])
	draw_colored_polygon(top, Color(HULL_COLOR, alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -15), Vector2(2.5, -7), Vector2(0, -2), Vector2(-2.5, -7)]), Color(ACCENT, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _focus_blend > 0.01:
		var a: float = _focus_blend
		draw_arc(core(), graze_radius, _time * 2.0, _time * 2.0 + TAU, 40, Color(1.0, 1.0, 1.0, 0.12 * a), 1.0)
		for k in 4:
			var ang: float = _time * 2.0 + TAU * k / 4.0
			draw_arc(core(), graze_radius, ang, ang + 0.5, 6, Color(ACCENT, 0.45 * a), 2.0)
		draw_circle(core(), hitbox + 2.5, Color(1.0, 0.25, 0.35, a))
		draw_circle(core(), hitbox, Color(1.0, 1.0, 1.0, a))

func _draw_flames(alpha: float) -> void:
	var glow: Texture2D = Tex.glow()
	var flicker: float = 0.8 + 0.2 * sin(_time * 40.0) + (0.3 if velocity.y < 0.0 else 0.0) - (0.25 if velocity.y > 0.0 else 0.0)
	for side in [-4.0, 4.0]:
		var base := Vector2(side, 15.0)
		var length: float = 13.0 * flicker
		draw_colored_polygon(PackedVector2Array([base + Vector2(-2.5, 0), base + Vector2(0, length), base + Vector2(2.5, 0)]), Color(1.0, 0.65, 0.3, 0.85 * alpha))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-1.2, 0), base + Vector2(0, length * 0.6), base + Vector2(1.2, 0)]), Color(1.0, 1.0, 0.85, alpha))
		Tex.put(self, glow, base + Vector2(0, 4), 10.0, Color(1.0, 0.6, 0.3, 0.5 * alpha))

func _draw_options(alpha: float) -> void:
	var glow: Texture2D = Tex.glow()
	for i in _option_count():
		var at: Vector2 = _options[i] - position
		Tex.put(self, glow, at, 14.0, Color(ACCENT, 0.55 * alpha))
		draw_circle(at, 5.0, Color(0.15, 0.3, 0.5, alpha))
		draw_circle(at, 3.5, Color(ACCENT, alpha))
		var spin: float = _time * 6.0 + i
		draw_arc(at, 7.5, spin, spin + 2.0, 8, Color(1.0, 1.0, 1.0, 0.7 * alpha), 1.2)

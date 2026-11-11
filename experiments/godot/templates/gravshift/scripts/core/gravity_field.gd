class_name GravityField
extends Node2D

# GravityField: the ship's gravity well. Follows the ship (game_manager
# moves it every frame) and holds the orbit of captured bullets.
#
# PASSIVE: always on, weak: enemies within 1.2 x pull_radius drift toward the
#   ship by passive_pull / mass. The ship's position bends their paths.
# OPEN (well held): costs flux_drain flux per second and slows the ship.
#   Pellets inside pull_radius are pulled in (bullet_field.gd) and captured
#   inside capture_radius, up to orbit_capacity, each giving back
#   flux_per_capture. Enemies are pulled by enemy_pull / mass: light drones
#   are dragged into the orbit, where each bullet touching them costs it
#   (grinder upgrade: the bullet survives).
# RELEASE: every orbiting bullet is flung at the nearest enemies, spread
#   among them in turn, as a homing SLING shot; a shockwave of
#   shockwave_radius pushes back the bullets and enemies close by. When the
#   flux runs out the well collapses: the release is forced.
# Flux refills at flux_regen per second, flux_regen_delay s after a release.

signal twist_activated()

var gm: Node = null
var active: bool = false
var flux: float = 100.0
var flux_max: float = 100.0
var capacity: int = 12
var pierce: int = 0
var shrapnel: bool = false
var grinder: bool = false
var horizon: float = 1.0
var sling_mult: float = 1.0
var regen_mult: float = 1.0
var recoil: float = 1.0
var captured_total: int = 0

var _g: Dictionary = {}
var _angle := PackedFloat32Array()
var _radius := PackedFloat32Array()
var _settle := PackedFloat32Array()
var _from := PackedVector2Array()
var _regen_wait: float = 0.0
var _spin: float = 0.0
var _open_t: float = 0.0
var _twist_done: bool = false

func setup(gameplay: Dictionary) -> void:
	_g = gameplay
	reset()

func reset() -> void:
	active = false
	flux_max = float(_g.get("flux_max", 100.0))
	flux = flux_max
	capacity = int(_g.get("orbit_capacity", 12))
	pierce = 0
	shrapnel = false
	grinder = false
	horizon = 1.0
	sling_mult = 1.0
	regen_mult = 1.0
	recoil = 1.0
	captured_total = 0
	_clear_orbit()

func pull_radius() -> float:
	return float(_g.get("pull_radius", 230.0)) * horizon

func capture_radius() -> float:
	return float(_g.get("capture_radius", 74.0)) * horizon

func bullet_pull() -> float:
	return float(_g.get("bullet_pull", 1400.0))

func orbit_count() -> int:
	return _angle.size()

func can_capture() -> bool:
	return active and _angle.size() < capacity

func capture(at: Vector2, _velocity: Vector2) -> void:
	var n: int = _angle.size()
	_angle.append((at - global_position).angle())
	_radius.append(float(_g.get("orbit_radius", 48.0)) + float(n % 3) * 7.0)
	_settle.append(0.0)
	_from.append(at)
	flux = minf(flux + float(_g.get("flux_per_capture", 5.0)), flux_max)
	captured_total += 1
	gm.call("sfx", "capture", 1.0 + 0.06 * n, 0.0)
	gm.call("fx_burst", at, Color(0.4, 0.95, 1.0), 4, 80.0)
	if not _twist_done:
		_twist_done = true
		twist_activated.emit()

## Acceleration that the well applies to a body of this mass at pos.
func pull_on(pos: Vector2, mass: float) -> Vector2:
	var d: Vector2 = global_position - pos
	var dist: float = d.length()
	if dist < 1.0:
		return Vector2.ZERO
	var r: float = pull_radius()
	if active and dist < r:
		return d / dist * float(_g.get("enemy_pull", 900.0)) / mass * (1.0 - dist / r)
	var pr: float = r * 1.2
	if dist < pr:
		return d / dist * float(_g.get("passive_pull", 120.0)) / mass * (1.0 - dist / pr)
	return Vector2.ZERO

func step(delta: float, held: bool, ship_alive: bool) -> void:
	_spin += delta * (5.0 if active else 1.2)
	if not ship_alive:
		if active:
			active = false
		_clear_orbit()
		return
	if held and not active and flux >= float(_g.get("flux_min_to_open", 12.0)):
		active = true
		_open_t = 0.0
		gm.call("sfx", "well_open", 1.0, 0.05)
	if active:
		_open_t += delta
		flux -= float(_g.get("flux_drain", 28.0)) * delta
		if not held:
			release(false)
		elif flux <= 0.0:
			flux = 0.0
			release(true)
	else:
		if _regen_wait > 0.0:
			_regen_wait -= delta
		else:
			flux = minf(flux + float(_g.get("flux_regen", 22.0)) * regen_mult * delta, flux_max)
	var speed: float = float(_g.get("orbit_speed", 4.2))
	for i in _angle.size():
		_angle[i] = _angle[i] + speed * delta
		_settle[i] = minf(_settle[i] + delta * 6.0, 1.0)
	queue_redraw()

func orbiter_position(i: int) -> Vector2:
	var target: Vector2 = global_position + Vector2.RIGHT.rotated(_angle[i]) * _radius[i]
	return _from[i].lerp(target, ease(_settle[i], 0.5))

## Orbiting bullets touching an enemy: [{enemy, index}]. Grinder keeps them.
func orbit_contacts(enemies: Array) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for i in range(_angle.size() - 1, -1, -1):
		if _settle[i] < 1.0:
			continue
		var p: Vector2 = orbiter_position(i)
		for e in enemies:
			var en: Node2D = e as Node2D
			if not bool(en.get("alive")):
				continue
			var r: float = float(en.get("radius")) + 6.0
			if en.global_position.distance_squared_to(p) < r * r:
				hits.append({enemy = en, index = i})
				break
	return hits

func remove_orbiter(i: int) -> void:
	_angle.remove_at(i)
	_radius.remove_at(i)
	_settle.remove_at(i)
	_from.remove_at(i)

func release(collapse: bool) -> void:
	active = false
	_regen_wait = float(_g.get("flux_regen_delay", 0.35))
	var n: int = _angle.size()
	var enemies: Array = gm.call("live_enemies") as Array
	enemies.sort_custom(func(a: Variant, b: Variant) -> bool:
		return (a as Node2D).global_position.distance_squared_to(global_position) < (b as Node2D).global_position.distance_squared_to(global_position))
	var shots: Node = gm.call("shots_node") as Node
	var speed: float = float(_g.get("sling_speed", 780.0))
	var damage: float = float(_g.get("sling_damage", 3.0)) * sling_mult
	for i in n:
		var from: Vector2 = orbiter_position(i)
		var dir: Vector2 = (from - global_position).normalized()
		if not enemies.is_empty():
			var target: Node2D = enemies[i % mini(enemies.size(), maxi(n, 1))] as Node2D
			dir = (target.global_position - from).normalized()
		shots.call("spawn", from, dir * speed, damage, 1, pierce, float(_g.get("sling_homing", 7.0)))
	_clear_orbit()
	var radius: float = float(_g.get("shockwave_radius", 130.0)) * recoil
	gm.call("on_release", global_position, n, radius, collapse)

func _clear_orbit() -> void:
	_angle.resize(0)
	_radius.resize(0)
	_settle.resize(0)
	_from.resize(0)

func _draw() -> void:
	var pull_r: float = pull_radius()
	var capture_r: float = capture_radius()
	if active:
		var k: float = minf(_open_t * 6.0, 1.0)
		Effects.put(self, Vector2.ZERO, capture_r * 1.6 * k, Color(0.1, 0.5, 1.0, 0.3))
		draw_arc(Vector2.ZERO, capture_r * k, 0.0, TAU, 48, Color(0.4, 0.95, 1.0, 0.6), 2.0)
		for arm in 4:
			var pts := PackedVector2Array()
			for s in 14:
				var f: float = float(s) / 13.0
				var a: float = _spin * 1.4 + TAU * arm / 4.0 + f * 2.6
				pts.append(Vector2.RIGHT.rotated(a) * lerpf(pull_r, capture_r, f) * k)
			draw_polyline(pts, Color(0.3, 0.8, 1.0, 0.22), 2.0)
		draw_arc(Vector2.ZERO, pull_r * k, _spin, _spin + TAU, 72, Color(0.3, 0.8, 1.0, 0.16), 1.5)
	else:
		for d in 16:
			var a2: float = _spin * 0.4 + TAU * d / 16.0
			draw_arc(Vector2.ZERO, pull_r * 1.2, a2, a2 + 0.12, 3, Color(0.3, 0.7, 1.0, 0.12), 1.5)
	for i in _angle.size():
		var p: Vector2 = orbiter_position(i) - global_position
		for t in 3:
			var trail: Vector2 = Vector2.RIGHT.rotated(_angle[i] - (t + 1) * 0.12) * _radius[i]
			if _settle[i] >= 1.0:
				draw_circle(trail, 3.5 - t, Color(0.4, 0.95, 1.0, 0.35 - t * 0.1))
		Effects.put(self, p, 12.0, Color(0.4, 0.95, 1.0, 0.7))
		draw_circle(p, 4.0, Color(0.75, 1.0, 1.0))
	var ratio: float = flux / flux_max
	var color: Color = Color(0.35, 0.9, 1.0).lerp(Color(1.0, 0.3, 0.3), clampf(1.0 - ratio * 2.0, 0.0, 1.0))
	draw_arc(Vector2.ZERO, 30.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 40, Color(color, 0.85), 3.0)
	if capacity > 0 and _angle.size() > 0:
		var orbit_ratio: float = float(_angle.size()) / float(capacity)
		draw_arc(Vector2.ZERO, 36.0, -PI * 0.5, -PI * 0.5 + TAU * orbit_ratio, 40, Color(1.0, 1.0, 1.0, 0.5), 2.0)

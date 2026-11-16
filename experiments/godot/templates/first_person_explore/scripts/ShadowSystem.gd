# =============================================================================
# ShadowSystem.gd: The black stones and their solid shadows
# =============================================================================
# THE RULE OF THE GAME: the shadow of a black stone lies on the horizontal
# plane at the height of the stone's foot, and it is solid. White
# architecture casts no shadow at all.
#
# GEOMETRY: a stone is a box (width w, height h, depth d, turned by yaw
#   around the vertical axis). Its eight corners are projected onto the
#   plane along the sun's rays: p = c - dir * (c.y - plane) / dir.y, where
#   dir points towards the sun. The shadow is the convex hull of these
#   points (a box standing on the plane: from its foot to the projection of
#   its top; a floating box: a separate patch that travels with the sun).
# KINETIC STONES: a stone may move on its own. "spin" turns it around a
#   vertical axis (the jib: a beam on a white mast, whose shadow sweeps a
#   circle like a clock hand); "slide" carries it back and forth between
#   two points with a rest at each end (the ferry: a cabin on a white rail,
#   whose shadow is a raft that crosses the void by itself). Their shadows
#   are rebuilt every physics frame, the others only when the sun moves.
# PER SHADOW: a fill mesh just above the plane (graphite, hatched like the
#   shade on an architect's drawing), a light outline, short side walls (a
#   slab seen from below), and a StaticBody3D on collision layer 2 whose
#   ConvexPolygonShape3D is the hull, 0.12 m thick, its top flush with the
#   plane.
# CARRYING: a player standing on a shadow that moves (sun or stone) is
#   carried with it (carry()): the ray from the feet towards the old sun
#   hits the stone, in its old place, at a point q; q follows the stone to
#   its new place, and the feet go to its projection along the new sun.
# CLOUDS: two clouds sweep back and forth across the dawn bridge. Inside a
#   cloud's shade there is no sunlight, hence no shadow: the shader cuts a
#   hole there and is_clouded() tells the player to ignore layer 2.
# =============================================================================

class_name ShadowSystem
extends Node3D

const SHADOW_LAYER: int = 2
const SLAB: float = 0.12
const LIFT: float = 0.03
const OUTLINE: float = 0.05
const SIDE: float = 0.15

class Caster:
	var id: String = ""
	var foot := Vector3.ZERO      # centre of the bottom face
	var size := Vector3.ONE       # w, h, d
	var yaw: float = 0.0
	var plane: float = 0.0
	var prev_foot := Vector3.ZERO # place at the previous physics frame (carrying)
	var prev_yaw: float = 0.0
	var motion: String = ""       # "", "spin" or "slide"
	var pivot := Vector3.ZERO     # spin: axis (at foot height); slide: start
	var arm: float = 0.0          # spin: distance from the axis to the stone's centre
	var spin_speed: float = 0.0   # spin: radians per second
	var phase: float = 0.0        # spin: angle at time 0; slide: fraction of a period at time 0
	var slide_to := Vector3.ZERO  # slide: end
	var period: float = 10.0      # slide: seconds for a round trip
	var pause: float = 0.0        # slide: rest at each end, in seconds
	var dirty: bool = true
	var stone_body: StaticBody3D = null
	var stone: MeshInstance3D = null
	var stone_shape: BoxShape3D = null
	var fill: MeshInstance3D = null
	var body: StaticBody3D = null
	var shape: ConvexPolygonShape3D = null
	var poly := PackedVector2Array()

var casters: Array[Caster] = []
var sun_dir := Vector3.UP
var shadows_visible: bool = true
var fill_material: ShaderMaterial = null
var edge_material: ShaderMaterial = null
var stone_material: ShaderMaterial = null
var anim_time: float = 0.0
var _clouds: Array[Dictionary] = []
var _cloud_radius: float = 5.5
var _cloud_speed: float = 5.0
var _pulse: float = 0.0

func _init() -> void:
	fill_material = ShaderMaterial.new()
	fill_material.shader = preload("res://shaders/shadow.gdshader")
	fill_material.render_priority = 1
	edge_material = ShaderMaterial.new()
	edge_material.shader = preload("res://shaders/shadow.gdshader")
	edge_material.set_shader_parameter("edge", 1.0)
	edge_material.render_priority = 2
	stone_material = ShaderMaterial.new()
	stone_material.shader = preload("res://shaders/stone.gdshader")

## def: {id, x, z, w, d, h, yaw, lift, motion...}; plane: height of the
## shadow plane. For "spin", x and z give the axis; for "slide", the start.
func add_caster(def: Dictionary, plane: float) -> Caster:
	var c := Caster.new()
	c.id = str(def.get("id", ""))
	c.plane = plane
	c.yaw = deg_to_rad(float(def.get("yaw", 0.0)))
	c.size = Vector3(float(def["w"]), float(def["h"]), float(def["d"]))
	c.foot = Vector3(float(def["x"]), plane + float(def.get("lift", 0.0)), float(def["z"]))
	c.motion = str(def.get("motion", ""))
	c.pivot = c.foot
	match c.motion:
		"spin":
			c.arm = float(def.get("arm", 0.0))
			c.spin_speed = deg_to_rad(float(def.get("spin", 20.0)))
			c.phase = deg_to_rad(float(def.get("phase", 0.0)))
		"slide":
			var to: Array = def.get("to", [def["x"], def["z"]]) as Array
			c.slide_to = Vector3(float(to[0]), c.foot.y, float(to[1]))
			c.period = maxf(float(def.get("period", 12.0)), 1.0)
			c.pause = clampf(float(def.get("pause", 1.0)), 0.0, c.period * 0.45)
			c.phase = float(def.get("phase", 0.0))
	c.stone_body = StaticBody3D.new()
	c.stone_body.set_meta("surface", "stone")
	add_child(c.stone_body)
	c.stone = MeshInstance3D.new()
	c.stone.mesh = BoxMesh.new()
	c.stone.material_override = stone_material
	c.stone_body.add_child(c.stone)
	c.stone_shape = BoxShape3D.new()
	var stone_collision := CollisionShape3D.new()
	stone_collision.shape = c.stone_shape
	c.stone_body.add_child(stone_collision)
	c.fill = MeshInstance3D.new()
	c.fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(c.fill)
	c.body = StaticBody3D.new()
	c.body.collision_layer = 0
	c.body.set_collision_layer_value(SHADOW_LAYER, true)
	c.body.collision_mask = 0
	c.body.set_meta("surface", "shadow")
	c.body.set_meta("caster", casters.size())
	c.shape = ConvexPolygonShape3D.new()
	c.shape.points = PackedVector3Array([c.foot, c.foot + Vector3(0.1, 0.0, 0.0), c.foot + Vector3(0.0, 0.0, 0.1), c.foot + Vector3(0.0, -0.1, 0.0)])
	var col := CollisionShape3D.new()
	col.shape = c.shape
	c.body.add_child(col)
	add_child(c.body)
	casters.append(c)
	_animate(c, 0.0)
	c.prev_foot = c.foot
	c.prev_yaw = c.yaw
	_place_stone(c)
	return c

func find(id: String) -> Caster:
	for c in casters:
		if c.id == id:
			return c
	return null

func index_of(id: String) -> int:
	for i in casters.size():
		if casters[i].id == id:
			return i
	return -1

func set_height(id: String, h: float) -> void:
	var c: Caster = find(id)
	if c == null or is_equal_approx(c.size.y, h):
		return
	c.size.y = h
	_place_stone(c)
	c.dirty = true

func _place_stone(c: Caster) -> void:
	(c.stone.mesh as BoxMesh).size = c.size
	c.stone_shape.size = c.size
	c.stone_body.transform = Transform3D(Basis(Vector3.UP, c.yaw), c.foot + Vector3(0.0, c.size.y * 0.5, 0.0))

## Place of a kinetic stone at time t (seconds since the start).
func _animate(c: Caster, t: float) -> void:
	match c.motion:
		"spin":
			c.yaw = c.phase + c.spin_speed * t
			c.foot = c.pivot + Basis(Vector3.UP, c.yaw) * Vector3(c.arm, 0.0, 0.0)
		"slide":
			c.foot = c.pivot.lerp(c.slide_to, slide_fraction(c, t))

## 0 at the start, 1 at the end: a rest, a smooth crossing, a rest, the way back.
static func slide_fraction(c: Caster, t: float) -> float:
	var half: float = c.period * 0.5
	var s: float = fposmod(t + c.phase * c.period, c.period)
	var back: bool = s >= half
	if back:
		s -= half
	var k: float = smoothstep(0.0, 1.0, clampf((s - c.pause) / maxf(half - c.pause, 0.01), 0.0, 1.0))
	return 1.0 - k if back else k

func setup_clouds(defs: Array, radius: float, speed: float) -> void:
	_cloud_radius = radius
	_cloud_speed = speed
	for d in defs:
		var cloud := {x = float(d["x"]), z_min = float(d["z_min"]), z_max = float(d["z_max"]), t = float(d.get("phase", 0.0)), z = 0.0, node = _make_cloud()}
		_clouds.append(cloud)
	_step_clouds(0.0)

func _make_cloud() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.94)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.6, 0.62)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + _clouds.size()
	for i in 7:
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var r: float = rng.randf_range(2.2, 3.8)
		sphere.radius = r
		sphere.height = r * 1.3
		sphere.radial_segments = 16
		sphere.rings = 8
		puff.mesh = sphere
		puff.material_override = mat
		puff.position = Vector3(rng.randf_range(-4.0, 4.0), rng.randf_range(-0.5, 1.0), rng.randf_range(-3.0, 3.0))
		root.add_child(puff)
	add_child(root)
	return root

func _process(delta: float) -> void:
	_step_clouds(delta)
	_pulse = maxf(_pulse - delta * 2.5, 0.0)
	edge_material.set_shader_parameter("pulse", _pulse)
	fill_material.set_shader_parameter("pulse", _pulse)

func _step_clouds(delta: float) -> void:
	var params: Array[Vector3] = [Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, -1.0)]
	for i in _clouds.size():
		var cl: Dictionary = _clouds[i]
		var span: float = float(cl["z_max"]) - float(cl["z_min"])
		cl["t"] = float(cl["t"]) + delta * _cloud_speed / maxf(span * 2.0, 0.01)
		var k: float = pingpong(float(cl["t"]) * 2.0, 1.0)
		cl["z"] = lerpf(float(cl["z_min"]), float(cl["z_max"]), smoothstep(0.0, 1.0, k))
		(cl["node"] as Node3D).position = Vector3(float(cl["x"]), 22.0, float(cl["z"]))
		if i < 2:
			params[i] = Vector3(float(cl["x"]), float(cl["z"]), _cloud_radius)
	fill_material.set_shader_parameter("cloud_a", params[0])
	fill_material.set_shader_parameter("cloud_b", params[1])
	edge_material.set_shader_parameter("cloud_a", params[0])
	edge_material.set_shader_parameter("cloud_b", params[1])

func is_clouded(p: Vector3) -> bool:
	for cl in _clouds:
		if Vector2(p.x - float(cl["x"]), p.z - float(cl["z"])).length() < _cloud_radius:
			return true
	return false

## Brief brighter outlines (when the hour starts moving).
func pulse() -> void:
	_pulse = 1.0

func set_sun(dir: Vector3) -> void:
	if dir.is_equal_approx(sun_dir):
		return
	sun_dir = dir
	for c in casters:
		c.dirty = true

func set_shadows_visible(value: bool) -> void:
	shadows_visible = value
	for c in casters:
		c.fill.visible = value
		c.body.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED

## Kinetic stones move first, so that the player, processed after this
## node, can be carried from their old place to the new one.
func _physics_process(delta: float) -> void:
	anim_time += delta
	for c in casters:
		c.prev_foot = c.foot
		c.prev_yaw = c.yaw
		if c.motion != "":
			_animate(c, anim_time)
			_place_stone(c)
			c.dirty = true
	rebuild_if_needed()

func rebuild_if_needed() -> void:
	for c in casters:
		if c.dirty:
			c.dirty = false
			c.poly = shadow_polygon(c, sun_dir)
			_build_shadow(c)

func shadow_polygon(c: Caster, dir: Vector3) -> PackedVector2Array:
	return polygon_for(c.foot, c.yaw, c.size, c.plane, dir)

## Shadow of a box (foot, yaw, size) on the plane, for any sun direction.
static func polygon_for(foot: Vector3, yaw: float, size: Vector3, plane: float, dir: Vector3) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if dir.y < 0.02:
		return pts
	var basis := Basis(Vector3.UP, yaw)
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			for sy in [0.0, 1.0]:
				var corner: Vector3 = foot + basis * Vector3(sx * size.x, sy * size.y, sz * size.z)
				var k: float = (corner.y - plane) / dir.y
				pts.append(Vector2(corner.x - dir.x * k, corner.z - dir.z * k))
	var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)
	return hull

func _build_shadow(c: Caster) -> void:
	var poly: PackedVector2Array = c.poly
	if poly.size() < 3:
		c.fill.mesh = null
		c.shape.points = PackedVector3Array([Vector3(0.0, -500.0, 0.0), Vector3(0.1, -500.0, 0.0), Vector3(0.0, -500.0, 0.1), Vector3(0.0, -500.1, 0.0)])
		return
	var y: float = c.plane + LIFT
	var centre := Vector2.ZERO
	for p in poly:
		centre += p
	centre /= poly.size()
	var fill_v := PackedVector3Array()
	var edge_v := PackedVector3Array()
	var n: int = poly.size()
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		fill_v.append_array([Vector3(centre.x, y, centre.y), Vector3(a.x, y, a.y), Vector3(b.x, y, b.y)])
		# side wall, so the slab has a visible thickness from below
		var a_top := Vector3(a.x, y, a.y)
		var b_top := Vector3(b.x, y, b.y)
		var a_low := Vector3(a.x, y - SIDE, a.y)
		var b_low := Vector3(b.x, y - SIDE, b.y)
		fill_v.append_array([a_top, b_low, b_top, a_top, a_low, b_low])
		# light outline: a thin ribbon along the edge, just inside
		var along: Vector2 = (b - a).normalized()
		var inward := Vector2(-along.y, along.x)
		if inward.dot(centre - a) < 0.0:
			inward = -inward
		var ai: Vector2 = a + inward * OUTLINE
		var bi: Vector2 = b + inward * OUTLINE
		var ey: float = y + 0.005
		edge_v.append_array([Vector3(a.x, ey, a.y), Vector3(b.x, ey, b.y), Vector3(bi.x, ey, bi.y)])
		edge_v.append_array([Vector3(a.x, ey, a.y), Vector3(bi.x, ey, bi.y), Vector3(ai.x, ey, ai.y)])
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = fill_v
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, fill_material)
	var edge_arrays: Array = []
	edge_arrays.resize(Mesh.ARRAY_MAX)
	edge_arrays[Mesh.ARRAY_VERTEX] = edge_v
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, edge_arrays)
	mesh.surface_set_material(1, edge_material)
	c.fill.mesh = mesh
	var points := PackedVector3Array()
	for p in poly:
		points.append(Vector3(p.x, c.plane, p.y))
		points.append(Vector3(p.x, c.plane - SLAB, p.y))
	c.shape.points = points

## Horizontal displacement of feet standing on the shadow of caster `index`
## between the previous physics frame (old sun, old place of the stone) and
## this one (new sun, new place).
func carry(feet: Vector3, index: int, old_dir: Vector3, new_dir: Vector3) -> Vector3:
	if index < 0 or index >= casters.size() or old_dir.y < 0.02 or new_dir.y < 0.02:
		return Vector3.ZERO
	var c: Caster = casters[index]
	var origin := Vector3(feet.x, c.plane, feet.z)
	var hit: Variant = _ray_box(c.prev_foot, c.prev_yaw, c.size, origin, old_dir)
	if hit == null:
		return Vector3.ZERO
	var local: Vector3 = Basis(Vector3.UP, -c.prev_yaw) * ((hit as Vector3) - c.prev_foot)
	var q: Vector3 = c.foot + Basis(Vector3.UP, c.yaw) * local
	var k: float = (q.y - c.plane) / new_dir.y
	return Vector3(q.x - new_dir.x * k - feet.x, 0.0, q.z - new_dir.z * k - feet.z)

## True when the stone moved since the previous physics frame.
func moved(index: int) -> bool:
	if index < 0 or index >= casters.size():
		return false
	var c: Caster = casters[index]
	return not c.foot.is_equal_approx(c.prev_foot) or not is_equal_approx(c.yaw, c.prev_yaw)

## First point where the ray (origin, dir) enters the box, or null.
static func _ray_box(foot: Vector3, yaw: float, size: Vector3, origin: Vector3, dir: Vector3) -> Variant:
	var inv := Basis(Vector3.UP, -yaw)
	var o: Vector3 = inv * (origin - foot)
	var d: Vector3 = inv * dir
	var lo := Vector3(-size.x * 0.5, 0.0, -size.z * 0.5)
	var hi := Vector3(size.x * 0.5, size.y, size.z * 0.5)
	var t_min: float = 0.0
	var t_max: float = 1e9
	for axis in 3:
		if absf(d[axis]) < 1e-6:
			if o[axis] < lo[axis] - 0.05 or o[axis] > hi[axis] + 0.05:
				return null
			continue
		var t1: float = (lo[axis] - o[axis]) / d[axis]
		var t2: float = (hi[axis] - o[axis]) / d[axis]
		t_min = maxf(t_min, minf(t1, t2))
		t_max = minf(t_max, maxf(t1, t2))
	if t_max < t_min - 0.05:
		return null
	return origin + dir * t_min

# =============================================================================
# ShadowSystem.gd — The black stones and their solid shadows
# =============================================================================
# THE RULE OF THE GAME: the shadow of a black stone lies on the horizontal
# plane at the height of the stone's foot, and it is solid.
#
# GEOMETRY: a stone is a box (width w, height h, depth d, turned by yaw
#   around the vertical axis). Its eight corners are projected onto the
#   plane along the sun's rays: p = c - dir * (c.y - plane) / dir.y, where
#   dir points towards the sun. The shadow is the convex hull of these
#   points (a box standing on the plane: from its foot to the projection of
#   its top; a floating box, the monolith: a separate patch that travels
#   with the sun).
# PER SHADOW: a fill mesh just above the plane (indigo glass), a gold
#   outline, short side walls (a slab seen from below), and a StaticBody3D
#   on collision layer 2 whose ConvexPolygonShape3D is the hull, 0.12 m
#   thick (a shadow hanging 2 m above the ground still lets the player walk
#   under it), its top flush with the plane. Everything is rebuilt whenever the
#   sun moves or a stone changes height (the great gnomon).
# CARRYING: a player standing on a shadow when the sun moves is carried
#   with it (carry()): the ray from the feet towards the old sun hits the
#   stone at a point q; the feet move to the projection of q along the new
#   sun. Riding the monolith's shadow across the void relies on this.
# CLOUDS: two clouds sweep back and forth across the dawn bridge. Inside a
#   cloud's shade there is no sunlight, hence no shadow: the shader cuts a
#   hole there and is_clouded() tells the player to ignore layer 2.
# =============================================================================

class_name ShadowSystem
extends Node3D

const SHADOW_LAYER: int = 2
const SLAB: float = 0.12
const LIFT: float = 0.03
const OUTLINE: float = 0.07
const SIDE: float = 0.15

class Caster:
	var id: String = ""
	var foot := Vector3.ZERO      # centre of the bottom face
	var size := Vector3.ONE       # w, h, d
	var yaw: float = 0.0
	var plane: float = 0.0
	var stone: MeshInstance3D = null
	var stone_shape: BoxShape3D = null
	var stone_collision: CollisionShape3D = null
	var fill: MeshInstance3D = null
	var body: StaticBody3D = null
	var shape: ConvexPolygonShape3D = null
	var poly := PackedVector2Array()

var casters: Array[Caster] = []
var sun_dir := Vector3.UP
var shadows_visible: bool = true
var fill_material: ShaderMaterial = null
var edge_material: ShaderMaterial = null
var basalt_material: ShaderMaterial = null
var _dirty: bool = true
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
	basalt_material = ShaderMaterial.new()
	basalt_material.shader = preload("res://shaders/basalt.gdshader")

## def: {id, x, z, w, d, h, yaw, lift}; plane: height of the shadow plane.
func add_caster(def: Dictionary, plane: float) -> Caster:
	var c := Caster.new()
	c.id = str(def.get("id", ""))
	c.plane = plane
	c.yaw = deg_to_rad(float(def.get("yaw", 0.0)))
	c.size = Vector3(float(def["w"]), float(def["h"]), float(def["d"]))
	c.foot = Vector3(float(def["x"]), plane + float(def.get("lift", 0.0)), float(def["z"]))
	var stone_body := StaticBody3D.new()
	stone_body.set_meta("surface", "stone")
	add_child(stone_body)
	c.stone = MeshInstance3D.new()
	c.stone.mesh = BoxMesh.new()
	c.stone.material_override = basalt_material
	stone_body.add_child(c.stone)
	c.stone_shape = BoxShape3D.new()
	c.stone_collision = CollisionShape3D.new()
	c.stone_collision.shape = c.stone_shape
	stone_body.add_child(c.stone_collision)
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
	_place_stone(c)
	_dirty = true
	return c

func find(id: String) -> Caster:
	for c in casters:
		if c.id == id:
			return c
	return null

func set_height(id: String, h: float) -> void:
	var c: Caster = find(id)
	if c == null or is_equal_approx(c.size.y, h):
		return
	c.size.y = h
	_place_stone(c)
	_dirty = true

func _place_stone(c: Caster) -> void:
	(c.stone.mesh as BoxMesh).size = c.size
	c.stone_shape.size = c.size
	var xf := Transform3D(Basis(Vector3.UP, c.yaw), c.foot + Vector3(0.0, c.size.y * 0.5, 0.0))
	c.stone.transform = xf
	c.stone_collision.transform = xf

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
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.55, 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + _clouds.size()
	for i in 7:
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var r: float = rng.randf_range(2.2, 3.8)
		sphere.radius = r
		sphere.height = r * 1.4
		sphere.radial_segments = 12
		sphere.rings = 6
		puff.mesh = sphere
		puff.material_override = mat
		puff.position = Vector3(rng.randf_range(-4.0, 4.0), rng.randf_range(-0.5, 1.2), rng.randf_range(-3.0, 3.0))
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
	if dir.is_equal_approx(sun_dir) and not _dirty:
		return
	sun_dir = dir
	_dirty = true

func set_shadows_visible(value: bool) -> void:
	shadows_visible = value
	for c in casters:
		c.fill.visible = value
		c.body.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED

func _physics_process(_delta: float) -> void:
	rebuild_if_needed()

func rebuild_if_needed() -> void:
	if not _dirty:
		return
	_dirty = false
	for c in casters:
		c.poly = shadow_polygon(c, sun_dir)
		_build_shadow(c)

func shadow_polygon(c: Caster, dir: Vector3) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if dir.y < 0.02:
		return pts
	var basis := Basis(Vector3.UP, c.yaw)
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			for sy in [0.0, 1.0]:
				var corner: Vector3 = c.foot + basis * Vector3(sx * c.size.x, sy * c.size.y, sz * c.size.z)
				var k: float = (corner.y - c.plane) / dir.y
				pts.append(Vector2(corner.x - dir.x * k, corner.z - dir.z * k))
	var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)
	return hull

func _build_shadow(c: Caster) -> void:
	var poly: PackedVector2Array = c.poly
	if poly.size() < 3:
		c.fill.mesh = null
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
		# gold outline: a thin ribbon along the edge, just inside
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
## when the sun turns from old_dir to new_dir.
func carry(feet: Vector3, index: int, old_dir: Vector3, new_dir: Vector3) -> Vector3:
	if index < 0 or index >= casters.size() or old_dir.y < 0.02 or new_dir.y < 0.02:
		return Vector3.ZERO
	var c: Caster = casters[index]
	var origin := Vector3(feet.x, c.plane, feet.z)
	var hit: Variant = _ray_box(c, origin, old_dir)
	if hit == null:
		return Vector3.ZERO
	var q: Vector3 = hit
	var k: float = (q.y - c.plane) / new_dir.y
	return Vector3(q.x - new_dir.x * k - feet.x, 0.0, q.z - new_dir.z * k - feet.z)

## First point where the ray (origin, dir) enters the stone, or null.
func _ray_box(c: Caster, origin: Vector3, dir: Vector3) -> Variant:
	var inv := Basis(Vector3.UP, -c.yaw)
	var o: Vector3 = inv * (origin - c.foot)
	var d: Vector3 = inv * dir
	var lo := Vector3(-c.size.x * 0.5, 0.0, -c.size.z * 0.5)
	var hi := Vector3(c.size.x * 0.5, c.size.y, c.size.z * 0.5)
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

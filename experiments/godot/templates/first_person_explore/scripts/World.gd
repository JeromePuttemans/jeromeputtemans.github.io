# =============================================================================
# World.gd: Builds the white archipelago from data/world.json
# =============================================================================
# PLATFORMS: slabs of white concrete 0.8 m thick floating over the mist, on
#   slender pilotis that vanish into it. Three shapes: "disc", "rect" (with
#   optional rectangular wells, "holes", cut through it) and "ring" (the
#   Oculus, a disc around a dark well with a spiral ramp). Collision: convex
#   prisms and boxes only (Godot Physics lets bodies sink through cylinder
#   shapes); a rect with holes is cut into boxes. Every platform body
#   carries meta "surface" and "island".
# BLACK STONES: handed to ShadowSystem. A spinning stone (the jib) stands on
#   a white mast; a sliding stone (the ferry) hangs from a white rail that
#   floats like everything else. White pieces cast no shadow: that is the
#   rule of the world.
# OTHER PIECES: frameless glass balustrades, white walls, benches and
#   portal frames, standable blocks, grey figures for scale, sun shards,
#   the three seals (circle, square, triangle) with their markers, the
#   return beams, the sockets near the gnomon, a small sundial whose lines
#   show where its needle's shadow falls, distant monumental volumes and
#   the mist below.
# PICKUPS: update_pickups() runs every physics frame with the player's
#   position: shards drift towards the player inside the magnet radius and
#   are taken inside the pick radius; seals, beams and the Oculus are
#   simple distance triggers. Results go out as signals.
# =============================================================================

class_name World
extends Node3D

signal shard_collected(index: int, position: Vector3)
signal seal_taken(id: String, position: Vector3)
signal beam_entered(id: String)
signal observatory_reached()

const ROMAN: Array[String] = ["VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII"]
const ACCENT: Color = Color(1.0, 0.38, 0.1)
const SLAB_THICKNESS: float = 0.8
const MIST_Y: float = -70.0
const RAIL_HEIGHT: float = 1.05

var data: Dictionary = {}
var islands: Dictionary = {}          # id -> definition
var shadows: ShadowSystem = null
var lowest_y: float = 0.0

var _concrete: ShaderMaterial = null
var _concrete_plain: ShaderMaterial = null
var _metal: StandardMaterial3D = null
var _glass: StandardMaterial3D = null
var _figure: StandardMaterial3D = null
var _ink: StandardMaterial3D = null
var _shards: Array[Dictionary] = []   # {node, home, pos, taken, offset}
var _seals: Array[Dictionary] = []    # {id, node, sky, beam, pos, beam_pos, taken}
var _sockets: Array[Dictionary] = []  # {node, seal, base}
var _time: float = 0.0
var _magnet: float = 2.6
var _pick: float = 1.0
var _seal_pick: float = 1.6
var _beam_radius: float = 1.3

func build(shadow_system: ShadowSystem) -> void:
	shadows = shadow_system
	data = ConfigManager.load_json("res://data/world.json") as Dictionary
	_magnet = ConfigManager.get_float("shard_magnet_radius", 2.6)
	_pick = ConfigManager.get_float("shard_pick_radius", 1.0)
	_seal_pick = ConfigManager.get_float("seal_pick_radius", 1.6)
	_beam_radius = ConfigManager.get_float("beam_radius", 1.3)
	_make_materials()
	for d in data.get("islands", []) as Array:
		var def: Dictionary = d as Dictionary
		islands[str(def["id"])] = def
		lowest_y = minf(lowest_y, float(def["y"]))
		_build_island(def)
	for d in data.get("casters", []) as Array:
		var def: Dictionary = d as Dictionary
		var plane: float = float(def.get("base_y", 0.0))
		if def.has("island"):
			plane = float((islands[str(def["island"])] as Dictionary)["y"])
		var caster: ShadowSystem.Caster = shadows.add_caster(def, plane)
		_build_caster_support(caster, def)
	for d in data.get("blocks", []) as Array:
		_build_block(d as Dictionary)
	for d in data.get("props", []) as Array:
		_build_prop(d as Dictionary)
	shadows.setup_clouds(data.get("clouds", []) as Array, ConfigManager.get_float("cloud_radius", 5.5), ConfigManager.get_float("cloud_speed", 5.0))
	_build_shards()
	_build_seals()
	_build_sockets()
	_build_sundial()
	_build_far_architecture()
	_build_mist()

func shard_total() -> int:
	return _shards.size()

func island(id: String) -> Dictionary:
	return islands.get(id, {}) as Dictionary

## Island whose flat top holds these feet, or "" (a shadow lying on an
## island does not hide it: arrivals are read from the geometry; a well cut
## through a slab is not part of it).
func island_at(feet: Vector3) -> String:
	for id in islands:
		var d: Dictionary = islands[id]
		if absf(feet.y - float(d["y"])) < 0.25 and contains(d, feet.x, feet.z, 0.05):
			return str(id)
	return ""

## True when (x, z) lies on the platform, `margin` metres around it included.
static func contains(d: Dictionary, x: float, z: float, margin: float) -> bool:
	var dx: float = x - float(d["x"])
	var dz: float = z - float(d["z"])
	match str(d.get("shape", "disc")):
		"rect":
			if absf(dx) > float(d["w"]) * 0.5 + margin or absf(dz) > float(d["d"]) * 0.5 + margin:
				return false
			for h in d.get("holes", []) as Array:
				var hole: Array = h as Array
				if absf(x - float(hole[0])) < float(hole[2]) * 0.5 - margin and absf(z - float(hole[1])) < float(hole[3]) * 0.5 - margin:
					return false
			return true
		"ring":
			var dist: float = Vector2(dx, dz).length()
			return dist <= float(d["r"]) + margin and dist >= float(d.get("inner", 0.0)) - margin
	return Vector2(dx, dz).length() <= float(d["r"]) + margin

## Outline of a platform seen from above (wells ignored), for the checks.
static func outline(d: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cx: float = float(d["x"])
	var cz: float = float(d["z"])
	if str(d.get("shape", "disc")) == "rect":
		var hw: float = float(d["w"]) * 0.5
		var hd: float = float(d["d"]) * 0.5
		pts.append_array(PackedVector2Array([Vector2(cx - hw, cz - hd), Vector2(cx + hw, cz - hd), Vector2(cx + hw, cz + hd), Vector2(cx - hw, cz + hd)]))
		return pts
	var r: float = float(d["r"])
	for i in 48:
		var a: float = TAU * i / 48.0
		pts.append(Vector2(cx + cos(a) * r, cz + sin(a) * r))
	return pts

func spawn_point(id: String) -> Vector3:
	var d: Dictionary = island(id)
	if d.is_empty():
		return Vector3(0.0, 1.0, 0.0)
	var s: Array = d.get("spawn", [d["x"], d["z"]]) as Array
	return Vector3(float(s[0]), float(d["y"]) + 0.1, float(s[1]))

# --- materials ---------------------------------------------------------------

func _make_materials() -> void:
	_concrete = ShaderMaterial.new()
	_concrete.shader = preload("res://shaders/concrete.gdshader")
	_concrete_plain = ShaderMaterial.new()
	_concrete_plain.shader = preload("res://shaders/concrete.gdshader")
	_concrete_plain.set_shader_parameter("detail", 0.0)
	_metal = StandardMaterial3D.new()
	_metal.albedo_color = Color(0.42, 0.43, 0.45)
	_metal.metallic = 0.7
	_metal.roughness = 0.35
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.78, 0.86, 0.88, 0.16)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.roughness = 0.05
	_glass.metallic_specular = 0.9
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_figure = StandardMaterial3D.new()
	_figure.albedo_color = Color(0.5, 0.5, 0.52)
	_figure.roughness = 0.85
	_ink = StandardMaterial3D.new()
	_ink.albedo_color = Color(0.16, 0.16, 0.17)
	_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _beam_material(color: Color, height: float, strength: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/beam.gdshader")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("height", height)
	m.set_shader_parameter("strength", strength)
	return m

# --- platforms ---------------------------------------------------------------

func _build_island(d: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "Island_" + str(d["id"])
	body.position = Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
	body.set_meta("surface", "concrete")
	body.set_meta("island", str(d["id"]))
	add_child(body)
	match str(d.get("shape", "disc")):
		"rect":
			_build_rect_slab(body, d)
		"ring":
			_build_ring_slab(body, d)
		_:
			var r: float = float(d["r"])
			var top := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = r
			cyl.bottom_radius = r
			cyl.height = SLAB_THICKNESS
			cyl.radial_segments = 64
			cyl.rings = 1
			top.mesh = cyl
			top.material_override = _concrete
			top.position.y = -SLAB_THICKNESS * 0.5
			body.add_child(top)
			_add_shape(body, _prism(r, SLAB_THICKNESS, 48), Vector3(0.0, -SLAB_THICKNESS * 0.5, 0.0))
	_build_pilotis(d)
	for seg in d.get("rails", []) as Array:
		var s: Array = seg as Array
		var y: float = float(d["y"])
		_build_rail(Vector3(float(s[0]), y, float(s[1])), Vector3(float(s[2]), y, float(s[3])))
	for arc in d.get("rail_arcs", []) as Array:
		_build_rail_arc(d, float((arc as Array)[0]), float((arc as Array)[1]))

## A rectangle minus its wells, cut into boxes: the x and z edges of the
## wells split it into a grid; each row keeps its runs of solid cells.
func _build_rect_slab(body: StaticBody3D, d: Dictionary) -> void:
	var cx: float = float(d["x"])
	var cz: float = float(d["z"])
	var x0: float = cx - float(d["w"]) * 0.5
	var x1: float = cx + float(d["w"]) * 0.5
	var z0: float = cz - float(d["d"]) * 0.5
	var z1: float = cz + float(d["d"]) * 0.5
	var holes: Array = d.get("holes", []) as Array
	var xs: Array[float] = [x0, x1]
	var zs: Array[float] = [z0, z1]
	for h in holes:
		var hole: Array = h as Array
		xs.append_array([float(hole[0]) - float(hole[2]) * 0.5, float(hole[0]) + float(hole[2]) * 0.5])
		zs.append_array([float(hole[1]) - float(hole[3]) * 0.5, float(hole[1]) + float(hole[3]) * 0.5])
	xs.sort()
	zs.sort()
	for j in zs.size() - 1:
		var za: float = zs[j]
		var zb: float = zs[j + 1]
		if zb - za < 0.01:
			continue
		var run_start: float = NAN
		for i in xs.size():
			var solid: bool = false
			if i < xs.size() - 1 and xs[i + 1] - xs[i] > 0.01:
				solid = contains(d, (xs[i] + xs[i + 1]) * 0.5, (za + zb) * 0.5, 0.0)
			elif i < xs.size() - 1:
				continue
			if solid and is_nan(run_start):
				run_start = xs[i]
			elif not solid and not is_nan(run_start):
				_slab_box(body, Rect2(run_start, za, xs[i] - run_start, zb - za))
				run_start = NAN
		if not is_nan(run_start):
			_slab_box(body, Rect2(run_start, za, x1 - run_start, zb - za))

func _slab_box(body: StaticBody3D, r: Rect2) -> void:
	var size := Vector3(r.size.x, SLAB_THICKNESS, r.size.y)
	var pos := Vector3(r.position.x + r.size.x * 0.5 - body.position.x, -SLAB_THICKNESS * 0.5, r.position.y + r.size.y * 0.5 - body.position.z)
	_add_box(body, size, pos, _concrete)
	var shape := BoxShape3D.new()
	shape.size = size
	_add_shape(body, shape, pos)

## The Oculus: a ring of concrete, a parapet around the well, the well's
## walls fading to black and a spiral ramp winding down into it.
func _build_ring_slab(body: StaticBody3D, d: Dictionary) -> void:
	var r: float = float(d["r"])
	var inner: float = float(d.get("inner", 1.5))
	var segments: int = 48
	body.add_child(_annulus(inner, r, 0.0, -SLAB_THICKNESS, segments, _concrete))
	for i in 24:
		var a0: float = TAU * i / 24.0
		var a1: float = TAU * (i + 1) / 24.0
		var pts := PackedVector3Array()
		for a in [a0, a1]:
			for rad in [inner, r / cos(PI / 24.0)]:
				pts.append(Vector3(cos(a) * rad, 0.0, sin(a) * rad))
				pts.append(Vector3(cos(a) * rad, -SLAB_THICKNESS, sin(a) * rad))
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		_add_shape(body, shape, Vector3.ZERO)
	# parapet: a low concrete ring, solid, so nobody falls into the well
	body.add_child(_annulus(inner, inner + 0.22, 0.95, 0.0, segments, _concrete_plain))
	for i in 24:
		var a: float = TAU * (i + 0.5) / 24.0
		var wall := BoxShape3D.new()
		wall.size = Vector3(0.3, 0.95, TAU * (inner + 0.11) / 24.0 + 0.05)
		var col := CollisionShape3D.new()
		col.shape = wall
		col.transform = Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * (inner + 0.11), 0.475, sin(a) * (inner + 0.11)))
		body.add_child(col)
	# the well: a hollow tower down into the mist, its inside fading to black
	# a few metres down; outside, plain concrete
	var depth: float = float(d["y"]) - SLAB_THICKNESS - MIST_Y
	var well_mat := ShaderMaterial.new()
	well_mat.shader = preload("res://shaders/concrete.gdshader")
	well_mat.set_shader_parameter("fade_top", float(d["y"]) - SLAB_THICKNESS)
	well_mat.set_shader_parameter("fade_len", 7.0)
	body.add_child(_annulus(inner, inner, -SLAB_THICKNESS, -SLAB_THICKNESS - depth, segments, well_mat))
	body.add_child(_annulus(inner + 0.35, inner + 0.35, -SLAB_THICKNESS, -SLAB_THICKNESS - depth, segments, _concrete_plain))
	body.add_child(_spiral_ramp(inner - 0.02, well_mat))

## Flat ring between two radii, from y_top down to y_bottom, all faces.
func _annulus(r_in: float, r_out: float, y_top: float, y_bottom: float, segments: int, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0: float = TAU * i / segments
		var a1: float = TAU * (i + 1) / segments
		var c0 := Vector3(cos(a0), 0.0, sin(a0))
		var c1 := Vector3(cos(a1), 0.0, sin(a1))
		var top := Vector3(0.0, y_top, 0.0)
		var low := Vector3(0.0, y_bottom, 0.0)
		_quad(st, c0 * r_in + top, c1 * r_in + top, c1 * r_out + top, c0 * r_out + top)
		_quad(st, c0 * r_out + low, c1 * r_out + low, c1 * r_in + low, c0 * r_in + low)
		_quad(st, c0 * r_out + top, c1 * r_out + top, c1 * r_out + low, c0 * r_out + low)
		_quad(st, c0 * r_in + low, c1 * r_in + low, c1 * r_in + top, c0 * r_in + top)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	return m

## Quad a, b, c, d, given counter-clockwise as seen from the side it faces;
## written clockwise, the winding of Godot's front faces.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)
	st.add_vertex(a)
	st.add_vertex(d)
	st.add_vertex(c)

## Ramp winding down the inside of the well, three turns, 1.1 m wide.
func _spiral_ramp(r: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = 120
	var drop: float = 18.0
	var width: float = 1.1
	for i in steps:
		var t0: float = float(i) / steps
		var t1: float = float(i + 1) / steps
		var a0: float = t0 * TAU * 3.0
		var a1: float = t1 * TAU * 3.0
		var y0: float = -SLAB_THICKNESS - 0.6 - t0 * drop
		var y1: float = -SLAB_THICKNESS - 0.6 - t1 * drop
		var o0 := Vector3(cos(a0) * r, y0, sin(a0) * r)
		var o1 := Vector3(cos(a1) * r, y1, sin(a1) * r)
		var i0 := Vector3(cos(a0) * (r - width), y0, sin(a0) * (r - width))
		var i1 := Vector3(cos(a1) * (r - width), y1, sin(a1) * (r - width))
		var down := Vector3(0.0, 0.25, 0.0)
		_quad(st, i0, i1, o1, o0)
		_quad(st, o0 - down, o1 - down, i1 - down, i0 - down)
		_quad(st, i0 - down, i1 - down, i1, i0)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	return m

## Slender columns under some platforms, down into the mist ("pilotis":
## offsets from the centre). The others float.
func _build_pilotis(d: Dictionary) -> void:
	var y: float = float(d["y"]) - SLAB_THICKNESS
	var cx: float = float(d["x"])
	var cz: float = float(d["z"])
	if not d.has("pilotis"):
		return
	var spots: Array[Vector2] = []
	var radius: float = float(d.get("pilotis_radius", 0.3))
	for p in d["pilotis"] as Array:
		spots.append(Vector2(cx + float((p as Array)[0]), cz + float((p as Array)[1])))
	for s in spots:
		if not contains(d, s.x, s.y, -radius):
			continue
		var h: float = y - MIST_Y
		_add_cylinder(self, radius, radius, h, Vector3(s.x, y - h * 0.5, s.y), _concrete_plain, 12)

## Frameless glass balustrade between two points at deck height: a glass
## panel, a slim handrail, a base shoe. Its collision stops the walk but
## is never climbed (meta "no_mantle").
func _build_rail(a: Vector3, b: Vector3) -> void:
	var length: float = Vector2(b.x - a.x, b.z - a.z).length()
	if length < 0.2:
		return
	var body := StaticBody3D.new()
	body.position = (a + b) * 0.5
	body.rotation.y = atan2(-(b.z - a.z), b.x - a.x)
	body.set_meta("surface", "stone")
	body.set_meta("no_mantle", true)
	add_child(body)
	_add_box(body, Vector3(length, RAIL_HEIGHT - 0.12, 0.02), Vector3(0.0, 0.06 + (RAIL_HEIGHT - 0.12) * 0.5, 0.0), _glass)
	_add_box(body, Vector3(length, 0.045, 0.06), Vector3(0.0, RAIL_HEIGHT, 0.0), _metal)
	_add_box(body, Vector3(length, 0.08, 0.07), Vector3(0.0, 0.04, 0.0), _metal)
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, RAIL_HEIGHT, 0.1)
	_add_shape(body, shape, Vector3(0.0, RAIL_HEIGHT * 0.5, 0.0))

## Balustrade along the rim of a disc, between two angles in degrees
## (0 = east, 90 = south).
func _build_rail_arc(d: Dictionary, from_deg: float, to_deg: float) -> void:
	var r: float = float(d["r"]) - 0.12
	var centre := Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
	var steps: int = maxi(ceili(absf(to_deg - from_deg) / 12.0), 1)
	for i in steps:
		var a0: float = deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		var a1: float = deg_to_rad(lerpf(from_deg, to_deg, float(i + 1) / steps))
		_build_rail(centre + Vector3(cos(a0), 0.0, sin(a0)) * r, centre + Vector3(cos(a1), 0.0, sin(a1)) * r)

# --- kinetic stones' supports --------------------------------------------------

func _build_caster_support(c: ShadowSystem.Caster, def: Dictionary) -> void:
	match c.motion:
		"spin":
			var top: float = c.foot.y + c.size.y + 0.5
			var h: float = top - c.plane
			var mast := StaticBody3D.new()
			mast.position = Vector3(c.pivot.x, c.plane, c.pivot.z)
			mast.set_meta("surface", "stone")
			mast.set_meta("no_mantle", true)
			add_child(mast)
			_add_cylinder(mast, 0.3, 0.38, h, Vector3(0.0, h * 0.5, 0.0), _concrete_plain, 16)
			_add_shape(mast, _prism(0.36, h, 12), Vector3(0.0, h * 0.5, 0.0))
		"slide":
			var rail_y: float = c.foot.y + c.size.y + 1.6
			var a := Vector3(c.pivot.x, rail_y, c.pivot.z)
			var b := Vector3(c.slide_to.x, rail_y, c.slide_to.z)
			var along: Vector3 = (b - a).normalized()
			var length: float = a.distance_to(b) + 2.0
			var rail := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(length, 0.28, 0.28)
			rail.mesh = box
			rail.material_override = _concrete_plain
			rail.position = (a + b) * 0.5
			rail.rotation.y = atan2(-along.z, along.x)
			add_child(rail)
			var rod := MeshInstance3D.new()
			var rod_box := BoxMesh.new()
			rod_box.size = Vector3(0.14, 1.6, 0.14)
			rod.mesh = rod_box
			rod.material_override = _concrete_plain
			rod.position = Vector3(0.0, c.size.y * 0.5 + 0.8, 0.0)
			c.stone_body.add_child(rod)

# --- blocks and props ---------------------------------------------------------

func _build_block(d: Dictionary) -> void:
	var x: float = float(d["x"])
	var z: float = float(d["z"])
	var size := Vector3(float(d["w"]), float(d["h"]), float(d["d"]))
	var body := StaticBody3D.new()
	body.position = Vector3(x, float(d.get("y", ground_y(x, z))) + size.y * 0.5, z)
	body.set_meta("surface", "concrete")
	add_child(body)
	_add_box(body, size, Vector3.ZERO, _concrete)
	var shape := BoxShape3D.new()
	shape.size = size
	_add_shape(body, shape, Vector3.ZERO)

## Height of the platform under (x, z), wells ignored, 0 over the void.
func ground_y(x: float, z: float) -> float:
	for id in islands:
		var d: Dictionary = islands[id]
		if contains(d, x, z, 0.0) or (str(d.get("shape", "")) == "rect" and absf(x - float(d["x"])) <= float(d["w"]) * 0.5 and absf(z - float(d["z"])) <= float(d["d"]) * 0.5):
			return float(d["y"])
	return 0.0

func _build_prop(d: Dictionary) -> void:
	var x: float = float(d["x"])
	var z: float = float(d["z"])
	var body := StaticBody3D.new()
	body.position = Vector3(x, ground_y(x, z), z)
	body.rotation.y = deg_to_rad(float(d.get("yaw", 0.0)))
	body.set_meta("surface", "concrete")
	add_child(body)
	match str(d["type"]):
		"wall":
			var size := Vector3(float(d.get("w", 4.0)), float(d.get("h", 2.6)), 0.3)
			_add_box(body, size, Vector3(0.0, size.y * 0.5, 0.0), _concrete)
			var shape := BoxShape3D.new()
			shape.size = size
			_add_shape(body, shape, Vector3(0.0, size.y * 0.5, 0.0))
		"bench":
			var size := Vector3(float(d.get("w", 2.4)), 0.45, 0.55)
			_add_box(body, size, Vector3(0.0, size.y * 0.5, 0.0), _concrete_plain)
			var shape := BoxShape3D.new()
			shape.size = size
			_add_shape(body, shape, Vector3(0.0, size.y * 0.5, 0.0))
		"frame":
			var w: float = float(d.get("w", 2.4))
			var h: float = float(d.get("h", 3.2))
			for side in [-1.0, 1.0]:
				var post := Vector3(0.3, h, 0.3)
				_add_box(body, post, Vector3(side * w * 0.5, h * 0.5, 0.0), _concrete_plain)
				var shape := BoxShape3D.new()
				shape.size = post
				_add_shape(body, shape, Vector3(side * w * 0.5, h * 0.5, 0.0))
			_add_box(body, Vector3(w + 0.3, 0.3, 0.3), Vector3(0.0, h + 0.15, 0.0), _concrete_plain)
			body.set_meta("no_mantle", true)
		"column":
			var h: float = float(d.get("h", 4.0))
			var r: float = float(d.get("r", 0.22))
			_add_cylinder(body, r, r, h, Vector3(0.0, h * 0.5, 0.0), _concrete_plain, 16)
			_add_shape(body, _prism(r, h, 12), Vector3(0.0, h * 0.5, 0.0))
			body.set_meta("no_mantle", true)
		"figure":
			_build_figure(body)

## A grey figure for scale, like the people in an architect's model.
func _build_figure(body: StaticBody3D) -> void:
	body.set_meta("no_mantle", true)
	for side in [-0.09, 0.09]:
		_add_cylinder(body, 0.065, 0.055, 0.82, Vector3(side, 0.41, 0.0), _figure, 8)
	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.17
	capsule.height = 0.72
	capsule.radial_segments = 12
	capsule.rings = 4
	torso.mesh = capsule
	torso.material_override = _figure
	torso.position.y = 1.16
	torso.scale = Vector3(1.0, 1.0, 0.7)
	body.add_child(torso)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.24
	sphere.radial_segments = 12
	sphere.rings = 6
	head.mesh = sphere
	head.material_override = _figure
	head.position.y = 1.64
	body.add_child(head)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 1.75
	_add_shape(body, shape, Vector3(0.0, 0.875, 0.0))

func _add_cylinder(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, mat: Material, segments: int = 16) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = top
	cyl.bottom_radius = bottom
	cyl.height = h
	cyl.radial_segments = segments
	cyl.rings = 1
	m.mesh = cyl
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m

## Upright prism standing in for a cylinder, its flat sides touching the
## given radius: convex shapes are reliable in Godot Physics, cylinders are
## not (a body can sink through them, as seen in the web build).
func _prism(radius: float, height: float, sides: int) -> ConvexPolygonShape3D:
	var pts := PackedVector3Array()
	var outer: float = radius / cos(PI / sides)
	for i in sides:
		var a: float = TAU * i / sides
		var rim := Vector3(cos(a) * outer, 0.0, sin(a) * outer)
		pts.append(rim + Vector3(0.0, height * 0.5, 0.0))
		pts.append(rim - Vector3(0.0, height * 0.5, 0.0))
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	return shape

func _add_shape(body: StaticBody3D, shape: Shape3D, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	body.add_child(col)

# --- shards, seals, sockets ---------------------------------------------------

func _build_shards() -> void:
	var gem := SphereMesh.new()
	gem.radius = 0.2
	gem.height = 0.52
	gem.radial_segments = 4
	gem.rings = 2
	var gem_mat := _glow_material(ACCENT, 1.4)
	var list: Array = data.get("shards", []) as Array
	for i in list.size():
		var p: Array = list[i] as Array
		var root := Node3D.new()
		root.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		var m := MeshInstance3D.new()
		m.mesh = gem
		m.material_override = gem_mat
		root.add_child(m)
		add_child(root)
		_shards.append({node = root, home = root.position, pos = root.position, taken = false, offset = float(i) * 0.7})

func set_shards_taken(indices: Array[int]) -> void:
	for i in _shards.size():
		var taken: bool = indices.has(i)
		_shards[i]["taken"] = taken
		(_shards[i]["node"] as Node3D).visible = not taken
		_shards[i]["pos"] = _shards[i]["home"]

func shard_position(index: int) -> Vector3:
	return _shards[index]["home"] as Vector3

func shard_taken(index: int) -> bool:
	return bool(_shards[index]["taken"])

func _build_seals() -> void:
	for d in data.get("seals", []) as Array:
		var def: Dictionary = d as Dictionary
		var id: String = str(def["id"])
		var ground: float = float(island(str(def["island"])).get("y", 0.0))
		var pos := Vector3(float(def["x"]), ground, float(def["z"]))
		var plinth := StaticBody3D.new()
		plinth.position = pos
		plinth.set_meta("surface", "concrete")
		add_child(plinth)
		_add_box(plinth, Vector3(0.9, 0.9, 0.9), Vector3(0.0, 0.45, 0.0), _concrete_plain)
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.9, 0.9, 0.9)
		_add_shape(plinth, shape, Vector3(0.0, 0.45, 0.0))
		var seal := seal_mesh(id, 2.0)
		seal.position = pos + Vector3(0.0, 1.8, 0.0)
		add_child(seal)
		var sky_beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.07
		cyl.bottom_radius = 0.07
		cyl.height = 140.0
		cyl.radial_segments = 8
		sky_beam.mesh = cyl
		sky_beam.material_override = _beam_material(ACCENT, 140.0, 1.6)
		sky_beam.position = pos + Vector3(0.0, 72.5, 0.0)
		add_child(sky_beam)
		var bp: Array = def.get("beam", [def["x"], def["z"]]) as Array
		var beam_pos := Vector3(float(bp[0]), ground, float(bp[1]))
		var beam := MeshInstance3D.new()
		var bcyl := CylinderMesh.new()
		bcyl.top_radius = _beam_radius
		bcyl.bottom_radius = _beam_radius
		bcyl.height = 30.0
		bcyl.radial_segments = 32
		beam.mesh = bcyl
		beam.material_override = _beam_material(ACCENT, 30.0, 0.55)
		beam.position = beam_pos + Vector3(0.0, 15.0, 0.0)
		beam.visible = false
		add_child(beam)
		_seals.append({id = id, node = seal, sky = sky_beam, beam = beam, pos = pos + Vector3(0.0, 1.8, 0.0), beam_pos = beam_pos, taken = false})

## The three seals are told apart by their shape: a circle for dawn, a
## square for noon, a triangle for dusk.
func seal_mesh(id: String, energy: float) -> Node3D:
	var root := Node3D.new()
	var mat := _glow_material(ACCENT, energy)
	match id:
		"dawn":
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.42
			torus.outer_radius = 0.52
			torus.rings = 32
			torus.ring_segments = 8
			ring.mesh = torus
			ring.material_override = mat
			ring.rotation.x = PI * 0.5
			root.add_child(ring)
		"noon":
			for k in 4:
				var a: float = PI * 0.5 * k
				var bar := _add_box(root, Vector3(0.9, 0.1, 0.1), Vector3(sin(a) * 0.4, cos(a) * 0.4, 0.0), mat)
				bar.rotation.z = -a
		_:
			for k in 3:
				var a: float = TAU * k / 3.0
				var mid := Vector2(sin(a + PI), cos(a + PI)) * 0.27
				var bar := _add_box(root, Vector3(0.94, 0.1, 0.1), Vector3(mid.x, mid.y + 0.05, 0.0), mat)
				bar.rotation.z = -a
	return root

func set_seals_state(taken: Array[String]) -> void:
	for s in _seals:
		var t: bool = taken.has(str(s["id"]))
		s["taken"] = t
		(s["node"] as Node3D).visible = not t
		(s["sky"] as Node3D).visible = not t
		(s["beam"] as Node3D).visible = t

func seal_position(id: String) -> Vector3:
	for s in _seals:
		if str(s["id"]) == id:
			return s["pos"] as Vector3
	return Vector3.ZERO

func beam_position(id: String) -> Vector3:
	for s in _seals:
		if str(s["id"]) == id:
			return s["beam_pos"] as Vector3
	return Vector3.ZERO

func _build_sockets() -> void:
	var hub: Dictionary = island(str(data.get("hub_island", "cadran")))
	var ground: float = float(hub.get("y", 0.0))
	var ids: Array[String] = ["dawn", "noon", "dusk"]
	var list: Array = data.get("sockets", []) as Array
	for i in list.size():
		var p: Array = list[i] as Array
		var body := StaticBody3D.new()
		body.position = Vector3(float(p[0]), ground, float(p[1]))
		body.set_meta("surface", "concrete")
		add_child(body)
		_add_box(body, Vector3(0.7, 1.0, 0.7), Vector3(0.0, 0.5, 0.0), _concrete_plain)
		_add_box(body, Vector3(0.4, 0.02, 0.4), Vector3(0.0, 1.01, 0.0), _ink)
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.7, 1.0, 0.7)
		_add_shape(body, shape, Vector3(0.0, 0.5, 0.0))
		var seal := seal_mesh(ids[i % ids.size()], 1.6)
		seal.position = body.position + Vector3(0.0, 1.8, 0.0)
		seal.scale = Vector3.ONE * 0.8
		seal.visible = false
		add_child(seal)
		_sockets.append({node = seal, seal = ids[i % ids.size()], base = body.position})

func set_sockets_state(placed: Array[String]) -> void:
	for s in _sockets:
		(s["node"] as Node3D).visible = placed.has(str(s["seal"]))

func socket_position(seal_id: String) -> Vector3:
	for s in _sockets:
		if str(s["seal"]) == seal_id:
			return (s["base"] as Vector3) + Vector3(0.0, 1.8, 0.0)
	return Vector3.ZERO

# --- sundial and scenery --------------------------------------------------------

func observatory_position() -> Vector3:
	var o: Dictionary = data.get("observatory", {}) as Dictionary
	return Vector3(float(o.get("x", 0.0)), ground_y(float(o.get("x", 0.0)), float(o.get("z", 0.0))), float(o.get("z", 0.0)))

## Hour lines around the Dial's needle: each graphite line points where the
## needle's shadow falls at that hour, with the hour in Roman numerals.
func _build_sundial() -> void:
	var needle: ShadowSystem.Caster = shadows.find("cad_aiguille")
	if needle == null:
		return
	var max_elevation: float = ConfigManager.get_float("sun_max_elevation_deg", 65.0)
	var root := Node3D.new()
	root.position = Vector3(needle.foot.x, needle.plane + 0.02, needle.foot.z)
	add_child(root)
	_add_cylinder(root, 2.9, 2.9, 0.04, Vector3.ZERO, _concrete_plain, 48)
	for i in ROMAN.size():
		var h: float = 7.0 + i
		var dir: Vector3 = Sun.direction_for(h, max_elevation)
		var flat := Vector2(-dir.x, -dir.z).normalized()
		var angle: float = atan2(flat.x, flat.y)
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.025, 0.01, 1.3)
		line.mesh = box
		line.material_override = _ink
		line.position = Vector3(flat.x * 1.25, 0.025, flat.y * 1.25)
		line.rotation.y = angle
		root.add_child(line)
		var label := Label3D.new()
		label.text = ROMAN[i]
		label.font_size = 40
		label.pixel_size = 0.006
		label.modulate = Color(0.16, 0.16, 0.17)
		label.outline_size = 0
		label.position = Vector3(flat.x * 2.3, 0.04, flat.y * 2.3)
		label.rotation = Vector3(-PI * 0.5, angle + PI, 0.0)
		root.add_child(label)

## Monumental white volumes far away, rising from the mist: towers and
## floating slabs, paled by the fog.
func _build_far_architecture() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in 20:
		var a: float = TAU * (float(i) + rng.randf_range(0.0, 0.7)) / 20.0
		var dist: float = rng.randf_range(220.0, 420.0)
		var base := Vector3(cos(a) * dist, 0.0, sin(a) * dist)
		var root := Node3D.new()
		root.position = base
		root.rotation.y = rng.randf() * TAU
		add_child(root)
		match i % 2:
			0:
				var w: float = rng.randf_range(6.0, 16.0)
				var h: float = rng.randf_range(80.0, 180.0)
				var top: float = rng.randf_range(-10.0, 70.0)
				_add_box(root, Vector3(w, h, rng.randf_range(6.0, 16.0)), Vector3(0.0, top - h * 0.5, 0.0), _concrete_plain)
			_:
				var w: float = rng.randf_range(24.0, 60.0)
				var d: float = rng.randf_range(10.0, 28.0)
				var y: float = rng.randf_range(-25.0, 35.0)
				_add_box(root, Vector3(w, rng.randf_range(1.5, 3.5), d), Vector3(0.0, y, 0.0), _concrete_plain)

func _build_mist() -> void:
	var mist := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(9000.0, 9000.0)
	mist.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/mist.gdshader")
	mist.material_override = mat
	mist.position = Vector3(0.0, MIST_Y, 0.0)
	mist.name = "Mist"
	add_child(mist)

func mist_material() -> ShaderMaterial:
	return (get_node("Mist") as MeshInstance3D).material_override as ShaderMaterial

# --- per frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	for s in _shards:
		if bool(s["taken"]):
			continue
		var node: Node3D = s["node"]
		node.rotation.y = _time * 1.6 + float(s["offset"])
		node.position = (s["pos"] as Vector3) + Vector3(0.0, sin(_time * 2.0 + float(s["offset"])) * 0.1, 0.0)
	for s in _seals:
		(s["node"] as Node3D).rotation.y = _time * 0.8
		(s["node"] as Node3D).position.y = (s["pos"] as Vector3).y + sin(_time * 1.3) * 0.1
	for s in _sockets:
		(s["node"] as Node3D).rotation.y = -_time * 0.5

## Shard magnet and pickups, seals, beams and the Oculus.
func update_pickups(player_pos: Vector3, delta: float) -> void:
	var chest: Vector3 = player_pos + Vector3(0.0, 1.0, 0.0)
	for i in _shards.size():
		var s: Dictionary = _shards[i]
		if bool(s["taken"]):
			continue
		var pos: Vector3 = s["pos"]
		var dist: float = pos.distance_to(chest)
		if dist < _pick:
			s["taken"] = true
			(s["node"] as Node3D).visible = false
			shard_collected.emit(i, pos)
		elif dist < _magnet:
			s["pos"] = pos.move_toward(chest, delta * (5.0 + (_magnet - dist) * 7.0))
		else:
			s["pos"] = pos.move_toward(s["home"], delta * 3.0)
	for s in _seals:
		if not bool(s["taken"]):
			if (s["pos"] as Vector3).distance_to(chest) < _seal_pick:
				seal_taken.emit(str(s["id"]), s["pos"])
		else:
			var bp: Vector3 = s["beam_pos"]
			if Vector2(player_pos.x - bp.x, player_pos.z - bp.z).length() < _beam_radius and absf(player_pos.y - bp.y) < 2.0:
				beam_entered.emit(str(s["id"]))
	var o: Dictionary = data.get("observatory", {}) as Dictionary
	if not o.is_empty():
		if Vector2(player_pos.x - float(o["x"]), player_pos.z - float(o["z"])).length() < float(o.get("r", 1.8)) and player_pos.y > -1.0:
			observatory_reached.emit()

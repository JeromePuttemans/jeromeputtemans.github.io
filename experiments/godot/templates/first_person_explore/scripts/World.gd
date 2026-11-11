# =============================================================================
# World.gd — Builds the archipelago from data/world.json
# =============================================================================
# ISLANDS: a flat grassy disc (a 48-sided convex prism for collision: Godot
#   Physics lets bodies sink through cylinder shapes; top at the island height)
#   over a jagged rock cone generated with SurfaceTool, tufts of grass in a
#   MultiMesh. Every island body carries meta "surface" and "island".
# BLACK STONES: handed to ShadowSystem (the great gnomon starts low and
#   rises once the three seals are set).
# OTHER PIECES: light marble props (columns, low walls, braziers) and steps,
#   sun shards, the three seals with their light columns, the return beams,
#   the sockets around the gnomon, the observatory's armillary sphere, a
#   small sundial on the Dial whose hour marks show where the needle's
#   shadow points, distant decorative islands and the sea of clouds below.
# PICKUPS: update_pickups() runs every physics frame with the player's
#   position: shards drift towards the player inside the magnet radius and
#   are taken inside the pick radius; seals, beams and the observatory are
#   simple distance triggers. Results go out as signals.
# =============================================================================

class_name World
extends Node3D

signal shard_collected(index: int, position: Vector3)
signal seal_taken(id: String, position: Vector3)
signal beam_entered(id: String)
signal observatory_reached()

const ROMAN: Array[String] = ["VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII"]
const SEAL_COLORS: Dictionary = {dawn = Color(1.0, 0.62, 0.55), noon = Color(1.0, 0.95, 0.7), dusk = Color(1.0, 0.5, 0.25)}

var data: Dictionary = {}
var islands: Dictionary = {}          # id -> definition
var shadows: ShadowSystem = null
var lowest_y: float = 0.0

var _grass_material: ShaderMaterial = null
var _rock_material: ShaderMaterial = null
var _marble: StandardMaterial3D = null
var _gold: StandardMaterial3D = null
var _shards: Array[Dictionary] = []   # {node, home, pos, taken, offset}
var _seals: Array[Dictionary] = []    # {id, node, beam, island, pos, taken, beam_pos}
var _sockets: Array[Dictionary] = []  # {node, seal}
var _armillary: Node3D = null
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
		shadows.add_caster(def, plane)
	for d in data.get("blocks", []) as Array:
		_build_block(d as Dictionary)
	for d in data.get("props", []) as Array:
		_build_prop(d as Dictionary)
	shadows.setup_clouds(data.get("clouds", []) as Array, ConfigManager.get_float("cloud_radius", 5.5), ConfigManager.get_float("cloud_speed", 5.0))
	_build_shards()
	_build_seals()
	_build_sockets()
	_build_observatory()
	_build_sundial()
	_build_far_islands()
	_build_sea()

func shard_total() -> int:
	return _shards.size()

func island(id: String) -> Dictionary:
	return islands.get(id, {}) as Dictionary

## Island whose flat top holds these feet, or "" (a shadow lying on an
## island does not hide it: arrivals are read from the geometry).
func island_at(feet: Vector3) -> String:
	for id in islands:
		var d: Dictionary = islands[id]
		if absf(feet.y - float(d["y"])) < 0.25 and Vector2(feet.x - float(d["x"]), feet.z - float(d["z"])).length() <= float(d["r"]) + 0.05:
			return str(id)
	return ""

func spawn_point(id: String) -> Vector3:
	var d: Dictionary = island(id)
	if d.is_empty():
		return Vector3(0.0, 1.0, 0.0)
	var s: Array = d.get("spawn", [d["x"], d["z"]]) as Array
	return Vector3(float(s[0]), float(d["y"]) + 0.1, float(s[1]))

# --- materials ---------------------------------------------------------------

func _make_materials() -> void:
	_grass_material = ShaderMaterial.new()
	_grass_material.shader = preload("res://shaders/grass.gdshader")
	_rock_material = ShaderMaterial.new()
	_rock_material.shader = preload("res://shaders/rock.gdshader")
	_marble = StandardMaterial3D.new()
	_marble.albedo_color = Color(0.9, 0.86, 0.78)
	_marble.roughness = 0.6
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = Color(1.0, 0.78, 0.35)
	_gold.metallic = 0.6
	_gold.roughness = 0.3
	_gold.emission_enabled = true
	_gold.emission = Color(1.0, 0.7, 0.3)
	_gold.emission_energy_multiplier = 0.6

func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _halo_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g * 0.85, color.b * 0.6, 0.12)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	return m

func _beam_material(color: Color, height: float, strength: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/beam.gdshader")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("height", height)
	m.set_shader_parameter("strength", strength)
	return m

# --- islands -----------------------------------------------------------------

func _build_island(d: Dictionary) -> void:
	var r: float = float(d["r"])
	var body := StaticBody3D.new()
	body.name = "Island_" + str(d["id"])
	body.position = Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
	body.set_meta("surface", "grass")
	body.set_meta("island", str(d["id"]))
	add_child(body)
	var top := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r * 0.97
	cyl.height = 0.6
	cyl.radial_segments = 48
	cyl.rings = 1
	top.mesh = cyl
	top.material_override = _grass_material
	top.position.y = -0.3
	body.add_child(top)
	var shape := _prism(r, 0.6, 48)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = -0.3
	body.add_child(col)
	var under := MeshInstance3D.new()
	under.mesh = _rock_mesh(r * 0.97, float(d.get("depth", 8.0)), hash(str(d["id"])))
	under.material_override = _rock_material
	under.position.y = -0.55
	body.add_child(under)
	_add_grass(body, r, hash(str(d["id"])) + 7)

## Jagged cone hanging under an island: rings shrinking from the rim to a
## tip, each vertex pushed in or out by a few sine waves.
func _rock_mesh(r: float, depth: float, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var segments: int = 28
	var rings: int = 7
	var phase_a: float = rng.randf() * TAU
	var phase_b: float = rng.randf() * TAU
	var grid: Array[PackedVector3Array] = []
	for k in rings + 1:
		var t: float = float(k) / float(rings)
		var ring := PackedVector3Array()
		var radius: float = r * pow(1.0 - t, 0.75) * (1.0 if k == 0 else rng.randf_range(0.85, 1.05))
		var y: float = -depth * pow(t, 1.15)
		for s in segments:
			var a: float = TAU * float(s) / float(segments)
			var j: float = 1.0
			if k > 0 and k < rings:
				j = 0.85 + 0.12 * sin(a * 3.0 + phase_a + k) + 0.08 * sin(a * 7.0 + phase_b - k * 2.0) + rng.randf_range(-0.05, 0.05)
			ring.append(Vector3(cos(a) * radius * j, y + (rng.randf_range(-0.3, 0.3) if k > 0 else 0.0), sin(a) * radius * j))
		grid.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in rings:
		for s in segments:
			var a0: Vector3 = grid[k][s]
			var a1: Vector3 = grid[k][(s + 1) % segments]
			var b0: Vector3 = grid[k + 1][s]
			var b1: Vector3 = grid[k + 1][(s + 1) % segments]
			st.add_vertex(a0)
			st.add_vertex(a1)
			st.add_vertex(b1)
			st.add_vertex(a0)
			st.add_vertex(b1)
			st.add_vertex(b0)
	st.generate_normals()
	return st.commit()

func _add_grass(parent: Node3D, r: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = int(r * r * 2.2)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _tuft_mesh()
	mm.instance_count = count
	for i in count:
		var a: float = rng.randf() * TAU
		var dist: float = sqrt(rng.randf()) * (r - 0.4)
		var s: float = rng.randf_range(0.6, 1.3)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.7, 1.4), s)), Vector3(cos(a) * dist, 0.0, sin(a) * dist))
		mm.set_instance_transform(i, xf)
		var flower: bool = rng.randf() < 0.07
		mm.set_instance_color(i, Color(1.0, 0.85, 0.4) if flower else Color.from_hsv(rng.randf_range(0.17, 0.25), rng.randf_range(0.45, 0.7), rng.randf_range(0.45, 0.7)))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)

## Three thin blades leaning outwards.
func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a: float = TAU * k / 3.0
		var side := Vector3(cos(a + PI * 0.5), 0.0, sin(a + PI * 0.5)) * 0.03
		var lean := Vector3(cos(a), 0.0, sin(a)) * 0.09
		st.set_normal(Vector3.UP)
		st.add_vertex(-side)
		st.add_vertex(side)
		st.add_vertex(lean + Vector3(0.0, 0.22, 0.0))
	return st.commit()

# --- props -------------------------------------------------------------------

func _build_block(d: Dictionary) -> void:
	var size := Vector3(float(d["w"]), float(d["h"]), float(d["d"]))
	var body := StaticBody3D.new()
	body.position = Vector3(float(d["x"]), float(d.get("y", 0.0)) + size.y * 0.5, float(d["z"]))
	body.set_meta("surface", "stone")
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _marble
	body.add_child(mesh)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)

func _ground_y(x: float, z: float) -> float:
	for id in islands:
		var d: Dictionary = islands[id]
		if Vector2(x - float(d["x"]), z - float(d["z"])).length() <= float(d["r"]):
			return float(d["y"])
	return 0.0

func _build_prop(d: Dictionary) -> void:
	var x: float = float(d["x"])
	var z: float = float(d["z"])
	var base := Vector3(x, _ground_y(x, z), z)
	var body := StaticBody3D.new()
	body.position = base
	body.rotation.y = deg_to_rad(float(d.get("yaw", 0.0)))
	body.set_meta("surface", "stone")
	add_child(body)
	match str(d["type"]):
		"column":
			var h: float = float(d.get("h", 2.0))
			_add_cylinder(body, 0.42, 0.42, h, Vector3(0.0, h * 0.5, 0.0), _marble)
			_add_cylinder(body, 0.62, 0.62, 0.3, Vector3(0.0, 0.15, 0.0), _marble)
			if h > 2.0:
				_add_box(body, Vector3(1.2, 0.25, 1.2), Vector3(0.0, h + 0.12, 0.0), _marble)
			var shape := _prism(0.5, h, 16)
			_add_shape(body, shape, Vector3(0.0, h * 0.5, 0.0))
		"wall":
			_add_box(body, Vector3(2.6, 0.55, 0.45), Vector3(0.0, 0.275, 0.0), _marble)
			_add_box(body, Vector3(1.1, 0.35, 0.45), Vector3(-0.6, 0.72, 0.0), _marble)
			var shape := BoxShape3D.new()
			shape.size = Vector3(2.6, 0.9, 0.45)
			_add_shape(body, shape, Vector3(0.0, 0.45, 0.0))
		"brazier":
			_add_cylinder(body, 0.18, 0.28, 0.9, Vector3(0.0, 0.45, 0.0), _marble)
			_add_cylinder(body, 0.45, 0.25, 0.25, Vector3(0.0, 1.0, 0.0), _gold)
			var flame := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.22
			sphere.height = 0.5
			flame.mesh = sphere
			flame.material_override = _glow_material(Color(1.0, 0.6, 0.25), 3.0)
			flame.position = Vector3(0.0, 1.25, 0.0)
			flame.set_meta("flame", true)
			body.add_child(flame)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.65, 0.35)
			light.light_energy = 1.4
			light.omni_range = 7.0
			light.position = Vector3(0.0, 1.5, 0.0)
			body.add_child(light)
			var shape := _prism(0.4, 1.1, 16)
			_add_shape(body, shape, Vector3(0.0, 0.55, 0.0))

func _add_cylinder(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = top
	cyl.bottom_radius = bottom
	cyl.height = h
	cyl.radial_segments = 16
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
	gem.radius = 0.22
	gem.height = 0.6
	gem.radial_segments = 4
	gem.rings = 2
	var halo := SphereMesh.new()
	halo.radius = 0.36
	halo.height = 0.72
	halo.radial_segments = 12
	halo.rings = 6
	var gem_mat := _glow_material(Color(1.0, 0.82, 0.35), 2.2)
	var halo_mat := _halo_material(Color(1.0, 0.8, 0.4))
	var list: Array = data.get("shards", []) as Array
	for i in list.size():
		var p: Array = list[i] as Array
		var root := Node3D.new()
		root.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		var m := MeshInstance3D.new()
		m.mesh = gem
		m.material_override = gem_mat
		root.add_child(m)
		var h := MeshInstance3D.new()
		h.mesh = halo
		h.material_override = halo_mat
		root.add_child(h)
		add_child(root)
		_shards.append({node = root, home = root.position, pos = root.position, taken = false, offset = float(i) * 0.7})

func set_shards_taken(indices: Array[int]) -> void:
	for i in _shards.size():
		var taken: bool = indices.has(i)
		_shards[i]["taken"] = taken
		(_shards[i]["node"] as Node3D).visible = not taken
		_shards[i]["pos"] = _shards[i]["home"]

func _build_seals() -> void:
	for d in data.get("seals", []) as Array:
		var def: Dictionary = d as Dictionary
		var id: String = str(def["id"])
		var ground: float = float(island(str(def["island"])).get("y", 0.0))
		var pos := Vector3(float(def["x"]), ground, float(def["z"]))
		var pedestal := StaticBody3D.new()
		pedestal.position = pos
		pedestal.set_meta("surface", "stone")
		add_child(pedestal)
		_add_cylinder(pedestal, 0.5, 0.7, 0.8, Vector3(0.0, 0.4, 0.0), _marble)
		var shape := _prism(0.65, 0.8, 16)
		_add_shape(pedestal, shape, Vector3(0.0, 0.4, 0.0))
		var seal := _seal_mesh(id)
		seal.position = pos + Vector3(0.0, 1.7, 0.0)
		add_child(seal)
		var sky_beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.18
		cyl.bottom_radius = 0.18
		cyl.height = 120.0
		cyl.radial_segments = 8
		sky_beam.mesh = cyl
		sky_beam.material_override = _beam_material(SEAL_COLORS[id], 120.0, 0.28)
		sky_beam.position = pos + Vector3(0.0, 61.0, 0.0)
		add_child(sky_beam)
		var bp: Array = def.get("beam", [def["x"], def["z"]]) as Array
		var beam_pos := Vector3(float(bp[0]), ground, float(bp[1]))
		var beam := MeshInstance3D.new()
		var bcyl := CylinderMesh.new()
		bcyl.top_radius = _beam_radius
		bcyl.bottom_radius = _beam_radius
		bcyl.height = 30.0
		bcyl.radial_segments = 20
		beam.mesh = bcyl
		beam.material_override = _beam_material(Color(0.6, 0.85, 1.0), 30.0, 0.7)
		beam.position = beam_pos + Vector3(0.0, 15.0, 0.0)
		beam.visible = false
		add_child(beam)
		_seals.append({id = id, node = seal, sky = sky_beam, beam = beam, pos = pos + Vector3(0.0, 1.7, 0.0), beam_pos = beam_pos, taken = false})

func _seal_mesh(id: String) -> Node3D:
	var root := Node3D.new()
	var color: Color = SEAL_COLORS[id]
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.55
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = _glow_material(color, 2.0)
	ring.rotation.x = PI * 0.5
	root.add_child(ring)
	var core := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.3
	disc.bottom_radius = 0.3
	disc.height = 0.06
	disc.radial_segments = 16 if id != "noon" else 6
	core.mesh = disc
	core.material_override = _glow_material(color.lightened(0.3), 2.6)
	core.rotation.x = PI * 0.5
	root.add_child(core)
	var halo := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.9
	sphere.height = 1.8
	halo.mesh = sphere
	halo.material_override = _halo_material(color)
	root.add_child(halo)
	return root

func set_seals_state(taken: Array[String]) -> void:
	for s in _seals:
		var t: bool = taken.has(str(s["id"]))
		s["taken"] = t
		(s["node"] as Node3D).visible = not t
		(s["sky"] as Node3D).visible = not t
		(s["beam"] as Node3D).visible = t

func _build_sockets() -> void:
	var hub: Dictionary = island(str(data.get("hub_island", "cadran")))
	var ground: float = float(hub.get("y", 0.0))
	var ids: Array[String] = ["dawn", "noon", "dusk"]
	var list: Array = data.get("sockets", []) as Array
	for i in list.size():
		var p: Array = list[i] as Array
		var body := StaticBody3D.new()
		body.position = Vector3(float(p[0]), ground, float(p[1]))
		body.set_meta("surface", "stone")
		add_child(body)
		_add_cylinder(body, 0.4, 0.55, 1.0, Vector3(0.0, 0.5, 0.0), _marble)
		_add_cylinder(body, 0.5, 0.4, 0.12, Vector3(0.0, 1.06, 0.0), _gold)
		var shape := _prism(0.5, 1.1, 16)
		_add_shape(body, shape, Vector3(0.0, 0.55, 0.0))
		var seal := _seal_mesh(ids[i % ids.size()])
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

# --- observatory, sundial, scenery ------------------------------------------

func _build_observatory() -> void:
	var o: Dictionary = data.get("observatory", {}) as Dictionary
	if o.is_empty():
		return
	var pos := Vector3(float(o["x"]), _ground_y(float(o["x"]), float(o["z"])), float(o["z"]))
	var floor_ring := StaticBody3D.new()
	floor_ring.position = pos
	floor_ring.set_meta("surface", "stone")
	add_child(floor_ring)
	_add_cylinder(floor_ring, 1.9, 1.9, 0.04, Vector3(0.0, 0.02, 0.0), _marble)
	_add_cylinder(floor_ring, 0.35, 0.5, 1.4, Vector3(0.0, 0.7, 0.0), _gold)
	var column := _prism(0.5, 1.4, 16)
	_add_shape(floor_ring, column, Vector3(0.0, 0.7, 0.0))
	_armillary = Node3D.new()
	_armillary.position = pos + Vector3(0.0, 2.6, 0.0)
	add_child(_armillary)
	for k in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.25 - k * 0.22
		torus.outer_radius = 1.33 - k * 0.22
		torus.rings = 36
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = _gold
		ring.rotation = Vector3(PI * 0.5 * k, k * 0.6, 0.0)
		_armillary.add_child(ring)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	core.mesh = sphere
	core.material_override = _glow_material(Color(1.0, 0.85, 0.5), 3.0)
	_armillary.add_child(core)

func observatory_position() -> Vector3:
	var o: Dictionary = data.get("observatory", {}) as Dictionary
	return Vector3(float(o.get("x", 0.0)), 0.0, float(o.get("z", 0.0)))

## Hour marks around the Dial's needle: each gold line points where the
## needle's shadow falls at that hour, with the hour in Roman numerals.
func _build_sundial() -> void:
	var needle: ShadowSystem.Caster = shadows.find("cad_aiguille")
	if needle == null:
		return
	var max_elevation: float = ConfigManager.get_float("sun_max_elevation_deg", 65.0)
	var root := Node3D.new()
	root.position = Vector3(needle.foot.x, needle.plane + 0.02, needle.foot.z)
	add_child(root)
	_add_cylinder(root, 2.9, 2.9, 0.04, Vector3.ZERO, _marble)
	for i in ROMAN.size():
		var h: float = 7.0 + i
		var dir: Vector3 = Sun.direction_for(h, max_elevation)
		var flat := Vector2(-dir.x, -dir.z).normalized()
		var angle: float = atan2(flat.x, flat.y)
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.03, 1.3)
		line.mesh = box
		line.material_override = _gold
		line.position = Vector3(flat.x * 1.25, 0.03, flat.y * 1.25)
		line.rotation.y = angle
		root.add_child(line)
		var label := Label3D.new()
		label.text = ROMAN[i]
		label.font_size = 48
		label.pixel_size = 0.006
		label.modulate = Color(0.45, 0.32, 0.12)
		label.outline_size = 0
		label.position = Vector3(flat.x * 2.3, 0.05, flat.y * 2.3)
		label.rotation = Vector3(-PI * 0.5, angle + PI, 0.0)
		root.add_child(label)

func _build_far_islands() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 22:
		var a: float = rng.randf() * TAU
		var dist: float = rng.randf_range(150.0, 320.0)
		var r: float = rng.randf_range(4.0, 18.0)
		var root := Node3D.new()
		root.position = Vector3(cos(a) * dist, rng.randf_range(-35.0, 45.0), sin(a) * dist)
		add_child(root)
		var top := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = r
		cyl.bottom_radius = r * 0.95
		cyl.height = 0.8
		cyl.radial_segments = 20
		top.mesh = cyl
		top.material_override = _grass_material
		root.add_child(top)
		var under := MeshInstance3D.new()
		under.mesh = _rock_mesh(r * 0.95, r * rng.randf_range(1.0, 1.8), i * 31 + 5)
		under.material_override = _rock_material
		under.position.y = -0.4
		root.add_child(under)

func _build_sea() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(9000.0, 9000.0)
	sea.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/sea.gdshader")
	sea.material_override = mat
	sea.position = Vector3(0.0, -55.0, 0.0)
	sea.name = "Sea"
	add_child(sea)

func sea_material() -> ShaderMaterial:
	return (get_node("Sea") as MeshInstance3D).material_override as ShaderMaterial

# --- per frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	for s in _shards:
		if bool(s["taken"]):
			continue
		var node: Node3D = s["node"]
		node.rotation.y = _time * 1.6 + float(s["offset"])
		node.position = (s["pos"] as Vector3) + Vector3(0.0, sin(_time * 2.0 + float(s["offset"])) * 0.12, 0.0)
	for s in _seals:
		(s["node"] as Node3D).rotation.y = _time * 0.8
		(s["node"] as Node3D).position.y = (s["pos"] as Vector3).y + sin(_time * 1.3) * 0.1
	for s in _sockets:
		(s["node"] as Node3D).rotation.y = -_time * 0.5
	if _armillary != null:
		_armillary.rotation.y = _time * 0.3
		(_armillary.get_child(1) as Node3D).rotation.z = _time * 0.5

## Shard magnet and pickups, seals, beams and the observatory.
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
			s["pos"] = pos.move_toward(chest, delta * (4.0 + (_magnet - dist) * 6.0))
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

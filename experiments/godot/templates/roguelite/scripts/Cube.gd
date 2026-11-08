class_name RoomCube
extends Node3D

# RoomCube: visual of one room. Built in code, no assets:
#   - 12 edges (one shared line mesh), tinted by room type
#   - one translucent panel per wall face (open faces have none: you see
#     through them, which shows the possible ways out at a glance)
#   - a decoration by type: green crystal (energy), red spikes (trap),
#     blue ring (teleporter), glowing yellow sphere with a light (core)
# Meshes and materials are cached in static variables and shared by every
# room, so a maze of hundreds of rooms stays cheap.
#
# FOCUS (readability when rooms overlap in depth):
#   GridManager marks each room as near (within GameManager.focus_radius moves of the
#   player through open passages) or far. A far room uses the "far" variant
#   of its materials, whose alpha is the base alpha x far_opacity (the
#   options slider). Every far room shares those few materials, so moving the
#   slider only updates a handful of materials. At 0 the far rooms are hidden.
#   The teleporter and the core keep their glowing decoration at full
#   strength: they stay visible as landmarks.

const TYPE_COLORS: Array[Color] = [
	Color(0.62, 0.68, 0.82),   # neutral
	Color(0.25, 0.95, 0.55),   # energy crystal
	Color(1.0, 0.32, 0.32),    # trap
	Color(0.38, 0.62, 1.0),    # teleporter
	Color(1.0, 0.82, 0.25)]    # core

static var _edge_mesh: ArrayMesh = null
static var _panels: Array[BoxMesh] = []
static var _mats: Dictionary = {}
static var far_opacity: float = 0.15

var mask: int = 0
var type: int = 0
var _walls: Node3D = null
var _deco: Node3D = null
var _edges: MeshInstance3D = null
var _time: float = 0.0
var _pop: Tween = null
var _near: bool = true

func setup(m: int, t: int, animate: bool) -> void:
	mask = m
	type = t
	_time = randf() * 10.0
	_build()
	if animate:
		scale = Vector3.ONE * 0.4
		_pop = create_tween()
		_pop.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Removes the room; its pop-in tween is stopped first (a room created and
## destroyed by a bomb in the same frame would otherwise warn).
func remove() -> void:
	if _pop != null and _pop.is_valid():
		_pop.kill()
	queue_free()

func has_wall(dir: Vector3i) -> bool:
	return (mask & GridManager.dir_bit(dir)) != 0

func set_mask(m: int) -> void:
	mask = m
	_build_walls()
	apply_focus(_near)

func is_near() -> bool:
	return _near

func _is_landmark() -> bool:
	return type == GridManager.Type.TELEPORTER or type == GridManager.Type.CORE

## Switches the room between its near and far look (see FOCUS above).
func apply_focus(near: bool) -> void:
	_near = near
	var hidden: bool = not near and far_opacity <= 0.01
	_edges.visible = not hidden
	_walls.visible = not hidden
	_edges.material_override = _mat("edge", type, not near)
	for c in _walls.get_children():
		var wall: MeshInstance3D = c as MeshInstance3D
		wall.material_override = _mat("wall", type, not near)
	if _deco != null:
		var deco_far: bool = not near and not _is_landmark()
		_deco.visible = not (deco_far and hidden)
		for c in _deco.get_children():
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi != null:
				mi.material_override = _mat("glow", type, deco_far)

## Opacity of far rooms, from 0 (hidden) to 1 (same as near rooms).
static func set_far_opacity(value: float) -> void:
	far_opacity = clampf(value, 0.0, 1.0)
	for key in _mats.keys():
		var k: String = str(key)
		if k.ends_with("_far"):
			var parts: PackedStringArray = k.split("_")
			var m: StandardMaterial3D = _mats[key] as StandardMaterial3D
			m.albedo_color.a = _base_alpha(parts[0], int(parts[1])) * far_opacity

func set_type(t: int) -> void:
	type = t
	_build()

func _process(delta: float) -> void:
	if _deco == null:
		return
	_time += delta
	match type:
		GridManager.Type.RESOURCE:
			_deco.rotation.y = _time * 1.6
			_deco.position.y = sin(_time * 2.5) * 0.06
		GridManager.Type.TRAP:
			_deco.rotation.y = -_time * 0.8
		GridManager.Type.TELEPORTER:
			_deco.rotation.y = _time * 0.7
		GridManager.Type.CORE:
			var s: float = 1.0 + 0.12 * sin(_time * 4.0)
			_deco.scale = Vector3(s, s, s)

# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

func _color() -> Color:
	return TYPE_COLORS[clampi(type, 0, TYPE_COLORS.size() - 1)]

func _build() -> void:
	if _edges == null:
		_edges = MeshInstance3D.new()
		_edges.mesh = _get_edge_mesh()
		add_child(_edges)
	_build_walls()
	_build_deco()
	apply_focus(_near)

func _build_walls() -> void:
	if _walls != null:
		_walls.free()
	_walls = Node3D.new()
	add_child(_walls)
	for i in GridManager.DIRS.size():
		if mask & (1 << i):
			var dir: Vector3i = GridManager.DIRS[i]
			var mi := MeshInstance3D.new()
			mi.mesh = _get_panel(dir)
			mi.position = Vector3(dir) * 0.48
			mi.material_override = _mat("wall", type)
			_walls.add_child(mi)

func _build_deco() -> void:
	if _deco != null:
		_deco.free()
		_deco = null
	var color: Color = _color()
	match type:
		GridManager.Type.RESOURCE:
			_deco = Node3D.new()
			var crystal := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.16, 0.32, 0.16)
			crystal.mesh = box
			crystal.rotation = Vector3(0.6, 0.0, 0.6)
			crystal.material_override = _mat("glow", type)
			_deco.add_child(crystal)
		GridManager.Type.TRAP:
			_deco = Node3D.new()
			for i in 4:
				var spike := MeshInstance3D.new()
				var prism := PrismMesh.new()
				prism.size = Vector3(0.14, 0.26, 0.14)
				spike.mesh = prism
				spike.position = Vector3(cos(i * PI * 0.5) * 0.16, -0.36, sin(i * PI * 0.5) * 0.16)
				spike.material_override = _mat("glow", type)
				_deco.add_child(spike)
		GridManager.Type.TELEPORTER:
			_deco = Node3D.new()
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.26
			torus.outer_radius = 0.36
			ring.mesh = torus
			ring.position.y = -0.4
			ring.material_override = _mat("glow", type)
			_deco.add_child(ring)
		GridManager.Type.CORE:
			_deco = Node3D.new()
			var orb := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.2
			sphere.height = 0.4
			orb.mesh = sphere
			orb.material_override = _mat("glow", type)
			_deco.add_child(orb)
			var light := OmniLight3D.new()
			light.light_color = color
			light.light_energy = 1.6
			light.omni_range = 3.0
			_deco.add_child(light)
	if _deco != null:
		add_child(_deco)

# ---------------------------------------------------------------------------
# Shared resources
# ---------------------------------------------------------------------------

static func _get_edge_mesh() -> ArrayMesh:
	if _edge_mesh != null:
		return _edge_mesh
	var pts := PackedVector3Array()
	var h: float = 0.5
	var corners: Array[Vector3] = []
	for x in [-h, h]:
		for y in [-h, h]:
			for z in [-h, h]:
				corners.append(Vector3(x, y, z))
	for a in corners.size():
		for b in range(a + 1, corners.size()):
			var diff: Vector3 = (corners[b] - corners[a]).abs()
			# an edge joins two corners that differ on exactly one axis
			if int(diff.x > 0.0) + int(diff.y > 0.0) + int(diff.z > 0.0) == 1:
				pts.append(corners[a])
				pts.append(corners[b])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	_edge_mesh = ArrayMesh.new()
	_edge_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return _edge_mesh

static func _get_panel(dir: Vector3i) -> BoxMesh:
	if _panels.is_empty():
		for size in [Vector3(0.03, 0.92, 0.92), Vector3(0.92, 0.03, 0.92), Vector3(0.92, 0.92, 0.03)]:
			var b := BoxMesh.new()
			b.size = size
			_panels.append(b)
	if dir.x != 0:
		return _panels[0]
	if dir.y != 0:
		return _panels[1]
	return _panels[2]

static func _base_alpha(kind: String, t: int) -> float:
	match kind:
		"edge":
			return 0.75 if t != GridManager.Type.NEUTRAL else 0.4
		"wall":
			return 0.42
	return 1.0

static func _mat(kind: String, t: int, far: bool = false) -> StandardMaterial3D:
	var key: String = "%s_%d_%s" % [kind, t, "far" if far else "near"]
	if _mats.has(key):
		return _mats[key] as StandardMaterial3D
	var c: Color = TYPE_COLORS[clampi(t, 0, TYPE_COLORS.size() - 1)]
	var alpha: float = _base_alpha(kind, t) * (far_opacity if far else 1.0)
	var m := StandardMaterial3D.new()
	match kind:
		"edge":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(c, alpha)
		"wall":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.albedo_color = Color(c.darkened(0.15), alpha)
			m.emission_enabled = true
			m.emission = c * 0.18
			m.roughness = 0.7
		_:
			if far:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(c, alpha)
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 1.6
	_mats[key] = m
	return m

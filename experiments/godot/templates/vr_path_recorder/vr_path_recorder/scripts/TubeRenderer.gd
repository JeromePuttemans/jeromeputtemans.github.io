class_name TubeRenderer
extends Node3D

# ─── Constants ────────────────────────────────────────────────
const MAX_RADIUS:    float = 0.05   # 5 cm at pressure = 0
const TUBE_SIDES:    int   = 10     # Polygon segments for tube cross-section
const MIN_RADIUS:    float = 0.001  # Below this → no mesh, no cap

# ─── Internal mesh nodes (created in _ready) ──────────────────
var _tube_body:  MeshInstance3D
var _cap_start:  MeshInstance3D
var _cap_end:    MeshInstance3D

# ─── Cached path to detect new points ─────────────────────────
var _cached_size: int = -1

# ──────────────────────────────────────────────────────────────
func _ready() -> void:
	_tube_body = MeshInstance3D.new()
	_cap_start = MeshInstance3D.new()
	_cap_end   = MeshInstance3D.new()

	_tube_body.name = "TubeBody"
	_cap_start.name = "CapStart"
	_cap_end.name   = "CapEnd"

	add_child(_tube_body)
	add_child(_cap_start)
	add_child(_cap_end)

# ─── Public API ───────────────────────────────────────────────

## Called every frame during RECORDING.
## Only rebuilds the mesh when the path has grown.
func update_from_path(path: Array) -> void:
	if path.size() == _cached_size:
		return
	_cached_size = path.size()

	if path.size() == 0:
		_clear_meshes()
		return

	if path.size() == 1:
		_update_cap(_cap_end, path[0])
		return

	_rebuild_tube(path)

## Wipe everything (called on RESET or start of new session)
func clear_tube() -> void:
	_cached_size = -1
	_clear_meshes()

# ─── Tube mesh generation ─────────────────────────────────────

func _rebuild_tube(path: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var prev_ring: Array = []

	for i in range(path.size()):
		var p        = path[i]
		var pos      := _p2v(p.position)
		var radius   := MAX_RADIUS * (1.0 - float(p.pressure))
		var dir      := _direction_at(path, i)
		var ring     := _make_ring(pos, dir, radius)

		if prev_ring.size() == TUBE_SIDES:
			_connect_rings(st, prev_ring, ring)

		prev_ring = ring

	st.generate_normals()
	_tube_body.mesh = st.commit()

	# Caps at both ends
	_update_cap(_cap_start, path[0])
	_update_cap(_cap_end,   path.back())

# ─── Ring helpers ─────────────────────────────────────────────

func _direction_at(path: Array, i: int) -> Vector3:
	if path.size() < 2:
		return Vector3.FORWARD
	if i == 0:
		return (_p2v(path[1].position) - _p2v(path[0].position)).normalized()
	elif i == path.size() - 1:
		return (_p2v(path[i].position) - _p2v(path[i - 1].position)).normalized()
	else:
		return (_p2v(path[i + 1].position) - _p2v(path[i - 1].position)).normalized()

func _make_ring(center: Vector3, dir: Vector3, radius: float) -> Array:
	var ring := []
	# Build a stable perpendicular basis
	var up := Vector3.UP
	if abs(dir.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var right := dir.cross(up).normalized()
	up = right.cross(dir).normalized()

	for i in range(TUBE_SIDES):
		var angle  := (float(i) / float(TUBE_SIDES)) * TAU
		var offset := right * cos(angle) * radius + up * sin(angle) * radius
		ring.append(center + offset)

	return ring

func _connect_rings(st: SurfaceTool, ring_a: Array, ring_b: Array) -> void:
	for i in range(TUBE_SIDES):
		var n := (i + 1) % TUBE_SIDES
		# Quad → 2 triangles
		st.add_vertex(ring_a[i])
		st.add_vertex(ring_b[i])
		st.add_vertex(ring_a[n])

		st.add_vertex(ring_b[i])
		st.add_vertex(ring_b[n])
		st.add_vertex(ring_a[n])

# ─── Spherical caps ───────────────────────────────────────────

func _update_cap(cap: MeshInstance3D, point: Dictionary) -> void:
	var radius := MAX_RADIUS * (1.0 - float(point.pressure))

	if radius < MIN_RADIUS:
		cap.mesh = null
		return

	var sphere                := SphereMesh.new()
	sphere.radius             = radius
	sphere.height             = radius * 2.0
	sphere.radial_segments    = TUBE_SIDES
	sphere.rings              = 5

	cap.mesh     = sphere
	cap.position = _p2v(point.position)

# ─── Utilities ────────────────────────────────────────────────

func _clear_meshes() -> void:
	_tube_body.mesh = null
	_cap_start.mesh = null
	_cap_end.mesh   = null

func _p2v(arr: Array) -> Vector3:
	return Vector3(arr[0], arr[1], arr[2])

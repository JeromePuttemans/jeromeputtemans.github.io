class_name PathRecorder
extends Node

# ─── Constants ────────────────────────────────────────────────
const SAMPLE_RATE       := 30.0   # Hz
const MAX_PRESSURE      := 1.0    # At or above this value → point skipped

# ─── Public paths (read by GameManager → TubeRenderer) ────────
var path_left:  Array = []
var path_right: Array = []

# ─── Controller references (assigned by GameManager) ──────────
var controller_left:  XRController3D = null
var controller_right: XRController3D = null

# ─── Internal state ───────────────────────────────────────────
var _is_recording: bool  = false
var _timer:        float = 0.0
var _start_time:   float = 0.0

# ─── Public API ───────────────────────────────────────────────

func start_recording() -> void:
	path_left.clear()
	path_right.clear()
	_timer      = 0.0
	_start_time = Time.get_ticks_msec() / 1000.0
	_is_recording = true

func stop_recording() -> void:
	_is_recording = false

func clear() -> void:
	path_left.clear()
	path_right.clear()
	_is_recording = false

# ─── Per-frame timer ──────────────────────────────────────────

func _process(delta: float) -> void:
	if not _is_recording:
		return

	_timer += delta
	if _timer >= 1.0 / SAMPLE_RATE:
		_timer -= 1.0 / SAMPLE_RATE
		_capture_point()

# ─── Internal capture ─────────────────────────────────────────

func _capture_point() -> void:
	var timestamp: float = Time.get_ticks_msec() / 1000.0 - _start_time

	if controller_left and controller_left.get_is_active():
		var pressure: float = controller_left.get_float("trigger")
		if pressure < MAX_PRESSURE:
			path_left.append({
				"position":  _v3(controller_left.global_position),
				"rotation":  _quat(controller_left.global_transform.basis.get_rotation_quaternion()),
				"pressure":  pressure,
				"timestamp": timestamp
			})

	if controller_right and controller_right.get_is_active():
		var pressure: float = controller_right.get_float("trigger")
		if pressure < MAX_PRESSURE:
			path_right.append({
				"position":  _v3(controller_right.global_position),
				"rotation":  _quat(controller_right.global_transform.basis.get_rotation_quaternion()),
				"pressure":  pressure,
				"timestamp": timestamp
			})

# ─── Helpers ──────────────────────────────────────────────────

func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func _quat(q: Quaternion) -> Array:
	return [q.x, q.y, q.z, q.w]

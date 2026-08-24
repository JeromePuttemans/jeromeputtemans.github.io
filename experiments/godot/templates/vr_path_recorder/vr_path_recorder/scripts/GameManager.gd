extends Node3D

# ─── State machine ────────────────────────────────────────────
enum State { IDLE, COUNTDOWN, RECORDING, SAVED }

# ─── Config ───────────────────────────────────────────────────
const COUNTDOWN_SEC:   float = 3.0
const LONG_PRESS_SEC:  float = 1.0   # Hold X to reset

# ─── Scene references ─────────────────────────────────────────
@onready var path_recorder:    PathRecorder   = $PathRecorder
@onready var tube_left:        TubeRenderer   = $TubeLeft
@onready var tube_right:       TubeRenderer   = $TubeRight
@onready var export_manager:   ExportManager  = $ExportManager

@onready var controller_left:  XRController3D = $XROrigin3D/LeftController
@onready var controller_right: XRController3D = $XROrigin3D/RightController

@onready var countdown_label:  Label3D        = $XROrigin3D/XRCamera3D/CountdownLabel
@onready var status_label:     Label3D        = $XROrigin3D/XRCamera3D/StatusLabel

# ─── Runtime vars ─────────────────────────────────────────────
var _state:             State = State.IDLE
var _countdown_timer:   float = 0.0
var _long_press_timer:  float = 0.0
var _long_press_active: bool  = false
var _last_haptic_sec:   int   = -1   # Tracks which countdown second triggered haptics

# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	# ── Initialise OpenXR ──
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.initialize():
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("[GameManager] OpenXR initialised")
	else:
		push_warning("[GameManager] OpenXR not found — running in desktop preview mode")

	# ── Wire controllers to PathRecorder ──
	path_recorder.controller_left  = controller_left
	path_recorder.controller_right = controller_right

	# ── Connect button signals ──
	controller_right.button_pressed.connect(_on_right_pressed)
	controller_left.button_pressed.connect(_on_left_pressed)
	controller_left.button_released.connect(_on_left_released)

	countdown_label.visible = false
	_refresh_status()

# ─── Main loop ────────────────────────────────────────────────
func _process(delta: float) -> void:
	match _state:
		State.COUNTDOWN:
			_tick_countdown(delta)
		State.RECORDING:
			_tick_tubes()
			_tick_long_press(delta)
		State.IDLE:
			_tick_long_press(delta)

# ─── Countdown ────────────────────────────────────────────────
func _tick_countdown(delta: float) -> void:
	_countdown_timer -= delta

	var seconds_left: int = ceili(_countdown_timer)
	countdown_label.text  = str(max(seconds_left, 0))

	# One haptic pulse per second descending
	if seconds_left != _last_haptic_sec and seconds_left >= 0:
		_last_haptic_sec = seconds_left
		_haptic_both(0.4, 0.15)

	if _countdown_timer <= 0.0:
		_enter_recording()

# ─── Tube update ──────────────────────────────────────────────
func _tick_tubes() -> void:
	tube_left.update_from_path(path_recorder.path_left)
	tube_right.update_from_path(path_recorder.path_right)

# ─── Long-press detection (X = reset) ────────────────────────
func _tick_long_press(delta: float) -> void:
	if not _long_press_active:
		return
	_long_press_timer += delta
	if _long_press_timer >= LONG_PRESS_SEC:
		_long_press_active = false
		_do_reset()

# ─── Button callbacks ─────────────────────────────────────────

# Right controller: A (ax_button) or B (by_button) → start countdown
func _on_right_pressed(action: String) -> void:
	if action in ["ax_button", "by_button"]:
		if _state == State.IDLE or _state == State.SAVED:
			_enter_countdown()

# Left controller:
#   Y (by_button)  → save session
#   X (ax_button)  → begin long-press detection for reset
func _on_left_pressed(action: String) -> void:
	match action:
		"by_button":                         # Y — Save
			if _state == State.RECORDING:
				_do_save()
		"ax_button":                         # X — Reset (long press)
			if _state in [State.RECORDING, State.IDLE, State.SAVED]:
				_long_press_active = true
				_long_press_timer  = 0.0

func _on_left_released(action: String) -> void:
	if action == "ax_button":
		_long_press_active = false
		_long_press_timer  = 0.0

# ─── State transitions ────────────────────────────────────────

func _enter_countdown() -> void:
	_state              = State.COUNTDOWN
	_countdown_timer    = COUNTDOWN_SEC
	_last_haptic_sec    = ceili(COUNTDOWN_SEC)
	countdown_label.text    = str(ceili(COUNTDOWN_SEC))
	countdown_label.visible = true
	_haptic_both(0.2, 0.1)
	_refresh_status()

func _enter_recording() -> void:
	_state = State.RECORDING
	countdown_label.visible = false
	tube_left.clear_tube()
	tube_right.clear_tube()
	path_recorder.start_recording()
	_haptic_both(0.8, 0.3)
	_refresh_status()

func _do_save() -> void:
	path_recorder.stop_recording()
	var name := export_manager.save_session(
		path_recorder.path_left,
		path_recorder.path_right,
		tube_left,
		tube_right
	)
	_state = State.SAVED
	status_label.text = "✓ Saved: %s" % name
	_haptic_both(1.0, 0.5)

func _do_reset() -> void:
	path_recorder.clear()
	tube_left.clear_tube()
	tube_right.clear_tube()
	_state = State.IDLE
	_haptic_both(0.6, 0.4)
	_refresh_status()

# ─── UI helpers ───────────────────────────────────────────────
func _refresh_status() -> void:
	match _state:
		State.IDLE:
			status_label.text = "IDLE  —  A / B to record"
		State.COUNTDOWN:
			status_label.text = "Get ready…"
		State.RECORDING:
			status_label.text = "● REC  —  Y to save  |  hold X to reset"
		State.SAVED:
			pass   # set by _do_save

# ─── Haptics ──────────────────────────────────────────────────
func _haptic_both(amplitude: float, duration: float) -> void:
	controller_left.trigger_haptic_pulse("haptic",  0.0, amplitude, duration, 0.0)
	controller_right.trigger_haptic_pulse("haptic", 0.0, amplitude, duration, 0.0)

# InputBuffer.gd
# Buffered input reader for a fighting game.
#
# PATTERN: Circular buffer (ring buffer) for input history.
# WHY: Fighting games require "leniency" — special moves use recent inputs
#      (e.g., ↓↘→ + P). A buffer lets us check the last N frames of input
#      without allocating new arrays every frame.
#
# USAGE:
#   var buf := InputBuffer.new("p1", 30)  # 30-frame buffer
#   buf.record(delta)                     # call in _physics_process
#   buf.is_pressed("light_punch")
#   buf.was_just_pressed("jump")
#   buf.check_motion([...])              # motion input detection

class_name InputBuffer
extends RefCounted

const BUFFER_SIZE := 30  # frames of history kept

# Maps action name → player-prefixed action (e.g. "light_punch" → "p1_light_punch")
var _prefix: String
var _actions: Array[String] = [
	"left", "right", "up", "down",
	"light_punch", "heavy_punch",
	"light_kick", "heavy_kick",
	"special", "block"
]

# Ring buffer storing one Dictionary per frame
var _history: Array[Dictionary] = []
var _head: int = 0   # points to current frame slot
var _filled: bool = false

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _init(player_prefix: String, buffer_size: int = BUFFER_SIZE) -> void:
	_prefix = player_prefix + "_"
	# Pre-allocate the ring buffer — avoids per-frame allocation
	_history.resize(buffer_size)
	for i in range(buffer_size):
		_history[i] = _make_empty_frame()

## Call once per physics frame to snapshot current input state.
func record() -> void:
	var frame := {}
	for action in _actions:
		var full := _prefix + action
		frame[action] = {
			"pressed":      Input.is_action_pressed(full),
			"just_pressed": Input.is_action_just_pressed(full),
			"just_released":Input.is_action_just_released(full),
			"strength":     Input.get_action_strength(full)
		}
	_history[_head] = frame
	_head = (_head + 1) % _history.size()
	if not _filled and _head == 0:
		_filled = true

# ── Queries ──────────────────────────────────────────────────────────────────

func is_pressed(action: String) -> bool:
	return _current_frame().get(action, {}).get("pressed", false)

func was_just_pressed(action: String) -> bool:
	return _current_frame().get(action, {}).get("just_pressed", false)

func was_just_released(action: String) -> bool:
	return _current_frame().get(action, {}).get("just_released", false)

func get_strength(action: String) -> float:
	return _current_frame().get(action, {}).get("strength", 0.0)

## Check if all actions in `sequence` were pressed within `window_frames` frames.
## Simple sequential motion check (not strict QCF, but sufficient for prototype).
func check_motion(sequence: Array[String], window_frames: int = 15) -> bool:
	if sequence.is_empty():
		return false
	var matched := 0
	var total := _history.size() if _filled else _head
	var checked := 0
	# Walk backwards through history
	var idx := (_head - 1 + _history.size()) % _history.size()
	while checked < min(window_frames, total):
		var frame: Dictionary = _history[idx]
		if frame.has(sequence[sequence.size() - 1 - matched]):
			if frame[sequence[sequence.size() - 1 - matched]].get("just_pressed", false):
				matched += 1
				if matched == sequence.size():
					return true
		idx = (idx - 1 + _history.size()) % _history.size()
		checked += 1
	return false

# ── Private ──────────────────────────────────────────────────────────────────

func _current_frame() -> Dictionary:
	# head - 1 is the last recorded frame
	var last := (_head - 1 + _history.size()) % _history.size()
	return _history[last]

func _make_empty_frame() -> Dictionary:
	var f := {}
	for action in _actions:
		f[action] = {"pressed": false, "just_pressed": false, "just_released": false, "strength": 0.0}
	return f

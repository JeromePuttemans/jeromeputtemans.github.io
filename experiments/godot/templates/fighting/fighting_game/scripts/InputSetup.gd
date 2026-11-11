# =============================================================================
# InputSetup.gd — Builds the input actions for the current mode
# =============================================================================
# Letter keys use physical key codes, so the layout does not matter (the
# W/A/S/D keys are Z/Q/S/D on an AZERTY keyboard).
#   Player 1   W A S D (+ arrows when playing alone), J light, K heavy,
#              L special; pad 1: stick or d-pad, A jump, X light,
#              Y heavy, B special
#   Player 2   arrows, numpad 1 light, 2 heavy, 3 special; pad 2
#   Both       Esc / P / Start: pause
# =============================================================================

class_name InputSetup
extends RefCounted

const DEADZONE: float = 0.4

static func register(two_players: bool) -> void:
	var p1_dirs: Dictionary = {left = [KEY_A], right = [KEY_D], up = [KEY_W], down = [KEY_S]}
	if not two_players:
		p1_dirs = {left = [KEY_A, KEY_LEFT], right = [KEY_D, KEY_RIGHT], up = [KEY_W, KEY_UP], down = [KEY_S, KEY_DOWN]}
	var pad1: int = 0 if two_players else -1
	_player("p1_", p1_dirs, {light = [KEY_J], heavy = [KEY_K], special = [KEY_L]}, pad1)
	_player("p2_", {left = [KEY_LEFT], right = [KEY_RIGHT], up = [KEY_UP], down = [KEY_DOWN]}, {light = [KEY_KP_1], heavy = [KEY_KP_2], special = [KEY_KP_3]}, 1)
	_action("pause", [KEY_ESCAPE, KEY_P], [[JOY_BUTTON_START, -1]], [])

static func _player(prefix: String, dirs: Dictionary, buttons: Dictionary, device: int) -> void:
	_action(prefix + "left", dirs["left"], [[JOY_BUTTON_DPAD_LEFT, device]], [[JOY_AXIS_LEFT_X, -1.0, device]])
	_action(prefix + "right", dirs["right"], [[JOY_BUTTON_DPAD_RIGHT, device]], [[JOY_AXIS_LEFT_X, 1.0, device]])
	_action(prefix + "up", dirs["up"], [[JOY_BUTTON_DPAD_UP, device], [JOY_BUTTON_A, device]], [[JOY_AXIS_LEFT_Y, -1.0, device]])
	_action(prefix + "down", dirs["down"], [[JOY_BUTTON_DPAD_DOWN, device]], [[JOY_AXIS_LEFT_Y, 1.0, device]])
	_action(prefix + "light", buttons["light"], [[JOY_BUTTON_X, device]], [])
	_action(prefix + "heavy", buttons["heavy"], [[JOY_BUTTON_Y, device]], [])
	_action(prefix + "special", buttons["special"], [[JOY_BUTTON_B, device]], [])

static func _action(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, DEADZONE)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	for b in buttons:
		var pad := InputEventJoypadButton.new()
		pad.button_index = int(b[0])
		pad.device = int(b[1])
		InputMap.action_add_event(action, pad)
	for a in axes:
		var motion := InputEventJoypadMotion.new()
		motion.axis = int(a[0])
		motion.axis_value = float(a[1])
		motion.device = int(a[2])
		InputMap.action_add_event(action, motion)

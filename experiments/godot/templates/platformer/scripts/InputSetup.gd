# =============================================================================
# InputSetup.gd — Registers the input actions at startup
# =============================================================================
# Letter keys use physical key codes: the key at the W/A/S/D position works
# on any layout (it is Z/Q/S/D on an AZERTY keyboard). Pads: d-pad or left
# stick to move, A (bottom button) to jump, Start to pause, Back to restart
# from the last lantern.
# =============================================================================

class_name InputSetup
extends RefCounted

const DEADZONE: float = 0.4

static func register() -> void:
	_action("move_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_action("move_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_action("move_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_action("jump", [KEY_SPACE, KEY_UP, KEY_W, KEY_K], [JOY_BUTTON_A], JOY_AXIS_INVALID, 0.0)
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], JOY_AXIS_INVALID, 0.0)
	_action("restart", [KEY_R], [JOY_BUTTON_BACK], JOY_AXIS_INVALID, 0.0)

static func _action(action: String, keys: Array, buttons: Array, axis: JoyAxis, direction: float) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, DEADZONE)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	for button in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)
	if axis != JOY_AXIS_INVALID:
		var motion := InputEventJoypadMotion.new()
		motion.axis = axis
		motion.axis_value = direction
		InputMap.action_add_event(action, motion)

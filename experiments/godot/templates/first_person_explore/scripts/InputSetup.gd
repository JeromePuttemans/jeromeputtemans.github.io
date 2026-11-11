# =============================================================================
# InputSetup.gd — Registers the input actions at startup
# =============================================================================
# Letter keys use physical key codes: the keys at the W/A/S/D and Q/E
# positions work on any layout (Z/Q/S/D and A/E on an AZERTY keyboard);
# key_name() gives the letter printed on the player's keyboard. Pads: left
# stick to move, right stick to look, A to jump, left stick click to run,
# shoulders or triggers to move the sun, Start to pause.
# =============================================================================

class_name InputSetup
extends RefCounted

const DEADZONE: float = 0.25

static func register() -> void:
	_action("move_forward", [KEY_W, KEY_UP], [], JOY_AXIS_LEFT_Y, -1.0)
	_action("move_back", [KEY_S, KEY_DOWN], [], JOY_AXIS_LEFT_Y, 1.0)
	_action("move_left", [KEY_A, KEY_LEFT], [], JOY_AXIS_LEFT_X, -1.0)
	_action("move_right", [KEY_D, KEY_RIGHT], [], JOY_AXIS_LEFT_X, 1.0)
	_action("jump", [KEY_SPACE], [JOY_BUTTON_A], JOY_AXIS_INVALID, 0.0)
	_action("sprint", [KEY_SHIFT], [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_B], JOY_AXIS_INVALID, 0.0)
	_action("time_back", [KEY_Q], [JOY_BUTTON_LEFT_SHOULDER], JOY_AXIS_TRIGGER_LEFT, 1.0)
	_action("time_forward", [KEY_E], [JOY_BUTTON_RIGHT_SHOULDER], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], JOY_AXIS_INVALID, 0.0)

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

const AZERTY: Dictionary = {KEY_Q: KEY_A, KEY_W: KEY_Z, KEY_A: KEY_Q}

## Letter printed on the player's keyboard at this physical position. The
## browser does not tell the layout: there, French players are assumed to
## use an AZERTY keyboard and the others a QWERTY one.
static func key_name(physical: Key) -> String:
	var label: Key = physical
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		if StringManager.get_language() == "fr":
			label = AZERTY.get(physical, physical)
	else:
		label = DisplayServer.keyboard_get_label_from_physical(physical)
		if label == KEY_NONE:
			label = physical
	return OS.get_keycode_string(label)

static func move_keys() -> String:
	return "%s%s%s%s" % [key_name(KEY_W), key_name(KEY_A), key_name(KEY_S), key_name(KEY_D)]

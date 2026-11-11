extends Node

# InputManager: registers the input actions at startup.
# Letter keys use physical key codes, so the keys at the W/A/S/D positions
# move the ship on any layout (Z/Q/S/D on an AZERTY keyboard).
#   move     arrows, W A S D, d-pad, left stick
#   well     Space, J, Shift (held), pad A or right trigger
#   pause    Esc, P, pad Start
#   choose   1 2 3 on the upgrade screen; L language, M sound on the title

const DEADZONE: float = 0.35

func _ready() -> void:
	_action("move_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_action("move_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_action("move_up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_action("move_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_action("well", [KEY_SPACE, KEY_J, KEY_SHIFT], [JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], JOY_AXIS_INVALID, 0.0)
	_action("confirm", [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_A], JOY_AXIS_INVALID, 0.0)

func _action(action: String, keys: Array, buttons: Array, axis: JoyAxis, direction: float) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, DEADZONE)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	for button in buttons:
		var pad := InputEventJoypadButton.new()
		pad.button_index = button
		InputMap.action_add_event(action, pad)
	if axis != JOY_AXIS_INVALID:
		var motion := InputEventJoypadMotion.new()
		motion.axis = axis
		motion.axis_value = direction
		InputMap.action_add_event(action, motion)

func move_vector() -> Vector2:
	var v := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	return v.normalized() if v.length() > 1.0 else v

func well_held() -> bool:
	return Input.is_action_pressed("well")

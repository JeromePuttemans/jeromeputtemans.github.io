class_name InputManager
extends RefCounted

# InputManager: input actions created by code at startup, and key names for
# the on-screen hints.
#
# Letter keys are bound by PHYSICAL position (InputEventKey.physical_keycode),
# named after the US QWERTY key at that place: the WASD block moves the ship
# on every layout (it prints ZQSD on an AZERTY keyboard).
# key_label() returns the letter printed on the player's keyboard: the OS
# keymap on desktop, the locale in the browser (French outside Canada and
# Switzerland: AZERTY).
# Gamepad: left stick or D-pad to move, A to fire and start, B or the left
# shoulder to purge, Start to pause.

const DESKTOP_SERVERS: Array[String] = ["Windows", "macOS", "X11", "Wayland"]
const AZERTY_LETTERS: Dictionary = {KEY_W: "Z", KEY_A: "Q", KEY_Q: "A", KEY_Z: "W"}

static func configure() -> void:
	_bind_move("move_left", [KEY_LEFT, KEY_A], JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0)
	_bind_move("move_right", [KEY_RIGHT, KEY_D], JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	_bind_move("move_up", [KEY_UP, KEY_W], JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0)
	_bind_move("move_down", [KEY_DOWN, KEY_S], JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0)
	_bind_keys("fire", [KEY_SPACE])
	_bind_buttons("fire", [JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER])
	_bind_mouse("fire", MOUSE_BUTTON_LEFT)
	_bind_keys("purge", [KEY_SHIFT])
	_bind_buttons("purge", [JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER])
	_bind_mouse("purge", MOUSE_BUTTON_RIGHT)
	_bind_keys("pause", [KEY_ESCAPE, KEY_P])
	_bind_buttons("pause", [JOY_BUTTON_START])
	_bind_keys("start", [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER])
	_bind_buttons("start", [JOY_BUTTON_A, JOY_BUTTON_START])
	_bind_keys("to_title", [KEY_ESCAPE])
	_bind_buttons("to_title", [JOY_BUTTON_BACK])
	_bind_keys("language", [KEY_L])

## Letters of the movement block as printed on the keyboard: "ZQSD" or "WASD".
static func move_keys_label() -> String:
	return key_label(KEY_W) + key_label(KEY_A) + key_label(KEY_S) + key_label(KEY_D)

static func key_label(physical: Key) -> String:
	if DisplayServer.get_name() in DESKTOP_SERVERS:
		var mapped: String = OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(physical))
		if mapped.length() == 1:
			return mapped
	elif _locale_is_azerty() and AZERTY_LETTERS.has(physical):
		return AZERTY_LETTERS[physical] as String
	return OS.get_keycode_string(physical)

static func _locale_is_azerty() -> bool:
	var locale: String = OS.get_locale().replace("-", "_").to_upper()
	if OS.get_locale_language() == "fr":
		return not (locale.ends_with("_CA") or locale.ends_with("_CH"))
	return locale == "NL_BE"

static func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)

static func _bind_move(action: String, keys: Array[Key], button: JoyButton, axis: JoyAxis, direction: float) -> void:
	_bind_keys(action, keys)
	_bind_buttons(action, [button])
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = direction
	InputMap.action_add_event(action, motion)

static func _bind_keys(action: String, keys: Array[Key]) -> void:
	_ensure(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

static func _bind_buttons(action: String, buttons: Array[JoyButton]) -> void:
	_ensure(action)
	for button in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)

static func _bind_mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

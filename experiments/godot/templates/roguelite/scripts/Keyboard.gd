extends Node

# Keyboard (Autoload): keyboard layout behind the key letters shown on screen.
#
# The movement keys are read by PHYSICAL position (PHYSICAL_DIRS), named after
# the US QWERTY key at that place: KEY_W is the key that prints Z on an AZERTY
# keyboard. Movement therefore works on every layout; the layout only decides
# which letters the HUD shows (Z Q S D on AZERTY, W A S D on QWERTY).
#
# mode "auto" (default): letters detected from the best available source,
#   each one refining the previous:
#   1. startup, locale: French outside Canada, Switzerland and Luxembourg, or
#      Dutch in Belgium -> AZERTY; anything else -> QWERTY
#   2. startup, desktop: the OS keymap (keyboard_get_keycode_from_physical)
#   3. startup, web: the browser Keyboard API (navigator.keyboard), which only
#      Chromium browsers offer; the answer is asynchronous, so it is polled
#   4. every movement key pressed: the character produced at that physical
#      position. A key that differs between the two layouts (Z/W, Q/A, A/Q)
#      switches all six letters at once.
# mode "azerty" / "qwerty": letters forced by the player in the options
#   panel, for when the detection is wrong. GameManager saves the mode.

signal layout_changed()

const MODES: Array[String] = ["auto", "azerty", "qwerty"]
const PHYSICAL_DIRS: Dictionary = {
	KEY_W: Vector3i(0, 0, -1), KEY_S: Vector3i(0, 0, 1),
	KEY_A: Vector3i(-1, 0, 0), KEY_D: Vector3i(1, 0, 0),
	KEY_E: Vector3i(0, 1, 0), KEY_Q: Vector3i(0, -1, 0)}
const LAYOUTS: Dictionary = {
	"azerty": {KEY_W: "Z", KEY_S: "S", KEY_A: "Q", KEY_D: "D", KEY_E: "E", KEY_Q: "A"},
	"qwerty": {KEY_W: "W", KEY_S: "S", KEY_A: "A", KEY_D: "D", KEY_E: "E", KEY_Q: "Q"}}
const DESKTOP_SERVERS: Array[String] = ["Windows", "macOS", "X11", "Wayland"]
const WEB_POLL_TIME: float = 3.0
const WEB_JS: String = """
(function () {
	window.roguelite_layout = '';
	if (!navigator.keyboard || !navigator.keyboard.getLayoutMap) return;
	navigator.keyboard.getLayoutMap().then(function (m) {
		var o = {};
		['KeyW', 'KeyA', 'KeyS', 'KeyD', 'KeyE', 'KeyQ'].forEach(function (c) { o[c] = m.get(c) || ''; });
		window.roguelite_layout = JSON.stringify(o);
	}).catch(function () {});
})();
"""

var mode: String = "auto"
var _detected: Dictionary = {}   # physical key -> letter
var _web_wait: float = 0.0

func _ready() -> void:
	_detected = (LAYOUTS[_layout_from_locale()] as Dictionary).duplicate()
	set_process(false)
	if DisplayServer.get_name() in DESKTOP_SERVERS:
		for k in PHYSICAL_DIRS:
			var letter: String = OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(k))
			if letter.length() == 1:
				_detected[k] = letter.to_upper()
	elif OS.has_feature("web"):
		JavaScriptBridge.eval(WEB_JS, true)
		_web_wait = WEB_POLL_TIME
		set_process(true)

func set_mode(m: String) -> void:
	if not m in MODES:
		m = "auto"
	if m == mode:
		return
	mode = m
	layout_changed.emit()

## Letter shown for a key direction (before the camera rotation).
func label(dir: Vector3i) -> String:
	var letters: Dictionary = _letters()
	for k in PHYSICAL_DIRS:
		if PHYSICAL_DIRS[k] == dir:
			return str(letters.get(k, "?"))
	return "?"

## Detected layout, "AZERTY" or "QWERTY", or "" for any other layout.
func detected_name() -> String:
	for n in LAYOUTS:
		if _same(LAYOUTS[n] as Dictionary, _detected):
			return str(n).to_upper()
	return ""

## Direction of a key event without a physical position (some virtual
## keyboards send none), found from the character it produced.
func dir_from_keycode(keycode: Key) -> Vector3i:
	var letter: String = OS.get_keycode_string(keycode)
	var letters: Dictionary = _letters()
	for k in letters:
		if letters[k] == letter:
			return PHYSICAL_DIRS[k] as Vector3i
	return Vector3i.ZERO

func _letters() -> Dictionary:
	return _detected if mode == "auto" else LAYOUTS[mode] as Dictionary

func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or not PHYSICAL_DIRS.has(key.physical_keycode):
		return
	var letter: String = OS.get_keycode_string(key.keycode)
	if letter.length() == 1:
		_learn(key.physical_keycode, letter.to_upper())

func _learn(physical: Key, letter: String) -> void:
	var before: Dictionary = _detected.duplicate()
	var az: String = (LAYOUTS["azerty"] as Dictionary)[physical]
	var qw: String = (LAYOUTS["qwerty"] as Dictionary)[physical]
	if letter == az and letter != qw:
		_detected = (LAYOUTS["azerty"] as Dictionary).duplicate()
	elif letter == qw and letter != az:
		_detected = (LAYOUTS["qwerty"] as Dictionary).duplicate()
	else:
		_detected[physical] = letter   # same key in both layouts, or another layout
	_notify_if_changed(before)

## Web only: waits for the Keyboard API answer written by WEB_JS.
func _process(delta: float) -> void:
	_web_wait -= delta
	var answer: Variant = JavaScriptBridge.eval("window.roguelite_layout", true)
	if answer is String and not (answer as String).is_empty():
		var data: Variant = JSON.parse_string(answer as String)
		if data is Dictionary:
			var before: Dictionary = _detected.duplicate()
			for k in PHYSICAL_DIRS:
				var letter: String = str((data as Dictionary).get("Key" + OS.get_keycode_string(k), ""))
				if letter.length() == 1:
					_detected[k] = letter.to_upper()
			_notify_if_changed(before)
		set_process(false)
	elif _web_wait <= 0.0:
		set_process(false)   # API missing or refused: locale and key presses remain

## Also emitted in a forced mode: the options panel shows the detected layout.
func _notify_if_changed(before: Dictionary) -> void:
	if not _same(before, _detected):
		layout_changed.emit()

static func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k) or str(b[k]) != str(a[k]):
			return false
	return true

static func _layout_from_locale() -> String:
	var parts: PackedStringArray = OS.get_locale().replace("-", "_").split("_")
	var lang: String = parts[0].to_lower() if parts.size() > 0 else ""
	var country: String = parts[1].left(2).to_upper() if parts.size() > 1 else ""
	if lang == "fr" and not country in ["CA", "CH", "LU"]:
		return "azerty"
	if lang == "nl" and country == "BE":
		return "azerty"
	return "qwerty"

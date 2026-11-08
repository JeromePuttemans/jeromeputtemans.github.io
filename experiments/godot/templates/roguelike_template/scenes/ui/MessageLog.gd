# =============================================================================
# MessageLog.gd (VBoxContainer): rolling log of the last game events.
# =============================================================================
# Keeps the last MAX_LINES messages, newest at the bottom. Each message has a
# kind that sets its color, so the player reads the situation at a glance:
#   combat (your hits) white, damage (hits you take) red, heal green,
#   loot gold, level violet, warn orange, hint cyan, info grey.
# Older lines fade out. A new message flashes briefly.
# =============================================================================

extends VBoxContainer

const MAX_LINES: int = 5
const KIND_COLORS: Dictionary = {
	combat = Color("e8edf5"), damage = Color("ff7b7b"), heal = Color("7ee08a"),
	loot = Color("ffd34d"), level = Color("c7a8ff"), warn = Color("ffad5e"),
	hint = Color("7fe3ff"), info = Color("a9b4c8")}

var _messages: Array[Dictionary] = []   # {text, kind}
var _labels: Array[Label] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in MAX_LINES:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.clip_text = true
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		_labels.append(lbl)
	GameState.message_added.connect(_on_message_added)
	GameState.run_started.connect(clear)
	_update_display(false)

func clear() -> void:
	_messages.clear()
	_update_display(false)

func _on_message_added(text: String, kind: String) -> void:
	# Same message twice in a row (two bats biting): count it instead
	if not _messages.is_empty() and str(_messages[-1]["base"]) == text:
		_messages[-1]["count"] = int(_messages[-1]["count"]) + 1
	else:
		_messages.append({base = text, kind = kind, count = 1})
		if _messages.size() > 40:
			_messages.pop_front()
	_update_display(true)

func _update_display(flash_newest: bool) -> void:
	var start: int = maxi(0, _messages.size() - MAX_LINES)
	var shown: Array = _messages.slice(start)
	for i in MAX_LINES:
		var lbl: Label = _labels[i]
		# Bottom-aligned: the newest message sits on the last line
		var idx: int = i - (MAX_LINES - shown.size())
		if idx < 0:
			lbl.text = ""
			continue
		var m: Dictionary = shown[idx]
		var count: int = int(m["count"])
		lbl.text = str(m["base"]) + ("  x%d" % count if count > 1 else "")
		var col: Color = KIND_COLORS.get(str(m["kind"]), KIND_COLORS["info"]) as Color
		var age: int = shown.size() - 1 - idx
		col.a = 1.0 - 0.17 * age
		lbl.add_theme_color_override("font_color", col)
		if flash_newest and age == 0:
			lbl.modulate = Color(1.6, 1.6, 1.6)
			create_tween().tween_property(lbl, "modulate", Color.WHITE, 0.35)

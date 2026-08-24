# =============================================================================
# MessageLog.gd — Scrolling message log (last N game events).
# =============================================================================
# Displays a rolling buffer of the most recent log messages.
# Older messages scroll upward as new ones arrive at the bottom.
# The log is cleared on each new floor (dungeon_ready signal).
# =============================================================================

extends VBoxContainer

const MAX_LINES = 5

var _messages: Array = []
var _labels: Array   = []   # Array[Label], populated in _ready()

func _ready() -> void:
	# Build the label array at runtime to avoid @onready + typed-array edge cases
	_labels = [$Msg0, $Msg1, $Msg2, $Msg3, $Msg4]
	GameState.message_added.connect(_on_message_added)
	GameState.dungeon_ready.connect(_on_dungeon_ready)
	_update_display()

func _on_dungeon_ready() -> void:
	_messages.clear()
	_update_display()

func _on_message_added(text: String) -> void:
	_messages.append(text)
	_update_display()

func _update_display() -> void:
	# Show the last MAX_LINES messages, oldest at top, newest at bottom
	var start = max(0, _messages.size() - MAX_LINES)
	var displayed = _messages.slice(start)
	for i in MAX_LINES:
		_labels[i].text = displayed[i] if i < displayed.size() else ""

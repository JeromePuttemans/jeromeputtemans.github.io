# ControlsOverlay.gd
# CanvasLayer — toggle controls panel with TAB key.

extends CanvasLayer

const P1: Array = [
	["W",        "Sauter / Jump"],
	["A / D",    "Marcher / Walk"],
	["Y",        "Bloquer / Block"],
	["U",        "Light Punch"],
	["I",        "Heavy Punch"],
	["J",        "Light Kick"],
	["K",        "Heavy Kick"],
	["L",        "Spécial / Dash"],
]
const P2: Array = [
	["↑",        "Sauter / Jump"],
	["← / →",    "Marcher / Walk"],
	["KP 2",     "Bloquer / Block"],
	["KP 7",     "Light Punch"],
	["KP 8",     "Heavy Punch"],
	["KP 4",     "Light Kick"],
	["KP 5",     "Heavy Kick"],
	["KP 6",     "Spécial / Dash"],
]

var _show: bool = false
@onready var _draw_node: Node2D = $OverlayDraw

func _ready() -> void:
	_draw_node.set_visible_data(false, P1, P2)
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_show = not _show
			_draw_node.set_visible_data(_show, P1, P2)

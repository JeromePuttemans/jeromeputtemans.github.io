# =============================================================================
# EndScreen.gd — The finished board, hung like a painting, with its label
# =============================================================================
# The board appears as a canvas in a white mat and a black frame, on a dark
# wall, beside a museum label: "Composition No. n", its colours by area
# ("in red, yellow and blue"), its size, then the score, lines, level and
# number of flat areas, and "New record" when it is one.
# =============================================================================

class_name EndScreen
extends Control

signal again_requested()
signal gallery_requested()
signal title_requested()

const CELL: float = 26.0
const ORIGIN: Vector2 = Vector2(150.0, 100.0)

var _blocks: Array = []
var _cols: int = 12
var _rows: int = 20
var _time: float = 0.0
var _lines: Array[Label] = []
var _card: VBoxContainer = null
var _buttons: Array[Button] = []
var _hint: Label = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card = VBoxContainer.new()
	_card.position = Vector2(620, 150)
	_card.custom_minimum_size = Vector2(520, 0)
	_card.add_theme_constant_override("separation", 10)
	add_child(_card)
	var row := HBoxContainer.new()
	row.position = Vector2(620, 560)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for cb in [func() -> void: again_requested.emit(), func() -> void: gallery_requested.emit(), func() -> void: title_requested.emit()]:
		var b := UiTheme.button("", cb, 180.0)
		row.add_child(b)
		_buttons.append(b)
	_hint = UiTheme.label("", 16, Color(1, 1, 1, 0.6))
	_hint.position = Vector2(620, 636)
	add_child(_hint)

func show_result(blocks: Array, stats: Dictionary, info: Dictionary, cols: int, rows: int) -> void:
	_blocks = blocks
	_cols = cols
	_rows = rows
	for c in _card.get_children():
		c.queue_free()
	_lines.clear()
	var texts: Array = [
		[StringManager.t("end_title", {n = int(info["n"])}), 40, Pieces.LINE],
		[StringManager.t("end_colors", {colors = Painting.colour_words(blocks)}), 24, Pieces.LINE],
		[StringManager.t("end_canvas", {w = cols, h = rows}), 18, Color(Pieces.LINE, 0.65)],
		["", 8, Pieces.LINE],
		[StringManager.t("end_score", {n = Frame.group(int(stats["score"]))}), 34, Pieces.LINE],
		[StringManager.t("end_details", {lines = int(stats["lines"]), level = int(stats["level"]), aplats = int(stats["aplats"])}), 19, Pieces.LINE],
	]
	if bool(info.get("record", false)):
		texts.append([StringManager.t("end_record"), 26, Pieces.PALETTE[Pieces.Col.RED]])
	for t in texts:
		var l := UiTheme.label(str(t[0]), int(t[1]), t[2] as Color)
		l.modulate.a = 0.0
		_card.add_child(l)
		_lines.append(l)
	_buttons[0].text = StringManager.t("end_again")
	_buttons[1].text = StringManager.t("end_gallery")
	_buttons[2].text = StringManager.t("end_title_screen")
	_hint.text = StringManager.t("end_hint")
	_time = 0.0
	visible = true
	_buttons[0].grab_focus()

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for i in _lines.size():
		_lines[i].modulate.a = clampf((_time - 0.6 - i * 0.18) * 3.0, 0.0, 1.0)
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo() or _time < 0.8:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_G:
			Sfx.play("ui")
			gallery_requested.emit()
		KEY_ESCAPE:
			Sfx.play("ui")
			title_requested.emit()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#202020"))
	var k: float = ease(clampf(_time / 0.6, 0.0, 1.0), 0.4)
	var size := Vector2(_cols, _rows) * CELL
	var lift: float = (1.0 - k) * 30.0
	var origin: Vector2 = ORIGIN + Vector2(0, lift)
	draw_rect(Rect2(origin - Vector2(46, 46), size + Vector2(92, 92)), Color(0.0, 0.0, 0.0, 0.35 * k))
	draw_rect(Rect2(origin - Vector2(40, 40), size + Vector2(80, 80)), Color(Pieces.LINE, k))
	draw_rect(Rect2(origin - Vector2(30, 30), size + Vector2(60, 60)), Color(Pieces.PALETTE[Pieces.Col.WHITE], k))
	if k > 0.05:
		Painting.draw(self, origin, CELL, _cols, _rows, _blocks, 5.0)
	var card := Rect2(600, 120, 600, 400)
	draw_rect(card.grow(6), Color(0.0, 0.0, 0.0, 0.3 * k))
	draw_rect(card, Color(Pieces.PALETTE[Pieces.Col.WHITE], k))

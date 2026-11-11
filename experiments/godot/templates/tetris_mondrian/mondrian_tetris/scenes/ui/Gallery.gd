# =============================================================================
# Gallery.gd — The last eight finished boards, hung side by side
# =============================================================================

class_name Gallery
extends Control

signal closed()

const CELL: float = 8.0
const COLS: int = 4

var _items: Array = []
var _font: Font = null
var _back: Button = null
var _cols: int = 12
var _rows: int = 20

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	_back = UiTheme.button("", func() -> void: closed.emit(), 220.0)
	_back.position = Vector2(530, 640)
	add_child(_back)

func open(cols: int, rows: int) -> void:
	_cols = cols
	_rows = rows
	_items = SaveManager.gallery()
	_back.text = StringManager.t("gallery_back")
	visible = true
	_back.grab_focus()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and not event.is_echo() and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		Sfx.play("ui")
		closed.emit()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#202020"))
	var title: String = StringManager.t("gallery_title")
	var w: float = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	draw_string(_font, Vector2(640 - w * 0.5, 66), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Pieces.PALETTE[Pieces.Col.WHITE])
	if _items.is_empty():
		var msg: String = StringManager.t("gallery_empty")
		var mw: float = _font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(_font, Vector2(640 - mw * 0.5, 360), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.75))
		return
	var size := Vector2(_cols, _rows) * CELL
	var slot := Vector2(300, 270)
	var start := Vector2(640 - slot.x * COLS * 0.5, 100)
	for i in _items.size():
		var item: Dictionary = _items[i]
		var cell := Vector2(i % COLS, floori(i / float(COLS)))
		var centre: Vector2 = start + cell * slot + Vector2(slot.x * 0.5, 0)
		var origin := Vector2(centre.x - size.x * 0.5, centre.y + 22)
		draw_rect(Rect2(origin - Vector2(16, 16), size + Vector2(32, 32)), Pieces.LINE)
		draw_rect(Rect2(origin - Vector2(11, 11), size + Vector2(22, 22)), Pieces.PALETTE[Pieces.Col.WHITE])
		Painting.draw(self, origin, CELL, _cols, _rows, item.get("blocks", []) as Array, 2.5)
		var label: String = StringManager.t("gallery_item", {n = int(item["n"]), score = Frame.group(int(item["score"]))})
		var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(_font, Vector2(centre.x - lw * 0.5, origin.y + size.y + 40), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.85))

# =============================================================================
# Pieces.gd — The rectangles and the palette
# =============================================================================
# Every piece is a rectangle, as in Mondrian's grids: turning it swaps its
# width and height. Pieces come from a shuffled bag of ten, so the sizes
# stay balanced (two 2x1, two 3x1, one 4x1, two 2x2, one 3x2, one 3x3, one
# 1x1); colours from a bag of seven (red, yellow, blue twice each, white
# once). The 1x1 is always black: the small black squares of the paintings.
# =============================================================================

class_name Pieces
extends RefCounted

enum Col { RED, YELLOW, BLUE, WHITE, BLACK, GREY }

const PALETTE: Array[Color] = [
	Color("#D52B1E"),   # red
	Color("#F3C623"),   # yellow
	Color("#1F4FA0"),   # blue
	Color("#F4F1EA"),   # white
	Color("#151515"),   # black
	Color("#A4A39E"),   # grey (the rising lines)
]
const CANVAS: Color = Color("#ECE8DF")
const LINE: Color = Color("#141414")
const COLOR_KEYS: Array[String] = ["color_red", "color_yellow", "color_blue", "color_white", "color_black", "color_grey"]

const SIZE_BAG: Array[Vector2i] = [
	Vector2i(2, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 1), Vector2i(4, 1),
	Vector2i(2, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 3), Vector2i(1, 1),
]
const COLOR_BAG: Array[int] = [Col.RED, Col.YELLOW, Col.BLUE, Col.RED, Col.YELLOW, Col.BLUE, Col.WHITE]

var _rng := RandomNumberGenerator.new()
var _sizes: Array[Vector2i] = []
var _colors: Array[int] = []

func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

## Next piece: {size: Vector2i(w, h), color: int}.
func draw() -> Dictionary:
	if _sizes.is_empty():
		_sizes = SIZE_BAG.duplicate()
		_shuffle(_sizes)
	var size: Vector2i = _sizes.pop_back()
	var color: int = Col.BLACK
	if size != Vector2i(1, 1):
		if _colors.is_empty():
			_colors = COLOR_BAG.duplicate()
			_shuffle(_colors)
		color = _colors.pop_back()
	return {size = size, color = color}

func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = list[i]
		list[i] = list[j]
		list[j] = tmp

static func text_color(color: int) -> Color:
	return PALETTE[Col.WHITE] if color == Col.RED or color == Col.BLUE or color == Col.BLACK else LINE

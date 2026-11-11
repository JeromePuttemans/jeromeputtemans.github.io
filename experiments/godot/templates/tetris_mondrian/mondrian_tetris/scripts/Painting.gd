# =============================================================================
# Painting.gd — Draws a finished board as a Mondrian canvas
# =============================================================================
# A composition is a list of rectangles [x, y, w, h, colour] on a canvas of
# cols x rows squares (Board.snapshot()). Each rectangle is drawn as a
# colour field inside black lines of `line` pixels; the empty canvas stays
# off-white. Used by the end screen, the gallery and the title screen.
# =============================================================================

class_name Painting
extends RefCounted

static func draw(canvas: CanvasItem, origin: Vector2, cell: float, cols: int, rows: int, blocks: Array, line: float) -> void:
	var size := Vector2(cols, rows) * cell
	canvas.draw_rect(Rect2(origin - Vector2(line, line), size + Vector2(line, line) * 2.0), Pieces.LINE)
	canvas.draw_rect(Rect2(origin, size), Pieces.CANVAS)
	for b in blocks:
		var r := Rect2(origin + Vector2(float(b[0]), float(b[1])) * cell, Vector2(float(b[2]), float(b[3])) * cell)
		canvas.draw_rect(r.grow(line * 0.5), Pieces.LINE)
		canvas.draw_rect(r.grow(-line * 0.5), Pieces.PALETTE[int(b[4])])

## "rouge, jaune et bleu": the colours of the composition by area, white
## and black left out unless nothing else is there.
static func colour_words(blocks: Array) -> String:
	var area: Dictionary = {}
	for b in blocks:
		var c: int = int(b[4])
		area[c] = int(area.get(c, 0)) + int(b[2]) * int(b[3])
	var order: Array = area.keys()
	order.sort_custom(func(a: Variant, b: Variant) -> bool: return int(area[a]) > int(area[b]))
	var words: Array[String] = []
	for c in order:
		if int(c) <= Pieces.Col.BLUE:
			words.append(StringManager.t(Pieces.COLOR_KEYS[int(c)]))
	if words.is_empty():
		for c in order:
			words.append(StringManager.t(Pieces.COLOR_KEYS[int(c)]))
	if words.is_empty():
		return StringManager.t("color_white")
	if words.size() == 1:
		return words[0]
	return ", ".join(words.slice(0, words.size() - 1)) + " " + StringManager.t("and") + " " + words[words.size() - 1]

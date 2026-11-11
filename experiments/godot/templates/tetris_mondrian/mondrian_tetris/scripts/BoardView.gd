# =============================================================================
# BoardView.gd — Draws the board and animates what happens on it
# =============================================================================
# Every block is a colour field inside black lines (6 px), so the board
# always looks like a Mondrian canvas in progress.
# ANIMATION
#   piece      glides between rows and columns (its drawn position follows
#              the real one), swells on turning, squashes when it locks
#   hard drop  a streak of its colour from where it started
#   lines      each cleared row flashes and closes up; the rows above slide
#              down to their new place
#   fusion     the black line between the two merged blocks fades away and
#              the new aplat flashes
#   grey line  everything slides up one row
#   danger     the top of the canvas reddens as the stack nears it
# =============================================================================

class_name BoardView
extends Node2D

const LINE: float = 6.0

var board: Board = null
var cell: float = 32.0
var playing: bool = false

var _vis := Vector2.ZERO
var _pop: float = 0.0
var _squash: Dictionary = {}
var _offsets := PackedFloat32Array()
var _offset_t: float = 1.0
var _flashes: Array[Dictionary] = []
var _fusions: Array[Dictionary] = []
var _streak: Dictionary = {}
var _danger: float = 0.0
var _time: float = 0.0

func setup(b: Board, cell_size: float) -> void:
	board = b
	cell = cell_size
	_offsets.resize(board.total)
	_offsets.fill(0.0)
	snap()

func board_size() -> Vector2:
	return Vector2(board.cols, board.rows) * cell

func snap() -> void:
	if board != null and not board.piece.is_empty():
		_vis = Vector2(board.piece["pos"])

func reset() -> void:
	_squash = {}
	_flashes.clear()
	_fusions.clear()
	_streak = {}
	_offsets.fill(0.0)
	snap()

## Pixel position of a cell (column x, grid row y counting the hidden rows).
func cell_pos(x: float, y: float) -> Vector2:
	return Vector2(x * cell, (y - board.hidden) * cell)

func on_rotated() -> void:
	_pop = 1.0

func on_spawned() -> void:
	snap()

func on_locked(rect: Rect2i, color: int, hard: bool, distance: int) -> void:
	_squash = {rect = rect, t = 0.0}
	if hard and distance > 0:
		_streak = {rect = Rect2i(rect.position - Vector2i(0, distance), Vector2i(rect.size.x, distance)), color = color, t = 0.0}

func on_fused(rect: Rect2i, first: Rect2i, second: Rect2i) -> void:
	var a: Vector2
	var b: Vector2
	if first.position.x == second.position.x:
		var y: float = maxf(first.position.y, second.position.y)
		a = cell_pos(rect.position.x, y)
		b = cell_pos(rect.end.x, y)
	else:
		var x: float = maxf(first.position.x, second.position.x)
		a = cell_pos(x, rect.position.y)
		b = cell_pos(x, rect.end.y)
	_fusions.append({a = a, b = b, rect = rect, t = 0.0})

func on_cleared(rows: Array[int]) -> void:
	var k: int = 0
	_offsets.fill(0.0)
	for y in range(board.total - 1, -1, -1):
		if rows.has(y):
			k += 1
			_flashes.append({y = (y - board.hidden) * cell, t = 0.0})
		elif y + k < board.total:
			_offsets[y + k] = k * cell
	_offset_t = 0.0

## A grey line came up: every row slides up from one row lower.
func on_rose() -> void:
	_offsets.fill(-cell)
	_offset_t = 0.0

func _process(delta: float) -> void:
	_time += delta
	if board == null:
		return
	if not board.piece.is_empty():
		var target := Vector2(board.piece["pos"])
		_vis = _vis.lerp(target, 1.0 - exp(-28.0 * delta))
		if _vis.distance_to(target) > 4.0:
			_vis = target
	_pop = maxf(_pop - delta * 6.0, 0.0)
	if not _squash.is_empty():
		_squash["t"] = float(_squash["t"]) + delta
	if not _streak.is_empty():
		_streak["t"] = float(_streak["t"]) + delta
		if float(_streak["t"]) > 0.25:
			_streak = {}
	_offset_t = minf(_offset_t + delta / 0.22, 1.0)
	for i in range(_flashes.size() - 1, -1, -1):
		_flashes[i]["t"] = float(_flashes[i]["t"]) + delta
		if float(_flashes[i]["t"]) > 0.35:
			_flashes.remove_at(i)
	for i in range(_fusions.size() - 1, -1, -1):
		_fusions[i]["t"] = float(_fusions[i]["t"]) + delta
		if float(_fusions[i]["t"]) > 0.5:
			_fusions.remove_at(i)
	var height: int = board.stack_height() - board.hidden
	_danger = lerpf(_danger, clampf((height - board.rows + 7) / 5.0, 0.0, 1.0), 1.0 - exp(-4.0 * delta))
	queue_redraw()

func _row_offset(y: int) -> float:
	if _offset_t >= 1.0 or y < 0 or y >= _offsets.size():
		return 0.0
	return _offsets[y] * (1.0 - ease(_offset_t, 0.4))

func _block_rect(r: Rect2i) -> Rect2:
	var top: float = (r.position.y - board.hidden) * cell - _row_offset(r.position.y)
	var bottom: float = (r.end.y - board.hidden) * cell - _row_offset(r.end.y - 1)
	return Rect2(r.position.x * cell, top, r.size.x * cell, bottom - top)

func _field(r: Rect2, color: Color) -> void:
	var view := Rect2(Vector2.ZERO, board_size())
	var outer: Rect2 = r.grow(LINE * 0.5).intersection(view.grow(LINE * 0.5))
	if outer.size.x <= 0.0 or outer.size.y <= 0.0:
		return
	draw_rect(outer, Pieces.LINE)
	var inner: Rect2 = r.grow(-LINE * 0.5).intersection(view)
	if inner.size.x > 0.0 and inner.size.y > 0.0:
		draw_rect(inner, color)

func _draw() -> void:
	if board == null:
		return
	var size: Vector2 = board_size()
	draw_rect(Rect2(Vector2.ZERO, size), Pieces.CANVAS)
	for x in range(1, board.cols):
		draw_line(Vector2(x * cell, 0.0), Vector2(x * cell, size.y), Color(0.0, 0.0, 0.0, 0.045), 1.0)
	for y in range(1, board.rows):
		draw_line(Vector2(0.0, y * cell), Vector2(size.x, y * cell), Color(0.0, 0.0, 0.0, 0.045), 1.0)
	if _danger > 0.01:
		var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
		for i in 6:
			draw_rect(Rect2(0.0, i * cell, size.x, cell), Color(0.84, 0.17, 0.12, _danger * (0.16 - i * 0.025) * (0.6 + 0.4 * pulse)))
	for id in board.blocks:
		var b: Dictionary = board.blocks[id]
		var r: Rect2 = _block_rect(b["rect"])
		if not _squash.is_empty() and (_squash["rect"] as Rect2i) == (b["rect"] as Rect2i):
			var k: float = clampf(1.0 - float(_squash["t"]) / 0.14, 0.0, 1.0)
			var grow := Vector2(r.size.x * 0.06 * k, -r.size.y * 0.08 * k)
			r = Rect2(r.position + Vector2(-grow.x * 0.5, -grow.y), r.size + grow)
		_field(r, Pieces.PALETTE[int(b["color"])])
	for f in _fusions:
		var k: float = clampf(1.0 - float(f["t"]) / 0.4, 0.0, 1.0)
		draw_line(f["a"], f["b"], Color(Pieces.LINE, k), LINE)
		var fr: Rect2 = _block_rect(f["rect"]).grow(-LINE * 0.5)
		draw_rect(fr, Color(1.0, 1.0, 1.0, 0.55 * k * k))
	for fl in _flashes:
		var t: float = float(fl["t"]) / 0.35
		var h: float = cell * (1.0 - ease(t, 0.5))
		draw_rect(Rect2(0.0, float(fl["y"]) + (cell - h) * 0.5, size.x, h), Color(1.0, 1.0, 1.0, 1.0 - t * 0.6))
	if board.over or board.piece.is_empty() or not playing:
		return
	var psize: Vector2i = board.piece["size"]
	var color: Color = Pieces.PALETTE[int(board.piece["color"])]
	var gy: int = board.ghost_y()
	var ghost := Rect2(cell_pos((board.piece["pos"] as Vector2i).x, gy), Vector2(psize) * cell)
	if gy > (board.piece["pos"] as Vector2i).y:
		var gr: Rect2 = ghost.grow(-LINE * 0.5).intersection(Rect2(Vector2.ZERO, size))
		if gr.size.y > 0.0:
			draw_rect(gr, Color(color.r, color.g, color.b, 0.2))
			draw_rect(gr, Color(Pieces.LINE, 0.55), false, 2.0)
	if not _streak.is_empty():
		var k: float = 1.0 - float(_streak["t"]) / 0.25
		var sr: Rect2 = _block_rect(_streak["rect"]).intersection(Rect2(Vector2.ZERO, size))
		var sc: Color = Pieces.PALETTE[int(_streak["color"])]
		if sr.size.y > 0.0:
			draw_rect(sr.grow_individual(-sr.size.x * 0.3, 0.0, -sr.size.x * 0.3, 0.0), Color(sc.r, sc.g, sc.b, 0.22 * k))
	var pr := Rect2(cell_pos(_vis.x, _vis.y), Vector2(psize) * cell)
	if _pop > 0.0:
		pr = pr.grow(cell * 0.12 * _pop)
	_field(pr, color)

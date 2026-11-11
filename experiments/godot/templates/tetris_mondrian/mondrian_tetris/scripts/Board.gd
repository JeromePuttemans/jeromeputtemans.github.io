# =============================================================================
# Board.gd — Rules of the game, without any drawing
# =============================================================================
# GRID: cols x (hidden + rows) cells; new pieces appear on the first visible
#   row, the hidden rows above give room to turn them and to the stack
#   pushed up by the grey lines. Each cell stores a colour and the id of the
#   block it belongs to.
#   A block is a rectangle (a locked piece, or an aplat made of several):
#   blocks[id] = {rect: Rect2i, color, aplat}.
# PIECE: a rectangle (size, colour, top-left position). It falls one row
#   every gravity[level - 1] seconds (soft_drop_factor times faster while the
#   soft drop is held), moves sideways, turns (width and height swap around
#   its centre, with small sideways or upward nudges if that hits a wall),
#   can be dropped at once, or put aside in the hold once per piece.
#   On the ground it locks after lock_delay s; moving or turning restarts
#   that delay, at most lock_resets times.
# FUSION (APLAT): two blocks of the same colour sharing a whole side (same
#   width one above the other, or same height side by side) merge into one
#   rectangle without the black line between them. Checked after every lock
#   and after every line clear (rows that close up can align new pairs).
#   The grey lines never fuse: they are not the player's paint.
# LINES: a full row disappears and the rows above come down.
# SCORE (x level): soft drop 1 per row, hard drop 2 per row; fusion
#   score_fusion_per_cell x area of the new aplat; lines score_lines[n];
#   a sober row (two colours at most) doubles its share; every aplat of at least
#   aplat_min_area cells crossed by the cleared rows adds
#   score_aplat_per_cell x its area; consecutive clearing locks add
#   score_combo x combo; an empty board after a clear adds score_perfect.
# GREY LINES: every rise_every() locked pieces (rise_start, one fewer every
#   two levels, never fewer than rise_min) the whole stack goes up one row
#   and a grey line with one gap appears at the bottom: the pressure that
#   keeps a game of rectangles from lasting for ever. Two times out of
#   three the gap sits above the previous one, so the gaps form a well that
#   a long piece standing up can clear in one go.
# LEVEL: 1 + lines / lines_per_level.
# END: the next piece cannot appear, a piece locks entirely in the hidden
#   rows, or a grey line pushes a cell out of the top row.
# =============================================================================

class_name Board
extends RefCounted

signal spawned()
signal moved()
signal rotated()
signal touched_down()
signal locked(rect: Rect2i, color: int, hard: bool, distance: int)
signal fused(rect: Rect2i, color: int, first: Rect2i, second: Rect2i, points: int)
signal cleared(rows: Array[int], result: Dictionary)
signal held()
signal level_up(level: int)
signal game_over()
signal rose(gap: int)

var cols: int = 12
var rows: int = 20
var hidden: int = 3
var total: int = 23
var colors := PackedInt32Array()
var block_ids := PackedInt32Array()
var blocks: Dictionary = {}
var piece: Dictionary = {}           # {size: Vector2i, color: int, pos: Vector2i}
var queue: Array[Dictionary] = []
var hold_piece: Dictionary = {}
var can_hold: bool = true
var score: int = 0
var lines: int = 0
var level: int = 1
var combo: int = -1
var aplats: int = 0
var biggest: int = 0
var over: bool = false
var grounded: bool = false
var locks_since_rise: int = 0
var _last_gap: int = -1

var _cfg: Dictionary = {}
var _gen: Pieces = null
var _next_id: int = 1
var _fall: float = 0.0
var _lock_timer: float = 0.0
var _lock_resets: int = 0

func _init(seed_value: int = 0) -> void:
	cols = ConfigManager.get_int("cols", 12)
	rows = ConfigManager.get_int("rows", 20)
	hidden = ConfigManager.get_int("hidden_rows", 3)
	total = rows + hidden
	_gen = Pieces.new(seed_value)
	reset()

func cfg_f(key: String, default: float) -> float:
	return ConfigManager.get_float(key, default)

func reset() -> void:
	colors.resize(cols * total)
	colors.fill(-1)
	block_ids.resize(cols * total)
	block_ids.fill(0)
	blocks.clear()
	_next_id = 1
	score = 0
	lines = 0
	level = 1
	combo = -1
	aplats = 0
	biggest = 0
	over = false
	locks_since_rise = 0
	_last_gap = -1
	hold_piece = {}
	can_hold = true
	queue.clear()
	for i in ConfigManager.get_int("next_count", 3):
		queue.append(_gen.draw())
	_spawn(_take_next())

# --- queries -----------------------------------------------------------------------

func color_at(x: int, y: int) -> int:
	if x < 0 or x >= cols or y < 0 or y >= total:
		return -1
	return colors[y * cols + x]

func is_free(x: int, y: int) -> bool:
	if x < 0 or x >= cols or y >= total:
		return false
	if y < 0:
		return true
	return colors[y * cols + x] == -1

func fits(size: Vector2i, pos: Vector2i) -> bool:
	for dy in size.y:
		for dx in size.x:
			if not is_free(pos.x + dx, pos.y + dy):
				return false
	return true

## Lowest row a rectangle of this size can reach in column x, from y.
func drop_y(size: Vector2i, x: int, from_y: int) -> int:
	var y: int = from_y
	while fits(size, Vector2i(x, y + 1)):
		y += 1
	return y

func ghost_y() -> int:
	return drop_y(piece["size"], (piece["pos"] as Vector2i).x, (piece["pos"] as Vector2i).y)

func gravity() -> float:
	var table: Array = ConfigManager.get_array("gravity", [0.8])
	return float(table[clampi(level - 1, 0, table.size() - 1)])

func rise_every() -> int:
	return maxi(ConfigManager.get_int("rise_start", 14) - floori((level - 1) / 2.0), ConfigManager.get_int("rise_min", 7))

func stack_height() -> int:
	for y in total:
		for x in cols:
			if colors[y * cols + x] != -1:
				return total - y
	return 0

# --- actions -----------------------------------------------------------------------

func move(dx: int) -> bool:
	if over:
		return false
	var pos: Vector2i = piece["pos"] + Vector2i(dx, 0)
	if not fits(piece["size"], pos):
		return false
	piece["pos"] = pos
	_after_move()
	moved.emit()
	return true

func rotate() -> bool:
	if over:
		return false
	var size: Vector2i = piece["size"]
	if size.x == size.y:
		rotated.emit()
		return true
	var turned := Vector2i(size.y, size.x)
	var pos: Vector2i = piece["pos"]
	var centre: Vector2i = pos * 2 + size
	var base := Vector2i(floori((centre.x - turned.x) / 2.0), floori((centre.y - turned.y) / 2.0))
	for kick in [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(-1, -1), Vector2i(1, -1)]:
		if fits(turned, base + kick):
			piece["size"] = turned
			piece["pos"] = base + kick
			_after_move()
			rotated.emit()
			return true
	return false

func hold() -> bool:
	if over or not can_hold:
		return false
	var current: Dictionary = {size = piece["size"], color = piece["color"]}
	var size: Vector2i = current["size"]
	if size.x < size.y:
		current["size"] = Vector2i(size.y, size.x)
	can_hold = false
	if hold_piece.is_empty():
		hold_piece = current
		_spawn(_take_next())
	else:
		var next: Dictionary = hold_piece
		hold_piece = current
		_spawn(next)
	held.emit()
	return true

func hard_drop() -> void:
	if over:
		return
	var pos: Vector2i = piece["pos"]
	var target: int = ghost_y()
	var distance: int = target - pos.y
	piece["pos"] = Vector2i(pos.x, target)
	score += distance * ConfigManager.get_int("score_hard_drop", 2)
	_lock(true, distance)

## Advances time: gravity, soft drop, lock delay.
func step(delta: float, soft: bool) -> void:
	if over:
		return
	var interval: float = gravity()
	if soft:
		interval = minf(interval, gravity() / cfg_f("soft_drop_factor", 20.0))
	var down: Vector2i = piece["pos"] + Vector2i(0, 1)
	if fits(piece["size"], down):
		if grounded:
			grounded = false
		_fall += delta
		while _fall >= interval and not over:
			_fall -= interval
			var next: Vector2i = piece["pos"] + Vector2i(0, 1)
			if fits(piece["size"], next):
				piece["pos"] = next
				if soft:
					score += ConfigManager.get_int("score_soft_drop", 1)
			else:
				break
		if not fits(piece["size"], piece["pos"] + Vector2i(0, 1)):
			grounded = true
			_lock_timer = 0.0
			touched_down.emit()
	else:
		if not grounded:
			grounded = true
			touched_down.emit()
		_lock_timer += delta
		if _lock_timer >= cfg_f("lock_delay", 0.5):
			_lock(false, 0)

func _after_move() -> void:
	if grounded and _lock_resets < ConfigManager.get_int("lock_resets", 15):
		_lock_resets += 1
		_lock_timer = 0.0
	grounded = not fits(piece["size"], piece["pos"] + Vector2i(0, 1))

func _take_next() -> Dictionary:
	var next: Dictionary = queue.pop_front()
	queue.append(_gen.draw())
	return next

func _spawn(next: Dictionary) -> void:
	var size: Vector2i = next["size"]
	piece = {size = size, color = next["color"], pos = Vector2i(floori((cols - size.x) / 2.0), hidden)}
	_fall = 0.0
	_lock_timer = 0.0
	_lock_resets = 0
	grounded = false
	if not fits(size, piece["pos"]):
		over = true
		game_over.emit()
		return
	spawned.emit()

# --- locking, fusion, lines ----------------------------------------------------------

func _lock(hard: bool, distance: int) -> void:
	var size: Vector2i = piece["size"]
	var pos: Vector2i = piece["pos"]
	var color: int = piece["color"]
	var id: int = _next_id
	_next_id += 1
	for dy in size.y:
		for dx in size.x:
			var i: int = (pos.y + dy) * cols + pos.x + dx
			colors[i] = color
			block_ids[i] = id
	var rect := Rect2i(pos, size)
	blocks[id] = {rect = rect, color = color, aplat = false}
	locked.emit(rect, color, hard, distance)
	_merge_all()
	var cleared_any: bool = _clear_lines()
	if cleared_any:
		_merge_all()
	if pos.y + size.y <= hidden:
		over = true
		game_over.emit()
		return
	locks_since_rise += 1
	if locks_since_rise >= rise_every():
		locks_since_rise = 0
		if not _rise():
			over = true
			game_over.emit()
			return
	can_hold = true
	_spawn(_take_next())

## Pushes everything up one row and adds a grey line with one gap at the
## bottom. Returns false if a cell is pushed out of the top row.
func _rise() -> bool:
	for x in cols:
		if colors[x] != -1:
			return false
	for i in range(0, cols * (total - 1)):
		colors[i] = colors[i + cols]
		block_ids[i] = block_ids[i + cols]
	for id in blocks:
		var r: Rect2i = blocks[id]["rect"]
		blocks[id]["rect"] = Rect2i(r.position - Vector2i(0, 1), r.size)
	var gap: int = _last_gap if _last_gap >= 0 and randf() < 0.65 else randi() % cols
	_last_gap = gap
	var bottom: int = total - 1
	for part in [Vector2i(0, gap), Vector2i(gap + 1, cols)]:
		if part.y <= part.x:
			continue
		var id: int = _next_id
		_next_id += 1
		for x in range(part.x, part.y):
			colors[bottom * cols + x] = Pieces.Col.GREY
			block_ids[bottom * cols + x] = id
		blocks[id] = {rect = Rect2i(part.x, bottom, part.y - part.x, 1), color = Pieces.Col.GREY, aplat = false}
	colors[bottom * cols + gap] = -1
	block_ids[bottom * cols + gap] = 0
	rose.emit(gap)
	_merge_all()
	return true

## Merges every pair of same-coloured blocks sharing a whole side, until
## none is left.
func _merge_all() -> void:
	var merged: bool = true
	while merged:
		merged = false
		var ids: Array = blocks.keys()
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var a: Dictionary = blocks[ids[i]]
				var b: Dictionary = blocks[ids[j]]
				if int(a["color"]) == int(b["color"]) and int(a["color"]) != Pieces.Col.GREY and _share_side(a["rect"], b["rect"]):
					_merge(int(ids[i]), int(ids[j]))
					merged = true
					break
			if merged:
				break

func _share_side(a: Rect2i, b: Rect2i) -> bool:
	if a.position.x == b.position.x and a.size.x == b.size.x:
		return a.end.y == b.position.y or b.end.y == a.position.y
	if a.position.y == b.position.y and a.size.y == b.size.y:
		return a.end.x == b.position.x or b.end.x == a.position.x
	return false

func _merge(keep: int, gone: int) -> void:
	var a: Dictionary = blocks[keep]
	var b: Dictionary = blocks[gone]
	var first: Rect2i = a["rect"]
	var second: Rect2i = b["rect"]
	var rect: Rect2i = first.merge(second)
	for y in range(second.position.y, second.end.y):
		for x in range(second.position.x, second.end.x):
			block_ids[y * cols + x] = keep
	a["rect"] = rect
	a["aplat"] = true
	blocks.erase(gone)
	var area: int = rect.size.x * rect.size.y
	var points: int = ConfigManager.get_int("score_fusion_per_cell", 5) * area * level
	score += points
	aplats += 1
	biggest = maxi(biggest, area)
	fused.emit(rect, int(a["color"]), first, second, points)

func _clear_lines() -> bool:
	var full: Array[int] = []
	for y in total:
		var complete: bool = true
		for x in cols:
			if colors[y * cols + x] == -1:
				complete = false
				break
		if complete:
			full.append(y)
	if full.is_empty():
		combo = -1
		return false
	var n: int = full.size()
	var mono: int = 0
	var crossed: Dictionary = {}
	for y in full:
		var used: Dictionary = {}
		for x in cols:
			used[colors[y * cols + x]] = true
			var id: int = block_ids[y * cols + x]
			var b: Dictionary = blocks[id]
			var r: Rect2i = b["rect"]
			if bool(b["aplat"]) and r.size.x * r.size.y >= ConfigManager.get_int("aplat_min_area", 4):
				crossed[id] = r.size.x * r.size.y
		if used.size() <= 2:
			mono += 1
	var row_colors: Array[PackedInt32Array] = []
	for y in full:
		row_colors.append(colors.slice(y * cols, (y + 1) * cols))
	var table: Array = ConfigManager.get_array("score_lines", [0, 100, 300, 500, 800])
	var base: int = int(table[mini(n, table.size() - 1)]) * level
	var mono_bonus: int = int(base * mono / float(n) * (ConfigManager.get_float("sober_multiplier", 2.0) - 1.0))
	var aplat_bonus: int = 0
	for id in crossed:
		aplat_bonus += int(crossed[id]) * ConfigManager.get_int("score_aplat_per_cell", 20) * level
	_remove_rows(full)
	combo += 1
	var combo_bonus: int = ConfigManager.get_int("score_combo", 50) * combo * level if combo > 0 else 0
	var perfect: bool = blocks.is_empty()
	var perfect_bonus: int = ConfigManager.get_int("score_perfect", 2000) * level if perfect else 0
	var total_points: int = base + mono_bonus + aplat_bonus + combo_bonus + perfect_bonus
	score += total_points
	lines += n
	var result: Dictionary = {row_colors = row_colors, n = n, base = base, mono = mono, mono_bonus = mono_bonus, aplat_count = crossed.size(), aplat_bonus = aplat_bonus, combo = combo, combo_bonus = combo_bonus, perfect = perfect, total = total_points, level = level}
	cleared.emit(full, result)
	var new_level: int = 1 + floori(lines / float(ConfigManager.get_int("lines_per_level", 10)))
	if new_level != level:
		level = new_level
		level_up.emit(level)
	return true

func _remove_rows(full: Array[int]) -> void:
	var new_colors := PackedInt32Array()
	new_colors.resize(cols * total)
	new_colors.fill(-1)
	var new_ids := PackedInt32Array()
	new_ids.resize(cols * total)
	new_ids.fill(0)
	var target: int = total - 1
	for y in range(total - 1, -1, -1):
		if full.has(y):
			continue
		for x in cols:
			new_colors[target * cols + x] = colors[y * cols + x]
			new_ids[target * cols + x] = block_ids[y * cols + x]
		target -= 1
	colors = new_colors
	block_ids = new_ids
	var bounds: Dictionary = {}
	for y in total:
		for x in cols:
			var id: int = block_ids[y * cols + x]
			if id == 0:
				continue
			if bounds.has(id):
				bounds[id] = (bounds[id] as Rect2i).expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
			else:
				bounds[id] = Rect2i(x, y, 1, 1)
	for id in blocks.keys():
		if bounds.has(id):
			blocks[id]["rect"] = bounds[id]
		else:
			blocks.erase(id)

## The board as a list of rectangles, for the painting and the gallery.
func snapshot() -> Array:
	var out: Array = []
	for id in blocks:
		var b: Dictionary = blocks[id]
		var r: Rect2i = b["rect"]
		if r.end.y <= hidden:
			continue
		var top: int = maxi(r.position.y, hidden)
		out.append([r.position.x, top - hidden, r.size.x, r.end.y - top, int(b["color"])])
	return out

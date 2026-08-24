extends Node2D

# ═══════════════════════════════════════════════════════════
#   MONDRIAN TETRIS  —  inspiré de Piet Mondrian
#   Godot 4.x  |  Node2D  |  dessin entièrement via _draw()
# ═══════════════════════════════════════════════════════════

# ── Références aux constantes partagées ─────────────────────
const Constants := preload("res://scripts/Constants.gd")

# ── Design size for reference (used for UI positioning calculations) ─────
const DESIGN_WIDTH := Constants.BX + Constants.COLS * Constants.CELL_SIZE + Constants.UI_OFFSET_X + 100
const DESIGN_HEIGHT := max(Constants.BY + Constants.ROWS * Constants.CELL_SIZE, Constants.GAME_OVER_Y + Constants.ROWS * Constants.CELL_SIZE) + 20

# ── Signaux ─────────────────────────────────────────────────
signal score_changed(new_score)
signal level_changed(new_level)
signal lines_changed(new_lines)
signal next_piece_changed(new_type, new_color)
signal game_over_changed(new_is_over)

# ── État du jeu ─────────────────────────────────────────────
var board        : Array   # board[r][c]    = Color | null
var board_id     : Array   # board_id[r][c] = int   (0 = vide)
var next_piece_id: int = 1

var piece        : Array   # Array[Vector2i] positions sur le plateau
var piece_color  : Color
var next_type    : int = 0
var next_color   : Color

var score  := 0
var level  := 1
var lines  := 0
var fall_t := 0.0
var fall_dt:= 0.8
var is_over:= false

# ── Initialisation ──────────────────────────────────────────
func _ready() -> void:
	randomize()
	_reset()
	
	# Connect signals to UI node
	var ui_node = get_node("../UI")
	if ui_node:
		score_changed.connect(ui_node._on_score_changed)
		level_changed.connect(ui_node._on_level_changed)
		lines_changed.connect(ui_node._on_lines_changed)
		next_piece_changed.connect(ui_node._on_next_piece_changed)
		game_over_changed.connect(ui_node._on_game_over_changed)
		
		# Set board properties for UI
		ui_node.board_offset_x = Constants.BX
		ui_node.board_offset_y = Constants.BY
		ui_node.board_cols = Constants.COLS
		ui_node.board_rows = Constants.ROWS
		ui_node.board_cell_size = Constants.CELL_SIZE
		
		# Note: For proper stretching while maintaining aspect ratio,
		# configure this in Project Settings -> Display -> Window -> Stretch
		# Set Mode to "Keep Aspect" and Aspect to 1.0
		# We'll calculate a scale factor for drawing instead
		pass

func _reset() -> void:
	board    = []
	board_id = []
	for _i in range(Constants.ROWS):
		var row := []
		row.resize(Constants.COLS)
		row.fill(null)
		board.append(row)

		var id_row := []
		id_row.resize(Constants.COLS)
		id_row.fill(0)
		board_id.append(id_row)

	score = 0; level = 1; lines = 0
	fall_t = 0.0; fall_dt = 0.8; is_over = false
	next_piece_id = 1
	next_type  = _get_next_piece_type()
	next_color = _get_next_piece_color()
	# Emit signals for initial values
	score_changed.emit(score)
	level_changed.emit(level)
	lines_changed.emit(lines)
	game_over_changed.emit(is_over)
	# Emit signal for initial next piece
	next_piece_changed.emit(next_type, next_color)
	_spawn()

# ── Logique des pièces ──────────────────────────────────────
func _get_next_piece_type() -> int:
	return randi() % Constants.SHAPES.size()

func _get_next_piece_color() -> Color:
	var color_id := randi() % Constants.PIECE_COLORS.size()
	return Constants.PIECE_COLORS[color_id]

func _spawn() -> void:
	var type    := next_type
	piece_color  = next_color

	next_type  = _get_next_piece_type()
	next_color = _get_next_piece_color()
	# Emit signal for next piece change
	next_piece_changed.emit(next_type, next_color)

	var offset_x := Constants.COLS / 2 - 2
	piece = []
	for v : Vector2i in Constants.SHAPES[type]:
		piece.append(Vector2i(v.x + offset_x, v.y))

	if not _valid(piece):
		is_over = true
		# Emit signal for game over
		game_over_changed.emit(is_over)

func _valid(_piece: Array) -> bool:
	for v : Vector2i in _piece:
		if v.x < 0 or v.x >= Constants.COLS or v.y >= Constants.ROWS: return false
		if v.y >= 0 and board[v.y][v.x] != null:   return false
	return true

func _shift(_piece: Array, dx: int, dy: int) -> Array:
	var result := []
	for v : Vector2i in _piece:
		result.append(v + Vector2i(dx, dy))
	return result

func _try_move(dx: int, dy: int) -> bool:
	var np := _shift(piece, dx, dy)
	if _valid(np):
		piece = np
		return true
	return false

func _rotate() -> void:
	var xs : Array = piece.map(func(v: Vector2i): return v.x)
	var ys : Array = piece.map(func(v: Vector2i): return v.y)
	var mx : int = xs.min()
	var my : int = ys.min()
	var h  : int = ys.max() - my
	var rotated : Array = piece.map(func(v: Vector2i) -> Vector2i:
		return Vector2i(mx + h - (v.y - my), my + (v.x - mx)))
	if _valid(rotated):
		piece = rotated
		return
	for dx in [-1, 1, -2, 2]:
		var s := _shift(rotated, dx, 0)
		if _valid(s):
			piece = s
			return

func _lock() -> void:
	var pid := next_piece_id
	next_piece_id += 1
	for v : Vector2i in piece:
		if v.y >= 0:
			board[v.y][v.x]    = piece_color
			board_id[v.y][v.x] = pid
	_clear_lines()
	_spawn()

func _clear_lines() -> void:
	var n := 0
	var r := Constants.ROWS - 1
	while r >= 0:
		var full : bool = true
		for cell in board[r]:
			if cell == null:
				full = false
				break
		if full:
			board.remove_at(r)
			board_id.remove_at(r)
			var row := []; row.resize(Constants.COLS); row.fill(null)
			board.insert(0, row)
			var id_row := []; id_row.resize(Constants.COLS); id_row.fill(0)
			board_id.insert(0, id_row)
			n += 1
		else:
			r -= 1
	if n > 0:
		var pts : Array = [0, 100, 300, 500, 800]
		score  += pts[min(n, 4)] * level
		lines  += n
		level   = int(1 + lines / 10)
		fall_dt = max(0.1, 0.8 - (level - 1) * 0.07)
		# Emit signals for updated values
		score_changed.emit(score)
		level_changed.emit(level)
		lines_changed.emit(lines)

func _ghost() -> Array:
	var g := piece.duplicate()
	while true:
		var ng := _shift(g, 0, 1)
		if _valid(ng): g = ng
		else: break
	return g

func _hard_drop() -> void:
	while _try_move(0, 1): pass
	_lock()

# ── Boucle principale ───────────────────────────────────────
func _process(delta: float) -> void:
	if is_over: return
	fall_t += delta
	if fall_t >= fall_dt:
		fall_t = 0.0
		if not _try_move(0, 1): _lock()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey): return
	var key := event as InputEventKey

	if not key.pressed: return
	if is_over:
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_R]:
			_reset()
		return
	match key.keycode:
		KEY_LEFT:
			_try_move(-1, 0)
		KEY_RIGHT:
			_try_move(1, 0)
		KEY_DOWN:
			if not _try_move(0, 1): _lock()
			fall_t = 0.0
		KEY_UP:
			_rotate()
		KEY_SPACE:
			_hard_drop()

# ── Draw Helpers ─────────────────────────────────────────────
func _draw_cell(_column: int, _row: int) -> Rect2:
	return Rect2(Constants.BX + _column * Constants.CELL_SIZE, Constants.BY + _row * Constants.CELL_SIZE, Constants.CELL_SIZE, Constants.CELL_SIZE)

func _draw_hline(x0: float, x1: float, y: float, w: float) -> void:
	draw_line(Vector2(x0, y), Vector2(x1, y), Constants.C_BLACK, w)

func _draw_vline(x: float, y0: float, y1: float, w: float) -> void:
	draw_line(Vector2(x, y0), Vector2(x, y1), Constants.C_BLACK, w)

# ── Rendu principal ──────────────────────────────────────────
func _draw() -> void:
	_draw_board()

# ── Plateau de jeu ───────────────────────────────────────────
func _draw_board() -> void:
# Fond du plateau
	draw_rect(Rect2(Constants.BX, Constants.BY, Constants.COLS * Constants.CELL_SIZE, Constants.ROWS * Constants.CELL_SIZE), Constants.C_WHITE)

	# Lignes de grille
	for c in range(Constants.COLS + 1):
		_draw_vline(Constants.BX + c * Constants.CELL_SIZE, Constants.BY, Constants.BY + Constants.ROWS * Constants.CELL_SIZE, Constants.LINE_WIDTH)
	for r in range(Constants.ROWS + 1):
		_draw_hline(Constants.BX, Constants.BX + Constants.COLS * Constants.CELL_SIZE, Constants.BY + r * Constants.CELL_SIZE, Constants.LINE_WIDTH)

	# Cellules verrouillées
	for r in range(Constants.ROWS):
		for c in range(Constants.COLS):
			if board[r][c] != null:
				draw_rect(_draw_cell(c, r), board[r][c])

	# Bordures des formes verrouillées
	_draw_borders()

	if not is_over:
		# Pièce fantôme (projection)
		var ghost := _ghost()
		for v : Vector2i in ghost:
			if v.y >= 0:
				var gc := piece_color
				gc.a = 0.22
				draw_rect(_draw_cell(v.x, v.y), gc)
		_draw_piece_borders(ghost, Constants.C_BORDERS)
		# Pièce active
		for v : Vector2i in piece:
			if v.y >= 0:
				draw_rect(_draw_cell(v.x, v.y), piece_color)
		_draw_piece_borders(piece, Constants.C_BORDERS)

	# Bordure épaisse du plateau
	draw_rect(Rect2(Constants.BX, Constants.BY, Constants.COLS * Constants.CELL_SIZE, Constants.ROWS * Constants.CELL_SIZE), Constants.C_BLACK, false, Constants.LINE_WIDTH * 2)

func get_cell(x: int, y: int):
	if x < 0 or x >= Constants.COLS or y < 0 or y >= Constants.ROWS:
		return null
	return board[y][x]

func _draw_borders() -> void:
	for y in range(Constants.ROWS):
		for x in range(Constants.COLS):
			if board[y][x] == null:
				continue

			var pid : int = board_id[y][x]
			var px  := float(Constants.BX + x * Constants.CELL_SIZE)
			var py  := float(Constants.BY + y * Constants.CELL_SIZE)

			# Haut
			if y == 0 or board_id[y - 1][x] != pid:
				draw_line(Vector2(px, py), Vector2(px + Constants.CELL_SIZE, py), Constants.C_BORDERS, Constants.LINE_WIDTH)
			# Bas
			if y == Constants.ROWS - 1 or board_id[y + 1][x] != pid:
				draw_line(Vector2(px, py + Constants.CELL_SIZE), Vector2(px + Constants.CELL_SIZE, py + Constants.CELL_SIZE), Constants.C_BORDERS, Constants.LINE_WIDTH)
			# Gauche
			if x == 0 or board_id[y][x - 1] != pid:
				draw_line(Vector2(px, py), Vector2(px, py + Constants.CELL_SIZE), Constants.C_BORDERS, Constants.LINE_WIDTH)
			# Droite
			if x == Constants.COLS - 1 or board_id[y][x + 1] != pid:
				draw_line(Vector2(px + Constants.CELL_SIZE, py), Vector2(px + Constants.CELL_SIZE, py + Constants.CELL_SIZE), Constants.C_BORDERS, Constants.LINE_WIDTH)

func _draw_piece_borders(cells: Array, color: Color) -> void:
	for v : Vector2i in cells:
		if v.y < 0:
			continue
		var px := float(Constants.BX + v.x * Constants.CELL_SIZE)
		var py := float(Constants.BY + v.y * Constants.CELL_SIZE)

		# Haut
		if not cells.has(Vector2i(v.x, v.y - 1)):
			draw_line(Vector2(px, py), Vector2(px + Constants.CELL_SIZE, py), color, Constants.LINE_WIDTH)
		# Bas
		if not cells.has(Vector2i(v.x, v.y + 1)):
			draw_line(Vector2(px, py + Constants.CELL_SIZE), Vector2(px + Constants.CELL_SIZE, py + Constants.CELL_SIZE), color, Constants.LINE_WIDTH)
		# Gauche
		if not cells.has(Vector2i(v.x - 1, v.y)):
			draw_line(Vector2(px, py), Vector2(px, py + Constants.CELL_SIZE), color, Constants.LINE_WIDTH)
		# Droite
		if not cells.has(Vector2i(v.x + 1, v.y)):
			draw_line(Vector2(px + Constants.CELL_SIZE, py), Vector2(px + Constants.CELL_SIZE, py + Constants.CELL_SIZE), color, Constants.LINE_WIDTH)

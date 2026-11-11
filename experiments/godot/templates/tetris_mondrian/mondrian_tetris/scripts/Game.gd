# =============================================================================
# Game.gd — A game in progress: input, timing, and the reactions to it
# =============================================================================
# Owns the Board (rules), the Frame (screen composition and information),
# the BoardView (canvas and animations) and the Effects2D layer, and turns
# every board event into sound, motion and words.
# INPUT: left and right move once, then repeat every `arr` s after being
#   held `das` s (the last pressed direction wins); down drops softly; up
#   or X turns; space drops at once; C or shift puts the piece in the hold.
# FEEL: hard drop shakes the screen in proportion to the distance and the
#   board bumps down; locks make a wooden "thock"; fusions play a rising
#   arpeggio and throw squares of their colour; cleared lines play the
#   chord of the bar the music is in (more notes for more lines), flash,
#   close up, throw their squares, and shake the screen from three lines up.
# =============================================================================

class_name Game
extends Node2D

signal finished(snapshot: Array, stats: Dictionary)

const ACTIONS: Dictionary = {
	"left": [[KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT]],
	"right": [[KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT]],
	"soft": [[KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN]],
	"rotate": [[KEY_UP, KEY_X, KEY_W], [JOY_BUTTON_A]],
	"drop": [[KEY_SPACE], [JOY_BUTTON_DPAD_UP, JOY_BUTTON_Y]],
	"hold": [[KEY_C, KEY_SHIFT], [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B]],
	"pause": [[KEY_ESCAPE, KEY_P], [JOY_BUTTON_START]],
}

var board: Board = null
var view: BoardView = null
var frame: Frame = null
var effects: Effects2D = null
var active: bool = false
var bot_control: bool = false        # tests drive the board directly

var _dir: int = 0
var _das: float = 0.0
var _shake: float = 0.0
var _bump: float = 0.0
var _bump_v: float = 0.0
var _root: Node2D = null
var _ending: float = -1.0

static func register_actions() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.4)
		for key in ACTIONS[action][0]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)
		for button in ACTIONS[action][1]:
			var j := InputEventJoypadButton.new()
			j.button_index = button
			InputMap.action_add_event(action, j)

func _ready() -> void:
	_root = Node2D.new()
	add_child(_root)
	frame = Frame.new()
	_root.add_child(frame)
	view = BoardView.new()
	view.position = Frame.BOARD_ORIGIN
	_root.add_child(view)
	effects = Effects2D.new()
	_root.add_child(effects)

func start(seed_value: int = 0) -> void:
	board = Board.new(seed_value)
	frame.board = board
	frame.reset()
	view.setup(board, ConfigManager.get_float("cell", 32.0))
	view.reset()
	view.playing = true
	effects.clear()
	board.spawned.connect(view.on_spawned)
	board.moved.connect(func() -> void: Sfx.play("move", 1.0, 0.05, -4.0))
	board.rotated.connect(func() -> void:
		Sfx.play("rotate", 1.0, 0.04, -3.0)
		view.on_rotated())
	board.locked.connect(_on_locked)
	board.fused.connect(_on_fused)
	board.cleared.connect(_on_cleared)
	board.held.connect(func() -> void:
		Sfx.play("hold")
		frame.hold_flash())
	board.level_up.connect(_on_level_up)
	board.game_over.connect(_on_game_over)
	board.rose.connect(func(_gap: int) -> void:
		view.on_rose()
		Sfx.play("rise")
		_shake = maxf(_shake, 3.0)
		_bump_v -= 120.0)
	_dir = 0
	_ending = -1.0
	active = true
	Sfx.start_music(1)

func stop() -> void:
	active = false
	view.playing = false
	Sfx.stop_music()

func board_rect() -> Rect2:
	return Rect2(Frame.BOARD_ORIGIN, view.board_size())

## Screen position of a grid cell's centre.
func cell_centre(x: float, y: float) -> Vector2:
	return Frame.BOARD_ORIGIN + view.cell_pos(x + 0.5, y + 0.5)

# --- frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	_shake = maxf(_shake - delta * 30.0, 0.0)
	_bump_v += (-_bump * 260.0 - _bump_v * 18.0) * minf(delta, 0.02)
	_bump += _bump_v * minf(delta, 0.02)
	_root.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	view.position = Frame.BOARD_ORIGIN + Vector2(0.0, _bump)
	if _ending >= 0.0:
		_ending += delta
		if _ending > 1.4:
			_ending = -1.0
			finished.emit(board.snapshot(), {score = board.score, lines = board.lines, level = board.level, aplats = board.aplats, biggest = board.biggest})
		return
	if not active or board == null or board.over:
		return
	if not bot_control:
		_read_input(delta)
	board.step(delta, Input.is_action_pressed("soft") and not bot_control)

func _read_input(delta: float) -> void:
	if Input.is_action_just_pressed("left"):
		_dir = -1
		_das = ConfigManager.get_float("das", 0.17)
		board.move(-1)
	elif Input.is_action_just_pressed("right"):
		_dir = 1
		_das = ConfigManager.get_float("das", 0.17)
		board.move(1)
	if _dir == -1 and not Input.is_action_pressed("left"):
		_dir = 1 if Input.is_action_pressed("right") else 0
		_das = ConfigManager.get_float("das", 0.17)
	elif _dir == 1 and not Input.is_action_pressed("right"):
		_dir = -1 if Input.is_action_pressed("left") else 0
		_das = ConfigManager.get_float("das", 0.17)
	if _dir != 0:
		_das -= delta
		while _das <= 0.0:
			_das += ConfigManager.get_float("arr", 0.05)
			if not board.move(_dir):
				break
	if Input.is_action_just_pressed("rotate"):
		board.rotate()
	if Input.is_action_just_pressed("hold"):
		board.hold()
	if Input.is_action_just_pressed("drop"):
		board.hard_drop()

# --- board events ------------------------------------------------------------------

func _on_locked(rect: Rect2i, color: int, hard: bool, distance: int) -> void:
	view.on_locked(rect, color, hard, distance)
	var base := Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y)
	if hard:
		Sfx.play("drop", 1.0 + randf_range(-0.05, 0.05), 0.0, clampf(distance * 0.3 - 3.0, -6.0, 2.0))
		_shake = maxf(_shake, clampf(distance * 0.5, 2.0, 9.0))
		_bump_v += clampf(distance * 18.0, 60.0, 260.0)
		for i in rect.size.x:
			effects.burst(cell_centre(rect.position.x + i, rect.end.y - 1) + Vector2(0, view.cell * 0.5), Pieces.LINE, 2, 160.0, 6.0, 0.4, 120.0)
	else:
		Sfx.play("lock", 1.0, 0.06, -2.0)
	effects.burst(cell_centre(base.x - 0.5, base.y - 0.5) + Vector2(0, view.cell * 0.5), Pieces.PALETTE[color], 3 + rect.size.x, 120.0, 7.0, 0.45, 80.0)

func _on_fused(rect: Rect2i, color: int, first: Rect2i, second: Rect2i, points: int) -> void:
	view.on_fused(rect, first, second)
	var area: int = rect.size.x * rect.size.y
	Sfx.arpeggio(clampi(2 + floori(area / 3.0), 3, 7), 1, 0.06, -3.0)
	var centre: Vector2 = cell_centre(rect.position.x + rect.size.x * 0.5 - 0.5, rect.position.y + rect.size.y * 0.5 - 0.5)
	effects.burst(centre, Pieces.PALETTE[color], 8 + area * 2, 280.0, 12.0, 0.8, 120.0)
	effects.popup(centre, "+" + Frame.group(points), Pieces.PALETTE[Pieces.Col.WHITE] if color != Pieces.Col.WHITE else Pieces.PALETTE[Pieces.Col.YELLOW], 24)
	frame.add_event(StringManager.t("ev_fusion", {w = rect.size.x, h = rect.size.y}), points, Pieces.PALETTE[color])
	frame.score_pop()

func _on_cleared(rows: Array[int], result: Dictionary) -> void:
	view.on_cleared(rows)
	var n: int = int(result["n"])
	Sfx.bar_chord(3 + n, 0 if n < 3 else 1, -1.0 + n)
	Sfx.play("wipe", 1.0 + n * 0.08, 0.0, -4.0)
	var row_colors: Array = result["row_colors"]
	for k in rows.size():
		var colors: PackedInt32Array = row_colors[k]
		for x in board.cols:
			var c: int = colors[x]
			if c >= 0 and (x + k) % 2 == 0:
				effects.burst(cell_centre(x, rows[k]), Pieces.PALETTE[c], 2, 420.0, 13.0, 0.9, 260.0)
	var key: String = "ev_lines_%d" % mini(n, 4)
	frame.add_event(StringManager.t(key), int(result["base"]), Pieces.PALETTE[Pieces.Col.BLUE])
	if int(result["mono"]) > 0:
		frame.add_event(StringManager.t("ev_sober"), int(result["mono_bonus"]), Pieces.PALETTE[Pieces.Col.RED])
	if int(result["aplat_count"]) > 0:
		frame.add_event(StringManager.t("ev_aplat"), int(result["aplat_bonus"]), Pieces.PALETTE[Pieces.Col.YELLOW])
		Sfx.arpeggio(6, 1, 0.05, -2.0)
	if int(result["combo"]) > 0:
		frame.add_event(StringManager.t("ev_combo", {n = int(result["combo"]) + 1}), int(result["combo_bonus"]), Pieces.PALETTE[Pieces.Col.RED])
	if bool(result["perfect"]):
		frame.add_event(StringManager.t("ev_perfect"), ConfigManager.get_int("score_perfect", 2000) * int(result["level"]), Pieces.PALETTE[Pieces.Col.WHITE])
		Sfx.arpeggio(8, 0, 0.07, 0.0)
	var mid_y: float = 0.0
	for r in rows:
		mid_y += r
	mid_y /= rows.size()
	effects.popup(cell_centre(board.cols * 0.5 - 0.5, mid_y), "+" + Frame.group(int(result["total"])), Pieces.PALETTE[Pieces.Col.YELLOW], 30 + n * 4, 1.1)
	if n >= 3:
		_shake = maxf(_shake, 5.0 + n * 2.0)
	frame.score_pop()

func _on_level_up(level: int) -> void:
	frame.repaint()
	Sfx.set_level(level)
	Sfx.arpeggio(5, 0, 0.08, -1.0)
	frame.add_event(StringManager.t("ev_level", {n = level}), 0, Pieces.PALETTE[Pieces.Col.RED])

func _on_game_over() -> void:
	active = false
	view.playing = false
	Sfx.stop_music()
	Sfx.play("over")
	_shake = 6.0
	_ending = 0.0

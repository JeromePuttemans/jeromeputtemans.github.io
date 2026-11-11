# =============================================================================
# Frame.gd — The whole screen as a Mondrian composition
# =============================================================================
# The screen is cut into rectangles by black lines (the dark background
# showing between panels). Some panels carry the game's information:
#   hold (white), score (yellow), level (red), lines (blue), next pieces
#   (white), events (white)
# the others are colour fields, repainted panel by panel at each new level.
# BOOGIE: the panel at the bottom right and the thin strip above the board
# are crossed by yellow lanes on which small red, blue and grey squares hop
# forward on every beat of the music, after Mondrian's last paintings
# (Broadway Boogie Woogie).
# GREY LINE METER: the strip under the board fills with black segments,
# one per locked piece; when it is full a grey line comes up.
# =============================================================================

class_name Frame
extends Node2D

const BOARD_ORIGIN: Vector2 = Vector2(448.0, 40.0)
const HOLD: Rect2 = Rect2(120, 10, 318, 220)
const SCORE: Rect2 = Rect2(120, 240, 318, 190)
const LEVEL: Rect2 = Rect2(120, 440, 154, 270)
const LINES: Rect2 = Rect2(284, 440, 154, 150)
const NEXT: Rect2 = Rect2(842, 10, 230, 400)
const EVENTS: Rect2 = Rect2(842, 420, 428, 150)
const BOOGIE: Rect2 = Rect2(972, 580, 298, 130)
const STRIP_TOP: Rect2 = Rect2(448, 10, 384, 20)
const STRIP_BOTTOM: Rect2 = Rect2(448, 690, 384, 20)
const DECOR: Array[Rect2] = [
	Rect2(10, 10, 100, 300), Rect2(10, 320, 100, 150), Rect2(10, 480, 100, 230),
	Rect2(284, 600, 154, 110), Rect2(1082, 10, 188, 170), Rect2(1082, 190, 188, 220),
	Rect2(842, 580, 120, 130),
]
const DECOR_CHOICES: Array[int] = [Pieces.Col.RED, Pieces.Col.YELLOW, Pieces.Col.BLUE, Pieces.Col.WHITE, Pieces.Col.WHITE, Pieces.Col.BLACK]
const GREY: Color = Color("#9A9A96")

var board: Board = null
var show_info: bool = true
var _font: Font = null
var _decor: Array[Dictionary] = []    # from, to, t, delay, vertical
var _lanes: Array[Dictionary] = []    # a, b, squares [{t, color}]
var _events: Array[Dictionary] = []   # text, points, color, t
var _score_shown: float = 0.0
var _beat_prev: float = 0.0
var _score_pop: float = 0.0
var _level_pop: float = 0.0
var _hold_flash: float = 0.0

func _ready() -> void:
	_font = ThemeDB.fallback_font
	for r in DECOR:
		var c: int = DECOR_CHOICES[randi() % DECOR_CHOICES.size()]
		_decor.append({from = c, to = c, t = 1.0, delay = 0.0, vertical = randf() < 0.5})
	_build_lanes()

func _build_lanes() -> void:
	_lanes.clear()
	var b: Rect2 = BOOGIE
	for k in 2:
		var y: float = b.position.y + b.size.y * (0.3 + 0.42 * k)
		_lanes.append(_lane(Vector2(b.position.x, y), Vector2(b.end.x, y)))
	for k in 3:
		var x: float = b.position.x + b.size.x * (0.18 + 0.32 * k)
		_lanes.append(_lane(Vector2(x, b.position.y), Vector2(x, b.end.y)))
	_lanes.append(_lane(Vector2(STRIP_TOP.position.x, STRIP_TOP.get_center().y), Vector2(STRIP_TOP.end.x, STRIP_TOP.get_center().y)))

func _lane(a: Vector2, b: Vector2) -> Dictionary:
	var squares: Array[Dictionary] = []
	var length: float = a.distance_to(b)
	var count: int = int(length / 46.0)
	for i in count:
		var roll: float = randf()
		squares.append({t = randf() * length, color = Pieces.PALETTE[Pieces.Col.RED] if roll < 0.4 else (Pieces.PALETTE[Pieces.Col.BLUE] if roll < 0.75 else GREY)})
	return {a = a, b = b, length = length, squares = squares}

func reset() -> void:
	_events.clear()
	_score_shown = 0.0

## Repaints the decorative panels one after the other (new level).
func repaint() -> void:
	for i in _decor.size():
		var d: Dictionary = _decor[i]
		var c: int = DECOR_CHOICES[randi() % DECOR_CHOICES.size()]
		if c == int(d["to"]):
			c = DECOR_CHOICES[(DECOR_CHOICES.find(c) + 1 + randi() % 3) % DECOR_CHOICES.size()]
		d["from"] = d["to"]
		d["to"] = c
		d["t"] = 0.0
		d["delay"] = i * 0.07
		d["vertical"] = randf() < 0.5
	_level_pop = 1.0

func add_event(text: String, points: int, color: Color) -> void:
	_events.push_front({text = text, points = points, color = color, t = 0.0})
	while _events.size() > 4:
		_events.pop_back()

func score_pop() -> void:
	_score_pop = 1.0

func hold_flash() -> void:
	_hold_flash = 1.0

func _process(delta: float) -> void:
	for d in _decor:
		if float(d["delay"]) > 0.0:
			d["delay"] = float(d["delay"]) - delta
		elif float(d["t"]) < 1.0:
			d["t"] = minf(float(d["t"]) + delta / 0.35, 1.0)
	var pulse: float = Sfx.beat_pulse
	if pulse > _beat_prev + 0.5:
		for lane in _lanes:
			for s in lane["squares"]:
				s["t"] = fmod(float(s["t"]) + 12.0, float(lane["length"]))
	_beat_prev = pulse
	for e in _events:
		e["t"] = float(e["t"]) + delta
	for i in range(_events.size() - 1, -1, -1):
		if float(_events[i]["t"]) > 3.2:
			_events.remove_at(i)
	if board != null:
		_score_shown = lerpf(_score_shown, float(board.score), 1.0 - exp(-9.0 * delta))
		if absf(_score_shown - board.score) < 1.0:
			_score_shown = board.score
	_score_pop = maxf(_score_pop - delta * 3.0, 0.0)
	_level_pop = maxf(_level_pop - delta * 1.5, 0.0)
	_hold_flash = maxf(_hold_flash - delta * 4.0, 0.0)
	queue_redraw()

# --- drawing -------------------------------------------------------------------------

func _text(at: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _text_centered(centre_x: float, y: float, text: String, size: int, color: Color) -> void:
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, Vector2(centre_x - w * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func group(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

func _draw() -> void:
	for i in DECOR.size():
		_draw_decor(DECOR[i], _decor[i])
	draw_rect(HOLD, Pieces.PALETTE[Pieces.Col.WHITE])
	draw_rect(SCORE, Pieces.PALETTE[Pieces.Col.YELLOW])
	draw_rect(LEVEL, Pieces.PALETTE[Pieces.Col.RED])
	draw_rect(LINES, Pieces.PALETTE[Pieces.Col.BLUE])
	draw_rect(NEXT, Pieces.PALETTE[Pieces.Col.WHITE])
	draw_rect(EVENTS, Pieces.PALETTE[Pieces.Col.WHITE])
	draw_rect(BOOGIE, Pieces.CANVAS)
	draw_rect(STRIP_TOP, Pieces.CANVAS)
	draw_rect(STRIP_BOTTOM, Pieces.CANVAS)
	for lane in _lanes:
		var a: Vector2 = lane["a"]
		var b: Vector2 = lane["b"]
		draw_line(a, b, Pieces.PALETTE[Pieces.Col.YELLOW], 9.0)
		var dir: Vector2 = (b - a).normalized()
		for s in lane["squares"]:
			var p: Vector2 = a + dir * float(s["t"])
			draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9.0, 9.0)), s["color"])
	if board == null or not show_info:
		return
	_draw_rise_meter()
	_draw_info()

func _draw_rise_meter() -> void:
	var n: int = board.rise_every()
	var filled: int = board.locks_since_rise
	var gap: float = 4.0
	var w: float = (STRIP_BOTTOM.size.x - gap * (n + 1)) / n
	for i in n:
		var r := Rect2(STRIP_BOTTOM.position.x + gap + i * (w + gap), STRIP_BOTTOM.position.y + 4, w, STRIP_BOTTOM.size.y - 8)
		if i < filled:
			draw_rect(r, Pieces.LINE)
		elif i == filled and filled == n - 1:
			draw_rect(r, Color(Pieces.PALETTE[Pieces.Col.RED], 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)))
		else:
			draw_rect(r, Color(Pieces.LINE, 0.12))

func _draw_decor(r: Rect2, d: Dictionary) -> void:
	draw_rect(r, Pieces.PALETTE[int(d["from"])])
	var t: float = ease(float(d["t"]), 0.4)
	if t <= 0.0:
		return
	var fill: Rect2 = r
	if bool(d["vertical"]):
		fill.size.y = r.size.y * t
	else:
		fill.size.x = r.size.x * t
	draw_rect(fill, Pieces.PALETTE[int(d["to"])])

func _draw_info() -> void:
	var ink: Color = Pieces.LINE
	var paper: Color = Pieces.PALETTE[Pieces.Col.WHITE]
	_text(HOLD.position + Vector2(18, 34), StringManager.t("hud_hold"), 20, ink)
	if not board.hold_piece.is_empty():
		var alpha: float = 1.0 if board.can_hold else 0.35
		_draw_piece(Rect2(HOLD.position + Vector2(0, 40), HOLD.size - Vector2(0, 40)), board.hold_piece, 30.0, alpha)
	if _hold_flash > 0.0:
		draw_rect(HOLD, Color(Pieces.PALETTE[Pieces.Col.YELLOW], 0.35 * _hold_flash))
	_text(SCORE.position + Vector2(18, 34), StringManager.t("hud_score"), 20, ink)
	var size: int = int(48 + 10 * _score_pop)
	_text(SCORE.position + Vector2(18, 104 + 4 * _score_pop), group(int(round(_score_shown))), size, ink)
	_text(SCORE.position + Vector2(18, 160), StringManager.t("hud_best", {n = group(maxi(SaveManager.best_score(), board.score))}), 18, ink)
	_text(LEVEL.position + Vector2(16, 34), StringManager.t("hud_level"), 20, paper)
	var lsize: int = int(80 + 30 * _level_pop)
	_text_centered(LEVEL.get_center().x, LEVEL.position.y + 130 + 10 * _level_pop, str(board.level), lsize, paper)
	var per_level: int = ConfigManager.get_int("lines_per_level", 10)
	var done: int = board.lines % per_level
	for i in per_level:
		var col: int = i % 5
		var row: int = floori(i / 5.0)
		var sq := Rect2(LEVEL.position + Vector2(17 + col * 25, 188 + row * 32), Vector2(20, 26))
		draw_rect(sq, paper if i < done else Color(0.0, 0.0, 0.0, 0.22))
	_text(LINES.position + Vector2(16, 34), StringManager.t("hud_lines"), 20, paper)
	_text_centered(LINES.get_center().x, LINES.position.y + 112, str(board.lines), 50, paper)
	_text(NEXT.position + Vector2(18, 34), StringManager.t("hud_next"), 20, ink)
	var slot_y: float = NEXT.position.y + 46
	for i in board.queue.size():
		var h: float = 150.0 if i == 0 else 98.0
		_draw_piece(Rect2(NEXT.position.x, slot_y, NEXT.size.x, h), board.queue[i], 30.0 if i == 0 else 20.0, 1.0 if i == 0 else 0.85)
		slot_y += h
	_draw_events()

func _draw_piece(area: Rect2, p: Dictionary, cell: float, alpha: float) -> void:
	var size: Vector2i = p["size"]
	var s := Vector2(size) * cell
	var r := Rect2(area.get_center() - s * 0.5, s)
	draw_rect(r.grow(3.0), Color(Pieces.LINE, alpha))
	var c: Color = Pieces.PALETTE[int(p["color"])]
	draw_rect(r.grow(-3.0), Color(c.r, c.g, c.b, alpha))

func _draw_events() -> void:
	var ink: Color = Pieces.LINE
	if _events.is_empty():
		var hint: String = StringManager.t("hud_controls")
		var parts: PackedStringArray = hint.split("     ")
		for i in parts.size():
			_text(EVENTS.position + Vector2(18 + (i % 2) * 210, 36 + floori(i / 2.0) * 34), parts[i], 16, Color(ink, 0.7))
		return
	var y: float = EVENTS.position.y + 52
	for i in mini(_events.size(), 3):
		var e: Dictionary = _events[i]
		var t: float = float(e["t"])
		var alpha: float = clampf((3.2 - t) / 0.6, 0.0, 1.0)
		var size: int = 32 if i == 0 else 20
		var bump: float = maxf(0.0, 1.0 - t / 0.15) * 8.0 if i == 0 else 0.0
		var c: Color = e["color"]
		draw_rect(Rect2(EVENTS.position.x + 14, y - size + 2 - bump, 12, size - 2), Color(c, alpha))
		_text(Vector2(EVENTS.position.x + 36, y - bump), str(e["text"]), size + int(bump), Color(ink, alpha))
		if int(e["points"]) > 0:
			var pts: String = "+" + group(int(e["points"]))
			var w: float = _font.get_string_size(pts, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			_text(Vector2(EVENTS.end.x - 18 - w, y - bump), pts, size, Color(ink, alpha))
		y += 44 if i == 0 else 30

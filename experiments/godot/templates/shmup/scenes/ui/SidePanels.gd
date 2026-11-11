# =============================================================================
# SidePanels.gd — Arcade side panels around the play field
# =============================================================================
# Left: score, best score, chain multiplier with its countdown bar, grazes,
# stage progress. Right: lives, bombs, power level, difficulty, key hints.
# Everything is drawn in _draw (texts with draw_string): the layout follows
# the field position, which Main sets when the window is resized.
# The opaque panels also hide whatever leaves the field.
# =============================================================================

class_name SidePanels
extends Control

var game: Game = null
var field_left: float = 370.0
var field_width: float = 540.0
var _font: Font = null
var _score_shown: float = 0.0
var _chain_pulse: float = 0.0
var _last_chain: float = 1.0
var _time: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

func _process(delta: float) -> void:
	_time += delta
	_score_shown = lerpf(_score_shown, float(GameState.score), minf(delta * 12.0, 1.0))
	if absf(_score_shown - GameState.score) < 1.0:
		_score_shown = GameState.score
	if GameState.chain > _last_chain + 0.05:
		_chain_pulse = 1.0
	_last_chain = GameState.chain
	_chain_pulse = maxf(_chain_pulse - delta * 4.0, 0.0)
	queue_redraw()

static func group_digits(value: int) -> String:
	var s: String = str(value)
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return out

func _text(at: Vector2, text: String, size: int, color: Color, align_right: bool = false, width: float = 0.0) -> void:
	var p: Vector2 = at
	if align_right:
		p.x += width - _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, UiTheme.SHADOW)
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	var h: float = size.y
	var right_x: float = field_left + field_width
	_panel_background(Rect2(0.0, 0.0, field_left, h), true)
	_panel_background(Rect2(right_x, 0.0, size.x - right_x, h), false)
	if GameState.phase == GameState.Phase.MENU:
		return
	var lx: float = maxf(field_left - 300.0, 20.0)
	var lw: float = field_left - lx - 30.0
	_draw_left(lx, lw)
	_draw_right(right_x + 30.0, minf(size.x - right_x - 60.0, 280.0))

func _panel_background(r: Rect2, left: bool) -> void:
	if r.size.x <= 0.0:
		return
	var inner: float = r.end.x if left else r.position.x
	var outer: float = r.position.x if left else r.end.x
	var c0 := Color(0.02, 0.025, 0.07)
	var c1 := Color(0.05, 0.06, 0.14)
	draw_polygon(PackedVector2Array([Vector2(outer, 0), Vector2(inner, 0), Vector2(inner, r.size.y), Vector2(outer, r.size.y)]),
		PackedColorArray([c0, c1, c1, c0]))
	var y: float = fmod(_time * 20.0, 40.0)
	while y < r.size.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.3, 0.4, 0.9, 0.05), 1.0)
		y += 40.0
	draw_line(Vector2(inner, 0), Vector2(inner, r.size.y), Color(UiTheme.CYAN, 0.75), 2.0)
	draw_line(Vector2(inner + (-6.0 if left else 6.0), 0), Vector2(inner + (-6.0 if left else 6.0), r.size.y), Color(UiTheme.CYAN, 0.15), 6.0)

func _draw_left(x: float, w: float) -> void:
	var y: float = 70.0
	_text(Vector2(x, y), StringManager.t("title"), 34, UiTheme.CYAN)
	draw_line(Vector2(x, y + 12.0), Vector2(x + w, y + 12.0), Color(UiTheme.CYAN, 0.4), 1.0)
	y += 70.0
	_text(Vector2(x, y), StringManager.t("panel_score"), 15, UiTheme.MUTED)
	_text(Vector2(x, y + 38.0), group_digits(int(_score_shown)), 34, UiTheme.TEXT, true, w)
	y += 80.0
	_text(Vector2(x, y), StringManager.t("panel_best"), 15, UiTheme.MUTED)
	var best: int = maxi(SaveManager.best(GameState.difficulty), GameState.score)
	_text(Vector2(x, y + 28.0), group_digits(best), 22, UiTheme.GOLD if best == GameState.score and best > 0 else UiTheme.TEXT, true, w)
	y += 70.0
	_text(Vector2(x, y), StringManager.t("panel_chain"), 15, UiTheme.MUTED)
	var chain: float = GameState.chain
	var hot: float = clampf((chain - 1.0) / 7.0, 0.0, 1.0)
	var chain_color: Color = UiTheme.CYAN.lerp(UiTheme.MAGENTA, hot)
	var chain_size: int = int(34 + 10 * _chain_pulse)
	_text(Vector2(x, y + 42.0), "x%.1f" % chain, chain_size, chain_color, true, w)
	draw_rect(Rect2(x, y + 54.0, w, 5.0), Color(0.1, 0.12, 0.25))
	draw_rect(Rect2(x, y + 54.0, w * GameState.chain_ratio(), 5.0), chain_color)
	y += 100.0
	_text(Vector2(x, y), StringManager.t("panel_graze"), 15, UiTheme.MUTED)
	_text(Vector2(x, y + 28.0), group_digits(GameState.graze), 22, UiTheme.TEXT, true, w)
	y += 70.0
	_text(Vector2(x, y), StringManager.t("panel_progress"), 15, UiTheme.MUTED)
	var progress: float = game.stage.progress() if game != null and game.running else 0.0
	draw_rect(Rect2(x, y + 14.0, w, 8.0), Color(0.1, 0.12, 0.25))
	draw_rect(Rect2(x, y + 14.0, w * progress, 8.0), UiTheme.CYAN)
	for mark in (game.stage.marks if game != null else []):
		draw_rect(Rect2(x + w * mark - 2.0, y + 10.0, 4.0, 16.0), UiTheme.MAGENTA)

func _draw_right(x: float, w: float) -> void:
	var y: float = 140.0
	_text(Vector2(x, y), StringManager.t("panel_lives"), 15, UiTheme.MUTED)
	for i in maxi(GameState.lives - 1, 0):
		UiTheme.draw_ship(self, Vector2(x + 16.0 + i * 34.0, y + 30.0), 1.2, UiTheme.CYAN)
	y += 70.0
	_text(Vector2(x, y), StringManager.t("panel_bombs"), 15, UiTheme.MUTED)
	for i in GameState.bombs:
		UiTheme.draw_bomb(self, Vector2(x + 14.0 + i * 32.0, y + 28.0), 1.2, Color(0.4, 1.0, 0.6))
	y += 70.0
	_text(Vector2(x, y), StringManager.t("panel_power"), 15, UiTheme.MUTED)
	var power_max: int = ConfigManager.get_int("power_max", 4)
	for i in power_max:
		var lit: bool = i < GameState.power
		draw_rect(Rect2(x + i * 40.0, y + 14.0, 34.0, 14.0), Color(1.0, 0.35, 0.5) if lit else Color(0.12, 0.12, 0.25))
	if GameState.power >= power_max:
		_text(Vector2(x + power_max * 40.0 + 6.0, y + 27.0), StringManager.t("panel_power_max"), 16, Color(1.0, 0.5, 0.6))
	y += 70.0
	var tag: String = StringManager.t("difficulty_hard" if GameState.difficulty == "hard" else "difficulty_normal")
	var tag_color: Color = UiTheme.RED if GameState.difficulty == "hard" else UiTheme.CYAN
	draw_rect(Rect2(x, y - 2.0, _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20.0, 28.0), Color(tag_color, 0.15))
	_text(Vector2(x + 10.0, y + 18.0), tag, 16, tag_color)
	y += 80.0
	var lines: PackedStringArray = StringManager.t("panel_hints").split("\n")
	for line in lines:
		_text(Vector2(x, y), line, 15, UiTheme.MUTED)
		y += 24.0

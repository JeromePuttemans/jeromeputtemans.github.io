extends Control

# HUD: in-game display, built by game_manager.gd under UI. Labels are created
# here in _ready(); gauges are drawn in _draw(). Updated from signals only.
#
#   top left      score, multiplier (x2...) and the time left in the chain
#   top right     sector, time, best score
#   bottom left   hull points and the purge gauge (bright when ready)
#   bottom centre SPEED gauge: fill = ship speed, white mark = the current.
#                 Below the mark the ship cannot hold its position: the gauge
#                 turns red and "TOO SLOW" blinks. This is the twist made
#                 visible.
#   centre        sector banner, one-time tip when the twist first happens
#   left edge     "THE VOID" warning, stronger near the edge
# A red flash covers the screen when the hull is hit.

const COLOR_TEXT: Color = Color(0.91, 0.91, 1.0)
const COLOR_MUTED: Color = Color(0.6, 0.62, 0.78)
const COLOR_GOLD: Color = Color(1.0, 0.8, 0.0)
const COLOR_DANGER: Color = Color(1.0, 0.267, 0.333)
const COLOR_CYAN: Color = Color(0.45, 0.9, 1.0)
const GAUGE_WIDTH: float = 340.0
const GAUGE_HEIGHT: float = 10.0
const TIP_TIME: float = 7.0
const BANNER_TIME: float = 2.2

var _manager: Node = null
var _speed_base: float = 300.0
var _score_label: Label
var _multiplier_label: Label
var _sector_label: Label
var _time_label: Label
var _best_label: Label
var _hull_label: Label
var _purge_label: Label
var _speed_label: Label
var _current_label: Label
var _slow_label: Label
var _banner_label: Label
var _banner_sub_label: Label
var _tip_label: Label
var _void_label: Label
var _flash: ColorRect
var _speed: float = 300.0
var _current: float = 90.0
var _purge_ratio: float = 1.0
var _hull: int = 3
var _hull_max: int = 3
var _chain_ratio: float = 0.0
var _danger: float = 0.0
var _banner_left: float = 0.0
var _tip_left: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_labels()
	_build_bottom_labels()
	_build_center_labels()

## Called by game_manager.gd after add_child().
func bind(manager: Node, player: Node2D, speed_base: float) -> void:
	_manager = manager
	_speed_base = speed_base
	manager.score_changed.connect(_on_score_changed)
	manager.sector_changed.connect(_on_sector_changed)
	manager.danger_changed.connect(_on_danger_changed)
	manager.game_state_changed.connect(_on_game_state_changed)
	manager.language_changed.connect(refresh_texts)
	manager.twist_activated.connect(_on_twist_activated)
	player.player_status_changed.connect(_on_player_status_changed)
	player.player_hull_changed.connect(_on_player_hull_changed)
	refresh_texts()
	_on_game_state_changed(int(manager.get("current_state")))

func refresh_texts() -> void:
	if not is_instance_valid(_manager):
		return
	_hull_label.text = _text("hull_label")
	_purge_label.text = _text("purge_label")
	_speed_label.text = _text("speed_label")
	_current_label.text = _text("current_label")
	_slow_label.text = _text("too_slow")
	_tip_label.text = _text("twist_tip")
	_void_label.text = _text("void_warning")
	var best: int = int(_manager.get("best_score"))
	_best_label.text = "%s  %s" % [_text("best"), str(_manager.call("format_score", best))] if best > 0 else ""

func _process(delta: float) -> void:
	_time += delta
	_banner_left = maxf(_banner_left - delta, 0.0)
	_tip_left = maxf(_tip_left - delta, 0.0)
	_flash.color.a = maxf(_flash.color.a - delta * 1.6, 0.0)
	var banner_alpha: float = clampf(_banner_left / 0.4, 0.0, 1.0) * clampf((BANNER_TIME - _banner_left) / 0.2, 0.0, 1.0)
	_banner_label.modulate.a = banner_alpha
	_banner_sub_label.modulate.a = banner_alpha
	_tip_label.modulate.a = clampf(_tip_left / 0.5, 0.0, 1.0)
	_slow_label.visible = _speed < _current and visible
	_slow_label.modulate.a = 0.55 + 0.45 * sin(_time * 12.0)
	_void_label.modulate.a = clampf((_danger - 0.3) / 0.4, 0.0, 1.0) * (0.6 + 0.4 * sin(_time * 10.0))
	queue_redraw()

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

func _on_score_changed(score: int, multiplier: int, chain_ratio: float, elapsed: float) -> void:
	_score_label.text = str(_manager.call("format_score", score))
	_multiplier_label.text = _textf("multiplier", {value = multiplier}) if multiplier > 1 else ""
	_chain_ratio = chain_ratio
	_time_label.text = str(_manager.call("format_time", elapsed))

func _on_sector_changed(sector: int) -> void:
	_sector_label.text = _textf("sector", {value = sector})
	_banner_label.text = _textf("sector", {value = sector})
	_banner_sub_label.text = _text("sector_up") if sector > 1 else _text("tagline")
	_banner_left = BANNER_TIME

func _on_danger_changed(intensity: float) -> void:
	_danger = intensity

func _on_game_state_changed(state: int) -> void:
	visible = state == 1 or state == 2   # PLAYING or PAUSED
	if state == 1:
		refresh_texts()

func _on_twist_activated() -> void:
	_tip_left = TIP_TIME

func _on_player_status_changed(speed: float, current_speed: float, purge_ratio: float) -> void:
	_speed = speed
	_current = current_speed
	_purge_ratio = purge_ratio

func _on_player_hull_changed(hull: int, hull_max: int) -> void:
	if hull < _hull:
		_flash.color.a = 0.35
	_hull = hull
	_hull_max = hull_max

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	_draw_chain_bar()
	_draw_hull_pips()
	_draw_purge_gauge()
	_draw_speed_gauge()
	if _tip_left > 0.0:
		var text_size: Vector2 = _tip_label.get_minimum_size()
		var center: Vector2 = _tip_label.position + _tip_label.size * 0.5
		var rect := Rect2(center - text_size * 0.5 - Vector2(16.0, 8.0), text_size + Vector2(32.0, 16.0))
		draw_rect(rect, Color(0.02, 0.02, 0.06, 0.75 * _tip_label.modulate.a))
		draw_rect(rect, Color(COLOR_GOLD, 0.6 * _tip_label.modulate.a), false, 1.5)

func _draw_chain_bar() -> void:
	if _chain_ratio <= 0.0:
		return
	var origin: Vector2 = _multiplier_label.position + Vector2(2.0, _multiplier_label.size.y + 2.0)
	draw_rect(Rect2(origin, Vector2(90.0, 3.0)), Color(COLOR_GOLD, 0.2))
	draw_rect(Rect2(origin, Vector2(90.0 * _chain_ratio, 3.0)), COLOR_GOLD)

func _draw_hull_pips() -> void:
	var origin: Vector2 = _hull_label.position + Vector2(_hull_label.size.x + 14.0, _hull_label.size.y * 0.5)
	for i in _hull_max:
		var center: Vector2 = origin + Vector2(i * 26.0, 0.0)
		var pip := PackedVector2Array([center + Vector2(10.0, 0.0), center + Vector2(-7.0, -7.0), center + Vector2(-3.0, 0.0), center + Vector2(-7.0, 7.0)])
		var filled: bool = i < _hull
		draw_colored_polygon(pip, Color(COLOR_TEXT if filled else COLOR_MUTED, 1.0 if filled else 0.25))

func _draw_purge_gauge() -> void:
	var origin: Vector2 = _purge_label.position + Vector2(_purge_label.size.x + 14.0, _purge_label.size.y * 0.5 - 4.0)
	var ready: bool = _purge_ratio >= 1.0
	var color: Color = COLOR_CYAN if ready else COLOR_MUTED
	draw_rect(Rect2(origin, Vector2(90.0, 8.0)), Color(color, 0.18))
	draw_rect(Rect2(origin, Vector2(90.0 * clampf(_purge_ratio, 0.0, 1.0), 8.0)), Color(color, 0.95 if ready else 0.6))
	if ready:
		draw_rect(Rect2(origin - Vector2(2.0, 2.0), Vector2(94.0, 12.0)), Color(COLOR_CYAN, 0.3 + 0.3 * sin(_time * 6.0)), false, 1.0)

func _draw_speed_gauge() -> void:
	var origin := Vector2((size.x - GAUGE_WIDTH) * 0.5, size.y - 52.0)
	var ratio: float = clampf(_speed / _speed_base, 0.0, 1.0)
	var mark: float = clampf(_current / _speed_base, 0.0, 1.0)
	var color: Color = COLOR_CYAN
	if _speed < _current:
		color = COLOR_DANGER
	elif _speed < _current * 1.5:
		color = COLOR_GOLD
	draw_rect(Rect2(origin, Vector2(GAUGE_WIDTH, GAUGE_HEIGHT)), Color(0.1, 0.1, 0.2, 0.85))
	draw_rect(Rect2(origin, Vector2(GAUGE_WIDTH * ratio, GAUGE_HEIGHT)), color)
	var mark_x: float = origin.x + GAUGE_WIDTH * mark
	draw_line(Vector2(mark_x, origin.y - 5.0), Vector2(mark_x, origin.y + GAUGE_HEIGHT + 5.0), COLOR_TEXT, 2.0)
	_speed_label.position = Vector2(origin.x - _speed_label.size.x - 12.0, origin.y - 5.0)
	_current_label.position = Vector2(mark_x - _current_label.size.x * 0.5, origin.y + GAUGE_HEIGHT + 4.0)
	_slow_label.position = Vector2((size.x - _slow_label.size.x) * 0.5, origin.y - 30.0)

# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

func _build_top_labels() -> void:
	_score_label = _label(30, COLOR_TEXT, Vector2(20.0, 12.0))
	_multiplier_label = _label(22, COLOR_GOLD, Vector2(22.0, 50.0))
	_sector_label = _label(15, COLOR_MUTED, Vector2.ZERO)
	_time_label = _label(22, COLOR_TEXT, Vector2.ZERO)
	_best_label = _label(14, COLOR_MUTED, Vector2.ZERO)
	for label in [_sector_label, _time_label, _best_label]:
		(label as Label).set_anchors_preset(Control.PRESET_TOP_RIGHT)
		(label as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place_right(_sector_label, 12.0)
	_place_right(_time_label, 32.0)
	_place_right(_best_label, 62.0)

func _place_right(label: Label, top: float) -> void:
	label.offset_left = -320.0
	label.offset_right = -20.0
	label.offset_top = top
	label.offset_bottom = top + 30.0

func _build_bottom_labels() -> void:
	_hull_label = _label(14, COLOR_MUTED, Vector2.ZERO)
	_purge_label = _label(14, COLOR_MUTED, Vector2.ZERO)
	for pair in [[_hull_label, -78.0], [_purge_label, -50.0]]:
		var label: Label = pair[0] as Label
		label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		label.offset_left = 20.0
		label.offset_top = float(pair[1])
		label.offset_bottom = float(pair[1]) + 22.0
	_speed_label = _label(14, COLOR_MUTED, Vector2.ZERO)
	_current_label = _label(11, COLOR_TEXT, Vector2.ZERO)
	_slow_label = _label(17, COLOR_DANGER, Vector2.ZERO)

func _build_center_labels() -> void:
	_banner_label = _centered_label(44, COLOR_GOLD, -150.0)
	_banner_sub_label = _centered_label(18, COLOR_TEXT, -96.0)
	_tip_label = _centered_label(18, COLOR_GOLD, 150.0)
	_tip_label.modulate.a = 0.0
	_void_label = _label(18, COLOR_DANGER, Vector2.ZERO)
	_void_label.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_void_label.offset_left = 26.0
	_void_label.offset_top = -12.0
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(COLOR_DANGER, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

func _centered_label(font_size: int, color: Color, offset_y: float) -> Label:
	var label: Label = _label(font_size, color, Vector2.ZERO)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -500.0
	label.offset_right = 500.0
	label.offset_top = offset_y
	label.offset_bottom = offset_y + font_size * 1.6
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _label(font_size: int, color: Color, at: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	return label

func _text(key: String) -> String:
	return str(_manager.call("t", key)) if is_instance_valid(_manager) else key

func _textf(key: String, params: Dictionary) -> String:
	return str(_manager.call("tf", key, params)) if is_instance_valid(_manager) else key

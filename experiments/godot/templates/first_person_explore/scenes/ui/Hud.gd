# =============================================================================
# Hud.gd — Crosshair, sun dial, shards, seals, tips and banners
# =============================================================================
# TOP CENTRE: an arc from 7:00 (left) to 17:00 (right) with the sun on it
#   and the hour below, the same layout as the astrolabe in hand.
# BOTTOM LEFT: sun shards found out of the total (the icon swells on each
#   new one). BOTTOM RIGHT: the three seals, outlined when missing, a ring
#   when carried, filled once set in the Dial.
# TIPS: one at a time in a panel at the bottom, queued, each shown for a
#   time that grows with its length. BANNERS: island names and big events,
#   in the upper third, fading in and out.
# =============================================================================

class_name Hud
extends Control

const SEAL_ORDER: Array[String] = ["dawn", "noon", "dusk"]
const SEAL_COLORS: Dictionary = {dawn = Color(1.0, 0.62, 0.55), noon = Color(1.0, 0.95, 0.7), dusk = Color(1.0, 0.5, 0.25)}

var sun: Sun = null
var shard_total: int = 20

var _hour_label: Label = null
var _shard_label: Label = null
var _tip_panel: PanelContainer = null
var _tip_label: Label = null
var _tip_queue: Array[String] = []
var _tip_time: float = 0.0
var _banner: VBoxContainer = null
var _banner_title: Label = null
var _banner_sub: Label = null
var _banner_time: float = 0.0
var _pop: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hour_label = UiTheme.label("", 18, UiTheme.TEXT, 6)
	_hour_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hour_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hour_label.offset_left = -80.0
	_hour_label.offset_right = 80.0
	_hour_label.offset_top = 82.0
	add_child(_hour_label)
	_shard_label = UiTheme.label("", 22, UiTheme.TEXT, 6)
	_shard_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_shard_label.offset_left = 64.0
	_shard_label.offset_top = -62.0
	_shard_label.offset_bottom = -30.0
	add_child(_shard_label)
	_tip_panel = PanelContainer.new()
	_tip_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tip_panel.offset_left = -360.0
	_tip_panel.offset_right = 360.0
	_tip_panel.offset_top = -150.0
	_tip_panel.offset_bottom = -96.0
	_tip_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.modulate.a = 0.0
	add_child(_tip_panel)
	_tip_label = UiTheme.label("", 19, UiTheme.TEXT)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.custom_minimum_size = Vector2(680.0, 0.0)
	_tip_panel.add_child(_tip_label)
	_banner = VBoxContainer.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -500.0
	_banner.offset_right = 500.0
	_banner.offset_top = 170.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner_title = UiTheme.label("", 46, UiTheme.TEXT, 10)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_sub = UiTheme.label("", 21, UiTheme.GOLD, 6)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_sub)
	GameState.shards_changed.connect(_on_shards)
	GameState.seals_changed.connect(queue_redraw)
	GameState.tip_requested.connect(_on_tip)
	GameState.banner_requested.connect(_on_banner)
	_on_shards(GameState.shards.size())

func reset() -> void:
	_tip_queue.clear()
	_tip_time = 0.0
	_tip_panel.modulate.a = 0.0
	_banner_time = 0.0
	_banner.modulate.a = 0.0

func _on_shards(count: int) -> void:
	_shard_label.text = StringManager.t("hud_shards", {n = count, total = shard_total})
	if visible and count > 0:
		_pop = 1.0

func _on_tip(key: String) -> void:
	_tip_queue.append(UiTheme.keys(StringManager.t(key)))
	if _tip_time <= 0.0:
		_next_tip()

func _next_tip() -> void:
	if _tip_queue.is_empty():
		return
	_tip_label.text = _tip_queue.pop_front()
	_tip_time = 3.5 + _tip_label.text.length() * 0.045
	Sfx.play("tip")

func _on_banner(title: String, subtitle: String) -> void:
	_banner_title.text = title
	_banner_sub.text = subtitle
	_banner_sub.visible = subtitle != ""
	_banner_time = 3.2

func _process(delta: float) -> void:
	if _tip_time > 0.0:
		_tip_time -= delta
		_tip_panel.modulate.a = clampf(minf(_tip_time * 2.0, 1.0), 0.0, 1.0) if _tip_time < 0.5 else move_toward(_tip_panel.modulate.a, 1.0, delta * 4.0)
		if _tip_time <= 0.0:
			_tip_panel.modulate.a = 0.0
			_next_tip()
	if _banner_time > 0.0:
		_banner_time -= delta
		_banner.modulate.a = clampf(_banner_time / 0.6, 0.0, 1.0) if _banner_time < 0.6 else move_toward(_banner.modulate.a, 1.0, delta * 3.0)
	_pop = maxf(_pop - delta * 2.5, 0.0)
	if sun != null:
		_hour_label.text = UiTheme.hour_text(sun.hour)
	queue_redraw()

func _arc_point(centre: Vector2, radius: float, h: float) -> Vector2:
	var a: float = (h - 12.0) / 5.0 * deg_to_rad(75.0)
	return centre + Vector2(sin(a), -cos(a)) * radius

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var c := Vector2(w * 0.5, h * 0.5)
	draw_circle(c, 3.5, Color(0.0, 0.0, 0.0, 0.45))
	draw_circle(c, 2.0, Color(1.0, 0.97, 0.9, 0.9))
	if sun == null:
		return
	var dial := Vector2(w * 0.5, 84.0)
	var radius: float = 58.0
	var pts := PackedVector2Array()
	for i in 41:
		pts.append(_arc_point(dial, radius, 7.0 + 10.0 * i / 40.0))
	draw_polyline(pts, Color(0.0, 0.0, 0.0, 0.35), 5.0, true)
	draw_polyline(pts, Color(1.0, 0.9, 0.7, 0.75), 2.0, true)
	for hr in range(7, 18):
		var outer: Vector2 = _arc_point(dial, radius + (7.0 if hr % 5 == 2 else 4.0), float(hr))
		var inner: Vector2 = _arc_point(dial, radius - 4.0, float(hr))
		draw_line(inner, outer, Color(1.0, 0.9, 0.7, 0.8), 2.0)
	var sp: Vector2 = _arc_point(dial, radius, clampf(sun.hour, 7.0, 17.0))
	var glow: float = clampf(absf(sun.speed), 0.0, 1.0)
	draw_circle(sp, 14.0 + glow * 6.0, Color(1.0, 0.75, 0.3, 0.18 + glow * 0.15))
	draw_circle(sp, 8.0, Color(1.0, 0.82, 0.4))
	draw_circle(sp, 4.5, Color(1.0, 0.97, 0.85))
	var icon := Vector2(42.0, h - 46.0)
	var s: float = 13.0 * (1.0 + _pop * 0.6)
	var diamond := PackedVector2Array([icon + Vector2(0.0, -s), icon + Vector2(s * 0.7, 0.0), icon + Vector2(0.0, s), icon + Vector2(-s * 0.7, 0.0)])
	draw_colored_polygon(diamond, Color(1.0, 0.8, 0.35))
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color(0.3, 0.18, 0.05, 0.8), 2.0)
	for i in SEAL_ORDER.size():
		var id: String = SEAL_ORDER[i]
		var p := Vector2(w - 140.0 + i * 46.0, h - 46.0)
		var col: Color = SEAL_COLORS[id]
		if GameState.seals_placed.has(id):
			draw_circle(p, 15.0, col)
			draw_arc(p, 15.0, 0.0, TAU, 32, Color(0.2, 0.12, 0.05, 0.8), 2.0)
		elif GameState.seals_taken.has(id):
			draw_arc(p, 13.0, 0.0, TAU, 32, col, 5.0)
		else:
			draw_arc(p, 13.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.3), 2.0)

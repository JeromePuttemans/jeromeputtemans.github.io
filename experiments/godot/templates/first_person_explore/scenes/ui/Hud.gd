# =============================================================================
# Hud.gd: Reticle, sun arc, clock, splits, shards, seals, tips and banners
# =============================================================================
# Drawn like an architect's sheet: graphite lines, one accent colour.
# TOP CENTRE: an arc from 7:00 (left) to 17:00 (right) with the sun on it
#   and the hour below, the same layout as the dial in hand.
# TOP RIGHT: the run clock to the tenth of a second; on the first arrival
#   on a platform, its name, the time, and the gap with the best run.
# CENTRE: the reticle, flanked by two short strokes while the dash is
#   ready (they flash on refill), and speed lines at the edges of the
#   screen during dashes and launches.
# BOTTOM LEFT: sun shards found out of the total (the mark swells on each
#   new one). BOTTOM RIGHT: the three seals, circle, square and triangle,
#   outlined when missing, accent outline when carried, filled once set.
# TIPS: one at a time on a paper strip at the bottom, queued, each shown for
#   a time that grows with its length. BANNERS: platform names with their
#   level mark, and big events, on a white title block in the upper third.
# =============================================================================

class_name Hud
extends Control

const SEAL_ORDER: Array[String] = ["dawn", "noon", "dusk"]

var sun: Sun = null
var player: Player = null
var shard_total: int = 30

var _hour_label: Label = null
var _clock_label: Label = null
var _split_label: Label = null
var _split_delta: Label = null
var _split_time: float = 0.0
var _shard_label: Label = null
var _tip_panel: PanelContainer = null
var _tip_label: Label = null
var _tip_queue: Array[String] = []
var _tip_time: float = 0.0
var _banner: VBoxContainer = null
var _banner_card: PanelContainer = null
var _banner_title: Label = null
var _banner_sub: Label = null
var _banner_time: float = 0.0
var _pop: float = 0.0
var _refill_flash: float = 0.0
var _speed_fx: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hour_label = UiTheme.label("", 15, UiTheme.INK, 0, 3)
	_hour_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hour_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hour_label.offset_left = -80.0
	_hour_label.offset_right = 80.0
	_hour_label.offset_top = 64.0
	add_child(_hour_label)
	_clock_label = UiTheme.label("", 20, UiTheme.INK, 0, 2)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_clock_label.offset_left = -260.0
	_clock_label.offset_right = -40.0
	_clock_label.offset_top = 30.0
	add_child(_clock_label)
	_split_label = UiTheme.label("", 13, UiTheme.MUTED, 0, 3)
	_split_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_split_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_split_label.offset_left = -360.0
	_split_label.offset_right = -40.0
	_split_label.offset_top = 62.0
	add_child(_split_label)
	_split_delta = UiTheme.label("", 17, UiTheme.INK, 0, 2)
	_split_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_split_delta.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_split_delta.offset_left = -360.0
	_split_delta.offset_right = -40.0
	_split_delta.offset_top = 82.0
	add_child(_split_delta)
	_shard_label = UiTheme.label("", 18, UiTheme.INK, 0, 2)
	_shard_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_shard_label.offset_left = 66.0
	_shard_label.offset_top = -58.0
	_shard_label.offset_bottom = -32.0
	add_child(_shard_label)
	_tip_panel = PanelContainer.new()
	_tip_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tip_panel.offset_left = -360.0
	_tip_panel.offset_right = 360.0
	_tip_panel.offset_top = -140.0
	_tip_panel.offset_bottom = -92.0
	_tip_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.modulate.a = 0.0
	var strip := UiTheme.box(UiTheme.PAPER, UiTheme.FAINT, 18)
	strip.border_color = UiTheme.ACCENT
	strip.border_width_left = 3
	strip.border_width_top = 0
	strip.border_width_right = 0
	strip.border_width_bottom = 0
	_tip_panel.add_theme_stylebox_override("panel", strip)
	add_child(_tip_panel)
	_tip_label = UiTheme.label("", 17, UiTheme.INK)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(660.0, 0.0)
	_tip_panel.add_child(_tip_label)
	# the banner is a title block on a white card, readable over any stone
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	holder.offset_left = -500.0
	holder.offset_right = 500.0
	holder.offset_top = 150.0
	holder.offset_bottom = 290.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_banner_card = PanelContainer.new()
	_banner_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_card.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.PAPER.r, UiTheme.PAPER.g, UiTheme.PAPER.b, 0.88), UiTheme.FAINT, 22))
	_banner_card.modulate.a = 0.0
	holder.add_child(_banner_card)
	_banner = VBoxContainer.new()
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_theme_constant_override("separation", 10)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_card.add_child(_banner)
	_banner_title = UiTheme.label("", 34, UiTheme.INK, 0, 10)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	var line := UiTheme.rule(90.0, UiTheme.ACCENT, 2.0)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner.add_child(line)
	_banner_sub = UiTheme.label("", 13, UiTheme.MUTED, 0, 4)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_sub)
	GameState.shards_changed.connect(_on_shards)
	GameState.seals_changed.connect(queue_redraw)
	GameState.tip_requested.connect(_on_tip)
	GameState.banner_requested.connect(_on_banner)
	GameState.split_reached.connect(_on_split)
	_on_shards(GameState.shards.size())

func reset() -> void:
	_tip_queue.clear()
	_tip_time = 0.0
	_tip_panel.modulate.a = 0.0
	_banner_time = 0.0
	_banner_card.modulate.a = 0.0
	_split_time = 0.0
	_split_label.modulate.a = 0.0
	_split_delta.modulate.a = 0.0

func flash_refill() -> void:
	_refill_flash = 1.0

func _on_shards(count: int) -> void:
	_shard_label.text = StringManager.t("hud_shards", {n = "%02d" % count, total = shard_total})
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
	_banner_title.text = title.to_upper()
	_banner_sub.text = subtitle.to_upper()
	_banner_sub.visible = subtitle != ""
	_banner_time = 2.8

## First arrival on a platform: its name, the time, the gap with the best.
func _on_split(island: String, time: float) -> void:
	_split_label.text = StringManager.t("island_" + island).to_upper() + "   " + GameState.format_precise(time)
	var best: float = SaveManager.best_split(island)
	if best >= 0.0:
		var gap: float = time - best
		_split_delta.text = GameState.format_delta(gap)
		_split_delta.add_theme_color_override("font_color", UiTheme.ACCENT if gap < 0.0 else UiTheme.MUTED)
	else:
		_split_delta.text = ""
	_split_time = 3.5

func _process(delta: float) -> void:
	_time += delta
	if _tip_time > 0.0:
		_tip_time -= delta
		_tip_panel.modulate.a = clampf(minf(_tip_time * 2.0, 1.0), 0.0, 1.0) if _tip_time < 0.5 else move_toward(_tip_panel.modulate.a, 1.0, delta * 4.0)
		if _tip_time <= 0.0:
			_tip_panel.modulate.a = 0.0
			_next_tip()
	if _banner_time > 0.0:
		_banner_time -= delta
		_banner_card.modulate.a = clampf(_banner_time / 0.6, 0.0, 1.0) if _banner_time < 0.6 else move_toward(_banner_card.modulate.a, 1.0, delta * 3.0)
	_split_time = maxf(_split_time - delta, 0.0)
	var split_alpha: float = clampf(_split_time / 0.5, 0.0, 1.0)
	_split_label.modulate.a = split_alpha
	_split_delta.modulate.a = split_alpha
	_pop = maxf(_pop - delta * 2.5, 0.0)
	_refill_flash = maxf(_refill_flash - delta * 3.0, 0.0)
	if sun != null:
		_hour_label.text = UiTheme.hour_text(sun.hour)
	_clock_label.text = GameState.format_precise(GameState.time)
	var fx: float = 0.0
	if player != null:
		var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
		fx = 1.0 if player.dashing else clampf((speed - 9.5) / 5.0, 0.0, 1.0)
	_speed_fx = lerpf(_speed_fx, fx, 1.0 - exp(-12.0 * delta))
	queue_redraw()

func _arc_point(centre: Vector2, radius: float, h: float) -> Vector2:
	var a: float = (h - 12.0) / 5.0 * deg_to_rad(75.0)
	return centre + Vector2(sin(a), -cos(a)) * radius

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var c := Vector2(w * 0.5, h * 0.5)
	var ink: Color = UiTheme.INK
	var halo: Color = UiTheme.HALO
	_draw_speed_lines(c, w, h)
	draw_circle(c, 3.2, halo)
	draw_circle(c, 1.8, ink)
	if player != null:
		var dash_on: bool = player.dash_ready
		var col: Color = UiTheme.ACCENT.lerp(ink, 1.0 - _refill_flash) if dash_on else Color(ink.r, ink.g, ink.b, 0.18)
		for side in [-1.0, 1.0]:
			var a := c + Vector2(side * 9.0, 0.0)
			var b := c + Vector2(side * 17.0, 0.0)
			draw_line(a, b, halo, 3.5)
			draw_line(a, b, col, 1.6)
	if sun == null:
		return
	var dial := Vector2(w * 0.5, 64.0)
	var radius: float = 40.0
	var pts := PackedVector2Array()
	for i in 41:
		pts.append(_arc_point(dial, radius, 7.0 + 10.0 * i / 40.0))
	draw_polyline(pts, halo, 3.5, true)
	draw_polyline(pts, ink, 1.2, true)
	for hr in range(7, 18):
		var outer: Vector2 = _arc_point(dial, radius + (6.0 if hr % 5 == 2 else 3.0), float(hr))
		var inner: Vector2 = _arc_point(dial, radius, float(hr))
		draw_line(inner, outer, ink, 1.2)
	var sp: Vector2 = _arc_point(dial, radius, clampf(sun.hour, 7.0, 17.0))
	var glow: float = clampf(absf(sun.speed), 0.0, 1.0)
	draw_circle(sp, 7.5 + glow * 3.0, halo)
	draw_circle(sp, 5.5, UiTheme.ACCENT)
	if glow > 0.05:
		draw_arc(sp, 9.0 + glow * 4.0, 0.0, TAU, 32, Color(UiTheme.ACCENT.r, UiTheme.ACCENT.g, UiTheme.ACCENT.b, glow * 0.8), 1.2, true)
	var icon := Vector2(44.0, h - 45.0)
	var s: float = 9.0 * (1.0 + _pop * 0.6)
	var diamond := PackedVector2Array([icon + Vector2(0.0, -s * 1.3), icon + Vector2(s, 0.0), icon + Vector2(0.0, s * 1.3), icon + Vector2(-s, 0.0)])
	draw_colored_polygon(diamond, UiTheme.ACCENT)
	for i in SEAL_ORDER.size():
		var id: String = SEAL_ORDER[i]
		var p := Vector2(w - 150.0 + i * 46.0, h - 45.0)
		var state: int = 2 if GameState.seals_placed.has(id) else (1 if GameState.seals_taken.has(id) else 0)
		_draw_seal(id, p, 12.0, state)

## Seal mark: 0 missing (faint outline), 1 carried (accent outline), 2 set
## (filled).
func _draw_seal(id: String, p: Vector2, r: float, state: int) -> void:
	var col: Color = UiTheme.ACCENT if state > 0 else Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.35)
	var width: float = 2.0 if state == 1 else 1.2
	var shape := PackedVector2Array()
	match id:
		"dawn":
			if state == 2:
				draw_circle(p, r, col)
			else:
				draw_arc(p, r, 0.0, TAU, 40, col, width, true)
			return
		"noon":
			var k: float = r * 0.88
			shape = PackedVector2Array([p + Vector2(-k, -k), p + Vector2(k, -k), p + Vector2(k, k), p + Vector2(-k, k)])
		_:
			shape = PackedVector2Array([p + Vector2(0.0, -r * 1.05), p + Vector2(r, r * 0.75), p + Vector2(-r, r * 0.75)])
	if state == 2:
		draw_colored_polygon(shape, col)
	else:
		draw_polyline(shape + PackedVector2Array([shape[0]]), col, width, true)

## Thin graphite lines streaming in from the edges at high speed.
func _draw_speed_lines(c: Vector2, w: float, h: float) -> void:
	if _speed_fx < 0.02:
		return
	var count: int = 26
	for i in count:
		var a: float = TAU * (float(i) + 0.37 * sin(i * 12.9)) / count
		var dir := Vector2(cos(a), sin(a))
		var far: float = maxf(w, h) * 0.75
		var phase: float = fposmod(_time * 3.0 + i * 0.37, 1.0)
		var start: float = lerpf(far, far * 0.55, phase)
		var length: float = far * 0.12 * _speed_fx
		var col := Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.22 * _speed_fx * (1.0 - phase))
		draw_line(c + dir * start, c + dir * (start - length), col, 1.4)

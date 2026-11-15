extends Control

# HUD (CanvasLayer 2, over the distortion shader, so it never bends).
#   TOP LEFT      score (rolls toward the real value), the last gains in
#                 gold, the multiplier badge: its ring is the chain timer,
#                 it swells when the multiplier goes up
#   TOP CENTRE    sector, one pip per sector (boss sectors are hexagons),
#                 a progress bar of the sector and the enemies left; during
#                 a boss fight its name and a segmented health bar (one
#                 notch per phase, a white ghost bar trails the damage)
#   TOP RIGHT     hull: one small ship per point, the last one pulses red
#   BOTTOM        FLUX and NOVA gauges, the orbit count; the Nova gauge
#                 glows and names its key when full
#   BOTTOM LEFT   the upgrades taken this run, with their level
#   BANNER        big centred title with optional subtitle lines: sector
#                 start, boss warning, phase change, sector cleared
# The flux and the orbit are also drawn around the ship itself
# (gravity_field.gd), where the eyes are during a fight.

var gm: Node = null
var _score_shown: float = 0.0
var _time: float = 0.0
var _last_mult: int = 1
var _mult_pop: float = 0.0
var _last_hp: int = 3
var _hp_pop: float = 0.0
var _boss_ghost: float = 1.0
var _boss_hit: float = 0.0
var _boss_last: float = 1.0
var _nova_was_ready: bool = false
var _nova_pop: float = 0.0
var _banner: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Connected to game_manager.game_state_changed: shown while a run is on.
func on_state_changed(state: int) -> void:
	visible = state == 1 or state == 2 or state == 3
	if state == 0:
		_banner.clear()
		_score_shown = 0.0

## Big centred title for `life` seconds (subtitle and line may be empty).
func banner(title: String, subtitle: String, line: String, color: Color, life: float) -> void:
	_banner = {title = title, subtitle = subtitle, line = line, color = color, life = life, max = life}

func _process(delta: float) -> void:
	_time += delta
	var target: float = float(gm.get("score"))
	_score_shown = lerpf(_score_shown, target, minf(delta * 9.0, 1.0))
	if absf(_score_shown - target) < 1.0:
		_score_shown = target
	var mult: int = int(gm.call("multiplier"))
	if mult > _last_mult:
		_mult_pop = 1.0
	_last_mult = mult
	_mult_pop = maxf(_mult_pop - delta * 3.0, 0.0)
	var hp: int = int(gm.call("ship_hp"))
	if hp != _last_hp:
		_hp_pop = 1.0
	_last_hp = hp
	_hp_pop = maxf(_hp_pop - delta * 2.5, 0.0)
	var well: GravityField = gm.call("well_node") as GravityField
	if well.nova_ready() and not _nova_was_ready:
		_nova_pop = 1.0
	_nova_was_ready = well.nova_ready()
	_nova_pop = maxf(_nova_pop - delta * 2.0, 0.0)
	var b: Node2D = gm.get("boss") as Node2D
	if b != null and is_instance_valid(b):
		var ratio: float = float(b.get("hp")) / float(b.get("max_hp"))
		if ratio < _boss_last - 0.0005:
			_boss_hit = 1.0
		_boss_last = ratio
		_boss_ghost = maxf(move_toward(_boss_ghost, ratio, delta * 0.25), ratio)
	else:
		_boss_ghost = 1.0
		_boss_last = 1.0
	_boss_hit = maxf(_boss_hit - delta * 6.0, 0.0)
	if not _banner.is_empty():
		_banner["life"] = float(_banner["life"]) - delta
		if float(_banner["life"]) <= 0.0:
			_banner.clear()
	queue_redraw()

func _tx(section: String, key: String, rep: Dictionary = {}) -> String:
	return gm.call("text", section, key, rep) as String

func _draw() -> void:
	_draw_score()
	_draw_sector()
	_draw_hull()
	_draw_gauges()
	_draw_upgrades()
	_draw_banner()

func _draw_score() -> void:
	UiKit.panel(self, Rect2(14.0, 12.0, 250.0, 118.0), Color(UiKit.CYAN, 0.25))
	UiKit.text(self, Vector2(30.0, 36.0), _tx("gameplay", "score"), 13, UiKit.DIM, 0.0, UiKit.bold(), 3)
	var value: String = str(int(_score_shown))
	UiKit.text(self, Vector2(30.0, 74.0), value, 34, Color.WHITE, 0.0, UiKit.heavy(), 5)
	var gains: Array = gm.get("gains") as Array
	var x: float = 38.0 + UiKit.width(value, 34, UiKit.heavy())
	for i in range(gains.size() - 1, maxi(gains.size() - 3, 0) - 1, -1):
		var g: Dictionary = gains[i] as Dictionary
		var t: float = float(g["t"])
		var alpha: float = clampf(1.0 - (t - 0.8) / 0.8, 0.0, 1.0)
		var row: int = gains.size() - 1 - i
		UiKit.text(self, Vector2(x, 60.0 - row * 15.0 - t * 6.0), "+" + str(int(g["v"])), 13 if row == 0 else 11, Color(UiKit.GOLD, alpha * (1.0 if row == 0 else 0.6)), 0.0, UiKit.bold(), 3)
	var mult: int = int(gm.call("multiplier"))
	var mmax: int = int((gm.get("gameplay") as Dictionary).get("multiplier_max", 8))
	var heat: float = clampf((mult - 1) / float(maxi(mmax - 1, 1)), 0.0, 1.0)
	var mc: Color = UiKit.CYAN.lerp(Color(1.0, 0.45, 0.9), heat)
	var c := Vector2(50.0, 106.0)
	var r: float = 17.0 * (1.0 + 0.35 * _mult_pop)
	if mult > 1:
		Effects.put(self, c, r * 2.2, Color(mc, 0.25 + 0.3 * _mult_pop))
	draw_circle(c, r, Color(0.02, 0.04, 0.12, 0.95))
	draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * float(gm.call("chain_ratio")), 32, mc, 3.0)
	UiKit.text(self, c + Vector2(0.0, 6.0), _tx("gameplay", "multiplier", {n = mult}), 16, mc, 0.5, UiKit.heavy(), 3)
	var chain: int = int(gm.get("chain"))
	if chain > 0:
		UiKit.text(self, Vector2(78.0, 111.0), _tx("gameplay", "chain", {n = chain}), 13, Color(mc, 0.85), 0.0, UiKit.bold(), 3)

func _draw_sector() -> void:
	var cx: float = size.x * 0.5
	var wave: int = int(gm.get("wave_number"))
	var total: int = int(gm.call("total_waves"))
	UiKit.text(self, Vector2(cx, 34.0), _tx("gameplay", "sector", {n = wave, total = total}), 20, UiKit.CYAN, 0.5, UiKit.heavy(), 4)
	var spacing: float = 22.0
	var x0: float = cx - (total - 1) * spacing * 0.5
	for i in total:
		var p := Vector2(x0 + i * spacing, 50.0)
		var n: int = i + 1
		var col: Color = Color(0.2, 0.28, 0.5)
		if n < wave:
			col = UiKit.CYAN
		elif n == wave:
			col = Color(1.0, 1.0, 1.0, 0.6 + 0.4 * sin(_time * 5.0))
		if bool(gm.call("is_boss_wave", n)):
			var pts := PackedVector2Array()
			for k in 7:
				pts.append(p + Vector2.RIGHT.rotated(TAU * k / 6.0) * 6.0)
			if n < wave:
				draw_colored_polygon(pts.slice(0, 6), Color(1.0, 0.45, 0.7))
			draw_polyline(pts, Color(1.0, 0.45, 0.7) if n >= wave else col, 1.5)
		else:
			var d: float = 4.0 if n != wave else 5.0
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)]), col)
	var b: Node2D = gm.get("boss") as Node2D
	if b != null and is_instance_valid(b) and bool(b.get("alive")) and bool(b.get("entered")):
		_draw_boss_bar(b, cx)
		return
	var bar := Rect2(cx - 120.0, 64.0, 240.0, 4.0)
	UiKit.bar(self, bar, float(gm.call("sector_progress")), Color(UiKit.CYAN, 0.8))
	UiKit.text(self, Vector2(cx, 88.0), _tx("gameplay", "enemies_left", {n = gm.call("enemies_left")}), 13, UiKit.DIM, 0.5, UiKit.bold(), 3)

func _draw_boss_bar(b: Node2D, cx: float) -> void:
	var kind: String = str(b.get("kind"))
	var ratio: float = clampf(float(b.get("hp")) / float(b.get("max_hp")), 0.0, 1.0)
	var bar := Rect2(cx - 290.0, 80.0, 580.0, 12.0)
	var shake: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 3.0 * _boss_hit
	bar.position += shake
	UiKit.panel(self, Rect2(bar.position - Vector2(14.0, 22.0), bar.size + Vector2(28.0, 34.0)), Color(1.0, 0.45, 0.8, 0.35), Color(0.06, 0.01, 0.07, 0.75))
	UiKit.text(self, Vector2(cx, bar.position.y - 6.0) + shake, _tx("gameplay", "boss_" + kind), 15, Color(1.0, 0.65, 0.9), 0.5, UiKit.heavy(), 3)
	draw_rect(bar.grow(2.0), Color(0.0, 0.0, 0.03, 0.9))
	draw_rect(bar, Color(0.18, 0.04, 0.16))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _boss_ghost, bar.size.y)), Color(1.0, 0.95, 1.0, 0.75))
	var fill: Color = Color(1.0, 0.35, 0.8).lerp(Color.WHITE, _boss_hit * 0.6)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, 4.0)), Color(1.0, 1.0, 1.0, 0.25))
	var notches: Array = [0.5] if kind == "guardian" else [0.33, 0.66]
	for n in notches:
		var x: float = bar.position.x + bar.size.x * float(n)
		draw_line(Vector2(x, bar.position.y - 4.0), Vector2(x, bar.end.y + 4.0), Color(0.0, 0.0, 0.05, 0.9), 3.0)
		draw_line(Vector2(x, bar.position.y - 4.0), Vector2(x, bar.end.y + 4.0), Color(1.0, 0.8, 0.95, 0.8), 1.0)

func _draw_hull() -> void:
	var hp: int = int(gm.call("ship_hp"))
	var hp_max: int = int(gm.call("ship_hp_max"))
	var w: float = maxf(150.0, 30.0 + hp_max * 28.0)
	var r := Rect2(size.x - 14.0 - w, 12.0, w, 62.0)
	var danger: bool = hp == 1
	UiKit.panel(self, r, Color(UiKit.DANGER, 0.5) if danger else Color(UiKit.CYAN, 0.25))
	UiKit.text(self, Vector2(r.end.x - 16.0, 34.0), _tx("gameplay", "hull"), 13, UiKit.DANGER if danger else UiKit.DIM, 1.0, UiKit.bold(), 3)
	for i in hp_max:
		var at := Vector2(r.end.x - 26.0 - (hp_max - 1 - i) * 28.0, 54.0)
		var full: bool = i < hp
		var col: Color = UiKit.CYAN if full else Color(0.15, 0.2, 0.35)
		var s: float = 1.0
		if full and danger:
			col = UiKit.DANGER.lerp(Color.WHITE, 0.3 * (0.5 + 0.5 * sin(_time * 8.0)))
			s = 1.0 + 0.12 * (0.5 + 0.5 * sin(_time * 8.0))
		if i == hp and _hp_pop > 0.0:
			s += _hp_pop * 0.6
			col = col.lerp(Color(1.0, 0.4, 0.4), _hp_pop)
		var pts := PackedVector2Array([at + Vector2(0, -10) * s, at + Vector2(9, 8) * s, at + Vector2(0, 4) * s, at + Vector2(-9, 8) * s])
		if full:
			draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, col, 1.5)

func _draw_gauges() -> void:
	var well: GravityField = gm.call("well_node") as GravityField
	var y: float = size.y - 30.0
	var x0: float = size.x * 0.5 - 256.0
	UiKit.panel(self, Rect2(x0 - 16.0, y - 32.0, 544.0, 52.0), Color(UiKit.CYAN, 0.2))
	var flux: float = float(well.flux) / float(well.flux_max)
	var fc: Color = UiKit.CYAN.lerp(Color(1.0, 0.35, 0.35), clampf(1.0 - flux * 2.0, 0.0, 1.0))
	if well.nova_active():
		fc = GravityField.NOVA_COLOR
		flux = 1.0
	var flux_bar := Rect2(x0, y, 290.0, 9.0)
	UiKit.bar(self, flux_bar, flux, fc, 10)
	UiKit.text(self, Vector2(flux_bar.position.x, y - 8.0), _tx("gameplay", "flux"), 13, UiKit.DIM, 0.0, UiKit.bold(), 3)
	var orbit_text: String = _tx("gameplay", "orbit", {n = well.orbit_count(), max = well.current_capacity()})
	UiKit.text(self, Vector2(flux_bar.end.x, y - 8.0), orbit_text, 13, UiKit.PALE if well.orbit_count() > 0 else UiKit.DIM, 1.0, UiKit.bold(), 3)
	var nova_bar := Rect2(x0 + 314.0, y, 198.0, 9.0)
	var nc: Color = GravityField.NOVA_COLOR
	var ratio: float = well.nova_ratio()
	var label: String = _tx("gameplay", "nova")
	var label_color: Color = UiKit.DIM
	if well.nova_active():
		ratio = well.nova_left()
		nc = Color.WHITE
	elif well.nova_ready():
		var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
		nc = GravityField.NOVA_COLOR.lerp(Color.WHITE, 0.4 * pulse)
		Effects.put(self, nova_bar.get_center(), 120.0 * (1.0 + _nova_pop * 0.5), Color(0.6, 0.45, 1.0, 0.18 + 0.12 * pulse + 0.3 * _nova_pop))
		label = _tx("gameplay", "nova_ready")
		label_color = Color(0.9, 0.82, 1.0)
	UiKit.bar(self, nova_bar, ratio, nc, 4)
	UiKit.text(self, Vector2(nova_bar.position.x, y - 8.0), label, 13, label_color, 0.0, UiKit.bold(), 3)

func _draw_upgrades() -> void:
	var levels: Dictionary = gm.get("levels") as Dictionary
	if levels.is_empty():
		return
	var x: float = 30.0
	var y: float = size.y - 34.0
	for id in levels:
		var lv: int = int(levels[id])
		Effects.put(self, Vector2(x, y), 22.0, Color(0.2, 0.6, 1.0, 0.15))
		UiKit.upgrade_icon(self, str(id), Vector2(x, y), 0.32, UiKit.CYAN, _time)
		for k in lv:
			draw_circle(Vector2(x - (lv - 1) * 3.5 + k * 7.0, y + 17.0), 2.2, UiKit.GOLD)
		x += 34.0

func _draw_banner() -> void:
	if _banner.is_empty():
		return
	var life: float = float(_banner["life"])
	var total: float = float(_banner["max"])
	var age: float = total - life
	var appear: float = ease(clampf(age / 0.25, 0.0, 1.0), 0.4)
	var alpha: float = minf(appear, clampf(life / 0.4, 0.0, 1.0))
	var c: Color = _banner["color"] as Color
	var cx: float = size.x * 0.5
	var y: float = 250.0
	var title: String = str(_banner["title"])
	var spread: float = (1.0 - appear) * 18.0
	var tw: float = UiKit.width(title, 46, UiKit.heavy()) + spread * title.length()
	var line_w: float = (tw * 0.5 + 60.0) * appear
	draw_line(Vector2(cx - line_w, y + 14.0), Vector2(cx + line_w, y + 14.0), Color(c, 0.6 * alpha), 2.0)
	Effects.put(self, Vector2(cx, y - 14.0), tw * 0.6, Color(c, 0.12 * alpha))
	var x: float = cx - tw * 0.5
	for i in title.length():
		var ch: String = title[i]
		UiKit.text(self, Vector2(x, y), ch, 46, Color(c, alpha), 0.0, UiKit.heavy(), 7)
		x += UiKit.width(ch, 46, UiKit.heavy()) + spread
	var sub: String = str(_banner["subtitle"])
	if not sub.is_empty():
		UiKit.text(self, Vector2(cx, y + 50.0), sub, 28, Color(1.0, 1.0, 1.0, alpha), 0.5, UiKit.heavy(), 5)
	var line: String = str(_banner["line"])
	if not line.is_empty():
		var ly: float = y + (86.0 if not sub.is_empty() else 46.0)
		for row in UiKit.wrap(line, 760.0, 18, UiKit.bold()):
			UiKit.text(self, Vector2(cx, ly), row, 18, Color(UiKit.PALE, alpha), 0.5, UiKit.bold(), 4)
			ly += 26.0

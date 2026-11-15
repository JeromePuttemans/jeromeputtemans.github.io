extends Control

# Screens (CanvasLayer 3): title menu, help page, pause, upgrade choice and
# end of run, drawn over the bending grid. Keyboard and pad go through
# game_manager (menus, upgrade keys); the mouse is handled here: hovering a
# menu line or a card selects it, a click confirms it, a click on the help
# page closes it.
#   TITLE    the logo with bullets orbiting around it, the tagline, the
#            menu (play, help, language, sound effects, music), best score
#   HELP     four panels, each with a looping mini animation drawn by code
#            (capture, send back, throw, Nova), the heavy orb rule and the
#            controls
#   PAUSE    resume or give up, and the upgrades taken so far
#   UPGRADE  the sector report, three cards (icon, name, level pips,
#            description) rising one after the other; the chosen card then
#            flies to the HUD's upgrade row
#   END      the title lands, the score counts up, the rank is stamped, the
#            statistics appear line by line, then the menu
# Each screen animates in from the moment its state starts (_since).

var gm: Node = null
var _time: float = 0.0
var _since: float = 0.0
var _cards: Array[Rect2] = []
var _menu_rects: Array[Rect2] = []
var _chosen: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Connected to game_manager.game_state_changed.
func on_state_changed(state: int) -> void:
	_since = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE if state == 1 else Control.MOUSE_FILTER_STOP

## The upgrade card `index` was picked: keep it for the fly-away animation.
func on_chosen(index: int) -> void:
	if index < _cards.size():
		_chosen = {id = str((gm.get("offer") as Array)[index]), rect = _cards[index], t = 0.0}

func _process(delta: float) -> void:
	_time += delta
	_since += delta
	if not _chosen.is_empty():
		_chosen["t"] = float(_chosen["t"]) + delta
		if float(_chosen["t"]) > 0.6:
			_chosen.clear()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var state: int = int(gm.get("current_state"))
	if event is InputEventMouseMotion:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		if state == 3:
			for i in _cards.size():
				if _cards[i].has_point(pos) and int(gm.get("offer_index")) != i:
					gm.set("offer_index", i)
					gm.call("sfx", "ui_move", 1.0, 0.0)
		for i in _menu_rects.size():
			if _menu_rects[i].has_point(pos):
				gm.call("menu_hover", i)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = (event as InputEventMouseButton).position
		if state == 0 and bool(gm.get("help_open")):
			gm.call("close_help")
			accept_event()
			return
		if state == 3:
			for i in _cards.size():
				if _cards[i].has_point(at):
					gm.call("choose_from_click", i)
					accept_event()
					return
		for i in _menu_rects.size():
			if _menu_rects[i].has_point(at):
				gm.call("menu_click", i)
				accept_event()
				return

func _tx(section: String, key: String, rep: Dictionary = {}) -> String:
	return gm.call("text", section, key, rep) as String

func _veil(alpha: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.05, alpha))

func _draw() -> void:
	_cards.clear()
	_menu_rects.clear()
	match int(gm.get("current_state")):
		0:
			if bool(gm.get("help_open")):
				_draw_help()
			else:
				_draw_title()
		2:
			_draw_pause()
		3:
			_draw_upgrades()
		4, 5:
			_draw_end(int(gm.get("current_state")) == 5)
	if not _chosen.is_empty():
		_draw_chosen()

# =============================================================================
# MENU
# =============================================================================

func _draw_menu(top: float, spacing: float, font_size: int) -> void:
	var items: Array = gm.call("menu_items") as Array
	var selected: int = int(gm.get("menu_index"))
	var cx: float = size.x * 0.5
	for i in items.size():
		var label: String = gm.call("menu_label", str(items[i])) as String
		var y: float = top + i * spacing
		var w: float = maxf(UiKit.width(label, font_size, UiKit.heavy()) + 80.0, 300.0)
		var r := Rect2(cx - w * 0.5, y - font_size - 6.0, w, font_size + 18.0)
		_menu_rects.append(r)
		var appear: float = ease(clampf((_since - 0.05 * i) * 5.0, 0.0, 1.0), 0.4)
		var on: bool = i == selected
		var c: Color = Color(UiKit.CYAN, appear) if on else Color(UiKit.DIM, appear * 0.9)
		if on:
			var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
			UiKit.panel(self, r, Color(UiKit.CYAN, 0.6 * appear), Color(0.05, 0.16, 0.3, 0.6 * appear), 8.0)
			Effects.put(self, r.get_center(), w * 0.45, Color(0.2, 0.6, 1.0, 0.12 * appear))
			var off: float = 6.0 * pulse
			UiKit.text(self, Vector2(r.position.x + 18.0 - off, y), ">", font_size, c, 0.0, UiKit.heavy(), 3)
			UiKit.text(self, Vector2(r.end.x - 18.0 + off, y), "<", font_size, c, 1.0, UiKit.heavy(), 3)
		UiKit.text(self, Vector2(cx + (1.0 - appear) * 40.0, y), label, font_size, Color.WHITE.lerp(c, 0.25) if on else c, 0.5, UiKit.heavy() if on else UiKit.bold(), 4)

# =============================================================================
# TITLE AND HELP
# =============================================================================

func _draw_title() -> void:
	_veil(0.3)
	var cx: float = size.x * 0.5
	var title: String = _tx("ui", "title")
	var fs: int = 100
	var font: Font = UiKit.heavy()
	var w: float = UiKit.width(title, fs, font)
	var base_y: float = 190.0
	var orbit_c := Vector2(cx, base_y - 34.0)
	Effects.put(self, orbit_c, w * 0.65, Color(0.2, 0.6, 1.0, 0.2 + 0.06 * sin(_time * 2.0)))
	_draw_logo_orbit(orbit_c, w * 0.62, false)
	var x: float = cx - w * 0.5
	for k in title.length():
		var ch: String = title[k]
		var wobble: float = sin(_time * 2.2 + k * 0.6) * 6.0
		var drop: float = (1.0 - ease(clampf((_since - k * 0.04) * 3.0, 0.0, 1.0), 0.3)) * -60.0
		var col: Color = UiKit.CYAN.lerp(Color(0.8, 0.65, 1.0), 0.5 + 0.5 * sin(_time * 1.5 + k * 0.5))
		UiKit.text(self, Vector2(x, base_y + wobble + drop), ch, fs, col, 0.0, font, 10)
		x += UiKit.width(ch, fs, font)
	_draw_logo_orbit(orbit_c, w * 0.62, true)
	UiKit.text(self, Vector2(cx, base_y + 54.0), _tx("gameplay", "tagline"), 24, UiKit.GOLD, 0.5, UiKit.bold(), 5)
	_draw_menu(340.0, 46.0, 24)
	if int(gm.get("best_score")) > 0:
		var best: String = "%s     %s" % [_tx("gameplay", "best", {n = int(gm.get("best_score"))}), _tx("gameplay", "best_wave", {n = int(gm.get("best_wave"))})]
		UiKit.text(self, Vector2(cx, 618.0), best, 17, UiKit.GOLD, 0.5, UiKit.bold(), 4)
	UiKit.text(self, Vector2(cx, 656.0), _tx("gameplay", "controls"), 14, UiKit.DIM, 0.5, UiKit.bold(), 3)
	UiKit.text(self, Vector2(cx, 684.0), _tx("ui", "menu_hint"), 13, Color(UiKit.DIM, 0.7), 0.5, UiKit.regular(), 3)

## Bullets on a tilted ellipse around the logo: back half before the
## letters, front half after them, so they seem to circle it.
func _draw_logo_orbit(c: Vector2, rx: float, front: bool) -> void:
	for k in 14:
		var a: float = _time * 0.9 + TAU * k / 14.0
		var depth: float = sin(a)
		if (depth > 0.0) != front:
			continue
		var p: Vector2 = c + Vector2(cos(a) * rx, depth * rx * 0.16 - cos(a) * 18.0)
		var s: float = 3.0 + 2.0 * (depth * 0.5 + 0.5)
		var col: Color = Color(1.0, 0.62, 0.25) if k % 3 == 0 else Color(0.5, 0.95, 1.0)
		Effects.put(self, p, s * 3.0, Color(col, 0.5))
		draw_circle(p, s, col.lightened(0.3))

func _draw_help() -> void:
	_veil(0.78)
	var cx: float = size.x * 0.5
	UiKit.text(self, Vector2(cx, 82.0), _tx("ui", "help_title"), 40, UiKit.CYAN, 0.5, UiKit.heavy(), 8)
	var keys: Array[String] = ["capture", "sling", "crash", "nova"]
	var pw: float = 280.0
	var gap: float = 22.0
	var x0: float = cx - (pw * 4.0 + gap * 3.0) * 0.5
	for i in keys.size():
		var appear: float = ease(clampf((_since - 0.08 * i) * 4.0, 0.0, 1.0), 0.3)
		var r := Rect2(x0 + i * (pw + gap), 120.0 + (1.0 - appear) * 40.0, pw, 300.0)
		UiKit.panel(self, r, Color(UiKit.CYAN, 0.35 * appear), Color(0.02, 0.05, 0.13, 0.85 * appear), 12.0)
		UiKit.text(self, r.position + Vector2(20.0, 34.0), str(i + 1), 26, Color(UiKit.GOLD, appear), 0.0, UiKit.heavy(), 4)
		UiKit.text(self, r.position + Vector2(48.0, 33.0), _tx("help", keys[i] + "_title"), 20, Color(Color.WHITE, appear), 0.0, UiKit.heavy(), 4)
		var stage := Rect2(r.position + Vector2(14.0, 50.0), Vector2(pw - 28.0, 150.0))
		draw_rect(stage, Color(0.0, 0.02, 0.07, 0.8 * appear))
		draw_rect(stage, Color(UiKit.CYAN, 0.15 * appear), false, 1.0)
		_help_anim(keys[i], stage.get_center(), appear)
		var y: float = stage.end.y + 30.0
		for row in UiKit.wrap(_tx("help", keys[i]), pw - 32.0, 15, UiKit.bold()):
			UiKit.text(self, Vector2(r.position.x + pw * 0.5, y), row, 15, Color(UiKit.PALE, appear), 0.5, UiKit.bold(), 3)
			y += 21.0
	var hy: float = 474.0
	_heavy_orb(Vector2(cx - UiKit.width(_tx("help", "heavy"), 17, UiKit.bold()) * 0.5 - 26.0, hy - 6.0), 1.0)
	UiKit.text(self, Vector2(cx, hy), _tx("help", "heavy"), 17, UiKit.PALE, 0.5, UiKit.bold(), 4)
	UiKit.text(self, Vector2(cx, 524.0), _tx("gameplay", "controls"), 15, UiKit.DIM, 0.5, UiKit.bold(), 3)
	var blink: float = 0.6 + 0.4 * sin(_time * 4.0)
	UiKit.text(self, Vector2(cx, 600.0), _tx("ui", "back_hint"), 18, Color(1.0, 1.0, 1.0, blink), 0.5, UiKit.heavy(), 4)

func _mini_ship(at: Vector2, a: float, alpha: float) -> void:
	var f := Vector2.RIGHT.rotated(a)
	var s := Vector2(-f.y, f.x)
	var pts := PackedVector2Array([at + f * 11.0, at - f * 7.0 + s * 8.0, at - f * 3.0, at - f * 7.0 - s * 8.0])
	draw_colored_polygon(pts, Color(0.03, 0.15, 0.24, alpha))
	pts.append(pts[0])
	draw_polyline(pts, Color(UiKit.CYAN, alpha), 2.0)
	draw_circle(at, 2.0, Color(1.0, 1.0, 1.0, alpha))

func _mini_enemy(at: Vector2, c: Color, a: float, s: float, alpha: float) -> void:
	var pts := PackedVector2Array()
	for k in 4:
		pts.append(at + Vector2.RIGHT.rotated(a + TAU * k / 4.0) * 11.0 * s)
	draw_colored_polygon(pts, Color(c.darkened(0.8), alpha))
	pts.append(pts[0])
	draw_polyline(pts, Color(c, alpha), 2.0)

func _pellet(at: Vector2, alpha: float) -> void:
	Effects.put(self, at, 9.0, Color(1.0, 0.5, 0.15, 0.5 * alpha))
	draw_circle(at, 3.5, Color(1.0, 0.65, 0.3, alpha))

func _heavy_orb(at: Vector2, alpha: float) -> void:
	Effects.put(self, at, 18.0, Color(1.0, 0.1, 0.2, 0.5 * alpha))
	for k in 6:
		var a: float = _time * 6.0 + TAU * k / 6.0
		draw_line(at + Vector2.RIGHT.rotated(a) * 6.0, at + Vector2.RIGHT.rotated(a) * 11.0, Color(1.0, 0.25, 0.3, alpha), 2.0)
	draw_circle(at, 7.0, Color(0.9, 0.1, 0.18, alpha))

## Looping mini animation of one rule, centred on c (stage 252 x 150).
func _help_anim(key: String, c: Vector2, alpha: float) -> void:
	match key:
		"capture":
			var t: float = fmod(_time, 3.0) / 3.0
			var ship := c + Vector2(-50.0, 0.0)
			draw_arc(ship, 44.0, 0.0, TAU, 32, Color(UiKit.CYAN, 0.35 * alpha), 1.5)
			Effects.put(self, ship, 50.0, Color(0.1, 0.5, 1.0, 0.25 * alpha))
			for k in 3:
				var start := c + Vector2(110.0, -36.0 + k * 36.0)
				var orbit: Vector2 = ship + Vector2.RIGHT.rotated(_time * 4.0 + TAU * k / 3.0) * 26.0
				var arrive: float = clampf((t - 0.1 * k) / 0.45, 0.0, 1.0)
				var p: Vector2 = start.lerp(orbit, ease(arrive, 0.6)) if arrive < 1.0 else orbit
				_pellet(p, alpha)
			_mini_ship(ship, 0.0, alpha)
		"sling":
			var t2: float = fmod(_time, 2.6) / 2.6
			var ship2 := c + Vector2(-80.0, 20.0)
			var target := c + Vector2(80.0, -20.0)
			_mini_ship(ship2, (target - ship2).angle(), alpha)
			var hit: bool = t2 > 0.62
			if t2 < 0.85:
				_mini_enemy(target, Color(1.0, 0.35, 0.5), _time * 3.0, 1.0, alpha * (1.0 if not hit else 1.0 - (t2 - 0.62) / 0.23))
			if hit and t2 < 0.95:
				draw_arc(target, (t2 - 0.62) * 140.0, 0.0, TAU, 24, Color(1.0, 0.5, 0.6, alpha * (1.0 - (t2 - 0.62) / 0.33)), 2.0)
			for k in 4:
				var orbit2: Vector2 = ship2 + Vector2.RIGHT.rotated(_time * 4.0 + TAU * k / 4.0) * 24.0
				if t2 < 0.4:
					draw_circle(orbit2, 3.5, Color(0.75, 1.0, 1.0, alpha))
				elif t2 < 0.64:
					var f: float = (t2 - 0.4) / 0.24
					var p2: Vector2 = orbit2.lerp(target, f)
					Effects.put(self, p2, 10.0, Color(0.3, 0.9, 1.0, 0.6 * alpha))
					draw_circle(p2, 3.5, Color(0.75, 1.0, 1.0, alpha))
		"crash":
			var t3: float = fmod(_time, 2.8) / 2.8
			var ship3 := c + Vector2(0.0, 40.0)
			var pull: float = clampf(t3 / 0.55, 0.0, 1.0)
			for k in 4:
				var a3: float = _time * 2.0 + TAU * k / 4.0
				draw_arc(ship3, 60.0 - 10.0 * k, a3, a3 + 1.2, 10, Color(UiKit.CYAN, 0.2 * alpha), 1.5)
			var meet := c + Vector2(0.0, -14.0)
			if t3 < 0.55:
				_mini_enemy(c + Vector2(-100.0, -30.0).lerp(meet - c + Vector2(-11.0, 0.0), ease(pull, 2.2)), Color(1.0, 0.35, 0.5), _time * 3.0, 1.0, alpha)
				_mini_enemy(c + Vector2(100.0, -30.0).lerp(meet - c + Vector2(11.0, 0.0), ease(pull, 2.2)), Color(1.0, 0.6, 0.25), -_time * 3.0, 1.0, alpha)
			elif t3 < 0.9:
				var f3: float = (t3 - 0.55) / 0.35
				draw_arc(meet, f3 * 60.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.7, alpha * (1.0 - f3)), 3.0)
				for k in 8:
					var a4: float = TAU * k / 8.0
					draw_line(meet + Vector2.RIGHT.rotated(a4) * f3 * 30.0, meet + Vector2.RIGHT.rotated(a4 + 0.5) * f3 * 44.0, Color(1.0, 0.6, 0.5, alpha * (1.0 - f3)), 2.0)
			_mini_ship(ship3, -PI * 0.5, alpha)
		"nova":
			var t4: float = fmod(_time, 3.4) / 3.4
			var ship4 := c + Vector2(0.0, -6.0)
			if t4 < 0.45:
				for k in 6:
					var a5: float = TAU * k / 6.0 + 0.4
					var p4: Vector2 = (ship4 + Vector2.RIGHT.rotated(a5) * 95.0).lerp(ship4, clampf((t4 - k * 0.04) / 0.35, 0.0, 1.0))
					var g := Vector2.RIGHT.rotated(_time * 4.0 + k) * 4.0
					var h := Vector2(-g.y, g.x) * 0.55
					draw_colored_polygon(PackedVector2Array([p4 + g, p4 + h, p4 - g, p4 - h]), Color(0.65, 0.95, 1.0, alpha))
			elif t4 < 0.72:
				var f4: float = (t4 - 0.45) / 0.27
				Effects.put(self, ship4, 60.0, Color(0.5, 0.35, 1.0, 0.5 * alpha))
				draw_arc(ship4, 100.0 * (1.0 - f4) + 10.0, 0.0, TAU, 32, Color(0.78, 0.62, 1.0, alpha), 2.5)
				for k in 5:
					var a6: float = TAU * k / 5.0 + _time
					_pellet(ship4 + Vector2.RIGHT.rotated(a6) * lerpf(110.0, 24.0, f4), alpha)
			else:
				var f5: float = (t4 - 0.72) / 0.28
				draw_arc(ship4, 20.0 + f5 * 110.0, 0.0, TAU, 40, Color(0.85, 0.75, 1.0, alpha * (1.0 - f5)), 4.0)
			_mini_ship(ship4, -PI * 0.5, alpha)
			var bar := Rect2(c.x - 60.0, c.y + 58.0, 120.0, 6.0)
			var fill: float = clampf(t4 / 0.45, 0.0, 1.0) if t4 < 0.45 else maxf(1.0 - (t4 - 0.45) / 0.27, 0.0)
			UiKit.bar(self, bar, fill, Color(0.78, 0.62, 1.0, alpha))

# =============================================================================
# PAUSE
# =============================================================================

func _draw_pause() -> void:
	_veil(0.66)
	var cx: float = size.x * 0.5
	UiKit.text(self, Vector2(cx, 176.0), _tx("ui", "pause_title"), 60, UiKit.CYAN, 0.5, UiKit.heavy(), 10)
	_draw_menu(252.0, 48.0, 24)
	var levels: Dictionary = gm.get("levels") as Dictionary
	var r := Rect2(cx - 330.0, 340.0, 660.0, 250.0)
	UiKit.panel(self, r, Color(UiKit.CYAN, 0.3), Color(0.02, 0.05, 0.13, 0.85), 12.0)
	UiKit.text(self, Vector2(cx, r.position.y + 32.0), _tx("ui", "pause_upgrades"), 18, UiKit.DIM, 0.5, UiKit.heavy(), 3)
	if levels.is_empty():
		UiKit.text(self, Vector2(cx, r.position.y + 130.0), _tx("ui", "pause_none"), 17, UiKit.PALE, 0.5, UiKit.bold(), 3)
	else:
		var i: int = 0
		for id in levels:
			var col: int = i % 3
			var row: int = i / 3
			var at := Vector2(r.position.x + 40.0 + col * 210.0, r.position.y + 72.0 + row * 46.0)
			UiKit.upgrade_icon(self, str(id), at, 0.36, UiKit.CYAN, _time)
			UiKit.text(self, at + Vector2(28.0, -2.0), _tx("upgrades", "name_" + str(id)), 15, Color.WHITE, 0.0, UiKit.bold(), 3)
			var lv: int = int(levels[id])
			var mx: int = int(preload("res://scripts/core/upgrades.gd").max_level(str(id)))
			for k in mx:
				var dot := at + Vector2(32.0 + k * 11.0, 12.0)
				if k < lv:
					draw_circle(dot, 3.0, UiKit.GOLD)
				else:
					draw_arc(dot, 3.0, 0.0, TAU, 10, Color(UiKit.GOLD, 0.5), 1.0)
			i += 1
	UiKit.text(self, Vector2(cx, 640.0), _tx("gameplay", "controls"), 14, UiKit.DIM, 0.5, UiKit.bold(), 3)

# =============================================================================
# UPGRADES
# =============================================================================

func _draw_upgrades() -> void:
	_veil(0.6)
	var cx: float = size.x * 0.5
	var land: float = ease(clampf(_since * 4.0, 0.0, 1.0), 0.4)
	UiKit.text(self, Vector2(cx, 120.0 - (1.0 - land) * 30.0), _tx("ui", "upgrade_title", {n = int(gm.get("wave_number"))}), 40, Color(0.6, 1.0, 0.75, land), 0.5, UiKit.heavy(), 8)
	var report: Dictionary = gm.get("sector_report") as Dictionary
	if not report.is_empty():
		UiKit.text(self, Vector2(cx, 158.0), _tx("ui", "sector_report", report), 16, Color(UiKit.GOLD, land), 0.5, UiKit.bold(), 3)
	UiKit.text(self, Vector2(cx, 198.0), _tx("ui", "upgrade_subtitle"), 20, Color(UiKit.PALE, land), 0.5, UiKit.bold(), 4)
	var offer: Array = gm.get("offer") as Array
	var levels: Dictionary = gm.get("levels") as Dictionary
	var selected: int = int(gm.get("offer_index"))
	var card_w: float = 300.0
	var card_h: float = 310.0
	var gap: float = 30.0
	var x0: float = cx - (offer.size() * card_w + (offer.size() - 1) * gap) * 0.5
	for i in offer.size():
		var base := Rect2(x0 + i * (card_w + gap), 236.0, card_w, card_h)
		_cards.append(base)
		var on: bool = i == selected
		var rise: float = ease(clampf((_since - 0.1 * i) * 4.0, 0.0, 1.0), 0.3)
		var r: Rect2 = base
		r.position.y += (-12.0 if on else 0.0) + (1.0 - rise) * 90.0
		var alpha: float = rise
		var id: String = str(offer[i])
		var lv: int = int(levels.get(id, 0))
		var mx: int = int(preload("res://scripts/core/upgrades.gd").max_level(id))
		if on:
			Effects.put(self, r.get_center(), 230.0, Color(0.2, 0.6, 1.0, 0.16 * alpha))
		UiKit.panel(self, r, Color(UiKit.CYAN, alpha) if on else Color(0.25, 0.35, 0.6, alpha), Color(0.03, 0.07, 0.17, 0.95 * alpha), 16.0, 3.0 if on else 1.5)
		var icon_c: Vector2 = r.position + Vector2(card_w * 0.5, 78.0)
		draw_circle(icon_c, 48.0, Color(0.0, 0.03, 0.1, alpha))
		draw_arc(icon_c, 48.0, 0.0, TAU, 40, Color(UiKit.CYAN if on else UiKit.DIM, 0.5 * alpha), 1.5)
		UiKit.upgrade_icon(self, id, icon_c, 1.0, Color(UiKit.CYAN if on else Color(0.4, 0.65, 0.9), alpha), _time)
		UiKit.text(self, r.position + Vector2(card_w * 0.5, 160.0), _tx("upgrades", "name_" + id), 23, Color(Color.WHITE, alpha), 0.5, UiKit.heavy(), 4)
		var tag: String = _tx("ui", "upgrade_new") if lv == 0 else _tx("ui", "upgrade_level", {n = lv + 1})
		UiKit.text(self, r.position + Vector2(card_w * 0.5, 184.0), tag, 13, Color(UiKit.GOLD, alpha), 0.5, UiKit.bold(), 3)
		var y: float = 216.0
		for row in UiKit.wrap(_tx("upgrades", "desc_" + id), card_w - 40.0, 16, UiKit.bold()):
			UiKit.text(self, r.position + Vector2(card_w * 0.5, y), row, 16, Color(UiKit.PALE, alpha), 0.5, UiKit.bold(), 3)
			y += 22.0
		for k in mx:
			var dot: Vector2 = r.position + Vector2(card_w * 0.5 - (mx - 1) * 8.0 + k * 16.0, card_h - 22.0)
			if k < lv:
				draw_circle(dot, 4.0, Color(UiKit.GOLD, alpha))
			elif k == lv:
				var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
				draw_circle(dot, 4.0 + pulse, Color(UiKit.CYAN, alpha * (0.6 + 0.4 * pulse)))
			else:
				draw_arc(dot, 4.0, 0.0, TAU, 12, Color(UiKit.DIM, alpha), 1.5)
		UiKit.text(self, r.position + Vector2(18.0, card_h - 14.0), str(i + 1), 15, Color(UiKit.DIM, alpha), 0.0, UiKit.heavy(), 3)
	UiKit.text(self, Vector2(cx, 600.0), _tx("ui", "upgrade_hint"), 16, UiKit.DIM, 0.5, UiKit.bold(), 3)

## The chosen card shrinks and flies to the HUD's upgrade row.
func _draw_chosen() -> void:
	var t: float = clampf(float(_chosen["t"]) / 0.6, 0.0, 1.0)
	var r: Rect2 = _chosen["rect"] as Rect2
	var levels: Dictionary = gm.get("levels") as Dictionary
	var slot: int = maxi(levels.keys().find(str(_chosen["id"])), 0)
	var goal := Vector2(30.0 + slot * 34.0, size.y - 34.0)
	var k: float = ease(t, 0.5)
	var at: Vector2 = r.get_center().lerp(goal, k)
	var s: float = lerpf(1.0, 0.32, k)
	var alpha: float = 1.0 - t * t
	Effects.put(self, at, 120.0 * s, Color(0.3, 0.8, 1.0, 0.4 * alpha))
	UiKit.upgrade_icon(self, str(_chosen["id"]), at, s, Color(Color.WHITE, alpha), _time)
	if t < 0.3:
		draw_rect(r.grow(t * 40.0), Color(1.0, 1.0, 1.0, 0.25 * (1.0 - t / 0.3)), false, 3.0)

# =============================================================================
# END OF RUN
# =============================================================================

func _draw_end(won: bool) -> void:
	_veil(0.62)
	var cx: float = size.x * 0.5
	var title: String = _tx("feedback", "victory" if won else "game_over")
	var land: float = ease(clampf(_since * 3.0, 0.0, 1.0), 0.4)
	draw_set_transform(Vector2(cx, 118.0), 0.0, Vector2.ONE * lerpf(1.8, 1.0, land))
	UiKit.text(self, Vector2.ZERO, title, 54, Color(0.6, 1.0, 0.75, land) if won else Color(1.0, 0.4, 0.45, land), 0.5, UiKit.heavy(), 10)
	draw_set_transform(Vector2.ZERO)
	var final_score: int = int(gm.get("score"))
	var count: float = ease(clampf((_since - 0.3) / 1.2, 0.0, 1.0), 0.4)
	var shown: int = int(final_score * count)
	UiKit.text(self, Vector2(cx, 196.0), "%s  %d  %s" % [_tx("gameplay", "score"), shown, _tx("gameplay", "score_unit")], 38, Color.WHITE, 0.5, UiKit.heavy(), 6)
	if bool(gm.get("new_best")) and _since > 1.5:
		var blink: float = 0.6 + 0.4 * sin(_time * 6.0)
		UiKit.text(self, Vector2(cx, 236.0), _tx("feedback", "new_best"), 22, Color(UiKit.GOLD, blink), 0.5, UiKit.heavy(), 5)
	var stamp_c := Vector2(cx - 300.0, 390.0)
	if _since > 1.5:
		var st: float = clampf((_since - 1.5) / 0.25, 0.0, 1.0)
		var letter: String = gm.call("rank") as String
		var colors: Dictionary = {S = UiKit.GOLD, A = UiKit.CYAN, B = Color(0.55, 1.0, 0.6), C = Color(0.8, 0.65, 1.0), D = UiKit.DIM}
		var rc: Color = colors.get(letter, UiKit.DIM) as Color
		var s: float = lerpf(2.6, 1.0, ease(st, 0.4))
		Effects.put(self, stamp_c, 120.0, Color(rc, 0.18 * st))
		if st < 1.0:
			draw_arc(stamp_c, 70.0 + (1.0 - st) * 80.0, 0.0, TAU, 40, Color(rc, st), 3.0)
		var hex := PackedVector2Array()
		for k in 7:
			hex.append(stamp_c + Vector2.RIGHT.rotated(TAU * k / 6.0 + PI / 6.0) * 70.0 * s)
		draw_colored_polygon(hex.slice(0, 6), Color(0.02, 0.04, 0.12, 0.9 * st))
		draw_polyline(hex, Color(rc, st), 3.0)
		UiKit.text(self, stamp_c + Vector2(0.0, 30.0 * s), letter, int(86 * s), Color(rc, st), 0.5, UiKit.heavy(), 8)
		UiKit.text(self, stamp_c + Vector2(0.0, 98.0), _tx("ui", "rank"), 16, Color(UiKit.DIM, st), 0.5, UiKit.heavy(), 3)
	var reached: int = int(gm.get("wave_number")) if won else maxi(int(gm.get("wave_number")), 1)
	var secs: int = int(float(gm.get("run_time")))
	var lines: Array[String] = [
		_tx("gameplay", "stats_wave", {n = reached, total = gm.call("total_waves")}),
		_tx("gameplay", "stats_kills", {n = int(gm.get("kills"))}),
		_tx("gameplay", "stats_captured", {n = gm.call("captured_total")}),
		_tx("gameplay", "stats_volley", {n = int(gm.get("best_volley"))}),
		_tx("gameplay", "stats_grazes", {n = int(gm.get("grazes"))}),
		_tx("gameplay", "stats_novas", {n = int(gm.get("novas"))}),
		_tx("gameplay", "stats_time", {m = secs / 60, s = secs % 60}),
	]
	var sx: float = cx - 170.0
	for i in lines.size():
		var t: float = clampf((_since - 0.6 - 0.15 * i) * 4.0, 0.0, 1.0)
		if t <= 0.0:
			continue
		var y: float = 300.0 + i * 33.0
		draw_rect(Rect2(sx - 14.0, y - 9.0, 6.0, 6.0), Color(UiKit.CYAN, t))
		UiKit.text(self, Vector2(sx + (1.0 - t) * 30.0, y), lines[i], 19, Color(UiKit.PALE, t), 0.0, UiKit.bold(), 4)
	if _since > 1.0:
		_draw_menu(590.0, 46.0, 22)

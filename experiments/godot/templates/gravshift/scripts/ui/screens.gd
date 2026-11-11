extends Control

# Screens: title, pause, upgrade choice and end of run, drawn over the
# bending grid. Keyboard driven (game_manager reads the keys); the upgrade
# cards can also be clicked. Each screen animates in from the moment its
# state starts (_since): the cards rise one after the other, the end title
# lands, then the statistics appear line by line.

var gm: Node = null
var _font: Font = null
var _time: float = 0.0
var _cards: Array[Rect2] = []
var _since: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

## Connected to game_manager.game_state_changed.
func on_state_changed(state: int) -> void:
	_since = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP if state == 3 else Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	_since += delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		for i in _cards.size():
			if _cards[i].has_point((event as InputEventMouseButton).position):
				gm.call("choose_from_click", i)
				accept_event()
				return
	elif event is InputEventMouseMotion:
		for i in _cards.size():
			if _cards[i].has_point((event as InputEventMouseMotion).position) and int(gm.get("offer_index")) != i:
				gm.set("offer_index", i)
				gm.call("sfx", "ui_move", 1.0, 0.0)

func _tx(section: String, key: String, rep: Dictionary = {}) -> String:
	return gm.call("text", section, key, rep) as String

func _t(at: Vector2, label: String, size: int, color: Color, outline: int = 5) -> void:
	var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p: Vector2 = at - Vector2(w * 0.5, 0.0)
	draw_string_outline(_font, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0.0, 0.0, 0.06, 0.9))
	draw_string(_font, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _veil(alpha: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.05, alpha))

func _draw() -> void:
	_cards.clear()
	match int(gm.get("current_state")):
		0:
			_draw_title()
		2:
			_veil(0.6)
			_t(size * Vector2(0.5, 0.45), _tx("ui", "pause_title"), 56, Color(0.5, 0.95, 1.0), 10)
			_t(size * Vector2(0.5, 0.55), _tx("ui", "pause_hint"), 20, Color(0.85, 0.9, 1.0))
		3:
			_draw_upgrades()
		4, 5:
			_draw_end(int(gm.get("current_state")) == 5)

func _draw_title() -> void:
	_veil(0.35)
	var cx: float = size.x * 0.5
	var title: String = _tx("ui", "title")
	var fs: int = 104
	var w: float = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(cx - w * 0.5, 220.0)
	Effects.put(self, Vector2(cx, 190.0), w * 0.6, Color(0.2, 0.6, 1.0, 0.22 + 0.06 * sin(_time * 2.0)))
	for k in title.length():
		var ch: String = title[k]
		var cw: float = _font.get_string_size(title.substr(0, k), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var wobble: float = sin(_time * 2.2 + k * 0.6) * 6.0
		var at := Vector2(p.x + cw, p.y + wobble)
		draw_string_outline(_font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(0.0, 0.05, 0.15, 0.9))
		draw_string(_font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.45, 0.95, 1.0))
	_t(Vector2(cx, 280.0), _tx("gameplay", "tagline"), 24, Color(1.0, 0.85, 0.5))
	var rules: Array[String] = ["rule_well", "rule_sling", "rule_crash", "rule_heavy"]
	for i in rules.size():
		_t(Vector2(cx, 340.0 + i * 32.0), _tx("gameplay", rules[i]), 18, Color(0.85, 0.92, 1.0), 4)
	_t(Vector2(cx, 500.0), _tx("gameplay", "controls"), 16, Color(0.6, 0.7, 0.9), 4)
	var blink: float = 0.55 + 0.45 * sin(_time * 4.0)
	_t(Vector2(cx, 570.0), _tx("gameplay", "press_start"), 28, Color(1.0, 1.0, 1.0, blink), 6)
	if int(gm.get("best_score")) > 0:
		var best: String = "%s     %s" % [_tx("gameplay", "best", {n = int(gm.get("best_score"))}), _tx("gameplay", "best_wave", {n = int(gm.get("best_wave"))})]
		_t(Vector2(cx, 620.0), best, 18, Color(1.0, 0.85, 0.5), 4)
	var sound: String = _tx("ui", "sound_off") if bool(gm.get("muted")) else _tx("ui", "sound_on")
	_t(Vector2(cx, 680.0), _tx("ui", "language_hint", {sound = sound}), 14, Color(0.55, 0.62, 0.8), 3)

func _draw_upgrades() -> void:
	_veil(0.55)
	var cx: float = size.x * 0.5
	_t(Vector2(cx, 150.0), _tx("ui", "upgrade_title", {n = int(gm.get("wave_number"))}), 40, Color(0.6, 1.0, 0.75), 8)
	_t(Vector2(cx, 195.0), _tx("ui", "upgrade_subtitle"), 20, Color(0.85, 0.92, 1.0))
	var offer: Array = gm.get("offer") as Array
	var levels: Dictionary = gm.get("levels") as Dictionary
	var selected: int = int(gm.get("offer_index"))
	var card_w: float = 300.0
	var gap: float = 30.0
	var x0: float = cx - (offer.size() * card_w + (offer.size() - 1) * gap) * 0.5
	for i in offer.size():
		var r := Rect2(x0 + i * (card_w + gap), 250.0, card_w, 280.0)
		_cards.append(r)
		var on: bool = i == selected
		var rise: float = ease(clampf((_since - 0.1 * i) * 4.0, 0.0, 1.0), 0.3)
		var lift: float = -10.0 if on else 0.0
		r.position.y += lift + (1.0 - rise) * 80.0
		draw_rect(r, Color(0.04, 0.07, 0.16, 0.95))
		draw_rect(r, Color(0.45, 0.95, 1.0) if on else Color(0.2, 0.3, 0.55), false, 3.0 if on else 1.5)
		if on:
			Effects.put(self, r.get_center(), 200.0, Color(0.2, 0.6, 1.0, 0.12))
		var id: String = str(offer[i])
		_icon(id, r.position + Vector2(card_w * 0.5, 70.0), on)
		_t(r.position + Vector2(card_w * 0.5, 150.0), _tx("upgrades", "name_" + id), 22, Color.WHITE, 4)
		_wrapped(_tx("upgrades", "desc_" + id), r.position + Vector2(20.0, 185.0), card_w - 40.0, 16, Color(0.75, 0.85, 1.0))
		var lv: int = int(levels.get(id, 0))
		_t(r.position + Vector2(card_w * 0.5, 262.0), "%d   %s" % [i + 1, _tx("ui", "upgrade_level", {n = lv + 1})], 14, Color(0.55, 0.62, 0.8), 3)
	_t(Vector2(cx, 600.0), _tx("ui", "upgrade_hint"), 16, Color(0.6, 0.7, 0.9))

func _wrapped(label: String, at: Vector2, width: float, size_px: int, color: Color) -> void:
	var words: PackedStringArray = label.split(" ")
	var line: String = ""
	var y: float = at.y
	for word in words:
		var test: String = word if line.is_empty() else line + " " + word
		if _font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > width and not line.is_empty():
			_t(Vector2(at.x + width * 0.5, y), line, size_px, color, 3)
			y += size_px + 6.0
			line = word
		else:
			line = test
	if not line.is_empty():
		_t(Vector2(at.x + width * 0.5, y), line, size_px, color, 3)

func _icon(id: String, at: Vector2, on: bool) -> void:
	var c := Color(0.45, 0.95, 1.0) if on else Color(0.35, 0.6, 0.85)
	match id:
		"orbit":
			draw_arc(at, 28.0, 0.0, TAU, 32, c, 2.0)
			for k in 8:
				draw_circle(at + Vector2.RIGHT.rotated(_time * 2.0 + TAU * k / 8.0) * 28.0, 4.0, c)
		"horizon":
			for k in 3:
				draw_arc(at, 12.0 + k * 12.0, 0.0, TAU, 32, Color(c, 1.0 - k * 0.3), 2.0)
		"sling":
			for k in 3:
				var off := Vector2(-20.0 + k * 20.0, 10.0 - k * 10.0)
				draw_line(at + off - Vector2(18, 0), at + off, Color(c, 0.6), 3.0)
				draw_circle(at + off, 5.0, c)
		"tank":
			draw_rect(Rect2(at - Vector2(14, 26), Vector2(28, 52)), c, false, 2.5)
			draw_rect(Rect2(at - Vector2(10, 4), Vector2(20, 26)), c)
		"twin":
			for s in [-12.0, 12.0]:
				draw_line(at + Vector2(s, 20), at + Vector2(s, -24), c, 3.0)
		"hull":
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -26), at + Vector2(22, 0), at + Vector2(0, 26), at + Vector2(-22, 0)]), c)
		"shrapnel":
			for k in 8:
				var a: float = TAU * k / 8.0
				draw_line(at + Vector2.RIGHT.rotated(a) * 8.0, at + Vector2.RIGHT.rotated(a) * 28.0, c, 2.5)
		"pierce":
			draw_line(at + Vector2(-30, 0), at + Vector2(30, 0), c, 3.0)
			draw_arc(at + Vector2(-8, 0), 10.0, 0.0, TAU, 20, Color(c, 0.6), 2.0)
			draw_arc(at + Vector2(12, 0), 10.0, 0.0, TAU, 20, Color(c, 0.6), 2.0)
		"grinder":
			for k in 6:
				var a2: float = -_time * 3.0 + TAU * k / 6.0
				draw_line(at, at + Vector2.RIGHT.rotated(a2) * 28.0, c, 3.0)
		"recoil":
			for k in 3:
				var rr: float = fmod(_time * 30.0 + k * 10.0, 30.0)
				draw_arc(at, rr, 0.0, TAU, 32, Color(c, 1.0 - rr / 30.0), 2.0)

func _draw_end(won: bool) -> void:
	_veil(0.55)
	var cx: float = size.x * 0.5
	var title: String = _tx("feedback", "victory" if won else "game_over")
	var land: float = ease(clampf(_since * 3.0, 0.0, 1.0), 0.4)
	draw_set_transform(Vector2(cx, 200.0), 0.0, Vector2.ONE * lerpf(1.8, 1.0, land))
	_t(Vector2.ZERO, title, 56, Color(0.6, 1.0, 0.75, land) if won else Color(1.0, 0.4, 0.45, land), 10)
	draw_set_transform(Vector2.ZERO)
	_t(Vector2(cx, 280.0), "%s %d %s" % [_tx("gameplay", "score"), int(gm.get("score")), _tx("gameplay", "score_unit")], 36, Color.WHITE, 6)
	if bool(gm.get("new_best")):
		var blink: float = 0.6 + 0.4 * sin(_time * 6.0)
		_t(Vector2(cx, 325.0), _tx("feedback", "new_best"), 24, Color(1.0, 0.85, 0.4, blink), 5)
	var reached: int = int(gm.get("wave_number")) if won else maxi(int(gm.get("wave_number")), 1)
	var lines: Array[String] = [
		_tx("gameplay", "stats_wave", {n = reached, total = gm.call("total_waves")}),
		_tx("gameplay", "stats_captured", {n = gm.call("captured_total")}),
		_tx("gameplay", "stats_volley", {n = int(gm.get("best_volley"))}),
	]
	for i in lines.size():
		if _since > 0.5 + 0.25 * i:
			_t(Vector2(cx, 390.0 + i * 34.0), lines[i], 20, Color(0.8, 0.88, 1.0), 4)
	_t(Vector2(cx, 560.0), _tx("ui", "end_hint"), 20, Color(0.6, 0.7, 0.9), 4)

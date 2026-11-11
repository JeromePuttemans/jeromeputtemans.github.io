# =============================================================================
# Hud.gd — Health bars, round wins, timer, super gauges, combo counters
# =============================================================================
# Drawn every frame from the Match state. The health bar keeps a red trail
# of the recent damage that drains a moment later, so the size of a combo
# stays readable. A gauge full of super meter glows.
# =============================================================================

class_name Hud
extends Control

var match_node: Match = null
var _font: Font = null
var _trail: Array[float] = [1.0, 1.0]
var _trail_delay: Array[float] = [0.0, 0.0]
var _last_hp: Array[float] = [1.0, 1.0]
var _combo_show: Array[float] = [0.0, 0.0]
var _combo_hits: Array[int] = [0, 0]
var _combo_damage: Array[float] = [0.0, 0.0]
var _time: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

func reset() -> void:
	_trail = [1.0, 1.0]
	_last_hp = [1.0, 1.0]
	_combo_show = [0.0, 0.0]

func _process(delta: float) -> void:
	_time += delta
	if match_node == null or not is_instance_valid(match_node):
		return
	for i in 2:
		var f: Fighter = match_node.fighters[i]
		var ratio: float = f.hp / f.max_hp
		if ratio < _last_hp[i] - 0.0001:
			_trail_delay[i] = 0.6
		elif ratio > _last_hp[i]:
			_trail[i] = ratio
		_last_hp[i] = ratio
		_trail_delay[i] -= delta
		if _trail_delay[i] <= 0.0:
			_trail[i] = move_toward(_trail[i], ratio, delta * 0.8)
		# Combo made by player i = hits taken by the opponent
		var opp: Fighter = match_node.fighters[1 - i]
		if opp.combo_hits >= 2:
			_combo_hits[i] = opp.combo_hits
			_combo_damage[i] = opp.combo_damage
			_combo_show[i] = 1.4
		else:
			_combo_show[i] = maxf(_combo_show[i] - delta, 0.0)
	queue_redraw()

func _text(at: Vector2, text: String, size: int, color: Color, align: int = 0) -> void:
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at
	if align == 1:
		p.x -= w * 0.5
	elif align == 2:
		p.x -= w
	draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, UiTheme.SHADOW)
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	if match_node == null or not is_instance_valid(match_node):
		return
	var w: float = size.x
	var cx: float = w * 0.5
	var bar_w: float = minf(cx - 110.0, 520.0)
	for i in 2:
		var f: Fighter = match_node.fighters[i]
		var right: bool = i == 1
		var x0: float = cx + 80.0 if right else cx - 80.0 - bar_w
		var r := Rect2(x0, 30.0, bar_w, 26.0)
		draw_rect(r.grow(3.0), Color("1a120c"))
		draw_rect(r, Color("2a1a14"))
		var ratio: float = f.hp / f.max_hp
		var trail_w: float = bar_w * _trail[i]
		var hp_w: float = bar_w * ratio
		var color: Color = Color("f2c14e").lerp(Color("e8503a"), 1.0 - ratio)
		if right:
			draw_rect(Rect2(x0, 30.0, trail_w, 26.0), Color("c0302a"))
			draw_rect(Rect2(x0, 30.0, hp_w, 26.0), color)
			draw_rect(Rect2(x0, 30.0, hp_w, 6.0), Color(1.0, 1.0, 1.0, 0.25))
		else:
			draw_rect(Rect2(x0 + bar_w - trail_w, 30.0, trail_w, 26.0), Color("c0302a"))
			draw_rect(Rect2(x0 + bar_w - hp_w, 30.0, hp_w, 26.0), color)
			draw_rect(Rect2(x0 + bar_w - hp_w, 30.0, hp_w, 6.0), Color(1.0, 1.0, 1.0, 0.25))
		draw_rect(r.grow(3.0), UiTheme.BORDER, false, 2.0)
		var label_text: String = GameState.fighter_name(f.char_id)
		_text(Vector2(x0 + (bar_w if right else 0.0), 82.0), label_text, 20, UiTheme.P2 if right else UiTheme.P1, 2 if right else 0)
		for k in ConfigManager.get_int("rounds_to_win", 2):
			var px: float = cx + (60.0 + k * 24.0) * (1.0 if right else -1.0)
			var won: bool = k < match_node.wins[i]
			draw_circle(Vector2(px, 74.0), 8.0, Color("1a120c"))
			draw_circle(Vector2(px, 74.0), 6.0, UiTheme.BRASS if won else Color("3a2a1e"))
		var mx0: float = 40.0 if not right else w - 40.0 - 300.0
		var mr := Rect2(mx0, size.y - 46.0, 300.0, 14.0)
		draw_rect(mr.grow(2.0), Color("1a120c"))
		var full: bool = f.meter >= 100.0
		var mcolor: Color = Color("6ff2ff") if not full else Color(1.0, 0.85, 0.4).lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 10.0))
		var mw: float = 300.0 * f.meter / 100.0
		if right:
			draw_rect(Rect2(mx0 + 300.0 - mw, mr.position.y, mw, 14.0), mcolor)
		else:
			draw_rect(Rect2(mx0, mr.position.y, mw, 14.0), mcolor)
		draw_rect(mr.grow(2.0), UiTheme.BORDER, false, 1.5)
		_text(Vector2(mx0 + (300.0 if right else 0.0), size.y - 54.0), "SUPER" if full else "", 16, mcolor, 2 if right else 0)
		if _combo_show[i] > 0.0:
			var a: float = minf(_combo_show[i] * 2.0, 1.0)
			var cxp: float = 60.0 if not right else w - 60.0
			var align: int = 0 if not right else 2
			_text(Vector2(cxp, 200.0), StringManager.t("combo", {n = _combo_hits[i]}), 34, Color(1.0, 0.82, 0.35, a), align)
			_text(Vector2(cxp, 230.0), StringManager.t("combo_damage", {d = int(_combo_damage[i])}), 18, Color(0.95, 0.9, 0.8, a), align)
	UiTheme.gear(self, Vector2(cx, 44.0), 40.0, 12, _time * 0.2, Color("4a3220"))
	draw_circle(Vector2(cx, 44.0), 30.0, Color("1a120c"))
	var timer_text: String = "--" if match_node.training else str(maxi(int(ceil(match_node.timer_frames / 60.0)), 0))
	var tcolor: Color = UiTheme.RED if (not match_node.training and match_node.timer_frames < 600) else UiTheme.TEXT
	_text(Vector2(cx, 56.0), timer_text, 32, tcolor, 1)
	if match_node.training:
		_text(Vector2(cx, 120.0), StringManager.t("training"), 18, UiTheme.BRASS, 1)
		_text(Vector2(cx, 144.0), StringManager.t("dummy_" + match_node.dummy_mode) + "     " + StringManager.t("training_hint"), 15, UiTheme.MUTED, 1)
		var info: Dictionary = match_node.last_info
		if not info.is_empty():
			var adv: int = int(info["advantage"])
			var adv_text: String = ("KD" if bool(info["launch"]) and not bool(info["blocked"]) else ("%+d" % adv))
			var move_key: String = str(info["move"])
			var label: String = StringManager.t("move_" + move_key) if not move_key.begins_with("sp_") and move_key != "super" else StringManager.t("move_%s_%s" % [match_node.fighters[0].char_id, move_key.trim_prefix("sp_")])
			_text(Vector2(cx, size.y - 80.0), StringManager.t("training_info", {move = label, s = int(info["startup"]), a = adv_text}), 18, UiTheme.TEXT, 1)

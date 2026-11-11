# =============================================================================
# Stage.gd — The three arenas, drawn with parallax layers
# =============================================================================
# A layer with factor f is drawn at its base position + camera x (1 - f):
# a far layer (small f) follows the camera and barely scrolls, the floor
# (f = 1) is fixed to the world. The floor lines converge toward the
# camera centre, which gives depth when the camera travels.
#   atelier    clockmaker's workshop: giant gears, window, swinging lamps
#   fonderie   foundry: glowing furnaces, chains, rising embers
#   serre      greenhouse at night: glass panes, moon, plants, fireflies
# =============================================================================

class_name Stage
extends Node2D

var theme_id: String = "atelier"
var camera_center := Vector2(900.0, -300.0)
var camera_zoom: float = 1.0
var _time: float = 0.0

func _ready() -> void:
	z_index = -10

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _view() -> Rect2:
	var half := Vector2(640.0, 360.0) / camera_zoom
	return Rect2(camera_center - half - Vector2(40.0, 40.0), half * 2.0 + Vector2(80.0, 80.0))

## World position of a point placed at x on a layer of parallax factor f.
func _lx(x: float, f: float) -> float:
	return x + camera_center.x * (1.0 - f) - 900.0 * (1.0 - f)

func _draw() -> void:
	var v: Rect2 = _view()
	match theme_id:
		"fonderie":
			_draw_foundry(v)
		"serre":
			_draw_greenhouse(v)
		_:
			_draw_workshop(v)

func _gradient(v: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([v.position, Vector2(v.end.x, v.position.y), v.end, Vector2(v.position.x, v.end.y)]), PackedColorArray([top, top, bottom, bottom]))

func _gear(at: Vector2, r: float, teeth: int, angle: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in teeth * 4:
		var a: float = angle + TAU * k / (teeth * 4)
		var rr: float = r * (1.0 if (k % 4) < 2 else 0.84)
		pts.append(at + Vector2.RIGHT.rotated(a) * rr)
	draw_colored_polygon(pts, color)
	draw_circle(at, r * 0.62, color.darkened(0.2))
	for k in 5:
		var a2: float = angle + TAU * k / 5.0
		draw_line(at, at + Vector2.RIGHT.rotated(a2) * r * 0.62, color.lightened(0.08), r * 0.1)
	draw_circle(at, r * 0.18, color.lightened(0.15))

func _floor(v: Rect2, base: Color, line: Color, plank: float) -> void:
	draw_rect(Rect2(v.position.x, 0.0, v.size.x, v.end.y), base)
	draw_rect(Rect2(v.position.x, 0.0, v.size.x, 6.0), base.lightened(0.15))
	var cx: float = camera_center.x
	var x: float = floorf(v.position.x / plank) * plank - plank * 4.0
	while x < v.end.x + plank * 4.0:
		draw_line(Vector2(x, 0.0), Vector2(cx + (x - cx) * 2.4, 420.0), line, 2.0)
		x += plank
	var y: float = 22.0
	var gap: float = 24.0
	while y < v.end.y:
		draw_line(Vector2(v.position.x, y), Vector2(v.end.x, y), Color(line, line.a * 0.6), 1.5)
		y += gap
		gap *= 1.35

func _draw_workshop(v: Rect2) -> void:
	_gradient(v, Color("2b1d14"), Color("4a3020"))
	var glow: Texture2D = Fx.glow()
	var wx: float = _lx(900.0, 0.2)
	var win := Rect2(wx - 160.0, -560.0, 320.0, 260.0)
	draw_rect(win.grow(10.0), Color("3a2618"))
	_gradient(win, Color("101a3a"), Color("2a3a6a"))
	draw_circle(win.position + Vector2(230.0, 70.0), 30.0, Color("f4ecd0"))
	Fx.put(self, glow, win.position + Vector2(230.0, 70.0), 90.0, Color(0.9, 0.9, 1.0, 0.25))
	for k in 3:
		draw_line(Vector2(win.position.x + win.size.x * (k + 1) / 4.0, win.position.y), Vector2(win.position.x + win.size.x * (k + 1) / 4.0, win.end.y), Color("3a2618"), 6.0)
	draw_line(Vector2(win.position.x, win.position.y + win.size.y * 0.5), Vector2(win.end.x, win.position.y + win.size.y * 0.5), Color("3a2618"), 6.0)
	var gears: Array = [[200.0, -430.0, 190.0, 18, 0.12], [520.0, -260.0, 110.0, 12, -0.2], [1320.0, -400.0, 230.0, 22, 0.09], [1620.0, -200.0, 120.0, 12, -0.18], [1080.0, -620.0, 90.0, 10, 0.25]]
	for g in gears:
		_gear(Vector2(_lx(float(g[0]), 0.35), float(g[1])), float(g[2]), int(g[3]), _time * float(g[4]), Color("5a3e22"))
	for k in 6:
		var sx: float = _lx(120.0 + k * 300.0, 0.6)
		draw_rect(Rect2(sx, -190.0, 200.0, 10.0), Color("6a4628"))
		for c in 3:
			var at := Vector2(sx + 35.0 + c * 65.0, -215.0)
			draw_circle(at, 18.0, Color("8a6a3a"))
			draw_circle(at, 14.0, Color("e8dcb8"))
			var hand: float = _time * (0.5 + c * 0.3) + k
			draw_line(at, at + Vector2.UP.rotated(hand) * 11.0, Color("2a1a10"), 2.0)
	for k in 4:
		var lx: float = _lx(250.0 + k * 450.0, 0.85)
		var swing: float = sin(_time * 1.3 + k) * 0.08
		var top := Vector2(lx, -760.0)
		var bulb: Vector2 = top + Vector2(0.0, 360.0).rotated(swing)
		draw_line(top, bulb, Color("1a120c"), 3.0)
		Fx.put(self, glow, bulb, 170.0, Color(1.0, 0.75, 0.4, 0.22))
		draw_colored_polygon(PackedVector2Array([bulb + Vector2(-26.0, 0.0), bulb + Vector2(26.0, 0.0), bulb + Vector2(12.0, -22.0), bulb + Vector2(-12.0, -22.0)]), Color("3a2a1a"))
		draw_circle(bulb + Vector2(0.0, 6.0), 9.0, Color("ffe0a0"))
	_floor(v, Color("5a3a22"), Color(0.2, 0.12, 0.06, 0.6), 90.0)

func _draw_foundry(v: Rect2) -> void:
	_gradient(v, Color("1a0a0a"), Color("3a1410"))
	var glow: Texture2D = Fx.glow()
	for k in 4:
		var fx: float = _lx(200.0 + k * 480.0, 0.3)
		var mouth := Rect2(fx - 90.0, -330.0, 180.0, 150.0)
		draw_rect(mouth.grow(26.0), Color("2a1a18"))
		var flick: float = 0.8 + 0.2 * sin(_time * 9.0 + k * 2.0) + 0.1 * sin(_time * 23.0 + k)
		_gradient(mouth, Color(1.0, 0.75, 0.3) * flick, Color(1.0, 0.35, 0.1) * flick)
		Fx.put(self, glow, mouth.get_center(), 260.0, Color(1.0, 0.45, 0.15, 0.25 * flick))
		draw_rect(Rect2(fx - 120.0, -460.0, 240.0, 30.0), Color("3a2420"))
		draw_rect(Rect2(fx - 40.0, -900.0, 80.0, 440.0), Color("2a1816"))
	var channel_y: float = -120.0
	var cx0: float = _lx(-200.0, 0.5)
	draw_rect(Rect2(cx0, channel_y, 2600.0, 26.0), Color(1.0, 0.5, 0.15))
	for k in 30:
		var x: float = cx0 + fmod(k * 97.0 + _time * 60.0, 2600.0)
		draw_circle(Vector2(x, channel_y + 12.0), 8.0, Color(1.0, 0.85, 0.4, 0.8))
	for k in 6:
		var chx: float = _lx(80.0 + k * 330.0, 0.7)
		var sway: float = sin(_time * 0.9 + k) * 6.0
		for link in 14:
			var at := Vector2(chx + sway * link / 14.0, -900.0 + link * 40.0)
			draw_arc(at, 12.0, 0.0, TAU, 10, Color("1a0e0c"), 5.0)
	for k in 40:
		var ex: float = v.position.x + fmod(k * 173.0, v.size.x)
		var ey: float = fmod(-_time * (40.0 + k % 7 * 12.0) - k * 61.0, 700.0)
		Fx.put(self, glow, Vector2(ex + sin(_time + k) * 20.0, ey), 10.0, Color(1.0, 0.6, 0.2, 0.6))
	_floor(v, Color("3a3438"), Color(0.1, 0.08, 0.1, 0.7), 140.0)
	var rx: float = floorf(v.position.x / 140.0) * 140.0
	while rx < v.end.x:
		draw_circle(Vector2(rx + 70.0, 12.0), 3.0, Color("6a6268"))
		rx += 140.0

func _draw_greenhouse(v: Rect2) -> void:
	_gradient(v, Color("0a1426"), Color("1c3a3a"))
	var glow: Texture2D = Fx.glow()
	var moon := Vector2(_lx(1300.0, 0.08), -620.0)
	Fx.put(self, glow, moon, 220.0, Color(0.8, 0.9, 1.0, 0.25))
	draw_circle(moon, 46.0, Color("eef4ff"))
	for k in 60:
		var sx: float = v.position.x + fmod(k * 211.0, v.size.x)
		var sy: float = -900.0 + fmod(k * 137.0, 500.0)
		draw_circle(Vector2(sx, sy), 1.5, Color(1.0, 1.0, 1.0, 0.4 + 0.4 * sin(_time * 2.0 + k)))
	var frame := Color("1e2e2a")
	var px: float = floorf((v.position.x - camera_center.x * 0.75) / 220.0) * 220.0
	for k in 14:
		var x: float = px + k * 220.0 + camera_center.x * 0.75
		draw_line(Vector2(x, -1000.0), Vector2(x, 0.0), frame, 8.0)
	for y in [-760.0, -520.0, -300.0]:
		draw_line(Vector2(v.position.x, y), Vector2(v.end.x, y), frame, 6.0)
	for k in 9:
		var bx: float = _lx(60.0 + k * 230.0, 0.55)
		var h: float = 160.0 + float((k * 53) % 90)
		var leaf := Color("16382a")
		draw_rect(Rect2(bx - 40.0, -60.0, 80.0, 60.0), Color("3a2a22"))
		for l in 7:
			var a: float = -PI * 0.5 + (l - 3) * 0.32 + sin(_time * 0.8 + k + l) * 0.04
			var tip := Vector2(bx, -60.0) + Vector2.RIGHT.rotated(a) * h * (0.6 + 0.4 * float((l * 3 + k) % 4) / 3.0)
			draw_line(Vector2(bx, -60.0), tip, leaf, 10.0)
			draw_circle(tip, 12.0, leaf)
	for k in 8:
		var vx: float = _lx(100.0 + k * 260.0, 0.9)
		var vine := PackedVector2Array()
		for s in 10:
			vine.append(Vector2(vx + sin(_time * 1.1 + k + s * 0.5) * 8.0 * s / 10.0, -980.0 + s * 34.0))
		draw_polyline(vine, Color("1e4a32"), 5.0)
	for k in 18:
		var fx: float = v.position.x + fmod(k * 157.0 + sin(_time * 0.5 + k) * 60.0, v.size.x)
		var fy: float = -150.0 - fmod(k * 83.0, 400.0) + sin(_time * 1.3 + k) * 20.0
		Fx.put(self, glow, Vector2(fx, fy), 14.0, Color(0.85, 1.0, 0.5, 0.5 + 0.4 * sin(_time * 3.0 + k)))
	_floor(v, Color("2e4a44"), Color(0.08, 0.16, 0.14, 0.6), 110.0)

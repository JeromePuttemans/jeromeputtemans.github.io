# =============================================================================
# HudIcon.gd: Control that draws a small vector icon with _draw().
# =============================================================================
# Replaces emoji in the UI: emoji glyphs depend on the system fonts and are
# missing in the Web export, vector icons render identically everywhere.
#
# kind:
#   coin, heart, wave, star, damage, range, rate, splash,
#   pause, play, speed1, speed2, sound, mute,
#   tower:<id>  mini tower drawn with Tower.draw_model (shop cards)
#   enemy:<id>  mini enemy drawn with Enemy.draw_model (wave preview)
# animate: the icon redraws every frame (turret slowly turning, enemy walking).
# =============================================================================

class_name HudIcon
extends Control

@export var kind: String = "coin":
	set(value):
		kind = value
		queue_redraw()
@export var tint: Color = Color.WHITE:
	set(value):
		tint = value
		queue_redraw()
@export var animate: bool = false

var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if animate:
		_time += delta
		queue_redraw()

func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size * 0.5
	var r: float = s * 0.5
	if kind.begins_with("tower:"):
		_draw_tower(kind.substr(6), c, s)
		return
	if kind.begins_with("enemy:"):
		_draw_enemy(kind.substr(6), c, r)
		return
	match kind:
		"coin":
			draw_circle(c, r * 0.9, Color("b8860b"))
			draw_circle(c, r * 0.72, Color("ffd34d"))
			draw_rect(Rect2(c.x - r * 0.12, c.y - r * 0.42, r * 0.24, r * 0.84), Color("d9a520"))
		"heart":
			var col := Color("ff5d6c")
			draw_circle(c + Vector2(-r * 0.38, -r * 0.18), r * 0.42, col)
			draw_circle(c + Vector2(r * 0.38, -r * 0.18), r * 0.42, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.05),
				c + Vector2(r * 0.8, -r * 0.05), c + Vector2(0, r * 0.82)]), col)
			draw_circle(c + Vector2(-r * 0.45, -r * 0.3), r * 0.13, Color(1, 1, 1, 0.6))
		"wave":
			Enemy.draw_model(self, "blob", Color("ff5a5a"), r * 0.75, Vector2.DOWN, c + Vector2(0, -r * 0.05), 0.0, 0.0)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var rad: float = r * (0.9 if i % 2 == 0 else 0.4)
				pts.append(c + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * rad)
			draw_colored_polygon(pts, Color("b48cff"))
		"damage":
			draw_line(c + Vector2(-r * 0.7, r * 0.7), c + Vector2(r * 0.7, -r * 0.7), tint, 2.5, true)
			draw_line(c + Vector2(-r * 0.75, r * 0.15), c + Vector2(-r * 0.15, r * 0.75), tint, 2.5, true)
		"range":
			draw_arc(c, r * 0.8, 0.0, TAU, 24, tint, 1.8, true)
			draw_circle(c, r * 0.22, tint)
		"rate":
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.2, -r * 0.9),
				c + Vector2(-r * 0.5, r * 0.1), c + Vector2(-r * 0.02, r * 0.1),
				c + Vector2(-r * 0.2, r * 0.9), c + Vector2(r * 0.5, -r * 0.1),
				c + Vector2(r * 0.02, -r * 0.1)]), tint)
		"splash":
			for i in 8:
				var dir := Vector2.from_angle(i * PI * 0.25)
				draw_line(c + dir * r * 0.3, c + dir * r * 0.85, tint, 2.0, true)
			draw_circle(c, r * 0.25, tint)
		"pause":
			draw_rect(Rect2(c.x - r * 0.45, c.y - r * 0.5, r * 0.3, r), tint)
			draw_rect(Rect2(c.x + r * 0.15, c.y - r * 0.5, r * 0.3, r), tint)
		"play", "speed1":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.35, -r * 0.5),
				c + Vector2(r * 0.5, 0), c + Vector2(-r * 0.35, r * 0.5)]), tint)
		"speed2":
			for dx in [-0.45, 0.15]:
				var o := c + Vector2(r * float(dx), 0)
				draw_colored_polygon(PackedVector2Array([o + Vector2(-r * 0.25, -r * 0.45),
					o + Vector2(r * 0.4, 0), o + Vector2(-r * 0.25, r * 0.45)]), tint)
		"sound", "mute":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.22),
				c + Vector2(-r * 0.35, -r * 0.22), c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.6),
				c + Vector2(-r * 0.35, r * 0.22), c + Vector2(-r * 0.7, r * 0.22)]), tint)
			if kind == "sound":
				draw_arc(c + Vector2(r * 0.05, 0), r * 0.35, -0.9, 0.9, 10, tint, 1.8, true)
				draw_arc(c + Vector2(r * 0.05, 0), r * 0.65, -0.9, 0.9, 12, tint, 1.8, true)
			else:
				draw_line(c + Vector2(r * 0.25, -r * 0.3), c + Vector2(r * 0.8, r * 0.3), Color("ff5d6c"), 2.2, true)
				draw_line(c + Vector2(r * 0.8, -r * 0.3), c + Vector2(r * 0.25, r * 0.3), Color("ff5d6c"), 2.2, true)

func _draw_tower(id: String, c: Vector2, s: float) -> void:
	var data: Dictionary = TowerDatabase.get_type(id)
	if data.is_empty():
		return
	var col := Color("#" + str(data.get("color", "ffffff")))
	var angle: float = -PI * 0.25 + (sin(_time * 1.6) * 0.6 if animate else 0.0)
	Tower.draw_model(self, str(data.get("attack", "bullet")), col, s * 1.05, angle,
		0.0, 0.0, 1, tint.a, c + Vector2(0, -s * 0.03), 1.0)

func _draw_enemy(id: String, c: Vector2, r: float) -> void:
	var data: Dictionary = EnemyDatabase.get_type(id)
	if data.is_empty():
		return
	var col := Color("#" + str(data.get("color", "ffffff")))
	var size_ratio: float = clampf(float(data.get("size", 0.25)) / 0.34, 0.8, 1.0)
	Enemy.draw_model(self, str(data.get("shape", "blob")), col, r * 0.78 * size_ratio,
		Vector2.RIGHT, c + Vector2(0, -r * 0.05), 0.0, _time)

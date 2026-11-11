# =============================================================================
# Background.gd — Scrolling space behind the field
# =============================================================================
# Three star layers scroll down at different speeds (near stars faster and
# brighter: parallax), nebula clouds drift slowly, and a planet passes in
# the middle of the stage. The colours follow the stage progress through
# the "palettes" of stage.json, blended between two neighbours, so the sky
# turns from blue to violet to red as the boss gets closer.
# warp (1 = normal) speeds everything up and stretches the near stars into
# streaks, used when the boss arrives.
# =============================================================================

class_name Background
extends Node2D

const LAYER_SPEEDS: Array[float] = [22.0, 60.0, 150.0]
const LAYER_COUNTS: Array[int] = [70, 45, 22]

var field := Vector2(540.0, 720.0)
var progress: float = 0.0
var warp: float = 1.0
var palettes: Array = []
var _stars: Array[PackedVector2Array] = []
var _nebulae: Array[Dictionary] = []
var _time: float = 0.0
var _planet_y: float = -400.0

func _ready() -> void:
	for layer in 3:
		var stars := PackedVector2Array()
		for i in LAYER_COUNTS[layer]:
			stars.append(Vector2(randf() * field.x, randf() * field.y))
		_stars.append(stars)
	for i in 5:
		_nebulae.append({pos = Vector2(randf() * field.x, randf() * field.y), radius = randf_range(140.0, 260.0), speed = randf_range(8.0, 16.0), tint = randf()})

func _process(delta: float) -> void:
	_time += delta
	var w: float = warp
	for layer in 3:
		var stars: PackedVector2Array = _stars[layer]
		var dy: float = LAYER_SPEEDS[layer] * w * delta
		for i in stars.size():
			var p: Vector2 = stars[i]
			p.y += dy
			if p.y > field.y + 4.0:
				p = Vector2(randf() * field.x, -4.0)
			stars[i] = p
		_stars[layer] = stars
	for n in _nebulae:
		var p: Vector2 = n["pos"]
		p.y += float(n["speed"]) * w * delta
		if p.y - float(n["radius"]) > field.y:
			p = Vector2(randf() * field.x, -float(n["radius"]))
		n["pos"] = p
	var planet_window: float = clampf((progress - 0.3) / 0.3, 0.0, 1.0)
	_planet_y = lerpf(-260.0, field.y + 260.0, planet_window)
	queue_redraw()

func _palette() -> Dictionary:
	if palettes.is_empty():
		return {top = "070b1e", bottom = "1a1040", nebula = "3050ff", accent = "8fd9ff"}
	var a: Dictionary = palettes[0] as Dictionary
	var b: Dictionary = a
	for entry in palettes:
		var e: Dictionary = entry as Dictionary
		if progress >= float(e.get("at", 0.0)):
			a = e
		else:
			b = e
			break
	var span: float = float(b.get("at", 1.0)) - float(a.get("at", 0.0))
	var t: float = clampf((progress - float(a.get("at", 0.0))) / span, 0.0, 1.0) if span > 0.0 else 0.0
	var out: Dictionary = {}
	for key in ["top", "bottom", "nebula", "accent"]:
		out[key] = Color(str(a.get(key, "000000"))).lerp(Color(str(b.get(key, "000000"))), t)
	return out

func _draw() -> void:
	var pal: Dictionary = _palette()
	var top: Color = pal["top"] if pal["top"] is Color else Color(str(pal["top"]))
	var bottom: Color = pal["bottom"] if pal["bottom"] is Color else Color(str(pal["bottom"]))
	var nebula: Color = pal["nebula"] if pal["nebula"] is Color else Color(str(pal["nebula"]))
	var accent: Color = pal["accent"] if pal["accent"] is Color else Color(str(pal["accent"]))
	var m: float = 40.0
	draw_polygon(PackedVector2Array([Vector2(-m, -m), Vector2(field.x + m, -m), Vector2(field.x + m, field.y + m), Vector2(-m, field.y + m)]),
		PackedColorArray([top, top, bottom, bottom]))
	var glow: Texture2D = Tex.glow()
	for n in _nebulae:
		var c: Color = nebula.lerp(accent, float(n["tint"]) * 0.5)
		Tex.put(self, glow, n["pos"] as Vector2, float(n["radius"]), Color(c, 0.16))
	if _planet_y > -250.0 and _planet_y < field.y + 250.0:
		_draw_planet(Vector2(field.x * 0.72, _planet_y), accent)
	for layer in 3:
		var stars: PackedVector2Array = _stars[layer]
		var alpha: float = 0.35 + 0.3 * layer
		var size: float = 1.0 + layer * 0.7
		var streak: float = (warp - 1.0) * LAYER_SPEEDS[layer] * 0.08
		for p in stars:
			if streak > 1.0:
				draw_line(p, p - Vector2(0.0, streak), Color(1.0, 1.0, 1.0, alpha * 0.8), size)
			else:
				Tex.put(self, glow, p, size * 2.2, Color(0.85, 0.92, 1.0, alpha))

func _draw_planet(at: Vector2, accent: Color) -> void:
	var r: float = 150.0
	var base: Color = accent.darkened(0.55)
	Tex.put(self, Tex.glow(), at, r * 1.5, Color(accent, 0.18))
	draw_circle(at, r, base)
	for k in 5:
		var band_y: float = at.y - r + (k + 0.5) * r * 2.0 / 5.0
		var half: float = sqrt(maxf(r * r - (band_y - at.y) * (band_y - at.y), 0.0))
		draw_line(Vector2(at.x - half, band_y), Vector2(at.x + half, band_y), Color(accent.darkened(0.35), 0.5), 10.0)
	draw_circle(at + Vector2(r * 0.25, r * 0.2), r * 0.92, Color(0.0, 0.0, 0.05, 0.45))
	draw_arc(at, r * 1.45, PI * 1.08, PI * 1.92, 48, Color(accent, 0.55), 3.0)
	draw_arc(at, r * 1.3, PI * 1.04, PI * 1.96, 48, Color(accent, 0.3), 6.0)

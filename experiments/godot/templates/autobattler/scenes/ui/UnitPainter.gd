# =============================================================================
# UnitPainter.gd — Draws a unit token anywhere (board, bench, shop, info)
# =============================================================================
# A token reads at a glance:
#   body colour   origin (ember orange, frost cyan, grove green)
#   icon          class: shield (guardian), sword (blade), four-point star
#                 (arcane), bow (ranger); the boss has a glowing eye
#   outer ring    side: blue for the player, red for the enemy
#   pips          one gold diamond per star above the token
# Everything is drawn with polygons, so it scales with the token radius.
# =============================================================================

class_name UnitPainter
extends RefCounted

static func origin_color(data: Dictionary) -> Color:
	var traits: Array = data.get("traits", []) as Array
	for t in traits:
		if UnitDatabase.trait_data(str(t)).get("kind", "") == "origin":
			return UnitDatabase.trait_color(str(t))
	return Color(0.62, 0.48, 0.85)

static func class_id(data: Dictionary) -> String:
	for t in data.get("traits", []) as Array:
		if UnitDatabase.trait_data(str(t)).get("kind", "") == "class":
			return str(t)
	return ""

## options: alpha, team (0 / 1 / -1 none), star, flash (0..1)
static func draw_token(canvas: CanvasItem, center: Vector2, radius: float, data: Dictionary, options: Dictionary) -> void:
	var alpha: float = float(options.get("alpha", 1.0))
	var team: int = int(options.get("team", -1))
	var body: Color = origin_color(data)
	canvas.draw_circle(center + Vector2(0.0, radius * 0.85), radius * 0.8, Color(0.0, 0.0, 0.0, 0.25 * alpha))
	if team >= 0:
		canvas.draw_circle(center, radius * 1.12, Color(UiTheme.PLAYER if team == 0 else UiTheme.ENEMY, 0.85 * alpha))
	canvas.draw_circle(center, radius, Color(body.darkened(0.55), alpha))
	canvas.draw_circle(center, radius * 0.86, Color(body.darkened(0.25), alpha))
	canvas.draw_arc(center, radius * 0.93, 0.0, TAU, 32, Color(body.lightened(0.2), alpha), maxf(radius * 0.12, 1.5), true)
	var icon_color := Color(1.0, 0.97, 0.9, alpha)
	if bool(data.get("boss", false)):
		_draw_eye(canvas, center, radius, alpha)
	else:
		draw_class_icon(canvas, center, radius * 0.55, class_id(data), icon_color)
	var flash: float = float(options.get("flash", 0.0))
	if flash > 0.0:
		canvas.draw_circle(center, radius, Color(1.0, 1.0, 1.0, flash * 0.8 * alpha))
	draw_stars(canvas, center + Vector2(0.0, -radius * 1.3), int(options.get("star", 1)), radius * 0.22, alpha)

static func draw_class_icon(canvas: CanvasItem, c: Vector2, s: float, class_name_id: String, color: Color) -> void:
	match class_name_id:
		"guardian":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -1) * s, c + Vector2(0.85, -0.65) * s,
				c + Vector2(0.75, 0.3) * s, c + Vector2(0, 1) * s, c + Vector2(-0.75, 0.3) * s, c + Vector2(-0.85, -0.65) * s]), color)
		"blade":
			canvas.draw_line(c + Vector2(-0.7, 0.7) * s, c + Vector2(0.75, -0.75) * s, color, s * 0.32, true)
			canvas.draw_line(c + Vector2(-0.55, 0.05) * s, c + Vector2(-0.05, 0.55) * s, color, s * 0.24, true)
			canvas.draw_circle(c + Vector2(-0.8, 0.8) * s, s * 0.17, color)
		"arcane":
			var star := PackedVector2Array()
			for i in 8:
				var r: float = s if i % 2 == 0 else s * 0.35
				star.append(c + Vector2.UP.rotated(TAU * i / 8.0) * r)
			canvas.draw_colored_polygon(star, color)
		"ranger":
			canvas.draw_arc(c + Vector2(-0.25, 0) * s, s * 0.85, -PI * 0.42, PI * 0.42, 16, color, s * 0.2, true)
			canvas.draw_line(c + Vector2(0.05, -0.8) * s, c + Vector2(0.05, 0.8) * s, color, s * 0.1, true)
			canvas.draw_line(c + Vector2(-0.6, 0) * s, c + Vector2(0.95, 0) * s, color, s * 0.14, true)
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(1.05, 0) * s, c + Vector2(0.7, -0.22) * s, c + Vector2(0.7, 0.22) * s]), color)

static func _draw_eye(canvas: CanvasItem, c: Vector2, radius: float, alpha: float) -> void:
	var eye := PackedVector2Array()
	for i in 16:
		var angle: float = TAU * i / 16.0
		eye.append(c + Vector2(cos(angle) * radius * 0.6, sin(angle) * radius * 0.3))
	canvas.draw_colored_polygon(eye, Color(1.0, 0.85, 0.4, alpha))
	canvas.draw_circle(c, radius * 0.18, Color(0.5, 0.05, 0.1, alpha))

static func draw_stars(canvas: CanvasItem, center: Vector2, count: int, size: float, alpha: float) -> void:
	var spacing: float = size * 2.3
	var start: Vector2 = center - Vector2(spacing * (count - 1) * 0.5, 0.0)
	for i in count:
		var p: Vector2 = start + Vector2(spacing * i, 0.0)
		var diamond := PackedVector2Array([p + Vector2(0, -size), p + Vector2(size * 0.8, 0), p + Vector2(0, size), p + Vector2(-size * 0.8, 0)])
		canvas.draw_colored_polygon(diamond, Color(UiTheme.GOLD, alpha))
		canvas.draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0.3, 0.2, 0.0, alpha), 1.0, true)

## Health bar (with shield) and mana bar above a token, for battles.
static func draw_bars(canvas: CanvasItem, center: Vector2, radius: float, unit: Unit) -> void:
	var width: float = radius * 2.1
	var origin: Vector2 = center + Vector2(-width * 0.5, -radius * 1.75)
	var ratio: float = clampf(unit.hp / maxf(unit.hp_max, 1.0), 0.0, 1.0)
	canvas.draw_rect(Rect2(origin - Vector2(1, 1), Vector2(width + 2, 7)), Color(0.0, 0.0, 0.0, 0.75))
	var color: Color = UiTheme.GOOD if ratio > 0.5 else (UiTheme.GOLD if ratio > 0.25 else UiTheme.BAD)
	if unit.team == 1:
		color = UiTheme.ENEMY.lerp(color, 0.25)
	canvas.draw_rect(Rect2(origin, Vector2(width * ratio, 5)), color)
	if unit.shield > 0.0:
		var shield_ratio: float = clampf(unit.shield / maxf(unit.hp_max, 1.0), 0.0, 1.0 - ratio)
		canvas.draw_rect(Rect2(origin + Vector2(width * ratio, 0), Vector2(width * shield_ratio, 5)), Color(0.95, 0.95, 1.0))
	if unit.mana_max > 0.0:
		canvas.draw_rect(Rect2(origin + Vector2(0, 6), Vector2(width * clampf(unit.mana / unit.mana_max, 0.0, 1.0), 2)), UiTheme.MANA)

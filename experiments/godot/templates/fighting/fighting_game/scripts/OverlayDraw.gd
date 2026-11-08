# OverlayDraw.gd
# Node2D child of ControlsOverlay. Renders the controls panel via _draw().

extends Node2D

var _show: bool  = false
var _p1: Array   = []
var _p2: Array   = []

func set_visible_data(show: bool, p1: Array, p2: Array) -> void:
	_show = show
	_p1   = p1
	_p2   = p2
	queue_redraw()

func _draw() -> void:
	if not _show:
		return

	var vp  := get_viewport_rect()
	var pw  := 285.0
	var ph  := 288.0
	var pad := 12.0
	var lh  := 28.0

	var bg     := Color(0.05, 0.05, 0.10, 0.90)
	var border := Color(0.40, 0.40, 0.60, 1.00)

	# P1 panel — bottom left
	_draw_panel(
		Vector2(20.0, vp.size.y - ph - 20.0),
		pw, ph, bg, border,
		"JOUEUR 1 (WASD)", Color(0.3, 0.6, 1.0), _p1, pad, lh
	)
	# P2 panel — bottom right
	_draw_panel(
		Vector2(vp.size.x - pw - 20.0, vp.size.y - ph - 20.0),
		pw, ph, bg, border,
		"JOUEUR 2 (PAVE NUM)", Color(1.0, 0.45, 0.2), _p2, pad, lh
	)

func _draw_panel(pos: Vector2, w: float, h: float,
				bg: Color, border: Color,
				title: String, title_col: Color,
				rows: Array, pad: float, lh: float) -> void:

	var font := ThemeDB.fallback_font

	# Drop shadow
	draw_rect(Rect2(pos + Vector2(4, 4), Vector2(w, h)), Color(0, 0, 0, 0.5))
	# Background + border
	draw_rect(Rect2(pos, Vector2(w, h)), bg)
	draw_rect(Rect2(pos, Vector2(w, h)), border, false, 2.0)

	var y := pos.y + pad + 18.0

	# Title
	draw_string(font, Vector2(pos.x + pad, y), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, title_col)
	y += 8.0
	# Separator
	draw_line(Vector2(pos.x + pad, y), Vector2(pos.x + w - pad, y), border, 1.5)
	y += lh * 0.55

	# Rows: key badge + action label
	var badge_w := 76.0
	for row in rows:
		var key_str: String = str(row[0])
		var act_str: String = str(row[1])

		# Badge background + border
		draw_rect(Rect2(Vector2(pos.x + pad, y - 15), Vector2(badge_w, 21)),
			Color(0.18, 0.18, 0.28, 1.0))
		draw_rect(Rect2(Vector2(pos.x + pad, y - 15), Vector2(badge_w, 21)),
			border, false, 1.0)
		draw_string(font, Vector2(pos.x + pad + 4, y),
			key_str, HORIZONTAL_ALIGNMENT_LEFT, int(badge_w) - 8, 12, Color.WHITE)

		# Action text
		draw_string(font, Vector2(pos.x + pad + badge_w + 10, y),
			act_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.85, 1.0))
		y += lh

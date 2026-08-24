# =============================================================================
# BoardView.gd — Dungeon/board renderer (Node2D, uses _draw()).
# =============================================================================
# Reads RoundManager.board and draws board slots + unit glyphs.
# Contains NO game logic — pure view.
#
# CLICK HANDLING:
#   Clicking a board slot in PREP phase calls RoundManager.return_unit_to_bench().
#   The tile_size comes from config so the click→slot mapping stays in sync.
# =============================================================================

extends Node2D

var _tile_size: int = 72

func _ready() -> void:
	RoundManager.board_changed.connect(queue_redraw)
	RoundManager.phase_changed.connect(_on_phase_changed)
	RoundManager.battle_event.connect(_on_battle_event)
	_tile_size = ConfigManager.get_int("tile_size", 72)
	StringManager.language_changed.connect(func(_l): queue_redraw())

func _on_phase_changed(_p: RoundManager.Phase) -> void:
	queue_redraw()

func _on_battle_event(_ev: BattleSimulator.BattleEvent) -> void:
	# Redraw after every combat tick so HP bars animate in real time
	queue_redraw()

func _draw() -> void:
	if RoundManager.board == null:
		return
	var b     = RoundManager.board
	var ts    = _tile_size
	var font  = ThemeDB.fallback_font
	var fsz   = ts - 12

	for row in b.rows:
		for col in b.cols:
			var screen = Vector2(col * ts, row * ts)
			var rect   = Rect2(screen, Vector2(ts - 2, ts - 2))

			# Slot background
			draw_rect(rect, Color(0.15, 0.15, 0.25, 1.0))
			draw_rect(rect, Color(0.3, 0.3, 0.5, 1.0), false, 1.0)

			var unit: Unit = b.get_board_unit(col, row)
			if unit == null:
				continue

			# Unit background highlight
			draw_rect(rect, unit.color * Color(1, 1, 1, 0.3))

			# Glyph centred in tile
			draw_string(font,
				screen + Vector2(ts * 0.5 - fsz * 0.3, ts * 0.5 + fsz * 0.35),
				unit.glyph,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, unit.color)

			# HP bar at bottom of tile (shows current/max ratio)
			var hp_ratio = float(unit.hp_current) / float(unit.hp_max)
			var bar_w    = (ts - 6) * hp_ratio
			draw_rect(Rect2(screen + Vector2(3, ts - 7), Vector2(ts - 6, 4)),
				Color(0.2, 0.2, 0.2, 0.8))
			draw_rect(Rect2(screen + Vector2(3, ts - 7), Vector2(bar_w, 4)),
				_hp_color(hp_ratio))

## Returns a colour interpolated red→yellow→green based on HP ratio.
func _hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.2, 0.9, 0.2)
	elif ratio > 0.25:
		return Color(0.9, 0.8, 0.1)
	return Color(0.9, 0.2, 0.2)

func _input(event: InputEvent) -> void:
	# Only accept board clicks during PREP phase
	if RoundManager.phase != RoundManager.Phase.PREP:
		return
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	var local = to_local(event.position)
	var col   = int(local.x / _tile_size)
	var row   = int(local.y / _tile_size)

	if col < 0 or col >= RoundManager.board.cols:
		return
	if row < 0 or row >= RoundManager.board.rows:
		return

	var unit = RoundManager.board.get_board_unit(col, row)
	if unit == null:
		return
	RoundManager.return_unit_to_bench(unit)

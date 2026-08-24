# =============================================================================
# DungeonView.gd — Dungeon renderer (Node2D, uses _draw()).
# =============================================================================
# Reads GameState data and draws it each frame when queue_redraw() is called.
# Contains NO game logic — it is a pure view.
#
# DRAWING LAYERS (back to front):
#   1. Tile backgrounds (colored rectangles per cell)
#   2. Stairs glyph (">")
#   3. Enemy glyphs (only when in visible FOV)
#   4. Player glyph ("@", always on top)
#
# All colors and tile_size come from ConfigManager (data/config.json).
# All glyphs use ThemeDB.fallback_font, always available in Godot 4.
# =============================================================================

extends Node2D

func _ready() -> void:
	GameState.dungeon_ready.connect(queue_redraw)
	GameState.turn_ended.connect(queue_redraw)

func _draw() -> void:
	if GameState.dungeon == null or GameState.player == null:
		return
	if GameState.visible.is_empty():
		return

	var dungeon  = GameState.dungeon
	var ts       = ConfigManager.get_int("tile_size", 20)
	var font     = ThemeDB.fallback_font
	var font_sz  = ts - 2   # Glyph fits inside the tile with a small margin

	# Pre-fetch colors once to avoid repeated Dictionary lookups in the inner loop
	var c_wall_vis  = ConfigManager.get_color("wall_visible",   Color(0.227, 0.227, 0.361))
	var c_wall_exp  = ConfigManager.get_color("wall_explored",  Color(0.118, 0.118, 0.200))
	var c_floor_vis = ConfigManager.get_color("floor_visible",  Color(0.361, 0.361, 0.541))
	var c_floor_exp = ConfigManager.get_color("floor_explored", Color(0.165, 0.165, 0.259))
	var c_stairs    = ConfigManager.get_color("stairs",         Color(1.000, 0.843, 0.000))
	var c_hidden    = ConfigManager.get_color("hidden",         Color.BLACK)

	# --- Draw tiles ---------------------------------------------------------
	for x in dungeon.width:
		for y in dungeon.height:
			var screen = Vector2(x * ts, y * ts)
			var rect   = Rect2(screen, Vector2(ts, ts))
			var is_vis = GameState.visible[x][y]
			var is_exp = dungeon.explored[x][y]

			if not is_exp and not is_vis:
				draw_rect(rect, c_hidden)
				continue

			var tile = dungeon.get_tile(Vector2i(x, y))
			var bg: Color
			match tile:
				DungeonData.TileType.WALL:
					bg = c_wall_vis if is_vis else c_wall_exp
				DungeonData.TileType.STAIRS_DOWN:
					bg = c_stairs if is_vis else c_floor_exp
				_:  # FLOOR
					bg = c_floor_vis if is_vis else c_floor_exp

			draw_rect(rect, bg)

			# Draw stairs glyph only when visible
			if tile == DungeonData.TileType.STAIRS_DOWN and is_vis:
				draw_string(font,
					screen + Vector2(3, ts - 3),
					">", HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color.YELLOW)

	# --- Draw enemies (visible only) ----------------------------------------
	for enemy in GameState.enemies:
		if not enemy.is_alive():
			continue
		var ex = enemy.grid_pos.x
		var ey = enemy.grid_pos.y
		if not GameState.visible[ex][ey]:
			continue
		var screen = Vector2(ex * ts, ey * ts)
		# Dim tinted background so the glyph stands out against the floor
		draw_rect(Rect2(screen, Vector2(ts, ts)), enemy.color * Color(1, 1, 1, 0.35))
		draw_string(font,
			screen + Vector2(3, ts - 3),
			enemy.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, enemy.color)

	# --- Draw player --------------------------------------------------------
	var ps = Vector2(GameState.player.grid_pos.x * ts, GameState.player.grid_pos.y * ts)
	draw_string(font,
		ps + Vector2(3, ts - 3),
		"@", HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color.WHITE)

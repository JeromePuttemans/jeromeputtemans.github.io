# =============================================================================
# Minimap.gd (Control): explored layout of the current floor, 1 tile = N px.
# =============================================================================
# Shows what the player knows: explored floor, wall faces, the stairs once
# seen, remembered items, enemies currently in view and the player. Redrawn
# on dungeon_ready / turn_ended only (no per-frame cost), except for the
# blinking player dot.
# =============================================================================

class_name Minimap
extends Control

var _blink: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.dungeon_ready.connect(queue_redraw)
	GameState.turn_ended.connect(queue_redraw)

func _process(delta: float) -> void:
	_blink += delta
	queue_redraw()

func _draw() -> void:
	var d: DungeonData = GameState.dungeon
	if d == null or GameState.visible.is_empty():
		return
	var cell: float = floorf(minf(size.x / d.width, size.y / d.height))
	var origin: Vector2 = ((size - Vector2(d.width, d.height) * cell) * 0.5).floor()
	draw_rect(Rect2(origin - Vector2(2, 2), Vector2(d.width, d.height) * cell + Vector2(4, 4)), Color(0, 0, 0, 0.45))
	for x in d.width:
		for y in d.height:
			if not bool(d.explored[x][y]):
				continue
			var p := Vector2i(x, y)
			var r := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
			var vis: bool = bool(GameState.visible[x][y])
			match d.get_tile(p):
				DungeonData.TileType.WALL:
					draw_rect(r, Color("5d6680") if vis else Color("3a4152"))
				DungeonData.TileType.STAIRS_DOWN:
					draw_rect(r.grow(1.0), Color("7fe3ff") if d.is_last_floor else Color("ffd34d"))
				_:
					draw_rect(r, Color("8d97b0") if vis else Color("4a5266"))
	for pos_v in d.items.keys():
		var pos: Vector2i = pos_v as Vector2i
		if bool(d.explored[pos.x][pos.y]):
			draw_rect(Rect2(origin + Vector2(pos) * cell, Vector2(cell, cell)), Color("5fd6ff"))
	for e in GameState.enemies:
		if bool(GameState.visible[e.grid_pos.x][e.grid_pos.y]):
			draw_rect(Rect2(origin + Vector2(e.grid_pos) * cell, Vector2(cell, cell)).grow(0.5), Color("ff5d5d"))
	var pp: Vector2 = origin + (Vector2(GameState.player.grid_pos) + Vector2(0.5, 0.5)) * cell
	draw_circle(pp, cell * (1.4 + 0.3 * sin(_blink * 6.0)), Color(1, 1, 1, 0.35))
	draw_circle(pp, cell, Color.WHITE)

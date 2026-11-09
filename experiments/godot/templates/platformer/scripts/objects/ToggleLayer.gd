# =============================================================================
# ToggleLayer.gd — Draws the amber ('a') and blue ('b') blocks
# =============================================================================
# Level.toggle_phase 0: amber blocks are solid, 1: blue blocks are solid.
# Solid blocks are filled, passable ones are a dashed outline, so the next
# state is always visible. swapped() starts a short pop on every block.
# =============================================================================

class_name ToggleLayer
extends Node2D

const AMBER: Color = Color("f2a93b")
const BLUE: Color = Color("3ba7f2")

var cells: Array[Vector2i] = []
var _level: Level = null
var _pop: float = 1.0

func setup(level: Level, toggle_cells: Array[Vector2i]) -> void:
	_level = level
	cells = toggle_cells

func swapped() -> void:
	_pop = 0.0

func _process(delta: float) -> void:
	_pop = minf(_pop + delta * 6.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var t: float = LevelData.TILE
	var bump: float = sin(_pop * PI) * 4.0
	for cell in cells:
		var is_a: bool = _level.data.tile(cell.x, cell.y) == LevelData.Tile.TOGGLE_A
		var color: Color = AMBER if is_a else BLUE
		var solid: bool = is_a == (_level.toggle_phase == 0)
		var r := Rect2(Vector2(cell) * t, Vector2(t, t))
		if solid:
			var g: Rect2 = r.grow(bump * 0.5 - 1.0)
			var alpha: float = 0.45 if _level.is_ghost(cell) else 1.0
			draw_rect(g, Color(color.darkened(0.45), alpha))
			draw_rect(g.grow(-3.0), Color(color, alpha))
			draw_rect(Rect2(g.position + Vector2(3.0, 3.0), Vector2(g.size.x - 6.0, 4.0)), Color(color.lightened(0.35), alpha))
			_draw_symbol(r.get_center(), is_a, Color(color.darkened(0.4), alpha))
		else:
			var g2: Rect2 = r.grow(-4.0 - bump * 0.3)
			draw_rect(g2, Color(color, 0.08))
			_dashed_rect(g2, Color(color, 0.55))
			_draw_symbol(r.get_center(), is_a, Color(color, 0.35))

func _draw_symbol(at: Vector2, diamond: bool, color: Color) -> void:
	if diamond:
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -7), at + Vector2(7, 0), at + Vector2(0, 7), at + Vector2(-7, 0)]), color)
	else:
		draw_circle(at, 6.5, color)

func _dashed_rect(r: Rect2, color: Color) -> void:
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 2.0, 5.0)

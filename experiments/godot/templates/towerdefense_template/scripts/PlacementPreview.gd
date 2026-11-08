# =============================================================================
# PlacementPreview.gd (Node2D drawn above the world): placement feedback.
# =============================================================================
# Shows, depending on Main's state:
#   - placing mode : ghost tower + its range on the hovered tile, green when
#                    the tile is free and affordable, red otherwise (with a
#                    cross on blocked tiles). The player sees the exact
#                    coverage BEFORE spending gold.
#   - selection    : range of the selected tower (animated dashed ring).
#   - hover        : faint range of a hovered tower, light tile highlight.
# Redrawn every frame (the dashed rings rotate); cheap since it only draws a
# handful of shapes.
# =============================================================================

class_name PlacementPreview
extends Node2D

const COLOR_OK  := Color(0.45, 1.0, 0.55)
const COLOR_BAD := Color(1.0, 0.36, 0.36)

var grid: TDGrid = null

var _cell:       Vector2i   = Vector2i(-1, -1)
var _place_data: Dictionary = {}
var _selected:   Tower      = null
var _time:       float      = 0.0

func set_hover(cell: Vector2i) -> void:
	_cell = cell

func set_placing(data: Dictionary) -> void:
	_place_data = data

func set_selected(tower: Tower) -> void:
	_selected = tower

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if grid == null:
		return
	var t: float = float(grid.tile_size)

	if is_instance_valid(_selected):
		_draw_range(to_local(_selected.global_position), _selected.range_px, _selected.color, 1.0)

	if _cell.x < 0:
		return
	var center: Vector2 = grid.grid_to_world(_cell.x, _cell.y)
	var rect := Rect2(Vector2(_cell) * t, Vector2(t, t))

	if not _place_data.is_empty():
		_draw_placing(center, rect, t)
		return

	var hovered: Tower = grid.get_tower_at(_cell.x, _cell.y)
	if hovered != null:
		draw_rect(rect.grow(-3), Color(1, 1, 1, 0.10))
		if hovered != _selected:
			_draw_range(center, hovered.range_px, hovered.color, 0.45)
	elif grid.tile_at(_cell.x, _cell.y) == "B":
		draw_rect(rect.grow(-3), Color(1, 1, 1, 0.10))
		draw_rect(rect.grow(-3), Color(1, 1, 1, 0.25), false, 1.5)

func _draw_placing(center: Vector2, rect: Rect2, t: float) -> void:
	var valid: bool = grid.is_buildable(_cell.x, _cell.y)
	var affordable: bool = GameState.can_afford(int(_place_data.get("cost", 0)))
	var col: Color = COLOR_OK if valid and affordable else COLOR_BAD
	draw_rect(rect.grow(-2), Color(col, 0.16))
	draw_rect(rect.grow(-2), Color(col, 0.75), false, 2.0)
	if not valid:
		var k: float = t * 0.22
		draw_line(center + Vector2(-k, -k), center + Vector2(k, k), Color(col, 0.9), 4.0, true)
		draw_line(center + Vector2(k, -k), center + Vector2(-k, k), Color(col, 0.9), 4.0, true)
		return
	var stats: Dictionary = Tower.stats_for(_place_data, 1)
	var tower_color := Color("#" + str(_place_data.get("color", "ffffff")))
	_draw_range(center, float(stats["range"]) * t, col, 0.9)
	var angle: float = -PI * 0.5 + sin(_time * 1.5) * 0.4
	Tower.draw_model(self, str(_place_data.get("attack", "bullet")), tower_color, t,
		angle, 0.0, 0.0, 1, 0.7 if affordable else 0.4, center, 1.0)

## Filled disc + rotating dashed outline. strength scales the opacity.
func _draw_range(center: Vector2, radius: float, color: Color, strength: float) -> void:
	draw_circle(center, radius, Color(color, 0.09 * strength))
	draw_arc(center, radius, 0.0, TAU, 64, Color(color, 0.25 * strength), 1.5, true)
	var dashes: int = maxi(int(radius / 9.0), 12)
	var step: float = TAU / dashes
	var offset: float = _time * 0.35
	for i in dashes:
		if i % 2 == 0:
			var a: float = offset + i * step
			draw_arc(center, radius, a, a + step, 4, Color(color, 0.85 * strength), 2.5, true)

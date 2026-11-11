extends Control

# HUD: score and multiplier (top left), sector and enemies left (top
# centre), hull (top right), orbit count and flux (bottom centre), boss
# health (top). The flux and the orbit are also drawn around the ship
# itself (gravity_field.gd), where the eyes are during a fight.

var gm: Node = null
var _font: Font = null
var _score_shown: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

## Connected to game_manager.game_state_changed: shown while a run is on.
func on_state_changed(state: int) -> void:
	visible = state == 1 or state == 2 or state == 3

func _process(delta: float) -> void:
	var target: float = float(gm.get("score"))
	_score_shown = lerpf(_score_shown, target, minf(delta * 10.0, 1.0))
	if absf(_score_shown - target) < 1.0:
		_score_shown = target
	queue_redraw()

func _t(at: Vector2, label: String, size: int, color: Color, align: int = 0) -> void:
	var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p: Vector2 = at - Vector2(w * 0.5 * align, 0.0)
	draw_string_outline(_font, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.0, 0.0, 0.05, 0.85))
	draw_string(_font, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	var w: float = size.x
	var cyan := Color(0.45, 0.95, 1.0)
	_t(Vector2(24.0, 36.0), gm.call("text", "gameplay", "score") as String, 14, Color(0.6, 0.7, 0.9))
	_t(Vector2(24.0, 70.0), str(int(_score_shown)), 32, Color.WHITE)
	var mult: int = int(gm.call("multiplier"))
	_t(Vector2(24.0, 104.0), gm.call("text", "gameplay", "multiplier", {n = mult}) as String, 22, cyan.lerp(Color(1.0, 0.5, 0.9), clampf((mult - 1) / 7.0, 0.0, 1.0)))
	draw_rect(Rect2(80.0, 90.0, 120.0, 6.0), Color(0.1, 0.12, 0.25))
	draw_rect(Rect2(80.0, 90.0, 120.0 * float(gm.call("chain_ratio")), 6.0), cyan)
	var wave: int = int(gm.get("wave_number"))
	_t(Vector2(w * 0.5, 36.0), gm.call("text", "gameplay", "sector", {n = wave, total = gm.call("total_waves")}) as String, 20, cyan, 1)
	var b: Node2D = gm.get("boss") as Node2D
	if b != null and is_instance_valid(b) and bool(b.get("alive")):
		var name_key: String = "boss_" + str(b.get("kind"))
		_t(Vector2(w * 0.5, 64.0), gm.call("text", "gameplay", name_key) as String, 16, Color(1.0, 0.6, 0.9), 1)
		var ratio: float = float(b.get("hp")) / float(b.get("max_hp"))
		draw_rect(Rect2(w * 0.5 - 260.0, 74.0, 520.0, 10.0), Color(0.15, 0.05, 0.15, 0.9))
		draw_rect(Rect2(w * 0.5 - 260.0, 74.0, 520.0 * ratio, 10.0), Color(1.0, 0.4, 0.85))
	else:
		_t(Vector2(w * 0.5, 60.0), gm.call("text", "gameplay", "enemies_left", {n = gm.call("enemies_left")}) as String, 14, Color(0.6, 0.7, 0.9), 1)
	_t(Vector2(w - 24.0 - 140.0, 36.0), gm.call("text", "gameplay", "hull") as String, 14, Color(0.6, 0.7, 0.9))
	var hp: int = int(gm.call("ship_hp"))
	for i in int(gm.call("ship_hp_max")):
		var at := Vector2(w - 150.0 + i * 24.0, 56.0)
		var full: bool = i < hp
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -9), at + Vector2(8, 0), at + Vector2(0, 9), at + Vector2(-8, 0)]), cyan if full else Color(0.15, 0.2, 0.35))
	var well: Node = gm.call("well_node") as Node
	var flux: float = float(well.get("flux")) / float(well.get("flux_max"))
	var bar := Rect2(w * 0.5 - 180.0, size.y - 40.0, 360.0, 10.0)
	draw_rect(bar.grow(2.0), Color(0.05, 0.08, 0.18, 0.9))
	var fc: Color = cyan.lerp(Color(1.0, 0.35, 0.35), clampf(1.0 - flux * 2.0, 0.0, 1.0))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * flux, bar.size.y)), fc)
	_t(Vector2(bar.position.x, bar.position.y - 8.0), gm.call("text", "gameplay", "flux") as String, 13, Color(0.6, 0.7, 0.9))
	_t(Vector2(bar.end.x, bar.position.y - 8.0), gm.call("text", "gameplay", "orbit", {n = well.call("orbit_count"), max = well.get("capacity")}) as String, 13, Color(0.85, 0.95, 1.0), 2)

# =============================================================================
# Flyer.gd — Wasp: hovers along a sine path, ignores the terrain
# =============================================================================
# Horizontal ('f') or vertical ('F') sweep of flyer_range tiles around its
# spawn point, plus a small bob. Stompable: a chain of wasps over a pit can
# be crossed by bouncing from one to the next (each stomp also refills the
# air jump).
# =============================================================================

class_name Flyer
extends Enemy

var vertical: bool = false
var origin := Vector2.ZERO
var phase: float = 0.0
var _range: float = 0.0
var _speed: float = 0.0
var _facing: int = 1

func _ready() -> void:
	_range = ConfigManager.get_float("flyer_range", 2.0) * LevelData.TILE
	_speed = ConfigManager.get_float("flyer_speed", 1.4)

func _step_alive(_delta: float) -> void:
	var t: float = _anim * _speed + phase
	var previous_x: float = position.x
	if vertical:
		position = origin + Vector2(sin(t * 2.0) * 4.0, sin(t) * _range)
	else:
		position = origin + Vector2(sin(t) * _range, sin(t * 2.3) * 7.0)
	if absf(position.x - previous_x) > 0.05:
		_facing = 1 if position.x > previous_x else -1

func hit_box() -> Rect2:
	return Rect2(position.x - 14.0, position.y - 12.0, 28.0, 24.0)

func color() -> Color:
	return Color("f2c14e")

func _draw() -> void:
	var s: Vector2 = death_scale()
	var a: float = death_alpha()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s.x * _facing, s.y))
	var flap: float = absf(sin(_anim * 38.0))
	var wing := Color(0.85, 0.95, 1.0, 0.55 * a)
	PlayerArt.ellipse(self, Vector2(-4.0, -10.0 - flap * 4.0), 7.0, 4.0 + flap * 3.0, wing)
	PlayerArt.ellipse(self, Vector2(3.0, -11.0 - flap * 3.0), 6.0, 3.5 + flap * 2.5, wing)
	var outline := Color(0.15, 0.1, 0.02, a)
	PlayerArt.ellipse(self, Vector2(-6.0, 1.0), 9.0, 7.0, outline)
	PlayerArt.ellipse(self, Vector2(-6.0, 1.0), 7.5, 5.8, Color(0.95, 0.75, 0.2, a))
	draw_rect(Rect2(-9.0, -4.5, 3.0, 11.0), Color(0.2, 0.13, 0.03, a))
	draw_rect(Rect2(-4.0, -4.5, 3.0, 11.0), Color(0.2, 0.13, 0.03, a))
	draw_colored_polygon(PackedVector2Array([Vector2(-14.0, 0.0), Vector2(-20.0, 3.0), Vector2(-14.0, 4.0)]), outline)
	PlayerArt.ellipse(self, Vector2(7.0, 0.0), 6.5, 6.0, outline)
	PlayerArt.ellipse(self, Vector2(7.0, 0.0), 5.2, 4.8, Color(0.95, 0.75, 0.2, a))
	draw_circle(Vector2(9.5, -1.5), 2.2, Color(0.1, 0.05, 0.0, a))
	draw_circle(Vector2(10.0, -2.2), 0.8, Color(1.0, 1.0, 1.0, a))
	draw_line(Vector2(9.0, -5.0), Vector2(13.0, -11.0), outline, 1.3)

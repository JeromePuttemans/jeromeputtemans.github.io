# =============================================================================
# Icon.gd — Small drawn icons: firefly, acorn, fall, clock, lock
# =============================================================================
# Drawn with primitives instead of typed symbols: the web build has no font
# fallback, a typed star or skull would show as a box.
# =============================================================================

class_name Icon
extends Control

var kind: String = "firefly"
var filled: bool = true
var pulse: float = 0.0

static func make(icon_kind: String, size: float = 24.0, is_filled: bool = true) -> Icon:
	var icon := Icon.new()
	icon.kind = icon_kind
	icon.filled = is_filled
	icon.custom_minimum_size = Vector2(size, size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func bump() -> void:
	pulse = 1.0

func _process(delta: float) -> void:
	if pulse > 0.0:
		pulse = maxf(pulse - delta * 3.0, 0.0)
		queue_redraw()

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var k: float = minf(size.x, size.y) / 24.0 * (1.0 + 0.35 * sin(pulse * PI))
	draw_set_transform(c, 0.0, Vector2(k, k))
	match kind:
		"firefly":
			Pickups.glow(self, Vector2.ZERO, 14.0, Color("f4f08a"), 1.6 if filled else 0.4)
			PlayerArt.ellipse(self, Vector2(-4.0, -4.0), 4.0, 2.5, Color(1.0, 1.0, 1.0, 0.7))
			PlayerArt.ellipse(self, Vector2(4.0, -4.0), 4.0, 2.5, Color(1.0, 1.0, 1.0, 0.7))
			PlayerArt.ellipse(self, Vector2(0.0, 1.0), 4.0, 5.0, Color(0.95, 1.0, 0.55) if filled else Color(0.5, 0.5, 0.45))
		"acorn":
			var gold: Color = Color("ffcc33") if filled else Color(0.3, 0.3, 0.28)
			var cap: Color = Color("a8741a") if filled else Color(0.24, 0.24, 0.22)
			PlayerArt.ellipse(self, Vector2(0.0, 2.5), 7.5, 8.5, Color(0.2, 0.13, 0.02) if filled else Color(0.45, 0.45, 0.4))
			PlayerArt.ellipse(self, Vector2(0.0, 2.5), 6.2, 7.3, gold)
			PlayerArt.ellipse(self, Vector2(0.0, -5.0), 8.5, 4.0, cap)
			draw_line(Vector2(0.0, -8.0), Vector2(1.5, -11.0), cap, 2.0)
		"fall":
			PlayerArt.ellipse(self, Vector2(0.0, 0.0), 9.0, 9.5, Color(0.92, 0.9, 0.82))
			draw_line(Vector2(-6.0, -4.0), Vector2(-2.0, 0.0), Color(0.15, 0.15, 0.15), 2.0)
			draw_line(Vector2(-2.0, -4.0), Vector2(-6.0, 0.0), Color(0.15, 0.15, 0.15), 2.0)
			draw_line(Vector2(2.0, -4.0), Vector2(6.0, 0.0), Color(0.15, 0.15, 0.15), 2.0)
			draw_line(Vector2(6.0, -4.0), Vector2(2.0, 0.0), Color(0.15, 0.15, 0.15), 2.0)
			draw_line(Vector2(-3.0, 5.0), Vector2(3.0, 5.0), Color(0.15, 0.15, 0.15), 2.0)
		"clock":
			draw_circle(Vector2.ZERO, 9.5, Color(0.92, 0.9, 0.82))
			draw_arc(Vector2.ZERO, 9.5, 0.0, TAU, 24, Color(0.2, 0.2, 0.18), 1.5)
			draw_line(Vector2.ZERO, Vector2(0.0, -6.5), Color(0.15, 0.15, 0.15), 2.0)
			draw_line(Vector2.ZERO, Vector2(4.5, 1.5), Color(0.15, 0.15, 0.15), 2.0)
		"lock":
			draw_arc(Vector2(0.0, -3.0), 5.0, PI, TAU, 12, Color(0.75, 0.75, 0.7), 2.5)
			draw_rect(Rect2(-7.0, -3.0, 14.0, 11.0), Color(0.75, 0.75, 0.7))
			draw_circle(Vector2(0.0, 2.0), 1.8, Color(0.2, 0.2, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# =============================================================================
# Pickups.gd — Glow helper shared by the fireflies and the golden acorns
# =============================================================================
# A soft halo is a stack of concentric circles of decreasing alpha: cheap,
# no texture and no shader, and it reads as light on any background.
# =============================================================================

class_name Pickups
extends RefCounted

static func glow(canvas: CanvasItem, at: Vector2, radius: float, color: Color, strength: float = 1.0) -> void:
	var steps: int = clampi(int(radius / 10.0), 5, 16)
	for i in steps:
		var t: float = float(i + 1) / float(steps)
		canvas.draw_circle(at, radius * (1.15 - t * 0.85), Color(color, 0.45 * strength * t / float(steps)))

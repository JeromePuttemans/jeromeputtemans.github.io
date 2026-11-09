extends EnemyBase

# Drifter (red diamond): crosses the screen in a straight line. The most
# common and easiest target; it teaches aiming in the first sector.

func _shape() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-radius, 0.0), Vector2(0.0, -radius * 0.85),
		Vector2(radius * 0.8, 0.0), Vector2(0.0, radius * 0.85)])

func _draw_details(color: Color) -> void:
	draw_circle(Vector2(-radius * 0.15, 0.0), radius * 0.22, Color(color.lightened(0.5), 0.9))

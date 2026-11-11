# =============================================================================
# Fade.gd — Full-screen colour fades (falls, light columns, start)
# =============================================================================
# fade_to(color, time) and fade_from(time) are awaitable: Main waits for the
# screen to be covered before moving the player, so no jump is ever seen.
# =============================================================================

class_name Fade
extends ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1.0, 1.0, 1.0, 0.0)
	process_mode = Node.PROCESS_MODE_ALWAYS

func fade_to(target: Color, time: float) -> void:
	var start := Color(target.r, target.g, target.b, color.a)
	var t: float = 0.0
	while t < time:
		t += get_process_delta_time()
		color = start.lerp(target, clampf(t / time, 0.0, 1.0))
		await get_tree().process_frame
	color = target

func fade_from(time: float) -> void:
	var start: Color = color
	var t: float = 0.0
	while t < time:
		t += get_process_delta_time()
		color = Color(start.r, start.g, start.b, start.a * (1.0 - clampf(t / time, 0.0, 1.0)))
		await get_tree().process_frame
	color.a = 0.0

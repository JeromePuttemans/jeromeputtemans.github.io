# =============================================================================
# Toasts.gd — Short notices at the bottom of the screen
# =============================================================================
# push(text, color) shows a notice that slides in, stays TOAST_TIME seconds
# and fades out. At most MAX_TOASTS at once: the oldest leaves first.
# =============================================================================

extends VBoxContainer

const TOAST_TIME: float = 2.6
const MAX_TOASTS: int = 3

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 6)

func push(text: String, color: Color) -> void:
	while get_child_count() >= MAX_TOASTS:
		var oldest: Node = get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.06, 0.07, 0.13, 0.94), color.darkened(0.2), 8, 14))
	var label: Label = UiTheme.label(text, 15, color)
	panel.add_child(label)
	add_child(panel)
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_interval(TOAST_TIME)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)

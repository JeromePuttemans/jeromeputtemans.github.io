# =============================================================================
# ProducerIcon.gd — Gem icon of a producer (or a locked silhouette)
# =============================================================================
# Draws the producer's gem (UiTheme.draw_gem) slowly turning; pop() makes it
# swell and settle back after a purchase or a milestone.
# =============================================================================

extends Control

var producer: Producer = null
var locked: bool = false
var _pop: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(52.0, 52.0)

func pop() -> void:
	_pop = 1.0

func _process(delta: float) -> void:
	_time += delta
	_pop = maxf(_pop - delta * 3.0, 0.0)
	queue_redraw()

func _draw() -> void:
	if producer == null:
		return
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.38 * (1.0 + 0.35 * _pop)
	if locked:
		UiTheme.draw_gem(self, center, radius, producer.sides, Color(0.25, 0.27, 0.38), 0.0)
		return
	draw_circle(center, radius * 1.35, Color(producer.color, 0.1 + 0.25 * _pop))
	UiTheme.draw_gem(self, center, radius, producer.sides, producer.color, sin(_time * 0.8) * 0.3)

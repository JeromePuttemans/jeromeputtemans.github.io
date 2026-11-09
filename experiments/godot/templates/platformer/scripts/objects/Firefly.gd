# =============================================================================
# Firefly.gd — Small collectible ('o')
# =============================================================================
# The logical position stays on its tile centre (Level tests the distance
# to the player); only the drawing hovers around it. Once collected it
# flies up and fades out. Collected fireflies stay collected after a fall.
# =============================================================================

class_name Firefly
extends Node2D

var index: int = 0
var collected: bool = false
var _time: float = 0.0
var _gone: float = 1.0

func _ready() -> void:
	_time = randf() * TAU
	if not collected:
		_gone = 0.0

func collect() -> void:
	collected = true
	_gone = 0.0

func _process(delta: float) -> void:
	_time += delta
	if collected and _gone < 1.0:
		_gone = minf(_gone + delta * 2.4, 1.0)
	queue_redraw()

func _draw() -> void:
	if collected and _gone >= 1.0:
		return
	var hover := Vector2(cos(_time * 1.3) * 4.0, sin(_time * 2.1) * 5.0)
	var alpha: float = 1.0
	if collected:
		hover.y -= _gone * 46.0
		alpha = 1.0 - _gone
	var pulse: float = 0.75 + 0.25 * sin(_time * 5.0)
	Pickups.glow(self, hover, 22.0, Color("f4f08a"), pulse * alpha * 1.6)
	var flap: float = absf(sin(_time * 30.0))
	PlayerArt.ellipse(self, hover + Vector2(-5.0, -5.0), 5.0, 2.5 + flap * 2.0, Color(1.0, 1.0, 1.0, 0.65 * alpha))
	PlayerArt.ellipse(self, hover + Vector2(5.0, -5.0), 5.0, 2.5 + flap * 2.0, Color(1.0, 1.0, 1.0, 0.65 * alpha))
	PlayerArt.ellipse(self, hover + Vector2(0.0, 1.5), 4.2, 5.4, Color(0.95, 1.0, 0.55, alpha))
	draw_circle(hover + Vector2(0.0, -3.0), 2.8, Color(0.35, 0.3, 0.2, alpha))

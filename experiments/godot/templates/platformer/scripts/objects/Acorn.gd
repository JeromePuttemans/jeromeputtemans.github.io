# =============================================================================
# Acorn.gd — Golden acorn ('G'), three per level, usually off the main path
# =============================================================================
# An acorn already found in a previous run is drawn translucent: it can be
# taken again, the save keeps the union of all the acorns ever found.
# =============================================================================

class_name Acorn
extends Node2D

const GOLD: Color = Color("ffcc33")
const CAP: Color = Color("a8741a")

var index: int = 0
var collected: bool = false
var found_before: bool = false
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
		_gone = minf(_gone + delta * 1.8, 1.0)
	queue_redraw()

func _draw() -> void:
	if collected and _gone >= 1.0:
		return
	var alpha: float = 0.45 if found_before else 1.0
	var size: float = 1.0
	var at := Vector2(0.0, sin(_time * 2.0) * 4.0)
	if collected:
		size = 1.0 + _gone * 0.8
		alpha *= 1.0 - _gone
		at.y -= _gone * 20.0
	Pickups.glow(self, at, 34.0 * size, Color("ffe066"), alpha * (1.2 + 0.4 * sin(_time * 3.0)))
	var tilt: float = sin(_time * 1.6) * 0.18
	draw_set_transform(at, tilt, Vector2(size, size))
	PlayerArt.ellipse(self, Vector2(0.0, 3.0), 10.5, 12.5, Color(0.4, 0.25, 0.02, alpha))
	PlayerArt.ellipse(self, Vector2(0.0, 3.0), 9.0, 11.0, Color(GOLD, alpha))
	PlayerArt.ellipse(self, Vector2(-3.5, 1.0), 2.5, 5.0, Color(1.0, 0.97, 0.8, alpha * 0.7))
	PlayerArt.ellipse(self, Vector2(0.0, -7.0), 12.0, 5.5, Color(0.35, 0.22, 0.02, alpha))
	PlayerArt.ellipse(self, Vector2(0.0, -7.5), 10.5, 4.5, Color(CAP, alpha))
	for i in 4:
		draw_line(Vector2(-8.0 + i * 5.0, -10.0), Vector2(-6.0 + i * 5.0, -5.0), Color(0.45, 0.28, 0.05, alpha), 1.0)
	draw_line(Vector2(0.0, -11.0), Vector2(2.0, -16.0), Color(0.35, 0.22, 0.02, alpha), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sparkle: float = fmod(_time * 0.8, 1.0)
	if sparkle < 0.25 and not collected:
		var k: float = sin(sparkle / 0.25 * PI)
		var p: Vector2 = at + Vector2(6.0, -2.0)
		draw_line(p - Vector2(5.0 * k, 0.0), p + Vector2(5.0 * k, 0.0), Color(1.0, 1.0, 1.0, alpha * k), 1.5)
		draw_line(p - Vector2(0.0, 5.0 * k), p + Vector2(0.0, 5.0 * k), Color(1.0, 1.0, 1.0, alpha * k), 1.5)

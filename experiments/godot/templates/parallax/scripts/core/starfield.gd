extends Node2D

# Starfield: the parallax background, drawn in _draw().
#
# Three star layers move left at a fraction of the current speed (far 12 %,
# middle 40 %, near 100 %): the nearer the layer, the faster and the bigger
# its stars, which gives depth and shows the current the ship fights.
# Near stars are drawn as streaks whose length follows the current.
# VERTICAL PARALLAX: each layer is also shifted against the ship's height
# (focus), more for near layers: moving up or down makes the depth visible.
# A few large, faint nebulae drift even slower than the far layer.

const LAYER_SPEED: Array[float] = [0.12, 0.4, 1.0]
const LAYER_COUNT: Array[int] = [90, 55, 26]
const LAYER_SIZE: Array[float] = [1.0, 1.7, 2.4]
const LAYER_ALPHA: Array[float] = [0.35, 0.6, 0.95]
const LAYER_PARALLAX_Y: Array[float] = [0.04, 0.1, 0.2]
const NEBULA_COUNT: int = 5
const NEBULA_SPEED: float = 0.05
const NEBULA_COLORS: Array[Color] = [Color(0.25, 0.15, 0.55), Color(0.1, 0.25, 0.5), Color(0.45, 0.1, 0.35)]
const BACKGROUND: Color = Color(0.024, 0.024, 0.059)

var _stars: Array[PackedVector2Array] = []
var _twinkle: Array[PackedFloat32Array] = []
var _nebulae: Array[Dictionary] = []
var _current_speed: float = 90.0
var _focus_offset: float = 0.0
var _focus_target: float = 0.0
var _time: float = 0.0
var _screen: Vector2 = Vector2(1280.0, 720.0)

func _ready() -> void:
	_screen = get_viewport_rect().size
	for layer in LAYER_SPEED.size():
		var points := PackedVector2Array()
		var phases := PackedFloat32Array()
		for i in LAYER_COUNT[layer]:
			points.append(Vector2(randf() * _screen.x, randf() * _screen.y))
			phases.append(randf() * TAU)
		_stars.append(points)
		_twinkle.append(phases)
	for i in NEBULA_COUNT:
		_nebulae.append(_new_nebula(randf() * _screen.x))

func set_current_speed(speed: float) -> void:
	_current_speed = speed

## Ship height relative to the screen centre (pixels); drives the vertical parallax.
func set_focus(ship_y: float) -> void:
	_focus_target = ship_y - _screen.y * 0.5

func _process(delta: float) -> void:
	_screen = get_viewport_rect().size
	_time += delta
	_focus_offset = lerpf(_focus_offset, _focus_target, 1.0 - exp(-4.0 * delta))
	for layer in _stars.size():
		var points: PackedVector2Array = _stars[layer]
		var step: float = _current_speed * LAYER_SPEED[layer] * delta
		for i in points.size():
			var p: Vector2 = points[i]
			p.x -= step
			if p.x < -4.0:
				p = Vector2(_screen.x + randf() * 40.0, randf() * _screen.y)
			points[i] = p
		_stars[layer] = points
	_move_nebulae(delta)
	queue_redraw()

func _move_nebulae(delta: float) -> void:
	for i in _nebulae.size():
		var nebula: Dictionary = _nebulae[i]
		var pos: Vector2 = nebula["pos"] as Vector2
		pos.x -= _current_speed * NEBULA_SPEED * delta
		nebula["pos"] = pos
		if pos.x < -float(nebula["radius"]):
			_nebulae[i] = _new_nebula(_screen.x + float(nebula["radius"]))

func _new_nebula(x: float) -> Dictionary:
	var radius: float = randf_range(140.0, 300.0)
	var color: Color = NEBULA_COLORS[randi() % NEBULA_COLORS.size()]
	return {pos = Vector2(x, randf() * _screen.y), radius = radius, color = color}

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _screen), BACKGROUND)
	_draw_nebulae()
	for layer in _stars.size():
		_draw_layer(layer)

func _draw_nebulae() -> void:
	for nebula in _nebulae:
		var pos: Vector2 = nebula["pos"] as Vector2
		pos.y = fposmod(pos.y - _focus_offset * 0.02, _screen.y + 300.0) - 150.0
		var radius: float = float(nebula["radius"])
		var color: Color = nebula["color"] as Color
		for ring in 5:
			var t: float = float(ring) / 5.0
			draw_circle(pos, radius * (1.0 - t * 0.8), Color(color, 0.018 + t * 0.012))

func _draw_layer(layer: int) -> void:
	var points: PackedVector2Array = _stars[layer]
	var phases: PackedFloat32Array = _twinkle[layer]
	var shift: float = _focus_offset * LAYER_PARALLAX_Y[layer]
	var size: float = LAYER_SIZE[layer]
	var streak: float = _current_speed * LAYER_SPEED[layer] * 0.07
	for i in points.size():
		var p: Vector2 = points[i]
		p.y = fposmod(p.y - shift, _screen.y)
		var alpha: float = LAYER_ALPHA[layer] * (0.75 + 0.25 * sin(_time * 2.0 + phases[i]))
		var color := Color(0.85, 0.88, 1.0, alpha)
		if layer == LAYER_SPEED.size() - 1:
			draw_line(p, p + Vector2(streak, 0.0), Color(color, alpha * 0.5), size * 0.8)
		draw_rect(Rect2(p - Vector2(size, size) * 0.5, Vector2(size, size)), color)

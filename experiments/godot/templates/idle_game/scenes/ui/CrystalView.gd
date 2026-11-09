# =============================================================================
# CrystalView.gd — The crystal heart, its orbits and the overheat gauge
# =============================================================================
# CLICK: a left click on the crystal (or Space, through strike()) calls
#   GameManager.click(). Feedback: the crystal squashes and springs back
#   (damped spring on its scale), a ripple ring expands, shards fly out with
#   gravity, and struck(position, amount, critical) lets the FX layer show the
#   floating number.
# ORBITS: one ring per producer type owned, with up to MAX_ORBITERS small gems
#   of its shape and colour: the empire grows visibly around the heart. The
#   newest orbiter of a type pops in after each purchase (spawn_orbiter).
# GAUGE: an arc around the crystal shows the overheat gauge, cyan to orange;
#   while overheating the whole ring burns and the crystal turns orange. An
#   eruption (meteor) tints it gold.
# =============================================================================

extends Control

signal struck(at: Vector2, amount: float, critical: bool)

const RADIUS: float = 84.0
const RING_START: float = 124.0
const RING_STEP: float = 11.0
const MAX_ORBITERS: int = 12
const SPRING: float = 320.0
const DAMPING: float = 14.0
const GRAVITY: float = 420.0

var _scale: float = 1.0
var _scale_velocity: float = 0.0
var _time: float = 0.0
var _hover: bool = false
var _ripples: Array[Dictionary] = []
var _shards: Array[Dictionary] = []
var _pops: Dictionary = {}   # producer id -> pop timer (0..1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)

func center() -> Vector2:
	return size * 0.5

func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.position.distance_to(center()) <= RADIUS * 1.15:
		strike(button.position)
		accept_event()

## A strike at a local position: game logic, then all the feedback.
func strike(at: Vector2) -> void:
	var amount: float = GameManager.click()
	var critical: bool = GameManager.last_critical
	_scale_velocity -= 7.0 if critical else 3.5
	_ripples.append({radius = RADIUS, life = 0.5, color = UiTheme.GOLD if critical else _crystal_color()})
	for i in (16 if critical else 7):
		var direction: Vector2 = (at - center()).normalized().rotated(randf_range(-1.2, 1.2))
		if direction == Vector2.ZERO:
			direction = Vector2.UP.rotated(randf_range(-1.0, 1.0))
		_shards.append({pos = at, vel = direction * randf_range(120.0, 320.0) + Vector2(0.0, -80.0),
			life = randf_range(0.5, 0.9), spin = randf_range(-12.0, 12.0), angle = randf() * TAU,
			color = UiTheme.GOLD if critical else _crystal_color().lightened(randf() * 0.4)})
	Sfx.play_click(BoostManager.heat, critical)
	struck.emit(get_global_rect().position + at, amount, critical)

func spawn_orbiter(producer: Producer) -> void:
	_pops[producer.id] = 1.0

func _process(delta: float) -> void:
	_time += delta
	var acceleration: float = -SPRING * (_scale - 1.0) - DAMPING * _scale_velocity
	_scale_velocity += acceleration * delta
	_scale += _scale_velocity * delta
	for i in range(_ripples.size() - 1, -1, -1):
		var r: Dictionary = _ripples[i]
		r["life"] = float(r["life"]) - delta
		r["radius"] = float(r["radius"]) + 260.0 * delta
		if float(r["life"]) <= 0.0:
			_ripples.remove_at(i)
	_update_shards(delta)
	for id in _pops.keys():
		_pops[id] = maxf(float(_pops[id]) - delta * 2.0, 0.0)
	queue_redraw()

func _update_shards(delta: float) -> void:
	for i in range(_shards.size() - 1, -1, -1):
		var s: Dictionary = _shards[i]
		var velocity: Vector2 = s["vel"] as Vector2
		velocity.y += GRAVITY * delta
		s["vel"] = velocity
		s["pos"] = (s["pos"] as Vector2) + velocity * delta
		s["angle"] = float(s["angle"]) + float(s["spin"]) * delta
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) <= 0.0:
			_shards.remove_at(i)

func _crystal_color() -> Color:
	if BoostManager.is_frenzy():
		return UiTheme.HEAT
	if BoostManager.eruption_left > 0.0:
		return UiTheme.GOLD
	return UiTheme.CRYSTAL

# =============================================================================
# DRAWING
# =============================================================================

func _draw() -> void:
	_draw_orbits()
	_draw_gauge()
	_draw_crystal()
	for r in _ripples:
		var t: float = float(r["life"]) / 0.5
		draw_arc(center(), float(r["radius"]), 0.0, TAU, 64, Color(r["color"] as Color, t * 0.6), 3.0 * t + 1.0, true)
	for s in _shards:
		var pos: Vector2 = s["pos"] as Vector2
		var angle: float = float(s["angle"])
		var tri := PackedVector2Array([pos + Vector2(6.0, 0.0).rotated(angle), pos + Vector2(-3.0, 3.0).rotated(angle), pos + Vector2(-3.0, -3.0).rotated(angle)])
		draw_colored_polygon(tri, Color(s["color"] as Color, clampf(float(s["life"]) * 2.0, 0.0, 1.0)))

func _draw_orbits() -> void:
	var ring: int = 0
	for id in ProducerManager.producer_order:
		var producer: Producer = ProducerManager.producers[id] as Producer
		if producer.owned <= 0:
			continue
		var radius: float = RING_START + ring * RING_STEP
		draw_arc(center(), radius, 0.0, TAU, 96, Color(producer.color, 0.1), 1.0, true)
		var count: int = mini(producer.owned, MAX_ORBITERS)
		var direction: float = 1.0 if ring % 2 == 0 else -1.0
		var speed: float = direction * (0.5 / (1.0 + ring * 0.35))
		for i in count:
			var angle: float = _time * speed + TAU * i / count + ring * 0.7
			var size_factor: float = 1.0
			if i == count - 1:
				size_factor += float(_pops.get(id, 0.0)) * 1.5
			UiTheme.draw_gem(self, center() + Vector2.RIGHT.rotated(angle) * radius, 4.5 * size_factor, producer.sides, producer.color, angle * 2.0)
		ring += 1

func _draw_gauge() -> void:
	var radius: float = RADIUS + 20.0
	draw_arc(center(), radius, 0.0, TAU, 96, Color(1.0, 1.0, 1.0, 0.06), 6.0, true)
	var heat: float = BoostManager.heat
	if heat <= 0.0:
		return
	var color: Color = UiTheme.CRYSTAL.lerp(UiTheme.HEAT, heat)
	var width: float = 6.0
	if BoostManager.is_frenzy():
		width += 3.0 * (0.5 + 0.5 * sin(_time * 14.0))
	draw_arc(center(), radius, -PI * 0.5, -PI * 0.5 + TAU * heat, 96, color, width, true)

func _crystal_points(scale_factor: float) -> PackedVector2Array:
	var shape: Array[float] = [1.25, 0.9, 0.82, 0.9, 1.3, 0.9, 0.82, 0.9]
	var points := PackedVector2Array()
	var squash := Vector2(1.0 + (1.0 - _scale) * 0.6, _scale)
	for i in shape.size():
		var direction: Vector2 = Vector2.UP.rotated(TAU * i / shape.size())
		points.append(center() + direction * RADIUS * shape[i] * scale_factor * squash)
	return points

func _draw_crystal() -> void:
	var color: Color = _crystal_color()
	var glow: float = 0.08 + (0.05 if _hover else 0.0) + 0.03 * sin(_time * 2.0)
	for i in 6:
		draw_circle(center(), RADIUS * (1.9 - i * 0.14), Color(color, glow * (0.3 + i * 0.12)))
	var points: PackedVector2Array = _crystal_points(1.0)
	var core: Vector2 = center() + Vector2(0.0, -RADIUS * 0.1)
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var shade: float = 0.5 + 0.5 * sin(_time * 1.3 + i * 0.9)
		draw_colored_polygon(PackedVector2Array([core, a, b]), color.darkened(0.55 - shade * 0.4))
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, color.lightened(0.5), 2.5, true)
	var inner: PackedVector2Array = _crystal_points(0.45)
	inner.append(inner[0])
	draw_polyline(inner, Color(1.0, 1.0, 1.0, 0.35), 1.5, true)
	draw_circle(core + Vector2(-RADIUS * 0.25, -RADIUS * 0.35), RADIUS * 0.1, Color(1.0, 1.0, 1.0, 0.55))

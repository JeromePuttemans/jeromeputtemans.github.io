extends Node2D

# PickupRepair: a green cross dropped by tanks (spawner.gd, World/Pickups).
# Drifts left with the current while bobbing. Touching it repairs one hull
# point, or gives repair_points_when_full points with a full hull (combat.gd
# detects the contact, game_manager.gd applies the effect).

var radius: float = 14.0
var _drift_speed: float = 60.0
var _time: float = 0.0
var _base_y: float = 0.0

func setup(drift_speed: float, pickup_radius: float) -> void:
	_drift_speed = drift_speed
	radius = pickup_radius

func _ready() -> void:
	_base_y = position.y

func _physics_process(delta: float) -> void:
	_time += delta
	position.x -= _drift_speed * delta
	position.y = _base_y + sin(_time * 3.0) * 8.0
	if position.x < -radius * 2.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
	var green := Color(0.35, 1.0, 0.55)
	draw_circle(Vector2.ZERO, radius * 1.6, Color(green, 0.08 + 0.08 * pulse))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(green, 0.85), 2.0)
	draw_rect(Rect2(-radius * 0.55, -radius * 0.18, radius * 1.1, radius * 0.36), green)
	draw_rect(Rect2(-radius * 0.18, -radius * 0.55, radius * 0.36, radius * 1.1), green)

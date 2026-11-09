class_name EnemyBase
extends Node2D

# EnemyBase: what the five enemy kinds share. Built by spawner.gd in
# World/Enemies; each kind is a subclass that overrides _move(), _shape(),
# _body_color() and optionally _draw_details().
#
# LIFE: hp from settings.json; combat.gd calls hit(), which flashes the enemy
#   white and knocks it back a few pixels (visible feedback on every hit).
# SPAWN: the shape grows from 0 to full size in SPAWN_TIME.
# SHOTS: _fire_at_target() emits shot_fired; spawner.gd creates the orb.
# Freed once well outside the screen.

signal shot_fired(origin: Vector2, velocity: Vector2)

const FLASH_TIME: float = 0.07
const KNOCKBACK: float = 7.0
const SPAWN_TIME: float = 0.25
const DARK_FILL: float = 0.28

var kind: String = ""
var hp: int = 1
var hp_max: int = 1
var radius: float = 14.0
var points: int = 100
var speed: float = 120.0
var config: Dictionary = {}
var _age: float = 0.0
var _flash: float = 0.0
var _target: Node2D = null
var _screen: Vector2 = Vector2(1280.0, 720.0)
var _shot_speed: float = 300.0
var _sfx: Node = null

func _ready() -> void:
	add_to_group("enemies")
	_sfx = get_tree().get_first_node_in_group("sfx")

## Called by spawner.gd after add_child(): stores the data, no tree access.
func setup(enemy_kind: String, enemy_config: Dictionary, target: Node2D, screen: Vector2, shot_speed: float) -> void:
	kind = enemy_kind
	config = enemy_config
	hp = int(config.get("hp", 1))
	hp_max = hp
	radius = float(config.get("radius", 14.0))
	points = int(config.get("points", 100))
	speed = float(config.get("speed", 120.0))
	_target = target
	_screen = screen
	_shot_speed = shot_speed
	_on_setup()

## Returns true when this hit destroys the enemy.
func hit(damage: int) -> bool:
	hp -= damage
	_flash = FLASH_TIME
	position.x += KNOCKBACK
	return hp <= 0

func _physics_process(delta: float) -> void:
	_age += delta
	_flash = maxf(_flash - delta, 0.0)
	_move(delta)
	if _is_off_screen():
		queue_free()
	queue_redraw()

func _is_off_screen() -> bool:
	var margin: float = radius * 3.0 + 30.0
	return (position.x < -margin or position.y < -margin * 2.0
		or position.y > _screen.y + margin * 2.0 or position.x > _screen.x + 600.0)

# ---------------------------------------------------------------------------
# Overridable behaviour
# ---------------------------------------------------------------------------

func _on_setup() -> void:
	pass

func _move(delta: float) -> void:
	position.x -= speed * delta

func _shape() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-radius, 0.0), Vector2(0.0, -radius), Vector2(radius, 0.0), Vector2(0.0, radius)])

func _body_color() -> Color:
	return Color(1.0, 0.267, 0.333)

func _draw_details(_color: Color) -> void:
	pass

# ---------------------------------------------------------------------------
# Helpers for subclasses
# ---------------------------------------------------------------------------

func _aim_direction() -> Vector2:
	if not is_instance_valid(_target) or not _target.visible:
		return Vector2.LEFT
	return (_target.global_position - global_position).normalized()

func _fire_at_target(spread_radians: float) -> void:
	shot_fired.emit(global_position, _aim_direction().rotated(spread_radians) * _shot_speed)

func _play(sound: String) -> void:
	if is_instance_valid(_sfx):
		_sfx.call("play", sound, 0.06, 0.0)

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	var grow: float = ease(clampf(_age / SPAWN_TIME, 0.0, 1.0), 0.4)
	var color: Color = _body_color()
	var points_shape := PackedVector2Array()
	for p in _shape():
		points_shape.append(p * grow)
	draw_circle(Vector2.ZERO, radius * 1.7 * grow, Color(color, 0.07))
	draw_colored_polygon(points_shape, Color(color * DARK_FILL, 1.0))
	var outline: PackedVector2Array = points_shape.duplicate()
	outline.append(points_shape[0])
	draw_polyline(outline, color, 2.5)
	_draw_details(color)
	if _flash > 0.0:
		draw_colored_polygon(points_shape, Color(1.0, 1.0, 1.0, 0.9))
	if hp_max > 2 and hp < hp_max:
		var ratio: float = float(hp) / float(hp_max)
		draw_arc(Vector2.ZERO, radius + 7.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 32, Color(color, 0.8), 2.0)

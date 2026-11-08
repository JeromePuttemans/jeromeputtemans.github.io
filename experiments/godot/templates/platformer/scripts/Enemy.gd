# =============================================================================
# Enemy.gd — CharacterBody2D: patrol AI with edge and wall detection.
# =============================================================================
# All runtime values are loaded from ConfigManager in _ready().
# Variable declarations use 0.0 so config.json is the single source of truth.
#
# PATROL ALGORITHM:
#   Walks in `direction` (±1) at `speed`. Two conditions flip direction:
#   1. Wall hit  — is_on_wall() == true after move_and_slide()
#   2. Edge ahead — RayCast2D at the front foot no longer hits ground
#   A flip_cooldown (set in config via "enemy_flip_cooldown") prevents
#   oscillation at corners. patrol_distance (from levels.json) limits range.
# =============================================================================

class_name Enemy
extends CharacterBody2D

const SIZE := Vector2(28, 36)

const LAYER_ENEMY = 4
const LAYER_WORLD = 1

var speed:           float = 0.0   # loaded from config
var patrol_distance: float = 0.0   # set by LevelBuilder from levels.json
var direction:       int   = 1

var _origin_x:      float = 0.0
var _gravity:       float = 0.0
var _flip_cooldown: float = 0.0
var _ready_frames:  int   = 0

var _edge_ray: RayCast2D = null
var _alive:    bool      = true

func _ready() -> void:
	speed    = ConfigManager.get_float("enemy_speed",    0.0)
	_gravity = ConfigManager.get_float("gravity",        0.0)

	collision_layer = LAYER_ENEMY
	collision_mask  = LAYER_WORLD

	var shape  = RectangleShape2D.new()
	shape.size = SIZE
	var coll   = CollisionShape2D.new()
	coll.shape = shape
	add_child(coll)

	_edge_ray                 = RayCast2D.new()
	_edge_ray.collision_mask  = LAYER_WORLD
	_edge_ray.enabled         = true
	_edge_ray.target_position = Vector2(0.0, SIZE.y * 0.5 + 10.0)
	add_child(_edge_ray)
	_update_ray_position()

func _physics_process(delta: float) -> void:
	if not _alive:
		return

	# Let the raycast settle for two frames before trusting its output
	_ready_frames += 1
	if _ready_frames < 3:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += _gravity * delta
	else:
		velocity.y = 0.0

	_flip_cooldown -= delta

	if _flip_cooldown <= 0.0:
		var at_wall    = is_on_wall()
		var at_edge    = not _edge_ray.is_colliding()
		var past_limit = abs(position.x - _origin_x) > patrol_distance
		if at_wall or at_edge or past_limit:
			_flip()

	velocity.x = direction * speed
	move_and_slide()
	queue_redraw()

func _flip() -> void:
	direction       = -direction
	_flip_cooldown  = 0.25
	_update_ray_position()

func _update_ray_position() -> void:
	if _edge_ray != null:
		_edge_ray.position = Vector2(direction * SIZE.x * 0.5, 0.0)

func die() -> void:
	if not _alive:
		return
	_alive = false
	queue_free()

func _draw() -> void:
	if not _alive:
		return
	draw_rect(Rect2(-SIZE * 0.5, SIZE), Color(0.85, 0.25, 0.25))
	var eye_y = -SIZE.y * 0.2
	var eye_x = direction * SIZE.x * 0.2
	draw_circle(Vector2(eye_x, eye_y), 3.0, Color(1.0, 0.9, 0.0))

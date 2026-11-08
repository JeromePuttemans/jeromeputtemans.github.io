# =============================================================================
# Collectible.gd — Area2D coin collectible.
# =============================================================================
# Detects when the Player body enters its area.
# On collection: awards score via GameState, then removes itself with free().
#
# IMPORTANT: free() not queue_free() — instant removal so the scene tree is
# clean before the next physics frame. queue_free() would leave the Area2D
# active for one extra frame and could trigger a second collection event.
# =============================================================================

class_name Collectible
extends Area2D

const RADIUS      = 10.0
const LAYER_COIN  = 8
const LAYER_PLAYER = 2

func _ready() -> void:
	collision_layer = LAYER_COIN
	collision_mask  = LAYER_PLAYER
	monitoring      = true
	monitorable     = false

	var shape    = CircleShape2D.new()
	shape.radius = RADIUS
	var coll     = CollisionShape2D.new()
	coll.shape   = shape
	add_child(coll)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	# Godot locks the object during signal emission — free() would crash here.
	# Disabling monitoring is synchronous: the signal cannot fire a second time
	# while this node is queued for deletion, so queue_free() is safe.
	monitoring = false
	GameState.add_score(ConfigManager.get_int("coin_score_value", 0))
	queue_free()

func _draw() -> void:
	# Gold coin with a shine dot
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.82, 0.1))
	draw_circle(Vector2(-RADIUS * 0.3, -RADIUS * 0.3), RADIUS * 0.25, Color(1.0, 1.0, 0.7, 0.8))

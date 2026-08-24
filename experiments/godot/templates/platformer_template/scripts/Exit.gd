# =============================================================================
# Exit.gd — Area2D level exit marker.
# =============================================================================
# When the player walks into this area GameState.complete_level() is called.
# Drawn as a green flag pole so the player can clearly see the goal.
# =============================================================================

class_name Exit
extends Area2D

const WIDTH        = 32.0
const HEIGHT       = 64.0
const LAYER_EXIT   = 16
const LAYER_PLAYER = 2

func _ready() -> void:
	collision_layer = LAYER_EXIT
	collision_mask  = LAYER_PLAYER
	monitoring      = true
	monitorable     = false

	var shape    = RectangleShape2D.new()
	shape.size   = Vector2(WIDTH, HEIGHT)
	var coll     = CollisionShape2D.new()
	coll.shape   = shape
	add_child(coll)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	# Disable monitoring synchronously to prevent re-entry during the same frame.
	monitoring = false
	GameState.complete_level()

func _draw() -> void:
	# Pole
	draw_rect(Rect2(-4.0, -HEIGHT * 0.5, 8.0, HEIGHT), Color(0.8, 0.8, 0.8))
	# Flag
	draw_rect(Rect2(4.0, -HEIGHT * 0.5, 28.0, 20.0), Color(0.2, 0.9, 0.3))
	# Glow base
	draw_circle(Vector2(0.0, HEIGHT * 0.5), 6.0, Color(1.0, 0.9, 0.2, 0.8))

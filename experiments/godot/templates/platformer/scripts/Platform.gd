# =============================================================================
# Platform.gd — StaticBody2D that draws itself; no external sprite needed.
# =============================================================================
# Created at runtime by LevelBuilder. setup() must be called immediately after
# add_child() so the collision shape and color are ready before the first frame.
# =============================================================================

class_name Platform
extends StaticBody2D

# Collision layer 1: world geometry
const LAYER_WORLD = 1

var _size:  Vector2 = Vector2(64, 32)
var _color: Color   = Color(0.25, 0.25, 0.35)

## Configures size and color, then attaches a matching CollisionShape2D.
## w and h are the full pixel dimensions of the platform.
## The node's position must already be set to the platform's CENTER before
## or after calling setup() — LevelBuilder sets it after.
func setup(w: float, h: float, hex_color: String = "3a3a52") -> void:
	_size  = Vector2(w, h)
	_color = Color("#" + hex_color if not hex_color.begins_with("#") else hex_color)

	collision_layer = LAYER_WORLD
	collision_mask  = 0   # static body — does not need to sense anything

	var shape      = RectangleShape2D.new()
	shape.size     = _size
	var coll       = CollisionShape2D.new()
	coll.shape     = shape
	add_child(coll)

	queue_redraw()

func _draw() -> void:
	# Rect2 centered on the node origin
	draw_rect(Rect2(-_size * 0.5, _size), _color)
	# Subtle top-edge highlight for readability
	draw_line(-_size * 0.5, Vector2(_size.x * 0.5, -_size.y * 0.5),
		_color.lightened(0.35), 2.0)

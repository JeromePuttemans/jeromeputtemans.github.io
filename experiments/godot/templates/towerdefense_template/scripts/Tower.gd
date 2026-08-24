# =============================================================================
# Tower.gd — Node2D: scans enemies, fires projectiles, draws itself.
# =============================================================================
# TARGETING STRATEGY — "first":
#   Among all enemies within range, the tower picks the one with the highest
#   progress() value (furthest along the path). This is the default strategy
#   and the most useful for the player. It can be swapped to nearest/strongest
#   by changing _pick_target() without touching any other code.
#
# FIRE RATE:
#   A _cooldown float counts down each frame. When it reaches 0 the tower
#   fires and resets to (1.0 / fire_rate). This avoids a Timer node per tower.
#
# SPLASH TOWERS:
#   When data["splash"] == true, on hit all enemies within splash_radius of
#   the impact point receive the same damage. The Projectile node calls
#   Tower.on_hit(impact_position) after reaching the target.
#
# RANGE RING:
#   Drawn faintly in _draw(). Shown always when selected, faded otherwise.
# =============================================================================

class_name Tower
extends Node2D

var tower_id:     String = ""
var damage:       int    = 0
var range_px:     float  = 0.0
var fire_rate:    float  = 0.0
var splash:       bool   = false
var splash_radius: float = 0.0
var sell_value:   int    = 0
var _color:       Color  = Color.CYAN

var _cooldown:   float  = 0.0
var _selected:   bool   = false

# Reference set by Main after placement so towers can scan enemies
var enemies_node: Node2D = null

func setup(data: Dictionary) -> void:
	tower_id      = data.get("id",           "")
	damage        = data.get("damage",        0)
	range_px      = float(data.get("range",   0))
	fire_rate     = float(data.get("fire_rate", 0))
	splash        = data.get("splash",        false)
	splash_radius = float(data.get("splash_radius", 0))
	var cost      = data.get("cost", 0)
	sell_value    = int(cost * ConfigManager.get_float("sell_refund_ratio", 0.0))
	_color        = Color("#" + data.get("color", "4a90d9"))
	_cooldown     = 0.0

func _process(delta: float) -> void:
	if enemies_node == null:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target = _pick_target()
	if target == null:
		return
	_fire(target)
	_cooldown = 1.0 / fire_rate

## Picks the enemy furthest along the path within range.
func _pick_target():
	var best:     Enemy = null
	var best_prog: float = -1.0
	for child in enemies_node.get_children():
		if not (child is Enemy) or not child.is_alive():
			continue
		if child.position.distance_to(global_position) <= range_px:
			var p = child.progress()
			if p > best_prog:
				best_prog = p
				best      = child
	return best

func _fire(target: Enemy) -> void:
	var proj = Projectile.new()
	proj.setup(target, damage, splash, splash_radius, _color, enemies_node)
	get_parent().add_child(proj)
	proj.global_position = global_position

func set_selected(sel: bool) -> void:
	_selected = sel
	queue_redraw()

func _draw() -> void:
	var tile = ConfigManager.get_int("tile_size", 0)
	var half = tile * 0.5
	# Tower body
	draw_rect(Rect2(-half + 8, -half + 8, tile - 16, tile - 16), _color)
	# Turret circle
	draw_circle(Vector2.ZERO, half * 0.38, _color.lightened(0.3))
	# Range ring (faint always, bright when selected)
	var ring_color = Color(1, 1, 1, 0.55 if _selected else 0.08)
	draw_arc(Vector2.ZERO, range_px, 0, TAU, 48, ring_color, 1.2)

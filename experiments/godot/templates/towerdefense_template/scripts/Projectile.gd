# =============================================================================
# Projectile.gd — Node2D: moves toward its target enemy and deals damage.
# =============================================================================
# HOMING PROJECTILE:
#   Each frame the projectile moves toward the target's current position at
#   `projectile_speed` px/s. This gives a "homing" effect that looks natural
#   for slow/medium enemies. If the target dies before impact, the projectile
#   simply disappears (queue_free on null target check).
#
# SPLASH vs SINGLE:
#   On arrival (distance < HIT_THRESHOLD) the projectile checks the splash
#   flag. If true it calls take_damage() on every living enemy within
#   splash_radius of the impact point. If false it damages the single target.
# =============================================================================

class_name Projectile
extends Node2D

const HIT_THRESHOLD = 10.0

var _target:       Enemy   = null
var _damage:       int     = 0
var _splash:       bool    = false
var _splash_radius: float  = 0.0
var _color:        Color   = Color.WHITE
var _enemies_node: Node2D  = null
var _speed:        float   = 0.0

func setup(target: Enemy, damage: int, splash: bool, splash_radius: float,
		   color: Color, enemies_node: Node2D) -> void:
	_target        = target
	_damage        = damage
	_splash        = splash
	_splash_radius = splash_radius
	_color         = color
	_enemies_node  = enemies_node
	_speed         = ConfigManager.get_float("projectile_speed", 0.0)

func _process(delta: float) -> void:
	# Target died before impact
	if not is_instance_valid(_target) or not _target.is_alive():
		queue_free()
		return

	var diff = _target.global_position - global_position
	var dist = diff.length()

	if dist < HIT_THRESHOLD:
		_on_impact()
		return

	global_position += diff.normalized() * _speed * delta
	queue_redraw()

func _on_impact() -> void:
	if _splash and _enemies_node != null:
		var impact_pos = global_position
		for child in _enemies_node.get_children():
			if child is Enemy and child.is_alive():
				if child.global_position.distance_to(impact_pos) <= _splash_radius:
					child.take_damage(_damage)
	else:
		if is_instance_valid(_target) and _target.is_alive():
			_target.take_damage(_damage)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, _color)

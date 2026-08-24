# =============================================================================
# Enemy.gd — Node2D: follows waypoints, takes damage, draws itself.
# =============================================================================
# PATHFINDING:
#   Enemies follow a pre-computed waypoint list (world-space Vector2 array)
#   stored in GridMap.waypoints. Each enemy keeps a _wp_index pointing to the
#   next waypoint it needs to reach. On each _process frame it moves toward
#   that waypoint at `speed` px/s. When it gets within 4 px (arrival threshold)
#   it advances _wp_index. When _wp_index exceeds the last waypoint the enemy
#   has reached the exit → GameState.enemy_reached_exit() is called.
#
# HEALTH BAR:
#   Drawn in _draw() as a simple red/green bar above the enemy sprite.
#   No textures needed.
#
# SIGNALS:
#   died()         — emitted when hp <= 0; WaveManager listens to count kills
#   reached_exit() — emitted before calling GameState.enemy_reached_exit()
# =============================================================================

class_name Enemy
extends Node2D

signal died()
signal reached_exit()

var hp:       int   = 0
var hp_max:   int   = 0
var speed:    float = 0.0
var reward:   int   = 0
var _color:   Color = Color.RED
var _size:    float = 0.0

var _waypoints: Array   = []   # Array[Vector2] — reference to GridMap.waypoints
var _wp_index:  int     = 0
var _alive:     bool    = true
var _removed:   bool    = false   # guard against emitting both died and reached_exit

const ARRIVAL_THRESHOLD = 4.0

func setup(data: Dictionary, waypoints: Array) -> void:
	hp        = data.get("hp",    0)
	hp_max    = hp
	speed     = float(data.get("speed",  0))
	reward    = data.get("reward", 0)
	_color    = Color("#" + data.get("color", "e74c3c"))
	_size     = float(data.get("size", 16))
	_waypoints = waypoints
	_wp_index  = 0
	# Start position: first waypoint
	if not _waypoints.is_empty():
		position = _waypoints[0]
		_wp_index = 1   # head toward second waypoint immediately

func _process(delta: float) -> void:
	if not _alive:
		return
	if _wp_index >= _waypoints.size():
		# Reached the exit
		if _removed:
			return
		_removed = true
		_alive = false
		emit_signal("reached_exit")
		GameState.enemy_reached_exit()
		queue_free()
		return

	var target = _waypoints[_wp_index]
	var diff   = target - position
	var dist   = diff.length()
	if dist <= ARRIVAL_THRESHOLD:
		position  = target
		_wp_index += 1
	else:
		position += diff.normalized() * speed * delta

	queue_redraw()

## Applies damage. Returns actual damage dealt.
func take_damage(amount: int) -> int:
	if not _alive:
		return 0
	var dealt = mini(amount, hp)
	hp -= dealt
	if hp <= 0:
		if _removed:
			return 0
		_removed = true
		_alive = false
		GameState.add_score(reward)
		GameState.add_gold(reward)
		emit_signal("died")
		queue_free()
	else:
		queue_redraw()
	return dealt

func is_alive() -> bool:
	return _alive

## Distance traveled so far — used by towers for "first" targeting.
func progress() -> float:
	if _wp_index == 0 or _waypoints.is_empty():
		return 0.0
	var base = 0.0
	for i in range(1, mini(_wp_index, _waypoints.size())):
		base += (_waypoints[i] - _waypoints[i - 1]).length()
	# Add partial segment toward current waypoint
	if _wp_index < _waypoints.size():
		base += (position - _waypoints[_wp_index - 1]).length()
	return base

func _draw() -> void:
	if not _alive:
		return
	# Enemy circle
	draw_circle(Vector2.ZERO, _size, _color)
	# Health bar (above)
	var bar_w  = _size * 2.2
	var bar_h  = 4.0
	var bar_y  = -_size - 7.0
	var bar_x  = -bar_w * 0.5
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.8, 0.1, 0.1))
	var fill = bar_w * (float(hp) / float(hp_max))
	draw_rect(Rect2(bar_x, bar_y, fill, bar_h), Color(0.1, 0.9, 0.1))

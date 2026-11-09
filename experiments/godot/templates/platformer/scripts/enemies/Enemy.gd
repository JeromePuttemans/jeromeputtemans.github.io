# =============================================================================
# Enemy.gd — Base class of the enemies
# =============================================================================
# Level calls step() every physics tick and tests hit_box() against the
# player. stompable: jumping on it kills it and bounces the player. After
# die(), the enemy plays a short squash and fade, then sets removed: Level
# takes it out of its list and frees it.
# =============================================================================

class_name Enemy
extends Node2D

const DEATH_TIME: float = 0.45

var level: Level = null
var alive: bool = true
var removed: bool = false
var stompable: bool = true
var _death: float = 0.0
var _anim: float = 0.0

func step(delta: float) -> void:
	_anim += delta
	if not alive:
		_death += delta
		if _death >= DEATH_TIME:
			removed = true
		return
	_step_alive(delta)

func _step_alive(_delta: float) -> void:
	pass

func hit_box() -> Rect2:
	return Rect2(position.x - 14.0, position.y - 26.0, 28.0, 26.0)

func die() -> void:
	alive = false
	_death = 0.0

func color() -> Color:
	return Color.WHITE

func _process(_delta: float) -> void:
	queue_redraw()

## 1 while alive, then shrinks to 0: squash flat and fade.
func death_scale() -> Vector2:
	if alive:
		return Vector2.ONE
	var t: float = clampf(_death / DEATH_TIME, 0.0, 1.0)
	return Vector2(1.0 + 0.6 * t, maxf(1.0 - 1.4 * t, 0.05))

func death_alpha() -> float:
	return 1.0 if alive else clampf(1.0 - _death / DEATH_TIME, 0.0, 1.0)

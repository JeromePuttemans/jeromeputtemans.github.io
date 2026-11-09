# =============================================================================
# GameCamera.gd — Platformer camera: look-ahead, ground anchoring, shake
# =============================================================================
# Horizontal: the target leads the player by up to camera_look_ahead px in
# the facing direction, scaled by the running speed, and is smoothed.
# Vertical: the camera follows an anchor that only moves when the player
# lands, climbs far above it, or falls below it. Jumping in place therefore
# does not bob the screen, while a long fall is followed quickly.
# Smoothing is exponential: x += (target - x) * (1 - exp(-k * dt)), the
# same feel at any frame rate.
# Shake: impacts add "trauma" (0..1); the offset is random * trauma^2 *
# camera_shake px and trauma decays, so small hits stay subtle.
# =============================================================================

class_name GameCamera
extends Camera2D

var _level_size := Vector2.ZERO
var _look: float = 0.0
var _anchor_y: float = 0.0
var _trauma: float = 0.0
var _look_ahead: float = 90.0
var _shake: float = 14.0
var _run_speed: float = 300.0

func setup(level_size: Vector2) -> void:
	_level_size = level_size
	_look_ahead = ConfigManager.get_float("camera_look_ahead", 90.0)
	_shake = ConfigManager.get_float("camera_shake", 14.0)
	_run_speed = ConfigManager.get_float("run_speed", 300.0)
	position_smoothing_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	limit_left = 0
	limit_right = int(level_size.x)
	limit_bottom = int(level_size.y)
	limit_top = 0
	make_current()

func snap_to(player: Player) -> void:
	_look = 0.0
	_anchor_y = player.position.y - 70.0
	position = _clamped(Vector2(player.position.x, _anchor_y))
	reset_physics_interpolation()

func follow(player: Player, delta: float) -> void:
	var speed_ratio: float = clampf(absf(player.velocity.x) / _run_speed, 0.0, 1.0)
	var look_target: float = player.facing * _look_ahead * speed_ratio
	_look = lerpf(_look, look_target, 1.0 - exp(-2.5 * delta))
	var py: float = player.position.y - 70.0
	var falling_fast: bool = false
	if player.grounded or player.sliding:
		_anchor_y = py
	elif py < _anchor_y - 130.0:
		_anchor_y = py + 130.0
	elif py > _anchor_y + 60.0:
		_anchor_y = py - 60.0
		falling_fast = true
	var target := Vector2(player.position.x + _look, _anchor_y)
	var x: float = lerpf(position.x, target.x, 1.0 - exp(-8.0 * delta))
	var y: float = lerpf(position.y, target.y, 1.0 - exp(-(12.0 if falling_fast else 5.0) * delta))
	position = _clamped(Vector2(x, y))

## Keeps the centre inside the level so the limits never lag behind.
func _clamped(p: Vector2) -> Vector2:
	var half: Vector2 = get_viewport_rect().size * 0.5
	var out := p
	out.x = clampf(p.x, half.x, maxf(_level_size.x - half.x, half.x))
	out.y = clampf(p.y, half.y, maxf(_level_size.y - half.y, half.y))
	return out

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	_trauma = maxf(_trauma - 1.6 * delta, 0.0)
	var amount: float = _trauma * _trauma * _shake
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount

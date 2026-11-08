# =============================================================================
# GameCamera.gd (Camera2D): smooth follow + trauma-based screen shake.
# =============================================================================
# FOLLOW:
#   The camera keeps the player at the center of the MAP AREA (the screen
#   part not covered by the side panel and the message log), not at the
#   center of the screen. Each frame:
#     position = lerp(position, target, 1 - exp(-FOLLOW_SPEED x delta))
#   This exponential smoothing is frame-rate independent. The position is
#   clamped so the camera never shows much beyond the dungeon edges.
#
# SHAKE (Squirrel Eiserloh, "Juicing your cameras", GDC 2016):
#   add_trauma() accumulates 0..1, decays linearly; offset amplitude is
#   trauma², built from sines of unrelated frequencies (smooth, no jitter).
# =============================================================================

class_name GameCamera
extends Camera2D

const FOLLOW_SPEED: float = 9.0

static var _instance: GameCamera = null

var area: Rect2 = Rect2()          # map area in screen pixels
var map_size: Vector2 = Vector2()  # dungeon size in world pixels
var _target: Vector2 = Vector2()
var _trauma: float = 0.0
var _time: float = 0.0
var _decay: float = 0.0
var _max_offset: float = 0.0

func _enter_tree() -> void:
	_instance = self

func _exit_tree() -> void:
	if _instance == self:
		_instance = null

func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	_decay = ConfigManager.get_float("shake_decay", 0.0)
	_max_offset = ConfigManager.get_float("shake_max_offset", 0.0)
	make_current()

static func add_trauma(amount: float) -> void:
	if _instance != null:
		_instance._trauma = minf(_instance._trauma + amount, 1.0)

## World point (the player's drawn position) to keep centered.
func follow(world_point: Vector2) -> void:
	_target = _clamp(world_point - area.get_center())

func snap(world_point: Vector2) -> void:
	follow(world_point)
	position = _target

func _clamp(top_left: Vector2) -> Vector2:
	var pad: float = 48.0
	var result := top_left
	for axis in 2:
		var lo: float = -area.position[axis] - pad
		var hi: float = map_size[axis] - area.end[axis] + pad
		if hi < lo:
			result[axis] = (lo + hi) * 0.5   # map smaller than the area: center it
		else:
			result[axis] = clampf(result[axis], lo, hi)
	return result

func _process(delta: float) -> void:
	position = position.lerp(_target, 1.0 - exp(-FOLLOW_SPEED * delta))
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return
	_time += delta
	_trauma = maxf(_trauma - _decay * delta, 0.0)
	var amp: float = _trauma * _trauma * _max_offset
	offset = Vector2(
		sin(_time * 47.0) * 0.7 + sin(_time * 83.0 + 1.3) * 0.3,
		sin(_time * 59.0 + 2.1) * 0.7 + sin(_time * 97.0 + 0.4) * 0.3) * amp

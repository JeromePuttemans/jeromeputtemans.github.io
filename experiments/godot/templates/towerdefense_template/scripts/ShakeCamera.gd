# =============================================================================
# ShakeCamera.gd: Camera2D with a trauma-based screen shake.
# =============================================================================
# TRAUMA MODEL (Squirrel Eiserloh, "Juicing your cameras", GDC 2016):
#   add_trauma(x) accumulates a 0..1 value that decays linearly over time.
#   The actual shake amplitude is trauma², so small hits are barely felt and
#   big ones are violent; this non-linear curve reads as "physical".
#   The offset uses two sines of unrelated frequencies per axis instead of
#   random numbers: smooth, organic motion without frame-to-frame jitter.
#
#   The camera is anchored top-left at (0, 0): world coordinates equal screen
#   coordinates when there is no shake, and the HUD (CanvasLayer) is never
#   shaken.
# =============================================================================

class_name ShakeCamera
extends Camera2D

static var _instance: ShakeCamera = null

var _trauma:     float = 0.0
var _decay:      float = 0.0
var _max_offset: float = 0.0
var _time:       float = 0.0

func _enter_tree() -> void:
	_instance = self

func _exit_tree() -> void:
	if _instance == self:
		_instance = null

func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	position    = Vector2.ZERO
	_decay      = ConfigManager.get_float("shake_decay", 0.0)
	_max_offset = ConfigManager.get_float("shake_max_offset", 0.0)
	make_current()

static func add_trauma(amount: float) -> void:
	if _instance == null:
		return
	_instance._trauma = minf(_instance._trauma + amount, 1.0)

static func reset() -> void:
	if _instance == null:
		return
	_instance._trauma = 0.0
	_instance.offset = Vector2.ZERO

func _process(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return
	_time += delta
	_trauma = maxf(_trauma - _decay * delta, 0.0)
	var amp: float = _trauma * _trauma * _max_offset
	offset = Vector2(
		sin(_time * 47.0) * 0.7 + sin(_time * 83.0 + 1.3) * 0.3,
		sin(_time * 59.0 + 2.1) * 0.7 + sin(_time * 97.0 + 0.4) * 0.3
	) * amp

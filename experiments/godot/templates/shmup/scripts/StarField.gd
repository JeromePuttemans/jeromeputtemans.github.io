# =============================================================================
# StarField.gd — 3-layer parallax stars, batch-optimised for HTML5.
# =============================================================================
# OPTIMISATIONS:
#   - Far layer uses draw_rect(1×1) instead of draw_circle — faster on WebGL.
#   - Mid and near layers use draw_circle (still one CanvasItem batch).
#   - Star positions stored in a flat PackedVector2Array per layer for
#     cache-friendly iteration (avoids per-element Dictionary overhead).
#   - queue_redraw() called only once per frame from _process.
#   - Layer data stored as typed arrays: positions (PackedVector2Array),
#     speed (float), size (float), alpha (float).
# =============================================================================
class_name StarField
extends Node2D

var _layers: Array = []   # Array[Dictionary{pts, speed, size, alpha, use_rect}]
var _w: float = 0.0
var _h: float = 0.0

func setup() -> void:
	_w = ConfigManager.get_float("viewport_play_width",  0.0)
	_h = ConfigManager.get_float("viewport_play_height", 0.0)
	var n     = ConfigManager.get_int("star_count", 0)
	var s_far = ConfigManager.get_float("star_speed_far",  0.0)
	var s_mid = ConfigManager.get_float("star_speed_mid",  0.0)
	var s_nea = ConfigManager.get_float("star_speed_near", 0.0)

	_layers = [
		# Far: many tiny dots — use rect for speed
		{pts=_gen(n,     _w,_h), speed=s_far, size=0.7, alpha=0.32, use_rect=true},
		# Mid: medium circles
		{pts=_gen(n/2,   _w,_h), speed=s_mid, size=1.3, alpha=0.52, use_rect=false},
		# Near: few bright circles
		{pts=_gen(n/4,   _w,_h), speed=s_nea, size=2.0, alpha=0.82, use_rect=false},
	]

func _gen(count: int, w: float, h: float) -> PackedVector2Array:
	var arr = PackedVector2Array()
	arr.resize(count)
	for i in count:
		arr[i] = Vector2(randf() * w, randf() * h)
	return arr

func _process(delta: float) -> void:
	for layer in _layers:
		var pts: PackedVector2Array = layer.pts
		var spd: float = layer.speed
		var count = pts.size()
		for i in count:
			pts[i].y += spd * delta
			if pts[i].y > _h:
				pts[i] = Vector2(randf() * _w, -2.0)
		layer.pts = pts   # PackedVector2Array is value type — write back
	queue_redraw()

func _draw() -> void:
	for layer in _layers:
		var pts:      PackedVector2Array = layer.pts
		var col:      Color  = Color(1.0, 1.0, 1.0, layer.alpha)
		var sz:       float  = layer.size
		var use_rect: bool   = layer.use_rect
		if use_rect:
			for p in pts:
				draw_rect(Rect2(p.x, p.y, sz, sz), col)
		else:
			for p in pts:
				draw_circle(p, sz, col)

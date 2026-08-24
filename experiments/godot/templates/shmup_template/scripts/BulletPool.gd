# =============================================================================
# BulletPool.gd — Single Node2D that owns, updates, and draws all bullets.
# =============================================================================
# ARCHITECTURE (key optimisation):
#   Previous design: N ShmupBullet Node2D children → N _process() callbacks,
#   N queue_redraw() calls, N separate WebGL CanvasItem batches per frame.
#
#   New design: ONE Node2D. Bullets are plain Dictionaries in _bullets[].
#   A single _process() loop updates all positions. A single _draw() call
#   renders all bullets in one WebGL batch — dramatically cheaper on HTML5.
#
# TRAIL:
#   Each bullet carries a trail Array of past positions (local space).
#   Positions are pushed at the front and popped from the back each frame.
#   All trail circles are emitted in the same _draw() call as the bullet core.
#
# POOL:
#   acquire() scans for the first inactive slot — O(pool_size) worst case,
#   O(1) typical (first free slot is usually near the front during active play).
#   release(index) sets active=false, clears trail.
# =============================================================================
class_name BulletPool
extends Node2D

const TRAIL_LEN = 8

var _bullets:   Array  = []   # Array[Dictionary]
var _play_w:    float  = 0.0
var _play_h:    float  = 0.0
var _any_active: bool  = false  # skip _draw() when nothing is flying

func setup(pool_size: int) -> void:
	_play_w = ConfigManager.get_float("viewport_play_width",  0.0)
	_play_h = ConfigManager.get_float("viewport_play_height", 0.0)
	_bullets.clear()
	for _i in pool_size:
		_bullets.append({
			active = false,
			pos    = Vector2.ZERO,
			vel    = Vector2.ZERO,
			color  = Color.WHITE,
			radius = 4.0,
			trail  = []
		})

## Fire a bullet. Returns the slot index, or -1 if pool full.
func acquire(pos: Vector2, vel: Vector2, col: Color, radius: float) -> int:
	for i in _bullets.size():
		var b = _bullets[i]
		if not b.active:
			b.active = true
			b.pos    = pos
			b.vel    = vel
			b.color  = col
			b.radius = radius
			b.trail  = []
			_any_active = true
			return i
	push_warning("BulletPool: pool exhausted (%d)" % _bullets.size())
	return -1

## Deactivate bullet at index.
func release(index: int) -> void:
	if index < 0 or index >= _bullets.size():
		return
	var b  = _bullets[index]
	b.active = false
	b.trail  = []

## Returns Array of active bullet indices. Called by collision code.
## Reuses a pre-allocated Array to avoid per-frame allocation.
var _active_cache: Array = []
func get_active_indices() -> Array:
	_active_cache.clear()
	for i in _bullets.size():
		if _bullets[i].active:
			_active_cache.append(i)
	return _active_cache

## Direct access to bullet data by index (no copy).
func get_bullet(i: int) -> Dictionary:
	return _bullets[i]

func _process(delta: float) -> void:
	_any_active = false
	for b in _bullets:
		if not b.active:
			continue
		_any_active = true

		# Trail: prepend current position before moving
		b.trail.push_front(b.pos)
		if b.trail.size() > TRAIL_LEN:
			b.trail.pop_back()

		b.pos += b.vel * delta

		# Off-screen deactivation
		if (b.pos.y < -40 or b.pos.y > _play_h + 40 or
			b.pos.x < -40 or b.pos.x > _play_w + 40):
			b.active = false
			b.trail  = []

	if _any_active:
		queue_redraw()

func _draw() -> void:
	if not _any_active:
		return
	for b in _bullets:
		if not b.active:
			continue
		var c = b.color
		var r = b.radius

		# Trail (fading circles, shrinking radius)
		var tlen = b.trail.size()
		for i in tlen:
			var alpha = (1.0 - float(i) / TRAIL_LEN) * 0.5
			var tr    = r * (1.0 - float(i + 1) / TRAIL_LEN) * 0.75
			if tr > 0.4:
				draw_circle(b.trail[i], tr, Color(c.r, c.g, c.b, alpha))

		# Bullet core
		draw_circle(b.pos, r, c)
		# Glow halo (cheap — just a larger semi-transparent circle)
		draw_circle(b.pos, r * 1.8, Color(c.r, c.g, c.b, 0.18))

# =============================================================================
# Explosion.gd — Node2D: animated explosion, auto-queues free when done.
# ALGORITHM:
#   _t / _duration drives a 0→1 progress value each frame.
#   Ring: radius expands, alpha fades out.
#   Particles: N points distributed radially with random spread,
#              each stored as (angle, speed, size) at spawn.
#              Position computed each frame as pos = angle_dir * speed * _t.
# =============================================================================
class_name Explosion
extends Node2D

var _duration:    float = 0.0
var _radius:      float = 0.0
var _color:       Color = Color.ORANGE
var _particles:   Array = []   # Array[{angle, speed, size}]
var _t:           float = 0.0

func setup(radius: float, color: Color) -> void:
	_duration  = ConfigManager.get_float("explosion_duration", 0.0)
	_radius    = radius
	_color     = color
	_t         = 0.0

	var count = ConfigManager.get_int("explosion_particles", 0)
	_particles = []
	for i in count:
		_particles.append({
			angle = randf() * TAU,
			speed = randf_range(radius * 0.8, radius * 3.0),
			size  = randf_range(2.0, 5.0)
		})

func _process(delta: float) -> void:
	_t += delta / _duration
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress  = _t
	var inv       = 1.0 - progress
	var ring_r    = _radius * (0.5 + progress * 1.8)
	var ring_a    = inv * 0.9

	# Expanding ring
	draw_arc(Vector2.ZERO, ring_r, 0, TAU, 32,
		Color(_color.r, _color.g, _color.b, ring_a), 2.5)

	# Inner flash (only first 30% of animation)
	if progress < 0.3:
		var flash_a = (0.3 - progress) / 0.3
		draw_circle(Vector2.ZERO, ring_r * 0.6,
			Color(1.0, 1.0, 0.8, flash_a * 0.6))

	# Radial particles
	for p in _particles:
		var dist = p.speed * progress
		var pos  = Vector2(cos(p.angle), sin(p.angle)) * dist
		var a    = inv * 0.85
		var s    = p.size * inv
		draw_circle(pos, s, Color(_color.r, _color.g, _color.b, a))

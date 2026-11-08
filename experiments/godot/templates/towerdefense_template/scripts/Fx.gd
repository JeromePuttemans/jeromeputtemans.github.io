# =============================================================================
# Fx.gd (Node2D): one world-space layer that draws every short-lived effect.
# =============================================================================
# WHY ONE NODE:
#   Particles, shockwave rings, beam tracers and floating texts are all tiny,
#   short-lived and numerous. Instead of one node per effect, they are plain
#   objects stored in arrays, updated in _process and drawn in a single
#   _draw() call. No allocation of nodes in the hot path, one draw call
#   batch, and clear_all() resets everything on restart.
#
# STATIC API:
#   Any script can call Fx.burst(...), Fx.ring(...), Fx.tracer(...),
#   Fx.text(...) with GLOBAL positions. The calls are forwarded to the single
#   instance registered in _enter_tree(); they are no-ops if no Fx node is in
#   the tree, so gameplay code never depends on the effect layer.
# =============================================================================

class_name Fx
extends Node2D

static var _instance: Fx = null

const MAX_PARTICLES: int = 800

class Particle:
	var pos:      Vector2
	var vel:      Vector2
	var life:     float
	var max_life: float
	var size:     float
	var color:    Color
	var drag:     float
	var gravity:  float

class Ring:
	var pos:      Vector2
	var radius:   float
	var life:     float
	var max_life: float
	var color:    Color
	var width:    float

class Tracer:
	var from:     Vector2
	var to:       Vector2
	var life:     float
	var max_life: float
	var color:    Color
	var width:    float

class FloatText:
	var pos:      Vector2
	var text:     String
	var life:     float
	var max_life: float
	var color:    Color
	var size:     int

var _particles: Array[Particle]  = []
var _rings:     Array[Ring]      = []
var _tracers:   Array[Tracer]    = []
var _texts:     Array[FloatText] = []
var _font:      Font = null

func _enter_tree() -> void:
	_instance = self

func _exit_tree() -> void:
	if _instance == self:
		_instance = null

func _ready() -> void:
	_font = ThemeDB.fallback_font

# ---------------------------------------------------------------------------
# Static API (global positions)
# ---------------------------------------------------------------------------

## Radial burst of particles. gravity > 0 pulls them down (debris, coins).
static func burst(pos: Vector2, color: Color, count: int = 10, speed: float = 120.0,
		size: float = 3.0, life: float = 0.5, gravity: float = 0.0) -> void:
	if _instance == null:
		return
	_instance._add_burst(pos, color, count, speed, size, life, gravity)

## Expanding shockwave circle, from 0 to radius.
static func ring(pos: Vector2, color: Color, radius: float, life: float = 0.35,
		width: float = 3.0) -> void:
	if _instance == null:
		return
	var r := Ring.new()
	r.pos = _instance.to_local(pos)
	r.radius = radius
	r.life = life
	r.max_life = life
	r.color = color
	r.width = width
	_instance._rings.append(r)

## Straight line that fades out (instant-hit weapons).
static func tracer(from: Vector2, to: Vector2, color: Color, width: float = 4.0,
		life: float = 0.18) -> void:
	if _instance == null:
		return
	var t := Tracer.new()
	t.from = _instance.to_local(from)
	t.to = _instance.to_local(to)
	t.life = life
	t.max_life = life
	t.color = color
	t.width = width
	_instance._tracers.append(t)

## Floating text that pops, rises and fades ("+6", "Not enough gold"...).
static func text(pos: Vector2, msg: String, color: Color, font_size: int = 18,
		life: float = 0.9) -> void:
	if _instance == null:
		return
	var f := FloatText.new()
	f.pos = _instance.to_local(pos)
	f.text = msg
	f.life = life
	f.max_life = life
	f.color = color
	f.size = font_size
	_instance._texts.append(f)

static func clear_all() -> void:
	if _instance == null:
		return
	_instance._particles.clear()
	_instance._rings.clear()
	_instance._tracers.clear()
	_instance._texts.clear()
	_instance.queue_redraw()

# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------

func _add_burst(pos: Vector2, color: Color, count: int, speed: float, size: float,
		life: float, gravity: float) -> void:
	var local: Vector2 = to_local(pos)
	for i in count:
		if _particles.size() >= MAX_PARTICLES:
			_particles.pop_front()
		var p := Particle.new()
		var angle: float = randf() * TAU
		var spd: float = speed * randf_range(0.35, 1.0)
		p.pos = local
		p.vel = Vector2.from_angle(angle) * spd
		if gravity > 0.0:
			p.vel.y -= speed * 0.6   # throw debris upward first
		p.life = life * randf_range(0.6, 1.0)
		p.max_life = p.life
		p.size = size * randf_range(0.6, 1.2)
		p.color = color
		p.drag = 3.5
		p.gravity = gravity
		_particles.append(p)

func _process(delta: float) -> void:
	var alive_p: Array[Particle] = []
	for p in _particles:
		p.life -= delta
		if p.life <= 0.0:
			continue
		p.vel *= maxf(1.0 - p.drag * delta, 0.0)
		p.vel.y += p.gravity * delta
		p.pos += p.vel * delta
		alive_p.append(p)
	_particles = alive_p

	var alive_r: Array[Ring] = []
	for r in _rings:
		r.life -= delta
		if r.life > 0.0:
			alive_r.append(r)
	_rings = alive_r

	var alive_t: Array[Tracer] = []
	for t in _tracers:
		t.life -= delta
		if t.life > 0.0:
			alive_t.append(t)
	_tracers = alive_t

	var alive_f: Array[FloatText] = []
	for f in _texts:
		f.life -= delta
		if f.life > 0.0:
			f.pos.y -= 38.0 * delta * (f.life / f.max_life + 0.2)
			alive_f.append(f)
	_texts = alive_f

	queue_redraw()

# ---------------------------------------------------------------------------
# Draw
# ---------------------------------------------------------------------------

func _draw() -> void:
	for t in _tracers:
		var k: float = t.life / t.max_life
		var outer := Color(t.color, 0.45 * k)
		draw_line(t.from, t.to, outer, t.width * (1.0 + 1.5 * k), true)
		draw_line(t.from, t.to, Color(1.0, 1.0, 1.0, k), maxf(t.width * 0.4 * k, 1.0), true)

	for r in _rings:
		var k: float = 1.0 - r.life / r.max_life           # 0 -> 1
		var radius: float = r.radius * (1.0 - pow(1.0 - k, 3.0))   # ease-out cubic
		draw_arc(r.pos, radius, 0.0, TAU, 40,
			Color(r.color, 1.0 - k), r.width * (1.0 - k * 0.6), true)

	for p in _particles:
		var k: float = p.life / p.max_life
		draw_circle(p.pos, maxf(p.size * (0.4 + 0.6 * k), 0.5), Color(p.color, minf(k * 1.6, 1.0)))

	for f in _texts:
		var k: float = 1.0 - f.life / f.max_life           # 0 -> 1
		var pop: float = 1.0 + 0.5 * maxf(1.0 - k * 6.0, 0.0)   # quick scale pop
		var alpha: float = clampf(f.life / f.max_life * 2.5, 0.0, 1.0)
		var fs: int = int(f.size * pop)
		var w: float = 260.0
		var at := Vector2(f.pos.x - w * 0.5, f.pos.y)
		draw_string_outline(_font, at, f.text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 5,
			Color(0.05, 0.05, 0.08, alpha * 0.85))
		draw_string(_font, at, f.text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(f.color, alpha))

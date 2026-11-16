# =============================================================================
# Effects3D.gd: One-shot particle bursts (CPUParticles3D)
# =============================================================================
# Small square billboards, blended rather than added: on a white world an
# additive glow would vanish. Accent colour for shards and seals, graphite
# for dashes and launches, pale concrete dust for landings and the gnomon
# rising. Each burst frees itself when its particles have died.
# =============================================================================

class_name Effects3D
extends Node3D

var _quad: QuadMesh = null
var _materials: Dictionary = {}

func _ready() -> void:
	_quad = QuadMesh.new()
	_quad.size = Vector2(0.1, 0.1)

func _material(additive: bool) -> StandardMaterial3D:
	if _materials.has(additive):
		return _materials[additive]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_materials[additive] = m
	return m

## amount particles thrown outwards at `speed` from `pos`, for `life` s.
func burst(pos: Vector3, color: Color, amount: int, speed: float, life: float, gravity: float = 0.0, size: float = 1.0, additive: bool = false, spread: float = 180.0, direction: Vector3 = Vector3.UP) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.mesh = _quad
	p.material_override = _material(additive)
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -gravity, 0.0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)

## Ring of dust spreading on the ground.
func dust(pos: Vector3, amount: int, speed: float) -> void:
	burst(pos + Vector3(0.0, 0.1, 0.0), Color(0.78, 0.78, 0.76, 0.7), amount, speed, 0.7, 2.0, 2.2, false, 80.0)

## Graphite streaks left behind by a dash, thrown backwards.
func streak(pos: Vector3, dir: Vector3) -> void:
	burst(pos + Vector3(0.0, 0.9, 0.0), Color(0.15, 0.15, 0.17, 0.55), 14, 5.0, 0.35, 0.0, 0.8, false, 25.0, -dir)

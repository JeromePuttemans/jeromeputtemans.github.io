# =============================================================================
# Seed.gd — Projectile of the spitter plant
# =============================================================================
# Flies straight, pops on the first solid tile or after seed_lifetime s.
# =============================================================================

class_name Seed
extends Node2D

var level: Level = null
var velocity := Vector2.ZERO
var gone: bool = false
var _life: float = 0.0
var _max_life: float = 0.0

func _ready() -> void:
	_max_life = ConfigManager.get_float("seed_lifetime", 5.0)

func step(delta: float) -> void:
	_life += delta
	position += velocity * delta
	if level.is_solid_px(position) or _life > _max_life:
		gone = true
		level.effects.burst(position, Color("a0d468"), 5, 90.0)

func hit_box() -> Rect2:
	return Rect2(position.x - 6.0, position.y - 6.0, 12.0, 12.0)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var spin: float = _life * 14.0 * signf(velocity.x)
	draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
	PlayerArt.ellipse(self, Vector2.ZERO, 8.0, 6.0, Color(0.2, 0.3, 0.1))
	PlayerArt.ellipse(self, Vector2.ZERO, 6.5, 4.5, Color(0.75, 0.88, 0.4))
	draw_circle(Vector2(-2.0, -1.5), 1.5, Color(1.0, 1.0, 0.9, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 3:
		var back: Vector2 = Vector2(-signf(velocity.x) * (10.0 + i * 7.0), sin(_life * 20.0 + i) * 1.5)
		draw_circle(back, 2.5 - i * 0.6, Color(0.75, 0.88, 0.4, 0.35 - i * 0.1))

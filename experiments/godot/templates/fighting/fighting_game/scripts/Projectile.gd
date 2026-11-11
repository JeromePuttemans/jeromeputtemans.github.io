# =============================================================================
# Projectile.gd — Steam bolt, ground shockwave or flying blade
# =============================================================================
# Moves speed px per frame in its direction for lifetime frames. Match
# tests its box against the opponent's hurtboxes and against the other
# fighter's projectiles (two projectiles cancel each other out). Its
# "height" works like a move's: the shockwave travels along the floor and
# must be blocked crouching.
# =============================================================================

class_name Projectile
extends Node2D

var owner_fighter: Fighter = null
var data: Dictionary = {}
var dir: int = 1
var dead: bool = false
var _life: int = 0
var _time: float = 0.0

func step() -> void:
	_life += 1
	position.x += float(data.get("speed", 8.0)) * dir
	if _life > int(data.get("lifetime", 100)) or position.x < -50.0 or position.x > Match.STAGE_WIDTH + 50.0:
		dead = true

func box() -> Rect2:
	var s: float = float(data.get("size", 16))
	if str(data.get("kind", "")) == "wave":
		return Rect2(position.x - s, position.y - s * 1.6, s * 2.0, s * 2.0)
	return Rect2(position.x - s, position.y - s, s * 2.0, s * 2.0)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var s: float = float(data.get("size", 16))
	var glow: Texture2D = Fx.glow()
	var eye := Color(str(owner_fighter.style.get("eye", "ffffff")))
	match str(data.get("kind", "steam")):
		"steam":
			Fx.put(self, glow, Vector2.ZERO, s * 3.2, Color(eye, 0.35))
			for k in 5:
				var off := Vector2(-dir * k * 9.0, sin(_time * 18.0 + k) * 4.0)
				draw_circle(off, s * (1.0 - k * 0.15), Color(0.9, 0.95, 1.0, 0.8 - k * 0.14))
			draw_circle(Vector2.ZERO, s * 0.55, Color(1.0, 1.0, 1.0))
		"wave":
			Fx.put(self, glow, Vector2(0.0, -s * 0.5), s * 3.0, Color(1.0, 0.55, 0.2, 0.5))
			for k in 4:
				var h: float = s * (1.6 - k * 0.3) * (0.85 + 0.15 * sin(_time * 30.0 + k))
				var x: float = -dir * k * 12.0
				draw_colored_polygon(PackedVector2Array([Vector2(x - 8.0, 18.0), Vector2(x + dir * 6.0, 18.0 - h * 1.4), Vector2(x + 14.0 * dir, 18.0)]), Color(1.0, 0.6 - k * 0.1, 0.25, 0.9 - k * 0.2))
		"blade":
			Fx.put(self, glow, Vector2.ZERO, s * 2.6, Color(eye, 0.45))
			draw_set_transform(Vector2.ZERO, _time * 30.0 * dir, Vector2.ONE)
			for k in 3:
				var a: float = TAU * k / 3.0
				draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2.RIGHT.rotated(a) * s * 1.4, Vector2.RIGHT.rotated(a + 0.5) * s * 0.6]), Color(0.92, 0.95, 1.0))
			draw_circle(Vector2.ZERO, 3.0, eye)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

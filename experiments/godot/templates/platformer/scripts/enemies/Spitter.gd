# =============================================================================
# Spitter.gd — Plant that spits a seed every spitter_interval seconds
# =============================================================================
# Fixed on its tile, facing left ('t') or right ('T'). It only shoots when
# the player is within spitter_range tiles horizontally and 5 tiles
# vertically, with a short swelling tell (0.35 s) before each shot.
# Stompable from above, deadly from the sides.
# =============================================================================

class_name Spitter
extends Enemy

const TELL: float = 0.35

var dir: int = -1
var timer: float = 1.0
var _interval: float = 0.0
var _range: float = 0.0

func _ready() -> void:
	_interval = ConfigManager.get_float("spitter_interval", 2.2)
	_range = ConfigManager.get_float("spitter_range", 13.0) * LevelData.TILE

func _step_alive(delta: float) -> void:
	var p: Player = level.player
	var near: bool = absf(p.position.x - position.x) < _range and absf(p.position.y - position.y) < LevelData.TILE * 5.0
	if not near and timer < TELL:
		timer = TELL
	timer -= delta
	if timer <= 0.0:
		timer = _interval
		if near and not p.dead:
			level.spawn_seed(position + Vector2(dir * 18.0, -20.0), dir)
			Sfx.play("spit")

func hit_box() -> Rect2:
	return Rect2(position.x - 15.0, position.y - 34.0, 30.0, 34.0)

func color() -> Color:
	return Color("4caf50")

func _draw() -> void:
	var s: Vector2 = death_scale()
	var a: float = death_alpha()
	var swell: float = 0.0
	if alive and timer < TELL:
		swell = 1.0 - timer / TELL
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s.x * dir, s.y))
	var stem := Color(0.2, 0.45, 0.18, a)
	draw_line(Vector2(0.0, 0.0), Vector2(-2.0, -14.0), stem, 5.0)
	PlayerArt.ellipse(self, Vector2(-9.0, -4.0), 8.0, 3.5, Color(0.3, 0.62, 0.25, a))
	PlayerArt.ellipse(self, Vector2(7.0, -5.0), 7.0, 3.0, Color(0.3, 0.62, 0.25, a))
	var head_r: float = 11.0 + swell * 3.0
	PlayerArt.ellipse(self, Vector2(0.0, -23.0), head_r + 1.5, head_r * 0.9 + 1.5, Color(0.12, 0.25, 0.1, a))
	PlayerArt.ellipse(self, Vector2(0.0, -23.0), head_r, head_r * 0.9, Color(0.36, 0.7, 0.3, a))
	PlayerArt.ellipse(self, Vector2(-3.0, -28.0), 4.0, 2.0, Color(0.7, 0.95, 0.6, a * 0.5))
	PlayerArt.ellipse(self, Vector2(9.0 + swell, -22.0), 5.0 + swell * 2.0, 4.0 + swell * 2.0, Color(0.55, 0.12, 0.15, a))
	draw_circle(Vector2(1.0, -27.0), 2.0, Color(1.0, 1.0, 1.0, a))
	draw_circle(Vector2(1.6, -27.0), 1.0, Color(0.05, 0.05, 0.05, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

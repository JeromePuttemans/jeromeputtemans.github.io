# =============================================================================
# Walker.gd — Beetle (stompable) or hedgehog (spiky, never stompable)
# =============================================================================
# Patrols its floor: it turns around when the tile ahead is a wall or when
# there is no floor under its front foot, so it never walks off a ledge.
# It reads the tile grid directly (Level.is_solid / is_floor), it has no
# collision body. Without floor under it (a crumbling block fell, a
# coloured block swapped), it falls until it lands or leaves the level.
# =============================================================================

class_name Walker
extends Enemy

const HALF_WIDTH: float = 14.0

var spiky: bool = false
var dir: int = -1
var _speed: float = 0.0
var _fall_speed: float = 0.0

func _ready() -> void:
	_speed = ConfigManager.get_float("hedgehog_speed" if spiky else "beetle_speed", 70.0)
	stompable = not spiky

func _step_alive(delta: float) -> void:
	var t: float = LevelData.TILE
	var below: int = floori((position.y + 1.0) / t)
	var on_floor: bool = level.is_floor(floori(position.x / t), below)
	if not on_floor:
		_fall_speed = minf(_fall_speed + ConfigManager.get_float("gravity", 2220.0) * delta, 900.0)
		var next_y: float = position.y + _fall_speed * delta
		var col: int = floori(position.x / t)
		for r in range(floori((position.y - 0.001) / t) + 1, floori((next_y - 0.001) / t) + 1):
			if level.is_floor(col, r):
				next_y = r * t
				_fall_speed = 0.0
				break
		position.y = next_y
		if position.y > level.data.height * t + 80.0:
			alive = false
			removed = true
		return
	_fall_speed = 0.0
	var ahead_x: float = position.x + dir * (HALF_WIDTH + 2.0)
	var col: int = floori(ahead_x / t)
	var wall: bool = level.is_solid(col, floori((position.y - 10.0) / t))
	var edge: bool = not level.is_floor(col, below)
	if wall or edge:
		dir = -dir
	else:
		position.x += dir * _speed * delta

func hit_box() -> Rect2:
	if spiky:
		return Rect2(position.x - 15.0, position.y - 28.0, 30.0, 28.0)
	return Rect2(position.x - 15.0, position.y - 24.0, 30.0, 24.0)

func color() -> Color:
	return Color("8a5cc7") if spiky else Color("d9534f")

func _draw() -> void:
	var s: Vector2 = death_scale()
	var a: float = death_alpha()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s.x * -dir, s.y))
	var bob: float = absf(sin(_anim * 9.0)) * 1.5 if alive else 0.0
	if spiky:
		_draw_hedgehog(bob, a)
	else:
		_draw_beetle(bob, a)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Facing right in local space (the transform mirrors it).
func _draw_beetle(bob: float, a: float) -> void:
	var outline := Color(0.18, 0.06, 0.06, a)
	for i in 3:
		var lx: float = -8.0 + i * 8.0
		var swing: float = sin(_anim * 14.0 + i * 2.0) * 3.0
		draw_line(Vector2(lx, -6.0), Vector2(lx + swing, 0.0), outline, 2.0)
	PlayerArt.ellipse(self, Vector2(0.0, -12.0 - bob), 16.0, 12.0, outline)
	PlayerArt.ellipse(self, Vector2(0.0, -12.5 - bob), 14.5, 10.5, Color(0.85, 0.3, 0.27, a))
	draw_line(Vector2(-2.0, -22.0 - bob), Vector2(-2.0, -3.0 - bob), Color(0.45, 0.1, 0.1, a), 1.5)
	PlayerArt.ellipse(self, Vector2(-7.0, -15.0 - bob), 2.6, 2.0, Color(0.15, 0.04, 0.04, a))
	PlayerArt.ellipse(self, Vector2(5.0, -9.0 - bob), 2.2, 1.8, Color(0.15, 0.04, 0.04, a))
	PlayerArt.ellipse(self, Vector2(-5.0, -18.0 - bob), 3.5, 1.6, Color(1.0, 0.75, 0.7, a * 0.6))
	PlayerArt.ellipse(self, Vector2(14.0, -9.0 - bob), 6.5, 6.0, outline)
	draw_circle(Vector2(16.0, -11.0 - bob), 2.4, Color(1.0, 1.0, 1.0, a))
	draw_circle(Vector2(16.8, -11.0 - bob), 1.2, Color(0.05, 0.05, 0.05, a))
	draw_line(Vector2(17.0, -14.0 - bob), Vector2(22.0, -19.0 - bob), outline, 1.5)

func _draw_hedgehog(bob: float, a: float) -> void:
	var spike_color := Color(0.33, 0.2, 0.5, a)
	var points := PackedVector2Array()
	var count: int = 9
	for i in count + 1:
		var ang: float = PI + PI * float(i) / float(count)
		var r: float = 20.0 if i % 2 == 0 else 12.0
		points.append(Vector2(cos(ang) * r - 2.0, sin(ang) * r * 0.95 - 6.0 - bob))
	points.append(Vector2(14.0, -6.0 - bob))
	draw_colored_polygon(points, spike_color)
	PlayerArt.ellipse(self, Vector2(-1.0, -10.0 - bob), 14.0, 10.0, Color(0.55, 0.36, 0.78, a))
	PlayerArt.ellipse(self, Vector2(10.0, -7.0 - bob), 7.5, 6.0, Color(0.93, 0.8, 0.66, a))
	draw_circle(Vector2(17.0, -7.5 - bob), 2.0, Color(0.15, 0.08, 0.1, a))
	draw_circle(Vector2(10.5, -10.0 - bob), 1.6, Color(0.1, 0.05, 0.1, a))
	for i in 2:
		var swing: float = sin(_anim * 12.0 + i * PI) * 3.0
		draw_line(Vector2(-6.0 + i * 10.0, -2.0), Vector2(-6.0 + i * 10.0 + swing, 0.0), Color(0.2, 0.1, 0.25, a), 3.0)

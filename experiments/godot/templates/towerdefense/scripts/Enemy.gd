# =============================================================================
# Enemy.gd (Node2D): follows the path, takes damage, draws itself.
# =============================================================================
# PATH FOLLOWING (distance-based):
#   The path is a polyline of global waypoints. Each frame the enemy has a
#   distance budget (speed x delta) that it spends segment by segment: if the
#   next waypoint is closer than the budget, it snaps to it, subtracts that
#   length and continues on the next segment. Compared to a "move toward the
#   waypoint, snap within 4 px" approach, this never overshoots or jitters,
#   whatever the speed, frame rate or game speed (x2).
#
# PROGRESS (for tower targeting):
#   _traveled accumulates the distance spent above: progress() is O(1).
#
# PREDICTION (for mortar shells):
#   predict_position(t) walks the remaining path by speed x t from the current
#   position. Unlike a straight-line lead (pos + velocity x t), it stays
#   correct around corners.
#
# ARMOR:
#   damage taken = max(1, damage - armor). Many small hits (Gatling) are
#   nearly useless against armor; one big hit (Railgun) barely notices it.
#   This single rule creates the tower / enemy counter-play.
#
# SIGNALS:
#   died():         killed by a tower
#   reached_exit(): got to the base (emitted AFTER lives are removed)
# =============================================================================

class_name Enemy
extends Node2D

signal died()
signal reached_exit()

var type_id:      String = ""
var hp:           int    = 0
var hp_max:       int    = 0
var speed:        float  = 0.0   # px/s
var reward:       int    = 0
var armor:        int    = 0
var lives_damage: int    = 0

var _shape:    String = "blob"
var _color:    Color  = Color.RED
var _radius:   float  = 0.0
var _path:     Array[Vector2] = []   # global positions
var _seg:      int    = 0            # moving from _path[_seg] to _path[_seg + 1]
var _traveled: float  = 0.0
var _dir:      Vector2 = Vector2.RIGHT
var _alive:    bool   = true
var _flash:    float  = 0.0          # hit flash, 1 -> 0
var _hp_trail: float  = 1.0          # delayed health ratio (white "damage" part)
var _spawn_t:  float  = 0.0          # 0 -> 1 spawn-in animation
var _time:     float  = 0.0

func setup(data: Dictionary, path: Array[Vector2], hp_mult: float, tile: float) -> void:
	type_id      = str(data.get("id", ""))
	hp_max       = maxi(1, int(round(float(data.get("hp", 1)) * hp_mult)))
	hp           = hp_max
	speed        = float(data.get("speed", 0.0)) * tile
	reward       = int(data.get("reward", 0))
	armor        = int(data.get("armor", 0))
	lives_damage = int(data.get("lives_damage", ConfigManager.get_int("enemy_reach_damage", 0)))
	_shape       = str(data.get("shape", "blob"))
	_color       = Color("#" + str(data.get("color", "ff5a5a")))
	_radius      = float(data.get("size", 0.25)) * tile
	_path        = path
	_time        = randf() * 10.0   # desynchronise the walk cycles
	if _path.size() > 1:
		global_position = _path[0]
		_dir = (_path[1] - _path[0]).normalized()
	Fx.ring(global_position, Color("c79bff"), _radius * 2.2, 0.35, 2.5)

func is_alive() -> bool:
	return _alive

func progress() -> float:
	return _traveled

## Global position after t seconds if the enemy keeps walking the path.
func predict_position(t: float) -> Vector2:
	var budget: float = speed * t
	var pos: Vector2 = global_position
	var i: int = _seg
	while budget > 0.0 and i < _path.size() - 1:
		var next: Vector2 = _path[i + 1]
		var d: float = pos.distance_to(next)
		if d >= budget:
			return pos + (next - pos) / d * budget
		budget -= d
		pos = next
		i += 1
	return pos

# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _alive:
		return
	_time    += delta
	_spawn_t  = minf(_spawn_t + delta * 4.0, 1.0)
	_flash    = maxf(_flash - delta * 12.0, 0.0)
	var ratio: float = float(hp) / float(hp_max)
	_hp_trail = move_toward(_hp_trail, ratio, delta * 0.9) if _hp_trail > ratio else ratio
	_advance(speed * delta)
	queue_redraw()

func _advance(distance: float) -> void:
	while distance > 0.0 and _seg < _path.size() - 1:
		var target: Vector2 = _path[_seg + 1]
		var d: float = global_position.distance_to(target)
		if d <= distance:
			global_position = target
			_traveled += d
			distance -= d
			_seg += 1
			if _seg < _path.size() - 1:
				_dir = (_path[_seg + 1] - _path[_seg]).normalized()
		else:
			global_position += (target - global_position) / d * distance
			_traveled += distance
			distance = 0.0
	if _seg >= _path.size() - 1:
		_reach_exit()

## Applies damage after armor. Returns the damage actually dealt.
func take_damage(amount: int) -> int:
	if not _alive:
		return 0
	var dealt: int = mini(maxi(1, amount - armor), hp)
	hp -= dealt
	# Flash strength follows the hit size: a Railgun shot flashes white, a
	# stream of Gatling bullets on a Brute only tints it (it stays readable).
	_flash = maxf(_flash, 0.45 + 0.55 * clampf(float(dealt) * 6.0 / float(hp_max), 0.0, 1.0))
	if armor > 0 and float(amount - armor) < float(amount) * 0.5:
		# Most of the hit bounced off: show it so the player learns the counter
		Fx.burst(global_position + Vector2(0, -_radius * 0.5), Color("d8dee9"), 3, 90.0, 1.8, 0.2)
		Sfx.play("clank", 0.1, -6.0)
	if hp <= 0:
		_die()
	return dealt

func _die() -> void:
	_alive = false
	GameState.register_kill(reward)
	Fx.burst(global_position, _color, 14, 170.0, 3.5, 0.55)
	Fx.burst(global_position, Color.WHITE, 6, 120.0, 2.0, 0.25)
	Fx.ring(global_position, _color.lightened(0.3), _radius * 2.4, 0.3, 3.0)
	Fx.text(global_position + Vector2(0, -_radius - 4.0), "+%d" % reward, Color("ffd34d"), 17, 0.8)
	Sfx.play("kill", 0.12, -2.0)
	if armor > 0:
		ShakeCamera.add_trauma(0.15)
	died.emit()
	queue_free()

func _reach_exit() -> void:
	if not _alive:
		return
	_alive = false
	GameState.enemy_reached_exit(lives_damage)   # lives first (see GameState)
	Fx.burst(global_position, Color("ff4d5e"), 18, 200.0, 4.0, 0.6)
	Fx.text(global_position + Vector2(0, -24), "-%d" % lives_damage, Color("ff6b78"), 22, 1.0)
	ShakeCamera.add_trauma(0.35 + 0.1 * lives_damage)
	Sfx.play("leak")
	reached_exit.emit()
	queue_free()

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _draw() -> void:
	if not _alive:
		return
	var grow: float = _spawn_t * (1.0 + 0.25 * sin(_spawn_t * PI))   # pop out of the portal
	draw_model(self, _shape, _color, _radius * grow, _dir, Vector2.ZERO, _flash, _time)
	if hp < hp_max:
		_draw_health_bar()

func _draw_health_bar() -> void:
	var w: float = maxf(_radius * 2.2, 26.0)
	var h: float = 5.0
	var origin := Vector2(-w * 0.5, -_radius - 13.0)
	var ratio: float = float(hp) / float(hp_max)
	var fill: Color = Color("5ee07a") if ratio > 0.5 else (Color("ffd34d") if ratio > 0.25 else Color("ff5a5a"))
	draw_rect(Rect2(origin - Vector2(1, 1), Vector2(w + 2, h + 2)), Color(0.05, 0.06, 0.09, 0.85))
	draw_rect(Rect2(origin, Vector2(w * _hp_trail, h)), Color(1, 1, 1, 0.85))
	draw_rect(Rect2(origin, Vector2(w * ratio, h)), fill)
	if armor > 0:
		# Small shield badge: this enemy is armored
		var c := origin + Vector2(-6, h * 0.5)
		var shield := PackedVector2Array([c + Vector2(-4, -4), c + Vector2(4, -4), c + Vector2(4, 0),
			c + Vector2(0, 5), c + Vector2(-4, 0)])
		draw_colored_polygon(shield, Color("d8dee9"))

## Draws an enemy body on any CanvasItem (enemy node or HUD icon).
## dir = facing direction, time drives the walk cycle.
static func draw_model(ci: CanvasItem, shape: String, col: Color, radius: float, dir: Vector2,
		center: Vector2, flash: float, time: float) -> void:
	if radius <= 0.5:
		return
	var body: Color = col.lerp(Color.WHITE, flash)
	var outline: Color = col.darkened(0.45).lerp(Color.WHITE, flash)
	var perp := Vector2(-dir.y, dir.x)
	# Ground shadow (does not bob)
	ci.draw_set_transform(center + Vector2(0, radius * 0.8), 0.0, Vector2(1.0, 0.4))
	ci.draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.28))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match shape:
		"dart":
			# Runner: arrow-head pointing forward, speed streaks behind
			var c := center + Vector2(0, -absf(sin(time * 14.0)) * 2.0)
			for i in 3:
				var off := perp * (float(i) - 1.0) * radius * 0.5
				ci.draw_line(c - dir * radius * (1.2 + i * 0.15) + off, c - dir * radius * 2.0 + off,
					Color(col, 0.35), 2.0, true)
			var pts := PackedVector2Array([c + dir * radius * 1.3, c - dir * radius * 0.9 + perp * radius,
				c - dir * radius * 0.4, c - dir * radius * 0.9 - perp * radius])
			ci.draw_colored_polygon(pts, body)
			var line := pts.duplicate()
			line.append(pts[0])
			ci.draw_polyline(line, outline, 2.0, true)
			ci.draw_circle(c + dir * radius * 0.35, radius * 0.28, Color.WHITE)
			ci.draw_circle(c + dir * radius * 0.45, radius * 0.14, Color("1b1b24"))
		"armored":
			# Brute: heavy rounded block with an armor band and a glowing visor
			var hop: float = absf(sin(time * 4.0)) * 1.5
			ci.draw_set_transform(center + Vector2(0, -hop), dir.angle(), Vector2.ONE)
			var s: float = radius
			ci.draw_rect(Rect2(-s, -s, s * 2.0, s * 2.0), outline)
			ci.draw_rect(Rect2(-s + 2.5, -s + 2.5, s * 2.0 - 5.0, s * 2.0 - 5.0), body)
			ci.draw_rect(Rect2(-s * 0.25, -s + 2.5, s * 0.5, s * 2.0 - 5.0), body.darkened(0.25))
			for y in [-0.6, 0.6]:
				ci.draw_circle(Vector2(-s * 0.62, s * float(y)), 2.0, body.lightened(0.35))
			ci.draw_rect(Rect2(s * 0.45, -s * 0.55, s * 0.3, s * 1.1), Color("ff6b4a").lerp(Color.WHITE, flash))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_:
			# Grunt: bouncy blob with eyes looking where it walks
			var bob: float = sin(time * 9.0)
			var c := center + Vector2(0, -absf(bob) * 3.0)
			ci.draw_set_transform(c, 0.0, Vector2(1.0 + bob * 0.07, 1.0 - bob * 0.07))
			ci.draw_circle(Vector2.ZERO, radius, outline)
			ci.draw_circle(Vector2.ZERO, radius - 2.0, body)
			ci.draw_circle(Vector2(-radius * 0.35, -radius * 0.4), radius * 0.25, body.lightened(0.3))
			for side in [-1.0, 1.0]:
				var eye: Vector2 = dir * radius * 0.35 + perp * radius * 0.38 * float(side)
				ci.draw_circle(eye, radius * 0.27, Color.WHITE)
				ci.draw_circle(eye + dir * radius * 0.1, radius * 0.13, Color("1b1b24"))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

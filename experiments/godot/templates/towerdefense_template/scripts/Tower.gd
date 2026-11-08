# =============================================================================
# Tower.gd (Node2D): targeting, aiming, firing, upgrades, self-drawing.
# =============================================================================
# TARGETING STRATEGIES (cycled by the player, per tower):
#   FIRST:  highest progress(), the enemy closest to the base (default)
#   LAST:   lowest progress(), picks off stragglers, spreads damage
#   STRONG: highest current HP, railguns on brutes
#   CLOSE:  smallest distance, keeps the turret on nearby threats
#   All four are one linear scan over the enemies in range, with a different
#   score. Distances are compared squared (no sqrt in the loop).
#
# AIMING:
#   The turret angle turns toward the target at TURN_SPEED rad/s with
#   rotate_toward(); bullet and beam towers only fire once the barrel is within
#   AIM_TOLERANCE of the target. Retargeting therefore costs a little time,
#   which makes the targeting choice matter and the motion readable.
#
# ATTACK TYPES (towers.json "attack"):
#   bullet: homing Projectile (Gatling)
#   beam:   instant hit, drawn as a fading tracer (Railgun)
#   shell:  ballistic Projectile aimed at the PREDICTED position of the
#            target (Enemy.predict_position), area damage on landing (Mortar)
#
# FIRE RATE: a _cooldown float counts down each frame (no Timer node per tower).
#
# UPGRADES: towers.json "upgrades" lists level 2 and 3 as partial overrides of
#   the base stats; stats_for(data, level) merges them. Sell value is based on
#   the total gold invested (build + upgrades) x sell_refund_ratio.
# =============================================================================

class_name Tower
extends Node2D

enum Target { FIRST, LAST, STRONG, CLOSE }

const TARGET_KEYS: Array[String] = ["target_first", "target_last", "target_strong", "target_close"]
const STAT_KEYS:   Array[String] = ["damage", "range", "fire_rate", "splash_radius", "projectile_speed"]
const TURN_SPEED:    float = 12.0
const AIM_TOLERANCE: float = 0.25

const COLOR_STONE       := Color("737d8c")
const COLOR_STONE_DARK  := Color("4b5361")
const COLOR_STONE_LIGHT := Color("8f99a8")
const COLOR_METAL       := Color("2b3342")
const COLOR_PIP         := Color("ffd34d")

var tower_id:            String = ""
var attack:              String = "bullet"
var level:               int    = 1
var damage:              int    = 0
var range_px:            float  = 0.0
var fire_rate:           float  = 0.0
var splash_px:           float  = 0.0
var projectile_speed_px: float  = 0.0
var invested:            int    = 0
var target_mode:         Target = Target.FIRST
var color:               Color  = Color.WHITE
var data:                Dictionary = {}

# Set by Main right after add_child()
var enemies_node:     Node2D = null
var projectiles_node: Node2D = null

var _tile:        float = 0.0
var _cooldown:    float = 0.0
var _angle:       float = -PI * 0.5
var _recoil:      float = 0.0
var _muzzle:      float = 0.0
var _pop:         float = 0.0
var _barrel_side: float = 1.0
var _selected:    bool  = false
var _time:        float = 0.0

# ---------------------------------------------------------------------------
# Data helpers (static: also used by the shop, the ghost and the HUD panel)
# ---------------------------------------------------------------------------

## Stats at a given level: base fields overridden by upgrades[0 .. level-2].
## Distances are returned in TILES, as stored in towers.json.
static func stats_for(d: Dictionary, lvl: int) -> Dictionary:
	var s: Dictionary = {}
	for k in STAT_KEYS:
		s[k] = float(d.get(k, 0.0))
	var ups: Array = d.get("upgrades", []) as Array
	for i in range(mini(lvl - 1, ups.size())):
		var u: Dictionary = ups[i] as Dictionary
		for k in STAT_KEYS:
			if u.has(k):
				s[k] = float(u[k])
	return s

static func max_level_for(d: Dictionary) -> int:
	return 1 + (d.get("upgrades", []) as Array).size()

## Cost to go from lvl to lvl + 1, or -1 at max level.
static func upgrade_cost_for(d: Dictionary, lvl: int) -> int:
	var ups: Array = d.get("upgrades", []) as Array
	if lvl - 1 >= ups.size():
		return -1
	return int((ups[lvl - 1] as Dictionary).get("cost", 0))

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func setup(d: Dictionary, tile: float) -> void:
	data     = d
	tower_id = str(d.get("id", ""))
	attack   = str(d.get("attack", "bullet"))
	color    = Color("#" + str(d.get("color", "4aa3ff")))
	_tile    = tile
	level    = 1
	invested = int(d.get("cost", 0))
	_apply_stats()
	_pop = 0.0
	Fx.burst(global_position + Vector2(0, tile * 0.25), Color("cbb48a"), 12, 110.0, 3.5, 0.45)
	Fx.ring(global_position, Color(1, 1, 1, 0.8), tile * 0.6, 0.3, 2.0)

func _apply_stats() -> void:
	var s: Dictionary = stats_for(data, level)
	damage    = int(s["damage"])
	range_px  = float(s["range"]) * _tile
	fire_rate = maxf(float(s["fire_rate"]), 0.01)
	splash_px = float(s["splash_radius"]) * _tile
	var speed: float = float(s["projectile_speed"])
	if speed <= 0.0:
		speed = ConfigManager.get_float("projectile_speed", 0.0)
	projectile_speed_px = speed * _tile

func max_level() -> int:
	return max_level_for(data)

func next_upgrade_cost() -> int:
	return upgrade_cost_for(data, level)

## Main checks and spends the gold before calling this.
func upgrade() -> void:
	var cost: int = next_upgrade_cost()
	if cost < 0:
		return
	level += 1
	invested += cost
	_apply_stats()
	_pop = 0.55   # re-trigger the pop animation from mid-way: a "bump"
	Fx.ring(global_position, color.lightened(0.4), _tile * 0.8, 0.45, 4.0)
	Fx.burst(global_position, COLOR_PIP, 16, 140.0, 3.0, 0.6)
	Fx.burst(global_position, color.lightened(0.3), 10, 90.0, 2.5, 0.5)

func sell_value() -> int:
	return int(invested * ConfigManager.get_float("sell_refund_ratio", 0.0))

func cycle_target() -> void:
	target_mode = ((int(target_mode) + 1) % TARGET_KEYS.size()) as Target

func target_key() -> String:
	return TARGET_KEYS[int(target_mode)]

func set_selected(sel: bool) -> void:
	_selected = sel

# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time    += delta
	_pop      = minf(_pop + delta * 3.0, 1.0)
	_recoil   = maxf(_recoil - delta * 7.0, 0.0)
	_muzzle   = maxf(_muzzle - delta * 12.0, 0.0)
	_cooldown = maxf(_cooldown - delta, 0.0)
	queue_redraw()
	if enemies_node == null:
		return

	var target: Enemy = _pick_target()
	if target == null:
		if attack != "shell":
			_angle = wrapf(_angle + delta * 0.35, -PI, PI)   # idle scan
		return
	var desired: float = (target.global_position - global_position).angle()
	_angle = rotate_toward(_angle, desired, TURN_SPEED * delta)
	var aimed: bool = absf(angle_difference(_angle, desired)) < AIM_TOLERANCE
	if _cooldown <= 0.0 and (aimed or attack == "shell"):
		_fire(target)
		_cooldown = 1.0 / fire_rate

func _pick_target() -> Enemy:
	var best: Enemy = null
	var best_score: float = -INF
	var range_sq: float = range_px * range_px
	for child in enemies_node.get_children():
		var e: Enemy = child as Enemy
		if e == null or not e.is_alive():
			continue
		var dist_sq: float = e.global_position.distance_squared_to(global_position)
		if dist_sq > range_sq:
			continue
		var score: float = 0.0
		match target_mode:
			Target.FIRST:  score = e.progress()
			Target.LAST:   score = -e.progress()
			Target.STRONG: score = float(e.hp) + e.progress() * 0.001   # tie-break: furthest
			Target.CLOSE:  score = -dist_sq
		if score > best_score:
			best_score = score
			best = e
	return best

func _barrel_length() -> float:
	match attack:
		"beam":  return _tile * 0.52
		"shell": return _tile * 0.3
	return _tile * 0.42

func _fire(target: Enemy) -> void:
	_recoil = 1.0
	_muzzle = 1.0
	var dir: Vector2 = Vector2.from_angle(_angle)
	var muzzle_pos: Vector2 = global_position + dir * _barrel_length()
	match attack:
		"beam":
			var hit_pos: Vector2 = target.global_position
			target.take_damage(damage)
			Fx.tracer(muzzle_pos, hit_pos, color.lightened(0.35), 5.0, 0.2)
			Fx.burst(hit_pos, color.lightened(0.5), 8, 160.0, 2.5, 0.3)
			Fx.burst(muzzle_pos, Color.WHITE, 4, 90.0, 2.0, 0.15)
			Sfx.play("rail")
			ShakeCamera.add_trauma(0.08)
		"shell":
			var dist: float = muzzle_pos.distance_to(target.global_position)
			var flight: float = clampf(dist / projectile_speed_px, 0.35, 1.0)
			var aim: Vector2 = target.predict_position(flight)
			var shell := Projectile.new()
			projectiles_node.add_child(shell)
			shell.setup_shell(muzzle_pos, aim, flight, damage, splash_px, color, enemies_node)
			Fx.burst(muzzle_pos, Color(0.85, 0.85, 0.85, 0.8), 6, 50.0, 5.0, 0.6)
			Sfx.play("mortar")
		_:
			_barrel_side = -_barrel_side
			var side: Vector2 = Vector2(-dir.y, dir.x) * 4.0 * _barrel_side
			var bullet := Projectile.new()
			projectiles_node.add_child(bullet)
			bullet.setup_bullet(muzzle_pos + side, target, damage, projectile_speed_px, color)
			Fx.burst(muzzle_pos + side, Color(1.0, 0.9, 0.5), 3, 70.0, 1.8, 0.12)
			Sfx.play("gun", 0.08, -3.0)

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _draw() -> void:
	var p: float = maxf(_ease_out_back(_pop), 0.05)
	draw_model(self, attack, color, _tile, _angle, _recoil, _muzzle, level, 1.0, Vector2.ZERO, p)
	if _selected:
		var h: float = _tile * 0.38 * p + 4.0
		var outline := _chamfer(Vector2.ZERO, h, h * 0.35)
		outline.append(outline[0])
		draw_polyline(outline, Color(1, 1, 1, 0.6 + 0.3 * sin(_time * 6.0)), 2.0, true)

static func _ease_out_back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)

static func _fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)

## Octagon (square with cut corners), half-size h, chamfer c.
static func _chamfer(center: Vector2, h: float, c: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-h + c, -h), center + Vector2(h - c, -h),
		center + Vector2(h, -h + c),  center + Vector2(h, h - c),
		center + Vector2(h - c, h),   center + Vector2(-h + c, h),
		center + Vector2(-h, h - c),  center + Vector2(-h, -h + c)])

## Draws a complete tower on any CanvasItem (tower node, ghost, shop icon).
static func draw_model(ci: CanvasItem, atk: String, col: Color, tile: float, angle: float,
		recoil: float, muzzle: float, lvl: int, alpha: float, center: Vector2,
		scale: float) -> void:
	var h: float = tile * 0.38 * scale
	# Ground shadow
	ci.draw_set_transform(center + Vector2(0, h * 0.6), 0.0, Vector2(1.0, 0.4))
	ci.draw_circle(Vector2.ZERO, h * 1.2, Color(0, 0, 0, 0.28 * alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Stone base: dark side for depth, top plate, inner plate tinted by type
	ci.draw_colored_polygon(_chamfer(center + Vector2(0, 4.0 * scale), h, h * 0.35), _fade(COLOR_STONE_DARK, alpha))
	ci.draw_colored_polygon(_chamfer(center, h, h * 0.35), _fade(COLOR_STONE, alpha))
	ci.draw_colored_polygon(_chamfer(center, h * 0.8, h * 0.28), _fade(COLOR_STONE_LIGHT.lerp(col, 0.18), alpha))
	# Level pips along the bottom edge
	for i in lvl:
		var x: float = (float(i) - float(lvl - 1) * 0.5) * 9.0 * scale
		var pip := center + Vector2(x, h - 5.0 * scale)
		ci.draw_circle(pip, 3.4 * scale, _fade(Color(0.1, 0.1, 0.12), alpha))
		ci.draw_circle(pip, 2.4 * scale, _fade(COLOR_PIP, alpha))
	# Turret, rotated, slightly bigger at each level
	var ts: float = scale * (1.0 + 0.07 * float(lvl - 1))
	ci.draw_set_transform(center, angle, Vector2(ts, ts))
	match atk:
		"beam":  _draw_railgun(ci, col, tile, recoil, muzzle, lvl, alpha)
		"shell": _draw_mortar(ci, col, tile, recoil, lvl, alpha)
		_:       _draw_gatling(ci, col, tile, recoil, muzzle, lvl, alpha)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _draw_gatling(ci: CanvasItem, col: Color, tile: float, recoil: float,
		muzzle: float, lvl: int, a: float) -> void:
	var r: float = tile * 0.2
	var back: float = -recoil * 5.0
	var length: float = tile * 0.36
	for side in [-1.0, 1.0]:
		var y: float = float(side) * 4.5
		ci.draw_rect(Rect2(back + r * 0.3, y - 2.5, length, 5.0), _fade(COLOR_METAL, a))
		ci.draw_rect(Rect2(back + r * 0.3 + length - 4.0, y - 3.0, 4.0, 6.0), _fade(COLOR_METAL.lightened(0.25), a))
		if muzzle > 0.0:
			ci.draw_circle(Vector2(back + r * 0.3 + length + 3.0, y), 5.0 * muzzle, Color(1.0, 0.9, 0.5, muzzle * a))
	ci.draw_circle(Vector2.ZERO, r, _fade(col.darkened(0.3), a))
	ci.draw_circle(Vector2.ZERO, r * 0.8, _fade(col, a))
	ci.draw_circle(Vector2(-r * 0.25, 0), r * 0.35, _fade(col.lightened(0.35), a))
	if lvl >= 3:
		ci.draw_arc(Vector2.ZERO, r + 1.5, 0.0, TAU, 24, _fade(COLOR_PIP, a), 2.0, true)

static func _draw_railgun(ci: CanvasItem, col: Color, tile: float, recoil: float,
		muzzle: float, lvl: int, a: float) -> void:
	var r: float = tile * 0.19
	var back: float = -recoil * 9.0
	var length: float = tile * 0.52
	ci.draw_rect(Rect2(back, -3.5, length, 7.0), _fade(COLOR_METAL, a))
	ci.draw_line(Vector2(back + 4.0, -3.5), Vector2(back + length, -3.5), _fade(col.lightened(0.3), a), 1.5)
	ci.draw_line(Vector2(back + 4.0, 3.5), Vector2(back + length, 3.5), _fade(col.lightened(0.3), a), 1.5)
	ci.draw_circle(Vector2(back + length, 0), 3.5 + muzzle * 5.0, Color(col.lightened(0.5), (0.7 + muzzle * 0.3) * a))
	var hex := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 6:
		var ang: float = i * PI / 3.0
		hex.append(Vector2.from_angle(ang) * r)
		inner.append(Vector2.from_angle(ang) * r * 0.72)
	ci.draw_colored_polygon(hex, _fade(col.darkened(0.3), a))
	ci.draw_colored_polygon(inner, _fade(col, a))
	ci.draw_circle(Vector2.ZERO, r * 0.3, _fade(col.lightened(0.6), a))
	if lvl >= 3:
		var ring := hex.duplicate()
		ring.append(hex[0])
		ci.draw_polyline(ring, _fade(COLOR_PIP, a), 2.0, true)

static func _draw_mortar(ci: CanvasItem, col: Color, tile: float, recoil: float,
		lvl: int, a: float) -> void:
	var r: float = tile * 0.25
	var back: float = -recoil * 4.0
	var length: float = tile * 0.22
	ci.draw_circle(Vector2.ZERO, r, _fade(col.darkened(0.3), a))
	ci.draw_circle(Vector2.ZERO, r * 0.86, _fade(col, a))
	for i in 4:
		ci.draw_circle(Vector2.from_angle(PI * 0.25 + i * PI * 0.5) * r * 0.66, 2.2, _fade(col.darkened(0.45), a))
	ci.draw_rect(Rect2(back + r * 0.1, -7.0, length, 14.0), _fade(COLOR_METAL, a))
	ci.draw_circle(Vector2(back + r * 0.1 + length, 0), 7.5, _fade(COLOR_METAL.lightened(0.2), a))
	ci.draw_circle(Vector2(back + r * 0.1 + length, 0), 5.0, _fade(Color("15181e"), a))
	if lvl >= 3:
		ci.draw_arc(Vector2.ZERO, r + 1.5, 0.0, TAU, 24, _fade(COLOR_PIP, a), 2.0, true)

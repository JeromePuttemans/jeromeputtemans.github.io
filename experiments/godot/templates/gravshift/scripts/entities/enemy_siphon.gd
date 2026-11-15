extends EnemyBase

# Siphon: an enemy gravity well. It keeps about 340 px from the ship and
# pulls the free orange pellets within pull_radius toward itself
# (bullet_field.gd, through game_manager.gravity_sinks()), absorbing those
# that touch it, up to store_max. It swells as it fills (up to +35 % of
# its radius). Every fire_interval s, if it holds at least 6 pellets, it
# spits them all at the ship in a fan. Destroyed, it bursts: every stored
# pellet plus 8 more fly out in a ring, a feast for the well.
# The race is for the bullets: catch them before it does.

var stored: int = 0
var _store_max: int = 24
var _base_radius: float = 22.0
var _swirl: float = 0.0
var burst_done: bool = false

func _ready() -> void:
	sides = 8
	_store_max = int(data.get("store_max", 24))
	_base_radius = radius

## Read by game_manager.gravity_sinks(): empty while full or outside.
func sink() -> Dictionary:
	if not entered or not alive or stored >= _store_max:
		return {}
	return {pos = position, radius = float(data.get("pull_radius", 170.0)), pull = 900.0, absorb = radius + 4.0, node = self}

func absorb(_at: Vector2) -> void:
	stored += 1
	_flash = maxf(_flash, 0.35)
	gm.call("sfx", "siphon_absorb", 1.0 + stored * 0.02, 0.0)

func _behave(delta: float) -> void:
	_swirl += delta * (2.0 + stored * 0.15)
	var to_ship: Vector2 = ship() - position
	var dist: float = maxf(to_ship.length(), 1.0)
	var dir: Vector2 = to_ship / dist
	var radial: float = clampf((dist - 340.0) / 100.0, -1.0, 1.0)
	var side: Vector2 = Vector2(-dir.y, dir.x) * (1.0 if uid % 2 == 0 else -1.0)
	steer((dir * radial + side * 0.4).normalized() * speed, 80.0, delta)
	radius = _base_radius * (1.0 + 0.35 * float(stored) / _store_max)
	if fire_ready(delta) and stored >= 6:
		var n: int = stored
		for k in n:
			var spread: float = lerpf(-0.55, 0.55, float(k) / maxf(n - 1, 1))
			shoot(dir.rotated(spread), false)
		stored = 0
		gm.call("sfx", "siphon_fire", 1.0, 0.05)

func burst() -> void:
	if burst_done:
		return
	burst_done = true
	var n: int = stored + 8
	var offset: float = randf() * TAU
	for k in n:
		shoot(Vector2.RIGHT.rotated(offset + TAU * k / n), false)
	stored = 0

func _shape(c: Color) -> void:
	var reach: float = float(data.get("pull_radius", 170.0))
	if entered and stored < _store_max:
		for k in 10:
			var a: float = -_swirl * 0.7 + TAU * k / 10.0
			draw_arc(Vector2.ZERO, reach, a, a + 0.1, 3, Color(c, 0.18), 1.5)
	draw_circle(Vector2.ZERO, radius, Color(0.02, 0.0, 0.07, 0.97).lerp(Color.WHITE, _flash * 0.5))
	for k in 3:
		var r: float = radius * (0.95 + k * 0.22)
		var start: float = _swirl * (1.0 + k * 0.4) + k * 2.0
		draw_arc(Vector2.ZERO, r, start, start + PI * 1.2, 24, Color(c, 0.85 - k * 0.22), 3.0 - k * 0.7)
	for k in mini(stored, _store_max):
		var a2: float = _swirl * 1.8 + TAU * k / maxf(stored, 1)
		draw_circle(Vector2.RIGHT.rotated(a2) * radius * 0.55, 2.2, Color(1.0, 0.6, 0.25))
	var warm: float = clampf((charge() - 0.8) / 0.2, 0.0, 1.0) if stored >= 6 else 0.0
	if warm > 0.0:
		Effects.put(self, Vector2.ZERO, radius * (1.2 + warm), Color(1.0, 0.5, 0.2, 0.5 * warm))

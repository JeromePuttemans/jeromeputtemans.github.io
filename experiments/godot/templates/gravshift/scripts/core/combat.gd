extends Node

# Combat: every collision, once per frame, as circle tests on squared
# distances.
#   shots -> enemies     a shot hitting a boss shield arc is stopped
#   orbit -> enemies     each orbiting bullet touching an enemy deals 1 and
#                        is used up (kept with the grinder upgrade)
#   enemy -> enemy       two enemies meeting faster than crash_speed both
#                        take crash_damage x relative speed / crash_speed:
#                        the well turns enemies into projectiles
#   bullets -> ship      the ship's small hitbox (player_radius)
#   enemy -> ship        contact damages the ship and the enemy

var gm: Node = null
var _g: Dictionary = {}

func setup(gameplay: Dictionary) -> void:
	_g = gameplay

func step(_delta: float) -> void:
	var enemies: Array = gm.call("live_enemies") as Array
	_shots_vs_enemies(enemies)
	_orbit_vs_enemies(enemies)
	_crashes(enemies)
	_ship_hits(enemies)

func _shots_vs_enemies(enemies: Array) -> void:
	var shots: Node = gm.call("shots_node") as Node
	var i: int = int(shots.call("count")) - 1
	while i >= 0:
		var p: Vector2 = shots.call("position_of", i) as Vector2
		var sling: bool = int(shots.call("kind_of", i)) == 1
		for e in enemies:
			var en: EnemyBase = e as EnemyBase
			if not en.alive or not en.entered or int(shots.call("last_hit", i)) == en.uid:
				continue
			if en.has_method("blocks_shot") and bool(en.call("blocks_shot", p)):
				gm.call("fx_burst", p, Color(0.6, 0.95, 1.0), 3, 120.0)
				shots.call("remove", i)
				break
			var r: float = en.radius + (6.0 if sling else 3.0)
			if p.distance_squared_to(en.position) < r * r:
				var damage: float = float(shots.call("damage_of", i))
				var used: bool = bool(shots.call("consume", i, en.uid))
				gm.call("enemy_hit", en, damage, sling, p)
				if used:
					shots.call("remove", i)
				break
		i -= 1

func _orbit_vs_enemies(enemies: Array) -> void:
	var well: GravityField = gm.call("well_node") as GravityField
	for contact in well.orbit_contacts(enemies):
		var en: EnemyBase = contact["enemy"] as EnemyBase
		var p: Vector2 = well.orbiter_position(int(contact["index"]))
		gm.call("enemy_hit", en, 1.0, true, p)
		if not well.grinder:
			well.remove_orbiter(int(contact["index"]))

func _crashes(enemies: Array) -> void:
	var threshold: float = float(_g.get("crash_speed", 150.0))
	for a in range(enemies.size()):
		var ea: EnemyBase = enemies[a] as EnemyBase
		if not ea.alive or not ea.entered:
			continue
		for b in range(a + 1, enemies.size()):
			var eb: EnemyBase = enemies[b] as EnemyBase
			if not eb.alive or not eb.entered:
				continue
			var d: Vector2 = eb.position - ea.position
			var min_d: float = ea.radius + eb.radius
			if d.length_squared() >= min_d * min_d:
				continue
			var dist: float = maxf(d.length(), 0.1)
			var n: Vector2 = d / dist
			var push: float = (min_d - dist) * 0.5
			ea.position -= n * push * (eb.mass / (ea.mass + eb.mass)) * 2.0
			eb.position += n * push * (ea.mass / (ea.mass + eb.mass)) * 2.0
			var rel: float = (ea.vel - eb.vel).dot(n)
			if rel > threshold:
				var damage: float = float(_g.get("crash_damage", 3.0)) * rel / threshold
				var bounce: Vector2 = n * rel * 0.6
				ea.vel -= bounce * (eb.mass / (ea.mass + eb.mass)) * 2.0
				eb.vel += bounce * (ea.mass / (ea.mass + eb.mass)) * 2.0
				gm.call("crash", ea, eb, damage, ea.position + n * ea.radius)

func _ship_hits(enemies: Array) -> void:
	var ship: Node2D = gm.call("ship_node") as Node2D
	if not bool(ship.get("alive")):
		return
	var core: Vector2 = ship.position
	var r: float = float(ship.get("radius"))
	var safe: bool = float(ship.get("invulnerable")) > 0.0
	var bullets: Node = gm.call("bullets_node") as Node
	if not safe and bool(bullets.call("check_player", core, r)):
		gm.call("ship_hit")
		return
	for e in enemies:
		var en: EnemyBase = e as EnemyBase
		if not en.alive or not en.entered:
			continue
		var rr: float = en.radius * 0.8 + r
		if core.distance_squared_to(en.position) < rr * rr:
			if not safe:
				gm.call("ship_hit")
				if not en.boss:
					gm.call("enemy_hit", en, 3.0, false, core)
			return

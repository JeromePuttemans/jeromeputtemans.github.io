# =============================================================================
# LevelCheck.gd: Geometric checks of the archipelago (no rendering)
# =============================================================================
# Run: godot --headless --path . -- --check
# PASSAGES: for every passage of the solution, the hours (to the minute) at
#   which the shadow connects its two platforms, the shadow eroded by
#   0.4 m so that a body fits on it. A hanging shadow must also come within
#   reach of the block it is climbed from. On a kinetic stone, riders are
#   simulated: points boarded on the first platform are carried with the
#   stone exactly as the player is (same formula as ShadowSystem.carry)
#   and must reach the second platform.
# SHORTCUTS: every standable surface (platforms, blocks, plinths, low
#   stones) against every other platform: the horizontal gap is compared
#   with the reach of the body (run, coyote time, jump, air dash, ledge
#   grab), simulated with the values of config.json. A reachable pair that
#   the design does not allow is reported: it would skip a shadow.
# =============================================================================

class_name LevelCheck
extends RefCounted

const ALLOWED: Array = [["cadran", "gue"], ["gue", "belv"], ["belv", "cadran"], ["e2", "e1"]]

static func run(world: World, shadows: ShadowSystem) -> int:
	var problems: int = 0
	print("=== Passages (heures où l'ombre relie les deux plateformes) ===")
	problems += _static_passage(world, shadows, "Seuil > Cadran", "seuil_mur", "seuil", "cadran")
	problems += _static_passage(world, shadows, "Seuil > Marche", "seuil_mur", "seuil", "e1")
	problems += _static_passage(world, shadows, "Cadran > Dalle", "cad_ouest", "cadran", "w1")
	problems += _static_passage(world, shadows, "Dalle > Repit", "w1_dalle", "w1", "rest")
	problems += _static_passage(world, shadows, "Dalle > Cap", "w1_dalle", "w1", "w2")
	problems += _hanging_passage(world, shadows, "Marche > Tour (ombre suspendue)", "e2_tour", "e2")
	problems += _rider_passage(world, shadows, "Tour > Vigie (fleche)", "fleche", "e2", "e3")
	problems += _rider_passage(world, shadows, "Belvedere > Zenith (bac)", "bac", "belv", "n2")
	var gnomon: ShadowSystem.Caster = shadows.find("gnomon")
	var low: float = gnomon.size.y
	shadows.set_height("gnomon", 40.0)
	problems += _static_passage(world, shadows, "Cadran > Oculus (gnomon leve)", "gnomon", "cadran", "obs")
	shadows.set_height("gnomon", low)
	print("=== Ombres a heure precise (eclats) ===")
	_shard_windows(world, shadows)
	print("  (gnomon leve)")
	shadows.set_height("gnomon", 40.0)
	_shard_windows(world, shadows)
	shadows.set_height("gnomon", low)
	print("=== Portee du corps ===")
	for dy in [-4.0, -2.0, 0.0, 0.8, 1.2, 2.0, 2.2, 2.5, 3.0]:
		print("  denivele %+.1f m : %.1f m" % [dy, reach(dy)])
	print("=== Raccourcis ===")
	problems += _shortcuts(world, shadows)
	print("=== %d probleme(s) ===" % problems)
	return problems

# --- passages ----------------------------------------------------------------------

static func _eroded(poly: PackedVector2Array, margin: float) -> PackedVector2Array:
	if poly.size() < 3:
		return PackedVector2Array()
	var out: Array[PackedVector2Array] = Geometry2D.offset_polygon(poly, -margin)
	var best := PackedVector2Array()
	for p in out:
		if p.size() > best.size():
			best = p
	return best

static func _overlap(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if a.size() < 3 or b.size() < 3:
		return 0.0
	var area: float = 0.0
	for p in Geometry2D.intersect_polygons(a, b):
		area += absf(_area(p))
	return area

static func _area(p: PackedVector2Array) -> float:
	var s: float = 0.0
	for i in p.size():
		s += p[i].cross(p[(i + 1) % p.size()])
	return s * 0.5

static func _hour_text(h: float) -> String:
	var m: int = int(round(h * 60.0))
	return "%dh%02d" % [floori(m / 60.0), m % 60]

static func _windows(ok: Array[bool], step: float) -> String:
	var parts: Array[String] = []
	var start: int = -1
	for i in ok.size() + 1:
		var on: bool = i < ok.size() and ok[i]
		if on and start < 0:
			start = i
		elif not on and start >= 0:
			parts.append("%s-%s" % [_hour_text(7.0 + start * step), _hour_text(7.0 + (i - 1) * step)])
			start = -1
	return ", ".join(parts) if not parts.is_empty() else "JAMAIS"

static func _static_passage(world: World, shadows: ShadowSystem, label: String, caster_id: String, from_id: String, to_id: String) -> int:
	var c: ShadowSystem.Caster = shadows.find(caster_id)
	var a: PackedVector2Array = World.outline(world.island(from_id))
	var b: PackedVector2Array = World.outline(world.island(to_id))
	var ok: Array[bool] = []
	var max_elevation: float = ConfigManager.get_float("sun_max_elevation_deg", 65.0)
	for i in 601:
		var h: float = 7.0 + i / 60.0
		var poly: PackedVector2Array = _eroded(shadows.shadow_polygon(c, Sun.direction_for(h, max_elevation)), 0.4)
		ok.append(_overlap(poly, a) > 0.3 and _overlap(poly, b) > 0.3)
	var text: String = _windows(ok, 1.0 / 60.0)
	print("  %-34s %s" % [label, text])
	return 1 if text == "JAMAIS" else 0

static func _hanging_passage(world: World, shadows: ShadowSystem, label: String, caster_id: String, to_id: String) -> int:
	var c: ShadowSystem.Caster = shadows.find(caster_id)
	var b: PackedVector2Array = World.outline(world.island(to_id))
	var block: Dictionary = {}
	var top: float = -INF
	for entry in world.data.get("blocks", []) as Array:
		var candidate: Dictionary = entry as Dictionary
		var candidate_top: float = float(candidate.get("y", world.ground_y(float(candidate["x"]), float(candidate["z"])))) + float(candidate["h"])
		if candidate_top > top:
			top = candidate_top
			block = candidate
	var bx: float = float(block["x"])
	var bz: float = float(block["z"])
	var hw: float = float(block["w"]) * 0.5
	var hd: float = float(block["d"]) * 0.5
	var block_poly := PackedVector2Array([Vector2(bx - hw, bz - hd), Vector2(bx + hw, bz - hd), Vector2(bx + hw, bz + hd), Vector2(bx - hw, bz + hd)])
	var dy: float = c.plane - top
	var grab: float = reach(dy, true)
	var ok: Array[bool] = []
	var comfy: Array[bool] = []
	var max_elevation: float = ConfigManager.get_float("sun_max_elevation_deg", 65.0)
	for i in 601:
		var h: float = 7.0 + i / 60.0
		var poly: PackedVector2Array = _eroded(shadows.shadow_polygon(c, Sun.direction_for(h, max_elevation)), 0.4)
		var gap: float = _distance(poly, block_poly) if poly.size() >= 3 else INF
		var linked: bool = _overlap(poly, b) > 0.3
		ok.append(linked and gap <= grab)
		comfy.append(linked and gap <= 1.5)
	var text: String = _windows(ok, 1.0 / 60.0)
	print("  %-34s %s   (bloc %.1f m, ombre a %.1f m, prise a %.1f m)" % [label, text, top, c.plane, grab])
	print("  %-34s %s   (bord de l'ombre a moins de 1,5 m du bloc)" % ["  dont confortable", _windows(comfy, 1.0 / 60.0)])
	return 1 if text == "JAMAIS" else 0

## Riders boarded on `from_id` and carried with a kinetic stone.
static func _rider_passage(world: World, shadows: ShadowSystem, label: String, caster_id: String, from_id: String, to_id: String) -> int:
	var src: ShadowSystem.Caster = shadows.find(caster_id)
	var from_def: Dictionary = world.island(from_id)
	var to_def: Dictionary = world.island(to_id)
	var max_elevation: float = ConfigManager.get_float("sun_max_elevation_deg", 65.0)
	var cycle: float = src.period if src.motion == "slide" else TAU / maxf(absf(src.spin_speed), 0.01)
	var c := ShadowSystem.Caster.new()
	c.size = src.size
	c.plane = src.plane
	c.motion = src.motion
	c.pivot = src.pivot
	c.arm = src.arm
	c.spin_speed = src.spin_speed
	c.phase = src.phase
	c.slide_to = src.slide_to
	c.period = src.period
	c.pause = src.pause
	var ok: Array[bool] = []
	var step: float = 0.25
	var dt: float = 0.1
	var hours: int = int(10.0 / step) + 1
	for i in hours:
		var h: float = 7.0 + i * step
		var sun: Vector3 = Sun.direction_for(h, max_elevation)
		var success: bool = false
		var boards: int = 24
		for k in boards:
			if success:
				break
			var t0: float = cycle * k / boards
			shadows._animate(c, t0)
			var poly: PackedVector2Array = _eroded(ShadowSystem.polygon_for(c.foot, c.yaw, c.size, c.plane, sun), 0.35)
			for p in _sample_points(poly, from_def):
				var feet := Vector3(p.x, c.plane, p.y)
				var t: float = t0
				var prev_foot: Vector3 = c.foot
				var prev_yaw: float = c.yaw
				var left: bool = false
				while t < t0 + cycle:
					t += dt
					shadows._animate(c, t)
					var hit: Variant = ShadowSystem._ray_box(prev_foot, prev_yaw, c.size, Vector3(feet.x, c.plane, feet.z), sun)
					if hit == null:
						break
					var local: Vector3 = Basis(Vector3.UP, -prev_yaw) * ((hit as Vector3) - prev_foot)
					var q: Vector3 = c.foot + Basis(Vector3.UP, c.yaw) * local
					var kk: float = (q.y - c.plane) / sun.y
					feet = Vector3(q.x - sun.x * kk, c.plane, q.z - sun.z * kk)
					prev_foot = c.foot
					prev_yaw = c.yaw
					if not World.contains(from_def, feet.x, feet.z, 0.0):
						left = true
					if left and World.contains(to_def, feet.x, feet.z, -0.4):
						success = true
						break
				if success:
					break
		ok.append(success)
	var text: String = _windows(ok, step)
	print("  %-34s %s   (pas de %d min, tour de %.1f s)" % [label, text, int(step * 60.0), cycle])
	return 1 if text == "JAMAIS" else 0

## A few points of the shadow lying on the platform, 0.4 m inside it.
static func _sample_points(poly: PackedVector2Array, def: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if poly.size() < 3:
		return out
	var inter: Array[PackedVector2Array] = Geometry2D.intersect_polygons(poly, _eroded(World.outline(def), 0.4))
	for p in inter:
		var centre := Vector2.ZERO
		for v in p:
			centre += v
		centre /= p.size()
		out.append(centre)
		for v in p:
			out.append(centre.lerp(v, 0.6))
	return out

static func _shard_windows(world: World, shadows: ShadowSystem) -> void:
	var max_elevation: float = ConfigManager.get_float("sun_max_elevation_deg", 65.0)
	var list: Array = world.data.get("shards", []) as Array
	for i in list.size():
		var p: Array = list[i] as Array
		var pos := Vector2(float(p[0]), float(p[2]))
		var feet_y: float = float(p[1]) - 1.0
		var over_island: bool = false
		for id in world.islands:
			if World.contains(world.islands[id] as Dictionary, pos.x, pos.y, 0.0) and absf(float((world.islands[id] as Dictionary)["y"]) - feet_y) < 1.6:
				over_island = true
		if over_island:
			continue
		var ok: Array[bool] = []
		var found: String = ""
		for c in shadows.casters:
			if c.motion != "" or absf(c.plane - feet_y) > 1.5:
				continue
			ok.clear()
			var any: bool = false
			for m in 601:
				var h: float = 7.0 + m / 60.0
				var poly: PackedVector2Array = _eroded(shadows.shadow_polygon(c, Sun.direction_for(h, max_elevation)), 0.3)
				var inside: bool = poly.size() >= 3 and Geometry2D.is_point_in_polygon(pos, poly)
				ok.append(inside)
				any = any or inside
			if any:
				found += "%s %s  " % [c.id, _windows(ok, 1.0 / 60.0)]
		print("  eclat %2d (%.1f, %.1f) au-dessus du vide : %s" % [i, pos.x, pos.y, found if found != "" else "pierre cinetique ou gnomon leve"])

# --- reach of the body ---------------------------------------------------------------

## Farthest horizontal gap the body can cross to land `dy` metres higher
## (negative: lower), or to grab a ledge there (grab_only).
static func reach(dy: float, grab_only: bool = false) -> float:
	var g: float = ConfigManager.get_float("gravity", 22.0)
	var fall_mult: float = ConfigManager.get_float("fall_gravity_mult", 1.25)
	var jump: float = ConfigManager.get_float("jump_velocity", 7.8)
	var sprint: float = ConfigManager.get_float("sprint_speed", 8.5)
	var dash_speed: float = ConfigManager.get_float("dash_speed", 17.0)
	var dash_time: float = ConfigManager.get_float("dash_time", 0.15)
	var dash_exit: float = ConfigManager.get_float("dash_exit_speed", 9.5)
	var drag: float = ConfigManager.get_float("air_drag", 4.0)
	var coyote: float = ConfigManager.get_float("coyote_time", 0.12)
	var grab: float = ConfigManager.get_float("mantle_reach", 1.1)
	var dt: float = 1.0 / 240.0
	var best: float = 0.0
	for dash_step in range(-1, 70):
		var x: float = coyote * dash_exit
		var y: float = -0.5 * g * fall_mult * coyote * coyote
		var vx: float = dash_exit
		var vy: float = jump
		var t: float = 0.0
		var dashed: bool = false
		var dash_left: float = 0.0
		var land_x: float = -1.0
		var grab_x: float = -1.0
		while t < 3.0 and y > minf(dy, 0.0) - 4.0:
			if dash_step >= 0 and not dashed and t >= dash_step * 0.02:
				dashed = true
				dash_left = dash_time
			if dash_left > 0.0:
				vx = dash_speed
				vy = 0.0
				dash_left -= dt
				if dash_left <= 0.0:
					vx = dash_exit
			else:
				vy -= g * (fall_mult if vy < 0.0 else 1.0) * dt
				if vx > sprint:
					vx = maxf(vx - drag * dt, sprint)
			x += vx * dt
			y += vy * dt
			t += dt
			if y >= dy and vy <= 0.0:
				land_x = x
			if y >= dy - grab and y <= dy - 0.3:
				grab_x = x + 0.8
		var r: float = grab_x if grab_only else maxf(land_x + 0.3 if land_x >= 0.0 else -1.0, grab_x)
		best = maxf(best, r)
	return best

# --- shortcuts -------------------------------------------------------------------------

static func _rect_poly(x: float, z: float, w: float, d: float, yaw: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var basis := Basis(Vector3.UP, yaw)
	for corner in [Vector3(-w, 0, -d), Vector3(w, 0, -d), Vector3(w, 0, d), Vector3(-w, 0, d)]:
		var p: Vector3 = basis * (corner * 0.5)
		out.append(Vector2(x + p.x, z + p.z))
	return out

static func _distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if _overlap(a, b) > 0.0001:
		return 0.0
	var best: float = INF
	for pass_index in 2:
		var p: PackedVector2Array = a if pass_index == 0 else b
		var q: PackedVector2Array = b if pass_index == 0 else a
		for v in p:
			for i in q.size():
				var c: Vector2 = Geometry2D.get_closest_point_to_segment(v, q[i], q[(i + 1) % q.size()])
				best = minf(best, v.distance_to(c))
	return best

static func _island_of(world: World, x: float, z: float, y: float) -> String:
	for id in world.islands:
		var d: Dictionary = world.islands[id]
		if World.contains(d, x, z, 0.3) and y >= float(d["y"]) - 0.1:
			return str(id)
	return ""

static func _shortcuts(world: World, shadows: ShadowSystem) -> int:
	var surfaces: Array[Dictionary] = []
	for id in world.islands:
		var d: Dictionary = world.islands[id]
		surfaces.append({name = "plateforme " + str(id), island = str(id), poly = World.outline(d), top = float(d["y"])})
	for b in world.data.get("blocks", []) as Array:
		var block: Dictionary = b as Dictionary
		var x: float = float(block["x"])
		var z: float = float(block["z"])
		var base: float = float(block.get("y", world.ground_y(x, z)))
		surfaces.append({name = "bloc", island = _island_of(world, x, z, base), poly = _rect_poly(x, z, float(block["w"]), float(block["d"]), 0.0), top = base + float(block["h"])})
	for c in shadows.casters:
		if c.motion != "":
			continue
		surfaces.append({name = "pierre " + c.id, island = _island_of(world, c.foot.x, c.foot.z, c.foot.y), poly = _rect_poly(c.foot.x, c.foot.z, c.size.x, c.size.z, c.yaw), top = c.foot.y + c.size.y})
	for s in world.data.get("seals", []) as Array:
		var seal: Dictionary = s as Dictionary
		var x: float = float(seal["x"])
		var z: float = float(seal["z"])
		surfaces.append({name = "socle " + str(seal["id"]), island = str(seal["island"]), poly = _rect_poly(x, z, 0.9, 0.9, 0.0), top = world.ground_y(x, z) + 0.9})
	for p in world.data.get("props", []) as Array:
		var prop: Dictionary = p as Dictionary
		if str(prop["type"]) != "bench":
			continue
		var x: float = float(prop["x"])
		var z: float = float(prop["z"])
		surfaces.append({name = "banc", island = _island_of(world, x, z, world.ground_y(x, z)), poly = _rect_poly(x, z, float(prop.get("w", 2.4)), 0.55, deg_to_rad(float(prop.get("yaw", 0.0)))), top = world.ground_y(x, z) + 0.45})
	var problems: int = 0
	var reach_ground: float = ConfigManager.get_float("jump_velocity", 7.8)
	reach_ground = reach_ground * reach_ground / (2.0 * ConfigManager.get_float("gravity", 22.0)) + ConfigManager.get_float("mantle_reach", 1.1)
	for s in surfaces:
		var from_island: String = str(s["island"])
		var top: float = float(s["top"])
		if top - float(world.island(from_island).get("y", 0.0)) > reach_ground + 0.01 and not str(s["name"]).begins_with("plateforme"):
			continue
		for id in world.islands:
			if str(id) == from_island:
				continue
			var allowed: bool = false
			for pair in ALLOWED:
				if (pair[0] == from_island and pair[1] == id) or (pair[1] == from_island and pair[0] == id):
					allowed = true
			if allowed:
				continue
			var d: Dictionary = world.islands[id]
			var gap: float = _distance(s["poly"] as PackedVector2Array, World.outline(d))
			var dy: float = float(d["y"]) - top
			var r: float = reach(dy)
			var margin: float = gap - r
			if margin < 1.5:
				var verdict: String = "RACCOURCI" if margin <= 0.0 else "juste"
				print("  %-9s %s (%.1f m) > %s : ecart %.1f m, denivele %+.1f m, portee %.1f m" % [verdict, s["name"], top, id, gap, dy, r])
				if margin <= 0.0:
					problems += 1
	return problems

extends RefCounted

# Upgrades offered between sectors (three drawn at random from
# settings.json "upgrades", never one already at its maximum level).
#   orbit     +6 orbit capacity                 (max 3 levels)
#   horizon   +20 % capture and pull radius      (max 3)
#   sling     +40 % sling damage                 (max 3)
#   tank      +30 flux, +25 % regeneration       (max 3)
#   twin      +1 auto-fire bolt, +15 % fire rate (max 3)
#   hull      +1 maximum hull, repairs 1         (max 3)
#   shrapnel  slings burst on impact             (max 1)
#   pierce    slings go through one more enemy   (max 2)
#   grinder   orbiting bullets are not used up   (max 1)
#   recoil    release shockwave +60 % and stuns  (max 1)

const MAX_LEVEL: Dictionary = {orbit = 3, horizon = 3, sling = 3, tank = 3, twin = 3, hull = 3, shrapnel = 1, pierce = 2, grinder = 1, recoil = 1}

static func offer(pool: Array, levels: Dictionary, count: int) -> Array[String]:
	var open: Array[String] = []
	for id in pool:
		var key: String = str(id)
		if int(levels.get(key, 0)) < int(MAX_LEVEL.get(key, 1)):
			open.append(key)
	open.shuffle()
	var out: Array[String] = []
	for i in mini(count, open.size()):
		out.append(open[i])
	return out

static func apply(id: String, well: GravityField, ship: Node, levels: Dictionary) -> void:
	levels[id] = int(levels.get(id, 0)) + 1
	match id:
		"orbit":
			well.capacity += 6
		"horizon":
			well.horizon += 0.2
		"sling":
			well.sling_mult += 0.4
		"tank":
			well.flux_max += 30.0
			well.flux = well.flux_max
			well.regen_mult += 0.25
		"twin":
			ship.set("twin", int(ship.get("twin")) + 1)
			ship.set("fire_rate", float(ship.get("fire_rate")) * 1.15)
		"hull":
			ship.set("hp_max", int(ship.get("hp_max")) + 1)
			ship.set("hp", mini(int(ship.get("hp")) + 1, int(ship.get("hp_max"))))
		"shrapnel":
			well.shrapnel = true
		"pierce":
			well.pierce += 1
		"grinder":
			well.grinder = true
		"recoil":
			well.recoil = 1.6

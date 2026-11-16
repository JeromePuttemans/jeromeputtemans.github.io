# =============================================================================
# DungeonGenerator.gd: procedural floor generation (pure static functions).
# =============================================================================
# ALGORITHM: random room placement + L-shaped corridors + a few loops.
#
# 1. Fill the grid with WALL.
# 2. Try to place up to `max_rooms` random rectangles (max_rooms x 4
#    attempts). A room overlapping an existing one (1-tile buffer) is
#    rejected.
# 3. Connect each new room to the previous one with an L-shaped corridor,
#    horizontal-first or vertical-first at random: every room is reachable.
# 4. Add `extra_corridors` corridors between random room pairs. They create
#    loops: the player can circle around a troll instead of being cornered
#    in a dead end, which makes fights more tactical.
# 5. Player start = center of rooms[0]. The stairs go to the room whose
#    center is the FURTHEST walking distance from the start (BFS with
#    DijkstraMap), so each floor has to be crossed. Placement order alone
#    would sometimes put the stairs next door.
# 6. Enemies: per room (except the start room), a random count plus a bonus
#    that grows with depth, each type drawn from the depth-aware spawn table.
#    No enemy within `enemy_safe_radius` of the start, never two on the same
#    cell. On the last floor the boss stands next to the exit.
# 7. The key: on every floor but the last, a key thief starts in a room far
#    from the start (at least 40 % of the longest walk away) that is not the
#    stairs room. On the last floor the Warden carries the key of the portal.
# 8. Items: a few per floor on free cells; the first one is always a healing
#    potion, so every floor offers at least one way to recover.
# 9. Scenery with a use: barrels against room walls (they block the way and
#    may hold something; keg_chance of them are powder kegs that explode),
#    torches on the top walls of most rooms and candles in room corners
#    (light), a glowing rune on most floors (coloured light), banners on
#    some walls, bones and rubble (looks only). A barrel is kept only if
#    every floor cell stays reachable without breaking it.
#
# The generator is pure: it receives the config, the floor number, a seeded
# RandomNumberGenerator and two pickers (Callables), and returns a
# DungeonData. Same seed, same floor, which makes bugs reproducible.
# =============================================================================

class_name DungeonGenerator
extends RefCounted

## enemy_picker(floor: int, rng) -> String  enemy type id ("" = none)
## item_picker(floor: int, rng) -> String   item id ("" = none)
static func generate(cfg: Dictionary, floor_number: int, total_floors: int,
		rng: RandomNumberGenerator, enemy_picker: Callable, item_picker: Callable,
		boss_id: String) -> DungeonData:
	var w: int = int(cfg.get("dungeon_width", 50))
	var h: int = int(cfg.get("dungeon_height", 30))
	var data := DungeonData.new(w, h)
	data.floor_number = floor_number
	data.is_last_floor = floor_number >= total_floors

	_place_rooms(data, cfg, rng)
	if data.rooms.is_empty():
		push_error("DungeonGenerator: failed to place any room.")
		return data
	_add_loops(data, int(cfg.get("extra_corridors", 0)), rng)

	data.player_start = _room_center(data.rooms[0])
	data.stairs_pos = _furthest_room_center(data)
	data.set_tile(data.stairs_pos, DungeonData.TileType.STAIRS_DOWN)

	var occupied: Dictionary = {data.player_start: true, data.stairs_pos: true}
	_spawn_enemies(data, cfg, rng, enemy_picker, occupied)
	if data.is_last_floor and not boss_id.is_empty():
		_spawn_boss(data, boss_id, occupied)
	elif not data.is_last_floor:
		_spawn_thief(data, rng, occupied)
	_spawn_items(data, cfg, rng, item_picker, occupied)
	_place_barrels(data, cfg, rng, occupied)
	_place_torches(data, cfg, rng)
	_place_banners(data, cfg, rng)
	_place_lights(data, cfg, rng, occupied)
	_place_decor(data, rng, occupied)
	return data

# =============================================================================
# ROOMS AND CORRIDORS
# =============================================================================

static func _place_rooms(data: DungeonData, cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	var max_rooms: int = int(cfg.get("max_rooms", 12))
	var room_min: int = int(cfg.get("room_min_size", 4))
	var room_max: int = int(cfg.get("room_max_size", 10))
	for _attempt in max_rooms * 4:
		if data.rooms.size() >= max_rooms:
			break
		var rw: int = rng.randi_range(room_min, room_max)
		var rh: int = rng.randi_range(room_min, mini(room_max, data.height - 4))
		var rx: int = rng.randi_range(1, data.width - rw - 2)
		var ry: int = rng.randi_range(1, data.height - rh - 2)
		var room := Rect2i(rx, ry, rw, rh)
		var overlaps: bool = false
		for existing in data.rooms:
			if room.intersects(existing.grow(1)):   # 1-tile buffer
				overlaps = true
				break
		if overlaps:
			continue
		_carve_room(data, room)
		if not data.rooms.is_empty():
			_connect_rooms(data, data.rooms[data.rooms.size() - 1], room, rng)
		data.rooms.append(room)

static func _add_loops(data: DungeonData, count: int, rng: RandomNumberGenerator) -> void:
	if data.rooms.size() < 3:
		return
	for _i in count:
		var a: int = rng.randi_range(0, data.rooms.size() - 1)
		var b: int = rng.randi_range(0, data.rooms.size() - 1)
		if absi(a - b) > 1:   # adjacent rooms are already connected
			_connect_rooms(data, data.rooms[a], data.rooms[b], rng)

static func _carve_room(data: DungeonData, room: Rect2i) -> void:
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)

static func _connect_rooms(data: DungeonData, a: Rect2i, b: Rect2i, rng: RandomNumberGenerator) -> void:
	var ca: Vector2i = _room_center(a)
	var cb: Vector2i = _room_center(b)
	if rng.randf() < 0.5:
		_carve_h(data, ca.x, cb.x, ca.y)
		_carve_v(data, ca.y, cb.y, cb.x)
	else:
		_carve_v(data, ca.y, cb.y, ca.x)
		_carve_h(data, ca.x, cb.x, cb.y)

static func _carve_h(data: DungeonData, x1: int, x2: int, y: int) -> void:
	for x in range(mini(x1, x2), maxi(x1, x2) + 1):
		data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)

static func _carve_v(data: DungeonData, y1: int, y2: int, x: int) -> void:
	for y in range(mini(y1, y2), maxi(y1, y2) + 1):
		data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)

static func _room_center(room: Rect2i) -> Vector2i:
	return room.position + room.size / 2

## Center of the room with the longest walking distance from the start.
static func _furthest_room_center(data: DungeonData) -> Vector2i:
	var dmap: DijkstraMap = DijkstraMap.compute(data, data.player_start, 1 << 20)
	var best: Vector2i = _room_center(data.rooms[data.rooms.size() - 1])
	var best_d: int = -1
	for i in range(1, data.rooms.size()):
		var c: Vector2i = _room_center(data.rooms[i])
		var d: int = dmap.get_dist(c)
		if d > best_d:
			best_d = d
			best = c
	return best

# =============================================================================
# SPAWNS
# =============================================================================

static func _spawn_enemies(data: DungeonData, cfg: Dictionary, rng: RandomNumberGenerator,
		picker: Callable, occupied: Dictionary) -> void:
	var per_min: int = int(cfg.get("enemies_per_room_min", 0))
	var per_max: int = int(cfg.get("enemies_per_room_max", 2))
	var bonus: float = float(cfg.get("enemies_bonus_per_floor", 0.0)) * float(data.floor_number - 1)
	var safe: int = int(cfg.get("enemy_safe_radius", 0))
	for i in range(1, data.rooms.size()):
		# Fractional bonus: 0.7 extra enemy = +1 with a 70% chance
		var count: int = rng.randi_range(per_min, per_max) + int(bonus)
		if rng.randf() < bonus - floorf(bonus):
			count += 1
		for _j in count:
			var type_id: String = str(picker.call(data.floor_number, rng))
			if type_id.is_empty():
				continue
			var pos: Vector2i = _free_cell_in_room(data, data.rooms[i], occupied, rng)
			if pos.x < 0 or _chebyshev(pos, data.player_start) <= safe:
				continue
			occupied[pos] = true
			data.enemy_spawns.append({pos = pos, type_id = type_id})

static func _spawn_boss(data: DungeonData, boss_id: String, occupied: Dictionary) -> void:
	for dir in DijkstraMap.DIRS:
		var p: Vector2i = data.stairs_pos + dir
		if data.get_tile(p) == DungeonData.TileType.FLOOR and not occupied.has(p):
			occupied[p] = true
			data.enemy_spawns.append({pos = p, type_id = boss_id})
			return

## The key thief starts in a far room that does not hold the stairs.
static func _spawn_thief(data: DungeonData, rng: RandomNumberGenerator, occupied: Dictionary) -> void:
	var dmap: DijkstraMap = DijkstraMap.compute(data, data.player_start, 1 << 20)
	var longest: int = 1
	for i in range(1, data.rooms.size()):
		longest = maxi(longest, dmap.get_dist(_room_center(data.rooms[i])))
	var candidates: Array[int] = []
	for i in range(1, data.rooms.size()):
		var room: Rect2i = data.rooms[i]
		if room.has_point(data.stairs_pos):
			continue
		if dmap.get_dist(_room_center(room)) >= longest * 0.4:
			candidates.append(i)
	if candidates.is_empty():
		for i in range(1, data.rooms.size()):
			candidates.append(i)
	for _attempt in 10:
		var room: Rect2i = data.rooms[candidates[rng.randi_range(0, candidates.size() - 1)]]
		var pos: Vector2i = _free_cell_in_room(data, room, occupied, rng)
		if pos.x >= 0:
			occupied[pos] = true
			data.enemy_spawns.append({pos = pos, type_id = "thief"})
			return

static func _spawn_items(data: DungeonData, cfg: Dictionary, rng: RandomNumberGenerator,
		picker: Callable, occupied: Dictionary) -> void:
	var count: int = rng.randi_range(int(cfg.get("items_per_floor_min", 0)), int(cfg.get("items_per_floor_max", 0)))
	for k in count:
		var item_id: String = "potion" if k == 0 else str(picker.call(data.floor_number, rng))
		if item_id.is_empty():
			continue
		var room: Rect2i = data.rooms[rng.randi_range(0, data.rooms.size() - 1)]
		var pos: Vector2i = _free_cell_in_room(data, room, occupied, rng)
		if pos.x < 0:
			continue
		occupied[pos] = true
		data.item_spawns.append({pos = pos, item_id = item_id})

## Random FLOOR cell of the room not in `occupied`; (-1, -1) after 20 tries.
static func _free_cell_in_room(data: DungeonData, room: Rect2i, occupied: Dictionary,
		rng: RandomNumberGenerator) -> Vector2i:
	for _attempt in 20:
		var pos := Vector2i(rng.randi_range(room.position.x, room.end.x - 1),
			rng.randi_range(room.position.y, room.end.y - 1))
		if data.get_tile(pos) == DungeonData.TileType.FLOOR and not occupied.has(pos):
			return pos
	return Vector2i(-1, -1)

# =============================================================================
# SCENERY
# =============================================================================

static func _in_any_room(data: DungeonData, p: Vector2i) -> bool:
	for room in data.rooms:
		if room.has_point(p):
			return true
	return false

## Barrels against room walls, never next to a corridor, never cutting off
## part of the floor.
static func _place_barrels(data: DungeonData, cfg: Dictionary, rng: RandomNumberGenerator, occupied: Dictionary) -> void:
	var count: int = rng.randi_range(int(cfg.get("barrels_per_floor_min", 0)), int(cfg.get("barrels_per_floor_max", 0)))
	var placed: int = 0
	for _attempt in count * 12:
		if placed >= count or data.rooms.size() < 2:
			break
		var room: Rect2i = data.rooms[rng.randi_range(1, data.rooms.size() - 1)]
		var pos := Vector2i(rng.randi_range(room.position.x, room.end.x - 1), rng.randi_range(room.position.y, room.end.y - 1))
		var on_border: bool = pos.x == room.position.x or pos.x == room.end.x - 1 or pos.y == room.position.y or pos.y == room.end.y - 1
		if not on_border or occupied.has(pos) or data.get_tile(pos) != DungeonData.TileType.FLOOR:
			continue
		var near_corridor: bool = false
		for dir in DijkstraMap.DIRS:
			var n: Vector2i = pos + dir
			if data.is_open(n) and not _in_any_room(data, n):
				near_corridor = true
		if near_corridor:
			continue
		data.barrels[pos] = "keg" if rng.randf() < float(cfg.get("keg_chance", 0.0)) else "barrel"
		if not _all_reachable(data):
			data.barrels.erase(pos)
			continue
		occupied[pos] = true
		placed += 1

static func _all_reachable(data: DungeonData) -> bool:
	var dmap: DijkstraMap = DijkstraMap.compute(data, data.player_start, 1 << 20)
	for x in data.width:
		for y in data.height:
			var p := Vector2i(x, y)
			if data.is_walkable(p) and dmap.get_dist(p) < 0:
				return false
	return true

## Torches on the top wall of most rooms (two in wide rooms): light sources.
static func _place_torches(data: DungeonData, cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	var chance: float = float(cfg.get("torch_chance_per_room", 0.75))
	for room in data.rooms:
		if rng.randf() > chance:
			continue
		var y: int = room.position.y - 1
		var spots: Array[Vector2i] = []
		for x in range(room.position.x, room.end.x):
			var p := Vector2i(x, y)
			if data.get_tile(p) == DungeonData.TileType.WALL and data.get_tile(p + Vector2i(0, 1)) == DungeonData.TileType.FLOOR:
				spots.append(p)
		if spots.is_empty():
			continue
		var wanted: int = 2 if room.size.x >= 7 and spots.size() >= 5 else 1
		if wanted == 2:
			data.torches.append(spots[1])
			data.torches.append(spots[spots.size() - 2])
		else:
			data.torches.append(spots[rng.randi_range(0, spots.size() - 1)])

## Banners on free spots of the top walls (not on a torch).
static func _place_banners(data: DungeonData, cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	var chance: float = float(cfg.get("banner_chance", 0.0))
	for room in data.rooms:
		if rng.randf() > chance:
			continue
		var spots: Array[Vector2i] = []
		for x in range(room.position.x, room.end.x):
			var p := Vector2i(x, room.position.y - 1)
			if data.get_tile(p) == DungeonData.TileType.WALL and data.get_tile(p + Vector2i(0, 1)) == DungeonData.TileType.FLOOR 					and not data.torches.has(p) and not data.torches.has(p + Vector2i(1, 0)) and not data.torches.has(p - Vector2i(1, 0)):
				spots.append(p)
		if not spots.is_empty():
			data.banners[spots[rng.randi_range(0, spots.size() - 1)]] = true

## Candles in room corners, and one glowing rune near the middle of a room
## (never the start room nor the stairs room). Both are walkable light sources.
static func _place_lights(data: DungeonData, cfg: Dictionary, rng: RandomNumberGenerator, occupied: Dictionary) -> void:
	var chance: float = float(cfg.get("candle_chance_per_room", 0.0))
	for room in data.rooms:
		if rng.randf() > chance:
			continue
		var corners: Array[Vector2i] = [room.position, Vector2i(room.end.x - 1, room.position.y),
			Vector2i(room.position.x, room.end.y - 1), room.end - Vector2i.ONE]
		var c: Vector2i = corners[rng.randi_range(0, 3)]
		if data.get_tile(c) == DungeonData.TileType.FLOOR and not occupied.has(c) and c != data.player_start:
			occupied[c] = true
			data.candles.append(c)
	if data.rooms.size() < 3 or rng.randf() > float(cfg.get("rune_chance", 0.0)):
		return
	for _attempt in 10:
		var room: Rect2i = data.rooms[rng.randi_range(1, data.rooms.size() - 1)]
		if room.has_point(data.stairs_pos):
			continue
		var p: Vector2i = _free_cell_in_room(data, room.grow(-1) if room.size.x > 4 and room.size.y > 4 else room, occupied, rng)
		if p.x >= 0:
			occupied[p] = true
			data.runes.append(p)
			return

static func _place_decor(data: DungeonData, rng: RandomNumberGenerator, occupied: Dictionary) -> void:
	for _i in rng.randi_range(5, 10):
		var room: Rect2i = data.rooms[rng.randi_range(0, data.rooms.size() - 1)]
		var pos: Vector2i = _free_cell_in_room(data, room, occupied, rng)
		if pos.x >= 0 and pos != data.player_start:
			data.decor[pos] = "bones"
	# rubble along the walls: floor cells that touch a wall
	for _i in rng.randi_range(8, 14):
		var room: Rect2i = data.rooms[rng.randi_range(0, data.rooms.size() - 1)]
		var pos: Vector2i = _free_cell_in_room(data, room, occupied, rng)
		if pos.x < 0 or pos == data.player_start or data.decor.has(pos):
			continue
		var by_wall: bool = false
		for dir in DijkstraMap.DIRS:
			if data.get_tile(pos + dir) == DungeonData.TileType.WALL:
				by_wall = true
		if by_wall:
			data.decor[pos] = "rubble"

static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

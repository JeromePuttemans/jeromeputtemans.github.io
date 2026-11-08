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
# 7. Items: a few per floor on free cells; the first one is always a healing
#    potion, so every floor offers at least one way to recover.
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
	_spawn_items(data, cfg, rng, item_picker, occupied)
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

static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

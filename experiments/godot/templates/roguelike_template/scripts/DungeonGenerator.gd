# =============================================================================
# DungeonGenerator.gd — Procedural dungeon generation.
# =============================================================================
# ALGORITHM: Random Room Placement + L-shaped corridors.
#
# 1. Fill the entire grid with WALL.
# 2. Attempt to place `max_rooms` randomly-sized rooms.
#    Each room must not overlap any already-placed room (with a 1-tile buffer).
# 3. Connect each new room to the previous one via an L-shaped corridor
#    (horizontal segment then vertical). This guarantees full connectivity —
#    every room is always reachable from every other.
# 4. Place STAIRS_DOWN in the center of the last room placed.
# 5. Spawn enemies randomly in all rooms except rooms[0] (player start).
#
# All parameters are read from a config Dictionary, making them data-driven.
# =============================================================================

class_name DungeonGenerator
extends RefCounted

## Generates a complete DungeonData.
## cfg  — flat Dictionary from config.json
## enemy_types — Array[Dictionary] from EnemyDatabase.get_all()
static func generate(cfg: Dictionary, enemy_types: Array) -> DungeonData:
	var w        = int(cfg.get("dungeon_width",      50))
	var h        = int(cfg.get("dungeon_height",     30))
	var max_rooms = int(cfg.get("max_rooms",         12))
	var room_min = int(cfg.get("room_min_size",       4))
	var room_max = int(cfg.get("room_max_size",      10))
	var enem_min = int(cfg.get("enemies_per_room_min", 0))
	var enem_max = int(cfg.get("enemies_per_room_max", 2))

	var data = DungeonData.new(w, h)

	# --- Place rooms --------------------------------------------------------
	for i in max_rooms:
		var rw = randi_range(room_min, room_max)
		var rh = randi_range(room_min, room_max)
		# Keep rooms at least 1 tile inside the dungeon border
		var rx = randi_range(1, w - rw - 2)
		var ry = randi_range(1, h - rh - 2)
		var room = Rect2i(rx, ry, rw, rh)

		if i > 0:
			var overlaps = false
			for existing in data.rooms:
				# grow(1) adds a 1-tile buffer so rooms never touch
				if room.intersects(existing.grow(1)):
					overlaps = true
					break
			if overlaps:
				continue

		_carve_room(data, room)

		if data.rooms.size() > 0:
			_connect_rooms(data, data.rooms.back(), room)

		data.rooms.append(room)

	if data.rooms.is_empty():
		push_error("DungeonGenerator: failed to place any room.")
		return data

	# --- Key positions ------------------------------------------------------
	data.player_start = _room_center(data.rooms.front())

	if data.rooms.size() > 1:
		data.stairs_pos = _room_center(data.rooms.back())
	else:
		var r = data.rooms.front()
		data.stairs_pos = Vector2i(r.end.x - 1, r.end.y - 1)

	data.set_tile(data.stairs_pos, DungeonData.TileType.STAIRS_DOWN)

	# --- Enemy spawns (skip rooms[0] = player start) -----------------------
	for i in range(1, data.rooms.size()):
		if enemy_types.is_empty():
			break
		var count = randi_range(enem_min, enem_max)
		for _j in count:
			var pos = _random_floor_in_room(data, data.rooms[i])
			if pos == Vector2i(-1, -1):
				continue
			var type_data = enemy_types[randi() % enemy_types.size()]
			data.enemy_spawns.append({"pos": pos, "type_id": type_data.get("id", "")})

	return data

# =============================================================================
# PRIVATE HELPERS
# =============================================================================

static func _carve_room(data: DungeonData, room: Rect2i) -> void:
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)

static func _connect_rooms(data: DungeonData, a: Rect2i, b: Rect2i) -> void:
	var ca = _room_center(a)
	var cb = _room_center(b)
	_carve_h(data, ca.x, cb.x, ca.y)
	_carve_v(data, ca.y, cb.y, cb.x)

static func _carve_h(data: DungeonData, x1: int, x2: int, y: int) -> void:
	for x in range(min(x1, x2), max(x1, x2) + 1):
		data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)

static func _carve_v(data: DungeonData, y1: int, y2: int, x: int) -> void:
	for y in range(min(y1, y2), max(y1, y2) + 1):
		data.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR)

static func _room_center(room: Rect2i) -> Vector2i:
	return room.position + room.size / 2

## Tries up to 10 random positions inside the room; returns (-1,-1) on failure.
static func _random_floor_in_room(data: DungeonData, room: Rect2i) -> Vector2i:
	for _attempt in 10:
		var pos = Vector2i(
			randi_range(room.position.x, room.end.x - 1),
			randi_range(room.position.y, room.end.y - 1)
		)
		if data.get_tile(pos) == DungeonData.TileType.FLOOR:
			return pos
	return Vector2i(-1, -1)

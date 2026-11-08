class_name GridManager
extends Node3D

# GridManager: the 3D maze of rooms (one room = one cube of side 1).
#
# WALL BITMASK:
#   Each room stores a 6-bit mask, one bit per face (DIRS order below).
#   Bit set = wall, bit clear = open. Moving from A to B is allowed only if
#   A has no wall toward B and B (when it exists) has no wall toward A.
#
# GENERATION ON ENTRY:
#   Rooms do not exist before the player walks into them. When the player
#   enters an empty cell, each face of the new room is:
#     - copied from the neighbour room when there is one (shared face,
#       so walls stay consistent on both sides);
#     - otherwise a wall with probability wall_chance (grows with depth).
#   The room type is rolled at the same time: energy crystal, trap or neutral.
#   The maze is therefore built by the player's own path: dead ends happen,
#   and the bomb is the way out.
#
# BOMB: removes every room in the 3x3x3 block around the player (except the
#   teleporter and the core) and opens all the walls of the player's room.
#   The removed cells will be regenerated, with new walls, when re-entered.

enum Type { NEUTRAL, RESOURCE, TRAP, TELEPORTER, CORE }

const DIRS: Array[Vector3i] = [
	Vector3i(0, 0, -1), Vector3i(0, 0, 1), Vector3i(-1, 0, 0),
	Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]

var grid: Dictionary = {}            # Vector3i -> RoomCube
var teleporter_pos: Vector3i = Vector3i.ZERO
var core_pos: Vector3i = Vector3i.ZERO
var rng := RandomNumberGenerator.new()

static func dir_bit(dir: Vector3i) -> int:
	return 1 << DIRS.find(dir)

func setup_level(_level: int) -> void:
	for c in get_children():
		var r: RoomCube = c as RoomCube
		if r != null and r._pop != null and r._pop.is_valid():
			r._pop.kill()
		c.free()
	grid.clear()
	rng.randomize()
	# Teleporter: floor below, open on every other side
	_add_room(teleporter_pos, dir_bit(Vector3i(0, -1, 0)), Type.TELEPORTER, false)
	core_pos = _pick_core_position(GameManager.core_distance(), GameManager.level)
	_add_room(core_pos, 0, Type.CORE, false)

## Cell at Manhattan distance `dist` from the teleporter. From level 2 on,
## the core can sit one floor above or below: Up / Down moves become needed.
func _pick_core_position(dist: int, level: int) -> Vector3i:
	var dy: int = rng.randi_range(-1, 1) if level >= 2 and dist >= 3 else 0
	var rest: int = dist - absi(dy)
	var dx: int = rng.randi_range(-rest, rest)
	var dz: int = (rest - absi(dx)) * (1 if rng.randf() < 0.5 else -1)
	var p := Vector3i(dx, dy, dz)
	return p if p != teleporter_pos else Vector3i(dist, 0, 0)

func room(p: Vector3i) -> RoomCube:
	return grid.get(p) as RoomCube

func has_room(p: Vector3i) -> bool:
	return grid.has(p)

func room_type(p: Vector3i) -> int:
	var r: RoomCube = room(p)
	return r.type if r != null else -1

func can_move(from: Vector3i, dir: Vector3i) -> bool:
	var a: RoomCube = room(from)
	if a == null or a.has_wall(dir):
		return false
	var b: RoomCube = room(from + dir)
	return b == null or not b.has_wall(-dir)

func open_dirs(p: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for d in DIRS:
		if can_move(p, d):
			result.append(d)
	return result

## Creates the room at `p` if it does not exist. Returns true if created.
func enter(p: Vector3i) -> bool:
	if has_room(p):
		return false
	var mask: int = 0
	for d in DIRS:
		var n: RoomCube = room(p + d)
		if n != null:
			if n.has_wall(-d):
				mask |= dir_bit(d)
		elif rng.randf() < GameManager.wall_chance():
			mask |= dir_bit(d)
	var roll: float = rng.randf()
	var type: int = Type.NEUTRAL
	if roll < GameManager.resource_chance():
		type = Type.RESOURCE
	elif roll < GameManager.resource_chance() + GameManager.trap_chance():
		type = Type.TRAP
	_add_room(p, mask, type, true)
	return true

## A collected crystal or a triggered trap becomes a neutral room.
func set_neutral(p: Vector3i) -> void:
	var r: RoomCube = room(p)
	if r != null:
		r.set_type(Type.NEUTRAL)

func bomb(center: Vector3i) -> void:
	for p_v in grid.keys():
		var p: Vector3i = p_v as Vector3i
		var d: Vector3i = (p - center).abs()
		if p == center or maxi(d.x, maxi(d.y, d.z)) > 1:
			continue
		var r: RoomCube = room(p)
		if r.type == Type.TELEPORTER or r.type == Type.CORE:
			continue
		r.remove()
		grid.erase(p)
	# Open the player's room on every side, and the faces of the rooms that
	# survived next to it (teleporter, core) so walls stay consistent.
	room(center).set_mask(0)
	for dir in DIRS:
		var n: RoomCube = room(center + dir)
		if n != null:
			n.set_mask(n.mask & ~dir_bit(-dir))

func room_count() -> int:
	return grid.size()

## FOCUS: rooms within GameManager.focus_radius moves (options slider) of
## `center`, walking only through
## open passages (breadth-first search over the room graph), are drawn
## normally; every other room fades to the far opacity. A room right behind
## a wall is therefore faded: what counts is the walking distance, which is
## what the player needs to read.
func update_focus(center: Vector3i) -> void:
	var radius: int = GameManager.focus_radius
	var dist: Dictionary = {center: 0}
	var queue: Array[Vector3i] = [center]
	var head: int = 0
	while head < queue.size():
		var cur: Vector3i = queue[head]
		head += 1
		var d_cur: int = int(dist[cur])
		if d_cur >= radius:
			continue
		for d in DIRS:
			var n: Vector3i = cur + d
			if dist.has(n) or not has_room(n) or not can_move(cur, d):
				continue
			dist[n] = d_cur + 1
			queue.append(n)
	for p in grid:
		(grid[p] as RoomCube).apply_focus(dist.has(p))

func _add_room(p: Vector3i, mask: int, type: int, animate: bool) -> void:
	var r := RoomCube.new()
	add_child(r)
	r.position = Vector3(p)
	r.setup(mask, type, animate)
	grid[p] = r

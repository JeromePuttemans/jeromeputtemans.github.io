# =============================================================================
# Board.gd — The player's half of the arena and the bench
# =============================================================================
# cells: Dictionary Vector2i(col, row) -> Unit, for the cols x rows player
#   half (row 0 is the front line, next to the enemy). A dictionary keeps
#   lookups O(1) and empty cells free.
# bench: fixed-size Array of Unit or null.
# A location is {"zone": "board", "cell": Vector2i} or
# {"zone": "bench", "index": int}; move() swaps when the target is taken.
# In battle, board row r becomes arena row (rows + r): the player fights
# from the bottom half, the enemy from the top half.
# =============================================================================

class_name Board
extends RefCounted

var cols: int = 7
var rows: int = 4
var cells: Dictionary = {}
var bench: Array = []

func _init(board_cols: int, board_rows: int, bench_size: int) -> void:
	cols = board_cols
	rows = board_rows
	bench.resize(bench_size)
	bench.fill(null)

func board_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for c in cells:
		result.append(cells[c] as Unit)
	result.sort_custom(func(a: Unit, b: Unit) -> bool: return a.instance_id < b.instance_id)
	return result

func bench_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for u in bench:
		if u != null:
			result.append(u as Unit)
	return result

func all_units() -> Array[Unit]:
	var result: Array[Unit] = board_units()
	result.append_array(bench_units())
	return result

func board_count() -> int:
	return cells.size()

func first_free_bench() -> int:
	for i in bench.size():
		if bench[i] == null:
			return i
	return -1

func is_valid(location: Dictionary) -> bool:
	if location.get("zone", "") == "board":
		var c: Vector2i = location.get("cell", Vector2i(-1, -1)) as Vector2i
		return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows
	if location.get("zone", "") == "bench":
		var i: int = int(location.get("index", -1))
		return i >= 0 and i < bench.size()
	return false

func unit_at(location: Dictionary) -> Unit:
	if not is_valid(location):
		return null
	if location["zone"] == "board":
		return cells.get(location["cell"]) as Unit
	return bench[int(location["index"])] as Unit

func location_of(unit: Unit) -> Dictionary:
	for c in cells:
		if cells[c] == unit:
			return {"zone": "board", "cell": c}
	for i in bench.size():
		if bench[i] == unit:
			return {"zone": "bench", "index": i}
	return {}

func put(unit: Unit, location: Dictionary) -> void:
	if location["zone"] == "board":
		if unit == null:
			cells.erase(location["cell"])
		else:
			cells[location["cell"]] = unit
	else:
		bench[int(location["index"])] = unit

func remove(unit: Unit) -> bool:
	var location: Dictionary = location_of(unit)
	if location.is_empty():
		return false
	put(null, location)
	return true

## Moves a unit to a location, swapping with the unit already there.
func move(unit: Unit, to: Dictionary) -> void:
	var from: Dictionary = location_of(unit)
	var other: Unit = unit_at(to)
	put(other, from)
	put(unit, to)

# =============================================================================
# Board.gd — Manages the player board and bench slot arrays.
# =============================================================================
# The board is a flat Array of (cols × rows) slots.
# The bench is a flat Array of bench_size slots.
# Both arrays store Unit references or null for empty slots.
#
# SLOT INDEXING (board):
#   index = row * cols + col
#   This is row-major order — iterating by index visits left-to-right, top-to-bottom.
# =============================================================================

class_name Board
extends RefCounted

var cols:       int = 4
var rows:       int = 2
var bench_size: int = 8

# Each element is a Unit or null.
var board_slots: Array = []
var bench_slots: Array = []

func _init(c: int, r: int, b: int) -> void:
	cols       = c
	rows       = r
	bench_size = b
	board_slots.resize(cols * rows)
	board_slots.fill(null)
	bench_slots.resize(bench_size)
	bench_slots.fill(null)

# =============================================================================
# BOARD HELPERS
# =============================================================================

func board_index(col: int, row: int) -> int:
	return row * cols + col

func get_board_unit(col: int, row: int) -> Variant:
	var idx = board_index(col, row)
	if idx < 0 or idx >= board_slots.size():
		return null
	return board_slots[idx]

func set_board_unit(col: int, row: int, unit: Variant) -> void:
	var idx = board_index(col, row)
	if idx >= 0 and idx < board_slots.size():
		board_slots[idx] = unit

## Returns an Array of all non-null units on the board.
func get_board_units() -> Array:
	var result: Array = []
	for u in board_slots:
		if u != null:
			result.append(u)
	return result

## Returns the first empty board slot index, or -1 if the board is full.
func first_empty_board_slot() -> int:
	for i in board_slots.size():
		if board_slots[i] == null:
			return i
	return -1

func is_board_full() -> bool:
	return first_empty_board_slot() == -1

# =============================================================================
# BENCH HELPERS
# =============================================================================

## Returns an Array of all non-null units on the bench.
func get_bench_units() -> Array:
	var result: Array = []
	for u in bench_slots:
		if u != null:
			result.append(u)
	return result

## Returns the first empty bench slot index, or -1 if the bench is full.
func first_empty_bench_slot() -> int:
	for i in bench_slots.size():
		if bench_slots[i] == null:
			return i
	return -1

func is_bench_full() -> bool:
	return first_empty_bench_slot() == -1

## Finds which bench slot holds the given unit. Returns -1 if not found.
func find_bench_slot(unit: Unit) -> int:
	for i in bench_slots.size():
		if bench_slots[i] == unit:
			return i
	return -1

## Finds which board slot index holds the given unit. Returns -1 if not found.
func find_board_slot(unit: Unit) -> int:
	for i in board_slots.size():
		if board_slots[i] == unit:
			return i
	return -1

## Moves a unit from bench to the first available board slot.
## Returns true on success, false if board is full or unit not on bench.
func move_bench_to_board(unit: Unit) -> bool:
	var bench_idx = find_bench_slot(unit)
	if bench_idx == -1:
		return false
	var board_idx = first_empty_board_slot()
	if board_idx == -1:
		return false
	bench_slots[bench_idx] = null
	board_slots[board_idx] = unit
	return true

## Moves a unit from board to the first available bench slot.
## Returns true on success, false if bench is full or unit not on board.
func move_board_to_bench(unit: Unit) -> bool:
	var board_idx = find_board_slot(unit)
	if board_idx == -1:
		return false
	var bench_idx = first_empty_bench_slot()
	if bench_idx == -1:
		return false
	board_slots[board_idx] = null
	bench_slots[bench_idx] = unit
	return true

## Removes a unit from wherever it is (board or bench). Returns true if found.
func remove_unit(unit: Unit) -> bool:
	for i in board_slots.size():
		if board_slots[i] == unit:
			board_slots[i] = null
			return true
	for i in bench_slots.size():
		if bench_slots[i] == unit:
			bench_slots[i] = null
			return true
	return false

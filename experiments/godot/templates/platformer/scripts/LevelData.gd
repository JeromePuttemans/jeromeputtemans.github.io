# =============================================================================
# LevelData.gd — One level parsed from data/levels.json
# =============================================================================
# A level is drawn as ASCII art: one string per row, one character per tile
# of TILE x TILE pixels. Terrain characters fill the tile grid, entity
# characters become spawn points (their tile stays empty).
#
#   #  ground            =  plank (one-way)      :  cave or ruin backdrop
#   ^ v < >  spikes (pointing up, down, left, right)
#   c  crumbling block   a / b  amber / blue block, swapped on every jump
#   P  start   E  exit   K  lantern (checkpoint)   1-9  hint sign
#   o  firefly   G  golden acorn   s  spring
#   w  beetle   h  hedgehog   f / F  wasp (horizontal / vertical)
#   t / T  spitter plant facing left / right
#
# Moving platforms do not fit in a character: they are listed in "movers"
# with tile coordinates, a width, a travel and a period.
# =============================================================================

class_name LevelData
extends RefCounted

const TILE: int = 40

enum Tile { EMPTY, SOLID, ONEWAY, SPIKE_UP, SPIKE_DOWN, SPIKE_LEFT, SPIKE_RIGHT, CRUMBLE, TOGGLE_A, TOGGLE_B }

const TILE_CHARS: Dictionary = {
	"#": Tile.SOLID, "=": Tile.ONEWAY, "^": Tile.SPIKE_UP, "v": Tile.SPIKE_DOWN,
	"<": Tile.SPIKE_LEFT, ">": Tile.SPIKE_RIGHT, "c": Tile.CRUMBLE, "a": Tile.TOGGLE_A, "b": Tile.TOGGLE_B,
}
const ENTITY_CHARS: Dictionary = {
	"P": "start", "E": "exit", "K": "checkpoint", "o": "firefly", "G": "acorn", "s": "spring",
	"w": "walker", "h": "hedgehog", "f": "flyer", "F": "flyer_v", "t": "spitter_left", "T": "spitter_right",
}

var id: int = 0
var name_key: String = ""
var width: int = 0
var height: int = 0
var tiles := PackedByteArray()
var backdrop := PackedByteArray()
var spawns: Array[Dictionary] = []
var movers: Array[Dictionary] = []
var theme: Dictionary = {}
var start_cell := Vector2i(1, 1)
var firefly_total: int = 0
var acorn_total: int = 0
var has_toggles: bool = false

static func from_dict(data: Dictionary) -> LevelData:
	var level := LevelData.new()
	level.id = int(data.get("id", 0))
	level.name_key = str(data.get("name", ""))
	level.theme = data.get("theme", {}) as Dictionary
	var rows: Array = data.get("map", []) as Array
	level.height = rows.size()
	for row in rows:
		level.width = maxi(level.width, str(row).length())
	level.tiles.resize(level.width * level.height)
	level.backdrop.resize(level.width * level.height)
	for y in level.height:
		var row: String = str(rows[y])
		for x in level.width:
			var ch: String = row[x] if x < row.length() else "."
			level._read_char(ch, x, y)
	level._fill_entity_backdrop()
	for m in data.get("movers", []) as Array:
		level.movers.append(m as Dictionary)
	return level

func _read_char(ch: String, x: int, y: int) -> void:
	var i: int = y * width + x
	if TILE_CHARS.has(ch):
		tiles[i] = int(TILE_CHARS[ch])
		has_toggles = has_toggles or ch == "a" or ch == "b"
		return
	if ch == ":":
		backdrop[i] = 1
		return
	var kind: String = ""
	if ENTITY_CHARS.has(ch):
		kind = str(ENTITY_CHARS[ch])
	elif ch >= "1" and ch <= "9":
		kind = "sign"
	if kind.is_empty():
		return
	if kind == "start":
		start_cell = Vector2i(x, y)
		return
	var spawn: Dictionary = {kind = kind, cell = Vector2i(x, y)}
	if kind == "sign":
		spawn["text"] = "sign_%d_%s" % [id, ch]
	elif kind == "firefly":
		spawn["index"] = firefly_total
		firefly_total += 1
	elif kind == "acorn":
		spawn["index"] = acorn_total
		acorn_total += 1
	spawns.append(spawn)

## Entities standing in a cave keep the backdrop behind them.
func _fill_entity_backdrop() -> void:
	for spawn in spawns:
		var c: Vector2i = spawn["cell"] as Vector2i
		var left: bool = c.x > 0 and backdrop[c.y * width + c.x - 1] == 1
		var right: bool = c.x < width - 1 and backdrop[c.y * width + c.x + 1] == 1
		if left or right:
			backdrop[c.y * width + c.x] = 1
	var s: Vector2i = start_cell
	if s.x > 0 and backdrop[s.y * width + s.x - 1] == 1:
		backdrop[s.y * width + s.x] = 1

func tile(x: int, y: int) -> int:
	if x < 0 or x >= width or y < 0 or y >= height:
		return Tile.EMPTY
	return tiles[y * width + x]

func has_backdrop(x: int, y: int) -> bool:
	if x < 0 or x >= width or y < 0 or y >= height:
		return false
	return backdrop[y * width + x] == 1

func pixel_size() -> Vector2:
	return Vector2(width * TILE, height * TILE)

## Bottom centre of a cell: where feet stand.
static func cell_feet(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * TILE, (cell.y + 1) * TILE)

static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * TILE, (cell.y + 0.5) * TILE)

func theme_color(key: String, fallback: Color) -> Color:
	if not theme.has(key):
		return fallback
	return Color(str(theme[key]))

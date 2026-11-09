# =============================================================================
# TileChunk.gd — Draws a 16 x 16 tile area of the static terrain
# =============================================================================
# The terrain never changes, so each chunk records its drawing once (the
# canvas keeps the commands) and Godot skips the chunks outside the view.
# Ground tiles are "autotiled" from their neighbours: a top band (grass,
# sand, moss) with a lip and tufts where the tile above is open, darker
# edges on open sides, pebbles placed by a hash of the cell coordinates so
# the same level always looks the same.
# =============================================================================

class_name TileChunk
extends Node2D

const T: float = LevelData.TILE

var _data: LevelData = null
var _area := Rect2i()
var _ground := Color()
var _ground_dark := Color()
var _top := Color()
var _top_dark := Color()
var _spike := Color()
var _plank := Color()
var _backdrop := Color()
var _decor: String = "flowers"
var _accent := Color()

func setup(data: LevelData, area: Rect2i) -> void:
	_data = data
	_area = area
	_ground = data.theme_color("ground", Color("6b4a3a"))
	_ground_dark = data.theme_color("ground_dark", Color("4e3428"))
	_top = data.theme_color("top", Color("6cc24a"))
	_top_dark = data.theme_color("top_dark", Color("4e9a36"))
	_spike = data.theme_color("spike", Color("d8d8e0"))
	_plank = data.theme_color("plank", Color("8a5a33"))
	_backdrop = data.theme_color("backdrop", Color("2a2438"))
	_accent = data.theme_color("accent", Color("f28fb5"))
	_decor = str(data.theme.get("decor", "flowers"))

func _draw() -> void:
	var x1: int = mini(_area.end.x, _data.width)
	var y1: int = mini(_area.end.y, _data.height)
	for y in range(_area.position.y, y1):
		for x in range(_area.position.x, x1):
			if _data.has_backdrop(x, y):
				_draw_backdrop(x, y)
	for y in range(_area.position.y, y1):
		for x in range(_area.position.x, x1):
			match _data.tile(x, y):
				LevelData.Tile.SOLID:
					_draw_ground(x, y)
				LevelData.Tile.ONEWAY:
					_draw_plank(x, y)
				LevelData.Tile.SPIKE_UP, LevelData.Tile.SPIKE_DOWN, LevelData.Tile.SPIKE_LEFT, LevelData.Tile.SPIKE_RIGHT:
					_draw_spikes(x, y, _data.tile(x, y))

static func cell_hash(x: int, y: int) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))

func _solid(x: int, y: int) -> bool:
	if x < 0 or x >= _data.width or y >= _data.height:
		return true
	if y < 0:
		return false
	return _data.tile(x, y) == LevelData.Tile.SOLID

## Stone bricks: two courses per tile, joints offset every other course.
func _draw_backdrop(x: int, y: int) -> void:
	var r := Rect2(x * T, y * T, T, T)
	draw_rect(r, _backdrop)
	var line := _backdrop.darkened(0.25)
	var half: float = T * 0.5
	draw_line(r.position, Vector2(r.end.x, r.position.y), line, 1.0)
	draw_line(r.position + Vector2(0.0, half), Vector2(r.end.x, r.position.y + half), line, 1.0)
	var upper: float = 0.0 if y % 2 == 0 else half
	var lower: float = half - upper
	draw_line(r.position + Vector2(upper, 0.0), r.position + Vector2(upper, half), line, 1.0)
	draw_line(r.position + Vector2(lower, half), r.position + Vector2(lower, T), line, 1.0)
	if cell_hash(x, y) % 9 == 0:
		draw_circle(r.position + Vector2(12.0, 28.0), 3.0, _backdrop.lightened(0.08))

func _draw_ground(x: int, y: int) -> void:
	var r := Rect2(x * T, y * T, T, T)
	var h: int = cell_hash(x, y)
	draw_rect(r, _ground)
	# Depth: the deeper below the surface, the darker
	var depth: int = 0
	while depth < 4 and _solid(x, y - depth - 1):
		depth += 1
	if depth > 0:
		draw_rect(r, Color(_ground_dark, 0.11 * depth))
	if h % 4 == 0:
		var p := r.position + Vector2(6.0 + float(h % 26), 14.0 + float((h >> 5) % 20))
		PlayerArt.ellipse(self, p, 4.0 + float(h % 3), 2.6, _ground_dark)
		PlayerArt.ellipse(self, p + Vector2(-1.0, -1.0), 2.0, 1.0, _ground.lightened(0.15))
	elif h % 7 == 1:
		draw_line(r.position + Vector2(8.0, 22.0), r.position + Vector2(15.0, 26.0), _ground_dark, 2.0)
	var open_left: bool = not _solid(x - 1, y)
	var open_right: bool = not _solid(x + 1, y)
	if not _solid(x, y + 1):
		draw_rect(Rect2(r.position.x, r.end.y - 6.0, T, 6.0), _ground_dark)
	if open_left:
		draw_rect(Rect2(r.position.x, r.position.y, 4.0, T), _ground_dark)
	if open_right:
		draw_rect(Rect2(r.end.x - 4.0, r.position.y, 4.0, T), _ground_dark)
	if not _solid(x, y - 1):
		_draw_top(r, h, open_left, open_right)

func _draw_top(r: Rect2, h: int, open_left: bool, open_right: bool) -> void:
	var left: float = r.position.x - (3.0 if open_left else 0.0)
	var right: float = r.end.x + (3.0 if open_right else 0.0)
	draw_rect(Rect2(left, r.position.y - 2.0, right - left, 12.0), _top_dark)
	draw_rect(Rect2(left, r.position.y - 2.0, right - left, 8.0), _top)
	draw_rect(Rect2(left, r.position.y - 2.0, right - left, 2.0), _top.lightened(0.2))
	# Scalloped underside of the band
	for i in 4:
		draw_circle(Vector2(r.position.x + 5.0 + i * 10.0, r.position.y + 10.0), 3.5, _top_dark)
	# Tufts
	var tufts: int = 1 + h % 3
	for i in tufts:
		var tx: float = r.position.x + 6.0 + float((h >> (i * 4)) % 28)
		var tip := Vector2(tx + 1.5, r.position.y - 7.0 - float((h >> (i * 3)) % 4))
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 2.5, r.position.y - 1.0), tip, Vector2(tx + 3.5, r.position.y - 1.0)]), _top)
	_draw_decor(r, h)

func _draw_decor(r: Rect2, h: int) -> void:
	var roll: int = (h >> 7) % 9
	if roll > 1:
		return
	var at := Vector2(r.position.x + 8.0 + float((h >> 9) % 24), r.position.y - 2.0)
	match _decor:
		"flowers":
			draw_line(at, at + Vector2(0.0, -10.0), _top_dark, 1.5)
			for k in 5:
				var a: float = TAU * k / 5.0
				draw_circle(at + Vector2(0.0, -12.0) + Vector2(cos(a), sin(a)) * 3.0, 2.2, _accent)
			draw_circle(at + Vector2(0.0, -12.0), 1.8, Color("fff0a0"))
		"mushrooms":
			draw_rect(Rect2(at + Vector2(-1.5, -7.0), Vector2(3.0, 7.0)), Color("efe3c8"))
			PlayerArt.ellipse(self, at + Vector2(0.0, -8.0), 6.0, 3.5, _accent)
			draw_circle(at + Vector2(-2.0, -9.0), 1.0, Color(1.0, 1.0, 1.0, 0.8))
		"crystals":
			var c: Color = _accent
			draw_colored_polygon(PackedVector2Array([at + Vector2(-4.0, 0.0), at + Vector2(-1.0, -14.0), at + Vector2(2.0, 0.0)]), c)
			draw_colored_polygon(PackedVector2Array([at + Vector2(1.0, 0.0), at + Vector2(5.0, -9.0), at + Vector2(7.0, 0.0)]), c.lightened(0.2))
			Pickups.glow(self, at + Vector2(1.0, -6.0), 16.0, c, 0.8)
		"stones":
			PlayerArt.ellipse(self, at + Vector2(0.0, -3.0), 6.0, 4.0, _ground_dark)
			PlayerArt.ellipse(self, at + Vector2(-1.5, -4.5), 2.5, 1.5, _ground.lightened(0.2))

func _draw_plank(x: int, y: int) -> void:
	var r := Rect2(x * T, y * T, T, 12.0)
	draw_rect(r, _plank.darkened(0.3))
	draw_rect(Rect2(r.position, Vector2(T, 9.0)), _plank)
	draw_rect(Rect2(r.position, Vector2(T, 2.0)), _plank.lightened(0.25))
	draw_circle(r.position + Vector2(6.0, 5.0), 1.5, _plank.darkened(0.5))
	draw_circle(r.position + Vector2(T - 6.0, 5.0), 1.5, _plank.darkened(0.5))
	if _data.tile(x - 1, y) != LevelData.Tile.ONEWAY:
		draw_rect(Rect2(r.position + Vector2(0.0, 0.0), Vector2(3.0, 12.0)), _plank.darkened(0.4))
	if _data.tile(x + 1, y) != LevelData.Tile.ONEWAY:
		draw_rect(Rect2(r.position + Vector2(T - 3.0, 0.0), Vector2(3.0, 12.0)), _plank.darkened(0.4))
	if _solid(x - 1, y) or _solid(x + 1, y):
		var side: float = 0.0 if _solid(x - 1, y) else T
		var dir: float = 1.0 if side == 0.0 else -1.0
		draw_line(Vector2(x * T + side, y * T + 26.0), Vector2(x * T + side + dir * 14.0, y * T + 11.0), _plank.darkened(0.35), 3.0)

func _draw_spikes(x: int, y: int, kind: int) -> void:
	var base := Vector2(x * T, y * T)
	var dark := _spike.darkened(0.45)
	for i in 3:
		var a: float = 2.0 + i * 12.0
		var b: float = a + 12.0
		var m: float = (a + b) * 0.5
		var tri: PackedVector2Array
		match kind:
			LevelData.Tile.SPIKE_UP:
				tri = PackedVector2Array([base + Vector2(a, T), base + Vector2(m, T - 20.0), base + Vector2(b, T)])
			LevelData.Tile.SPIKE_DOWN:
				tri = PackedVector2Array([base + Vector2(a, 0.0), base + Vector2(b, 0.0), base + Vector2(m, 20.0)])
			LevelData.Tile.SPIKE_LEFT:
				tri = PackedVector2Array([base + Vector2(T, a), base + Vector2(T, b), base + Vector2(T - 20.0, m)])
			_:
				tri = PackedVector2Array([base + Vector2(0.0, a), base + Vector2(20.0, m), base + Vector2(0.0, b)])
		draw_colored_polygon(tri, dark)
		var inner := PackedVector2Array([tri[0].lerp(tri[1], 0.15), tri[1].lerp(tri[0], 0.0), (tri[0] + tri[2]) * 0.5])
		draw_colored_polygon(inner, _spike)

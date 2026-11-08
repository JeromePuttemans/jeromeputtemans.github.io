# =============================================================================
# DungeonView.gd (Node2D): dungeon renderer and animation layer.
# =============================================================================
# Reads GameState data; never changes it.
#
# LOGIC IS INSTANT, VISUALS CATCH UP:
#   GameState resolves a whole turn in one call. This view keeps, for each
#   actor, a visual state (VisState): drawn position, lunge offset, hit
#   flash. Each frame the drawn position eases toward the logical grid
#   position (exponential smoothing), so moves slide instead of jumping, and
#   the event signals (entity_attacked, entity_died...) trigger lunges,
#   flashes, particles, sounds and screen shake. The player can keep
#   pressing keys: animations never block input.
#
# DRAWING LAYERS (back to front), only tiles inside the camera view:
#   1. floor tiles (two-tone checker + seeded speckles), lit by the torch:
#      brightness falls off with the distance to the player, with a slight
#      flicker; explored-but-not-visible tiles are drawn dim and cold (fog of
#      war: you remember the layout, not what moves in it)
#   2. wall faces (only walls touching a floor; the rest is solid rock)
#   3. stairs / exit portal, items on the ground (bobbing when visible)
#   4. enemies in view: token, health bar when hurt, "z" when unaware
#   5. the player, then the hovered-tile outline
# =============================================================================

class_name DungeonView
extends Node2D

class VisState:
	var pos:   Vector2 = Vector2.ZERO
	var lunge: Vector2 = Vector2.ZERO
	var flash: float   = 0.0
	var spawn: float   = 0.0

var hover_tile: Vector2i = Vector2i(-1, -1)

var _ts:    float = 32.0
var _vis:   Dictionary = {}   # Entity -> VisState
var _time:  float = 0.0
var _fov:   float = 8.0
var _wall:      Color
var _wall_top:  Color
var _floor:     Color
var _floor_alt: Color
var _light:     Color
const FOG_TINT := Color(0.05, 0.06, 0.1)

func _ready() -> void:
	_ts = float(ConfigManager.get_int("tile_size", 32))
	_fov = float(ConfigManager.get_int("fov_radius", 8))
	GameState.dungeon_ready.connect(_on_dungeon_ready)
	GameState.entity_moved.connect(_on_entity_moved)
	GameState.entity_attacked.connect(_on_entity_attacked)
	GameState.entity_died.connect(_on_entity_died)
	GameState.projectile_fired.connect(_on_projectile_fired)
	GameState.enemy_alerted.connect(_on_enemy_alerted)
	GameState.item_picked.connect(_on_item_picked)
	GameState.item_used.connect(_on_item_used)
	GameState.spell_hit.connect(_on_spell_hit)
	GameState.player_leveled.connect(_on_player_leveled)
	GameState.wall_bumped.connect(_on_wall_bumped)

func tile_size() -> float:
	return _ts

func tile_center(p: Vector2i) -> Vector2:
	return (Vector2(p) + Vector2(0.5, 0.5)) * _ts

## Drawn (animated) position of the player, followed by the camera.
func player_draw_pos() -> Vector2:
	if GameState.player == null:
		return Vector2.ZERO
	return _state(GameState.player).pos

func _state(e: Entity) -> VisState:
	if not _vis.has(e):
		var s := VisState.new()
		s.pos = tile_center(e.grid_pos)
		_vis[e] = s
	return _vis[e] as VisState

# ---------------------------------------------------------------------------
# Events -> animation
# ---------------------------------------------------------------------------

func _on_dungeon_ready() -> void:
	var theme: Dictionary = ConfigManager.get_floor_theme(GameState.current_floor)
	_wall      = Color("#" + str(theme.get("wall", "4b5468")))
	_wall_top  = Color("#" + str(theme.get("wall_top", "68728a")))
	_floor     = Color("#" + str(theme.get("floor", "2b3040")))
	_floor_alt = Color("#" + str(theme.get("floor_alt", "2f3446")))
	_light     = Color("#" + str(theme.get("light", "ffd9a6")))
	_vis.clear()
	Fx.clear_all()
	_state(GameState.player)
	for e in GameState.enemies:
		_state(e)

func _on_entity_moved(entity: Entity, from: Vector2i, to: Vector2i) -> void:
	var s: VisState = _state(entity)
	if AISystem.chebyshev(from, to) > 1:   # teleport: no slide across the map
		s.pos = tile_center(to)
		if entity == GameState.player:
			Fx.burst(tile_center(from), Color("c38bff"), 18, 140.0, 3.0, 0.5)
			Fx.burst(tile_center(to), Color("c38bff"), 18, 140.0, 3.0, 0.5)
			Fx.ring(tile_center(to), Color("e2c8ff"), _ts * 1.2, 0.4, 3.0)
	elif entity == GameState.player:
		Sfx.play("step", 0.15, -10.0)

func _on_entity_attacked(attacker: Entity, target: Entity, damage: int, crit: bool) -> void:
	var a: VisState = _state(attacker)
	var t: VisState = _state(target)
	if AISystem.chebyshev(attacker.grid_pos, target.grid_pos) <= 1:
		a.lunge = (tile_center(target.grid_pos) - tile_center(attacker.grid_pos)).normalized() * _ts * 0.38
	t.flash = 1.0
	var at: Vector2 = tile_center(target.grid_pos)
	if target == GameState.player:
		Fx.text(at + Vector2(0, -18), "-%d" % damage, Color("ff6b6b"), 20, 0.9)
		Fx.burst(at, Color("ff5d5d"), 8, 110.0, 2.5, 0.35)
		GameCamera.add_trauma(0.22 + 0.5 * float(damage) / float(maxi(GameState.player.hp_max, 1)))
		Sfx.play("hurt", 0.08)
	else:
		var col: Color = Color("ffd34d") if crit else Color.WHITE
		Fx.text(at + Vector2(0, -18), ("%d!" if crit else "%d") % damage, col, 24 if crit else 18, 0.8)
		Fx.burst(at, target.color.lightened(0.3), 10 if crit else 6, 150.0 if crit else 100.0, 2.5, 0.35)
		if crit:
			GameCamera.add_trauma(0.25)
			Fx.ring(at, Color("ffd34d"), _ts * 0.9, 0.3, 3.0)
		Sfx.play("crit" if crit else "hit", 0.1)

func _on_entity_died(entity: Entity) -> void:
	var at: Vector2 = tile_center(entity.grid_pos)
	Fx.burst(at, entity.color, 22, 190.0, 3.5, 0.6)
	Fx.burst(at, Color.WHITE, 8, 120.0, 2.0, 0.25)
	Fx.ring(at, entity.color.lightened(0.3), _ts * 1.1, 0.35, 3.0)
	var enemy: EnemyEntity = entity as EnemyEntity
	if enemy != null and enemy.is_boss:
		GameCamera.add_trauma(0.8)
		Fx.burst(at, Color("ffd34d"), 40, 260.0, 4.0, 1.0, 200.0)
	Sfx.play("kill", 0.1)
	_vis.erase(entity)

func _on_projectile_fired(from: Vector2i, to: Vector2i, color: Color) -> void:
	Fx.tracer(tile_center(from), tile_center(to), color.lightened(0.3), 3.0, 0.22)
	Sfx.play("shoot", 0.1)

func _on_enemy_alerted(enemy: EnemyEntity) -> void:
	var at: Vector2 = tile_center(enemy.grid_pos)
	Fx.text(at + Vector2(0, -24), "!", Color("ffd34d") if not enemy.is_boss else Color("ff5d5d"), 28, 0.9)
	_state(enemy).flash = 0.6
	if enemy.is_boss:
		GameCamera.add_trauma(0.5)
		Sfx.play("boss", 0.0)
	else:
		Sfx.play("alert", 0.05)

func _on_item_picked(item: Dictionary, pos: Vector2i) -> void:
	var at: Vector2 = tile_center(pos)
	var col := Color("#" + str(item.get("color", "ffffff")))
	Fx.burst(at, col, 12, 110.0, 2.5, 0.5)
	Fx.text(at + Vector2(0, -20), ItemDatabase.display_name(item), col.lightened(0.3), 15, 1.0)
	if bool(item.get("instant", false)):
		Fx.ring(at, col, _ts * 1.0, 0.45, 3.0)
		Sfx.play("upgrade", 0.0)
	else:
		Sfx.play("pickup", 0.05)

func _on_item_used(item: Dictionary, targets: Array) -> void:
	var at: Vector2 = player_draw_pos()
	match str(item.get("effect", "")):
		"heal_ratio":
			Fx.burst(at, Color("6be08a"), 18, 90.0, 3.0, 0.7)
			Fx.ring(at, Color("6be08a"), _ts, 0.4, 3.0)
			Sfx.play("potion", 0.0)
		"energy":
			Fx.burst(at, Color("ffc46b"), 12, 70.0, 3.0, 0.6)
			Sfx.play("eat", 0.05)
		"thunder":
			for p in targets:
				var to: Vector2 = tile_center(p as Vector2i)
				Fx.tracer(at + Vector2(0, -_ts * 3.0), to, Color("9fd8ff"), 6.0, 0.35)
				Fx.tracer(at, to, Color("dff3ff"), 3.0, 0.25)
			GameCamera.add_trauma(0.45)
			Sfx.play("thunder", 0.0)
		"blink":
			Sfx.play("blink", 0.0)
		"reveal":
			Fx.ring(at, Color("e8d9a8"), _ts * 6.0, 0.8, 3.0)
			Sfx.play("map", 0.0)

func _on_spell_hit(target: Entity, damage: int) -> void:
	var at: Vector2 = tile_center(target.grid_pos)
	_state(target).flash = 1.0
	Fx.text(at + Vector2(0, -18), "%d" % damage, Color("9fd8ff"), 20, 0.8)
	Fx.burst(at, Color("9fd8ff"), 10, 140.0, 2.5, 0.4)

func _on_player_leveled(level: int) -> void:
	var at: Vector2 = player_draw_pos()
	Fx.ring(at, Color("ffd34d"), _ts * 2.2, 0.6, 4.0)
	Fx.burst(at, Color("ffd34d"), 30, 170.0, 3.0, 0.9)
	Fx.text(at + Vector2(0, -34), StringManager.t("level_label", {value = level}).to_upper(), Color("ffd34d"), 22, 1.4)
	Sfx.play("levelup", 0.0)

func _on_wall_bumped(direction: Vector2i) -> void:
	_state(GameState.player).lunge = Vector2(direction) * _ts * 0.15
	Sfx.play("bump", 0.05, -6.0)

# ---------------------------------------------------------------------------
# Animation update
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if GameState.player == null:
		return
	var k: float = 1.0 - exp(-delta * 20.0)
	var live: Dictionary = {GameState.player: true}
	for e in GameState.enemies:
		live[e] = true
	for e in _vis.keys():
		if not live.has(e):
			_vis.erase(e)
			continue
		var s: VisState = _vis[e] as VisState
		var target: Vector2 = tile_center((e as Entity).grid_pos)
		if s.pos.distance_to(target) > _ts * 3.0:
			s.pos = target   # too far behind (fast key repeat): snap
		s.pos = s.pos.lerp(target, k)
		s.lunge = s.lunge.lerp(Vector2.ZERO, 1.0 - exp(-delta * 14.0))
		s.flash = maxf(s.flash - delta * 5.0, 0.0)
		s.spawn = minf(s.spawn + delta * 5.0, 1.0)
	queue_redraw()

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	var d: DungeonData = GameState.dungeon
	if d == null or GameState.player == null or GameState.visible.is_empty():
		return
	var view: Rect2 = _view_rect()
	var x0: int = maxi(int(view.position.x / _ts) - 1, 0)
	var y0: int = maxi(int(view.position.y / _ts) - 1, 0)
	var x1: int = mini(int(view.end.x / _ts) + 1, d.width - 1)
	var y1: int = mini(int(view.end.y / _ts) + 1, d.height - 1)
	var ppos: Vector2 = player_draw_pos()
	var flicker: float = 1.0 + 0.025 * sin(_time * 7.3) + 0.015 * sin(_time * 13.1 + 1.7)

	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var vis: bool = bool(GameState.visible[x][y])
			if not vis and not bool(d.explored[x][y]):
				continue
			var p := Vector2i(x, y)
			var light: float = _light_at(tile_center(p), ppos, flicker) if vis else 0.0
			var tile: DungeonData.TileType = d.get_tile(p)
			if tile == DungeonData.TileType.WALL:
				if d.is_wall_face(p):
					_draw_wall(p, vis, light)
			else:
				_draw_floor(p, vis, light)
				if tile == DungeonData.TileType.STAIRS_DOWN:
					_draw_stairs(p, vis, light)

	_draw_items(d, view)
	for e in GameState.enemies:
		if bool(GameState.visible[e.grid_pos.x][e.grid_pos.y]):
			_draw_enemy(e)
	var ps: VisState = _state(GameState.player)
	Sprites.draw_token(self, ps.pos + ps.lunge, _ts * 0.4, GameState.player.color, "@", ps.flash)
	_draw_hover(d)

func _view_rect() -> Rect2:
	var inv: Transform2D = get_canvas_transform().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * get_viewport_rect().size
	return Rect2(a, b - a)

## Torch light: 1 next to the player, fading with distance (quadratic).
## Example with fov_radius 8: 1.0 at 0 tiles, 0.84 at 4 tiles, 0.35 at 8.
func _light_at(world: Vector2, ppos: Vector2, flicker: float) -> float:
	var dist: float = world.distance_to(ppos) / (_fov * _ts)
	return clampf((1.0 - dist * dist * 0.65) * flicker, 0.35, 1.0)

## Lit tiles get brighter and warmer near the torch; remembered tiles are
## pulled toward a cold dark blue (readable, clearly "not live").
func _lit(base: Color, vis: bool, light: float) -> Color:
	if not vis:
		return base.lerp(FOG_TINT, 0.5)
	var k: float = 0.7 + 0.9 * light
	return base.lerp(_light, 0.16 * light) * Color(k, k, k)

func _draw_floor(p: Vector2i, vis: bool, light: float) -> void:
	var rect := Rect2(Vector2(p) * _ts, Vector2(_ts, _ts))
	var base: Color = _floor if (p.x + p.y) % 2 == 0 else _floor_alt
	draw_rect(rect, _lit(base, vis, light))
	# Deterministic speckles: same tile, same pattern, every frame
	var h: int = (p.x * 73856093) ^ (p.y * 19349663)
	if absi(h) % 5 == 0:
		var off := Vector2(float(absi(h) % 23) / 23.0, float(absi(h / 23) % 19) / 19.0) * (_ts - 10.0) + Vector2(5, 5)
		draw_circle(rect.position + off, 1.8, _lit(base.darkened(0.35), vis, light))
	if absi(h) % 7 == 0:
		var off2 := Vector2(float(absi(h / 7) % 17) / 17.0, float(absi(h / 11) % 13) / 13.0) * (_ts - 12.0) + Vector2(6, 6)
		draw_line(rect.position + off2, rect.position + off2 + Vector2(5, 2), _lit(base.lightened(0.12), vis, light), 1.0)

func _draw_wall(p: Vector2i, vis: bool, light: float) -> void:
	var rect := Rect2(Vector2(p) * _ts, Vector2(_ts, _ts))
	draw_rect(rect, _lit(_wall, vis, light))
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(_ts - 4, _ts * 0.55)), _lit(_wall_top, vis, light))
	# Front face toward a floor below: darker band = the wall has height
	if GameState.dungeon.is_walkable(p + Vector2i(0, 1)):
		draw_rect(Rect2(rect.position + Vector2(0, _ts * 0.62), Vector2(_ts, _ts * 0.38)), _lit(_wall.darkened(0.3), vis, light))
		draw_line(rect.position + Vector2(_ts * 0.33, _ts * 0.62), rect.position + Vector2(_ts * 0.33, _ts), _lit(_wall.darkened(0.45), vis, light), 1.0)
		draw_line(rect.position + Vector2(_ts * 0.72, _ts * 0.62), rect.position + Vector2(_ts * 0.72, _ts), _lit(_wall.darkened(0.45), vis, light), 1.0)

func _draw_stairs(p: Vector2i, vis: bool, light: float) -> void:
	var rect := Rect2(Vector2(p) * _ts, Vector2(_ts, _ts))
	if GameState.dungeon.is_last_floor:
		Sprites.draw_portal(self, rect.get_center(), _ts * 0.45, _time, 1.0 if vis else 0.4)
		return
	var col: Color = Color("ffd34d") if vis else Color("8a7a40")
	if vis:
		draw_circle(rect.get_center(), _ts * (0.6 + 0.06 * sin(_time * 3.0)), Color(1.0, 0.85, 0.3, 0.12 * light))
	Sprites.draw_stairs(self, rect, col.darkened(0.2 * (1.0 - light)))

func _draw_items(d: DungeonData, view: Rect2) -> void:
	for pos_v in d.items.keys():
		var pos: Vector2i = pos_v as Vector2i
		var center: Vector2 = tile_center(pos)
		if not view.grow(_ts).has_point(center):
			continue
		var vis: bool = bool(GameState.visible[pos.x][pos.y])
		if not vis and not bool(d.explored[pos.x][pos.y]):
			continue
		var item: Dictionary = d.items[pos_v]
		var col := Color("#" + str(item.get("color", "ffffff")))
		if vis:
			var bob: float = sin(_time * 3.0 + float(pos.x + pos.y)) * 2.0
			draw_circle(center, _ts * 0.42, Color(col, 0.12))
			Sprites.draw_item(self, str(item.get("shape", "")), col, center + Vector2(0, bob - 2), _ts * 0.62)
		else:
			Sprites.draw_item(self, str(item.get("shape", "")), col, center, _ts * 0.55, 0.35)

func _draw_enemy(e: EnemyEntity) -> void:
	var s: VisState = _state(e)
	var r: float = _ts * (0.47 if e.is_boss else 0.38) * (0.4 + 0.6 * s.spawn)
	var at: Vector2 = s.pos + s.lunge
	if e.is_boss:
		draw_arc(at, r + 4.0, 0.0, TAU, 28, Color(1.0, 0.8, 0.3, 0.5 + 0.3 * sin(_time * 4.0)), 2.0, true)
	Sprites.draw_token(self, at, r, e.color, e.glyph, s.flash)
	if e.hp < e.hp_max:
		var w: float = _ts * 0.8
		var bar := Rect2(at + Vector2(-w * 0.5, -r - 9.0), Vector2(w, 4.0))
		draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bar.position, Vector2(w * float(e.hp) / float(e.hp_max), 4.0)), Color("ff5d5d"))
	if not e.alerted:
		var font: Font = ThemeDB.fallback_font
		var zy: float = fmod(_time * 0.8 + float(e.grid_pos.x) * 0.37, 1.0)
		draw_string(font, at + Vector2(r * 0.6, -r - zy * 10.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.8, 0.85, 1.0, 0.8 * (1.0 - zy)))

func _draw_hover(d: DungeonData) -> void:
	if not d.in_bounds(hover_tile):
		return
	var rect := Rect2(Vector2(hover_tile) * _ts, Vector2(_ts, _ts))
	draw_rect(rect.grow(-1.0), Color(1, 1, 1, 0.5 + 0.2 * sin(_time * 5.0)), false, 1.5)

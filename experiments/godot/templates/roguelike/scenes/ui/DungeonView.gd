# =============================================================================
# DungeonView.gd (Node2D): dungeon renderer and animation layer.
# =============================================================================
# Reads GameState data; never changes it.
#
# LOGIC IS INSTANT, VISUALS CATCH UP:
#   GameState resolves a whole turn in one call. This view keeps, for each
#   actor, a visual state (VisState): drawn position, lunge offset, hit
#   flash, hop. Each frame the drawn position eases toward the logical grid
#   position (exponential smoothing): moves slide with a little hop instead
#   of jumping, and the event signals (entity_attacked, key_dropped...)
#   trigger lunges, flashes, particles, sounds and screen shake. The player
#   can keep pressing keys: animations never block input.
#
# PIXEL ART: tiles (TileArt) and sprites (PixelArt) are 16 x 16 textures
#   drawn at 32 x 32 with nearest filtering (texture_filter on this node).
#   Sprite positions are rounded to whole pixels so they stay crisp.
#
# LIGHT: every visible tile is tinted by two light sources, the player's
#   torch (falls off with distance) and the wall torches of the floor (a
#   light map computed once per floor, blocked by walls). Explored tiles out
#   of sight are drawn in a cold dark blue: you remember the layout, not
#   what moves in it.
#
# DRAWING LAYERS (back to front), only tiles inside the camera view:
#   1. floor tiles with contact shadows under walls, wall tops and fronts,
#      wall torches with their glow
#   2. stairs and their grille (or the exit portal), decor bones, the
#      thief's footprints, skeleton remains, barrels, items on the ground
#   3. actors sorted by height (the lower one in front): shadow, sprite,
#      health bar, "z" when unaware, key above the key carrier
#   4. dagger in flight, aim reticle, the jingling-keys hint around the
#      player, the hovered-tile outline
# =============================================================================

class_name DungeonView
extends Node2D

class VisState:
	var pos:    Vector2 = Vector2.ZERO
	var lunge:  Vector2 = Vector2.ZERO
	var flash:  float   = 0.0
	var spawn:  float   = 0.0
	var hop:    float   = 0.0
	var squash: float   = 0.0
	var phase:  float   = 0.0

class Missile:
	var from:   Vector2
	var to:     Vector2
	var t:      float = 0.0
	var dur:    float = 0.14

var hover_tile: Vector2i = Vector2i(-1, -1)

const MEMORY := Color(0.24, 0.27, 0.4)
const GOLD := Color("ffd34d")
const BONE := Color("e8e4d8")
const ANIM_FPS: Dictionary = {"bat": 9.0, "slime": 3.0}

var _ts:    float = 32.0
var _vis:   Dictionary = {}   # Entity -> VisState
var _time:  float = 0.0
var _fov:   float = 8.0
var _tiles: TileArt = TileArt.new()
var _light: Color = Color("ffd9a6")
var _torch_map: PackedFloat32Array = PackedFloat32Array()
var _grille_open: float = 0.0
var _grille_shake: float = 0.0
var _missiles: Array[Missile] = []
var _hint_dir: Vector2 = Vector2.RIGHT
var _hint_alpha: float = 0.0
var _aim: EnemyEntity = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ts = float(ConfigManager.get_int("tile_size", 32))
	_fov = float(ConfigManager.get_int("fov_radius", 8))
	GameState.dungeon_ready.connect(_on_dungeon_ready)
	GameState.turn_ended.connect(_on_turn_ended)
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
	GameState.key_dropped.connect(_on_key_dropped)
	GameState.key_picked.connect(_on_key_picked)
	GameState.stairs_unlocked.connect(_on_stairs_unlocked)
	GameState.stairs_refused.connect(_on_stairs_refused)
	GameState.dagger_thrown.connect(_on_dagger_thrown)
	GameState.dagger_dodged.connect(_on_dagger_dodged)
	GameState.barrel_broken.connect(_on_barrel_broken)
	GameState.enemy_split.connect(_on_enemy_split)
	GameState.bones_crushed.connect(_on_bones_crushed)
	GameState.skeleton_rose.connect(_on_skeleton_rose)
	GameState.thief_panicked.connect(_on_thief_panicked)
	GameState.thief_tired.connect(_on_thief_tired)
	GameState.keys_heard.connect(_on_keys_heard)

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
		s.spawn = 1.0
		s.phase = randf() * 10.0
		_vis[e] = s
	return _vis[e] as VisState

# ---------------------------------------------------------------------------
# Events -> animation
# ---------------------------------------------------------------------------

func _on_dungeon_ready() -> void:
	var d: DungeonData = GameState.dungeon
	var theme: Dictionary = ConfigManager.get_floor_theme(GameState.current_floor)
	_light = Color("#" + str(theme.get("light", "ffd9a6")))
	_tiles.build(theme, GameState.current_floor * 7919 + 17)
	_build_torch_map(d)
	_grille_open = 0.0 if d.stairs_locked else 1.0
	_grille_shake = 0.0
	_missiles.clear()
	_hint_alpha = 0.0
	_vis.clear()
	Fx.clear_all()
	_state(GameState.player)
	for e in GameState.enemies:
		_state(e)
	_on_turn_ended()

## Light of the wall torches, per cell: (1 - d / r)^1.4 within the radius,
## only where the torch has a line of sight (light does not cross walls).
func _build_torch_map(d: DungeonData) -> void:
	_torch_map = PackedFloat32Array()
	_torch_map.resize(d.width * d.height)
	var r: float = ConfigManager.get_float("torch_light_radius", 4.5)
	var ri: int = ceili(r)
	for t in d.torches:
		var origin: Vector2i = t + Vector2i(0, 1)
		for dx in range(-ri, ri + 1):
			for dy in range(0, ri + 1):
				var p: Vector2i = origin + Vector2i(dx, dy)
				if not d.in_bounds(p) or not d.is_open(p):
					continue
				var dist: float = Vector2(dx, dy + 0.4).length()
				if dist > r or not FOVSystem.has_los(d, origin, p):
					continue
				var v: float = pow(1.0 - dist / r, 1.4)
				var i: int = p.y * d.width + p.x
				_torch_map[i] = maxf(_torch_map[i], v)
		# the wall itself and its neighbours glow too
		for dx in range(-1, 2):
			var w: Vector2i = t + Vector2i(dx, 0)
			if d.in_bounds(w):
				_torch_map[w.y * d.width + w.x] = maxf(_torch_map[w.y * d.width + w.x], 0.8 - absi(dx) * 0.3)

func _on_turn_ended() -> void:
	_aim = null
	if GameState.player != null and GameState.player.daggers > 0 and GameState.dungeon != null:
		_aim = GameState.best_throw_target()

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
		if randf() < 0.35:
			Fx.burst(tile_center(from) + Vector2(0, _ts * 0.35), Color(0.75, 0.75, 0.85, 0.5), 3, 25.0, 2.0, 0.35, -20.0)

func _on_entity_attacked(attacker: Entity, target: Entity, damage: int, crit: bool) -> void:
	var a: VisState = _state(attacker)
	var t: VisState = _state(target)
	if AISystem.chebyshev(attacker.grid_pos, target.grid_pos) <= 1:
		a.lunge = (tile_center(target.grid_pos) - tile_center(attacker.grid_pos)).normalized() * _ts * 0.4
		a.squash = -0.6
	t.flash = 1.0
	t.squash = 0.8
	t.lunge += (tile_center(target.grid_pos) - tile_center(attacker.grid_pos)).normalized() * _ts * 0.12
	var at: Vector2 = tile_center(target.grid_pos)
	if target == GameState.player:
		Fx.text(at + Vector2(0, -24), "-%d" % damage, Color("ff6b6b"), 20, 0.9)
		Fx.burst(at, Color("ff5d5d"), 8, 110.0, 2.5, 0.35, 160.0)
		GameCamera.add_trauma(0.22 + 0.5 * float(damage) / float(maxi(GameState.player.hp_max, 1)))
		Sfx.play("hurt", 0.08)
	else:
		var col: Color = GOLD if crit else Color.WHITE
		Fx.text(at + Vector2(0, -24), ("%d!" if crit else "%d") % damage, col, 24 if crit else 18, 0.8)
		Fx.burst(at, target.color.lightened(0.3), 12 if crit else 7, 160.0 if crit else 110.0, 2.5, 0.4, 220.0)
		if crit:
			GameCamera.add_trauma(0.25)
			Fx.ring(at, GOLD, _ts * 0.9, 0.3, 3.0)
		else:
			GameCamera.add_trauma(0.06)
		Sfx.play("crit" if crit else "hit", 0.1)

func _on_entity_died(entity: Entity) -> void:
	var at: Vector2 = tile_center(entity.grid_pos)
	var enemy: EnemyEntity = entity as EnemyEntity
	var col: Color = entity.color
	Fx.burst(at, col, 24, 200.0, 3.5, 0.7, 260.0)
	Fx.burst(at, Color.WHITE, 8, 120.0, 2.0, 0.25)
	Fx.ring(at, col.lightened(0.3), _ts * 1.1, 0.35, 3.0)
	if enemy != null and enemy.revives:
		Fx.burst(at, BONE, 14, 150.0, 3.0, 0.6, 300.0)
	if enemy != null and enemy.is_boss:
		GameCamera.add_trauma(0.8)
		Fx.burst(at, GOLD, 40, 260.0, 4.0, 1.0, 200.0)
	else:
		GameCamera.add_trauma(0.12)
	Sfx.play("kill", 0.1)
	_vis.erase(entity)

func _on_projectile_fired(from: Vector2i, to: Vector2i, color: Color) -> void:
	Fx.tracer(tile_center(from), tile_center(to), color.lightened(0.3), 3.0, 0.22)
	Sfx.play("shoot", 0.1)

func _on_enemy_alerted(enemy: EnemyEntity) -> void:
	var at: Vector2 = tile_center(enemy.grid_pos)
	Fx.text(at + Vector2(0, -34), "!", GOLD if not enemy.is_boss else Color("ff5d5d"), 28, 0.9)
	var s: VisState = _state(enemy)
	s.flash = 0.6
	s.squash = -0.8
	if enemy.is_boss:
		GameCamera.add_trauma(0.5)
		Sfx.play("boss", 0.0)
	else:
		Sfx.play("alert", 0.05)

func _on_item_picked(item: Dictionary, pos: Vector2i) -> void:
	var at: Vector2 = tile_center(pos)
	var col := Color("#" + str(item.get("color", "ffffff")))
	Fx.burst(at, col, 12, 110.0, 2.5, 0.5)
	_state(GameState.player).squash = -0.5
	if str(item.get("effect", "")) == "dagger":
		Fx.text(at + Vector2(0, -26), "+1", col.lightened(0.3), 14, 0.7)
		Sfx.play("pickup", 0.05)
		return
	Fx.text(at + Vector2(0, -26), ItemDatabase.display_name(item), col.lightened(0.3), 15, 1.0)
	if bool(item.get("instant", false)):
		Fx.ring(at, col, _ts * 1.0, 0.45, 3.0)
		Sfx.play("upgrade", 0.0)
	else:
		Sfx.play("pickup", 0.05)

func _on_item_used(item: Dictionary, targets: Array) -> void:
	var at: Vector2 = player_draw_pos()
	match str(item.get("effect", "")):
		"heal_ratio":
			Fx.burst(at, Color("6be08a"), 18, 90.0, 3.0, 0.7, -60.0)
			Fx.ring(at, Color("6be08a"), _ts, 0.4, 3.0)
			Sfx.play("potion", 0.0)
		"energy":
			Fx.burst(at, Color("ffc46b"), 12, 70.0, 3.0, 0.6, 120.0)
			Sfx.play("eat", 0.05)
		"thunder":
			for p in targets:
				var to: Vector2 = tile_center(p as Vector2i)
				Fx.tracer(to + Vector2(randf_range(-20, 20), -_ts * 5.0), to, Color("9fd8ff"), 6.0, 0.35)
				Fx.tracer(at, to, Color("dff3ff"), 3.0, 0.25)
				Fx.burst(to, Color("dff3ff"), 10, 150.0, 2.5, 0.4)
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
	Fx.text(at + Vector2(0, -24), "%d" % damage, Color("9fd8ff"), 20, 0.8)
	Fx.burst(at, Color("9fd8ff"), 10, 140.0, 2.5, 0.4)

func _on_player_leveled(level: int) -> void:
	var at: Vector2 = player_draw_pos()
	Fx.ring(at, GOLD, _ts * 2.2, 0.6, 4.0)
	Fx.burst(at, GOLD, 30, 170.0, 3.0, 0.9, -40.0)
	Fx.text(at + Vector2(0, -44), StringManager.t("level_label", {value = level}).to_upper(), GOLD, 22, 1.4)
	Sfx.play("levelup", 0.0)

func _on_wall_bumped(direction: Vector2i) -> void:
	_state(GameState.player).lunge = Vector2(direction) * _ts * 0.15
	Sfx.play("bump", 0.05, -6.0)

func _on_key_dropped(pos: Vector2i) -> void:
	if not GameState.dungeon.in_bounds(pos):
		return
	var at: Vector2 = tile_center(pos)
	Fx.tracer(at + Vector2(0, -_ts * 4.0), at, Color(1.0, 0.85, 0.3, 0.8), 5.0, 0.6)
	Fx.ring(at, GOLD, _ts * 1.6, 0.6, 3.0)
	Fx.burst(at, GOLD, 26, 170.0, 3.0, 0.8, 200.0)
	Fx.text(at + Vector2(0, -30), StringManager.t("key_name"), GOLD, 20, 1.4)
	GameCamera.add_trauma(0.2)
	Sfx.play("key", 0.0)

func _on_key_picked(pos: Vector2i) -> void:
	var at: Vector2 = tile_center(pos)
	Fx.ring(at, GOLD, _ts * 2.4, 0.7, 4.0)
	Fx.burst(at, GOLD, 34, 200.0, 3.0, 0.9, -30.0)
	_state(GameState.player).squash = -0.9
	GameCamera.add_trauma(0.18)
	Sfx.play("key", 0.0, 2.0)

func _on_stairs_unlocked(pos: Vector2i) -> void:
	var at: Vector2 = tile_center(pos)
	Fx.burst(at, GOLD, 30, 180.0, 3.0, 0.8, 160.0)
	Fx.burst(at, Color("8a8fa0"), 14, 120.0, 2.5, 0.6, 300.0)
	Fx.ring(at, GOLD, _ts * 2.0, 0.6, 3.0)
	GameCamera.add_trauma(0.3)
	Sfx.play("unlock", 0.0)

func _on_stairs_refused(_pos: Vector2i) -> void:
	_grille_shake = 1.0
	Sfx.play("locked", 0.05)

func _on_dagger_thrown(from: Vector2i, to: Vector2i) -> void:
	var m := Missile.new()
	m.from = tile_center(from)
	m.to = tile_center(to)
	m.dur = 0.06 + 0.025 * float(AISystem.chebyshev(from, to))
	_missiles.append(m)
	_state(GameState.player).lunge = (m.to - m.from).normalized() * _ts * 0.2
	Sfx.play("throw", 0.08)

func _on_dagger_dodged(enemy: EnemyEntity) -> void:
	var s: VisState = _state(enemy)
	s.lunge = Vector2(0, -_ts * 0.35)
	s.squash = -0.7
	Fx.text(tile_center(enemy.grid_pos) + Vector2(0, -30), StringManager.t("dodge_label"), Color("c7a8ff"), 16, 0.8)

func _on_barrel_broken(pos: Vector2i) -> void:
	var at: Vector2 = tile_center(pos)
	Fx.burst(at, Color("8a5a32"), 18, 170.0, 3.5, 0.6, 420.0)
	Fx.burst(at, Color("c08850"), 10, 120.0, 2.5, 0.5, 380.0)
	Fx.burst(at, Color("7d8794"), 4, 90.0, 2.5, 0.5, 380.0)
	_state(GameState.player).lunge = Vector2(pos - GameState.player.grid_pos) * _ts * 0.3
	GameCamera.add_trauma(0.14)
	Sfx.play("barrel", 0.1)

func _on_enemy_split(child: EnemyEntity, from: Vector2i) -> void:
	var s: VisState = _state(child)
	s.pos = tile_center(from)
	s.spawn = 0.2
	s.squash = 0.8
	Fx.burst(tile_center(from), child.color, 14, 120.0, 3.0, 0.5, 200.0)
	Sfx.play("split", 0.1)

func _on_bones_crushed(pos: Vector2i) -> void:
	Fx.burst(tile_center(pos) + Vector2(0, _ts * 0.2), BONE, 16, 120.0, 2.5, 0.5, 340.0)
	Sfx.play("crush", 0.1)

func _on_skeleton_rose(enemy: EnemyEntity) -> void:
	var s: VisState = _state(enemy)
	s.spawn = 0.0
	s.flash = 1.0
	var at: Vector2 = tile_center(enemy.grid_pos)
	Fx.burst(at, BONE, 18, 140.0, 3.0, 0.6, -80.0)
	Fx.ring(at, Color("b6ff9e"), _ts * 1.3, 0.5, 3.0)
	Sfx.play("rise", 0.05)

func _on_thief_panicked(t: EnemyEntity) -> void:
	Fx.text(tile_center(t.grid_pos) + Vector2(0, -34), "!", Color("c7a8ff"), 28, 0.9)
	_state(t).squash = -0.8
	Sfx.play("panic", 0.05)

func _on_thief_tired(t: EnemyEntity) -> void:
	Fx.text(tile_center(t.grid_pos) + Vector2(0, -34), "...", Color("c7a8ff"), 22, 1.2)
	Sfx.play("pant", 0.05)

func _on_keys_heard(strength: float) -> void:
	Sfx.play("jingle", 0.06, lerpf(-20.0, -4.0, strength))

# ---------------------------------------------------------------------------
# Animation update
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if GameState.player == null or GameState.dungeon == null:
		return
	var k: float = 1.0 - exp(-delta * 18.0)
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
		var before: float = s.pos.distance_to(target)
		s.pos = s.pos.lerp(target, k)
		var left: float = clampf(s.pos.distance_to(target) / _ts, 0.0, 1.0)
		s.hop = sin(left * PI) if before > 0.5 else 0.0
		if before > 2.0 and s.pos.distance_to(target) <= 2.0:
			s.squash = 0.45   # landing
		s.lunge = s.lunge.lerp(Vector2.ZERO, 1.0 - exp(-delta * 14.0))
		s.flash = maxf(s.flash - delta * 5.0, 0.0)
		s.spawn = minf(s.spawn + delta * 4.0, 1.0)
		s.squash = lerpf(s.squash, 0.0, 1.0 - exp(-delta * 12.0))
	var d: DungeonData = GameState.dungeon
	_grille_open = move_toward(_grille_open, 0.0 if d.stairs_locked else 1.0, delta * 1.6)
	_grille_shake = maxf(_grille_shake - delta * 3.0, 0.0)
	for m in _missiles.duplicate():
		m.t += delta / m.dur
		if m.t >= 1.0:
			_missiles.erase(m)
			Fx.burst(m.to, Color("dfe6ee"), 6, 90.0, 2.0, 0.25)
	if GameState.key_hint != Vector2.ZERO:
		_hint_dir = _hint_dir.slerp(GameState.key_hint, 1.0 - exp(-delta * 8.0)).normalized()
		_hint_alpha = move_toward(_hint_alpha, 0.35 + 0.65 * GameState.key_hint_strength, delta * 3.0)
	else:
		_hint_alpha = move_toward(_hint_alpha, 0.0, delta * 3.0)
	_spawn_embers(delta)
	queue_redraw()

## A few sparks rise from the visible wall torches.
func _spawn_embers(delta: float) -> void:
	var d: DungeonData = GameState.dungeon
	for t in d.torches:
		if not bool(GameState.visible[t.x][t.y]) or randf() > delta * 1.6:
			continue
		var flame: Vector2 = Vector2(t) * _ts + Vector2(_ts * 0.5, _ts * 0.42)
		Fx.burst(flame, _light.lightened(0.2), 1, 18.0, 1.6, 0.9, -45.0)

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
	var flick: float = 1.0 + 0.03 * sin(_time * 7.3) + 0.02 * sin(_time * 13.1 + 1.7)
	var tflick: float = 1.0 + 0.06 * sin(_time * 9.7) + 0.04 * sin(_time * 21.3 + 0.6)

	# 1. tiles
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var vis: bool = bool(GameState.visible[x][y])
			if not vis and not bool(d.explored[x][y]):
				continue
			var p := Vector2i(x, y)
			var rect := Rect2(Vector2(p) * _ts, Vector2(_ts, _ts))
			var mod: Color = _tile_mod(p, vis, ppos, flick, tflick)
			var tile: DungeonData.TileType = d.get_tile(p)
			if tile == DungeonData.TileType.WALL:
				if d.is_open(p + Vector2i(0, 1)):
					draw_texture_rect(_tiles.get_texture("wall_front"), rect, false, mod)
				elif d.is_wall_face(p):
					draw_texture_rect(_tiles.get_texture("wall_top"), rect, false, mod)
				continue
			draw_texture_rect(_tiles.get_texture("floor_%d" % _floor_variant(p)), rect, false, mod)
			_draw_contact_shadow(d, p, rect)
			if tile == DungeonData.TileType.STAIRS_DOWN:
				_draw_stairs(d, p, rect, vis, mod)
	for t in d.torches:
		if t.x >= x0 and t.x <= x1 and t.y >= y0 and t.y <= y1 and bool(d.explored[t.x][t.y]):
			_draw_torch(t, bool(GameState.visible[t.x][t.y]), tflick)

	# 2. things on the floor
	_draw_floor_things(d, view, ppos, flick, tflick)

	# 3. actors, the lower one in front
	var actors: Array = []
	for e in GameState.enemies:
		if bool(GameState.visible[e.grid_pos.x][e.grid_pos.y]):
			actors.append(e)
	actors.append(GameState.player)
	actors.sort_custom(func(a, b): return _state(a).pos.y < _state(b).pos.y)
	for a in actors:
		_draw_actor(a as Entity, ppos, flick, tflick)

	# 4. overlays
	for m in _missiles:
		_draw_missile(m)
	_draw_aim()
	_draw_key_hint()
	_draw_hover(d)

func _view_rect() -> Rect2:
	var inv: Transform2D = get_canvas_transform().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * get_viewport_rect().size
	return Rect2(a, b - a)

func _floor_variant(p: Vector2i) -> int:
	var h: int = absi((p.x * 73856093) ^ (p.y * 19349663)) % 20
	if h < 9:
		return 0
	if h < 15:
		return 1
	if h < 19:
		return 2
	return 3

## Light at a cell (0..~1.2): torch of the player, wall torches, a little
## of both adding up where they overlap.
func _light_value(p: Vector2i, ppos: Vector2, flick: float, tflick: float) -> float:
	var dist: float = tile_center(p).distance_to(ppos) / (_fov * _ts)
	var lp: float = clampf(1.0 - dist * dist * 0.8, 0.22, 1.0) * flick
	var lt: float = 0.0
	if not _torch_map.is_empty():
		lt = _torch_map[p.y * GameState.dungeon.width + p.x] * tflick
	return clampf(maxf(lp, lt) + minf(lp, lt) * 0.3, 0.0, 1.2)

func _tile_mod(p: Vector2i, vis: bool, ppos: Vector2, flick: float, tflick: float) -> Color:
	if not vis:
		return MEMORY
	var l: float = _light_value(p, ppos, flick, tflick)
	var lt: float = 0.0
	if not _torch_map.is_empty():
		lt = _torch_map[p.y * GameState.dungeon.width + p.x]
	var c: Color = Color.WHITE.lerp(_light, clampf(0.12 + lt * 0.45, 0.0, 0.6))
	var k: float = 0.38 + 0.78 * l
	return Color(c.r * k, c.g * k, c.b * k)

## Walls cast a short shadow on the floor below and to their right: the
## floor reads as lower than the walls.
func _draw_contact_shadow(d: DungeonData, p: Vector2i, rect: Rect2) -> void:
	if not d.is_open(p + Vector2i(0, -1)):
		draw_rect(Rect2(rect.position, Vector2(_ts, 6)), Color(0, 0, 0, 0.32))
		draw_rect(Rect2(rect.position + Vector2(0, 6), Vector2(_ts, 4)), Color(0, 0, 0, 0.14))
	if not d.is_open(p + Vector2i(-1, 0)):
		draw_rect(Rect2(rect.position, Vector2(4, _ts)), Color(0, 0, 0, 0.22))

func _draw_stairs(d: DungeonData, p: Vector2i, rect: Rect2, vis: bool, mod: Color) -> void:
	if d.is_last_floor:
		Sprites.draw_portal(self, rect.get_center(), _ts * 0.45, _time, 1.0 if vis else 0.4)
	else:
		if vis and not d.stairs_locked:
			draw_circle(rect.get_center(), _ts * (0.62 + 0.06 * sin(_time * 3.0)), Color(1.0, 0.85, 0.3, 0.14))
		draw_texture_rect(PixelArt.texture("stairs"), rect, false, mod)
	if _grille_open >= 1.0:
		return
	var shake: float = sin(_time * 70.0) * 3.0 * _grille_shake
	var lift: float = _grille_open * _grille_open * _ts * 0.8
	var g := Rect2(rect.position + Vector2(shake, -lift), rect.size)
	var gm: Color = mod if vis else MEMORY
	draw_texture_rect(PixelArt.texture("grille"), g, false, Color(gm, 1.0 - _grille_open))
	# with the key in hand, the lock calls you
	if vis and GameState.player.has_key and d.stairs_locked:
		var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
		draw_circle(rect.get_center() + Vector2(0, 2), _ts * (0.3 + 0.1 * pulse), Color(1.0, 0.85, 0.3, 0.18 + 0.12 * pulse))

func _draw_torch(t: Vector2i, vis: bool, tflick: float) -> void:
	var rect := Rect2(Vector2(t) * _ts, Vector2(_ts, _ts))
	if vis:
		var flame: Vector2 = rect.position + Vector2(_ts * 0.5, _ts * 0.38)
		draw_circle(flame, _ts * 0.9 * tflick, Color(_light, 0.07))
		draw_circle(flame, _ts * 0.5 * tflick, Color(_light, 0.12))
		draw_texture_rect(PixelArt.texture("torch", int(_time * 7.0 + t.x) % 2), rect, false, Color.WHITE)
	else:
		draw_texture_rect(PixelArt.texture("torch", 0), rect, false, MEMORY)

func _draw_floor_things(d: DungeonData, view: Rect2, ppos: Vector2, flick: float, tflick: float) -> void:
	var area: Rect2 = view.grow(_ts)
	for pos_v in d.decor.keys():
		var pos: Vector2i = pos_v as Vector2i
		if area.has_point(tile_center(pos)) and bool(d.explored[pos.x][pos.y]) and not d.items.has(pos):
			var mod: Color = _tile_mod(pos, bool(GameState.visible[pos.x][pos.y]), ppos, flick, tflick)
			draw_texture_rect(PixelArt.texture("bones"), Rect2(Vector2(pos) * _ts, Vector2(_ts, _ts)), false, Color(mod * 0.8, 0.85))
	_draw_footprints(d, area)
	for pos_v in d.bone_piles.keys():
		var pos: Vector2i = pos_v as Vector2i
		if not area.has_point(tile_center(pos)) or not bool(GameState.visible[pos.x][pos.y]):
			continue
		var turns: int = int((d.bone_piles[pos_v] as Dictionary).get("turns", 9))
		var mod: Color = _tile_mod(pos, true, ppos, flick, tflick)
		var shake: float = sin(_time * 45.0) * (3.0 - turns) if turns <= 2 else 0.0
		var r := Rect2(Vector2(pos) * _ts + Vector2(shake, 0), Vector2(_ts, _ts))
		draw_texture_rect(PixelArt.texture("bones"), r, false, mod.lerp(Color("c8ffb0"), 0.25))
		var glow: float = 0.5 + 0.5 * sin(_time * (4.0 + 6.0 / maxf(turns, 1)))
		draw_circle(r.get_center() + Vector2(0, 4), _ts * 0.3, Color(0.6, 1.0, 0.55, 0.06 + 0.1 * glow))
	for pos_v in d.barrels.keys():
		var pos: Vector2i = pos_v as Vector2i
		if not area.has_point(tile_center(pos)) or not bool(d.explored[pos.x][pos.y]):
			continue
		var vis: bool = bool(GameState.visible[pos.x][pos.y])
		var mod: Color = _tile_mod(pos, vis, ppos, flick, tflick)
		var r := Rect2(Vector2(pos) * _ts, Vector2(_ts, _ts))
		draw_set_transform(r.get_center() + Vector2(0, _ts * 0.4), 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, _ts * 0.36, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_texture_rect(PixelArt.texture("barrel"), r, false, mod.lerp(Color.WHITE, 0.15) if vis else mod)
	for pos_v in d.items.keys():
		var pos: Vector2i = pos_v as Vector2i
		var center: Vector2 = tile_center(pos)
		if not area.has_point(center):
			continue
		var vis: bool = bool(GameState.visible[pos.x][pos.y])
		if not vis and not bool(d.explored[pos.x][pos.y]):
			continue
		var item: Dictionary = d.items[pos_v]
		var sprite: String = PixelArt.item_sprite(item)
		var col := Color("#" + str(item.get("color", "ffffff")))
		if vis:
			var bob: float = roundf(sin(_time * 3.0 + float(pos.x + pos.y)) * 2.0)
			draw_circle(center + Vector2(0, 4), _ts * 0.4, Color(col, 0.12))
			draw_set_transform(center + Vector2(0, _ts * 0.38), 0.0, Vector2(1.0, 0.3))
			draw_circle(Vector2.ZERO, _ts * (0.26 - bob * 0.01), Color(0, 0, 0, 0.3))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			PixelArt.draw(self, sprite, (center + Vector2(0, _ts * 0.5 - 4.0 + bob)).round(), _ts)
			if str(item.get("effect", "")) == "key":
				_draw_sparkle(center + Vector2(9, -9), fmod(_time * 1.3, 1.0))
				_draw_sparkle(center + Vector2(-10, 2), fmod(_time * 1.3 + 0.5, 1.0))
		else:
			PixelArt.draw(self, sprite, center + Vector2(0, _ts * 0.5 - 4.0), _ts, 0, false, Color(MEMORY * 1.4, 0.8))

## The thief's tracks: pairs of pale prints that fade over footprint_turns
## turns. Only drawn where you can see.
func _draw_footprints(d: DungeonData, area: Rect2) -> void:
	var life: float = float(ConfigManager.get_int("footprint_turns", 40))
	for pos_v in d.footprints.keys():
		var pos: Vector2i = pos_v as Vector2i
		if not area.has_point(tile_center(pos)) or not bool(GameState.visible[pos.x][pos.y]):
			continue
		var fp: Dictionary = d.footprints[pos_v]
		var age: float = float(GameState.turn - int(fp.get("turn", 0)))
		if age > life:
			continue
		var a: float = 0.55 * (1.0 - age / life)
		var dir: Vector2 = Vector2(fp.get("dir", Vector2i.RIGHT) as Vector2i).normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var c: Vector2 = tile_center(pos)
		for i in 2:
			var s: float = -1.0 if i == 0 else 1.0
			var at: Vector2 = c + side * 4.5 * s + dir * (5.0 * s)
			draw_set_transform(at, dir.angle(), Vector2(1.0, 0.55))
			draw_circle(Vector2.ZERO, 3.6, Color(0.78, 0.66, 1.0, a))
			draw_circle(Vector2(3.8, 0), 1.6, Color(0.78, 0.66, 1.0, a))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_sparkle(at: Vector2, t: float) -> void:
	var a: float = sin(t * PI)
	var r: float = 2.0 + 4.0 * a
	var col := Color(1.0, 0.95, 0.7, a)
	draw_line(at - Vector2(r, 0), at + Vector2(r, 0), col, 1.5)
	draw_line(at - Vector2(0, r), at + Vector2(0, r), col, 1.5)

func _draw_actor(e: Entity, ppos: Vector2, flick: float, tflick: float) -> void:
	var s: VisState = _state(e)
	var id: String = e.sprite
	var size: float = maxf(roundf(_ts * PixelArt.scale_of(id) / 16.0) * 16.0, _ts)
	var foot: Vector2 = s.pos + s.lunge + Vector2(0, _ts * 0.44)
	var lift: float = s.hop * _ts * 0.16
	var appear: float = ease(s.spawn, -2.0)
	# shadow (stays on the ground during the hop)
	draw_set_transform(foot + Vector2(0, -2), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, size * 0.3 * (1.0 - s.hop * 0.2) * appear, Color(0, 0, 0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var cell: Vector2i = Vector2i((s.pos / _ts).floor())
	var mod: Color = Color.WHITE
	if GameState.dungeon.in_bounds(cell):
		var l: float = _light_value(cell, ppos, flick, tflick)
		var k: float = 0.62 + 0.45 * l
		mod = Color(k, k, k)
	var enemy: EnemyEntity = e as EnemyEntity
	if enemy != null and enemy.tired > 0:
		mod = mod.lerp(Color("9aa0c0"), 0.25)
	var fps: float = float(ANIM_FPS.get(id, 1.8))
	var frame: int = int(_time * fps + s.phase)
	var sx: float = (1.0 + s.squash * 0.18) * appear
	var sy: float = (1.0 - s.squash * 0.18) * appear
	var base: Vector2 = (foot - Vector2(0, lift)).round()
	draw_set_transform(base, 0.0, Vector2(sx, sy))
	PixelArt.draw(self, id, Vector2.ZERO, size, frame, e.facing < 0, mod, s.flash)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var head: Vector2 = base - Vector2(0, size * sy * (1.0 - PixelArt.headroom(id)) + 4.0)
	if enemy != null:
		_draw_enemy_marks(enemy, s, head, size)
	elif GameState.player.has_key:
		var bob: float = roundf(sin(_time * 4.0) * 2.0)
		PixelArt.draw_icon(self, "key", Rect2(head + Vector2(-8, -14 + bob), Vector2(16, 16)))

func _draw_enemy_marks(e: EnemyEntity, s: VisState, head: Vector2, size: float) -> void:
	if e.is_boss:
		draw_arc(head + Vector2(0, size * 0.55), size * 0.62, 0.0, TAU, 32,
			Color(1.0, 0.8, 0.3, 0.25 + 0.2 * sin(_time * 4.0)), 2.0, true)
	var y: float = head.y
	if e.hp < e.hp_max:
		var w: float = _ts * 0.75
		var bar := Rect2(Vector2(head.x - w * 0.5, y - 2.0), Vector2(w, 4.0))
		draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(bar.position, Vector2(w * float(e.hp) / float(e.hp_max), 4.0)), Color("ff5d5d"))
		y -= 8.0
	if e.key_carrier:
		var bob: float = roundf(sin(_time * 5.0 + s.phase) * 2.0)
		PixelArt.draw_icon(self, "key", Rect2(Vector2(head.x - 8, y - 16 + bob), Vector2(16, 16)))
		y -= 16.0
	if e.tired > 0:
		for i in 2:
			var t: float = fmod(_time * 1.4 + i * 0.5, 1.0)
			draw_circle(Vector2(head.x + 11 + i * 5, head.y + 6 + t * 10.0), 2.0, Color(0.6, 0.85, 1.0, 1.0 - t))
	elif not e.alerted and e.ai != "thief":
		var font: Font = ThemeDB.fallback_font
		var zy: float = fmod(_time * 0.8 + s.phase, 1.0)
		draw_string(font, Vector2(head.x + 8, y + 4 - zy * 10.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.8, 0.85, 1.0, 0.8 * (1.0 - zy)))

func _draw_missile(m: Missile) -> void:
	var t: float = clampf(m.t, 0.0, 1.0)
	var at: Vector2 = m.from.lerp(m.to, t) + Vector2(0, -sin(t * PI) * 6.0)
	var dir: Vector2 = (m.to - m.from).normalized()
	draw_line(at - dir * 18.0, at, Color(1, 1, 1, 0.25), 2.0)
	# the dagger sprite points up-right (-45 degrees)
	draw_set_transform(at.round(), dir.angle() + PI * 0.25, Vector2.ONE)
	PixelArt.draw(self, "dagger", Vector2(0, _ts * 0.5), _ts)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Reticle on the enemy a dagger would hit (hovered one first).
func _draw_aim() -> void:
	if GameState.player.daggers <= 0 or GameState.phase != GameState.Phase.PLAYER:
		return
	var target: EnemyEntity = _aim
	var d: DungeonData = GameState.dungeon
	if d.in_bounds(hover_tile) and GameState.enemy_positions.has(hover_tile):
		var h: EnemyEntity = GameState.enemy_positions[hover_tile] as EnemyEntity
		if GameState.can_throw_at(h):
			target = h
	if target == null or not GameState.enemies.has(target) or not _vis.has(target):
		return
	var c: Vector2 = _state(target).pos
	var r: float = _ts * 0.62 + sin(_time * 6.0) * 2.0
	var col: Color = GOLD if target.key_carrier else Color(1, 1, 1, 0.7)
	for i in 4:
		var a: float = i * TAU / 4.0 + PI * 0.25
		var corner: Vector2 = c + Vector2.from_angle(a) * r
		draw_line(corner, corner - Vector2.from_angle(a - PI * 0.25) * 7.0, col, 2.0)
		draw_line(corner, corner - Vector2.from_angle(a + PI * 0.25) * 7.0, col, 2.0)

## The jingling keys: a key and sound waves around the player, pointing
## where the thief is heard. Brighter when he is closer.
func _draw_key_hint() -> void:
	if _hint_alpha <= 0.01:
		return
	var c: Vector2 = player_draw_pos()
	var at: Vector2 = c + _hint_dir * _ts * 1.25
	var a: float = _hint_alpha
	for i in 3:
		var t: float = fmod(_time * 1.2 + i / 3.0, 1.0)
		var r: float = _ts * (0.4 + 0.5 * t)
		var ang: float = _hint_dir.angle()
		draw_arc(at, r, ang - 0.6, ang + 0.6, 10, Color(1.0, 0.85, 0.3, a * (1.0 - t) * 0.8), 2.0, true)
	var jig: float = sin(_time * 18.0) * 2.0
	PixelArt.draw_icon(self, "key", Rect2((at - Vector2(8, 8) + Vector2(jig, 0)).round(), Vector2(16, 16)), 0, Color(1, 1, 1, a))

func _draw_hover(d: DungeonData) -> void:
	if not d.in_bounds(hover_tile):
		return
	var rect := Rect2(Vector2(hover_tile) * _ts, Vector2(_ts, _ts))
	draw_rect(rect.grow(-1.0), Color(1, 1, 1, 0.5 + 0.2 * sin(_time * 5.0)), false, 1.5)

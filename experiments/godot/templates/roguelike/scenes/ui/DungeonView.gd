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
#   of jumping, dashes and knockbacks slide fast without a hop, and the
#   event signals (entity_attacked, keg_exploded...) trigger lunges,
#   flashes, particles, sounds, screen shake and a short hit-stop. The
#   player can keep pressing keys: animations never block input.
#
# PIXEL ART: tiles (TileArt) and sprites (PixelArt) are 16 x 16 textures
#   drawn at 32 x 32 with nearest filtering (texture_filter on this node).
#   Sprite positions are rounded to whole pixels so they stay crisp. Walls
#   are two cells tall: the face of a wall with floor below is drawn on its
#   cell (bricks) and on the cell above (capstone and bricks).
#
# LIGHT (the mood: cool indigo shadows, warm pools of light):
#   colour of a visible cell = ambient (theme, indigo)
#                            + static light x flicker of its main source
#                            + the player's lantern (falls off with distance)
#   The static light map is computed once per floor: wall torches, candles,
#   runes (and the exit portal), each with its colour, radius and a line of
#   sight test (light does not cross walls). Explored cells out of sight are
#   drawn in a darker indigo, with a trace of the static light.
#   Smooth shading: every tile is drawn as a quad whose four corners take
#   the average colour of the four cells around them (vertex colours), so
#   light fades across tiles instead of in steps. Actors take the colour
#   interpolated at their drawn position.
#   Batching: the quads are gathered per texture and sent as one triangle
#   array per texture (RenderingServer.canvas_item_add_triangle_array):
#   about fifteen calls a frame instead of one per tile. A first version
#   used draw_primitive with four points per tile; the quad came out split
#   along the wrong diagonal, with a dark wedge in every tile (2026-11-16).
#
# GLOW LAYER: a child Node2D with an additive material draws soft radial
#   halos (flames, runes, portal, items, lit kegs, dangers) and the embers
#   that drift up through the air.
#
# DRAWING LAYERS (back to front), only tiles inside the camera view:
#   1. floor tiles with contact shadows, wall faces and caps, stairs
#   2. torches and banners on the walls
#   3. bones, rubble, scorch marks, runes, candles, the thief's footprints,
#      skeleton remains, barrels and kegs, items on the ground
#   4. danger zones (heavy blows, arrow lines, keg blasts)
#   5. dash afterimages, then actors sorted by height (the lower one in
#      front): shadow, sprite, health bar, "z", stun stars, key
#   6. dagger in flight, aim reticle, the jingling-keys hint, hovered tile
#   7. glow layer (child node, additive)
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
	var fast:   bool    = false   # dash or knockback: quick slide, no hop

class Missile:
	var from:   Vector2
	var to:     Vector2
	var t:      float = 0.0
	var dur:    float = 0.14

class Ghost:
	var pos:      Vector2
	var life:     float
	var max_life: float
	var flip:     bool
	var frame:    int

class Batch:
	var tex:  RID
	var pts:  PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	var uvs:  PackedVector2Array = PackedVector2Array()
	var idx:  PackedInt32Array = PackedInt32Array()

class Ember:
	var pos:      Vector2
	var vel:      Vector2
	var life:     float
	var max_life: float
	var size:     float
	var col:      Color
	var sway:     float

var hover_tile: Vector2i = Vector2i(-1, -1)

const GOLD := Color("ffd34d")
const BONE := Color("e8e4d8")
const DANGER := Color("ff3b4e")
const BLAST := Color("ff8a2a")
const VOID := Color(0, 0, 0, 1)
const ANIM_FPS: Dictionary = {"bat": 9.0, "slime": 3.0, "candles": 6.0}
const MAX_EMBERS: int = 80
const HURT_COLORS: Dictionary = {impact = Color("ffad5e"), blast = Color("ff8a2a"), friendly = Color("d6f07a")}

var _ts:    float = 32.0
var _vis:   Dictionary = {}   # Entity -> VisState
var _time:  float = 0.0
var _tiles: TileArt = TileArt.new()
var _light: Color = Color("ff9c4c")     # torch colour of the floor
var _candle: Color = Color("ffb35c")
var _ambient: Color = Color("4c4e90")
var _memory: Color = Color(0.13, 0.13, 0.24)
var _lantern: Color = Color("ffc58a")
var _lantern_r: float = 176.0
var _lantern_k: float = 0.75
var _rune_col: Color = Color("a865ff")
var _static: PackedColorArray = PackedColorArray()   # static light per cell
var _src: PackedInt32Array = PackedInt32Array()      # main light source per cell (-1: none)
var _flick: PackedFloat32Array = PackedFloat32Array()  # flicker of each source, this frame
var _pflick: float = 1.0
var _grille_open: float = 0.0
var _grille_shake: float = 0.0
var _missiles: Array[Missile] = []
var _ghosts: Array[Ghost] = []
var _embers: Array[Ember] = []
var _ember_acc: float = 0.0
var _keg_slides: Dictionary = {}   # cell -> {from: Vector2, t: float}
var _scorch: Dictionary = {}       # cell -> strength (burn marks of blasts)
var _hint_dir: Vector2 = Vector2.RIGHT
var _hint_alpha: float = 0.0
var _aim: EnemyEntity = null
var _glow: Node2D = null
var _radial: Texture2D = null
var _uv: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
var _hitstop_until: int = 0
var _batches: Dictionary = {}   # texture RID -> Batch, filled then flushed each frame
# light window of the current frame: corner colours of the visible tiles
var _cx0: int = 0
var _cy0: int = 0
var _cw: int = 0
var _ch: int = 0
var _corners: PackedColorArray = PackedColorArray()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ts = float(ConfigManager.get_int("tile_size", 32))
	_lantern = Color("#" + ConfigManager.get_string("lantern_color", "ffc58a"))
	_lantern_r = ConfigManager.get_float("lantern_radius", 5.5) * _ts
	_lantern_k = ConfigManager.get_float("lantern_strength", 0.75)
	_radial = _make_radial()
	_glow = Node2D.new()
	_glow.name = "Glow"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_glow)
	_glow.draw.connect(_draw_glow)
	GameState.dungeon_ready.connect(_on_dungeon_ready)
	GameState.turn_ended.connect(_on_turn_ended)
	GameState.entity_moved.connect(_on_entity_moved)
	GameState.entity_attacked.connect(_on_entity_attacked)
	GameState.entity_hurt.connect(_on_entity_hurt)
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
	GameState.player_dashed.connect(_on_player_dashed)
	GameState.enemy_knocked.connect(_on_enemy_knocked)
	GameState.impact.connect(_on_impact)
	GameState.enemy_stunned.connect(_on_enemy_stunned)
	GameState.danger_marked.connect(_on_danger_marked)
	GameState.danger_struck.connect(_on_danger_struck)
	GameState.attack_interrupted.connect(_on_attack_interrupted)
	GameState.heavy_dodged.connect(_on_heavy_dodged)
	GameState.keg_lit.connect(_on_keg_lit)
	GameState.keg_slid.connect(_on_keg_slid)
	GameState.keg_exploded.connect(_on_keg_exploded)
	GameState.elan_changed.connect(_on_elan_changed)
	GameState.warden_enraged.connect(_on_warden_enraged)

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

## Soft white disc fading to transparent, tinted per halo.
func _make_radial() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.3, Color(1, 1, 1, 0.5))
	g.add_point(0.65, Color(1, 1, 1, 0.12))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t

## Freezes the animation for `seconds` (real time): impacts land harder.
func _hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	_hitstop_until = maxi(_hitstop_until, Time.get_ticks_msec() + int(seconds * 1000.0))

# ---------------------------------------------------------------------------
# Events -> animation
# ---------------------------------------------------------------------------

func _on_dungeon_ready() -> void:
	var d: DungeonData = GameState.dungeon
	var theme: Dictionary = ConfigManager.get_floor_theme(GameState.current_floor)
	_light = Color("#" + str(theme.get("light", "ff9c4c")))
	_candle = _light.lerp(Color("ffb35c"), 0.5)
	_ambient = Color("#" + str(theme.get("ambient", "4c4e90")))
	_memory = Color(_ambient.r * 0.3, _ambient.g * 0.3, _ambient.b * 0.36)
	_rune_col = Color("#" + str(theme.get("rune", "a865ff")))
	_tiles.build(theme, GameState.current_floor * 7919 + 17)
	_build_light_map(d)
	_grille_open = 0.0 if d.stairs_locked else 1.0
	_grille_shake = 0.0
	_missiles.clear()
	_ghosts.clear()
	_embers.clear()
	_keg_slides.clear()
	_scorch.clear()
	_hint_alpha = 0.0
	_vis.clear()
	Fx.clear_all()
	_state(GameState.player)
	for e in GameState.enemies:
		_state(e)
	_on_turn_ended()

## Static light of the floor: for every source, (1 - d / r)^1.2 x intensity
## on the open cells and wall faces it can see. The source contributing most
## to a cell gives it its flicker.
func _build_light_map(d: DungeonData) -> void:
	var n: int = d.width * d.height
	_static = PackedColorArray()
	_static.resize(n)
	_static.fill(Color(0, 0, 0, 0))
	_src = PackedInt32Array()
	_src.resize(n)
	_src.fill(-1)
	var best := PackedFloat32Array()
	best.resize(n)
	var sources: Array = []   # [origin, colour, radius, intensity]
	var torch_r: float = ConfigManager.get_float("torch_light_radius", 4.5)
	var candle_r: float = ConfigManager.get_float("candle_light_radius", 3.0)
	for t in d.torches:
		sources.append([t + Vector2i(0, 1), _light, torch_r, 1.3])
	for c in d.candles:
		sources.append([c, _candle, candle_r, 1.0])
	for r in d.runes:
		sources.append([r, _rune_col, 2.8, 0.95])
	if d.is_last_floor:
		sources.append([d.stairs_pos, Color("7fe3ff"), 3.2, 0.9])
	for k in sources.size():
		var o: Vector2i = sources[k][0]
		var col: Color = sources[k][1]
		var r: float = sources[k][2]
		var inten: float = sources[k][3]
		var ri: int = ceili(r)
		for dx in range(-ri, ri + 1):
			for dy in range(-ri, ri + 1):
				var p: Vector2i = o + Vector2i(dx, dy)
				if not d.in_bounds(p) or not (d.is_open(p) or d.is_wall_face(p)):
					continue
				var dist: float = Vector2(dx, dy).length()
				if dist > r or not FOVSystem.has_los(d, o, p):
					continue
				var v: float = pow(1.0 - dist / r, 1.2) * inten
				var i: int = p.y * d.width + p.x
				_static[i] = _static[i] + col * v
				if v > best[i]:
					best[i] = v
					_src[i] = k
	_flick = PackedFloat32Array()
	_flick.resize(sources.size())
	_flick.fill(1.0)

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
			Fx.burst(tile_center(from) + Vector2(0, _ts * 0.35), Color(0.7, 0.72, 0.85, 0.5), 3, 25.0, 2.0, 0.35, -20.0)

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
			GameCamera.add_trauma(0.28)
			Fx.ring(at, GOLD, _ts * 0.9, 0.3, 3.0)
			_hitstop(0.06)
		else:
			GameCamera.add_trauma(0.07)
		Sfx.play("crit" if crit else "hit", 0.1)

## Damage from impacts, blasts and friendly fire.
func _on_entity_hurt(target: Entity, damage: int, kind: String) -> void:
	if not _vis.has(target) and target != GameState.player:
		return
	var s: VisState = _state(target)
	s.flash = 1.0
	s.squash = 0.7
	var col: Color = HURT_COLORS.get(kind, Color.WHITE) as Color
	var at: Vector2 = tile_center(target.grid_pos)
	Fx.text(at + Vector2(0, -24), ("-%d" if target == GameState.player else "%d") % damage, col, 20, 0.85)
	Fx.burst(at, col, 8, 120.0, 2.5, 0.4, 200.0)
	if target == GameState.player:
		GameCamera.add_trauma(0.3 + 0.5 * float(damage) / float(maxi(GameState.player.hp_max, 1)))
		Sfx.play("hurt", 0.08)

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
		GameCamera.add_trauma(0.9)
		Fx.burst(at, GOLD, 40, 260.0, 4.0, 1.0, 200.0)
		Fx.ring(at, GOLD, _ts * 3.0, 0.8, 5.0)
		_hitstop(0.35)
	else:
		GameCamera.add_trauma(0.14)
		_hitstop(0.04)
	Sfx.play("kill", 0.1)
	_vis.erase(entity)

func _on_projectile_fired(from: Vector2i, to: Vector2i, color: Color) -> void:
	Fx.tracer(tile_center(from), tile_center(to), color.lightened(0.3), 3.0, 0.22)
	Fx.burst(tile_center(to), color.lightened(0.4), 5, 80.0, 2.0, 0.25)
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
			_hitstop(0.06)
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
	if AISystem.chebyshev(pos, GameState.player.grid_pos) <= 1:
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

## Dash: fast slide and a trail of afterimages along the path.
func _on_player_dashed(from: Vector2i, to: Vector2i) -> void:
	var s: VisState = _state(GameState.player)
	s.fast = true
	s.squash = -0.5
	var a: Vector2 = tile_center(from)
	var b: Vector2 = tile_center(to)
	var n: int = 2 + AISystem.chebyshev(from, to) * 2
	for i in n:
		var g := Ghost.new()
		g.pos = a.lerp(b, float(i) / float(n))
		g.max_life = 0.18 + 0.05 * i
		g.life = g.max_life
		g.flip = GameState.player.facing < 0
		g.frame = 0
		_ghosts.append(g)
	Fx.burst(a + Vector2(0, _ts * 0.35), Color(0.75, 0.72, 0.85, 0.7), 10, 90.0, 2.5, 0.4, -10.0)
	GameCamera.add_trauma(0.12)
	Sfx.play("dash", 0.08)

func _on_enemy_knocked(enemy: EnemyEntity, from: Vector2i, _to: Vector2i) -> void:
	var s: VisState = _state(enemy)
	s.fast = true
	s.squash = 0.6
	Fx.burst(tile_center(from) + Vector2(0, _ts * 0.35), Color(0.75, 0.72, 0.85, 0.6), 8, 80.0, 2.5, 0.35, -10.0)
	Sfx.play("knock", 0.1)

## Pushed into an obstacle: debris at the contact point, heavy shake.
func _on_impact(enemy: EnemyEntity, at: Vector2i) -> void:
	var contact: Vector2 = (tile_center(enemy.grid_pos) + tile_center(at)) * 0.5
	Fx.ring(contact, Color("ffd9a0"), _ts * 1.0, 0.3, 4.0)
	Fx.burst(contact, Color("b8b0a8"), 16, 180.0, 3.0, 0.5, 380.0)
	Fx.burst(contact, Color("ffad5e"), 8, 140.0, 2.5, 0.35)
	Fx.text(tile_center(enemy.grid_pos) + Vector2(0, -44), StringManager.t("impact_label"), Color("ffad5e"), 18, 0.8)
	_state(enemy).lunge = (tile_center(at) - tile_center(enemy.grid_pos)).normalized() * _ts * 0.3
	GameCamera.add_trauma(0.4)
	_hitstop(0.08)
	Sfx.play("impact", 0.08)

func _on_enemy_stunned(enemy: EnemyEntity) -> void:
	_state(enemy).squash = 0.5
	Sfx.play("stun", 0.1)

func _on_danger_marked(dz: Dictionary) -> void:
	var owner: EnemyEntity = dz["owner"] as EnemyEntity
	if not _vis.has(owner):
		return
	var s: VisState = _state(owner)
	s.squash = -0.7
	if str(dz["kind"]) == "arrow":
		Sfx.play("aim", 0.08)
	else:
		Sfx.play("windup", 0.06)

func _on_danger_struck(dz: Dictionary) -> void:
	if str(dz["kind"]) == "arrow":
		return
	var owner: EnemyEntity = dz["owner"] as EnemyEntity
	var cells: Array = dz["cells"]
	if cells.is_empty():
		return
	var center := Vector2.ZERO
	for c in cells:
		center += tile_center(c as Vector2i)
		if bool(GameState.visible[(c as Vector2i).x][(c as Vector2i).y]):
			Fx.burst(tile_center(c as Vector2i) + Vector2(0, _ts * 0.3), Color(0.72, 0.68, 0.72, 0.8), 5, 90.0, 2.5, 0.4, 260.0)
	center /= float(cells.size())
	if _vis.has(owner):
		var s: VisState = _state(owner)
		s.lunge = (center - s.pos).normalized() * _ts * 0.45
		s.squash = 0.9
	var slam: bool = str(dz["kind"]) == "slam"
	Fx.ring(center if not slam else tile_center(owner.grid_pos), Color("ff8a6a"), _ts * (2.6 if slam else 1.4), 0.4, 4.0)
	GameCamera.add_trauma(0.55 if slam else 0.3)
	_hitstop(0.05)
	Sfx.play("slam", 0.06)

func _on_attack_interrupted(enemy: EnemyEntity) -> void:
	Fx.text(tile_center(enemy.grid_pos) + Vector2(0, -56), StringManager.t("interrupt_label"), Color("9fe8ff"), 16, 0.9)
	Sfx.play("interrupt", 0.06)

func _on_heavy_dodged(enemy: EnemyEntity) -> void:
	if AISystem.chebyshev(enemy.grid_pos, GameState.player.grid_pos) > 3:
		return
	Fx.text(player_draw_pos() + Vector2(0, -44), StringManager.t("dodged_label"), Color("9fe8ff"), 16, 0.8)

func _on_keg_lit(pos: Vector2i) -> void:
	var at: Vector2 = tile_center(pos) + Vector2(2, -_ts * 0.42)
	Fx.burst(at, Color("ffd36b"), 12, 90.0, 2.0, 0.4, -40.0)
	_state(GameState.player).lunge = Vector2(pos - GameState.player.grid_pos) * _ts * 0.2
	Sfx.play("fuse", 0.05)

func _on_keg_slid(from: Vector2i, to: Vector2i) -> void:
	_keg_slides[to] = {from = tile_center(from), t = 0.0}
	Fx.burst(tile_center(from) + Vector2(0, _ts * 0.35), Color(0.75, 0.72, 0.85, 0.6), 8, 70.0, 2.5, 0.35, -10.0)
	_state(GameState.player).lunge = Vector2(to - from).normalized() * _ts * 0.25
	Sfx.play("kick", 0.08)

func _on_keg_exploded(pos: Vector2i, radius: int) -> void:
	var at: Vector2 = tile_center(pos)
	Fx.burst(at, Color("fff0a0"), 18, 120.0, 4.0, 0.3)
	Fx.burst(at, Color("ff9a3a"), 36, 260.0, 4.0, 0.6, -60.0)
	Fx.burst(at, Color("d8402a"), 20, 200.0, 3.5, 0.7, 120.0)
	Fx.burst(at, Color(0.3, 0.27, 0.32, 0.8), 18, 90.0, 5.0, 1.1, -50.0)
	Fx.burst(at, Color("6a4a32"), 14, 220.0, 3.0, 0.7, 420.0)
	Fx.ring(at, Color("ffc46b"), _ts * (radius + 0.8), 0.4, 5.0)
	Fx.ring(at, Color("ff6a3a"), _ts * (radius + 1.6), 0.6, 3.0)
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var p: Vector2i = pos + Vector2i(dx, dy)
			if GameState.dungeon.is_open(p):
				_scorch[p] = maxf(float(_scorch.get(p, 0.0)), 1.0 if p == pos else 0.55)
	GameCamera.add_trauma(0.7)
	_hitstop(0.09)
	Sfx.play("explode", 0.08)

func _on_elan_changed(value: int, gained: bool) -> void:
	var at: Vector2 = player_draw_pos()
	if gained:
		Fx.text(at + Vector2(0, -58), StringManager.t("elan_popup", {value = value}), Color("ffb04a"), 16 + value * 2, 1.0)
		Fx.burst(at, Color("ff8a3a"), 6 + value * 3, 110.0, 2.5, 0.6, -80.0)
		Sfx.play("elan", 0.0, 0.0, 1.0 + 0.08 * value)
	else:
		Fx.burst(at, Color(0.6, 0.55, 0.65, 0.6), 8, 60.0, 2.0, 0.5, -40.0)

func _on_warden_enraged(enemy: EnemyEntity) -> void:
	var at: Vector2 = tile_center(enemy.grid_pos)
	Fx.ring(at, Color("ff3b4e"), _ts * 2.5, 0.6, 5.0)
	Fx.burst(at, Color("ff5d5d"), 30, 200.0, 3.5, 0.8, -40.0)
	GameCamera.add_trauma(0.6)
	Sfx.play("boss", 0.0, 2.0)

# ---------------------------------------------------------------------------
# Animation update
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _hitstop_until:
		Engine.time_scale = 1.0
	_time += delta
	if GameState.player == null or GameState.dungeon == null:
		return
	var k: float = 1.0 - exp(-delta * 18.0)
	var kf: float = 1.0 - exp(-delta * 34.0)
	var live: Dictionary = {GameState.player: true}
	for e in GameState.enemies:
		live[e] = true
	for e in _vis.keys():
		if not live.has(e):
			_vis.erase(e)
			continue
		var s: VisState = _vis[e] as VisState
		var target: Vector2 = tile_center((e as Entity).grid_pos)
		var far: float = _ts * (5.0 if s.fast else 3.0)
		if s.pos.distance_to(target) > far:
			s.pos = target   # too far behind (fast key repeat): snap
		var before: float = s.pos.distance_to(target)
		s.pos = s.pos.lerp(target, kf if s.fast else k)
		var left: float = clampf(s.pos.distance_to(target) / _ts, 0.0, 1.0)
		s.hop = sin(left * PI) if before > 0.5 and not s.fast else 0.0
		if before > 2.0 and s.pos.distance_to(target) <= 2.0:
			s.squash = 0.45   # landing
			s.fast = false
		elif before <= 0.5:
			s.fast = false
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
	for g in _ghosts.duplicate():
		g.life -= delta
		if g.life <= 0.0:
			_ghosts.erase(g)
	for p in _keg_slides.keys():
		var sl: Dictionary = _keg_slides[p]
		sl["t"] = float(sl["t"]) + delta * 7.0
		if float(sl["t"]) >= 1.0:
			_keg_slides.erase(p)
	if GameState.key_hint != Vector2.ZERO:
		_hint_dir = _hint_dir.slerp(GameState.key_hint, 1.0 - exp(-delta * 8.0)).normalized()
		_hint_alpha = move_toward(_hint_alpha, 0.35 + 0.65 * GameState.key_hint_strength, delta * 3.0)
	else:
		_hint_alpha = move_toward(_hint_alpha, 0.0, delta * 3.0)
	for i in _flick.size():
		_flick[i] = 1.0 + 0.07 * sin(_time * 9.7 + i * 2.3) + 0.045 * sin(_time * 23.0 + i * 5.1)
	_pflick = 1.0 + 0.03 * sin(_time * 7.3) + 0.02 * sin(_time * 13.1 + 1.7)
	_update_embers(delta)
	queue_redraw()
	_glow.queue_redraw()

## Embers drift up through the air: half rise from the visible flames, the
## rest appear anywhere over explored ground in view.
func _update_embers(delta: float) -> void:
	for e in _embers.duplicate():
		e.life -= delta
		if e.life <= 0.0:
			_embers.erase(e)
			continue
		e.vel.x = sin(_time * 1.6 + e.sway) * 9.0
		e.pos += e.vel * delta
	var d: DungeonData = GameState.dungeon
	var view: Rect2 = _view_rect()
	_ember_acc += delta * 16.0
	var tries: int = 0
	while _ember_acc >= 1.0 and _embers.size() < MAX_EMBERS and tries < 8:
		tries += 1
		_ember_acc -= 1.0
		var e := Ember.new()
		var flames: Array[Vector2] = []
		if randf() < 0.5:
			for t in d.torches:
				if bool(GameState.visible[t.x][t.y]):
					flames.append(Vector2(t) * _ts + Vector2(_ts * 0.5, _ts * 0.35))
			for c in d.candles:
				if bool(GameState.visible[c.x][c.y]):
					flames.append(tile_center(c) + Vector2(0, -6))
		if not flames.is_empty():
			e.pos = flames[randi() % flames.size()] + Vector2(randf_range(-5, 5), 0)
			e.vel = Vector2(0, -randf_range(18.0, 40.0))
			e.max_life = randf_range(1.2, 2.4)
			e.col = _light.lightened(0.15) if randf() < 0.6 else Color("ff5a2a")
		else:
			e.pos = view.position + Vector2(randf() * view.size.x, randf() * view.size.y)
			var cell: Vector2i = Vector2i((e.pos / _ts).floor())
			if not d.in_bounds(cell) or not bool(d.explored[cell.x][cell.y]):
				continue
			e.vel = Vector2(0, -randf_range(6.0, 16.0))
			e.max_life = randf_range(2.5, 5.0)
			e.col = Color("ff6a3a") if randf() < 0.7 else Color("ffb05a")
		e.life = e.max_life
		e.size = 2.0 if randf() < 0.75 else 3.0
		e.sway = randf() * TAU
		_embers.append(e)

# ---------------------------------------------------------------------------
# Lighting
# ---------------------------------------------------------------------------

func _cell_color(x: int, y: int, ppos: Vector2) -> Color:
	var d: DungeonData = GameState.dungeon
	if x < 0 or y < 0 or x >= d.width or y >= d.height:
		return VOID
	var i: int = y * d.width + x
	if bool(GameState.visible[x][y]):
		# walls stand up into the light: a little more ambient on them
		var c: Color = _ambient * (1.35 if d.grid[x][y] == DungeonData.TileType.WALL else 1.0)
		var k: int = _src[i]
		if k >= 0:
			c += _static[i] * _flick[k]
		var dd: float = ((Vector2(x, y) + Vector2(0.5, 0.5)) * _ts).distance_squared_to(ppos) / (_lantern_r * _lantern_r)
		if dd < 1.0:
			var lp: float = 1.0 - dd
			c += _lantern * (lp * lp * _lantern_k * _pflick)
		return Color(minf(c.r, 1.45), minf(c.g, 1.45), minf(c.b, 1.45), 1.0)
	if bool(d.explored[x][y]):
		var m: Color = _memory * (1.3 if d.grid[x][y] == DungeonData.TileType.WALL else 1.0) + _static[i] * 0.12
		return Color(m.r, m.g, m.b, 1.0)
	return VOID

## Corner colours of the tiles in [x0, x1] x [y0, y1]: each corner is the
## average of the four cells that share it.
func _build_corners(x0: int, y0: int, x1: int, y1: int, ppos: Vector2) -> void:
	var lw: int = x1 - x0 + 3
	var lh: int = y1 - y0 + 3
	var cells := PackedColorArray()
	cells.resize(lw * lh)
	for j in lh:
		for i in lw:
			cells[j * lw + i] = _cell_color(x0 - 1 + i, y0 - 1 + j, ppos)
	_cx0 = x0
	_cy0 = y0
	_cw = lw - 1
	_ch = lh - 1
	_corners.resize(_cw * _ch)
	for j in _ch:
		for i in _cw:
			var a: int = j * lw + i
			_corners[j * _cw + i] = (cells[a] + cells[a + 1] + cells[a + lw] + cells[a + lw + 1]) * 0.25

func _corner(x: int, y: int) -> Color:
	var i: int = clampi(x - _cx0, 0, _cw - 1)
	var j: int = clampi(y - _cy0, 0, _ch - 1)
	return _corners[j * _cw + i]

## Light at a world position, interpolated between the corners.
func _light_at(world: Vector2) -> Color:
	if _corners.is_empty():
		return Color.WHITE
	var gx: float = clampf(world.x / _ts - _cx0, 0.0, _cw - 1.001)
	var gy: float = clampf(world.y / _ts - _cy0, 0.0, _ch - 1.001)
	var ix: int = floori(gx)
	var iy: int = floori(gy)
	var fx: float = gx - ix
	var fy: float = gy - iy
	var top: Color = _corners[iy * _cw + ix].lerp(_corners[iy * _cw + ix + 1], fx)
	var bot: Color = _corners[(iy + 1) * _cw + ix].lerp(_corners[(iy + 1) * _cw + ix + 1], fx)
	return top.lerp(bot, fy)

## Modulate for a sprite: the light where it stands, lifted toward white so
## creatures and items stay readable in the dark.
func _sprite_mod(world: Vector2, lift: float = 0.4) -> Color:
	var l: Color = _light_at(world)
	return Color(minf(lerpf(l.r, 1.0, lift), 1.25), minf(lerpf(l.g, 1.0, lift), 1.25), minf(lerpf(l.b, 1.0, lift), 1.25), 1.0)

## Draws a texture on the tile at `p` with the corner colours of tile `lp`.
func _quad(tex: Texture2D, p: Vector2i, lp: Vector2i, scale: float = 1.0) -> void:
	var a: Vector2 = Vector2(p) * _ts
	var b: Vector2 = a + Vector2(_ts, _ts)
	var c0: Color = _corner(lp.x, lp.y) * scale
	var c1: Color = _corner(lp.x + 1, lp.y) * scale
	var c2: Color = _corner(lp.x + 1, lp.y + 1)
	var c3: Color = _corner(lp.x, lp.y + 1)
	if scale != 1.0 and p != lp:
		# upper half of a wall face: bottom edge takes the top edge of the face below
		c2 = _corner(lp.x + 1, lp.y)
		c3 = _corner(lp.x, lp.y)
	c0.a = 1.0
	c1.a = 1.0
	var rid: RID = tex.get_rid()
	var bt: Batch = _batches.get(rid) as Batch
	if bt == null:
		bt = Batch.new()
		bt.tex = rid
		_batches[rid] = bt
	var n: int = bt.pts.size()
	bt.pts.append(a)
	bt.pts.append(Vector2(b.x, a.y))
	bt.pts.append(b)
	bt.pts.append(Vector2(a.x, b.y))
	bt.cols.append(c0)
	bt.cols.append(c1)
	bt.cols.append(c2)
	bt.cols.append(c3)
	bt.uvs.append_array(_uv)
	bt.idx.append_array(PackedInt32Array([n, n + 1, n + 2, n, n + 2, n + 3]))

## Sends the gathered quads, one triangle array per texture.
func _flush_quads() -> void:
	var ci: RID = get_canvas_item()
	for rid in _batches:
		var bt: Batch = _batches[rid] as Batch
		RenderingServer.canvas_item_add_triangle_array(ci, bt.idx, bt.pts, bt.cols, bt.uvs,
			PackedInt32Array(), PackedFloat32Array(), bt.tex)
	_batches.clear()

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
	var y1: int = mini(int(view.end.y / _ts) + 2, d.height - 1)
	var ppos: Vector2 = player_draw_pos()
	_build_corners(x0, y0, x1, y1, ppos)

	# 1. tiles (gathered, then sent per texture), shadows and stairs on top
	var floors: Array[Vector2i] = []
	var caps: Array[Vector2i] = []
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if not bool(GameState.visible[x][y]) and not bool(d.explored[x][y]):
				continue
			var p := Vector2i(x, y)
			if d.get_tile(p) == DungeonData.TileType.WALL:
				if _draw_wall(d, p):
					caps.append(p)
				continue
			_quad(_tiles.get_texture("floor_%d" % TileArt.variant_for(p, TileArt.FLOOR_VARIANTS)), p, p)
			floors.append(p)
	_flush_quads()
	for p in floors:
		_draw_contact_shadow(d, p)
		if d.get_tile(p) == DungeonData.TileType.STAIRS_DOWN:
			_draw_stairs(d, p, bool(GameState.visible[p.x][p.y]))
	for p in caps:
		_draw_cap_edges(d, p)

	# 2. on the walls
	for t in d.torches:
		if t.x >= x0 and t.x <= x1 and t.y >= y0 and t.y <= y1 and bool(d.explored[t.x][t.y]):
			_draw_torch(t, bool(GameState.visible[t.x][t.y]))
	for b_v in d.banners.keys():
		var b: Vector2i = b_v as Vector2i
		if b.x >= x0 and b.x <= x1 and b.y >= y0 and b.y <= y1 and bool(d.explored[b.x][b.y]):
			var sway: float = roundf(sin(_time * 1.3 + b.x) * 0.6)
			draw_texture_rect(PixelArt.texture("banner"), Rect2(Vector2(b) * _ts + Vector2(sway, -_ts * 0.45), Vector2(_ts, _ts)),
				false, _sprite_mod(tile_center(b), 0.1))

	# 3. things on the floor
	_draw_floor_things(d, view)

	# 4. announced attacks
	_draw_dangers(d)

	# 5. afterimages, then actors, the lower one in front
	for g in _ghosts:
		var a: float = g.life / g.max_life
		PixelArt.draw_silhouette(self, "player", (g.pos + Vector2(0, _ts * 0.44)).round(), _ts, g.frame, g.flip,
			Color(1.0, 0.55, 0.4, 0.45 * a))
	var actors: Array = []
	for e in GameState.enemies:
		if bool(GameState.visible[e.grid_pos.x][e.grid_pos.y]):
			actors.append(e)
	actors.append(GameState.player)
	actors.sort_custom(func(a, b): return _state(a).pos.y < _state(b).pos.y)
	for a in actors:
		_draw_actor(a as Entity)

	# 6. overlays
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

## Wall cell: a face (floor below) is two cells tall, bricks here and the
## capstone on the cell above when that one is a wall too; a wall touching
## the floor elsewhere shows its cap; solid rock stays black. Returns true
## when a cap was drawn (its edges are drawn after the tiles).
func _draw_wall(d: DungeonData, p: Vector2i) -> bool:
	var below: Vector2i = p + Vector2i(0, 1)
	if d.is_open(below):
		var above: Vector2i = p - Vector2i(0, 1)
		if d.is_open(above):
			_quad(_tiles.get_texture("wall_single_%d" % TileArt.variant_for(p, 2, 3)), p, p)
		else:
			_quad(_tiles.get_texture("wall_low_%d" % TileArt.variant_for(p, 3, 1)), p, p)
			_quad(_tiles.get_texture("wall_high_%d" % TileArt.variant_for(p, 2, 2)), above, p, 0.78)
		return false
	# upper half of the face below, drawn with it, once that face has been
	# seen; before that, the cell shows its cap (a wall two cells thick seen
	# from the corridor above used to stay black until the room below was
	# explored)
	if d.get_tile(below) == DungeonData.TileType.WALL and d.is_open(below + Vector2i(0, 1)) \
			and bool(d.explored[below.x][below.y]):
		return false
	if d.is_wall_face(p):
		_quad(_tiles.get_texture("wall_cap_%d" % TileArt.variant_for(p, 3, 4)), p, p)
		return true
	return false

## Where the top of a wall meets the floor: a dark line on the edge, then a
## rim lit from the top left (light on the top and left edges, shade on the
## right one). Together with the darker cap, it tells the raised wall from
## the paving at a glance.
func _draw_cap_edges(d: DungeonData, p: Vector2i) -> void:
	var o: Vector2 = Vector2(p) * _ts
	var dark := Color(0.02, 0.01, 0.05, 0.8)
	var lit: float = 0.2 if bool(GameState.visible[p.x][p.y]) else 0.07
	var rim := Color(1.0, 0.95, 0.85, lit)
	var shade := Color(0.02, 0.01, 0.05, 0.3)
	if d.is_open(p + Vector2i(0, -1)):
		draw_rect(Rect2(o, Vector2(_ts, 2)), dark)
		draw_rect(Rect2(o + Vector2(0, 2), Vector2(_ts, 2)), rim)
	if d.is_open(p + Vector2i(-1, 0)):
		draw_rect(Rect2(o, Vector2(2, _ts)), dark)
		draw_rect(Rect2(o + Vector2(2, 0), Vector2(2, _ts)), rim)
	if d.is_open(p + Vector2i(1, 0)):
		draw_rect(Rect2(o + Vector2(_ts - 2, 0), Vector2(2, _ts)), dark)
		draw_rect(Rect2(o + Vector2(_ts - 4, 0), Vector2(2, _ts)), shade)

## Walls cast a soft violet shadow on the floor at their foot and along the
## sides: the floor reads as lower than the walls. A wall below the cell
## (the top of the bottom wall of a room) darkens its lower edge.
func _draw_contact_shadow(d: DungeonData, p: Vector2i) -> void:
	var o: Vector2 = Vector2(p) * _ts
	var sh := Color(0.05, 0.02, 0.1)
	if not d.is_open(p + Vector2i(0, -1)):
		draw_rect(Rect2(o, Vector2(_ts, 4)), Color(sh, 0.5))
		draw_rect(Rect2(o + Vector2(0, 4), Vector2(_ts, 4)), Color(sh, 0.28))
		draw_rect(Rect2(o + Vector2(0, 8), Vector2(_ts, 4)), Color(sh, 0.12))
	if not d.is_open(p + Vector2i(-1, 0)):
		draw_rect(Rect2(o, Vector2(4, _ts)), Color(sh, 0.3))
		draw_rect(Rect2(o + Vector2(4, 0), Vector2(3, _ts)), Color(sh, 0.12))
	if not d.is_open(p + Vector2i(1, 0)):
		draw_rect(Rect2(o + Vector2(_ts - 4, 0), Vector2(4, _ts)), Color(sh, 0.26))
	if not d.is_open(p + Vector2i(0, 1)):
		draw_rect(Rect2(o + Vector2(0, _ts - 3), Vector2(_ts, 3)), Color(sh, 0.4))
		draw_rect(Rect2(o + Vector2(0, _ts - 6), Vector2(_ts, 3)), Color(sh, 0.15))

func _draw_stairs(d: DungeonData, p: Vector2i, vis: bool) -> void:
	var rect := Rect2(Vector2(p) * _ts, Vector2(_ts, _ts))
	var mod: Color = _sprite_mod(rect.get_center(), 0.15)
	if d.is_last_floor:
		Sprites.draw_portal(self, rect.get_center(), _ts * 0.45, _time, 1.0 if vis else 0.4)
	else:
		draw_texture_rect(PixelArt.texture("stairs"), rect, false, mod)
	if _grille_open >= 1.0:
		return
	var shake: float = sin(_time * 70.0) * 3.0 * _grille_shake
	var lift: float = _grille_open * _grille_open * _ts * 0.8
	var g := Rect2(rect.position + Vector2(shake, -lift), rect.size)
	draw_texture_rect(PixelArt.texture("grille"), g, false, Color(mod, 1.0 - _grille_open))
	# with the key in hand, the lock calls you
	if vis and GameState.player.has_key and d.stairs_locked:
		var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
		draw_circle(rect.get_center() + Vector2(0, 2), _ts * (0.3 + 0.1 * pulse), Color(1.0, 0.85, 0.3, 0.18 + 0.12 * pulse))

func _draw_torch(t: Vector2i, vis: bool) -> void:
	var rect := Rect2(Vector2(t) * _ts, Vector2(_ts, _ts))
	var frame: int = int(_time * 7.0 + t.x) % 2
	draw_texture_rect(PixelArt.texture("torch", frame), rect, false, Color.WHITE if vis else Color(0.7, 0.62, 0.7))

func _draw_floor_things(d: DungeonData, view: Rect2) -> void:
	var area: Rect2 = view.grow(_ts)
	for pos_v in _scorch.keys():
		var pos: Vector2i = pos_v as Vector2i
		if area.has_point(tile_center(pos)) and bool(d.explored[pos.x][pos.y]):
			var k: float = float(_scorch[pos_v])
			draw_set_transform(tile_center(pos) + Vector2(0, 3), 0.0, Vector2(1.0, 0.75))
			draw_circle(Vector2.ZERO, _ts * 0.48 * k, Color(0.06, 0.03, 0.06, 0.32 * k))
			draw_circle(Vector2.ZERO, _ts * 0.3 * k, Color(0.04, 0.02, 0.04, 0.35 * k))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for pos_v in d.decor.keys():
		var pos: Vector2i = pos_v as Vector2i
		if area.has_point(tile_center(pos)) and bool(d.explored[pos.x][pos.y]) and not d.items.has(pos):
			var kind: String = str(d.decor[pos_v])
			draw_texture_rect(PixelArt.texture(kind), Rect2(Vector2(pos) * _ts, Vector2(_ts, _ts)), false,
				Color(_sprite_mod(tile_center(pos), 0.0) * 0.95, 0.9))
	for r in d.runes:
		if area.has_point(tile_center(r)) and bool(d.explored[r.x][r.y]):
			var pulse: float = 0.5 + 0.5 * sin(_time * 2.2)
			var a: float = (0.65 + 0.3 * pulse) if bool(GameState.visible[r.x][r.y]) else 0.35
			draw_texture_rect(PixelArt.texture("rune@" + _rune_col.to_html(false)), Rect2(Vector2(r) * _ts, Vector2(_ts, _ts)), false, Color(1, 1, 1, a))
	for c in d.candles:
		if area.has_point(tile_center(c)) and bool(d.explored[c.x][c.y]):
			var vis: bool = bool(GameState.visible[c.x][c.y])
			var frame: int = int(_time * 6.0 + c.y) % 2
			draw_texture_rect(PixelArt.texture("candles", frame), Rect2(Vector2(c) * _ts, Vector2(_ts, _ts)), false,
				Color.WHITE if vis else Color(0.62, 0.56, 0.66))
	_draw_footprints(d, area)
	for pos_v in d.bone_piles.keys():
		var pos: Vector2i = pos_v as Vector2i
		if not area.has_point(tile_center(pos)) or not bool(GameState.visible[pos.x][pos.y]):
			continue
		var turns: int = int((d.bone_piles[pos_v] as Dictionary).get("turns", 9))
		var shake: float = sin(_time * 45.0) * (3.0 - turns) if turns <= 2 else 0.0
		var r := Rect2(Vector2(pos) * _ts + Vector2(shake, 0), Vector2(_ts, _ts))
		draw_texture_rect(PixelArt.texture("bones"), r, false, _sprite_mod(r.get_center(), 0.3).lerp(Color("c8ffb0"), 0.3))
		var glow: float = 0.5 + 0.5 * sin(_time * (4.0 + 6.0 / maxf(turns, 1)))
		draw_circle(r.get_center() + Vector2(0, 4), _ts * 0.3, Color(0.6, 1.0, 0.55, 0.06 + 0.1 * glow))
	for pos_v in d.barrels.keys():
		var pos: Vector2i = pos_v as Vector2i
		if not area.has_point(tile_center(pos)) or not bool(d.explored[pos.x][pos.y]):
			continue
		var keg: bool = str(d.barrels[pos_v]) == "keg"
		var center: Vector2 = tile_center(pos)
		if _keg_slides.has(pos):
			var sl: Dictionary = _keg_slides[pos]
			center = (sl["from"] as Vector2).lerp(center, ease(float(sl["t"]), 0.4))
		var lit: bool = d.fuses.has(pos)
		if lit:
			center.x += sin(_time * 50.0) * (2.0 if int(d.fuses[pos]) <= 1 else 1.0)
		var r := Rect2(center - Vector2(_ts, _ts) * 0.5, Vector2(_ts, _ts))
		draw_set_transform(r.get_center() + Vector2(0, _ts * 0.4), 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, _ts * 0.36, Color(0.04, 0.02, 0.09, 0.4))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_texture_rect(PixelArt.texture("keg" if keg else "barrel"), r, false, _sprite_mod(r.get_center(), 0.3))
		if lit:
			var spark: Vector2 = r.position + Vector2(_ts * 0.53, _ts * 0.08)
			var fl: float = 0.5 + 0.5 * sin(_time * 40.0)
			draw_circle(spark, 2.5 + fl * 1.5, Color(1.0, 0.85, 0.3, 0.9))
			draw_circle(spark, 1.4, Color(1, 1, 1, 1))
			var font: Font = Sprites.bold_font()
			var txt: String = str(int(d.fuses[pos]))
			var at: Vector2 = r.position + Vector2(_ts * 0.5 - 12.0, -2.0)
			draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_CENTER, 24, 16, 4, Color(0.1, 0.02, 0.02, 0.9))
			draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_CENTER, 24, 16, Color("ffcf5a"))
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
		if vis:
			var bob: float = roundf(sin(_time * 3.0 + float(pos.x + pos.y)) * 2.0)
			draw_set_transform(center + Vector2(0, _ts * 0.38), 0.0, Vector2(1.0, 0.3))
			draw_circle(Vector2.ZERO, _ts * (0.26 - bob * 0.01), Color(0.04, 0.02, 0.09, 0.4))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			PixelArt.draw(self, sprite, (center + Vector2(0, _ts * 0.5 - 4.0 + bob)).round(), _ts, 0, false, _sprite_mod(center, 0.55))
			if str(item.get("effect", "")) == "key":
				_draw_sparkle(center + Vector2(9, -9), fmod(_time * 1.3, 1.0))
				_draw_sparkle(center + Vector2(-10, 2), fmod(_time * 1.3 + 0.5, 1.0))
		else:
			PixelArt.draw(self, sprite, center + Vector2(0, _ts * 0.5 - 4.0), _ts, 0, false, Color(_memory * 2.2, 0.8))

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
		var a: float = 0.6 * (1.0 - age / life)
		var dir: Vector2 = Vector2(fp.get("dir", Vector2i.RIGHT) as Vector2i).normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var c: Vector2 = tile_center(pos)
		for i in 2:
			var s: float = -1.0 if i == 0 else 1.0
			var at: Vector2 = c + side * 4.5 * s + dir * (5.0 * s)
			draw_set_transform(at, dir.angle(), Vector2(1.0, 0.55))
			draw_circle(Vector2.ZERO, 3.6, Color(0.8, 0.66, 1.0, a))
			draw_circle(Vector2(3.8, 0), 1.6, Color(0.8, 0.66, 1.0, a))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Cells struck at the next enemy turn: heavy blows in red with a bright
## border, arrow lines as a dashed red line, keg blasts in orange (brighter
## on the last turn of the fuse).
func _draw_dangers(d: DungeonData) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 9.0)
	for dz in GameState.dangers:
		var owner: EnemyEntity = dz["owner"] as EnemyEntity
		var cells: Array = dz["cells"]
		if str(dz["kind"]) == "arrow":
			if cells.is_empty() or not bool(GameState.visible[owner.grid_pos.x][owner.grid_pos.y]):
				continue
			for c in cells:
				var p: Vector2i = c as Vector2i
				if bool(GameState.visible[p.x][p.y]):
					draw_rect(Rect2(Vector2(p) * _ts, Vector2(_ts, _ts)).grow(-5.0), Color(DANGER, 0.1 + 0.08 * pulse))
			var a: Vector2 = _state(owner).pos if _vis.has(owner) else tile_center(owner.grid_pos)
			draw_dashed_line(a, tile_center(cells[cells.size() - 1] as Vector2i), Color(DANGER, 0.55 + 0.35 * pulse), 2.0, 7.0)
			continue
		for c in cells:
			var p: Vector2i = c as Vector2i
			if not bool(GameState.visible[p.x][p.y]):
				continue
			var r := Rect2(Vector2(p) * _ts, Vector2(_ts, _ts)).grow(-2.0)
			draw_rect(r, Color(DANGER, 0.2 + 0.16 * pulse))
			draw_rect(r, Color(1.0, 0.45, 0.5, 0.6 + 0.35 * pulse), false, 2.0)
			draw_line(r.position + Vector2(5, r.size.y - 5), r.position + Vector2(r.size.x - 5, 5), Color(DANGER, 0.25), 2.0)
	var radius: int = ConfigManager.get_int("keg_radius", 1)
	for k_v in d.fuses.keys():
		var k: Vector2i = k_v as Vector2i
		var last: bool = int(d.fuses[k_v]) <= 1
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var p: Vector2i = k + Vector2i(dx, dy)
				if not d.in_bounds(p) or not d.is_open(p) or not bool(GameState.visible[p.x][p.y]):
					continue
				var r := Rect2(Vector2(p) * _ts, Vector2(_ts, _ts)).grow(-2.0)
				draw_rect(r, Color(BLAST, (0.16 + 0.16 * pulse) if last else 0.08))
				if last:
					draw_rect(r, Color(1.0, 0.7, 0.35, 0.5 + 0.4 * pulse), false, 2.0)

func _draw_sparkle(at: Vector2, t: float) -> void:
	var a: float = sin(t * PI)
	var r: float = 2.0 + 4.0 * a
	var col := Color(1.0, 0.95, 0.7, a)
	draw_line(at - Vector2(r, 0), at + Vector2(r, 0), col, 1.5)
	draw_line(at - Vector2(0, r), at + Vector2(0, r), col, 1.5)

func _draw_actor(e: Entity) -> void:
	var s: VisState = _state(e)
	var id: String = e.sprite
	var size: float = maxf(roundf(_ts * PixelArt.scale_of(id) / 16.0) * 16.0, _ts)
	var enemy: EnemyEntity = e as EnemyEntity
	var windup: bool = enemy != null and not GameState.danger_of(enemy).is_empty()
	var shake := Vector2.ZERO
	if windup:
		shake.x = sin(_time * 55.0) * 1.5
	var foot: Vector2 = s.pos + s.lunge + shake + Vector2(0, _ts * 0.44)
	var lift: float = s.hop * _ts * 0.16
	var appear: float = ease(s.spawn, -2.0)
	# shadow (stays on the ground during the hop)
	draw_set_transform(foot + Vector2(0, -2), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, size * 0.3 * (1.0 - s.hop * 0.2) * appear, Color(0.04, 0.02, 0.09, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var mod: Color = _sprite_mod(s.pos, 0.42)
	if enemy != null and (enemy.tired > 0 or enemy.stunned > 0):
		mod = mod.lerp(Color("9aa0c0"), 0.25)
	var fps: float = float(ANIM_FPS.get(id, 1.8))
	var frame: int = int(_time * fps + s.phase)
	var sx: float = (1.0 + s.squash * 0.18) * appear
	var sy: float = (1.0 - s.squash * 0.18) * appear
	if windup:
		sy *= 1.06   # rears up before the blow
	var base: Vector2 = (foot - Vector2(0, lift)).round()
	draw_set_transform(base, 0.0, Vector2(sx, sy))
	PixelArt.draw(self, id, Vector2.ZERO, size, frame, e.facing < 0, mod, s.flash)
	if windup or (enemy != null and enemy.enraged):
		var pulse: float = 0.5 + 0.5 * sin(_time * (12.0 if windup else 4.0))
		PixelArt.draw_silhouette(self, id, Vector2.ZERO, size, frame, e.facing < 0, Color(1.0, 0.2, 0.25, (0.25 + 0.3 * pulse) if windup else 0.12 + 0.1 * pulse))
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
		draw_rect(bar.grow(1.0), Color(0.04, 0.02, 0.06, 0.8))
		draw_rect(Rect2(bar.position, Vector2(w * float(e.hp) / float(e.hp_max), 4.0)), Color("ff5d5d"))
		y -= 8.0
	if e.key_carrier:
		var bob: float = roundf(sin(_time * 5.0 + s.phase) * 2.0)
		PixelArt.draw_icon(self, "key", Rect2(Vector2(head.x - 8, y - 16 + bob), Vector2(16, 16)))
		y -= 16.0
	if e.stunned > 0:
		for i in 3:
			var a: float = _time * 5.0 + i * TAU / 3.0
			var at: Vector2 = Vector2(head.x, y - 4) + Vector2(cos(a) * 11.0, sin(a) * 3.5)
			var col := Color(1.0, 0.9, 0.4, 0.95)
			draw_line(at - Vector2(3, 0), at + Vector2(3, 0), col, 1.5)
			draw_line(at - Vector2(0, 3), at + Vector2(0, 3), col, 1.5)
	elif e.tired > 0:
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

## Reticle on the enemy (or keg) a dagger would hit (hovered one first).
func _draw_aim() -> void:
	if GameState.player.daggers <= 0 or GameState.phase != GameState.Phase.PLAYER:
		return
	var d: DungeonData = GameState.dungeon
	var c := Vector2.INF
	var col: Color = Color(1, 1, 1, 0.7)
	if d.in_bounds(hover_tile) and GameState.enemy_positions.has(hover_tile):
		var h: EnemyEntity = GameState.enemy_positions[hover_tile] as EnemyEntity
		if GameState.can_throw_at(h) and _vis.has(h):
			c = _state(h).pos
			col = GOLD if h.key_carrier else col
	elif d.in_bounds(hover_tile) and d.is_keg(hover_tile) and GameState.can_throw_at_cell(hover_tile):
		c = tile_center(hover_tile)
		col = BLAST
	if c == Vector2.INF:
		if _aim == null or not GameState.enemies.has(_aim) or not _vis.has(_aim):
			return
		c = _state(_aim).pos
		col = GOLD if _aim.key_carrier else col
	var r: float = _ts * 0.62 + sin(_time * 6.0) * 2.0
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

# ---------------------------------------------------------------------------
# Glow layer (additive)
# ---------------------------------------------------------------------------

func _g(at: Vector2, radius: float, col: Color) -> void:
	_glow.draw_texture_rect(_radial, Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)

func _draw_glow() -> void:
	var d: DungeonData = GameState.dungeon
	if d == null or GameState.player == null or GameState.visible.is_empty():
		return
	var area: Rect2 = _view_rect().grow(_ts * 3.0)
	for t in d.torches:
		var flame: Vector2 = Vector2(t) * _ts + Vector2(_ts * 0.5, _ts * 0.38)
		if not area.has_point(flame) or not bool(d.explored[t.x][t.y]):
			continue
		var k: float = 1.0 if bool(GameState.visible[t.x][t.y]) else 0.35
		var f: float = 1.0 + 0.08 * sin(_time * 9.7 + t.x * 1.3) + 0.05 * sin(_time * 21.0 + t.y)
		_g(flame, _ts * 0.7 * f, Color(_light, 0.6 * k))
		_g(flame + Vector2(0, _ts * 1.2), _ts * 3.6 * f, Color(_light, 0.15 * k))
	for c in d.candles:
		var at: Vector2 = tile_center(c) + Vector2(0, -2)
		if not area.has_point(at) or not bool(d.explored[c.x][c.y]):
			continue
		var k: float = 1.0 if bool(GameState.visible[c.x][c.y]) else 0.35
		var f: float = 1.0 + 0.1 * sin(_time * 12.0 + c.x * 2.1)
		_g(at, _ts * 0.55 * f, Color(_candle, 0.55 * k))
		_g(at + Vector2(0, 6), _ts * 2.4 * f, Color(_candle, 0.14 * k))
	for r in d.runes:
		var at: Vector2 = tile_center(r)
		if not area.has_point(at) or not bool(d.explored[r.x][r.y]):
			continue
		var k: float = 1.0 if bool(GameState.visible[r.x][r.y]) else 0.4
		var pulse: float = 0.5 + 0.5 * sin(_time * 2.2)
		_g(at, _ts * 0.75, Color(_rune_col.lightened(0.2), (0.3 + 0.15 * pulse) * k))
		_g(at, _ts * 1.9, Color(_rune_col, (0.14 + 0.06 * pulse) * k))
	var sp: Vector2i = d.stairs_pos
	if bool(d.explored[sp.x][sp.y]):
		var k: float = 1.0 if bool(GameState.visible[sp.x][sp.y]) else 0.4
		if d.is_last_floor:
			_g(tile_center(sp), _ts * 1.6, Color(0.5, 0.9, 1.0, 0.35 * k))
		elif not d.stairs_locked:
			_g(tile_center(sp), _ts * (1.1 + 0.08 * sin(_time * 3.0)), Color(1.0, 0.8, 0.3, 0.35 * k))
	# the hero's lantern and the heat of the elan
	var pp: Vector2 = player_draw_pos()
	_g(pp, _ts * 2.6, Color(_lantern, 0.07 * _pflick))
	var elan: int = GameState.player.elan
	if elan > 0:
		_g(pp + Vector2(0, 4), _ts * (0.9 + 0.12 * elan), Color(1.0, 0.45, 0.15, (0.05 + 0.025 * elan) * (0.85 + 0.15 * sin(_time * 6.0))))
	for pos_v in d.items.keys():
		var pos: Vector2i = pos_v as Vector2i
		if not bool(GameState.visible[pos.x][pos.y]) or not area.has_point(tile_center(pos)):
			continue
		var item: Dictionary = d.items[pos_v]
		var col := Color("#" + str(item.get("color", "ffffff")))
		var key: bool = str(item.get("effect", "")) == "key"
		_g(tile_center(pos) + Vector2(0, 2), _ts * (1.0 if key else 0.7), Color(col, 0.4 if key else 0.16))
	for k_v in d.fuses.keys():
		var k: Vector2i = k_v as Vector2i
		if bool(GameState.visible[k.x][k.y]):
			var fl: float = 0.5 + 0.5 * sin(_time * 30.0)
			_g(tile_center(k) + Vector2(2, -_ts * 0.42), _ts * (0.4 + 0.15 * fl), Color(1.0, 0.7, 0.25, 0.7))
			_g(tile_center(k), _ts * 1.4, Color(1.0, 0.35, 0.1, 0.1 + 0.06 * fl))
	var pulse: float = 0.5 + 0.5 * sin(_time * 9.0)
	for dz in GameState.dangers:
		if str(dz["kind"]) == "arrow":
			continue
		for c in dz["cells"]:
			var p: Vector2i = c as Vector2i
			if bool(GameState.visible[p.x][p.y]):
				_g(tile_center(p), _ts * 0.75, Color(1.0, 0.15, 0.2, 0.1 + 0.08 * pulse))
	for e in GameState.enemies:
		if e.enraged and bool(GameState.visible[e.grid_pos.x][e.grid_pos.y]) and _vis.has(e):
			_g(_state(e).pos, _ts * 1.8, Color(1.0, 0.2, 0.2, 0.12 + 0.06 * sin(_time * 4.0)))
	for e in _embers:
		var t: float = e.life / e.max_life
		var a: float = sin(t * PI) * (0.75 + 0.25 * sin(_time * 14.0 + e.sway * 5.0))
		_glow.draw_rect(Rect2(e.pos.round(), Vector2(e.size, e.size)), Color(e.col, a))

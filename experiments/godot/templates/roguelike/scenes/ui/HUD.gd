# =============================================================================
# HUD.gd (class GameHUD): side panel, message log frame, banners, overlays.
# =============================================================================
# Layout (scene Main.tscn):
#   SidePanel  floor title, HP / energy / XP bars, level and stats,
#              key row (where the floor's key is, what you hear) and
#              daggers, inventory (6 slots, click = use, right-click = drop),
#              "Look" box (what is under the mouse), minimap, controls
#   LogPanel   MessageLog (colored, rolling)
#   Banner     floor name when arriving on a floor
#   Fade       black fade-in after taking the stairs
#   EndOverlay death / victory screen with the cause and run stats
#   ActionBar  top left of the map: dash (ready or recharging) and elan
#              (flames, damage bonus, turns left before it drops)
#   Vignette   dark violet edges around the map, red flash when hurt,
#              pulse at low HP (shader)
#
# The HUD never changes the game: it emits intents (item_use_requested,
# item_drop_requested, restart_requested) that Main.gd turns into GameState
# calls, and it refreshes itself from GameState signals.
# =============================================================================

class_name GameHUD
extends Control

signal item_use_requested(slot: int)
signal item_drop_requested(slot: int)
signal restart_requested()

# Shared with Main.gd: the map area is the screen minus these panels
const SIDE_W:  float = 288.0
const LOG_H:   float = 116.0
const MARGIN:  float = 8.0

const COL_TEXT   := Color("efe7dc")
const COL_MUTED  := Color("9a8fa6")
const COL_PANEL  := Color(0.075, 0.058, 0.11, 0.95)
const COL_BORDER := Color("4c3446")
const COL_ACCENT := Color("d07a45")
const COL_HP     := Color("e0464f")
const COL_ENERGY := Color("eba046")
const COL_XP     := Color("a070f0")
const COL_GOLD   := Color("ffcf5a")

# --- Small custom-drawn controls -------------------------------------------

## Bar with a delayed white "trail" showing the last loss.
class StatBar extends Control:
	var label: String = ""
	var value: float = 0.0
	var max_value: float = 1.0
	var color: Color = Color.WHITE
	var _trail: float = 0.0
	func set_values(v: float, m: float) -> void:
		value = v
		max_value = maxf(m, 1.0)
		if _trail < value:
			_trail = value
		queue_redraw()
	func _process(delta: float) -> void:
		if _trail > value:
			_trail = move_toward(_trail, value, delta * max_value * 0.6)
			queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.45))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _trail / max_value, size.y)), Color(1, 1, 1, 0.55))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * value / max_value, size.y)), color)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * value / max_value, 3.0)), color.lightened(0.35))
		var font: Font = Sprites.bold_font()
		var text: String = "%s  %d/%d" % [label, int(value), int(max_value)]
		var at := Vector2(6, size.y * 0.5 + 5)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.7))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

## Pixel-art icon (inventory slots, look box, key row). Empty id = nothing.
class SpriteIcon extends Control:
	var sprite: String = ""
	var modulate_icon: Color = Color.WHITE
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	func set_sprite(id: String, tint: Color = Color.WHITE) -> void:
		sprite = id
		modulate_icon = tint
		queue_redraw()
	func _draw() -> void:
		if not sprite.is_empty():
			PixelArt.draw_icon(self, sprite, Rect2(Vector2.ZERO, size), 0, modulate_icon)

## Speaker icon for the sound button.
class SpeakerIcon extends Control:
	var muted: bool = false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		var col := Color("e8edf5")
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.22), c + Vector2(-r * 0.35, -r * 0.22),
			c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.6), c + Vector2(-r * 0.35, r * 0.22),
			c + Vector2(-r * 0.7, r * 0.22)]), col)
		if muted:
			draw_line(c + Vector2(r * 0.25, -r * 0.3), c + Vector2(r * 0.8, r * 0.3), Color("ff5d6c"), 2.0, true)
			draw_line(c + Vector2(r * 0.8, -r * 0.3), c + Vector2(r * 0.25, r * 0.3), Color("ff5d6c"), 2.0, true)
		else:
			draw_arc(c + Vector2(r * 0.05, 0), r * 0.35, -0.9, 0.9, 10, col, 1.8, true)
			draw_arc(c + Vector2(r * 0.05, 0), r * 0.65, -0.9, 0.9, 12, col, 1.8, true)

## Dash and elan, top left of the map. Redrawn every frame (it pulses).
class ActionBar extends Control:
	var _time: float = 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()
	func _draw() -> void:
		var p: PlayerEntity = GameState.player
		if p == null:
			return
		var bold: Font = Sprites.bold_font()
		var font: Font = ThemeDB.fallback_font
		var muted := Color("9a8fa6")
		var flame := Color("ff9a3c")
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.06, 0.04, 0.09, 0.78))
		draw_rect(r, Color("4c3446"), false, 1.0)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 2)), Color(0.82, 0.48, 0.27, 0.8))
		# dash
		var ready: bool = p.dash_cd <= 0
		var y: float = 24.0
		draw_string(bold, Vector2(10, y), StringManager.t("dash_label"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, muted)
		var cx: float = 96.0
		var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
		var chev: Color = Color("ffcf5a").lerp(Color.WHITE, 0.3 * pulse) if ready else Color(0.55, 0.5, 0.6)
		for i in 2:
			var x0: float = cx + i * 7.0
			draw_polyline(PackedVector2Array([Vector2(x0, y - 12), Vector2(x0 + 6, y - 6), Vector2(x0, y)]), chev, 2.5)
		if ready:
			draw_string(bold, Vector2(cx + 24, y), StringManager.t("dash_ready"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffcf5a"))
			draw_string(font, Vector2(cx + 76, y), StringManager.t("dash_key"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, muted)
		else:
			var full: int = maxi(ConfigManager.get_int("dash_cooldown", 6), 1)
			var w: float = 70.0
			var bar := Rect2(Vector2(cx + 24, y - 9), Vector2(w, 6))
			draw_rect(bar, Color(0, 0, 0, 0.5))
			draw_rect(Rect2(bar.position, Vector2(w * (1.0 - float(p.dash_cd) / full), 6)), Color(0.75, 0.62, 0.4))
			draw_string(font, Vector2(cx + 102, y), StringManager.t("dash_wait", {turns = p.dash_cd}), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, muted)
		# elan
		y = 50.0
		draw_string(bold, Vector2(10, y), StringManager.t("elan_label"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, muted)
		var emax: int = ConfigManager.get_int("elan_max", 5)
		for i in emax:
			var c := Vector2(cx + 4 + i * 16.0, y - 6)
			var lit: bool = i < p.elan
			var flick: float = 1.0 + (0.12 * sin(_time * 12.0 + i * 1.7) if lit else 0.0)
			var pts := PackedVector2Array([c + Vector2(0, -8) * flick, c + Vector2(4.5, -1), c + Vector2(3.5, 4),
				c + Vector2(0, 6), c + Vector2(-3.5, 4), c + Vector2(-4.5, -1)])
			if lit:
				draw_colored_polygon(pts, flame)
				draw_circle(c + Vector2(0, 2), 2.2, Color("ffe08a"))
			else:
				pts.append(pts[0])
				draw_polyline(pts, Color(0.45, 0.4, 0.5), 1.2)
		var tx: float = cx + 6 + emax * 16.0
		if p.elan > 0:
			var bonus: int = GameState.elan_bonus()
			if bonus > 0:
				draw_string(bold, Vector2(tx, y), StringManager.t("elan_bonus", {value = bonus}), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, flame)
			var win: int = maxi(ConfigManager.get_int("elan_window", 4), 1)
			for i in win:
				draw_rect(Rect2(Vector2(cx - 4 + i * (80.0 / win), y + 5), Vector2(80.0 / win - 3.0, 3)),
					flame if i < p.elan_timer else Color(0.3, 0.26, 0.34))
		else:
			draw_string(font, Vector2(tx, y), StringManager.t("elan_none"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.55, 0.65))

# --- Nodes ------------------------------------------------------------------

@onready var floor_title:  Label          = $SidePanel/VBox/Header/FloorTitle
@onready var sound_btn:    Button         = $SidePanel/VBox/Header/SoundButton
@onready var lang_btn:     Button         = $SidePanel/VBox/Header/LangButton
@onready var floor_name:   Label          = $SidePanel/VBox/FloorName
@onready var bars_box:     VBoxContainer  = $SidePanel/VBox/Bars
@onready var level_lbl:    Label          = $SidePanel/VBox/LevelRow/LevelLabel
@onready var stats_lbl:    Label          = $SidePanel/VBox/LevelRow/StatsLabel
@onready var inv_title:    Label          = $SidePanel/VBox/InvTitle
@onready var inv_grid:     GridContainer  = $SidePanel/VBox/InvGrid
@onready var look_title:   Label          = $SidePanel/VBox/LookTitle
@onready var look_panel:   PanelContainer = $SidePanel/VBox/LookPanel
@onready var look_name:    Label          = $SidePanel/VBox/LookPanel/Row/Text/LookName
@onready var look_text:    Label          = $SidePanel/VBox/LookPanel/Row/Text/LookText
@onready var look_slot:    Control        = $SidePanel/VBox/LookPanel/Row/IconSlot
@onready var controls_lbl: Label          = $SidePanel/VBox/Controls
@onready var log_panel:    PanelContainer = $LogPanel
@onready var banner:       VBoxContainer  = $Banner
@onready var banner_title: Label          = $Banner/Title
@onready var banner_sub:   Label          = $Banner/Sub
@onready var fade:         ColorRect      = $Fade
@onready var end_overlay:  ColorRect      = $EndOverlay
@onready var end_panel:    PanelContainer = $EndOverlay/Center/Panel
@onready var end_title:    Label          = $EndOverlay/Center/Panel/VBox/Title
@onready var end_cause:    Label          = $EndOverlay/Center/Panel/VBox/Cause
@onready var end_stats:    Label          = $EndOverlay/Center/Panel/VBox/Stats
@onready var restart_btn:  Button         = $EndOverlay/Center/Panel/VBox/RestartButton
@onready var vignette:     ColorRect      = $"../Vignette"

var _hp_bar:     StatBar = null
var _energy_bar: StatBar = null
var _xp_bar:     StatBar = null
var _look_icon:  SpriteIcon = null
var _speaker:    SpeakerIcon = null
var _slots:      Array[Button] = []
var _slot_icons: Array[SpriteIcon] = []
var _slot_names: Array[Label] = []
var _look_tile:  Vector2i = Vector2i(-2, -2)
var _key_icon:   SpriteIcon = null
var _key_lbl:    Label = null
var _dagger_icon: SpriteIcon = null
var _dagger_lbl: Label = null
var _controls_keys: String = "WASD"
var _vignette_mat: ShaderMaterial = null
var _flash:  float = 0.0
var _time:   float = 0.0
var _victory: bool = false
var _banner_tween: Tween = null
var _action_bar: ActionBar = null

func _ready() -> void:
	theme = _build_theme()
	_setup_vignette()
	_build_bars()
	_build_key_row()
	_build_inventory()
	_build_look_icon()
	_action_bar = ActionBar.new()
	add_child(_action_bar)
	move_child(_action_bar, banner.get_index())
	_action_bar.position = Vector2(MARGIN + 4.0, MARGIN + 4.0)
	_action_bar.size = Vector2(320, 62)
	_style_nodes()
	GameState.stats_changed.connect(refresh)
	GameState.turn_ended.connect(_refresh_key_row)
	GameState.dungeon_ready.connect(_on_dungeon_ready)
	GameState.entity_attacked.connect(_on_entity_attacked)
	GameState.entity_hurt.connect(_on_entity_hurt)
	StringManager.language_changed.connect(_on_language_changed)
	Sfx.mute_changed.connect(_on_mute_changed)
	lang_btn.pressed.connect(_on_lang_pressed)
	sound_btn.pressed.connect(func() -> void: Sfx.toggle_mute())
	restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	end_overlay.visible = false
	banner.visible = false
	fade.color.a = 0.0
	_refresh_texts()

func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta * 1.6, 0.0)
	var low: bool = false
	if GameState.player != null and GameState.phase != GameState.Phase.GAME_OVER:
		low = float(GameState.player.hp) <= float(GameState.player.hp_max) * 0.3
	var pulse: float = (0.22 + 0.1 * sin(_time * 4.0)) if low else 0.0
	_vignette_mat.set_shader_parameter("intensity", maxf(_flash, pulse))
	var vp: Vector2 = get_viewport_rect().size
	var area: Rect2 = map_area()
	_vignette_mat.set_shader_parameter("area", Vector4(area.position.x / vp.x, area.position.y / vp.y,
		area.size.x / vp.x, area.size.y / vp.y))

# ---------------------------------------------------------------------------
# Public API (Main.gd)
# ---------------------------------------------------------------------------

## Screen rectangle where the dungeon is visible (camera centers the player
## in it).
func map_area() -> Rect2:
	var vp: Vector2 = get_viewport_rect().size
	return Rect2(Vector2.ZERO, Vector2(vp.x - SIDE_W - MARGIN, vp.y - LOG_H - MARGIN))

func set_controls_keys(keys: String) -> void:
	_controls_keys = keys
	controls_lbl.text = StringManager.t("controls", {keys = _controls_keys})

func refresh() -> void:
	var p: PlayerEntity = GameState.player
	if p == null:
		return
	floor_title.text = StringManager.t("floor_label", {value = GameState.current_floor, total = GameState.total_floors})
	var theme_data: Dictionary = ConfigManager.get_floor_theme(GameState.current_floor)
	floor_name.text = StringManager.t(str(theme_data.get("name_key", "")))
	floor_name.add_theme_color_override("font_color", Color("#" + str(theme_data.get("light", "ffd9a6"))))
	_hp_bar.label = StringManager.t("hp")
	_hp_bar.set_values(float(p.hp), float(p.hp_max))
	_energy_bar.label = StringManager.t("energy")
	_energy_bar.set_values(float(p.energy), float(p.energy_max))
	_energy_bar.color = COL_ENERGY if p.energy > ConfigManager.get_int("hungry_threshold", 0) else Color("ff6b3d")
	_xp_bar.label = StringManager.t("xp")
	_xp_bar.set_values(float(p.xp), float(p.xp_next))
	level_lbl.text = StringManager.t("level_label", {value = p.level})
	stats_lbl.text = "%s %d   %s %d   %s" % [StringManager.t("stat_attack"), p.attack,
		StringManager.t("stat_defense"), p.defense, StringManager.t("stat_turns", {value = GameState.turn})]
	_refresh_inventory()
	_refresh_key_row()
	var tile: Vector2i = _look_tile
	_look_tile = Vector2i(-2, -2)
	set_look(tile)

## Describes the tile under the mouse ((-1, -1) = nothing hovered).
func set_look(tile: Vector2i) -> void:
	if tile == _look_tile:
		return
	_look_tile = tile
	var d: DungeonData = GameState.dungeon
	look_name.remove_theme_color_override("font_color")
	_look_icon.set_sprite("")
	look_text.text = ""
	if d == null or not d.in_bounds(tile):
		look_name.text = ""
		look_text.text = StringManager.t("look_hint")
		return
	var vis: bool = bool(GameState.visible[tile.x][tile.y])
	if not vis and not bool(d.explored[tile.x][tile.y]):
		look_name.text = StringManager.t("look_unknown")
	elif tile == GameState.player.grid_pos:
		_describe_player()
	elif vis and GameState.enemy_positions.has(tile):
		_describe_enemy(GameState.enemy_positions[tile] as EnemyEntity)
	elif d.items.has(tile):
		var item: Dictionary = d.items[tile]
		look_name.text = ItemDatabase.display_name(item)
		look_text.text = ItemDatabase.description(item) + ("" if vis else "\n" + StringManager.t("look_remembered"))
		_look_icon.set_sprite(PixelArt.item_sprite(item))
	elif d.is_keg(tile):
		look_name.text = StringManager.t("look_keg_name")
		if d.fuses.has(tile):
			look_text.text = StringManager.t("look_keg_lit", {turns = int(d.fuses[tile])})
		else:
			look_text.text = StringManager.t("look_keg", {turns = ConfigManager.get_int("keg_fuse_turns", 3),
				damage = GameState.keg_damage(), radius = ConfigManager.get_int("keg_radius", 1)})
		_look_icon.set_sprite("keg")
	elif d.barrels.has(tile):
		look_name.text = StringManager.t("look_barrel_name")
		look_text.text = StringManager.t("look_barrel", {pct = int(round(ConfigManager.get_float("barrel_loot_chance", 0.4) * 100.0))})
		_look_icon.set_sprite("barrel")
	elif vis and d.bone_piles.has(tile):
		look_name.text = StringManager.t("look_remains_name")
		look_text.text = StringManager.t("look_remains", {turns = int((d.bone_piles[tile] as Dictionary).get("turns", 0))})
		_look_icon.set_sprite("bones", Color("d8ffc8"))
	elif d.get_tile(tile) == DungeonData.TileType.STAIRS_DOWN:
		look_name.text = StringManager.t("look_exit_name" if d.is_last_floor else "look_stairs_name")
		if d.stairs_locked:
			look_text.text = StringManager.t("look_locked_portal" if d.is_last_floor else "look_locked")
			_look_icon.set_sprite("grille")
		else:
			look_text.text = StringManager.t("look_exit" if d.is_last_floor else "look_stairs")
			_look_icon.set_sprite("" if d.is_last_floor else "stairs")
	elif vis and d.footprints.has(tile) and GameState.turn - int((d.footprints[tile] as Dictionary).get("turn", 0)) <= ConfigManager.get_int("footprint_turns", 40):
		var age: int = GameState.turn - int((d.footprints[tile] as Dictionary).get("turn", 0))
		look_name.text = StringManager.t("look_tracks_name")
		look_text.text = StringManager.t("look_tracks", {turns = age, dir = StringManager.t("dir_" + GameState.compass(Vector2((d.footprints[tile] as Dictionary).get("dir", Vector2i.RIGHT) as Vector2i)))})
	elif d.torches.has(tile):
		look_name.text = StringManager.t("look_torch")
		_look_icon.set_sprite("torch")
	elif d.banners.has(tile):
		look_name.text = StringManager.t("look_banner")
		_look_icon.set_sprite("banner")
	elif d.candles.has(tile):
		look_name.text = StringManager.t("look_candles")
		_look_icon.set_sprite("candles")
	elif d.runes.has(tile):
		look_name.text = StringManager.t("look_rune")
		_look_icon.set_sprite("rune@" + str(ConfigManager.get_floor_theme(GameState.current_floor).get("rune", "a865ff")))
	elif d.decor.has(tile):
		var rubble: bool = str(d.decor[tile]) == "rubble"
		look_name.text = StringManager.t("look_rubble" if rubble else "look_bones")
		_look_icon.set_sprite("rubble" if rubble else "bones")
	else:
		match d.get_tile(tile):
			DungeonData.TileType.WALL:
				look_name.text = StringManager.t("look_wall")
			_:
				look_name.text = StringManager.t("look_floor")
	if vis and GameState.is_cell_threatened(tile):
		look_text.text = (look_text.text + "\n" if not look_text.text.is_empty() else "") + StringManager.t("look_danger")

func flash_damage(strength: float) -> void:
	_flash = maxf(_flash, strength)

func show_end(victory: bool) -> void:
	_victory = victory
	_fill_end_texts()
	end_overlay.visible = true
	end_overlay.modulate.a = 0.0
	end_panel.pivot_offset = end_panel.size * 0.5
	end_panel.scale = Vector2(0.7, 0.7)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(end_overlay, "modulate:a", 1.0, 0.4)
	tw.tween_property(end_panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_end() -> void:
	end_overlay.visible = false

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

func _on_dungeon_ready() -> void:
	refresh()
	# Fade in from black and show the floor name
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 0.7)
	var theme_data: Dictionary = ConfigManager.get_floor_theme(GameState.current_floor)
	banner_title.text = StringManager.t("floor_label", {value = GameState.current_floor, total = GameState.total_floors}).to_upper()
	banner_sub.text = StringManager.t(str(theme_data.get("name_key", "")))
	banner_sub.add_theme_color_override("font_color", Color("#" + str(theme_data.get("light", "ffd9a6"))))
	var area: Rect2 = map_area()
	banner.size = Vector2(area.size.x, 90)
	banner.position = Vector2(area.position.x, area.size.y * 0.22)
	banner.visible = true
	banner.modulate.a = 0.0
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(0.25)
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.35)
	_banner_tween.tween_interval(1.4)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.6)
	_banner_tween.tween_callback(func() -> void: banner.visible = false)
	if GameState.current_floor > 1:
		Sfx.play("stairs", 0.0)

func _on_entity_attacked(_attacker: Entity, target: Entity, damage: int, _crit: bool) -> void:
	if target == GameState.player:
		flash_damage(0.35 + 0.6 * float(damage) / float(maxi(GameState.player.hp_max, 1)))

func _on_entity_hurt(target: Entity, damage: int, _kind: String) -> void:
	_on_entity_attacked(null, target, damage, false)

func _on_mute_changed(muted: bool) -> void:
	_speaker.muted = muted
	_speaker.queue_redraw()

func _on_lang_pressed() -> void:
	var langs: Array[String] = ["en", "fr"]
	var idx: int = langs.find(StringManager.get_language())
	StringManager.set_language(langs[(idx + 1) % langs.size()])

func _on_language_changed(_lang: String) -> void:
	_refresh_texts()
	refresh()
	if end_overlay.visible:
		_fill_end_texts()

func _refresh_texts() -> void:
	lang_btn.text = StringManager.t("lang_button")
	inv_title.text = StringManager.t("inventory_title")
	look_title.text = StringManager.t("look_title")
	restart_btn.text = StringManager.t("restart_button")
	controls_lbl.text = StringManager.t("controls", {keys = _controls_keys})
	_action_bar.tooltip_text = StringManager.t("dash_tooltip", {range = ConfigManager.get_int("dash_range", 3),
		bonus = ConfigManager.get_int("dash_attack_bonus", 1), cooldown = ConfigManager.get_int("dash_cooldown", 6)}) \
		+ "\n\n" + StringManager.t("elan_tooltip", {max = ConfigManager.get_int("elan_max", 5),
		every = ConfigManager.get_int("elan_damage_every", 2), window = ConfigManager.get_int("elan_window", 4)})
	_energy_bar.tooltip_text = StringManager.t("energy_tooltip", {
		drain = ConfigManager.get_int("energy_drain_every", 0),
		regen = ConfigManager.get_int("hp_regen_every", 0),
		starve = ConfigManager.get_int("starve_damage_every", 0)})

func _fill_end_texts() -> void:
	end_title.text = StringManager.t("victory_title" if _victory else "game_over_title")
	end_title.add_theme_color_override("font_color", COL_GOLD if _victory else COL_HP)
	end_cause.text = StringManager.t("victory_text") if _victory else GameState.death_text()
	var p: PlayerEntity = GameState.player
	end_stats.text = StringManager.t("end_stats", {level = p.level, kills = GameState.kills, turns = GameState.turn,
		keys = GameState.keys_found, elan = GameState.best_elan})

# ---------------------------------------------------------------------------
# Look descriptions
# ---------------------------------------------------------------------------

func _describe_player() -> void:
	var p: PlayerEntity = GameState.player
	look_name.text = StringManager.t("level_label", {value = p.level})
	look_text.text = StringManager.t("look_player", {atk = p.attack, def = p.defense, crit = int(round(p.crit_chance * 100.0))})
	_look_icon.set_sprite("player")

func _describe_enemy(e: EnemyEntity) -> void:
	look_name.text = GameState.enemy_name(e, true)
	look_name.add_theme_color_override("font_color", e.color.lightened(0.3))
	var lines: Array[String] = [StringManager.t("look_enemy_stats", {hp = e.hp, max = e.hp_max, atk = e.attack, def = e.defense})]
	lines.append(StringManager.t("look_hunting") if e.alerted else StringManager.t("look_asleep"))
	if e.ai == "ranged":
		lines.append(StringManager.t("look_ranged", {range = e.attack_range}))
	if e.ai == "erratic":
		lines.append(StringManager.t("look_erratic"))
	if e.speed > 1.0:
		lines.append(StringManager.t("look_fast"))
	elif e.speed < 1.0:
		lines.append(StringManager.t("look_slow"))
	if e.ai == "thief":
		lines[1] = StringManager.t("look_thief_tired" if e.tired > 0 else ("look_thief_fleeing" if e.fleeing else "look_thief"))
	if e.key_carrier:
		lines.append(StringManager.t("look_key_carrier"))
	if e.splits:
		lines.append(StringManager.t("look_splits"))
	if e.revives:
		lines.append(StringManager.t("look_revives"))
	if e.heavy == "cleave":
		lines.append(StringManager.t("look_heavy"))
	elif e.heavy == "slam":
		lines.append(StringManager.t("look_enraged") if e.enraged else StringManager.t("look_slam", {every = e.heavy_every}))
	if e.massive:
		lines.append(StringManager.t("look_massive"))
	var dz: Dictionary = GameState.danger_of(e)
	if e.stunned > 0:
		lines.insert(1, StringManager.t("look_stunned"))
	elif not dz.is_empty():
		lines.insert(1, StringManager.t("look_aiming" if str(dz["kind"]) == "arrow" else "look_winding_up"))
	look_text.text = "\n".join(lines)
	_look_icon.set_sprite(e.sprite)

# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

func _build_bars() -> void:
	for spec in [[COL_HP, "hp"], [COL_ENERGY, "energy"], [COL_XP, "xp"]]:
		var bar := StatBar.new()
		bar.custom_minimum_size = Vector2(0, 20)
		bar.color = spec[0] as Color
		bar.mouse_filter = Control.MOUSE_FILTER_PASS
		bars_box.add_child(bar)
		match str(spec[1]):
			"hp": _hp_bar = bar
			"energy": _energy_bar = bar
			_: _xp_bar = bar

## Key row: where the floor's key is and how to find it; daggers on the right.
func _build_key_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var vbox: Node = bars_box.get_parent()
	vbox.add_child(row)
	vbox.move_child(row, $SidePanel/VBox/LevelRow.get_index() + 1)
	_key_icon = SpriteIcon.new()
	_key_icon.custom_minimum_size = Vector2(32, 32)
	_key_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_key_icon)
	_key_lbl = Label.new()
	_key_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_key_lbl.add_theme_font_size_override("font_size", 12)
	_key_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_key_lbl)
	_dagger_icon = SpriteIcon.new()
	_dagger_icon.custom_minimum_size = Vector2(32, 32)
	_dagger_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dagger_icon.set_sprite("dagger")
	row.add_child(_dagger_icon)
	_dagger_lbl = Label.new()
	_dagger_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dagger_lbl.add_theme_font_override("font", Sprites.bold_font())
	_dagger_lbl.add_theme_font_size_override("font_size", 14)
	_dagger_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_dagger_lbl)

func _refresh_key_row() -> void:
	var p: PlayerEntity = GameState.player
	var d: DungeonData = GameState.dungeon
	if p == null or d == null or _key_lbl == null:
		return
	var text: String
	var col: Color = COL_MUTED.lightened(0.3)
	if not d.stairs_locked:
		text = StringManager.t("keyrow_open_portal" if d.is_last_floor else "keyrow_open")
		col = Color("7ee08a")
		_key_icon.set_sprite("stairs" if not d.is_last_floor else "key", Color.WHITE)
	elif p.has_key:
		text = StringManager.t("keyrow_have")
		col = COL_GOLD
		_key_icon.set_sprite("key", Color.WHITE)
	elif d.is_last_floor:
		text = StringManager.t("keyrow_warden")
		_key_icon.set_sprite("key", Color(0.55, 0.55, 0.6))
	elif GameState.thief == null:
		text = StringManager.t("keyrow_dropped")
		col = COL_GOLD
		_key_icon.set_sprite("key", Color.WHITE)
	elif GameState.key_hint != Vector2.ZERO:
		text = StringManager.t("keyrow_heard", {dir = StringManager.t("dir_" + GameState.compass(GameState.key_hint))})
		col = COL_GOLD.lerp(COL_TEXT, 0.4)
		_key_icon.set_sprite("key", Color(1, 1, 1, 0.5 + 0.5 * GameState.key_hint_strength))
	elif GameState.thief.tired > 0 and bool(GameState.visible[GameState.thief.grid_pos.x][GameState.thief.grid_pos.y]):
		text = StringManager.t("keyrow_tired")
		col = COL_GOLD.lerp(COL_TEXT, 0.4)
		_key_icon.set_sprite("thief", Color.WHITE)
	else:
		text = StringManager.t("keyrow_thief")
		_key_icon.set_sprite("key", Color(0.55, 0.55, 0.6))
	_key_lbl.text = text
	_key_lbl.add_theme_color_override("font_color", col)
	_key_lbl.tooltip_text = StringManager.t("keyrow_tooltip", {hear = ConfigManager.get_int("key_hear_distance", 18)})
	_dagger_lbl.text = "%d/%d" % [p.daggers, p.daggers_max]
	_dagger_lbl.add_theme_color_override("font_color", COL_TEXT if p.daggers > 0 else Color(COL_MUTED, 0.6))
	_dagger_lbl.tooltip_text = StringManager.t("dagger_tooltip", {range = ConfigManager.get_int("dagger_range", 6)})
	_dagger_icon.set_sprite("dagger", Color.WHITE if p.daggers > 0 else Color(1, 1, 1, 0.35))

func _build_inventory() -> void:
	for i in ConfigManager.get_int("inventory_size", 0):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(126, 36)
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void: item_use_requested.emit(i))
		btn.gui_input.connect(_on_slot_gui_input.bind(i))
		inv_grid.add_child(btn)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)
		btn.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
		var key := Label.new()
		key.text = str(i + 1)
		key.add_theme_font_size_override("font_size", 11)
		key.add_theme_color_override("font_color", COL_MUTED)
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(key)
		var icon := SpriteIcon.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var name_lbl := Label.new()
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.max_lines_visible = 2   # "Parchemin de téléportation" spilled out of the slot
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)
		_slots.append(btn)
		_slot_icons.append(icon)
		_slot_names.append(name_lbl)

func _on_slot_gui_input(event: InputEvent, slot: int) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		item_drop_requested.emit(slot)

func _refresh_inventory() -> void:
	var inv: Array[Dictionary] = GameState.player.inventory
	for i in _slots.size():
		var icon: SpriteIcon = _slot_icons[i]
		if i < inv.size():
			var item: Dictionary = inv[i]
			icon.set_sprite(PixelArt.item_sprite(item))
			_slot_names[i].text = ItemDatabase.display_name(item)
			_slot_names[i].add_theme_color_override("font_color", COL_TEXT)
			_slots[i].tooltip_text = ItemDatabase.description(item)
		else:
			icon.set_sprite("")
			_slot_names[i].text = StringManager.t("slot_empty")
			_slot_names[i].add_theme_color_override("font_color", Color(COL_MUTED, 0.6))
			_slots[i].tooltip_text = ""

func _build_look_icon() -> void:
	_look_icon = SpriteIcon.new()
	_look_icon.custom_minimum_size = Vector2(48, 48)
	look_slot.add_child(_look_icon)
	_look_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_speaker = SpeakerIcon.new()
	sound_btn.add_child(_speaker)
	_speaker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)

# ---------------------------------------------------------------------------
# Theme & styling
# ---------------------------------------------------------------------------

func _sb(bg: Color, border: Color, radius: int, border_w: int, margin: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	s.anti_aliasing = true
	return s

## Dark plum panel, thin border, thicker on top: the panels sit in the same
## warm-dark range as the dungeon.
func _panel_box() -> StyleBoxFlat:
	var panel := _sb(COL_PANEL, COL_BORDER, 6, 1, 12)
	panel.border_width_top = 2
	panel.shadow_color = Color(0.02, 0.0, 0.05, 0.55)
	panel.shadow_size = 10
	return panel

func _build_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 14
	th.set_color("font_color", "Label", COL_TEXT)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.7))
	th.set_stylebox("panel", "PanelContainer", _panel_box())
	th.set_stylebox("normal", "Button", _sb(Color("1e1727"), Color("3e2d40"), 4, 1, 8))
	th.set_stylebox("hover", "Button", _sb(Color("2a2033"), COL_ACCENT, 4, 1, 8))
	th.set_stylebox("pressed", "Button", _sb(Color("150f1c"), COL_ACCENT, 4, 1, 8))
	th.set_stylebox("disabled", "Button", _sb(Color("17111d"), Color("2a2030"), 4, 1, 8))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", COL_TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_font("font", "Button", Sprites.bold_font())
	th.set_font_size("font_size", "Button", 14)
	th.set_stylebox("panel", "TooltipPanel", _sb(Color("0f0b15"), COL_ACCENT.darkened(0.3), 4, 1, 8))
	th.set_color("font_color", "TooltipLabel", COL_TEXT)
	th.set_font_size("font_size", "TooltipLabel", 13)
	return th

func _style_nodes() -> void:
	floor_title.add_theme_font_override("font", Sprites.bold_font())
	floor_title.add_theme_font_size_override("font_size", 17)
	floor_name.add_theme_font_size_override("font_size", 14)
	level_lbl.add_theme_font_override("font", Sprites.bold_font())
	level_lbl.add_theme_color_override("font_color", COL_XP.lightened(0.3))
	stats_lbl.add_theme_font_size_override("font_size", 13)
	stats_lbl.add_theme_color_override("font_color", COL_MUTED.lightened(0.2))
	for lbl in [inv_title, look_title]:
		(lbl as Label).add_theme_font_override("font", Sprites.bold_font())
		(lbl as Label).add_theme_font_size_override("font_size", 12)
		(lbl as Label).add_theme_color_override("font_color", COL_MUTED)
	look_panel.add_theme_stylebox_override("panel", _sb(Color(0.02, 0.0, 0.04, 0.35), Color(1, 0.85, 0.7, 0.07), 4, 1, 8))
	look_name.add_theme_font_override("font", Sprites.bold_font())
	look_name.add_theme_font_size_override("font_size", 14)
	look_text.add_theme_font_size_override("font_size", 12)
	look_text.add_theme_color_override("font_color", COL_MUTED.lightened(0.25))
	controls_lbl.add_theme_font_size_override("font_size", 11)
	controls_lbl.add_theme_color_override("font_color", Color(COL_MUTED, 0.85))
	log_panel.add_theme_stylebox_override("panel", _panel_box())
	floor_title.add_theme_color_override("font_color", COL_GOLD)
	banner_title.add_theme_font_override("font", Sprites.bold_font())
	banner_title.add_theme_font_size_override("font_size", 40)
	banner_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	banner_title.add_theme_constant_override("outline_size", 10)
	banner_sub.add_theme_font_size_override("font_size", 20)
	banner_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	banner_sub.add_theme_constant_override("outline_size", 8)
	end_title.add_theme_font_override("font", Sprites.bold_font())
	end_title.add_theme_font_size_override("font_size", 42)
	end_cause.add_theme_font_size_override("font_size", 16)
	end_stats.add_theme_font_size_override("font_size", 15)
	end_stats.add_theme_color_override("font_color", COL_MUTED.lightened(0.3))
	var accent := Color("c0603a")
	restart_btn.add_theme_stylebox_override("normal", _sb(accent.darkened(0.15), accent.lightened(0.2), 8, 1, 10))
	restart_btn.add_theme_stylebox_override("hover", _sb(accent, accent.lightened(0.4), 8, 1, 10))
	restart_btn.add_theme_font_size_override("font_size", 17)

func _setup_vignette() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity = 0.0;
uniform float base = 0.62;
uniform vec4 tint : source_color = vec4(0.9, 0.08, 0.12, 1.0);
uniform vec4 shade : source_color = vec4(0.03, 0.01, 0.07, 1.0);
uniform vec4 area = vec4(0.0, 0.0, 1.0, 1.0);   // map area in screen UV: x, y, w, h
void fragment() {
	vec2 uv = (UV - area.xy) / area.zw - vec2(0.5);
	float d = length(uv * vec2(1.0, 0.86));
	float v = smoothstep(0.3, 0.86, d);
	float hurt = clamp(intensity, 0.0, 1.0);
	vec3 col = mix(shade.rgb, tint.rgb, clamp(hurt * 2.2, 0.0, 1.0));
	COLOR = vec4(col, v * max(base, hurt));
}
"""
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = shader
	vignette.material = _vignette_mat

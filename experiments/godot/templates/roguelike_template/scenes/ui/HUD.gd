# =============================================================================
# HUD.gd (class GameHUD): side panel, message log frame, banners, overlays.
# =============================================================================
# Layout (scene Main.tscn):
#   SidePanel  floor title, HP / energy / XP bars, level and stats,
#              inventory (6 slots, click = use, right-click = drop),
#              "Look" box (what is under the mouse), minimap, controls
#   LogPanel   MessageLog (colored, rolling)
#   Banner     floor name when arriving on a floor
#   Fade       black fade-in after taking the stairs
#   EndOverlay death / victory screen with the cause and run stats
#   Vignette   red screen-edge flash when hurt, pulse at low HP (shader)
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

const COL_TEXT   := Color("e8edf5")
const COL_MUTED  := Color("8a97ab")
const COL_PANEL  := Color(0.07, 0.08, 0.12, 0.94)
const COL_BORDER := Color("2c3550")
const COL_HP     := Color("e8505b")
const COL_ENERGY := Color("f0b44a")
const COL_XP     := Color("a77dff")
const COL_GOLD   := Color("ffd34d")

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

## Item or actor icon (inventory slots, look box).
class SpriteIcon extends Control:
	var mode: String = "none"   # none, item, token
	var shape: String = ""
	var color: Color = Color.WHITE
	var glyph: String = ""
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var s: float = minf(size.x, size.y)
		if mode == "item":
			Sprites.draw_item(self, shape, color, c, s * 0.8)
		elif mode == "token":
			Sprites.draw_token(self, c + Vector2(0, -2), s * 0.38, color, glyph, 0.0)

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
var _controls_keys: String = "WASD"
var _vignette_mat: ShaderMaterial = null
var _flash:  float = 0.0
var _time:   float = 0.0
var _victory: bool = false
var _banner_tween: Tween = null

func _ready() -> void:
	theme = _build_theme()
	_setup_vignette()
	_build_bars()
	_build_inventory()
	_build_look_icon()
	_style_nodes()
	GameState.stats_changed.connect(refresh)
	GameState.dungeon_ready.connect(_on_dungeon_ready)
	GameState.entity_attacked.connect(_on_entity_attacked)
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
	_look_icon.mode = "none"
	look_text.text = ""
	if d == null or not d.in_bounds(tile):
		look_name.text = ""
		look_text.text = StringManager.t("look_hint")
		_look_icon.queue_redraw()
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
		_look_icon.mode = "item"
		_look_icon.shape = str(item.get("shape", ""))
		_look_icon.color = Color("#" + str(item.get("color", "ffffff")))
	else:
		match d.get_tile(tile):
			DungeonData.TileType.STAIRS_DOWN:
				look_name.text = StringManager.t("look_exit" if d.is_last_floor else "look_stairs")
			DungeonData.TileType.WALL:
				look_name.text = StringManager.t("look_wall")
			_:
				look_name.text = StringManager.t("look_floor")
	_look_icon.queue_redraw()

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
	_energy_bar.tooltip_text = StringManager.t("energy_tooltip", {
		drain = ConfigManager.get_int("energy_drain_every", 0),
		regen = ConfigManager.get_int("hp_regen_every", 0),
		starve = ConfigManager.get_int("starve_damage_every", 0)})

func _fill_end_texts() -> void:
	end_title.text = StringManager.t("victory_title" if _victory else "game_over_title")
	end_title.add_theme_color_override("font_color", COL_GOLD if _victory else COL_HP)
	end_cause.text = StringManager.t("victory_text") if _victory else GameState.death_text()
	var p: PlayerEntity = GameState.player
	end_stats.text = StringManager.t("end_stats", {level = p.level, kills = GameState.kills, turns = GameState.turn})

# ---------------------------------------------------------------------------
# Look descriptions
# ---------------------------------------------------------------------------

func _describe_player() -> void:
	var p: PlayerEntity = GameState.player
	look_name.text = StringManager.t("level_label", {value = p.level})
	look_text.text = StringManager.t("look_player", {atk = p.attack, def = p.defense, crit = int(round(p.crit_chance * 100.0))})
	_look_icon.mode = "token"
	_look_icon.color = p.color
	_look_icon.glyph = "@"

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
	look_text.text = "\n".join(lines)
	_look_icon.mode = "token"
	_look_icon.color = e.color
	_look_icon.glyph = e.glyph

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

func _build_inventory() -> void:
	for i in ConfigManager.get_int("inventory_size", 0):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(126, 40)
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
		icon.custom_minimum_size = Vector2(28, 28)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var name_lbl := Label.new()
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
			icon.mode = "item"
			icon.shape = str(item.get("shape", ""))
			icon.color = Color("#" + str(item.get("color", "ffffff")))
			_slot_names[i].text = ItemDatabase.display_name(item)
			_slot_names[i].add_theme_color_override("font_color", COL_TEXT)
			_slots[i].tooltip_text = ItemDatabase.description(item)
		else:
			icon.mode = "none"
			_slot_names[i].text = StringManager.t("slot_empty")
			_slot_names[i].add_theme_color_override("font_color", Color(COL_MUTED, 0.6))
			_slots[i].tooltip_text = ""
		icon.queue_redraw()

func _build_look_icon() -> void:
	_look_icon = SpriteIcon.new()
	_look_icon.custom_minimum_size = Vector2(40, 40)
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

func _build_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 14
	th.set_color("font_color", "Label", COL_TEXT)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.7))
	var panel := _sb(COL_PANEL, COL_BORDER, 10, 1, 12)
	panel.shadow_color = Color(0, 0, 0, 0.4)
	panel.shadow_size = 8
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("normal", "Button", _sb(Color("1d2436"), Color("2f3a56"), 7, 1, 8))
	th.set_stylebox("hover", "Button", _sb(Color("263049"), Color("5a73a0"), 7, 1, 8))
	th.set_stylebox("pressed", "Button", _sb(Color("151b2a"), Color("5a73a0"), 7, 1, 8))
	th.set_stylebox("disabled", "Button", _sb(Color("161b28"), Color("232a3d"), 7, 1, 8))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", COL_TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_font("font", "Button", Sprites.bold_font())
	th.set_font_size("font_size", "Button", 14)
	th.set_stylebox("panel", "TooltipPanel", _sb(Color("0b0e16"), COL_BORDER, 6, 1, 8))
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
	look_panel.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.06), 8, 1, 8))
	look_name.add_theme_font_override("font", Sprites.bold_font())
	look_name.add_theme_font_size_override("font_size", 14)
	look_text.add_theme_font_size_override("font_size", 12)
	look_text.add_theme_color_override("font_color", COL_MUTED.lightened(0.25))
	controls_lbl.add_theme_font_size_override("font_size", 11)
	controls_lbl.add_theme_color_override("font_color", Color(COL_MUTED, 0.85))
	log_panel.add_theme_stylebox_override("panel", _sb(COL_PANEL, COL_BORDER, 10, 1, 12))
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
	var accent := Color("38b866")
	restart_btn.add_theme_stylebox_override("normal", _sb(accent.darkened(0.15), accent.lightened(0.2), 8, 1, 10))
	restart_btn.add_theme_stylebox_override("hover", _sb(accent, accent.lightened(0.4), 8, 1, 10))
	restart_btn.add_theme_font_size_override("font_size", 17)

func _setup_vignette() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity = 0.0;
uniform vec4 tint : source_color = vec4(0.9, 0.08, 0.12, 1.0);
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.0, 0.8));
	float v = smoothstep(0.3, 0.78, d);
	COLOR = vec4(tint.rgb, v * intensity);
}
"""
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = shader
	vignette.material = _vignette_mat

# =============================================================================
# HUD.gd (UI layer): stats bar, shop, tower panel, wave panel, overlays.
# =============================================================================
# Layout (scene Main.tscn, containers only):
#   TopBar:     gold, lives, wave, score | speed, pause, sound, language
#   SidePanel:  shop cards (built from towers.json), selected tower panel,
#                next / current wave panel with the "Start wave" button
#   Banner:     big animated text over the map ("WAVE 3", "Wave cleared")
#   Hint:       contextual help under the map while placing a tower
#   Overlays:   pause menu, end screen (victory / defeat)
#   Vignette:   full-screen red edge flash on damage / low lives (shader)
#
# COMMUNICATION:
#   The HUD never touches the world. It emits intent signals that Main.gd
#   handles (tower_type_requested, upgrade_requested, ...), and Main calls the
#   public methods below (show_tower_panel, set_paused, show_end, ...).
#   Pure display state (gold, lives, phase...) is read from GameState signals.
#
# THEME:
#   Built in code (_build_theme) and assigned to this root Control, so every
#   descendant (including cards created at runtime) inherits the same styles.
# =============================================================================

class_name GameHUD
extends Control

signal tower_type_requested(type_id: String)
signal upgrade_requested()
signal sell_requested()
signal target_cycle_requested()
signal wave_requested()
signal speed_toggled()
signal pause_toggled()
signal restart_requested()

# Layout constants shared with Main.gd (map placement)
const TOP_BAR_H: float = 52.0
const SIDE_W:    float = 300.0
const MARGIN:    float = 10.0
# Shop card heights: name + stats + 2-line description, or name + stats only
const CARD_H:         float = 92.0
const CARD_H_COMPACT: float = 62.0

const COL_TEXT   := Color("e8edf5")
const COL_MUTED  := Color("8a97ab")
const COL_PANEL  := Color(0.10, 0.13, 0.19, 0.95)
const COL_BORDER := Color("2f3d55")
const COL_GOLD   := Color("ffd34d")
const COL_LIVES  := Color("ff5d6c")
const COL_WAVE   := Color("6cc6ff")
const COL_SCORE  := Color("c7a8ff")
const COL_ACCENT := Color("38b866")
const COL_GOOD   := Color("7ee08a")
const COL_BAD    := Color("ff6b6b")
const STAT_COLORS: Dictionary = {
	damage = Color("ff8f80"), range = Color("7cc4ff"),
	rate = Color("ffd34d"), splash = Color("ffa75e")}

@onready var gold_box:    HBoxContainer = $TopBar/Row/Gold
@onready var gold_lbl:    Label         = $TopBar/Row/Gold/Value
@onready var lives_box:   HBoxContainer = $TopBar/Row/Lives
@onready var lives_lbl:   Label         = $TopBar/Row/Lives/Value
@onready var wave_lbl:    Label         = $TopBar/Row/Wave/Value
@onready var score_lbl:   Label         = $TopBar/Row/Score/Value
@onready var speed_btn:   Button        = $TopBar/Row/SpeedButton
@onready var pause_btn:   Button        = $TopBar/Row/PauseButton
@onready var pause_icon:  HudIcon       = $TopBar/Row/PauseButton/Icon
@onready var sound_btn:   Button        = $TopBar/Row/SoundButton
@onready var sound_icon:  HudIcon       = $TopBar/Row/SoundButton/Icon
@onready var lang_btn:    Button        = $TopBar/Row/LangButton

@onready var shop_title:  Label          = $SidePanel/VBox/ShopTitle
@onready var shop_list:   VBoxContainer  = $SidePanel/VBox/ShopList
@onready var tower_panel: PanelContainer = $SidePanel/VBox/TowerPanel
@onready var tp_name:     Label          = $SidePanel/VBox/TowerPanel/VBox/Header/Name
@onready var tp_level:    Label          = $SidePanel/VBox/TowerPanel/VBox/Header/Level
@onready var tp_stats:    GridContainer  = $SidePanel/VBox/TowerPanel/VBox/Stats
@onready var tp_target:   Button         = $SidePanel/VBox/TowerPanel/VBox/TargetButton
@onready var tp_upgrade:  Button         = $SidePanel/VBox/TowerPanel/VBox/Actions/UpgradeButton
@onready var tp_sell:     Button         = $SidePanel/VBox/TowerPanel/VBox/Actions/SellButton
@onready var wave_title:  Label          = $SidePanel/VBox/WavePanel/VBox/Title
@onready var wave_chips:  HBoxContainer  = $SidePanel/VBox/WavePanel/VBox/Chips
@onready var wave_status: Label          = $SidePanel/VBox/WavePanel/VBox/Status
@onready var wave_bar:    ProgressBar    = $SidePanel/VBox/WavePanel/VBox/Progress
@onready var wave_btn:    Button         = $SidePanel/VBox/WavePanel/VBox/WaveButton
@onready var controls_lbl: Label         = $SidePanel/VBox/Controls

@onready var banner:      Label          = $Banner
@onready var hint:        Label          = $Hint
@onready var vignette:    ColorRect      = $"../Vignette"
@onready var pause_overlay: ColorRect    = $PauseOverlay
@onready var pause_title: Label          = $PauseOverlay/Center/Panel/VBox/Title
@onready var resume_btn:  Button         = $PauseOverlay/Center/Panel/VBox/ResumeButton
@onready var pause_restart_btn: Button   = $PauseOverlay/Center/Panel/VBox/RestartButton
@onready var end_overlay: ColorRect      = $EndOverlay
@onready var end_panel:   PanelContainer = $EndOverlay/Center/Panel
@onready var end_title:   Label          = $EndOverlay/Center/Panel/VBox/Title
@onready var end_stats:   Label          = $EndOverlay/Center/Panel/VBox/Stats
@onready var end_restart_btn: Button     = $EndOverlay/Center/Panel/VBox/RestartButton

var _wave_manager:  WaveManager = null
var _panel_tower:   Tower       = null
var _panel_key:     String      = ""
var _selected_type: String      = ""
var _cards:         Dictionary  = {}   # type_id -> {button, cost_label, icon, cost, normal, selected}
var _shown_gold:    float       = 0.0
var _flash:         float       = 0.0
var _time:          float       = 0.0
var _bold:          FontVariation = null
var _vignette_mat:  ShaderMaterial = null
var _banner_tween:  Tween = null
var _map_rect:      Rect2 = Rect2()
var _last_victory:  bool  = false

func _ready() -> void:
	_bold = FontVariation.new()
	_bold.base_font = ThemeDB.fallback_font
	_bold.variation_embolden = 0.8
	theme = _build_theme()
	_setup_vignette()
	_style_nodes()
	_connect_signals()
	_build_shop()
	_refresh_texts()
	tower_panel.visible   = false
	pause_overlay.visible = false
	end_overlay.visible   = false
	banner.visible        = false
	hint.text             = ""
	_sync_all()

func _connect_signals() -> void:
	GameState.gold_changed.connect(_on_gold)
	GameState.lives_changed.connect(_on_lives)
	GameState.score_changed.connect(_on_score)
	GameState.phase_changed.connect(_on_phase)
	GameState.wave_cleared.connect(_on_wave_cleared)
	GameState.life_lost.connect(_on_life_lost)
	GameState.early_bonus_awarded.connect(_on_early_bonus)
	StringManager.language_changed.connect(_on_language)
	Sfx.mute_changed.connect(_on_mute_changed)
	lang_btn.pressed.connect(_on_lang_pressed)
	sound_btn.pressed.connect(func() -> void: Sfx.toggle_mute())
	speed_btn.pressed.connect(_on_speed_pressed)
	pause_btn.pressed.connect(_on_pause_pressed)
	resume_btn.pressed.connect(_on_pause_pressed)
	pause_restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	end_restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	wave_btn.pressed.connect(func() -> void: wave_requested.emit())
	tp_target.pressed.connect(func() -> void: target_cycle_requested.emit())
	tp_upgrade.pressed.connect(func() -> void: upgrade_requested.emit())
	tp_sell.pressed.connect(func() -> void: sell_requested.emit())

func _click() -> void:
	Sfx.play("click", 0.0)

func _on_speed_pressed() -> void:
	_click()
	speed_toggled.emit()

func _on_pause_pressed() -> void:
	_click()
	pause_toggled.emit()

# ---------------------------------------------------------------------------
# Per-frame: rolling gold counter, vignette, live wave status
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	var target_gold: float = float(GameState.gold)
	if absf(_shown_gold - target_gold) > 0.5:
		var rate: float = maxf(absf(target_gold - _shown_gold) * 10.0, 40.0)
		_shown_gold = move_toward(_shown_gold, target_gold, rate * delta)
	else:
		_shown_gold = target_gold
	gold_lbl.text = str(int(round(_shown_gold)))

	_flash = maxf(_flash - delta * 1.5, 0.0)
	var low: bool = GameState.is_playing() and GameState.lives > 0 \
		and GameState.lives <= ConfigManager.get_int("low_lives_threshold", 0)
	var pulse: float = (0.2 + 0.1 * sin(_time * 4.0)) if low else 0.0
	_vignette_mat.set_shader_parameter("intensity", maxf(_flash, pulse))

	_update_wave_status()

# ---------------------------------------------------------------------------
# Public API (called by Main.gd)
# ---------------------------------------------------------------------------

func bind_wave_manager(wm: WaveManager) -> void:
	_wave_manager = wm
	_update_wave_label()
	_refresh_wave_panel()

func set_map_rect(rect: Rect2) -> void:
	_map_rect = rect
	hint.position = Vector2(rect.position.x, rect.end.y + 3.0)
	hint.size     = Vector2(rect.size.x, 26.0)

## Called after a restart: no rolling counter from the previous game's gold.
func reset_counters() -> void:
	_shown_gold = float(GameState.gold)
	_flash = 0.0
	hide_tower_panel()
	set_selected_type("")
	show_hint("")

func set_selected_type(type_id: String) -> void:
	_selected_type = type_id
	_refresh_shop_state()

func show_hint(text: String) -> void:
	hint.text = text

func show_tower_panel(tower: Tower) -> void:
	var was_hidden: bool = not tower_panel.visible
	_panel_tower = tower
	_panel_key = ""
	tower_panel.visible = true
	_set_compact(true)
	refresh_tower_panel()
	if was_hidden:
		tower_panel.modulate.a = 0.0
		create_tween().tween_property(tower_panel, "modulate:a", 1.0, 0.15)

func hide_tower_panel() -> void:
	_panel_tower = null
	tower_panel.visible = false
	_set_compact(false)

## With a tower selected, the shop hides its descriptions (the stats stay)
## and the controls line: the side panel keeps a fixed height and never
## covers the top bar.
func _set_compact(compact: bool) -> void:
	controls_lbl.visible = not compact
	for id in _cards:
		var card: Dictionary = _cards[id]
		var desc: Label = card["desc"] as Label
		var btn: Button = card["button"] as Button
		desc.visible = not compact
		btn.custom_minimum_size = Vector2(0, CARD_H_COMPACT if compact else CARD_H)

func refresh_tower_panel() -> void:
	if not is_instance_valid(_panel_tower):
		hide_tower_panel()
		return
	var t: Tower = _panel_tower
	var key: String = "%d_%d" % [t.get_instance_id(), t.level]
	if key != _panel_key:
		_panel_key = key
		_rebuild_tower_stats(t)
	tp_name.text = StringManager.t_or("tower_%s_name" % t.tower_id, str(t.data.get("display_name", t.tower_id)))
	tp_name.add_theme_color_override("font_color", t.color.lightened(0.25))
	tp_level.text = StringManager.t("level_label", {value = t.level})
	tp_target.text = StringManager.t("target_label", {mode = StringManager.t(t.target_key())})
	var cost: int = t.next_upgrade_cost()
	if cost < 0:
		tp_upgrade.text = StringManager.t("upgrade_max")
		tp_upgrade.disabled = true
	else:
		tp_upgrade.text = StringManager.t("upgrade_button", {cost = cost})
		tp_upgrade.disabled = not GameState.can_afford(cost)
	tp_sell.text = StringManager.t("sell_button", {value = t.sell_value()})

func set_speed(mult: float) -> void:
	speed_btn.text = "x%d" % int(round(mult))
	speed_btn.add_theme_color_override("font_color", COL_GOLD if mult > 1.0 else COL_TEXT)
	speed_btn.add_theme_color_override("font_hover_color", COL_GOLD if mult > 1.0 else Color.WHITE)

func set_paused(paused: bool) -> void:
	pause_overlay.visible = paused
	pause_icon.kind = "play" if paused else "pause"
	if paused:
		pause_overlay.modulate.a = 0.0
		create_tween().tween_property(pause_overlay, "modulate:a", 1.0, 0.15)

func show_end(victory: bool) -> void:
	_last_victory = victory
	_fill_end_texts()
	end_overlay.visible = true
	end_overlay.modulate.a = 0.0
	end_panel.pivot_offset = end_panel.size * 0.5
	end_panel.scale = Vector2(0.7, 0.7)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(end_overlay, "modulate:a", 1.0, 0.35)
	tw.tween_property(end_panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_end() -> void:
	end_overlay.visible = false

func flash_damage(strength: float = 0.6) -> void:
	_flash = maxf(_flash, strength)

func show_banner(text: String, color: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.size = Vector2(_map_rect.size.x, 90.0)
	banner.position = Vector2(_map_rect.position.x, _map_rect.position.y + _map_rect.size.y * 0.3 - 45.0)
	banner.pivot_offset = banner.size * 0.5
	banner.visible = true
	banner.scale = Vector2(0.5, 0.5)
	banner.modulate.a = 0.0
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.2)
	_banner_tween.chain().tween_interval(1.1)
	_banner_tween.chain().tween_property(banner, "modulate:a", 0.0, 0.45)
	_banner_tween.tween_property(banner, "scale", Vector2(1.08, 1.08), 0.45)
	_banner_tween.chain().tween_callback(func() -> void: banner.visible = false)

# ---------------------------------------------------------------------------
# GameState signals
# ---------------------------------------------------------------------------

func _on_gold(value: int) -> void:
	if float(value) > _shown_gold + 0.5:
		_pop(gold_box, Color(1.4, 1.3, 0.8), 1.15)
	elif float(value) < _shown_gold - 0.5:
		_pop(gold_box, Color(1.4, 0.6, 0.6), 1.08)
	_refresh_shop_state()
	if tower_panel.visible:
		refresh_tower_panel()

func _on_lives(value: int) -> void:
	lives_lbl.text = str(value)
	var low: bool = value <= ConfigManager.get_int("low_lives_threshold", 0)
	lives_lbl.add_theme_color_override("font_color", COL_LIVES if low else COL_TEXT)

func _on_score(value: int) -> void:
	score_lbl.text = str(value)

func _on_life_lost(_amount: int) -> void:
	flash_damage(0.65)
	_pop(lives_box, Color(1.8, 0.5, 0.5), 1.35)

func _on_phase(p: GameState.Phase) -> void:
	_update_wave_label()
	_refresh_wave_panel()
	_refresh_shop_state()
	if p == GameState.Phase.WAVE:
		var is_final: bool = GameState.wave_index == GameState.total_waves - 1
		var text: String = StringManager.t("banner_final") if is_final \
			else StringManager.t("banner_wave", {value = GameState.wave_index + 1})
		show_banner(text, COL_LIVES if is_final else COL_WAVE)

func _on_wave_cleared(_wave_index: int, bonus: int) -> void:
	if GameState.wave_index >= GameState.total_waves:
		return   # victory: Main runs the end sequence
	show_banner(StringManager.t("banner_cleared", {gold = bonus}), COL_GOLD)
	Sfx.play("clear", 0.0)
	_float_label("+%d" % bonus, COL_GOLD)

func _on_early_bonus(amount: int) -> void:
	Sfx.play("coin", 0.0)
	_float_label(StringManager.t("early_bonus", {gold = amount}), COL_GOLD)

func _on_mute_changed(is_muted: bool) -> void:
	sound_icon.kind = "mute" if is_muted else "sound"

# ---------------------------------------------------------------------------
# Wave panel
# ---------------------------------------------------------------------------

func _update_wave_label() -> void:
	var shown: int = mini(GameState.wave_index + 1, maxi(GameState.total_waves, 1))
	wave_lbl.text = StringManager.t("wave_label", {current = shown, total = GameState.total_waves})

func _refresh_wave_panel() -> void:
	for c in wave_chips.get_children():
		c.free()
	var idx: int = GameState.wave_index
	if _wave_manager == null or idx >= GameState.total_waves:
		wave_title.text = ""
		return
	var is_final: bool = idx == GameState.total_waves - 1
	var title_key: String = "final_wave_title" if is_final else "next_wave_title"
	if GameState.phase == GameState.Phase.WAVE:
		wave_title.text = StringManager.t("wave_label", {current = idx + 1, total = GameState.total_waves}).to_upper()
	else:
		wave_title.text = "%s  %d/%d" % [StringManager.t(title_key), idx + 1, GameState.total_waves]
	wave_title.add_theme_color_override("font_color", COL_LIVES if is_final else COL_MUTED)
	var hp_mult: float = _wave_manager.hp_multiplier(idx)
	for entry in _wave_manager.get_composition(idx):
		wave_chips.add_child(_make_enemy_chip(str(entry["type"]), int(entry["count"]), hp_mult))

func _make_enemy_chip(type_id: String, count: int, hp_mult: float) -> Control:
	var data: Dictionary = EnemyDatabase.get_type(type_id)
	var chip := PanelContainer.new()
	var sb := _sb(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.08), 6, 1, 4)
	sb.content_margin_left = 3
	sb.content_margin_right = 8
	chip.add_theme_stylebox_override("panel", sb)
	chip.tooltip_text = StringManager.t("enemy_tooltip", {
		name  = StringManager.t_or("enemy_" + type_id, str(data.get("display_name", type_id))),
		hp    = int(round(float(data.get("hp", 0)) * hp_mult)),
		armor = int(data.get("armor", 0)),
		lives = int(data.get("lives_damage", 1))})
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	chip.add_child(row)
	var icon := HudIcon.new()
	icon.kind = "enemy:" + type_id
	icon.animate = true
	icon.custom_minimum_size = Vector2(28, 28)
	row.add_child(icon)
	var lbl := Label.new()
	lbl.text = "x%d" % count
	lbl.add_theme_font_override("font", _bold)
	lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(lbl)
	return chip

func _update_wave_status() -> void:
	match GameState.phase:
		GameState.Phase.BUILD:
			wave_btn.disabled = false
			if GameState.next_wave_timer > 0.0:
				var total: float = maxf(ConfigManager.get_float("wave_between_delay", 1.0), 0.01)
				wave_bar.visible = true
				wave_bar.value = GameState.next_wave_timer / total
				wave_status.text = StringManager.t("countdown_label", {sec = int(ceil(GameState.next_wave_timer))})
				wave_btn.text = StringManager.t("call_early_button", {gold = GameState.early_bonus_preview()})
				wave_btn.modulate = Color.WHITE
			else:
				wave_bar.visible = false
				wave_status.text = ""
				wave_btn.text = StringManager.t("start_wave_button")
				# First wave: the button breathes to tell the player what to do
				var k: float = 0.5 + 0.5 * sin(_time * 4.0)
				wave_btn.modulate = Color(1.0 + 0.25 * k, 1.0 + 0.25 * k, 1.0 + 0.25 * k)
		GameState.Phase.WAVE:
			wave_btn.disabled = true
			wave_btn.modulate = Color.WHITE
			wave_btn.text = StringManager.t("start_wave_button")
			wave_status.text = StringManager.t("wave_in_progress")
			wave_bar.visible = _wave_manager != null
			if _wave_manager != null:
				wave_bar.value = float(_wave_manager.remaining()) / float(maxi(_wave_manager.wave_total(), 1))
		_:
			wave_btn.disabled = true
			wave_btn.modulate = Color.WHITE
			wave_status.text = ""
			wave_bar.visible = false

# ---------------------------------------------------------------------------
# Shop
# ---------------------------------------------------------------------------

func _build_shop() -> void:
	for c in shop_list.get_children():
		c.free()   # immediate: new cards are added right after
	_cards.clear()
	var index: int = 0
	for data_v in TowerDatabase.get_all():
		var data: Dictionary = data_v as Dictionary
		index += 1
		var id: String = str(data.get("id", ""))
		var col := Color("#" + str(data.get("color", "ffffff")))
		var cost: int = int(data.get("cost", 0))

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, CARD_H)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(_on_card_pressed.bind(id))
		btn.tooltip_text = _stats_tooltip(data)
		shop_list.add_child(btn)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		btn.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)

		var icon := HudIcon.new()
		icon.kind = "tower:" + id
		icon.custom_minimum_size = Vector2(56, 56)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)

		var info := VBoxContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.add_theme_constant_override("separation", 1)
		row.add_child(info)

		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(top)
		var name_lbl := Label.new()
		name_lbl.text = StringManager.t_or("tower_%s_name" % id, str(data.get("display_name", id)))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_override("font", _bold)
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", col.lightened(0.35))
		top.add_child(name_lbl)
		var coin := HudIcon.new()
		coin.kind = "coin"
		coin.custom_minimum_size = Vector2(15, 15)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(coin)
		var cost_lbl := Label.new()
		cost_lbl.text = str(cost)
		cost_lbl.add_theme_font_override("font", _bold)
		cost_lbl.add_theme_font_size_override("font_size", 15)
		top.add_child(cost_lbl)
		var key_lbl := Label.new()
		key_lbl.text = str(index)
		key_lbl.add_theme_font_size_override("font_size", 11)
		key_lbl.add_theme_color_override("font_color", COL_MUTED)
		var key_sb := _sb(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.15), 4, 1, 0)
		key_sb.content_margin_left = 5
		key_sb.content_margin_right = 5
		key_lbl.add_theme_stylebox_override("normal", key_sb)
		top.add_child(key_lbl)

		info.add_child(_make_card_stats(data))

		var desc := Label.new()
		desc.text = StringManager.t_or("tower_%s_desc" % id, "")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", COL_MUTED)
		info.add_child(desc)

		_cards[id] = {
			button = btn, cost_label = cost_lbl, icon = icon, cost = cost, desc = desc,
			normal = _card_styles(col, false), selected = _card_styles(col, true)}
	_refresh_shop_state()
	_set_compact(tower_panel.visible)

## Always-visible stats line of a shop card (level 1): the player compares
## towers at a glance, before buying. Same icons and colors as the tower panel.
func _make_card_stats(data: Dictionary) -> HBoxContainer:
	var s: Dictionary = Tower.stats_for(data, 1)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 9)
	_card_stat(line, "damage", String.num(float(s["damage"]), 0))
	_card_stat(line, "range", String.num(float(s["range"]), 1))
	_card_stat(line, "rate", String.num(float(s["fire_rate"]), 2) + "/s")
	if float(s["splash_radius"]) > 0.0:
		_card_stat(line, "splash", String.num(float(s["splash_radius"]), 2))
	return line

func _card_stat(line: HBoxContainer, kind: String, value: String) -> void:
	var group := HBoxContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_theme_constant_override("separation", 3)
	line.add_child(group)
	var icon := HudIcon.new()
	icon.kind = kind
	icon.tint = STAT_COLORS[kind]
	icon.custom_minimum_size = Vector2(13, 13)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	group.add_child(icon)
	var lbl := Label.new()
	lbl.text = value
	lbl.add_theme_font_override("font", _bold)
	lbl.add_theme_font_size_override("font_size", 12)
	group.add_child(lbl)

## Level 1 stats with their names, as the card tooltip.
func _stats_tooltip(data: Dictionary) -> String:
	var s: Dictionary = Tower.stats_for(data, 1)
	var text: String = "%s %d   ·   %s %.1f   ·   %s %.2f/s" % [
		StringManager.t("stat_damage"), int(s["damage"]),
		StringManager.t("stat_range"), float(s["range"]),
		StringManager.t("stat_rate"), float(s["fire_rate"])]
	if float(s["splash_radius"]) > 0.0:
		text += "   ·   %s %.2f" % [StringManager.t("stat_splash"), float(s["splash_radius"])]
	return text

## Returns {normal, hover, pressed} styleboxes for a card.
func _card_styles(col: Color, selected: bool) -> Dictionary:
	var border_w: int = 2 if selected else 1
	var normal := _sb(col.darkened(0.78 if not selected else 0.62), col.darkened(0.25) if not selected else col.lightened(0.2), 9, border_w, 0)
	var hover := _sb(col.darkened(0.68 if not selected else 0.58), col.lightened(0.1), 9, border_w, 0)
	var pressed := _sb(col.darkened(0.55), col.lightened(0.3), 9, border_w, 0)
	if selected:
		for sb: StyleBoxFlat in [normal, hover, pressed]:
			sb.shadow_color = Color(col, 0.45)
			sb.shadow_size = 8
	return {normal = normal, hover = hover, pressed = pressed}

func _refresh_shop_state() -> void:
	var playing: bool = GameState.is_playing()
	for id in _cards:
		var card: Dictionary = _cards[id]
		var btn: Button = card["button"] as Button
		var selected: bool = id == _selected_type
		var styles: Dictionary = card["selected"] if selected else card["normal"]
		btn.add_theme_stylebox_override("normal", styles["normal"] as StyleBox)
		btn.add_theme_stylebox_override("hover", styles["hover"] as StyleBox)
		btn.add_theme_stylebox_override("pressed", styles["pressed"] as StyleBox)
		btn.add_theme_stylebox_override("disabled", styles["normal"] as StyleBox)
		var affordable: bool = GameState.can_afford(int(card["cost"]))
		(card["cost_label"] as Label).add_theme_color_override("font_color", COL_GOLD if affordable else COL_BAD)
		btn.modulate = Color(1, 1, 1, 1.0 if (affordable or selected) else 0.55)
		var icon: HudIcon = card["icon"] as HudIcon
		icon.animate = selected
		btn.disabled = not playing

func _on_card_pressed(type_id: String) -> void:
	_click()
	tower_type_requested.emit(type_id)

# ---------------------------------------------------------------------------
# Tower panel
# ---------------------------------------------------------------------------

func _rebuild_tower_stats(t: Tower) -> void:
	for c in tp_stats.get_children():
		c.free()
	var now: Dictionary = Tower.stats_for(t.data, t.level)
	var has_next: bool = t.level < t.max_level()
	var next: Dictionary = Tower.stats_for(t.data, t.level + 1) if has_next else now
	_stat_row("damage", "stat_damage", float(now["damage"]), float(next["damage"]), "%d")
	_stat_row("range", "stat_range", float(now["range"]), float(next["range"]), "%.1f")
	_stat_row("rate", "stat_rate", float(now["fire_rate"]), float(next["fire_rate"]), "%.2f/s")
	if t.attack == "shell":
		_stat_row("splash", "stat_splash", float(now["splash_radius"]), float(next["splash_radius"]), "%.2f")

func _stat_row(icon_kind: String, label_key: String, value: float, next_value: float, fmt: String) -> void:
	var icon := HudIcon.new()
	icon.kind = icon_kind
	icon.tint = STAT_COLORS[icon_kind]
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tp_stats.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = StringManager.t(label_key)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", COL_MUTED)
	name_lbl.add_theme_font_size_override("font_size", 13)
	tp_stats.add_child(name_lbl)
	var value_lbl := Label.new()
	value_lbl.text = fmt % value
	value_lbl.add_theme_font_override("font", _bold)
	value_lbl.add_theme_font_size_override("font_size", 13)
	tp_stats.add_child(value_lbl)
	var next_lbl := Label.new()
	var delta: float = next_value - value
	next_lbl.text = ("+" + fmt % delta) if delta > 0.001 else ""
	next_lbl.custom_minimum_size = Vector2(52, 0)
	next_lbl.add_theme_color_override("font_color", COL_GOOD)
	next_lbl.add_theme_font_size_override("font_size", 12)
	tp_stats.add_child(next_lbl)

# ---------------------------------------------------------------------------
# Language & texts
# ---------------------------------------------------------------------------

func _on_lang_pressed() -> void:
	_click()
	var langs: Array[String] = ["en", "fr"]
	var idx: int = langs.find(StringManager.get_language())
	StringManager.set_language(langs[(idx + 1) % langs.size()])

func _on_language(_lang: String) -> void:
	_build_shop()
	_refresh_texts()
	_sync_all()
	if end_overlay.visible:
		_fill_end_texts()

func _refresh_texts() -> void:
	lang_btn.text          = StringManager.t("lang_button")
	shop_title.text        = StringManager.t("shop_title")
	controls_lbl.text      = StringManager.t("controls")
	pause_title.text       = StringManager.t("paused_title")
	resume_btn.text        = StringManager.t("resume_button")
	pause_restart_btn.text = StringManager.t("restart_button")
	end_restart_btn.text   = StringManager.t("restart_button")

func _fill_end_texts() -> void:
	end_title.text = StringManager.t("victory_title" if _last_victory else "game_over_title")
	end_title.add_theme_color_override("font_color", COL_GOLD if _last_victory else COL_LIVES)
	var waves: int = GameState.total_waves if _last_victory else GameState.wave_index
	end_stats.text = StringManager.t("stats_line", {waves = waves, kills = GameState.kills, score = GameState.score})

func _sync_all() -> void:
	_shown_gold = float(GameState.gold)
	gold_lbl.text = str(GameState.gold)
	_on_lives(GameState.lives)
	_on_score(GameState.score)
	_on_mute_changed(Sfx.muted)
	set_speed(Engine.time_scale)
	_update_wave_label()
	_refresh_wave_panel()
	_refresh_shop_state()
	if tower_panel.visible:
		_panel_key = ""
		refresh_tower_panel()

# ---------------------------------------------------------------------------
# Juice helpers
# ---------------------------------------------------------------------------

## Scale "pop" + color flash on a control (value changed).
func _pop(ctrl: Control, flash: Color, amount: float) -> void:
	ctrl.pivot_offset = ctrl.size * 0.5
	ctrl.scale = Vector2(amount, amount)
	ctrl.modulate = flash
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "modulate", Color.WHITE, 0.35)

## Text that rises and fades from the gold counter (bonuses).
func _float_label(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", _bold)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("outline_size", 6)
	add_child(lbl)
	lbl.position = gold_box.global_position + Vector2(0, 30)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 34.0, 1.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tw.chain().tween_callback(lbl.queue_free)

# ---------------------------------------------------------------------------
# Theme & static styling
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

	var panel := _sb(COL_PANEL, COL_BORDER, 12, 1, 12)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 10
	panel.shadow_offset = Vector2(0, 4)
	th.set_stylebox("panel", "PanelContainer", panel)

	th.set_stylebox("normal", "Button", _sb(Color("27334b"), Color("36476a"), 8, 1, 10))
	th.set_stylebox("hover", "Button", _sb(Color("31415f"), Color("5a73a0"), 8, 1, 10))
	th.set_stylebox("pressed", "Button", _sb(Color("1c2536"), Color("5a73a0"), 8, 1, 10))
	th.set_stylebox("disabled", "Button", _sb(Color(0.14, 0.17, 0.23, 0.7), Color(0.2, 0.24, 0.32, 0.7), 8, 1, 10))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", COL_TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", COL_TEXT)
	th.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(0.6, 0.65, 0.75, 0.6))
	th.set_font("font", "Button", _bold)
	th.set_font_size("font_size", "Button", 14)

	th.set_stylebox("background", "ProgressBar", _sb(Color(0, 0, 0, 0.4), Color(0, 0, 0, 0), 4, 0, 0))
	th.set_stylebox("fill", "ProgressBar", _sb(COL_WAVE, Color(0, 0, 0, 0), 4, 0, 0))

	th.set_stylebox("panel", "TooltipPanel", _sb(Color("0e131c"), COL_BORDER, 6, 1, 8))
	th.set_color("font_color", "TooltipLabel", COL_TEXT)
	th.set_font_size("font_size", "TooltipLabel", 13)
	return th

func _style_nodes() -> void:
	for lbl in [gold_lbl, lives_lbl, wave_lbl, score_lbl]:
		(lbl as Label).add_theme_font_override("font", _bold)
		(lbl as Label).add_theme_font_size_override("font_size", 18)
	gold_lbl.add_theme_color_override("font_color", COL_GOLD)
	wave_lbl.add_theme_color_override("font_color", COL_WAVE)
	score_lbl.add_theme_color_override("font_color", COL_SCORE)

	for lbl in [shop_title, wave_title]:
		(lbl as Label).add_theme_font_override("font", _bold)
		(lbl as Label).add_theme_font_size_override("font_size", 12)
		(lbl as Label).add_theme_color_override("font_color", COL_MUTED)
	tp_name.add_theme_font_override("font", _bold)
	tp_name.add_theme_font_size_override("font_size", 17)
	tp_level.add_theme_color_override("font_color", COL_GOLD)
	tp_level.add_theme_font_size_override("font_size", 13)
	wave_status.add_theme_font_size_override("font_size", 13)
	wave_status.add_theme_color_override("font_color", COL_TEXT)
	controls_lbl.add_theme_font_size_override("font_size", 11)
	controls_lbl.add_theme_color_override("font_color", Color(COL_MUTED, 0.8))

	var inner := _sb(Color(0, 0, 0, 0.22), Color(1, 1, 1, 0.06), 10, 1, 10)
	tower_panel.add_theme_stylebox_override("panel", inner)
	$SidePanel/VBox/WavePanel.add_theme_stylebox_override("panel", inner)

	# Accent "Start wave" button
	wave_btn.add_theme_stylebox_override("normal", _sb(COL_ACCENT.darkened(0.15), COL_ACCENT.lightened(0.2), 8, 1, 10))
	wave_btn.add_theme_stylebox_override("hover", _sb(COL_ACCENT, COL_ACCENT.lightened(0.4), 8, 1, 10))
	wave_btn.add_theme_stylebox_override("pressed", _sb(COL_ACCENT.darkened(0.3), COL_ACCENT.lightened(0.2), 8, 1, 10))
	wave_btn.add_theme_font_size_override("font_size", 16)
	# Sell button reads as "money back", upgrade as the main action
	tp_upgrade.add_theme_stylebox_override("normal", _sb(Color("3a3320"), Color("8a7330"), 8, 1, 10))
	tp_upgrade.add_theme_stylebox_override("hover", _sb(Color("4a4128"), COL_GOLD, 8, 1, 10))
	tp_upgrade.add_theme_color_override("font_color", COL_GOLD)

	banner.add_theme_font_override("font", _bold)
	banner.add_theme_font_size_override("font_size", 46)
	banner.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.9))
	banner.add_theme_constant_override("outline_size", 12)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(COL_TEXT, 0.85))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	hint.add_theme_constant_override("outline_size", 4)

	for lbl in [pause_title, end_title]:
		(lbl as Label).add_theme_font_override("font", _bold)
		(lbl as Label).add_theme_font_size_override("font_size", 44)
	end_stats.add_theme_font_size_override("font_size", 16)
	end_stats.add_theme_color_override("font_color", COL_TEXT)
	var accent_restart := _sb(COL_ACCENT.darkened(0.15), COL_ACCENT.lightened(0.2), 8, 1, 10)
	end_restart_btn.add_theme_stylebox_override("normal", accent_restart)
	end_restart_btn.add_theme_stylebox_override("hover", _sb(COL_ACCENT, COL_ACCENT.lightened(0.4), 8, 1, 10))
	end_restart_btn.add_theme_font_size_override("font_size", 17)

func _setup_vignette() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.12, 0.18, 1.0);
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

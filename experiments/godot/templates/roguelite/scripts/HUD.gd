class_name RogueHUD
extends CanvasLayer

# HUD: status panel, goal, messages, direction labels, options, intro,
# upgrade choice and end screens.
#
# UPGRADE CHOICE: after each delivered core (GameManager.upgrade_offered),
#   three cards, one per upgrade, each with what it does and its effect in
#   numbers for the next level ("Rooms with a crystal: 10 % -> 13 %"). Click
#   a card's button or press 1, 2, 3 (number row by physical position, or
#   keypad). A maxed upgrade's card is disabled. The end screen offers no
#   upgrade: it sums up the run and lists the upgrades kept.
#
# DIRECTION LABELS: the arrows themselves are 3D meshes (DirectionGizmo,
#   child of the player). The HUD only writes, in 2D, each arrow's key
#   letter at the projected label point of the arrow, and the distance in
#   rooms next to the golden goal arrow (hidden, like the arrow, when the
#   goal is close). Labels are drawn farthest first, and
#   fade out when they come close to the player on screen (arrow pointing
#   almost straight at or away from the camera).

signal start_requested()

const COL_TEXT  := Color("e8edf5")
const COL_MUTED := Color("8a97ab")
const COL_GOOD  := Color("6be08a")
const COL_BAD   := Color("ff6b6b")
const COL_GOLD  := Color("ffd34d")
const COL_CYAN  := Color("6fe3ff")
const KIND_COLORS: Dictionary = {good = Color("6be08a"), bad = Color("ff6b6b"), warn = Color("ffad5e"), info = Color("c8d2e6")}

class Gizmo extends Control:
	var hud: RogueHUD = null
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if hud == null or hud.camera == null or hud.player == null or not GameManager.can_act():
			return
		var cam: Camera3D = hud.camera
		var origin: Vector3 = hud.player.global_position
		if cam.is_position_behind(origin):
			return
		var center: Vector2 = cam.unproject_position(origin)
		var items: Array = []   # [camera distance, world point, text, color, font size]
		for dir in GridManager.DIRS:
			var open: bool = hud.grid.can_move(hud.player.cell, dir)
			var reach: float = DirectionGizmo.OPEN_LABEL if open else DirectionGizmo.BLOCKED_LABEL
			var col: Color = Color(0.6, 1.0, 0.7) if open else Color(1.0, 0.6, 0.6, 0.55)
			var p: Vector3 = origin + Vector3(dir) * reach
			items.append([cam.global_position.distance_to(p), p, hud.key_label(hud.player.to_relative(dir)), col, 16])
		var to_goal: Vector3 = Vector3(hud.goal_cell()) - origin
		if to_goal.length() > DirectionGizmo.GOAL_MIN_DIST:
			var g: Vector3 = origin + to_goal.normalized() * DirectionGizmo.GOAL_LABEL
			items.append([cam.global_position.distance_to(g), g, str(hud.goal_distance()), COL_GOLD, 18])
		items.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		var font: Font = ThemeDB.fallback_font
		for it in items:
			var p: Vector3 = it[1]
			if cam.is_position_behind(p):
				continue
			var at: Vector2 = cam.unproject_position(p)
			var col: Color = it[3]
			col.a *= smoothstep(10.0, 26.0, at.distance_to(center))
			if col.a <= 0.01:
				continue
			var text: String = it[2]
			var size: int = it[4]
			var pos: Vector2 = at + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5, size * 0.35)
			draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.8 * col.a))
			draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

class EnergyBar extends Control:
	var value: float = 0.0
	var max_value: float = 1.0
	var _shown: float = 0.0
	func _process(delta: float) -> void:
		_shown = move_toward(_shown, value, delta * max_value * 1.5)
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
		var ratio: float = clampf(_shown / maxf(max_value, 1.0), 0.0, 1.0)
		var col: Color = Color("6fe3ff") if ratio > 0.3 else Color("ff6b6b")
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y)), col)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ratio, 3.0)), col.lightened(0.4))
		var font: Font = ThemeDB.fallback_font
		var text: String = "%s  %d/%d" % [Strings.t("energy"), int(value), int(max_value)]
		draw_string_outline(font, Vector2(6, size.y * 0.5 + 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(6, size.y * 0.5 + 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

var camera: Camera3D = null
var player: PlayerPawn = null
var grid: GridManager = null

var _status: PanelContainer
var _level_lbl: Label
var _bar: EnergyBar
var _crystal_lbl: Label
var _bomb_lbl: Label
var _best_lbl: Label
var _goal_lbl: Label
var _msg_box: VBoxContainer
var _controls_lbl: Label
var _camera_lbl: Label
var _radius_title: Label
var _radius_slider: HSlider
var _radius_value: Label
var _far_title: Label
var _far_slider: HSlider
var _far_value: Label
var _kb_title: Label
var _kb_option: OptionButton
var _lang_btn: Button
var _intro: PanelContainer
var _intro_title: Label
var _intro_text: Label
var _start_btn: Button
var _over: ColorRect
var _over_title: Label
var _over_stats: Label
var _over_kept: Label
var _restart_btn: Button
var _choice: ColorRect
var _choice_title: Label
var _choice_text: Label
var _cards: Dictionary = {}   # upgrade id -> {name, desc, effect, level, button}
var _banner: Label
var _flash: ColorRect

func bind(cam: Camera3D, pawn: PlayerPawn, g: GridManager) -> void:
	camera = cam
	player = pawn
	grid = g

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _build_theme()
	add_child(root)
	var gizmo := Gizmo.new()
	gizmo.hud = self
	gizmo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(gizmo)
	_build_status(root)
	_build_overlays(root)
	GameManager.energy_changed.connect(_on_energy)
	GameManager.level_started.connect(_on_level_started)
	GameManager.core_collected_changed.connect(func(_c: bool) -> void: _refresh())
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.message.connect(_on_message)
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.upgrade_offered.connect(_on_upgrade_offered)
	GameManager.upgrades_changed.connect(_refresh)
	GameManager.settings_changed.connect(_sync_options)
	Keyboard.layout_changed.connect(_refresh_texts)
	Strings.language_changed.connect(func(_l: String) -> void: _refresh_texts())
	_refresh_texts()
	show_intro()

func _process(_delta: float) -> void:
	if GameManager.running and grid != null:
		_goal_lbl.text = Strings.t("goal_back" if GameManager.core_collected else "goal_core", {dist = goal_distance()})

# ---------------------------------------------------------------------------
# Public helpers (used by the gizmo)
# ---------------------------------------------------------------------------

func goal_cell() -> Vector3i:
	return grid.teleporter_pos if GameManager.core_collected else grid.core_pos

func goal_distance() -> int:
	var d: Vector3i = (goal_cell() - player.cell).abs()
	return d.x + d.y + d.z

func key_label(dir: Vector3i) -> String:
	return Keyboard.label(dir)

## Intro: no run yet, so the status panel and the goal are hidden.
func show_intro() -> void:
	_intro.visible = true
	_over.visible = false
	_choice.visible = false
	_status.visible = false
	_goal_lbl.visible = false

func hide_overlays() -> void:
	_intro.visible = false
	_over.visible = false
	_choice.visible = false
	_status.visible = true
	_goal_lbl.visible = true

# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

func _on_energy(current: int, maximum: int) -> void:
	if current < int(_bar.value):
		_flash.color.a = 0.25
		create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	_bar.value = current
	_bar.max_value = maximum

func _on_message(text: String, kind: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", KIND_COLORS.get(kind, COL_TEXT) as Color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("outline_size", 4)
	_msg_box.add_child(lbl)
	while _msg_box.get_child_count() > 4:
		_msg_box.get_child(0).free()
	# Tween owned by the label: freeing an old message also stops its fade
	var tw := lbl.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)

func _on_level_completed(level: int) -> void:
	_on_message(Strings.t("msg_level", {value = level}), "good")

## Banner for every level after the first, once the upgrade is picked.
func _on_level_started(level: int) -> void:
	_refresh()
	if level <= 1:
		return
	_banner.text = Strings.t("level", {value = level}).to_upper()
	_banner.visible = true
	_banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.2)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: _banner.visible = false)

func _on_upgrade_offered() -> void:
	_refresh()
	_refresh_choice()
	_choice.visible = true
	_choice.modulate.a = 0.0
	create_tween().tween_property(_choice, "modulate:a", 1.0, 0.25)

func _choose(id: String) -> void:
	if not GameManager.choose_upgrade(id):
		return
	Sfx.play("upgrade", 0.0)
	_choice.visible = false
	_on_message(Strings.t("msg_upgrade", {name = Strings.t("up_%s_name" % id),
		value = int(GameManager.upgrades[id]), max = GameManager.upgrade_max(id)}), "good")

## Keys 1 / 2 / 3 pick a card. The number row is read by physical position
## (an AZERTY keyboard types other characters there without Shift), the
## keypad by keycode.
func _unhandled_input(event: InputEvent) -> void:
	if not _choice.visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var index: int = [KEY_1, KEY_2, KEY_3].find(key.physical_keycode)
	if index < 0:
		index = [KEY_KP_1, KEY_KP_2, KEY_KP_3].find(key.keycode)
	if index >= 0 and index < GameManager.UPGRADE_IDS.size():
		_choose(GameManager.UPGRADE_IDS[index])
		get_viewport().set_input_as_handled()

func _on_run_ended(reason: String) -> void:
	Sfx.play("death", 0.0)
	_refresh_over()
	_over.visible = true
	_over.modulate.a = 0.0
	create_tween().tween_property(_over, "modulate:a", 1.0, 0.4)

# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func _refresh() -> void:
	_level_lbl.text = Strings.t("level", {value = GameManager.level})
	_crystal_lbl.text = Strings.t("crystals", {value = GameManager.upgrade_value("prospect", int(GameManager.upgrades["prospect"]))})
	_bomb_lbl.text = Strings.t("bomb", {value = GameManager.bomb_cost()})
	_best_lbl.text = Strings.t("best", {value = maxi(GameManager.best_level, 1)})

func _refresh_texts() -> void:
	_refresh()
	_lang_btn.text = Strings.t("lang_button")
	_camera_lbl.text = Strings.t("camera_hint")
	_radius_title.text = Strings.t("opt_radius")
	_far_title.text = Strings.t("opt_far")
	_sync_options()
	_kb_title.text = Strings.t("opt_keyboard")
	var detected: String = Keyboard.detected_name()
	_kb_option.set_item_text(0, Strings.t("kb_auto", {value = detected}) if detected != "" else Strings.t("kb_auto_other"))
	_kb_option.select(maxi(Keyboard.MODES.find(Keyboard.mode), 0))
	_intro_title.text = Strings.t("title")
	_intro_text.text = Strings.t("intro")
	_start_btn.text = Strings.t("start")
	_restart_btn.text = Strings.t("restart")
	_controls_lbl.text = Strings.t("controls", {front = key_label(Vector3i(0, 0, -1)), back = key_label(Vector3i(0, 0, 1)),
		left = key_label(Vector3i(-1, 0, 0)), right = key_label(Vector3i(1, 0, 0)),
		up = key_label(Vector3i(0, 1, 0)), down = key_label(Vector3i(0, -1, 0))})
	if _over.visible:
		_refresh_over()
	if _choice.visible:
		_refresh_choice()

## End screen: run summary, then the upgrades kept (when there are any).
func _refresh_over() -> void:
	_over_title.text = Strings.t(GameManager.end_reason)
	_over_stats.text = Strings.t("over_stats", {level = GameManager.level, rooms = GameManager.rooms_explored})
	var kept: PackedStringArray = []
	for id in GameManager.UPGRADE_IDS:
		if int(GameManager.upgrades[id]) > 0:
			kept.append("%s %d/%d" % [Strings.t("up_%s_name" % id), int(GameManager.upgrades[id]), GameManager.upgrade_max(id)])
	_over_kept.text = Strings.t("over_kept", {list = "   ·   ".join(kept)}) if not kept.is_empty() else ""
	_over_kept.visible = not kept.is_empty()

## Cards: effect for the NEXT level, so the player sees what the pick buys.
func _refresh_choice() -> void:
	_choice_title.text = Strings.t("choice_title", {value = GameManager.level - 1})
	_choice_text.text = Strings.t("choice_text")
	for i in GameManager.UPGRADE_IDS.size():
		var id: String = GameManager.UPGRADE_IDS[i]
		var card: Dictionary = _cards[id]
		var lvl: int = int(GameManager.upgrades[id])
		var open: bool = GameManager.upgrade_available(id)
		(card["name"] as Label).text = Strings.t("up_%s_name" % id)
		(card["desc"] as Label).text = Strings.t("up_%s_desc" % id)
		(card["effect"] as Label).text = Strings.t("up_%s_effect" % id, {now = GameManager.upgrade_value(id, lvl),
			next = GameManager.upgrade_value(id, lvl + 1)}) if open else ""
		(card["level"] as Label).text = Strings.t("up_level", {value = lvl, max = GameManager.upgrade_max(id)})
		var btn: Button = card["button"] as Button
		btn.text = Strings.t("up_choose", {key = i + 1}) if open else Strings.t("up_maxed")
		btn.disabled = not open

# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

func _build_status(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(270, 0)
	root.add_child(panel)
	_status = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_level_lbl = _label(20, COL_GOLD)
	box.add_child(_level_lbl)
	_bar = EnergyBar.new()
	_bar.custom_minimum_size = Vector2(0, 22)
	box.add_child(_bar)
	_bomb_lbl = _label(14, COL_TEXT)
	box.add_child(_bomb_lbl)
	_crystal_lbl = _label(14, COL_GOOD)
	box.add_child(_crystal_lbl)
	_best_lbl = _label(13, COL_MUTED)
	box.add_child(_best_lbl)
	_msg_box = VBoxContainer.new()
	_msg_box.position = Vector2(18, 200)
	_msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_msg_box)
	_goal_lbl = _label(17, COL_GOLD)
	_goal_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_goal_lbl.position = Vector2(-300, 18)
	_goal_lbl.size = Vector2(600, 30)
	_goal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_goal_lbl.add_theme_constant_override("outline_size", 5)
	root.add_child(_goal_lbl)
	_controls_lbl = _label(13, COL_MUTED)
	_controls_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_controls_lbl.position = Vector2(-520, -34)
	_controls_lbl.size = Vector2(1040, 24)
	_controls_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_controls_lbl)
	_camera_lbl = _label(12, Color(COL_MUTED, 0.85))
	_camera_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_camera_lbl.position = Vector2(-520, -56)
	_camera_lbl.size = Vector2(1040, 20)
	_camera_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_camera_lbl)
	_build_options(root)
	_lang_btn = Button.new()
	_lang_btn.focus_mode = Control.FOCUS_NONE
	_lang_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lang_btn.position = Vector2(-70, 16)
	_lang_btn.custom_minimum_size = Vector2(54, 34)
	_lang_btn.pressed.connect(func() -> void: Strings.toggle())
	root.add_child(_lang_btn)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 0.2, 0.2, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	_banner = _label(48, COL_GOLD)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(-300, -140)
	_banner.size = Vector2(600, 70)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.visible = false
	root.add_child(_banner)

## Options panel: focus radius, opacity of the rooms outside it, keyboard
## layout of the key letters. No control takes keyboard focus: the arrow
## keys keep moving the player. The panel grows upward from its bottom edge.
func _build_options(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 16
	panel.offset_top = -64   # clear of the camera hint line below
	panel.offset_bottom = -64
	root.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)
	_radius_title = _label(13, COL_TEXT)
	grid.add_child(_radius_title)
	_radius_slider = HSlider.new()
	_radius_slider.min_value = GameManager.FOCUS_RADIUS_MIN
	_radius_slider.max_value = GameManager.FOCUS_RADIUS_MAX
	_radius_slider.step = 1.0
	_radius_slider.tick_count = GameManager.FOCUS_RADIUS_MAX - GameManager.FOCUS_RADIUS_MIN + 1
	_radius_slider.ticks_on_borders = true
	_radius_slider.value = GameManager.focus_radius
	_radius_slider.focus_mode = Control.FOCUS_NONE
	_radius_slider.custom_minimum_size = Vector2(140, 20)
	_radius_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_radius_slider.value_changed.connect(func(value: float) -> void: GameManager.set_focus_radius(int(value)))
	grid.add_child(_radius_slider)
	_radius_value = _label(13, COL_CYAN)
	grid.add_child(_radius_value)
	_far_title = _label(13, COL_TEXT)
	grid.add_child(_far_title)
	_far_slider = HSlider.new()
	_far_slider.min_value = 0.0
	_far_slider.max_value = 1.0
	_far_slider.step = 0.05
	_far_slider.value = GameManager.far_opacity
	_far_slider.focus_mode = Control.FOCUS_NONE
	_far_slider.custom_minimum_size = Vector2(140, 20)
	_far_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_far_slider.value_changed.connect(_on_far_changed)
	grid.add_child(_far_slider)
	_far_value = _label(13, COL_CYAN)
	_far_value.custom_minimum_size = Vector2(44, 0)
	grid.add_child(_far_value)
	_kb_title = _label(13, COL_TEXT)
	grid.add_child(_kb_title)
	_kb_option = OptionButton.new()
	_kb_option.focus_mode = Control.FOCUS_NONE
	_kb_option.add_theme_font_size_override("font_size", 13)
	for text in ["auto", "AZERTY", "QWERTY"]:   # item 0 text is set by _refresh_texts
		_kb_option.add_item(text)
	_kb_option.get_popup().add_theme_font_size_override("font_size", 13)
	_kb_option.item_selected.connect(func(index: int) -> void: GameManager.set_keyboard_mode(Keyboard.MODES[index]))
	grid.add_child(_kb_option)
	grid.add_child(Control.new())   # empty third column

## Sliders and value labels from the settings (after a change, a loaded
## save or a language switch), without re-emitting value_changed.
func _sync_options() -> void:
	var r: int = GameManager.focus_radius
	_radius_slider.set_value_no_signal(r)
	_radius_value.text = Strings.t("radius_value_one") if r == 1 else Strings.t("radius_value", {value = r})
	_far_slider.set_value_no_signal(GameManager.far_opacity)
	_far_value.text = "%d %%" % int(round(GameManager.far_opacity * 100.0))

func _on_far_changed(value: float) -> void:
	GameManager.set_far_opacity(value)

func _build_overlays(root: Control) -> void:
	# Intro
	_intro = PanelContainer.new()
	_intro.set_anchors_preset(Control.PRESET_CENTER)
	_intro.custom_minimum_size = Vector2(620, 0)
	_intro.position = Vector2(-310, -130)
	root.add_child(_intro)
	var ib := VBoxContainer.new()
	ib.add_theme_constant_override("separation", 16)
	_intro.add_child(ib)
	_intro_title = _label(34, COL_CYAN)
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ib.add_child(_intro_title)
	_intro_text = _label(16, COL_TEXT)
	_intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ib.add_child(_intro_text)
	_start_btn = _accent_button()
	_start_btn.pressed.connect(func() -> void: start_requested.emit())
	ib.add_child(_start_btn)
	# Game over: summary only
	_over = ColorRect.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.color = Color(0.02, 0.03, 0.06, 0.82)
	root.add_child(_over)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var ob := VBoxContainer.new()
	ob.add_theme_constant_override("separation", 12)
	panel.add_child(ob)
	_over_title = _label(34, COL_BAD)
	_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ob.add_child(_over_title)
	_over_stats = _label(15, COL_TEXT)
	_over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ob.add_child(_over_stats)
	_over_kept = _label(14, COL_GOOD)
	_over_kept.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_kept.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ob.add_child(_over_kept)
	_restart_btn = _accent_button()
	_restart_btn.pressed.connect(func() -> void: start_requested.emit())
	ob.add_child(_restart_btn)
	_build_choice(root)

## Upgrade choice: title, explanation, one card per upgrade.
func _build_choice(root: Control) -> void:
	_choice = ColorRect.new()
	_choice.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice.color = Color(0.02, 0.03, 0.06, 0.78)
	_choice.visible = false
	root.add_child(_choice)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	_choice_title = _label(34, COL_GOLD)
	_choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_choice_title)
	_choice_text = _label(15, COL_TEXT)
	_choice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choice_text.custom_minimum_size = Vector2(780, 0)
	box.add_child(_choice_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for id in GameManager.UPGRADE_IDS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(250, 0)
		row.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		card.add_child(v)
		var name_lbl := _label(21, COL_CYAN)
		v.add_child(name_lbl)
		var desc := _label(14, COL_TEXT)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(226, 0)
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(desc)
		var effect := _label(15, COL_GOLD)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.custom_minimum_size = Vector2(226, 0)
		v.add_child(effect)
		var lvl := _label(13, COL_MUTED)
		v.add_child(lvl)
		var btn := _accent_button()
		btn.pressed.connect(_choose.bind(id))
		v.add_child(btn)
		_cards[id] = {name = name_lbl, desc = desc, effect = effect, level = lvl, button = btn}

func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _accent_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_stylebox_override("normal", _sb(Color("2e9e5a"), Color("5fd68a"), 8))
	b.add_theme_stylebox_override("hover", _sb(Color("38b866"), Color("8ff0b0"), 8))
	b.add_theme_font_size_override("font_size", 18)
	return b

func _sb(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _build_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 15
	th.set_color("font_color", "Label", COL_TEXT)
	th.set_stylebox("panel", "PanelContainer", _sb(Color(0.06, 0.08, 0.13, 0.9), Color("2c3550"), 10))
	th.set_stylebox("normal", "Button", _sb(Color("1d2436"), Color("2f3a56"), 7))
	th.set_stylebox("hover", "Button", _sb(Color("263049"), Color("5a73a0"), 7))
	th.set_stylebox("pressed", "Button", _sb(Color("151b2a"), Color("5a73a0"), 7))
	th.set_stylebox("disabled", "Button", _sb(Color("141824"), Color("222a3c"), 7))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", COL_TEXT)
	th.set_color("font_disabled_color", "Button", Color(0.55, 0.6, 0.7, 0.6))
	return th

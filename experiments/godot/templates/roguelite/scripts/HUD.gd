class_name RogueHUD
extends CanvasLayer

# HUD: status panel, goal, messages, direction gizmo, intro and end screens.
#
# DIRECTION GIZMO (the readability key of a 3D grid game):
#   around the player's screen position, one arrow per direction (front,
#   back, left, right, up, down), drawn by projecting the world direction
#   with Camera3D.unproject_position(). Each arrow carries its key letter;
#   green = open, faint red = wall. A golden arrow points to the current goal
#   (core, then teleporter) with its distance in rooms.

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
		if hud == null or hud.camera == null or hud.player == null or not GameManager.running:
			return
		var cam: Camera3D = hud.camera
		var origin: Vector3 = hud.player.position
		if cam.is_position_behind(origin):
			return
		var center: Vector2 = cam.unproject_position(origin)
		var font: Font = ThemeDB.fallback_font
		for dir in GridManager.DIRS:
			var tip2: Vector2 = cam.unproject_position(origin + Vector3(dir) * 0.5)
			var v: Vector2 = (tip2 - center).normalized()
			var open: bool = hud.grid.can_move(hud.player.cell, dir)
			var col: Color = Color(0.45, 1.0, 0.6, 0.95) if open else Color(1.0, 0.4, 0.4, 0.3)
			var a: Vector2 = center + v * 26.0
			var b: Vector2 = center + v * 58.0
			draw_line(a, b, col, 3.0, true)
			var side := Vector2(-v.y, v.x)
			draw_colored_polygon(PackedVector2Array([b + v * 10.0, b + side * 7.0, b - side * 7.0]), col)
			var label: String = hud.key_label(dir)
			var at: Vector2 = b + v * 22.0 + Vector2(-8, 6)
			draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.8))
			draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col if open else Color(1, 0.6, 0.6, 0.5))
		# Goal arrow
		var target: Vector3i = hud.goal_cell()
		var delta3: Vector3 = Vector3(target) - origin
		if delta3.length() > 0.1:
			var g2: Vector2 = cam.unproject_position(origin + delta3.normalized())
			var gv: Vector2 = (g2 - center).normalized()
			var p: Vector2 = center + gv * 96.0
			var gs := Vector2(-gv.y, gv.x)
			draw_colored_polygon(PackedVector2Array([p + gv * 18.0, p + gs * 11.0, p - gs * 11.0]), COL_GOLD)
			var dist: int = hud.goal_distance()
			draw_string_outline(font, p + gv * 30.0 + Vector2(-10, 6), str(dist), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.85))
			draw_string(font, p + gv * 30.0 + Vector2(-10, 6), str(dist), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COL_GOLD)

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
var _frag_lbl: Label
var _bomb_lbl: Label
var _best_lbl: Label
var _goal_lbl: Label
var _msg_box: VBoxContainer
var _controls_lbl: Label
var _lang_btn: Button
var _intro: PanelContainer
var _intro_title: Label
var _intro_text: Label
var _start_btn: Button
var _over: ColorRect
var _over_title: Label
var _over_stats: Label
var _shop_title: Label
var _shop_rows: Dictionary = {}
var _restart_btn: Button
var _banner: Label
var _flash: ColorRect
var _key_labels: Dictionary = {}

func bind(cam: Camera3D, pawn: PlayerPawn, g: GridManager) -> void:
	camera = cam
	player = pawn
	grid = g

func _ready() -> void:
	_compute_key_labels()
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
	GameManager.fragments_changed.connect(func(_t: int) -> void: _refresh())
	GameManager.level_started.connect(func(_l: int) -> void: _refresh())
	GameManager.core_collected_changed.connect(func(_c: bool) -> void: _refresh())
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.message.connect(_on_message)
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.upgrades_changed.connect(_refresh_shop)
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
	return str(_key_labels.get(dir, "?"))

## Intro: no run yet, so the status panel and the goal are hidden.
func show_intro() -> void:
	_intro.visible = true
	_over.visible = false
	_status.visible = false
	_goal_lbl.visible = false

func hide_overlays() -> void:
	_intro.visible = false
	_over.visible = false
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

func _on_level_completed(level: int, bonus: int) -> void:
	_on_message(Strings.t("msg_level", {value = level, frag = bonus}), "good")
	_banner.text = Strings.t("level", {value = level + 1}).to_upper()
	_banner.visible = true
	_banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.2)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: _banner.visible = false)

func _on_run_ended(reason: String) -> void:
	Sfx.play("death", 0.0)
	_over_title.text = Strings.t(reason)
	_over_stats.text = Strings.t("over_stats", {level = GameManager.level, rooms = GameManager.rooms_explored, frag = GameManager.run_fragments})
	_refresh_shop()
	_over.visible = true
	_over.modulate.a = 0.0
	create_tween().tween_property(_over, "modulate:a", 1.0, 0.4)

# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func _refresh() -> void:
	_level_lbl.text = Strings.t("level", {value = GameManager.level})
	_frag_lbl.text = Strings.t("fragments", {value = GameManager.fragments})
	_bomb_lbl.text = Strings.t("bomb", {value = GameManager.bomb_cost()})
	_best_lbl.text = Strings.t("best", {value = maxi(GameManager.best_level, 1)})

func _refresh_texts() -> void:
	_refresh()
	_lang_btn.text = Strings.t("lang_button")
	_intro_title.text = Strings.t("title")
	_intro_text.text = Strings.t("intro")
	_start_btn.text = Strings.t("start")
	_restart_btn.text = Strings.t("restart")
	_shop_title.text = Strings.t("shop_title")
	_controls_lbl.text = Strings.t("controls", {front = key_label(Vector3i(0, 0, -1)), back = key_label(Vector3i(0, 0, 1)),
		left = key_label(Vector3i(-1, 0, 0)), right = key_label(Vector3i(1, 0, 0)),
		up = key_label(Vector3i(0, 1, 0)), down = key_label(Vector3i(0, -1, 0))})
	if _over.visible:
		_over_title.text = Strings.t(GameManager.end_reason)
		_over_stats.text = Strings.t("over_stats", {level = GameManager.level, rooms = GameManager.rooms_explored, frag = GameManager.run_fragments})
	_refresh_shop()

func _refresh_shop() -> void:
	_refresh()
	for id in _shop_rows:
		var row: Dictionary = _shop_rows[id]
		var lvl: int = int(GameManager.upgrades[id])
		var name_lbl: Label = row["name"] as Label
		var lvl_lbl: Label = row["level"] as Label
		name_lbl.text = Strings.t("up_" + str(id), {value = int(GameManager.num("energy_per_upgrade"))})
		lvl_lbl.text = Strings.t("up_level", {value = lvl, max = int(GameManager.num("upgrade_max_level"))})
		var cost: int = GameManager.upgrade_cost(str(id))
		var btn: Button = row["button"] as Button
		btn.text = Strings.t("up_maxed") if cost < 0 else Strings.t("up_buy", {cost = cost})
		btn.disabled = cost < 0 or GameManager.fragments < cost

# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

func _compute_key_labels() -> void:
	var physical: Dictionary = {Vector3i(0, 0, -1): KEY_W, Vector3i(0, 0, 1): KEY_S, Vector3i(-1, 0, 0): KEY_A,
		Vector3i(1, 0, 0): KEY_D, Vector3i(0, 1, 0): KEY_E, Vector3i(0, -1, 0): KEY_Q}
	var desktop: bool = DisplayServer.get_name() in ["Windows", "macOS", "X11", "Wayland"]
	var azerty: Dictionary = {KEY_W: "Z", KEY_A: "Q", KEY_Q: "A"}
	for dir in physical:
		var k: Key = physical[dir]
		var label: String = OS.get_keycode_string(k)
		if desktop:
			var mapped: String = OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(k))
			if mapped.length() == 1:
				label = mapped
		elif OS.get_locale_language() == "fr" and azerty.has(k):
			label = str(azerty[k])
		_key_labels[dir] = label

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
	_frag_lbl = _label(15, Color("c7a8ff"))
	box.add_child(_frag_lbl)
	_bomb_lbl = _label(14, COL_TEXT)
	box.add_child(_bomb_lbl)
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
	# Game over + shop
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
	_shop_title = _label(13, COL_MUTED)
	ob.add_child(_shop_title)
	for id in GameManager.UPGRADE_IDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		ob.add_child(row)
		var name_lbl := _label(15, COL_TEXT)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var lvl_lbl := _label(13, COL_MUTED)
		row.add_child(lvl_lbl)
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(150, 34)
		btn.pressed.connect(_on_buy.bind(id))
		row.add_child(btn)
		_shop_rows[id] = {name = name_lbl, level = lvl_lbl, button = btn}
	_restart_btn = _accent_button()
	_restart_btn.pressed.connect(func() -> void: start_requested.emit())
	ob.add_child(_restart_btn)

func _on_buy(id: String) -> void:
	if GameManager.buy_upgrade(id):
		Sfx.play("upgrade", 0.0)

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

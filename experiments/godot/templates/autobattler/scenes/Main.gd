# =============================================================================
# Main.gd — Builds the screen and turns game events into feedback
# =============================================================================
# Layout (1280 x 720, stretched):
#   top bar        round, health, gold and income, level, language, sound
#   left           the arena and the bench (BoardView), a hint line below
#   middle         synergies of the board (TraitsPanel)
#   right          shop, fight / speed button, details of the hovered unit
#   overlays       banners over the arena, end screen
# Keys: Space fights (then toggles the battle speed), D refreshes the shop,
# F buys a level, R restarts after the end.
# Main holds no rule: it listens to RoundManager and answers with banners,
# sounds and texts.
# =============================================================================

extends Node

const BOARD_POSITION: Vector2 = Vector2(24.0, 66.0)
const FEEDBACK_TIME: float = 2.2

class Backdrop extends Control:
	func _draw() -> void:
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
			PackedColorArray([UiTheme.BG_TOP, UiTheme.BG_TOP, UiTheme.BG_BOTTOM, UiTheme.BG_BOTTOM]))

var _root: Control
var _board: Control
var _traits: VBoxContainer
var _shop: VBoxContainer
var _info: PanelContainer
var _top: PanelContainer
var _banner: Control
var _end: Control
var _fight: Button
var _hint: Label
var _feedback_left: float = 0.0

func _ready() -> void:
	_build()
	_connect_signals()
	RoundManager.new_game()

# =============================================================================
# BUILDING
# =============================================================================

func _build() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.theme = UiTheme.build()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := Backdrop.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top = _make(PanelContainer.new(), "res://scenes/ui/TopBar.gd") as PanelContainer
	_root.add_child(_top)
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.offset_bottom = 54.0
	_build_board()
	_build_columns()
	_end = _make(Control.new(), "res://scenes/ui/EndScreen.gd")
	_root.add_child(_end)
	_end.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_board() -> void:
	_board = _make(Control.new(), "res://scenes/ui/BoardView.gd")
	_root.add_child(_board)
	_board.position = BOARD_POSITION
	_board.size = _board.custom_minimum_size
	_hint = UiTheme.label("", 13, UiTheme.MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.position = BOARD_POSITION + Vector2(0.0, _board.size.y + 8.0)
	_hint.size = Vector2(_board.size.x, 40.0)
	_root.add_child(_hint)
	_banner = _make(Control.new(), "res://scenes/ui/Banner.gd")
	_root.add_child(_banner)
	_banner.position = BOARD_POSITION
	_banner.size = Vector2(_board.size.x, _board.size.x)

func _build_columns() -> void:
	_traits = _make(VBoxContainer.new(), "res://scenes/ui/TraitsPanel.gd") as VBoxContainer
	_root.add_child(_traits)
	_traits.position = Vector2(BOARD_POSITION.x + _board.size.x + 20.0, BOARD_POSITION.y)
	_traits.size = Vector2(196.0, 560.0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_root.add_child(column)
	column.position = Vector2(_traits.position.x + 216.0, BOARD_POSITION.y)
	column.size = Vector2(532.0, 640.0)
	_shop = _make(VBoxContainer.new(), "res://scenes/ui/ShopPanel.gd") as VBoxContainer
	column.add_child(_shop)
	_fight = Button.new()
	_fight.focus_mode = Control.FOCUS_NONE
	_fight.custom_minimum_size = Vector2(0.0, 56.0)
	_fight.add_theme_font_size_override("font_size", 22)
	_fight.add_theme_stylebox_override("normal", UiTheme.box(Color(0.45, 0.2, 0.12), Color(1.0, 0.55, 0.3), 8, 10))
	_fight.add_theme_stylebox_override("hover", UiTheme.box(Color(0.58, 0.26, 0.15), Color(1.0, 0.7, 0.45), 8, 10))
	_fight.pressed.connect(_on_fight_pressed)
	column.add_child(_fight)
	_info = _make(PanelContainer.new(), "res://scenes/ui/InfoPanel.gd") as PanelContainer
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_info)

func _make(node: Node, script_path: String) -> Node:
	node.set_script(load(script_path))
	return node

# =============================================================================
# SIGNALS
# =============================================================================

func _connect_signals() -> void:
	RoundManager.phase_changed.connect(_on_phase_changed)
	RoundManager.battle_finished.connect(_on_battle_finished)
	RoundManager.feedback.connect(_on_feedback)
	RoundManager.board_changed.connect(_refresh)
	RoundManager.level_changed.connect(func(_l: int) -> void: _refresh())
	_board.connect("unit_hovered", func(unit: Unit) -> void: _info.call("show_unit", unit))
	_board.connect("unit_dropped_outside", _on_dropped_outside)
	_board.connect("drag_changed", func(unit: Unit) -> void: _shop.call("show_sell_hint", unit))
	_shop.connect("card_hovered", func(id: String) -> void: _info.call("show_type", id))
	_shop.connect("card_unhovered", func() -> void: _info.call("show_unit", null))
	_top.connect("language_pressed", func() -> void:
		Sfx.play("ui")
		StringManager.cycle_language())
	_top.connect("sound_pressed", func() -> void:
		Sfx.toggle_mute()
		Sfx.play("ui")
		_top.call("refresh"))
	_end.connect("restart_requested", _restart)
	StringManager.language_changed.connect(func(_l: String) -> void: _refresh())

func _on_phase_changed(phase: int) -> void:
	match phase:
		RoundManager.Phase.PREP:
			var r: int = RoundManager.round_number
			var boss: bool = RoundManager.is_boss_round(r)
			var title: String = StringManager.t("round_banner", {value = r})
			var sub: String = StringManager.t("round_banner_boss" if boss else "round_banner_sub", {count = RoundManager.enemy_lineup.size()})
			_banner.call("show_banner", title, sub, UiTheme.ENEMY if boss else UiTheme.GOLD, 0.9)
		RoundManager.Phase.BATTLE:
			_banner.call("show_banner", StringManager.t("battle_banner"), "", UiTheme.TEXT, 0.4)
			Sfx.play("battle")
		RoundManager.Phase.GAME_OVER:
			_end.call("open", false)
		RoundManager.Phase.VICTORY:
			_end.call("open", true)
	_refresh()

func _on_battle_finished(won: bool, damage: int) -> void:
	if won:
		_banner.call("show_banner", StringManager.t("win_banner"), StringManager.t("win_banner_sub", {value = ConfigManager.get_int("win_bonus", 1)}), UiTheme.GOOD, 1.2)
		Sfx.play("win")
	else:
		_banner.call("show_banner", StringManager.t("lose_banner"), StringManager.t("lose_banner_sub", {value = damage}), UiTheme.BAD, 1.2)
		Sfx.play("lose")

func _on_feedback(key: String) -> void:
	Sfx.play("deny")
	_hint.text = StringManager.t(key, {level = RoundManager.level})
	_hint.add_theme_color_override("font_color", UiTheme.BAD)
	_feedback_left = FEEDBACK_TIME

func _on_dropped_outside(unit: Unit, global_point: Vector2) -> void:
	if (_shop.call("sell_rect") as Rect2).has_point(global_point) and RoundManager.sell(unit):
		_board.call("sell_feedback_at_global", global_point, unit)

func _on_fight_pressed() -> void:
	match RoundManager.phase:
		RoundManager.Phase.PREP:
			RoundManager.start_battle()
		RoundManager.Phase.BATTLE:
			RoundManager.set_battle_speed(2.0 if RoundManager.battle_speed < 1.5 else 1.0)
			Sfx.play("ui")
	_refresh()

func _restart() -> void:
	_end.visible = false
	Sfx.play("ui")
	RoundManager.new_game()

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_SPACE:
			_on_fight_pressed()
		KEY_D:
			if RoundManager.reroll():
				Sfx.play("reroll")
		KEY_F:
			if RoundManager.level_up():
				Sfx.play("level")
		KEY_R:
			if RoundManager.phase == RoundManager.Phase.GAME_OVER or RoundManager.phase == RoundManager.Phase.VICTORY:
				_restart()

func _process(delta: float) -> void:
	if _feedback_left > 0.0:
		_feedback_left -= delta
		if _feedback_left <= 0.0:
			_refresh()

## Fight button and hint line, from the phase and the board.
func _refresh() -> void:
	var count: int = RoundManager.board.board_count() if RoundManager.board != null else 0
	match RoundManager.phase:
		RoundManager.Phase.PREP:
			_fight.text = StringManager.t("fight_button")
			_fight.disabled = count == 0
		RoundManager.Phase.BATTLE:
			_fight.text = StringManager.t("speed_button", {value = int(RoundManager.battle_speed)})
			_fight.disabled = false
		_:
			_fight.text = StringManager.t("wait_button")
			_fight.disabled = true
	if _feedback_left > 0.0:
		return
	_hint.add_theme_color_override("font_color", UiTheme.MUTED)
	if RoundManager.phase == RoundManager.Phase.BATTLE:
		_hint.text = StringManager.t("hint_battle")
	elif count == 0:
		_hint.text = StringManager.t("hint_empty")
	elif count < RoundManager.level:
		_hint.text = StringManager.t("hint_room", {count = count, level = RoundManager.level})
	else:
		_hint.text = StringManager.t("hint_full", {count = count, level = RoundManager.level})

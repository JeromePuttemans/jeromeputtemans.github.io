# =============================================================================
# TopBar.gd — Round, health, gold, level, language and sound
# =============================================================================
# Health and gold numbers pulse when they change (red when health drops).
# The gold line previews the income of the next round: base + interest +
# win bonus.
# =============================================================================

extends PanelContainer

class Icon extends Control:
	var kind: String = "coin"
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		if kind == "heart":
			draw_circle(c + Vector2(-4, -2), 5.0, UiTheme.BAD)
			draw_circle(c + Vector2(4, -2), 5.0, UiTheme.BAD)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 0), c + Vector2(9, 0), c + Vector2(0, 10)]), UiTheme.BAD)
		else:
			draw_circle(c, 9.0, UiTheme.GOLD.darkened(0.35))
			draw_circle(c, 7.0, UiTheme.GOLD)
			draw_rect(Rect2(c - Vector2(1.5, 4), Vector2(3, 8)), UiTheme.GOLD.darkened(0.35))

signal language_pressed()
signal sound_pressed()

var _round: Label
var _hp: Label
var _gold: Label
var _income: Label
var _level: Label
var _lang: Button
var _sound: Button
var _hp_pulse: float = 0.0
var _gold_pulse: float = 0.0

func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.08, 0.08, 0.12, 0.96), UiTheme.BORDER, 0, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	_round = UiTheme.label("", 18, UiTheme.GOLD)
	_round.custom_minimum_size = Vector2(240.0, 0.0)
	row.add_child(_round)
	row.add_child(_icon("heart"))
	_hp = UiTheme.label("", 20, UiTheme.TEXT)
	row.add_child(_hp)
	row.add_child(_icon("coin"))
	_gold = UiTheme.label("", 20, UiTheme.GOLD)
	row.add_child(_gold)
	_income = UiTheme.label("", 12, UiTheme.MUTED)
	_income.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_income)
	_level = UiTheme.label("", 16, UiTheme.TEXT)
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_level)
	_lang = _button(row, func() -> void: language_pressed.emit())
	_sound = _button(row, func() -> void: sound_pressed.emit())
	RoundManager.hp_changed.connect(func(_v: int, delta: int) -> void:
		if delta < 0:
			_hp_pulse = 1.0
		refresh())
	RoundManager.gold_changed.connect(func(_v: int) -> void:
		_gold_pulse = 1.0
		refresh())
	RoundManager.level_changed.connect(func(_v: int) -> void: refresh())
	RoundManager.board_changed.connect(refresh)
	RoundManager.phase_changed.connect(func(_p: int) -> void: refresh())
	StringManager.language_changed.connect(func(_l: String) -> void: refresh())

func _icon(kind: String) -> Control:
	var icon := Icon.new()
	icon.kind = kind
	icon.custom_minimum_size = Vector2(22.0, 22.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon

func _button(parent: HBoxContainer, action: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _process(delta: float) -> void:
	_hp_pulse = maxf(_hp_pulse - delta * 2.0, 0.0)
	_gold_pulse = maxf(_gold_pulse - delta * 3.0, 0.0)
	_hp.add_theme_color_override("font_color", UiTheme.TEXT.lerp(UiTheme.BAD, _hp_pulse))
	_hp.pivot_offset = _hp.size * 0.5
	_hp.scale = Vector2.ONE * (1.0 + 0.3 * _hp_pulse)
	_gold.pivot_offset = _gold.size * 0.5
	_gold.scale = Vector2.ONE * (1.0 + 0.2 * _gold_pulse)

func refresh() -> void:
	var r: int = RoundManager.round_number
	var total: int = ConfigManager.get_int("rounds_total", 15)
	_round.text = StringManager.t("round_label", {current = r, total = total})
	if RoundManager.is_boss_round(r):
		_round.text += "  " + StringManager.t("boss_tag")
	_hp.text = str(RoundManager.hp)
	_gold.text = str(RoundManager.gold)
	var interest: int = mini(int(RoundManager.gold / float(ConfigManager.get_int("interest_step", 10))), ConfigManager.get_int("interest_cap", 5))
	_income.text = StringManager.t("income_label", {base = ConfigManager.get_int("income_base", 5), interest = interest})
	var count: int = RoundManager.board.board_count() if RoundManager.board != null else 0
	_level.text = StringManager.t("level_label", {level = RoundManager.level, count = count})
	_level.add_theme_color_override("font_color", UiTheme.GOOD if count >= RoundManager.level else UiTheme.TEXT)
	_lang.text = StringManager.t("lang_button")
	_sound.text = StringManager.t("sound_off" if Sfx.muted else "sound_on")

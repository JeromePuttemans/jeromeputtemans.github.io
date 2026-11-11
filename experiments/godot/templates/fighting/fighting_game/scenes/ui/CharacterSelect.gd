# =============================================================================
# CharacterSelect.gd — Choosing the automatons (and the CPU difficulty)
# =============================================================================
# Arcade: player 1 picks a fighter and the difficulty (up / down).
# Versus: player 1 picks, then player 2 with his own keys.
# Training: player 1 picks his fighter, then the dummy's.
# Cards can also be clicked.
# =============================================================================

class_name CharacterSelect
extends Control

signal confirmed(p1: String, p2: String, difficulty: int)
signal back_requested()

## One card: background, portrait, name, cursor frames.
class Card extends Control:
	var fighter_id: String = ""
	var p1_here: bool = false
	var p2_here: bool = false
	var p1_locked: bool = false
	var _time: float = 0.0
	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var style: Dictionary = (GameState.roster.get(fighter_id, {}) as Dictionary).get("style", {}) as Dictionary
		var tint := Color(str(style.get("dark", "333333")))
		draw_rect(r, Color(tint.darkened(0.5), 0.92))
		draw_rect(Rect2(0.0, size.y * 0.55, size.x, size.y * 0.45), Color(tint.darkened(0.2), 0.5))
		draw_rect(r, UiTheme.BORDER, false, 2.0)
		var font: Font = ThemeDB.fallback_font
		var title: String = GameState.fighter_name(fighter_id)
		var w: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string_outline(font, Vector2((size.x - w) * 0.5, size.y - 16.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, UiTheme.SHADOW)
		draw_string(font, Vector2((size.x - w) * 0.5, size.y - 16.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiTheme.TEXT)
		var pulse: float = 0.6 + 0.4 * sin(_time * 6.0)
		if p1_here:
			draw_rect(r.grow(4.0), Color(UiTheme.P1, 1.0 if p1_locked else pulse), false, 4.0)
			draw_string(font, Vector2(10.0, 26.0), "J1", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.P1)
		if p2_here:
			draw_rect(r.grow(10.0), Color(UiTheme.P2, pulse), false, 4.0)
			draw_string(font, Vector2(size.x - 38.0, 26.0), "J2", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.P2)

## Three stats drawn as rows of five pips.
class StatBars extends Control:
	var values: Array = [3, 3, 3]
	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var keys: Array[String] = ["stat_power", "stat_speed", "stat_range"]
		for k in 3:
			var x: float = k * 210.0
			draw_string(font, Vector2(x, 18.0), StringManager.t(keys[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiTheme.MUTED)
			for i in 5:
				var lit: bool = i < int(values[k])
				draw_rect(Rect2(x + 96.0 + i * 20.0, 5.0, 15.0, 14.0), UiTheme.BRASS if lit else Color(0.25, 0.2, 0.15))

var mode: String = "arcade"
var _phase: int = 0
var _cursor: Array[int] = [0, 1]
var _difficulty: int = 1
var _cards: Array[Card] = []
var _title: Label
var _hint: Label
var _name: Label
var _role: Label
var _stats: StatBars
var _extra: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.veil(0.0))
	var center := UiTheme.center_box()
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	_title = UiTheme.label("", 36, UiTheme.BRASS, 6)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for i in GameState.order.size():
		var card := Card.new()
		card.fighter_id = GameState.order[i]
		card.custom_minimum_size = Vector2(230.0, 330.0)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_input.bind(i))
		var portrait := UiTheme.Portrait.new()
		portrait.fighter_id = card.fighter_id
		portrait.size_factor = 1.2
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.offset_bottom = -40.0
		card.add_child(portrait)
		row.add_child(card)
		_cards.append(card)
	var panel := PanelContainer.new()
	column.add_child(panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	panel.add_child(info)
	_name = UiTheme.label("", 24, UiTheme.TEXT)
	info.add_child(_name)
	_role = UiTheme.label("", 16, UiTheme.MUTED)
	info.add_child(_role)
	_stats = StatBars.new()
	_stats.custom_minimum_size = Vector2(620.0, 26.0)
	info.add_child(_stats)
	_extra = UiTheme.label("", 16, UiTheme.P1)
	info.add_child(_extra)
	_hint = UiTheme.label("", 14, UiTheme.MUTED, 4)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint)
	StringManager.language_changed.connect(func(_l: String) -> void:
		if visible:
			_refresh())

func open(selection_mode: String) -> void:
	mode = selection_mode
	_phase = 0
	_cursor = [GameState.order.find(GameState.p1) if GameState.order.has(GameState.p1) else 0, 1]
	_difficulty = GameState.difficulty
	_refresh()

func _refresh() -> void:
	_title.text = StringManager.t("select_title")
	var active: int = _cursor[mini(_phase, 1)]
	var id: String = GameState.order[active]
	var character: Dictionary = GameState.roster[id] as Dictionary
	_name.text = GameState.fighter_name(id)
	_role.text = StringManager.t(str(character.get("role", "")))
	var stats: Dictionary = character.get("stats", {}) as Dictionary
	_stats.values = [int(stats.get("power", 3)), int(stats.get("speed", 3)), int(stats.get("range", 3))]
	_stats.queue_redraw()
	var lines: PackedStringArray = []
	if mode == "arcade":
		lines.append(StringManager.t("select_difficulty", {d = StringManager.t("diff_%d" % _difficulty)}))
		var cleared: int = SaveManager.cleared_level(id)
		if cleared >= 0:
			lines.append(StringManager.t("cleared", {d = StringManager.t("diff_%d" % cleared)}))
	elif _phase == 1:
		lines.append(StringManager.t("select_p2" if mode == "versus" else "select_dummy"))
	_extra.text = "\n".join(lines)
	_extra.add_theme_color_override("font_color", UiTheme.P2 if _phase == 1 else UiTheme.P1)
	_hint.text = StringManager.t("select_hint")
	for i in _cards.size():
		_cards[i].p1_here = _cursor[0] == i
		_cards[i].p1_locked = _phase >= 1
		_cards[i].p2_here = _phase >= 1 and _cursor[1] == i

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var prefix: String = "p2_" if (_phase == 1 and mode == "versus") else "p1_"
	var handled: bool = true
	if event.is_action_pressed(prefix + "left") or (event.is_action_pressed("ui_left") and prefix == "p1_"):
		_move(-1)
	elif event.is_action_pressed(prefix + "right") or (event.is_action_pressed("ui_right") and prefix == "p1_"):
		_move(1)
	elif mode == "arcade" and (event.is_action_pressed(prefix + "up") or event.is_action_pressed("ui_up")):
		_difficulty = mini(_difficulty + 1, 2)
		Sfx.play("ui_move")
		_refresh()
	elif mode == "arcade" and (event.is_action_pressed(prefix + "down") or event.is_action_pressed("ui_down")):
		_difficulty = maxi(_difficulty - 1, 0)
		Sfx.play("ui_move")
		_refresh()
	elif event.is_action_pressed(prefix + "light") or event.is_action_pressed("ui_accept"):
		_confirm()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if _phase == 1:
			_phase = 0
			Sfx.play("ui")
			_refresh()
		else:
			back_requested.emit()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _move(dir: int) -> void:
	var slot: int = mini(_phase, 1)
	_cursor[slot] = posmod(_cursor[slot] + dir, _cards.size())
	Sfx.play("ui_move")
	_refresh()

func _confirm() -> void:
	Sfx.play("select")
	if mode == "arcade":
		confirmed.emit(GameState.order[_cursor[0]], "", _difficulty)
		return
	if _phase == 0:
		_phase = 1
		_cursor[1] = posmod(_cursor[0] + 1, _cards.size())
		_refresh()
		return
	confirmed.emit(GameState.order[_cursor[0]], GameState.order[_cursor[1]], _difficulty)

func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var slot: int = mini(_phase, 1)
		if _cursor[slot] == index:
			_confirm()
		else:
			_cursor[slot] = index
			Sfx.play("ui_move")
			_refresh()

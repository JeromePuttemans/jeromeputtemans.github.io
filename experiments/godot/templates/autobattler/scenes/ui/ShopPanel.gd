# =============================================================================
# ShopPanel.gd — Shop offers, odds, refresh and level buttons
# =============================================================================
# Five ShopCards, the tier odds of the current level, a refresh button (D)
# and a level button (F). While a unit is dragged, a "drop here to sell"
# overlay covers the panel: dropping it there sells it (BoardView reports
# the drop, Main checks it falls inside sell_rect()).
# =============================================================================

extends VBoxContainer

signal card_hovered(type_id: String)
signal card_unhovered()

var _title: Label
var _odds: Label
var _cards: Array[Button] = []
var _reroll: Button
var _level: Button
var _sell_overlay: PanelContainer
var _sell_label: Label

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	add_child(head)
	_title = UiTheme.label("", 18, UiTheme.TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_odds = UiTheme.label("", 12, UiTheme.MUTED)
	_odds.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_odds)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for i in ConfigManager.get_int("shop_size", 5):
		var card := Button.new()
		card.set_script(load("res://scenes/ui/ShopCard.gd"))
		row.add_child(card)
		card.call("setup", i)
		card.connect("hovered", func(id: String) -> void: card_hovered.emit(id))
		card.connect("unhovered", func() -> void: card_unhovered.emit())
		_cards.append(card)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	add_child(buttons)
	_reroll = _button(buttons, _on_reroll)
	_level = _button(buttons, _on_level)
	_build_sell_overlay(row)
	for sig in [RoundManager.gold_changed, RoundManager.level_changed, RoundManager.phase_changed]:
		(sig as Signal).connect(func(_v: Variant) -> void: refresh())
	StringManager.language_changed.connect(func(_l: String) -> void: refresh())
	refresh()

func _on_reroll() -> void:
	if RoundManager.reroll():
		Sfx.play("reroll")
	else:
		Sfx.play("deny")

func _on_level() -> void:
	if RoundManager.level_up():
		Sfx.play("level")
	else:
		Sfx.play("deny")

func _button(parent: HBoxContainer, action: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 38.0)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_sell_overlay(row: Control) -> void:
	_sell_overlay = PanelContainer.new()
	_sell_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_overlay.add_theme_stylebox_override("panel", UiTheme.box(Color(0.25, 0.18, 0.05, 0.9), UiTheme.GOLD, 8, 10))
	_sell_overlay.visible = false
	_sell_label = UiTheme.label("", 18, UiTheme.GOLD)
	_sell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sell_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sell_overlay.add_child(_sell_label)
	row.add_child(_sell_overlay)
	_sell_overlay.top_level = true

func show_sell_hint(unit: Unit) -> void:
	_sell_overlay.visible = unit != null
	if unit == null:
		return
	_sell_label.text = StringManager.t("sell_drop", {value = unit.sell_value()})
	var rect: Rect2 = sell_rect()
	_sell_overlay.position = rect.position
	_sell_overlay.size = rect.size

## Global rectangle where a dropped unit is sold: the cards row and buttons.
func sell_rect() -> Rect2:
	var first: Rect2 = _cards[0].get_global_rect()
	var last: Rect2 = _level.get_global_rect()
	return Rect2(first.position, last.end - first.position)

func refresh() -> void:
	var prep: bool = RoundManager.phase == RoundManager.Phase.PREP
	_title.text = StringManager.t("shop_title")
	var odds: Array = UnitDatabase.odds_for_level(RoundManager.level)
	var parts: PackedStringArray = []
	for value in odds:
		parts.append("%d %%" % int(value) if StringManager.get_language() == "fr" else "%d%%" % int(value))
	_odds.text = StringManager.t("odds_label", {value = " / ".join(parts)})
	var reroll_cost: int = ConfigManager.get_int("reroll_cost", 2)
	_reroll.text = StringManager.t("reroll_button", {cost = reroll_cost})
	_reroll.disabled = not prep or RoundManager.gold < reroll_cost
	var level_cost: int = RoundManager.level_cost()
	if level_cost < 0:
		_level.text = StringManager.t("level_max")
		_level.disabled = true
	else:
		_level.text = StringManager.t("level_button", {cost = level_cost})
		_level.disabled = not prep or RoundManager.gold < level_cost

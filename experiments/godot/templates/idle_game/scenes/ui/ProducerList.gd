# =============================================================================
# ProducerList.gd — Producers title, buy mode selector and the cards
# =============================================================================
# Shows every revealed producer, plus the next hidden one as a locked card;
# the others stay hidden until they come close. Buy modes x1, x10, x100 and
# MAX (as many as affordable) apply to every card.
# Prices are refreshed every frame (cheap: a few cards); texts with
# production figures four times a second, so they follow the boosts.
# =============================================================================

extends VBoxContainer

signal producer_bought(producer: Producer, amount: int, at: Vector2)

const TEXT_REFRESH: float = 0.25

var _cards: Dictionary = {}   # producer id -> card
var _mode_buttons: Array[Button] = []
var _title: Label
var _refresh_left: float = 0.0

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_build_header()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for id in ProducerManager.producer_order:
		var card := PanelContainer.new()
		card.set_script(load("res://scenes/ui/ProducerCard.gd"))
		list.add_child(card)
		card.call("setup", ProducerManager.producers[id])
		card.connect("bought", func(p: Producer, n: int, at: Vector2) -> void: producer_bought.emit(p, n, at))
		_cards[id] = card
	ProducerManager.producer_purchased.connect(func(_p: Producer, _n: int) -> void: refresh_all())
	ProducerManager.producer_revealed.connect(func(_p: Producer) -> void: refresh_all())
	ProducerManager.upgrade_purchased.connect(func(_u: Upgrade) -> void: refresh_all())
	PrestigeManager.prestige_done.connect(func(_g: int, _t: int) -> void: refresh_all())
	StringManager.language_changed.connect(func(_l: String) -> void: refresh_all())
	refresh_all()

func _build_header() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	add_child(header)
	_title = UiTheme.label("", 18, UiTheme.TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	for mode in ProducerManager.BUY_MODES:
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(58.0, 30.0)
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_on_mode_pressed.bind(mode))
		header.add_child(button)
		_mode_buttons.append(button)

func _on_mode_pressed(mode: int) -> void:
	GameManager.set_buy_mode(mode)
	Sfx.play("ui")
	refresh_all()

## Visibility (revealed, next locked, hidden), texts and mode buttons.
func refresh_all() -> void:
	_title.text = StringManager.t("producers_title")
	var locked_shown: bool = false
	for id in ProducerManager.producer_order:
		var producer: Producer = ProducerManager.producers[id] as Producer
		var card: Control = _cards[id] as Control
		var revealed: bool = ProducerManager.is_revealed(producer)
		card.visible = revealed or not locked_shown
		if not revealed:
			locked_shown = true
		card.call("set_locked", not revealed)
	for i in _mode_buttons.size():
		var mode: int = ProducerManager.BUY_MODES[i]
		_mode_buttons[i].text = StringManager.t("buy_mode_max") if mode < 0 else "×%d" % mode
		_mode_buttons[i].set_pressed_no_signal(GameManager.buy_mode == mode)

func card_for(producer_id: String) -> Control:
	return _cards.get(producer_id) as Control

func _process(delta: float) -> void:
	for card in _cards.values():
		if (card as Control).visible:
			card.call("update_buy", GameManager.buy_mode)
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = TEXT_REFRESH
		for card in _cards.values():
			if (card as Control).visible:
				card.call("refresh")

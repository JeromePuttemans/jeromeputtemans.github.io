# =============================================================================
# ProducerCard.gd — One producer: icon, count, production, milestone, buy
# =============================================================================
# Built by code. Three lines of information:
#   name and owned count
#   owned: its production and share of the total; none owned: what it does
#          and what one unit produces
#   progress toward the next milestone (x2 at 10, 25, 50... owned)
# The buy button shows the price of the current buy mode (x1, x10, x100,
# max). Affordable: green. Not affordable: dimmed, with a bar filling up
# toward the price; clicking it anyway shakes the card with a low buzz.
# A locked card (next producer not revealed yet) shows a grey silhouette,
# "???" and the shards to produce before it appears.
# =============================================================================

extends PanelContainer

signal bought(producer: Producer, amount: int, at: Vector2)

class ProgressBarLine extends Control:
	var ratio: float = 0.0
	var color: Color = Color.WHITE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, 0.08))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(ratio, 0.0, 1.0), size.y)), color)

class BuyButton extends Button:
	var progress: float = 1.0
	func _draw() -> void:
		if progress >= 1.0:
			return
		var bar := Rect2(Vector2(6.0, size.y - 6.0), Vector2((size.x - 12.0) * clampf(progress, 0.0, 1.0), 3.0))
		draw_rect(Rect2(Vector2(6.0, size.y - 6.0), Vector2(size.x - 12.0, 3.0)), Color(1.0, 1.0, 1.0, 0.08))
		draw_rect(bar, UiTheme.CRYSTAL)

var producer: Producer = null
var _icon: Control
var _name_label: Label
var _owned_label: Label
var _info_label: Label
var _milestone_label: Label
var _milestone_bar: ProgressBarLine
var _buy: BuyButton
var _locked: bool = false
var _flash: float = 0.0
var _shake: float = 0.0
var _hover: bool = false
var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_buy_ok: StyleBoxFlat
var _style_buy_ok_hover: StyleBoxFlat
var _style_buy_no: StyleBoxFlat

func setup(p: Producer) -> void:
	producer = p
	_build()
	refresh()

func _build() -> void:
	_style_normal = UiTheme.box(UiTheme.PANEL, UiTheme.BORDER, 10, 10)
	_style_hover = UiTheme.box(UiTheme.PANEL_LIGHT, producer.color.darkened(0.2), 10, 10)
	_style_buy_ok = UiTheme.box(Color(0.12, 0.32, 0.22), UiTheme.GOOD, 8, 8)
	_style_buy_ok_hover = UiTheme.box(Color(0.15, 0.42, 0.28), UiTheme.GOOD.lightened(0.3), 8, 8)
	_style_buy_no = UiTheme.box(Color(0.09, 0.1, 0.17), Color(0.18, 0.2, 0.3), 8, 8)
	add_theme_stylebox_override("panel", _style_normal)
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = Control.new()
	_icon.set_script(load("res://scenes/ui/ProducerIcon.gd"))
	_icon.set("producer", producer)
	row.add_child(_icon)
	row.add_child(_build_info())
	_buy = BuyButton.new()
	_buy.custom_minimum_size = Vector2(150.0, 56.0)
	_buy.focus_mode = Control.FOCUS_NONE
	_buy.add_theme_font_size_override("font_size", 14)
	_buy.pressed.connect(_on_buy_pressed)
	row.add_child(_buy)

func _build_info() -> VBoxContainer:
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label = UiTheme.label("", 17, UiTheme.TEXT)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_owned_label = UiTheme.label("", 22, UiTheme.GOLD)
	head.add_child(_name_label)
	head.add_child(_owned_label)
	info.add_child(head)
	_info_label = UiTheme.label("", 13, UiTheme.MUTED)
	info.add_child(_info_label)
	var milestone := HBoxContainer.new()
	milestone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	milestone.add_theme_constant_override("separation", 8)
	_milestone_bar = ProgressBarLine.new()
	_milestone_bar.custom_minimum_size = Vector2(120.0, 5.0)
	_milestone_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_milestone_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_milestone_label = UiTheme.label("", 12, UiTheme.MUTED)
	milestone.add_child(_milestone_bar)
	milestone.add_child(_milestone_label)
	info.add_child(milestone)
	return info

# =============================================================================
# REFRESH
# =============================================================================

func set_locked(value: bool) -> void:
	_locked = value
	_icon.set("locked", value)
	refresh()

func refresh() -> void:
	if producer == null:
		return
	if _locked:
		_refresh_locked()
		return
	_name_label.text = StringManager.producer_name(producer.id)
	_owned_label.text = str(producer.owned) if producer.owned > 0 else ""
	if producer.owned > 0:
		var total: float = maxf(ProducerManager.get_total_rps(), 0.000001)
		var rps: float = ProducerManager.get_producer_rps(producer)
		_info_label.text = StringManager.t("producer_rps", {value = Utils.format_number(rps), share = Utils.format_percent(rps / total)})
	else:
		_info_label.text = StringManager.t("producer_unit", {desc = StringManager.t("producer_%s_desc" % producer.id),
			value = Utils.format_number(producer.get_unit_rps() * ProducerManager.global_multiplier * PrestigeManager.multiplier())})
	_refresh_milestone()

func _refresh_locked() -> void:
	_name_label.text = StringManager.t("locked_name")
	_owned_label.text = ""
	_info_label.text = StringManager.t("locked_hint", {value = Utils.format_number(producer.base_cost * ConfigManager.get_float("reveal_ratio", 0.5))})
	_milestone_label.text = ""
	_milestone_bar.visible = false

func _refresh_milestone() -> void:
	var milestones: Array = ConfigManager.get_array("milestones")
	var next: int = producer.next_milestone(milestones)
	_milestone_bar.visible = next > 0
	if next < 0:
		_milestone_label.text = StringManager.t("milestone_done")
		return
	var previous: int = producer.previous_milestone(milestones)
	_milestone_bar.ratio = float(producer.owned - previous) / float(next - previous)
	_milestone_bar.color = producer.color
	_milestone_bar.queue_redraw()
	_milestone_label.text = StringManager.t("milestone_next", {target = next, owned = producer.owned,
		mult = int(ConfigManager.get_float("milestone_multiplier", 2.0))})

## Every frame: price of the current buy mode and affordability.
func update_buy(mode: int) -> void:
	var amount: int = ProducerManager.amount_for_mode(producer, mode)
	var cost: float = producer.get_bulk_cost(amount)
	var budget: float = ResourceManager.get_amount(ResourceManager.main_resource)
	var affordable: bool = budget >= cost and not _locked
	_buy.text = "%s\n%s" % [StringManager.t("buy_label", {value = amount}), Utils.format_number(cost)]
	_buy.progress = 1.0 if affordable else budget / maxf(cost, 0.000001)
	_buy.add_theme_stylebox_override("normal", _style_buy_ok if affordable else _style_buy_no)
	_buy.add_theme_stylebox_override("hover", _style_buy_ok_hover if affordable else _style_buy_no)
	_buy.add_theme_color_override("font_color", Color.WHITE if affordable else UiTheme.MUTED)
	_buy.queue_redraw()

func flash() -> void:
	_flash = 1.0
	_icon.call("pop")

func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 3.0, 0.0)
	_shake = maxf(_shake - delta * 4.0, 0.0)
	modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.6, 1.6, 1.6), _flash)
	add_theme_stylebox_override("panel", _style_hover if _hover or _flash > 0.0 else _style_normal)
	# Rotation is not overridden by the container layout, unlike position
	_buy.pivot_offset = _buy.size * 0.5
	_buy.rotation = sin(_shake * 40.0) * 0.08 * _shake

func _on_buy_pressed() -> void:
	if _locked:
		return
	var amount: int = ProducerManager.buy_producer(producer.id, GameManager.buy_mode)
	if amount <= 0:
		_shake = 1.0
		Sfx.play("deny")
		return
	flash()
	bought.emit(producer, amount, _buy.get_global_rect().get_center())

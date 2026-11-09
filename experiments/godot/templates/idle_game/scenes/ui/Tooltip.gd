# =============================================================================
# Tooltip.gd — Details of the hovered upgrade
# =============================================================================
# Name, effect, the figures before and after the purchase, and the cost
# (green when affordable). Follows the mouse and stays inside the screen.
# Figures are computed live, so they include every current multiplier:
#   producer upgrade  that producer's production before / after
#   global upgrade    total production before / after
#   click upgrade     value of a strike before / after
# =============================================================================

extends PanelContainer

const OFFSET: Vector2 = Vector2(18.0, 18.0)

var _upgrade: Upgrade = null
var _name: Label
var _effect: Label
var _detail: Label
var _cost: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_LIGHT, UiTheme.GOLD.darkened(0.3), 8, 12))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_name = UiTheme.label("", 17, UiTheme.GOLD)
	_effect = UiTheme.label("", 14, UiTheme.TEXT)
	_detail = UiTheme.label("", 13, UiTheme.CRYSTAL)
	_cost = UiTheme.label("", 14, UiTheme.TEXT)
	for label in [_name, _effect, _detail, _cost]:
		box.add_child(label as Label)

func show_upgrade(upgrade: Upgrade) -> void:
	_upgrade = upgrade
	visible = upgrade != null
	_refresh()

func hide_tooltip() -> void:
	_upgrade = null
	visible = false

func _process(_delta: float) -> void:
	if not visible:
		return
	_refresh()
	reset_size()
	var screen: Vector2 = get_viewport_rect().size
	var target: Vector2 = get_viewport().get_mouse_position() + OFFSET
	target.x = minf(target.x, screen.x - size.x - 8.0)
	target.y = minf(target.y, screen.y - size.y - 8.0)
	position = target

func _refresh() -> void:
	if _upgrade == null:
		return
	_name.text = upgrade_name(_upgrade)
	_effect.text = effect_text(_upgrade)
	_detail.text = _detail_text(_upgrade)
	var affordable: bool = ResourceManager.can_afford(ResourceManager.main_resource, _upgrade.cost)
	_cost.text = StringManager.t("cost", {value = Utils.format_number(_upgrade.cost)})
	_cost.add_theme_color_override("font_color", UiTheme.GOOD if affordable else UiTheme.BAD)

func upgrade_name(upgrade: Upgrade) -> String:
	return StringManager.t(upgrade.name_key, {producer = StringManager.producer_name(upgrade.name_producer)})

func effect_text(upgrade: Upgrade) -> String:
	var value: String = _number(upgrade.effect_value)
	match upgrade.effect_type:
		Upgrade.EffectType.MULTIPLY_PRODUCER:
			return StringManager.t("effect_producer", {producer = StringManager.producer_name(upgrade.effect_producer_id), value = value})
		Upgrade.EffectType.MULTIPLY_ALL:
			return StringManager.t("effect_all", {value = value})
		Upgrade.EffectType.MULTIPLY_CLICK:
			return StringManager.t("effect_click", {value = value})
	return StringManager.t("effect_share", {value = Utils.format_percent(upgrade.effect_value)})

func _detail_text(upgrade: Upgrade) -> String:
	match upgrade.effect_type:
		Upgrade.EffectType.MULTIPLY_PRODUCER:
			var producer: Producer = ProducerManager.producers.get(upgrade.effect_producer_id) as Producer
			var before: float = ProducerManager.get_producer_rps(producer) if producer != null else 0.0
			return StringManager.t("detail_rps", {before = Utils.format_number(before), after = Utils.format_number(before * upgrade.effect_value)})
		Upgrade.EffectType.MULTIPLY_ALL:
			var total: float = ProducerManager.get_total_rps()
			return StringManager.t("detail_rps", {before = Utils.format_number(total), after = Utils.format_number(total * upgrade.effect_value)})
	var click: float = ProducerManager.click_value()
	var base: float = ConfigManager.get_float("click_base_value", 1.0) * ProducerManager.click_multiplier
	var boost: float = PrestigeManager.multiplier() * BoostManager.click_multiplier()
	var after: float = click + base * (upgrade.effect_value - 1.0) * boost
	if upgrade.effect_type == Upgrade.EffectType.CLICK_RPS_SHARE:
		after = click + upgrade.effect_value * ProducerManager.get_base_rps() * boost
	return StringManager.t("detail_click", {before = Utils.format_number(click), after = Utils.format_number(after)})

func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, round(value)) else str(value).replace(".", "," if StringManager.get_language() == "fr" else ".")

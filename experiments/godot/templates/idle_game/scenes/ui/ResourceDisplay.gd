# =============================================================================
# ResourceDisplay.gd — Shard counter, production and strike value
# =============================================================================
# The big number rolls toward the real amount (exponential smoothing) instead
# of jumping, and pulses on large gains (meteor, offline gains). Below it:
# the production per second, with the active boost when there is one, and
# the value of one strike.
# =============================================================================

extends VBoxContainer

const ROLL_SPEED: float = 12.0

var _amount_label: Label
var _unit_label: Label
var _rps_label: Label
var _click_label: Label
var _shown: float = 0.0
var _pulse: float = 0.0
var _refresh_left: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 0)
	_amount_label = _centered(UiTheme.label("0", 50, UiTheme.TEXT))
	_unit_label = _centered(UiTheme.label("", 16, UiTheme.MUTED))
	_rps_label = _centered(UiTheme.label("", 19, UiTheme.CRYSTAL))
	_click_label = _centered(UiTheme.label("", 13, UiTheme.MUTED))
	_amount_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	_amount_label.add_theme_constant_override("outline_size", 6)
	_shown = ResourceManager.get_amount(ResourceManager.main_resource)

func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.pivot_offset = Vector2(220.0, 30.0)
	add_child(label)
	return label

func pulse() -> void:
	_pulse = 1.0

func _process(delta: float) -> void:
	var actual: float = ResourceManager.get_amount(ResourceManager.main_resource)
	if actual < _shown:
		_shown = actual   # spending: no rolling down, the price leaves at once
	else:
		_shown += (actual - _shown) * (1.0 - exp(-ROLL_SPEED * delta))
	_amount_label.text = Utils.format_number(_shown)
	_pulse = maxf(_pulse - delta * 2.5, 0.0)
	_amount_label.scale = Vector2.ONE * (1.0 + 0.12 * _pulse)
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.1
		_refresh_details()

func _refresh_details() -> void:
	_unit_label.text = StringManager.t("unit_name")
	var rps_text: String = StringManager.t("rps_value", {value = Utils.format_number(ProducerManager.get_total_rps())})
	if BoostManager.is_frenzy():
		rps_text += "   " + StringManager.t("boost_frenzy", {value = _mult(ConfigManager.get_float("frenzy_multiplier", 2.0))})
	if BoostManager.eruption_left > 0.0:
		rps_text += "   " + StringManager.t("boost_eruption", {value = _mult(ConfigManager.get_float("meteor_eruption_multiplier", 5.0))})
	_rps_label.text = rps_text
	_rps_label.add_theme_color_override("font_color", UiTheme.HEAT if BoostManager.is_frenzy() else (UiTheme.GOLD if BoostManager.eruption_left > 0.0 else UiTheme.CRYSTAL))
	_click_label.text = StringManager.t("per_click", {value = Utils.format_number(ProducerManager.click_value())})

func _mult(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, round(value)) else str(value)

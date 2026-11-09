# =============================================================================
# InfoPanel.gd — Details of the hovered unit (shop, bench, board, enemies)
# =============================================================================
# Name in the tier colour, price and stars, class and origin, the stats of
# its star level (an enemy's include its round growth), and its ability with
# the real figures. Without a hovered unit, it shows how to play.
# =============================================================================

extends PanelContainer

class TokenView extends Control:
	var data: Dictionary = {}
	var star: int = 1
	var team: int = -1
	func _draw() -> void:
		if not data.is_empty():
			UnitPainter.draw_token(self, size * 0.5 + Vector2(0.0, 6.0), 24.0, data, {"star": star, "team": team})

var _token: TokenView
var _name: Label
var _sub: Label
var _traits: Label
var _stats: Label
var _ability: Label
var _help: Label

func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	_token = TokenView.new()
	_token.custom_minimum_size = Vector2(64.0, 70.0)
	head.add_child(_token)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	head.add_child(titles)
	_name = UiTheme.label("", 19, UiTheme.TEXT)
	_sub = UiTheme.label("", 13, UiTheme.MUTED)
	_traits = UiTheme.label("", 13, UiTheme.TEXT)
	for label in [_name, _sub, _traits]:
		titles.add_child(label as Label)
	_stats = UiTheme.label("", 13, UiTheme.TEXT)
	box.add_child(_stats)
	_ability = _wrapped(box, 13, UiTheme.GOLD)
	_help = _wrapped(box, 13, UiTheme.MUTED)
	StringManager.language_changed.connect(func(_l: String) -> void: show_unit(null))
	show_unit(null)

func _wrapped(parent: Control, font_size: int, color: Color) -> Label:
	var label: Label = UiTheme.label("", font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(480.0, 0.0)
	parent.add_child(label)
	return label

func show_type(type_id: String) -> void:
	var unit := Unit.new()
	unit.setup(UnitDatabase.unit_data(type_id), 1)
	show_unit(unit)

func show_unit(unit: Unit) -> void:
	var has_unit: bool = unit != null
	for control in [_token, _name, _sub, _traits, _stats, _ability]:
		(control as Control).visible = has_unit
	_help.visible = not has_unit
	if not has_unit:
		_help.text = StringManager.t("help_text")
		return
	_token.data = unit.data
	_token.star = unit.star
	_token.team = unit.team if RoundManager.phase == RoundManager.Phase.BATTLE else -1
	_token.queue_redraw()
	_name.text = StringManager.unit_name(unit.type_id)
	_name.add_theme_color_override("font_color", UiTheme.tier_color(unit.tier) if not unit.is_boss else UiTheme.ENEMY)
	_sub.text = StringManager.t("boss_label") if unit.is_boss else StringManager.t("unit_sub", {cost = unit.tier, star = unit.star, sell = unit.sell_value()})
	var names: PackedStringArray = []
	for t in unit.traits:
		names.append(StringManager.trait_name(t))
	_traits.text = "  ·  ".join(names)
	_stats.text = StringManager.t("unit_stats", {hp = int(unit.base_hp()), atk = int(unit.base_attack()),
		speed = _decimal(float(unit.data.get("attack_speed", 1.0))), range = unit.base_range(),
		armor = int(unit.data.get("armor", 0)), mana = int(unit.data.get("mana", 0))})
	_ability.text = ability_text(unit)

func ability_text(unit: Unit) -> String:
	var ability: Dictionary = unit.ability()
	var kind: String = str(ability.get("type", "strike"))
	var value: float = float(ability.get("value", 0.0))
	var shown: String = str(int(round(value * 100.0))) if kind in ["strike", "volley", "dash"] else str(int(round(value * unit.ability_factor() * unit.stat_scale)))
	return StringManager.t("ability_" + kind, {value = shown, count = int(ability.get("count", 0)),
		duration = _decimal(float(ability.get("duration", 0.0)))})

func _decimal(value: float) -> String:
	var text: String = str(snappedf(value, 0.01))
	return text.replace(".", ",") if StringManager.get_language() == "fr" else text

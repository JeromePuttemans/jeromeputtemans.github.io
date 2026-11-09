# =============================================================================
# ShopCard.gd — One offer of the shop
# =============================================================================
# Drawn by code: border in the tier colour, the unit token, its name, the
# icons of its class and origin, the price, and gold pips counting the copies
# already owned toward a merge (two pips lit: the next copy merges). Dimmed
# when the gold is short; an empty dark slot once bought.
# =============================================================================

extends Button

signal hovered(type_id: String)
signal unhovered()

const SIZE: Vector2 = Vector2(100.0, 150.0)

var index: int = 0
var _font: Font = null
var _hover_time: float = 0.0

func setup(shop_index: int) -> void:
	index = shop_index
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_NONE
	flat = true
	_font = ThemeDB.fallback_font
	mouse_entered.connect(func() -> void:
		if not type_id().is_empty():
			hovered.emit(type_id()))
	mouse_exited.connect(func() -> void: unhovered.emit())
	pressed.connect(_on_pressed)

func type_id() -> String:
	return RoundManager.shop[index] if index < RoundManager.shop.size() else ""

func _on_pressed() -> void:
	if type_id().is_empty():
		return
	if RoundManager.buy(index):
		Sfx.play("buy")
		_hover_time = 0.0
	else:
		Sfx.play("deny")

func _process(delta: float) -> void:
	_hover_time = _hover_time + delta if is_hovered() else 0.0
	queue_redraw()

func _owned_copies(id: String) -> int:
	var count: int = 0
	for unit in RoundManager.board.all_units():
		if unit.type_id == id and unit.star == 1:
			count += 1
	return count

func _draw() -> void:
	var id: String = type_id()
	var rect := Rect2(Vector2.ZERO, size)
	if id.is_empty():
		draw_style_box(UiTheme.box(Color(0.08, 0.08, 0.11), Color(0.16, 0.16, 0.22), 8, 0), rect)
		return
	var data: Dictionary = UnitDatabase.unit_data(id)
	var tier: int = int(data.get("tier", 1))
	var affordable: bool = RoundManager.gold >= tier and RoundManager.phase == RoundManager.Phase.PREP
	var alpha: float = 1.0 if affordable else 0.45
	var lift: float = -3.0 * clampf(_hover_time * 8.0, 0.0, 1.0)
	var style: StyleBoxFlat = UiTheme.box(UiTheme.PANEL_LIGHT if is_hovered() else UiTheme.PANEL, UiTheme.tier_color(tier), 8, 0)
	style.set_border_width_all(2)
	draw_style_box(style, Rect2(Vector2(0.0, lift), size))
	UnitPainter.draw_token(self, Vector2(size.x * 0.5, 46.0 + lift), 25.0, data, {"alpha": alpha})
	draw_multiline_string(_font, Vector2(4.0, 92.0 + lift), StringManager.unit_name(id), HORIZONTAL_ALIGNMENT_CENTER, size.x - 8.0, 12, 2, Color(UiTheme.TEXT, alpha))
	_draw_traits(data, Vector2(size.x * 0.5, 122.0 + lift), alpha)
	_draw_price(tier, Vector2(10.0, size.y - 11.0 + lift), alpha)
	_draw_copies(_owned_copies(id), Vector2(size.x - 12.0, size.y - 11.0 + lift))

func _draw_traits(data: Dictionary, center: Vector2, alpha: float) -> void:
	var traits: Array = data.get("traits", []) as Array
	for i in traits.size():
		var t: String = str(traits[i])
		var pos: Vector2 = center + Vector2((i - (traits.size() - 1) * 0.5) * 24.0, 0.0)
		var color: Color = UnitDatabase.trait_color(t)
		draw_circle(pos, 9.0, Color(color.darkened(0.6), alpha))
		if UnitDatabase.trait_data(t).get("kind", "") == "class":
			UnitPainter.draw_class_icon(self, pos, 6.0, t, Color(color, alpha))
		else:
			draw_circle(pos, 5.0, Color(color, alpha))

func _draw_price(tier: int, pos: Vector2, alpha: float) -> void:
	draw_circle(pos, 7.0, Color(UiTheme.GOLD.darkened(0.3), alpha))
	draw_circle(pos, 5.0, Color(UiTheme.GOLD, alpha))
	draw_string(_font, pos + Vector2(10.0, 5.0), str(tier), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UiTheme.GOLD, alpha))

func _draw_copies(count: int, right: Vector2) -> void:
	var needed: int = ConfigManager.get_int("merge_count", 3)
	for i in needed - 1:
		var pos: Vector2 = right - Vector2(i * 11.0, 0.0)
		var lit: bool = (needed - 2 - i) < count
		draw_circle(pos, 4.0, UiTheme.GOLD if lit else Color(1.0, 1.0, 1.0, 0.15))

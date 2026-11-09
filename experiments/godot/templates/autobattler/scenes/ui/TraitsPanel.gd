# =============================================================================
# TraitsPanel.gd — Synergies of the units on the board
# =============================================================================
# One row per trait present on the board, active ones first: its icon, its
# name, the count against each threshold (lit when reached) and the effect
# it gives now, or the one it would give at the next threshold. A trait
# counts different unit types, so the row tells the player which new unit
# would light the next threshold.
# =============================================================================

extends VBoxContainer

class TraitIcon extends Control:
	var trait_id: String = ""
	var active: bool = false
	func _draw() -> void:
		var color: Color = UnitDatabase.trait_color(trait_id)
		var center: Vector2 = size * 0.5
		draw_circle(center, 13.0, color.darkened(0.6) if active else Color(0.15, 0.15, 0.2))
		draw_arc(center, 13.0, 0.0, TAU, 24, color if active else Color(0.35, 0.35, 0.45), 1.5, true)
		if UnitDatabase.trait_data(trait_id).get("kind", "") == "class":
			UnitPainter.draw_class_icon(self, center, 8.0, trait_id, color if active else Color(0.6, 0.6, 0.66))
		else:
			draw_circle(center, 6.0, color if active else Color(0.5, 0.5, 0.56))

var _title: Label
var _list: VBoxContainer
var _empty: Label

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_title = UiTheme.label("", 18, UiTheme.TEXT)
	add_child(_title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	add_child(_list)
	_empty = UiTheme.label("", 13, UiTheme.MUTED)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size = Vector2(180.0, 0.0)
	add_child(_empty)
	RoundManager.board_changed.connect(rebuild)
	StringManager.language_changed.connect(func(_l: String) -> void: rebuild())
	rebuild()

func rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_title.text = StringManager.t("traits_title")
	var counts: Dictionary = TraitSystem.count(RoundManager.board.board_units()) if RoundManager.board != null else {}
	var ids: Array = counts.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var la: int = TraitSystem.level_for(str(a), int(counts[a]))
		var lb: int = TraitSystem.level_for(str(b), int(counts[b]))
		return la > lb or (la == lb and int(counts[a]) > int(counts[b])))
	for id in ids:
		_list.add_child(_make_row(str(id), int(counts[id])))
	_empty.text = StringManager.t("traits_empty")
	_empty.visible = ids.is_empty()

func _make_row(trait_id: String, amount: int) -> PanelContainer:
	var level: int = TraitSystem.level_for(trait_id, amount)
	var color: Color = UnitDatabase.trait_color(trait_id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_LIGHT if level > 0 else UiTheme.PANEL, color.darkened(0.3) if level > 0 else UiTheme.BORDER, 6, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var icon := TraitIcon.new()
	icon.trait_id = trait_id
	icon.active = level > 0
	icon.custom_minimum_size = Vector2(28.0, 28.0)
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var thresholds: Array = UnitDatabase.trait_data(trait_id).get("thresholds", []) as Array
	var parts: PackedStringArray = []
	for t in thresholds:
		parts.append(str(int(t)))
	var head: Label = UiTheme.label("%s  %d (%s)" % [StringManager.trait_name(trait_id), amount, " / ".join(parts)], 14, color if level > 0 else UiTheme.MUTED)
	texts.add_child(head)
	var effect_level: int = clampi(level if level > 0 else 1, 1, thresholds.size())
	var effect_key: String = "trait_%s_%d" % [trait_id, effect_level]
	var effect_text: String = StringManager.t(effect_key)
	if level == 0:
		effect_text = StringManager.t("trait_next", {count = int(thresholds[0]) if not thresholds.is_empty() else 2, effect = effect_text})
	var effect: Label = UiTheme.label(effect_text, 11, UiTheme.TEXT if level > 0 else UiTheme.MUTED)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.custom_minimum_size = Vector2(140.0, 0.0)
	texts.add_child(effect)
	return panel

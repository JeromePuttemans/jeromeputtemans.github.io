# =============================================================================
# LevelSelect.gd — One card per level: record, fireflies, golden acorns
# =============================================================================
# A level is playable once the previous one has been finished
# (SaveManager.unlocked). Locked cards are disabled and show a padlock.
# =============================================================================

class_name LevelSelect
extends Control

signal level_chosen(index: int)
signal back_requested()

var _title: Label
var _cards: HBoxContainer
var _back: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.veil(0.35))
	var center := UiTheme.center_box()
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 26)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)
	_title = UiTheme.label("", 44, UiTheme.TEXT, 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 16)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_cards)
	var holder := CenterContainer.new()
	_back = UiTheme.button("", func() -> void: back_requested.emit())
	holder.add_child(_back)
	column.add_child(holder)
	StringManager.language_changed.connect(func(_l: String) -> void:
		if visible:
			rebuild())

func rebuild() -> void:
	_title.text = StringManager.t("levels_title")
	_back.text = StringManager.t("back")
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for i in GameState.levels.size():
		_cards.add_child(_card(i))

func focus_default() -> void:
	rebuild()
	var index: int = clampi(SaveManager.unlocked() - 1, 0, _cards.get_child_count() - 1)
	(_cards.get_child(index) as Button).grab_focus()

func _card(index: int) -> Button:
	var data: LevelData = GameState.levels[index]
	var locked: bool = index >= SaveManager.unlocked()
	var rec: Dictionary = SaveManager.record(data.id)
	var card := UiTheme.button("", func() -> void: level_chosen.emit(index), 200.0)
	card.custom_minimum_size = Vector2(200.0, 236.0)
	card.disabled = locked
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 14.0
	box.offset_bottom = -12.0
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var number := UiTheme.label(str(index + 1), 46, UiTheme.MUTED if locked else UiTheme.GOLD, 6)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(number)
	var name_label := UiTheme.label(StringManager.t(data.name_key), 19, UiTheme.MUTED if locked else UiTheme.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	if locked:
		box.add_child(_centered(Icon.make("lock", 34.0)))
		var text := UiTheme.label(StringManager.t("locked"), 15, UiTheme.MUTED)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(text)
		return card
	var best: String = GameState.format_time(float(rec["best_time"])) if rec.has("best_time") else StringManager.t("not_finished")
	var time := UiTheme.label(best, 17, UiTheme.TEXT if rec.has("best_time") else UiTheme.MUTED)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(time)
	var flies := HBoxContainer.new()
	flies.alignment = BoxContainer.ALIGNMENT_CENTER
	flies.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flies.add_child(Icon.make("firefly", 22.0))
	var best_flies: int = int(rec.get("fireflies", 0))
	flies.add_child(UiTheme.label("%d / %d" % [best_flies, data.firefly_total], 16, UiTheme.GOLD if best_flies == data.firefly_total else UiTheme.TEXT))
	box.add_child(flies)
	var acorns := HBoxContainer.new()
	acorns.alignment = BoxContainer.ALIGNMENT_CENTER
	acorns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for a in data.acorn_total:
		acorns.add_child(Icon.make("acorn", 22.0, SaveManager.acorn_found(data.id, a)))
	box.add_child(acorns)
	return card

func _centered(control: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(control)
	return c

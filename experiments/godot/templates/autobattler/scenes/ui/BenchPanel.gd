# =============================================================================
# BenchPanel.gd — Displays bench units with Place and Sell buttons.
# =============================================================================
# CRITICAL: use free() not queue_free() when clearing children before rebuild.
# queue_free() defers deletion so newly added children coexist with the old
# ones until end-of-frame, causing phantom duplicates in the layout.
# =============================================================================

extends VBoxContainer

@onready var title_label: Label         = $TitleLabel
@onready var vbox:        VBoxContainer = $ScrollContainer/VBox

func _ready() -> void:
	RoundManager.board_changed.connect(_rebuild)
	RoundManager.phase_changed.connect(_on_phase_changed)
	StringManager.language_changed.connect(_on_language_changed)
	title_label.text = StringManager.t("bench_title")
	_rebuild()

func _rebuild() -> void:
	# free() removes nodes immediately so the layout is clean before add_child
	for child in vbox.get_children():
		child.free()

	if RoundManager.board == null:
		return

	var is_prep = RoundManager.phase == RoundManager.Phase.PREP

	for unit in RoundManager.board.get_bench_units():
		vbox.add_child(_make_card(unit, is_prep))

func _make_card(unit: Unit, is_prep: bool) -> HBoxContainer:
	var hbox = HBoxContainer.new()

	var info = Label.new()
	info.text = "%s\n%s" % [
		unit.display_name,
		StringManager.t("unit_stats", {hp = unit.hp_max, atk = unit.attack, def = unit.defense})
	]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 11)
	hbox.add_child(info)

	var place_btn = Button.new()
	place_btn.text     = StringManager.t("place_button")
	place_btn.disabled = not is_prep
	place_btn.pressed.connect(func(): RoundManager.place_unit(unit))
	hbox.add_child(place_btn)

	var sell_btn = Button.new()
	sell_btn.text     = StringManager.t("sell_button", {value = ConfigManager.get_int("unit_sell_value", 1)})
	sell_btn.disabled = not is_prep
	sell_btn.pressed.connect(func(): RoundManager.sell_unit(unit))
	hbox.add_child(sell_btn)

	return hbox

func _on_phase_changed(_p: RoundManager.Phase) -> void:
	_rebuild()

func _on_language_changed(_lang: String) -> void:
	title_label.text = StringManager.t("bench_title")
	_rebuild()

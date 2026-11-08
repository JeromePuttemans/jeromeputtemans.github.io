# =============================================================================
# ShopPanel.gd — Displays the shop pool with Buy buttons and Refresh.
# =============================================================================
# shop_pool is an Array[String] of type_ids maintained by RoundManager.
# Buying a slot replaces its entry with "" (sold-out) until the next refresh.
# =============================================================================

extends VBoxContainer

@onready var title_label:   Label        = $TitleLabel
@onready var items_hbox:    HBoxContainer = $ItemsHBox
@onready var refresh_btn:   Button       = $RefreshButton
@onready var feedback_label: Label       = $FeedbackLabel

var _feedback_timer: float = 0.0
const FEEDBACK_DURATION = 2.0

func _ready() -> void:
	RoundManager.phase_changed.connect(_on_phase_changed)
	RoundManager.gold_changed.connect(func(_v): _rebuild())
	StringManager.language_changed.connect(_on_language_changed)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	feedback_label.visible = false
	_refresh_static()
	_rebuild()

func _process(delta: float) -> void:
	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0:
			feedback_label.visible = false

func _rebuild() -> void:
	for child in items_hbox.get_children():
		child.free()

	var is_prep = RoundManager.phase == RoundManager.Phase.PREP
	var cost    = ConfigManager.get_int("unit_buy_cost", 3)
	var can_buy = RoundManager.player_gold >= cost

	for i in RoundManager.shop_pool.size():
		var type_id: String = RoundManager.shop_pool[i]
		var slot_idx = i   # Capture for lambda

		var card = VBoxContainer.new()
		card.custom_minimum_size = Vector2(90, 0)

		if type_id.is_empty():
			# Sold-out slot
			var lbl = Label.new()
			lbl.text = "—"
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add_child(lbl)
		else:
			var data = UnitDatabase.get_type(type_id)

			var name_lbl = Label.new()
			name_lbl.text = data.get("display_name", type_id)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.add_theme_font_size_override("font_size", 12)
			card.add_child(name_lbl)

			var stats_lbl = Label.new()
			stats_lbl.text = StringManager.t("unit_stats", {
				hp  = data.get("hp",      1),
				atk = data.get("attack",  1),
				def = data.get("defense", 0)
			})
			stats_lbl.add_theme_font_size_override("font_size", 10)
			stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add_child(stats_lbl)

			var btn = Button.new()
			btn.text     = StringManager.t("buy_button", {cost = cost})
			btn.disabled = not is_prep or not can_buy
			btn.pressed.connect(func():
				if RoundManager.buy_unit(type_id):
					RoundManager.shop_pool[slot_idx] = ""
					_rebuild()
				elif RoundManager.board.is_bench_full():
					_show_feedback(StringManager.t("bench_full"))
				else:
					_show_feedback(StringManager.t("not_enough_gold"))
			)
			card.add_child(btn)

		items_hbox.add_child(card)

	refresh_btn.disabled = not is_prep or \
		RoundManager.player_gold < ConfigManager.get_int("shop_refresh_cost", 2)

func _on_refresh_pressed() -> void:
	if not RoundManager.refresh_shop():
		_show_feedback(StringManager.t("not_enough_gold"))
	else:
		_rebuild()

func _show_feedback(msg: String) -> void:
	feedback_label.text    = msg
	feedback_label.visible = true
	_feedback_timer        = FEEDBACK_DURATION

func _on_phase_changed(_p: RoundManager.Phase) -> void:
	_rebuild()

func _on_language_changed(_lang: String) -> void:
	_refresh_static()
	_rebuild()

func _refresh_static() -> void:
	title_label.text = StringManager.t("shop_title")
	refresh_btn.text = StringManager.t("refresh_button", {
		cost = ConfigManager.get_int("shop_refresh_cost", 2)
	})

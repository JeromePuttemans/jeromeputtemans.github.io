# =============================================================================
# UpgradePanel.gd — Upgrade display panel
# =============================================================================
# On language switch:
#   - The panel title is refreshed via @onready.
#   - Each upgrade card's buy button text is refreshed via stored meta.
#     (upgrade meta stores both the Upgrade object and the Button reference)
# =============================================================================

extends PanelContainer

@onready var title_label: Label       = $VBox/Title
@onready var vbox:        VBoxContainer = $VBox/ScrollContainer/VBoxContainer

func _ready() -> void:
	ProducerManager.upgrade_unlocked.connect(_on_upgrade_unlocked)
	ResourceManager.resource_changed.connect(_on_resource_changed)
	StringManager.language_changed.connect(_on_language_changed)
	_refresh_title()
	_populate_unlocked()

func _refresh_title() -> void:
	title_label.text = StringManager.t("upgrades_title")

func _populate_unlocked() -> void:
	for upgrade in ProducerManager.upgrades.values():
		if not upgrade.is_purchased and upgrade.is_unlocked(
				ProducerManager.producers,
				ResourceManager.get_total_produced(ResourceManager.main_resource)):
			_add_upgrade_card(upgrade)

func _on_upgrade_unlocked(upgrade: Upgrade) -> void:
	if not vbox.get_node_or_null(upgrade.id):
		_add_upgrade_card(upgrade)

func _add_upgrade_card(upgrade: Upgrade) -> void:
	var card = PanelContainer.new()
	card.name = upgrade.id
	card.custom_minimum_size = Vector2(0, 50)

	var hbox = HBoxContainer.new()
	card.add_child(hbox)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var title = Label.new()
	title.text = upgrade.display_name
	info.add_child(title)

	var desc = Label.new()
	desc.text = upgrade.description
	desc.add_theme_font_size_override("font_size", 11)
	info.add_child(desc)

	var btn = Button.new()
	btn.text     = StringManager.t("buy_button", {value = Utils.format_number(upgrade.cost)})
	btn.disabled = not ResourceManager.can_afford(ResourceManager.main_resource, upgrade.cost)
	btn.pressed.connect(func():
		if ProducerManager.buy_upgrade(upgrade.id):
			card.queue_free()
	)
	hbox.add_child(btn)
	vbox.add_child(card)

	# Store both the Upgrade reference and the Button reference.
	# The Upgrade is needed to rebuild the buy_button text on language switch
	# (cost value must be re-formatted into the new language template).
	card.set_meta("upgrade", upgrade)
	card.set_meta("buy_button", btn)

func _on_resource_changed(_id: String, _val: float) -> void:
	for card in vbox.get_children():
		if card.has_meta("buy_button"):
			var upgrade: Upgrade = card.get_meta("upgrade")
			var btn: Button      = card.get_meta("buy_button")
			btn.disabled = not ResourceManager.can_afford(ResourceManager.main_resource, upgrade.cost)

func _on_language_changed(_lang: String) -> void:
	_refresh_title()
	# Rebuild buy button text for every visible upgrade card
	for card in vbox.get_children():
		if card.has_meta("buy_button"):
			var upgrade: Upgrade = card.get_meta("upgrade")
			var btn: Button      = card.get_meta("buy_button")
			btn.text = StringManager.t("buy_button", {value = Utils.format_number(upgrade.cost)})

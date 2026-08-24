# =============================================================================
# ProducerCard.gd — UI card for a single producer
# =============================================================================
# Subscribes to language_changed so all labels re-render on language switch.
# Note: display_name and description come from producers.json (game data),
# not from StringManager — only UI chrome is translated here.
# =============================================================================

extends PanelContainer

@onready var name_label:        Label  = $VBox/Header/NameLabel
@onready var owned_label:       Label  = $VBox/Header/OwnedLabel
@onready var description_label: Label  = $VBox/DescriptionLabel
@onready var cost_label:        Label  = $VBox/Footer/CostLabel
@onready var rps_label:         Label  = $VBox/Footer/RPSLabel
@onready var buy_button:        Button = $VBox/Footer/BuyButton

var producer: Producer = null

func setup(p: Producer) -> void:
	producer               = p
	name_label.text        = producer.display_name
	description_label.text = producer.description
	buy_button.pressed.connect(_on_buy_pressed)
	StringManager.language_changed.connect(_on_language_changed)
	refresh()

func refresh() -> void:
	if not producer:
		return
	owned_label.text  = StringManager.t("owned_count", {value = producer.owned})
	cost_label.text   = StringManager.t("cost_label",  {value = Utils.format_number(producer.get_current_cost())})
	buy_button.text   = StringManager.t("buy_producer_button")

	if producer.owned == 0:
		rps_label.text = StringManager.t("rps_per_unit", {
			value = "%.2f" % (producer.base_production * producer.multiplier)
		})
	else:
		rps_label.text = StringManager.t("rps_total", {
			value = "%.2f" % producer.get_rps()
		})
	refresh_affordability()

func refresh_affordability() -> void:
	if not producer:
		return
	buy_button.disabled = not ResourceManager.can_afford(
		ResourceManager.main_resource,
		producer.get_current_cost()
	)

func _on_buy_pressed() -> void:
	if ProducerManager.buy_producer(producer.id):
		refresh()

func _on_language_changed(_lang: String) -> void:
	refresh()

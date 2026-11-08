# =============================================================================
# ProducerList.gd — Scrollable list of all producers
# =============================================================================
# On language switch, forwards the refresh to all cards.
# =============================================================================

extends ScrollContainer

const PRODUCER_CARD_SCENE = preload("res://scenes/ui/ProducerCard.tscn")

@onready var vbox: VBoxContainer = $VBoxContainer

var _cards: Dictionary = {}  # { producer_id: ProducerCard }

func _ready() -> void:
	ProducerManager.producer_purchased.connect(_on_producer_purchased)
	ResourceManager.resource_changed.connect(_on_resource_changed)
	StringManager.language_changed.connect(_on_language_changed)
	_populate()

func _populate() -> void:
	for child in vbox.get_children():
		child.queue_free()
	_cards.clear()
	for producer in ProducerManager.producers.values():
		var card = PRODUCER_CARD_SCENE.instantiate()
		vbox.add_child(card)
		card.setup(producer)
		_cards[producer.id] = card

func _on_producer_purchased(_producer: Producer) -> void:
	for card in _cards.values():
		card.refresh()

func _on_resource_changed(_id: String, _val: float) -> void:
	for card in _cards.values():
		card.refresh_affordability()

## Cards subscribe to language_changed individually in their own setup(),
## so this handler is only needed if ProducerList itself had static text.
## Kept for symmetry and future extensibility.
func _on_language_changed(_lang: String) -> void:
	pass

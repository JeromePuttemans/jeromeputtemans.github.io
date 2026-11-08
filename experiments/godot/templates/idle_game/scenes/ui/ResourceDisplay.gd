# =============================================================================
# ResourceDisplay.gd — Resource amount display
# =============================================================================

extends VBoxContainer

@onready var gold_label: Label = $GoldLabel

func _ready() -> void:
	ResourceManager.resource_changed.connect(_on_resource_changed)
	StringManager.language_changed.connect(_on_language_changed)
	_refresh()

func _on_resource_changed(_id: String, _val: float) -> void:
	_refresh()

func _on_language_changed(_lang: String) -> void:
	_refresh()

func _refresh() -> void:
	gold_label.text = StringManager.t("resource_display", {
		value = Utils.format_number(ResourceManager.get_amount(ResourceManager.main_resource))
	})

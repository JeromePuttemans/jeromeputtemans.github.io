# =============================================================================
# Main.gd — Main scene script
# =============================================================================
# Responsibilities:
#   - Wire the save button and RPS label
#   - Own the language toggle button
#   - Refresh static labels (ProducersTitle, SaveButton) on language switch
# =============================================================================

extends Node

@onready var save_button:     Button = $UI/Root/MainVBox/HUD/SaveButton
@onready var lang_button:     Button = $UI/Root/MainVBox/HUD/LangButton
@onready var rps_label:       Label  = $UI/Root/MainVBox/HUD/RPSLabel
@onready var producers_title: Label  = $UI/Root/MainVBox/Columns/RightColumn/ProducersTitle

func _ready() -> void:
	save_button.pressed.connect(func(): SaveManager.save_game())
	lang_button.pressed.connect(_on_lang_button_pressed)
	ResourceManager.resource_changed.connect(_on_resource_changed)
	StringManager.language_changed.connect(_on_language_changed)
	_refresh_static()

## Cycles through available languages.
## Add new language codes here when adding more translations.
func _on_lang_button_pressed() -> void:
	var langs = ["en", "fr"]
	var idx   = langs.find(StringManager.get_language())
	StringManager.set_language(langs[(idx + 1) % langs.size()])

func _on_language_changed(_lang: String) -> void:
	_refresh_static()
	# Re-emit the last known RPS so the label re-renders in the new language
	_on_resource_changed("", 0.0)

func _on_resource_changed(_id: String, _val: float) -> void:
	rps_label.text = StringManager.t("rps_label", {
		value = Utils.format_number(ProducerManager.get_total_rps())
	})

## Refreshes all labels whose text is purely a string key (no runtime value).
func _refresh_static() -> void:
	save_button.text     = StringManager.t("save_button")
	lang_button.text     = StringManager.t("lang_button")
	producers_title.text = StringManager.t("producers_title")

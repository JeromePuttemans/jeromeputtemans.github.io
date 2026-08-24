# =============================================================================
# HUD.gd — Heads-Up Display: floor, HP, and language toggle button.
# =============================================================================
# Subscribes to GameState signals for content updates and to
# StringManager.language_changed for text re-rendering on language switch.
# =============================================================================

extends HBoxContainer

@onready var floor_label: Label  = $FloorLabel
@onready var hp_label:    Label  = $HPLabel
@onready var lang_button: Button = $LangButton

func _ready() -> void:
	GameState.dungeon_ready.connect(_refresh)
	GameState.turn_ended.connect(_refresh)
	StringManager.language_changed.connect(_on_language_changed)
	lang_button.pressed.connect(_on_lang_button_pressed)
	_refresh_lang_button()
	_refresh()

func _refresh() -> void:
	if GameState.player == null:
		return
	floor_label.text = StringManager.t("floor_label", {value = GameState.current_floor})
	hp_label.text    = StringManager.t("hp_label", {
		current = GameState.player.hp,
		max     = GameState.player.hp_max
	})

## Cycles to the next available language.
## Extend the list here when adding more languages.
func _on_lang_button_pressed() -> void:
	var langs = ["en", "fr"]
	var idx   = langs.find(StringManager.get_language())
	var next  = langs[(idx + 1) % langs.size()]
	StringManager.set_language(next)

## Called by language_changed signal — refreshes all text in the HUD.
func _on_language_changed(_lang: String) -> void:
	_refresh_lang_button()
	_refresh()

## The button label shows the CURRENT language code so the player
## always knows what language is active (not what it would switch to).
func _refresh_lang_button() -> void:
	lang_button.text = StringManager.t("lang_button")

# =============================================================================
# Main.gd — Root scene script.
# =============================================================================
# Handles the game-over / victory overlay and the R-to-restart shortcut.
# All game logic lives in RoundManager; this file only manages the overlay.
# =============================================================================

extends Node

@onready var overlay:       ColorRect = $UI/Overlay
@onready var overlay_title: Label     = $UI/Overlay/VBox/TitleLabel
@onready var overlay_sub:   Label     = $UI/Overlay/VBox/SubLabel

func _ready() -> void:
	overlay.visible = false
	RoundManager.game_over.connect(_on_game_over)
	RoundManager.game_won.connect(_on_game_won)
	StringManager.language_changed.connect(_on_language_changed)
	RoundManager.new_game()

func _on_game_over() -> void:
	overlay_title.text = StringManager.t("game_over_title")
	overlay_sub.text   = StringManager.t("game_over_sub")
	overlay.visible    = true

func _on_game_won() -> void:
	overlay_title.text = StringManager.t("victory_title")
	overlay_sub.text   = StringManager.t("victory_sub")
	overlay.visible    = true

func _on_language_changed(_lang: String) -> void:
	if not overlay.visible:
		return
	match RoundManager.phase:
		RoundManager.Phase.GAME_OVER:
			overlay_title.text = StringManager.t("game_over_title")
			overlay_sub.text   = StringManager.t("game_over_sub")
		RoundManager.Phase.VICTORY:
			overlay_title.text = StringManager.t("victory_title")
			overlay_sub.text   = StringManager.t("victory_sub")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_R:
		var p = RoundManager.phase
		if p == RoundManager.Phase.GAME_OVER or p == RoundManager.Phase.VICTORY:
			overlay.visible = false
			RoundManager.new_game()

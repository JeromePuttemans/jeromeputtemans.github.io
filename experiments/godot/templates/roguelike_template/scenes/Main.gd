# =============================================================================
# Main.gd — Root scene script.
# =============================================================================
# Responsibilities:
#   - Start a new game on _ready()
#   - Route keyboard input to GameState.player_action()
#   - Show/hide the game over / victory overlay
#   - Refresh the controls label on language switch
# =============================================================================

extends Node

@onready var overlay:        ColorRect = $UI/Overlay
@onready var overlay_title:  Label     = $UI/Overlay/VBox/TitleLabel
@onready var overlay_sub:    Label     = $UI/Overlay/VBox/SubLabel
@onready var controls_label: Label     = $UI/ControlsLabel

func _ready() -> void:
	overlay.visible = false
	GameState.player_died.connect(_on_game_over)
	GameState.player_won.connect(_on_victory)
	StringManager.language_changed.connect(_on_language_changed)
	_refresh_controls()
	GameState.new_game()

func _on_game_over() -> void:
	overlay_title.text = StringManager.t("game_over_title")
	overlay_sub.text   = StringManager.t("player_died_msg")
	overlay.visible    = true

func _on_victory() -> void:
	overlay_title.text = StringManager.t("victory_title")
	overlay_sub.text   = StringManager.t("victory_msg")
	overlay.visible    = true

func _on_language_changed(_lang: String) -> void:
	_refresh_controls()
	# If the overlay is visible its text must also be re-translated
	if overlay.visible:
		if GameState.phase == GameState.Phase.GAME_OVER:
			overlay_title.text = StringManager.t("game_over_title")
			overlay_sub.text   = StringManager.t("player_died_msg")
		elif GameState.phase == GameState.Phase.VICTORY:
			overlay_title.text = StringManager.t("victory_title")
			overlay_sub.text   = StringManager.t("victory_msg")

func _refresh_controls() -> void:
	controls_label.text = StringManager.t("controls")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	if event.keycode == KEY_R:
		if GameState.phase == GameState.Phase.GAME_OVER \
		or GameState.phase == GameState.Phase.VICTORY:
			overlay.visible = false
			GameState.new_game()
		return

	var dir = _keycode_to_dir(event.keycode)
	if dir != null:
		GameState.player_action(dir)

func _keycode_to_dir(keycode: int) -> Variant:
	match keycode:
		KEY_W, KEY_UP:         return Vector2i( 0, -1)
		KEY_S, KEY_DOWN:       return Vector2i( 0,  1)
		KEY_A, KEY_LEFT:       return Vector2i(-1,  0)
		KEY_D, KEY_RIGHT:      return Vector2i( 1,  0)
		KEY_Q:                 return Vector2i(-1, -1)
		KEY_E:                 return Vector2i( 1, -1)
		KEY_Z:                 return Vector2i(-1,  1)
		KEY_C:                 return Vector2i( 1,  1)
		KEY_PERIOD, KEY_SPACE: return Vector2i( 0,  0)
	return null

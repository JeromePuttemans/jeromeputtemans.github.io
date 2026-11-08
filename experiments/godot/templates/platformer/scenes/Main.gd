# =============================================================================
# Main.gd — Root scene script.
# =============================================================================
# Responsibilities:
#   - Load levels.json and build the initial level
#   - Listen to GameState signals and transition between states
#   - Manage respawn timer and level-to-level transitions
#   - Check the kill zone (player fell below the level)
#   - Show / hide the overlay
# =============================================================================

extends Node2D

@onready var platforms:    Node2D    = $World/Platforms
@onready var enemies_node: Node2D    = $World/Enemies
@onready var coins_node:   Node2D    = $World/Collectibles
@onready var world:        Node2D    = $World
@onready var overlay:      ColorRect = $UI/Overlay
@onready var ov_title:     Label     = $UI/Overlay/VBox/TitleLabel
@onready var ov_sub:       Label     = $UI/Overlay/VBox/SubLabel

var _levels:         Array  = []   # raw data from levels.json
var _player:         Player = null
var _kill_y:         float  = 900.0
var _respawn_timer:  float  = 0.0
var _respawning:     bool   = false

func _ready() -> void:
	_load_levels()
	GameState.total_levels = _levels.size()
	GameState.new_game()

	GameState.player_died.connect(_on_player_died)
	GameState.level_complete.connect(_on_level_complete)
	GameState.game_over.connect(_on_game_over)
	GameState.game_won.connect(_on_game_won)
	StringManager.language_changed.connect(_on_language_changed)

	overlay.visible = false
	_build_current_level()

func _process(delta: float) -> void:
	# Respawn countdown
	if _respawning:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawning     = false
			overlay.visible = false
			GameState.resume_playing()
			_build_current_level()
		return

	# Kill zone: player fell below the level floor
	if _player != null and is_instance_valid(_player):
		if _player.position.y > _kill_y and GameState.phase == GameState.Phase.PLAYING:
			_player._die()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_R:
		var p = GameState.phase
		if p == GameState.Phase.GAME_OVER or p == GameState.Phase.WIN:
			overlay.visible = false
			GameState.new_game()
			_build_current_level()

# ---------------------------------------------------------------------------
# Level management
# ---------------------------------------------------------------------------

func _load_levels() -> void:
	var path = "res://data/levels.json"
	if not FileAccess.file_exists(path):
		push_error("Main: levels.json not found")
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Main: levels.json parse error")
		return
	_levels = json.get_data()

func _build_current_level() -> void:
	if _levels.is_empty():
		push_error("Main: no levels loaded")
		return
	var idx = clamp(GameState.current_level, 0, _levels.size() - 1)
	var data = _levels[idx]

	_kill_y = float(data.get("kill_y", 900))
	_player = LevelBuilder.build(data, platforms, enemies_node, coins_node, world)

	# Set camera limits based on level dimensions
	var lw = float(data.get("width",  1920))
	var lh = float(data.get("height", 768))
	_player.camera.limit_left   = 0
	_player.camera.limit_top    = -200
	_player.camera.limit_right  = int(lw)
	_player.camera.limit_bottom = int(lh) + 200

	# Update HUD level label via a group message to avoid tight coupling
	var hud = get_node_or_null("UI/HUD")
	if hud and hud.has_method("refresh_level"):
		hud.refresh_level()

# ---------------------------------------------------------------------------
# GameState signal handlers
# ---------------------------------------------------------------------------

func _on_player_died() -> void:
	var delay = ConfigManager.get_float("respawn_delay", 0.0)
	_respawning    = true
	_respawn_timer = delay
	ov_title.text  = StringManager.t("dead_title")
	ov_sub.text    = StringManager.t("dead_sub")
	overlay.visible = true

func _on_level_complete() -> void:
	overlay.visible = false
	_build_current_level()

func _on_game_over() -> void:
	ov_title.text   = StringManager.t("game_over_title")
	ov_sub.text     = StringManager.t("game_over_sub")
	overlay.visible = true

func _on_game_won() -> void:
	ov_title.text   = StringManager.t("win_title")
	ov_sub.text     = StringManager.t("win_sub")
	overlay.visible = true

func _on_language_changed(_lang: String) -> void:
	# Re-translate overlay if it is currently visible
	if not overlay.visible:
		return
	match GameState.phase:
		GameState.Phase.DEAD:
			ov_title.text = StringManager.t("dead_title")
			ov_sub.text   = StringManager.t("dead_sub")
		GameState.Phase.GAME_OVER:
			ov_title.text = StringManager.t("game_over_title")
			ov_sub.text   = StringManager.t("game_over_sub")
		GameState.Phase.WIN:
			ov_title.text = StringManager.t("win_title")
			ov_sub.text   = StringManager.t("win_sub")

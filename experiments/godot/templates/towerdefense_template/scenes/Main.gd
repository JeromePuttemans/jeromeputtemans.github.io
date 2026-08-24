# =============================================================================
# Main.gd — Root scene script.
# =============================================================================
# Responsibilities:
#   - Load maps.json and build the grid + wave system
#   - Handle mouse input for tower placement / selection / selling
#   - Show / hide overlay (game over, victory)
#   - Connect GameState signals to UI updates
# =============================================================================

extends Node2D

@onready var grid_map:     TDGrid  = $World/GridMap
@onready var enemies_node: Node2D   = $World/Enemies
@onready var towers_node:  Node2D   = $World/Towers
@onready var projs_node:   Node2D   = $World/Projectiles
@onready var overlay:      ColorRect = $UI/Overlay
@onready var ov_title:     Label    = $UI/Overlay/VBox/TitleLabel
@onready var ov_sub:       Label    = $UI/Overlay/VBox/SubLabel

var _wave_manager:    WaveManager = null
var _selected_tower_id: String    = ""   # type id chosen in shop panel
var _selected_tower:    Tower     = null # placed tower currently selected
var _maps:            Array       = []

func _ready() -> void:
	_load_maps()
	GameState.new_game()
	GameState.game_over.connect(_on_game_over)
	GameState.game_won.connect(_on_game_won)
	StringManager.language_changed.connect(_on_language_changed)
	overlay.visible = false
	_build_map(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell = grid_map.world_to_grid(grid_map.to_local(get_global_mouse_position()))
		grid_map.set_hover(cell)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(get_global_mouse_position())
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			var p = GameState.phase
			if p == GameState.Phase.GAME_OVER or p == GameState.Phase.VICTORY:
				_restart()
		elif event.keycode == KEY_ESCAPE:
			_deselect_all()

func _handle_click(world_pos: Vector2) -> void:
	var local = grid_map.to_local(world_pos)
	var cell  = grid_map.world_to_grid(local)
	if cell.x < 0:
		return

	# Click on an existing tower → select it for selling
	var existing = grid_map.get_tower_at(cell.x, cell.y)
	if existing != null:
		_select_placed_tower(existing, cell)
		return

	# Click on a buildable tile with a tower type chosen → place it
	if not _selected_tower_id.is_empty() and GameState.phase == GameState.Phase.BUILD:
		_try_place_tower(cell)
		return

	_deselect_all()

func _try_place_tower(cell: Vector2i) -> void:
	if not grid_map.is_buildable(cell.x, cell.y):
		_show_feedback(StringManager.t("tile_occupied"))
		return
	var data = TowerDatabase.get_type(_selected_tower_id)
	if data.is_empty():
		return
	var cost = data.get("cost", 0)
	if not GameState.spend_gold(cost):
		_show_feedback(StringManager.t("no_gold"))
		return

	var tower = Tower.new()
	tower.name = "Tower"
	towers_node.add_child(tower)
	tower.setup(data)
	tower.enemies_node = enemies_node
	tower.global_position = grid_map.to_global(grid_map.grid_to_world(cell.x, cell.y))
	grid_map.place_tower(cell.x, cell.y, tower)

func _select_placed_tower(tower: Tower, cell: Vector2i) -> void:
	_deselect_all()
	_selected_tower = tower
	tower.set_selected(true)
	var hud = get_node_or_null("UI/HUD")
	if hud and hud.has_method("show_sell_panel"):
		hud.show_sell_panel(tower, cell)

func _deselect_all() -> void:
	if _selected_tower != null:
		_selected_tower.set_selected(false)
		_selected_tower = null
	_selected_tower_id = ""
	var hud = get_node_or_null("UI/HUD")
	if hud and hud.has_method("hide_sell_panel"):
		hud.hide_sell_panel()
	if hud and hud.has_method("clear_shop_selection"):
		hud.clear_shop_selection()

## Called by HUD when the player picks a tower type in the shop.
func select_tower_type(type_id: String) -> void:
	_deselect_all()
	_selected_tower_id = type_id

## Called by HUD sell button.
func sell_tower(tower: Tower, cell: Vector2i) -> void:
	GameState.add_gold(tower.sell_value)
	grid_map.remove_tower(cell.x, cell.y)
	tower.free()
	_deselect_all()

# ---------------------------------------------------------------------------
# Map / wave setup
# ---------------------------------------------------------------------------

func _load_maps() -> void:
	var path = "res://data/maps.json"
	if not FileAccess.file_exists(path):
		push_error("Main: maps.json not found")
		return
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("Main: maps.json parse error")
		return
	_maps = j.get_data()

func _build_map(index: int) -> void:
	if _maps.is_empty():
		push_error("Main: no maps loaded")
		return
	var map_data = _maps[clamp(index, 0, _maps.size() - 1)]
	grid_map.setup(map_data)

	# Clear previous enemies/towers/projectiles (free not queue_free)
	for c in enemies_node.get_children():    c.free()
	for c in towers_node.get_children():     c.free()
	for c in projs_node.get_children():      c.free()

	# Build WaveManager
	if _wave_manager != null:
		_wave_manager.free()
	_wave_manager              = WaveManager.new()
	_wave_manager.enemies_node = enemies_node
	_wave_manager.waypoints    = grid_map.waypoints
	add_child(_wave_manager)

	# Resize the viewport to fit the grid
	var tile = ConfigManager.get_int("tile_size", 0)
	var gw   = grid_map.cols * tile
	var gh   = grid_map.rows * tile
	var hud  = get_node_or_null("UI/HUD")
	if hud and hud.has_method("set_grid_size"):
		hud.set_grid_size(gw, gh)

func _restart() -> void:
	overlay.visible    = false
	_selected_tower_id = ""
	_selected_tower    = null
	GameState.new_game()
	_build_map(0)

# ---------------------------------------------------------------------------
# Overlay
# ---------------------------------------------------------------------------

func _on_game_over() -> void:
	ov_title.text   = StringManager.t("game_over_title")
	ov_sub.text     = StringManager.t("game_over_sub")
	overlay.visible = true

func _on_game_won() -> void:
	ov_title.text   = StringManager.t("victory_title")
	ov_sub.text     = StringManager.t("victory_sub")
	overlay.visible = true

func _on_language_changed(_lang: String) -> void:
	if not overlay.visible:
		return
	match GameState.phase:
		GameState.Phase.GAME_OVER:
			ov_title.text = StringManager.t("game_over_title")
			ov_sub.text   = StringManager.t("game_over_sub")
		GameState.Phase.VICTORY:
			ov_title.text = StringManager.t("victory_title")
			ov_sub.text   = StringManager.t("victory_sub")

func _show_feedback(msg: String) -> void:
	var hud = get_node_or_null("UI/HUD")
	if hud and hud.has_method("show_feedback"):
		hud.show_feedback(msg)

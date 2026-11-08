# =============================================================================
# Main.gd: root scene script.
# =============================================================================
# Responsibilities:
#   - Load maps.json, build the grid, the path markers and the WaveManager
#   - Center the map in the space left free by the HUD
#   - Player input: placement mode, selection, upgrade, sell, targeting,
#     keyboard shortcuts, game speed, pause
#   - End-of-game sequences (slow motion on defeat, confetti on victory)
#
# INPUT MODEL:
#   placing mode: a tower type is chosen (shop card or keys 1-3). Left click
#                   builds, the mode stays active while the player can afford
#                   another one. Right click / Esc cancels.
#   selection:    left click on a tower shows its panel (upgrade, sell,
#                   targeting). Right click / Esc / click elsewhere deselects.
#   Digits use physical_keycode so 1-3 work on AZERTY keyboards too; letters
#   use keycode (the letter printed on the key).
#
# PROCESS MODES:
#   Main and UI run ALWAYS (input and menus work while paused), World and the
#   WaveManager are PAUSABLE: get_tree().paused freezes only the game.
# =============================================================================

extends Node2D

@onready var world:        Node2D           = $World
@onready var grid_map:     TDGrid           = $World/GridMap
@onready var markers:      PathMarkers      = $World/PathMarkers
@onready var towers_node:  Node2D           = $World/Towers
@onready var enemies_node: Node2D           = $World/Enemies
@onready var projs_node:   Node2D           = $World/Projectiles
@onready var preview:      PlacementPreview = $World/Preview
@onready var hud:          GameHUD          = $UI/HUD

const COL_GOLD := Color("ffd34d")
const COL_BAD  := Color("ff6b6b")

var _maps:          Array       = []
var _wave_manager:  WaveManager = null
var _placing_id:    String      = ""
var _selected:      Tower       = null
var _selected_cell: Vector2i    = Vector2i(-1, -1)
var _hover_cell:    Vector2i    = Vector2i(-1, -1)
var _speed:         float       = 1.0
var _end_seq:       int         = 0   # invalidates pending end sequences on restart

func _ready() -> void:
	_load_maps()
	_connect_signals()
	GameState.new_game()
	_build_map(0)
	hud.reset_counters()

func _connect_signals() -> void:
	GameState.game_over.connect(_on_game_over)
	GameState.game_won.connect(_on_game_won)
	hud.tower_type_requested.connect(_on_tower_type_requested)
	hud.upgrade_requested.connect(_upgrade_selected)
	hud.sell_requested.connect(_sell_selected)
	hud.target_cycle_requested.connect(_cycle_target)
	hud.wave_requested.connect(_call_wave)
	hud.speed_toggled.connect(_toggle_speed)
	hud.pause_toggled.connect(_toggle_pause)
	hud.restart_requested.connect(_restart)

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover()
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed:
		if get_tree().paused or not GameState.is_playing():
			return
		_update_hover()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_click()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_all()
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_handle_key(key)

func _handle_key(key: InputEventKey) -> void:
	# Always available
	if key.keycode == KEY_M:
		Sfx.toggle_mute()
		return
	if key.keycode == KEY_R and (not GameState.is_playing() or get_tree().paused):
		_restart()
		return
	if not GameState.is_playing():
		return
	if key.keycode == KEY_P or (key.keycode == KEY_ESCAPE and not _has_context()):
		_toggle_pause()
		return
	if get_tree().paused:
		return

	var digit: int = -1
	if key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_9:
		digit = key.physical_keycode - KEY_1
	elif key.keycode >= KEY_KP_1 and key.keycode <= KEY_KP_9:
		digit = key.keycode - KEY_KP_1
	if digit >= 0:
		var all: Array = TowerDatabase.get_all()
		if digit < all.size():
			_on_tower_type_requested(str((all[digit] as Dictionary).get("id", "")))
		return

	match key.keycode:
		KEY_ESCAPE:
			_cancel_all()
		KEY_SPACE:
			_call_wave()
		KEY_U:
			_upgrade_selected()
		KEY_S, KEY_DELETE, KEY_BACKSPACE:
			_sell_selected()
		KEY_T:
			_cycle_target()
		KEY_F:
			_toggle_speed()

func _has_context() -> bool:
	return not _placing_id.is_empty() or is_instance_valid(_selected)

func _update_hover() -> void:
	var cell: Vector2i = grid_map.world_to_grid(grid_map.get_local_mouse_position())
	if cell == _hover_cell:
		return
	_hover_cell = cell
	preview.set_hover(cell)

func _handle_click() -> void:
	var cell: Vector2i = _hover_cell
	if cell.x < 0:
		_cancel_all()
		return
	var existing: Tower = grid_map.get_tower_at(cell.x, cell.y)
	if existing != null:
		_select_tower(existing, cell)
		return
	if not _placing_id.is_empty():
		_try_place_tower(cell)
		return
	_deselect()

# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------

func _on_tower_type_requested(type_id: String) -> void:
	if not GameState.is_playing():
		return
	if type_id == _placing_id:
		_cancel_placing()
		return
	var data: Dictionary = TowerDatabase.get_type(type_id)
	if data.is_empty():
		return
	_deselect()
	_placing_id = type_id
	preview.set_placing(data)
	hud.set_selected_type(type_id)
	var tower_name: String = StringManager.t_or("tower_%s_name" % type_id, str(data.get("display_name", type_id)))
	hud.show_hint(StringManager.t("hint_place", {name = tower_name}))

func _try_place_tower(cell: Vector2i) -> void:
	var data: Dictionary = TowerDatabase.get_type(_placing_id)
	var pos: Vector2 = grid_map.to_global(grid_map.grid_to_world(cell.x, cell.y))
	if not grid_map.is_buildable(cell.x, cell.y):
		match grid_map.tile_at(cell.x, cell.y):
			"P": _feedback(pos, StringManager.t("tile_path"))
			"X": _feedback(pos, StringManager.t("tile_rock"))
			_:   _feedback(pos, StringManager.t("tile_blocked"))
		return
	var cost: int = int(data.get("cost", 0))
	if not GameState.spend_gold(cost):
		_feedback_gold(pos, cost)
		return

	var tower := Tower.new()
	tower.name = "Tower_%s" % _placing_id
	towers_node.add_child(tower)
	tower.global_position  = pos
	tower.enemies_node     = enemies_node
	tower.projectiles_node = projs_node
	tower.setup(data, float(grid_map.tile_size))
	grid_map.place_tower(cell.x, cell.y, tower)
	Sfx.play("place")
	ShakeCamera.add_trauma(0.12)
	Fx.text(pos + Vector2(0, -26), "-%d" % cost, COL_GOLD, 15, 0.7)
	if not GameState.can_afford(cost):
		_cancel_placing()

func _feedback(pos: Vector2, msg: String) -> void:
	Fx.text(pos + Vector2(0, -20), msg, COL_BAD, 16, 1.0)
	Sfx.play("error", 0.0)

## Names the exact amount missing, so the player knows how long to wait.
func _feedback_gold(pos: Vector2, cost: int) -> void:
	_feedback(pos, StringManager.t("no_gold", {missing = cost - GameState.gold}))

func _cancel_placing() -> void:
	_placing_id = ""
	preview.set_placing({})
	hud.set_selected_type("")
	hud.show_hint("")

# ---------------------------------------------------------------------------
# Selection, upgrade, sell, targeting
# ---------------------------------------------------------------------------

func _select_tower(tower: Tower, cell: Vector2i) -> void:
	_cancel_placing()
	if tower == _selected:
		return
	_deselect()
	_selected = tower
	_selected_cell = cell
	tower.set_selected(true)
	preview.set_selected(tower)
	hud.show_tower_panel(tower)
	Sfx.play("click", 0.0)

func _deselect() -> void:
	if is_instance_valid(_selected):
		_selected.set_selected(false)
	_selected = null
	_selected_cell = Vector2i(-1, -1)
	preview.set_selected(null)
	hud.hide_tower_panel()

func _cancel_all() -> void:
	_cancel_placing()
	_deselect()

func _upgrade_selected() -> void:
	if not is_instance_valid(_selected) or not GameState.is_playing():
		return
	var cost: int = _selected.next_upgrade_cost()
	if cost < 0:
		return
	var pos: Vector2 = _selected.global_position
	if not GameState.spend_gold(cost):
		_feedback_gold(pos, cost)
		return
	_selected.upgrade()
	Sfx.play("upgrade", 0.0)
	ShakeCamera.add_trauma(0.1)
	Fx.text(pos + Vector2(0, -30), StringManager.t("level_label", {value = _selected.level}), COL_GOLD, 16, 0.9)
	hud.refresh_tower_panel()

func _sell_selected() -> void:
	if not is_instance_valid(_selected) or not GameState.is_playing():
		return
	var tower: Tower = _selected
	var value: int = tower.sell_value()
	var pos: Vector2 = tower.global_position
	_deselect()
	grid_map.remove_tower(_cell_of(tower).x, _cell_of(tower).y)
	GameState.add_gold(value)
	Fx.burst(pos, COL_GOLD, 16, 160.0, 3.5, 0.7, 420.0)
	Fx.text(pos + Vector2(0, -26), "+%d" % value, COL_GOLD, 17, 0.9)
	Sfx.play("sell", 0.0)
	tower.free()   # immediate: the tile is free right now, no phantom tower

func _cell_of(tower: Tower) -> Vector2i:
	return grid_map.world_to_grid(grid_map.to_local(tower.global_position))

func _cycle_target() -> void:
	if not is_instance_valid(_selected):
		return
	_selected.cycle_target()
	Fx.text(_selected.global_position + Vector2(0, -30), StringManager.t(_selected.target_key()), Color.WHITE, 14, 0.7)
	Sfx.play("click", 0.0)
	hud.refresh_tower_panel()

# ---------------------------------------------------------------------------
# Wave, speed, pause
# ---------------------------------------------------------------------------

func _call_wave() -> void:
	if GameState.phase == GameState.Phase.BUILD and not get_tree().paused:
		GameState.call_wave()

func _toggle_speed() -> void:
	_speed = 2.0 if _speed < 1.5 else 1.0
	if GameState.is_playing():
		Engine.time_scale = _speed
	hud.set_speed(_speed)

func _toggle_pause() -> void:
	if not GameState.is_playing():
		return
	var paused: bool = not get_tree().paused
	get_tree().paused = paused
	hud.set_paused(paused)

# ---------------------------------------------------------------------------
# Map / wave setup
# ---------------------------------------------------------------------------

func _load_maps() -> void:
	var file_path: String = "res://data/maps.json"
	if not FileAccess.file_exists(file_path):
		push_error("Main: maps.json not found")
		return
	var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("Main: maps.json parse error")
		return
	_maps = j.get_data() as Array

func _build_map(index: int) -> void:
	if _maps.is_empty():
		push_error("Main: no maps loaded")
		return
	var map_data: Dictionary = _maps[clampi(index, 0, _maps.size() - 1)] as Dictionary
	grid_map.setup(map_data)

	# Clear previous entities (free, not queue_free: no ghosts next frame)
	for c in enemies_node.get_children():
		c.free()
	for c in towers_node.get_children():
		c.free()
	for c in projs_node.get_children():
		c.free()

	world.position = _compute_map_origin()
	var tile: float = float(grid_map.tile_size)
	var path: Array[Vector2] = []
	for wp in grid_map.waypoints:
		path.append(grid_map.to_global(wp))
	markers.setup(grid_map.waypoints, tile)
	preview.grid = grid_map
	preview.set_hover(Vector2i(-1, -1))
	preview.set_placing({})
	preview.set_selected(null)
	_hover_cell = Vector2i(-1, -1)

	if _wave_manager != null:
		_wave_manager.free()
	_wave_manager = WaveManager.new()
	_wave_manager.name = "WaveManager"
	_wave_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	_wave_manager.enemies_node = enemies_node
	_wave_manager.path = path
	_wave_manager.tile = tile
	add_child(_wave_manager)

	hud.bind_wave_manager(_wave_manager)
	hud.set_map_rect(Rect2(world.position, grid_map.map_size()))

## Centers the map in the screen area not covered by the top bar / side panel.
func _compute_map_origin() -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	var area := Rect2(
		GameHUD.MARGIN,
		GameHUD.TOP_BAR_H + GameHUD.MARGIN,
		vp.x - GameHUD.SIDE_W - GameHUD.MARGIN * 3.0,
		vp.y - GameHUD.TOP_BAR_H - GameHUD.MARGIN * 2.0)
	return (area.position + (area.size - grid_map.map_size()) * 0.5).floor()

func _restart() -> void:
	_end_seq += 1
	get_tree().paused = false
	hud.set_paused(false)
	hud.hide_end()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	Engine.time_scale = _speed
	_cancel_all()
	Fx.clear_all()
	ShakeCamera.reset()
	GameState.new_game()
	_build_map(0)
	hud.reset_counters()
	Sfx.play("click", 0.0)

# ---------------------------------------------------------------------------
# End sequences
# ---------------------------------------------------------------------------

func _on_game_over() -> void:
	_cancel_all()
	_end_seq += 1
	var seq: int = _end_seq
	Sfx.play("defeat", 0.0)
	ShakeCamera.add_trauma(0.8)
	hud.flash_damage(1.0)
	Engine.time_scale = 0.25   # slow motion: the player sees the breach
	await get_tree().create_timer(1.4, true, false, true).timeout
	if seq != _end_seq:
		return
	Engine.time_scale = _speed
	world.process_mode = Node.PROCESS_MODE_DISABLED   # freeze frame behind the menu
	hud.show_end(false)

func _on_game_won() -> void:
	_cancel_all()
	_end_seq += 1
	var seq: int = _end_seq
	Sfx.play("victory", 0.0)
	var size: Vector2 = grid_map.map_size()
	var colors: Array[Color] = [Color("ffd34d"), Color("6cc6ff"), Color("ff5d6c"), Color("7ee08a"), Color("c7a8ff")]
	for i in 7:
		var p: Vector2 = world.position + Vector2(randf_range(0.15, 0.85) * size.x, randf_range(0.2, 0.7) * size.y)
		Fx.burst(p, colors[i % colors.size()], 28, 280.0, 4.0, 1.3, 260.0)
		Fx.ring(p, colors[i % colors.size()], 70.0, 0.6, 3.0)
	await get_tree().create_timer(1.3, true, false, true).timeout
	if seq != _end_seq:
		return
	hud.show_end(true)

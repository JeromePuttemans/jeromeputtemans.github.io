# =============================================================================
# Main.gd: root scene script.
# =============================================================================
# Responsibilities:
#   - start a run, restart after death or victory
#   - route keyboard input to GameState (move, wait, use, drop, descend)
#   - drive the camera (follow the player's animated position)
#   - send the hovered tile to the view (outline) and the HUD (Look box)
#   - end-of-run sequences (sound, shake, confetti, then the end screen)
#
# KEYBOARD LAYOUTS:
#   Letter keys are read by PHYSICAL position (physical_keycode): the WASD
#   block is ZQSD on an AZERTY keyboard, without any setting. The controls
#   hint asks the OS which letters sit at those positions, so it prints
#   "ZQSD" or "WASD" to match the player's keyboard. Arrows, numpad, Space,
#   Enter and digits work everywhere. Digits are physical too: 1-6 use an
#   item on AZERTY without Shift; Shift + digit drops it.
# =============================================================================

extends Node

@onready var view:   DungeonView = $World/DungeonView
@onready var camera: GameCamera  = $Camera
@onready var hud:    GameHUD     = $UI/HUD

const PHYSICAL_MOVES: Dictionary = {
	KEY_W: Vector2i(0, -1), KEY_S: Vector2i(0, 1), KEY_A: Vector2i(-1, 0), KEY_D: Vector2i(1, 0),
	KEY_Q: Vector2i(-1, -1), KEY_E: Vector2i(1, -1), KEY_Z: Vector2i(-1, 1), KEY_C: Vector2i(1, 1),
	KEY_PERIOD: Vector2i.ZERO}
const KEYCODE_MOVES: Dictionary = {
	KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0),
	KEY_KP_8: Vector2i(0, -1), KEY_KP_2: Vector2i(0, 1), KEY_KP_4: Vector2i(-1, 0), KEY_KP_6: Vector2i(1, 0),
	KEY_KP_7: Vector2i(-1, -1), KEY_KP_9: Vector2i(1, -1), KEY_KP_1: Vector2i(-1, 1), KEY_KP_3: Vector2i(1, 1),
	KEY_HOME: Vector2i(-1, -1), KEY_PAGEUP: Vector2i(1, -1), KEY_END: Vector2i(-1, 1), KEY_PAGEDOWN: Vector2i(1, 1),
	KEY_KP_5: Vector2i.ZERO, KEY_SPACE: Vector2i.ZERO}

var _end_seq: int = 0   # invalidates a pending end sequence on restart

func _ready() -> void:
	GameState.player_died.connect(_on_game_over)
	GameState.player_won.connect(_on_victory)
	GameState.dungeon_ready.connect(_on_dungeon_ready)
	hud.item_use_requested.connect(_on_use_requested)
	hud.item_drop_requested.connect(_on_drop_requested)
	hud.restart_requested.connect(_restart)
	camera.area = hud.map_area()
	hud.set_controls_keys(_movement_key_labels())
	GameState.new_game()

func _on_dungeon_ready() -> void:
	var ts: float = view.tile_size()
	camera.map_size = Vector2(GameState.dungeon.width, GameState.dungeon.height) * ts
	camera.snap(view.tile_center(GameState.player.grid_pos))

func _process(_delta: float) -> void:
	if GameState.player == null:
		return
	camera.follow(view.player_draw_pos())
	_update_hover()

func _update_hover() -> void:
	var tile := Vector2i(-1, -1)
	if hud.map_area().has_point(get_viewport().get_mouse_position()) and not hud.end_overlay.visible:
		var local: Vector2 = view.get_local_mouse_position()
		var ts: float = view.tile_size()
		tile = Vector2i(floori(local.x / ts), floori(local.y / ts))
	view.hover_tile = tile
	hud.set_look(tile)

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_M and not key.echo:
		Sfx.toggle_mute()
		return
	if GameState.phase == GameState.Phase.GAME_OVER or GameState.phase == GameState.Phase.VICTORY:
		if key.keycode == KEY_R and not key.echo:
			_restart()
		return
	if not key.echo and key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_9:
		var slot: int = key.physical_keycode - KEY_1
		if key.shift_pressed:
			GameState.drop_item(slot)
		else:
			GameState.use_item(slot)
		get_viewport().set_input_as_handled()
		return
	if (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER) and not key.echo:
		GameState.descend()
		get_viewport().set_input_as_handled()
		return
	# Held keys repeat (echo): walking or resting by holding a key is allowed
	if KEYCODE_MOVES.has(key.keycode):
		GameState.player_action(KEYCODE_MOVES[key.keycode] as Vector2i)
		get_viewport().set_input_as_handled()
	elif PHYSICAL_MOVES.has(key.physical_keycode):
		GameState.player_action(PHYSICAL_MOVES[key.physical_keycode] as Vector2i)
		get_viewport().set_input_as_handled()

func _on_use_requested(slot: int) -> void:
	GameState.use_item(slot)

func _on_drop_requested(slot: int) -> void:
	GameState.drop_item(slot)

## Letters printed on the player's keyboard at the WASD / QEZC positions.
## Desktop display servers can map a physical key to the layout's letter.
## Others (Web, headless) cannot: the browser language is used as a hint,
## French meaning AZERTY.
func _movement_key_labels() -> String:
	if not DisplayServer.get_name() in ["Windows", "macOS", "X11", "Wayland"]:
		return "ZQSD + AEWC" if OS.get_locale_language() == "fr" else "WASD + QEZC"
	var cardinals: String = ""
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		cardinals += _key_label(k)
	var diagonals: String = ""
	for k in [KEY_Q, KEY_E, KEY_Z, KEY_C]:
		diagonals += _key_label(k)
	return "%s + %s" % [cardinals, diagonals]

func _key_label(physical: Key) -> String:
	var keycode: Key = DisplayServer.keyboard_get_keycode_from_physical(physical)
	var label: String = OS.get_keycode_string(keycode)
	return label if label.length() == 1 else OS.get_keycode_string(physical)

# ---------------------------------------------------------------------------
# End of run
# ---------------------------------------------------------------------------

func _on_game_over() -> void:
	_end_seq += 1
	var seq: int = _end_seq
	Sfx.play("death", 0.0)
	GameCamera.add_trauma(0.7)
	hud.flash_damage(1.0)
	await get_tree().create_timer(1.2).timeout
	if seq != _end_seq:
		return
	hud.show_end(false)

func _on_victory() -> void:
	_end_seq += 1
	var seq: int = _end_seq
	Sfx.play("victory", 0.0)
	var at: Vector2 = view.player_draw_pos()
	var colors: Array[Color] = [Color("ffd34d"), Color("7fe3ff"), Color("ff6b8f"), Color("7ee08a"), Color("c7a8ff")]
	for i in 6:
		var p: Vector2 = at + Vector2(randf_range(-180, 180), randf_range(-120, 80))
		Fx.burst(p, colors[i % colors.size()], 26, 240.0, 3.5, 1.3, 240.0)
		Fx.ring(p, colors[i % colors.size()], 60.0, 0.6, 3.0)
	await get_tree().create_timer(1.2).timeout
	if seq != _end_seq:
		return
	hud.show_end(true)

func _restart() -> void:
	_end_seq += 1
	hud.hide_end()
	GameState.new_game()
	Sfx.play("click", 0.0)

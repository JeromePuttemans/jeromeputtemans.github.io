class_name PlayerPawn
extends Node3D

# Player: input, grid movement, room effects, bomb.
#
# KEYS are read by PHYSICAL position (layout independent, see Keyboard):
#   WASD block (ZQSD on AZERTY): front / left / back / right
#   E: up, Q (A on AZERTY): down. Arrows and Page Up / Page Down also work.
#   Space: bomb. A key event without a physical position (some virtual
#   keyboards) is matched by its character, with the layout in use.
# Front / back / left / right are CAMERA-RELATIVE: "front" is the horizontal
# world axis closest to where the camera looks. The camera can orbit, so the
# view yaw is rounded to a quarter turn and the key direction is rotated by
# that many quarter turns (to_world). Up / down never change.
# One move = one room = move_cost energy. Entering an empty cell creates the
# room (GridManager.enter), then its effect applies:
#   energy crystal  +resource_energy energy
#   trap            -trap_damage energy
#   core            collected: the goal becomes the teleporter
#   teleporter      with the core: level complete, upgrade choice
# After each move: 0 energy ends the run, and so does being walled in (no
# open side) without enough energy for a bomb.

signal moved(cell: Vector3i)
signal bumped(dir: Vector3i)
signal bombed(cell: Vector3i)

const MOVE_TIME: float = 0.13

const KEYCODE_KEYS: Dictionary = {
	KEY_UP: Vector3i(0, 0, -1), KEY_DOWN: Vector3i(0, 0, 1),
	KEY_LEFT: Vector3i(-1, 0, 0), KEY_RIGHT: Vector3i(1, 0, 0),
	KEY_PAGEUP: Vector3i(0, 1, 0), KEY_PAGEDOWN: Vector3i(0, -1, 0)}

@export var grid_path: NodePath = ^"../GridManager"

var cell: Vector3i = Vector3i.ZERO
var moving: bool = false
var view_yaw: float = 0.0   # camera yaw in radians, set by Main every frame
var _grid: GridManager = null
var _orb: MeshInstance3D = null
var _time: float = 0.0

func _ready() -> void:
	_grid = get_node(grid_path) as GridManager
	_orb = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	_orb.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.95, 1.0)
	mat.emission_energy_multiplier = 2.0
	_orb.material_override = mat
	add_child(_orb)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.95, 1.0)
	light.light_energy = 1.4
	light.omni_range = 4.0
	add_child(light)

func reset_to(p: Vector3i) -> void:
	cell = p
	position = Vector3(p)
	moving = false

func _process(delta: float) -> void:
	_time += delta
	_orb.position.y = sin(_time * 3.0) * 0.05

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or not GameManager.can_act() or moving:
		return
	if key.keycode == KEY_SPACE and not key.echo:
		use_bomb()
	elif KEYCODE_KEYS.has(key.keycode):
		try_move(to_world(KEYCODE_KEYS[key.keycode] as Vector3i))
	elif Keyboard.PHYSICAL_DIRS.has(key.physical_keycode):
		try_move(to_world(Keyboard.PHYSICAL_DIRS[key.physical_keycode] as Vector3i))
	elif key.physical_keycode == KEY_NONE and Keyboard.dir_from_keycode(key.keycode) != Vector3i.ZERO:
		try_move(to_world(Keyboard.dir_from_keycode(key.keycode)))
	else:
		return
	get_viewport().set_input_as_handled()

## Quarter turns of the camera around the vertical axis, 0 to 3.
func view_quarter() -> int:
	return posmod(int(round(view_yaw / (PI * 0.5))), 4)

## Key direction -> world direction. One quarter turn maps (x, z) to (z, -x):
## with the camera turned 90 degrees, "front" (0, 0, -1) becomes (-1, 0, 0).
func to_world(rel: Vector3i) -> Vector3i:
	var v: Vector3i = rel
	for _i in view_quarter():
		v = Vector3i(v.z, v.y, -v.x)
	return v

## World direction -> key direction (inverse of to_world), for the HUD labels.
func to_relative(world: Vector3i) -> Vector3i:
	var v: Vector3i = world
	for _i in (4 - view_quarter()) % 4:
		v = Vector3i(v.z, v.y, -v.x)
	return v

func try_move(dir: Vector3i) -> void:
	if not _grid.can_move(cell, dir):
		bumped.emit(dir)
		GameManager.say(Strings.t("msg_wall"), "warn")
		Sfx.play("bump", 0.05, -4.0)
		var t := create_tween()
		t.tween_property(self, "position", Vector3(cell) + Vector3(dir) * 0.12, 0.05)
		t.tween_property(self, "position", Vector3(cell), 0.08)
		return
	cell += dir
	if _grid.enter(cell):
		GameManager.rooms_explored += 1
	_grid.update_focus(cell)
	GameManager.spend_energy(int(GameManager.num("move_cost")))
	moving = true
	Sfx.play("step", 0.12, -6.0)
	var tween := create_tween()
	tween.tween_property(self, "position", Vector3(cell), MOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_arrive)

func _arrive() -> void:
	moving = false
	moved.emit(cell)
	match _grid.room_type(cell):
		GridManager.Type.RESOURCE:
			var e: int = int(GameManager.num("resource_energy"))
			GameManager.add_energy(e)
			_grid.set_neutral(cell)
			GameManager.say(Strings.t("msg_resource", {energy = e}), "good")
			Sfx.play("pickup", 0.05)
		GridManager.Type.TRAP:
			var dmg: int = int(GameManager.num("trap_damage"))
			GameManager.spend_energy(dmg)
			_grid.set_neutral(cell)
			GameManager.say(Strings.t("msg_trap", {value = dmg}), "bad")
			Sfx.play("hurt", 0.05)
		GridManager.Type.CORE:
			if not GameManager.core_collected:
				GameManager.collect_core()
				_grid.set_neutral(cell)   # the core is carried away: its room empties
				GameManager.say(Strings.t("msg_core"), "good")
				Sfx.play("levelup", 0.0)
		GridManager.Type.TELEPORTER:
			if GameManager.core_collected:
				Sfx.play("stairs", 0.0)
				GameManager.complete_level()
				return
	_check_end()

func use_bomb() -> void:
	var cost: int = GameManager.bomb_cost()
	if GameManager.energy < cost:
		GameManager.say(Strings.t("msg_no_bomb", {value = cost}), "warn")
		Sfx.play("error", 0.0)
		return
	GameManager.spend_energy(cost)
	_grid.bomb(cell)
	_grid.update_focus(cell)
	bombed.emit(cell)
	GameManager.say(Strings.t("msg_bomb", {value = cost}), "info")
	Sfx.play("thunder", 0.0)
	_check_end()

func _check_end() -> void:
	if GameManager.energy <= 0:
		GameManager.end_run("over_energy")
	elif _grid.open_dirs(cell).is_empty() and GameManager.energy < GameManager.bomb_cost():
		GameManager.end_run("over_trapped")

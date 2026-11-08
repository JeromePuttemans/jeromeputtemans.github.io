class_name PlayerPawn
extends Node3D

# Player: input, grid movement, room effects, bomb.
#
# KEYS are read by PHYSICAL position (layout independent):
#   WASD block (ZQSD on AZERTY): front / left / back / right
#   E: up, Q (A on AZERTY): down. Arrows and Page Up / Page Down also work.
#   Space: bomb.
# One move = one room = move_cost energy. Entering an empty cell creates the
# room (GridManager.enter), then its effect applies:
#   energy crystal  +resource_energy energy, +resource_fragments fragment
#   trap            -trap_damage energy
#   core            collected: the goal becomes the teleporter
#   teleporter      with the core: level complete
# After each move: 0 energy ends the run, and so does being walled in (no
# open side) without enough energy for a bomb.

signal moved(cell: Vector3i)
signal bumped(dir: Vector3i)
signal bombed(cell: Vector3i)

const MOVE_TIME: float = 0.13

const PHYSICAL_KEYS: Dictionary = {
	KEY_W: Vector3i(0, 0, -1), KEY_S: Vector3i(0, 0, 1),
	KEY_A: Vector3i(-1, 0, 0), KEY_D: Vector3i(1, 0, 0),
	KEY_E: Vector3i(0, 1, 0), KEY_Q: Vector3i(0, -1, 0)}
const KEYCODE_KEYS: Dictionary = {
	KEY_UP: Vector3i(0, 0, -1), KEY_DOWN: Vector3i(0, 0, 1),
	KEY_LEFT: Vector3i(-1, 0, 0), KEY_RIGHT: Vector3i(1, 0, 0),
	KEY_PAGEUP: Vector3i(0, 1, 0), KEY_PAGEDOWN: Vector3i(0, -1, 0)}

@export var grid_path: NodePath = ^"../GridManager"

var cell: Vector3i = Vector3i.ZERO
var moving: bool = false
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
	if key == null or not key.pressed or not GameManager.running or moving:
		return
	if key.keycode == KEY_SPACE and not key.echo:
		use_bomb()
	elif KEYCODE_KEYS.has(key.keycode):
		try_move(KEYCODE_KEYS[key.keycode] as Vector3i)
	elif PHYSICAL_KEYS.has(key.physical_keycode):
		try_move(PHYSICAL_KEYS[key.physical_keycode] as Vector3i)
	else:
		return
	get_viewport().set_input_as_handled()

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
			var f: int = int(GameManager.num("resource_fragments"))
			GameManager.add_energy(e)
			GameManager.add_fragments(f)
			_grid.set_neutral(cell)
			GameManager.say(Strings.t("msg_resource", {energy = e, frag = f}), "good")
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
	bombed.emit(cell)
	GameManager.say(Strings.t("msg_bomb", {value = cost}), "info")
	Sfx.play("thunder", 0.0)
	_check_end()

func _check_end() -> void:
	if GameManager.energy <= 0:
		GameManager.end_run("over_energy")
	elif _grid.open_dirs(cell).is_empty() and GameManager.energy < GameManager.bomb_cost():
		GameManager.end_run("over_trapped")

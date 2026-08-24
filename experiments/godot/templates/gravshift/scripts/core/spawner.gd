extends Node

class_name Spawner

# ── Signals ───────────────────────────────────────────────────────────────────
signal wave_cleared
signal enemy_destroyed

# ── Constants ─────────────────────────────────────────────────────────────────
const SPAWN_MARGIN_X: float = 60.0
const SPAWN_Y_OFFSET: float = -40.0
const WAVE_DENSITY_MULTIPLIER: float = 1.3

# ── State ─────────────────────────────────────────────────────────────────────
var _enemies_alive: int = 0
var _enemies_container: Node2D = null
var _game_manager: Node = null
var _enemy_linear_script: Script = null
var _enemy_wave_script: Script = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_game_manager = get_node_or_null("/root/Main")
	if is_instance_valid(_game_manager):
		_enemies_container = _game_manager.get_enemies_container()
	_enemy_linear_script = load("res://scripts/entities/enemy_linear.gd") as Script
	_enemy_wave_script = load("res://scripts/entities/enemy_wave.gd") as Script

# ── Public API ────────────────────────────────────────────────────────────────
func reset() -> void:
	_enemies_alive = 0
	# Clear any remaining enemies from previous run
	if is_instance_valid(_enemies_container):
		for child_v in _enemies_container.get_children():
			var child: Node = child_v as Node
			if is_instance_valid(child):
				child.queue_free()

func spawn_wave(wave_number: int) -> void:
	if not is_instance_valid(_enemies_container):
		_enemies_container = _game_manager.get_enemies_container()

	var base_count: int = _game_manager.get_setting("enemies_per_wave", 6) as int
	# Increase enemy count slightly each wave
	var count: int = base_count + (wave_number - 1) * 2
	_enemies_alive = count

	var viewport_width: float = 1152.0
	# Try to get actual viewport size
	var vp: Viewport = get_viewport()
	if is_instance_valid(vp):
		viewport_width = vp.get_visible_rect().size.x

	for i in range(count):
		var enemy: CharacterBody2D = CharacterBody2D.new()
		# Alternate types: linear for even index, wave for odd
		if i % 2 == 0:
			enemy.set_script(_enemy_linear_script)
		else:
			enemy.set_script(_enemy_wave_script)

		var spawn_x: float = SPAWN_MARGIN_X + (float(i) / float(count - 1 if count > 1 else 1)) * (viewport_width - SPAWN_MARGIN_X * 2.0)
		var spawn_y: float = SPAWN_Y_OFFSET - float(i) * 30.0
		enemy.position = Vector2(spawn_x, spawn_y)

		# Connect destruction signal before add_child so it fires correctly
		_enemies_container.add_child(enemy)
		enemy.enemy_destroyed.connect(_on_enemy_died)

func _on_enemy_died() -> void:
	_enemies_alive -= 1
	enemy_destroyed.emit()
	if _enemies_alive <= 0:
		wave_cleared.emit()

# =============================================================================
# WaveManager.gd — Node: loads waves.json, spawns enemies on demand.
# =============================================================================
# SPAWN ALGORITHM:
#   waves.json lists each wave as an array of {type, count} blocks.
#   WaveManager flattens these into a _spawn_queue: Array[String] of type IDs.
#   A Timer fires every `spawn_interval` seconds and pops one entry from the
#   queue, creating one Enemy node. This keeps the main thread free between
#   spawns.
#
#   _alive_count tracks how many enemies are currently alive (incremented on
#   spawn, decremented on died/reached_exit). When _alive_count reaches 0 AND
#   _spawn_queue is empty, the wave is complete → GameState.wave_cleared().
#
# The node is added as a child of the Enemies container by Main.gd.
# =============================================================================

class_name WaveManager
extends Node

var _waves:       Array   = []   # raw data from waves.json
var _spawn_queue: Array   = []   # Array[String] type IDs to spawn
var _alive_count: int     = 0
var _spawning:    bool    = false
var _spawn_timer: float   = 0.0
var _interval:    float   = 0.0

# Set by Main.gd before use
var enemies_node: Node2D  = null
var waypoints:    Array   = []

func _ready() -> void:
	_load_waves()
	_interval = ConfigManager.get_float("spawn_interval", 0.0)
	GameState.wave_started.connect(_on_wave_started)

func _load_waves() -> void:
	var path = "res://data/waves.json"
	if not FileAccess.file_exists(path):
		push_error("WaveManager: not found — " + path)
		return
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("WaveManager: parse error at line %d" % j.get_error_line())
		return
	_waves = j.get_data()
	GameState.total_waves = _waves.size()

func _process(delta: float) -> void:
	if not _spawning or _spawn_queue.is_empty():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _interval
		_spawn_next()

func _on_wave_started(wave_index: int) -> void:
	if wave_index >= _waves.size():
		return
	var wave_data = _waves[wave_index]
	_spawn_queue = []
	for block in wave_data.get("spawns", []):
		var type_id: String = block.get("type", "basic")
		var count:   int    = block.get("count", 1)
		for _i in count:
			_spawn_queue.append(type_id)
	_alive_count = 0
	_spawn_timer = 0.0   # spawn first enemy immediately
	_spawning    = true

func _spawn_next() -> void:
	if _spawn_queue.is_empty():
		_spawning = false
		# Do not call wave_cleared here — wait until all alive enemies die
		return
	var type_id  = _spawn_queue.pop_front()
	var data     = EnemyDatabase.get_type(type_id)
	if data.is_empty():
		push_warning("WaveManager: unknown enemy type '%s'" % type_id)
		_check_wave_complete()
		return

	var enemy = Enemy.new()
	enemies_node.add_child(enemy)
	enemy.setup(data, waypoints)
	_alive_count += 1

	# If this was the last item, stop the spawn loop now.
	# _check_wave_complete relies on _spawning == false to confirm the
	# wave is done, so we must clear the flag here, not on the next tick.
	if _spawn_queue.is_empty():
		_spawning = false

	# Connect cleanup signals
	enemy.died.connect(_on_enemy_removed)
	enemy.reached_exit.connect(_on_enemy_removed)

func _on_enemy_removed() -> void:
	_alive_count -= 1
	_check_wave_complete()

func _check_wave_complete() -> void:
	if _alive_count <= 0 and _spawn_queue.is_empty() and not _spawning:
		GameState.wave_cleared()

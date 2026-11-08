# =============================================================================
# WaveManager.gd (Node): loads waves.json, spawns enemies, detects wave end.
# =============================================================================
# SPAWN ALGORITHM:
#   waves.json lists each wave as blocks {type, count, interval?, delay?}.
#   On wave start they are flattened into _queue: an array of
#   {type, wait} entries, where `wait` is the time to wait BEFORE spawning
#   that entry:
#     first entry of block 0     : delay
#     first entry of block k > 0 : previous block interval + delay
#     other entries              : interval
#   A single float timer consumes the queue: no Timer node, and a `while`
#   loop spawns several entries in one frame if delta is large (game x2).
#
# HP SCALING:
#   hp x (1 + hp_scale_per_wave x wave_index): the same three enemy types stay
#   relevant for ten waves without inflating enemies.json.
#
# COMPLETION:
#   _alive_count goes up on spawn and down on died / reached_exit. When it is
#   0 AND the queue is empty AND spawning is over -> GameState.on_wave_completed().
#   _spawning is cleared the moment the last entry is spawned (not on the next
#   tick), otherwise the completion check could never succeed.
# =============================================================================

class_name WaveManager
extends Node

var _waves:        Array = []
var _queue:        Array[Dictionary] = []
var _alive_count:  int   = 0
var _spawning:     bool  = false
var _spawn_timer:  float = 0.0
var _hp_mult:      float = 1.0
var _wave_total:   int   = 0

# Set by Main before add_child()
var enemies_node: Node2D = null
var path:         Array[Vector2] = []   # global waypoints
var tile:         float = 0.0

func _ready() -> void:
	_load_waves()
	GameState.wave_started.connect(_on_wave_started)

func _load_waves() -> void:
	var file_path: String = "res://data/waves.json"
	if not FileAccess.file_exists(file_path):
		push_error("WaveManager: file not found: " + file_path)
		return
	var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("WaveManager: parse error at line %d" % j.get_error_line())
		return
	_waves = j.get_data() as Array
	GameState.total_waves = _waves.size()

## Aggregated composition of a wave, for the HUD preview: [{type, count}].
func get_composition(wave_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if wave_index < 0 or wave_index >= _waves.size():
		return result
	var wave: Dictionary = _waves[wave_index] as Dictionary
	for block_v in wave.get("spawns", []) as Array:
		var block: Dictionary = block_v as Dictionary
		var type_id: String = str(block.get("type", ""))
		var found: bool = false
		for entry in result:
			if entry["type"] == type_id:
				entry["count"] = int(entry["count"]) + int(block.get("count", 1))
				found = true
		if not found:
			result.append({type = type_id, count = int(block.get("count", 1))})
	return result

func hp_multiplier(wave_index: int) -> float:
	return 1.0 + ConfigManager.get_float("hp_scale_per_wave", 0.0) * wave_index

## Enemies still to deal with in the current wave (alive + not yet spawned).
func remaining() -> int:
	return _alive_count + _queue.size()

func wave_total() -> int:
	return _wave_total

func _process(delta: float) -> void:
	GameState.tick_countdown(delta)
	if not _spawning:
		return
	if GameState.phase != GameState.Phase.WAVE:
		_spawning = false
		return
	_spawn_timer -= delta
	while _spawning and _spawn_timer <= 0.0:
		_spawn_next()

func _on_wave_started(wave_index: int) -> void:
	if wave_index >= _waves.size():
		return
	var default_interval: float = ConfigManager.get_float("spawn_interval", 0.0)
	var wave: Dictionary = _waves[wave_index] as Dictionary
	_queue.clear()
	var prev_interval: float = 0.0
	for block_v in wave.get("spawns", []) as Array:
		var block: Dictionary = block_v as Dictionary
		var interval: float = float(block.get("interval", default_interval))
		var delay: float = float(block.get("delay", 0.0))
		for i in int(block.get("count", 1)):
			var wait: float = interval
			if i == 0:
				wait = prev_interval + delay
			_queue.append({type = str(block.get("type", "")), wait = wait})
		prev_interval = interval
	_hp_mult     = hp_multiplier(wave_index)
	_wave_total  = _queue.size()
	_alive_count = 0
	_spawning    = not _queue.is_empty()
	_spawn_timer = float(_queue[0]["wait"]) if _spawning else 0.0
	Sfx.play("wave", 0.0)
	_check_wave_complete()   # an empty wave completes immediately

func _spawn_next() -> void:
	var entry: Dictionary = _queue.pop_front()
	var type_id: String = str(entry["type"])
	var data: Dictionary = EnemyDatabase.get_type(type_id)
	if data.is_empty():
		push_warning("WaveManager: unknown enemy type '%s'" % type_id)
	else:
		var enemy := Enemy.new()
		enemies_node.add_child(enemy)
		enemy.setup(data, path, _hp_mult, tile)
		enemy.died.connect(_on_enemy_removed)
		enemy.reached_exit.connect(_on_enemy_removed)
		_alive_count += 1

	if _queue.is_empty():
		_spawning = false   # last entry spawned: clear the flag NOW
		_check_wave_complete()
	else:
		_spawn_timer += float(_queue[0]["wait"])

func _on_enemy_removed() -> void:
	_alive_count -= 1
	_check_wave_complete()

func _check_wave_complete() -> void:
	if _alive_count <= 0 and _queue.is_empty() and not _spawning:
		GameState.on_wave_completed()

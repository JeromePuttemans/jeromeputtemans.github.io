# =============================================================================
# WaveManager.gd — Node: spawns enemy formations from waves.json.
# =============================================================================
# SPAWN ALGORITHM:
#   Each wave contains formations. Formations are queued and spawned with
#   a stagger delay between them. Within a formation, enemies are positioned
#   according to their pattern (line_h = horizontal line, v_shape = V).
#
#   After all enemies in a wave are dead (tracked via _alive_count), a
#   wave_clear callback fires. If it was the last wave, game_won fires.
#
#   _alive_count is incremented at spawn and decremented on each enemy's
#   died signal. When it reaches 0 and the spawn queue is empty, wave ends.
# =============================================================================
class_name WaveManager
extends Node

signal spawn_enemy(enemy: ShmupEnemy)
signal wave_complete(wave_num: int)

var _waves:        Array   = []
var _spawn_queue:  Array   = []   # Array[Dictionary] — pre-built spawn jobs
var _alive_count:  int     = 0
var _spawn_timer:  float   = 0.0
var _interval:     float   = 0.0
var _active:       bool    = false

# Set by Main before use
var player_ref:    Node2D  = null
var play_w:        float   = 0.0

func _ready() -> void:
	_interval = ConfigManager.get_float("spawn_interval", 0.0)
	_load_waves()

func _load_waves() -> void:
	var path = "res://data/waves.json"
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: push_error("WaveManager: " + path); return
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("WaveManager: parse error"); return
	_waves = j.get_data()
	GameState.total_waves = _waves.size()

func start_wave(wave_index: int) -> void:
	if wave_index >= _waves.size():
		return
	var wdata = _waves[wave_index]
	_spawn_queue = []
	_alive_count = 0

	for formation in wdata.get("formations", []):
		var type_id    = formation.get("type",    "basic")
		var count      = formation.get("count",   1)
		var pattern    = formation.get("pattern", "line_h")
		var x_spread   = float(formation.get("x_spread", 0.5))

		var positions  = _build_formation(count, pattern, x_spread)
		# Stagger within formation: each enemy added slightly after the previous
		for idx in count:
			_spawn_queue.append({
				type_id  = type_id,
				position = positions[idx],
				delay    = idx * 0.18 + _spawn_queue.size() * 0.05
			})

	# Sort by delay so timer works simply
	_spawn_queue.sort_custom(func(a, b): return a.delay < b.delay)
	_spawn_timer = 0.0
	_active      = true

func _build_formation(count: int, pattern: String, x_spread: float) -> Array:
	var positions: Array = []
	var entry_y   = -30.0

	match pattern:
		"line_h":
			var start_x = play_w * (0.5 - x_spread * 0.5)
			var step    = (play_w * x_spread) / max(count - 1, 1)
			for i in count:
				positions.append(Vector2(start_x + step * i, entry_y))
		"v_shape":
			var cx = play_w * 0.5
			var half = count / 2
			for i in count:
				var offset = (i - float(count - 1) * 0.5) * (play_w * x_spread / max(count, 1))
				var vy     = entry_y - abs(offset) * 0.5
				positions.append(Vector2(cx + offset, vy))
		_:
			# Fallback: single column
			for i in count:
				positions.append(Vector2(play_w * 0.5, entry_y - i * 40.0))

	return positions

func _process(delta: float) -> void:
	if not _active or _spawn_queue.is_empty():
		return
	_spawn_timer += delta
	while not _spawn_queue.is_empty() and _spawn_queue[0].delay <= _spawn_timer:
		var job  = _spawn_queue.pop_front()
		_do_spawn(job)

func _do_spawn(job: Dictionary) -> void:
	var data = EnemyDatabase.get_type(job.type_id)
	if data.is_empty():
		push_warning("WaveManager: unknown type '%s'" % job.type_id)
		_check_complete()
		return

	var enemy = ShmupEnemy.new()
	enemy.player_ref = player_ref
	enemy.setup(data)
	enemy.position   = job.position
	enemy.died.connect(_on_enemy_died)
	_alive_count += 1

	# If this was the last queued item, clear _active so _process stops looping
	if _spawn_queue.is_empty():
		_active = false

	emit_signal("spawn_enemy", enemy)

func _on_enemy_died(_enemy: ShmupEnemy) -> void:
	_alive_count -= 1
	_check_complete()

func _check_complete() -> void:
	if _alive_count <= 0 and _spawn_queue.is_empty() and not _active:
		emit_signal("wave_complete", GameState.wave)

## True while enemies are alive or still spawning.
func is_busy() -> bool:
	return _alive_count > 0 or _active or not _spawn_queue.is_empty()

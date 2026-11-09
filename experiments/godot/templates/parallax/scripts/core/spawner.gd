extends Node

# Spawner: waves of enemies, enemy orbs and repair pickups.
#
# WAVES (settings.json, gameplay.waves): each entry has a pattern, an enemy
#   kind, a size (count), the first sector where it may appear (min_sector),
#   a weight for the random draw and a cost. When the timer runs out, one
#   wave is drawn among the allowed ones (weighted), then the next wave comes
#   after spawn_interval x cost seconds: big waves leave more time.
# PATTERNS: single (random height), line (one behind the other), column (one
#   above the other), pair (two heights), vee (V formation).
# DIFFICULTY: spawn_interval = enemy_spawn_interval - per_sector x (sector - 1),
#   never below enemy_spawn_interval_min; new kinds unlock with the sectors.
# The first wave of a run is a single slow drifter in the middle of the
#   screen, so the player can try shooting before anything dangerous comes.

const SCRIPTS: Dictionary = {
	"straight": "res://scripts/entities/enemy_straight.gd",
	"sine": "res://scripts/entities/enemy_sine.gd",
	"charger": "res://scripts/entities/enemy_charger.gd",
	"gunner": "res://scripts/entities/enemy_gunner.gd",
	"tank": "res://scripts/entities/enemy_tank.gd"}
const SHOT_SCRIPT: String = "res://scripts/entities/enemy_shot.gd"
const PICKUP_SCRIPT: String = "res://scripts/entities/pickup_repair.gd"
const SPAWN_MARGIN: float = 50.0
const EDGE_MARGIN: float = 70.0
const LINE_SPACING: float = 70.0
const COLUMN_SPACING: float = 64.0
const FIRST_ENEMY_SPEED_FACTOR: float = 0.45

var _gameplay: Dictionary = {}
var _containers: Dictionary = {}
var _player: Node2D = null
var _screen: Vector2 = Vector2(1280.0, 720.0)
var _scripts: Dictionary = {}
var _active: bool = false
var _timer: float = 0.0
var _sector: int = 1
var _first_wave: bool = true

func configure(gameplay: Dictionary, containers: Dictionary, player: Node2D, screen: Vector2) -> void:
	_gameplay = gameplay
	_containers = containers
	_player = player
	_screen = screen
	for kind_v in SCRIPTS:
		_scripts[kind_v] = load(SCRIPTS[kind_v] as String)

func start() -> void:
	_active = true
	_sector = 1
	_first_wave = true
	_timer = float(_gameplay.get("first_wave_delay", 1.2))

func stop() -> void:
	_active = false

func clear() -> void:
	for key in ["enemies", "shots", "pickups"]:
		var container: Node2D = _containers[key] as Node2D
		for child_v in container.get_children():
			var child: Node = child_v as Node
			container.remove_child(child)
			child.queue_free()

func set_sector(sector: int) -> void:
	_sector = sector

func spawn_interval() -> float:
	var base: float = float(_gameplay.get("enemy_spawn_interval", 2.0))
	var step: float = float(_gameplay.get("enemy_spawn_interval_per_sector", 0.22))
	return maxf(float(_gameplay.get("enemy_spawn_interval_min", 0.7)), base - step * (_sector - 1))

func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if _first_wave:
		_first_wave = false
		var first: EnemyBase = _spawn_enemy("straight", Vector2(_screen.x + SPAWN_MARGIN, _screen.y * 0.5))
		first.speed *= FIRST_ENEMY_SPEED_FACTOR
		_timer = spawn_interval() * 1.5
		return
	var wave: Dictionary = _draw_wave()
	_spawn_wave(wave)
	_timer = spawn_interval() * float(wave.get("cost", 1.0))

func _draw_wave() -> Dictionary:
	var allowed: Array[Dictionary] = []
	var total: float = 0.0
	for wave_v in _gameplay.get("waves", []) as Array:
		var wave: Dictionary = wave_v as Dictionary
		if int(wave.get("min_sector", 1)) <= _sector:
			allowed.append(wave)
			total += float(wave.get("weight", 1.0))
	var roll: float = randf() * total
	for wave in allowed:
		roll -= float(wave.get("weight", 1.0))
		if roll <= 0.0:
			return wave
	if allowed.is_empty():
		return {"pattern": "single", "kind": "straight"}
	return allowed.back()

func _spawn_wave(wave: Dictionary) -> void:
	var kind: String = wave.get("kind", "straight") as String
	for at in _pattern_positions(wave.get("pattern", "single") as String, int(wave.get("count", 1))):
		_spawn_enemy(kind, at)

func _pattern_positions(pattern: String, count: int) -> Array[Vector2]:
	var x: float = _screen.x + SPAWN_MARGIN
	var low: float = EDGE_MARGIN
	var high: float = _screen.y - EDGE_MARGIN
	var result: Array[Vector2] = []
	match pattern:
		"line":
			var y: float = randf_range(low, high)
			for i in count:
				result.append(Vector2(x + i * LINE_SPACING, y))
		"column":
			var top: float = randf_range(low, maxf(low, high - COLUMN_SPACING * (count - 1)))
			for i in count:
				result.append(Vector2(x, top + i * COLUMN_SPACING))
		"pair":
			var middle: float = randf_range(low + 90.0, high - 90.0)
			result.append(Vector2(x, middle - 90.0))
			result.append(Vector2(x + 30.0, middle + 90.0))
		"vee":
			result = _vee_positions(x, count, low, high)
		_:
			result.append(Vector2(x, randf_range(low, high)))
	return result

func _vee_positions(x: float, count: int, low: float, high: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var center: float = randf_range(low + 120.0, high - 120.0)
	for i in count:
		var rank: int = floori((i + 1) / 2.0)
		var side: float = -1.0 if i % 2 == 1 else 1.0
		result.append(Vector2(x + rank * 55.0, center + side * rank * 55.0))
	return result

func _spawn_enemy(kind: String, at: Vector2) -> EnemyBase:
	var enemy := Node2D.new()
	enemy.position = at
	enemy.set_script(_scripts.get(kind, _scripts["straight"]) as Script)
	var typed: EnemyBase = enemy as EnemyBase
	(_containers["enemies"] as Node2D).add_child(typed)
	var config: Dictionary = (_gameplay.get("enemies", {}) as Dictionary).get(kind, {}) as Dictionary
	typed.setup(kind, config, _player, _screen, float(_gameplay.get("enemy_shot_speed", 300.0)))
	typed.shot_fired.connect(_on_shot_fired)
	return typed

func _on_shot_fired(origin: Vector2, velocity: Vector2) -> void:
	var shot := Node2D.new()
	shot.position = origin
	shot.set_script(load(SHOT_SCRIPT))
	(_containers["shots"] as Node2D).add_child(shot)
	shot.call("setup", velocity, float(_gameplay.get("enemy_shot_radius", 6.0)), _screen)

func spawn_pickup(at: Vector2, drift_speed: float) -> void:
	var pickup := Node2D.new()
	pickup.position = at
	pickup.set_script(load(PICKUP_SCRIPT))
	(_containers["pickups"] as Node2D).add_child(pickup)
	pickup.call("setup", drift_speed, float(_gameplay.get("pickup_radius", 14.0)))

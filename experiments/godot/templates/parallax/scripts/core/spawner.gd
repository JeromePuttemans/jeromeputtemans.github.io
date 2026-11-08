extends Node
# Spawns enemies by building nodes entirely in GDScript — no .tscn loading.

const SPAWN_MARGIN: float = 60.0

var _spawn_interval: float = 2.0
var _is_active: bool = false
var _spawn_timer: float = 0.0
var _spawn_count: int = 0
var _viewport_size: Vector2 = Vector2(1280.0, 720.0)

func _ready() -> void:
	_load_settings()
	var vp: Viewport = get_viewport()
	if is_instance_valid(vp):
		_viewport_size = vp.get_visible_rect().size

func _load_settings() -> void:
	var file: FileAccess = FileAccess.open("res://datas/settings.json", FileAccess.READ)
	if not file:
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data: Dictionary = json.data as Dictionary
		var gp: Dictionary = data.get("gameplay", {}) as Dictionary
		_spawn_interval = gp.get("enemy_spawn_interval", 2.0) as float
	file.close()

func start_spawning() -> void:
	_is_active = true
	_spawn_count = 0
	_spawn_interval = 2.0
	_spawn_timer = 0.5

func stop_spawning() -> void:
	_is_active = false
	_clear_enemies()

func _process(delta: float) -> void:
	if not _is_active:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_enemy()
		_spawn_timer = _spawn_interval
		_spawn_interval = maxf(0.8, _spawn_interval - 0.05)

func _spawn_enemy() -> void:
	var vp: Viewport = get_viewport()
	if is_instance_valid(vp):
		_viewport_size = vp.get_visible_rect().size

	var use_sine: bool = (_spawn_count > 0) and (_spawn_count % 3 == 2)
	var enemy: CharacterBody2D = _build_enemy_sine() if use_sine else _build_enemy_straight()

	var spawn_x: float = _viewport_size.x + SPAWN_MARGIN
	var spawn_y: float = randf_range(_viewport_size.y * 0.15, _viewport_size.y * 0.85)
	if _spawn_count == 0:
		spawn_y = _viewport_size.y * 0.5
		enemy.set("speed_override", 60.0)

	enemy.position = Vector2(spawn_x, spawn_y)
	var world: Node2D = get_parent() as Node2D
	if is_instance_valid(world):
		world.add_child(enemy)
	_spawn_count += 1

func _build_enemy_straight() -> CharacterBody2D:
	var enemy := CharacterBody2D.new()
	enemy.name = "EnemyStraight"
	enemy.collision_layer = 2
	enemy.collision_mask = 0

	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([Vector2(0, -12), Vector2(12, 0), Vector2(0, 12), Vector2(-12, 0)])
	body.color = Color(1.0, 0.267, 0.333, 1.0)
	enemy.add_child(body)

	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	col.shape = circle
	hitbox.add_child(col)
	enemy.add_child(hitbox)

	enemy.set_script(load("res://scripts/entities/enemy_straight.gd"))
	return enemy

func _build_enemy_sine() -> CharacterBody2D:
	var enemy := CharacterBody2D.new()
	enemy.name = "EnemySine"
	enemy.collision_layer = 2
	enemy.collision_mask = 0

	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([Vector2(0, -12), Vector2(10, 6), Vector2(-10, 6)])
	body.color = Color(1.0, 0.267, 0.333, 1.0)
	enemy.add_child(body)

	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	col.shape = circle
	hitbox.add_child(col)
	enemy.add_child(hitbox)

	enemy.set_script(load("res://scripts/entities/enemy_sine.gd"))
	return enemy

func _clear_enemies() -> void:
	var world: Node2D = get_parent() as Node2D
	if not is_instance_valid(world):
		return
	for child_v in world.get_children():
		var child: Node = child_v as Node
		if is_instance_valid(child) and child.is_in_group("enemies"):
			child.queue_free()

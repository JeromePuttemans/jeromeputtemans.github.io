extends CharacterBody2D
# Enemy — sine wave vertical movement. Built by code in spawner.gd.

var speed_override: float = -1.0
var _speed: float = 100.0
var _amplitude: float = 80.0
var _frequency: float = 1.5
var _origin_y: float = 0.0
var _time: float = 0.0
var _hitbox: Area2D = null

func _ready() -> void:
	add_to_group("enemies")
	if speed_override > 0.0:
		_speed = speed_override
	else:
		_load_settings()
	_origin_y = position.y
	_time = randf() * TAU
	_hitbox = get_node_or_null("Hitbox") as Area2D
	if is_instance_valid(_hitbox):
		_hitbox.add_to_group("enemy_hitboxes")
		_hitbox.area_entered.connect(_on_hitbox_area_entered)

func _load_settings() -> void:
	var file: FileAccess = FileAccess.open("res://datas/settings.json", FileAccess.READ)
	if not file:
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data: Dictionary = json.data as Dictionary
		var gp: Dictionary = data.get("gameplay", {}) as Dictionary
		_speed     = gp.get("enemy_speed_base", 100.0) as float
		_amplitude = gp.get("enemy_sine_amplitude", 80.0) as float
		_frequency = gp.get("enemy_sine_frequency", 1.5) as float
	file.close()

func _physics_process(delta: float) -> void:
	_time += delta
	velocity.x = -_speed
	velocity.y = sin(_time * _frequency * TAU) * _amplitude
	move_and_slide()
	if position.x < -80.0:
		queue_free()

func _on_hitbox_area_entered(_area: Area2D) -> void:
	queue_free()

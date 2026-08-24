extends CharacterBody2D
# Enemy — straight horizontal movement. Built by code in spawner.gd.

var speed_override: float = -1.0
var _speed: float = 120.0
var _viewport_size: Vector2 = Vector2(1280.0, 720.0)
var _hitbox: Area2D = null

func _ready() -> void:
	add_to_group("enemies")
	if speed_override > 0.0:
		_speed = speed_override
	else:
		_load_speed()
	_hitbox = get_node_or_null("Hitbox") as Area2D
	if is_instance_valid(_hitbox):
		_hitbox.add_to_group("enemy_hitboxes")
		_hitbox.area_entered.connect(_on_hitbox_area_entered)
	var vp: Viewport = get_viewport()
	if is_instance_valid(vp):
		_viewport_size = vp.get_visible_rect().size

func _load_speed() -> void:
	var file: FileAccess = FileAccess.open("res://datas/settings.json", FileAccess.READ)
	if not file:
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data: Dictionary = json.data as Dictionary
		var gp: Dictionary = data.get("gameplay", {}) as Dictionary
		_speed = gp.get("enemy_speed_base", 120.0) as float
	file.close()

func _physics_process(_delta: float) -> void:
	velocity = Vector2(-_speed, 0.0)
	move_and_slide()
	if position.x < -80.0:
		queue_free()

func _on_hitbox_area_entered(_area: Area2D) -> void:
	queue_free()

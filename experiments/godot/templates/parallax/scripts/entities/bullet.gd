extends Area2D
# Bullet — built entirely by code in player.gd

var player_ref: CharacterBody2D = null
var bullet_speed: float = 500.0
var _lifetime_timer: Timer = null

func _ready() -> void:
	add_to_group("bullets")
	_lifetime_timer = get_node_or_null("LifeTimer") as Timer
	if is_instance_valid(_lifetime_timer):
		_lifetime_timer.timeout.connect(_on_lifetime_expired)
		_lifetime_timer.start()
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	position.x += bullet_speed * delta

func _on_lifetime_expired() -> void:
	_destroy()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitboxes"):
		_destroy()

func _destroy() -> void:
	if is_instance_valid(player_ref):
		player_ref.register_bullet_destroyed()
	queue_free()

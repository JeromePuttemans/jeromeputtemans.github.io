extends Node

# Combat: every collision of the game, resolved once per physics frame after
# all entities have moved (process_physics_priority set by game_manager.gd).
# Every entity is a circle (position + radius): a hit is a distance check,
# with no physics bodies to configure.
#
#   bullet  x enemy   -> bullet freed (its drag disappears), enemy.hit()
#   ship    x enemy   -> one hull point, the enemy takes contact damage
#   ship    x orb     -> one hull point, orb freed
#   ship    x pickup  -> pickup_collected
# The ship is only tested while alive and not invulnerable.

signal enemy_destroyed(enemy: EnemyBase)
signal enemy_damaged(enemy: EnemyBase, impact: Vector2)
signal player_struck(impact: Vector2)
signal pickup_collected(kind: String, at: Vector2)

var active: bool = false
var _player: Node2D = null
var _bullets: Node2D = null
var _enemies: Node2D = null
var _shots: Node2D = null
var _pickups: Node2D = null
var _bullet_damage: int = 1
var _contact_damage: int = 3

func configure(player: Node2D, containers: Dictionary, gameplay: Dictionary) -> void:
	_player = player
	_bullets = containers["bullets"] as Node2D
	_enemies = containers["enemies"] as Node2D
	_shots = containers["shots"] as Node2D
	_pickups = containers["pickups"] as Node2D
	_bullet_damage = int(gameplay.get("bullet_damage", 1))
	_contact_damage = int(gameplay.get("contact_damage_to_enemy", 3))

func _physics_process(_delta: float) -> void:
	if not active:
		return
	_resolve_bullets()
	if is_instance_valid(_player) and bool(_player.get("alive")):
		_resolve_ship_contacts()
		_resolve_ship_shots()
		_resolve_pickups()

func _resolve_bullets() -> void:
	for bullet_v in _bullets.get_children():
		var bullet: Node2D = bullet_v as Node2D
		if bullet.is_queued_for_deletion():
			continue
		var enemy: EnemyBase = _first_enemy_touching(bullet.position, float(bullet.get("radius")))
		if enemy == null:
			continue
		_bullets.remove_child(bullet)
		bullet.queue_free()
		_damage_enemy(enemy, _bullet_damage, bullet.position)

func _first_enemy_touching(at: Vector2, radius: float) -> EnemyBase:
	for enemy_v in _enemies.get_children():
		var enemy: EnemyBase = enemy_v as EnemyBase
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		var reach: float = radius + enemy.radius
		if at.distance_squared_to(enemy.position) < reach * reach:
			return enemy
	return null

func _damage_enemy(enemy: EnemyBase, damage: int, impact: Vector2) -> void:
	if enemy.hit(damage):
		enemy_destroyed.emit(enemy)
		enemy.queue_free()
	else:
		enemy_damaged.emit(enemy, impact)

func _resolve_ship_contacts() -> void:
	var radius: float = float(_player.get("radius"))
	var enemy: EnemyBase = _first_enemy_touching(_player.position, radius * 0.85)
	if enemy == null or bool(_player.call("is_invulnerable")):
		return
	if bool(_player.call("take_hit")):
		player_struck.emit(_player.position)
		_damage_enemy(enemy, _contact_damage, _player.position)

func _resolve_ship_shots() -> void:
	var radius: float = float(_player.get("radius"))
	for shot_v in _shots.get_children():
		var shot: Node2D = shot_v as Node2D
		var reach: float = radius + float(shot.get("radius"))
		if shot.is_queued_for_deletion() or _player.position.distance_squared_to(shot.position) >= reach * reach:
			continue
		if bool(_player.call("take_hit")):
			player_struck.emit(shot.position)
			shot.queue_free()
		return

func _resolve_pickups() -> void:
	var radius: float = float(_player.get("radius"))
	for pickup_v in _pickups.get_children():
		var pickup: Node2D = pickup_v as Node2D
		var reach: float = radius + float(pickup.get("radius"))
		if pickup.is_queued_for_deletion() or _player.position.distance_squared_to(pickup.position) >= reach * reach:
			continue
		pickup_collected.emit("repair", pickup.position)
		pickup.queue_free()

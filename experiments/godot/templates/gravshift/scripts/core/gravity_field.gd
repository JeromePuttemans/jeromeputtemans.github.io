extends Node

class_name GravityField

# ── Signals ───────────────────────────────────────────────────────────────────
signal twist_activated

# ── State ─────────────────────────────────────────────────────────────────────
var _twist_emitted: bool = false
var _gravity_radius: float = 180.0
var _gravity_strength: float = 0.35
var _player: CharacterBody2D = null
var _enemies_container: Node2D = null
var _game_manager: Node = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_game_manager = get_node_or_null("/root/Main")
	if is_instance_valid(_game_manager):
		_gravity_radius = _game_manager.get_setting("gravity_radius", 180) as float
		_gravity_strength = _game_manager.get_setting("gravity_strength", 0.35) as float

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_game_manager):
		return
	if _game_manager.get_current_state() != _game_manager.GameState.PLAYING:
		return

	# Lazy-resolve references (available after _build_scene)
	if not is_instance_valid(_player):
		_player = _game_manager.get_player()
	if not is_instance_valid(_enemies_container):
		_enemies_container = _game_manager.get_enemies_container()

	if not is_instance_valid(_player) or not is_instance_valid(_enemies_container):
		return

	var player_pos: Vector2 = _player.global_position
	var player_velocity: Vector2 = _player.velocity

	# Only apply field when player is moving (twist: position matters)
	var player_is_moving: bool = player_velocity.length_squared() > 1.0

	for child_v in _enemies_container.get_children():
		# Enemies are either EnemyLinear or EnemyWave — both expose apply_gravity_deviation
		var dist_check: float = 0.0
		var child_pos: Vector2 = Vector2.ZERO
		if child_v is EnemyLinear:
			var enemy_l: EnemyLinear = child_v as EnemyLinear
			child_pos = enemy_l.global_position
			dist_check = child_pos.distance_to(player_pos)
			if dist_check < _gravity_radius and dist_check > 1.0:
				var direction: Vector2 = (player_pos - child_pos).normalized()
				var factor: float = (1.0 - dist_check / _gravity_radius) * _gravity_strength
				enemy_l.apply_gravity_deviation(direction * factor)
				if player_is_moving and not _twist_emitted:
					_twist_emitted = true
					twist_activated.emit()
		elif child_v is EnemyWave:
			var enemy_w: EnemyWave = child_v as EnemyWave
			child_pos = enemy_w.global_position
			dist_check = child_pos.distance_to(player_pos)
			if dist_check < _gravity_radius and dist_check > 1.0:
				var direction: Vector2 = (player_pos - child_pos).normalized()
				var factor: float = (1.0 - dist_check / _gravity_radius) * _gravity_strength
				enemy_w.apply_gravity_deviation(direction * factor)
				if player_is_moving and not _twist_emitted:
					_twist_emitted = true
					twist_activated.emit()

func reset_twist_state() -> void:
	_twist_emitted = false

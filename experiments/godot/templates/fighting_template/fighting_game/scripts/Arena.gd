# Arena.gd [v2]
# Orchestrates fighters, round manager, camera, HUD.

class_name Arena
extends Node2D

@onready var fighter_p1: Fighter         = $FighterP1
@onready var fighter_p2: Fighter         = $FighterP2
@onready var round_manager: RoundManager = $RoundManager
@onready var hud: CanvasLayer            = $HUD
@onready var camera: Camera2D            = $Camera2D

var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_elapsed: float  = 0.0
var _is_shaking: bool      = false
var _camera_base: Vector2  = Vector2.ZERO

const SHAKE_SAMPLES := 64
var _shake_offsets: Array[Vector2] = []
var _shake_sample_idx: int = 0

# Stage bounds (match viewport)
const STAGE_LEFT  := 40.0
const STAGE_RIGHT := 1240.0
const FLOOR_Y     := 540.0

func _ready() -> void:
	add_to_group("arena")
	_shake_strength = float(SettingsManager.get_value("camera.shake_strength", 0.0))
	_shake_duration = float(SettingsManager.get_value("camera.shake_duration", 0.0))
	_camera_base    = camera.position

	_shake_offsets.resize(SHAKE_SAMPLES)
	for i in range(SHAKE_SAMPLES):
		_shake_offsets[i] = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))

	_setup_fighters()
	round_manager.setup([fighter_p1, fighter_p2])
	_connect_round_signals()
	_connect_fighter_signals()

func _process(delta: float) -> void:
	_update_camera_shake(delta)

func _setup_fighters() -> void:
	fighter_p1.set_opponent(fighter_p2)
	fighter_p2.set_opponent(fighter_p1)
	fighter_p1.set_arena(self)
	fighter_p2.set_arena(self)

func _connect_round_signals() -> void:
	round_manager.round_started.connect(hud._on_round_started)
	round_manager.round_ended.connect(hud._on_round_ended)
	round_manager.match_ended.connect(_on_match_ended)
	round_manager.timer_updated.connect(hud._on_timer_updated)
	round_manager.countdown_tick.connect(hud._on_countdown_tick)

func _connect_fighter_signals() -> void:
	fighter_p1.health_changed.connect(hud._on_p1_health_changed)
	fighter_p2.health_changed.connect(hud._on_p2_health_changed)
	fighter_p1.hit_landed.connect(func(move_id: String, target: Fighter): _on_hit_landed(move_id, target, 0))
	fighter_p2.hit_landed.connect(func(move_id: String, target: Fighter): _on_hit_landed(move_id, target, 1))

func trigger_shake() -> void:
	_is_shaking    = true
	_shake_elapsed = 0.0

func _update_camera_shake(delta: float) -> void:
	if not _is_shaking:
		camera.position = _camera_base
		return
	_shake_elapsed += delta
	if _shake_elapsed >= _shake_duration:
		_is_shaking      = false
		camera.position  = _camera_base
		return
	var t := 1.0 - (_shake_elapsed / _shake_duration)
	_shake_sample_idx  = (_shake_sample_idx + 1) % SHAKE_SAMPLES
	camera.position    = _camera_base + _shake_offsets[_shake_sample_idx] * (_shake_strength * t)

func _on_hit_landed(_move_id: String, _target: Fighter, attacker_index: int) -> void:
	var attacker := fighter_p1 if attacker_index == 0 else fighter_p2
	hud._on_combo_updated(attacker_index, attacker.combo_count)

func _on_match_ended(winner_index: int) -> void:
	hud._on_match_ended(winner_index)
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

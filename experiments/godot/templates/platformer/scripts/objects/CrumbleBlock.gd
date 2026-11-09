# =============================================================================
# CrumbleBlock.gd — Cracked block ('c') that falls when stood on
# =============================================================================
# IDLE -> stood on -> SHAKING for crumble_delay s -> FALLEN (passable) for
# crumble_respawn s -> back to IDLE as soon as the player is not inside.
# =============================================================================

class_name CrumbleBlock
extends Node2D

enum State { IDLE, SHAKING, FALLEN }

var cell := Vector2i.ZERO
var theme_data: LevelData = null
var state: State = State.IDLE
var _timer: float = 0.0
var _fall: float = 0.0
var _pop: float = 1.0
var _delay: float = 0.45
var _respawn_time: float = 2.5
var _color := Color("9b8a74")

func _ready() -> void:
	position = Vector2(cell) * LevelData.TILE
	_delay = ConfigManager.get_float("crumble_delay", 0.45)
	_respawn_time = ConfigManager.get_float("crumble_respawn", 2.5)
	if theme_data != null:
		_color = theme_data.theme_color("crumble", _color)

func rect() -> Rect2:
	return Rect2(position, Vector2(LevelData.TILE, LevelData.TILE))

func is_solid() -> bool:
	return state != State.FALLEN

func trigger() -> void:
	if state != State.IDLE:
		return
	state = State.SHAKING
	_timer = _delay
	Sfx.play("crumble")

func wants_respawn() -> bool:
	return state == State.FALLEN and _timer <= 0.0

func respawn() -> void:
	state = State.IDLE
	_pop = 0.0

func _physics_process(delta: float) -> void:
	if state == State.SHAKING:
		_timer -= delta
		if _timer <= 0.0:
			state = State.FALLEN
			_timer = _respawn_time
			_fall = 0.0
	elif state == State.FALLEN:
		_timer -= delta

func _process(delta: float) -> void:
	if state == State.FALLEN:
		_fall += delta
	_pop = minf(_pop + delta * 5.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var t: float = LevelData.TILE
	if state == State.FALLEN:
		if _fall > 0.5:
			return
		var a: float = 1.0 - _fall / 0.5
		for i in 4:
			var piece := Vector2((i % 2) * t * 0.5, floorf(i / 2.0) * t * 0.5)
			var drop := Vector2((i % 2 - 0.5) * 30.0 * _fall, 260.0 * _fall * _fall + i * 4.0 * _fall)
			draw_rect(Rect2(piece + drop, Vector2(t * 0.5 - 2.0, t * 0.5 - 2.0)), Color(_color, a))
		return
	var shake := Vector2.ZERO
	if state == State.SHAKING:
		shake = Vector2(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0))
	var s: float = ease(_pop, 0.5)
	var size := Vector2(t, t) * s
	var origin: Vector2 = shake + (Vector2(t, t) - size) * 0.5
	draw_rect(Rect2(origin, size), _color.darkened(0.3))
	draw_rect(Rect2(origin + Vector2(2.0, 2.0), size - Vector2(4.0, 6.0)), _color)
	draw_rect(Rect2(origin + Vector2(2.0, 2.0), Vector2(size.x - 4.0, 3.0)), _color.lightened(0.25))
	var crack := _color.darkened(0.45)
	var o: Vector2 = origin
	draw_polyline(PackedVector2Array([o + Vector2(8, 4) * s, o + Vector2(16, 16) * s, o + Vector2(12, 26) * s, o + Vector2(20, 36) * s]), crack, 1.5)
	draw_polyline(PackedVector2Array([o + Vector2(16, 16) * s, o + Vector2(30, 14) * s, o + Vector2(34, 24) * s]), crack, 1.5)

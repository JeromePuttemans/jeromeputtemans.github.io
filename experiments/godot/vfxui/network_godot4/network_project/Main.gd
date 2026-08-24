extends Node2D

## Taille du canvas shader (pixels)
const SZ := 512

## Inertie souris (0 = aucune, 1 = instantané)
const INERTIA := 0.08

# Uniformes courants
var _n      : float = 12.0
var _speed  : float = 0.3
var _glow   : float = 1.0

# Position souris (espace shader –1..1)
var _mouse_x : float = 0.0
var _mouse_y : float = 0.0
var _target_x : float = 0.0
var _target_y : float = 0.0

# Références nœuds
@onready var _rect   : ColorRect   = $ColorRect
@onready var _mat    : ShaderMaterial = $ColorRect.material as ShaderMaterial

@onready var _sl_branches : HSlider = $UI/Panel/VBox/RowBranches/SliderBranches
@onready var _sl_speed    : HSlider = $UI/Panel/VBox/RowSpeed/SliderSpeed
@onready var _sl_glow     : HSlider = $UI/Panel/VBox/RowGlow/SliderGlow

@onready var _lbl_branches : Label = $UI/Panel/VBox/RowBranches/ValBranches
@onready var _lbl_speed    : Label = $UI/Panel/VBox/RowSpeed/ValSpeed
@onready var _lbl_glow     : Label = $UI/Panel/VBox/RowGlow/ValGlow


func _ready() -> void:
	_mat.set_shader_parameter("u_res",   Vector2(SZ, SZ))
	_mat.set_shader_parameter("u_n",     _n)
	_mat.set_shader_parameter("u_glow",  _glow)
	_mat.set_shader_parameter("u_mouse", Vector2.ZERO)

	_sl_branches.value_changed.connect(_on_branches_changed)
	_sl_speed.value_changed.connect(_on_speed_changed)
	_sl_glow.value_changed.connect(_on_glow_changed)


func _process(delta: float) -> void:
	# Inertie souris
	_mouse_x += (_target_x - _mouse_x) * INERTIA
	_mouse_y += (_target_y - _mouse_y) * INERTIA

	var t : float = Time.get_ticks_msec() * 0.001 * _speed
	_mat.set_shader_parameter("u_t",     t)
	_mat.set_shader_parameter("u_glow",  _glow)
	_mat.set_shader_parameter("u_n",     _n)
	_mat.set_shader_parameter("u_mouse", Vector2(_mouse_x, _mouse_y))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var rect : Rect2 = _rect.get_global_rect()
		var cx : float = (event.position.x - rect.position.x) / rect.size.x   # 0..1
		var cy : float = (event.position.y - rect.position.y) / rect.size.y   # 0..1
		_target_x =  cx * 2.0 - 1.0   # –1..1
		_target_y = -(cy * 2.0 - 1.0)  # –1..1 (Y inversé : haut = –1 dans Godot)


# ── Callbacks sliders ────────────────────────────────────────────────────────

func _on_branches_changed(value: float) -> void:
	_n = value
	_lbl_branches.text = str(int(value))


func _on_speed_changed(value: float) -> void:
	_speed = value / 10.0
	_lbl_speed.text = "%.1f" % _speed


func _on_glow_changed(value: float) -> void:
	_glow = value / 10.0
	_lbl_glow.text = "%.1f" % _glow

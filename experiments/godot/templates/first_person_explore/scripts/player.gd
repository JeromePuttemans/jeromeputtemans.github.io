extends CharacterBody3D

# Movement parameters
@export var speed: float = 5.0
@export var sensitivity: float = 0.1
@export var jump_force: float = 7.0

# Camera reference
@onready var camera: Camera3D = $Camera

# State variables
var direction: Vector3 = Vector3.ZERO
var look_angle: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Capture mouse and hide cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	move_and_slide()

func _handle_movement(delta: float) -> void:
	direction = Vector3.ZERO
	
	# Get input direction
	if Input.is_action_pressed("move_forward"):
		direction -= transform.basis.z
	if Input.is_action_pressed("move_backward"):
		direction += transform.basis.z
	if Input.is_action_pressed("move_left"):
		direction -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		direction += transform.basis.x
	
	direction = direction.normalized()
	
	# Apply movement
	var target_velocity: Vector3 = direction * speed
	if is_on_floor():
		target_velocity.y = velocity.y
		if Input.is_action_just_pressed("jump"):
			target_velocity.y = jump_force
	else:
		target_velocity.y = velocity.y
		target_velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
	velocity = velocity.lerp(target_velocity, 0.1)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_delta: Vector2 = event.relative
		mouse_delta *= -1 # Needed to have the correct rotations
	
		look_angle.y += mouse_delta.x * sensitivity
		look_angle.x += mouse_delta.y * sensitivity
		
		# Clamp vertical look angle to prevent flipping
		look_angle.x = clamp(look_angle.x, -85, 85)
		
		# Apply rotations
		rotation.y = deg_to_rad(look_angle.y)
		camera.rotation.x = deg_to_rad(look_angle.x)

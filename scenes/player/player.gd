extends CharacterBody3D

@export var speed: float = 5.0
@export var sensitivity: float = 0.003
@onready var pivot: Node3D = $CameraPivot
@onready var arm: SpringArm3D = $CameraPivot/SpringArm3D
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var controls_enabled: bool = true

func _ready() -> void:
	arm.add_excluded_object(get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivot.rotation.y -= event.relative.x * sensitivity
		arm.rotation.x = clampf(arm.rotation.x - event.relative.y * sensitivity, -1.1, -0.12)
	if event.is_action_pressed("zoom_in"):
		arm.spring_length = maxf(2.0, arm.spring_length - 0.5)
	if event.is_action_pressed("zoom_out"):
		arm.spring_length = minf(9.0, arm.spring_length + 0.5)

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if not controls_enabled:
		input = Vector2.ZERO
	var direction := pivot.global_basis * Vector3(input.x, 0.0, input.y)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if direction.length_squared() > 0.01:
		$Body.rotation.y = atan2(-direction.x, -direction.z)
	if position.y < -15.0:
		position = Vector3(0, 1, 4)
		velocity = Vector3.ZERO

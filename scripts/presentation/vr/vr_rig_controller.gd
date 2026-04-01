class_name VRRigController
extends RigInterface

## SPEC-VR-001: VR 리그 컨트롤러
## XROrigin3D 기반으로 HMD 카메라, 좌/우 컨트롤러를 관리한다.
## OpenXR 입력 바인딩을 통해 이동과 마킹을 처리한다.

const MOVE_SPEED: float = 3.0
const JOYSTICK_DEADZONE: float = 0.15

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var right_controller: XRController3D = $XROrigin3D/RightController


func _ready() -> void:
	# 오른손 트리거 버튼으로 마킹
	right_controller.button_pressed.connect(_on_right_button_pressed)


func _physics_process(delta: float) -> void:
	_process_joystick_movement(delta)


func get_camera() -> Camera3D:
	return xr_camera


func get_ray_origin() -> Vector3:
	return right_controller.global_position


func get_ray_direction() -> Vector3:
	return -right_controller.global_transform.basis.z


func get_player_position() -> Vector3:
	return xr_origin.global_position


func apply_movement(dir: Vector3, delta: float) -> void:
	xr_origin.global_position += dir * MOVE_SPEED * delta


func _process_joystick_movement(delta: float) -> void:
	var input_vector: Vector2 = left_controller.get_vector2("primary")
	if input_vector.length() < JOYSTICK_DEADZONE:
		return

	# 카메라 방향 기준으로 이동 방향 계산
	var cam_basis: Basis = xr_camera.global_transform.basis
	var forward: Vector3 = -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = cam_basis.x
	right.y = 0.0
	right = right.normalized()

	var direction: Vector3 = (forward * input_vector.y + right * input_vector.x).normalized()
	apply_movement(direction, delta)


func _on_right_button_pressed(button_name: String) -> void:
	if button_name == "trigger_click":
		mark_requested.emit(get_ray_origin(), get_ray_direction())

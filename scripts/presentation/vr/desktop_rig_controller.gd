class_name DesktopRigController
extends RigInterface

## SPEC-VR-002: 데스크톱 리그 컨트롤러
## CharacterBody3D + Camera3D 기반으로 키보드(WASD) 이동과 마우스 시점 제어를 제공한다.
## VR 기기 없이도 동일한 시뮬레이션 기능을 사용할 수 있게 한다.

const MOVE_SPEED: float = 5.0
const MOUSE_SENSITIVITY: float = 0.003
const GRAVITY: float = 9.8
const RAY_LENGTH: float = 100.0

var _mouse_captured: bool = false
var _camera_rotation: Vector2 = Vector2.ZERO

@onready var character_body: CharacterBody3D = $CharacterBody3D
@onready var camera: Camera3D = $CharacterBody3D/Camera3D


func _ready() -> void:
	_capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	# 마우스 시점 제어
	if event is InputEventMouseMotion and _mouse_captured:
		_rotate_camera(event.relative)

	# 마우스 좌클릭 마킹
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _mouse_captured:
				mark_requested.emit(get_ray_origin(), get_ray_direction())
			else:
				_capture_mouse()

	# ESC로 마우스 해제
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE and key_event.pressed:
			_release_mouse()


func _physics_process(delta: float) -> void:
	_process_keyboard_movement(delta)


func get_camera() -> Camera3D:
	return camera


func get_ray_origin() -> Vector3:
	return camera.global_position


func get_ray_direction() -> Vector3:
	return -camera.global_transform.basis.z


func get_player_position() -> Vector3:
	return character_body.global_position


func apply_movement(dir: Vector3, delta: float) -> void:
	var velocity: Vector3 = character_body.velocity
	velocity.x = dir.x * MOVE_SPEED
	velocity.z = dir.z * MOVE_SPEED

	# 중력 적용
	if not character_body.is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	character_body.velocity = velocity
	character_body.move_and_slide()


func _process_keyboard_movement(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0

	if input_dir.length() < 0.01:
		# 정지 시 수평 속도를 0으로
		var velocity: Vector3 = character_body.velocity
		velocity.x = 0.0
		velocity.z = 0.0
		if not character_body.is_on_floor():
			velocity.y -= GRAVITY * delta
		character_body.velocity = velocity
		character_body.move_and_slide()
		return

	input_dir = input_dir.normalized()

	# 카메라 방향 기준으로 이동 방향 계산
	var cam_basis: Basis = camera.global_transform.basis
	var forward: Vector3 = -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = cam_basis.x
	right.y = 0.0
	right = right.normalized()

	var direction: Vector3 = (forward * input_dir.y + right * input_dir.x).normalized()
	apply_movement(direction, delta)


func _rotate_camera(mouse_relative: Vector2) -> void:
	_camera_rotation.x -= mouse_relative.y * MOUSE_SENSITIVITY
	_camera_rotation.y -= mouse_relative.x * MOUSE_SENSITIVITY

	# 수직 회전 제한 (위아래 90도)
	_camera_rotation.x = clampf(_camera_rotation.x, -PI / 2.0, PI / 2.0)

	character_body.rotation.y = _camera_rotation.y
	camera.rotation.x = _camera_rotation.x


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_captured = false

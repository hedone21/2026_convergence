extends GutTest

# ======================================
# SPEC-VR-002: 데스크톱 모드 폴백
# ======================================
# UI/입력 관련 테스트는 headless에서 제한적.
# DesktopRigController의 @onready 노드가 씬 없이 초기화되지 않으므로
# 씬을 로드하여 테스트하거나 상수/시그널 존재만 검증.


## TEST-VR-002: DesktopRigController 상수 검증
func test_desktop_rig_constants() -> void:
	assert_eq(
		DesktopRigController.MOVE_SPEED, 5.0,
		"데스크톱 이동 속도 기본값은 5.0"
	)
	assert_eq(
		DesktopRigController.MOUSE_SENSITIVITY, 0.003,
		"마우스 감도 기본값은 0.003"
	)
	assert_eq(
		DesktopRigController.GRAVITY, 9.8,
		"중력 기본값은 9.8"
	)
	assert_eq(
		DesktopRigController.RAY_LENGTH, 100.0,
		"레이 길이 기본값은 100.0"
	)


## TEST-VR-002-2: 데스크톱 리그 씬 로드 테스트
func test_desktop_rig_scene_loads() -> void:
	var scene: PackedScene = load("res://scenes/vr_rig/desktop_rig.tscn")
	assert_not_null(scene, "데스크톱 리그 씬 로드 성공")

	var instance: Node = scene.instantiate()
	add_child_autoqfree(instance)

	assert_true(instance is RigInterface, "DesktopRig는 RigInterface를 상속")
	assert_true(instance is DesktopRigController, "DesktopRig는 DesktopRigController 타입")
	assert_true(instance.has_signal("mark_requested"), "mark_requested 시그널 존재")


## TEST-VR-002-3: 데스크톱 리그 씬의 노드 구조 확인
func test_desktop_rig_node_structure() -> void:
	var scene: PackedScene = load("res://scenes/vr_rig/desktop_rig.tscn")
	var instance: Node = scene.instantiate()
	add_child_autoqfree(instance)

	# CharacterBody3D와 Camera3D가 존재해야 함
	var char_body: CharacterBody3D = instance.get_node_or_null("CharacterBody3D") as CharacterBody3D
	assert_not_null(char_body, "CharacterBody3D 노드 존재")

	var camera: Camera3D = instance.get_node_or_null("CharacterBody3D/Camera3D") as Camera3D
	assert_not_null(camera, "CharacterBody3D/Camera3D 노드 존재")


## TEST-VR-002-4: 데스크톱 리그에서 get_camera, get_ray_origin, get_ray_direction이 동작
func test_desktop_rig_methods_work() -> void:
	var scene: PackedScene = load("res://scenes/vr_rig/desktop_rig.tscn")
	var instance: DesktopRigController = scene.instantiate() as DesktopRigController
	add_child_autoqfree(instance)

	# 카메라 반환
	var camera: Camera3D = instance.get_camera()
	assert_not_null(camera, "get_camera()가 null이 아님")

	# 레이 원점 (카메라 위치)
	var origin: Vector3 = instance.get_ray_origin()
	assert_typeof(origin, TYPE_VECTOR3, "get_ray_origin()은 Vector3 반환")

	# 레이 방향 (카메라 전방)
	var direction: Vector3 = instance.get_ray_direction()
	assert_typeof(direction, TYPE_VECTOR3, "get_ray_direction()은 Vector3 반환")

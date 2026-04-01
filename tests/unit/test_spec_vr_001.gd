extends GutTest

# ======================================
# SPEC-VR-001: VR 환경 초기화 및 세션 시작
# ======================================
# VR 하드웨어가 필요한 테스트는 headless에서 실행 불가.
# 코드 정합성 검증 위주로 자동화 가능한 항목만 테스트.


## TEST-VR-001: VRInitializer.initialize_openxr()가 Dictionary를 반환
func test_vr_initializer_returns_dictionary() -> void:
	var result: Dictionary = VRInitializer.initialize_openxr()

	assert_typeof(result, TYPE_DICTIONARY, "반환 타입은 Dictionary")
	assert_has(result, "success", "success 키가 존재해야 한다")

	# headless 환경에서는 VR 런타임이 없으므로 실패가 예상됨
	if not result["success"]:
		assert_has(result, "reason", "실패 시 reason 키가 존재해야 한다")
		assert_typeof(result["reason"], TYPE_STRING, "reason은 String 타입")


## TEST-VR-001-2: headless에서 VR 초기화 실패 시 success=false 반환
func test_vr_init_fails_in_headless() -> void:
	var result: Dictionary = VRInitializer.initialize_openxr()

	assert_false(result["success"], "headless 환경에서는 VR 초기화 실패 예상")
	assert_ne(result.get("reason", ""), "", "실패 사유가 비어있지 않아야 한다")


## TEST-VR-001-3: RigInterface의 추상 메서드가 push_error를 호출하는지 확인
func test_rig_interface_abstract_methods() -> void:
	var rig := RigInterface.new()
	add_child_autoqfree(rig)

	# 추상 메서드 호출 시 null/ZERO/FORWARD를 반환 (push_error 내부 호출)
	var camera: Camera3D = rig.get_camera()
	assert_null(camera, "추상 get_camera는 null 반환")
	assert_push_error("RigInterface.get_camera() must be overridden")

	var origin: Vector3 = rig.get_ray_origin()
	assert_eq(origin, Vector3.ZERO, "추상 get_ray_origin은 ZERO 반환")
	assert_push_error("RigInterface.get_ray_origin() must be overridden")

	var direction: Vector3 = rig.get_ray_direction()
	assert_eq(direction, Vector3.FORWARD, "추상 get_ray_direction은 FORWARD 반환")
	assert_push_error("RigInterface.get_ray_direction() must be overridden")

	var pos: Vector3 = rig.get_player_position()
	assert_eq(pos, Vector3.ZERO, "추상 get_player_position은 ZERO 반환")
	assert_push_error("RigInterface.get_player_position() must be overridden")

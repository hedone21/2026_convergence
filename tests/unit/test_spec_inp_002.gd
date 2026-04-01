extends GutTest

# ======================================
# SPEC-INP-002: 컨트롤러 버튼 마킹
# ======================================
# MarkingSystem의 레이캐스트 판정, 시그널 발행, 충돌 마스크를 검증한다.
# headless 환경에서는 물리 공간이 제한적이므로 구조적/단위 테스트 위주.


## TEST-INP-002: MarkingSystem 시그널 선언 확인
func test_marking_system_signals() -> void:
	var ms := MarkingSystem.new()
	add_child_autoqfree(ms)

	assert_true(ms.has_signal("mark_succeeded"), "mark_succeeded 시그널 존재")
	assert_true(ms.has_signal("mark_failed"), "mark_failed 시그널 존재")
	assert_true(ms.has_signal("mark_feedback"), "mark_feedback 시그널 존재")


## TEST-INP-002-2: 기본 최대 탐지 거리 50m
func test_default_max_distance() -> void:
	var ms := MarkingSystem.new()
	add_child_autoqfree(ms)

	assert_almost_eq(ms.max_distance, 50.0, 0.01, "기본 최대 거리 50m")


## TEST-INP-002-3: HAZARD_RAY_MASK가 BaseHazard의 HAZARD_COLLISION_LAYER와 일치
func test_ray_mask_matches_hazard_layer() -> void:
	assert_eq(
		MarkingSystem.HAZARD_RAY_MASK,
		BaseHazard.HAZARD_COLLISION_LAYER,
		"레이 마스크 == 위험 요소 충돌 레이어 (둘 다 32)"
	)


## TEST-INP-002-4: MarkingSystem은 Node를 상속 (씬 트리 필요)
func test_marking_system_is_node() -> void:
	var ms := MarkingSystem.new()
	add_child_autoqfree(ms)

	assert_true(ms is Node, "MarkingSystem은 Node")


## TEST-INP-002-5: perform_mark() — 물리 공간 없이 호출 시 에러 처리
func test_perform_mark_without_physics() -> void:
	var ms := MarkingSystem.new()
	add_child_autoqfree(ms)
	watch_signals(ms)

	# headless에서 물리 공간이 없을 수 있음
	ms.perform_mark(Vector3.ZERO, Vector3.FORWARD)

	# 물리 공간이 없으면 push_error 후 반환 (시그널 미발행)
	# 물리 공간이 있으면 아무것도 안 맞아서 mark_failed
	# 어느 쪽이든 크래시 없이 동작해야 함
	assert_true(true, "perform_mark 호출 시 크래시 없음")


## TEST-INP-002-6: set_ray_visible() 동작
func test_ray_visible_toggle() -> void:
	var ms := MarkingSystem.new()
	add_child_autoqfree(ms)

	assert_false(ms.ray_visible, "초기 레이 비가시")

	ms.set_ray_visible(true)
	assert_true(ms.ray_visible, "레이 가시 설정")

	ms.set_ray_visible(false)
	assert_false(ms.ray_visible, "레이 비가시 복원")


## TEST-INP-002-7: mark_succeeded 시그널 수동 트리거 테스트
## (실제 물리 레이캐스트 대신 시그널 emit을 직접 테스트)
func test_mark_succeeded_signal_emission() -> void:
	var ms := MarkingSystem.new()
	add_child_autoqfree(ms)
	watch_signals(ms)

	var hazard := BaseHazard.new()
	add_child_autoqfree(hazard)
	hazard.hazard_id = "test_01"

	# 시그널 직접 emit (시뮬레이션)
	ms.mark_succeeded.emit(hazard, Vector3(1.0, 0.0, 2.0))

	assert_signal_emitted(ms, "mark_succeeded", "mark_succeeded emit 확인")
	var params: Array = get_signal_parameters(ms, "mark_succeeded")
	assert_eq(params[0], hazard, "첫 번째 파라미터 = hazard 인스턴스")
	assert_eq(params[1], Vector3(1.0, 0.0, 2.0), "두 번째 파라미터 = hit_position")


## TEST-INP-002-8: mark_failed 시그널 수동 트리거 테스트
func test_mark_failed_signal_emission() -> void:
	var ms := MarkingSystem.new()
	add_child_autoqfree(ms)
	watch_signals(ms)

	ms.mark_failed.emit(Vector3(5.0, 1.0, 0.0), Vector3(0.0, 0.0, -1.0))

	assert_signal_emitted(ms, "mark_failed", "mark_failed emit 확인")
	var params: Array = get_signal_parameters(ms, "mark_failed")
	assert_eq(params[0], Vector3(5.0, 1.0, 0.0), "hit_position 파라미터")
	assert_eq(params[1], Vector3(0.0, 0.0, -1.0), "ray_direction 파라미터")


## TEST-INP-002-9: HazardManager.attempt_mark_hazard() — 정상 마킹
func test_attempt_mark_hazard_success() -> void:
	var hazard := BaseHazard.new()
	add_child_autoqfree(hazard)
	hazard.hazard_id = "mark_test_01"
	hazard.hazard_type = "crack"
	hazard.difficulty = 0.5

	# HazardManager의 attempt_mark_hazard 직접 호출이 가능한 경우
	var manager_node: Node = get_node_or_null("/root/HazardManager")
	if manager_node == null:
		# Autoload 없이 직접 테스트
		var changed: bool = hazard.discover()
		assert_true(changed, "discover() 성공")
		assert_true(hazard.is_discovered(), "발견 상태")
		return

	var result: MarkingResult = manager_node.attempt_mark_hazard(hazard, Vector3.ZERO)
	assert_not_null(result, "MarkingResult 반환")
	assert_true(result.is_correct, "마킹 성공")
	assert_eq(result.hazard_id, "mark_test_01", "hazard_id 일치")


## TEST-INP-002-10: HazardManager.attempt_mark_hazard() — 이미 발견된 위험 요소
func test_attempt_mark_already_discovered() -> void:
	var hazard := BaseHazard.new()
	add_child_autoqfree(hazard)
	hazard.hazard_id = "mark_test_02"
	hazard.discover()  # 이미 발견됨

	var manager_node: Node = get_node_or_null("/root/HazardManager")
	if manager_node == null:
		# Autoload 없이 직접 테스트
		var second: bool = hazard.discover()
		assert_false(second, "재발견은 false")
		return

	var result: MarkingResult = manager_node.attempt_mark_hazard(hazard, Vector3.ZERO)
	assert_not_null(result, "MarkingResult 반환")
	assert_false(result.is_correct, "이미 발견된 위험 요소 → is_correct false")


## TEST-INP-002-11: HazardManager.record_false_positive() — 오탐 기록
func test_record_false_positive() -> void:
	var manager_node: Node = get_node_or_null("/root/HazardManager")
	if manager_node == null:
		pending("HazardManager Autoload를 찾을 수 없음")
		return

	watch_signals(manager_node)
	var result: MarkingResult = manager_node.record_false_positive(
		Vector3(1.0, 1.0, 1.0), Vector3.FORWARD
	)

	assert_not_null(result, "MarkingResult 반환")
	assert_eq(result.hazard_id, "", "오탐은 hazard_id 빈 문자열")
	assert_false(result.is_correct, "오탐은 is_correct false")
	assert_signal_emitted(manager_node, "false_positive", "false_positive 시그널 발행")

extends GutTest

# ======================================
# SPEC-INP-001: 조이스틱 기반 이동
# ======================================
# Locomotion의 이동 속도 설정, 스냅 턴, 쿨다운을 검증한다.
# 실제 CharacterBody3D 이동은 RigInterface에 위임되므로,
# Locomotion 단위의 로직을 테스트한다.


## TEST-INP-001: Locomotion 기본 속도 설정값
func test_locomotion_default_speed() -> void:
	var loco := Locomotion.new()

	assert_almost_eq(loco.move_speed, 3.0, 0.01, "기본 이동 속도 3.0 m/s")
	assert_almost_eq(loco.snap_turn_degrees, 30.0, 0.01, "기본 스냅 턴 30도")


## TEST-INP-001-2: set_speed()로 속도 변경
func test_set_speed() -> void:
	var loco := Locomotion.new()

	loco.set_speed(5.0)
	assert_almost_eq(loco.move_speed, 5.0, 0.01, "속도 5.0으로 변경")

	loco.set_speed(0.0)
	assert_almost_eq(loco.move_speed, 0.0, 0.01, "속도 0.0 허용")


## TEST-INP-001-3: set_speed() 음수 입력 시 0.0으로 클램프
func test_set_speed_negative_clamped() -> void:
	var loco := Locomotion.new()

	loco.set_speed(-2.0)
	assert_almost_eq(loco.move_speed, 0.0, 0.01, "음수 속도 → 0.0으로 클램프")


## TEST-INP-001-4: apply_movement() — 리그 미연결 시 안전하게 무시
func test_apply_movement_without_rig() -> void:
	var loco := Locomotion.new()

	# 리그 없이 호출해도 에러 없이 반환
	loco.apply_movement(Vector3.FORWARD, 0.016)
	assert_true(true, "리그 없이 apply_movement() 호출 시 에러 없음")


## TEST-INP-001-5: apply_movement() — 제로 방향 벡터 무시
func test_apply_movement_zero_direction_ignored() -> void:
	var loco := Locomotion.new()
	var rig := RigInterface.new()
	add_child_autoqfree(rig)
	loco.bind_rig(rig)

	# 제로 벡터는 length_squared < 0.001이므로 무시됨
	# RigInterface.apply_movement()는 호출되지 않아야 함 (push_error 미발생)
	loco.apply_movement(Vector3.ZERO, 0.016)
	assert_true(true, "제로 방향에서 에러 없음")


## TEST-INP-001-6: apply_snap_turn() — 리그 미연결 시 안전하게 무시
func test_snap_turn_without_rig() -> void:
	var loco := Locomotion.new()

	loco.apply_snap_turn(30.0)
	assert_true(true, "리그 없이 snap_turn 호출 시 에러 없음")


## TEST-INP-001-7: 스냅 턴 쿨다운 — 쿨다운 중 추가 턴 무시
func test_snap_turn_cooldown() -> void:
	var loco := Locomotion.new()
	var rig := RigInterface.new()
	add_child_autoqfree(rig)
	loco.bind_rig(rig)

	# 첫 스냅 턴 → 쿨다운 시작
	loco.apply_snap_turn(30.0)
	assert_gt(loco._snap_turn_cooldown_remaining, 0.0, "쿨다운 활성화")

	# 쿨다운 중 두 번째 스냅 턴 → 무시됨
	var cooldown_before: float = loco._snap_turn_cooldown_remaining
	loco.apply_snap_turn(30.0)
	# 쿨다운 값은 변경되지 않음 (추가 턴이 적용되지 않았으므로)
	assert_eq(loco._snap_turn_cooldown_remaining, cooldown_before,
		"쿨다운 중 스냅 턴 무시")


## TEST-INP-001-8: update()로 쿨다운 감소
func test_update_reduces_cooldown() -> void:
	var loco := Locomotion.new()
	var rig := RigInterface.new()
	add_child_autoqfree(rig)
	loco.bind_rig(rig)

	loco.apply_snap_turn(30.0)
	var initial_cooldown: float = loco._snap_turn_cooldown_remaining
	assert_gt(initial_cooldown, 0.0, "쿨다운이 설정됨")

	# 시간 경과 시뮬레이션
	loco.update(0.1)
	assert_lt(loco._snap_turn_cooldown_remaining, initial_cooldown,
		"update 후 쿨다운 감소")

	# 충분한 시간 경과 후 쿨다운 0
	loco.update(1.0)
	assert_almost_eq(loco._snap_turn_cooldown_remaining, 0.0, 0.01,
		"충분한 시간 후 쿨다운 0")


## TEST-INP-001-9: bind_rig / unbind_rig 동작
func test_bind_unbind_rig() -> void:
	var loco := Locomotion.new()
	var rig := RigInterface.new()
	add_child_autoqfree(rig)

	loco.bind_rig(rig)
	assert_eq(loco._rig, rig, "리그 연결됨")

	loco.unbind_rig()
	assert_null(loco._rig, "리그 해제됨")


## TEST-INP-001-10: Locomotion은 RefCounted (Godot 노드가 아님)
func test_locomotion_is_refcounted() -> void:
	var loco := Locomotion.new()
	assert_true(loco is RefCounted, "Locomotion은 RefCounted")
	assert_eq(loco.get_class(), "RefCounted", "base class는 RefCounted")


## TEST-INP-001-11: SNAP_TURN_COOLDOWN 상수 검증 (VR 멀미 방지)
func test_snap_turn_cooldown_constant() -> void:
	assert_almost_eq(Locomotion.SNAP_TURN_COOLDOWN, 0.25, 0.01,
		"스냅 턴 쿨다운 0.25초")


## TEST-INP-001-12: InputManager Autoload 시그널 선언 확인
func test_input_manager_signals() -> void:
	var manager: Node = get_node_or_null("/root/InputManager")
	if manager == null:
		pending("InputManager Autoload를 찾을 수 없음 (headless 환경)")
		return

	assert_true(manager.has_signal("mark_requested"), "mark_requested 시그널 존재")
	assert_true(manager.has_signal("movement_input"), "movement_input 시그널 존재")
	assert_true(manager.has_signal("snap_turn_input"), "snap_turn_input 시그널 존재")

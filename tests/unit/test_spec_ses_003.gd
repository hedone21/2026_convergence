extends GutTest

# ======================================
# SPEC-SES-003: 세션 흐름 제어 (시작-진행-종료)
# ======================================
# SessionManager 상태 머신 전이를 검증한다.
# 유효/무효 전이, 시그널 발행, timer_expired 자동 종료를 테스트한다.


## SessionManager Autoload 획득
func _get_session_manager() -> Node:
	return get_node_or_null("/root/SessionManager")


## SessionManager 상태를 INITIALIZING으로 리셋 (테스트 간 격리)
func _reset_state(manager: Node) -> void:
	manager.current_state = manager.SessionState.INITIALIZING
	manager.session_data = null


## TEST-SES-003: 초기 상태는 INITIALIZING
func test_initial_state_is_initializing() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	# 참고: 실제 Autoload에서는 _ready() 후 상태가 변할 수 있으나,
	# 리셋 후 INITIALIZING으로 시작해야 함
	_reset_state(manager)
	assert_eq(manager.current_state, manager.SessionState.INITIALIZING, "초기 상태 == INITIALIZING")


## TEST-SES-003-2: 유효한 상태 전이 — INITIALIZING → SUBJECT_INPUT
func test_transition_initializing_to_subject_input() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)
	watch_signals(manager)

	manager._transition_to(manager.SessionState.SUBJECT_INPUT)

	assert_eq(manager.current_state, manager.SessionState.SUBJECT_INPUT, "INITIALIZING → SUBJECT_INPUT")
	assert_signal_emitted(manager, "state_changed", "state_changed 시그널 발행")


## TEST-SES-003-3: 유효한 상태 전이 — SUBJECT_INPUT → RUNNING
func test_transition_subject_input_to_running() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)
	manager.current_state = manager.SessionState.SUBJECT_INPUT
	watch_signals(manager)

	manager._transition_to(manager.SessionState.RUNNING)

	assert_eq(manager.current_state, manager.SessionState.RUNNING, "SUBJECT_INPUT → RUNNING")
	assert_signal_emitted(manager, "state_changed", "state_changed 시그널 발행")


## TEST-SES-003-4: 유효한 상태 전이 — RUNNING → RESULT
func test_transition_running_to_result() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)
	manager.current_state = manager.SessionState.RUNNING
	watch_signals(manager)

	manager._transition_to(manager.SessionState.RESULT)

	assert_eq(manager.current_state, manager.SessionState.RESULT, "RUNNING → RESULT")
	assert_signal_emitted(manager, "state_changed", "state_changed 시그널 발행")


## TEST-SES-003-5: 유효한 상태 전이 — RESULT → ENDED
func test_transition_result_to_ended() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)
	manager.current_state = manager.SessionState.RESULT
	watch_signals(manager)

	manager._transition_to(manager.SessionState.ENDED)

	assert_eq(manager.current_state, manager.SessionState.ENDED, "RESULT → ENDED")


## TEST-SES-003-6: 유효한 상태 전이 — RESULT → INITIALIZING (새 세션)
func test_transition_result_to_initializing() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)
	manager.current_state = manager.SessionState.RESULT
	watch_signals(manager)

	manager._transition_to(manager.SessionState.INITIALIZING)

	assert_eq(manager.current_state, manager.SessionState.INITIALIZING, "RESULT → INITIALIZING")


## TEST-SES-003-7: 잘못된 전이 거부 — SUBJECT_INPUT → ENDED
func test_invalid_transition_subject_input_to_ended() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)
	manager.current_state = manager.SessionState.SUBJECT_INPUT
	watch_signals(manager)

	manager._transition_to(manager.SessionState.ENDED)

	# 상태가 변경되지 않아야 함
	assert_eq(manager.current_state, manager.SessionState.SUBJECT_INPUT,
		"SUBJECT_INPUT → ENDED 거부됨 (상태 유지)")
	assert_signal_not_emitted(manager, "state_changed", "잘못된 전이 시 시그널 미발행")


## TEST-SES-003-8: 잘못된 전이 거부 — INITIALIZING → RUNNING (건너뛰기 불가)
func test_invalid_transition_initializing_to_running() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)
	watch_signals(manager)

	manager._transition_to(manager.SessionState.RUNNING)

	assert_eq(manager.current_state, manager.SessionState.INITIALIZING,
		"INITIALIZING → RUNNING 거부됨")
	assert_signal_not_emitted(manager, "state_changed", "잘못된 전이 시 시그널 미발행")


## TEST-SES-003-9: 잘못된 전이 거부 — INITIALIZING → RESULT
func test_invalid_transition_initializing_to_result() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)

	manager._transition_to(manager.SessionState.RESULT)

	assert_eq(manager.current_state, manager.SessionState.INITIALIZING,
		"INITIALIZING → RESULT 거부됨")


## TEST-SES-003-10: 잘못된 전이 거부 — RUNNING → INITIALIZING
func test_invalid_transition_running_to_initializing() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)
	manager.current_state = manager.SessionState.RUNNING

	manager._transition_to(manager.SessionState.INITIALIZING)

	assert_eq(manager.current_state, manager.SessionState.RUNNING,
		"RUNNING → INITIALIZING 거부됨")


## TEST-SES-003-11: _on_timer_expired() — RUNNING 상태에서 end_session("time_up")
func test_timer_expired_ends_session() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)
	manager.current_state = manager.SessionState.RUNNING

	# session_data 준비 (end_session에서 참조)
	var sd := SessionData.new()
	sd.session_id = "test_timer"
	sd.start_time = Time.get_ticks_msec() - 5000
	sd.total_hazards = 0
	manager.session_data = sd

	watch_signals(manager)

	manager._on_timer_expired()

	assert_eq(manager.current_state, manager.SessionState.RESULT,
		"timer_expired 후 RESULT 상태")
	assert_signal_emitted(manager, "session_ended", "session_ended 시그널 발행")


## TEST-SES-003-12: _on_timer_expired() — RUNNING이 아닌 상태에서는 무시
func test_timer_expired_ignored_when_not_running() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)
	# INITIALIZING 상태에서 timer_expired → 무시
	manager._on_timer_expired()

	assert_eq(manager.current_state, manager.SessionState.INITIALIZING,
		"INITIALIZING에서 timer_expired → 상태 변경 없음")


## TEST-SES-003-13: state_changed 시그널 파라미터 (old_state, new_state)
func test_state_changed_signal_parameters() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)
	watch_signals(manager)

	manager._transition_to(manager.SessionState.SUBJECT_INPUT)

	var params: Array = get_signal_parameters(manager, "state_changed")
	assert_eq(params[0], manager.SessionState.INITIALIZING, "old_state == INITIALIZING")
	assert_eq(params[1], manager.SessionState.SUBJECT_INPUT, "new_state == SUBJECT_INPUT")


## TEST-SES-003-14: _can_transition_to() 내부 함수 검증
func test_can_transition_to() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)

	# INITIALIZING에서 가능한 전이
	assert_true(manager._can_transition_to(manager.SessionState.SUBJECT_INPUT),
		"INITIALIZING → SUBJECT_INPUT 가능")
	assert_false(manager._can_transition_to(manager.SessionState.RUNNING),
		"INITIALIZING → RUNNING 불가")
	assert_false(manager._can_transition_to(manager.SessionState.RESULT),
		"INITIALIZING → RESULT 불가")
	assert_false(manager._can_transition_to(manager.SessionState.ENDED),
		"INITIALIZING → ENDED 불가")


## TEST-SES-003-15: get_state_name() — 각 상태의 문자열 표현
func test_get_state_name() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)
	assert_eq(manager.get_state_name(), "INITIALIZING", "INITIALIZING 문자열")

	manager.current_state = manager.SessionState.SUBJECT_INPUT
	assert_eq(manager.get_state_name(), "SUBJECT_INPUT", "SUBJECT_INPUT 문자열")

	manager.current_state = manager.SessionState.RUNNING
	assert_eq(manager.get_state_name(), "RUNNING", "RUNNING 문자열")

	manager.current_state = manager.SessionState.RESULT
	assert_eq(manager.get_state_name(), "RESULT", "RESULT 문자열")

	manager.current_state = manager.SessionState.ENDED
	assert_eq(manager.get_state_name(), "ENDED", "ENDED 문자열")

	# 테스트 후 원상 복구
	_reset_state(manager)


## TEST-SES-003-16: 전체 정상 흐름 — INITIALIZING → SUBJECT_INPUT → RUNNING → RESULT → ENDED
func test_full_valid_flow() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)

	# INITIALIZING → SUBJECT_INPUT
	manager._transition_to(manager.SessionState.SUBJECT_INPUT)
	assert_eq(manager.current_state, manager.SessionState.SUBJECT_INPUT, "1단계: SUBJECT_INPUT")

	# SUBJECT_INPUT → RUNNING
	manager._transition_to(manager.SessionState.RUNNING)
	assert_eq(manager.current_state, manager.SessionState.RUNNING, "2단계: RUNNING")

	# RUNNING → RESULT
	manager._transition_to(manager.SessionState.RESULT)
	assert_eq(manager.current_state, manager.SessionState.RESULT, "3단계: RESULT")

	# RESULT → ENDED
	manager._transition_to(manager.SessionState.ENDED)
	assert_eq(manager.current_state, manager.SessionState.ENDED, "4단계: ENDED")

	# 테스트 후 원상 복구
	_reset_state(manager)


## TEST-SES-003-17: SessionManager Autoload — 필수 시그널 존재
func test_session_manager_signals() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	assert_true(manager.has_signal("state_changed"), "state_changed 시그널")
	assert_true(manager.has_signal("session_started"), "session_started 시그널")
	assert_true(manager.has_signal("session_ended"), "session_ended 시그널")
	assert_true(manager.has_signal("subject_info_submitted"), "subject_info_submitted 시그널")
	assert_true(manager.has_signal("timer_updated"), "timer_updated 시그널")


## TEST-SES-003-18: SessionManager Autoload — 필수 메서드 존재
func test_session_manager_methods() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	assert_true(manager.has_method("start_new_session"), "start_new_session 메서드")
	assert_true(manager.has_method("submit_subject_info"), "submit_subject_info 메서드")
	assert_true(manager.has_method("end_session"), "end_session 메서드")
	assert_true(manager.has_method("request_early_end"), "request_early_end 메서드")
	assert_true(manager.has_method("proceed_to_next"), "proceed_to_next 메서드")
	assert_true(manager.has_method("get_elapsed_time"), "get_elapsed_time 메서드")
	assert_true(manager.has_method("get_state_name"), "get_state_name 메서드")


## TEST-SES-003-19: end_session() — RUNNING이 아닌 상태에서 호출 시 무시
func test_end_session_ignored_when_not_running() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)
	watch_signals(manager)

	# INITIALIZING에서 end_session → 무시
	manager.end_session("manual")

	assert_eq(manager.current_state, manager.SessionState.INITIALIZING,
		"INITIALIZING에서 end_session → 상태 변경 없음")
	assert_signal_not_emitted(manager, "session_ended", "session_ended 미발행")


## TEST-SES-003-20: ENDED → INITIALIZING 전이 가능 (새 세션 시작)
func test_ended_can_restart() -> void:
	var manager: Node = _get_session_manager()
	if manager == null:
		pending("SessionManager Autoload를 찾을 수 없음")
		return

	_reset_state(manager)
	manager.current_state = manager.SessionState.ENDED

	assert_true(manager._can_transition_to(manager.SessionState.INITIALIZING),
		"ENDED → INITIALIZING 전이 가능")

	manager._transition_to(manager.SessionState.INITIALIZING)
	assert_eq(manager.current_state, manager.SessionState.INITIALIZING,
		"ENDED → INITIALIZING 전이 성공")

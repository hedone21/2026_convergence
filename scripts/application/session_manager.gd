extends Node

## SPEC-SES-003: 세션 흐름 제어 (시작-진행-종료)
## SPEC-SES-001: 피험자 정보 제출 연동
## SPEC-SES-002: 세션 타이머 연동
##
## SessionManager Autoload -- 세션 상태 머신 관리
## 상태: INITIALIZING -> SUBJECT_INPUT -> RUNNING -> RESULT -> ENDED
## SOLID S: 세션 생명주기만 관리한다.
## SOLID D: SessionData(Domain)에만 의존, Presentation을 직접 제어하지 않는다.

## SPEC-SES-003: 상태 전환 시 발행
signal state_changed(old_state: SessionState, new_state: SessionState)

## SPEC-SES-003: 시뮬레이션 진행 시작
signal session_started

## SPEC-SES-003: 세션 종료 (시간초과/수동/전체발견)
signal session_ended(reason: String)

## SPEC-SES-001: 피험자 정보 제출 완료
signal subject_info_submitted(data: SubjectData)

## SPEC-SES-002: 타이머 갱신 (매초)
signal timer_updated(remaining_seconds: float)

## SPEC-SES-003: 세션 상태 열거형
enum SessionState {
	INITIALIZING,    ## 씬 로드, 시나리오 적용
	SUBJECT_INPUT,   ## 피험자 정보 입력 대기
	RUNNING,         ## 시뮬레이션 진행 중
	RESULT,          ## 결과 표시/저장
	ENDED,           ## 종료
}

## 현재 상태
var current_state: SessionState = SessionState.INITIALIZING

## 현재 세션 데이터
var session_data: SessionData = null

## 세션 타이머 (Presentation의 SessionTimer 노드)
var _session_timer: SessionTimer = null

## 세션 로거 (Infrastructure의 SessionLogger 노드)
var _session_logger: SessionLogger = null

## 시뮬레이션 시작 시각 (Time.get_ticks_msec)
var _session_start_ticks: int = 0

## SPEC-SES-003: 유효한 상태 전이 맵
## 키: 현재 상태, 값: 전이 가능한 상태 배열
var _valid_transitions: Dictionary = {
	SessionState.INITIALIZING: [SessionState.SUBJECT_INPUT],
	SessionState.SUBJECT_INPUT: [SessionState.RUNNING],
	SessionState.RUNNING: [SessionState.RESULT],
	SessionState.RESULT: [SessionState.ENDED, SessionState.INITIALIZING],
	SessionState.ENDED: [SessionState.INITIALIZING],
}


func _ready() -> void:
	# Deferred로 시그널 연결 및 세션 시작
	# (Autoload 로드 순서에 의해 GameManager.game_ready가 이미 emit된 상태이므로,
	#  deferred로 씬 트리 준비 후 직접 시작한다)
	call_deferred("_connect_signals")
	call_deferred("_auto_start_session")
	print("[SessionManager] Initialized.")


## SPEC-SES-003: 새 세션을 시작한다.
## INITIALIZING 상태로 진입 후, 시나리오 로드 -> SUBJECT_INPUT 전이.
func start_new_session() -> void:
	print("[SessionManager] Starting new session...")

	# 이미 INITIALIZING이 아니면 초기화 상태로 전환
	if current_state != SessionState.INITIALIZING:
		if not _can_transition_to(SessionState.INITIALIZING):
			push_warning("SPEC-SES-003: 현재 상태(%s)에서 새 세션을 시작할 수 없습니다." % _state_name(current_state))
			return
		_transition_to(SessionState.INITIALIZING)

	# 세션 데이터 초기화
	session_data = SessionData.new()
	session_data.session_id = "ses_%s" % _generate_timestamp_id()

	# 시나리오 로드
	var scenario: ScenarioData = ScenarioManager.load_default_scenario()
	if scenario == null:
		push_error("SPEC-SES-003: 시나리오 로드 실패. 세션을 시작할 수 없습니다.")
		return

	session_data.scenario_id = scenario.scenario_id
	session_data.site_type = scenario.site_type
	session_data.time_limit_seconds = scenario.time_limit_seconds

	# 시나리오 적용 (위험 요소 배치)
	ScenarioManager.apply_scenario()
	session_data.total_hazards = HazardManager.hazards.size()

	# SUBJECT_INPUT 상태로 전이
	_transition_to(SessionState.SUBJECT_INPUT)

	# SubjectInfoUI를 UILayer에 로드
	_show_subject_info_ui()


## SPEC-SES-001, SPEC-SES-003: 피험자 정보를 제출하고 시뮬레이션을 시작한다.
func submit_subject_info(data: SubjectData) -> void:
	if current_state != SessionState.SUBJECT_INPUT:
		push_warning(
			"SPEC-SES-003: SUBJECT_INPUT 상태가 아닌데 피험자 정보가 제출되었습니다. (현재: %s)" % _state_name(current_state)
		)
		return

	session_data.subject = data
	subject_info_submitted.emit(data)

	print("[SessionManager] Subject info submitted: %s (exp=%d years)" % [
		data.subject_id, data.experience_years
	])

	# RUNNING 상태로 전이
	_transition_to(SessionState.RUNNING)

	# SubjectInfoUI 제거
	_clear_ui_layer()

	# 세션 시작 시각 기록
	session_data.start_time = Time.get_ticks_msec()
	_session_start_ticks = session_data.start_time

	# SPEC-SES-002: 타이머 시작
	if _session_timer != null:
		_session_timer.start_timer(float(session_data.time_limit_seconds))
	else:
		push_warning("SPEC-SES-002: SessionTimer를 찾을 수 없습니다. 타이머 없이 진행합니다.")

	# EvaluationManager에 평가 시작 알림
	EvaluationManager.start_evaluation(session_data.total_hazards)

	session_started.emit()
	print("[SessionManager] Session RUNNING: %s (time_limit=%ds, hazards=%d)" % [
		session_data.session_id, session_data.time_limit_seconds, session_data.total_hazards
	])


## SPEC-SES-003: 세션을 종료한다.
## reason: "time_up" | "all_discovered" | "manual" | "forced"
func end_session(reason: String) -> void:
	if current_state != SessionState.RUNNING:
		push_warning(
			"SPEC-SES-003: RUNNING 상태가 아닌데 세션 종료가 요청되었습니다. (현재: %s, reason: %s)" % [
				_state_name(current_state), reason
			]
		)
		return

	print("[SessionManager] Ending session: reason=%s" % reason)

	# 타이머 정지
	if _session_timer != null:
		_session_timer.stop_timer()

	# 세션 종료 데이터 기록
	session_data.end_time = Time.get_ticks_msec()
	session_data.end_reason = reason

	# 마킹 결과 수집
	_collect_marking_results()

	# EvaluationManager에 평가 종료 알림
	EvaluationManager.finalize_evaluation()

	# RESULT 상태로 전이
	_transition_to(SessionState.RESULT)

	# SPEC-DAT-001: SessionLogger로 결과 저장
	if _session_logger != null:
		var save_path: String = _session_logger.save_session_result(session_data)
		if save_path.is_empty():
			push_warning("SPEC-DAT-001: 세션 결과 저장 실패")
		else:
			print("[SessionManager] Session result saved: %s" % save_path)
	else:
		push_warning("SPEC-DAT-001: SessionLogger를 찾을 수 없습니다. 결과를 저장할 수 없습니다.")

	session_ended.emit(reason)
	print("[SessionManager] Session ended: %s (elapsed=%.1fs, discovery=%.1f%%)" % [
		reason,
		session_data.get_elapsed_seconds(),
		session_data.get_discovery_rate_percent(),
	])


## SPEC-SES-003: 조기 종료를 요청한다.
func request_early_end() -> void:
	if current_state == SessionState.RUNNING:
		end_session("manual")
	else:
		push_warning("SPEC-SES-003: RUNNING 상태가 아니므로 조기 종료를 수행할 수 없습니다.")


## SPEC-SES-003: 결과 확인 후 다음 단계로 진행한다.
## 새 세션을 시작하거나 완전히 종료한다.
func proceed_to_next(start_new: bool = false) -> void:
	if current_state != SessionState.RESULT:
		push_warning("SPEC-SES-003: RESULT 상태가 아닌데 proceed_to_next가 호출되었습니다.")
		return

	if start_new:
		_transition_to(SessionState.INITIALIZING)
		start_new_session()
	else:
		_transition_to(SessionState.ENDED)
		print("[SessionManager] Session flow completed.")


## 경과 시간을 반환한다 (밀리초).
func get_elapsed_time() -> float:
	if _session_start_ticks <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - _session_start_ticks)


## Autoload 초기화 완료 후 자동으로 세션을 시작한다.
func _auto_start_session() -> void:
	# GameManager가 이미 초기화 완료 상태인지 확인
	if GameManager.current_rig != null:
		print("[SessionManager] Auto-starting new session...")
		start_new_session()
	else:
		# 아직 준비되지 않았으면 game_ready를 기다림
		GameManager.game_ready.connect(func(): call_deferred("start_new_session"), CONNECT_ONE_SHOT)


## 현재 상태 이름을 반환한다 (로그용).
func get_state_name() -> String:
	return _state_name(current_state)


# ---------------------------------------------------------------------------
# 내부 메서드
# ---------------------------------------------------------------------------

## 상태 전이를 수행한다.
func _transition_to(new_state: SessionState) -> void:
	if not _can_transition_to(new_state):
		push_warning(
			"SPEC-SES-003: 유효하지 않은 상태 전이: %s -> %s (무시됨)" % [
				_state_name(current_state), _state_name(new_state)
			]
		)
		return

	var old_state: SessionState = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)
	print("[SessionManager] State: %s -> %s" % [_state_name(old_state), _state_name(new_state)])


## 특정 상태로 전이 가능한지 검사한다.
func _can_transition_to(new_state: SessionState) -> bool:
	if not _valid_transitions.has(current_state):
		return false
	var valid_targets: Array = _valid_transitions[current_state]
	return new_state in valid_targets


## 상태 열거형을 문자열로 변환한다.
func _state_name(state: SessionState) -> String:
	match state:
		SessionState.INITIALIZING: return "INITIALIZING"
		SessionState.SUBJECT_INPUT: return "SUBJECT_INPUT"
		SessionState.RUNNING: return "RUNNING"
		SessionState.RESULT: return "RESULT"
		SessionState.ENDED: return "ENDED"
	return "UNKNOWN"


## 시그널 연결 (deferred)
func _connect_signals() -> void:
	# HazardManager의 all_hazards_discovered 시그널 구독
	if not HazardManager.all_hazards_discovered.is_connected(_on_all_hazards_discovered):
		HazardManager.all_hazards_discovered.connect(_on_all_hazards_discovered)

	# SessionTimer 검색 및 연결
	_find_session_timer()

	# SessionLogger 검색 및 연결
	_find_session_logger()

	# SubjectInfoUI 검색 및 연결
	_find_subject_info_ui()


## SPEC-SES-003: 모든 위험 요소 발견 시 자동 종료
func _on_all_hazards_discovered() -> void:
	if current_state == SessionState.RUNNING:
		print("[SessionManager] All hazards discovered — auto-ending session.")
		end_session("all_discovered")


## SPEC-SES-002: 타이머 만료 시 자동 종료
func _on_timer_expired() -> void:
	if current_state == SessionState.RUNNING:
		print("[SessionManager] Timer expired — auto-ending session.")
		end_session("time_up")


## SPEC-SES-002: 타이머 갱신 전달
func _on_timer_updated(remaining: float) -> void:
	timer_updated.emit(remaining)


## SPEC-SES-001: SubjectInfoUI에서 피험자 정보가 제출되었을 때
func _on_subject_info_submitted(subject_data: SubjectData) -> void:
	submit_subject_info(subject_data)


## UILayer의 자식을 모두 제거한다.
func _clear_ui_layer() -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return
	var ui_layer: CanvasLayer = main_scene.get_node_or_null("UILayer") as CanvasLayer
	if ui_layer:
		for child: Node in ui_layer.get_children():
			child.queue_free()


## SubjectInfoUI를 UILayer에 로드하여 표시한다.
func _show_subject_info_ui() -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return

	var ui_layer: CanvasLayer = main_scene.get_node_or_null("UILayer") as CanvasLayer
	if ui_layer == null:
		push_error("[SessionManager] UILayer not found in main scene.")
		return

	# 기존 UI 제거
	for child: Node in ui_layer.get_children():
		child.queue_free()

	# SubjectInfoUI 씬 로드
	var ui_scene: PackedScene = load("res://scenes/ui/subject_info_ui.tscn") as PackedScene
	if ui_scene:
		var ui_instance: SubjectInfoUI = ui_scene.instantiate() as SubjectInfoUI
		ui_layer.add_child(ui_instance)
		# 시그널 연결
		if not ui_instance.info_submitted.is_connected(_on_subject_info_submitted):
			ui_instance.info_submitted.connect(_on_subject_info_submitted)
		print("[SessionManager] SubjectInfoUI displayed.")
	else:
		push_error("[SessionManager] Failed to load SubjectInfoUI scene.")


## SessionTimer 검색
func _find_session_timer() -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return

	# SessionTimer를 씬 트리에서 재귀 검색
	_session_timer = _find_node_of_type(main_scene, "SessionTimer") as SessionTimer
	if _session_timer != null:
		if not _session_timer.timer_expired.is_connected(_on_timer_expired):
			_session_timer.timer_expired.connect(_on_timer_expired)
		if not _session_timer.timer_updated.is_connected(_on_timer_updated):
			_session_timer.timer_updated.connect(_on_timer_updated)
		print("[SessionManager] SessionTimer connected.")
	else:
		# SessionTimer가 아직 없으면 새로 생성하여 자식으로 추가
		_session_timer = SessionTimer.new()
		_session_timer.name = "SessionTimer"
		add_child(_session_timer)
		_session_timer.timer_expired.connect(_on_timer_expired)
		_session_timer.timer_updated.connect(_on_timer_updated)
		print("[SessionManager] SessionTimer created as child.")


## SessionLogger 검색
func _find_session_logger() -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return

	_session_logger = _find_node_of_type(main_scene, "SessionLogger") as SessionLogger
	if _session_logger != null:
		print("[SessionManager] SessionLogger connected.")
	else:
		# SessionLogger가 없으면 새로 생성
		_session_logger = SessionLogger.new()
		_session_logger.name = "SessionLogger"
		add_child(_session_logger)
		print("[SessionManager] SessionLogger created as child.")


## SubjectInfoUI 검색 및 시그널 연결
func _find_subject_info_ui() -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return

	var ui: SubjectInfoUI = _find_node_of_type(main_scene, "SubjectInfoUI") as SubjectInfoUI
	if ui != null:
		if not ui.info_submitted.is_connected(_on_subject_info_submitted):
			ui.info_submitted.connect(_on_subject_info_submitted)
		print("[SessionManager] SubjectInfoUI connected.")


## 씬 트리에서 class_name으로 노드를 재귀 검색한다.
func _find_node_of_type(root: Node, type_name: String) -> Node:
	if root.get_class() == type_name or root.get_script() != null and _script_has_class_name(root, type_name):
		return root
	for child: Node in root.get_children():
		var found: Node = _find_node_of_type(child, type_name)
		if found != null:
			return found
	return null


## 스크립트의 class_name이 일치하는지 확인한다.
func _script_has_class_name(node: Node, type_name: String) -> bool:
	# GDScript에서 class_name 검사 — is 연산자 대안
	match type_name:
		"SessionTimer":
			return node is SessionTimer
		"SessionLogger":
			return node is SessionLogger
		"SubjectInfoUI":
			return node is SubjectInfoUI
	return false


## 마킹 결과를 HazardManager로부터 수집한다.
func _collect_marking_results() -> void:
	# HazardManager에서 발견된 위험 요소 정보를 SessionData에 반영
	# (실제 마킹 결과는 InputManager/MarkingSystem에서 실시간으로 기록되어야 하지만,
	#  현재 Phase에서는 EvaluationManager의 reaction_times 기반으로 결과를 재구성)
	var discovered: Array[BaseHazard] = HazardManager.get_discovered_hazards()
	var all_reaction_times: Dictionary = EvaluationManager.get_all_reaction_times()

	for hazard: BaseHazard in discovered:
		var result: MarkingResult = MarkingResult.new()
		result.hazard_id = hazard.hazard_id
		result.hazard_type = hazard.hazard_type
		result.hazard_difficulty = hazard.difficulty
		result.is_correct = true
		result.timestamp = Time.get_ticks_msec()
		result.reaction_time_ms = all_reaction_times.get(hazard.hazard_id, -1.0)
		session_data.marking_results.append(result)


## 타임스탬프 기반 세션 ID를 생성한다.
func _generate_timestamp_id() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"],
	]

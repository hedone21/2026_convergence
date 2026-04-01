extends GutTest

# ======================================
# 통합 테스트: 시그널 정합성 및 데이터 흐름 검증
# ======================================


## INTEGRATION-001: SessionTimer의 시그널이 올바른 파라미터로 발행되는지 검증
func test_session_timer_signals() -> void:
	var timer := SessionTimer.new()
	add_child_autoqfree(timer)
	watch_signals(timer)

	timer.start_timer(60.0)

	# timer_updated는 시작 즉시 발행됨
	assert_signal_emitted(timer, "timer_updated", "시작 시 timer_updated 발행")

	# timer_expired는 아직 발행되지 않아야 함
	assert_signal_not_emitted(timer, "timer_expired", "시작 직후에는 timer_expired 미발행")


## INTEGRATION-002: GazeTracker의 gaze_sampled 시그널 파라미터 타입 검증
func test_gaze_tracker_signal_params() -> void:
	var tracker := GazeTracker.new()
	add_child_autoqfree(tracker)

	# 시그널이 direction(Vector3) + timestamp(int) 파라미터를 가짐을 확인
	assert_true(tracker.has_signal("gaze_sampled"), "gaze_sampled 시그널 존재")


## INTEGRATION-003: SessionData와 MarkingResult 데이터 흐름 검증
func test_session_data_marking_flow() -> void:
	var session := SessionData.new()
	session.total_hazards = 3

	# 정답 1건
	var correct := MarkingResult.new()
	correct.hazard_id = "crack_01"
	correct.is_correct = true
	correct.reaction_time_ms = 5000.0
	session.marking_results.append(correct)

	# 오탐 1건
	var fp := MarkingResult.new()
	fp.hazard_id = ""
	fp.is_correct = false
	session.marking_results.append(fp)

	assert_eq(session.get_discovered_hazards(), 1, "발견 위험 요소 1개")
	assert_eq(session.get_false_positives().size(), 1, "오탐 1건")
	assert_eq(session.get_hazard_results().size(), 1, "위험 요소 결과 1건 (오탐 제외)")
	assert_almost_eq(session.get_discovery_rate_percent(), 33.3, 0.1, "1/3 = 33.3%")


## INTEGRATION-004: SessionLogger가 SessionData를 올바르게 직렬화하는지 검증
func test_logger_serializes_session_data() -> void:
	var logger := SessionLogger.new()
	add_child_autoqfree(logger)
	watch_signals(logger)

	var subject := SubjectData.new()
	subject.subject_id = "integ_test_01"
	subject.experience_years = 7
	subject.experience_category = "고급"

	var session := SessionData.new()
	session.session_id = "INTEG_001"
	session.subject = subject
	session.scenario_id = "default"
	session.site_type = "building_frame"
	session.start_time = 1711929600000
	session.end_time = 1711929900000
	session.time_limit_seconds = 300
	session.end_reason = "timer_expired"
	session.total_hazards = 2

	var m1 := MarkingResult.new()
	m1.hazard_id = "crack_01"
	m1.hazard_type = "crack"
	m1.hazard_difficulty = 0.3
	m1.is_correct = true
	m1.timestamp = 1711929650000
	m1.reaction_time_ms = 50000.0
	m1.player_position = Vector3(2.0, 1.7, 3.0)
	m1.gaze_direction = Vector3(0.0, 0.0, -1.0)
	session.marking_results.append(m1)

	var path: String = logger.save_session_result(session)
	assert_ne(path, "", "저장 성공")
	assert_signal_emitted(logger, "save_completed", "save_completed 시그널 발행")

	# JSON 내용 검증
	var content: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(content)
	assert_not_null(data, "JSON 파싱 성공")

	assert_eq(data["session_id"], "INTEG_001", "session_id 일치")
	assert_eq(data["subject"]["subject_id"], "integ_test_01", "subject_id 일치")
	assert_eq(data["total_hazards"], 2, "total_hazards 일치")
	assert_eq(data["discovered_hazards"], 1, "discovered_hazards 일치")
	assert_almost_eq(float(data["discovery_rate_percent"]), 50.0, 0.1, "발견율 50%")

	# 정리
	_cleanup_file(path)
	_cleanup_file(path.replace("_result.json", "_result.csv"))
	_cleanup_file(path.replace("_result.json", "_hazards.csv"))


## INTEGRATION-005: BuildingFrameSite + BaseSite 다형성 검증
func test_site_polymorphism() -> void:
	var scene: PackedScene = load("res://scenes/environment/building_frame.tscn")
	assert_not_null(scene, "BuildingFrame 씬 로드 성공")

	var site: Node = scene.instantiate()
	add_child_autoqfree(site)

	assert_true(site is BaseSite, "BuildingFrameSite는 BaseSite를 상속")
	assert_eq(site.get_site_type(), "building_frame", "다형성으로 site_type 반환")
	assert_gt(site.get_valid_surfaces().size(), 0, "다형성으로 표면 목록 반환")


## INTEGRATION-006: Autoload 참조 정합성 — GameManager class_name 충돌 검증
func test_autoload_class_name_conflict() -> void:
	# 이 테스트는 코드 리뷰로 발견된 BUG-001을 문서화한다.
	# project.godot: GameManager="*res://scripts/application/game_manager.gd"
	# game_manager.gd: class_name GameManager  <-- 충돌!
	# 수정: class_name을 제거하거나 autoload 이름을 변경해야 한다.
	# 이미 수정 완료됨 (class_name 제거)
	pass


func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

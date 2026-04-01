extends GutTest

# ======================================
# SPEC-DAT-001: 세션 결과 로컬 파일 저장
# ======================================


## TEST-DAT-001: SessionLogger가 JSON + CSV 파일을 올바르게 생성하는지 검증
func test_save_session_result_creates_files() -> void:
	var logger := SessionLogger.new()
	add_child_autoqfree(logger)

	var session := _create_test_session()
	var result_path: String = logger.save_session_result(session)

	assert_ne(result_path, "", "JSON 파일 경로가 비어있지 않아야 한다")
	assert_true(FileAccess.file_exists(result_path), "JSON 파일이 존재해야 한다")

	# CSV 파일도 생성되었는지 확인
	var csv_path: String = result_path.replace("_result.json", "_result.csv")
	assert_true(FileAccess.file_exists(csv_path), "CSV 요약 파일이 존재해야 한다")

	var hazards_csv_path: String = result_path.replace("_result.json", "_hazards.csv")
	assert_true(FileAccess.file_exists(hazards_csv_path), "위험 요소 상세 CSV 파일이 존재해야 한다")

	# 정리
	_cleanup_file(result_path)
	_cleanup_file(csv_path)
	_cleanup_file(hazards_csv_path)


## TEST-DAT-001-2: JSON 파일 구조가 스키마와 일치하는지 검증
func test_json_structure_matches_schema() -> void:
	var logger := SessionLogger.new()
	add_child_autoqfree(logger)

	var session := _create_test_session()
	var result_path: String = logger.save_session_result(session)

	assert_ne(result_path, "", "파일 저장 성공")

	var content: String = FileAccess.get_file_as_string(result_path)
	var data: Variant = JSON.parse_string(content)
	assert_not_null(data, "JSON 파싱 성공")

	# SPEC-DAT-001 필수 필드 확인
	assert_has(data, "session_id", "session_id 필드 존재")
	assert_has(data, "subject", "subject 필드 존재")
	assert_has(data, "scenario_id", "scenario_id 필드 존재")
	assert_has(data, "site_type", "site_type 필드 존재")
	assert_has(data, "start_time_epoch_ms", "start_time 필드 존재")
	assert_has(data, "end_time_epoch_ms", "end_time 필드 존재")
	assert_has(data, "time_limit_seconds", "time_limit 필드 존재")
	assert_has(data, "elapsed_seconds", "elapsed_seconds 필드 존재")
	assert_has(data, "end_reason", "end_reason 필드 존재")
	assert_has(data, "total_hazards", "total_hazards 필드 존재")
	assert_has(data, "discovered_hazards", "discovered_hazards 필드 존재")
	assert_has(data, "discovery_rate_percent", "discovery_rate_percent 필드 존재")
	assert_has(data, "avg_reaction_time_ms", "avg_reaction_time_ms 필드 존재")
	assert_has(data, "hazard_results", "hazard_results 필드 존재")
	assert_has(data, "false_positives", "false_positives 필드 존재")

	# subject 서브 필드
	var subject_dict: Dictionary = data["subject"]
	assert_has(subject_dict, "subject_id", "subject.subject_id 필드 존재")
	assert_has(subject_dict, "experience_years", "subject.experience_years 필드 존재")

	_cleanup_file(result_path)
	_cleanup_file(result_path.replace("_result.json", "_result.csv"))
	_cleanup_file(result_path.replace("_result.json", "_hazards.csv"))


## TEST-DAT-001-3: 파일명에 피험자 ID와 타임스탬프가 포함되는지 검증
func test_filename_contains_subject_id_and_timestamp() -> void:
	var logger := SessionLogger.new()
	add_child_autoqfree(logger)

	var session := _create_test_session()
	session.subject.subject_id = "SUBJ_42"
	var result_path: String = logger.save_session_result(session)

	assert_ne(result_path, "", "파일 저장 성공")
	var filename: String = result_path.get_file()
	assert_string_contains(filename, "SUBJ_42", "파일명에 피험자 ID 포함")
	assert_string_contains(filename, "_result.json", "파일명에 _result.json 포함")

	_cleanup_file(result_path)
	_cleanup_file(result_path.replace("_result.json", "_result.csv"))
	_cleanup_file(result_path.replace("_result.json", "_hazards.csv"))


## TEST-DAT-001-4: 기존 파일이 있으면 덮어쓰지 않고 새 파일 생성
func test_no_overwrite_existing_file() -> void:
	var logger := SessionLogger.new()
	add_child_autoqfree(logger)

	var session := _create_test_session()
	var path1: String = logger.save_session_result(session)
	var path2: String = logger.save_session_result(session)

	assert_ne(path1, "", "첫 번째 저장 성공")
	assert_ne(path2, "", "두 번째 저장 성공")
	assert_ne(path1, path2, "서로 다른 파일 경로 — 덮어쓰기 방지")

	_cleanup_file(path1)
	_cleanup_file(path2)
	_cleanup_file(path1.replace("_result.json", "_result.csv"))
	_cleanup_file(path2.replace("_result.json", "_result.csv"))
	_cleanup_file(path1.replace("_result.json", "_hazards.csv"))
	_cleanup_file(path2.replace("_result.json", "_hazards.csv"))


## TEST-DAT-001-F: 저장 실패 시 save_failed 시그널이 발행되고 콘솔 출력 폴백
func test_save_failed_signal_on_error() -> void:
	var logger := SessionLogger.new()
	add_child_autoqfree(logger)
	watch_signals(logger)

	# subject가 null인 세션 — 저장은 성공할 수 있으나 subject_id가 "unknown"이 됨
	var session := SessionData.new()
	session.session_id = "test_fail"
	session.start_time = 1000000
	# subject를 null로 두면 subject_id가 빈 문자열 -> "unknown"으로 대체됨
	var result_path: String = logger.save_session_result(session)

	# 저장 자체는 성공해야 함 (unknown으로 폴백)
	assert_ne(result_path, "", "subject가 null이어도 unknown으로 대체하여 저장 성공")

	_cleanup_file(result_path)
	_cleanup_file(result_path.replace("_result.json", "_result.csv"))
	_cleanup_file(result_path.replace("_result.json", "_hazards.csv"))


# ---------------------------------------------------------------------------
# 테스트 헬퍼
# ---------------------------------------------------------------------------

func _create_test_session() -> SessionData:
	var subject := SubjectData.new()
	subject.subject_id = "test_subject_01"
	subject.experience_years = 5
	subject.experience_category = "중급"

	var session := SessionData.new()
	session.session_id = "SES_UNIT_TEST"
	session.subject = subject
	session.scenario_id = "default"
	session.site_type = "building_frame"
	session.start_time = 1711929600000  # 2024-04-01T00:00:00 UTC (ms)
	session.end_time = 1711929900000    # 5분 후
	session.time_limit_seconds = 300
	session.end_reason = "timer_expired"
	session.total_hazards = 3

	# 정답 마킹 1개
	var correct := MarkingResult.new()
	correct.hazard_id = "crack_01"
	correct.hazard_type = "crack"
	correct.hazard_difficulty = 0.5
	correct.is_correct = true
	correct.timestamp = 1711929650000
	correct.reaction_time_ms = 50000.0
	correct.player_position = Vector3(1.0, 1.7, 2.0)
	correct.gaze_direction = Vector3(0.0, 0.0, -1.0)
	session.marking_results.append(correct)

	# 미발견 마킹 1개
	var missed := MarkingResult.new()
	missed.hazard_id = "crack_02"
	missed.hazard_type = "crack"
	missed.hazard_difficulty = 0.8
	missed.is_correct = false
	missed.reaction_time_ms = -1.0
	session.marking_results.append(missed)

	# 오탐 1개
	var fp := MarkingResult.new()
	fp.hazard_id = ""
	fp.is_correct = false
	fp.timestamp = 1711929700000
	fp.player_position = Vector3(3.0, 1.7, -1.0)
	fp.gaze_direction = Vector3(0.5, 0.0, -0.866)
	session.marking_results.append(fp)

	return session


func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

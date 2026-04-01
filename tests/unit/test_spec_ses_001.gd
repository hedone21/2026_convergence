extends GutTest

# ======================================
# SPEC-SES-001: 피험자 정보 입력 화면
# ======================================
# UI 테스트는 headless에서 제한적.
# SubjectInfoUI는 @onready 노드가 씬 트리 없이 동작하지 않으므로
# 도메인 모델(SubjectData, MarkingResult, SessionData)의 로직만 검증.


## TEST-SES-001: SubjectData 모델의 to_dict가 필수 필드를 포함
func test_subject_data_to_dict() -> void:
	var subject := SubjectData.new()
	subject.subject_id = "P001"
	subject.experience_years = 3
	subject.experience_category = "중급"

	var d: Dictionary = subject.to_dict()

	assert_has(d, "subject_id", "subject_id 키 존재")
	assert_has(d, "experience_years", "experience_years 키 존재")
	assert_has(d, "experience_category", "experience_category 키 존재")
	assert_eq(d["subject_id"], "P001", "subject_id 값 일치")
	assert_eq(d["experience_years"], 3, "experience_years 값 일치")
	assert_eq(d["experience_category"], "중급", "experience_category 값 일치")


## TEST-SES-001-2: SessionData 모델의 discovery_rate 계산 검증
func test_session_data_discovery_rate() -> void:
	var session := SessionData.new()
	session.total_hazards = 4

	# 2개 발견
	for i: int in range(2):
		var result := MarkingResult.new()
		result.hazard_id = "h_%d" % i
		result.is_correct = true
		result.reaction_time_ms = 1000.0
		session.marking_results.append(result)

	assert_almost_eq(
		session.get_discovery_rate_percent(), 50.0, 0.1,
		"4개 중 2개 발견 -> 50%"
	)


## TEST-SES-001-3: total_hazards가 0일 때 발견율이 0%
func test_discovery_rate_zero_hazards() -> void:
	var session := SessionData.new()
	session.total_hazards = 0

	assert_eq(
		session.get_discovery_rate_percent(), 0.0,
		"위험 요소 0개일 때 발견율 0%"
	)


## TEST-SES-001-4: MarkingResult.is_false_positive — hazard_id가 비어있으면 오탐
func test_marking_result_false_positive() -> void:
	var fp := MarkingResult.new()
	fp.hazard_id = ""
	assert_true(fp.is_false_positive(), "hazard_id 빈 문자열 -> 오탐")

	var real := MarkingResult.new()
	real.hazard_id = "crack_01"
	assert_false(real.is_false_positive(), "hazard_id 있음 -> 오탐 아님")


## TEST-SES-001-5: MarkingResult.to_dict — 오탐과 정답의 딕셔너리 구조가 다름
func test_marking_result_to_dict_structure() -> void:
	# 정답
	var correct := MarkingResult.new()
	correct.hazard_id = "crack_01"
	correct.hazard_type = "crack"
	correct.is_correct = true
	correct.reaction_time_ms = 5000.0
	correct.player_position = Vector3(1.0, 1.7, 2.0)
	correct.gaze_direction = Vector3(0.0, 0.0, -1.0)

	var correct_dict: Dictionary = correct.to_dict()
	assert_has(correct_dict, "hazard_id", "정답 dict에 hazard_id 존재")
	assert_has(correct_dict, "discovered", "정답 dict에 discovered 존재")
	assert_has(correct_dict, "reaction_time_ms", "정답 dict에 reaction_time_ms 존재")
	assert_has(correct_dict, "player_position", "정답 dict에 player_position 존재")

	# 오탐
	var fp := MarkingResult.new()
	fp.hazard_id = ""
	fp.player_position = Vector3(3.0, 1.7, -1.0)
	fp.gaze_direction = Vector3(0.5, 0.0, -0.866)

	var fp_dict: Dictionary = fp.to_dict()
	assert_has(fp_dict, "timestamp_ms", "오탐 dict에 timestamp_ms 존재")
	assert_has(fp_dict, "position", "오탐 dict에 position 존재")
	assert_has(fp_dict, "gaze_direction", "오탐 dict에 gaze_direction 존재")
	assert_does_not_have(fp_dict, "hazard_id", "오탐 dict에 hazard_id 미포함")


## TEST-SES-001-6: SessionData.get_elapsed_seconds 계산 검증
func test_session_elapsed_seconds() -> void:
	var session := SessionData.new()
	session.start_time = 1000000
	session.end_time = 1300000  # 300초(5분) 후

	assert_almost_eq(session.get_elapsed_seconds(), 300.0, 0.1, "300초 경과")


## TEST-SES-001-7: SessionData.get_avg_reaction_time_ms 계산 검증
func test_session_avg_reaction_time() -> void:
	var session := SessionData.new()

	var m1 := MarkingResult.new()
	m1.hazard_id = "h1"
	m1.is_correct = true
	m1.reaction_time_ms = 2000.0
	session.marking_results.append(m1)

	var m2 := MarkingResult.new()
	m2.hazard_id = "h2"
	m2.is_correct = true
	m2.reaction_time_ms = 4000.0
	session.marking_results.append(m2)

	assert_almost_eq(session.get_avg_reaction_time_ms(), 3000.0, 0.1, "평균 3000ms")

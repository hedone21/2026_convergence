extends GutTest

# ======================================
# SPEC-SCN-001: 시나리오 설정 파일 (JSON)
# ======================================
# ScenarioValidator 검증 로직, ScenarioData 파싱, ScenarioManager 로드를 검증한다.
# ScenarioValidator는 RefCounted로 씬 트리 없이 테스트 가능하다.


## TEST-SCN-001: ScenarioValidator는 RefCounted (Domain Layer 준수)
func test_scenario_validator_is_refcounted() -> void:
	var validator := ScenarioValidator.new()
	assert_true(validator is RefCounted, "ScenarioValidator는 RefCounted")
	assert_eq(validator.get_class(), "RefCounted", "base class는 RefCounted")


## TEST-SCN-001-2: 유효한 시나리오 데이터 — 검증 통과
func test_valid_scenario_passes_validation() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"scenario_id": "test_01",
		"site_type": "building_frame",
		"time_limit_seconds": 300,
		"random_placement": false,
		"hazards": [
			{
				"id": "crack_01",
				"type": "crack",
				"difficulty": 0.5,
				"position": [1.0, 2.0, 3.0],
			},
		],
	}
	var errors: Array[String] = validator.validate(data)
	assert_eq(errors.size(), 0, "유효한 시나리오 — 에러 없음")


## TEST-SCN-001-3: 필수 필드 누락 — scenario_id
func test_missing_scenario_id() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"site_type": "building_frame",
		"time_limit_seconds": 300,
	}
	var errors: Array[String] = validator.validate(data)
	assert_true(errors.size() > 0, "scenario_id 누락 시 에러 발생")
	var has_scenario_id_error: bool = false
	for err: String in errors:
		if "scenario_id" in err:
			has_scenario_id_error = true
			break
	assert_true(has_scenario_id_error, "에러 메시지에 scenario_id 포함")


## TEST-SCN-001-4: 필수 필드 누락 — site_type
func test_missing_site_type() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"scenario_id": "test_01",
		"time_limit_seconds": 300,
	}
	var errors: Array[String] = validator.validate(data)
	var has_site_type_error: bool = false
	for err: String in errors:
		if "site_type" in err:
			has_site_type_error = true
			break
	assert_true(has_site_type_error, "에러 메시지에 site_type 포함")


## TEST-SCN-001-5: 필수 필드 누락 — time_limit_seconds
func test_missing_time_limit() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"scenario_id": "test_01",
		"site_type": "building_frame",
	}
	var errors: Array[String] = validator.validate(data)
	var has_time_limit_error: bool = false
	for err: String in errors:
		if "time_limit_seconds" in err:
			has_time_limit_error = true
			break
	assert_true(has_time_limit_error, "에러 메시지에 time_limit_seconds 포함")


## TEST-SCN-001-6: 지원하지 않는 site_type
func test_invalid_site_type() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"scenario_id": "test_01",
		"site_type": "unknown_type",
		"time_limit_seconds": 300,
	}
	var errors: Array[String] = validator.validate(data)
	assert_true(errors.size() > 0, "지원하지 않는 site_type — 에러 발생")


## TEST-SCN-001-7: time_limit_seconds가 0 이하
func test_invalid_time_limit_zero() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"scenario_id": "test_01",
		"site_type": "building_frame",
		"time_limit_seconds": 0,
	}
	var errors: Array[String] = validator.validate(data)
	assert_true(errors.size() > 0, "time_limit_seconds=0 — 에러 발생")


## TEST-SCN-001-8: ScenarioData.from_dict() 정상 파싱
func test_scenario_data_from_dict() -> void:
	var data: Dictionary = {
		"scenario_id": "test_parse",
		"site_type": "building_frame",
		"time_limit_seconds": 180,
		"random_placement": false,
		"random_seed": 0,
		"hazards": [
			{
				"id": "crack_01",
				"type": "crack",
				"position": [1.0, 2.0, 3.0],
				"rotation": [0.0, 90.0, 0.0],
				"difficulty": 0.7,
				"params": {
					"length": 0.5,
					"width": 0.01,
					"branches": 2,
				},
			},
		],
	}

	var sd: ScenarioData = ScenarioData.from_dict(data)

	assert_eq(sd.scenario_id, "test_parse", "scenario_id 파싱")
	assert_eq(sd.site_type, "building_frame", "site_type 파싱")
	assert_eq(sd.time_limit_seconds, 180, "time_limit_seconds 파싱")
	assert_false(sd.random_placement, "random_placement 파싱")
	assert_eq(sd.hazards.size(), 1, "hazards 배열 크기")

	var hd: HazardData = sd.hazards[0]
	assert_eq(hd.hazard_id, "crack_01", "hazard id -> hazard_id 매핑")
	assert_eq(hd.hazard_type, "crack", "hazard type 파싱")
	assert_almost_eq(hd.difficulty, 0.7, 0.01, "difficulty 파싱")
	assert_almost_eq(hd.crack_length, 0.5, 0.01, "params.length -> crack_length 매핑")
	assert_almost_eq(hd.crack_width, 0.01, 0.001, "params.width -> crack_width 매핑")
	assert_eq(hd.crack_branches, 2, "params.branches -> crack_branches 매핑")


## TEST-SCN-001-9: ScenarioData.to_dict() 왕복 변환
func test_scenario_data_roundtrip() -> void:
	var original: Dictionary = {
		"scenario_id": "roundtrip_test",
		"site_type": "building_frame",
		"time_limit_seconds": 300,
		"random_placement": true,
		"random_seed": 42,
		"random_config": {
			"hazard_count": 5,
			"types": ["crack"],
			"min_spacing": 2.0,
			"difficulty_range": [0.1, 0.9],
		},
		"hazards": [],
	}

	var sd: ScenarioData = ScenarioData.from_dict(original)
	var exported: Dictionary = sd.to_dict()

	assert_eq(exported["scenario_id"], "roundtrip_test", "scenario_id 왕복")
	assert_eq(exported["site_type"], "building_frame", "site_type 왕복")
	assert_eq(exported["time_limit_seconds"], 300, "time_limit_seconds 왕복")
	assert_true(exported["random_placement"], "random_placement 왕복")
	assert_eq(exported["random_seed"], 42, "random_seed 왕복")


## TEST-SCN-001-10: mvp_easy.json 파일 파싱 — 모든 필수 필드 존재 및 유효
func test_mvp_easy_json_valid() -> void:
	var validator := ScenarioValidator.new()
	var path: String = "res://resources/scenarios/mvp_easy.json"

	assert_true(FileAccess.file_exists(path), "mvp_easy.json 존재")

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()

	assert_eq(err, OK, "JSON 파싱 성공")
	assert_true(json.data is Dictionary, "JSON 루트는 Dictionary")

	var errors: Array[String] = validator.validate(json.data as Dictionary)
	assert_eq(errors.size(), 0, "mvp_easy.json 검증 통과: %s" % str(errors))


## TEST-SCN-001-11: mvp_hard.json 파일 파싱 — 모든 필수 필드 존재 및 유효
func test_mvp_hard_json_valid() -> void:
	var validator := ScenarioValidator.new()
	var path: String = "res://resources/scenarios/mvp_hard.json"

	assert_true(FileAccess.file_exists(path), "mvp_hard.json 존재")

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()

	assert_eq(err, OK, "JSON 파싱 성공")

	var errors: Array[String] = validator.validate(json.data as Dictionary)
	assert_eq(errors.size(), 0, "mvp_hard.json 검증 통과: %s" % str(errors))


## TEST-SCN-001-12: mvp_test_01.json (랜덤 배치 모드) 파일 파싱
func test_mvp_test_01_json_valid() -> void:
	var validator := ScenarioValidator.new()
	var path: String = "res://resources/scenarios/mvp_test_01.json"

	assert_true(FileAccess.file_exists(path), "mvp_test_01.json 존재")

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()

	assert_eq(err, OK, "JSON 파싱 성공")

	var data: Dictionary = json.data as Dictionary
	assert_true(data.get("random_placement", false), "random_placement == true")
	assert_true(data.has("random_config"), "random_config 존재")

	var errors: Array[String] = validator.validate(data)
	assert_eq(errors.size(), 0, "mvp_test_01.json 검증 통과: %s" % str(errors))


## TEST-SCN-001-13: 빈 scenario_id 거부
func test_empty_scenario_id_rejected() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"scenario_id": "",
		"site_type": "building_frame",
		"time_limit_seconds": 300,
	}
	var errors: Array[String] = validator.validate(data)
	assert_true(errors.size() > 0, "빈 scenario_id — 에러 발생")


## TEST-SCN-001-14: hazards 배열 내 type 누락
func test_hazard_missing_type() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"scenario_id": "test_01",
		"site_type": "building_frame",
		"time_limit_seconds": 300,
		"random_placement": false,
		"hazards": [
			{
				"id": "crack_01",
				"position": [1.0, 2.0, 3.0],
			},
		],
	}
	var errors: Array[String] = validator.validate(data)
	var has_type_error: bool = false
	for err: String in errors:
		if "type" in err:
			has_type_error = true
			break
	assert_true(has_type_error, "type 누락 에러 포함")


## TEST-SCN-001-15: ScenarioManager Autoload 존재 확인
func test_scenario_manager_autoload() -> void:
	var manager: Node = get_node_or_null("/root/ScenarioManager")
	if manager == null:
		pending("ScenarioManager Autoload를 찾을 수 없음 (headless 환경)")
		return

	assert_true(manager.has_method("load_scenario"), "load_scenario 메서드 존재")
	assert_true(manager.has_method("load_default_scenario"), "load_default_scenario 메서드 존재")
	assert_true(manager.has_method("validate_scenario"), "validate_scenario 메서드 존재")
	assert_true(manager.has_method("generate_random_placement"), "generate_random_placement 메서드 존재")
	assert_true(manager.has_method("apply_scenario"), "apply_scenario 메서드 존재")
	assert_true(manager.has_signal("scenario_loaded"), "scenario_loaded 시그널 존재")
	assert_true(manager.has_signal("scenario_load_failed"), "scenario_load_failed 시그널 존재")
	assert_true(manager.has_signal("hazards_placed"), "hazards_placed 시그널 존재")


## TEST-SCN-001-16: ScenarioManager.load_scenario() — 존재하지 않는 파일
func test_load_nonexistent_file() -> void:
	var manager: Node = get_node_or_null("/root/ScenarioManager")
	if manager == null:
		pending("ScenarioManager Autoload를 찾을 수 없음")
		return

	watch_signals(manager)
	var result: Variant = manager.load_scenario("res://resources/scenarios/nonexistent.json")
	assert_null(result, "존재하지 않는 파일 → null 반환")
	assert_signal_emitted(manager, "scenario_load_failed", "scenario_load_failed 시그널 발행")
	assert_push_error("SPEC-SCN-001: 시나리오 파일을 찾을 수 없습니다: res://resources/scenarios/nonexistent.json",
		"push_error 발행 확인 (존재하지 않는 파일)")


## TEST-SCN-001-17: ScenarioManager.load_scenario() — 유효한 JSON 로드
func test_load_valid_scenario_file() -> void:
	var manager: Node = get_node_or_null("/root/ScenarioManager")
	if manager == null:
		pending("ScenarioManager Autoload를 찾을 수 없음")
		return

	watch_signals(manager)
	var result: Variant = manager.load_scenario("res://resources/scenarios/mvp_easy.json")
	assert_not_null(result, "유효한 파일 → ScenarioData 반환")
	assert_true(result is ScenarioData, "반환 타입은 ScenarioData")
	assert_signal_emitted(manager, "scenario_loaded", "scenario_loaded 시그널 발행")

	var sd: ScenarioData = result as ScenarioData
	assert_eq(sd.scenario_id, "mvp_easy", "scenario_id 일치")
	assert_eq(sd.hazards.size(), 3, "위험 요소 3개")

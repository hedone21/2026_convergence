extends GutTest

# ======================================
# SPEC-HAZ-002: 위험 요소 난이도 파라미터
# ======================================
# HazardRules.calculate_difficulty_visual_params() 순수 로직과
# HazardData 난이도 필드 클램프를 검증한다.
# HazardRules는 RefCounted로 씬 트리 없이 테스트 가능하다.


## TEST-HAZ-002: 난이도 0.0 ~ 1.0 범위 내 정상 값
func test_difficulty_normal_range() -> void:
	var rules := HazardRules.new()

	# 난이도 0.0 (매우 쉬움)
	var easy: Dictionary = rules.calculate_difficulty_visual_params(0.0)
	assert_almost_eq(easy["scale"], 1.5, 0.01, "난이도 0.0 → scale 1.5")
	assert_almost_eq(easy["opacity"], 1.0, 0.01, "난이도 0.0 → opacity 1.0")

	# 난이도 0.5 (중간)
	var mid: Dictionary = rules.calculate_difficulty_visual_params(0.5)
	assert_almost_eq(mid["scale"], 0.95, 0.01, "난이도 0.5 → scale 0.95")
	assert_almost_eq(mid["opacity"], 0.625, 0.01, "난이도 0.5 → opacity 0.625")

	# 난이도 1.0 (매우 어려움)
	var hard: Dictionary = rules.calculate_difficulty_visual_params(1.0)
	assert_almost_eq(hard["scale"], 0.4, 0.01, "난이도 1.0 → scale 0.4")
	assert_almost_eq(hard["opacity"], 0.25, 0.01, "난이도 1.0 → opacity 0.25")


## TEST-HAZ-002-2: 난이도 범위 밖 값 — 음수 → 0.0으로 클램프
func test_difficulty_clamp_negative() -> void:
	var rules := HazardRules.new()

	var neg: Dictionary = rules.calculate_difficulty_visual_params(-1.0)
	var zero: Dictionary = rules.calculate_difficulty_visual_params(0.0)

	assert_almost_eq(neg["scale"], zero["scale"], 0.01, "음수 난이도 → 0.0과 동일한 scale")
	assert_almost_eq(neg["opacity"], zero["opacity"], 0.01, "음수 난이도 → 0.0과 동일한 opacity")
	assert_almost_eq(neg["color_blend"], zero["color_blend"], 0.01, "음수 난이도 → 0.0과 동일한 color_blend")


## TEST-HAZ-002-3: 난이도 범위 밖 값 — 1.0 초과 → 1.0으로 클램프
func test_difficulty_clamp_over_one() -> void:
	var rules := HazardRules.new()

	var over: Dictionary = rules.calculate_difficulty_visual_params(2.0)
	var one: Dictionary = rules.calculate_difficulty_visual_params(1.0)

	assert_almost_eq(over["scale"], one["scale"], 0.01, "2.0 난이도 → 1.0과 동일한 scale")
	assert_almost_eq(over["opacity"], one["opacity"], 0.01, "2.0 난이도 → 1.0과 동일한 opacity")
	assert_almost_eq(over["color_blend"], one["color_blend"], 0.01, "2.0 난이도 → 1.0과 동일한 color_blend")


## TEST-HAZ-002-4: 난이도에 따른 시각적 차이 — 최솟값과 최댓값에서 구분 가능
func test_difficulty_visual_distinguishable() -> void:
	var rules := HazardRules.new()

	var easy: Dictionary = rules.calculate_difficulty_visual_params(0.0)
	var hard: Dictionary = rules.calculate_difficulty_visual_params(1.0)

	# 크기 차이가 있어야 함
	assert_true(easy["scale"] > hard["scale"], "쉬운 난이도가 어려운 난이도보다 큰 scale")
	assert_true(easy["scale"] - hard["scale"] > 0.5, "scale 차이가 0.5 이상으로 시각적 구분 가능")

	# 투명도 차이가 있어야 함
	assert_true(easy["opacity"] > hard["opacity"], "쉬운 난이도가 어려운 난이도보다 높은 opacity")
	assert_true(easy["opacity"] - hard["opacity"] > 0.3, "opacity 차이가 0.3 이상으로 시각적 구분 가능")

	# 색상 혼합도 차이
	assert_true(hard["color_blend"] > easy["color_blend"], "어려운 난이도가 배경과 더 유사")


## TEST-HAZ-002-5: HazardData.difficulty 범위 검증
func test_hazard_data_difficulty_range() -> void:
	var hd := HazardData.new()

	# 정상 범위
	hd.difficulty = 0.5
	assert_almost_eq(hd.difficulty, 0.5, 0.01, "difficulty 0.5 설정")

	hd.difficulty = 0.0
	assert_almost_eq(hd.difficulty, 0.0, 0.01, "difficulty 0.0 설정")

	hd.difficulty = 1.0
	assert_almost_eq(hd.difficulty, 1.0, 0.01, "difficulty 1.0 설정")


## TEST-HAZ-002-6: ScenarioValidator — hazards 배열 내 difficulty 범위 밖 값 검증
func test_validator_rejects_out_of_range_difficulty() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"scenario_id": "test_diff",
		"site_type": "building_frame",
		"time_limit_seconds": 300,
		"random_placement": false,
		"hazards": [
			{
				"id": "crack_01",
				"type": "crack",
				"difficulty": 1.5,
				"position": [1.0, 2.0, 3.0],
			},
		],
	}
	var errors: Array[String] = validator.validate(data)
	var has_diff_error: bool = false
	for err: String in errors:
		if "difficulty" in err:
			has_diff_error = true
			break
	assert_true(has_diff_error, "difficulty 1.5 → 범위 밖 에러")


## TEST-HAZ-002-7: ScenarioValidator — 음수 difficulty 거부
func test_validator_rejects_negative_difficulty() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"scenario_id": "test_diff_neg",
		"site_type": "building_frame",
		"time_limit_seconds": 300,
		"random_placement": false,
		"hazards": [
			{
				"id": "crack_01",
				"type": "crack",
				"difficulty": -0.5,
				"position": [1.0, 2.0, 3.0],
			},
		],
	}
	var errors: Array[String] = validator.validate(data)
	var has_diff_error: bool = false
	for err: String in errors:
		if "difficulty" in err:
			has_diff_error = true
			break
	assert_true(has_diff_error, "difficulty -0.5 → 범위 밖 에러")


## TEST-HAZ-002-8: random_config.difficulty_range 검증 — 정상
func test_validator_accepts_valid_difficulty_range() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"scenario_id": "test_rand_diff",
		"site_type": "building_frame",
		"time_limit_seconds": 300,
		"random_placement": true,
		"random_config": {
			"hazard_count": 3,
			"types": ["crack"],
			"min_spacing": 2.0,
			"difficulty_range": [0.2, 0.8],
		},
	}
	var errors: Array[String] = validator.validate(data)
	assert_eq(errors.size(), 0, "유효한 difficulty_range — 에러 없음: %s" % str(errors))


## TEST-HAZ-002-9: random_config.difficulty_range — min > max 거부
func test_validator_rejects_inverted_difficulty_range() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"scenario_id": "test_rand_diff_inv",
		"site_type": "building_frame",
		"time_limit_seconds": 300,
		"random_placement": true,
		"random_config": {
			"hazard_count": 3,
			"types": ["crack"],
			"difficulty_range": [0.9, 0.1],
		},
	}
	var errors: Array[String] = validator.validate(data)
	var has_range_error: bool = false
	for err: String in errors:
		if "difficulty_range" in err and "min" in err:
			has_range_error = true
			break
	assert_true(has_range_error, "difficulty_range min > max → 에러")


## TEST-HAZ-002-10: difficulty에 따른 비주얼 파라미터 연속성 (단조 감소)
func test_difficulty_visual_monotonic() -> void:
	var rules := HazardRules.new()

	var prev_scale: float = 999.0
	var prev_opacity: float = 999.0

	# 0.0부터 1.0까지 0.1 단위로 scale/opacity가 단조 감소
	var d: float = 0.0
	while d <= 1.0:
		var params: Dictionary = rules.calculate_difficulty_visual_params(d)
		assert_true(params["scale"] <= prev_scale, "d=%.1f: scale 단조 감소" % d)
		assert_true(params["opacity"] <= prev_opacity, "d=%.1f: opacity 단조 감소" % d)
		prev_scale = params["scale"]
		prev_opacity = params["opacity"]
		d += 0.1

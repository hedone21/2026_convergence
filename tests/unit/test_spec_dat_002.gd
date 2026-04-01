extends GutTest

# ======================================
# SPEC-DAT-002: 발견율 및 반응 시간 산출
# ======================================
# EvaluationService의 순수 계산 로직을 검증한다.
# EvaluationService는 RefCounted로 씬 트리 없이 테스트 가능하다.


## TEST-DAT-002: 발견율 계산 — 정상 케이스
func test_discovery_rate_normal() -> void:
	var svc := EvaluationService.new()

	var rate: float = svc.calculate_discovery_rate(2, 3)
	assert_almost_eq(rate, 66.7, 0.1, "2/3 = 66.7%")


## TEST-DAT-002-2: 발견율 — 전체 발견 (100%)
func test_discovery_rate_full() -> void:
	var svc := EvaluationService.new()

	var rate: float = svc.calculate_discovery_rate(5, 5)
	assert_almost_eq(rate, 100.0, 0.1, "5/5 = 100.0%")


## TEST-DAT-002-3: 발견율 — 미발견 (0%)
func test_discovery_rate_none() -> void:
	var svc := EvaluationService.new()

	var rate: float = svc.calculate_discovery_rate(0, 5)
	assert_almost_eq(rate, 0.0, 0.1, "0/5 = 0.0%")


## TEST-DAT-002-4: 발견율 — 1개 중 1개 (100%)
func test_discovery_rate_single() -> void:
	var svc := EvaluationService.new()

	var rate: float = svc.calculate_discovery_rate(1, 1)
	assert_almost_eq(rate, 100.0, 0.1, "1/1 = 100.0%")


## TEST-DAT-002-E: 발견율 — total이 0 (엣지 케이스)
func test_discovery_rate_zero_total() -> void:
	var svc := EvaluationService.new()

	var rate: float = svc.calculate_discovery_rate(0, 0)
	assert_almost_eq(rate, 0.0, 0.1, "0/0 = 0.0% (경고 로그)")


## TEST-DAT-002-E2: 발견율 — total이 음수 (방어적 처리)
func test_discovery_rate_negative_total() -> void:
	var svc := EvaluationService.new()

	var rate: float = svc.calculate_discovery_rate(1, -1)
	assert_almost_eq(rate, 0.0, 0.1, "음수 total → 0.0%")


## TEST-DAT-002-E3: 발견율 — discovered > total (비정상이지만 100% 클램프)
func test_discovery_rate_over_total() -> void:
	var svc := EvaluationService.new()

	var rate: float = svc.calculate_discovery_rate(5, 3)
	# 5/3*100 = 166.7이지만 clamp(0,100)에 의해 100.0
	assert_almost_eq(rate, 100.0, 0.1, "discovered > total → 100.0% 클램프")


## TEST-DAT-002-5: 개별 반응 시간 계산 — 정상
func test_reaction_time_normal() -> void:
	var svc := EvaluationService.new()

	var rt: float = svc.calculate_reaction_time(1000, 6000)
	assert_almost_eq(rt, 5000.0, 0.1, "6000 - 1000 = 5000ms")


## TEST-DAT-002-6: 개별 반응 시간 — 즉시 발견 (0ms)
func test_reaction_time_zero() -> void:
	var svc := EvaluationService.new()

	var rt: float = svc.calculate_reaction_time(5000, 5000)
	assert_almost_eq(rt, 0.0, 0.1, "동시 = 0ms")


## TEST-DAT-002-7: 개별 반응 시간 — 음수 보정
func test_reaction_time_negative_correction() -> void:
	var svc := EvaluationService.new()

	var rt: float = svc.calculate_reaction_time(6000, 1000)
	assert_almost_eq(rt, 0.0, 0.1, "음수 → 0.0ms 보정")


## TEST-DAT-002-8: 평균 반응 시간 — 정상
func test_avg_reaction_time_normal() -> void:
	var svc := EvaluationService.new()

	var times: Array = [1000.0, 2000.0, 3000.0]
	var avg: float = svc.calculate_avg_reaction_time(times)
	assert_almost_eq(avg, 2000.0, 0.1, "(1000+2000+3000)/3 = 2000ms")


## TEST-DAT-002-9: 평균 반응 시간 — 단일 값
func test_avg_reaction_time_single() -> void:
	var svc := EvaluationService.new()

	var times: Array = [5000.0]
	var avg: float = svc.calculate_avg_reaction_time(times)
	assert_almost_eq(avg, 5000.0, 0.1, "단일 값 = 5000ms")


## TEST-DAT-002-10: 평균 반응 시간 — 빈 배열 (엣지 케이스)
func test_avg_reaction_time_empty() -> void:
	var svc := EvaluationService.new()

	var times: Array = []
	var avg: float = svc.calculate_avg_reaction_time(times)
	assert_almost_eq(avg, 0.0, 0.1, "빈 배열 → 0.0ms")


## TEST-DAT-002-11: 평균 반응 시간 — 음수 값 무시
func test_avg_reaction_time_ignores_negative() -> void:
	var svc := EvaluationService.new()

	var times: Array = [1000.0, -500.0, 3000.0]
	var avg: float = svc.calculate_avg_reaction_time(times)
	# -500은 무시, (1000+3000)/2 = 2000
	assert_almost_eq(avg, 2000.0, 0.1, "음수 값 무시 → (1000+3000)/2")


## TEST-DAT-002-12: 평균 반응 시간 — 모두 음수 (엣지 케이스)
func test_avg_reaction_time_all_negative() -> void:
	var svc := EvaluationService.new()

	var times: Array = [-100.0, -200.0]
	var avg: float = svc.calculate_avg_reaction_time(times)
	assert_almost_eq(avg, 0.0, 0.1, "모두 음수 → 0.0ms")


## TEST-DAT-002-13: EvaluationService는 RefCounted (Domain 레이어 검증)
func test_evaluation_service_is_refcounted() -> void:
	var svc := EvaluationService.new()
	assert_true(svc is RefCounted, "EvaluationService는 RefCounted")
	# RefCounted는 Node가 될 수 없으므로 상속 체인 확인
	assert_eq(svc.get_class(), "RefCounted", "base class는 RefCounted")


## TEST-DAT-002-14: 발견율 소수점 1자리 반올림 (snappedf 0.1)
func test_discovery_rate_decimal_precision() -> void:
	var svc := EvaluationService.new()

	# 1/3 = 33.333...% → 33.3으로 반올림
	var rate: float = svc.calculate_discovery_rate(1, 3)
	assert_almost_eq(rate, 33.3, 0.1, "1/3 = 33.3%")

	# 1/6 = 16.666...% → 16.7로 반올림
	var rate2: float = svc.calculate_discovery_rate(1, 6)
	assert_almost_eq(rate2, 16.7, 0.1, "1/6 = 16.7%")


## TEST-DAT-002-15: EvaluationManager Autoload 기본 동작 확인
func test_evaluation_manager_autoload() -> void:
	var manager_node: Node = get_node_or_null("/root/EvaluationManager")
	if manager_node == null:
		pending("EvaluationManager Autoload를 찾을 수 없음 (headless 환경)")
		return

	assert_true(manager_node.has_method("start_evaluation"), "start_evaluation 메서드 존재")
	assert_true(manager_node.has_method("finalize_evaluation"), "finalize_evaluation 메서드 존재")
	assert_true(manager_node.has_method("get_discovery_rate"), "get_discovery_rate 메서드 존재")
	assert_true(manager_node.has_method("get_avg_reaction_time_ms"), "get_avg_reaction_time_ms 메서드 존재")
	assert_true(manager_node.has_method("get_reaction_time"), "get_reaction_time 메서드 존재")
	assert_true(manager_node.has_signal("evaluation_updated"), "evaluation_updated 시그널 존재")
	assert_true(manager_node.has_signal("evaluation_finalized"), "evaluation_finalized 시그널 존재")


## TEST-DAT-002-16: EvaluationManager.start_evaluation() → 초기화 확인
func test_evaluation_manager_start() -> void:
	var manager_node: Node = get_node_or_null("/root/EvaluationManager")
	if manager_node == null:
		pending("EvaluationManager Autoload를 찾을 수 없음")
		return

	manager_node.start_evaluation(5)
	assert_eq(manager_node.total_hazards, 5, "total_hazards == 5")
	assert_true(manager_node.session_start_time >= 0, "session_start_time >= 0")
	assert_almost_eq(manager_node.get_discovery_rate(), 0.0, 0.1, "초기 발견율 0%")


## TEST-DAT-002-17: 미발견 위험 요소의 반응 시간은 -1.0
func test_undiscovered_reaction_time() -> void:
	var manager_node: Node = get_node_or_null("/root/EvaluationManager")
	if manager_node == null:
		pending("EvaluationManager Autoload를 찾을 수 없음")
		return

	manager_node.start_evaluation(3)
	var rt: float = manager_node.get_reaction_time("nonexistent_hazard")
	assert_almost_eq(rt, -1.0, 0.01, "미발견 위험 요소 반응 시간 == -1.0")

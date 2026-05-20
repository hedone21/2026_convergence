extends GutTest

# ======================================
# SPEC-DAT-002 (보강): 세션 채점 — SessionScorer
# ======================================
# precision/recall/F1, miss/FP, 평균 식별 시간 산출 알고리즘 검증.


## TEST-DAT-002-S1: 완벽 매칭 — 1 hazard + 1 가까운 marking → F1=1.0
func test_perfect_match() -> void:
	var hazards: Array = [
		{"id": "h1", "position": Vector3(0, 0, 0), "type": "crack"},
	]
	var markings: Array = [
		{"position": Vector3(0.5, 0, 0), "timestamp_ms": 5000, "category": "crack"},
	]
	var r: SessionScorer.ScoreResult = SessionScorer.score(hazards, markings, 0)

	assert_eq(r.true_positives, 1, "TP=1")
	assert_eq(r.false_positives, 0, "FP=0")
	assert_eq(r.false_negatives, 0, "FN=0")
	assert_almost_eq(r.precision, 1.0, 0.001, "Precision=1.0")
	assert_almost_eq(r.recall, 1.0, 0.001, "Recall=1.0")
	assert_almost_eq(r.f1, 1.0, 0.001, "F1=1.0")
	assert_almost_eq(r.avg_time_to_detect_ms, 5000.0, 0.001, "Avg TTD=5000ms")


## TEST-DAT-002-S2: miss + FP — 거리 멀고 false_positive 카테고리 → F1=0
func test_miss_and_false_positive() -> void:
	var hazards: Array = [
		{"id": "h1", "position": Vector3(0, 0, 0), "type": "crack"},
	]
	var markings: Array = [
		# 거리 5m → 임계 2m 초과 → 매칭 안 됨 = FP
		{"position": Vector3(5, 0, 0), "timestamp_ms": 1000, "category": "crack"},
		# 명시적 false_positive → FP
		{"position": Vector3(0.1, 0, 0), "timestamp_ms": 2000, "category": "false_positive"},
	]
	var r: SessionScorer.ScoreResult = SessionScorer.score(hazards, markings, 0)

	assert_eq(r.true_positives, 0, "TP=0")
	assert_eq(r.false_positives, 2, "FP=2 (먼 marking + false_positive 카테고리)")
	assert_eq(r.false_negatives, 1, "FN=1 (h1 미식별)")
	assert_almost_eq(r.precision, 0.0, 0.001, "Precision=0")
	assert_almost_eq(r.recall, 0.0, 0.001, "Recall=0")
	assert_almost_eq(r.f1, 0.0, 0.001, "F1=0")

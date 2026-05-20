class_name SessionScorer
extends RefCounted

## SPEC-DAT-002 (보강): 세션 채점 시스템
##
## 실제 hazard 위치와 사용자 마킹(HazardMarkPlaced)을 거리 임계(2m)로 매칭하여
## precision/recall/F1, miss/false-positive, 평균 식별 시간을 산출한다.
##
## EvaluationManager(실시간 discovery_rate/reaction)와 별개로 사후 채점 도구 역할.
## 도메인 로직은 static으로 노출하여 헤드리스 단위 테스트 가능.

const MATCH_DISTANCE_M: float = 2.0


## 매칭 결과 단일 행.
class MatchPair extends RefCounted:
	var hazard_id: String = ""
	var hazard_position: Vector3 = Vector3.ZERO
	var marking_position: Vector3 = Vector3.ZERO
	var distance_m: float = 0.0
	var time_to_detect_ms: int = 0


## 채점 산출 결과.
class ScoreResult extends RefCounted:
	var precision: float = 0.0
	var recall: float = 0.0
	var f1: float = 0.0
	var true_positives: int = 0
	var false_positives: int = 0
	var false_negatives: int = 0  # missed hazards
	var avg_time_to_detect_ms: float = 0.0
	var matched_pairs: Array = []


## SPEC-DAT-002: 세션 채점.
## hazards: Array of Dictionary { "id": String, "position": Vector3, "type": String }
## markings: Array of Dictionary { "position": Vector3, "timestamp_ms": int, "category": String }
## session_start_ts: ms, 평균 식별 시간 계산 기준점
## match_dist: 매칭 임계 거리 (기본 2m)
## 반환: ScoreResult
static func score(
	hazards: Array,
	markings: Array,
	session_start_ts: int = 0,
	match_dist: float = MATCH_DISTANCE_M,
) -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	var used_marking: Array[bool] = []
	used_marking.resize(markings.size())
	used_marking.fill(false)

	# 각 hazard에 대해 가장 가까운 미사용 marking을 매칭 (greedy)
	var detect_times: Array[int] = []
	for hz: Dictionary in hazards:
		var best_idx: int = -1
		var best_dist: float = match_dist + 1.0
		var h_pos: Vector3 = hz.get("position", Vector3.ZERO)
		var h_type: String = hz.get("type", "")
		for i: int in range(markings.size()):
			if used_marking[i]:
				continue
			var m: Dictionary = markings[i]
			var m_cat: String = m.get("category", "")
			if m_cat == "false_positive":
				continue
			# 카테고리가 명시되었으면 일치 요구. "" 또는 동일 type만 허용.
			if m_cat != "" and m_cat != h_type:
				continue
			var d: float = h_pos.distance_to(m.get("position", Vector3.ZERO))
			if d < match_dist and d < best_dist:
				best_dist = d
				best_idx = i
		if best_idx >= 0:
			used_marking[best_idx] = true
			result.true_positives += 1
			var m: Dictionary = markings[best_idx]
			var pair: MatchPair = MatchPair.new()
			pair.hazard_id = hz.get("id", "")
			pair.hazard_position = h_pos
			pair.marking_position = m.get("position", Vector3.ZERO)
			pair.distance_m = best_dist
			pair.time_to_detect_ms = int(m.get("timestamp_ms", 0)) - session_start_ts
			result.matched_pairs.append(pair)
			detect_times.append(pair.time_to_detect_ms)
		else:
			result.false_negatives += 1

	# 사용되지 않은 marking은 모두 FP (false_positive 카테고리 포함)
	for i: int in range(markings.size()):
		if not used_marking[i]:
			result.false_positives += 1

	var p_denom: int = result.true_positives + result.false_positives
	var r_denom: int = result.true_positives + result.false_negatives
	result.precision = float(result.true_positives) / float(p_denom) if p_denom > 0 else 0.0
	result.recall = float(result.true_positives) / float(r_denom) if r_denom > 0 else 0.0
	var f_denom: float = result.precision + result.recall
	result.f1 = (2.0 * result.precision * result.recall / f_denom) if f_denom > 0.0 else 0.0

	if not detect_times.is_empty():
		var s: int = 0
		for t: int in detect_times:
			s += t
		result.avg_time_to_detect_ms = float(s) / float(detect_times.size())

	return result

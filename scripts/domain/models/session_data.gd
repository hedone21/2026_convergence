class_name SessionData
extends Resource

## SPEC-DAT-001: 세션 전체 결과 데이터 모델
## 한 세션에 대한 모든 정보(피험자, 시나리오, 결과)를 담는다.
## SessionLogger가 이 객체를 직렬화하여 JSON/CSV로 저장한다.

@export var session_id: String = ""
@export var subject: SubjectData = null
@export var scenario_id: String = ""
@export var site_type: String = ""

## Unix epoch 밀리초
@export var start_time: int = 0
@export var end_time: int = 0

@export var time_limit_seconds: int = 300
@export var end_reason: String = ""

## 위험 요소 마킹 결과 배열 (정답 + 오탐 모두 포함)
@export var marking_results: Array[MarkingResult] = []

## 시나리오에 존재하는 전체 위험 요소 수
@export var total_hazards: int = 0


func get_elapsed_seconds() -> float:
	if start_time <= 0 or end_time <= 0:
		return 0.0
	return float(end_time - start_time) / 1000.0


func get_discovered_hazards() -> int:
	var count: int = 0
	for result: MarkingResult in marking_results:
		if result.is_correct and not result.is_false_positive():
			count += 1
	return count


func get_false_positives() -> Array[MarkingResult]:
	var fps: Array[MarkingResult] = []
	for result: MarkingResult in marking_results:
		if result.is_false_positive():
			fps.append(result)
	return fps


func get_hazard_results() -> Array[MarkingResult]:
	var hrs: Array[MarkingResult] = []
	for result: MarkingResult in marking_results:
		if not result.is_false_positive():
			hrs.append(result)
	return hrs


func get_discovery_rate_percent() -> float:
	if total_hazards <= 0:
		return 0.0
	return float(get_discovered_hazards()) / float(total_hazards) * 100.0


func get_avg_reaction_time_ms() -> float:
	var total: float = 0.0
	var count: int = 0
	for result: MarkingResult in marking_results:
		if result.is_correct and not result.is_false_positive() and result.reaction_time_ms >= 0.0:
			total += result.reaction_time_ms
			count += 1
	if count == 0:
		return 0.0
	return total / float(count)

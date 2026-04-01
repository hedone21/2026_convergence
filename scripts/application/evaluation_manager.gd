extends Node

## SPEC-DAT-002: 발견율 및 반응 시간 산출
##
## EvaluationManager Autoload — 발견율, 반응 시간 실시간 산출, 평가 결과 생성
## 순수 계산은 Domain의 EvaluationService에 위임한다.
## HazardManager의 hazard_discovered 시그널을 구독하여 반응 시간을 기록한다.

## SPEC-DAT-002: 평가 데이터가 업데이트됨
signal evaluation_updated(discovery_rate: float, avg_reaction_ms: float)

## SPEC-DAT-002: 세션 종료 시 최종 평가 확정
signal evaluation_finalized(discovery_rate: float, avg_reaction_ms: float, reaction_times: Dictionary)

## 세션 시작 시각 (Time.get_ticks_msec 기준)
var session_start_time: int = -1

## {hazard_id: reaction_time_ms} — 발견된 위험 요소별 반응 시간
var reaction_times: Dictionary = {}

## 전체 위험 요소 수 (HazardManager에서 참조)
var total_hazards: int = 0

## Domain 서비스 인스턴스
var _eval_service: EvaluationService = EvaluationService.new()

## 현재 발견율 (캐시)
var _current_discovery_rate: float = 0.0

## 현재 평균 반응 시간 (캐시)
var _current_avg_reaction_ms: float = 0.0


func _ready() -> void:
	# HazardManager의 시그널 구독 (deferred — Autoload 로드 순서 보장)
	call_deferred("_connect_signals")
	print("[EvaluationManager] Initialized.")


## SPEC-DAT-002: 평가를 시작한다 (세션 시작 시 호출).
func start_evaluation(hazard_count: int) -> void:
	session_start_time = Time.get_ticks_msec()
	total_hazards = hazard_count
	reaction_times.clear()
	_current_discovery_rate = 0.0
	_current_avg_reaction_ms = 0.0
	print("[EvaluationManager] Evaluation started. Total hazards: %d" % total_hazards)


## SPEC-DAT-002: 평가를 종료하고 최종 결과를 발행한다.
func finalize_evaluation() -> void:
	_update_metrics()
	evaluation_finalized.emit(
		_current_discovery_rate,
		_current_avg_reaction_ms,
		reaction_times.duplicate()
	)
	print("[EvaluationManager] Evaluation finalized. Rate: %.1f%%, Avg reaction: %.1f ms" % [
		_current_discovery_rate, _current_avg_reaction_ms
	])


## SPEC-DAT-002: 현재 발견율을 반환한다 (0.0 ~ 100.0, 소수점 1자리).
func get_discovery_rate() -> float:
	return _current_discovery_rate


## SPEC-DAT-002: 현재 평균 반응 시간을 반환한다 (ms).
func get_avg_reaction_time_ms() -> float:
	return _current_avg_reaction_ms


## SPEC-DAT-002: 특정 위험 요소의 반응 시간을 반환한다 (ms).
## 미발견이면 -1.0을 반환한다.
func get_reaction_time(hazard_id: String) -> float:
	return reaction_times.get(hazard_id, -1.0)


## SPEC-DAT-002: 모든 반응 시간 사본을 반환한다.
func get_all_reaction_times() -> Dictionary:
	return reaction_times.duplicate()


## 시그널 연결 (deferred)
func _connect_signals() -> void:
	if HazardManager.hazard_discovered.is_connected(_on_hazard_discovered):
		return
	HazardManager.hazard_discovered.connect(_on_hazard_discovered)
	HazardManager.all_hazards_discovered.connect(_on_all_hazards_discovered)


## SPEC-DAT-002: 위험 요소 발견 핸들러 — 반응 시간 기록
func _on_hazard_discovered(hazard: BaseHazard) -> void:
	if session_start_time < 0:
		push_warning("SPEC-DAT-002: 세션이 시작되지 않은 상태에서 위험 요소가 발견되었습니다.")
		return

	var discovery_time: int = Time.get_ticks_msec()
	var reaction_ms: float = _eval_service.calculate_reaction_time(
		session_start_time, discovery_time
	)

	reaction_times[hazard.hazard_id] = reaction_ms
	_update_metrics()

	evaluation_updated.emit(_current_discovery_rate, _current_avg_reaction_ms)
	print("[EvaluationManager] Hazard '%s' discovered. Reaction: %.1f ms, Rate: %.1f%%" % [
		hazard.hazard_id, reaction_ms, _current_discovery_rate
	])


## 모든 위험 요소 발견 핸들러
func _on_all_hazards_discovered() -> void:
	_update_metrics()
	print("[EvaluationManager] All hazards discovered! Final rate: %.1f%%" % _current_discovery_rate)


## 지표를 재계산한다.
func _update_metrics() -> void:
	var discovered: int = reaction_times.size()
	_current_discovery_rate = _eval_service.calculate_discovery_rate(discovered, total_hazards)

	var times_array: Array = reaction_times.values()
	_current_avg_reaction_ms = _eval_service.calculate_avg_reaction_time(times_array)

class_name EvaluationService
extends RefCounted

## SPEC-DAT-002: 발견율 및 반응 시간 산출 — 순수 계산 로직
##
## Godot 노드를 상속하지 않는 순수 GDScript 클래스.
## EvaluationManager(Application)가 이 서비스에 계산을 위임한다.
## 유닛 테스트가 씬 트리 없이 가능하도록 설계되었다.


## SPEC-DAT-002: 발견율 산출
## discovered: 발견한 위험 요소 수, total: 전체 위험 요소 수
## 반환: 0.0 ~ 100.0 (소수점 1자리)
## total이 0이면 0.0을 반환하고 경고 로그를 출력한다.
func calculate_discovery_rate(discovered: int, total: int) -> float:
	if total <= 0:
		push_warning("SPEC-DAT-002: 전체 위험 요소 수가 0입니다. 발견율을 0.0%로 반환합니다.")
		return 0.0

	var rate: float = float(discovered) / float(total) * 100.0
	# 0~100 범위 클램프 (방어적 처리)
	rate = clampf(rate, 0.0, 100.0)
	# 소수점 1자리로 반올림
	return snappedf(rate, 0.1)


## SPEC-DAT-002: 개별 반응 시간 산출 (밀리초)
## start_ms: 세션 시작 시각 (Unix epoch ms 또는 ticks_msec)
## discovery_ms: 위험 요소 발견 시각
## 반환: 반응 시간 (ms). 음수가 되면 0.0을 반환한다.
func calculate_reaction_time(start_ms: int, discovery_ms: int) -> float:
	var reaction: float = float(discovery_ms - start_ms)
	if reaction < 0.0:
		push_warning("SPEC-DAT-002: 반응 시간이 음수입니다 (start=%d, discovery=%d). 0.0으로 보정합니다." % [start_ms, discovery_ms])
		return 0.0
	return reaction


## SPEC-DAT-002: 평균 반응 시간 산출 (밀리초)
## times: 개별 반응 시간 배열 (float, ms 단위)
## 빈 배열이면 0.0을 반환한다.
func calculate_avg_reaction_time(times: Array) -> float:
	if times.is_empty():
		return 0.0

	var total: float = 0.0
	var count: int = 0
	for t: float in times:
		if t >= 0.0:
			total += t
			count += 1

	if count == 0:
		return 0.0

	return total / float(count)

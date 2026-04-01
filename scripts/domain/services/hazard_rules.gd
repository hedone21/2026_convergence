class_name HazardRules
extends RefCounted

## SPEC-HAZ-001, SPEC-HAZ-002: 위험 요소 판정 규칙
##
## Godot 노드를 상속하지 않는 순수 GDScript 클래스.
## 탐지 범위 판정, 난이도에 따른 비주얼 파라미터 산출 등
## 위험 요소 관련 도메인 규칙을 캡슐화한다.
## HazardManager(Application)와 BaseHazard(Presentation)가 이 규칙을 참조한다.


## 플레이어-위험요소 간 탐지 범위 판정
## 두 위치 간 유클리드 거리가 range 이내이면 true
func is_within_detection_range(player_pos: Vector3, hazard_pos: Vector3, detection_range: float) -> bool:
	var distance: float = player_pos.distance_to(hazard_pos)
	return distance <= detection_range


## SPEC-HAZ-002: 난이도에 따른 비주얼 파라미터 산출
## difficulty: 0.0 (매우 쉬움) ~ 1.0 (매우 어려움)
## 반환 Dictionary:
##   "scale": float — 크랙 크기 배율 (높은 난이도 → 작은 크랙)
##   "opacity": float — 불투명도 (높은 난이도 → 더 투명)
##   "color_blend": float — 배경색 혼합도 (높은 난이도 → 배경과 유사)
func calculate_difficulty_visual_params(difficulty: float) -> Dictionary:
	# 난이도를 0~1 범위로 클램프
	var d: float = clampf(difficulty, 0.0, 1.0)

	# 쉬운 난이도: 크고 선명 / 어려운 난이도: 작고 희미
	var scale: float = lerpf(1.5, 0.4, d)
	var opacity: float = lerpf(1.0, 0.25, d)
	var color_blend: float = lerpf(0.0, 0.7, d)

	return {
		"scale": scale,
		"opacity": opacity,
		"color_blend": color_blend,
	}

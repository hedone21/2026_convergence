class_name BaseSite
extends Node3D

## SPEC-ENV-001, SPEC-ENV-003: 현장 추상 베이스 클래스
##
## 모든 건설 현장 유형의 공통 인터페이스를 정의한다.
## 새로운 현장 유형(터널, 교량 등)은 이 클래스를 상속하여 추가한다.
## SOLID O/L: 기존 코드 수정 없이 서브클래스 추가로 확장 가능.


## 위험 요소를 배치할 수 있는 유효 표면 목록을 반환한다.
## 각 표면은 Dictionary: { "node": Node3D, "surface_type": String, "aabb": AABB }
func get_valid_surfaces() -> Array:
	push_error("BaseSite.get_valid_surfaces() must be overridden")
	return []


## 위험 요소 배치가 가능한 전체 영역(바운딩 박스)을 반환한다.
func get_spawn_bounds() -> AABB:
	push_error("BaseSite.get_spawn_bounds() must be overridden")
	return AABB()


## 현장 유형 식별 문자열을 반환한다. (예: "building_frame", "tunnel")
func get_site_type() -> String:
	push_error("BaseSite.get_site_type() must be overridden")
	return ""

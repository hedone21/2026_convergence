class_name BaseSite
extends Node3D

## Decal 투영 분리용 visibility layer 비트.
## floor mesh는 1 | FLOOR_DECAL_LAYER를 layers로 설정.
## floor 전용 Decal은 cull_mask = FLOOR_DECAL_LAYER 단독 → wall/ceiling 투영 차단.
const FLOOR_DECAL_LAYER: int = 1 << 10  ## bit 10 (1024)

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


## 위치가 벽/기둥 등 구조물 안에 있어서 spawn 차단해야 하는지.
## 기본 false. 회전된 OBB 검사가 필요한 site에서 override.
func is_position_blocked(_pos: Vector3) -> bool:
	return false


## 플레이어가 spawn해야 할 시작 지점 (정문 안쪽 등).
## 기본 (0, 0, 0). 사이트별로 정문 위치를 계산하여 override.
## 반환: site 로컬 좌표 Vector3. y는 floor 위(예: 0.0).
func get_start_position() -> Vector3:
	return Vector3.ZERO


## 시작 시 플레이어가 바라봐야 할 방향 (radians, Y축 회전).
## 기본 0.0. 정문에서 건물 내부를 향하도록 site별 override.
func get_start_rotation_y() -> float:
	return 0.0

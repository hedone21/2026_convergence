class_name RigInterface
extends Node3D

## SPEC-VR-001, SPEC-VR-002: 리그 공통 인터페이스 (추상 베이스)
## VR 리그와 데스크톱 리그 모두 이 인터페이스를 구현하여
## GameManager가 구체 타입에 의존하지 않고 교체 가능하게 한다.

## 마킹 요청 시그널 — ray_origin과 ray_direction을 전달
signal mark_requested(ray_origin: Vector3, ray_direction: Vector3)


## 현재 활성 카메라를 반환한다.
func get_camera() -> Camera3D:
	push_error("RigInterface.get_camera() must be overridden")
	return null


## 마킹 레이의 시작점을 반환한다.
func get_ray_origin() -> Vector3:
	push_error("RigInterface.get_ray_origin() must be overridden")
	return Vector3.ZERO


## 마킹 레이의 방향 벡터를 반환한다.
func get_ray_direction() -> Vector3:
	push_error("RigInterface.get_ray_direction() must be overridden")
	return Vector3.FORWARD


## 플레이어의 현재 월드 위치를 반환한다.
func get_player_position() -> Vector3:
	push_error("RigInterface.get_player_position() must be overridden")
	return Vector3.ZERO


## 이동 입력을 적용한다. dir은 정규화된 방향, delta는 프레임 시간.
func apply_movement(dir: Vector3, delta: float) -> void:
	push_error("RigInterface.apply_movement() must be overridden")

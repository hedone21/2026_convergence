class_name MarkingSystem
extends Node

## SPEC-INP-002: 컨트롤러 버튼 마킹
##
## 레이캐스트 기반 마킹 시스템.
## 카메라/컨트롤러에서 전방으로 광선을 발사하여
## 위험 요소(BaseHazard) 적중 여부를 판별한다.
## 마킹 성공 시 mark_succeeded, 실패 시 mark_failed 시그널을 발행한다.

## SPEC-INP-002: 마킹 성공 — 위험 요소 적중
signal mark_succeeded(hazard: BaseHazard, hit_position: Vector3)

## SPEC-INP-002: 마킹 실패 — 오탐 (위험 요소 미적중)
signal mark_failed(hit_position: Vector3, ray_direction: Vector3)

## SPEC-INP-002: 마킹 피드백 트리거
signal mark_feedback(success: bool)

## SPEC-INP-002: 최대 탐지 거리 (기본 50m)
@export var max_distance: float = 50.0

## 마킹 레이 전용 충돌 마스크 (BaseHazard의 collision_layer와 일치)
## 비트 5 = 레이어 6 (값 32)
const HAZARD_RAY_MASK: int = 32

## 레이 시각화 on/off (연구 목적에 따라 토글)
var ray_visible: bool = false


## SPEC-INP-002: 마킹을 수행한다.
## origin: 광선 시작점 (카메라/컨트롤러 위치)
## direction: 광선 방향 벡터
## 물리 공간에서 직접 raycast를 수행하여 결과를 판별한다.
func perform_mark(origin: Vector3, direction: Vector3) -> void:
	var space_state: PhysicsDirectSpaceState3D = _get_space_state()
	if space_state == null:
		push_error("SPEC-INP-002: PhysicsDirectSpaceState3D를 가져올 수 없습니다.")
		return

	var normalized_dir: Vector3 = direction.normalized()
	var end_point: Vector3 = origin + normalized_dir * max_distance

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, end_point
	)
	# 위험 요소 레이어만 감지 + 일반 물리 레이어도 감지 (오탐 위치 파악)
	query.collision_mask = HAZARD_RAY_MASK | 1  # 레이어 1 (일반) + 레이어 6 (위험 요소)
	query.collide_with_areas = true  # Area3D(BaseHazard) 감지
	query.collide_with_bodies = true  # StaticBody3D(환경) 감지

	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		# 아무것도 적중하지 않음 — 허공 마킹 (오탐)
		var end_pos: Vector3 = end_point
		mark_failed.emit(end_pos, normalized_dir)
		mark_feedback.emit(false)
		return

	var collider: Object = result.get("collider")
	var hit_position: Vector3 = result.get("position", Vector3.ZERO)

	# 적중 대상이 BaseHazard인지 확인
	if collider is BaseHazard:
		var hazard: BaseHazard = collider as BaseHazard
		mark_succeeded.emit(hazard, hit_position)
		mark_feedback.emit(true)
	else:
		# 위험 요소가 아닌 곳 적중 — 오탐
		mark_failed.emit(hit_position, normalized_dir)
		mark_feedback.emit(false)


## 레이 시각화를 on/off한다.
func set_ray_visible(visible: bool) -> void:
	ray_visible = visible


## PhysicsDirectSpaceState3D를 가져온다.
func _get_space_state() -> PhysicsDirectSpaceState3D:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	var world: World3D = viewport.world_3d
	if world == null:
		return null
	return world.direct_space_state

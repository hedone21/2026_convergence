class_name BaseHazard
extends Area3D

## SPEC-HAZ-001: 위험 요소 기본 시스템 — 추상 베이스
##
## 모든 위험 요소 유형(크랙, 부식, 누수 등)의 공통 인터페이스를 정의한다.
## Area3D를 상속하여 탐지 가능 영역(CollisionShape3D)을 가지며,
## 마킹 레이와 충돌 판정을 수행한다.
##
## SOLID O/L: 새 위험 요소 유형 추가 시 이 클래스를 상속하여 확장.
## SOLID L: 서브클래스(CrackHazard 등)가 BaseHazard 자리에 투명 교체 가능.

## 위험 요소 상태 열거형
enum HazardState {
	UNDISCOVERED,  ## 미발견 상태 (초기)
	DISCOVERED,    ## 발견 상태
}

## SPEC-HAZ-001: 발견 상태 변경 시 발행
signal state_changed(new_state: HazardState)

## 위험 요소 고유 ID
@export var hazard_id: String = ""

## 위험 요소 유형 (예: "crack", "corrosion", "leak")
@export var hazard_type: String = ""

## 난이도 (0.0 ~ 1.0)
@export var difficulty: float = 0.5

## 현재 상태
var state: HazardState = HazardState.UNDISCOVERED

## 마킹 레이 전용 충돌 레이어 (비트 5 = 레이어 6)
## 마킹 레이의 collision_mask가 이 레이어와 일치해야 탐지됨
const HAZARD_COLLISION_LAYER: int = 32  # 비트 5 (2^5 = 32)


func _ready() -> void:
	# 일반 물리 충돌은 받지 않고, 마킹 레이 전용 레이어만 설정
	collision_layer = HAZARD_COLLISION_LAYER
	collision_mask = 0  # Area3D 자체는 다른 것과 충돌하지 않음
	monitorable = true
	monitoring = false

	_apply_difficulty()


## SPEC-HAZ-001: 위험 요소를 발견 상태로 전환한다.
## 이미 발견된 상태이면 중복 처리하지 않는다.
## 반환: 상태가 실제로 변경되었으면 true
func discover() -> bool:
	if state == HazardState.DISCOVERED:
		return false

	state = HazardState.DISCOVERED
	_show_discovered_feedback()
	state_changed.emit(HazardState.DISCOVERED)
	return true


## SPEC-HAZ-001: 발견 여부를 반환한다.
func is_discovered() -> bool:
	return state == HazardState.DISCOVERED


## SPEC-HAZ-001: HazardData를 구성하여 반환한다.
func get_hazard_data() -> HazardData:
	var data: HazardData = HazardData.new()
	data.hazard_id = hazard_id
	data.hazard_type = hazard_type
	data.difficulty = difficulty
	data.position = global_position
	data.rotation_degrees = rotation_degrees
	return data


## HazardData로부터 속성을 설정한다.
func apply_hazard_data(data: HazardData) -> void:
	hazard_id = data.hazard_id
	hazard_type = data.hazard_type
	difficulty = data.difficulty
	position = data.position
	rotation_degrees = data.rotation_degrees
	_apply_difficulty()


## 가상 메서드: 난이도에 따른 비주얼 조정 (서브클래스에서 오버라이드)
func _apply_difficulty() -> void:
	pass


## 가상 메서드: 발견 시 시각적 피드백 (서브클래스에서 오버라이드)
func _show_discovered_feedback() -> void:
	# 기본 구현: 발견 인디케이터 노드가 있으면 활성화
	var indicator: Node3D = get_node_or_null("DiscoveredIndicator")
	if indicator != null:
		indicator.visible = true

class_name HazardData
extends Resource

## SPEC-HAZ-001: 위험 요소 데이터 모델
## 위험 요소 하나의 설정 데이터를 담는 Resource.
## 시나리오 JSON에서 파싱되거나, 런타임에서 직접 생성하여 HazardManager에 전달한다.

## 위험 요소 고유 ID (예: "crack_01")
@export var hazard_id: String = ""

## 위험 요소 유형 (예: "crack", "corrosion", "leak")
@export var hazard_type: String = "crack"

## 난이도 (0.0 = 매우 쉬움 ~ 1.0 = 매우 어려움)
@export var difficulty: float = 0.5

## 배치 위치 (월드 좌표)
@export var position: Vector3 = Vector3.ZERO

## 배치 회전 (오일러 각, 도 단위)
@export var rotation_degrees: Vector3 = Vector3.ZERO

## 크랙 전용 파라미터 — 길이 (미터)
@export var crack_length: float = 1.0

## 크랙 전용 파라미터 — 폭 (미터)
@export var crack_width: float = 0.02

## 크랙 전용 파라미터 — 분기 수
@export var crack_branches: int = 2


func to_dict() -> Dictionary:
	return {
		"hazard_id": hazard_id,
		"type": hazard_type,
		"difficulty": difficulty,
		"position": [position.x, position.y, position.z],
		"rotation_degrees": [rotation_degrees.x, rotation_degrees.y, rotation_degrees.z],
		"crack_length": crack_length,
		"crack_width": crack_width,
		"crack_branches": crack_branches,
	}


static func from_dict(data: Dictionary) -> HazardData:
	var hd: HazardData = HazardData.new()
	hd.hazard_id = data.get("hazard_id", "")
	hd.hazard_type = data.get("type", "crack")
	hd.difficulty = data.get("difficulty", 0.5)

	var pos: Array = data.get("position", [0.0, 0.0, 0.0])
	if pos.size() >= 3:
		hd.position = Vector3(pos[0], pos[1], pos[2])

	var rot: Array = data.get("rotation_degrees", [0.0, 0.0, 0.0])
	if rot.size() >= 3:
		hd.rotation_degrees = Vector3(rot[0], rot[1], rot[2])

	hd.crack_length = data.get("crack_length", 1.0)
	hd.crack_width = data.get("crack_width", 0.02)
	hd.crack_branches = data.get("crack_branches", 2)
	return hd

class_name MarkingResult
extends Resource

## SPEC-DAT-001: 위험 요소 마킹 결과 데이터 모델
## 하나의 마킹 시도(성공/오탐)에 대한 기록을 담는다.
## hazard_id가 빈 문자열이면 오탐(false positive)을 나타낸다.

@export var hazard_id: String = ""
@export var hazard_type: String = ""
@export var hazard_difficulty: float = 0.0
@export var is_correct: bool = false
@export var timestamp: int = 0
@export var player_position: Vector3 = Vector3.ZERO
@export var gaze_direction: Vector3 = Vector3.FORWARD
## -1이면 미측정 (미발견 위험 요소)
@export var reaction_time_ms: float = -1.0


func is_false_positive() -> bool:
	return hazard_id.is_empty()


func to_dict() -> Dictionary:
	if is_false_positive():
		return {
			"timestamp_ms": timestamp,
			"position": [player_position.x, player_position.y, player_position.z],
			"gaze_direction": [gaze_direction.x, gaze_direction.y, gaze_direction.z],
		}

	var pos_val = [player_position.x, player_position.y, player_position.z] \
		if reaction_time_ms >= 0.0 else null
	var gaze_val = [gaze_direction.x, gaze_direction.y, gaze_direction.z] \
		if reaction_time_ms >= 0.0 else null

	return {
		"hazard_id": hazard_id,
		"type": hazard_type,
		"difficulty": hazard_difficulty,
		"discovered": is_correct,
		"reaction_time_ms": reaction_time_ms,
		"discovery_timestamp_ms": timestamp if is_correct else -1,
		"player_position": pos_val,
		"gaze_direction": gaze_val,
	}

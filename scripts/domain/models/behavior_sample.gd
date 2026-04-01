class_name BehaviorSample
extends Resource

## SPEC-DAT-004: 사용자 행동 샘플 데이터 모델
##
## 위치 샘플, 시선 샘플, 오탐 샘플 하나를 담는 Resource.
## BehaviorLogger가 버퍼에 이 객체 배열을 누적하고 flush 시 CSV로 변환한다.

## 샘플 유형 열거형
enum SampleType {
	POSITION,       ## 이동 경로 샘플 (x, y, z 유효, dir_* 비어있음)
	GAZE,           ## 시선 샘플 (dir_x, dir_y, dir_z 유효, x/y/z 비어있음)
	FALSE_POSITIVE, ## 오탐 샘플 (x, y, z 및 dir_x, dir_y, dir_z 모두 유효)
}

## SPEC-DAT-003 호환: Unix epoch 밀리초 기반 절대 타임스탬프
@export var epoch_ms: int = 0

## 샘플 유형
@export var sample_type: SampleType = SampleType.POSITION

## 위치 좌표 (POSITION / FALSE_POSITIVE 전용)
@export var position: Vector3 = Vector3.ZERO

## 방향 벡터 (GAZE / FALSE_POSITIVE 전용)
@export var direction: Vector3 = Vector3.ZERO


## CSV 행 문자열을 반환한다.
## 형식: epoch_ms,sample_type,x,y,z,dir_x,dir_y,dir_z
func to_csv_row() -> String:
	var type_str: String = _type_to_string()

	match sample_type:
		SampleType.POSITION:
			return "%d,%s,%.4f,%.4f,%.4f,,," % [
				epoch_ms, type_str,
				position.x, position.y, position.z,
			]
		SampleType.GAZE:
			return "%d,%s,,,,%.4f,%.4f,%.4f" % [
				epoch_ms, type_str,
				direction.x, direction.y, direction.z,
			]
		SampleType.FALSE_POSITIVE:
			return "%d,%s,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f" % [
				epoch_ms, type_str,
				position.x, position.y, position.z,
				direction.x, direction.y, direction.z,
			]
		_:
			return "%d,%s,,,,,," % [epoch_ms, type_str]


## 유형 문자열 반환
func _type_to_string() -> String:
	match sample_type:
		SampleType.POSITION:
			return "position"
		SampleType.GAZE:
			return "gaze"
		SampleType.FALSE_POSITIVE:
			return "false_positive"
		_:
			return "unknown"


## 위치 샘플 팩토리 메서드
static func make_position(pos: Vector3, ts: int) -> BehaviorSample:
	var s: BehaviorSample = BehaviorSample.new()
	s.epoch_ms = ts
	s.sample_type = SampleType.POSITION
	s.position = pos
	return s


## 시선 샘플 팩토리 메서드
static func make_gaze(dir: Vector3, ts: int) -> BehaviorSample:
	var s: BehaviorSample = BehaviorSample.new()
	s.epoch_ms = ts
	s.sample_type = SampleType.GAZE
	s.direction = dir
	return s


## 오탐 샘플 팩토리 메서드
static func make_false_positive(pos: Vector3, dir: Vector3, ts: int) -> BehaviorSample:
	var s: BehaviorSample = BehaviorSample.new()
	s.epoch_ms = ts
	s.sample_type = SampleType.FALSE_POSITIVE
	s.position = pos
	s.direction = dir
	return s

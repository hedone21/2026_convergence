class_name GazeTracker
extends Node

## SPEC-INP-003: 화면 중심 기반 시선 추적
## 카메라의 전방 벡터(forward vector)를 시선 방향으로 간주하고,
## 설정된 샘플링 주기마다 방향 벡터와 타임스탬프를 gaze_sampled 시그널로 발행한다.
## HMD 내장 eye tracker 연동은 향후 확장 예정 (요구사항 10절).

## SPEC-INP-003: 매 샘플링 주기마다 시선 방향과 타임스탬프(Unix ms)를 전달
signal gaze_sampled(direction: Vector3, timestamp: int)

## SPEC-INP-003: 샘플링 주기 (기본 100ms, @export로 인스펙터에서 변경 가능)
@export var sample_interval_ms: float = 100.0

var _is_tracking: bool = false
var _camera_ref: Camera3D = null

## 마지막 샘플 발행 이후 경과한 시간(ms)
var _elapsed_ms: float = 0.0


## SPEC-INP-003: 추적을 시작한다. camera가 null이면 에러를 출력하고 추적을 활성화하지 않는다.
func start_tracking(camera: Camera3D) -> void:
	if camera == null:
		push_error("SPEC-INP-003: GazeTracker.start_tracking — camera 인자가 null입니다. 시선 추적을 시작할 수 없습니다.")
		return

	_camera_ref = camera
	_is_tracking = true
	_elapsed_ms = 0.0


## SPEC-INP-003: 추적을 중단한다.
func stop_tracking() -> void:
	_is_tracking = false
	_camera_ref = null


## SPEC-INP-003: 현재 시선 방향(카메라 전방 벡터)을 반환한다.
## 추적 중이 아니거나 카메라가 준비되지 않았으면 Vector3.ZERO를 반환한다.
func get_current_gaze() -> Vector3:
	if not _is_tracking or _camera_ref == null:
		return Vector3.ZERO
	## 카메라의 로컬 -Z 축이 전방 방향 (Godot 3D 좌표계)
	return -_camera_ref.global_transform.basis.z


## 매 프레임마다 샘플링 주기를 누적하고 주기 도달 시 gaze_sampled를 발행한다
func _process(delta: float) -> void:
	if not _is_tracking or _camera_ref == null:
		return

	## SPEC-INP-003: 카메라가 씬 트리에서 제거된 경우 에러 로그 출력 후 추적 비활성화
	if not is_instance_valid(_camera_ref):
		push_error("SPEC-INP-003: GazeTracker — 카메라 참조가 유효하지 않습니다. 시선 추적을 중단합니다.")
		stop_tracking()
		return

	_elapsed_ms += delta * 1000.0

	if _elapsed_ms >= sample_interval_ms:
		_elapsed_ms -= sample_interval_ms
		_emit_sample()


## 현재 프레임의 시선 방향과 타임스탬프를 시그널로 발행한다
func _emit_sample() -> void:
	var direction: Vector3 = -_camera_ref.global_transform.basis.z
	## SPEC-INP-003: 타임스탬프는 Unix epoch 밀리초 (EEG 동기화용, SPEC-DAT-003 참조)
	## BUG-003 수정: Time.get_ticks_msec()는 상대 시간 → Unix epoch ms로 교체
	var timestamp: int = int(Time.get_unix_time_from_system() * 1000)
	gaze_sampled.emit(direction, timestamp)

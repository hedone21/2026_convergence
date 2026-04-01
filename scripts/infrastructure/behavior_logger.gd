class_name BehaviorLogger
extends Node

## SPEC-DAT-004: 사용자 행동 로깅 (이동 경로, 시선, 오탐)
##
## 세션 중 사용자의 이동 경로(200ms 간격), 시선 방향, 오탐을 수집하여
## 인메모리 버퍼에 누적하고 주기적으로 CSV 파일에 flush한다.
##
## CSV 형식: epoch_ms,sample_type,x,y,z,dir_x,dir_y,dir_z
## 저장 경로 예: data/sessions/{subject_id}_{timestamp}_behavior.csv
##
## SPEC-DAT-004 대안 동작:
## - 성능 문제 발생 시(버퍼 크기 임계치 초과) 샘플링 주기를 자동으로 2배로 늘림.

## 버퍼 크기가 이 임계치를 초과하면 샘플링 주기를 2배로 조정
const BUFFER_OVERFLOW_THRESHOLD: int = 2000

## 이동 샘플링 주기 기본값 (ms) — SPEC-DAT-004: 기본 200ms
@export var position_sample_interval_ms: float = 200.0

## 시선 샘플링 주기 기본값 (ms) — GazeTracker의 gaze_sampled 시그널 구독으로 수신
## (BehaviorLogger는 GazeTracker 시그널을 직접 구독하므로 별도 주기 관리 불필요)
## record_gaze()를 외부에서 직접 호출할 때만 의미 있음
@export var gaze_sample_interval_ms: float = 100.0

## 로깅 활성화 여부
var _is_logging: bool = false

## 인메모리 버퍼
var _buffer: Array[BehaviorSample] = []

## 저장 파일 경로 (flush 대상)
var _log_path: String = ""

## 이동 샘플링용 누적 경과 시간 (ms)
var _position_elapsed_ms: float = 0.0

## 플레이어 노드 참조 (이동 경로 주기 샘플링용)
var _player_ref: Node3D = null

## 현재 position 샘플링 주기 (성능 조정 시 2배로 변경됨)
var _current_position_interval: float = 200.0


## SPEC-DAT-004: 로깅을 시작한다.
## player가 null이면 위치 샘플링을 비활성화하고 경고를 출력한다.
func start_logging(player: Node3D = null) -> void:
	_player_ref = player
	if player == null:
		push_warning("SPEC-DAT-004: BehaviorLogger.start_logging() — player가 null입니다. 위치 샘플링이 비활성화됩니다.")

	_is_logging = true
	_position_elapsed_ms = 0.0
	_current_position_interval = position_sample_interval_ms


## SPEC-DAT-004: 로깅을 중단한다. 버퍼는 유지되며 save_behavior_log() 전까지 보관된다.
func stop_logging() -> void:
	_is_logging = false
	_player_ref = null


## SPEC-DAT-004: 위치 샘플을 버퍼에 추가한다.
## timestamp: Unix epoch 밀리초 (SPEC-DAT-003 호환)
func record_position(pos: Vector3, timestamp: int) -> void:
	if not _is_logging:
		return
	_buffer.append(BehaviorSample.make_position(pos, timestamp))
	_check_buffer_overflow()


## SPEC-DAT-004: 시선 방향 샘플을 버퍼에 추가한다.
## timestamp: Unix epoch 밀리초 (SPEC-DAT-003 호환)
func record_gaze(direction: Vector3, timestamp: int) -> void:
	if not _is_logging:
		return
	_buffer.append(BehaviorSample.make_gaze(direction, timestamp))
	_check_buffer_overflow()


## SPEC-DAT-004: 오탐(위험 요소가 아닌 곳 마킹) 샘플을 버퍼에 추가한다.
## timestamp: Unix epoch 밀리초 (SPEC-DAT-003 호환)
func record_false_positive(pos: Vector3, dir: Vector3, timestamp: int) -> void:
	# 오탐은 로깅 비활성화 상태에서도 기록 (세션 종료 직후 마킹 등 엣지 케이스 대비)
	_buffer.append(BehaviorSample.make_false_positive(pos, dir, timestamp))


## SPEC-DAT-004: 버퍼를 _log_path에 flush한다.
## 파일이 없으면 헤더를 포함하여 새로 생성하고, 있으면 끝에 추가(append)한다.
## flush 후 버퍼를 비운다.
func flush_buffer() -> void:
	if _buffer.is_empty():
		return

	if _log_path.is_empty():
		push_warning("SPEC-DAT-004: BehaviorLogger.flush_buffer() — 저장 경로가 설정되지 않았습니다. set_log_path()를 먼저 호출하세요.")
		return

	_ensure_dir(_log_path.get_base_dir())

	var need_header: bool = not FileAccess.file_exists(_log_path)

	var file: FileAccess = FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_log_path, FileAccess.WRITE)

	if file == null:
		push_error("SPEC-DAT-004: BehaviorLogger.flush_buffer() — 파일 열기 실패 (%s): %s" % [
			_log_path, error_string(FileAccess.get_open_error())
		])
		return

	if need_header:
		file.store_line("epoch_ms,sample_type,x,y,z,dir_x,dir_y,dir_z")
	else:
		file.seek_end()

	for sample: BehaviorSample in _buffer:
		file.store_line(sample.to_csv_row())

	file.close()
	_buffer.clear()


## 주기적 flush를 위해 저장 경로를 사전에 설정한다.
func set_log_path(path: String) -> void:
	_log_path = path


## SPEC-DAT-004: 남은 버퍼를 모두 flush하고 지정 경로에 최종 저장한다.
func save_behavior_log(path: String) -> void:
	_log_path = path
	flush_buffer()


## _process: 플레이어 위치 주기 샘플링
func _process(delta: float) -> void:
	if not _is_logging or _player_ref == null:
		return

	if not is_instance_valid(_player_ref):
		push_error("SPEC-DAT-004: BehaviorLogger — 플레이어 참조가 유효하지 않습니다. 위치 샘플링을 중단합니다.")
		_player_ref = null
		return

	_position_elapsed_ms += delta * 1000.0
	if _position_elapsed_ms >= _current_position_interval:
		_position_elapsed_ms -= _current_position_interval
		var ts: int = int(Time.get_unix_time_from_system() * 1000)
		record_position(_player_ref.global_position, ts)


## 버퍼 오버플로우 감지 — SPEC-DAT-004 대안 동작
func _check_buffer_overflow() -> void:
	if _buffer.size() > BUFFER_OVERFLOW_THRESHOLD:
		# 배치 쓰기로 전환하여 IO 부하 분산
		flush_buffer()
		# 샘플링 주기를 2배로 늘려 성능 보호
		if _current_position_interval < position_sample_interval_ms * 4.0:
			_current_position_interval *= 2.0
			push_warning("SPEC-DAT-004: BehaviorLogger — 버퍼 임계치 초과, 위치 샘플링 주기를 %.0fms로 조정했습니다." % _current_position_interval)


## 내부: 디렉토리가 없으면 생성한다.
func _ensure_dir(dir_path: String) -> void:
	if dir_path.is_empty():
		return
	if DirAccess.dir_exists_absolute(dir_path):
		return
	var err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		push_error("SPEC-DAT-004: BehaviorLogger — 디렉토리 생성 실패 (%s): %s" % [
			dir_path, error_string(err)
		])

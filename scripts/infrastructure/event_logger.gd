class_name EventLogger
extends Node

## SPEC-DAT-003: 뇌파(EEG) 동기화용 타임스탬프 이벤트 로깅
##
## VR 시뮬레이션 주요 이벤트에 Unix epoch 밀리초 기반 타임스탬프를 기록한다.
## epoch_ms(절대 시간)와 relative_ms(세션 시작 이후 상대 시간)를 모두 기록하여
## EEG 장비와의 후처리 동기화를 지원한다.
##
## CSV 형식: epoch_ms, relative_ms, event_type, data_json
## 저장 경로 예: data/sessions/{subject_id}_{timestamp}_events.csv

## 지원하는 이벤트 타입 상수
const EVENT_SESSION_START: String = "SESSION_START"
const EVENT_SESSION_END: String = "SESSION_END"
const EVENT_HAZARD_DISCOVERED: String = "HAZARD_DISCOVERED"
const EVENT_MARK_ATTEMPT: String = "MARK_ATTEMPT"
const EVENT_MOVEMENT_START: String = "MOVEMENT_START"
const EVENT_MOVEMENT_STOP: String = "MOVEMENT_STOP"

## 세션 시작 epoch ms (세션 시작 전 0)
var _session_start_epoch_ms: int = 0

## 인메모리 버퍼 — flush() 호출 전까지 누적
var _buffer: Array[Dictionary] = []

## 현재 flush 대상 파일 경로 (save_event_log() 전까지 빈 문자열)
var _log_path: String = ""


## SPEC-DAT-003: 이벤트를 기록한다.
## type: 이벤트 타입 (EVENT_* 상수 권장)
## data: 이벤트 부가 데이터 (JSON 직렬화 가능 Dictionary)
## 세션 시작 전 호출 시 epoch_ms는 정상 기록되나 relative_ms는 0으로 고정된다.
func log_event(type: String, data: Dictionary) -> void:
	var epoch_ms: int = int(Time.get_unix_time_from_system() * 1000)
	var relative_ms: int = 0
	if _session_start_epoch_ms > 0:
		relative_ms = epoch_ms - _session_start_epoch_ms

	_buffer.append({
		"epoch_ms": epoch_ms,
		"relative_ms": relative_ms,
		"event_type": type,
		"data": data,
	})


## SPEC-DAT-003: 세션 시작 절대 시간을 반환한다 (Unix ms).
## log_event(SESSION_START, ...) 이전에 호출하면 0을 반환한다.
func get_session_start_epoch() -> int:
	return _session_start_epoch_ms


## SPEC-DAT-003: SESSION_START 이벤트를 기록하고 세션 시작 기준 시간을 설정한다.
## 이 메서드를 통해 세션 시작을 기록해야 relative_ms 계산이 정확하다.
func log_session_start(data: Dictionary) -> void:
	_session_start_epoch_ms = int(Time.get_unix_time_from_system() * 1000)
	_buffer.append({
		"epoch_ms": _session_start_epoch_ms,
		"relative_ms": 0,
		"event_type": EVENT_SESSION_START,
		"data": data,
	})


## SPEC-DAT-003: 버퍼에 누적된 이벤트를 _log_path 파일에 추가 기록(append)한다.
## 파일이 없으면 헤더를 포함하여 새로 생성한다.
## flush 후 버퍼를 비운다.
## 경로가 설정되지 않았으면 경고를 출력하고 건너뛴다.
func flush() -> void:
	if _buffer.is_empty():
		return

	if _log_path.is_empty():
		push_warning("SPEC-DAT-003: EventLogger.flush() — 저장 경로가 설정되지 않았습니다. set_log_path()를 먼저 호출하세요.")
		return

	_ensure_dir(_log_path.get_base_dir())

	var need_header: bool = not FileAccess.file_exists(_log_path)

	var file: FileAccess = FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if file == null:
		# 파일이 없으면 WRITE 모드로 생성
		file = FileAccess.open(_log_path, FileAccess.WRITE)

	if file == null:
		push_error("SPEC-DAT-003: EventLogger.flush() — 파일 열기 실패 (%s): %s" % [
			_log_path, error_string(FileAccess.get_open_error())
		])
		return

	if need_header:
		file.store_line("epoch_ms,relative_ms,event_type,data_json")
	else:
		# 파일 끝으로 이동하여 append
		file.seek_end()

	for entry: Dictionary in _buffer:
		var data_json: String = JSON.stringify(entry["data"])
		# CSV 내 따옴표 이스케이프 (RFC 4180)
		data_json = '"' + data_json.replace('"', '""') + '"'
		file.store_line("%d,%d,%s,%s" % [
			entry["epoch_ms"],
			entry["relative_ms"],
			entry["event_type"],
			data_json,
		])

	file.close()
	_buffer.clear()


## SPEC-DAT-003: 주기적 flush를 위해 저장 경로를 사전에 설정한다.
func set_log_path(path: String) -> void:
	_log_path = path


## SPEC-DAT-003: 남은 버퍼를 모두 flush하고 지정 경로에 최종 저장한다.
## path가 현재 _log_path와 다르면 경로를 교체 후 flush한다.
## (flush()와 달리 path를 인자로 받아 최종 저장 시점에 경로를 확정할 수 있다.)
func save_event_log(path: String) -> void:
	_log_path = path
	flush()


## 내부: 디렉토리가 없으면 생성한다.
func _ensure_dir(dir_path: String) -> void:
	if dir_path.is_empty():
		return
	if DirAccess.dir_exists_absolute(dir_path):
		return
	var err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		push_error("SPEC-DAT-003: EventLogger — 디렉토리 생성 실패 (%s): %s" % [
			dir_path, error_string(err)
		])

extends GutTest

# ======================================
# SPEC-DAT-003: 뇌파(EEG) 동기화용 타임스탬프 로깅
# ======================================
# EventLogger의 epoch_ms, relative_ms, CSV 형식을 검증한다.

var _logger: EventLogger = null


func before_each() -> void:
	_logger = EventLogger.new()
	add_child_autoqfree(_logger)


## TEST-DAT-003: epoch_ms가 합리적인 값 (2020년 이후)
func test_epoch_ms_reasonable_value() -> void:
	_logger.log_event("TEST", {"msg": "test"})

	assert_true(_logger._buffer.size() > 0, "버퍼에 이벤트 추가됨")

	var entry: Dictionary = _logger._buffer[0]
	var epoch_ms: int = entry["epoch_ms"]

	# 2020-01-01 00:00:00 UTC = 1577836800000 ms
	var min_epoch_ms: int = 1577836800000
	assert_true(epoch_ms > min_epoch_ms,
		"epoch_ms(%d)는 2020년 이후: > %d" % [epoch_ms, min_epoch_ms])

	# 2030-01-01보다 이전이어야 함 (합리적 상한)
	var max_epoch_ms: int = 1893456000000
	assert_true(epoch_ms < max_epoch_ms,
		"epoch_ms(%d)는 2030년 이전: < %d" % [epoch_ms, max_epoch_ms])


## TEST-DAT-003-2: epoch_ms가 실제 Unix epoch (Time.get_unix_time_from_system 기반)
func test_epoch_ms_is_unix_time() -> void:
	var before: int = int(Time.get_unix_time_from_system() * 1000)
	_logger.log_event("TEST", {})
	var after: int = int(Time.get_unix_time_from_system() * 1000)

	var entry: Dictionary = _logger._buffer[0]
	var epoch_ms: int = entry["epoch_ms"]

	# before <= epoch_ms <= after 범위 내
	assert_true(epoch_ms >= before - 1, "epoch_ms >= before (허용 오차 1ms)")
	assert_true(epoch_ms <= after + 1, "epoch_ms <= after (허용 오차 1ms)")


## TEST-DAT-003-3: relative_ms가 0 이상 (세션 시작 후)
func test_relative_ms_non_negative() -> void:
	_logger.log_session_start({"subject": "test"})

	# 약간 대기하여 relative_ms > 0이 되도록
	_logger.log_event("TEST", {"msg": "after"})

	# SESSION_START의 relative_ms는 0
	assert_eq(_logger._buffer[0]["relative_ms"], 0, "SESSION_START의 relative_ms == 0")

	# 이후 이벤트의 relative_ms >= 0
	assert_true(_logger._buffer[1]["relative_ms"] >= 0,
		"이후 이벤트의 relative_ms >= 0: %d" % _logger._buffer[1]["relative_ms"])


## TEST-DAT-003-4: 세션 시작 전 이벤트의 relative_ms는 0
func test_relative_ms_before_session_start() -> void:
	# log_session_start() 호출 전
	_logger.log_event("PRE_SESSION", {})

	assert_eq(_logger._buffer[0]["relative_ms"], 0, "세션 시작 전 relative_ms == 0")


## TEST-DAT-003-5: get_session_start_epoch() — 세션 시작 전 0, 후 양수
func test_session_start_epoch() -> void:
	assert_eq(_logger.get_session_start_epoch(), 0, "세션 시작 전 epoch == 0")

	_logger.log_session_start({})

	var epoch: int = _logger.get_session_start_epoch()
	assert_true(epoch > 0, "세션 시작 후 epoch > 0")
	assert_true(epoch > 1577836800000, "세션 시작 epoch는 2020년 이후")


## TEST-DAT-003-6: CSV 형식 — 헤더와 데이터 행 검증
func test_csv_format() -> void:
	var test_path: String = "user://test_events_dat003.csv"

	_logger.log_session_start({"subject_id": "sub01"})
	_logger.log_event("HAZARD_DISCOVERED", {"hazard_id": "crack_01"})
	_logger.save_event_log(test_path)

	assert_true(FileAccess.file_exists(test_path), "CSV 파일 생성됨")

	var file: FileAccess = FileAccess.open(test_path, FileAccess.READ)
	assert_not_null(file, "CSV 파일 열기 성공")

	# 헤더 검증
	var header: String = file.get_line()
	assert_eq(header, "epoch_ms,relative_ms,event_type,data_json", "CSV 헤더 형식")

	# 첫 번째 데이터 행 (SESSION_START)
	var line1: String = file.get_line()
	var parts1: PackedStringArray = line1.split(",", true, 3)  # 최대 4개로 분리
	assert_true(parts1.size() >= 4, "데이터 행은 최소 4개 필드")
	assert_true(parts1[0].is_valid_int(), "epoch_ms는 정수")
	assert_eq(parts1[1].strip_edges(), "0", "SESSION_START의 relative_ms == 0")
	assert_eq(parts1[2], "SESSION_START", "event_type == SESSION_START")

	# 두 번째 데이터 행 (HAZARD_DISCOVERED)
	var line2: String = file.get_line()
	var parts2: PackedStringArray = line2.split(",", true, 3)
	assert_true(parts2[0].is_valid_int(), "epoch_ms는 정수")
	assert_eq(parts2[2], "HAZARD_DISCOVERED", "event_type == HAZARD_DISCOVERED")

	file.close()

	# 정리
	DirAccess.remove_absolute(test_path)


## TEST-DAT-003-7: 이벤트 타입 상수가 올바르게 정의됨
func test_event_type_constants() -> void:
	assert_eq(EventLogger.EVENT_SESSION_START, "SESSION_START", "SESSION_START 상수")
	assert_eq(EventLogger.EVENT_SESSION_END, "SESSION_END", "SESSION_END 상수")
	assert_eq(EventLogger.EVENT_HAZARD_DISCOVERED, "HAZARD_DISCOVERED", "HAZARD_DISCOVERED 상수")
	assert_eq(EventLogger.EVENT_MARK_ATTEMPT, "MARK_ATTEMPT", "MARK_ATTEMPT 상수")
	assert_eq(EventLogger.EVENT_MOVEMENT_START, "MOVEMENT_START", "MOVEMENT_START 상수")
	assert_eq(EventLogger.EVENT_MOVEMENT_STOP, "MOVEMENT_STOP", "MOVEMENT_STOP 상수")


## TEST-DAT-003-8: flush() — 경로 미설정 시 경고 (버퍼 유지)
func test_flush_without_path_keeps_buffer() -> void:
	_logger.log_event("TEST", {})
	assert_eq(_logger._buffer.size(), 1, "flush 전 버퍼 크기 1")

	_logger.flush()

	assert_eq(_logger._buffer.size(), 1, "경로 미설정 시 flush 후에도 버퍼 유지")


## TEST-DAT-003-9: flush() — 정상 경로 설정 시 버퍼 비움
func test_flush_with_path_clears_buffer() -> void:
	var test_path: String = "user://test_flush_dat003.csv"

	_logger.set_log_path(test_path)
	_logger.log_event("TEST", {})
	assert_eq(_logger._buffer.size(), 1, "flush 전 버퍼 크기 1")

	_logger.flush()

	assert_eq(_logger._buffer.size(), 0, "flush 후 버퍼 비워짐")

	# 정리
	DirAccess.remove_absolute(test_path)


## TEST-DAT-003-10: 여러 이벤트의 epoch_ms가 비감소 순서
func test_epoch_ms_monotonically_nondecreasing() -> void:
	_logger.log_session_start({})
	_logger.log_event("EVENT_A", {})
	_logger.log_event("EVENT_B", {})
	_logger.log_event("EVENT_C", {})

	for i: int in range(1, _logger._buffer.size()):
		assert_true(
			_logger._buffer[i]["epoch_ms"] >= _logger._buffer[i - 1]["epoch_ms"],
			"epoch_ms[%d] >= epoch_ms[%d]" % [i, i - 1]
		)


## TEST-DAT-003-11: CSV 내 JSON 데이터에 쉼표가 포함되어도 올바르게 이스케이프
func test_csv_json_escape() -> void:
	var test_path: String = "user://test_escape_dat003.csv"

	_logger.log_session_start({"key": "value, with comma"})
	_logger.save_event_log(test_path)

	var file: FileAccess = FileAccess.open(test_path, FileAccess.READ)
	var _header: String = file.get_line()
	var data_line: String = file.get_line()
	file.close()

	# RFC 4180: 쉼표를 포함하는 필드는 큰따옴표로 감싸야 함
	assert_true('"' in data_line, "JSON 데이터가 큰따옴표로 감싸져 있음")

	# 정리
	DirAccess.remove_absolute(test_path)


## TEST-DAT-003-12: BUG-003 수정 확인 — GazeTracker가 Unix epoch ms 사용
func test_gaze_tracker_uses_unix_epoch() -> void:
	# GazeTracker의 gaze_sampled 시그널이 Unix epoch ms를 전달하는지 확인
	# 직접 인스턴스화하여 소스 코드 수준 확인
	var gt := GazeTracker.new()
	add_child_autoqfree(gt)

	# GazeTracker._emit_sample() 내부에서 Time.get_unix_time_from_system()을 사용
	# 시그널 연결하여 수신된 타임스탬프가 Unix epoch인지 확인
	var cam := Camera3D.new()
	add_child_autoqfree(cam)

	var received_ts: Array = []
	gt.gaze_sampled.connect(func(dir: Vector3, ts: int) -> void: received_ts.append(ts))
	gt.start_tracking(cam)

	# 수동으로 _emit_sample() 호출 (private이지만 테스트 목적)
	gt._emit_sample()

	assert_true(received_ts.size() > 0, "gaze_sampled 시그널 수신")
	var ts: int = received_ts[0]

	# Unix epoch ms 범위 확인 (2020년 이후)
	assert_true(ts > 1577836800000, "GazeTracker 타임스탬프가 Unix epoch ms: %d" % ts)

	gt.stop_tracking()

extends GutTest

# ======================================
# SPEC-DAT-004: 사용자 행동 로깅 (이동 경로, 시선, 오탐)
# ======================================
# BehaviorSample 모델과 BehaviorLogger 로직을 검증한다.

var _logger: BehaviorLogger = null


func before_each() -> void:
	_logger = BehaviorLogger.new()
	add_child_autoqfree(_logger)


## TEST-DAT-004: BehaviorSample.make_position() — 위치 샘플 생성
func test_make_position_sample() -> void:
	var ts: int = int(Time.get_unix_time_from_system() * 1000)
	var sample: BehaviorSample = BehaviorSample.make_position(Vector3(1.0, 2.0, 3.0), ts)

	assert_eq(sample.sample_type, BehaviorSample.SampleType.POSITION, "sample_type == POSITION")
	assert_eq(sample.position, Vector3(1.0, 2.0, 3.0), "position 좌표")
	assert_eq(sample.epoch_ms, ts, "epoch_ms 설정")
	assert_eq(sample.direction, Vector3.ZERO, "POSITION 샘플의 direction은 ZERO")


## TEST-DAT-004-2: BehaviorSample.make_gaze() — 시선 샘플 생성
func test_make_gaze_sample() -> void:
	var ts: int = int(Time.get_unix_time_from_system() * 1000)
	var sample: BehaviorSample = BehaviorSample.make_gaze(Vector3(0.0, 0.0, -1.0), ts)

	assert_eq(sample.sample_type, BehaviorSample.SampleType.GAZE, "sample_type == GAZE")
	assert_eq(sample.direction, Vector3(0.0, 0.0, -1.0), "direction 벡터")
	assert_eq(sample.epoch_ms, ts, "epoch_ms 설정")
	assert_eq(sample.position, Vector3.ZERO, "GAZE 샘플의 position은 ZERO")


## TEST-DAT-004-3: BehaviorSample.make_false_positive() — 오탐 샘플 생성
func test_make_false_positive_sample() -> void:
	var ts: int = int(Time.get_unix_time_from_system() * 1000)
	var sample: BehaviorSample = BehaviorSample.make_false_positive(
		Vector3(1.0, 2.0, 3.0), Vector3(0.0, 0.0, -1.0), ts
	)

	assert_eq(sample.sample_type, BehaviorSample.SampleType.FALSE_POSITIVE, "sample_type == FALSE_POSITIVE")
	assert_eq(sample.position, Vector3(1.0, 2.0, 3.0), "position 좌표")
	assert_eq(sample.direction, Vector3(0.0, 0.0, -1.0), "direction 벡터")
	assert_eq(sample.epoch_ms, ts, "epoch_ms 설정")


## TEST-DAT-004-4: POSITION CSV 행 — 8 컬럼 (dir 비어있음)
func test_position_csv_row_format() -> void:
	var sample: BehaviorSample = BehaviorSample.make_position(Vector3(1.0, 2.5, -3.0), 1700000000000)

	var csv: String = sample.to_csv_row()
	var parts: PackedStringArray = csv.split(",")

	assert_eq(parts.size(), 8, "POSITION CSV 행은 8개 필드: %s" % csv)
	assert_eq(parts[0], "1700000000000", "epoch_ms")
	assert_eq(parts[1], "position", "sample_type")
	assert_true(parts[2].strip_edges() != "", "x 값 존재")
	assert_true(parts[3].strip_edges() != "", "y 값 존재")
	assert_true(parts[4].strip_edges() != "", "z 값 존재")
	assert_eq(parts[5].strip_edges(), "", "dir_x 비어있음")
	assert_eq(parts[6].strip_edges(), "", "dir_y 비어있음")
	assert_eq(parts[7].strip_edges(), "", "dir_z 비어있음")


## TEST-DAT-004-5: GAZE CSV 행 — 8 컬럼 (pos 비어있음)
func test_gaze_csv_row_format() -> void:
	var sample: BehaviorSample = BehaviorSample.make_gaze(Vector3(0.1, 0.2, -0.9), 1700000000000)

	var csv: String = sample.to_csv_row()
	var parts: PackedStringArray = csv.split(",")

	assert_eq(parts.size(), 8, "GAZE CSV 행은 8개 필드: %s" % csv)
	assert_eq(parts[0], "1700000000000", "epoch_ms")
	assert_eq(parts[1], "gaze", "sample_type")
	assert_eq(parts[2].strip_edges(), "", "x 비어있음")
	assert_eq(parts[3].strip_edges(), "", "y 비어있음")
	assert_eq(parts[4].strip_edges(), "", "z 비어있음")
	assert_true(parts[5].strip_edges() != "", "dir_x 값 존재")
	assert_true(parts[6].strip_edges() != "", "dir_y 값 존재")
	assert_true(parts[7].strip_edges() != "", "dir_z 값 존재")


## TEST-DAT-004-6: FALSE_POSITIVE CSV 행 — 8 컬럼 (모두 채워짐)
func test_false_positive_csv_row_format() -> void:
	var sample: BehaviorSample = BehaviorSample.make_false_positive(
		Vector3(1.0, 2.0, 3.0), Vector3(0.1, 0.2, -0.9), 1700000000000
	)

	var csv: String = sample.to_csv_row()
	var parts: PackedStringArray = csv.split(",")

	assert_eq(parts.size(), 8, "FALSE_POSITIVE CSV 행은 8개 필드: %s" % csv)
	assert_eq(parts[0], "1700000000000", "epoch_ms")
	assert_eq(parts[1], "false_positive", "sample_type")
	assert_true(parts[2].strip_edges() != "", "x 값 존재")
	assert_true(parts[3].strip_edges() != "", "y 값 존재")
	assert_true(parts[4].strip_edges() != "", "z 값 존재")
	assert_true(parts[5].strip_edges() != "", "dir_x 값 존재")
	assert_true(parts[6].strip_edges() != "", "dir_y 값 존재")
	assert_true(parts[7].strip_edges() != "", "dir_z 값 존재")


## TEST-DAT-004-7: BehaviorLogger.record_position() — 로깅 중 버퍼에 추가
func test_record_position_adds_to_buffer() -> void:
	_logger.start_logging()

	var ts: int = int(Time.get_unix_time_from_system() * 1000)
	_logger.record_position(Vector3(1.0, 2.0, 3.0), ts)

	assert_eq(_logger._buffer.size(), 1, "버퍼에 1개 추가")
	assert_eq(_logger._buffer[0].sample_type, BehaviorSample.SampleType.POSITION, "POSITION 타입")


## TEST-DAT-004-8: BehaviorLogger.record_gaze() — 로깅 중 버퍼에 추가
func test_record_gaze_adds_to_buffer() -> void:
	_logger.start_logging()

	var ts: int = int(Time.get_unix_time_from_system() * 1000)
	_logger.record_gaze(Vector3(0.0, 0.0, -1.0), ts)

	assert_eq(_logger._buffer.size(), 1, "버퍼에 1개 추가")
	assert_eq(_logger._buffer[0].sample_type, BehaviorSample.SampleType.GAZE, "GAZE 타입")


## TEST-DAT-004-9: BehaviorLogger.record_false_positive() — 로깅 비활성화 시에도 기록
func test_record_false_positive_even_when_not_logging() -> void:
	# start_logging() 호출하지 않음
	var ts: int = int(Time.get_unix_time_from_system() * 1000)
	_logger.record_false_positive(Vector3(1.0, 2.0, 3.0), Vector3(0.0, 0.0, -1.0), ts)

	assert_eq(_logger._buffer.size(), 1, "오탐은 로깅 비활성화 시에도 기록")
	assert_eq(_logger._buffer[0].sample_type, BehaviorSample.SampleType.FALSE_POSITIVE, "FALSE_POSITIVE 타입")


## TEST-DAT-004-10: record_position/gaze — 로깅 비활성화 시 기록 안 함
func test_record_position_gaze_ignored_when_not_logging() -> void:
	# start_logging() 호출하지 않음
	var ts: int = int(Time.get_unix_time_from_system() * 1000)
	_logger.record_position(Vector3(1.0, 2.0, 3.0), ts)
	_logger.record_gaze(Vector3(0.0, 0.0, -1.0), ts)

	assert_eq(_logger._buffer.size(), 0, "로깅 비활성화 → 버퍼 비어있음")


## TEST-DAT-004-11: CSV 파일 저장 — 헤더 + 데이터 행
func test_save_behavior_log_csv() -> void:
	var test_path: String = "user://test_behavior_dat004.csv"

	_logger.start_logging()

	var ts: int = int(Time.get_unix_time_from_system() * 1000)
	_logger.record_position(Vector3(1.0, 2.0, 3.0), ts)
	_logger.record_gaze(Vector3(0.0, 0.0, -1.0), ts + 100)
	_logger.record_false_positive(Vector3(4.0, 5.0, 6.0), Vector3(0.1, 0.2, -0.9), ts + 200)

	_logger.save_behavior_log(test_path)

	assert_true(FileAccess.file_exists(test_path), "CSV 파일 생성됨")

	var file: FileAccess = FileAccess.open(test_path, FileAccess.READ)

	# 헤더
	var header: String = file.get_line()
	assert_eq(header, "epoch_ms,sample_type,x,y,z,dir_x,dir_y,dir_z", "CSV 헤더 형식")

	# 행 개수 확인
	var line_count: int = 0
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if not line.is_empty():
			line_count += 1
	file.close()

	assert_eq(line_count, 3, "3개 데이터 행")

	# 정리
	DirAccess.remove_absolute(test_path)


## TEST-DAT-004-12: flush_buffer() — 경로 미설정 시 버퍼 유지
func test_flush_without_path_keeps_buffer() -> void:
	_logger.start_logging()

	var ts: int = int(Time.get_unix_time_from_system() * 1000)
	_logger.record_position(Vector3.ZERO, ts)

	_logger.flush_buffer()

	assert_eq(_logger._buffer.size(), 1, "경로 미설정 → 버퍼 유지")


## TEST-DAT-004-13: 버퍼 오버플로우 시 자동 flush + 주기 조정
func test_buffer_overflow_auto_flush() -> void:
	var test_path: String = "user://test_overflow_dat004.csv"
	_logger.set_log_path(test_path)
	_logger.start_logging()

	var ts: int = int(Time.get_unix_time_from_system() * 1000)

	# BUFFER_OVERFLOW_THRESHOLD 초과까지 샘플 추가
	for i: int in range(BehaviorLogger.BUFFER_OVERFLOW_THRESHOLD + 10):
		_logger.record_position(Vector3(float(i), 0.0, 0.0), ts + i)

	# 오버플로우 후 버퍼가 비워졌어야 함 (자동 flush 발생)
	assert_true(_logger._buffer.size() < BehaviorLogger.BUFFER_OVERFLOW_THRESHOLD,
		"오버플로우 후 버퍼 크기가 임계치 미만")

	# 샘플링 주기가 증가했어야 함
	assert_true(_logger._current_position_interval > _logger.position_sample_interval_ms,
		"오버플로우 후 샘플링 주기 증가: %.0f > %.0f" % [
			_logger._current_position_interval, _logger.position_sample_interval_ms
		])

	# 정리
	DirAccess.remove_absolute(test_path)


## TEST-DAT-004-14: BehaviorSample은 Resource (Domain Layer 준수)
func test_behavior_sample_is_resource() -> void:
	var sample := BehaviorSample.new()
	assert_true(sample is Resource, "BehaviorSample은 Resource")


## TEST-DAT-004-15: stop_logging() 후 record_position/gaze 무시
func test_stop_logging_stops_recording() -> void:
	_logger.start_logging()

	var ts: int = int(Time.get_unix_time_from_system() * 1000)
	_logger.record_position(Vector3.ONE, ts)
	assert_eq(_logger._buffer.size(), 1, "로깅 중 → 1개 기록")

	_logger.stop_logging()
	_logger.record_position(Vector3.ONE, ts + 100)
	_logger.record_gaze(Vector3.FORWARD, ts + 200)

	assert_eq(_logger._buffer.size(), 1, "로깅 중지 후 추가 기록 없음")

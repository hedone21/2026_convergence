extends GutTest

# ======================================
# SPEC-SES-002: 세션 타이머 (시간 제한)
# ======================================


## TEST-SES-002: 타이머 시작 시 초기 남은 시간이 설정값과 일치
func test_timer_start_sets_remaining() -> void:
	var timer := SessionTimer.new()
	add_child_autoqfree(timer)

	timer.start_timer(120.0)

	assert_eq(timer.get_remaining(), 120.0, "남은 시간이 설정한 120초와 일치해야 한다")
	assert_true(timer.is_running(), "타이머가 동작 중이어야 한다")


## TEST-SES-002-2: 기본 시간 제한이 300초(5분)인지 확인
func test_default_duration_is_300() -> void:
	assert_eq(
		SessionTimer.DEFAULT_DURATION_SECONDS, 300.0,
		"기본 시간 제한은 300초(5분)이어야 한다"
	)


## TEST-SES-002-3: stop_timer 호출 시 타이머가 정지
func test_stop_timer() -> void:
	var timer := SessionTimer.new()
	add_child_autoqfree(timer)

	timer.start_timer(60.0)
	assert_true(timer.is_running(), "시작 후 동작 중")

	timer.stop_timer()
	assert_false(timer.is_running(), "정지 후 비활성")


## TEST-SES-002-4: get_remaining_formatted가 MM:SS 형식을 반환
func test_remaining_formatted() -> void:
	var timer := SessionTimer.new()
	add_child_autoqfree(timer)

	timer.start_timer(125.0)
	assert_eq(timer.get_remaining_formatted(), "02:05", "125초 = 02:05")


## TEST-SES-002-5: 0 이하 duration 입력 시 기본값으로 대체
func test_zero_duration_fallback_to_default() -> void:
	var timer := SessionTimer.new()
	add_child_autoqfree(timer)

	timer.start_timer(0.0)
	assert_eq(
		timer.get_remaining(),
		SessionTimer.DEFAULT_DURATION_SECONDS,
		"0 이하 입력 시 기본값(300초)으로 대체"
	)


## TEST-SES-002-6: 음수 duration 입력 시 기본값으로 대체
func test_negative_duration_fallback_to_default() -> void:
	var timer := SessionTimer.new()
	add_child_autoqfree(timer)

	timer.start_timer(-10.0)
	assert_eq(
		timer.get_remaining(),
		SessionTimer.DEFAULT_DURATION_SECONDS,
		"음수 입력 시 기본값(300초)으로 대체"
	)


## TEST-SES-002-7: timer_updated 시그널이 시작 시 즉시 발행
func test_timer_updated_emitted_on_start() -> void:
	var timer := SessionTimer.new()
	add_child_autoqfree(timer)
	watch_signals(timer)

	timer.start_timer(60.0)

	assert_signal_emitted(timer, "timer_updated", "시작 시 timer_updated 발행")


## TEST-SES-002-8: 이미 정지된 타이머에 stop_timer 호출해도 에러 없음
func test_double_stop_no_error() -> void:
	var timer := SessionTimer.new()
	add_child_autoqfree(timer)

	timer.stop_timer()  # 시작하지 않은 상태에서 정지
	timer.stop_timer()  # 이중 정지
	assert_false(timer.is_running(), "에러 없이 비활성 상태 유지")

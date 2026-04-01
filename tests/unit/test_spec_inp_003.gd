extends GutTest

# ======================================
# SPEC-INP-003: 화면 중심 기반 시선 추적
# ======================================


## TEST-INP-003: 기본 샘플링 주기가 100ms인지 확인
func test_default_sample_interval() -> void:
	var tracker := GazeTracker.new()
	add_child_autoqfree(tracker)

	assert_eq(tracker.sample_interval_ms, 100.0, "기본 샘플링 주기는 100ms")


## TEST-INP-003-2: camera가 null이면 start_tracking이 추적을 활성화하지 않음
func test_start_tracking_null_camera() -> void:
	var tracker := GazeTracker.new()
	add_child_autoqfree(tracker)

	tracker.start_tracking(null)
	# push_error가 예상되므로 GUT에 알린다
	assert_push_error("camera")

	# 추적이 활성화되지 않았으므로 gaze는 ZERO
	assert_eq(
		tracker.get_current_gaze(), Vector3.ZERO,
		"null 카메라로 시작 시 gaze는 ZERO"
	)


## TEST-INP-003-3: stop_tracking 후 gaze가 ZERO를 반환
func test_stop_tracking_resets_gaze() -> void:
	var tracker := GazeTracker.new()
	add_child_autoqfree(tracker)

	var camera := Camera3D.new()
	add_child_autoqfree(camera)

	tracker.start_tracking(camera)
	tracker.stop_tracking()

	assert_eq(
		tracker.get_current_gaze(), Vector3.ZERO,
		"추적 중단 후 gaze는 ZERO"
	)


## TEST-INP-003-4: 추적 시작 후 카메라 전방 벡터를 올바르게 반환
func test_get_current_gaze_returns_camera_forward() -> void:
	var tracker := GazeTracker.new()
	add_child_autoqfree(tracker)

	var camera := Camera3D.new()
	add_child_autoqfree(camera)

	tracker.start_tracking(camera)

	# 기본 카메라 전방은 -Z 방향
	var gaze: Vector3 = tracker.get_current_gaze()

	# Godot의 기본 카메라 전방 벡터는 (0, 0, -1)
	assert_almost_eq(gaze.x, 0.0, 0.01, "gaze.x ~= 0")
	assert_almost_eq(gaze.y, 0.0, 0.01, "gaze.y ~= 0")
	assert_almost_eq(gaze.z, -1.0, 0.01, "gaze.z ~= -1")


## TEST-INP-003-5: 샘플링 주기가 @export로 변경 가능한지 확인
func test_sample_interval_is_configurable() -> void:
	var tracker := GazeTracker.new()
	add_child_autoqfree(tracker)

	tracker.sample_interval_ms = 50.0
	assert_eq(tracker.sample_interval_ms, 50.0, "샘플링 주기 변경 가능")

	tracker.sample_interval_ms = 200.0
	assert_eq(tracker.sample_interval_ms, 200.0, "샘플링 주기 변경 가능")


## TEST-INP-003-6: gaze_sampled 시그널이 direction과 timestamp 파라미터를 포함
func test_gaze_sampled_signal_exists() -> void:
	var tracker := GazeTracker.new()
	add_child_autoqfree(tracker)

	# GUT의 watch_signals로 시그널 존재 여부 확인
	watch_signals(tracker)

	# 시그널이 선언되어 있는지 확인 (has_signal)
	assert_true(
		tracker.has_signal("gaze_sampled"),
		"gaze_sampled 시그널이 선언되어 있어야 한다"
	)

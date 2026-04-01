class_name SessionTimer
extends Node

## SPEC-SES-002: 세션 타이머 (시간 제한)
## Timer 노드를 이용해 카운트다운을 수행하고, 매초 남은 시간을 알리며
## 시간이 0에 도달하면 timer_expired 시그널을 발행한다.
## HUD가 이 시그널을 수신해 분:초 형식으로 표시한다.

## 매초 남은 시간(초)을 전달
signal timer_updated(remaining_seconds: float)
## 제한 시간 도달 — 세션 자동 종료 트리거
signal timer_expired

## SPEC-SES-002: 기본 시간 제한은 300초(5분)
const DEFAULT_DURATION_SECONDS: float = 300.0
const MIN_DURATION_SECONDS: float = 1.0

var _duration: float = DEFAULT_DURATION_SECONDS
var _remaining: float = 0.0
var _is_running: bool = false

## 내부 1초 단위 카운트다운 타이머
var _tick_timer: Timer = null


func _ready() -> void:
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.one_shot = false
	_tick_timer.autostart = false
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)


## SPEC-SES-002: 타이머를 시작한다.
## duration_seconds가 0 이하이면 기본값(300초)으로 대체하고 경고를 출력한다.
func start_timer(duration_seconds: float) -> void:
	if duration_seconds <= 0.0:
		push_warning(
			"SPEC-SES-002: 시간 제한이 0 이하(%s)로 설정됨 — 기본값 %s초로 대체" % [
				duration_seconds, DEFAULT_DURATION_SECONDS
			]
		)
		_duration = DEFAULT_DURATION_SECONDS
	else:
		_duration = maxf(duration_seconds, MIN_DURATION_SECONDS)

	_remaining = _duration
	_is_running = true
	_tick_timer.start()

	## 시작 즉시 현재 남은 시간을 알린다
	timer_updated.emit(_remaining)


## 타이머를 정지한다 (세션 조기 종료 또는 일시정지 시).
func stop_timer() -> void:
	if not _is_running:
		return
	_is_running = false
	_tick_timer.stop()


## 현재 남은 시간(초)을 반환한다.
func get_remaining() -> float:
	return maxf(_remaining, 0.0)


## 타이머가 동작 중인지 여부를 반환한다.
func is_running() -> bool:
	return _is_running


## 남은 시간을 "MM:SS" 형식 문자열로 반환한다.
## HUD 레이블에 직접 사용 가능하다.
func get_remaining_formatted() -> String:
	var secs: int = int(maxf(_remaining, 0.0))
	var m: int = secs / 60
	var s: int = secs % 60
	return "%02d:%02d" % [m, s]


## 1초마다 호출되는 내부 콜백
func _on_tick() -> void:
	if not _is_running:
		return

	_remaining -= 1.0

	if _remaining <= 0.0:
		_remaining = 0.0
		_is_running = false
		_tick_timer.stop()
		timer_updated.emit(_remaining)
		timer_expired.emit()
	else:
		timer_updated.emit(_remaining)

extends Node

## SPEC-INP-001: 조이스틱 기반 이동
## SPEC-INP-002: 컨트롤러 버튼 마킹
##
## InputManager Autoload — VR/데스크톱 입력 추상화
## RigInterface의 mark_requested 시그널을 구독하고,
## MarkingSystem과 Locomotion에 입력을 전달한다.
## GameManager.is_vr_mode를 참조하여 입력 모드를 결정한다.

## SPEC-INP-002: 마킹 요청 시그널 (origin, direction)
signal mark_requested(ray_origin: Vector3, ray_direction: Vector3)

## SPEC-INP-001: 이동 입력 시그널 (direction, delta)
signal movement_input(direction: Vector3, delta: float)

## SPEC-INP-001: 스냅 턴 입력 시그널 (degrees)
signal snap_turn_input(degrees: float)

## 마킹 시스템 인스턴스
var marking_system: MarkingSystem = null

## 이동 시스템 인스턴스
var locomotion: Locomotion = null

## 현재 연결된 리그
var _current_rig: RigInterface = null

## 스냅 턴 조이스틱 데드존
const SNAP_TURN_DEADZONE: float = 0.6

## 스냅 턴 입력 상태 (중복 방지)
var _snap_turn_triggered: bool = false


func _ready() -> void:
	# MarkingSystem을 자식 노드로 추가
	marking_system = MarkingSystem.new()
	marking_system.name = "MarkingSystem"
	add_child(marking_system)

	# MarkingSystem 시그널 → HazardManager 연결
	marking_system.mark_succeeded.connect(_on_mark_succeeded)
	marking_system.mark_failed.connect(_on_mark_failed)

	# Locomotion 인스턴스 생성
	locomotion = Locomotion.new()

	# GameManager의 game_ready 시그널을 기다려 리그 연결
	if GameManager.current_rig != null:
		_connect_rig(GameManager.current_rig)
	else:
		GameManager.game_ready.connect(_on_game_ready)

	print("[InputManager] Initialized.")


func _physics_process(delta: float) -> void:
	locomotion.update(delta)

	# VR 모드에서 오른쪽 조이스틱 스냅 턴 처리
	if GameManager.is_vr_mode and _current_rig is VRRigController:
		_process_vr_snap_turn()


## 리그를 연결한다.
func _connect_rig(rig: RigInterface) -> void:
	if _current_rig != null:
		_disconnect_rig()

	_current_rig = rig
	_current_rig.mark_requested.connect(_on_mark_requested)
	locomotion.bind_rig(rig)
	print("[InputManager] Rig connected: %s" % rig.name)


## 리그 연결을 해제한다.
func _disconnect_rig() -> void:
	if _current_rig == null:
		return
	if _current_rig.mark_requested.is_connected(_on_mark_requested):
		_current_rig.mark_requested.disconnect(_on_mark_requested)
	locomotion.unbind_rig()
	_current_rig = null


## VR 모드에서 오른쪽 조이스틱 스냅 턴 처리
func _process_vr_snap_turn() -> void:
	var vr_rig: VRRigController = _current_rig as VRRigController
	if vr_rig == null or vr_rig.right_controller == null:
		return

	var right_input: Vector2 = vr_rig.right_controller.get_vector2("primary")

	if absf(right_input.x) > SNAP_TURN_DEADZONE:
		if not _snap_turn_triggered:
			var turn_dir: float = signf(right_input.x)
			var degrees: float = locomotion.snap_turn_degrees * turn_dir
			locomotion.apply_snap_turn(degrees)
			snap_turn_input.emit(degrees)
			_snap_turn_triggered = true
	else:
		_snap_turn_triggered = false


## mark_requested 시그널 핸들러 — 마킹 시스템에 전달
func _on_mark_requested(ray_origin: Vector3, ray_direction: Vector3) -> void:
	mark_requested.emit(ray_origin, ray_direction)
	marking_system.perform_mark(ray_origin, ray_direction)


## GameManager.game_ready 핸들러
func _on_game_ready() -> void:
	if GameManager.current_rig != null:
		_connect_rig(GameManager.current_rig)


## SPEC-INP-002: MarkingSystem.mark_succeeded → HazardManager 연결 + 시각 마커 spawn
func _on_mark_succeeded(hazard: BaseHazard, hit_position: Vector3) -> void:
	HazardManager.attempt_mark_hazard(hazard, hit_position)
	HazardManager.place_marker(hit_position, hazard.hazard_type)


## SPEC-INP-002: MarkingSystem.mark_failed → HazardManager 오탐 기록 + 시각 마커 spawn
func _on_mark_failed(hit_position: Vector3, ray_direction: Vector3) -> void:
	HazardManager.record_false_positive(hit_position, ray_direction)
	HazardManager.place_marker(hit_position, "false_positive")

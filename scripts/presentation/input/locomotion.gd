class_name Locomotion
extends RefCounted

## SPEC-INP-001: 조이스틱 기반 이동
##
## VR 조이스틱 / 데스크톱 키보드 입력을 받아
## CharacterBody3D (또는 XROrigin3D) 기반 이동을 수행한다.
## 실제 이동은 RigInterface.apply_movement()에 위임하므로
## 이 클래스는 이동 속도, 스냅 턴 로직을 관리한다.
## 충돌 처리는 CharacterBody3D의 move_and_slide()가 담당한다.

## SPEC-INP-001: 기본 이동 속도 (m/s)
const DEFAULT_MOVE_SPEED: float = 3.0

## SPEC-INP-001: 스냅 턴 기본 각도 (도)
const DEFAULT_SNAP_TURN_DEGREES: float = 30.0

## SPEC-INP-001: 스냅 턴 쿨다운 (초) — VR 멀미 방지
const SNAP_TURN_COOLDOWN: float = 0.25

## 이동 속도 (m/s)
var move_speed: float = DEFAULT_MOVE_SPEED

## 스냅 턴 각도 (도)
var snap_turn_degrees: float = DEFAULT_SNAP_TURN_DEGREES

## 현재 활성 리그 참조
var _rig: RigInterface = null

## 스냅 턴 쿨다운 타이머
var _snap_turn_cooldown_remaining: float = 0.0


## 리그를 연결한다.
func bind_rig(rig: RigInterface) -> void:
	_rig = rig


## 리그 연결을 해제한다.
func unbind_rig() -> void:
	_rig = null


## SPEC-INP-001: 이동을 적용한다.
## direction: 정규화된 이동 방향 벡터 (월드 좌표)
## delta: 프레임 시간 (초)
func apply_movement(direction: Vector3, delta: float) -> void:
	if _rig == null:
		return
	if direction.length_squared() < 0.001:
		return

	var move_dir: Vector3 = direction.normalized() * move_speed / DEFAULT_MOVE_SPEED
	_rig.apply_movement(move_dir, delta)


## SPEC-INP-001: 스냅 턴을 적용한다.
## degrees: 회전 각도 (양수 = 오른쪽, 음수 = 왼쪽)
## 쿨다운 중이면 무시한다.
func apply_snap_turn(degrees: float) -> void:
	if _rig == null:
		return
	if _snap_turn_cooldown_remaining > 0.0:
		return

	# XROrigin3D 또는 CharacterBody3D를 회전
	# RigInterface에는 직접 회전 메서드가 없으므로 노드를 직접 회전
	_rig.rotate_y(deg_to_rad(-degrees))
	_snap_turn_cooldown_remaining = SNAP_TURN_COOLDOWN


## SPEC-INP-001: 이동 속도를 변경한다.
func set_speed(speed: float) -> void:
	move_speed = maxf(0.0, speed)


## 쿨다운 타이머를 업데이트한다. 매 프레임 호출 필요.
func update(delta: float) -> void:
	if _snap_turn_cooldown_remaining > 0.0:
		_snap_turn_cooldown_remaining -= delta
		if _snap_turn_cooldown_remaining < 0.0:
			_snap_turn_cooldown_remaining = 0.0


## 바닥 접촉 여부를 반환한다.
## CharacterBody3D 기반 리그에서만 유효하다.
func is_grounded() -> bool:
	if _rig == null:
		return false
	# DesktopRigController의 character_body에 접근 시도
	if _rig is DesktopRigController:
		var desktop_rig: DesktopRigController = _rig as DesktopRigController
		return desktop_rig.character_body.is_on_floor()
	# VR 모드에서는 항상 grounded로 간주 (텔레포트/이동 기반)
	return true

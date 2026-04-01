extends Node

## SPEC-VR-001: VR 환경 초기화 및 세션 시작
## SPEC-VR-002: 데스크톱 모드 폴백
##
## 애플리케이션 생명주기를 관리하는 최상위 Autoload.
## VR 초기화를 시도하고, 실패 시 데스크톱 모드로 폴백한다.
## --desktop 커맨드라인 플래그로 강제 데스크톱 모드도 지원한다.

## VR 초기화 성공 시 발행
signal vr_initialized
## 데스크톱 모드로 전환 시 발행 (사유 포함)
signal desktop_mode_activated(reason: String)
## 모든 초기화가 완료되어 다음 시스템(SessionManager 등)이 시작 가능할 때 발행
signal game_ready

## VR 모드 여부
var is_vr_mode: bool = false
## 현재 활성 리그 (VR 또는 Desktop). RigInterface 타입으로 참조.
var current_rig: RigInterface = null

var _vr_rig_scene: PackedScene = preload("res://scenes/vr_rig/vr_rig.tscn")
var _desktop_rig_scene: PackedScene = preload("res://scenes/vr_rig/desktop_rig.tscn")


func _ready() -> void:
	print("[GameManager] Initializing...")

	if _has_desktop_flag():
		print("[GameManager] --desktop flag detected. Skipping VR initialization.")
		_activate_desktop_mode("Forced desktop mode via --desktop flag.")
	else:
		_attempt_vr_initialization()

	game_ready.emit()
	print("[GameManager] Game ready. VR mode: %s" % str(is_vr_mode))


## 현재 모드의 카메라를 반환한다.
func get_camera() -> Camera3D:
	if current_rig:
		return current_rig.get_camera()
	return null


## 애플리케이션을 안전하게 종료한다.
func quit_application() -> void:
	print("[GameManager] Quitting application...")
	get_tree().quit()


## 커맨드라인에 --desktop 플래그가 있는지 확인한다.
func _has_desktop_flag() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	for arg: String in args:
		if arg == "--desktop":
			return true
	return false


## VR 초기화를 시도한다. 실패 시 데스크톱 모드로 폴백.
func _attempt_vr_initialization() -> void:
	print("[GameManager] Attempting VR initialization...")

	var result: Dictionary = VRInitializer.initialize_openxr()

	if result.get("success", false):
		_activate_vr_mode(result["interface"])
	else:
		var reason: String = result.get("reason", "Unknown VR initialization failure.")
		print("[GameManager] VR initialization failed: %s" % reason)
		_activate_desktop_mode(reason)


## VR 모드를 활성화한다.
func _activate_vr_mode(xr_interface: XRInterface) -> void:
	print("[GameManager] Activating VR mode...")

	# 스테레오 렌더링 활성화
	get_viewport().use_xr = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# VR 리그 인스턴스 생성 및 씬에 추가
	var vr_rig: RigInterface = _vr_rig_scene.instantiate() as RigInterface
	_attach_rig(vr_rig)

	is_vr_mode = true
	vr_initialized.emit()
	print("[GameManager] VR mode activated successfully.")


## 데스크톱 모드를 활성화한다.
func _activate_desktop_mode(reason: String) -> void:
	print("[GameManager] Activating desktop mode. Reason: %s" % reason)

	# 데스크톱 리그 인스턴스 생성 및 씬에 추가
	var desktop_rig: RigInterface = _desktop_rig_scene.instantiate() as RigInterface
	_attach_rig(desktop_rig)

	is_vr_mode = false
	desktop_mode_activated.emit(reason)
	print("[GameManager] Desktop mode activated.")


## 리그를 메인 씬의 PlayerRig 슬롯에 부착한다.
func _attach_rig(rig: RigInterface) -> void:
	# 메인 씬에서 PlayerRig 노드를 찾아 자식으로 추가
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		push_error("[GameManager] No current scene found. Cannot attach rig.")
		return

	var player_rig_node: Node3D = main_scene.get_node_or_null("PlayerRig")
	if player_rig_node == null:
		push_error("[GameManager] PlayerRig node not found in main scene.")
		return

	# 기존 리그가 있으면 제거
	for child: Node in player_rig_node.get_children():
		child.queue_free()

	player_rig_node.add_child(rig)
	current_rig = rig
	print("[GameManager] Rig attached: %s" % rig.name)

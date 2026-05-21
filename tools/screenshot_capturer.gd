extends Node

## 데스크톱 모드 멀티앵글 진단용 스크린샷 캡처.
## 명령행 플래그 `--capture-screenshots`가 있을 때만 동작하며,
## 없으면 _ready에서 즉시 자기 자신을 free하여 일반 실행에 영향이 없다.
##
## 캡처는 2 batch:
##   1) with_ceiling/  -- 시나리오 그대로 (천장 슬래브 있음)
##   2) no_ceiling/    -- 천장 슬래브 제거 후 동일 앵글 재캡처 (도면 비교용)
##
## 사용법:
##   godot --path . -- --desktop --capture-screenshots

const OUTPUT_ROOT_RES: String = "res://_workspace/diagnosis/"
const FLAG: String = "--capture-screenshots"

## 사이트/라이트 안정화 대기 프레임 (≈1초)
const STABILIZE_FRAMES: int = 60

## 카메라 위치 재설정 후 셔터 대기
const SHUTTER_FRAMES: int = 6

## 천장 제거 후 재안정화 프레임
const TOGGLE_FRAMES: int = 30

## 캡처 앵글: 사이트 origin(0,0,0) = walls_bbox 중심 기준.
## rot_y=180 → -Z 시선 (도면 북쪽).
var _angles: Array = [
	{"name": "01_eye_north",   "pos": Vector3(0.0, 1.7, 0.0),   "rot_y": 180.0,  "pitch": 0.0},
	{"name": "02_eye_east",    "pos": Vector3(0.0, 1.7, 0.0),   "rot_y": -90.0,  "pitch": 0.0},
	{"name": "03_eye_south",   "pos": Vector3(0.0, 1.7, 0.0),   "rot_y": 0.0,    "pitch": 0.0},
	{"name": "04_eye_west",    "pos": Vector3(0.0, 1.7, 0.0),   "rot_y": 90.0,   "pitch": 0.0},
	{"name": "05_eye_up45",    "pos": Vector3(0.0, 1.7, 0.0),   "rot_y": 180.0,  "pitch": 35.0},
	{"name": "06_topdown_40m", "pos": Vector3(0.0, 40.0, 0.0),  "rot_y": 0.0,    "pitch": -89.0},
	{"name": "07_iso_high",    "pos": Vector3(22.0, 18.0, 22.0),"rot_y": 135.0,  "pitch": -25.0},
	{"name": "08_offset_north","pos": Vector3(0.0, 1.7, 8.0),   "rot_y": 180.0,  "pitch": 0.0},
]

## 외부 시점 캡처 앵글 — 사이트 BBox 바깥에서 건물을 본다.
## Phase 5b: 비계/거푸집/안전망/caution stand 외관 확인용.
var _exterior_angles: Array = [
	{"name": "01_north_30m",   "pos": Vector3(0.0, 1.7, -30.0),  "rot_y": 0.0,    "pitch": 0.0},
	{"name": "02_east_30m",    "pos": Vector3(30.0, 1.7, 0.0),   "rot_y": -90.0,  "pitch": 0.0},
	{"name": "03_south_30m",   "pos": Vector3(0.0, 1.7, 30.0),   "rot_y": 180.0,  "pitch": 0.0},
	{"name": "04_west_30m",    "pos": Vector3(-30.0, 1.7, 0.0),  "rot_y": 90.0,   "pitch": 0.0},
	{"name": "05_ne_iso",      "pos": Vector3(35.0, 12.0, -35.0),"rot_y": -45.0,  "pitch": -15.0},
	{"name": "06_sw_iso",      "pos": Vector3(-35.0, 12.0, 35.0),"rot_y": 135.0,  "pitch": -15.0},
	{"name": "07_north_low",   "pos": Vector3(0.0, 0.9, -18.0),  "rot_y": 0.0,    "pitch": 8.0},
	{"name": "08_iso_high_ext","pos": Vector3(45.0, 28.0, 45.0), "rot_y": -135.0, "pitch": -30.0},
]


func _ready() -> void:
	if not _has_flag():
		queue_free()
		return
	print("[ScreenshotCapturer] Active — output root: %s" % OUTPUT_ROOT_RES)
	_run_capture.call_deferred()


func _has_flag() -> bool:
	for a: String in OS.get_cmdline_args():
		if a == FLAG:
			return true
	for a: String in OS.get_cmdline_user_args():
		if a == FLAG:
			return true
	return false


func _ensure_dir(sub: String) -> String:
	var full: String = OUTPUT_ROOT_RES + sub
	var abs_dir: String = ProjectSettings.globalize_path(full)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	return full


func _run_capture() -> void:
	# 사이트 빌드 + 라이트 안정화 대기
	for _i: int in range(STABILIZE_FRAMES):
		await get_tree().process_frame

	# UI(피험자 입력 화면) 숨김
	var ui_layer: CanvasLayer = get_tree().current_scene.get_node_or_null("UILayer") as CanvasLayer
	if ui_layer != null:
		ui_layer.visible = false

	var camera: Camera3D = GameManager.get_camera()
	if camera == null:
		push_error("[ScreenshotCapturer] No active camera — desktop rig 부착 실패")
		get_tree().quit()
		return

	# 카메라를 부모 transform과 분리하여 절대 위치 제어
	camera.top_level = true
	camera.current = true

	# Batch 1: 천장 있음 (현재 시나리오 그대로)
	await _capture_batch(camera, _ensure_dir("with_ceiling/"))

	# 천장 슬래브 제거
	var ceiling: Node = _find_ceiling_node()
	if ceiling != null:
		print("[ScreenshotCapturer] Removing ceiling: %s" % ceiling.get_path())
		ceiling.queue_free()
		for _i: int in range(TOGGLE_FRAMES):
			await get_tree().process_frame
	else:
		print("[ScreenshotCapturer] No ceiling node found — batch 2 same as batch 1.")

	# Batch 2: 천장 없음
	await _capture_batch(camera, _ensure_dir("no_ceiling/"))

	# Batch 3: hazard closeup — 각 hazard 1.5m 거리에서 1장씩
	await _capture_hazard_closeups(camera, _ensure_dir("hazards/"))

	# Batch 4: 외부 시점 — 사이트 BBox 외부에서 비계/외관 캡처
	await _capture_exterior(camera, _ensure_dir("exterior/"))

	print("[ScreenshotCapturer] Done. Quitting.")
	get_tree().quit()


## 외부 시점 캡처 batch — _exterior_angles 8개.
func _capture_exterior(camera: Camera3D, out_dir: String) -> void:
	for angle in _exterior_angles:
		camera.global_position = angle["pos"] as Vector3
		camera.global_rotation_degrees = Vector3(
			angle["pitch"] as float, angle["rot_y"] as float, 0.0
		)
		for _i: int in range(SHUTTER_FRAMES):
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = out_dir + (angle["name"] as String) + ".png"
		var err: int = img.save_png(path)
		if err == OK:
			print("[ScreenshotCapturer] Saved %s" % ProjectSettings.globalize_path(path))
		else:
			push_error("[ScreenshotCapturer] save_png failed (%d): %s" % [err, path])


## HazardContainer 하위 각 hazard 1.5m 후방·1.2m 위에서 캡처.
func _capture_hazard_closeups(camera: Camera3D, out_dir: String) -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return
	var hazard_container: Node = main_scene.get_node_or_null("HazardContainer")
	if hazard_container == null:
		print("[ScreenshotCapturer] HazardContainer 없음 — closeup skip")
		return
	var hazards: Array = hazard_container.get_children()
	for i: int in hazards.size():
		var h: Node = hazards[i]
		if not (h is Node3D):
			continue
		var hp: Vector3 = (h as Node3D).global_position
		# closeup: hazard 근접 0.9m 후방 + 낮은 시선으로 각 hazard 단독 식별 강화
		camera.global_position = hp + Vector3(0.0, 0.6, 0.9)
		camera.look_at(hp + Vector3(0.0, 0.2, 0.0))
		for _i: int in range(SHUTTER_FRAMES):
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		var label: String = "hazard_%02d_%s.png" % [i + 1, h.name]
		var path: String = out_dir + label
		var err: int = img.save_png(path)
		if err == OK:
			print("[ScreenshotCapturer] Saved %s" % ProjectSettings.globalize_path(path))
		else:
			push_error("[ScreenshotCapturer] save_png failed (%d): %s" % [err, path])


func _capture_batch(camera: Camera3D, out_dir: String) -> void:
	var viewport: Viewport = get_viewport()
	for angle in _angles:
		camera.global_position = angle["pos"] as Vector3
		camera.global_rotation_degrees = Vector3(
			angle["pitch"] as float, angle["rot_y"] as float, 0.0
		)
		for _i: int in range(SHUTTER_FRAMES):
			await get_tree().process_frame

		var img: Image = viewport.get_texture().get_image()
		var path: String = out_dir + (angle["name"] as String) + ".png"
		var err: int = img.save_png(path)
		if err == OK:
			print("[ScreenshotCapturer] Saved %s" % ProjectSettings.globalize_path(path))
		else:
			push_error("[ScreenshotCapturer] save_png failed (%d): %s" % [err, path])


## SiteContainer 하위에서 ceiling 노드를 찾는다.
## 이전 "CeilingSlab"(통판) + 신규 "CeilingStructure"(빔 격자) 모두 인식.
func _find_ceiling_node() -> Node:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return null
	var site_container: Node = main_scene.get_node_or_null("SiteContainer")
	if site_container == null:
		return null
	for child: Node in site_container.get_children():
		for name_: String in ["CeilingStructure", "CeilingSlab"]:
			var ceiling: Node = child.get_node_or_null(name_)
			if ceiling != null:
				return ceiling
	return null

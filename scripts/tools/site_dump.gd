extends Node

## 헤드리스 부팅 시 site spawn 결과(wall/column StaticBody3D)를 CSV로 dump.
##
## ScreenshotCapturer와 같은 플래그 기반 진입. 평소 실행에는 영향 없음.
## SPEC-QM-001 (TBD) — 자동화된 도면-시뮬 품질 측정의 시뮬 측 수집기.
##
## 사용:
##   godot --headless --path . -- --desktop --dump-site=data/sessions/site_dump.csv
##   godot --headless --path . -- --desktop --dump-site=res://data/sessions/site_dump.csv
##
## 출력 형식:
##   group,index,start_x,start_z,end_x,end_z,length,angle_rad
##   walls,0,11.79,58.92,11.80,58.94,0.04,1.34
##   columns,0,27.34,30.55,27.41,30.85,0.30,1.34
##   ...
##
## 좌표계: Godot world (x, z). site_container가 (0,0,0)에 origin 고정이므로
## world 좌표 = (JSON 좌표 - bbox_center).

const FLAG_PREFIX: String = "--dump-site="
const STABILIZE_FRAMES: int = 60


func _ready() -> void:
	var path: String = _flag_value()
	if path == "":
		queue_free()
		return
	print("[SiteDump] Active — output: %s" % path)
	_run_dump.call_deferred(path)


func _flag_value() -> String:
	var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for a: String in args:
		if a.begins_with(FLAG_PREFIX):
			return a.substr(FLAG_PREFIX.length())
	return ""


func _run_dump(out_path: String) -> void:
	# 시나리오 빌드 안정화 대기 (CalPolyB001Site._ready + door cut + room labels)
	for _i: int in range(STABILIZE_FRAMES):
		await get_tree().process_frame

	var rows: PackedStringArray = PackedStringArray()
	rows.append("group,index,start_x,start_z,end_x,end_z,length,angle_rad")

	var main_scene: Node = get_tree().current_scene
	var site_container: Node = main_scene.get_node_or_null("SiteContainer") if main_scene else null
	if site_container == null:
		push_error("[SiteDump] SiteContainer not found")
		get_tree().quit()
		return

	var counts: Dictionary = {"walls": 0, "columns": 0}
	for site: Node in site_container.get_children():
		for group_name: String in ["Walls", "Columns"]:
			var grp: Node = site.get_node_or_null(group_name)
			if grp == null:
				continue
			var key: String = group_name.to_lower()
			for body: Node in grp.get_children():
				var seg: Array = _body_to_segment(body)
				if seg.is_empty():
					continue
				rows.append("%s,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.6f" % [
					key, counts[key],
					seg[0], seg[1], seg[2], seg[3],
					seg[4], seg[5],
				])
				counts[key] += 1

	# 경로 정규화 (res:// 또는 user:// → 절대 경로)
	var abs_path: String = out_path
	if out_path.begins_with("res://") or out_path.begins_with("user://"):
		abs_path = ProjectSettings.globalize_path(out_path)

	var dir_path: String = abs_path.get_base_dir()
	if not dir_path.is_empty() and not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var f: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		push_error("[SiteDump] FileAccess open 실패: %s (%s)" % [
			abs_path, error_string(FileAccess.get_open_error())
		])
		get_tree().quit()
		return

	for row: String in rows:
		f.store_line(row)
	f.close()

	print("[SiteDump] Wrote %s — walls=%d columns=%d" % [
		abs_path, counts["walls"], counts["columns"]
	])
	get_tree().quit()


## StaticBody3D + 자식 MeshInstance3D(BoxMesh)에서 segment 복원.
## body.position = (mid_x, h*0.5, mid_z), rotation.y = -angle
## BoxMesh.size.x = length.
## 반환: [start_x, start_z, end_x, end_z, length, angle_rad] (빈 배열이면 skip)
func _body_to_segment(body: Node) -> Array:
	if not (body is Node3D):
		return []
	var node3d: Node3D = body
	var mesh_instance: MeshInstance3D = null
	for child: Node in node3d.get_children():
		if child is MeshInstance3D:
			mesh_instance = child
			break
	if mesh_instance == null or not (mesh_instance.mesh is BoxMesh):
		return []
	var box: BoxMesh = mesh_instance.mesh
	var length: float = box.size.x
	if length < 0.01:
		return []
	var ang: float = -node3d.rotation.y
	var mid: Vector2 = Vector2(node3d.global_position.x, node3d.global_position.z)
	var dir: Vector2 = Vector2(cos(ang), sin(ang))
	var s: Vector2 = mid - dir * (length * 0.5)
	var e: Vector2 = mid + dir * (length * 0.5)
	return [s.x, s.y, e.x, e.y, length, ang]

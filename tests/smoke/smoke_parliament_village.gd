extends SceneTree

## 스모크 테스트: ParliamentVillageSite가 floor JSON을 로드해 wall/column/core를
## 정상 생성하는지 확인. headless에서 실행되며 결과를 stdout에 출력.

func _init() -> void:
	var packed: PackedScene = load("res://scenes/environment/parliament_village.tscn") as PackedScene
	if packed == null:
		push_error("scene 로드 실패")
		quit(1)
		return

	var site: Node3D = packed.instantiate() as Node3D
	root.add_child(site)
	await process_frame
	await process_frame

	var walls: Node = site.get_node_or_null("Walls")
	var columns: Node = site.get_node_or_null("Columns")
	var cores: Node = site.get_node_or_null("Cores")
	var slab: Node = site.get_node_or_null("Slab")

	var wall_count: int = walls.get_child_count() if walls != null else 0
	var column_count: int = columns.get_child_count() if columns != null else 0
	var core_count: int = cores.get_child_count() if cores != null else 0
	var slab_ok: bool = slab != null

	print("[smoke] walls=%d columns=%d cores=%d slab_ok=%s" % [
		wall_count, column_count, core_count, str(slab_ok)
	])

	var surfaces: Array = site.get_valid_surfaces() if site.has_method("get_valid_surfaces") else []
	var bounds: AABB = site.get_spawn_bounds() if site.has_method("get_spawn_bounds") else AABB()
	var site_type: String = site.get_site_type() if site.has_method("get_site_type") else ""
	print("[smoke] surfaces=%d site_type=%s bounds_size=%s" % [
		surfaces.size(), site_type, str(bounds.size)
	])

	var ok: bool = (
		wall_count > 0 and column_count > 0 and core_count > 0 and slab_ok
		and surfaces.size() > 0 and site_type == "parliament_village"
		and bounds.size.x > 10.0 and bounds.size.z > 10.0
	)
	print("[smoke] result: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)

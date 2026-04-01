extends GutTest

# ======================================
# SPEC-ENV-001: 건물 골조 현장 3D 환경
# ======================================
# 3D 렌더링은 headless에서 불가하지만 구조물 생성 로직은 검증 가능.
# BuildingFrameSite는 씬 파일을 통해 인스턴스화한다.

var _site_scene: PackedScene


func before_all() -> void:
	_site_scene = load("res://scenes/environment/building_frame.tscn")


## TEST-ENV-001: BuildingFrameSite가 BaseSite를 상속하는지 확인
func test_building_frame_extends_base_site() -> void:
	var site: Node = _site_scene.instantiate()
	add_child_autoqfree(site)

	assert_true(site is BaseSite, "BuildingFrameSite는 BaseSite를 상속해야 한다")


## TEST-ENV-001-2: get_site_type이 "building_frame"을 반환
func test_site_type_string() -> void:
	var site: Node = _site_scene.instantiate()
	add_child_autoqfree(site)

	assert_eq(site.get_site_type(), "building_frame", "현장 유형은 building_frame")


## TEST-ENV-001-3: get_valid_surfaces가 표면 목록을 반환 (기둥 >= 4, 보 >= 4, 슬래브 >= 1)
func test_valid_surfaces_count() -> void:
	var site: Node = _site_scene.instantiate()
	add_child_autoqfree(site)

	var surfaces: Array = site.get_valid_surfaces()
	assert_gt(surfaces.size(), 0, "표면 목록이 비어있지 않아야 한다")

	var column_count: int = 0
	var beam_count: int = 0
	var slab_count: int = 0
	var floor_count: int = 0

	for surface: Dictionary in surfaces:
		match surface["surface_type"]:
			"column":
				column_count += 1
			"beam":
				beam_count += 1
			"slab":
				slab_count += 1
			"floor":
				floor_count += 1

	assert_gte(column_count, 4, "기둥 최소 4개: 실제 %d개" % column_count)
	assert_gte(beam_count, 4, "보 최소 4개: 실제 %d개" % beam_count)
	assert_gte(slab_count, 1, "슬래브 최소 1개: 실제 %d개" % slab_count)
	assert_gte(floor_count, 1, "바닥 최소 1개: 실제 %d개" % floor_count)


## TEST-ENV-001-4: get_spawn_bounds가 유효한 AABB를 반환
func test_spawn_bounds_is_valid() -> void:
	var site: Node = _site_scene.instantiate()
	add_child_autoqfree(site)

	var bounds: AABB = site.get_spawn_bounds()
	assert_gt(bounds.size.x, 0.0, "AABB width > 0")
	assert_gt(bounds.size.y, 0.0, "AABB height > 0")
	assert_gt(bounds.size.z, 0.0, "AABB depth > 0")


## TEST-ENV-001-5: 기둥 개수가 정확히 8개 (3x3 중앙 제외)
func test_column_count_exact() -> void:
	var site: Node = _site_scene.instantiate()
	add_child_autoqfree(site)

	var surfaces: Array = site.get_valid_surfaces()
	var column_count: int = 0
	for surface: Dictionary in surfaces:
		if surface["surface_type"] == "column":
			column_count += 1

	assert_eq(column_count, 8, "기둥은 정확히 8개 (3x3 - 중앙 1)")


## TEST-ENV-001-6: 보 개수가 정확히 12개 (X방향 6 + Z방향 6)
func test_beam_count_exact() -> void:
	var site: Node = _site_scene.instantiate()
	add_child_autoqfree(site)

	var surfaces: Array = site.get_valid_surfaces()
	var beam_count: int = 0
	for surface: Dictionary in surfaces:
		if surface["surface_type"] == "beam":
			beam_count += 1

	assert_eq(beam_count, 12, "보는 정확히 12개 (X 6 + Z 6)")


## TEST-ENV-001-7: 모든 구조물(기둥, 보, 슬래브, 벽)에 충돌체(CollisionShape3D)가 존재
func test_all_structures_have_collision() -> void:
	var site: Node = _site_scene.instantiate()
	add_child_autoqfree(site)

	var surfaces: Array = site.get_valid_surfaces()
	for surface: Dictionary in surfaces:
		var node: Node = surface["node"]
		if node is StaticBody3D:
			var has_collision: bool = false
			for child: Node in node.get_children():
				if child is CollisionShape3D:
					has_collision = true
					break
			assert_true(
				has_collision,
				"%s (%s)에 CollisionShape3D 존재" % [node.name, surface["surface_type"]]
			)

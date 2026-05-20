extends GutTest

# ======================================
# SPEC-INP-002: 위험 마킹 — 시각 마커 (HazardMarker)
# ======================================
# hazard_marker.gd 신규 + HazardManager.place_marker + hazard_mark_placed 시그널 검증.


## TEST-INP-002-M1: HazardMarker 노드 생성 + 메타데이터 보관
func test_hazard_marker_holds_metadata() -> void:
	var marker := HazardMarker.new()
	add_child_autoqfree(marker)
	marker.place(Vector3(1.5, 2.0, -3.0), 1234567, "crack")

	assert_almost_eq(marker.marker_position, Vector3(1.5, 2.0, -3.0), 0.001, "위치 보존")
	assert_eq(marker.timestamp_ms, 1234567, "timestamp_ms 보존")
	assert_eq(marker.category, "crack", "카테고리 보존")


## TEST-INP-002-M2: HazardMarker는 Node3D 상속 (씬 트리 spawn 가능)
func test_hazard_marker_is_node3d() -> void:
	var marker := HazardMarker.new()
	add_child_autoqfree(marker)
	assert_true(marker is Node3D, "HazardMarker는 Node3D")


## TEST-INP-002-M3: HazardManager에 hazard_mark_placed (HazardMarkPlaced) 시그널 존재
func test_hazard_manager_has_mark_placed_signal() -> void:
	# HazardManager는 autoload — 직접 인스턴스화 불가, 시그널 목록만 검증
	assert_true(
		HazardManager.has_signal("hazard_mark_placed"),
		"hazard_mark_placed (HazardMarkPlaced) 시그널 존재"
	)


## TEST-INP-002-M4: 카테고리별 색상 분기
func test_category_colors_distinct() -> void:
	var crack := HazardMarker.CATEGORY_COLORS.get("crack", HazardMarker.DEFAULT_COLOR)
	var fp := HazardMarker.CATEGORY_COLORS.get("false_positive", HazardMarker.DEFAULT_COLOR)
	assert_ne(crack, fp, "crack과 false_positive 색이 달라야 한다")
	assert_ne(
		HazardMarker.CATEGORY_COLORS.get("unknown_cat", HazardMarker.DEFAULT_COLOR),
		HazardMarker.CATEGORY_COLORS["crack"],
		"미지정 카테고리는 DEFAULT_COLOR 사용",
	)

extends GutTest

# ======================================
# SPEC-HAZ-001: 위험 요소 기본 시스템 (배치 및 상태 관리)
# ======================================
# BaseHazard 상태 전환, CrackHazard 인스턴스화, HazardManager 등록/조회를 검증한다.


## TEST-HAZ-001: BaseHazard 초기 상태가 UNDISCOVERED인지
func test_base_hazard_initial_state() -> void:
	var hazard := BaseHazard.new()
	add_child_autoqfree(hazard)

	assert_eq(hazard.state, BaseHazard.HazardState.UNDISCOVERED, "초기 상태는 UNDISCOVERED")
	assert_false(hazard.is_discovered(), "is_discovered() == false")


## TEST-HAZ-001-2: discover() 호출 후 상태가 DISCOVERED로 변경
func test_discover_changes_state() -> void:
	var hazard := BaseHazard.new()
	add_child_autoqfree(hazard)
	watch_signals(hazard)

	var changed: bool = hazard.discover()

	assert_true(changed, "discover() 반환값 true (상태 변경됨)")
	assert_eq(hazard.state, BaseHazard.HazardState.DISCOVERED, "상태가 DISCOVERED")
	assert_true(hazard.is_discovered(), "is_discovered() == true")
	assert_signal_emitted(hazard, "state_changed", "state_changed 시그널 발행")


## TEST-HAZ-001-3: 이미 발견된 위험 요소 재발견 시 중복 처리 안 됨
func test_discover_duplicate_is_ignored() -> void:
	var hazard := BaseHazard.new()
	add_child_autoqfree(hazard)

	var first: bool = hazard.discover()
	assert_true(first, "첫 발견은 true")

	watch_signals(hazard)
	var second: bool = hazard.discover()

	assert_false(second, "재발견은 false (중복 무시)")
	assert_signal_not_emitted(hazard, "state_changed", "중복 시 시그널 미발행")


## TEST-HAZ-001-4: state_changed 시그널 파라미터가 DISCOVERED
func test_state_changed_signal_parameter() -> void:
	var hazard := BaseHazard.new()
	add_child_autoqfree(hazard)
	watch_signals(hazard)

	hazard.discover()

	var params: Array = get_signal_parameters(hazard, "state_changed")
	assert_eq(params[0], BaseHazard.HazardState.DISCOVERED, "시그널 파라미터 == DISCOVERED")


## TEST-HAZ-001-5: BaseHazard collision_layer가 HAZARD_COLLISION_LAYER(32)
func test_hazard_collision_layer() -> void:
	var hazard := BaseHazard.new()
	add_child_autoqfree(hazard)

	# _ready()에서 collision_layer가 설정됨
	assert_eq(hazard.collision_layer, BaseHazard.HAZARD_COLLISION_LAYER,
		"collision_layer == 32 (비트 5)")
	assert_eq(hazard.collision_mask, 0, "collision_mask == 0")
	assert_true(hazard.monitorable, "monitorable == true")
	assert_false(hazard.monitoring, "monitoring == false")


## TEST-HAZ-001-6: apply_hazard_data() — HazardData로부터 속성 설정
func test_apply_hazard_data() -> void:
	var hazard := BaseHazard.new()
	add_child_autoqfree(hazard)

	var data := HazardData.new()
	data.hazard_id = "crack_test_01"
	data.hazard_type = "crack"
	data.difficulty = 0.7
	data.position = Vector3(1.0, 2.0, 3.0)
	data.rotation_degrees = Vector3(0.0, 45.0, 0.0)

	hazard.apply_hazard_data(data)

	assert_eq(hazard.hazard_id, "crack_test_01", "hazard_id 적용")
	assert_eq(hazard.hazard_type, "crack", "hazard_type 적용")
	assert_almost_eq(hazard.difficulty, 0.7, 0.01, "difficulty 적용")
	assert_eq(hazard.position, Vector3(1.0, 2.0, 3.0), "position 적용")


## TEST-HAZ-001-7: get_hazard_data() — 현재 속성을 HazardData로 반환
func test_get_hazard_data() -> void:
	var hazard := BaseHazard.new()
	add_child_autoqfree(hazard)
	hazard.hazard_id = "test_02"
	hazard.hazard_type = "crack"
	hazard.difficulty = 0.4

	var data: HazardData = hazard.get_hazard_data()

	assert_eq(data.hazard_id, "test_02", "hazard_id 일치")
	assert_eq(data.hazard_type, "crack", "hazard_type 일치")
	assert_almost_eq(data.difficulty, 0.4, 0.01, "difficulty 일치")


## TEST-HAZ-001-8: CrackHazard 씬 인스턴스화 성공
func test_crack_hazard_scene_instantiation() -> void:
	var scene: PackedScene = load("res://scenes/hazards/crack_hazard.tscn")
	assert_not_null(scene, "crack_hazard.tscn 로드 성공")

	var node: Node = scene.instantiate()
	add_child_autoqfree(node)

	assert_true(node is CrackHazard, "CrackHazard 타입")
	assert_true(node is BaseHazard, "BaseHazard 상속")
	assert_true(node is Area3D, "Area3D 상속")
	assert_eq(node.hazard_type, "crack", "hazard_type == crack")


## TEST-HAZ-001-9: CrackHazard에 CrackDecal, DetectionArea, DiscoveredIndicator 자식 노드 존재
func test_crack_hazard_child_nodes() -> void:
	var scene: PackedScene = load("res://scenes/hazards/crack_hazard.tscn")
	var hazard: CrackHazard = scene.instantiate() as CrackHazard
	add_child_autoqfree(hazard)

	var crack_decal: Decal = hazard.get_node_or_null("CrackDecal") as Decal
	assert_not_null(crack_decal, "CrackDecal 노드 존재")
	assert_not_null(crack_decal.texture_albedo, "CrackDecal에 albedo 텍스처 할당됨")

	var detection_area: CollisionShape3D = hazard.get_node_or_null("DetectionArea") as CollisionShape3D
	assert_not_null(detection_area, "DetectionArea 노드 존재")
	assert_not_null(detection_area.shape, "DetectionArea에 셰이프 할당됨")

	var indicator: Node3D = hazard.get_node_or_null("DiscoveredIndicator")
	assert_not_null(indicator, "DiscoveredIndicator 노드 존재")
	assert_false(indicator.visible, "DiscoveredIndicator 초기 비활성")


## TEST-HAZ-001-10: HazardManager 등록/조회 — Autoload 싱글턴
func test_hazard_manager_registration() -> void:
	# Autoload HazardManager가 존재하는지 확인
	var manager: Node = Engine.get_singleton("HazardManager") if Engine.has_singleton("HazardManager") else get_node_or_null("/root/HazardManager")
	if manager == null:
		# GUT 환경에서 Autoload가 다르게 로드될 수 있음
		pending("HazardManager Autoload를 찾을 수 없음 (headless 환경)")
		return

	assert_true(manager.has_method("get_all_hazards"), "get_all_hazards 메서드 존재")
	assert_true(manager.has_method("get_discovered_hazards"), "get_discovered_hazards 메서드 존재")
	assert_true(manager.has_method("get_undiscovered_hazards"), "get_undiscovered_hazards 메서드 존재")
	assert_true(manager.has_method("spawn_hazard"), "spawn_hazard 메서드 존재")
	assert_true(manager.has_method("attempt_mark_hazard"), "attempt_mark_hazard 메서드 존재")


## TEST-HAZ-001-11: HazardData.to_dict() / from_dict() 왕복 변환
func test_hazard_data_serialization_roundtrip() -> void:
	var original := HazardData.new()
	original.hazard_id = "crack_rt_01"
	original.hazard_type = "crack"
	original.difficulty = 0.65
	original.position = Vector3(2.0, 0.5, -3.0)
	original.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	original.crack_length = 1.5
	original.crack_width = 0.04
	original.crack_branches = 3

	var dict: Dictionary = original.to_dict()
	var restored: HazardData = HazardData.from_dict(dict)

	assert_eq(restored.hazard_id, original.hazard_id, "hazard_id 왕복")
	assert_eq(restored.hazard_type, original.hazard_type, "hazard_type 왕복")
	assert_almost_eq(restored.difficulty, original.difficulty, 0.01, "difficulty 왕복")
	assert_almost_eq(restored.crack_length, original.crack_length, 0.01, "crack_length 왕복")
	assert_almost_eq(restored.crack_width, original.crack_width, 0.001, "crack_width 왕복")
	assert_eq(restored.crack_branches, original.crack_branches, "crack_branches 왕복")


## TEST-HAZ-001-12: HazardRules는 RefCounted (Domain 레이어 아키텍처 검증)
func test_hazard_rules_is_refcounted() -> void:
	var rules := HazardRules.new()
	assert_true(rules is RefCounted, "HazardRules는 RefCounted 상속")
	assert_eq(rules.get_class(), "RefCounted", "base class는 RefCounted")


## TEST-HAZ-001-13: HazardRules.is_within_detection_range() 판정
func test_hazard_rules_detection_range() -> void:
	var rules := HazardRules.new()

	# 범위 내
	assert_true(
		rules.is_within_detection_range(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), 2.0),
		"거리 1.0 <= 범위 2.0 → true"
	)
	# 범위 밖
	assert_false(
		rules.is_within_detection_range(Vector3.ZERO, Vector3(3.0, 0.0, 0.0), 2.0),
		"거리 3.0 > 범위 2.0 → false"
	)
	# 경계값 (정확히 범위)
	assert_true(
		rules.is_within_detection_range(Vector3.ZERO, Vector3(2.0, 0.0, 0.0), 2.0),
		"거리 2.0 == 범위 2.0 → true"
	)


## TEST-HAZ-001-14: HazardRules.calculate_difficulty_visual_params() 반환값 검증
func test_difficulty_visual_params() -> void:
	var rules := HazardRules.new()

	# 쉬운 난이도 (0.0)
	var easy: Dictionary = rules.calculate_difficulty_visual_params(0.0)
	assert_has(easy, "scale", "scale 키 존재")
	assert_has(easy, "opacity", "opacity 키 존재")
	assert_has(easy, "color_blend", "color_blend 키 존재")
	assert_almost_eq(easy["scale"], 1.5, 0.01, "난이도 0.0 → scale 1.5")
	assert_almost_eq(easy["opacity"], 1.0, 0.01, "난이도 0.0 → opacity 1.0")
	assert_almost_eq(easy["color_blend"], 0.0, 0.01, "난이도 0.0 → color_blend 0.0")

	# 어려운 난이도 (1.0)
	var hard: Dictionary = rules.calculate_difficulty_visual_params(1.0)
	assert_almost_eq(hard["scale"], 0.4, 0.01, "난이도 1.0 → scale 0.4")
	assert_almost_eq(hard["opacity"], 0.25, 0.01, "난이도 1.0 → opacity 0.25")
	assert_almost_eq(hard["color_blend"], 0.7, 0.01, "난이도 1.0 → color_blend 0.7")


## TEST-HAZ-001-E: 난이도 범위 밖 값 클램핑
func test_difficulty_clamping() -> void:
	var rules := HazardRules.new()

	var neg: Dictionary = rules.calculate_difficulty_visual_params(-0.5)
	assert_almost_eq(neg["scale"], 1.5, 0.01, "음수 난이도 → 0.0으로 클램프")

	var over: Dictionary = rules.calculate_difficulty_visual_params(2.0)
	assert_almost_eq(over["scale"], 0.4, 0.01, "2.0 난이도 → 1.0으로 클램프")

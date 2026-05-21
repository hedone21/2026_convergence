extends GutTest

# ======================================
# SPEC-SCN-002: 위험 요소 랜덤 배치
# ======================================
# ScenarioManager.generate_random_placement() 로직을 검증한다.
# 시드 재현성, 최소 간격, 배치 개수 등을 테스트한다.


## 테스트용 mock BaseSite
## surfaces를 빈 배열로 반환하여 bounds 전체에서 자유로운 랜덤 배치 테스트 가능
class MockSite extends BaseSite:
	func get_spawn_bounds() -> AABB:
		return AABB(Vector3(-50, 0, -50), Vector3(100, 10, 100))

	func get_valid_surfaces() -> Array:
		# 빈 배열 반환 → ScenarioManager가 bounds 내 랜덤 위치 사용
		return []

	func get_site_type() -> String:
		return "building_frame"


## ScenarioManager 인스턴스 획득 (Autoload)
func _get_scenario_manager() -> Node:
	return get_node_or_null("/root/ScenarioManager")


## TEST-SCN-002: 같은 seed → 같은 배치 결과
func test_same_seed_same_result() -> void:
	var manager: Node = _get_scenario_manager()
	if manager == null:
		pending("ScenarioManager Autoload를 찾을 수 없음")
		return

	var site: MockSite = MockSite.new()
	add_child_autoqfree(site)

	var config: Dictionary = {
		"hazard_count": 5,
		"types": ["crack"],
		"min_spacing": 1.0,
		"difficulty_range": [0.2, 0.8],
	}

	# 시드 고정
	manager.random_seed = 12345

	var result1: Array[HazardData] = manager.generate_random_placement(config, site)

	# 같은 시드로 다시 실행
	manager.random_seed = 12345
	var result2: Array[HazardData] = manager.generate_random_placement(config, site)

	assert_eq(result1.size(), result2.size(), "같은 seed → 같은 개수")

	for i: int in range(result1.size()):
		assert_almost_eq(result1[i].position.x, result2[i].position.x, 0.001,
			"hazard[%d] position.x 동일" % i)
		assert_almost_eq(result1[i].position.y, result2[i].position.y, 0.001,
			"hazard[%d] position.y 동일" % i)
		assert_almost_eq(result1[i].position.z, result2[i].position.z, 0.001,
			"hazard[%d] position.z 동일" % i)
		assert_almost_eq(result1[i].difficulty, result2[i].difficulty, 0.001,
			"hazard[%d] difficulty 동일" % i)


## TEST-SCN-002-2: 다른 seed → 다른 배치 결과
func test_different_seed_different_result() -> void:
	var manager: Node = _get_scenario_manager()
	if manager == null:
		pending("ScenarioManager Autoload를 찾을 수 없음")
		return

	var site: MockSite = MockSite.new()
	add_child_autoqfree(site)

	var config: Dictionary = {
		"hazard_count": 5,
		"types": ["crack"],
		"min_spacing": 1.0,
		"difficulty_range": [0.2, 0.8],
	}

	manager.random_seed = 11111
	var result1: Array[HazardData] = manager.generate_random_placement(config, site)

	manager.random_seed = 99999
	var result2: Array[HazardData] = manager.generate_random_placement(config, site)

	# 모든 위치가 동일할 확률은 극히 낮음 — 최소 하나라도 다르면 통과
	var any_different: bool = false
	for i: int in range(mini(result1.size(), result2.size())):
		if result1[i].position.distance_to(result2[i].position) > 0.01:
			any_different = true
			break
	assert_true(any_different, "다른 seed → 최소 하나의 위치가 다름")


## TEST-SCN-002-3: min_spacing 보장
func test_min_spacing_guaranteed() -> void:
	var manager: Node = _get_scenario_manager()
	if manager == null:
		pending("ScenarioManager Autoload를 찾을 수 없음")
		return

	var site: MockSite = MockSite.new()
	add_child_autoqfree(site)

	var min_spacing: float = 3.0
	var config: Dictionary = {
		"hazard_count": 5,
		"types": ["crack"],
		"min_spacing": min_spacing,
		"difficulty_range": [0.3, 0.7],
	}

	manager.random_seed = 42
	var result: Array[HazardData] = manager.generate_random_placement(config, site)

	# 모든 쌍의 거리가 min_spacing 이상인지 확인
	for i: int in range(result.size()):
		for j: int in range(i + 1, result.size()):
			var dist: float = result[i].position.distance_to(result[j].position)
			assert_true(dist >= min_spacing - 0.01,
				"hazard[%d]-[%d] 거리 %.2f >= min_spacing %.1f" % [i, j, dist, min_spacing])


## TEST-SCN-002-4: hazard_count만큼 생성
func test_hazard_count_matches() -> void:
	var manager: Node = _get_scenario_manager()
	if manager == null:
		pending("ScenarioManager Autoload를 찾을 수 없음")
		return

	var site: MockSite = MockSite.new()
	add_child_autoqfree(site)

	var config: Dictionary = {
		"hazard_count": 3,
		"types": ["crack"],
		"min_spacing": 1.0,
		"difficulty_range": [0.3, 0.7],
	}

	manager.random_seed = 42
	var result: Array[HazardData] = manager.generate_random_placement(config, site)

	assert_eq(result.size(), 3, "hazard_count=3 → 3개 생성")


## TEST-SCN-002-5: difficulty_range 범위 내 생성
func test_difficulty_within_range() -> void:
	var manager: Node = _get_scenario_manager()
	if manager == null:
		pending("ScenarioManager Autoload를 찾을 수 없음")
		return

	var site: MockSite = MockSite.new()
	add_child_autoqfree(site)

	var diff_min: float = 0.3
	var diff_max: float = 0.7
	var config: Dictionary = {
		"hazard_count": 10,
		"types": ["crack"],
		"min_spacing": 0.5,
		"difficulty_range": [diff_min, diff_max],
	}

	manager.random_seed = 42
	var result: Array[HazardData] = manager.generate_random_placement(config, site)

	for i: int in range(result.size()):
		assert_true(result[i].difficulty >= diff_min - 0.001,
			"hazard[%d] difficulty %.3f >= %.1f" % [i, result[i].difficulty, diff_min])
		assert_true(result[i].difficulty <= diff_max + 0.001,
			"hazard[%d] difficulty %.3f <= %.1f" % [i, result[i].difficulty, diff_max])


## TEST-SCN-002-6: hazard_id 형식 확인 — "{type}_{nn}"
func test_hazard_id_format() -> void:
	var manager: Node = _get_scenario_manager()
	if manager == null:
		pending("ScenarioManager Autoload를 찾을 수 없음")
		return

	var site: MockSite = MockSite.new()
	add_child_autoqfree(site)

	var config: Dictionary = {
		"hazard_count": 3,
		"types": ["crack"],
		"min_spacing": 1.0,
		"difficulty_range": [0.3, 0.7],
	}

	manager.random_seed = 42
	var result: Array[HazardData] = manager.generate_random_placement(config, site)

	for hd: HazardData in result:
		assert_true(hd.hazard_id.begins_with("crack_"), "hazard_id가 crack_으로 시작: %s" % hd.hazard_id)
		assert_false(hd.hazard_id.is_empty(), "hazard_id가 비어있지 않음")


## TEST-SCN-002-FLOOR: floor surface_type → 상단 Y 안착.
## hazard가 AABB 내부 random Y로 떨어지면 floor에 묻힘. 상단 Y에 고정되어야 한다.
func test_floor_surface_places_on_top() -> void:
	var manager: Node = _get_scenario_manager()
	if manager == null:
		pending("ScenarioManager Autoload 없음")
		return

	## floor surface 1개만 가진 Mock site — y_top = 0.0 (slab AABB y=-0.25, size.y=0.25).
	var floor_site: BaseSite = _FloorOnlySite.new()
	add_child_autoqfree(floor_site)

	var config: Dictionary = {
		"hazard_count": 10,
		"types": ["debris"],
		"min_spacing": 0.5,
		"difficulty_range": [0.3, 0.7],
	}
	manager.random_seed = 9999
	var result: Array[HazardData] = manager.generate_random_placement(config, floor_site)

	assert_eq(result.size(), 10, "10개 모두 배치")
	for i: int in range(result.size()):
		# floor 상단 = aabb.position.y + aabb.size.y = -0.25 + 0.25 = 0.0
		assert_almost_eq(result[i].position.y, 0.0, 0.001,
			"hazard[%d] Y가 floor 상단 0.0에 안착 (실제=%f)" % [i, result[i].position.y])


## floor surface 1개만 등록한 Mock — floor-안착 테스트용.
class _FloorOnlySite extends BaseSite:
	func get_spawn_bounds() -> AABB:
		return AABB(Vector3(-10, -1, -10), Vector3(20, 5, 20))

	func get_valid_surfaces() -> Array:
		return [{
			"node": self,
			"surface_type": "floor",
			"aabb": AABB(Vector3(-10, -0.25, -10), Vector3(20, 0.25, 20))
		}]

	func get_site_type() -> String:
		return "test_floor_only"


## TEST-SCN-002-EDGE: edge surface_type → unguarded_edge가 edge 우선 매칭.
func test_edge_surface_prefers_unguarded_edge() -> void:
	var manager: Node = _get_scenario_manager()
	if manager == null:
		pending("ScenarioManager Autoload 없음")
		return

	var site: BaseSite = _EdgeAndFloorSite.new()
	add_child_autoqfree(site)

	var config: Dictionary = {
		"hazard_count": 5,
		"types": ["unguarded_edge"],
		"min_spacing": 0.5,
		"difficulty_range": [0.3, 0.7],
	}
	manager.random_seed = 5555
	var result: Array[HazardData] = manager.generate_random_placement(config, site)

	assert_gt(result.size(), 0, "최소 1개 배치")
	## edge AABB: x ∈ [-10, -9] (서쪽 띠) 또는 x ∈ [9, 10] (동쪽 띠).
	## floor AABB: x ∈ [-10, 10]. edge가 우선 매칭되면 모든 x가 edge 범위 안.
	var on_edge: int = 0
	for hd: HazardData in result:
		var on_west: bool = hd.position.x <= -9.0
		var on_east: bool = hd.position.x >= 9.0
		if on_west or on_east:
			on_edge += 1
	assert_eq(on_edge, result.size(),
		"모든 unguarded_edge가 edge surface에 매칭 (%d/%d)" % [on_edge, result.size()])


class _EdgeAndFloorSite extends BaseSite:
	func get_spawn_bounds() -> AABB:
		return AABB(Vector3(-10, -1, -10), Vector3(20, 5, 20))

	func get_valid_surfaces() -> Array:
		return [
			{"node": self, "surface_type": "floor",
				"aabb": AABB(Vector3(-10, -0.25, -10), Vector3(20, 0.25, 20))},
			{"node": self, "surface_type": "edge",
				"aabb": AABB(Vector3(-10, -0.25, -10), Vector3(1.0, 0.25, 20))},
			{"node": self, "surface_type": "edge",
				"aabb": AABB(Vector3(9, -0.25, -10), Vector3(1.0, 0.25, 20))},
		]

	func get_site_type() -> String:
		return "test_edge"


## TEST-SCN-002-BLOCK: site.is_position_blocked → 차단 위치에 spawn 안 됨.
func test_is_position_blocked_respected() -> void:
	var manager: Node = _get_scenario_manager()
	if manager == null:
		pending("ScenarioManager Autoload 없음")
		return

	var site: BaseSite = _BlockedZoneSite.new()
	add_child_autoqfree(site)

	var config: Dictionary = {
		"hazard_count": 8,
		"types": ["debris"],
		"min_spacing": 0.3,
		"difficulty_range": [0.3, 0.7],
	}
	manager.random_seed = 3131
	var result: Array[HazardData] = manager.generate_random_placement(config, site)

	## 차단 영역 X ∈ [-2, 2] — 모든 hazard가 그 밖.
	for hd: HazardData in result:
		assert_true(absf(hd.position.x) > 2.0 - 0.01,
			"hazard X=%f 차단 영역(|x|<=2) 밖" % hd.position.x)


class _BlockedZoneSite extends BaseSite:
	func get_spawn_bounds() -> AABB:
		return AABB(Vector3(-10, -1, -10), Vector3(20, 5, 20))

	func get_valid_surfaces() -> Array:
		return [{"node": self, "surface_type": "floor",
			"aabb": AABB(Vector3(-10, -0.25, -10), Vector3(20, 0.25, 20))}]

	func get_site_type() -> String:
		return "test_blocked"

	## X 중앙 ±2m 영역을 spawn 차단 (시뮬: 가운데에 가로 벽).
	func is_position_blocked(pos: Vector3) -> bool:
		return absf(pos.x) <= 2.0


## TEST-SCN-002-7: _check_min_spacing 내부 함수 검증
func test_check_min_spacing_logic() -> void:
	var manager: Node = _get_scenario_manager()
	if manager == null:
		pending("ScenarioManager Autoload를 찾을 수 없음")
		return

	# 빈 placed 배열 → 항상 true
	var placed_empty: Array[Vector3] = []
	var r1: bool = manager._check_min_spacing(Vector3.ZERO, placed_empty, 2.0)
	assert_true(r1, "빈 배열 → true")

	# 충분한 거리
	var placed_one: Array[Vector3] = [Vector3.ZERO]
	var r2: bool = manager._check_min_spacing(Vector3(5, 0, 0), placed_one, 2.0)
	assert_true(r2, "거리 5.0 >= min_spacing 2.0 → true")

	# 불충분한 거리
	var r3: bool = manager._check_min_spacing(Vector3(1, 0, 0), placed_one, 2.0)
	assert_false(r3, "거리 1.0 < min_spacing 2.0 → false")


## TEST-SCN-002-8: random_config 검증 — hazard_count 누락
func test_validator_random_config_missing_count() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"scenario_id": "test_rand",
		"site_type": "building_frame",
		"time_limit_seconds": 300,
		"random_placement": true,
		"random_config": {
			"types": ["crack"],
		},
	}
	var errors: Array[String] = validator.validate(data)
	var has_count_error: bool = false
	for err: String in errors:
		if "hazard_count" in err:
			has_count_error = true
			break
	assert_true(has_count_error, "hazard_count 누락 에러")


## TEST-SCN-002-9: random_config 검증 — types 누락
func test_validator_random_config_missing_types() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"scenario_id": "test_rand",
		"site_type": "building_frame",
		"time_limit_seconds": 300,
		"random_placement": true,
		"random_config": {
			"hazard_count": 3,
		},
	}
	var errors: Array[String] = validator.validate(data)
	var has_types_error: bool = false
	for err: String in errors:
		if "types" in err:
			has_types_error = true
			break
	assert_true(has_types_error, "types 누락 에러")


## TEST-SCN-002-10: random_placement=true이지만 random_config 누락
func test_validator_random_no_config() -> void:
	var validator := ScenarioValidator.new()
	var data: Dictionary = {
		"scenario_id": "test_no_config",
		"site_type": "building_frame",
		"time_limit_seconds": 300,
		"random_placement": true,
	}
	var errors: Array[String] = validator.validate(data)
	var has_config_error: bool = false
	for err: String in errors:
		if "random_config" in err:
			has_config_error = true
			break
	assert_true(has_config_error, "random_config 누락 에러")

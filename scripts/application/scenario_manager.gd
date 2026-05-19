extends Node

## SPEC-SCN-001: 시나리오 설정 파일 로딩 및 검증
## SPEC-SCN-002: 위험 요소 랜덤 배치
##
## ScenarioManager Autoload -- 시나리오 설정 파일 로딩, 파싱, 검증 조율, 랜덤 배치 생성
## 검증 로직은 Domain의 ScenarioValidator에 위임한다.
## SOLID D: ScenarioData(Domain)에 의존, 구체 현장/위험요소 클래스를 직접 참조하지 않는다.

## SPEC-SCN-001: 시나리오 로드 완료
signal scenario_loaded(data: ScenarioData)

## SPEC-SCN-001: 시나리오 로드 실패
signal scenario_load_failed(error: String)

## SPEC-SCN-002: 위험 요소 배치 완료
signal hazards_placed

## 현재 로드된 시나리오
var current_scenario: ScenarioData = null

## 기본 시나리오 경로
## SPEC-ENV-003: Parliament Village South Hall 도면 기반 사이트 사용
var default_scenario_path: String = "res://resources/scenarios/mvp_parliament.json"

## SPEC-SCN-002: 랜덤 시드 (0이면 시스템 시간 기반)
var random_seed: int = 0

## Domain 서비스
var _validator: ScenarioValidator = ScenarioValidator.new()


func _ready() -> void:
	print("[ScenarioManager] Initialized.")


## SPEC-SCN-001: JSON 파일에서 시나리오를 로드하고 검증한다.
## 성공 시 ScenarioData를 반환하며 scenario_loaded 시그널을 발행한다.
## 실패 시 null을 반환하며 scenario_load_failed 시그널을 발행한다.
func load_scenario(path: String) -> ScenarioData:
	print("[ScenarioManager] Loading scenario: %s" % path)

	# JSON 파일 읽기
	if not FileAccess.file_exists(path):
		var err_msg: String = "SPEC-SCN-001: 시나리오 파일을 찾을 수 없습니다: %s" % path
		push_error(err_msg)
		scenario_load_failed.emit(err_msg)
		return null

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var err_msg: String = "SPEC-SCN-001: 시나리오 파일 열기 실패: %s (%s)" % [
			path, error_string(FileAccess.get_open_error())
		]
		push_error(err_msg)
		scenario_load_failed.emit(err_msg)
		return null

	var json_text: String = file.get_as_text()
	file.close()

	# JSON 파싱
	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(json_text)
	if parse_err != OK:
		var err_msg: String = "SPEC-SCN-001: JSON 파싱 실패 (line %d): %s" % [
			json.get_error_line(), json.get_error_message()
		]
		push_error(err_msg)
		scenario_load_failed.emit(err_msg)
		return null

	var data: Variant = json.data
	if not data is Dictionary:
		var err_msg: String = "SPEC-SCN-001: JSON 루트가 Dictionary가 아닙니다"
		push_error(err_msg)
		scenario_load_failed.emit(err_msg)
		return null

	# 검증 (Domain의 ScenarioValidator에 위임)
	var validation_errors: Array[String] = validate_scenario(data as Dictionary)
	if not validation_errors.is_empty():
		var err_msg: String = "SPEC-SCN-001: 시나리오 검증 실패:\n  - %s" % "\n  - ".join(
			PackedStringArray(validation_errors)
		)
		push_error(err_msg)
		scenario_load_failed.emit(err_msg)
		return null

	# ScenarioData 생성
	current_scenario = ScenarioData.from_dict(data as Dictionary)
	random_seed = current_scenario.random_seed

	print("[ScenarioManager] Scenario loaded: %s (site=%s, time=%ds, random=%s)" % [
		current_scenario.scenario_id,
		current_scenario.site_type,
		current_scenario.time_limit_seconds,
		str(current_scenario.random_placement),
	])

	scenario_loaded.emit(current_scenario)
	return current_scenario


## SPEC-SCN-001: 기본 시나리오를 로드한다.
func load_default_scenario() -> ScenarioData:
	print("[ScenarioManager] Loading default scenario: %s" % default_scenario_path)
	return load_scenario(default_scenario_path)


## SPEC-SCN-001: 시나리오 데이터를 검증한다 (ScenarioValidator에 위임).
## 에러 목록을 반환한다 (빈 배열이면 유효).
func validate_scenario(data: Dictionary) -> Array[String]:
	return _validator.validate(data)


## SPEC-SCN-002: 랜덤 배치를 생성한다.
## config: random_config Dictionary
## site: BaseSite -- get_spawn_bounds()로 배치 가능 영역을 획득한다.
## 반환: 생성된 HazardData 배열
func generate_random_placement(config: Dictionary, site: BaseSite) -> Array[HazardData]:
	var result: Array[HazardData] = []

	var hazard_count: int = int(config.get("hazard_count", 3))
	var types: Array = config.get("types", ["crack"])
	var min_spacing: float = float(config.get("min_spacing", 2.0))
	var difficulty_range: Array = config.get("difficulty_range", [0.3, 0.8])
	var diff_min: float = clampf(float(difficulty_range[0]), 0.0, 1.0) if difficulty_range.size() >= 1 else 0.3
	var diff_max: float = clampf(float(difficulty_range[1]), 0.0, 1.0) if difficulty_range.size() >= 2 else 0.8

	# SPEC-SCN-002: 시드 기반 재현 가능한 랜덤
	var effective_seed: int = random_seed
	if effective_seed == 0:
		effective_seed = int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = effective_seed
	print("[ScenarioManager] Random placement seed: %d" % effective_seed)

	# 배치 가능 영역
	var bounds: AABB = site.get_spawn_bounds()
	var surfaces: Array = site.get_valid_surfaces()

	# 이미 배치된 위치 목록 (최소 간격 검증용)
	var placed_positions: Array[Vector3] = []

	# 최대 시도 횟수 (무한 루프 방지)
	var max_attempts_per_hazard: int = 50

	for i: int in range(hazard_count):
		var placed: bool = false

		for attempt: int in range(max_attempts_per_hazard):
			# 유효 표면에서 랜덤 위치 생성
			var position: Vector3 = _generate_random_position_on_surface(
				rng, surfaces, bounds
			)

			# SPEC-SCN-002: 최소 간격 검증
			if _check_min_spacing(position, placed_positions, min_spacing):
				# 위험 요소 유형 선택
				var hazard_type: String = types[rng.randi() % types.size()] as String

				# 난이도 랜덤 생성
				var difficulty: float = rng.randf_range(diff_min, diff_max)

				# 회전 랜덤 생성 (Y축 기준)
				var rotation_y: float = rng.randf_range(0.0, 360.0)

				# HazardData 생성
				var hd: HazardData = HazardData.new()
				hd.hazard_id = "%s_%02d" % [hazard_type, i + 1]
				hd.hazard_type = hazard_type
				hd.difficulty = difficulty
				hd.position = position
				hd.rotation_degrees = Vector3(0.0, rotation_y, 0.0)

				# 크랙 파라미터 (난이도 기반 조정)
				if hazard_type == "crack":
					hd.crack_length = rng.randf_range(0.2, 1.0) * (1.0 - difficulty * 0.5)
					hd.crack_width = rng.randf_range(0.005, 0.03) * (1.0 - difficulty * 0.5)
					hd.crack_branches = rng.randi_range(0, 3)

				result.append(hd)
				placed_positions.append(position)
				placed = true
				break

		if not placed:
			push_warning(
				"SPEC-SCN-002: 위험 요소 %d번째 배치 실패 (최대 시도 %d회 초과). 건너뜁니다." % [
					i + 1, max_attempts_per_hazard
				]
			)

	if result.size() < hazard_count:
		push_warning(
			"SPEC-SCN-002: 요청 %d개 중 %d개만 배치 성공 (유효 위치 부족)" % [
				hazard_count, result.size()
			]
		)

	print("[ScenarioManager] Random placement complete: %d/%d hazards placed" % [
		result.size(), hazard_count
	])
	return result


## 현장 유형에 맞는 씬을 SiteContainer에 로드한다.
func _load_site() -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return

	var site_container: Node3D = main_scene.get_node_or_null("SiteContainer") as Node3D
	if site_container == null:
		push_error("[ScenarioManager] SiteContainer not found in main scene.")
		return

	# 기존 환경 제거
	for child: Node in site_container.get_children():
		child.queue_free()

	# 현장 유형에 따라 씬 로드
	var site_type: String = current_scenario.site_type if current_scenario else "building_frame"
	var site_scene_path: String = "res://scenes/environment/%s.tscn" % site_type

	if not ResourceLoader.exists(site_scene_path):
		push_warning("[ScenarioManager] Site scene not found: %s. Using building_frame." % site_scene_path)
		site_scene_path = "res://scenes/environment/building_frame.tscn"

	var site_scene: PackedScene = load(site_scene_path) as PackedScene
	if site_scene:
		var site_instance: Node3D = site_scene.instantiate() as Node3D
		site_container.add_child(site_instance)
		print("[ScenarioManager] Site loaded: %s" % site_type)
	else:
		push_error("[ScenarioManager] Failed to load site scene: %s" % site_scene_path)


## SPEC-SCN-001, SPEC-SCN-002: 시나리오를 씬에 적용한다.
## HazardManager에 위임하여 위험 요소를 생성한다.
func apply_scenario() -> void:
	if current_scenario == null:
		push_error("SPEC-SCN-001: 적용할 시나리오가 없습니다. load_scenario()를 먼저 호출하세요.")
		return

	# 환경 로드
	_load_site()

	var hazard_list: Array[HazardData] = []

	if current_scenario.random_placement:
		# SPEC-SCN-002: 랜덤 배치 모드
		var site: BaseSite = _find_current_site()
		if site == null:
			push_error("SPEC-SCN-002: 현재 씬에서 BaseSite를 찾을 수 없습니다. 랜덤 배치 불가.")
			return
		hazard_list = generate_random_placement(current_scenario.random_config, site)
		# 랜덤 생성된 hazard 목록을 시나리오에 저장 (재현성 기록)
		current_scenario.hazards = hazard_list
	else:
		hazard_list = current_scenario.hazards

	if hazard_list.is_empty():
		push_warning("SPEC-SCN-001: 시나리오에 위험 요소가 없습니다.")

	# HazardManager에 위임
	HazardManager.clear_hazards()
	for hd: HazardData in hazard_list:
		HazardManager.spawn_hazard(hd)

	hazards_placed.emit()
	print("[ScenarioManager] Scenario applied: %d hazards spawned" % hazard_list.size())


## 현장 유형 문자열을 반환한다.
func get_site_type() -> String:
	if current_scenario != null:
		return current_scenario.site_type
	return "building_frame"


## 유효 표면 위 랜덤 위치를 생성한다.
func _generate_random_position_on_surface(
	rng: RandomNumberGenerator,
	surfaces: Array,
	bounds: AABB,
) -> Vector3:
	if surfaces.is_empty():
		# 표면 정보가 없으면 바운드 내 랜덤 위치
		return Vector3(
			rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
			rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y),
			rng.randf_range(bounds.position.z, bounds.position.z + bounds.size.z),
		)

	# 랜덤 표면 선택
	var surface: Dictionary = surfaces[rng.randi() % surfaces.size()]
	var aabb: AABB = surface.get("aabb", AABB()) as AABB
	var surface_type: String = surface.get("surface_type", "") as String

	# 표면 유형에 따라 적절한 위치 생성
	match surface_type:
		"column":
			# 기둥 표면 — AABB 표면 위에 배치
			var side: int = rng.randi() % 4  # 0=+x, 1=-x, 2=+z, 3=-z
			var y: float = rng.randf_range(aabb.position.y + 0.5, aabb.position.y + aabb.size.y - 0.5)
			var center_x: float = aabb.position.x + aabb.size.x / 2.0
			var center_z: float = aabb.position.z + aabb.size.z / 2.0
			match side:
				0: return Vector3(aabb.position.x + aabb.size.x + 0.001, y, center_z)
				1: return Vector3(aabb.position.x - 0.001, y, center_z)
				2: return Vector3(center_x, y, aabb.position.z + aabb.size.z + 0.001)
				_: return Vector3(center_x, y, aabb.position.z - 0.001)
		"wall":
			# 벽면 — 벽 표면에 배치
			var y: float = rng.randf_range(0.5, aabb.size.y - 0.5)
			var center_x: float = aabb.position.x + aabb.size.x / 2.0
			var center_z: float = aabb.position.z + aabb.size.z / 2.0
			return Vector3(center_x + 0.001, y, center_z)
		"beam":
			# 보 표면 — 하단면에 배치
			var x: float = rng.randf_range(aabb.position.x + 0.2, aabb.position.x + aabb.size.x - 0.2)
			var z: float = rng.randf_range(aabb.position.z + 0.1, aabb.position.z + aabb.size.z - 0.1)
			return Vector3(x, aabb.position.y - 0.001, z)
		"slab":
			# 슬래브 — 하단면에 배치
			var x: float = rng.randf_range(aabb.position.x + 1.0, aabb.position.x + aabb.size.x - 1.0)
			var z: float = rng.randf_range(aabb.position.z + 1.0, aabb.position.z + aabb.size.z - 1.0)
			return Vector3(x, aabb.position.y - 0.001, z)
		_:
			# 기본: AABB 내부 랜덤 위치
			return Vector3(
				rng.randf_range(aabb.position.x, aabb.position.x + aabb.size.x),
				rng.randf_range(aabb.position.y, aabb.position.y + aabb.size.y),
				rng.randf_range(aabb.position.z, aabb.position.z + aabb.size.z),
			)

	# unreachable, but GDScript requires return
	return Vector3.ZERO


## SPEC-SCN-002: 최소 간격을 검증한다.
func _check_min_spacing(
	position: Vector3,
	placed: Array[Vector3],
	min_spacing: float,
) -> bool:
	for p: Vector3 in placed:
		if position.distance_to(p) < min_spacing:
			return false
	return true


## 현재 씬에서 BaseSite를 찾는다.
func _find_current_site() -> BaseSite:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return null

	# SiteContainer 하위에서 BaseSite 검색
	var site_container: Node = main_scene.get_node_or_null("SiteContainer")
	if site_container != null:
		for child: Node in site_container.get_children():
			if child is BaseSite:
				return child as BaseSite

	# 메인 씬 직접 하위에서 검색
	for child: Node in main_scene.get_children():
		if child is BaseSite:
			return child as BaseSite

	return null

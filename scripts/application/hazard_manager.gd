extends Node

## SPEC-HAZ-001: 위험 요소 기본 시스템 (배치 및 상태 관리)
## SPEC-ENV-002: 크랙 절차적 생성 시스템
##
## HazardManager Autoload — 위험 요소 인스턴스 관리, 상태 추적, 발견 처리
## 판정 규칙은 Domain의 HazardRules에 위임한다.
## SOLID D: BaseHazard 추상 타입에 의존, 구체 Hazard 클래스를 직접 참조하지 않는다.

## SPEC-HAZ-001: 위험 요소 생성됨
signal hazard_spawned(hazard: BaseHazard)

## SPEC-HAZ-001: 위험 요소 발견됨
signal hazard_discovered(hazard: BaseHazard)

## SPEC-INP-002: 오탐 (위험 요소가 아닌 곳 마킹)
signal false_positive(position: Vector3, direction: Vector3)

## SPEC-INP-002: 마킹 마커가 배치됨 (HazardMarkPlaced) — Vec3 + Unix epoch ms + 카테고리
signal hazard_mark_placed(marker_position: Vector3, timestamp_ms: int, category: String)

## SPEC-HAZ-001: 모든 위험 요소가 발견됨
signal all_hazards_discovered

## 현재 씬의 모든 위험 요소
var hazards: Array[BaseHazard] = []

## 발견된 위험 요소 수
var discovered_count: int = 0

## 위험 요소 컨테이너 노드 (메인 씬의 HazardContainer)
var hazard_container: Node3D = null

## 크랙 위험 요소 씬
var _crack_hazard_scene: PackedScene = preload("res://scenes/hazards/crack_hazard.tscn")

## SPEC-HAZ-003: 단순 위험 요소 씬 (BaseHazard 기반 5종)
var _simple_hazard_scenes: Dictionary = {
	"spill": preload("res://scenes/hazards/spill_hazard.tscn"),
	"debris": preload("res://scenes/hazards/debris_hazard.tscn"),
	"unguarded_edge": preload("res://scenes/hazards/unguarded_edge_hazard.tscn"),
	"exposed_rebar": preload("res://scenes/hazards/exposed_rebar_hazard.tscn"),
	"wet_floor": preload("res://scenes/hazards/wet_floor_hazard.tscn"),
}

## Domain 서비스
var _hazard_rules: HazardRules = HazardRules.new()


func _ready() -> void:
	# 메인 씬의 HazardContainer를 찾아 연결
	call_deferred("_find_hazard_container")
	print("[HazardManager] Initialized.")


## SPEC-HAZ-001: 위험 요소를 생성한다.
## data: HazardData — 위험 요소 설정 데이터
## 반환: 생성된 BaseHazard 인스턴스 (실패 시 null)
func spawn_hazard(data: HazardData) -> BaseHazard:
	if hazard_container == null:
		_find_hazard_container()
		if hazard_container == null:
			push_error("SPEC-HAZ-001: HazardContainer를 찾을 수 없습니다. 위험 요소를 생성할 수 없습니다.")
			return null

	var hazard: BaseHazard = null

	match data.hazard_type:
		"crack":
			hazard = _spawn_crack_hazard(data)
		"spill", "debris", "unguarded_edge", "exposed_rebar", "wet_floor":
			hazard = _spawn_simple_hazard(data)
		_:
			push_warning("SPEC-HAZ-001: 알 수 없는 위험 요소 유형: %s. crack으로 대체합니다." % data.hazard_type)
			data.hazard_type = "crack"
			hazard = _spawn_crack_hazard(data)

	if hazard == null:
		push_error("SPEC-HAZ-001: 위험 요소 생성 실패: %s" % data.hazard_id)
		return null

	# 상태 변경 시그널 구독
	hazard.state_changed.connect(_on_hazard_state_changed.bind(hazard))

	hazards.append(hazard)
	hazard_spawned.emit(hazard)
	print("[HazardManager] Hazard spawned: %s (type=%s, difficulty=%.2f)" % [
		data.hazard_id, data.hazard_type, data.difficulty
	])

	return hazard


## SPEC-INP-002: 마킹 시도를 처리한다.
## InputManager의 MarkingSystem에서 호출된다.
## hazard: 적중한 위험 요소 (BaseHazard)
## hit_position: 적중 위치
## 반환: MarkingResult
func attempt_mark_hazard(hazard: BaseHazard, hit_position: Vector3) -> MarkingResult:
	var result: MarkingResult = MarkingResult.new()
	result.hazard_id = hazard.hazard_id
	result.hazard_type = hazard.hazard_type
	result.hazard_difficulty = hazard.difficulty
	result.timestamp = Time.get_ticks_msec()
	result.player_position = hit_position

	if hazard.is_discovered():
		# 이미 발견된 위험 요소 — 중복 마킹 (에러 없이 무시)
		result.is_correct = false
		return result

	# 발견 처리
	var changed: bool = hazard.discover()
	result.is_correct = changed

	return result


## SPEC-INP-002: 마커 노드를 spawn하고 hazard_mark_placed 시그널을 발행한다.
## category — 적중한 hazard.hazard_type 또는 "false_positive".
## 반환: 생성된 HazardMarker (실패 시 null).
func place_marker(pos: Vector3, category: String) -> HazardMarker:
	var ts: int = Time.get_ticks_msec()
	var marker: HazardMarker = HazardMarker.new()
	marker.place(pos, ts, category)
	var parent: Node = hazard_container
	if parent == null:
		var scene: Node = get_tree().current_scene if get_tree() != null else null
		parent = scene if scene != null else self
	parent.add_child(marker)
	hazard_mark_placed.emit(pos, ts, category)
	return marker


## SPEC-INP-002: 오탐을 기록한다.
func record_false_positive(position: Vector3, direction: Vector3) -> MarkingResult:
	var result: MarkingResult = MarkingResult.new()
	result.hazard_id = ""  # 빈 ID = 오탐
	result.is_correct = false
	result.timestamp = Time.get_ticks_msec()
	result.player_position = position
	result.gaze_direction = direction

	false_positive.emit(position, direction)
	return result


## SPEC-HAZ-001: 전체 위험 요소 목록을 반환한다.
func get_all_hazards() -> Array[BaseHazard]:
	return hazards


## SPEC-HAZ-001: 발견된 위험 요소만 반환한다.
func get_discovered_hazards() -> Array[BaseHazard]:
	var discovered: Array[BaseHazard] = []
	for h: BaseHazard in hazards:
		if h.is_discovered():
			discovered.append(h)
	return discovered


## SPEC-HAZ-001: 미발견 위험 요소만 반환한다.
func get_undiscovered_hazards() -> Array[BaseHazard]:
	var undiscovered: Array[BaseHazard] = []
	for h: BaseHazard in hazards:
		if not h.is_discovered():
			undiscovered.append(h)
	return undiscovered


## SPEC-DAT-002: 현재 발견율을 반환한다 (0.0 ~ 100.0).
func get_discovery_rate() -> float:
	if hazards.is_empty():
		return 0.0
	return float(discovered_count) / float(hazards.size()) * 100.0


## 모든 위험 요소를 제거한다 (씬 전환 시).
func clear_hazards() -> void:
	for h: BaseHazard in hazards:
		if is_instance_valid(h):
			h.queue_free()
	hazards.clear()
	discovered_count = 0


## 위험 요소가 0개인지 경고한다.
func check_empty_hazards() -> void:
	if hazards.is_empty():
		push_warning("SPEC-HAZ-001: 현재 씬에 위험 요소가 0개입니다.")


## 크랙 위험 요소를 생성한다.
func _spawn_crack_hazard(data: HazardData) -> BaseHazard:
	var hazard_node: Node = _crack_hazard_scene.instantiate()
	var hazard: CrackHazard = hazard_node as CrackHazard
	if hazard == null:
		push_error("SPEC-ENV-002: crack_hazard.tscn 인스턴스가 CrackHazard가 아닙니다.")
		hazard_node.queue_free()
		return null

	hazard.apply_hazard_data(data)
	hazard.name = data.hazard_id
	hazard_container.add_child(hazard)
	return hazard


## SPEC-HAZ-003: 단순 위험 요소(SimpleHazard 기반)를 생성한다.
func _spawn_simple_hazard(data: HazardData) -> BaseHazard:
	var scene: PackedScene = _simple_hazard_scenes.get(data.hazard_type, null)
	if scene == null:
		push_error("SPEC-HAZ-003: 알 수 없는 단순 hazard 유형: %s" % data.hazard_type)
		return null
	var hazard_node: Node = scene.instantiate()
	var hazard: SimpleHazard = hazard_node as SimpleHazard
	if hazard == null:
		push_error("SPEC-HAZ-003: %s tscn 인스턴스가 SimpleHazard가 아닙니다." % data.hazard_type)
		hazard_node.queue_free()
		return null
	hazard.apply_hazard_data(data)
	hazard.name = data.hazard_id
	hazard_container.add_child(hazard)
	return hazard


## 메인 씬에서 HazardContainer 노드를 찾는다.
func _find_hazard_container() -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return
	hazard_container = main_scene.get_node_or_null("HazardContainer") as Node3D
	if hazard_container == null:
		push_warning("[HazardManager] HazardContainer not found in main scene.")


## 위험 요소 상태 변경 핸들러
func _on_hazard_state_changed(new_state: BaseHazard.HazardState, hazard: BaseHazard) -> void:
	if new_state == BaseHazard.HazardState.DISCOVERED:
		discovered_count += 1
		hazard_discovered.emit(hazard)
		print("[HazardManager] Hazard discovered: %s (%d/%d)" % [
			hazard.hazard_id, discovered_count, hazards.size()
		])

		# 모든 위험 요소가 발견되었는지 확인
		if discovered_count >= hazards.size():
			all_hazards_discovered.emit()
			print("[HazardManager] All hazards discovered!")

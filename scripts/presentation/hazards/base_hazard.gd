class_name BaseHazard
extends Area3D

## SPEC-HAZ-001: 위험 요소 기본 시스템 — 추상 베이스
##
## 모든 위험 요소 유형(크랙, 부식, 누수 등)의 공통 인터페이스를 정의한다.
## Area3D를 상속하여 탐지 가능 영역(CollisionShape3D)을 가지며,
## 마킹 레이와 충돌 판정을 수행한다.
##
## SOLID O/L: 새 위험 요소 유형 추가 시 이 클래스를 상속하여 확장.
## SOLID L: 서브클래스(CrackHazard 등)가 BaseHazard 자리에 투명 교체 가능.

## 위험 요소 상태 열거형
enum HazardState {
	UNDISCOVERED,  ## 미발견 상태 (초기)
	DISCOVERED,    ## 발견 상태
}

## SPEC-HAZ-001: 발견 상태 변경 시 발행
signal state_changed(new_state: HazardState)

## 위험 요소 고유 ID
@export var hazard_id: String = ""

## 위험 요소 유형 (예: "crack", "corrosion", "leak")
@export var hazard_type: String = ""

## 난이도 (0.0 ~ 1.0)
@export var difficulty: float = 0.5

## 현재 상태
var state: HazardState = HazardState.UNDISCOVERED

## warning marker (hazard 위에 떠 있는 안전 표지등)
var _warning_marker: MeshInstance3D = null

## 마킹 레이 전용 충돌 레이어 (비트 5 = 레이어 6)
## 마킹 레이의 collision_mask가 이 레이어와 일치해야 탐지됨
const HAZARD_COLLISION_LAYER: int = 32  # 비트 5 (2^5 = 32)

## warning marker 시각 파라미터.
## 사용자: "위험 요소가 눈에 잘 띄지 않아" — 멀리서도 보이는 safety beacon.
const MARKER_HEIGHT_M: float = 0.65
const MARKER_RADIUS: float = 0.06
const MARKER_COLOR: Color = Color(1.0, 0.85, 0.0)  # OSHA caution yellow
const MARKER_EMISSION_ENERGY: float = 2.5
const MARKER_COLOR_DISCOVERED: Color = Color(0.0, 1.0, 0.25)

## 발견 후 바닥에 투영되는 녹색 가이드 링.
const GUIDE_RING_SIZE: float = 1.6
const GUIDE_RING_INNER_RATIO: float = 0.62  # 안쪽 투명 영역 / outer radius
const GUIDE_RING_COLOR: Color = Color(0.05, 0.85, 0.22)

## 발견 후 생성되는 가이드 링 Decal (없으면 null)
var _guide_ring: Decal = null


func _ready() -> void:
	# 일반 물리 충돌은 받지 않고, 마킹 레이 전용 레이어만 설정
	collision_layer = HAZARD_COLLISION_LAYER
	collision_mask = 0  # Area3D 자체는 다른 것과 충돌하지 않음
	monitorable = true
	monitoring = false

	_build_warning_marker()
	_apply_difficulty()


## hazard 위에 띄우는 OSHA caution 색 emissive 구.
## 발견 전: yellow. 발견 후: green (discover()에서 변경).
func _build_warning_marker() -> void:
	_warning_marker = MeshInstance3D.new()
	_warning_marker.name = "WarningMarker"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = MARKER_RADIUS
	sphere.height = MARKER_RADIUS * 2.0
	_warning_marker.mesh = sphere

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = MARKER_COLOR
	mat.emission_enabled = true
	mat.emission = MARKER_COLOR
	mat.emission_energy_multiplier = MARKER_EMISSION_ENERGY
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warning_marker.material_override = mat

	_warning_marker.position = Vector3(0.0, MARKER_HEIGHT_M, 0.0)
	# 발견 전에는 시각 단서가 보이면 안 됨 (탐색 게임플레이 유지).
	# discover() 시점에만 visible=true로 전환.
	_warning_marker.visible = false
	add_child(_warning_marker)


## SPEC-HAZ-001: 위험 요소를 발견 상태로 전환한다.
## 이미 발견된 상태이면 중복 처리하지 않는다.
## 반환: 상태가 실제로 변경되었으면 true
func discover() -> bool:
	if state == HazardState.DISCOVERED:
		return false

	state = HazardState.DISCOVERED
	if _warning_marker != null:
		_warning_marker.visible = true
	_recolor_marker_discovered()
	_spawn_guide_ring()
	_show_discovered_feedback()
	state_changed.emit(HazardState.DISCOVERED)
	return true


## 발견 시 바닥에 녹색 가이드 링을 투영한다 (Decal).
## 절차 생성 ring alpha texture — 가운데 투명, 가장자리 녹색.
func _spawn_guide_ring() -> void:
	if _guide_ring != null:
		return
	_guide_ring = Decal.new()
	_guide_ring.name = "GuideRing"
	# y_size를 2.5m로 크게 잡아 hazard가 floor에서 떠 있어도(예: y=0.5)
	# ring AABB 하단(y_center - 1.25 = -0.75)이 floor에 닿게 한다.
	_guide_ring.size = Vector3(GUIDE_RING_SIZE, 2.5, GUIDE_RING_SIZE)
	_guide_ring.upper_fade = 0.3
	_guide_ring.lower_fade = 0.3
	_guide_ring.modulate = Color(GUIDE_RING_COLOR.r, GUIDE_RING_COLOR.g, GUIDE_RING_COLOR.b, 0.85)
	_guide_ring.texture_albedo = _make_guide_ring_texture()
	_guide_ring.cull_mask = BaseSite.FLOOR_DECAL_LAYER
	# decal projection 박스 중심이 hazard origin이 되도록 약간만 위로
	_guide_ring.position = Vector3(0.0, 0.05, 0.0)
	add_child(_guide_ring)


## 가이드 링 절차 텍스쳐. 중앙은 alpha 0, 가장자리에 가까울수록 alpha 1.
## inner_ratio ~ 1.0 영역만 실제로 보이는 ring 형태.
func _make_guide_ring_texture() -> ImageTexture:
	var size: int = 256
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cx: float = size * 0.5
	var cy: float = size * 0.5
	var outer: float = size * 0.48
	var inner: float = outer * GUIDE_RING_INNER_RATIO
	var ring_w: float = outer - inner
	for y in size:
		for x in size:
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			var d: float = sqrt(dx * dx + dy * dy)
			var a: float = 0.0
			if d >= inner and d <= outer:
				# ring 중앙에서 alpha 1, 양쪽 edge에서 0 (smooth)
				var t: float = (d - inner) / ring_w
				a = sin(t * PI)  # 0→1→0 부드러운 종 모양
				a = clampf(a, 0.0, 1.0)
			var c: Color = GUIDE_RING_COLOR
			c.a = a
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## 발견 시 marker 색상을 OSHA safe green으로 전환.
func _recolor_marker_discovered() -> void:
	if _warning_marker == null:
		return
	var mat: StandardMaterial3D = _warning_marker.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = MARKER_COLOR_DISCOVERED
	mat.emission = MARKER_COLOR_DISCOVERED


## SPEC-HAZ-001: 발견 여부를 반환한다.
func is_discovered() -> bool:
	return state == HazardState.DISCOVERED


## SPEC-HAZ-001: HazardData를 구성하여 반환한다.
func get_hazard_data() -> HazardData:
	var data: HazardData = HazardData.new()
	data.hazard_id = hazard_id
	data.hazard_type = hazard_type
	data.difficulty = difficulty
	data.position = global_position
	data.rotation_degrees = rotation_degrees
	return data


## HazardData로부터 속성을 설정한다.
func apply_hazard_data(data: HazardData) -> void:
	hazard_id = data.hazard_id
	hazard_type = data.hazard_type
	difficulty = data.difficulty
	position = data.position
	rotation_degrees = data.rotation_degrees
	_apply_difficulty()


## 가상 메서드: 난이도에 따른 비주얼 조정 (서브클래스에서 오버라이드)
func _apply_difficulty() -> void:
	pass


## 가상 메서드: 발견 시 시각적 피드백 (서브클래스에서 오버라이드)
func _show_discovered_feedback() -> void:
	# 기본 구현: 발견 인디케이터 노드가 있으면 활성화
	var indicator: Node3D = get_node_or_null("DiscoveredIndicator")
	if indicator != null:
		indicator.visible = true

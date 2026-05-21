class_name SiteProps
extends RefCounted

## 공사 현장 props 팩토리 — 외부 sky만으론 부족한 "공사중 활성 현장" 분위기 보강.
##
## OSHA 컬러 코딩 (orange=warning, yellow=caution, red=danger, blue=info)에 따라
## 색상 채택. 모든 prop은 primitive mesh + emission으로 단순 구성.
##
## 사용자: "좀 더 '공사중인 현장' 느낌이 나려면"

# ---------------------------------------------------------------------------
# 컬러 팔레트
# ---------------------------------------------------------------------------

const ORANGE_CONE: Color = Color(1.0, 0.42, 0.06)        # OSHA 안전 콘
const WHITE_REFLECT: Color = Color(0.95, 0.93, 0.88)     # 콘 반사띠
const TAPE_YELLOW: Color = Color(1.0, 0.85, 0.0)         # caution 황색
const TAPE_BLACK: Color = Color(0.05, 0.05, 0.05)        # 줄무늬
const BEACON_ORANGE: Color = Color(1.0, 0.55, 0.0)       # 회전 경광등
const WOOD_TINT: Color = Color(0.55, 0.40, 0.22)         # 합판/각재
const REBAR_TINT: Color = Color(0.45, 0.35, 0.28)        # 부식된 철근
const CEMENT_BAG_TINT: Color = Color(0.78, 0.74, 0.65)   # 시멘트 포대
const CABLE_BLACK: Color = Color(0.10, 0.10, 0.10)       # 절연 외피
const DUCT_SILVER: Color = Color(0.65, 0.65, 0.68)       # 알루미늄 덕트


# ---------------------------------------------------------------------------
# 안전 콘
# ---------------------------------------------------------------------------

## 표준 PVC 안전 콘 (높이 0.7m). 위치는 콘 바닥 중심.
func spawn_safety_cone(parent: Node3D, pos: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.name = "SafetyCone"
	root.position = pos
	parent.add_child(root)

	# 사각 base
	var base: MeshInstance3D = _box_mesh(Vector3(0.30, 0.04, 0.30), ORANGE_CONE, 0.0)
	base.position = Vector3(0.0, 0.02, 0.0)
	root.add_child(base)

	# 콘 body
	var body: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.16
	cm.height = 0.66
	body.mesh = cm
	body.material_override = _emissive_mat(ORANGE_CONE, 0.4)
	body.position = Vector3(0.0, 0.37, 0.0)
	root.add_child(body)

	# 흰 반사 띠 (두 개)
	for band_y: float in [0.30, 0.50]:
		var band: MeshInstance3D = MeshInstance3D.new()
		var bm: CylinderMesh = CylinderMesh.new()
		var ratio: float = (0.7 - band_y) / 0.66
		var r: float = lerpf(0.16, 0.025, 1.0 - ratio)
		bm.top_radius = r + 0.005
		bm.bottom_radius = r + 0.005
		bm.height = 0.06
		band.mesh = bm
		band.material_override = _emissive_mat(WHITE_REFLECT, 0.8)
		band.position = Vector3(0.0, band_y, 0.0)
		root.add_child(band)


# ---------------------------------------------------------------------------
# Hazard tape barrier (노랑-검정 줄무늬)
# ---------------------------------------------------------------------------

## 두 점 사이를 잇는 hazard tape 띠. height 0.9m 정도에 가로로 설치.
func spawn_hazard_tape(parent: Node3D, start: Vector3, end: Vector3) -> void:
	var ab: Vector3 = end - start
	var length: float = ab.length()
	if length < 0.2:
		return
	var ang_y: float = atan2(ab.x, ab.z)
	var mid: Vector3 = (start + end) * 0.5

	var root: Node3D = Node3D.new()
	root.name = "HazardTape"
	root.position = mid
	root.rotation = Vector3(0.0, ang_y, 0.0)
	parent.add_child(root)

	# 노랑 띠 (얇은 box)
	var tape: MeshInstance3D = _box_mesh(Vector3(0.005, 0.08, length), TAPE_YELLOW, 1.2)
	root.add_child(tape)

	# 검정 사선 줄무늬 (작은 box들 일정 간격)
	var stripe_spacing: float = 0.3
	var stripe_count: int = max(2, int(length / stripe_spacing))
	for i: int in stripe_count:
		var t: float = (float(i) + 0.5) / float(stripe_count) - 0.5
		var stripe: MeshInstance3D = _box_mesh(Vector3(0.007, 0.06, 0.08), TAPE_BLACK, 0.0)
		stripe.position = Vector3(0.0, 0.0, t * length)
		stripe.rotation = Vector3(0.0, 0.0, deg_to_rad(35.0))  # 사선
		root.add_child(stripe)


# ---------------------------------------------------------------------------
# 작업등 + orange beacon
# ---------------------------------------------------------------------------

## 삼각대 작업등 (1.2m) + 상단 orange beacon.
func spawn_work_lamp(parent: Node3D, pos: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.name = "WorkLamp"
	root.position = pos
	parent.add_child(root)

	# 삼각대 다리 (3개)
	for ang_deg: float in [0.0, 120.0, 240.0]:
		var leg: MeshInstance3D = MeshInstance3D.new()
		var lm: CylinderMesh = CylinderMesh.new()
		lm.top_radius = 0.012
		lm.bottom_radius = 0.018
		lm.height = 0.9
		leg.mesh = lm
		leg.material_override = _emissive_mat(Color(0.30, 0.30, 0.32), 0.0)
		var ang: float = deg_to_rad(ang_deg)
		var lean: float = deg_to_rad(15.0)
		leg.position = Vector3(sin(ang) * 0.13, 0.45, cos(ang) * 0.13)
		leg.rotation = Vector3(sin(ang) * lean, 0.0, -cos(ang) * lean)
		root.add_child(leg)

	# 중앙 기둥
	var post: MeshInstance3D = MeshInstance3D.new()
	var pm: CylinderMesh = CylinderMesh.new()
	pm.top_radius = 0.018
	pm.bottom_radius = 0.022
	pm.height = 1.05
	post.mesh = pm
	post.material_override = _emissive_mat(Color(0.25, 0.25, 0.27), 0.0)
	post.position = Vector3(0.0, 0.52, 0.0)
	root.add_child(post)

	# 작업등 head (큰 박스 reflector)
	var head: MeshInstance3D = _box_mesh(Vector3(0.32, 0.18, 0.10), Color(0.92, 0.92, 0.92), 0.3)
	head.position = Vector3(0.0, 1.08, 0.0)
	root.add_child(head)

	# 작업등 광원 (warm halogen)
	var work_light: SpotLight3D = SpotLight3D.new()
	work_light.position = Vector3(0.0, 1.08, 0.04)
	work_light.rotation = Vector3(deg_to_rad(-25.0), 0.0, 0.0)
	work_light.light_color = Color(1.0, 0.90, 0.70)
	work_light.light_energy = 4.5
	work_light.spot_range = 8.0
	work_light.spot_angle = 55.0
	work_light.spot_attenuation = 1.2
	work_light.shadow_enabled = false
	root.add_child(work_light)

	# 상단 orange beacon (회전 경광등 — 정적이지만 발광)
	var beacon: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.055
	sm.height = 0.11
	beacon.mesh = sm
	beacon.material_override = _emissive_mat(BEACON_ORANGE, 3.0)
	beacon.position = Vector3(0.0, 1.21, 0.0)
	root.add_child(beacon)


# ---------------------------------------------------------------------------
# 자재 더미
# ---------------------------------------------------------------------------

## 목재 적층 (3단, 2m 각재)
func spawn_material_wood(parent: Node3D, pos: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.name = "MaterialWood"
	root.position = pos
	parent.add_child(root)
	for tier: int in 3:
		var stack: MeshInstance3D = _box_mesh(
			Vector3(2.0, 0.08, 0.55), WOOD_TINT, 0.0
		)
		stack.position = Vector3(0.0, 0.04 + tier * 0.085, 0.0)
		root.add_child(stack)


## 철근 묶음 (얇은 cylinder 7개, 2m)
func spawn_material_rebar(parent: Node3D, pos: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.name = "MaterialRebar"
	root.position = pos
	parent.add_child(root)
	var positions: Array = [
		Vector2(-0.06, 0.03), Vector2(-0.02, 0.03), Vector2(0.02, 0.03), Vector2(0.06, 0.03),
		Vector2(-0.04, 0.07), Vector2(0.0, 0.07), Vector2(0.04, 0.07),
	]
	for p: Vector2 in positions:
		var bar: MeshInstance3D = MeshInstance3D.new()
		var bm: CylinderMesh = CylinderMesh.new()
		bm.top_radius = 0.015
		bm.bottom_radius = 0.015
		bm.height = 2.0
		bar.mesh = bm
		bar.material_override = _emissive_mat(REBAR_TINT, 0.0)
		bar.rotation = Vector3(0.0, 0.0, deg_to_rad(90.0))  # 수평
		bar.position = Vector3(0.0, p.y, p.x)
		root.add_child(bar)


## 시멘트 포대 적층 (3개, 약간 어긋난 배치)
func spawn_material_cement(parent: Node3D, pos: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.name = "MaterialCement"
	root.position = pos
	parent.add_child(root)
	var offsets: Array = [
		Vector3(0.0, 0.08, 0.0),
		Vector3(0.05, 0.24, 0.02),
		Vector3(-0.03, 0.40, -0.04),
	]
	for off: Vector3 in offsets:
		var bag: MeshInstance3D = _box_mesh(
			Vector3(0.55, 0.15, 0.32), CEMENT_BAG_TINT, 0.0
		)
		bag.position = off
		root.add_child(bag)


# ---------------------------------------------------------------------------
# 임시 케이블 / 덕트
# ---------------------------------------------------------------------------

## 천장에서 늘어진 cable bundle (가로 길이 length, 두 끝점이 천장 빔).
func spawn_cable_hanging(parent: Node3D, start: Vector3, end: Vector3) -> void:
	var ab: Vector3 = end - start
	var length: float = ab.length()
	if length < 0.5:
		return
	var ang_y: float = atan2(ab.x, ab.z)
	var mid: Vector3 = (start + end) * 0.5

	var root: Node3D = Node3D.new()
	root.name = "CableRun"
	root.position = mid
	root.rotation = Vector3(0.0, ang_y, 0.0)
	parent.add_child(root)

	# 메인 cable (얇은 길쭉한 box, 가운데 약간 처짐)
	var cable: MeshInstance3D = _box_mesh(
		Vector3(0.018, 0.018, length), CABLE_BLACK, 0.0
	)
	cable.position = Vector3(0.0, -0.05, 0.0)  # 빔 아래 5cm 처짐
	root.add_child(cable)

	# 보조 cable (병행 흰색 - 전원/통신선 구분)
	var cable2: MeshInstance3D = _box_mesh(
		Vector3(0.014, 0.014, length), Color(0.85, 0.55, 0.10), 0.0
	)
	cable2.position = Vector3(0.025, -0.05, 0.0)
	root.add_child(cable2)


## 알루미늄 임시 덕트 (HVAC, 빔 아래 매달려 있음)
func spawn_duct(parent: Node3D, start: Vector3, end: Vector3) -> void:
	var ab: Vector3 = end - start
	var length: float = ab.length()
	if length < 0.8:
		return
	var ang_y: float = atan2(ab.x, ab.z)
	var mid: Vector3 = (start + end) * 0.5

	var duct: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = 0.18
	cm.height = length
	duct.mesh = cm
	duct.material_override = _emissive_mat(DUCT_SILVER, 0.0)
	duct.position = mid
	duct.rotation = Vector3(deg_to_rad(90.0), ang_y, 0.0)
	parent.add_child(duct)


# ---------------------------------------------------------------------------
# 내부 헬퍼
# ---------------------------------------------------------------------------

func _emissive_mat(color: Color, emission_energy: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	mat.metallic = 0.0
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy
	return mat


func _box_mesh(size: Vector3, color: Color, emission_energy: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _emissive_mat(color, emission_energy)
	return mi

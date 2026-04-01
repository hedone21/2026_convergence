class_name BuildingFrameSite
extends BaseSite

## SPEC-ENV-001: 건물 골조 현장 3D 환경
##
## 철근콘크리트 건물 골조 공사 현장을 절차적으로 생성한다.
## 기둥, 보, 슬래브, 벽체, 바닥면을 MeshInstance3D + StaticBody3D로 구성하여
## 플레이어가 걸어다닐 수 있는 충돌 판정이 있는 환경을 제공한다.

# ---------------------------------------------------------------------------
# 구조물 치수 상수 (미터 단위)
# ---------------------------------------------------------------------------

## 전체 현장 크기
const SITE_WIDTH: float = 20.0
const SITE_DEPTH: float = 20.0

## 바닥
const FLOOR_THICKNESS: float = 0.3

## 기둥 — 3x3 그리드 중 중앙 제외 총 8개
const COLUMN_WIDTH: float = 0.5
const COLUMN_DEPTH: float = 0.5
const COLUMN_HEIGHT: float = 4.0

## 보 — 기둥 상단을 연결하는 수평 부재
const BEAM_WIDTH: float = 0.3
const BEAM_HEIGHT: float = 0.5

## 슬래브 — 천장/상층 바닥판
const SLAB_THICKNESS: float = 0.2

## 벽체
const WALL_THICKNESS: float = 0.2
const WALL_HEIGHT: float = 3.5

## 콘크리트 색상 (밝은 회색 계열) — PBR 머티리얼 생성 불가 시 폴백용
const COLOR_CONCRETE: Color = Color(0.78, 0.76, 0.74)
const COLOR_CONCRETE_DARK: Color = Color(0.65, 0.63, 0.61)
const COLOR_FLOOR: Color = Color(0.7, 0.68, 0.66)
const COLOR_SLAB: Color = Color(0.72, 0.70, 0.68)

# ---------------------------------------------------------------------------
# 내부 참조
# ---------------------------------------------------------------------------

var _columns_node: Node3D
var _beams_node: Node3D
var _slabs_node: Node3D
var _walls_node: Node3D
var _floor_body: StaticBody3D
var _environment: WorldEnvironment

## PBR 콘크리트 머티리얼 팩토리
var _concrete_material: ConcreteMaterial = ConcreteMaterial.new()

## 캐시된 PBR 머티리얼 (동일 유형은 재사용하여 드로우콜 절감)
var _mat_concrete: StandardMaterial3D = null
var _mat_floor: StandardMaterial3D = null
var _mat_rebar: StandardMaterial3D = null

## 표면 캐시 (get_valid_surfaces 용)
var _surfaces: Array = []


func _ready() -> void:
	_init_materials()
	_build_site()
	print("[BuildingFrameSite] Building frame site generated.")


# ---------------------------------------------------------------------------
# BaseSite 오버라이드
# ---------------------------------------------------------------------------

func get_valid_surfaces() -> Array:
	return _surfaces


func get_spawn_bounds() -> AABB:
	return AABB(
		Vector3(-SITE_WIDTH / 2.0, 0.0, -SITE_DEPTH / 2.0),
		Vector3(SITE_WIDTH, COLUMN_HEIGHT + SLAB_THICKNESS, SITE_DEPTH)
	)


func get_site_type() -> String:
	return "building_frame"


# ---------------------------------------------------------------------------
# PBR 머티리얼 초기화
# ---------------------------------------------------------------------------

## PBR 콘크리트 머티리얼을 사전 생성하여 캐시한다.
## 동일 머티리얼 유형은 인스턴스를 공유하여 드로우콜을 절감한다.
func _init_materials() -> void:
	_mat_concrete = _concrete_material.create_concrete_material()
	_mat_floor = _concrete_material.create_floor_material()
	_mat_rebar = _concrete_material.create_rebar_material()


# ---------------------------------------------------------------------------
# 절차적 생성
# ---------------------------------------------------------------------------

func _build_site() -> void:
	_create_floor()
	_create_columns()
	_create_beams()
	_create_slabs()
	_create_walls()
	_create_lighting()


# -- 바닥 ------------------------------------------------------------------

func _create_floor() -> void:
	_floor_body = StaticBody3D.new()
	_floor_body.name = "Floor"

	var mesh_instance: MeshInstance3D = _create_box_mesh_pbr(
		Vector3(SITE_WIDTH, FLOOR_THICKNESS, SITE_DEPTH),
		_mat_floor
	)
	_floor_body.add_child(mesh_instance)

	var collision: CollisionShape3D = _create_box_collision(
		Vector3(SITE_WIDTH, FLOOR_THICKNESS, SITE_DEPTH)
	)
	_floor_body.add_child(collision)

	# 바닥 상단이 y=0 이 되도록 배치
	_floor_body.position = Vector3(0.0, -FLOOR_THICKNESS / 2.0, 0.0)
	add_child(_floor_body)

	_surfaces.append({
		"node": _floor_body,
		"surface_type": "floor",
		"aabb": AABB(
			Vector3(-SITE_WIDTH / 2.0, -FLOOR_THICKNESS, -SITE_DEPTH / 2.0),
			Vector3(SITE_WIDTH, FLOOR_THICKNESS, SITE_DEPTH)
		)
	})


# -- 기둥 ------------------------------------------------------------------

func _create_columns() -> void:
	_columns_node = Node3D.new()
	_columns_node.name = "Columns"
	add_child(_columns_node)

	# 3x3 그리드 간격으로 기둥 배치 (최소 4개 이상 — 총 9개)
	var spacing_x: float = SITE_WIDTH / 3.0
	var spacing_z: float = SITE_DEPTH / 3.0
	var start_x: float = -SITE_WIDTH / 3.0
	var start_z: float = -SITE_DEPTH / 3.0

	var col_index: int = 0
	for ix: int in range(3):
		for iz: int in range(3):
			# 중앙 기둥은 스킵하여 개방감 확보 (총 8개)
			if ix == 1 and iz == 1:
				continue

			var pos_x: float = start_x + ix * spacing_x
			var pos_z: float = start_z + iz * spacing_z
			col_index += 1

			var column: StaticBody3D = _create_structural_element_pbr(
				"Column_%02d" % col_index,
				Vector3(COLUMN_WIDTH, COLUMN_HEIGHT, COLUMN_DEPTH),
				Vector3(pos_x, COLUMN_HEIGHT / 2.0, pos_z),
				_mat_concrete
			)
			_columns_node.add_child(column)

			_surfaces.append({
				"node": column,
				"surface_type": "column",
				"aabb": AABB(
					Vector3(pos_x - COLUMN_WIDTH / 2.0, 0.0, pos_z - COLUMN_DEPTH / 2.0),
					Vector3(COLUMN_WIDTH, COLUMN_HEIGHT, COLUMN_DEPTH)
				)
			})


# -- 보 --------------------------------------------------------------------

func _create_beams() -> void:
	_beams_node = Node3D.new()
	_beams_node.name = "Beams"
	add_child(_beams_node)

	var spacing_x: float = SITE_WIDTH / 3.0
	var spacing_z: float = SITE_DEPTH / 3.0
	var start_x: float = -SITE_WIDTH / 3.0
	var start_z: float = -SITE_DEPTH / 3.0
	var beam_y: float = COLUMN_HEIGHT + BEAM_HEIGHT / 2.0

	var beam_index: int = 0

	# X방향 보 — 각 행에서 기둥 간 연결 (3행 x 2구간 = 6개)
	for iz: int in range(3):
		var z_pos: float = start_z + iz * spacing_z
		for ix: int in range(2):
			var x_start: float = start_x + ix * spacing_x
			var x_end: float = x_start + spacing_x
			var x_mid: float = (x_start + x_end) / 2.0
			beam_index += 1

			var beam: StaticBody3D = _create_structural_element_pbr(
				"Beam_%02d" % beam_index,
				Vector3(spacing_x, BEAM_HEIGHT, BEAM_WIDTH),
				Vector3(x_mid, beam_y, z_pos),
				_mat_rebar
			)
			_beams_node.add_child(beam)

			_surfaces.append({
				"node": beam,
				"surface_type": "beam",
				"aabb": AABB(
					Vector3(x_mid - spacing_x / 2.0, beam_y - BEAM_HEIGHT / 2.0, z_pos - BEAM_WIDTH / 2.0),
					Vector3(spacing_x, BEAM_HEIGHT, BEAM_WIDTH)
				)
			})

	# Z방향 보 — 각 열에서 기둥 간 연결 (3열 x 2구간 = 6개)
	for ix: int in range(3):
		var x_pos: float = start_x + ix * spacing_x
		for iz: int in range(2):
			var z_start: float = start_z + iz * spacing_z
			var z_end: float = z_start + spacing_z
			var z_mid: float = (z_start + z_end) / 2.0
			beam_index += 1

			var beam: StaticBody3D = _create_structural_element_pbr(
				"Beam_%02d" % beam_index,
				Vector3(BEAM_WIDTH, BEAM_HEIGHT, spacing_z),
				Vector3(x_pos, beam_y, z_mid),
				_mat_rebar
			)
			_beams_node.add_child(beam)

			_surfaces.append({
				"node": beam,
				"surface_type": "beam",
				"aabb": AABB(
					Vector3(x_pos - BEAM_WIDTH / 2.0, beam_y - BEAM_HEIGHT / 2.0, z_mid - spacing_z / 2.0),
					Vector3(BEAM_WIDTH, BEAM_HEIGHT, spacing_z)
				)
			})


# -- 슬래브 ----------------------------------------------------------------

func _create_slabs() -> void:
	_slabs_node = Node3D.new()
	_slabs_node.name = "Slabs"
	add_child(_slabs_node)

	var slab_y: float = COLUMN_HEIGHT + BEAM_HEIGHT + SLAB_THICKNESS / 2.0

	# 전체 면적 슬래브 1개
	var slab: StaticBody3D = _create_structural_element_pbr(
		"Slab_01",
		Vector3(SITE_WIDTH, SLAB_THICKNESS, SITE_DEPTH),
		Vector3(0.0, slab_y, 0.0),
		_mat_concrete
	)
	_slabs_node.add_child(slab)

	_surfaces.append({
		"node": slab,
		"surface_type": "slab",
		"aabb": AABB(
			Vector3(-SITE_WIDTH / 2.0, slab_y - SLAB_THICKNESS / 2.0, -SITE_DEPTH / 2.0),
			Vector3(SITE_WIDTH, SLAB_THICKNESS, SITE_DEPTH)
		)
	})


# -- 벽체 ------------------------------------------------------------------

func _create_walls() -> void:
	_walls_node = Node3D.new()
	_walls_node.name = "Walls"
	add_child(_walls_node)

	var wall_y: float = WALL_HEIGHT / 2.0
	var half_w: float = SITE_WIDTH / 2.0
	var half_d: float = SITE_DEPTH / 2.0

	# 남쪽 벽 (Z+ 방향) — 출입구 개구부를 위해 2개로 분할
	var door_width: float = 2.0
	var south_wall_segment: float = (SITE_WIDTH - door_width) / 2.0

	var wall_south_left: StaticBody3D = _create_structural_element_pbr(
		"Wall_South_Left",
		Vector3(south_wall_segment, WALL_HEIGHT, WALL_THICKNESS),
		Vector3(-half_w + south_wall_segment / 2.0, wall_y, half_d - WALL_THICKNESS / 2.0),
		_mat_concrete
	)
	_walls_node.add_child(wall_south_left)

	var wall_south_right: StaticBody3D = _create_structural_element_pbr(
		"Wall_South_Right",
		Vector3(south_wall_segment, WALL_HEIGHT, WALL_THICKNESS),
		Vector3(half_w - south_wall_segment / 2.0, wall_y, half_d - WALL_THICKNESS / 2.0),
		_mat_concrete
	)
	_walls_node.add_child(wall_south_right)

	# 북쪽 벽 (Z- 방향) — 전체 벽
	var wall_north: StaticBody3D = _create_structural_element_pbr(
		"Wall_North",
		Vector3(SITE_WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3(0.0, wall_y, -half_d + WALL_THICKNESS / 2.0),
		_mat_concrete
	)
	_walls_node.add_child(wall_north)

	# 동쪽 벽 (X+ 방향)
	var wall_east: StaticBody3D = _create_structural_element_pbr(
		"Wall_East",
		Vector3(WALL_THICKNESS, WALL_HEIGHT, SITE_DEPTH),
		Vector3(half_w - WALL_THICKNESS / 2.0, wall_y, 0.0),
		_mat_concrete
	)
	_walls_node.add_child(wall_east)

	# 서쪽 벽 (X- 방향)
	var wall_west: StaticBody3D = _create_structural_element_pbr(
		"Wall_West",
		Vector3(WALL_THICKNESS, WALL_HEIGHT, SITE_DEPTH),
		Vector3(-half_w + WALL_THICKNESS / 2.0, wall_y, 0.0),
		_mat_concrete
	)
	_walls_node.add_child(wall_west)

	# 벽체를 표면 목록에 등록
	for wall: Node in _walls_node.get_children():
		_surfaces.append({
			"node": wall,
			"surface_type": "wall",
			"aabb": AABB(wall.position - Vector3(0.1, 0.0, 0.1), Vector3(0.2, WALL_HEIGHT, 0.2))
		})


# -- 조명 ------------------------------------------------------------------

func _create_lighting() -> void:
	# DirectionalLight3D — 태양광 시뮬레이션 (약간 따뜻한 톤, 그림자 품질 개선)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	sun.light_energy = 2.5
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.96, 0.90)  # 약간 따뜻한 톤
	sun.shadow_blur = 1.0
	sun.directional_shadow_max_distance = 50.0
	add_child(sun)

	# 보조 조명 — 반대편에서 약한 쿨톤 필 라이트
	var fill_light: DirectionalLight3D = DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.rotation_degrees = Vector3(-30.0, -150.0, 0.0)
	fill_light.light_energy = 0.6
	fill_light.shadow_enabled = false
	fill_light.light_color = Color(0.85, 0.90, 1.0)  # 쿨톤 필 라이트
	add_child(fill_light)

	# WorldEnvironment — ProceduralSky + SSAO + SSIL + ACES 톤매핑
	_environment = WorldEnvironment.new()
	_environment.name = "SiteEnvironment"
	var env: Environment = Environment.new()

	# -- 배경: ProceduralSky --
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.35, 0.55, 0.85)
	sky_material.sky_horizon_color = Color(0.65, 0.75, 0.88)
	sky_material.ground_bottom_color = Color(0.35, 0.30, 0.25)
	sky_material.ground_horizon_color = Color(0.65, 0.70, 0.72)
	sky_material.sun_angle_max = 30.0
	sky_material.sun_curve = 0.15
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256  # Quest 성능 고려
	env.sky = sky

	# -- 앰비언트 라이트: 하늘에서 자동 추출 --
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# -- 톤매핑: ACES Filmic --
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.tonemap_exposure = 1.6

	# -- SSAO (Screen-Space Ambient Occlusion) --
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.2
	env.ssao_power = 1.5
	env.ssao_detail = 0.5
	env.ssao_light_affect = 0.3

	# -- SSIL (Screen-Space Indirect Lighting) --
	env.ssil_enabled = true
	env.ssil_radius = 5.0
	env.ssil_intensity = 1.0
	env.ssil_normal_rejection = 1.0

	# -- Glow (미세한 블룸) --
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_strength = 0.8
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# -- Fog (대기 원근감) --
	env.fog_enabled = true
	env.fog_light_color = Color(0.70, 0.75, 0.82)
	env.fog_light_energy = 0.5
	env.fog_density = 0.002
	env.fog_sky_affect = 0.5

	_environment.environment = env
	add_child(_environment)


# ---------------------------------------------------------------------------
# 유틸리티 — 구조물 요소 생성 헬퍼
# ---------------------------------------------------------------------------

## StaticBody3D + MeshInstance3D + CollisionShape3D를 한 묶음으로 생성한다.
func _create_structural_element(
	element_name: String,
	size: Vector3,
	pos: Vector3,
	color: Color
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = element_name
	body.position = pos

	var mesh_instance: MeshInstance3D = _create_box_mesh(size, color)
	body.add_child(mesh_instance)

	var collision: CollisionShape3D = _create_box_collision(size)
	body.add_child(collision)

	return body


## PBR 머티리얼을 사용하는 구조물 요소 생성 (신규).
## 기존 _create_structural_element와 동일하되, 단색 대신 PBR 머티리얼을 적용한다.
func _create_structural_element_pbr(
	element_name: String,
	size: Vector3,
	pos: Vector3,
	material: StandardMaterial3D
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = element_name
	body.position = pos

	var mesh_instance: MeshInstance3D = _create_box_mesh_pbr(size, material)
	body.add_child(mesh_instance)

	var collision: CollisionShape3D = _create_box_collision(size)
	body.add_child(collision)

	return body


## BoxMesh를 가진 MeshInstance3D를 생성한다.
func _create_box_mesh(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	material.metallic = 0.0
	mesh_instance.material_override = material

	return mesh_instance


## PBR 머티리얼을 사용하는 BoxMesh MeshInstance3D 생성 (신규).
## UV 스케일은 머티리얼에 이미 설정되어 있으므로 별도 조정 불요.
func _create_box_mesh_pbr(size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material

	return mesh_instance


## BoxShape3D를 가진 CollisionShape3D를 생성한다.
func _create_box_collision(size: Vector3) -> CollisionShape3D:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	return collision

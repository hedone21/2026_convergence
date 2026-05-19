class_name ParliamentVillageSite
extends BaseSite

## SPEC-ENV-003: 추가 현장 유형 — Parliament Village South Hall
##
## Texas Woman's University Parliament Village South Hall 4층 기숙사 도면을 기반으로
## 골조 단계의 건설 현장을 절차적으로 생성한다. PDF 도면에서 추출한 floorplan JSON
## (외벽 line segment, 코어 영역, 구조 grid)을 읽어 wall mesh와 기둥을 배치한다.
##
## 데이터 소스: data/parliament_village/floor_*.json (tools/extract_floorplan.py 산출물)


# ---------------------------------------------------------------------------
# 데이터 소스
# ---------------------------------------------------------------------------

## 표시할 층 번호 (1~4). 4층 전체 동시 표시는 mesh 폭증으로 미지원.
@export var floor_to_show: int = 1

## floor JSON 경로 템플릿
const FLOOR_JSON_TEMPLATE: String = "res://data/parliament_village/floor_%02d.json"

# ---------------------------------------------------------------------------
# 치수 상수 (미터)
# ---------------------------------------------------------------------------

const FLOOR_HEIGHT: float = 3.5
const SLAB_THICKNESS: float = 0.25
const COLUMN_WIDTH: float = 0.45
const COLUMN_DEPTH: float = 0.45

## 외벽/내벽 두께
const OUTER_WALL_THICKNESS: float = 0.30
const INNER_WALL_THICKNESS: float = 0.18

## 구조물 시각화 높이 (바닥 슬래브 위, 천장 슬래브 아래)
const STRUCTURE_HEIGHT: float = FLOOR_HEIGHT - SLAB_THICKNESS

## 외벽 분할 — 가운데 띠가 창문 영역
const OUTER_WALL_BOTTOM_HEIGHT: float = 0.95  # 허리벽
const OUTER_WALL_TOP_HEIGHT: float = 0.55     # 인방
const WINDOW_BAND_BOTTOM_Y: float = OUTER_WALL_BOTTOM_HEIGHT
const WINDOW_BAND_TOP_Y: float = STRUCTURE_HEIGHT - OUTER_WALL_TOP_HEIGHT

## 내벽 높이 — 천장과 갭을 둬 방 사이 빛/공기 흐름 확보 (답답함 완화)
const INNER_WALL_HEIGHT: float = 2.55

## 슬래브가 grid 라벨 좌표 밖으로 확장되는 패딩 (외주부 처마)
const SLAB_EDGE_PADDING_M: float = 1.5

## 짧은 segment 노이즈 제외 임계값 (미터)
const MIN_WALL_LENGTH: float = 0.08

## 천장 광원
const CEILING_LIGHT_OFFSET_Y: float = STRUCTURE_HEIGHT - 0.05
const CEILING_LIGHT_ENERGY: float = 4.0
const CEILING_LIGHT_RANGE: float = 18.0
const CEILING_LIGHT_COLOR: Color = Color(1.0, 0.95, 0.85, 1.0)

## 엘리베이터 샤프트 외관
const ELEVATOR_WIDTH: float = 2.4
const ELEVATOR_DEPTH: float = 2.4
const ELEVATOR_DOOR_WIDTH: float = 1.0
const ELEVATOR_DOOR_HEIGHT: float = 2.2

## 계단 (절차적 step)
const STAIRS_FOOTPRINT_X: float = 3.5
const STAIRS_FOOTPRINT_Z: float = 4.5
const STAIRS_STEP_COUNT: int = 12
const STAIRS_HANDRAIL_HEIGHT: float = 1.0
const STAIRS_HANDRAIL_THICKNESS: float = 0.06

const COLOR_ELEVATOR_SHAFT: Color = Color(0.55, 0.55, 0.58)
const COLOR_ELEVATOR_DOOR: Color = Color(0.25, 0.25, 0.28)
const COLOR_STAIRS_STEP: Color = Color(0.62, 0.6, 0.58)
const COLOR_HANDRAIL: Color = Color(0.35, 0.32, 0.30)

# ---------------------------------------------------------------------------
# 내부 참조
# ---------------------------------------------------------------------------

var _walls_node: Node3D
var _columns_node: Node3D
var _cores_node: Node3D
var _lights_node: Node3D
var _floor_body: StaticBody3D
var _ceiling_body: StaticBody3D

var _concrete_material: ConcreteMaterial = ConcreteMaterial.new()
var _mat_outer_wall: StandardMaterial3D = null
var _mat_inner_wall: StandardMaterial3D = null
var _mat_slab: StandardMaterial3D = null
var _mat_column: StandardMaterial3D = null
var _mat_elevator_shaft: StandardMaterial3D = null
var _mat_elevator_door: StandardMaterial3D = null
var _mat_stairs_step: StandardMaterial3D = null
var _mat_handrail: StandardMaterial3D = null

var _surfaces: Array = []
var _spawn_bounds: AABB = AABB()


func _ready() -> void:
	_init_materials()
	var data: Dictionary = _load_floor_json(floor_to_show)
	if data.is_empty():
		push_error("[ParliamentVillageSite] Failed to load floor %d" % floor_to_show)
		return
	_build_from_floor(data)
	print("[ParliamentVillageSite] Floor %d built from floorplan JSON." % floor_to_show)


# ---------------------------------------------------------------------------
# BaseSite 오버라이드
# ---------------------------------------------------------------------------

func get_valid_surfaces() -> Array:
	return _surfaces


func get_spawn_bounds() -> AABB:
	return _spawn_bounds


func get_site_type() -> String:
	return "parliament_village"


# ---------------------------------------------------------------------------
# 머티리얼
# ---------------------------------------------------------------------------

func _init_materials() -> void:
	_mat_outer_wall = _concrete_material.create_concrete_material()
	_mat_inner_wall = _concrete_material.create_concrete_material()
	_mat_slab = _concrete_material.create_floor_material()
	_mat_column = _concrete_material.create_concrete_material()
	_mat_elevator_shaft = _make_simple_material(COLOR_ELEVATOR_SHAFT)
	_mat_elevator_door = _make_simple_material(COLOR_ELEVATOR_DOOR)
	_mat_stairs_step = _make_simple_material(COLOR_STAIRS_STEP)
	_mat_handrail = _make_simple_material(COLOR_HANDRAIL)


func _make_simple_material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	return mat


# ---------------------------------------------------------------------------
# JSON 로드
# ---------------------------------------------------------------------------

func _load_floor_json(floor_num: int) -> Dictionary:
	var path: String = FLOOR_JSON_TEMPLATE % floor_num
	if not FileAccess.file_exists(path):
		push_error("[ParliamentVillageSite] floor JSON not found: %s" % path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("[ParliamentVillageSite] floor JSON parse failed: %s" % path)
		return {}
	return parsed


# ---------------------------------------------------------------------------
# 변환
# ---------------------------------------------------------------------------

func _build_from_floor(data: Dictionary) -> void:
	var scale_dict: Dictionary = data.get("scale", {})
	var pt_to_m: float = float(scale_dict.get("pdf_pt_to_meter", 0.0338666))

	var walls_bbox: Array = data.get("walls_bbox_pt", [])
	if walls_bbox.size() != 4:
		push_error("[ParliamentVillageSite] walls_bbox_pt invalid")
		return

	# site origin: walls_bbox 중심
	var origin_x_pt: float = (float(walls_bbox[0]) + float(walls_bbox[2])) * 0.5
	var origin_y_pt: float = (float(walls_bbox[1]) + float(walls_bbox[3])) * 0.5

	# 슬래브 영역: grid bbox(외곽 기둥 포함) + 처마 패딩
	var slab_rect_m: Rect2 = _compute_slab_rect(
		data.get("grid", {}), walls_bbox, pt_to_m, origin_x_pt, origin_y_pt
	)
	var slab_size: Vector3 = Vector3(slab_rect_m.size.x, SLAB_THICKNESS, slab_rect_m.size.y)
	var slab_center: Vector3 = Vector3(
		slab_rect_m.position.x + slab_rect_m.size.x * 0.5,
		0.0,
		slab_rect_m.position.y + slab_rect_m.size.y * 0.5
	)

	_spawn_bounds = AABB(
		Vector3(slab_rect_m.position.x, 0.0, slab_rect_m.position.y),
		Vector3(slab_size.x, FLOOR_HEIGHT, slab_size.z)
	)

	_create_floor_slab(slab_size, slab_center)
	_create_ceiling_slab(slab_size, slab_center)
	_create_walls(data.get("walls", []), pt_to_m, origin_x_pt, origin_y_pt)
	_create_columns(data.get("grid", {}), pt_to_m, origin_x_pt, origin_y_pt)
	_create_core_markers(data.get("cores", []), pt_to_m, origin_x_pt, origin_y_pt)
	_create_ceiling_lights(slab_size, slab_center)


func _compute_slab_rect(
	grid: Dictionary, walls_bbox: Array, pt_to_m: float,
	origin_x_pt: float, origin_y_pt: float
) -> Rect2:
	# 우선순위: grid bbox(외곽 기둥 포함). 폴백: walls_bbox.
	var gx: Dictionary = grid.get("x", {})
	var gy: Dictionary = grid.get("y", {})
	var min_x_pt: float
	var max_x_pt: float
	var min_y_pt: float
	var max_y_pt: float
	if not gx.is_empty() and not gy.is_empty():
		var xs: Array = gx.values()
		var ys: Array = gy.values()
		min_x_pt = xs.min()
		max_x_pt = xs.max()
		min_y_pt = ys.min()
		max_y_pt = ys.max()
	else:
		min_x_pt = float(walls_bbox[0])
		min_y_pt = float(walls_bbox[1])
		max_x_pt = float(walls_bbox[2])
		max_y_pt = float(walls_bbox[3])

	var x0_m: float = (min_x_pt - origin_x_pt) * pt_to_m - SLAB_EDGE_PADDING_M
	var z0_m: float = (min_y_pt - origin_y_pt) * pt_to_m - SLAB_EDGE_PADDING_M
	var x1_m: float = (max_x_pt - origin_x_pt) * pt_to_m + SLAB_EDGE_PADDING_M
	var z1_m: float = (max_y_pt - origin_y_pt) * pt_to_m + SLAB_EDGE_PADDING_M
	return Rect2(Vector2(x0_m, z0_m), Vector2(x1_m - x0_m, z1_m - z0_m))


# ---------------------------------------------------------------------------
# 슬래브 (바닥 + 천장)
# ---------------------------------------------------------------------------

func _create_floor_slab(size: Vector3, center: Vector3) -> void:
	_floor_body = StaticBody3D.new()
	_floor_body.name = "FloorSlab"
	add_child(_floor_body)
	_floor_body.add_child(_make_box_mesh(size, _mat_slab))
	_floor_body.add_child(_make_box_collision(size))
	_floor_body.position = Vector3(center.x, -SLAB_THICKNESS * 0.5, center.z)

	_surfaces.append({
		"node": _floor_body,
		"surface_type": "floor",
		"aabb": AABB(
			Vector3(center.x - size.x * 0.5, -SLAB_THICKNESS, center.z - size.z * 0.5),
			Vector3(size.x, SLAB_THICKNESS, size.z)
		)
	})


func _create_ceiling_slab(size: Vector3, center: Vector3) -> void:
	_ceiling_body = StaticBody3D.new()
	_ceiling_body.name = "CeilingSlab"
	add_child(_ceiling_body)
	_ceiling_body.add_child(_make_box_mesh(size, _mat_slab))
	_ceiling_body.add_child(_make_box_collision(size))
	_ceiling_body.position = Vector3(
		center.x, STRUCTURE_HEIGHT + SLAB_THICKNESS * 0.5, center.z
	)


# ---------------------------------------------------------------------------
# 벽체 (line segment → BoxMesh, 외벽은 창문 띠 분할)
# ---------------------------------------------------------------------------

func _create_walls(walls: Array, pt_to_m: float, ox_pt: float, oy_pt: float) -> void:
	_walls_node = Node3D.new()
	_walls_node.name = "Walls"
	add_child(_walls_node)

	for raw in walls:
		if not (raw is Dictionary):
			continue
		var w: Dictionary = raw
		var a: Array = w.get("a_pt", [])
		var b: Array = w.get("b_pt", [])
		if a.size() != 2 or b.size() != 2:
			continue
		var ax_m: float = (float(a[0]) - ox_pt) * pt_to_m
		var az_m: float = (float(a[1]) - oy_pt) * pt_to_m
		var bx_m: float = (float(b[0]) - ox_pt) * pt_to_m
		var bz_m: float = (float(b[1]) - oy_pt) * pt_to_m

		var dx: float = bx_m - ax_m
		var dz: float = bz_m - az_m
		var length: float = sqrt(dx * dx + dz * dz)
		if length < MIN_WALL_LENGTH:
			continue

		var kind: String = w.get("kind", "inner")
		if kind == "outer":
			_spawn_outer_wall(Vector2(ax_m, az_m), Vector2(bx_m, bz_m), length)
		else:
			_spawn_inner_wall(Vector2(ax_m, az_m), Vector2(bx_m, bz_m), length)


func _spawn_outer_wall(a: Vector2, b: Vector2, length: float) -> void:
	# 외벽: 허리벽(아래) + 인방(위) 두 토막. 사이는 창문 띠.
	_add_wall_segment(
		a, b, length, OUTER_WALL_THICKNESS, _mat_outer_wall,
		OUTER_WALL_BOTTOM_HEIGHT * 0.5,
		OUTER_WALL_BOTTOM_HEIGHT
	)
	_add_wall_segment(
		a, b, length, OUTER_WALL_THICKNESS, _mat_outer_wall,
		WINDOW_BAND_TOP_Y + OUTER_WALL_TOP_HEIGHT * 0.5,
		OUTER_WALL_TOP_HEIGHT
	)


func _spawn_inner_wall(a: Vector2, b: Vector2, length: float) -> void:
	# 내벽: 천장보다 낮게 (방 사이 빛/공기 흐름)
	_add_wall_segment(
		a, b, length, INNER_WALL_THICKNESS, _mat_inner_wall,
		INNER_WALL_HEIGHT * 0.5,
		INNER_WALL_HEIGHT
	)


func _add_wall_segment(
	a: Vector2, b: Vector2, length: float, thickness: float,
	material: StandardMaterial3D, center_y: float, height: float
) -> void:
	var center: Vector2 = (a + b) * 0.5
	var angle: float = atan2(b.y - a.y, b.x - a.x)

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Wall"
	body.position = Vector3(center.x, center_y, center.y)
	body.rotation = Vector3(0.0, -angle, 0.0)

	var size: Vector3 = Vector3(length, height, thickness)
	body.add_child(_make_box_mesh(size, material))
	body.add_child(_make_box_collision(size))

	_walls_node.add_child(body)


# ---------------------------------------------------------------------------
# 기둥 (grid 교점)
# ---------------------------------------------------------------------------

func _create_columns(grid: Dictionary, pt_to_m: float, ox_pt: float, oy_pt: float) -> void:
	_columns_node = Node3D.new()
	_columns_node.name = "Columns"
	add_child(_columns_node)

	var gx: Dictionary = grid.get("x", {})
	var gy: Dictionary = grid.get("y", {})
	if gx.is_empty() or gy.is_empty():
		return

	for label_x in gx.keys():
		var x_pt: float = float(gx[label_x])
		var x_m: float = (x_pt - ox_pt) * pt_to_m
		for label_y in gy.keys():
			var y_pt: float = float(gy[label_y])
			var z_m: float = (y_pt - oy_pt) * pt_to_m

			var body: StaticBody3D = StaticBody3D.new()
			body.name = "Column_%s%s" % [label_y, label_x]
			body.position = Vector3(x_m, STRUCTURE_HEIGHT * 0.5, z_m)

			var size: Vector3 = Vector3(COLUMN_WIDTH, STRUCTURE_HEIGHT, COLUMN_DEPTH)
			body.add_child(_make_box_mesh(size, _mat_column))
			body.add_child(_make_box_collision(size))

			_columns_node.add_child(body)

			_surfaces.append({
				"node": body,
				"surface_type": "column",
				"aabb": AABB(
					Vector3(x_m - COLUMN_WIDTH * 0.5, 0.0, z_m - COLUMN_DEPTH * 0.5),
					size
				)
			})


# ---------------------------------------------------------------------------
# 코어 마커 (STAIRS/ELEVATOR) — 위험 요소 배치 지점 후보
# ---------------------------------------------------------------------------

func _create_core_markers(cores: Array, pt_to_m: float, ox_pt: float, oy_pt: float) -> void:
	_cores_node = Node3D.new()
	_cores_node.name = "Cores"
	add_child(_cores_node)

	for raw in cores:
		if not (raw is Dictionary):
			continue
		var core: Dictionary = raw
		var bbox: Array = core.get("bbox_pt", [])
		if bbox.size() != 4:
			continue
		var cx_pt: float = (float(bbox[0]) + float(bbox[2])) * 0.5
		var cy_pt: float = (float(bbox[1]) + float(bbox[3])) * 0.5
		var x_m: float = (cx_pt - ox_pt) * pt_to_m
		var z_m: float = (cy_pt - oy_pt) * pt_to_m
		var label: String = core.get("label", "UNKNOWN")

		var visual: Node3D
		var aabb_size: Vector3
		if label == "ELEVATOR":
			visual = _build_elevator(x_m, z_m)
			aabb_size = Vector3(ELEVATOR_WIDTH, FLOOR_HEIGHT, ELEVATOR_DEPTH)
		else:  # STAIRS
			visual = _build_stairs(x_m, z_m)
			aabb_size = Vector3(STAIRS_FOOTPRINT_X, FLOOR_HEIGHT, STAIRS_FOOTPRINT_Z)
		_cores_node.add_child(visual)

		_surfaces.append({
			"node": visual,
			"surface_type": "core",
			"aabb": AABB(
				Vector3(x_m - aabb_size.x * 0.5, 0.0, z_m - aabb_size.z * 0.5),
				aabb_size
			)
		})


func _build_elevator(x_m: float, z_m: float) -> Node3D:
	# 엘리베이터 샤프트 박스 + 문 panel
	var root: Node3D = Node3D.new()
	root.name = "Core_ELEVATOR"
	root.position = Vector3(x_m, 0.0, z_m)

	var shaft: StaticBody3D = StaticBody3D.new()
	shaft.name = "Shaft"
	var shaft_size: Vector3 = Vector3(ELEVATOR_WIDTH, STRUCTURE_HEIGHT, ELEVATOR_DEPTH)
	shaft.position = Vector3(0.0, STRUCTURE_HEIGHT * 0.5, 0.0)
	shaft.add_child(_make_box_mesh(shaft_size, _mat_elevator_shaft))
	shaft.add_child(_make_box_collision(shaft_size))
	root.add_child(shaft)

	# 정면(북측, -Z) 문 panel — 살짝 돌출
	var door: MeshInstance3D = _make_box_mesh(
		Vector3(ELEVATOR_DOOR_WIDTH, ELEVATOR_DOOR_HEIGHT, 0.05), _mat_elevator_door
	)
	door.name = "Door"
	door.position = Vector3(0.0, ELEVATOR_DOOR_HEIGHT * 0.5, -ELEVATOR_DEPTH * 0.5 - 0.02)
	root.add_child(door)
	return root


func _build_stairs(x_m: float, z_m: float) -> Node3D:
	# 절차적 계단 step + 측면 핸드레일
	var root: Node3D = Node3D.new()
	root.name = "Core_STAIRS"
	root.position = Vector3(x_m, 0.0, z_m)

	var step_rise: float = STRUCTURE_HEIGHT / float(STAIRS_STEP_COUNT)
	var step_run: float = STAIRS_FOOTPRINT_Z / float(STAIRS_STEP_COUNT)
	var step_width: float = STAIRS_FOOTPRINT_X

	for i in range(STAIRS_STEP_COUNT):
		var step_height: float = step_rise * float(i + 1)
		var step_mesh: MeshInstance3D = _make_box_mesh(
			Vector3(step_width, step_height, step_run), _mat_stairs_step
		)
		step_mesh.name = "Step_%02d" % i
		var z_offset: float = -STAIRS_FOOTPRINT_Z * 0.5 + step_run * (float(i) + 0.5)
		step_mesh.position = Vector3(0.0, step_height * 0.5, z_offset)
		root.add_child(step_mesh)

	# 양측 핸드레일 — 시각적 force 강조
	for side in [-1.0, 1.0]:
		var rail: MeshInstance3D = _make_box_mesh(
			Vector3(STAIRS_HANDRAIL_THICKNESS, STAIRS_HANDRAIL_THICKNESS, STAIRS_FOOTPRINT_Z),
			_mat_handrail
		)
		rail.name = "Handrail_%s" % ("L" if side < 0 else "R")
		rail.position = Vector3(
			side * (step_width * 0.5 - STAIRS_HANDRAIL_THICKNESS * 0.5),
			STRUCTURE_HEIGHT * 0.5 + STAIRS_HANDRAIL_HEIGHT * 0.5,
			0.0
		)
		root.add_child(rail)

	return root


# ---------------------------------------------------------------------------
# 천장 광원 — 천장 슬래브가 빛을 차단하므로 실내 보조 조명
# ---------------------------------------------------------------------------

func _create_ceiling_lights(slab_size: Vector3, slab_center: Vector3) -> void:
	_lights_node = Node3D.new()
	_lights_node.name = "CeilingLights"
	add_child(_lights_node)

	# 4×3 격자로 천장에 OmniLight3D 배치
	var n_x: int = 4
	var n_z: int = 3
	for ix in range(n_x):
		for iz in range(n_z):
			var fx: float = (float(ix) + 0.5) / float(n_x)
			var fz: float = (float(iz) + 0.5) / float(n_z)
			var px: float = slab_center.x - slab_size.x * 0.5 + slab_size.x * fx
			var pz: float = slab_center.z - slab_size.z * 0.5 + slab_size.z * fz
			var light: OmniLight3D = OmniLight3D.new()
			light.name = "Light_%d_%d" % [ix, iz]
			light.position = Vector3(px, CEILING_LIGHT_OFFSET_Y, pz)
			light.light_color = CEILING_LIGHT_COLOR
			light.light_energy = CEILING_LIGHT_ENERGY
			light.omni_range = CEILING_LIGHT_RANGE
			light.shadow_enabled = false  # 그림자 비활성 (성능)
			_lights_node.add_child(light)


# ---------------------------------------------------------------------------
# Mesh 헬퍼
# ---------------------------------------------------------------------------

func _make_box_mesh(size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mi.mesh = box
	if material != null:
		mi.material_override = material
	return mi


func _make_box_collision(size: Vector3) -> CollisionShape3D:
	var coll: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	coll.shape = shape
	return coll

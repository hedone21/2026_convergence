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

## 천장 슬래브 생성 여부. 디버깅/도면 비교 시 false로 두면 top-down에서 도면 구조가 보인다.
@export var show_ceiling: bool = true

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

## 내벽 높이 — 천장까지 완전히 닿게 (방 폐쇄성 확보).
## 이전엔 2.55m로 천장과 0.7m 갭을 뒀으나, 모든 방이 위로 연결되어
## "방"이 인지되지 않는 부작용. 폐쇄성이 인지 본질.
const INNER_WALL_HEIGHT: float = STRUCTURE_HEIGHT

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
var _mat_ceiling: StandardMaterial3D = null
var _mat_column: StandardMaterial3D = null
var _mat_elevator_shaft: StandardMaterial3D = null
var _mat_elevator_door: StandardMaterial3D = null
var _mat_stairs_step: StandardMaterial3D = null
var _mat_handrail: StandardMaterial3D = null

var _surfaces: Array = []
var _spawn_bounds: AABB = AABB()


func _ready() -> void:
	_init_materials()
	var data: SiteData = _load_floor_data(floor_to_show)
	if data == null:
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
	# 명도 분기로 오브젝트 구분 (외벽 밝음 / 내벽 중간 / 기둥·천장 짙음).
	_mat_outer_wall = _concrete_material.create_outer_wall_material()
	_mat_inner_wall = _concrete_material.create_inner_wall_material()
	_mat_slab = _concrete_material.create_floor_material()
	_mat_ceiling = _concrete_material.create_ceiling_material()
	_mat_column = _concrete_material.create_column_material()
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

func _load_floor_data(floor_num: int) -> SiteData:
	var path: String = FLOOR_JSON_TEMPLATE % floor_num
	return SiteDataParser.parse_from_path(path)


# ---------------------------------------------------------------------------
# 변환
# ---------------------------------------------------------------------------

func _build_from_floor(data: SiteData) -> void:
	if data.metadata.bbox_min == data.metadata.bbox_max:
		push_error("[ParliamentVillageSite] bbox missing in metadata")
		return

	# site origin: bbox 중심 (m 단위)
	var origin_m: Vector2 = (data.metadata.bbox_min + data.metadata.bbox_max) * 0.5

	# 슬래브 영역: grid bbox(외곽 기둥 포함) + 처마 패딩
	var slab_rect_m: Rect2 = _compute_slab_rect(data, origin_m)
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
	if show_ceiling:
		_create_ceiling_slab(slab_size, slab_center)
	# door swing 위치에서 wall을 cut해 출입구 생성. v1은 swing_radius 기반 circle cut.
	var outer_cut: Array[WallData] = _cut_walls_at_doors(data.outer_walls, data.doors)
	var inner_cut: Array[WallData] = _cut_walls_at_doors(data.inner_walls, data.doors)
	_create_walls(outer_cut, inner_cut, origin_m)
	_create_columns(data, origin_m)
	_create_core_markers(data, origin_m)
	_create_ceiling_lights(slab_size, slab_center)


func _compute_slab_rect(data: SiteData, origin_m: Vector2) -> Rect2:
	# 우선순위: grid bbox(외곽 기둥 포함). 폴백: metadata.bbox.
	var grid: Dictionary = data.raw_extra.get("grid", {})
	var gx: Dictionary = grid.get("x", {})
	var gy: Dictionary = grid.get("y", {})
	var pt_to_m: float = data.metadata.unit_scale_to_meter
	var min_x_m: float
	var max_x_m: float
	var min_y_m: float
	var max_y_m: float
	if not gx.is_empty() and not gy.is_empty():
		var xs: Array = gx.values()
		var ys: Array = gy.values()
		min_x_m = float(xs.min()) * pt_to_m
		max_x_m = float(xs.max()) * pt_to_m
		min_y_m = float(ys.min()) * pt_to_m
		max_y_m = float(ys.max()) * pt_to_m
	else:
		min_x_m = data.metadata.bbox_min.x
		min_y_m = data.metadata.bbox_min.y
		max_x_m = data.metadata.bbox_max.x
		max_y_m = data.metadata.bbox_max.y

	var x0: float = min_x_m - origin_m.x - SLAB_EDGE_PADDING_M
	var z0: float = min_y_m - origin_m.y - SLAB_EDGE_PADDING_M
	var x1: float = max_x_m - origin_m.x + SLAB_EDGE_PADDING_M
	var z1: float = max_y_m - origin_m.y + SLAB_EDGE_PADDING_M
	return Rect2(Vector2(x0, z0), Vector2(x1 - x0, z1 - z0))


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
	_ceiling_body.add_child(_make_box_mesh(size, _mat_ceiling))
	_ceiling_body.add_child(_make_box_collision(size))
	_ceiling_body.position = Vector3(
		center.x, STRUCTURE_HEIGHT + SLAB_THICKNESS * 0.5, center.z
	)


# ---------------------------------------------------------------------------
# 출입구 처리 — door 위치에서 wall segment를 cut
# ---------------------------------------------------------------------------

func _cut_walls_at_doors(walls: Array[WallData], doors: Array[DoorData]) -> Array[WallData]:
	if doors.is_empty():
		return walls
	# v1 door는 hinge + swing_radius_m로 circle cut.
	var door_circles: Array = []
	for d in doors:
		if d.swing_radius_m <= 0.0:
			continue
		door_circles.append({"center": d.hinge, "radius": d.swing_radius_m})
	if door_circles.is_empty():
		return walls
	var result: Array[WallData] = []
	for w in walls:
		var segments: Array = [{"a": w.start, "b": w.end}]
		for door in door_circles:
			var new_segments: Array = []
			for seg in segments:
				new_segments.append_array(
					_cut_segment_at_circle(seg, door["center"], door["radius"])
				)
			segments = new_segments
		for seg in segments:
			var nw: WallData = w.duplicate(true)
			nw.start = seg["a"]
			nw.end = seg["b"]
			result.append(nw)
	return result


func _cut_segment_at_circle(seg: Dictionary, center: Vector2, radius: float) -> Array:
	var a: Vector2 = seg["a"]
	var b: Vector2 = seg["b"]
	var length: float = a.distance_to(b)
	if length < 0.01:
		return [seg]
	var dir: Vector2 = (b - a) / length
	var ac: Vector2 = center - a
	var t_proj: float = ac.dot(dir)
	var perp_dist: float = (ac - dir * t_proj).length()
	if perp_dist >= radius:
		return [seg]  # 직선과 원이 안 만남
	var dt: float = sqrt(radius * radius - perp_dist * perp_dist)
	var t_lo: float = clampf(t_proj - dt, 0.0, length)
	var t_hi: float = clampf(t_proj + dt, 0.0, length)
	var pieces: Array = []
	if t_lo > 0.05:
		pieces.append({"a": a, "b": a + dir * t_lo})
	if t_hi < length - 0.05:
		pieces.append({"a": a + dir * t_hi, "b": b})
	return pieces


# ---------------------------------------------------------------------------
# 벽체 (line segment → BoxMesh, 외벽은 창문 띠 분할)
# ---------------------------------------------------------------------------

func _create_walls(
	outer_cut: Array[WallData], inner_cut: Array[WallData], origin: Vector2
) -> void:
	_walls_node = Node3D.new()
	_walls_node.name = "Walls"
	add_child(_walls_node)

	for w in outer_cut:
		var a: Vector2 = w.start - origin
		var b: Vector2 = w.end - origin
		var length: float = a.distance_to(b)
		if length < MIN_WALL_LENGTH:
			continue
		# WallData.thickness_m default 0.18은 outer 기본값으로 부적합 → OUTER_WALL_THICKNESS로 fallback.
		var thickness: float = w.thickness_m if w.thickness_m > 0.19 else OUTER_WALL_THICKNESS
		_spawn_outer_wall(a, b, length, thickness)

	for w in inner_cut:
		var a: Vector2 = w.start - origin
		var b: Vector2 = w.end - origin
		var length: float = a.distance_to(b)
		if length < MIN_WALL_LENGTH:
			continue
		_spawn_inner_wall(a, b, length)


func _spawn_outer_wall(a: Vector2, b: Vector2, length: float, thickness: float) -> void:
	# 외벽: STRUCTURE_HEIGHT 전체 단일 mesh (창문 띠 분할은 비계 인상 유발해 폐기).
	_add_wall_segment(
		a, b, length, thickness, _mat_outer_wall,
		STRUCTURE_HEIGHT * 0.5,
		STRUCTURE_HEIGHT
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

func _create_columns(data: SiteData, origin: Vector2) -> void:
	_columns_node = Node3D.new()
	_columns_node.name = "Columns"
	add_child(_columns_node)

	var grid: Dictionary = data.raw_extra.get("grid", {})
	var gx: Dictionary = grid.get("x", {})
	var gy: Dictionary = grid.get("y", {})
	if gx.is_empty() or gy.is_empty():
		return
	var pt_to_m: float = data.metadata.unit_scale_to_meter

	for label_x in gx.keys():
		var x_m: float = float(gx[label_x]) * pt_to_m - origin.x
		for label_y in gy.keys():
			var z_m: float = float(gy[label_y]) * pt_to_m - origin.y

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

func _create_core_markers(data: SiteData, origin: Vector2) -> void:
	_cores_node = Node3D.new()
	_cores_node.name = "Cores"
	add_child(_cores_node)

	var pt_to_m: float = data.metadata.unit_scale_to_meter
	for raw in data.raw_extra.get("cores", []):
		if not (raw is Dictionary):
			continue
		var core: Dictionary = raw
		var bbox: Array = core.get("bbox_pt", [])
		if bbox.size() != 4:
			continue
		var cx_pt: float = (float(bbox[0]) + float(bbox[2])) * 0.5
		var cy_pt: float = (float(bbox[1]) + float(bbox[3])) * 0.5
		var x_m: float = cx_pt * pt_to_m - origin.x
		var z_m: float = cy_pt * pt_to_m - origin.y
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

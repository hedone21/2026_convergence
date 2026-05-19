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

## wall 시각화 높이 (천장 슬래브 바닥과 만나도록)
const WALL_RENDER_HEIGHT: float = FLOOR_HEIGHT - SLAB_THICKNESS

## 짧은 segment 노이즈 제외 임계값 (미터)
const MIN_WALL_LENGTH: float = 0.15

# ---------------------------------------------------------------------------
# 내부 참조
# ---------------------------------------------------------------------------

var _walls_node: Node3D
var _columns_node: Node3D
var _slab_node: Node3D
var _cores_node: Node3D
var _floor_body: StaticBody3D

var _concrete_material: ConcreteMaterial = ConcreteMaterial.new()
var _mat_outer_wall: StandardMaterial3D = null
var _mat_inner_wall: StandardMaterial3D = null
var _mat_slab: StandardMaterial3D = null
var _mat_column: StandardMaterial3D = null

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

	var bbox: Array = data.get("walls_bbox_pt", [])
	if bbox.size() != 4:
		push_error("[ParliamentVillageSite] walls_bbox_pt invalid")
		return
	var bx0: float = float(bbox[0])
	var by0: float = float(bbox[1])
	var bx1: float = float(bbox[2])
	var by1: float = float(bbox[3])
	var cx: float = (bx0 + bx1) * 0.5
	var cy: float = (by0 + by1) * 0.5
	var width_m: float = (bx1 - bx0) * pt_to_m
	var depth_m: float = (by1 - by0) * pt_to_m

	_spawn_bounds = AABB(
		Vector3(-width_m * 0.5, 0.0, -depth_m * 0.5),
		Vector3(width_m, FLOOR_HEIGHT, depth_m)
	)

	_create_slab(width_m, depth_m)
	_create_walls(data.get("walls", []), pt_to_m, cx, cy)
	_create_columns(data.get("grid", {}), pt_to_m, cx, cy)
	_create_core_markers(data.get("cores", []), pt_to_m, cx, cy)


# ---------------------------------------------------------------------------
# 슬래브 (1층 바닥)
# ---------------------------------------------------------------------------

func _create_slab(width_m: float, depth_m: float) -> void:
	_floor_body = StaticBody3D.new()
	_floor_body.name = "Slab"
	add_child(_floor_body)

	var mesh: MeshInstance3D = _make_box_mesh(
		Vector3(width_m, SLAB_THICKNESS, depth_m), _mat_slab
	)
	_floor_body.add_child(mesh)

	var coll: CollisionShape3D = _make_box_collision(
		Vector3(width_m, SLAB_THICKNESS, depth_m)
	)
	_floor_body.add_child(coll)

	_floor_body.position = Vector3(0.0, -SLAB_THICKNESS * 0.5, 0.0)

	_surfaces.append({
		"node": _floor_body,
		"surface_type": "floor",
		"aabb": AABB(
			Vector3(-width_m * 0.5, -SLAB_THICKNESS, -depth_m * 0.5),
			Vector3(width_m, SLAB_THICKNESS, depth_m)
		)
	})


# ---------------------------------------------------------------------------
# 벽체 (line segment → BoxMesh)
# ---------------------------------------------------------------------------

func _create_walls(walls: Array, pt_to_m: float, cx: float, cy: float) -> void:
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
		var ax_m: float = (float(a[0]) - cx) * pt_to_m
		var az_m: float = (float(a[1]) - cy) * pt_to_m
		var bx_m: float = (float(b[0]) - cx) * pt_to_m
		var bz_m: float = (float(b[1]) - cy) * pt_to_m

		var dx: float = bx_m - ax_m
		var dz: float = bz_m - az_m
		var length: float = sqrt(dx * dx + dz * dz)
		if length < MIN_WALL_LENGTH:
			continue

		var kind: String = w.get("kind", "inner")
		var thickness: float = OUTER_WALL_THICKNESS if kind == "outer" else INNER_WALL_THICKNESS
		var material: StandardMaterial3D = _mat_outer_wall if kind == "outer" else _mat_inner_wall

		_spawn_wall_segment(
			Vector2(ax_m, az_m),
			Vector2(bx_m, bz_m),
			length,
			thickness,
			material,
			kind == "outer"
		)


func _spawn_wall_segment(
	a: Vector2, b: Vector2, length: float, thickness: float,
	material: StandardMaterial3D, with_collision: bool
) -> void:
	var center: Vector2 = (a + b) * 0.5
	var angle: float = atan2(b.y - a.y, b.x - a.x)

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Wall"
	body.position = Vector3(center.x, WALL_RENDER_HEIGHT * 0.5, center.y)
	body.rotation = Vector3(0.0, -angle, 0.0)

	var size: Vector3 = Vector3(length, WALL_RENDER_HEIGHT, thickness)
	body.add_child(_make_box_mesh(size, material))
	if with_collision:
		body.add_child(_make_box_collision(size))

	_walls_node.add_child(body)


# ---------------------------------------------------------------------------
# 기둥 (grid 교점)
# ---------------------------------------------------------------------------

func _create_columns(grid: Dictionary, pt_to_m: float, cx: float, cy: float) -> void:
	_columns_node = Node3D.new()
	_columns_node.name = "Columns"
	add_child(_columns_node)

	var gx: Dictionary = grid.get("x", {})
	var gy: Dictionary = grid.get("y", {})
	if gx.is_empty() or gy.is_empty():
		return

	var col_index: int = 0
	for label_x in gx.keys():
		var x_pt: float = float(gx[label_x])
		var x_m: float = (x_pt - cx) * pt_to_m
		for label_y in gy.keys():
			var y_pt: float = float(gy[label_y])
			var z_m: float = (y_pt - cy) * pt_to_m
			col_index += 1

			var body: StaticBody3D = StaticBody3D.new()
			body.name = "Column_%s%s" % [label_y, label_x]
			body.position = Vector3(x_m, WALL_RENDER_HEIGHT * 0.5, z_m)

			var size: Vector3 = Vector3(COLUMN_WIDTH, WALL_RENDER_HEIGHT, COLUMN_DEPTH)
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

func _create_core_markers(cores: Array, pt_to_m: float, cx: float, cy: float) -> void:
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
		var x_m: float = (cx_pt - cx) * pt_to_m
		var z_m: float = (cy_pt - cy) * pt_to_m

		var marker: Node3D = Node3D.new()
		marker.name = "Core_%s" % core.get("label", "UNKNOWN")
		marker.position = Vector3(x_m, 0.0, z_m)
		_cores_node.add_child(marker)

		_surfaces.append({
			"node": marker,
			"surface_type": "core",
			"aabb": AABB(
				Vector3(x_m - 1.0, 0.0, z_m - 1.0),
				Vector3(2.0, FLOOR_HEIGHT, 2.0)
			)
		})


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

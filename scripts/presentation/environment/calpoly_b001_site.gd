class_name CalPolyB001Site
extends BaseSite

## SPEC-ENV-004 (TBD): Cal Poly Building 001 — DXF 기반 대학 시설 도면
##
## Cal Poly의 공개 시설 도면(DWG)을 ODA로 DXF 변환 후 v2 schema JSON으로 변환한 자료를
## 읽어 5층 건물의 단일 층을 시각화한다. PDF 추출과 달리 AIA 표준 layer(A-WALL, A-DOOR,
## A-GLAZ, A-COLS, AREA-ASSIGN)로 의미가 명시되어 fragmenting/누락 없음.
##
## 데이터 소스: data/calpoly_b001/floor_<N>.json (tools/dxf_to_v2.py 산출물)

@export var floor_to_show: int = 1
@export var show_ceiling: bool = true
@export var show_windows: bool = true

const FLOOR_JSON_TEMPLATE: String = "res://data/calpoly_b001/floor_%d.json"

const FLOOR_HEIGHT: float = 3.5
const SLAB_THICKNESS: float = 0.25
const STRUCTURE_HEIGHT: float = FLOOR_HEIGHT - SLAB_THICKNESS

const WALL_THICKNESS: float = 0.18
const SLAB_EDGE_PADDING_M: float = 1.5
const MIN_WALL_LENGTH: float = 0.08

## 창문 sill / head 높이 — wall 중앙에 구멍 표시용 (시각만)
const WINDOW_SILL_HEIGHT: float = 0.9
const WINDOW_HEAD_HEIGHT: float = 2.4

## door span 양옆 padding (m). 벽 잘릴 영역 = span + 2 × padding.
const DOOR_CUT_PADDING_M: float = 0.05

## door axis와 wall 방향 평행 판정 임계값 (|cos θ| 최소).
const DOOR_AXIS_PARALLEL_COS: float = 0.85

## door hinge에서 wall line까지 수직 거리 임계값 (m). 벽 두께 + 문 두께 마진.
## hinge는 door slab 닫힘 위치 chord의 중점 — 벽 중심선과 0.5m 이내가 일반적.
const DOOR_HINGE_PERP_MAX_M: float = 1.00

var _walls_node: Node3D
var _columns_node: Node3D
var _windows_node: Node3D
var _surfaces: Array = []
var _spawn_bounds: AABB = AABB()

var _concrete_material: ConcreteMaterial = ConcreteMaterial.new()
var _mat_wall: StandardMaterial3D = null
var _mat_floor: StandardMaterial3D = null
var _mat_ceiling: StandardMaterial3D = null
var _mat_column: StandardMaterial3D = null
var _mat_window: StandardMaterial3D = null


func _ready() -> void:
	_init_materials()
	var data: Dictionary = _load_floor_json(floor_to_show)
	if data.is_empty():
		push_error("[CalPolyB001Site] floor %d 로드 실패" % floor_to_show)
		return
	_build_from_floor(data)
	print("[CalPolyB001Site] Floor %d 빌드 완료" % floor_to_show)


func get_valid_surfaces() -> Array:
	return _surfaces


func get_spawn_bounds() -> AABB:
	return _spawn_bounds


func get_site_type() -> String:
	return "calpoly_b001"


func _init_materials() -> void:
	_mat_wall = _concrete_material.create_inner_wall_material()
	_mat_floor = _concrete_material.create_floor_material()
	_mat_ceiling = _concrete_material.create_ceiling_material()
	_mat_column = _concrete_material.create_column_material()
	_mat_window = StandardMaterial3D.new()
	_mat_window.albedo_color = Color(0.55, 0.7, 0.85, 0.4)
	_mat_window.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_window.roughness = 0.1


func _load_floor_json(n: int) -> Dictionary:
	var path: String = FLOOR_JSON_TEMPLATE % n
	if not FileAccess.file_exists(path):
		push_error("[CalPolyB001Site] floor JSON not found: %s" % path)
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("[CalPolyB001Site] JSON parse 실패: %s" % path)
		return {}
	return parsed


func _build_from_floor(data: Dictionary) -> void:
	var cats: Dictionary = data.get("categories", {})
	var meta: Dictionary = data.get("metadata", {})
	var bbox: Array = meta.get("bbox_m", [[0.0, 0.0], [0.0, 0.0]])
	if bbox.size() != 2:
		push_error("[CalPolyB001Site] bbox_m 형식 오류")
		return

	var bb_min: Vector2 = Vector2(float(bbox[0][0]), float(bbox[0][1]))
	var bb_max: Vector2 = Vector2(float(bbox[1][0]), float(bbox[1][1]))

	# site origin = bbox center → (0,0) 중심 배치
	var origin: Vector2 = (bb_min + bb_max) * 0.5

	var size_v: Vector2 = (bb_max - bb_min) + Vector2(SLAB_EDGE_PADDING_M, SLAB_EDGE_PADDING_M) * 2.0
	var slab_size: Vector3 = Vector3(size_v.x, SLAB_THICKNESS, size_v.y)

	_spawn_bounds = AABB(
		Vector3(-slab_size.x * 0.5, 0.0, -slab_size.z * 0.5),
		Vector3(slab_size.x, FLOOR_HEIGHT, slab_size.z)
	)

	_create_floor_slab(slab_size, Vector3.ZERO)
	if show_ceiling:
		_create_ceiling_slab(slab_size, Vector3.ZERO)

	# door hinge/axis/span으로 wall cut → 출입구 생성
	var door_slots: Array = _build_door_slots(cats.get("doors", []))
	var outer_raw: Array = cats.get("outer_walls", [])
	var inner_raw: Array = cats.get("inner_walls", [])
	var outer_cut: Array = _cut_walls_at_doors(outer_raw, door_slots)
	var inner_cut: Array = _cut_walls_at_doors(inner_raw, door_slots)
	print("[CalPolyB001Site] door cut: outer %d→%d, inner %d→%d (doors=%d)" % [
		outer_raw.size(), outer_cut.size(),
		inner_raw.size(), inner_cut.size(),
		door_slots.size()
	])

	_walls_node = _new_group("Walls")
	for w in outer_cut:
		_spawn_wall_segment(w, origin, _walls_node)
	for w in inner_cut:
		_spawn_wall_segment(w, origin, _walls_node)

	_columns_node = _new_group("Columns")
	for c in cats.get("columns", []):
		if c.has("start") and c.has("end"):
			_spawn_wall_segment(c, origin, _columns_node, _mat_column)

	if show_windows:
		_windows_node = _new_group("Windows")
		for w in cats.get("windows", []):
			_spawn_window_segment(w, origin)


func _new_group(name_: String) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = name_
	add_child(n)
	return n


func _spawn_wall_segment(
	w: Dictionary, origin: Vector2, parent: Node3D,
	mat: StandardMaterial3D = null
) -> void:
	var s_arr: Array = w.get("start", [])
	var e_arr: Array = w.get("end", [])
	if s_arr.size() != 2 or e_arr.size() != 2:
		return
	var s: Vector2 = Vector2(float(s_arr[0]) - origin.x, float(s_arr[1]) - origin.y)
	var e: Vector2 = Vector2(float(e_arr[0]) - origin.x, float(e_arr[1]) - origin.y)
	var length: float = s.distance_to(e)
	if length < MIN_WALL_LENGTH:
		return
	var mid: Vector2 = (s + e) * 0.5
	var ang: float = atan2(e.y - s.y, e.x - s.x)

	var body: StaticBody3D = StaticBody3D.new()
	var size: Vector3 = Vector3(length, STRUCTURE_HEIGHT, WALL_THICKNESS)
	body.add_child(_make_box_mesh(size, mat if mat else _mat_wall))
	body.add_child(_make_box_collision(size))
	body.position = Vector3(mid.x, STRUCTURE_HEIGHT * 0.5, mid.y)
	body.rotation = Vector3(0.0, -ang, 0.0)
	parent.add_child(body)


func _spawn_window_segment(w: Dictionary, origin: Vector2) -> void:
	var s_arr: Array = w.get("start", [])
	var e_arr: Array = w.get("end", [])
	if s_arr.size() != 2 or e_arr.size() != 2:
		return
	var s: Vector2 = Vector2(float(s_arr[0]) - origin.x, float(s_arr[1]) - origin.y)
	var e: Vector2 = Vector2(float(e_arr[0]) - origin.x, float(e_arr[1]) - origin.y)
	var length: float = s.distance_to(e)
	if length < MIN_WALL_LENGTH:
		return
	var mid: Vector2 = (s + e) * 0.5
	var ang: float = atan2(e.y - s.y, e.x - s.x)
	var win_height: float = WINDOW_HEAD_HEIGHT - WINDOW_SILL_HEIGHT
	var win_y: float = (WINDOW_SILL_HEIGHT + WINDOW_HEAD_HEIGHT) * 0.5

	var body: Node3D = Node3D.new()
	var size: Vector3 = Vector3(length, win_height, WALL_THICKNESS * 0.5)
	body.add_child(_make_box_mesh(size, _mat_window))
	body.position = Vector3(mid.x, win_y, mid.y)
	body.rotation = Vector3(0.0, -ang, 0.0)
	_windows_node.add_child(body)


func _create_floor_slab(size: Vector3, center: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "FloorSlab"
	add_child(body)
	body.add_child(_make_box_mesh(size, _mat_floor))
	body.add_child(_make_box_collision(size))
	body.position = Vector3(center.x, -SLAB_THICKNESS * 0.5, center.z)
	_surfaces.append({
		"node": body,
		"surface_type": "floor",
		"aabb": AABB(
			Vector3(center.x - size.x * 0.5, -SLAB_THICKNESS, center.z - size.z * 0.5),
			Vector3(size.x, SLAB_THICKNESS, size.z)
		)
	})


func _create_ceiling_slab(size: Vector3, center: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "CeilingSlab"
	add_child(body)
	body.add_child(_make_box_mesh(size, _mat_ceiling))
	body.add_child(_make_box_collision(size))
	body.position = Vector3(center.x, STRUCTURE_HEIGHT + SLAB_THICKNESS * 0.5, center.z)


## door dict (hinge, axis, span) → 내부 slot 표현으로 변환.
func _build_door_slots(doors: Array) -> Array:
	var slots: Array = []
	for d in doors:
		if not (d is Dictionary):
			continue
		if not (d.has("hinge") and d.has("axis") and d.has("span_m")):
			continue
		var h: Array = d["hinge"]
		var a: Array = d["axis"]
		if h.size() != 2 or a.size() != 2:
			continue
		var axis: Vector2 = Vector2(float(a[0]), float(a[1])).normalized()
		var span: float = float(d["span_m"]) + DOOR_CUT_PADDING_M * 2.0
		slots.append({
			"hinge": Vector2(float(h[0]), float(h[1])),
			"axis": axis,
			"span": span,
		})
	return slots


## door slot으로 wall segment를 자른다.
## 각 slot은 wall과 평행하고 가까우면, wall 따라 hinge ± span/2 영역 제거.
func _cut_walls_at_doors(walls: Array, slots: Array) -> Array:
	if slots.is_empty():
		return walls
	var result: Array = []
	for w in walls:
		var s_arr: Array = w.get("start", [])
		var e_arr: Array = w.get("end", [])
		if s_arr.size() != 2 or e_arr.size() != 2:
			result.append(w)
			continue
		var segments: Array = [[
			Vector2(float(s_arr[0]), float(s_arr[1])),
			Vector2(float(e_arr[0]), float(e_arr[1]))
		]]
		for slot: Dictionary in slots:
			var new_segs: Array = []
			for seg: Array in segments:
				_clip_segment_by_slot(seg[0], seg[1], slot, new_segs)
			segments = new_segs
		for seg: Array in segments:
			var nw: Dictionary = w.duplicate(true)
			nw["start"] = [seg[0].x, seg[0].y]
			nw["end"] = [seg[1].x, seg[1].y]
			result.append(nw)
	return result


## wall segment (a→b)가 slot과 평행 + 가까우면 hinge 영역 cut.
## 그렇지 않으면 원본 그대로 out_segs에 추가.
func _clip_segment_by_slot(
	a: Vector2, b: Vector2, slot: Dictionary, out_segs: Array
) -> void:
	var ab: Vector2 = b - a
	var L: float = ab.length()
	if L < 0.001:
		out_segs.append([a, b])
		return
	var wall_dir: Vector2 = ab / L
	var axis: Vector2 = slot["axis"] as Vector2
	if absf(wall_dir.dot(axis)) < DOOR_AXIS_PARALLEL_COS:
		out_segs.append([a, b])
		return
	var hinge: Vector2 = slot["hinge"] as Vector2
	# wall line으로의 hinge 수직 거리
	var perp: Vector2 = Vector2(-wall_dir.y, wall_dir.x)
	var perp_dist: float = absf((hinge - a).dot(perp))
	if perp_dist > DOOR_HINGE_PERP_MAX_M:
		out_segs.append([a, b])
		return
	# hinge의 wall 상 t (0~L)
	var t_hinge: float = (hinge - a).dot(wall_dir)
	var span: float = float(slot["span"])
	var t0: float = t_hinge - span * 0.5
	var t1: float = t_hinge + span * 0.5
	# cut 영역이 wall 밖이면 원본 유지
	if t1 <= 0.0 or t0 >= L:
		out_segs.append([a, b])
		return
	var t0_clamp: float = clampf(t0, 0.0, L)
	var t1_clamp: float = clampf(t1, 0.0, L)
	# [0, t0] + [t1, L] 두 토막
	if t0_clamp > 0.001:
		out_segs.append([a, a + wall_dir * t0_clamp])
	if t1_clamp < L - 0.001:
		out_segs.append([a + wall_dir * t1_clamp, b])


func _make_box_mesh(size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	return mi


func _make_box_collision(size: Vector3) -> CollisionShape3D:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	return cs

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
## room 라벨 (방 번호) 3D billboard 표시. L 키로 런타임 토글.
@export var show_room_labels: bool = true

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
## 표준 문 span 0.9m + 양옆 0.25m = cut 폭 1.4m (VR 통과 편안).
const DOOR_CUT_PADDING_M: float = 0.25

## door axis와 wall 방향 평행 판정 임계값 (|cos θ| 최소).
const DOOR_AXIS_PARALLEL_COS: float = 0.85

## door hinge에서 wall line까지 수직 거리 임계값 (m). 벽 두께 + 문 두께 마진.
## hinge는 door slab 닫힘 위치 chord의 중점 — 벽 중심선과 0.5m 이내가 일반적.
const DOOR_HINGE_PERP_MAX_M: float = 1.00

## door cut 영역 *안*에 갇힌 axis-비평행 짧은 wall (door frame 등) 제거 임계 길이 (m).
## 이보다 짧고 cut 영역 안에 mid가 있으면 axis 평행 검사 없이 제거.
const DOOR_INSIDE_WALL_MAX_M: float = 0.5

## room 라벨 표시 높이 (m) — 사람 눈높이 약간 위.
const ROOM_LABEL_HEIGHT: float = 2.2
const ROOM_LABEL_FONT_SIZE: int = 48
const ROOM_LABEL_PIXEL_SIZE: float = 0.008

var _walls_node: Node3D
var _columns_node: Node3D
var _windows_node: Node3D
var _labels_node: Node3D
var _surfaces: Array = []
var _spawn_bounds: AABB = AABB()

var _concrete_material: ConcreteMaterial = ConcreteMaterial.new()
var _mat_wall_inner: StandardMaterial3D = null
var _mat_wall_outer: StandardMaterial3D = null
var _mat_floor: StandardMaterial3D = null
var _mat_ceiling: StandardMaterial3D = null
var _mat_column: StandardMaterial3D = null
var _mat_window: StandardMaterial3D = null


func _ready() -> void:
	_init_materials()
	var data: SiteData = _load_floor_data(floor_to_show)
	if data == null:
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
	_mat_wall_inner = _concrete_material.create_inner_wall_material()
	_mat_wall_outer = _concrete_material.create_outer_wall_material()
	_mat_floor = _concrete_material.create_floor_material()
	_mat_ceiling = _concrete_material.create_ceiling_material()
	_mat_column = _concrete_material.create_column_material()
	_mat_window = StandardMaterial3D.new()
	_mat_window.albedo_color = Color(0.55, 0.7, 0.85, 0.4)
	_mat_window.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_window.roughness = 0.1


func _load_floor_data(n: int) -> SiteData:
	var path: String = FLOOR_JSON_TEMPLATE % n
	return SiteDataParser.parse_from_path(path)


func _build_from_floor(data: SiteData) -> void:
	var bb_min: Vector2 = data.metadata.bbox_min
	var bb_max: Vector2 = data.metadata.bbox_max

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
	var door_slots: Array = _build_door_slots(data.doors)
	var outer_cut: Array[WallData] = _cut_walls_at_doors(data.outer_walls, door_slots)
	var inner_cut: Array[WallData] = _cut_walls_at_doors(data.inner_walls, door_slots)
	print("[CalPolyB001Site] door cut: outer %d→%d, inner %d→%d (doors=%d)" % [
		data.outer_walls.size(), outer_cut.size(),
		data.inner_walls.size(), inner_cut.size(),
		door_slots.size()
	])

	_walls_node = _new_group("Walls")
	for w in outer_cut:
		_spawn_wall_box(w.start, w.end, origin, _walls_node, _mat_wall_outer)
	for w in inner_cut:
		_spawn_wall_box(w.start, w.end, origin, _walls_node, _mat_wall_inner)

	_columns_node = _new_group("Columns")
	for c in data.columns:
		_spawn_wall_box(c.start, c.end, origin, _columns_node, _mat_column)

	if show_windows:
		_windows_node = _new_group("Windows")
		for w in data.windows:
			_spawn_window_segment(w, origin)

	_labels_node = _new_group("RoomLabels")
	_labels_node.visible = show_room_labels
	for r in data.rooms:
		_spawn_room_label(r, origin)


func _new_group(name_: String) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = name_
	add_child(n)
	return n


## start/end (사이트 좌표 m, origin 미차감) + mat을 받아 STRUCTURE_HEIGHT box를 spawn.
## WallData / ColumnData 모두에서 호출.
func _spawn_wall_box(
	start_w: Vector2, end_w: Vector2, origin: Vector2,
	parent: Node3D, mat: StandardMaterial3D
) -> void:
	var s: Vector2 = start_w - origin
	var e: Vector2 = end_w - origin
	var length: float = s.distance_to(e)
	if length < MIN_WALL_LENGTH:
		return
	var mid: Vector2 = (s + e) * 0.5
	var ang: float = atan2(e.y - s.y, e.x - s.x)

	var body: StaticBody3D = StaticBody3D.new()
	var size: Vector3 = Vector3(length, STRUCTURE_HEIGHT, WALL_THICKNESS)
	body.add_child(_make_box_mesh(size, mat))
	body.add_child(_make_box_collision(size))
	body.position = Vector3(mid.x, STRUCTURE_HEIGHT * 0.5, mid.y)
	body.rotation = Vector3(0.0, -ang, 0.0)
	parent.add_child(body)


func _spawn_room_label(r: RoomData, origin: Vector2) -> void:
	if r.label.is_empty():
		return
	var c: Vector2 = r.centroid - origin
	var lbl: Label3D = Label3D.new()
	lbl.text = r.label
	lbl.font_size = ROOM_LABEL_FONT_SIZE
	lbl.pixel_size = ROOM_LABEL_PIXEL_SIZE
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 6
	lbl.modulate = Color(1.0, 1.0, 1.0)
	lbl.outline_modulate = Color(0.0, 0.0, 0.0)
	lbl.position = Vector3(c.x, ROOM_LABEL_HEIGHT, c.y)
	_labels_node.add_child(lbl)


func _spawn_window_segment(w: WindowData, origin: Vector2) -> void:
	var s: Vector2 = w.start - origin
	var e: Vector2 = w.end - origin
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


## DoorData → 내부 slot 표현으로 변환. axis가 ZERO인 v1 데이터는 skip.
func _build_door_slots(doors: Array[DoorData]) -> Array:
	var slots: Array = []
	for d in doors:
		if d.axis.length_squared() < 0.001 or d.span_m <= 0.0:
			continue
		slots.append({
			"hinge": d.hinge,
			"axis": d.axis.normalized(),
			"span": d.span_m + DOOR_CUT_PADDING_M * 2.0,
		})
	return slots


## door slot으로 wall segment를 자른다.
## 각 slot은 wall과 평행하고 가까우면, wall 따라 hinge ± span/2 영역 제거.
func _cut_walls_at_doors(walls: Array[WallData], slots: Array) -> Array[WallData]:
	if slots.is_empty():
		return walls
	var result: Array[WallData] = []
	for w in walls:
		var segments: Array = [[w.start, w.end]]
		for slot: Dictionary in slots:
			var new_segs: Array = []
			for seg: Array in segments:
				_clip_segment_by_slot(seg[0], seg[1], slot, new_segs)
			segments = new_segs
		for seg: Array in segments:
			var nw: WallData = w.duplicate(true)
			nw.start = seg[0]
			nw.end = seg[1]
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
	var hinge: Vector2 = slot["hinge"] as Vector2
	var span: float = float(slot["span"])
	if absf(wall_dir.dot(axis)) < DOOR_AXIS_PARALLEL_COS:
		# axis 비평행이라도 짧은 wall이 cut 영역 안에 갇히면 (door frame) 제거
		if L < DOOR_INSIDE_WALL_MAX_M:
			var axis_perp: Vector2 = Vector2(-axis.y, axis.x)
			var mid: Vector2 = (a + b) * 0.5
			var along: float = (mid - hinge).dot(axis)
			var perp_d: float = absf((mid - hinge).dot(axis_perp))
			if absf(along) < span * 0.5 and perp_d < DOOR_HINGE_PERP_MAX_M:
				return
		out_segs.append([a, b])
		return
	# wall line으로의 hinge 수직 거리
	var perp: Vector2 = Vector2(-wall_dir.y, wall_dir.x)
	var perp_dist: float = absf((hinge - a).dot(perp))
	if perp_dist > DOOR_HINGE_PERP_MAX_M:
		out_segs.append([a, b])
		return
	# hinge의 wall 상 t (0~L)
	var t_hinge: float = (hinge - a).dot(wall_dir)
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


## L 키: room 라벨 가시성 토글 (desktop 모드).
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_L and _labels_node:
		show_room_labels = not show_room_labels
		_labels_node.visible = show_room_labels
		print("[CalPolyB001Site] room labels: %s" % ("ON" if show_room_labels else "OFF"))

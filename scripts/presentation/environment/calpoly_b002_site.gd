class_name CalPolyB002Site
extends BaseSite

## SPEC-ENV-005 (TBD): Cal Poly Building 002 — DXF 기반 두 번째 학교 도면 (일반화 검증용).
##
## B001과 동일한 dxf_to_v2 파이프라인을 다른 건물 도면에 적용하여 파이프라인 일반화를 검증한다.
## 빌딩 002는 컬럼이 없고 windows가 다수(51개)이며 room 54개 100% 라벨됨.
##
## 데이터 소스: data/calpoly_b002/floor_<N>.json (tools/dxf_to_v2.py 산출물)

@export var floor_to_show: int = 1
@export var show_ceiling: bool = true
@export var show_windows: bool = true
@export var show_room_labels: bool = true

const FLOOR_JSON_TEMPLATE: String = "res://data/calpoly_b002/floor_%d.json"

const FLOOR_HEIGHT: float = 3.5
const SLAB_THICKNESS: float = 0.25
const STRUCTURE_HEIGHT: float = FLOOR_HEIGHT - SLAB_THICKNESS

const WALL_THICKNESS: float = 0.18
const SLAB_EDGE_PADDING_M: float = 1.5
const MIN_WALL_LENGTH: float = 0.08

const WINDOW_SILL_HEIGHT: float = 0.9
const WINDOW_HEAD_HEIGHT: float = 2.4

const DOOR_CUT_PADDING_M: float = 0.25
const DOOR_AXIS_PARALLEL_COS: float = 0.85
const DOOR_HINGE_PERP_MAX_M: float = 1.00
const DOOR_INSIDE_WALL_MAX_M: float = 0.5

const ROOM_LABEL_HEIGHT: float = 2.2
const ROOM_LABEL_FONT_SIZE: int = 48
const ROOM_LABEL_PIXEL_SIZE: float = 0.008

## 천장 빔 그리드 — 통판 ceiling 대신 격자 빔으로 외부 sky 노출
const BEAM_SPAN: float = 6.0
const BEAM_WIDTH: float = 0.35
const BEAM_HEIGHT: float = 0.45
const WORK_LIGHT_SPAN: float = 12.0
const WORK_LIGHT_RANGE: float = 9.0
const WORK_LIGHT_ENERGY: float = 2.5
const WORK_LIGHT_DROP: float = 0.35

var _walls_node: Node3D
var _columns_node: Node3D
var _windows_node: Node3D
var _labels_node: Node3D
var _ceiling_node: Node3D

## prop 배치 시 회피용
var _wall_segments: Array = []
const PROP_WALL_MARGIN: float = 0.4
const PROP_HAZARD_RADIUS: float = 1.5
const PROP_RETRY_COUNT: int = 20
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
		push_error("[CalPolyB002Site] floor %d 로드 실패" % floor_to_show)
		return
	_build_from_floor(data)
	print("[CalPolyB002Site] Floor %d 빌드 완료" % floor_to_show)


func get_valid_surfaces() -> Array:
	return _surfaces


func get_spawn_bounds() -> AABB:
	return _spawn_bounds


func get_site_type() -> String:
	return "calpoly_b002"


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
	var origin: Vector2 = (bb_min + bb_max) * 0.5

	var size_v: Vector2 = (bb_max - bb_min) + Vector2(SLAB_EDGE_PADDING_M, SLAB_EDGE_PADDING_M) * 2.0
	var slab_size: Vector3 = Vector3(size_v.x, SLAB_THICKNESS, size_v.y)

	_spawn_bounds = AABB(
		Vector3(-slab_size.x * 0.5, 0.0, -slab_size.z * 0.5),
		Vector3(slab_size.x, FLOOR_HEIGHT, slab_size.z)
	)

	_create_floor_slab(slab_size, Vector3.ZERO)
	if show_ceiling:
		_create_ceiling_structure(bb_min, bb_max, origin)

	var door_slots: Array = _build_door_slots(data.doors)
	var outer_cut: Array[WallData] = _cut_walls_at_doors(data.outer_walls, door_slots)
	var inner_cut: Array[WallData] = _cut_walls_at_doors(data.inner_walls, door_slots)
	print("[CalPolyB002Site] door cut: outer %d→%d, inner %d→%d (doors=%d)" % [
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

	_spawn_props_async(bb_min, bb_max, origin)

	# Phase 5b: 외부 강관비계 (KOSHA), 안전망 drape, caution stand.
	_build_exterior_scaffolding(bb_min, bb_max, origin)


func _build_exterior_scaffolding(bb_min: Vector2, bb_max: Vector2, origin: Vector2) -> void:
	var local_min: Vector2 = bb_min - origin
	var local_max: Vector2 = bb_max - origin
	var scaff: ScaffoldingGenerator = ScaffoldingGenerator.new()
	scaff.name = "Scaffolding"
	add_child(scaff)
	scaff.setup(local_min, local_max, FLOOR_HEIGHT)
	scaff.build()

	var drape: SafetyMeshDrape = SafetyMeshDrape.new()
	drape.name = "SafetyMeshDrape"
	add_child(drape)
	drape.setup(local_min, local_max, FLOOR_HEIGHT)
	drape.build()

	var sign_root: CautionStandSign = CautionStandSign.new()
	sign_root.name = "CautionStands"
	add_child(sign_root)
	sign_root.setup(local_min, local_max)
	sign_root.build()


func _spawn_props_async(bb_min: Vector2, bb_max: Vector2, origin: Vector2) -> void:
	for _i: int in 10:
		await get_tree().process_frame
	var hazard_positions: Array = _collect_hazard_positions()
	print("[CalPolyB002Site] props 배치: walls=%d, hazards=%d" % [
		_wall_segments.size(), hazard_positions.size()
	])
	_spawn_props(bb_min, bb_max, origin, hazard_positions)


func _collect_hazard_positions() -> Array:
	var positions: Array = []
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return positions
	var container: Node = main_scene.get_node_or_null("HazardContainer")
	if container == null:
		return positions
	for h: Node in container.get_children():
		if h is Node3D:
			positions.append((h as Node3D).global_position)
	return positions


func _spawn_props(bb_min: Vector2, bb_max: Vector2, _origin: Vector2, hazard_positions: Array) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7777
	var size_x: float = bb_max.x - bb_min.x
	var size_z: float = bb_max.y - bb_min.y
	var props_root: Node3D = _new_group("SiteProps")
	var factory: SiteProps = SiteProps.new()

	for i: int in 8:
		factory.spawn_safety_cone(props_root, _safe_floor_pos(rng, size_x, size_z, 0.0, hazard_positions))
	for i: int in 4:
		factory.spawn_work_lamp(props_root, _safe_floor_pos(rng, size_x, size_z, 0.0, hazard_positions))
	for i: int in 2:
		factory.spawn_material_wood(props_root, _safe_floor_pos(rng, size_x, size_z, 0.0, hazard_positions))
	for i: int in 2:
		factory.spawn_material_rebar(props_root, _safe_floor_pos(rng, size_x, size_z, 0.0, hazard_positions))
	for i: int in 2:
		factory.spawn_material_cement(props_root, _safe_floor_pos(rng, size_x, size_z, 0.0, hazard_positions))
	for i: int in 3:
		var a: Vector3 = _safe_floor_pos(rng, size_x, size_z, 0.45, hazard_positions)
		var dir: float = rng.randf() * TAU
		var len: float = 2.5 + rng.randf() * 2.0
		var b: Vector3 = a + Vector3(cos(dir) * len, 0.0, sin(dir) * len)
		factory.spawn_hazard_tape(props_root, a, b)
	for i: int in 4:
		var a: Vector3 = _safe_floor_pos(rng, size_x, size_z, STRUCTURE_HEIGHT - 0.1, hazard_positions)
		var b: Vector3 = a + Vector3(0.0, 0.0, 4.0 + rng.randf() * 3.0)
		factory.spawn_cable_hanging(props_root, a, b)
	for i: int in 2:
		var a: Vector3 = _safe_floor_pos(rng, size_x, size_z, STRUCTURE_HEIGHT - 0.4, hazard_positions)
		var b: Vector3 = a + Vector3(5.0 + rng.randf() * 4.0, 0.0, 0.0)
		factory.spawn_duct(props_root, a, b)


func _safe_floor_pos(
	rng: RandomNumberGenerator, size_x: float, size_z: float, height: float,
	hazard_positions: Array
) -> Vector3:
	for _attempt: int in PROP_RETRY_COUNT:
		var p: Vector3 = _rand_floor_pos(rng, size_x, size_z, height)
		if _is_pos_blocked_by_wall(p):
			continue
		if _is_pos_near_hazard(p, hazard_positions):
			continue
		return p
	return _rand_floor_pos(rng, size_x, size_z, height)


func _rand_floor_pos(rng: RandomNumberGenerator, size_x: float, size_z: float, height: float) -> Vector3:
	var px: float = (rng.randf() - 0.5) * size_x * 0.7
	var pz: float = (rng.randf() - 0.5) * size_z * 0.7
	return Vector3(px, height, pz)


## BaseSite override — scenario_manager hazard spawn 시 호출.
func is_position_blocked(pos: Vector3) -> bool:
	return _is_pos_blocked_by_wall(pos)


func _is_pos_blocked_by_wall(p: Vector3) -> bool:
	var p2: Vector2 = Vector2(p.x, p.z)
	var half_thick: float = WALL_THICKNESS * 0.5 + PROP_WALL_MARGIN
	for seg: Dictionary in _wall_segments:
		var s: Vector2 = seg["start"] as Vector2
		var e: Vector2 = seg["end"] as Vector2
		var ab: Vector2 = e - s
		var L: float = ab.length()
		if L < 0.001:
			continue
		var u_dir: Vector2 = ab / L
		var u: float = (p2 - s).dot(u_dir)
		if u < -PROP_WALL_MARGIN or u > L + PROP_WALL_MARGIN:
			continue
		var perp: Vector2 = Vector2(-u_dir.y, u_dir.x)
		var v: float = absf((p2 - s).dot(perp))
		if v < half_thick:
			return true
	return false


func _is_pos_near_hazard(p: Vector3, hazard_positions: Array) -> bool:
	var p2: Vector2 = Vector2(p.x, p.z)
	for hp_v: Variant in hazard_positions:
		var hp: Vector3 = hp_v as Vector3
		var d: float = Vector2(hp.x, hp.z).distance_to(p2)
		if d < PROP_HAZARD_RADIUS:
			return true
	return false


func _new_group(name_: String) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = name_
	add_child(n)
	return n


func _spawn_wall_box(
	start_w: Vector2, end_w: Vector2, origin: Vector2,
	parent: Node3D, mat: StandardMaterial3D
) -> void:
	var s: Vector2 = start_w - origin
	var e: Vector2 = end_w - origin
	var length: float = s.distance_to(e)
	if length < MIN_WALL_LENGTH:
		return
	_wall_segments.append({"start": s, "end": e})
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
	var floor_mesh: MeshInstance3D = _make_box_mesh(size, _mat_floor)
	floor_mesh.layers = 1 | FLOOR_DECAL_LAYER
	body.add_child(floor_mesh)
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

	# 슬래브 외곽 0.5m 띠 4개 — unguarded_edge 우선 매칭용.
	var edge_w: float = 0.5
	var x_min: float = center.x - size.x * 0.5
	var z_min: float = center.z - size.z * 0.5
	var edges: Array = [
		AABB(Vector3(x_min, -SLAB_THICKNESS, z_min + edge_w),
			Vector3(edge_w, SLAB_THICKNESS, size.z - edge_w * 2.0)),
		AABB(Vector3(x_min + size.x - edge_w, -SLAB_THICKNESS, z_min + edge_w),
			Vector3(edge_w, SLAB_THICKNESS, size.z - edge_w * 2.0)),
		AABB(Vector3(x_min, -SLAB_THICKNESS, z_min),
			Vector3(size.x, SLAB_THICKNESS, edge_w)),
		AABB(Vector3(x_min, -SLAB_THICKNESS, z_min + size.z - edge_w),
			Vector3(size.x, SLAB_THICKNESS, edge_w)),
	]
	for e in edges:
		_surfaces.append({
			"node": body,
			"surface_type": "edge",
			"aabb": e
		})


## 통판 ceiling 대신 격자 빔 + 작업등 (94% sky 노출).
func _create_ceiling_structure(bb_min: Vector2, bb_max: Vector2, origin: Vector2) -> void:
	_ceiling_node = _new_group("CeilingStructure")
	var size_x: float = bb_max.x - bb_min.x
	var size_z: float = bb_max.y - bb_min.y
	var center_x: float = (bb_max.x + bb_min.x) * 0.5 - origin.x
	var center_z: float = (bb_max.y + bb_min.y) * 0.5 - origin.y
	var beam_y: float = STRUCTURE_HEIGHT + BEAM_HEIGHT * 0.5

	var beam_count_z: int = max(1, int(size_z / BEAM_SPAN))
	for i: int in range(beam_count_z + 1):
		var t: float = float(i) / float(beam_count_z) - 0.5
		var z: float = center_z + t * size_z
		_spawn_beam(Vector3(size_x, BEAM_HEIGHT, BEAM_WIDTH), Vector3(center_x, beam_y, z))

	var beam_count_x: int = max(1, int(size_x / BEAM_SPAN))
	for i: int in range(beam_count_x + 1):
		var t: float = float(i) / float(beam_count_x) - 0.5
		var x: float = center_x + t * size_x
		_spawn_beam(Vector3(BEAM_WIDTH, BEAM_HEIGHT, size_z), Vector3(x, beam_y, center_z))

	var light_count_x: int = max(1, int(size_x / WORK_LIGHT_SPAN))
	var light_count_z: int = max(1, int(size_z / WORK_LIGHT_SPAN))
	var light_y: float = STRUCTURE_HEIGHT - WORK_LIGHT_DROP
	for ix: int in range(light_count_x):
		for iz: int in range(light_count_z):
			var tx: float = (float(ix) + 0.5) / float(light_count_x) - 0.5
			var tz: float = (float(iz) + 0.5) / float(light_count_z) - 0.5
			var lx: float = center_x + tx * size_x
			var lz: float = center_z + tz * size_z
			_spawn_work_light(Vector3(lx, light_y, lz))

	# Phase 5b: 빔 격자 사이에 빨간 거푸집 합판 panel 오버레이.
	_overlay_formwork_red_panels(size_x, size_z, center_x, center_z, beam_y, beam_count_x, beam_count_z)


## Phase 5b: 빔 격자 cell마다 formwork_red panel 배치.
func _overlay_formwork_red_panels(
	size_x: float, size_z: float, center_x: float, center_z: float,
	beam_y: float, beam_count_x: int, beam_count_z: int
) -> void:
	var formwork_mat: StandardMaterial3D = _concrete_material.create_formwork_red_material()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9173
	var panel_h: float = 0.05
	var panel_y: float = beam_y - BEAM_HEIGHT * 0.5 - panel_h * 0.5
	for ix: int in range(beam_count_x):
		for iz: int in range(beam_count_z):
			if rng.randf() > 0.8:
				continue
			var tx: float = (float(ix) + 0.5) / float(beam_count_x) - 0.5
			var tz: float = (float(iz) + 0.5) / float(beam_count_z) - 0.5
			var px: float = center_x + tx * size_x
			var pz: float = center_z + tz * size_z
			var pw: float = (size_x / float(beam_count_x)) * 0.88
			var pd: float = (size_z / float(beam_count_z)) * 0.88
			var panel: MeshInstance3D = MeshInstance3D.new()
			panel.name = "FormworkRedPanel_%d_%d" % [ix, iz]
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(pw, panel_h, pd)
			panel.mesh = bm
			panel.material_override = formwork_mat
			panel.position = Vector3(px, panel_y, pz)
			panel.rotation = Vector3(
				rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.05, 0.05)
			)
			_ceiling_node.add_child(panel)


func _spawn_beam(size: Vector3, pos: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.add_child(_make_box_mesh(size, _mat_ceiling))
	body.add_child(_make_box_collision(size))
	body.position = pos
	_ceiling_node.add_child(body)


func _spawn_work_light(pos: Vector3) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = pos
	light.light_color = Color(1.0, 0.85, 0.62)
	light.light_energy = WORK_LIGHT_ENERGY
	light.omni_range = WORK_LIGHT_RANGE
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	_ceiling_node.add_child(light)


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
		if L < DOOR_INSIDE_WALL_MAX_M:
			var axis_perp: Vector2 = Vector2(-axis.y, axis.x)
			var mid: Vector2 = (a + b) * 0.5
			var along: float = (mid - hinge).dot(axis)
			var perp_d: float = absf((mid - hinge).dot(axis_perp))
			if absf(along) < span * 0.5 and perp_d < DOOR_HINGE_PERP_MAX_M:
				return
		out_segs.append([a, b])
		return
	var perp: Vector2 = Vector2(-wall_dir.y, wall_dir.x)
	var perp_dist: float = absf((hinge - a).dot(perp))
	if perp_dist > DOOR_HINGE_PERP_MAX_M:
		out_segs.append([a, b])
		return
	var t_hinge: float = (hinge - a).dot(wall_dir)
	var t0: float = t_hinge - span * 0.5
	var t1: float = t_hinge + span * 0.5
	if t1 <= 0.0 or t0 >= L:
		out_segs.append([a, b])
		return
	var t0_clamp: float = clampf(t0, 0.0, L)
	var t1_clamp: float = clampf(t1, 0.0, L)
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


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_L and _labels_node:
		show_room_labels = not show_room_labels
		_labels_node.visible = show_room_labels
		print("[CalPolyB002Site] room labels: %s" % ("ON" if show_room_labels else "OFF"))
	elif event.keycode == KEY_C and _ceiling_node:
		show_ceiling = not show_ceiling
		_ceiling_node.visible = show_ceiling
		print("[CalPolyB002Site] ceiling: %s" % ("ON" if show_ceiling else "OFF"))

class_name ScaffoldingGenerator
extends Node3D

## SPEC-GFX-006 (TBD): KOSHA 강관비계 절차생성.
##
## Phase 5b 한국 공사장 외관: 외벽 BBox 둘레에 강관비계 자동 생성.
## KOSHA C-30-2020 표준:
##  - 강관 OD 48.3mm (반경 0.024m)
##  - 띠장 방향(외벽 따라) 기둥 간격 ≤ 1.85m
##  - 장선 방향(직각) 기둥 간격 ≤ 1.5m
##  - 띠장(수평) 수직 간격 ≤ 2.0m
##  - 5m마다 wall tie
##  - X 가새 4-6 bay마다
##
## MultiMesh 통합: post / ledger / brace / plank 각각 별도 MultiMeshInstance3D.

const TUBE_RADIUS: float = 0.024
const POST_SPACING_BAY: float = 1.85
const POST_SPACING_DEPTH: float = 1.5
const LEDGER_HEIGHT: float = 2.0
const PLANK_LAYERS: Array = [2, 4]  # 짝수 층에 작업발판
const BRACE_INTERVAL_BAY: int = 4
const OFFSET_FROM_WALL: float = 0.4  # 외벽에서 비계까지 거리

# 외부에서 setup() 호출 시 세팅
var bbox_min: Vector2 = Vector2.ZERO
var bbox_max: Vector2 = Vector2.ZERO
var building_height: float = 9.0  # 기본 3층

var _post_transforms: Array[Transform3D] = []
var _ledger_transforms: Array[Transform3D] = []
var _brace_transforms: Array[Transform3D] = []
var _plank_transforms: Array[Transform3D] = []


## site에서 호출. walls_bbox와 building height를 받는다.
func setup(min_xz: Vector2, max_xz: Vector2, height: float) -> void:
	bbox_min = min_xz
	bbox_max = max_xz
	building_height = max(3.0, height)


func build() -> void:
	_generate_transforms()
	_spawn_multimesh("ScaffoldPosts", _make_pipe_cylinder(1.0), _post_transforms,
		_make_steel_material())
	_spawn_multimesh("ScaffoldLedgers", _make_pipe_cylinder(1.0), _ledger_transforms,
		_make_steel_material())
	_spawn_multimesh("ScaffoldBraces", _make_pipe_cylinder(1.0), _brace_transforms,
		_make_steel_material())
	_spawn_multimesh("ScaffoldPlanks", _make_plank_box(), _plank_transforms,
		_make_plank_material())
	print("[ScaffoldingGenerator] scaffold spawned: posts=%d ledgers=%d braces=%d planks=%d"
		% [_post_transforms.size(), _ledger_transforms.size(),
		   _brace_transforms.size(), _plank_transforms.size()])


func _generate_transforms() -> void:
	# 외벽 BBox를 OFFSET 만큼 확장
	var ext_min: Vector2 = bbox_min - Vector2(OFFSET_FROM_WALL, OFFSET_FROM_WALL)
	var ext_max: Vector2 = bbox_max + Vector2(OFFSET_FROM_WALL, OFFSET_FROM_WALL)
	# 두 번째 row (장선 방향 안쪽): OFFSET + POST_SPACING_DEPTH 만큼 더 안쪽
	var inn_min: Vector2 = ext_min + Vector2(POST_SPACING_DEPTH, POST_SPACING_DEPTH)
	var inn_max: Vector2 = ext_max - Vector2(POST_SPACING_DEPTH, POST_SPACING_DEPTH)

	# 4면 처리: north (z=ext_min.y), south (z=ext_max.y), east (x=ext_max.x), west (x=ext_min.x)
	var post_height: float = building_height + 1.5  # 상단 1.5m 여유
	var faces: Array = [
		# face name, outer_p0, outer_p1, inner_p0, inner_p1, dir_axis ("x" or "z")
		{"name": "north", "o0": Vector2(ext_min.x, ext_min.y), "o1": Vector2(ext_max.x, ext_min.y),
		 "i0": Vector2(ext_min.x, inn_min.y), "i1": Vector2(ext_max.x, inn_min.y), "axis": "x"},
		{"name": "south", "o0": Vector2(ext_min.x, ext_max.y), "o1": Vector2(ext_max.x, ext_max.y),
		 "i0": Vector2(ext_min.x, inn_max.y), "i1": Vector2(ext_max.x, inn_max.y), "axis": "x"},
		{"name": "west",  "o0": Vector2(ext_min.x, ext_min.y), "o1": Vector2(ext_min.x, ext_max.y),
		 "i0": Vector2(inn_min.x, ext_min.y), "i1": Vector2(inn_min.x, ext_max.y), "axis": "z"},
		{"name": "east",  "o0": Vector2(ext_max.x, ext_min.y), "o1": Vector2(ext_max.x, ext_max.y),
		 "i0": Vector2(inn_max.x, ext_min.y), "i1": Vector2(inn_max.x, ext_max.y), "axis": "z"},
	]

	for face in faces:
		_build_face_transforms(face, post_height)


func _build_face_transforms(face: Dictionary, post_height: float) -> void:
	var o0: Vector2 = face["o0"]
	var o1: Vector2 = face["o1"]
	var i0: Vector2 = face["i0"]
	var i1: Vector2 = face["i1"]
	var axis: String = face["axis"]
	var length: float = (o1 - o0).length()
	var post_count: int = max(2, int(length / POST_SPACING_BAY) + 1)

	for k in post_count:
		var t: float = float(k) / float(post_count - 1)
		var p_outer: Vector2 = o0.lerp(o1, t)
		var p_inner: Vector2 = i0.lerp(i1, t)
		# Vertical posts: outer row + inner row
		_post_transforms.append(_make_vertical_transform(
			Vector3(p_outer.x, 0.0, p_outer.y), post_height))
		_post_transforms.append(_make_vertical_transform(
			Vector3(p_inner.x, 0.0, p_inner.y), post_height))

		# Transom (수평 가로): outer↔inner 연결, 각 LEDGER_HEIGHT 마다
		var layer: int = 0
		var ly: float = LEDGER_HEIGHT
		while ly <= post_height:
			_ledger_transforms.append(_make_horizontal_transform(
				Vector3(p_outer.x, ly, p_outer.y),
				Vector3(p_inner.x, ly, p_inner.y)))
			# 작업발판 — 짝수 layer에서
			if (layer + 1) in PLANK_LAYERS:
				_plank_transforms.append(_make_plank_transform(p_outer, p_inner, ly, axis))
			ly += LEDGER_HEIGHT
			layer += 1

	# Horizontal ledgers (띠장 방향): 인접 post 사이를 잇는 수평 강관, 각 layer마다
	for k in post_count - 1:
		var ta: float = float(k) / float(post_count - 1)
		var tb: float = float(k + 1) / float(post_count - 1)
		var p_a_outer: Vector2 = o0.lerp(o1, ta)
		var p_b_outer: Vector2 = o0.lerp(o1, tb)
		var p_a_inner: Vector2 = i0.lerp(i1, ta)
		var p_b_inner: Vector2 = i0.lerp(i1, tb)
		var ly: float = LEDGER_HEIGHT
		while ly <= post_height:
			# 외측 row ledger
			_ledger_transforms.append(_make_horizontal_transform(
				Vector3(p_a_outer.x, ly, p_a_outer.y),
				Vector3(p_b_outer.x, ly, p_b_outer.y)))
			# 내측 row ledger
			_ledger_transforms.append(_make_horizontal_transform(
				Vector3(p_a_inner.x, ly, p_a_inner.y),
				Vector3(p_b_inner.x, ly, p_b_inner.y)))
			ly += LEDGER_HEIGHT
		# X brace — BRACE_INTERVAL_BAY마다 외측 row에 추가
		if k % BRACE_INTERVAL_BAY == 0:
			_brace_transforms.append(_make_brace_transform(
				Vector3(p_a_outer.x, 0.2, p_a_outer.y),
				Vector3(p_b_outer.x, LEDGER_HEIGHT, p_b_outer.y)))
			_brace_transforms.append(_make_brace_transform(
				Vector3(p_a_outer.x, LEDGER_HEIGHT, p_a_outer.y),
				Vector3(p_b_outer.x, 0.2, p_b_outer.y)))


func _make_vertical_transform(base: Vector3, height: float) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	# 기본 CylinderMesh는 Y축 방향, height=1m → scale Y로 height 조절
	t = t.scaled(Vector3(1.0, height, 1.0))
	t.origin = base + Vector3(0.0, height * 0.5, 0.0)
	return t


func _make_horizontal_transform(a: Vector3, b: Vector3) -> Transform3D:
	var diff: Vector3 = b - a
	var length: float = diff.length()
	if length < 0.001:
		return Transform3D.IDENTITY
	var dir: Vector3 = diff / length
	# Y축(기본) cylinder을 dir 방향으로 회전 + length로 scale
	var up: Vector3 = Vector3.UP
	var basis: Basis = Basis.IDENTITY
	if abs(dir.dot(up)) < 0.999:
		var quat: Quaternion = Quaternion(up, dir)
		basis = Basis(quat)
	basis = basis.scaled(Vector3(1.0, length, 1.0))
	return Transform3D(basis, (a + b) * 0.5)


func _make_brace_transform(a: Vector3, b: Vector3) -> Transform3D:
	return _make_horizontal_transform(a, b)


func _make_plank_transform(p_outer: Vector2, p_inner: Vector2, y: float, axis: String) -> Transform3D:
	# 작업발판은 outer-inner 사이를 가로지르는 box. axis는 face 방향.
	var center_xz: Vector2 = (p_outer + p_inner) * 0.5
	var t: Transform3D = Transform3D.IDENTITY
	t.origin = Vector3(center_xz.x, y + 0.04, center_xz.y)
	# 발판 크기: face 방향(axis)으로 POST_SPACING_BAY, 수직 방향으로 POST_SPACING_DEPTH * 0.85
	if axis == "x":
		t = t.scaled(Vector3(POST_SPACING_BAY * 0.95, 1.0, POST_SPACING_DEPTH * 0.85))
	else:
		t = t.scaled(Vector3(POST_SPACING_DEPTH * 0.85, 1.0, POST_SPACING_BAY * 0.95))
	return t


func _make_pipe_cylinder(height: float) -> CylinderMesh:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = TUBE_RADIUS
	cm.bottom_radius = TUBE_RADIUS
	cm.height = height
	cm.radial_segments = 8
	cm.rings = 1
	return cm


func _make_plank_box() -> BoxMesh:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(1.0, 0.04, 1.0)
	return bm


## zinc-plated steel — 회색 metallic 0.7, 약간 무광.
func _make_steel_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.62, 0.60)
	mat.roughness = 0.45
	mat.metallic = 0.7
	mat.metallic_specular = 0.3
	return mat


func _make_plank_material() -> StandardMaterial3D:
	# plywood texture 사용
	var cm: ConcreteMaterial = ConcreteMaterial.new()
	return cm.create_formwork_natural_material()


func _spawn_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D],
		mat: StandardMaterial3D) -> void:
	if transforms.is_empty():
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)

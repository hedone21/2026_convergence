class_name CrackGenerator
extends RefCounted

## SPEC-ENV-002: 크랙 메시 절차적 생성 유틸리티
##
## 크랙(균열)의 기하학적 메시를 절차적으로 생성한다.
## 크랙의 길이, 폭, 분기 수를 파라미터로 제어하며,
## 매번 약간의 랜덤 변동을 포함하여 절차적 생성의 의미를 갖는다.

## 크랙 세그먼트의 최소 길이 비율
const MIN_SEGMENT_RATIO: float = 0.15

## 분기 각도 범위 (라디안)
const BRANCH_ANGLE_MIN: float = 0.3
const BRANCH_ANGLE_MAX: float = 0.8

## 크랙 색상 (어두운 회색)
const CRACK_COLOR: Color = Color(0.15, 0.13, 0.12, 1.0)

## 배경(콘크리트) 색상 — 난이도에 따라 크랙 색상과 혼합
const BG_COLOR: Color = Color(0.78, 0.76, 0.74, 1.0)


## SPEC-ENV-002: 크랙 메시를 절차적으로 생성한다.
## length: 크랙 총 길이 (미터)
## width: 크랙 폭 (미터)
## branches: 분기 수 (0이면 직선 크랙)
## 반환: ArrayMesh (정점 + 인덱스 기반 삼각형 메시)
func generate_crack_mesh(length: float, width: float, branches: int) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 메인 크랙 경로 생성
	var main_path: PackedVector3Array = _generate_crack_path(
		Vector3.ZERO,
		Vector3(0.0, 0.0, -1.0),  # 기본 방향: -Z
		length,
		8  # 메인 세그먼트 수
	)
	_add_crack_strip(surface_tool, main_path, width)

	# 분기 크랙 생성
	for i: int in range(branches):
		if main_path.size() < 3:
			break

		# 분기 시작점: 메인 경로의 랜덤 위치 (20%~80% 구간)
		var branch_idx: int = randi_range(1, maxi(1, main_path.size() - 2))
		var branch_start: Vector3 = main_path[branch_idx]

		# 분기 방향: 메인 경로 접선에서 좌우 랜덤 분기
		var tangent: Vector3 = Vector3.ZERO
		if branch_idx < main_path.size() - 1:
			tangent = (main_path[branch_idx + 1] - main_path[branch_idx]).normalized()
		else:
			tangent = (main_path[branch_idx] - main_path[branch_idx - 1]).normalized()

		var side: float = 1.0 if randf() > 0.5 else -1.0
		var angle: float = randf_range(BRANCH_ANGLE_MIN, BRANCH_ANGLE_MAX) * side
		var branch_dir: Vector3 = tangent.rotated(Vector3.UP, angle)

		# 분기 길이는 메인의 30~60%
		var branch_length: float = length * randf_range(0.3, 0.6)
		var branch_width: float = width * randf_range(0.4, 0.7)

		var branch_path: PackedVector3Array = _generate_crack_path(
			branch_start,
			branch_dir,
			branch_length,
			4  # 분기 세그먼트 수
		)
		_add_crack_strip(surface_tool, branch_path, branch_width)

	surface_tool.generate_normals()
	surface_tool.commit(mesh)
	return mesh


## 크랙 경로(중심선) 점들을 생성한다.
## 직선이 아니라 약간의 랜덤 편차를 포함한다.
func _generate_crack_path(
	start: Vector3,
	direction: Vector3,
	total_length: float,
	segments: int
) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	var segment_length: float = total_length / float(segments)
	var current_pos: Vector3 = start
	var current_dir: Vector3 = direction.normalized()

	points.append(current_pos)

	for i: int in range(segments):
		# 방향에 약간의 랜덤 편향 추가 (y축 회전)
		var angle_offset: float = randf_range(-0.25, 0.25)
		current_dir = current_dir.rotated(Vector3.UP, angle_offset).normalized()

		# 세그먼트 길이에도 약간의 변동
		var seg_len: float = segment_length * randf_range(0.8, 1.2)
		current_pos = current_pos + current_dir * seg_len

		points.append(current_pos)

	return points


## 크랙 경로를 따라 삼각형 스트립을 생성한다.
## 경로 중심선 좌우로 width/2만큼 확장하여 평면 메시를 만든다.
func _add_crack_strip(
	surface_tool: SurfaceTool,
	path: PackedVector3Array,
	width: float
) -> void:
	if path.size() < 2:
		return

	var half_width: float = width / 2.0
	var left_points: PackedVector3Array = PackedVector3Array()
	var right_points: PackedVector3Array = PackedVector3Array()

	for i: int in range(path.size()):
		# 접선 벡터 계산
		var tangent: Vector3
		if i == 0:
			tangent = (path[1] - path[0]).normalized()
		elif i == path.size() - 1:
			tangent = (path[i] - path[i - 1]).normalized()
		else:
			tangent = (path[i + 1] - path[i - 1]).normalized()

		# 법선 (수평면에서의 좌우 방향)
		var normal: Vector3 = tangent.cross(Vector3.UP).normalized()
		if normal.length_squared() < 0.001:
			normal = tangent.cross(Vector3.FORWARD).normalized()

		# 크랙 폭이 양 끝에서 점점 좁아지는 효과
		var taper: float = 1.0
		var t: float = float(i) / float(path.size() - 1)
		# 양 끝 20%에서 테이퍼링
		if t < 0.2:
			taper = t / 0.2
		elif t > 0.8:
			taper = (1.0 - t) / 0.2

		# 폭에 약간의 랜덤 변동
		var w: float = half_width * taper * randf_range(0.7, 1.3)

		left_points.append(path[i] + normal * w)
		right_points.append(path[i] - normal * w)

	# 삼각형 생성 (2개씩 → 사각형 1개)
	for i: int in range(left_points.size() - 1):
		# 삼각형 1: left[i], right[i], left[i+1]
		surface_tool.add_vertex(left_points[i])
		surface_tool.add_vertex(right_points[i])
		surface_tool.add_vertex(left_points[i + 1])

		# 삼각형 2: right[i], right[i+1], left[i+1]
		surface_tool.add_vertex(right_points[i])
		surface_tool.add_vertex(right_points[i + 1])
		surface_tool.add_vertex(left_points[i + 1])


## 난이도에 따른 크랙 머티리얼을 생성한다.
## opacity: 불투명도 (0.0~1.0)
## color_blend: 배경색 혼합도 (0.0 = 순수 크랙색, 1.0 = 배경색)
func create_crack_material(opacity: float, color_blend: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()

	# 크랙 색상과 배경 색상을 혼합
	var blended_color: Color = CRACK_COLOR.lerp(BG_COLOR, clampf(color_blend, 0.0, 1.0))
	blended_color.a = clampf(opacity, 0.0, 1.0)

	mat.albedo_color = blended_color
	mat.roughness = 0.95
	mat.metallic = 0.0

	# 반투명 처리
	if opacity < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# 표면에 밀착 렌더링 (Z-fighting 방지)
	mat.render_priority = 1
	mat.no_depth_test = false

	return mat

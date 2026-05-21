class_name CautionStandSign
extends Node3D

## SPEC-GFX-008 (TBD): 한국식 H형 caution stand sign.
##
## Phase 5b: 콘크리트 베이스 + 노란 polepole + 표지판 panel.
## 3종 라벨: construction / no_entry / safety_first (절차 생성 텍스쳐).
## 외벽 BBox 4면에 face당 1개씩, 총 ≥ 2 spawn.

const POLE_HEIGHT: float = 1.3
const POLE_RADIUS: float = 0.035
const BASE_SIZE: Vector3 = Vector3(0.45, 0.18, 0.45)
const SIGN_SIZE: Vector3 = Vector3(0.65, 0.45, 0.025)
const OFFSET_FROM_BBOX: float = 2.2  # bbox에서 caution stand까지 거리 (외부)

var bbox_min: Vector2 = Vector2.ZERO
var bbox_max: Vector2 = Vector2.ZERO


func setup(min_xz: Vector2, max_xz: Vector2) -> void:
	bbox_min = min_xz
	bbox_max = max_xz


func build() -> void:
	# 4면 중심에 caution stand 1개씩 (총 4개)
	var center: Vector2 = (bbox_min + bbox_max) * 0.5
	var hx: float = (bbox_max.x - bbox_min.x) * 0.5
	var hz: float = (bbox_max.y - bbox_min.y) * 0.5
	var places: Array = [
		# pos_local, facing_dir, sign_type
		{"pos": Vector3(center.x, 0.0, bbox_min.y - OFFSET_FROM_BBOX),
		 "yaw": 0.0, "type": "construction"},
		{"pos": Vector3(center.x, 0.0, bbox_max.y + OFFSET_FROM_BBOX),
		 "yaw": PI, "type": "no_entry"},
		{"pos": Vector3(bbox_min.x - OFFSET_FROM_BBOX, 0.0, center.y),
		 "yaw": PI * 0.5, "type": "safety_first"},
		{"pos": Vector3(bbox_max.x + OFFSET_FROM_BBOX, 0.0, center.y),
		 "yaw": -PI * 0.5, "type": "construction"},
	]
	for p in places:
		_spawn_stand(p["pos"], p["yaw"], p["type"])
	print("[CautionStandSign] caution_stand spawned: %d" % places.size())


func _spawn_stand(pos: Vector3, yaw: float, sign_type: String) -> void:
	var root: Node3D = Node3D.new()
	root.name = "caution_stand_%s" % sign_type
	root.position = pos
	root.rotation.y = yaw

	# 콘크리트 베이스 (BoxMesh)
	var base_mi: MeshInstance3D = MeshInstance3D.new()
	var base_mesh: BoxMesh = BoxMesh.new()
	base_mesh.size = BASE_SIZE
	base_mi.mesh = base_mesh
	base_mi.material_override = _make_concrete_material()
	base_mi.position = Vector3(0.0, BASE_SIZE.y * 0.5, 0.0)
	root.add_child(base_mi)

	# 두 폴 (H 모양 — 좌우)
	var pole_mat: StandardMaterial3D = _make_pole_material()
	for sign_x in [-0.18, 0.18]:
		var pole_mi: MeshInstance3D = MeshInstance3D.new()
		var pole_mesh: CylinderMesh = CylinderMesh.new()
		pole_mesh.top_radius = POLE_RADIUS
		pole_mesh.bottom_radius = POLE_RADIUS
		pole_mesh.height = POLE_HEIGHT
		pole_mi.mesh = pole_mesh
		pole_mi.material_override = pole_mat
		pole_mi.position = Vector3(sign_x, BASE_SIZE.y + POLE_HEIGHT * 0.5, 0.0)
		root.add_child(pole_mi)

	# 표지판 panel
	var sign_mi: MeshInstance3D = MeshInstance3D.new()
	var sign_mesh: BoxMesh = BoxMesh.new()
	sign_mesh.size = SIGN_SIZE
	sign_mi.mesh = sign_mesh
	sign_mi.material_override = _make_sign_material(sign_type)
	sign_mi.position = Vector3(0.0, BASE_SIZE.y + POLE_HEIGHT * 0.85, 0.0)
	root.add_child(sign_mi)

	add_child(root)


func _make_concrete_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.58, 0.55, 0.50)
	mat.roughness = 0.92
	mat.metallic = 0.0
	return mat


## pole: 채도 낮은 머스타드(노랑)
func _make_pole_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.58, 0.48, 0.10)
	mat.roughness = 0.55
	mat.metallic = 0.3
	return mat


## 표지판 — 절차 생성 albedo 텍스쳐, sign_type에 따라 다른 색/패턴.
func _make_sign_material(sign_type: String) -> StandardMaterial3D:
	var size: int = 256
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	var bg: Color
	var stripe: Color
	match sign_type:
		"construction":
			# 노란 바탕 + 검정 사선
			bg = Color(0.62, 0.52, 0.10)
			stripe = Color(0.04, 0.04, 0.04)
		"no_entry":
			# 빨강 바탕 + 흰 가로띠
			bg = Color(0.55, 0.12, 0.10)
			stripe = Color(0.90, 0.88, 0.84)
		"safety_first":
			# 녹색 바탕 + 흰 띠 + 십자
			bg = Color(0.18, 0.42, 0.22)
			stripe = Color(0.90, 0.90, 0.86)
		_:
			bg = Color(0.55, 0.55, 0.55)
			stripe = Color(0.10, 0.10, 0.10)
	# 바탕 채움
	for y in size:
		for x in size:
			img.set_pixel(x, y, bg)
	# stripe 패턴
	match sign_type:
		"construction":
			# 사선
			for y in size:
				for x in size:
					if ((x + y) / 24) % 2 == 1:
						img.set_pixel(x, y, stripe)
		"no_entry":
			# 굵은 가로띠 3줄
			for y in size:
				if y > 80 and y < 100:
					for x in size:
						img.set_pixel(x, y, stripe)
				elif y > 155 and y < 175:
					for x in size:
						img.set_pixel(x, y, stripe)
		"safety_first":
			# 흰 가로띠 + 가운데 사각형
			for y in size:
				if y > 60 and y < 80:
					for x in size:
						img.set_pixel(x, y, stripe)
				elif y > 180 and y < 200:
					for x in size:
						img.set_pixel(x, y, stripe)
			# 가운데 흰 사각
			for y in range(100, 160):
				for x in range(95, 161):
					img.set_pixel(x, y, stripe)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color(0.92, 0.90, 0.86)
	mat.roughness = 0.78
	mat.metallic = 0.0
	return mat

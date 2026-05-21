class_name SafetyMeshDrape
extends Node3D

## SPEC-GFX-007 (TBD): 비계 외부에 부착되는 흰색 안전망/방진막.
##
## Phase 5b 한국 공사장: 비계 짝수 bay에 흰색 mesh fabric drape.
## HDPE 흰색 75g/m² 격자 (reference: strongarmstore/shademesh).
## alpha 0.55, double-sided, emission 0.

const SCAFFOLD_OFFSET: float = 0.4  # ScaffoldingGenerator.OFFSET_FROM_WALL 과 동일
const POST_SPACING_BAY: float = 1.85
const DRAPE_HEIGHT_FRAC: float = 0.85  # 건물 높이의 85% 만큼 늘어뜨림

var bbox_min: Vector2 = Vector2.ZERO
var bbox_max: Vector2 = Vector2.ZERO
var building_height: float = 9.0

var _drape_material: StandardMaterial3D


func setup(min_xz: Vector2, max_xz: Vector2, height: float) -> void:
	bbox_min = min_xz
	bbox_max = max_xz
	building_height = max(3.0, height)


func build() -> void:
	_drape_material = _make_drape_material()
	var ext_min: Vector2 = bbox_min - Vector2(SCAFFOLD_OFFSET, SCAFFOLD_OFFSET)
	var ext_max: Vector2 = bbox_max + Vector2(SCAFFOLD_OFFSET, SCAFFOLD_OFFSET)
	var faces: Array = [
		{"name": "north", "p0": Vector2(ext_min.x, ext_min.y), "p1": Vector2(ext_max.x, ext_min.y),
		 "normal": Vector3(0.0, 0.0, -1.0)},
		{"name": "south", "p0": Vector2(ext_min.x, ext_max.y), "p1": Vector2(ext_max.x, ext_max.y),
		 "normal": Vector3(0.0, 0.0,  1.0)},
		{"name": "west",  "p0": Vector2(ext_min.x, ext_min.y), "p1": Vector2(ext_min.x, ext_max.y),
		 "normal": Vector3(-1.0, 0.0, 0.0)},
		{"name": "east",  "p0": Vector2(ext_max.x, ext_min.y), "p1": Vector2(ext_max.x, ext_max.y),
		 "normal": Vector3( 1.0, 0.0, 0.0)},
	]
	var total: int = 0
	for f in faces:
		total += _build_face_drape(f)
	print("[SafetyMeshDrape] safety_mesh spawned: %d panels" % total)


## 한 face를 짝수 bay마다 drape panel로 채움.
func _build_face_drape(face: Dictionary) -> int:
	var p0: Vector2 = face["p0"]
	var p1: Vector2 = face["p1"]
	var face_name: String = face["name"]
	var length: float = (p1 - p0).length()
	var bay_count: int = max(2, int(length / POST_SPACING_BAY))
	var spawn_count: int = 0
	# 짝수 bay (k=0,2,4..)
	for k in bay_count:
		if k % 2 != 0:
			continue
		var ta: float = float(k) / float(bay_count)
		var tb: float = float(k + 1) / float(bay_count)
		var pa: Vector2 = p0.lerp(p1, ta)
		var pb: Vector2 = p0.lerp(p1, tb)
		var center_xz: Vector2 = (pa + pb) * 0.5
		var bay_width: float = (pb - pa).length()
		var drape_h: float = building_height * DRAPE_HEIGHT_FRAC
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "safety_mesh_%s_%d" % [face_name, k]
		var pm: PlaneMesh = PlaneMesh.new()
		pm.size = Vector2(bay_width * 0.95, drape_h)
		pm.subdivide_width = 1
		pm.subdivide_depth = 1
		pm.orientation = PlaneMesh.FACE_Z
		mi.mesh = pm
		mi.material_override = _drape_material
		mi.position = Vector3(center_xz.x, drape_h * 0.5 + 0.1, center_xz.y)
		# face 방향에 맞춰 회전
		if face_name == "west" or face_name == "east":
			mi.rotation = Vector3(0.0, PI * 0.5, 0.0)
		# 살짝 흔들림
		mi.rotation.z += (k % 4 - 1.5) * 0.015
		add_child(mi)
		spawn_count += 1
	return spawn_count


## 흰색 mesh fabric — 절차 생성 알파 격자.
func _make_drape_material() -> StandardMaterial3D:
	var size: int = 64
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var white: Color = Color(0.92, 0.90, 0.86, 1.0)
	var clear: Color = Color(0.0, 0.0, 0.0, 0.0)
	for y in size:
		for x in size:
			# 1/16" mesh — 가는 줄(2px) + 사이 투명(6px)
			var on: bool = (x % 8 < 2) or (y % 8 < 2)
			img.set_pixel(x, y, white if on else clear)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color(0.94, 0.92, 0.88, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.95
	mat.metallic = 0.0
	mat.uv1_scale = Vector3(8.0, 6.0, 1.0)
	return mat

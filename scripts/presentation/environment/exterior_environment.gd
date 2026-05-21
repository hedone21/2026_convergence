class_name ExteriorEnvironment
extends Node3D

## SPEC-GFX-005 (TBD): 외부 환경 — 사이트 둘레 ground plane + 옆 건물 silhouette + 외부 보행 collision.
##
## Phase 5b: 사용자가 건물 외부로 나가서 비계·외관을 볼 수 있도록 외부 환경 추가.
##
## 구성:
##  - ground PlaneMesh 200×200m (반경 100m) + asphalt PBR + StaticBody3D
##  - silhouette buildings 6동 (반경 30~80m, 무작위 가로/세로/높이)
##  - 환경/조명은 main.tscn의 WorldEnvironment/DirectionalLight 사용 (자체 생성 금지)

const GROUND_SIZE: float = 200.0  # PlaneMesh 한 변 (반경 100m)
const SILHOUETTE_COUNT: int = 6
const SILHOUETTE_INNER_RADIUS: float = 32.0
const SILHOUETTE_OUTER_RADIUS: float = 80.0

const TEX_ASPHALT_ALBEDO: String = "res://assets/textures/asphalt/asphalt_02_diff_1k.png"
const TEX_ASPHALT_NORMAL: String = "res://assets/textures/asphalt/asphalt_02_nor_gl_1k.png"
const TEX_ASPHALT_ROUGH: String = "res://assets/textures/asphalt/asphalt_02_rough_1k.png"
const TEX_ASPHALT_AO: String = "res://assets/textures/asphalt/asphalt_02_ao_1k.png"


func _ready() -> void:
	_build_ground()
	_build_silhouette_buildings()


func _build_ground() -> void:
	var ground_body: StaticBody3D = StaticBody3D.new()
	ground_body.name = "ExteriorGround"
	ground_body.position = Vector3(0.0, -0.05, 0.0)

	# Mesh
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = "GroundMesh"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	mesh_inst.mesh = pm
	mesh_inst.material_override = _make_asphalt_material()
	ground_body.add_child(mesh_inst)

	# Collision
	var coll: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(GROUND_SIZE, 0.1, GROUND_SIZE)
	coll.shape = shape
	coll.position.y = -0.05
	ground_body.add_child(coll)

	add_child(ground_body)
	print("[ExteriorEnvironment] Ground plane spawned (size=%.1fm)" % GROUND_SIZE)


func _build_silhouette_buildings() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 71043
	var container: Node3D = Node3D.new()
	container.name = "SilhouetteBuildings"
	add_child(container)

	var mat: StandardMaterial3D = _make_silhouette_material()
	for i in SILHOUETTE_COUNT:
		var angle: float = (float(i) / float(SILHOUETTE_COUNT)) * TAU + rng.randf_range(-0.2, 0.2)
		var radius: float = rng.randf_range(SILHOUETTE_INNER_RADIUS, SILHOUETTE_OUTER_RADIUS)
		var bx: float = cos(angle) * radius
		var bz: float = sin(angle) * radius
		var bw: float = rng.randf_range(12.0, 24.0)
		var bd: float = rng.randf_range(10.0, 22.0)
		var bh: float = rng.randf_range(8.0, 24.0)

		var inst: MeshInstance3D = MeshInstance3D.new()
		inst.name = "silhouette_building_%02d" % i
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(bw, bh, bd)
		inst.mesh = bm
		inst.material_override = mat
		inst.position = Vector3(bx, bh * 0.5, bz)
		inst.rotation = Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)
		container.add_child(inst)
		print("[ExteriorEnvironment] silhouette_building spawned: %s at (%.1f, %.1f, %.1f) size=%.1fx%.1fx%.1f"
			% [inst.name, bx, bh * 0.5, bz, bw, bh, bd])


func _make_asphalt_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.40, 0.38)
	var alb: Texture2D = _load_or_null(TEX_ASPHALT_ALBEDO)
	if alb != null:
		mat.albedo_texture = alb
	var nrm: Texture2D = _load_or_null(TEX_ASPHALT_NORMAL)
	if nrm != null:
		mat.normal_enabled = true
		mat.normal_texture = nrm
	var rgh: Texture2D = _load_or_null(TEX_ASPHALT_ROUGH)
	if rgh != null:
		mat.roughness_texture = rgh
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	var ao: Texture2D = _load_or_null(TEX_ASPHALT_AO)
	if ao != null:
		mat.ao_enabled = true
		mat.ao_texture = ao
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness = 0.92
	mat.metallic = 0.0
	mat.uv1_scale = Vector3(GROUND_SIZE / 4.0, GROUND_SIZE / 4.0, 1.0)
	return mat


## 옆 건물 silhouette — 무광 회색 단색. 디테일 텍스쳐 없음 (멀리 배경 용도).
func _make_silhouette_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.52, 0.52, 0.50)
	mat.roughness = 0.95
	mat.metallic = 0.0
	return mat


func _load_or_null(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

class_name SimpleHazard
extends BaseHazard

## SPEC-HAZ-003: 위험 요소 종류 확장 — 5종 (spill/debris/unguarded_edge/exposed_rebar/wet_floor)
##
## 사실적 시각화: primitive·형광·발광 표현 금지.
## debris=콘크리트 파편 더미(다중 mesh), exposed_rebar=녹슨 철근 묶음,
## spill=유성 누수 Decal, wet_floor=푸른 반투명 Decal,
## unguarded_edge=caution tape + stanchion.
## 모든 머티리얼은 PBR(albedo/normal/rough/AO) + emission_energy_multiplier ≤ 0.3.

@export var hazard_kind: String = "spill"

# 텍스쳐 경로
const TEX_CONCRETE_ALBEDO: String = "res://assets/textures/concrete/concrete033_albedo.jpg"
const TEX_CONCRETE_NORMAL: String = "res://assets/textures/concrete/concrete033_normal.jpg"
const TEX_CONCRETE_ROUGH: String = "res://assets/textures/concrete/concrete033_roughness.jpg"
const TEX_RUST_ALBEDO: String = "res://assets/textures/rust/rust_coarse_01_diff_1k.png"
const TEX_RUST_NORMAL: String = "res://assets/textures/rust/rust_coarse_01_nor_gl_1k.png"
const TEX_RUST_ROUGH: String = "res://assets/textures/rust/rust_coarse_01_rough_1k.png"


func _ready() -> void:
	hazard_type = hazard_kind
	_build_visual()
	_build_collision()
	super._ready()


func _build_visual() -> void:
	match hazard_kind:
		"debris":
			_build_debris_pile()
		"exposed_rebar":
			_build_rebar_bundle()
		"spill":
			_build_spill_decal()
		"wet_floor":
			_build_wet_floor_decal()
		"unguarded_edge":
			_build_unguarded_edge_marker()
		_:
			_build_spill_decal()


## debris: 콘크리트 파편 더미. 5개 box 무작위 배치/회전/스케일.
func _build_debris_pile() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(hazard_id) if hazard_id != "" else 12345
	var mat: StandardMaterial3D = _load_concrete_material()
	for i in 5:
		var box: BoxMesh = BoxMesh.new()
		var sx: float = rng.randf_range(0.20, 0.45)
		var sy: float = rng.randf_range(0.15, 0.30)
		var sz: float = rng.randf_range(0.20, 0.45)
		box.size = Vector3(sx, sy, sz)
		var inst: MeshInstance3D = MeshInstance3D.new()
		inst.mesh = box
		inst.material_override = mat
		inst.position = Vector3(
			rng.randf_range(-0.35, 0.35),
			sy * 0.5,
			rng.randf_range(-0.35, 0.35)
		)
		inst.rotation = Vector3(
			rng.randf_range(-0.2, 0.2),
			rng.randf_range(0.0, TAU),
			rng.randf_range(-0.2, 0.2)
		)
		add_child(inst)


## exposed_rebar: 녹슨 철근 4개 묶음, 약간씩 기울어진 배치 + 끝부분 안전 캡.
func _build_rebar_bundle() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(hazard_id + "rebar") if hazard_id != "" else 67890
	var mat: StandardMaterial3D = _load_rust_material()
	var cap_mat: StandardMaterial3D = _make_rebar_cap_material()
	var heights: Array = [1.20, 1.40, 1.05, 1.30]
	for i in 4:
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.022
		cyl.bottom_radius = 0.022
		cyl.height = heights[i]
		var inst: MeshInstance3D = MeshInstance3D.new()
		inst.mesh = cyl
		inst.material_override = mat
		var angle: float = (float(i) / 4.0) * TAU
		var rebar_pos: Vector3 = Vector3(cos(angle) * 0.05, heights[i] * 0.5, sin(angle) * 0.05)
		inst.position = rebar_pos
		inst.rotation = Vector3(
			rng.randf_range(-0.06, 0.06),
			0.0,
			rng.randf_range(-0.06, 0.06)
		)
		add_child(inst)
		# 안전 캡 — sphere, 어두운 채도 다운된 오렌지
		var cap: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.10
		cap.mesh = sm
		cap.material_override = cap_mat
		cap.position = Vector3(rebar_pos.x, heights[i] + 0.025, rebar_pos.z)
		add_child(cap)


## 철근 안전 캡 머티리얼 — 채도 다운된 안전 오렌지.
func _make_rebar_cap_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.34, 0.10)
	mat.roughness = 0.65
	mat.metallic = 0.0
	return mat


## spill: 어두운 유성 누수 Decal. emission 없음, 살짝 반광택.
func _build_spill_decal() -> void:
	var decal: Decal = Decal.new()
	decal.name = "SpillDecal"
	decal.size = Vector3(1.4, 0.5, 1.4)
	decal.upper_fade = 0.3
	decal.lower_fade = 0.3
	decal.modulate = Color(0.10, 0.07, 0.05, 0.95)
	decal.texture_albedo = _make_puddle_texture(Color(0.06, 0.05, 0.04))
	decal.position = Vector3(0.0, 0.02, 0.0)
	add_child(decal)


## wet_floor: 푸른 반투명 물웅덩이 Decal.
## peer-eval 피드백: 이전 채도 높은 cyan(0.62, 0.78, 0.92) → 채도 낮은 회청.
## 바닥 텍스쳐가 비치는 인상을 위해 alpha도 0.55→0.35.
func _build_wet_floor_decal() -> void:
	var decal: Decal = Decal.new()
	decal.name = "WetFloorDecal"
	decal.size = Vector3(2.0, 0.5, 2.0)
	decal.upper_fade = 0.3
	decal.lower_fade = 0.3
	decal.modulate = Color(0.50, 0.56, 0.62, 0.35)
	decal.texture_albedo = _make_puddle_texture(Color(0.38, 0.45, 0.52))
	decal.position = Vector3(0.0, 0.02, 0.0)
	add_child(decal)


## unguarded_edge: caution tape + 양 끝 콘크리트 stanchion.
func _build_unguarded_edge_marker() -> void:
	var tape_w: float = 2.4
	var tape: BoxMesh = BoxMesh.new()
	tape.size = Vector3(tape_w, 0.08, 0.02)
	var tape_mat: StandardMaterial3D = _make_caution_tape_material()
	var tape_inst: MeshInstance3D = MeshInstance3D.new()
	tape_inst.mesh = tape
	tape_inst.material_override = tape_mat
	tape_inst.position = Vector3(0.0, 0.85, 0.0)
	add_child(tape_inst)
	# 양 끝 stanchion (콘크리트)
	var concrete_mat: StandardMaterial3D = _load_concrete_material()
	for sign_x in [-1.0, 1.0]:
		var pole: CylinderMesh = CylinderMesh.new()
		pole.top_radius = 0.04
		pole.bottom_radius = 0.05
		pole.height = 0.9
		var pole_inst: MeshInstance3D = MeshInstance3D.new()
		pole_inst.mesh = pole
		pole_inst.material_override = concrete_mat
		pole_inst.position = Vector3(sign_x * tape_w * 0.5, 0.45, 0.0)
		add_child(pole_inst)


# --- helpers --------------------------------------------------------------

func _load_concrete_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.58, 0.54)
	var alb: Texture2D = load(TEX_CONCRETE_ALBEDO) as Texture2D
	if alb != null:
		mat.albedo_texture = alb
	var nrm: Texture2D = load(TEX_CONCRETE_NORMAL) as Texture2D
	if nrm != null:
		mat.normal_enabled = true
		mat.normal_texture = nrm
	var rgh: Texture2D = load(TEX_CONCRETE_ROUGH) as Texture2D
	if rgh != null:
		mat.roughness_texture = rgh
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness = 0.95
	mat.metallic = 0.0
	mat.uv1_scale = Vector3(2.0, 2.0, 2.0)
	return mat


func _load_rust_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	# peer-eval 피드백: 이전 albedo(0.58, 0.38, 0.22) + metallic 0.55가 형광 주황.
	# 자연 녹 톤은 어두운 갈색 + 낮은 metallic.
	mat.albedo_color = Color(0.30, 0.22, 0.14)
	var alb: Texture2D = load(TEX_RUST_ALBEDO) as Texture2D
	if alb != null:
		mat.albedo_texture = alb
	var nrm: Texture2D = load(TEX_RUST_NORMAL) as Texture2D
	if nrm != null:
		mat.normal_enabled = true
		mat.normal_texture = nrm
	var rgh: Texture2D = load(TEX_RUST_ROUGH) as Texture2D
	if rgh != null:
		mat.roughness_texture = rgh
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness = 0.92
	mat.metallic = 0.20
	mat.metallic_specular = 0.10
	mat.uv1_scale = Vector3(8.0, 8.0, 1.0)
	return mat


## 원형 알파 puddle albedo (Decal에 사용).
func _make_puddle_texture(base_color: Color) -> ImageTexture:
	var size: int = 256
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cx: float = size * 0.5
	var cy: float = size * 0.5
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	for y in size:
		for x in size:
			var dx: float = (float(x) - cx) / cx
			var dy: float = (float(y) - cy) / cy
			var d: float = sqrt(dx * dx + dy * dy)
			var n: float = rng.randf_range(-0.08, 0.08)
			var a: float = clampf(1.0 - (d + n), 0.0, 1.0)
			a = pow(a, 1.6)
			var c: Color = base_color
			c.a = a
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## caution tape 머티리얼 — 노란/검정 사선 줄무늬, emission 0.
## peer-eval 피드백: 이전 yellow(0.85, 0.70, 0.10)가 형광. 채도 낮은 머스타드로.
## tint도 albedo_color로 추가 다운.
func _make_caution_tape_material() -> StandardMaterial3D:
	var size: int = 128
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	var yellow: Color = Color(0.55, 0.42, 0.06)
	var black: Color = Color(0.04, 0.04, 0.04)
	for y in size:
		for x in size:
			var s: int = ((x + y) / 16) % 2
			img.set_pixel(x, y, yellow if s == 0 else black)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color(0.65, 0.58, 0.42)
	mat.roughness = 0.90
	mat.metallic = 0.0
	mat.uv1_scale = Vector3(3.0, 1.0, 1.0)
	return mat


func _build_collision() -> void:
	var coll: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	if hazard_kind == "unguarded_edge":
		shape.size = Vector3(2.6, 1.2, 0.6)
	elif hazard_kind == "exposed_rebar":
		shape.size = Vector3(0.4, 1.6, 0.4)
	else:
		shape.size = Vector3(1.6, 1.0, 1.6)
	coll.shape = shape
	add_child(coll)


func apply_hazard_data(data: HazardData) -> void:
	hazard_id = data.hazard_id
	difficulty = data.difficulty
	if data.hazard_type in ["spill", "debris", "unguarded_edge", "exposed_rebar", "wet_floor"]:
		hazard_kind = data.hazard_type
		hazard_type = data.hazard_type

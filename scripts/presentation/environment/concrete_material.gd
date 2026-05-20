class_name ConcreteMaterial
extends RefCounted

## PBR 콘크리트 머티리얼 팩토리
##
## ambientCG CC0 콘크리트 PBR 텍스처(albedo/normal/roughness/AO)를 우선 사용하고,
## 텍스처 파일이 없으면 NoiseTexture2D 기반 프로시저럴 폴백으로 동작한다.
## 기둥/보/벽체/슬래브 공용, 바닥, 철근 변형은 동일 텍스처에 tint와 UV 스케일로 차별화한다.

# ---------------------------------------------------------------------------
# 텍스처 리소스 경로
# ---------------------------------------------------------------------------

const TEX_ALBEDO_PATH: String = "res://assets/textures/concrete/concrete033_albedo.jpg"
const TEX_NORMAL_PATH: String = "res://assets/textures/concrete/concrete033_normal.jpg"
const TEX_ROUGHNESS_PATH: String = "res://assets/textures/concrete/concrete033_roughness.jpg"
const TEX_AO_PATH: String = "res://assets/textures/concrete/concrete033_ao.jpg"


# ---------------------------------------------------------------------------
# 프로시저럴 폴백 텍스처 해상도
# ---------------------------------------------------------------------------

const TEXTURE_SIZE: int = 256
const NORMAL_TEXTURE_SIZE: int = 256


# ---------------------------------------------------------------------------
# 콘크리트 색상 팔레트 (PBR albedo tint — 이미지 albedo와 multiply)
# ---------------------------------------------------------------------------

## 일반 콘크리트 (기둥/보/벽체/슬래브) — 텍스처 원본 톤 거의 그대로
const TINT_CONCRETE: Color = Color(0.82, 0.78, 0.72)

## 바닥 콘크리트 — 작업 흙먼지 / warm 회색
const TINT_FLOOR: Color = Color(0.62, 0.58, 0.52)

## 철근/구조물 — 살짝 밝게
const TINT_REBAR: Color = Color(0.95, 0.92, 0.88)

## 명도 분기 — 오브젝트 구분용 + warm 톤다운 (사용자: "전체 너무 흰색")
## hazard(crack=0.3 albedo) 대비 유지를 위해 표면 명도는 0.55~0.85 범위.
const TINT_OUTER_WALL: Color = Color(0.85, 0.80, 0.74)   # 외벽: 노출, 비교적 밝지만 warm
const TINT_INNER_WALL: Color = Color(0.72, 0.68, 0.62)   # 내벽: 중간 warm 회색
const TINT_COLUMN: Color = Color(0.60, 0.58, 0.54)       # 기둥: 짙어 구조 강조
const TINT_CEILING: Color = Color(0.55, 0.52, 0.48)      # 천장 빔: 가장 어두운 음영


# ---------------------------------------------------------------------------
# 공개 API
# ---------------------------------------------------------------------------

func create_concrete_material() -> StandardMaterial3D:
	return _build_material(TINT_CONCRETE, 1.0, Vector3(2.0, 2.0, 2.0))


func create_floor_material() -> StandardMaterial3D:
	return _build_material(TINT_FLOOR, 1.1, Vector3(3.0, 3.0, 3.0))


func create_rebar_material() -> StandardMaterial3D:
	return _build_material(TINT_REBAR, 0.9, Vector3(1.5, 1.5, 1.5))


func create_outer_wall_material() -> StandardMaterial3D:
	return _build_material(TINT_OUTER_WALL, 1.0, Vector3(2.0, 2.0, 2.0))


func create_inner_wall_material() -> StandardMaterial3D:
	return _build_material(TINT_INNER_WALL, 1.0, Vector3(2.0, 2.0, 2.0))


func create_column_material() -> StandardMaterial3D:
	# 기둥: 살짝 다른 UV scale로 거푸집 패턴 차별감
	return _build_material(TINT_COLUMN, 0.95, Vector3(1.8, 1.8, 1.8))


func create_ceiling_material() -> StandardMaterial3D:
	# 천장: UV scale 키워 슬래브와 같은 텍스처여도 패턴 빈도 다름
	return _build_material(TINT_CEILING, 1.05, Vector3(3.5, 3.5, 3.5))


## SPEC-GFX-001 (TBD): 벽 trim sheet 머티리얼.
## 상/중/하 차등 단일 sheet (assets/textures/trim_sheets/concrete_trim.png).
## 벽 mesh의 V축에 sheet의 zone이 매핑되도록 UV scale을 Y=1.0, X=2.0로.
const TRIM_SHEET_PATH: String = "res://assets/textures/trim_sheets/concrete_trim.png"


func create_wall_trim_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var trim_tex: Texture2D = load(TRIM_SHEET_PATH) as Texture2D
	if trim_tex != null:
		mat.albedo_texture = trim_tex
	mat.albedo_color = TINT_INNER_WALL
	mat.roughness = 0.85
	mat.metallic = 0.0
	mat.uv1_scale = Vector3(2.0, 1.0, 1.0)  # 가로 반복, 세로 1회 (상/중/하 zone)
	mat.uv1_triplanar = false
	return mat


# ---------------------------------------------------------------------------
# 내부 구현
# ---------------------------------------------------------------------------

func _build_material(
	tint_color: Color,
	roughness_value: float,
	uv_scale: Vector3
) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()

	mat.albedo_color = tint_color
	mat.albedo_texture = _load_texture_or_fallback(
		TEX_ALBEDO_PATH, _create_albedo_noise_texture
	)

	mat.roughness = roughness_value
	mat.roughness_texture = _load_texture_or_fallback(
		TEX_ROUGHNESS_PATH, _create_roughness_noise_texture
	)
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED

	mat.normal_enabled = true
	mat.normal_texture = _load_texture_or_fallback(
		TEX_NORMAL_PATH, _create_normal_noise_texture
	)
	mat.normal_scale = 1.0

	var ao_tex: Texture2D = _load_texture(TEX_AO_PATH)
	if ao_tex != null:
		mat.ao_enabled = true
		mat.ao_texture = ao_tex
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.ao_light_affect = 0.5

	mat.uv1_scale = uv_scale

	mat.metallic = 0.0
	mat.metallic_specular = 0.3

	return mat


func _load_texture_or_fallback(path: String, fallback_fn: Callable) -> Texture2D:
	var tex: Texture2D = _load_texture(path)
	if tex != null:
		return tex
	return fallback_fn.call()


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


# ---------------------------------------------------------------------------
# 프로시저럴 폴백 (이미지 없을 때만 사용)
# ---------------------------------------------------------------------------

func _create_albedo_noise_texture() -> NoiseTexture2D:
	var noise_tex: NoiseTexture2D = NoiseTexture2D.new()
	noise_tex.width = TEXTURE_SIZE
	noise_tex.height = TEXTURE_SIZE
	noise_tex.seamless = true
	noise_tex.seamless_blend_skirt = 0.15

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.015
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	noise.seed = randi()

	noise_tex.noise = noise

	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.35, 0.33, 0.31))
	gradient.set_color(1, Color(0.55, 0.53, 0.50))
	noise_tex.color_ramp = gradient

	return noise_tex


func _create_roughness_noise_texture() -> NoiseTexture2D:
	var noise_tex: NoiseTexture2D = NoiseTexture2D.new()
	noise_tex.width = TEXTURE_SIZE
	noise_tex.height = TEXTURE_SIZE
	noise_tex.seamless = true
	noise_tex.seamless_blend_skirt = 0.15

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.025
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	noise.seed = randi()

	noise_tex.noise = noise

	return noise_tex


func _create_normal_noise_texture() -> NoiseTexture2D:
	var noise_tex: NoiseTexture2D = NoiseTexture2D.new()
	noise_tex.width = NORMAL_TEXTURE_SIZE
	noise_tex.height = NORMAL_TEXTURE_SIZE
	noise_tex.seamless = true
	noise_tex.seamless_blend_skirt = 0.15
	noise_tex.as_normal_map = true
	noise_tex.bump_strength = 4.0

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	noise.seed = randi()

	noise_tex.noise = noise

	return noise_tex

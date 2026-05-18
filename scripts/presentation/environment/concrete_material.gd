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
const TINT_CONCRETE: Color = Color(1.0, 0.98, 0.95)

## 바닥 콘크리트 — 약간 어둡고 따뜻한 톤
const TINT_FLOOR: Color = Color(0.78, 0.76, 0.72)

## 철근/구조물 — 약간 밝게
const TINT_REBAR: Color = Color(1.1, 1.08, 1.05)


# ---------------------------------------------------------------------------
# 공개 API
# ---------------------------------------------------------------------------

func create_concrete_material() -> StandardMaterial3D:
	return _build_material(TINT_CONCRETE, 1.0, Vector3(2.0, 2.0, 2.0))


func create_floor_material() -> StandardMaterial3D:
	return _build_material(TINT_FLOOR, 1.1, Vector3(3.0, 3.0, 3.0))


func create_rebar_material() -> StandardMaterial3D:
	return _build_material(TINT_REBAR, 0.9, Vector3(1.5, 1.5, 1.5))


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

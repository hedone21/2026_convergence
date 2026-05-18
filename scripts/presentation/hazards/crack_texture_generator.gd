class_name CrackTextureGenerator
extends RefCounted

## 크랙 Decal용 텍스처 생성기
##
## ambientCG CC0 AsphaltDamageSet001(albedo+alpha / normal)을 우선 사용하고,
## 텍스처 파일이 없으면 NoiseTexture2D 기반 프로시저럴 폴백으로 동작한다.
## Decal.texture_albedo / Decal.texture_normal에 사용한다.

# ---------------------------------------------------------------------------
# 텍스처 리소스 경로 (이미지 우선)
# ---------------------------------------------------------------------------

const TEX_ALBEDO_PATH: String = "res://assets/textures/cracks/crack_set001_albedo.png"
const TEX_NORMAL_PATH: String = "res://assets/textures/cracks/crack_set001_normal.png"


# ---------------------------------------------------------------------------
# 프로시저럴 폴백 상수
# ---------------------------------------------------------------------------

const CRACK_TEXTURE_SIZE: int = 256
const CRACK_COLOR_DARK: Color = Color(0.12, 0.10, 0.09, 1.0)
const CRACK_COLOR_EDGE: Color = Color(0.25, 0.22, 0.20, 0.6)


# ---------------------------------------------------------------------------
# 공개 API
# ---------------------------------------------------------------------------

## 크랙 Decal용 albedo 텍스처를 반환한다.
## 이미지 파일이 있으면 PBR PNG(알파 마스크 포함), 없으면 프로시저럴 셀룰러 노이즈.
func create_crack_albedo_texture() -> Texture2D:
	var tex: Texture2D = _load_texture(TEX_ALBEDO_PATH)
	if tex != null:
		return tex
	return _create_procedural_albedo()


## 크랙 Decal용 노멀맵 텍스처를 반환한다.
## 이미지 파일이 있으면 GL 노멀맵 PNG, 없으면 프로시저럴 노멀맵.
func create_crack_normal_texture() -> Texture2D:
	var tex: Texture2D = _load_texture(TEX_NORMAL_PATH)
	if tex != null:
		return tex
	return _create_procedural_normal()


# ---------------------------------------------------------------------------
# 내부 구현
# ---------------------------------------------------------------------------

func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


# ---------------------------------------------------------------------------
# 프로시저럴 폴백 (이미지 없을 때만 사용)
# ---------------------------------------------------------------------------

func _create_procedural_albedo() -> NoiseTexture2D:
	var noise_tex: NoiseTexture2D = NoiseTexture2D.new()
	noise_tex.width = CRACK_TEXTURE_SIZE
	noise_tex.height = CRACK_TEXTURE_SIZE
	noise_tex.seamless = false

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.04
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	noise.cellular_jitter = 1.0
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	noise.seed = randi()

	noise_tex.noise = noise

	var gradient: Gradient = Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, CRACK_COLOR_DARK)
	gradient.add_point(0.15, CRACK_COLOR_EDGE)
	gradient.add_point(0.35, Color(0.0, 0.0, 0.0, 0.0))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))

	noise_tex.color_ramp = gradient

	return noise_tex


func _create_procedural_normal() -> NoiseTexture2D:
	var noise_tex: NoiseTexture2D = NoiseTexture2D.new()
	noise_tex.width = CRACK_TEXTURE_SIZE
	noise_tex.height = CRACK_TEXTURE_SIZE
	noise_tex.seamless = false
	noise_tex.as_normal_map = true
	noise_tex.bump_strength = 8.0

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.04
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	noise.cellular_jitter = 1.0
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	noise.seed = randi()

	noise_tex.noise = noise

	return noise_tex

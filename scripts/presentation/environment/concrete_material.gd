class_name ConcreteMaterial
extends RefCounted

## PBR 콘크리트 머티리얼 팩토리
##
## NoiseTexture2D + FastNoiseLite를 활용하여 프로시저럴 PBR 콘크리트 텍스처를 생성한다.
## 외부 이미지 파일 없이 코드만으로 콘크리트 표면의 albedo, roughness, normal 변화를 표현한다.
## Quest 72fps 유지를 위해 텍스처 해상도를 256~512px로 제한한다.

# ---------------------------------------------------------------------------
# 텍스처 해상도 상수 (Quest VR 성능 고려)
# ---------------------------------------------------------------------------

## 기본 텍스처 해상도 (정사각형)
const TEXTURE_SIZE: int = 256

## 노멀맵 텍스처 해상도 (약간 낮게)
const NORMAL_TEXTURE_SIZE: int = 256


# ---------------------------------------------------------------------------
# 콘크리트 색상 팔레트
# ---------------------------------------------------------------------------

## 일반 콘크리트 (밝은 회색)
const COLOR_CONCRETE: Color = Color(0.75, 0.73, 0.70)

## 바닥 콘크리트 (약간 더 어둡고 거친)
const COLOR_FLOOR: Color = Color(0.62, 0.60, 0.58)

## 철근/구조물 (약간 더 밝은)
const COLOR_REBAR: Color = Color(0.80, 0.78, 0.76)


# ---------------------------------------------------------------------------
# 공개 API
# ---------------------------------------------------------------------------

## 일반 콘크리트 머티리얼 생성 (기둥, 보, 벽체, 슬래브 공용)
## NoiseTexture2D albedo + 노멀맵으로 PBR 콘크리트 느낌을 표현한다.
func create_concrete_material() -> StandardMaterial3D:
	return _build_material(COLOR_CONCRETE, 0.88, Vector3(2.0, 2.0, 2.0))


## 바닥용 콘크리트 머티리얼 생성 (더 어둡고 거친 표면)
func create_floor_material() -> StandardMaterial3D:
	return _build_material(COLOR_FLOOR, 0.95, Vector3(3.0, 3.0, 3.0))


## 철근/구조물용 머티리얼 생성 (약간 더 밝고 매끈한)
func create_rebar_material() -> StandardMaterial3D:
	return _build_material(COLOR_REBAR, 0.82, Vector3(1.5, 1.5, 1.5))


# ---------------------------------------------------------------------------
# 내부 구현
# ---------------------------------------------------------------------------

## PBR 머티리얼을 구성한다.
## base_color: 기본 albedo 색상
## roughness_value: roughness 값 (0.0~1.0)
## uv_scale: UV 반복 스케일
func _build_material(
	base_color: Color,
	roughness_value: float,
	uv_scale: Vector3
) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()

	# -- Albedo --
	mat.albedo_color = base_color
	mat.albedo_texture = _create_albedo_noise_texture()

	# -- Roughness --
	mat.roughness = roughness_value
	mat.roughness_texture = _create_roughness_noise_texture()
	# roughness_texture의 채널 설정 (Green 채널 사용)
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN

	# -- Normal Map --
	mat.normal_enabled = true
	mat.normal_texture = _create_normal_noise_texture()
	mat.normal_scale = 0.6  # 미세한 요철 — 너무 강하지 않게

	# -- UV 스케일 --
	mat.uv1_scale = uv_scale

	# -- 기타 PBR 속성 --
	mat.metallic = 0.0
	mat.metallic_specular = 0.3

	return mat


## Albedo용 NoiseTexture2D 생성 — 콘크리트 표면의 미세한 색상 변화
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

	# GradientTexture로 색상 범위 제한 (회색 톤 유지)
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.65, 0.63, 0.61))  # 어두운 부분
	gradient.set_color(1, Color(0.85, 0.83, 0.80))  # 밝은 부분
	noise_tex.color_ramp = gradient

	return noise_tex


## Roughness용 NoiseTexture2D 생성 — 거친/매끈 영역 변화
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


## Normal Map용 NoiseTexture2D 생성 — 표면 요철 표현
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

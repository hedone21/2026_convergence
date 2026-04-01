class_name CrackTextureGenerator
extends RefCounted

## 크랙 Decal용 프로시저럴 텍스처 생성기
##
## NoiseTexture2D와 Gradient를 조합하여 코드만으로 크랙 패턴 텍스처를 생성한다.
## Decal.texture_albedo에 사용할 albedo 텍스처와
## Decal.texture_normal에 사용할 노멀맵을 생성한다.
## Quest 성능을 위해 해상도를 256px로 제한한다.

# ---------------------------------------------------------------------------
# 상수
# ---------------------------------------------------------------------------

## 크랙 텍스처 해상도 (정사각형)
const CRACK_TEXTURE_SIZE: int = 256

## 크랙 기본 색상 (어두운 갈색-회색)
const CRACK_COLOR_DARK: Color = Color(0.12, 0.10, 0.09, 1.0)

## 크랙 가장자리 색상 (약간 밝은)
const CRACK_COLOR_EDGE: Color = Color(0.25, 0.22, 0.20, 0.6)


# ---------------------------------------------------------------------------
# 공개 API
# ---------------------------------------------------------------------------

## 크랙 Decal용 albedo 텍스처를 생성한다.
## Cellular 노이즈의 가장자리 패턴을 활용하여 갈라진 모양을 표현한다.
func create_crack_albedo_texture() -> NoiseTexture2D:
	var noise_tex: NoiseTexture2D = NoiseTexture2D.new()
	noise_tex.width = CRACK_TEXTURE_SIZE
	noise_tex.height = CRACK_TEXTURE_SIZE
	noise_tex.seamless = false  # 크랙은 타일링 불필요

	var noise: FastNoiseLite = FastNoiseLite.new()
	# Cellular 노이즈 — 셀 경계가 크랙 패턴처럼 보임
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.04
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	# RETURN_DISTANCE2_SUB: 두 번째-첫 번째 거리 차이 -> 셀 경계에서 얇은 선 생성
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	noise.cellular_jitter = 1.0
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	noise.seed = randi()

	noise_tex.noise = noise

	# Gradient로 크랙 선만 어두운 색으로, 나머지는 투명하게
	var gradient: Gradient = Gradient.new()
	# 낮은 값(셀 경계) = 어두운 크랙 색상, 불투명
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, CRACK_COLOR_DARK)
	# 중간값 = 가장자리 반투명
	gradient.add_point(0.15, CRACK_COLOR_EDGE)
	# 높은 값(셀 내부) = 완전 투명
	gradient.add_point(0.35, Color(0.0, 0.0, 0.0, 0.0))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))

	noise_tex.color_ramp = gradient

	return noise_tex


## 크랙 Decal용 노멀맵 텍스처를 생성한다.
## 크랙 패턴의 깊이감을 표현한다.
func create_crack_normal_texture() -> NoiseTexture2D:
	var noise_tex: NoiseTexture2D = NoiseTexture2D.new()
	noise_tex.width = CRACK_TEXTURE_SIZE
	noise_tex.height = CRACK_TEXTURE_SIZE
	noise_tex.seamless = false
	noise_tex.as_normal_map = true
	noise_tex.bump_strength = 8.0  # 크랙의 깊이감을 강조

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.04
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	noise.cellular_jitter = 1.0
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	# 동일 시드를 사용하면 albedo와 정렬되지만, 별도로 생성하므로 랜덤
	noise.seed = randi()

	noise_tex.noise = noise

	return noise_tex

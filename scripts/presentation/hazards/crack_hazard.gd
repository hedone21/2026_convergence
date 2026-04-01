class_name CrackHazard
extends BaseHazard

## SPEC-ENV-002: 크랙 절차적 생성 시스템
## SPEC-HAZ-001: 위험 요소 기본 시스템
##
## BaseHazard를 상속하여 콘크리트 크랙(균열) 위험 요소를 구현한다.
## Decal 노드를 사용하여 크랙 비주얼을 구조물 표면에 투영한다.
## CrackTextureGenerator로 프로시저럴 크랙 텍스처를 생성한다.
## difficulty에 따라 Decal 크기(size), 투명도(modulate alpha)를 조절한다.

## 크랙 파라미터 — HazardData에서 설정됨
var crack_length: float = 1.0
var crack_width: float = 0.02
var crack_branches: int = 2

## 내부 참조
var _crack_decal: Decal = null
var _collision_shape: CollisionShape3D = null
var _discovered_indicator: Node3D = null

## 크랙 텍스처 생성기 인스턴스
var _texture_generator: CrackTextureGenerator = CrackTextureGenerator.new()
## 난이도 규칙 인스턴스
var _hazard_rules: HazardRules = HazardRules.new()

## 크랙 기본 색상 (Decal modulate)
const CRACK_MODULATE: Color = Color(0.3, 0.25, 0.2, 1.0)


func _ready() -> void:
	hazard_type = "crack"
	_build_visual()
	_build_collision()
	_build_discovered_indicator()
	super._ready()


## HazardData를 적용하고 비주얼을 재생성한다.
func apply_hazard_data(data: HazardData) -> void:
	crack_length = data.crack_length
	crack_width = data.crack_width
	crack_branches = data.crack_branches
	super.apply_hazard_data(data)
	# 비주얼이 이미 구성되어 있으면 재생성
	if _crack_decal != null:
		_rebuild_visual()


## 난이도에 따른 비주얼 조정
func _apply_difficulty() -> void:
	if _crack_decal == null:
		return

	var params: Dictionary = _hazard_rules.calculate_difficulty_visual_params(difficulty)
	var visual_scale: float = params["scale"]
	var opacity: float = params["opacity"]
	var color_blend: float = params["color_blend"]

	# Decal 크기 조정 — difficulty에 따라 스케일 변화
	var base_extents_x: float = crack_length * 0.6
	var base_extents_z: float = crack_length * 0.4
	_crack_decal.size = Vector3(
		base_extents_x * visual_scale,
		0.5,  # Y축 투영 깊이 (콘크리트 표면에 투영)
		base_extents_z * visual_scale
	)

	# Decal modulate — 투명도로 난이도 표현
	var blended_color: Color = CRACK_MODULATE.lerp(
		Color(0.75, 0.73, 0.70, 0.0),  # 배경 콘크리트색 + 완전 투명
		color_blend
	)
	blended_color.a = clampf(opacity, 0.0, 1.0)
	_crack_decal.modulate = blended_color

	# 충돌 영역도 스케일에 맞게 조정
	if _collision_shape != null:
		var shape: BoxShape3D = _collision_shape.shape as BoxShape3D
		if shape != null:
			shape.size = Vector3(
				crack_length * visual_scale + 0.2,
				0.3,
				crack_length * visual_scale + 0.2
			)


## 발견 시 시각적 피드백: 녹색 하이라이트
func _show_discovered_feedback() -> void:
	# Decal modulate를 녹색으로 변경
	if _crack_decal != null:
		_crack_decal.modulate = Color(0.0, 0.8, 0.2, 0.9)

	# 발견 인디케이터 표시
	if _discovered_indicator != null:
		_discovered_indicator.visible = true


## 크랙 Decal 비주얼을 생성한다.
func _build_visual() -> void:
	_crack_decal = Decal.new()
	_crack_decal.name = "CrackDecal"

	# 프로시저럴 크랙 텍스처 적용
	_crack_decal.texture_albedo = _texture_generator.create_crack_albedo_texture()
	_crack_decal.texture_normal = _texture_generator.create_crack_normal_texture()

	# Decal 기본 크기 (난이도 적용 전)
	_crack_decal.size = Vector3(crack_length * 0.6, 0.5, crack_length * 0.4)

	# Decal 색상 + 투명도
	_crack_decal.modulate = CRACK_MODULATE

	# Decal 설정 — 표면에 투영
	_crack_decal.upper_fade = 0.3
	_crack_decal.lower_fade = 0.3
	_crack_decal.normal_fade = 0.5

	# 표면에 살짝 떠있도록 (정확한 표면 투영을 위해)
	_crack_decal.position.y = 0.01

	add_child(_crack_decal)


## 비주얼을 재생성한다 (파라미터 변경 시).
func _rebuild_visual() -> void:
	if _crack_decal != null:
		# 텍스처 재생성 (랜덤 시드 변경으로 다른 패턴)
		_crack_decal.texture_albedo = _texture_generator.create_crack_albedo_texture()
		_crack_decal.texture_normal = _texture_generator.create_crack_normal_texture()

		# 크기 갱신
		_crack_decal.size = Vector3(crack_length * 0.6, 0.5, crack_length * 0.4)

		_apply_difficulty()


## 탐지용 충돌 영역을 생성한다.
func _build_collision() -> void:
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "DetectionArea"

	var shape: BoxShape3D = BoxShape3D.new()
	# 크랙 주변에 약간의 여유를 둔 탐지 영역
	shape.size = Vector3(crack_length + 0.2, 0.3, crack_length + 0.2)
	_collision_shape.shape = shape

	add_child(_collision_shape)


## 발견 인디케이터를 생성한다 (초기 비활성).
func _build_discovered_indicator() -> void:
	_discovered_indicator = Node3D.new()
	_discovered_indicator.name = "DiscoveredIndicator"
	_discovered_indicator.visible = false

	# 간단한 마커: 작은 구체
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	mesh_instance.mesh = sphere

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 1.0, 0.3, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.0, 1.0, 0.3)
	mat.emission_energy_multiplier = 0.5
	mesh_instance.material_override = mat

	mesh_instance.position = Vector3(0.0, 0.3, 0.0)
	_discovered_indicator.add_child(mesh_instance)

	add_child(_discovered_indicator)

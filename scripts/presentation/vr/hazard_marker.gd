class_name HazardMarker
extends Node3D

## SPEC-INP-002: 위험 마킹 시각 표시
##
## 사용자가 마킹한 위치에 영구 시각 마커를 표시한다.
## Vec3 위치 + Unix epoch ms timestamp + 카테고리 메타데이터를 보관하여
## 세션 채점(SPEC-DAT-002)에서 실제 hazard와 매칭하는 데 사용된다.
##
## HazardMarkPlaced 시그널 (snake_case: hazard_mark_placed) 발행 주체는 HazardManager.

const MARKER_RADIUS: float = 0.15
const STEM_HEIGHT: float = 0.4
const STEM_RADIUS: float = 0.02

## 카테고리별 마커 색상. 미지정 시 DEFAULT_COLOR.
const CATEGORY_COLORS: Dictionary = {
	"crack": Color(1.0, 0.3, 0.3),
	"spill": Color(0.3, 0.6, 1.0),
	"debris": Color(1.0, 0.7, 0.2),
	"unguarded_edge": Color(1.0, 0.0, 0.5),
	"exposed_rebar": Color(1.0, 0.5, 0.0),
	"wet_floor": Color(0.0, 0.8, 1.0),
	"false_positive": Color(0.5, 0.5, 0.5),
}
const DEFAULT_COLOR: Color = Color(1.0, 1.0, 0.3)

## 마킹 위치 (world Vector3)
var marker_position: Vector3 = Vector3.ZERO

## Unix epoch milliseconds (Time.get_ticks_msec())
var timestamp_ms: int = 0

## 카테고리 — hazard.hazard_type 또는 "false_positive"
var category: String = ""


func _ready() -> void:
	global_position = marker_position
	_build_visual()


## SPEC-INP-002: 마커 메타데이터를 설정한다.
## 호출 후 _ready / 즉시 시각 갱신.
func place(pos: Vector3, ts_ms: int, cat: String) -> void:
	marker_position = pos
	timestamp_ms = ts_ms
	category = cat
	if is_inside_tree():
		global_position = pos
		_build_visual()


func _build_visual() -> void:
	for c: Node in get_children():
		c.queue_free()

	var color: Color = CATEGORY_COLORS.get(category, DEFAULT_COLOR)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5

	var sphere_inst: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = MARKER_RADIUS
	sphere.height = MARKER_RADIUS * 2.0
	sphere_inst.mesh = sphere
	sphere_inst.material_override = mat
	sphere_inst.position = Vector3(0, STEM_HEIGHT, 0)
	add_child(sphere_inst)

	var stem_inst: MeshInstance3D = MeshInstance3D.new()
	var stem: CylinderMesh = CylinderMesh.new()
	stem.top_radius = STEM_RADIUS
	stem.bottom_radius = STEM_RADIUS
	stem.height = STEM_HEIGHT
	stem_inst.mesh = stem
	stem_inst.position = Vector3(0, STEM_HEIGHT * 0.5, 0)
	stem_inst.material_override = mat
	add_child(stem_inst)

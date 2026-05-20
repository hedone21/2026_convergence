class_name SimpleHazard
extends BaseHazard

## SPEC-HAZ-003: 위험 요소 종류 확장 — 5종 (spill/debris/unguarded_edge/exposed_rebar/wet_floor)
##
## BaseHazard 상속. tscn에 따라 hazard_kind를 다르게 설정하여 시각/크기 차별화.
## crack 외 단순 시각 위험요소를 공통 코드로 다룸.

const TYPE_CONFIG: Dictionary = {
	"spill": {
		"color": Color(0.3, 0.6, 1.0), "shape": "puddle",
		"size": Vector3(1.0, 0.05, 1.0),
	},
	"debris": {
		"color": Color(0.6, 0.4, 0.2), "shape": "box",
		"size": Vector3(0.5, 0.3, 0.5),
	},
	"unguarded_edge": {
		"color": Color(1.0, 0.0, 0.5), "shape": "box",
		"size": Vector3(2.0, 0.1, 0.2),
	},
	"exposed_rebar": {
		"color": Color(1.0, 0.5, 0.0), "shape": "cylinder",
		"size": Vector3(0.04, 1.0, 0.04),
	},
	"wet_floor": {
		"color": Color(0.0, 0.8, 1.0), "shape": "puddle",
		"size": Vector3(1.5, 0.02, 1.5),
	},
}

@export var hazard_kind: String = "spill"


func _ready() -> void:
	hazard_type = hazard_kind
	_build_visual()
	_build_collision()
	super._ready()


func _build_visual() -> void:
	var cfg: Dictionary = TYPE_CONFIG.get(hazard_kind, TYPE_CONFIG["spill"])
	var size: Vector3 = cfg["size"]
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()

	match cfg["shape"]:
		"box":
			var bm: BoxMesh = BoxMesh.new()
			bm.size = size
			mesh_inst.mesh = bm
		"cylinder", "puddle":
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = size.x
			cm.bottom_radius = size.x
			cm.height = size.y if cfg["shape"] == "cylinder" else max(size.y, 0.02)
			mesh_inst.mesh = cm

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = cfg["color"]
	mat.emission_enabled = true
	mat.emission = cfg["color"]
	mat.emission_energy_multiplier = 0.4
	mesh_inst.material_override = mat
	add_child(mesh_inst)


func _build_collision() -> void:
	var cfg: Dictionary = TYPE_CONFIG.get(hazard_kind, TYPE_CONFIG["spill"])
	var size: Vector3 = cfg["size"]
	var coll: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size + Vector3(0.3, 0.3, 0.3)
	coll.shape = shape
	add_child(coll)


func apply_hazard_data(data: HazardData) -> void:
	hazard_id = data.hazard_id
	difficulty = data.difficulty
	if data.hazard_type in TYPE_CONFIG:
		hazard_kind = data.hazard_type
		hazard_type = data.hazard_type

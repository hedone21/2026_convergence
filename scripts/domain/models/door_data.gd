class_name DoorData
extends Resource

## SPEC-ENV-005 (TBD): 문 데이터 모델.
## v2(Cal Poly): hinge + axis + span_m로 axis-based wall cut.
## v1(parliament): hinge + swing_radius_m로 swing-circle wall cut.
## 둘 중 하나만 채워지면 site.gd가 분기.

@export var id: String = ""
@export var hinge: Vector2 = Vector2.ZERO
## v2 only. ZERO면 v1 swing 모드.
@export var axis: Vector2 = Vector2.ZERO
## v2: 문 폭 (slab 닫힘 chord 길이). v1: width_pt × scale.
@export var span_m: float = 0.0
## v1 only. 0이면 v2 axis 모드.
@export var swing_radius_m: float = 0.0


static func from_v2(d: Dictionary) -> DoorData:
	var door: DoorData = DoorData.new()
	door.id = str(d.get("id", ""))
	var h: Array = d.get("hinge", [0.0, 0.0])
	var a: Array = d.get("axis", [0.0, 0.0])
	door.hinge = Vector2(float(h[0]), float(h[1]))
	door.axis = Vector2(float(a[0]), float(a[1])).normalized()
	door.span_m = float(d.get("span_m", 0.0))
	return door


static func from_v1(d: Dictionary, scale: float) -> DoorData:
	var door: DoorData = DoorData.new()
	var c: Array = d.get("center_pt", [0.0, 0.0])
	door.hinge = Vector2(float(c[0]) * scale, float(c[1]) * scale)
	door.span_m = float(d.get("width_pt", 0.0)) * scale
	door.swing_radius_m = float(d.get("cut_radius_pt", 0.0)) * scale
	return door

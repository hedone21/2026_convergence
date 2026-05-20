class_name WallData
extends Resource

## SPEC-ENV-005 (TBD): 벽 segment 데이터 모델.
## start/end는 m 단위, 사이트 원점 기준 좌표.

@export var id: String = ""
@export var start: Vector2 = Vector2.ZERO
@export var end: Vector2 = Vector2.ZERO
## "outer" | "inner". v1은 walls.kind에서, v2는 categories에서 결정.
@export var side: String = "inner"
## m. v1은 thickness_pt × scale, v2는 default 0.18.
@export var thickness_m: float = 0.18


static func from_v2(d: Dictionary, default_side: String = "inner") -> WallData:
	var w: WallData = WallData.new()
	w.id = str(d.get("id", ""))
	var s: Array = d.get("start", [0.0, 0.0])
	var e: Array = d.get("end", [0.0, 0.0])
	w.start = Vector2(float(s[0]), float(s[1]))
	w.end = Vector2(float(e[0]), float(e[1]))
	w.side = str(d.get("side", default_side))
	return w


static func from_v1(d: Dictionary, scale: float) -> WallData:
	var w: WallData = WallData.new()
	var a: Array = d.get("a_pt", [0.0, 0.0])
	var b: Array = d.get("b_pt", [0.0, 0.0])
	w.start = Vector2(float(a[0]) * scale, float(a[1]) * scale)
	w.end = Vector2(float(b[0]) * scale, float(b[1]) * scale)
	var kind: String = str(d.get("kind", "inner"))
	w.side = "outer" if kind == "outer_wall" else "inner"
	var t_pt: float = float(d.get("thickness_pt", 0.0))
	if t_pt > 0.0:
		w.thickness_m = t_pt * scale
	return w


func length() -> float:
	return start.distance_to(end)

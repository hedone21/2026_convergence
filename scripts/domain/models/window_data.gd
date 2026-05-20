class_name WindowData
extends Resource

## SPEC-ENV-005 (TBD): 창문 데이터 모델.
## DXF A-GLAZ LINE은 segment 단위. start/end는 m.

@export var id: String = ""
@export var start: Vector2 = Vector2.ZERO
@export var end: Vector2 = Vector2.ZERO


static func from_v2(d: Dictionary) -> WindowData:
	var w: WindowData = WindowData.new()
	w.id = str(d.get("id", ""))
	var s: Array = d.get("start", [0.0, 0.0])
	var e: Array = d.get("end", [0.0, 0.0])
	w.start = Vector2(float(s[0]), float(s[1]))
	w.end = Vector2(float(e[0]), float(e[1]))
	return w

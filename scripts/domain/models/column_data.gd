class_name ColumnData
extends Resource

## SPEC-ENV-005 (TBD): 기둥 데이터 모델.
## DXF A-COLS LINE은 정사각형 외곽 4개 line으로 들어와 segment 단위.
## start/end는 m 단위.

@export var id: String = ""
@export var start: Vector2 = Vector2.ZERO
@export var end: Vector2 = Vector2.ZERO


static func from_v2(d: Dictionary) -> ColumnData:
	var c: ColumnData = ColumnData.new()
	c.id = str(d.get("id", ""))
	var s: Array = d.get("start", [0.0, 0.0])
	var e: Array = d.get("end", [0.0, 0.0])
	c.start = Vector2(float(s[0]), float(s[1]))
	c.end = Vector2(float(e[0]), float(e[1]))
	return c

class_name RoomData
extends Resource

## SPEC-ENV-005 (TBD): 방 영역 데이터 모델.
## v2(Cal Poly): AREA-ASSIGN polygon + 면적 + label.
## v1(parliament): bbox_pt + label (polygon은 bbox 4 vertex로 합성).

@export var id: String = ""
@export var label: String = ""
@export var centroid: Vector2 = Vector2.ZERO
@export var polygon: PackedVector2Array = PackedVector2Array()
@export var area_m2: float = 0.0


static func from_v2(d: Dictionary) -> RoomData:
	var r: RoomData = RoomData.new()
	r.id = str(d.get("id", ""))
	var lbl = d.get("label", "")
	r.label = str(lbl) if lbl != null else ""
	var c: Array = d.get("centroid", [0.0, 0.0])
	r.centroid = Vector2(float(c[0]), float(c[1]))
	var poly_raw: Array = d.get("polygon", [])
	var poly: PackedVector2Array = PackedVector2Array()
	for p in poly_raw:
		if p is Array and p.size() >= 2:
			poly.append(Vector2(float(p[0]), float(p[1])))
	r.polygon = poly
	r.area_m2 = float(d.get("area_m2", 0.0))
	return r


static func from_v1(d: Dictionary, scale: float) -> RoomData:
	var r: RoomData = RoomData.new()
	r.label = str(d.get("label", ""))
	var c: Array = d.get("center_pt", [0.0, 0.0])
	r.centroid = Vector2(float(c[0]) * scale, float(c[1]) * scale)
	var bbox: Array = d.get("bbox_pt", [])
	if bbox.size() == 4:
		var x0: float = float(bbox[0]) * scale
		var y0: float = float(bbox[1]) * scale
		var x1: float = float(bbox[2]) * scale
		var y1: float = float(bbox[3]) * scale
		r.polygon = PackedVector2Array([
			Vector2(x0, y0), Vector2(x1, y0),
			Vector2(x1, y1), Vector2(x0, y1),
		])
		r.area_m2 = absf((x1 - x0) * (y1 - y0))
	return r

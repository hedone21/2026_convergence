class_name SiteMetadata
extends Resource

## SPEC-ENV-005 (TBD): 사이트 도면 메타데이터.
## floor JSON의 metadata 필드를 타입화한다.

## "1.0" (parliament_village 등 pt 기반) | "2.0" (DXF/m 기반).
@export var schema_version: String = "2.0"

## floor 도면 bbox (m 단위). [min_xy, max_xy].
@export var bbox_min: Vector2 = Vector2.ZERO
@export var bbox_max: Vector2 = Vector2.ZERO

## v1: pt → m 변환 비율. v2: 항상 1.0 (이미 m).
@export var unit_scale_to_meter: float = 1.0

## state plane / 큰 절대좌표를 원점으로 옮긴 offset (m).
@export var origin_offset: Vector2 = Vector2.ZERO


static func from_v2(meta: Dictionary) -> SiteMetadata:
	var m: SiteMetadata = SiteMetadata.new()
	m.schema_version = str(meta.get("schema_version", "2.0"))
	var bb: Array = meta.get("bbox_m", [[0.0, 0.0], [0.0, 0.0]])
	if bb.size() == 2 and bb[0] is Array and bb[1] is Array:
		m.bbox_min = Vector2(float(bb[0][0]), float(bb[0][1]))
		m.bbox_max = Vector2(float(bb[1][0]), float(bb[1][1]))
	var src: Dictionary = meta.get("source", {})
	m.unit_scale_to_meter = float(src.get("unit_scale_to_meter", 1.0))
	var off: Array = meta.get("origin_offset_m", [0.0, 0.0])
	if off.size() == 2:
		m.origin_offset = Vector2(float(off[0]), float(off[1]))
	return m


static func from_v1(data: Dictionary) -> SiteMetadata:
	var m: SiteMetadata = SiteMetadata.new()
	m.schema_version = "1.0"
	var scale_d: Dictionary = data.get("scale", {})
	m.unit_scale_to_meter = float(scale_d.get("pdf_pt_to_meter", 0.0338666))
	var bbox: Array = data.get("walls_bbox_pt", [])
	if bbox.size() == 4:
		var s: float = m.unit_scale_to_meter
		m.bbox_min = Vector2(float(bbox[0]) * s, float(bbox[1]) * s)
		m.bbox_max = Vector2(float(bbox[2]) * s, float(bbox[3]) * s)
	return m

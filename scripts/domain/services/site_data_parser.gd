class_name SiteDataParser
extends RefCounted

## SPEC-ENV-005 (TBD): floor JSON → SiteData 변환.
## schema_version 분기 (v1: parliament_village pt / v2: DXF m).
## v1은 categories 트리 없이 평면 구조, v2는 categories.* 트리.


## floor JSON 파일 경로에서 SiteData 생성. 실패 시 null.
static func parse_from_path(path: String) -> SiteData:
	if not FileAccess.file_exists(path):
		push_error("[SiteDataParser] file not found: %s" % path)
		return null
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("[SiteDataParser] JSON parse 실패: %s" % path)
		return null
	return parse_from_dict(parsed)


## Dictionary에서 SiteData 생성. schema_version에 따라 v1/v2 분기.
static func parse_from_dict(data: Dictionary) -> SiteData:
	var meta_dict: Dictionary = data.get("metadata", {})
	var schema: String = str(meta_dict.get("schema_version", ""))
	if schema == "" or not data.has("categories"):
		return _parse_v1(data)
	return _parse_v2(data)


static func _parse_v2(data: Dictionary) -> SiteData:
	var sd: SiteData = SiteData.new()
	sd.metadata = SiteMetadata.from_v2(data.get("metadata", {}))
	var cats: Dictionary = data.get("categories", {})

	for d in cats.get("outer_walls", []):
		if d is Dictionary:
			sd.outer_walls.append(WallData.from_v2(d, "outer"))
	for d in cats.get("inner_walls", []):
		if d is Dictionary:
			sd.inner_walls.append(WallData.from_v2(d, "inner"))
	for d in cats.get("doors", []):
		if d is Dictionary and d.has("hinge") and d.has("axis"):
			sd.doors.append(DoorData.from_v2(d))
	for d in cats.get("rooms", []):
		if d is Dictionary:
			sd.rooms.append(RoomData.from_v2(d))
	for d in cats.get("columns", []):
		if d is Dictionary:
			sd.columns.append(ColumnData.from_v2(d))
	for d in cats.get("windows", []):
		if d is Dictionary:
			sd.windows.append(WindowData.from_v2(d))
	return sd


static func _parse_v1(data: Dictionary) -> SiteData:
	var sd: SiteData = SiteData.new()
	sd.metadata = SiteMetadata.from_v1(data)
	var scale: float = sd.metadata.unit_scale_to_meter

	# v1 walls.kind로 outer/inner/column 분배. core는 별도 처리(site.gd가 raw로).
	for d in data.get("walls", []):
		if not (d is Dictionary):
			continue
		var kind: String = str(d.get("kind", "inner"))
		if kind == "column":
			# v1은 column도 walls 안 segment로 들어옴 (드물게).
			# columns는 주로 grid 교차점에서 site.gd가 별도 생성. 여기선 무시.
			continue
		var w: WallData = WallData.from_v1(d, scale)
		if w.side == "outer":
			sd.outer_walls.append(w)
		else:
			sd.inner_walls.append(w)

	for d in data.get("doors", []):
		if d is Dictionary:
			sd.doors.append(DoorData.from_v1(d, scale))

	for d in data.get("rooms", []):
		if d is Dictionary:
			sd.rooms.append(RoomData.from_v1(d, scale))
	# v1은 columns/windows 카테고리가 데이터에 없음. site.gd가 grid/cores로 별도 처리.
	return sd

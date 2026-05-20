class_name SiteData
extends Resource

## SPEC-ENV-005 (TBD): 사이트 도면 데이터 최상위 Resource.
## floor JSON (v1: parliament_village pt 기반 / v2: DXF m 기반)을 타입화한다.
## SiteDataParser가 schema_version으로 분기해 생성한다.

@export var metadata: SiteMetadata = SiteMetadata.new()
@export var outer_walls: Array[WallData] = []
@export var inner_walls: Array[WallData] = []
@export var doors: Array[DoorData] = []
@export var rooms: Array[RoomData] = []
@export var columns: Array[ColumnData] = []
@export var windows: Array[WindowData] = []


func wall_count() -> int:
	return outer_walls.size() + inner_walls.size()

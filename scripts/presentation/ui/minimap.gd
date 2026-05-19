extends Control

## 도면 미니맵. floor_*.json을 직접 읽어 _draw()로 외벽/내벽/코어/grid를 그린다.
## 플레이어 위치는 매 프레임 갱신되는 빨간 점으로 표시.
##
## 토글: M 키 (기본 표시)

const FLOOR_JSON_TEMPLATE: String = "res://data/parliament_village/floor_%02d.json"
const PT_TO_M: float = 0.0338666
const TOGGLE_KEYCODE: int = KEY_M

## 미니맵 외곽 padding (월드 pt 기준)
const BBOX_PADDING_PT: float = 60.0

const COLOR_BG: Color = Color(0.08, 0.09, 0.12, 0.88)
const COLOR_BORDER: Color = Color(0.4, 0.4, 0.5, 1.0)
const COLOR_GRID: Color = Color(0.35, 0.35, 0.42, 1.0)
const COLOR_GRID_TEXT: Color = Color(0.55, 0.6, 0.8, 1.0)
const COLOR_INNER_WALL: Color = Color(0.75, 0.75, 0.78, 1.0)
const COLOR_OUTER_WALL: Color = Color(0.95, 0.45, 0.35, 1.0)
const COLOR_CORE_STAIRS: Color = Color(0.35, 0.85, 0.5, 1.0)
const COLOR_CORE_ELEVATOR: Color = Color(0.4, 0.7, 0.95, 1.0)
const COLOR_PLAYER: Color = Color(1.0, 0.95, 0.2, 1.0)
const COLOR_PLAYER_HEADING: Color = Color(1.0, 0.95, 0.2, 0.7)

@export var floor_to_show: int = 1

var _floor_data: Dictionary = {}
var _bbox_x0: float = 0.0
var _bbox_y0: float = 0.0
var _bbox_x1: float = 0.0
var _bbox_y1: float = 0.0
var _bbox_center_x_pt: float = 0.0
var _bbox_center_y_pt: float = 0.0
## 이 미니맵 윈도우가 표시하는 pt 영역 → 픽셀 영역. 한 번 계산해 둠.
var _draw_rect: Rect2 = Rect2()
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	_load_floor_data()
	_compute_draw_rect()
	queue_redraw()
	set_process(true)


func _process(_delta: float) -> void:
	# 플레이어 점이 매 프레임 갱신되어야 하므로 redraw.
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event
		if key_event.keycode == TOGGLE_KEYCODE:
			visible = not visible


func _load_floor_data() -> void:
	var path: String = FLOOR_JSON_TEMPLATE % floor_to_show
	if not FileAccess.file_exists(path):
		push_error("[Minimap] floor JSON not found: %s" % path)
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("[Minimap] floor JSON parse failed: %s" % path)
		return
	_floor_data = parsed
	var bb: Array = _floor_data.get("walls_bbox_pt", [])
	if bb.size() != 4:
		push_error("[Minimap] walls_bbox_pt invalid")
		return
	_bbox_x0 = float(bb[0]) - BBOX_PADDING_PT
	_bbox_y0 = float(bb[1]) - BBOX_PADDING_PT
	_bbox_x1 = float(bb[2]) + BBOX_PADDING_PT
	_bbox_y1 = float(bb[3]) + BBOX_PADDING_PT
	# 시뮬 site origin = walls_bbox 중심 (padding 미적용)
	_bbox_center_x_pt = (float(bb[0]) + float(bb[2])) * 0.5
	_bbox_center_y_pt = (float(bb[1]) + float(bb[3])) * 0.5


func _compute_draw_rect() -> void:
	# 컨트롤 사이즈 안에 비율 유지하며 fit
	var avail: Vector2 = size
	var pt_w: float = _bbox_x1 - _bbox_x0
	var pt_h: float = _bbox_y1 - _bbox_y0
	if pt_w <= 0.0 or pt_h <= 0.0 or avail.x <= 0.0 or avail.y <= 0.0:
		_draw_rect = Rect2(Vector2.ZERO, avail)
		return
	var scale_x: float = avail.x / pt_w
	var scale_y: float = avail.y / pt_h
	var s: float = min(scale_x, scale_y)
	var draw_w: float = pt_w * s
	var draw_h: float = pt_h * s
	var offset: Vector2 = Vector2(
		(avail.x - draw_w) * 0.5,
		(avail.y - draw_h) * 0.5
	)
	_draw_rect = Rect2(offset, Vector2(draw_w, draw_h))


func _resized() -> void:
	_compute_draw_rect()
	queue_redraw()


## PDF pt 좌표 → 미니맵 픽셀 좌표
func _pt_to_pixel(px: float, py: float) -> Vector2:
	var pt_w: float = _bbox_x1 - _bbox_x0
	var pt_h: float = _bbox_y1 - _bbox_y0
	if pt_w <= 0.0 or pt_h <= 0.0:
		return Vector2.ZERO
	var u: float = (px - _bbox_x0) / pt_w
	var v: float = (py - _bbox_y0) / pt_h
	return _draw_rect.position + Vector2(u * _draw_rect.size.x, v * _draw_rect.size.y)


## Godot world (x, z) → 미니맵 픽셀
func _world_to_pixel(world_x: float, world_z: float) -> Vector2:
	var px: float = world_x / PT_TO_M + _bbox_center_x_pt
	var py: float = world_z / PT_TO_M + _bbox_center_y_pt
	return _pt_to_pixel(px, py)


func _draw() -> void:
	# 배경 + 테두리
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BORDER, false, 1.5)

	if _floor_data.is_empty():
		return

	# Grid lines
	var grid: Dictionary = _floor_data.get("grid", {})
	var gx: Dictionary = grid.get("x", {})
	var gy: Dictionary = grid.get("y", {})
	for key in gx.keys():
		var xpt: float = float(gx[key])
		var top: Vector2 = _pt_to_pixel(xpt, _bbox_y0)
		var bot: Vector2 = _pt_to_pixel(xpt, _bbox_y1)
		draw_line(top, bot, COLOR_GRID, 1.0)
		draw_string(_font, top + Vector2(-4, 12), str(key), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, COLOR_GRID_TEXT)
	for key in gy.keys():
		var ypt: float = float(gy[key])
		var lf: Vector2 = _pt_to_pixel(_bbox_x0, ypt)
		var rt: Vector2 = _pt_to_pixel(_bbox_x1, ypt)
		draw_line(lf, rt, COLOR_GRID, 1.0)
		draw_string(_font, lf + Vector2(2, 4), str(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GRID_TEXT)

	# Inner walls (thin)
	var walls: Array = _floor_data.get("walls", [])
	for raw in walls:
		if not (raw is Dictionary):
			continue
		var w: Dictionary = raw
		if w.get("kind", "") != "inner":
			continue
		var a: Array = w.get("a_pt", [])
		var b: Array = w.get("b_pt", [])
		if a.size() != 2 or b.size() != 2:
			continue
		draw_line(
			_pt_to_pixel(float(a[0]), float(a[1])),
			_pt_to_pixel(float(b[0]), float(b[1])),
			COLOR_INNER_WALL, 1.0
		)

	# Outer walls (thick)
	for raw in walls:
		if not (raw is Dictionary):
			continue
		var w: Dictionary = raw
		if w.get("kind", "") != "outer":
			continue
		var a: Array = w.get("a_pt", [])
		var b: Array = w.get("b_pt", [])
		if a.size() != 2 or b.size() != 2:
			continue
		draw_line(
			_pt_to_pixel(float(a[0]), float(a[1])),
			_pt_to_pixel(float(b[0]), float(b[1])),
			COLOR_OUTER_WALL, 2.0
		)

	# Cores
	var cores: Array = _floor_data.get("cores", [])
	for raw in cores:
		if not (raw is Dictionary):
			continue
		var core: Dictionary = raw
		var bbox: Array = core.get("bbox_pt", [])
		if bbox.size() != 4:
			continue
		var p0: Vector2 = _pt_to_pixel(float(bbox[0]), float(bbox[1]))
		var p1: Vector2 = _pt_to_pixel(float(bbox[2]), float(bbox[3]))
		var rect: Rect2 = Rect2(p0, p1 - p0).abs()
		var label: String = core.get("label", "")
		var color: Color = COLOR_CORE_STAIRS if label == "STAIRS" else COLOR_CORE_ELEVATOR
		draw_rect(rect.grow(4.0), color, false, 1.5)

	# Player dot + heading
	var camera: Camera3D = GameManager.get_camera() if GameManager else null
	if camera != null:
		var pos: Vector3 = camera.global_position
		var dot: Vector2 = _world_to_pixel(pos.x, pos.z)
		draw_circle(dot, 4.0, COLOR_PLAYER)
		# 카메라 forward 방향을 미니맵 위에 표시 (heading)
		var fwd: Vector3 = -camera.global_transform.basis.z
		var fwd_xz: Vector2 = Vector2(fwd.x, fwd.z).normalized()
		if fwd_xz.length() > 0.01:
			# 8m 앞 위치를 같은 방식으로 픽셀 변환
			var ahead: Vector2 = _world_to_pixel(pos.x + fwd_xz.x * 8.0, pos.z + fwd_xz.y * 8.0)
			draw_line(dot, ahead, COLOR_PLAYER_HEADING, 1.5)

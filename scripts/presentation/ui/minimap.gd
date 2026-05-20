extends Control

## 도면 미니맵. floor_*.json을 직접 읽어 _draw()로 외벽/내벽/코어/grid를 그린다.
## 플레이어 위치는 매 프레임 갱신되는 빨간 점으로 표시.
##
## 토글: M 키 (기본 표시)

## site_type별 floor JSON 경로 템플릿. zero-pad 여부 다름 (v1 vs v2 데이터 명명 차이).
const FLOOR_JSON_TEMPLATES: Dictionary = {
	"parliament_village": "res://data/parliament_village/floor_%02d.json",
	"calpoly_b001":       "res://data/calpoly_b001/floor_%d.json",
}
const DEFAULT_SITE_TYPE: String = "parliament_village"
const TOGGLE_KEYCODE: int = KEY_M
## SPEC-ENV-004 (TBD): 다층 전환 단축키. KEY_1~KEY_5 → floor 1~5.
const FLOOR_KEYCODES: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]

## 미니맵 외곽 padding (m)
const BBOX_PADDING_M: float = 2.0

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

var _site_data: SiteData = null
var _bbox_x0_m: float = 0.0
var _bbox_y0_m: float = 0.0
var _bbox_x1_m: float = 0.0
var _bbox_y1_m: float = 0.0
## 시뮬 site origin = bbox 중심 (padding 미적용). m.
var _bbox_center_m: Vector2 = Vector2.ZERO
## 이 미니맵 윈도우가 표시하는 m 영역 → 픽셀 영역. 한 번 계산해 둠.
var _draw_rect: Rect2 = Rect2()
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	_sync_with_scenario()
	_load_floor_data()
	_compute_draw_rect()
	queue_redraw()
	set_process(true)
	if ScenarioManager:
		ScenarioManager.floor_changed.connect(_on_floor_changed)
		ScenarioManager.scenario_loaded.connect(_on_scenario_loaded)


func _process(_delta: float) -> void:
	# 플레이어 점이 매 프레임 갱신되어야 하므로 redraw.
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event
		if key_event.keycode == TOGGLE_KEYCODE:
			visible = not visible
			return
		var idx: int = FLOOR_KEYCODES.find(key_event.keycode)
		if idx >= 0 and ScenarioManager:
			ScenarioManager.change_floor(idx + 1)


## ScenarioManager의 시그널로 동기화
func _on_floor_changed(floor_n: int) -> void:
	floor_to_show = floor_n
	_load_floor_data()
	_compute_draw_rect()
	queue_redraw()


func _on_scenario_loaded(data: ScenarioData) -> void:
	floor_to_show = data.site_floor
	_load_floor_data()
	_compute_draw_rect()
	queue_redraw()


func _sync_with_scenario() -> void:
	if ScenarioManager and ScenarioManager.current_scenario:
		floor_to_show = ScenarioManager.current_scenario.site_floor


func _site_type() -> String:
	if ScenarioManager and ScenarioManager.current_scenario:
		return ScenarioManager.current_scenario.site_type
	return DEFAULT_SITE_TYPE


func _load_floor_data() -> void:
	var site_type: String = _site_type()
	var template: String = FLOOR_JSON_TEMPLATES.get(
		site_type, FLOOR_JSON_TEMPLATES[DEFAULT_SITE_TYPE]
	)
	var path: String = template % floor_to_show
	_site_data = SiteDataParser.parse_from_path(path)
	if _site_data == null:
		return
	var bb_min: Vector2 = _site_data.metadata.bbox_min
	var bb_max: Vector2 = _site_data.metadata.bbox_max
	_bbox_x0_m = bb_min.x - BBOX_PADDING_M
	_bbox_y0_m = bb_min.y - BBOX_PADDING_M
	_bbox_x1_m = bb_max.x + BBOX_PADDING_M
	_bbox_y1_m = bb_max.y + BBOX_PADDING_M
	_bbox_center_m = (bb_min + bb_max) * 0.5


func _compute_draw_rect() -> void:
	# 컨트롤 사이즈 안에 비율 유지하며 fit
	var avail: Vector2 = size
	var m_w: float = _bbox_x1_m - _bbox_x0_m
	var m_h: float = _bbox_y1_m - _bbox_y0_m
	if m_w <= 0.0 or m_h <= 0.0 or avail.x <= 0.0 or avail.y <= 0.0:
		_draw_rect = Rect2(Vector2.ZERO, avail)
		return
	var scale_x: float = avail.x / m_w
	var scale_y: float = avail.y / m_h
	var s: float = min(scale_x, scale_y)
	var draw_w: float = m_w * s
	var draw_h: float = m_h * s
	var offset: Vector2 = Vector2(
		(avail.x - draw_w) * 0.5,
		(avail.y - draw_h) * 0.5
	)
	_draw_rect = Rect2(offset, Vector2(draw_w, draw_h))


func _resized() -> void:
	_compute_draw_rect()
	queue_redraw()


## site 좌표 (m, 절대) → 미니맵 픽셀 좌표
func _m_to_pixel(mx: float, my: float) -> Vector2:
	var m_w: float = _bbox_x1_m - _bbox_x0_m
	var m_h: float = _bbox_y1_m - _bbox_y0_m
	if m_w <= 0.0 or m_h <= 0.0:
		return Vector2.ZERO
	var u: float = (mx - _bbox_x0_m) / m_w
	var v: float = (my - _bbox_y0_m) / m_h
	return _draw_rect.position + Vector2(u * _draw_rect.size.x, v * _draw_rect.size.y)


## Godot world (x, z) — site origin 기준 m → 미니맵 픽셀
func _world_to_pixel(world_x: float, world_z: float) -> Vector2:
	return _m_to_pixel(world_x + _bbox_center_m.x, world_z + _bbox_center_m.y)


func _draw() -> void:
	# 배경 + 테두리
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BORDER, false, 1.5)

	if _site_data == null:
		return

	# Grid lines (raw_extra.grid, pt 단위 → m 변환)
	var grid: Dictionary = _site_data.raw_extra.get("grid", {})
	var gx: Dictionary = grid.get("x", {})
	var gy: Dictionary = grid.get("y", {})
	var pt_to_m: float = _site_data.metadata.unit_scale_to_meter
	for key in gx.keys():
		var x_m: float = float(gx[key]) * pt_to_m
		var top: Vector2 = _m_to_pixel(x_m, _bbox_y0_m)
		var bot: Vector2 = _m_to_pixel(x_m, _bbox_y1_m)
		draw_line(top, bot, COLOR_GRID, 1.0)
		draw_string(_font, top + Vector2(-4, 12), str(key), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, COLOR_GRID_TEXT)
	for key in gy.keys():
		var y_m: float = float(gy[key]) * pt_to_m
		var lf: Vector2 = _m_to_pixel(_bbox_x0_m, y_m)
		var rt: Vector2 = _m_to_pixel(_bbox_x1_m, y_m)
		draw_line(lf, rt, COLOR_GRID, 1.0)
		draw_string(_font, lf + Vector2(2, 4), str(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GRID_TEXT)

	# Inner walls (thin)
	for w in _site_data.inner_walls:
		draw_line(
			_m_to_pixel(w.start.x, w.start.y),
			_m_to_pixel(w.end.x, w.end.y),
			COLOR_INNER_WALL, 1.0
		)

	# Outer walls (thick)
	for w in _site_data.outer_walls:
		draw_line(
			_m_to_pixel(w.start.x, w.start.y),
			_m_to_pixel(w.end.x, w.end.y),
			COLOR_OUTER_WALL, 2.0
		)

	# Cores (raw_extra, pt 단위 bbox)
	for raw in _site_data.raw_extra.get("cores", []):
		if not (raw is Dictionary):
			continue
		var core: Dictionary = raw
		var bbox: Array = core.get("bbox_pt", [])
		if bbox.size() != 4:
			continue
		var p0: Vector2 = _m_to_pixel(float(bbox[0]) * pt_to_m, float(bbox[1]) * pt_to_m)
		var p1: Vector2 = _m_to_pixel(float(bbox[2]) * pt_to_m, float(bbox[3]) * pt_to_m)
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

	# Floor 라벨 (좌상단). 1~5 키로 전환.
	var floor_label: String = "Floor %d  [1-5]" % floor_to_show
	draw_string(_font, Vector2(8, 18), floor_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.95, 0.55, 0.95))

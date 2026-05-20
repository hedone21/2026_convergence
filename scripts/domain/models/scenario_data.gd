class_name ScenarioData
extends Resource

## SPEC-SCN-001: 시나리오 설정 데이터 모델
## SPEC-SCN-002: 랜덤 배치 설정 포함
##
## 시나리오 JSON 파일에서 파싱된 데이터를 담는 Resource.
## ScenarioManager가 이 객체를 생성하여 시스템에 전달한다.

## 시나리오 고유 ID (예: "scenario_mvp_01")
@export var scenario_id: String = ""

## 현장 유형 키 (예: "building_frame")
@export var site_type: String = "building_frame"

## SPEC-ENV-004 (TBD): 다층 사이트의 표시 층 (1부터). 단층 사이트는 무시.
@export var site_floor: int = 1

## 시간 제한 (초)
@export var time_limit_seconds: int = 300

## SPEC-SCN-002: 랜덤 배치 모드 여부
## true이면 hazards 배열을 무시하고 random_config를 사용한다.
@export var random_placement: bool = false

## SPEC-SCN-002: 랜덤 시드 (0이면 시스템 시간 기반)
@export var random_seed: int = 0

## 고정 배치 위험 요소 목록 (random_placement=false일 때 사용)
@export var hazards: Array[HazardData] = []

## SPEC-SCN-002: 랜덤 배치 설정 (random_placement=true일 때 사용)
## 키: hazard_count(int), types(Array[String]), min_spacing(float), difficulty_range(Array[float])
@export var random_config: Dictionary = {}


## JSON Dictionary에서 ScenarioData를 생성한다.
static func from_dict(data: Dictionary) -> ScenarioData:
	var sd: ScenarioData = ScenarioData.new()
	sd.scenario_id = data.get("scenario_id", "")
	sd.site_type = data.get("site_type", "building_frame")
	sd.site_floor = int(data.get("site_floor", 1))
	sd.time_limit_seconds = int(data.get("time_limit_seconds", 300))
	sd.random_placement = data.get("random_placement", false)
	sd.random_seed = int(data.get("random_seed", 0))
	sd.random_config = data.get("random_config", {})

	# 고정 배치 위험 요소 파싱
	var hazards_arr: Array = data.get("hazards", [])
	for h_dict: Variant in hazards_arr:
		if h_dict is Dictionary:
			# JSON 스키마에서 "id" 키를 "hazard_id"로 매핑
			var hd: Dictionary = h_dict as Dictionary
			if hd.has("id") and not hd.has("hazard_id"):
				hd["hazard_id"] = hd["id"]
			# "params" 내부 파라미터를 HazardData 필드로 펼침
			if hd.has("params") and hd["params"] is Dictionary:
				var params: Dictionary = hd["params"]
				if params.has("length"):
					hd["crack_length"] = params["length"]
				if params.has("width"):
					hd["crack_width"] = params["width"]
				if params.has("branches"):
					hd["crack_branches"] = params["branches"]
			# "rotation" -> "rotation_degrees" 매핑
			if hd.has("rotation") and not hd.has("rotation_degrees"):
				hd["rotation_degrees"] = hd["rotation"]
			sd.hazards.append(HazardData.from_dict(hd))

	return sd


## ScenarioData를 Dictionary로 변환한다.
func to_dict() -> Dictionary:
	var hazards_arr: Array = []
	for h: HazardData in hazards:
		hazards_arr.append(h.to_dict())

	return {
		"scenario_id": scenario_id,
		"site_type": site_type,
		"site_floor": site_floor,
		"time_limit_seconds": time_limit_seconds,
		"random_placement": random_placement,
		"random_seed": random_seed,
		"random_config": random_config,
		"hazards": hazards_arr,
	}

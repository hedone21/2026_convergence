class_name ScenarioValidator
extends RefCounted

## SPEC-SCN-001: 시나리오 JSON 데이터의 스키마 검증 순수 로직
## SPEC-SCN-002: 랜덤 배치 설정 검증 포함
##
## ScenarioManager(Application)가 이 서비스에 검증을 위임한다.
## 순수 GDScript 클래스 (RefCounted): 씬 트리 없이 인스턴스화 가능.

## 허용되는 현장 유형 목록
## SPEC-ENV-003: parliament_village (Texas Woman's University South Hall 평면도 기반)
## SPEC-ENV-004 (TBD): calpoly_b001 (Cal Poly Building 001 DXF 도면 기반)
var VALID_SITE_TYPES: Array[String] = ["building_frame", "parliament_village", "calpoly_b001"]

## 허용되는 위험 요소 유형 목록
## SPEC-HAZ-003: 위험 요소 종류 확장 — 5종 추가 (spill/debris/unguarded_edge/exposed_rebar/wet_floor)
var VALID_HAZARD_TYPES: Array[String] = [
	"crack",
	"spill",
	"debris",
	"unguarded_edge",
	"exposed_rebar",
	"wet_floor",
]


## 시나리오 데이터를 검증한다.
## 에러 목록을 반환한다 (빈 배열이면 유효).
func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	# --- 필수 필드 존재 검증 ---
	if not data.has("scenario_id"):
		errors.append("필수 필드 누락: scenario_id")
	elif not data["scenario_id"] is String or (data["scenario_id"] as String).strip_edges().is_empty():
		errors.append("scenario_id가 비어있거나 문자열이 아닙니다")

	if not data.has("site_type"):
		errors.append("필수 필드 누락: site_type")
	elif not data["site_type"] is String:
		errors.append("site_type이 문자열이 아닙니다")
	elif not (data["site_type"] as String) in VALID_SITE_TYPES:
		errors.append("지원하지 않는 site_type: %s" % data["site_type"])

	# SPEC-ENV-004 (TBD): site_floor (optional, default 1)
	if data.has("site_floor"):
		if not (data["site_floor"] is int or data["site_floor"] is float):
			errors.append("site_floor가 정수가 아닙니다")
		elif int(data["site_floor"]) < 1 or int(data["site_floor"]) > 20:
			errors.append("site_floor는 1~20 범위여야 합니다: %s" % str(data["site_floor"]))

	if not data.has("time_limit_seconds"):
		errors.append("필수 필드 누락: time_limit_seconds")
	elif not (data["time_limit_seconds"] is int or data["time_limit_seconds"] is float):
		errors.append("time_limit_seconds가 숫자가 아닙니다")
	elif int(data["time_limit_seconds"]) <= 0:
		errors.append("time_limit_seconds는 양의 정수여야 합니다: %s" % str(data["time_limit_seconds"]))

	# --- 랜덤 배치 설정 검증 ---
	var is_random: bool = data.get("random_placement", false)

	if is_random:
		errors.append_array(_validate_random_config(data))
	else:
		errors.append_array(_validate_hazards_array(data))

	return errors


## SPEC-SCN-002: random_config 검증
func _validate_random_config(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	if not data.has("random_config"):
		errors.append("random_placement=true이지만 random_config가 없습니다")
		return errors

	var config: Variant = data["random_config"]
	if not config is Dictionary:
		errors.append("random_config가 Dictionary가 아닙니다")
		return errors

	var rc: Dictionary = config as Dictionary

	# hazard_count
	if not rc.has("hazard_count"):
		errors.append("random_config.hazard_count 누락")
	elif not (rc["hazard_count"] is int or rc["hazard_count"] is float):
		errors.append("random_config.hazard_count가 숫자가 아닙니다")
	elif int(rc["hazard_count"]) <= 0:
		errors.append("random_config.hazard_count는 양의 정수여야 합니다")

	# types
	if not rc.has("types"):
		errors.append("random_config.types 누락")
	elif not rc["types"] is Array:
		errors.append("random_config.types가 배열이 아닙니다")
	else:
		var types: Array = rc["types"]
		if types.is_empty():
			errors.append("random_config.types가 비어있습니다")
		for t: Variant in types:
			if t is String and not (t as String) in VALID_HAZARD_TYPES:
				errors.append("random_config.types에 지원하지 않는 유형: %s" % t)

	# min_spacing
	if rc.has("min_spacing"):
		if not (rc["min_spacing"] is int or rc["min_spacing"] is float):
			errors.append("random_config.min_spacing이 숫자가 아닙니다")
		elif float(rc["min_spacing"]) < 0.0:
			errors.append("random_config.min_spacing은 0 이상이어야 합니다")

	# difficulty_range
	if rc.has("difficulty_range"):
		if not rc["difficulty_range"] is Array:
			errors.append("random_config.difficulty_range가 배열이 아닙니다")
		else:
			var dr: Array = rc["difficulty_range"]
			if dr.size() != 2:
				errors.append("random_config.difficulty_range는 [min, max] 형식이어야 합니다")
			else:
				var dr_min: float = float(dr[0])
				var dr_max: float = float(dr[1])
				if dr_min < 0.0 or dr_min > 1.0:
					errors.append("random_config.difficulty_range[0]은 0.0~1.0 범위여야 합니다")
				if dr_max < 0.0 or dr_max > 1.0:
					errors.append("random_config.difficulty_range[1]은 0.0~1.0 범위여야 합니다")
				if dr_min > dr_max:
					errors.append("random_config.difficulty_range: min(%s) > max(%s)" % [dr_min, dr_max])

	return errors


## 고정 배치 hazards 배열 검증
func _validate_hazards_array(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	if not data.has("hazards"):
		# 고정 배치 모드에서 hazards가 없으면 경고 (에러는 아님)
		return errors

	if not data["hazards"] is Array:
		errors.append("hazards가 배열이 아닙니다")
		return errors

	var hazards_arr: Array = data["hazards"]
	for i: int in range(hazards_arr.size()):
		var h: Variant = hazards_arr[i]
		if not h is Dictionary:
			errors.append("hazards[%d]가 Dictionary가 아닙니다" % i)
			continue

		var hd: Dictionary = h as Dictionary
		var prefix: String = "hazards[%d]" % i

		# id 필수
		if not hd.has("id") and not hd.has("hazard_id"):
			errors.append("%s: id 또는 hazard_id 누락" % prefix)

		# type 필수
		if not hd.has("type"):
			errors.append("%s: type 누락" % prefix)
		elif hd["type"] is String and not (hd["type"] as String) in VALID_HAZARD_TYPES:
			errors.append("%s: 지원하지 않는 type: %s" % [prefix, hd["type"]])

		# difficulty 범위
		if hd.has("difficulty"):
			var diff: float = float(hd["difficulty"])
			if diff < 0.0 or diff > 1.0:
				errors.append("%s: difficulty(%s)는 0.0~1.0 범위여야 합니다" % [prefix, diff])

		# position
		if hd.has("position"):
			if not hd["position"] is Array:
				errors.append("%s: position이 배열이 아닙니다" % prefix)
			elif (hd["position"] as Array).size() < 3:
				errors.append("%s: position은 [x, y, z] 형식이어야 합니다" % prefix)

	return errors

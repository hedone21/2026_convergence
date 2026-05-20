class_name TimeOfDay
extends RefCounted

## SPEC-GFX-004 (TBD): 시간대 시스템
##
## DirectionalLight3D의 angle/color/energy를 시간대 프리셋으로 동적 설정.
## 프리셋: morning / noon / dusk.
##
## 사용:
##   TimeOfDay.apply(light, "morning")
## 또는 시나리오 JSON의 "time_of_day" 필드를 ScenarioManager가 읽어 적용.

const PRESETS: Dictionary = {
	"morning": {
		"rotation_deg": Vector3(-25.0, -40.0, 0.0),
		"color": Color(1.0, 0.85, 0.65),
		"energy": 1.5,
		"indirect_energy": 1.0,
	},
	"noon": {
		"rotation_deg": Vector3(-80.0, -20.0, 0.0),
		"color": Color(1.0, 0.98, 0.95),
		"energy": 2.5,
		"indirect_energy": 1.4,
	},
	"dusk": {
		"rotation_deg": Vector3(-15.0, 130.0, 0.0),
		"color": Color(1.0, 0.55, 0.35),
		"energy": 1.3,
		"indirect_energy": 0.7,
	},
}

const DEFAULT_PRESET: String = "noon"


## SPEC-GFX-004: 시간대 프리셋을 DirectionalLight3D에 적용.
## 반환: 성공 시 true.
static func apply(light: DirectionalLight3D, preset_name: String) -> bool:
	if light == null:
		return false
	var preset: Dictionary = PRESETS.get(preset_name, PRESETS.get(DEFAULT_PRESET))
	if preset.is_empty():
		return false
	var rot_deg: Vector3 = preset["rotation_deg"]
	light.rotation_degrees = rot_deg
	light.light_color = preset["color"]
	light.light_energy = preset["energy"]
	light.light_indirect_energy = preset["indirect_energy"]
	return true


## 사용 가능한 프리셋 목록.
static func available_presets() -> Array[String]:
	var keys: Array[String] = []
	for k: String in PRESETS.keys():
		keys.append(k)
	return keys

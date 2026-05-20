extends SceneTree

## 스모크: TimeOfDay 3 프리셋 (morning/noon/dusk)을 DirectionalLight3D에 적용 검증.
## SPEC-GFX-004 (TBD) — 시간대 시스템.


func _init() -> void:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	root.add_child(light)

	var presets: Array = ["morning", "noon", "dusk"]
	var failures: Array = []

	for p: String in presets:
		var ok: bool = TimeOfDay.apply(light, p)
		if not ok:
			failures.append("apply(%s) 실패" % p)
			continue
		print("[smoke] %s: rot=%s color=%s energy=%.1f" % [
			p, str(light.rotation_degrees), str(light.light_color), light.light_energy,
		])

	# 3 프리셋이 서로 다른 값인지 검증
	var noon_color: Color = TimeOfDay.PRESETS["noon"]["color"]
	var dusk_color: Color = TimeOfDay.PRESETS["dusk"]["color"]
	if noon_color == dusk_color:
		failures.append("noon/dusk 색이 동일")

	if failures.is_empty():
		print("[smoke] result: PASS")
		quit(0)
	else:
		for msg: String in failures:
			print("[smoke] FAIL: %s" % msg)
		print("[smoke] result: FAIL")
		quit(1)

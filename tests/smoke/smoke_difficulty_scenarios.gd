extends SceneTree

## 스모크: 난이도 3 시나리오 (calpoly_b001_easy/medium/hard) 유효성 검증.
## ScenarioValidator로 JSON 무결성 확인.
## SPEC-HAZ-002 / SPEC-SCN-001 — 난이도 단계.


const PATHS: Array = [
	"res://resources/scenarios/calpoly_b001_easy.json",
	"res://resources/scenarios/calpoly_b001_medium.json",
	"res://resources/scenarios/calpoly_b001_hard.json",
]


func _init() -> void:
	var v: ScenarioValidator = ScenarioValidator.new()
	var failures: Array = []
	var hazard_counts: Array = []

	for path: String in PATHS:
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f == null:
			failures.append("로드 실패: %s" % path)
			continue
		var text: String = f.get_as_text()
		f.close()
		var data: Variant = JSON.parse_string(text)
		if not (data is Dictionary):
			failures.append("JSON 파싱 실패: %s" % path)
			continue
		var errors: Array = v.validate(data)
		var sid: String = str(data.get("scenario_id", ""))
		var cnt: int = int(data.get("random_config", {}).get("hazard_count", 0))
		hazard_counts.append(cnt)
		if errors.is_empty():
			print("[smoke] %s OK (hazard_count=%d)" % [sid, cnt])
		else:
			failures.append("%s: %s" % [sid, str(errors)])

	# 난이도 차등 검증: easy < medium < hard (hazard 수)
	if hazard_counts.size() == 3:
		if not (hazard_counts[0] < hazard_counts[1] and hazard_counts[1] < hazard_counts[2]):
			failures.append("난이도 차등 실패: %s" % str(hazard_counts))
		else:
			print("[smoke] 난이도 차등 OK: %s" % str(hazard_counts))

	if failures.is_empty():
		print("[smoke] result: PASS")
		quit(0)
	else:
		for msg: String in failures:
			print("[smoke] FAIL: %s" % msg)
		print("[smoke] result: FAIL")
		quit(1)

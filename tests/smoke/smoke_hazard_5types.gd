extends SceneTree

## 스모크: 5종 hazard (spill/debris/unguarded_edge/exposed_rebar/wet_floor)
## .tscn 인스턴스화 검증 + ScenarioValidator.VALID_HAZARD_TYPES 등록 확인.
## SPEC-HAZ-003 — 위험 요소 종류 확장.


const HAZARD_SCENES: Array = [
	["spill", "res://scenes/hazards/spill_hazard.tscn"],
	["debris", "res://scenes/hazards/debris_hazard.tscn"],
	["unguarded_edge", "res://scenes/hazards/unguarded_edge_hazard.tscn"],
	["exposed_rebar", "res://scenes/hazards/exposed_rebar_hazard.tscn"],
	["wet_floor", "res://scenes/hazards/wet_floor_hazard.tscn"],
]


func _init() -> void:
	var failures: Array = []

	# 5개 .tscn 인스턴스화 + hazard_type 검증
	for pair: Array in HAZARD_SCENES:
		var kind: String = pair[0]
		var path: String = pair[1]
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			failures.append("%s: 로드 실패 (%s)" % [kind, path])
			continue
		var node: Node = packed.instantiate()
		root.add_child(node)
		await process_frame
		if not (node is SimpleHazard):
			failures.append("%s: SimpleHazard 인스턴스 아님 (%s)" % [kind, node.get_class()])
			node.queue_free()
			continue
		var h: SimpleHazard = node as SimpleHazard
		if h.hazard_kind != kind:
			failures.append("%s: hazard_kind 불일치 (%s)" % [kind, h.hazard_kind])
		if h.hazard_type != kind:
			failures.append("%s: hazard_type 불일치 (%s)" % [kind, h.hazard_type])
		print("[smoke] %s OK — children=%d" % [kind, h.get_child_count()])

	# ScenarioValidator VALID_HAZARD_TYPES 검증
	var v: ScenarioValidator = ScenarioValidator.new()
	for pair: Array in HAZARD_SCENES:
		var kind: String = pair[0]
		if not (kind in v.VALID_HAZARD_TYPES):
			failures.append("VALID_HAZARD_TYPES 미등록: %s" % kind)

	if failures.is_empty():
		print("[smoke] result: PASS — 5종 모두 OK")
		quit(0)
	else:
		for msg: String in failures:
			print("[smoke] FAIL: %s" % msg)
		print("[smoke] result: FAIL")
		quit(1)

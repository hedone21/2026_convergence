extends SceneTree

## 스모크: 5종 prop .glb 로드 + 인스턴스화 검증.
## SPEC-GFX-003 (TBD) — 정적 prop 배치.


const PROP_PATHS: Array[String] = [
	"res://assets/models/props/worker.glb",
	"res://assets/models/props/excavator.glb",
	"res://assets/models/props/scaffold.glb",
	"res://assets/models/props/material_pile.glb",
	"res://assets/models/props/sign.glb",
]


func _init() -> void:
	var failures: Array = []
	for path: String in PROP_PATHS:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			failures.append("로드 실패: %s" % path)
			continue
		var node: Node = packed.instantiate()
		if node == null:
			failures.append("인스턴스화 실패: %s" % path)
			continue
		root.add_child(node)
		print("[smoke] %s OK (children=%d)" % [path.get_file(), node.get_child_count()])

	if failures.is_empty():
		print("[smoke] result: PASS")
		quit(0)
	else:
		for msg: String in failures:
			print("[smoke] FAIL: %s" % msg)
		print("[smoke] result: FAIL")
		quit(1)

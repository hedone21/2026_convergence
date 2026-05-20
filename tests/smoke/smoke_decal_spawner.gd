extends SceneTree

## 스모크: DecalSpawner가 bounds 안에 N≥10 데칼을 spawn하는지 검증.
## SPEC-GFX-002 — Decal 시스템.


func _init() -> void:
	var spawner: DecalSpawner = DecalSpawner.new()
	root.add_child(spawner)

	var bounds: AABB = AABB(Vector3(-12, 0, -12), Vector3(24, 0.1, 24))
	var requested: int = 12
	var spawned: int = spawner.spawn_decals(bounds, requested, 42)

	await process_frame

	var child_count: int = spawner.get_child_count()
	print("[smoke] requested=%d spawned=%d children=%d" % [requested, spawned, child_count])

	var ok: bool = (spawned >= 10 and child_count >= 10)
	print("[smoke] result: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)

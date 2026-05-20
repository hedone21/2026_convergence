extends SceneTree

## 스모크 테스트: ResultScreen 부팅 → session_ended 흐름 → 결과 표시.
## SPEC-SES-003 (보강) — 세션 흐름 + 결과 화면.
##
## main.tscn 의존 회피 (--script 모드 Autoload 미등록 우회).
## ResultScreen 단독 부팅 + _on_session_ended 시뮬레이션.


func _init() -> void:
	var packed: PackedScene = load("res://scenes/ui/result_screen.tscn") as PackedScene
	if packed == null:
		print("[smoke] result: FAIL — result_screen.tscn 로드 실패")
		quit(1)
		return

	var rs: Control = packed.instantiate() as Control
	root.add_child(rs)
	await process_frame
	await process_frame

	# 초기 visible=false 확인
	if rs.visible:
		print("[smoke] result: FAIL — 초기 visible=true (false 예상)")
		quit(1)
		return

	# 자식 노드 검증 (Panel/VBoxContainer/SummaryLabel/DetailLabel/RestartButton)
	var summary: Node = rs.get_node_or_null("Panel/VBoxContainer/SummaryLabel")
	var detail: Node = rs.get_node_or_null("Panel/VBoxContainer/DetailLabel")
	var btn: Node = rs.get_node_or_null("Panel/VBoxContainer/RestartButton")
	if summary == null or detail == null or btn == null:
		print("[smoke] result: FAIL — 자식 노드 누락 (summary=%s detail=%s btn=%s)" % [
			str(summary != null), str(detail != null), str(btn != null),
		])
		quit(1)
		return

	# 세션 종료 시뮬 — ResultScreen._on_session_ended 직접 호출
	rs._on_session_ended("forced_smoke")
	await process_frame

	if not rs.visible:
		print("[smoke] result: FAIL — session_ended 후에도 invisible")
		quit(1)
		return

	print("[smoke] visible after session_ended=%s" % str(rs.visible))
	print("[smoke] result: PASS")
	quit(0)

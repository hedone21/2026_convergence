class_name ResultScreen
extends Control

## SPEC-SES-003 (보강): 세션 결과 화면
##
## SessionManager.session_ended 시그널을 구독하여 종료 시 표시.
## SessionState 식별자 참조 회피 (--script 모드 호환).

var summary_label: Label = null
var detail_label: Label = null
var restart_button: Button = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS

	summary_label = get_node_or_null("Panel/VBoxContainer/SummaryLabel")
	detail_label = get_node_or_null("Panel/VBoxContainer/DetailLabel")
	restart_button = get_node_or_null("Panel/VBoxContainer/RestartButton")

	var sm: Node = get_node_or_null("/root/SessionManager")
	if sm != null and sm.has_signal("session_ended"):
		sm.session_ended.connect(_on_session_ended)
		sm.session_started.connect(_on_session_started)

	if restart_button != null:
		restart_button.pressed.connect(_on_restart_pressed)


func _on_session_started() -> void:
	visible = false


func _on_session_ended(_reason: String) -> void:
	_refresh()
	visible = true


func _refresh() -> void:
	var sm: Node = get_node_or_null("/root/SessionManager")
	if sm == null:
		return
	var sd: SessionData = sm.session_data
	if sd == null:
		return

	var em: Node = get_node_or_null("/root/EvaluationManager")
	var avg_reaction: float = em.get_avg_reaction_time_ms() if em != null else 0.0

	if summary_label != null:
		summary_label.text = "세션 종료 — %s" % sd.end_reason
	if detail_label != null:
		detail_label.text = (
			"발견율: %.1f%%\n경과 시간: %.1fs\n평균 반응 시간: %.0fms\n세션 ID: %s"
			% [
				sd.get_discovery_rate_percent(),
				sd.get_elapsed_seconds(),
				avg_reaction,
				sd.session_id,
			]
		)


func _on_restart_pressed() -> void:
	visible = false
	var sm: Node = get_node_or_null("/root/SessionManager")
	if sm != null and sm.has_method("proceed_to_next"):
		sm.proceed_to_next(true)

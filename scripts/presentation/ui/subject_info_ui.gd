class_name SubjectInfoUI
extends Control

## SPEC-SES-001: 피험자 정보 입력 화면
## 시뮬레이션 시작 전 피험자 ID와 경력을 입력받고 SubjectData를 생성해 시그널로 전달한다.
## VR 환경에서는 SubViewport + MeshInstance3D를 통해 3D 공간에 배치되며,
## 데스크톱 환경에서는 CanvasLayer 위에 직접 표시된다.

## SPEC-SES-001: 제출 시 SubjectData를 포함한 시그널 발행
signal info_submitted(subject_data: SubjectData)

@onready var id_input: LineEdit = $PanelContainer/VBoxContainer/IDInput
@onready var experience_spin: SpinBox = $PanelContainer/VBoxContainer/ExperienceInput
@onready var submit_button: Button = $PanelContainer/VBoxContainer/SubmitButton
@onready var warning_label: Label = $PanelContainer/VBoxContainer/WarningLabel


func _ready() -> void:
	## SPEC-SES-001: ID 필드 변경 시 제출 버튼 활성화 여부를 실시간으로 갱신한다
	id_input.text_changed.connect(_on_id_changed)
	submit_button.pressed.connect(_on_submit_pressed)

	## 초기 상태: ID가 비어있으므로 제출 버튼 비활성화
	_update_submit_state()
	warning_label.visible = false


## SPEC-SES-001: ID 입력값이 변경될 때마다 제출 버튼 상태를 갱신한다
func _on_id_changed(_new_text: String) -> void:
	_update_submit_state()


## SPEC-SES-001: ID가 비어있으면 제출 버튼을 비활성화한다
func _update_submit_state() -> void:
	var id_empty: bool = id_input.text.strip_edges().is_empty()
	submit_button.disabled = id_empty
	warning_label.visible = id_empty and id_input.text.length() > 0


## SPEC-SES-001: 제출 버튼이 눌리면 SubjectData를 생성해 시그널로 전달한다
func _on_submit_pressed() -> void:
	var trimmed_id: String = id_input.text.strip_edges()

	## ID가 비어있으면 제출하지 않는다 (버튼 비활성화로 이미 방어하지만 이중 방어)
	if trimmed_id.is_empty():
		warning_label.visible = true
		return

	var subject := SubjectData.new()
	subject.subject_id = trimmed_id
	subject.experience_years = int(experience_spin.value)
	subject.experience_category = _get_experience_category(subject.experience_years)

	info_submitted.emit(subject)


## 경력 연수를 카테고리 문자열로 변환한다 (로그 및 분석 편의용)
func _get_experience_category(years: int) -> String:
	if years == 0:
		return "신입"
	elif years <= 2:
		return "초급"
	elif years <= 5:
		return "중급"
	elif years <= 10:
		return "고급"
	else:
		return "전문가"

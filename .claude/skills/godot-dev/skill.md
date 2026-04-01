---
name: godot-dev
description: "Godot 4 VR 프로젝트의 단순/반복 개발 작업을 수행하는 스킬. Dev 에이전트가 UI, 환경 씬, 설정 파일, 유틸리티를 구현할 때 사용한다."
---

# Godot Dev — 일반 모듈 개발

Godot 4 + GDScript로 VR 프로젝트의 단순한 모듈을 구현한다.

## 구현 절차

### Step 1: Spec 및 설계 문서 확인
- `docs/specs.md`에서 담당 Spec ID의 성공/실패 조건을 확인한다
- `docs/architecture.md`에서 담당 모듈의 위치와 구조 파악
- Senior Dev의 인터페이스 계약 확인 (어떤 시그널을 연결할지, 어떤 베이스 클래스를 상속할지)
- 구현 코드에 관련 Spec ID를 주석으로 명시한다 (예: `## SPEC-UI-001`)

### Step 2: 구현

#### UI 구현 패턴
```gdscript
class_name SubjectInfoUI
extends Control

signal info_submitted(subject_data: Dictionary)

@onready var id_input: LineEdit = $VBoxContainer/IDInput
@onready var career_input: SpinBox = $VBoxContainer/CareerInput
@onready var submit_btn: Button = $VBoxContainer/SubmitButton

func _ready() -> void:
    submit_btn.pressed.connect(_on_submit)

func _on_submit() -> void:
    var data := {
        "subject_id": id_input.text,
        "career_years": int(career_input.value)
    }
    info_submitted.emit(data)
```

#### UI 씬 (.tscn) 작성
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/subject_info_ui.gd" id="1"]

[node name="SubjectInfoUI" type="Control"]
script = ExtResource("1")
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="VBoxContainer" type="VBoxContainer" parent="."]
[node name="IDLabel" type="Label" parent="VBoxContainer"]
text = "피험자 ID"
[node name="IDInput" type="LineEdit" parent="VBoxContainer"]
[node name="CareerLabel" type="Label" parent="VBoxContainer"]
text = "경력 (년)"
[node name="CareerInput" type="SpinBox" parent="VBoxContainer"]
[node name="SubmitButton" type="Button" parent="VBoxContainer"]
text = "시작"
```

#### 3D 환경 구성 패턴
건물 골조 현장의 기본 구조물을 CSG 노드로 구성:
```gdscript
# 기둥, 보, 슬래브 등을 CSGBox3D로 절차적 생성
func _create_column(pos: Vector3, height: float) -> CSGBox3D:
    var column := CSGBox3D.new()
    column.size = Vector3(0.4, height, 0.4)
    column.position = pos + Vector3(0, height / 2, 0)
    return column
```

#### 위험 요소 씬 (BaseHazard 상속)
Senior Dev가 정의한 `BaseHazard`를 상속:
```gdscript
class_name CrackHazard
extends BaseHazard

@export var crack_width: float = 0.01
@export var crack_length: float = 0.5

func _ready() -> void:
    hazard_type = "crack"
    # 크랙 비주얼 메시 설정
```

#### JSON 설정 파일 작성
```json
{
  "scenario_id": "mvp_test_01",
  "time_limit_seconds": 300,
  "difficulty": "medium",
  "hazards": [
    {
      "type": "crack",
      "position": [2.0, 1.5, -3.0],
      "rotation": [0, 0, 45],
      "severity": 0.7,
      "params": { "width": 0.02, "length": 0.8 }
    }
  ]
}
```

### Step 3: 구현 리포트 작성
`_workspace/03_dev_report.md`에 기록:
- 구현된 파일 목록
- Senior Dev의 인터페이스 준수 여부
- 미구현 항목 (있다면)

## 코딩 규칙
- 클래스명: PascalCase
- 파일명: snake_case
- Senior Dev의 베이스 클래스를 상속하여 구현한다
- 불필요한 추상화를 만들지 않는다
- 주석은 "왜"를 설명할 때만 작성한다

---
name: godot-core-dev
description: "Godot 4 VR 프로젝트의 핵심/복잡한 모듈을 구현하는 스킬. Senior Dev가 OpenXR 초기화, 시나리오 관리, 데이터 로깅, 위험 요소 시스템 등 코어 기능을 개발할 때 사용한다."
---

# Godot Core Dev — 핵심 모듈 개발

Godot 4 + GDScript + OpenXR 기반으로 VR 프로젝트의 핵심 시스템을 구현한다.

## 구현 절차

### Step 1: Spec 및 설계 문서 확인
1. `docs/specs.md`에서 담당 Spec ID의 성공/실패 조건을 확인한다
2. `docs/architecture.md`에서 담당 모듈의 인터페이스, 의존성, 데이터 모델을 파악한다
3. 추적성 매트릭스에서 이 모듈이 커버하는 Spec ID 목록을 확인한다

### Step 2: 구현

#### Spec ID 추적 주석
모든 클래스/메서드에 관련 Spec ID를 주석으로 명시한다:
```gdscript
## SPEC-HAZ-001: 위험 요소 등록 및 관리
```

#### GDScript 4.x 규칙
```gdscript
class_name HazardManager
extends Node

## SPEC-HAZ-001: 위험 요소를 관리하는 매니저. 등록, 탐지, 마킹을 처리한다.

signal hazard_detected(hazard: BaseHazard)
signal false_positive(position: Vector3)

@export var detection_range: float = 2.0

var _hazards: Array[BaseHazard] = []
var _discovered_count: int = 0

func register_hazard(hazard: BaseHazard) -> void:
    _hazards.append(hazard)

func attempt_mark(ray_origin: Vector3, ray_dir: Vector3) -> void:
    var result := _check_hazard_at(ray_origin, ray_dir)
    if result:
        result.discover()
        _discovered_count += 1
        hazard_detected.emit(result)
    else:
        false_positive.emit(ray_origin)
```

#### 타입 힌트
- 함수 파라미터와 리턴 타입에 타입 힌트를 명시한다
- 변수 선언 시 `:=` (타입 추론) 또는 `: Type` (명시적)을 사용한다
- `Array[Type]`, `Dictionary` 등 컬렉션 타입도 명시한다

#### 씬 파일 (.tscn) 작성
Claude Code에서 직접 작성 가능한 텍스트 형식:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/core/hazard_manager.gd" id="1"]

[node name="HazardManager" type="Node"]
script = ExtResource("1")
detection_range = 2.0
```

#### OpenXR 초기화 패턴
```gdscript
func _ready() -> void:
    var xr_interface := XRServer.find_interface("OpenXR")
    if xr_interface and xr_interface.initialize():
        get_viewport().use_xr = true
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
```

#### Autoload 패턴
글로벌 매니저는 Autoload로 등록한다. `project.godot`에:
```
[autoload]
GameManager="*res://scripts/core/game_manager.gd"
DataLogger="*res://scripts/data/data_logger.gd"
```

### Step 3: 시그널 연결
느슨한 결합을 위해 시그널 기반 통신:
```gdscript
# 코드에서 연결
SessionManager.session_started.connect(_on_session_started)

# 또는 씬에서 연결 (tscn에 connection 포함)
[connection signal="session_started" from="SessionManager" to="." method="_on_session_started"]
```

### Step 4: 데이터 로깅 구현
이벤트 기반 로깅. 모든 이벤트에 타임스탬프 포함:
```gdscript
func log_event(event_type: String, data: Dictionary = {}) -> void:
    var entry := {
        "timestamp": Time.get_unix_time_from_system(),
        "event": event_type,
        "data": data
    }
    _log_buffer.append(entry)
```

### Step 5: 구현 리포트 작성
`_workspace/03_senior_dev_report.md`에 기록:
- 구현된 파일 목록
- 공개 인터페이스 (시그널, 메서드 시그니처)
- 설계 변경 사항 (있다면)
- 알려진 제한사항
- Dev에게 전달할 인터페이스 계약

## 핵심 모듈별 가이드

### VR 리그
- XROrigin3D → XRCamera3D + XRController3D (Left/Right)
- 조이스틱 이동: `XRController3D`의 `Vector2` 입력 → 캐릭터 이동
- 마킹 버튼: 트리거 버튼 → `mark_requested` 시그널

### 시나리오 관리
- JSON 파일 파싱: `JSON.parse_string()` 사용
- 위험 요소 동적 생성: `PackedScene.instantiate()` + 위치/속성 설정
- 랜덤 생성: 사전 정의된 스폰 포인트에서 무작위 선택 + 속성 변동

### 데이터 로거
- 버퍼 기반 쓰기 — 매 이벤트마다 파일 I/O를 하지 않는다
- 세션 종료 시 일괄 저장 (`FileAccess.open()`)
- CSV와 JSON 양 포맷 지원

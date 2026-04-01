---
name: godot-test
description: "Spec ID와 1:1 매칭되는 자동화 테스트를 작성하고 실행하는 스킬. Tester가 GUT 프레임워크로 유닛/통합 테스트를 작성하고, 스펙의 성공/실패 조건을 검증할 때 사용한다."
---

# Godot Test — Spec ID 기반 자동화 테스트

Spec ID와 1:1 매칭되는 테스트를 GUT 프레임워크로 작성하고, 스펙의 성공/실패 조건을 자동 검증한다.

## 테스트 절차

### Step 0: 스모크 테스트 (최우선 — 반드시 먼저 실행)

유닛 테스트가 전부 통과해도 앱이 실행되지 않으면 의미가 없다. 모든 테스트의 전제 조건으로 스모크 테스트를 먼저 수행한다.

**Why**: 컴포넌트 단위로는 정상이지만 조립(wiring)이 누락되면 앱이 동작하지 않는다. 유닛 테스트는 "이 메서드가 동작하는가?"를 검증하지만, "누가 이 메서드를 호출하는가?"는 검증하지 못한다. 스모크 테스트만이 이 간극을 잡을 수 있다.

```bash
# 1. 프로젝트 로드 검증
godot --headless --path {project} --quit 2>&1

# 2. 데스크톱 실행 + 핵심 흐름 로그 검증
timeout 15 godot --path {project} -- --desktop 2>&1
```

**필수 확인 로그 (이 중 하나라도 없으면 FAIL):**
- `[GameManager] Game ready.` — 앱 초기화 완료
- `[SessionManager] Initialized.` — 세션 관리자 준비
- `State: INITIALIZING -> SUBJECT_INPUT` — 세션 흐름 시작
- Site/환경 로드 로그 — 화면에 뭔가 보이는가?

**스모크 테스트 FAIL 시**: GUT 유닛 테스트를 진행하지 않는다. 먼저 부트스트랩 문제를 해결한다.

### Step 0.5: 부트스트랩 통합 테스트

Autoload 초기화 체인, 시그널 연결 완성, 첫 화면 로드를 검증한다.

**검증 항목:**
- Autoload 초기화 순서가 올바른가? (project.godot의 등록 순서)
- 시그널 emit 시점에 수신자가 이미 connect 되어 있는가?
- GameManager → Rig 부착 → SessionManager → 시나리오 로드 → 환경 로드 → UI 표시 체인이 완성되는가?
- `call_deferred()`가 필요한 타이밍 문제가 없는가?

**GUT 통합 테스트 예시:**
```gdscript
# tests/integration/test_bootstrap.gd
extends GutTest

## 앱 시작 후 SessionManager가 SUBJECT_INPUT 상태에 도달하는가?
func test_bootstrap_reaches_subject_input() -> void:
    # SessionManager Autoload가 존재하는가?
    var sm = get_node_or_null("/root/SessionManager")
    assert_not_null(sm, "SessionManager Autoload 존재")
    
    # 상태가 INITIALIZING을 지나 SUBJECT_INPUT에 도달했는가?
    # (deferred 호출 때문에 한 프레임 대기)
    await get_tree().process_frame
    await get_tree().process_frame
    assert_ne(sm.current_state, sm.SessionState.INITIALIZING, 
              "INITIALIZING을 벗어남")
```

### Step 1: Spec 기반 테스트 매핑
`docs/specs.md`에서 모든 Spec ID를 추출하고 테스트 매핑 테이블을 생성한다:

```markdown
| Test ID | Spec ID | 성공 조건 (assertion) | 유형 | 자동화 |
|---------|---------|---------------------|------|--------|
| TEST-VR-001 | SPEC-VR-001 | xr_interface.is_initialized() == true | Unit | Yes |
| TEST-VR-001-F | SPEC-VR-001 | 실패 시 에러 시그널 emit | Unit | Yes |
| TEST-VR-001-E | SPEC-VR-001 | 미지원 기기에서 폴백 동작 | Unit | Yes |
```

**스펙 → 테스트 변환 규칙:**
- 성공 조건 → `TEST-{Spec ID}`: 정상 경로 테스트
- 실패 조건 → `TEST-{Spec ID}-F`: 실패 경로 테스트
- 예외 처리 → `TEST-{Spec ID}-E`: 예외 경로 테스트
- 대안 동작 → `TEST-{Spec ID}-A`: 폴백 테스트 (해당 시)

### Step 2: GUT 테스트 스크립트 작성

#### 유닛 테스트 패턴
```gdscript
# tests/unit/test_spec_haz_001.gd
extends GutTest

# ======================================
# SPEC-HAZ-001: 위험 요소 등록 및 관리
# ======================================

## TEST-HAZ-001: 위험 요소 정상 등록
func test_register_hazard() -> void:
    # Arrange
    var manager := HazardManager.new()
    var crack := CrackHazard.new()
    crack.hazard_type = "crack"
    crack.severity = 0.8

    # Act
    manager.register_hazard(crack)

    # Assert (← 스펙 성공 조건)
    assert_eq(manager.get_hazard_count(), 1)
    assert_has(manager.get_hazards(), crack)

## TEST-HAZ-001-F: null 위험 요소 등록 시 무시
func test_register_null_hazard() -> void:
    var manager := HazardManager.new()
    manager.register_hazard(null)
    assert_eq(manager.get_hazard_count(), 0, "null은 등록되지 않아야 함")
```

#### 통합 테스트 패턴
```gdscript
# tests/integration/test_spec_dat_001.gd
extends GutTest

# ======================================
# SPEC-DAT-001: 세션 데이터 로깅
# ======================================

## TEST-DAT-001: 이벤트 로깅 및 파일 저장
func test_event_logging_and_save() -> void:
    # Arrange
    var logger := DataLogger.new()
    add_child(logger)
    var session_data := {"subject_id": "test_001", "time_limit": 300}

    # Act
    logger.log_event("session_start", session_data)
    logger.log_event("hazard_detected", {"hazard_id": "crack_01", "time": 45.2})
    var save_path := logger.save_to_file("user://test_log.json")

    # Assert (← 스펙 성공 조건)
    assert_true(FileAccess.file_exists(save_path), "로그 파일 생성됨")
    var content := FileAccess.get_file_as_string(save_path)
    var data := JSON.parse_string(content)
    assert_eq(data.size(), 2, "2개 이벤트 기록됨")
    assert_has_key(data[0], "timestamp", "타임스탬프 포함")

## TEST-DAT-001-F: 잘못된 경로에 저장 시 에러 처리
func test_save_invalid_path() -> void:
    var logger := DataLogger.new()
    add_child(logger)
    watch_signals(logger)

    logger.save_to_file("/invalid/path/log.json")
    assert_signal_emitted(logger, "save_failed")
```

#### 파일명 컨벤션
```
tests/
├── unit/
│   ├── test_spec_vr_001.gd      # SPEC-VR-001 유닛 테스트
│   ├── test_spec_haz_001.gd     # SPEC-HAZ-001 유닛 테스트
│   └── test_spec_dat_001.gd     # SPEC-DAT-001 유닛 테스트
└── integration/
    ├── test_spec_ses_001.gd     # SPEC-SES-001 통합 테스트
    └── test_spec_scn_001.gd     # SPEC-SCN-001 통합 테스트
```

### Step 3: 통합 정합성 검증

코드 경계면을 교차 비교한다 (양쪽 동시 읽기):

```gdscript
# tests/integration/test_signal_coherence.gd
extends GutTest

## 시그널 정합성: hazard_detected 시그널 파라미터 일치
func test_hazard_detected_signal_params() -> void:
    var controller := HazardController.new()
    var logger := DataLogger.new()
    add_child(controller)
    add_child(logger)

    # 시그널 연결
    controller.hazard_detected.connect(logger._on_hazard_detected)

    # 트리거
    var hazard := CrackHazard.new()
    controller.register_hazard(hazard)
    controller.attempt_mark(Vector3.ZERO, Vector3.FORWARD)

    # 검증: 로거가 데이터를 받았는지
    assert_gt(logger.get_event_count(), 0, "로거가 이벤트를 수신")
```

### Step 4: 테스트 실행

```bash
# GUT CLI로 전체 테스트 실행
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit

# 특정 스펙 테스트만 실행
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_spec_haz_001.gd -gexit
```

### Step 5: 테스트 리포트 생성

`_workspace/04_test_report.md`에 저장:

```markdown
# 테스트 리포트

## 요약
- 총 Spec: {N}개
- 테스트 커버: {N}개 ({coverage}%)
- PASS: {N} / FAIL: {N} / SKIP: {N}
- 자동화 비율: {N}%

## Spec ID별 테스트 결과

| Spec ID | Test ID | 유형 | 자동화 | 결과 | 비고 |
|---------|---------|------|--------|------|------|
| SPEC-VR-001 | TEST-VR-001 | Unit | Yes | PASS | |
| SPEC-VR-001 | TEST-VR-001-F | Unit | Yes | PASS | |
| SPEC-HAZ-001 | TEST-HAZ-001 | Integration | Yes | FAIL | 시그널 파라미터 불일치 |

## 미커버 Spec
| Spec ID | 사유 |
|---------|------|
| SPEC-VR-003 | 미구현 (pending) |

## 버그 목록
| # | Test ID | Spec ID | 심각도 | 파일:라인 | 설명 | 담당 |
|---|---------|---------|-------|----------|------|------|
| 1 | TEST-HAZ-001 | SPEC-HAZ-001 | HIGH | hazard_controller.gd:45 | emit 파라미터 타입 불일치 | senior-dev |

## 통합 정합성 결과
| 경계면 | 결과 | 비고 |
|--------|------|------|
| 시그널 연결 | {N}/{M} 정합 | ... |
| 데이터 흐름 | {N}/{M} 정합 | ... |
```

## 자동화 불가 테스트 처리

VR 물리적 체험 등 자동화 불가 항목은 수동 테스트 절차서를 작성한다:

```markdown
### 수동 테스트: TEST-VR-002-M (SPEC-VR-002)
**목적**: VR 스테레오 렌더링 정상 동작 확인
**절차**:
1. Quest에서 앱 실행
2. 양안에 서로 다른 시점이 렌더링되는지 확인
3. 머리를 좌우로 회전하여 트래킹 반응 확인
**판정 기준**: 양안 분리 렌더링 + 1초 이내 트래킹 반응
```

## 품질 체크리스트
- [ ] 모든 Spec ID에 대응하는 TEST ID가 존재
- [ ] 성공 조건, 실패 조건, 예외 처리 각각에 테스트 존재
- [ ] 유닛 테스트와 통합 테스트가 구분됨
- [ ] GUT 프레임워크로 자동 실행 가능
- [ ] 테스트 리포트에 Spec ID별 PASS/FAIL이 명시됨

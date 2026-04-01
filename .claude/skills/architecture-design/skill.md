---
name: architecture-design
description: "Godot 4 VR 프로젝트의 SOLID + Layered Architecture 기반 아키텍처를 설계하는 스킬. 4개 계층(Presentation/Application/Domain/Infrastructure)으로 분리하고, Spec ID를 M:N 매핑한 추적성 매트릭스를 생성한다."
---

# Architecture Design — Spec ID 기반 Godot 4 아키텍처 설계

SOLID + Layered Architecture를 적용하여 Godot 4 VR 프로젝트를 설계한다. 의존성은 Presentation → Application → Domain ← Infrastructure 방향으로만 흐르며, **모든 Spec ID가 아키텍처에 매핑**되어야 한다.

## 설계 절차

### Step 1: 입력 분석
- `docs/specs.md`에서 모든 Spec ID와 성공 조건을 추출
- 각 스펙의 기술적 요구사항을 파악
- 스펙 간 의존성과 공통 기능을 식별

### Step 2: 아키텍처 모듈 도출
스펙을 기능 영역별로 그룹핑하고, 각 영역에 대응하는 아키텍처 모듈을 설계한다.

**프로젝트 디렉토리 구조:**
```
project/
├── project.godot
├── assets/
│   ├── models/          # 3D 모델
│   ├── materials/       # 머티리얼
│   └── textures/        # 텍스처
├── scenes/
│   ├── main.tscn        # 메인 진입 씬
│   ├── vr_rig/          # VR 플레이어 리그
│   ├── environment/     # 건설 현장 환경
│   ├── hazards/         # 위험 요소 씬
│   └── ui/              # UI 씬
├── scripts/
│   ├── core/            # Controller 계층 (매니저, 로직)
│   ├── hazards/         # 위험 요소 스크립트
│   ├── data/            # Model 계층 (데이터, 로거)
│   ├── ui/              # Presenter 계층 (UI)
│   └── utils/           # 유틸리티
├── resources/
│   ├── scenarios/       # 시나리오 JSON 설정 파일
│   └── data_schemas/    # 데이터 리소스 정의
├── tests/               # GUT 테스트 스크립트
│   ├── unit/            # 유닛 테스트
│   └── integration/     # 통합 테스트
└── exports/             # 내보내기 설정
```

### Step 3: Layered Architecture 매핑

| 계층 | Godot 구현 | 위치 | 의존 방향 |
|------|-----------|------|----------|
| **Presentation** | 씬 노드, UI, VR 리그 | `scenes/`, `scripts/presentation/` | → Application |
| **Application** | Autoload 매니저 | `scripts/application/` | → Domain |
| **Domain** | 순수 GDScript 클래스, Resource | `scripts/domain/` | (의존 없음) |
| **Infrastructure** | 파일 I/O, 외부 연동 | `scripts/infrastructure/` | → Domain |

### Step 4: 씬 트리 설계

```
Main (Node3D)
├── XROrigin3D                    ← SPEC-VR-xxx
│   ├── XRCamera3D
│   │   └── GazeCrosshair        ← SPEC-INP-xxx (시선)
│   ├── XRController3D (Left)
│   └── XRController3D (Right)
│       └── MarkerRay (RayCast3D) ← SPEC-INP-xxx (마킹)
├── Environment (Node3D)          ← SPEC-ENV-xxx
│   ├── ConstructionSite
│   └── Lighting
├── HazardContainer (Node3D)      ← SPEC-HAZ-xxx
│   └── (동적 생성되는 위험 요소들)
└── UILayer (Control)             ← SPEC-UI-xxx
    ├── SubjectInfoUI
    ├── SessionHUD
    └── ResultUI
```

### Step 5: 핵심 시스템 인터페이스

각 시스템의 공개 인터페이스(시그널, 메서드)를 정의하고, **관련 Spec ID를 명시**한다:

```markdown
#### GameManager (Autoload)
- 관련 Spec: SPEC-SES-xxx
- 시그널: game_initialized
- 메서드: start_session(), end_session()

#### HazardController
- 관련 Spec: SPEC-HAZ-xxx, SPEC-INP-xxx
- 시그널: hazard_detected(hazard), false_positive(pos)
- 메서드: register_hazard(), attempt_mark()
```

### Step 6: 데이터 스키마 설계

**시나리오 JSON:**
```json
{
  "scenario_id": "string",
  "time_limit_seconds": 300,
  "difficulty": "medium",
  "hazards": [
    {
      "type": "crack",
      "position": [x, y, z],
      "rotation": [x, y, z],
      "severity": 0.8,
      "params": {}
    }
  ]
}
```

**세션 로그 (이벤트 기반):**
```
timestamp, event_type, data_json
```

### Step 7: 추적성 매트릭스 생성 (필수)

**순방향: 모듈 → Spec**

| 아키텍처 모듈 | 관련 Spec ID |
|-------------|------------|
| VRRig | SPEC-VR-001, SPEC-VR-002 |
| InputController | SPEC-INP-001, SPEC-INP-002 |
| HazardSystem | SPEC-HAZ-001, SPEC-HAZ-002, SPEC-HAZ-003 |
| ScenarioManager | SPEC-SCN-001, SPEC-SCN-002 |
| DataLogger | SPEC-DAT-001, SPEC-DAT-002 |
| SessionManager | SPEC-SES-001, SPEC-SES-002 |
| Environment | SPEC-ENV-001 |
| UILayer | SPEC-UI-001, SPEC-UI-002, SPEC-UI-003 |

**역방향: Spec → 모듈 (누락 검증)**

| Spec ID | 관련 모듈 | 커버됨? |
|---------|----------|--------|
| SPEC-VR-001 | VRRig | ✓ |
| ... | ... | ✓ |

**✓가 없는 행이 있으면 설계가 불완전하다** — 해당 스펙을 커버하는 모듈을 추가하거나, 기존 모듈에 매핑을 추가해야 한다.

### Step 8: 시그널 맵

```
SessionManager.session_started → HazardController, DataLogger, UILayer
SessionManager.session_ended → DataLogger, UILayer
HazardController.hazard_spawned → DataLogger
InputController.mark_requested → HazardController
HazardController.hazard_detected → DataLogger, UILayer
HazardController.false_positive → DataLogger
DataLogger.log_saved → SessionManager
```

## 출력 형식

`docs/architecture.md` 파일에 위의 모든 내용을 포함:
1. 프로젝트 디렉토리 구조
2. Layered Architecture 매핑
3. 씬 트리 (Spec ID 주석 포함)
4. 핵심 시스템 인터페이스 (Spec ID 매핑)
5. 데이터 스키마
6. **추적성 매트릭스** (순방향 + 역방향)
7. 시그널 맵

## 품질 체크리스트
- [ ] 모든 Spec ID가 역방향 매트릭스에서 ✓
- [ ] SOLID 원칙이 각 모듈 설계에 반영됨
- [ ] Layered 분리가 명확함 (presentation/ vs application/ vs domain/ vs infrastructure/)
- [ ] tests/ 디렉토리가 설계에 포함됨

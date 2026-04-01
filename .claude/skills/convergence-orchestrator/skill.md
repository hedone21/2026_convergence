---
name: convergence-orchestrator
description: "VR 건설 현장 안전 점검 시뮬레이션 프로젝트의 Spec 기반 개발 파이프라인을 조율하는 오케스트레이터. 'MVP 개발 시작', '개발 진행', '다음 단계', '프로젝트 빌드', '구현해줘' 등 개발 작업 요청 시 반드시 이 스킬을 사용할 것. Requirements→Spec(ID)→Architecture(Spec M:N)→Code→Test(Spec 1:1) 파이프라인을 실행한다."
---

# Convergence Orchestrator — Spec 기반 개발 파이프라인

VR 건설 현장 안전 점검 시뮬레이션의 에이전트 팀을 조율하여 **Spec ID 기반 추적 가능한 파이프라인**을 실행한다.

## 실행 모드: 에이전트 팀

## 파이프라인 개요

```
Requirements → Spec (ID 부여) → Architecture (Spec M:N) → Code → Test (Spec 1:1)
     │              │                    │                  │          │
docs/requirements   01_specs.md         02_architecture    소스코드    04_test_report
                    (SPEC-xxx)          (추적성 매트릭스)   (.gd/.tscn) (TEST-xxx)
```

**추적성 체인**: 모든 Spec ID는 아키텍처 모듈에 매핑(M:N)되고, 코드에 주석으로 명시되고, 테스트에 1:1 매핑된다. 이 체인이 끊기면 파이프라인이 불완전하다.

## 에이전트 구성

| 팀원 | 에이전트 타입 | 모델 | 역할 | 스킬 | 핵심 산출물 |
|------|-------------|------|------|------|-----------|
| pm | 커스텀 (pm) | opus | 요구사항 → 정형 Spec 변환 | spec-analysis | `docs/specs.md`, `docs/todo.md` |
| architect | 커스텀 (architect) | opus | SOLID+Layered 설계 + Spec ID M:N 매핑 | architecture-design | `docs/architecture.md` (추적성 매트릭스 포함) |
| senior-dev | 커스텀 (senior-dev) | opus | 핵심/복잡 모듈 구현 | godot-core-dev | 소스 코드 + `_workspace/03_senior_dev_report.md` |
| dev | 커스텀 (dev) | sonnet | 단순/간단 모듈 구현 | godot-dev | 소스 코드 + `_workspace/03_dev_report.md` |
| tester | 커스텀 (tester) | sonnet | Spec ID 1:1 자동화 테스트 | godot-test | 테스트 코드 + `_workspace/04_test_report.md` |

## 워크플로우

### Phase 1: 준비
1. 사용자 입력 분석 — 개발 범위 파악 (전체 MVP / 특정 모듈 / 버그 수정)
2. 프로젝트 루트에 `_workspace/` 디렉토리 생성
3. `docs/requirements.md` 존재 여부 확인

### Phase 2: 팀 구성

1. 팀 생성:
   ```
   TeamCreate(
     team_name: "convergence-team",
     members: [
       {
         name: "pm",
         agent_type: "pm",
         model: "opus",
         prompt: "당신은 PM입니다. docs/requirements.md를 분석하여 정형 스펙 문서를 생성하세요.
           1. Read로 docs/requirements.md를 읽는다
           2. Read로 .claude/skills/spec-analysis/skill.md를 읽고 절차를 따른다
           3. docs/specs.md (Spec ID + 성공/실패/예외/대안)을 생성한다
           4. docs/todo.md (Spec ID 기반 할당표)를 생성한다
           5. 완료 후 architect에게 SendMessage로 알린다"
       },
       {
         name: "architect",
         agent_type: "architect",
         model: "opus",
         prompt: "당신은 Architect입니다. PM의 스펙이 완료되면:
           1. Read로 docs/specs.md를 읽는다
           2. Read로 .claude/skills/architecture-design/skill.md를 읽고 절차를 따른다
           3. docs/architecture.md를 생성한다 — 반드시 추적성 매트릭스(Spec ID M:N) 포함
           4. 역방향 매트릭스에서 모든 Spec ID에 ✓가 있는지 확인한다
           5. 완료 후 senior-dev와 dev에게 SendMessage로 알린다"
       },
       {
         name: "senior-dev",
         agent_type: "senior-dev",
         model: "opus",
         prompt: "당신은 Senior Dev입니다. Architect의 설계가 완료되면:
           1. Read로 docs/specs.md, docs/architecture.md를 읽는다
           2. Read로 .claude/skills/godot-core-dev/skill.md를 읽고 절차를 따른다
           3. 핵심 모듈을 구현한다 — 코드에 Spec ID 주석 포함
           4. _workspace/03_senior_dev_report.md에 구현된 Spec ID 목록 기록
           5. 완료 후 tester에게 SendMessage로 알린다"
       },
       {
         name: "dev",
         agent_type: "dev",
         model: "sonnet",
         prompt: "당신은 Dev입니다. Architect의 설계가 완료되면:
           1. Read로 docs/specs.md, docs/architecture.md를 읽는다
           2. Read로 .claude/skills/godot-dev/skill.md를 읽고 절차를 따른다
           3. UI, 환경, 설정 파일 등 단순 모듈을 구현한다 — 코드에 Spec ID 주석 포함
           4. _workspace/03_dev_report.md에 구현된 Spec ID 목록 기록
           5. 완료 후 tester에게 SendMessage로 알린다"
       },
       {
         name: "tester",
         agent_type: "tester",
         model: "sonnet",
         prompt: "당신은 Tester입니다. 개발자들의 구현이 완료되면:
           1. Read로 docs/specs.md를 읽어 모든 Spec ID를 수집한다
           2. Read로 .claude/skills/godot-test/skill.md를 읽고 절차를 따른다
           3. 각 Spec ID에 대해 1:1 매칭되는 테스트(TEST-xxx)를 작성한다
           4. GUT 테스트 스크립트를 tests/unit/, tests/integration/에 작성한다
           5. _workspace/04_test_report.md에 Spec ID별 PASS/FAIL 결과를 기록한다
           6. 버그 발견 시 담당 개발자에게 SendMessage로 알린다"
       }
     ]
   )
   ```

2. 작업 등록:
   ```
   TaskCreate(tasks: [
     {
       title: "요구사항 → 정형 Spec 변환",
       description: "docs/requirements.md를 분석하여 Spec ID가 부여된 정형 스펙 생성",
       assignee: "pm"
     },
     {
       title: "Spec 기반 아키텍처 설계",
       description: "SOLID+Layered 아키텍처 설계 + Spec ID M:N 추적성 매트릭스 생성",
       assignee: "architect",
       depends_on: ["요구사항 → 정형 Spec 변환"]
     },
     {
       title: "핵심 모듈 구현",
       description: "VR 리그, 위험 요소, 시나리오 관리, 데이터 로깅 등 — Spec ID 추적 주석 포함",
       assignee: "senior-dev",
       depends_on: ["Spec 기반 아키텍처 설계"]
     },
     {
       title: "일반 모듈 구현",
       description: "UI, 환경 씬, 설정 파일, 유틸리티 등 — Spec ID 추적 주석 포함",
       assignee: "dev",
       depends_on: ["Spec 기반 아키텍처 설계"]
     },
     {
       title: "Spec 기반 자동화 테스트",
       description: "각 Spec ID에 1:1 매칭되는 GUT 테스트 작성 및 실행",
       assignee: "tester",
       depends_on: ["핵심 모듈 구현", "일반 모듈 구현"]
     }
   ])
   ```

### Phase 3: 파이프라인 실행

**실행 흐름:**

```
[pm] ──→ [architect] ──→ [senior-dev] ──→ [tester]
 Spec ID      M:N매핑   └──→ [dev] ──────┘  1:1매핑
```

**Phase별 추적성 검증:**

| Phase | 에이전트 | 검증 항목 |
|-------|---------|----------|
| Spec | pm | 모든 요구사항이 Spec ID로 커버됨 |
| Architecture | architect | 역방향 매트릭스에서 모든 Spec ID에 ✓ |
| Code | senior-dev, dev | 구현 리포트에 Spec ID 목록 포함 |
| Test | tester | 모든 Spec ID에 대응하는 TEST ID 존재 |

**팀원 간 통신 규칙:**

| 발신 | 수신 | 내용 |
|------|------|------|
| pm | architect | Spec 문서 완료, 모든 Spec ID 커버 요청 |
| architect | senior-dev, dev | 아키텍처 + 추적성 매트릭스 완료 |
| architect | pm | 스펙 분할/조정 필요 시 피드백 |
| senior-dev | dev | 인터페이스 계약 (시그널, 베이스 클래스) |
| senior-dev, dev | tester | 구현 완료 + 구현된 Spec ID 목록 |
| tester | senior-dev/dev | 버그 리포트 (TEST ID + Spec ID + 파일:라인) |
| tester | pm | Spec ID별 PASS/FAIL 결과 |

**산출물 저장:**

| 팀원 | 출력 경로 | 핵심 내용 |
|------|----------|----------|
| pm | `docs/specs.md` | Spec ID + 성공/실패/예외/대안 |
| pm | `docs/todo.md` | Spec ID별 할당표 |
| architect | `docs/architecture.md` | 설계 + 추적성 매트릭스 |
| senior-dev | 소스 코드 + `_workspace/03_senior_dev_report.md` | Spec ID 추적 주석 |
| dev | 소스 코드 + `_workspace/03_dev_report.md` | Spec ID 추적 주석 |
| tester | `tests/` + `_workspace/04_test_report.md` | TEST-xxx ↔ SPEC-xxx 1:1 |

### Phase 4: 추적성 검증 및 결과 수집

1. 모든 팀원 작업 완료 대기 (TaskGet)
2. **추적성 체인 완전성 검증**:
   - `01_specs.md`의 모든 Spec ID가 `02_architecture.md` 매트릭스에 존재하는가?
   - `02_architecture.md`의 모든 모듈이 실제 코드로 구현되었는가?
   - `04_test_report.md`에 모든 Spec ID에 대응하는 TEST ID가 존재하는가?
3. 전체 결과 요약을 사용자에게 보고

### Phase 5: 정리

1. 팀원들에게 종료 요청 (SendMessage)
2. 팀 정리
3. `_workspace/` 디렉토리 보존
4. 최종 보고:
   - Spec 커버리지: {Spec 총 N개 중 구현 완료 M개}
   - 테스트 커버리지: {Spec 총 N개 중 테스트 작성 M개, PASS K개}
   - 남은 이슈 목록

## 데이터 흐름

```
docs/requirements.md
        │
        ▼
   [pm] ──→ docs/specs.md (SPEC-xxx)
        └──→ docs/todo.md
                     │
                     ▼
             [architect] ──→ docs/architecture.md
                     │         (추적성 매트릭스: SPEC ↔ Module)
              ┌──────┴──────┐
              ▼              ▼
      [senior-dev]        [dev]
         │                   │
         ▼                   ▼
    코드 (## SPEC-xxx)   코드 (## SPEC-xxx)
         │                   │
         └────────┬──────────┘
                  ▼
             [tester] ──→ tests/ (TEST-xxx ↔ SPEC-xxx 1:1)
                     └──→ _workspace/04_test_report.md
```

## 에러 핸들링

| 상황 | 전략 |
|------|------|
| PM: 요구사항 모호하여 성공 조건 정의 불가 | 해석 명시 + 비고에 "확인 필요" |
| Architect: Spec ID 매핑 누락 | 역방향 매트릭스로 자동 검증, 누락 시 모듈 추가 |
| Developer: Spec 충족 불확실 | Architect에게 설계 확인, PM에게 스펙 명확화 요청 |
| Tester: 자동화 불가 테스트 | 수동 테스트 절차서 작성, 리포트에 명시 |
| Tester: 버그 발견 (HIGH) | 담당 개발자에게 즉시 SendMessage, 수정 후 재테스트 (최대 2회) |
| 팀원 과반 실패 | 사용자에게 알리고 진행 여부 확인 |

## 부분 실행 모드

전체 파이프라인이 아닌 특정 Phase만 실행 가능:
- **"스펙만 작성"**: PM만 실행
- **"설계만"**: Architect만 실행 (기존 01_specs.md 필요)
- **"구현만"**: Senior Dev + Dev만 실행 (기존 02_architecture.md 필요)
- **"테스트만"**: Tester만 실행 (기존 01_specs.md + 소스 코드 필요)

## 테스트 시나리오

### 정상 흐름
1. 사용자가 "MVP 개발 시작"을 요청
2. Phase 1: `_workspace/` 생성
3. Phase 2: 팀 구성 (5명 + 5개 태스크)
4. Phase 3:
   - PM: requirements.md → 01_specs.md (SPEC-VR-001~SPEC-UI-003 등)
   - Architect: 01_specs.md → 02_architecture.md (추적성 매트릭스 100% 커버)
   - Senior Dev + Dev: 병렬 구현 (코드에 ## SPEC-xxx 주석)
   - Tester: TEST-VR-001~TEST-UI-003 작성, GUT 실행
5. Phase 4: 추적성 체인 검증 — 모든 Spec ID가 Architecture→Code→Test에 존재
6. Phase 5: 팀 정리, 최종 보고 (Spec 커버리지 + 테스트 결과)

### 에러 흐름
1. Phase 3에서 Tester가 TEST-HAZ-001 FAIL 발견 (시그널 파라미터 불일치)
2. Tester → senior-dev: "SPEC-HAZ-001 실패: hazard_detected 시그널 파라미터 타입 불일치 (hazard_controller.gd:45)"
3. senior-dev 수정 → tester 재검증
4. Tester: TEST-HAZ-001 PASS
5. 최종 리포트에 수정 이력 포함

### 추적성 누락 흐름
1. Phase 4에서 리더가 추적성 검증
2. SPEC-SCN-002가 02_architecture.md에 매핑되지 않음 발견
3. Architect에게 SendMessage: "SPEC-SCN-002 아키텍처 매핑 누락"
4. Architect 수정 → 리더 재검증

# Convergence — VR 건설 현장 안전 점검 시뮬레이션

## 시스템 지시

- **언어**: 모든 응답, 리포트, 계획, 설명은 한국어로 작성한다. 기술 용어와 코드 식별자는 원문 유지.

LLM의 흔한 코딩 실수를 줄이기 위한 행동 가이드라인. 프로젝트별 지시사항과 필요에 따라 병합한다.

**트레이드오프:** 이 가이드라인은 속도보다 신중함에 편향되어 있다. 사소한 작업에는 재량껏 판단한다.

### 1. 코딩 전 사고

**가정하지 말 것. 혼란을 숨기지 말 것. 트레이드오프를 표면화할 것.**

구현 전:
- 가정을 명시적으로 진술한다. 불확실하면 묻는다.
- 다중 해석이 가능하면 제시한다 — 침묵 속 결정 금지.
- 더 단순한 접근이 존재하면 그렇다고 말한다. 정당한 근거가 있으면 이의를 제기한다(push back).
- 불분명한 게 있으면 멈춘다. 무엇이 혼란스러운지 명명한다. 묻는다.

### 2. 단순함 우선

**문제를 해결하는 최소한의 코드. 추측성 코드 금지.**

- 요청된 것 이상의 기능 금지.
- 일회성 코드를 위한 추상화 금지.
- 요청되지 않은 "유연성"이나 "설정 가능성" 금지.
- 불가능한 시나리오에 대한 에러 핸들링 금지.
- 200줄로 쓴 것을 50줄로 쓸 수 있다면, 다시 쓴다.

자문하라: "시니어 엔지니어가 이걸 보고 과복잡하다고 할까?" 그렇다면 단순화한다.

### 3. 외과적 변경

**꼭 필요한 것만 건드린다. 자신이 만든 것만 정리한다.**

기존 코드를 편집할 때:
- 인접한 코드, 주석, 포매팅을 "개선"하지 않는다.
- 망가지지 않은 것을 리팩토링하지 않는다.
- 본인이라면 다르게 작성할지라도, 기존 스타일을 따른다.
- 무관한 dead code를 발견하면 언급만 한다 — 삭제하지 않는다.

본인의 변경이 orphan을 만들 때:
- 본인의 변경으로 인해 미사용이 된 import·변수·함수를 제거한다.
- 기존부터 있던 dead code는 요청받지 않는 한 제거하지 않는다.

검증 기준: 변경된 모든 라인은 사용자 요청으로 직접 추적 가능해야 한다.

### 4. 목표 기반 실행

**성공 기준을 정의한다. 검증될 때까지 반복한다.**

작업을 검증 가능한 목표로 변환한다:
- "validation 추가" → "invalid input에 대한 테스트를 작성한 뒤 통과시킨다"
- "버그 수정" → "버그를 재현하는 테스트를 작성한 뒤 통과시킨다"
- "X 리팩토링" → "리팩토링 전후로 테스트가 통과함을 보장한다"

다단계 작업의 경우 간단한 계획을 진술한다:
~~~
1. [단계] → 검증: [확인 방법]
2. [단계] → 검증: [확인 방법]
3. [단계] → 검증: [확인 방법]
~~~

강한 성공 기준은 독립적 반복을 가능하게 한다. 약한 기준("그냥 되게 하라")은 지속적인 명확화를 요구한다.

## 기술 스택
- **엔진**: Godot 4 (GDScript + OpenXR), Forward+ 렌더러(PC) / mobile(Quest)
- **VR**: Meta Quest 시리즈
- **씬 형식**: `.tscn` (텍스트 기반)
- **데이터 저장**: 로컬 CSV/JSON
- **테스트**: GUT 프레임워크 (`addons/gut/gut_cmdln.gd`)

## 빠른 시작
```bash
# 첫 실행 또는 자산/스크립트 변경 후 (import 캐시 갱신)
godot --headless --import --quit

# 데스크톱 모드 (OpenXR 없이 키보드/마우스로 실행)
godot --path . -- --desktop

# VR 모드 (OpenXR 런타임 필요)
godot --path .

# 유닛 테스트 (GUT)
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# 사이트 스모크 (씬 부팅 검증)
godot --headless --script tests/smoke/<smoke_script>.gd
```

## 코드 구조 (Layered Architecture)
```
scripts/
  application/   - 시나리오/세션/게임 매니저 — orchestration 계층
  domain/        - 모델·서비스·인터페이스 — 순수 GDScript(RefCounted), 씬 트리 무관
  presentation/  - 씬에 부착되는 노드 — VR rig, 환경(BaseSite), hazard
scenes/
  environment/   - 사이트 씬 (site_type별 .tscn, ScenarioManager가 동적 로드)
  hazards/       - 위험 요소 씬 (crack 등)
  vr_rig/        - vr_rig.tscn, desktop_rig.tscn
  main.tscn      - 진입점. 환경/조명 단일 소스 (WorldEnvironment + DirectionalLight)
resources/scenarios/  - 시나리오 JSON (site_type, hazards, random_placement)
data/                 - 외부 도면 등 추출 데이터 (예: parliament_village/floor_*.json)
tests/unit/           - GUT 유닛 테스트 (TEST-xxx ↔ SPEC-xxx 1:1)
tests/smoke/          - 스모크 테스트 (앱/씬 부팅 검증)
tools/                - 보조 스크립트 (PDF 추출 등)
```

## 개발 파이프라인
```
Requirements → Spec (SPEC-xxx) → Architecture (Spec M:N) → Code → Test (TEST-xxx, Spec 1:1)
```
- 모든 기능은 `docs/requirements.md`에서 출발하여 Spec ID로 추적 가능해야 한다
- 아키텍처는 모든 Spec ID를 M:N으로 매핑 (추적성 매트릭스)
- 테스트는 Spec ID와 1:1 매칭, GUT 프레임워크로 자동화

## 에이전트 팀 구성
| 에이전트 | 모델 | 역할 |
|---------|------|------|
| pm | opus | 요구사항 → 정형 Spec 변환 |
| architect | opus | SOLID + Layered Architecture + 추적성 매트릭스 |
| senior-dev | opus | 핵심/복잡 모듈 구현 |
| dev | sonnet | 단순/간단 모듈 구현 |
| tester | sonnet | Spec 1:1 자동화 테스트 |

## 산출물 경로
| 산출물 | 경로 |
|--------|------|
| 요구사항 | `docs/requirements.md` |
| 스펙 | `docs/specs.md` |
| 실행 계획 | `docs/todo.md` |
| 아키텍처 | `docs/architecture.md` |
| 테스트 리포트 | `_workspace/04_test_report.md` |
| 테스트 코드 | `tests/unit/`, `tests/integration/` |

## 코딩 규칙
- 클래스명: PascalCase, 파일명: snake_case, 시그널명: snake_case
- 구현 코드에 관련 Spec ID를 주석으로 명시: `## SPEC-HAZ-001`
- 타입 힌트 필수, 매직 넘버 금지 (@export 또는 상수 사용)

## Gotchas
- **환경/조명 단일 소스**: `WorldEnvironment`/`DirectionalLight`는 `main.tscn`에만. 사이트 씬에서 자체 생성 금지 (덮어쓰기 문제).
- **사이트 swap 패턴**: ScenarioManager가 `res://scenes/environment/<site_type>.tscn`을 시나리오 JSON의 `site_type`으로 동적 로드. 새 사이트 추가 시 `ScenarioValidator.VALID_SITE_TYPES`에 등록 필요.
- **스모크 우선**: 유닛 테스트 전부 통과해도 컴포넌트 조립 누락은 못 잡음. UI/시각 변경은 데스크톱 모드로 직접 확인.
- **근본 원인 우선**: 사용자 시각 검증이 두 번 부정되면 패치 누적 금지. 가설 목록화 후 단일 변경 실험.
- **Spec 추상성**: 스펙은 구현 독립적·불변. 클래스명·API·우선순위·할당은 `docs/todo.md`로 분리.

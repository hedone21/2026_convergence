# Convergence — VR 건설 현장 안전 점검 시뮬레이션

## 기술 스택
- **엔진**: Godot 4 (GDScript + OpenXR)
- **VR**: Meta Quest 시리즈
- **씬 형식**: `.tscn` (텍스트 기반)
- **데이터 저장**: 로컬 CSV/JSON

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

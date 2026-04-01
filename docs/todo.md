# 실행 계획 (Todo)

- 기준 문서: `docs/specs.md`
- 생성일: 2026-04-01
- 총 스펙 수: 20개 (P0: 11, P1: 6, P2: 3)
- Senior Dev: 12개, Dev: 8개

## 할당 기준

| 복잡도 지표 | Senior Dev (opus) | Dev (sonnet) |
|-----------|------------------|-------------|
| VR 코어 (OpenXR 등) | O | |
| 복잡한 알고리즘 (탐지, 랜덤 생성, 절차적 생성) | O | |
| 시스템 간 통합 로직 (세션 상태 머신, 평가 산출) | O | |
| 3D 환경 구성 (충돌 판정, 물리) | O | |
| UI 구현 | | O |
| 설정 파일 / 템플릿 | | O |
| 단순 데이터 로깅 | | O |
| 파라미터 기반 조정 로직 | | O |

---

## 태스크 목록

| Spec ID | 제목 | 우선순위 | 할당 | 의존성 | 상태 |
|---------|------|---------|------|--------|------|
| SPEC-VR-001 | VR 환경 초기화 및 세션 시작 | P0 | senior-dev | 없음 | pending |
| SPEC-VR-002 | 데스크톱 모드 폴백 | P0 | senior-dev | SPEC-VR-001 | pending |
| SPEC-ENV-001 | 건물 골조 현장 3D 환경 | P0 | senior-dev | SPEC-VR-001 | pending |
| SPEC-ENV-002 | 크랙 절차적 생성 시스템 | P0 | senior-dev | SPEC-ENV-001 | pending |
| SPEC-ENV-003 | 추가 현장 유형 확장 구조 | P2 | senior-dev | SPEC-ENV-001, SPEC-SCN-001 | pending |
| SPEC-HAZ-001 | 위험 요소 기본 시스템 (배치 및 상태 관리) | P0 | senior-dev | SPEC-ENV-001 | pending |
| SPEC-HAZ-002 | 위험 요소 난이도 파라미터 | P1 | dev | SPEC-HAZ-001 | pending |
| SPEC-HAZ-003 | 위험 요소 종류 확장 (부식, 누수 등) | P2 | dev | SPEC-HAZ-001 | pending |
| SPEC-INP-001 | 조이스틱 기반 이동 | P0 | senior-dev | SPEC-VR-001, SPEC-ENV-001 | pending |
| SPEC-INP-002 | 컨트롤러 버튼 마킹 | P0 | senior-dev | SPEC-VR-001, SPEC-HAZ-001 | pending |
| SPEC-INP-003 | 화면 중심 기반 시선 추적 | P0 | dev | SPEC-VR-001 | pending |
| SPEC-SCN-001 | 시나리오 설정 파일 | P1 | dev | 없음 | pending |
| SPEC-SCN-002 | 위험 요소 랜덤 배치 | P1 | senior-dev | SPEC-HAZ-001, SPEC-ENV-001, SPEC-SCN-001 | pending |
| SPEC-DAT-001 | 세션 결과 로컬 파일 저장 | P0 | dev | 없음 | pending |
| SPEC-DAT-002 | 발견율 및 반응 시간 산출 | P0 | senior-dev | SPEC-HAZ-001 | pending |
| SPEC-DAT-003 | 뇌파(EEG) 동기화용 타임스탬프 로깅 | P1 | dev | SPEC-DAT-001 | pending |
| SPEC-DAT-004 | 사용자 행동 로깅 (이동 경로, 시선, 오탐) | P1 | dev | SPEC-DAT-001, SPEC-INP-003 | pending |
| SPEC-DAT-005 | 뇌파 기기 실시간 연동 (LSL) | P2 | senior-dev | SPEC-DAT-003 | pending |
| SPEC-SES-001 | 피험자 정보 입력 화면 | P0 | dev | SPEC-VR-001 | pending |
| SPEC-SES-002 | 세션 타이머 (시간 제한) | P0 | dev | 없음 | pending |
| SPEC-SES-003 | 세션 흐름 제어 (시작-진행-종료) | P1 | senior-dev | SPEC-SES-001, SPEC-SES-002, SPEC-DAT-001 | pending |

---

## 구현 순서 권장안

개발 의존성을 고려한 단계별 구현 순서:

### Phase 1: 기반 시스템 (P0 핵심)
병렬 가능한 독립 작업부터 시작.

| 순서 | Spec ID | 할당 | 비고 |
|------|---------|------|------|
| 1-1 | SPEC-VR-001 | senior-dev | 모든 VR 기능의 기반 |
| 1-2 | SPEC-VR-002 | senior-dev | VR-001과 함께 구현 (개발 테스트에 필수) |
| 1-3 | SPEC-DAT-001 | dev | 의존성 없음, 병렬 진행 가능 |
| 1-4 | SPEC-SES-002 | dev | 의존성 없음, 병렬 진행 가능 |

### Phase 2: 환경 및 인터랙션 (P0 코어)
Phase 1 완료 후.

| 순서 | Spec ID | 할당 | 비고 |
|------|---------|------|------|
| 2-1 | SPEC-ENV-001 | senior-dev | VR-001 위에 3D 환경 구축 |
| 2-2 | SPEC-SES-001 | dev | VR-001 위에 UI 구축 |
| 2-3 | SPEC-INP-003 | dev | VR-001 위에 시선 추적 |

### Phase 3: 위험 요소 및 상호작용 (P0 완성)
Phase 2 완료 후.

| 순서 | Spec ID | 할당 | 비고 |
|------|---------|------|------|
| 3-1 | SPEC-ENV-002 | senior-dev | ENV-001 위에 크랙 생성 |
| 3-2 | SPEC-HAZ-001 | senior-dev | ENV-001 위에 위험 요소 시스템 |
| 3-3 | SPEC-INP-001 | senior-dev | ENV-001 + VR-001 위에 이동 |
| 3-4 | SPEC-INP-002 | senior-dev | HAZ-001 + VR-001 위에 마킹 |
| 3-5 | SPEC-DAT-002 | senior-dev | HAZ-001 위에 평가 산출 |

### Phase 4: 확장 기능 (P1)
MVP 완성 후.

| 순서 | Spec ID | 할당 | 비고 |
|------|---------|------|------|
| 4-1 | SPEC-SCN-001 | dev | 시나리오 설정 파일 |
| 4-2 | SPEC-HAZ-002 | dev | SCN-001과 연동 |
| 4-3 | SPEC-SCN-002 | senior-dev | SCN-001 + HAZ-001 위에 랜덤 배치 |
| 4-4 | SPEC-DAT-003 | dev | DAT-001 위에 타임스탬프 로깅 |
| 4-5 | SPEC-DAT-004 | dev | DAT-001 + INP-003 위에 행동 로깅 |
| 4-6 | SPEC-SES-003 | senior-dev | 전체 시스템 통합 |

### Phase 5: 장기 확장 (P2)
연구 진행에 따라 선택적 구현.

| 순서 | Spec ID | 할당 | 비고 |
|------|---------|------|------|
| 5-1 | SPEC-HAZ-003 | dev | 위험 요소 종류 확장 |
| 5-2 | SPEC-ENV-003 | senior-dev | 현장 유형 확장 |
| 5-3 | SPEC-DAT-005 | senior-dev | LSL 실시간 연동 |

---

## 의존성 다이어그램

```
SPEC-VR-001 (VR 환경 초기화)
├── SPEC-VR-002 (데스크톱 폴백)
├── SPEC-ENV-001 (3D 환경)
│   ├── SPEC-ENV-002 (크랙 생성)
│   ├── SPEC-HAZ-001 (위험 요소 시스템)
│   │   ├── SPEC-INP-002 (마킹)
│   │   ├── SPEC-DAT-002 (발견율/반응시간)
│   │   ├── SPEC-HAZ-002 (난이도)
│   │   ├── SPEC-HAZ-003 (종류 확장)
│   │   └── SPEC-SCN-002 (랜덤 배치)
│   └── SPEC-INP-001 (이동)
├── SPEC-INP-003 (시선 추적)
│   └── SPEC-DAT-004 (행동 로깅)
└── SPEC-SES-001 (피험자 입력 UI)

SPEC-DAT-001 (파일 저장) — 의존성 없음
├── SPEC-DAT-003 (타임스탬프 로깅)
│   └── SPEC-DAT-005 (LSL 연동)
└── SPEC-DAT-004 (행동 로깅)

SPEC-SES-002 (타이머) — 의존성 없음

SPEC-SCN-001 (설정 파일) — 의존성 없음
├── SPEC-SCN-002 (랜덤 배치)
└── SPEC-ENV-003 (현장 유형 확장)

SPEC-SES-003 (세션 흐름) — SES-001 + SES-002 + DAT-001 이후
```

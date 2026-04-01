# Dev 구현 리포트 — Phase 1

**작성일**: 2026-04-01  
**담당자**: Dev Agent

---

## 구현된 Spec ID 목록

| Spec ID | 설명 | 상태 |
|---|---|---|
| SPEC-DAT-001 | 세션 결과 로컬 파일 저장 (JSON + CSV) | 완료 |
| SPEC-SES-002 | 세션 타이머 (시간 제한, 카운트다운) | 완료 |

---

## 생성된 파일 목록

### Domain Layer

| 파일 | 클래스명 | 역할 |
|---|---|---|
| `scripts/domain/models/subject_data.gd` | `SubjectData` | 피험자 정보 Resource |
| `scripts/domain/models/marking_result.gd` | `MarkingResult` | 위험 요소 마킹 결과 Resource |
| `scripts/domain/models/session_data.gd` | `SessionData` | 세션 전체 결과 Resource |

### Infrastructure Layer

| 파일 | 클래스명 | 역할 |
|---|---|---|
| `scripts/infrastructure/session_logger.gd` | `SessionLogger` | JSON + CSV 저장, 경로 반환 |

### Presentation Layer

| 파일 | 클래스명 | 역할 |
|---|---|---|
| `scripts/presentation/ui/session_timer.gd` | `SessionTimer` | 카운트다운 타이머 노드 |

### 생성된 디렉토리

- `scripts/domain/models/`
- `scripts/infrastructure/`
- `scripts/presentation/ui/`
- `data/sessions/` — 세션 결과 저장 경로

---

## 공개 인터페이스

### SessionData (Domain)

**메서드**
- `get_elapsed_seconds() -> float` — (end_time - start_time) / 1000
- `get_discovered_hazards() -> int` — is_correct인 비오탐 마킹 수
- `get_false_positives() -> Array[MarkingResult]` — 오탐 목록
- `get_hazard_results() -> Array[MarkingResult]` — 비오탐 마킹 목록
- `get_discovery_rate_percent() -> float` — 발견율(%)
- `get_avg_reaction_time_ms() -> float` — 평균 반응 시간

### SubjectData (Domain)

**메서드**
- `to_dict() -> Dictionary` — JSON 직렬화용

### MarkingResult (Domain)

**메서드**
- `is_false_positive() -> bool` — hazard_id 비어있으면 true
- `to_dict() -> Dictionary` — JSON 직렬화용 (정답용/오탐용 분기)

### SessionLogger (Infrastructure)

**시그널**
- `save_completed(path: String)` — 저장 완료, JSON 파일 경로 전달
- `save_failed(error: String)` — 저장 실패, 에러 메시지 전달

**메서드**
- `save_session_result(session_data: SessionData) -> String` — JSON + CSV 저장, JSON 경로 반환 (실패 시 빈 문자열)

**저장 파일 (세션당 3개)**
- `data/sessions/{subject_id}_{timestamp}_result.json` — 상세 JSON
- `data/sessions/{subject_id}_{timestamp}_result.csv` — 세션 요약 CSV
- `data/sessions/{subject_id}_{timestamp}_hazards.csv` — 위험 요소별 CSV

**예외 처리**
- 기본 저장 경로 실패 시 `user://sessions`로 폴백
- 파일 이름 충돌 시 순번 suffix 추가 (덮어쓰지 않음)
- 저장 전체 실패 시 콘솔에 최소 결과 출력 (발견율, 반응시간, 경과시간)

### SessionTimer (Presentation)

**시그널**
- `timer_updated(remaining_seconds: float)` — 매초 남은 시간 전달
- `timer_expired` — 제한 시간 도달, 세션 자동 종료 트리거

**메서드**
- `start_timer(duration_seconds: float)` — 타이머 시작 (0 이하 입력 시 300초로 대체 + 경고)
- `stop_timer()` — 타이머 정지
- `get_remaining() -> float` — 남은 시간(초) 반환
- `is_running() -> bool` — 동작 중 여부
- `get_remaining_formatted() -> String` — "MM:SS" 형식 반환

---

## 의존성 방향 준수

- Infrastructure(`SessionLogger`) → Domain(`SessionData`, `SubjectData`, `MarkingResult`): 허용
- Presentation(`SessionTimer`) → Domain: 미참조 (독립적)
- Infrastructure가 Presentation을 참조하지 않음: 준수

---

## 미구현 항목

없음. Phase 1 범위(SPEC-DAT-001, SPEC-SES-002) 전체 완료.

---

# Dev 구현 리포트 — Phase 2

**작성일**: 2026-04-01  
**담당자**: Dev Agent

---

## 구현된 Spec ID 목록

| Spec ID | 설명 | 상태 |
|---|---|---|
| SPEC-SES-001 | 피험자 정보 입력 화면 (UI + 씬) | 완료 |
| SPEC-INP-003 | 화면 중심 기반 시선 추적 | 완료 |

---

## 생성된 파일 목록

### Presentation Layer

| 파일 | 클래스명 | 역할 |
|---|---|---|
| `scripts/presentation/ui/subject_info_ui.gd` | `SubjectInfoUI` | 피험자 ID·경력 입력 UI, SubjectData 생성 및 시그널 발행 |
| `scenes/ui/subject_info_ui.tscn` | — | SubjectInfoUI 씬 (Control 루트) |
| `scripts/presentation/input/gaze_tracker.gd` | `GazeTracker` | 화면 중심 기반 주기적 시선 방향 샘플링 |

### 생성된 디렉토리

- `scripts/presentation/input/` — 입력 처리 스크립트 디렉토리
- `scenes/ui/` — UI 씬 디렉토리

---

## 공개 인터페이스

### SubjectInfoUI (Presentation)

**시그널**
- `info_submitted(subject_data: SubjectData)` — 제출 시 SubjectData 인스턴스를 포함해 발행

**동작 규칙**
- ID 필드가 비어있으면 제출 버튼이 `disabled = true`로 비활성화됨 (SPEC-SES-001)
- `warning_label`은 ID를 입력 후 지운 경우(length > 0 후 empty)에만 표시
- `experience_category`는 경력 연수에서 자동 산출 (신입/초급/중급/고급/전문가)
- 기존 `SubjectData` Resource 재사용 (`scripts/domain/models/subject_data.gd`)

**씬 노드 구조**
```
SubjectInfoUI (Control, anchors_preset=15)
└── PanelContainer (중앙 정렬, 400×320)
    └── VBoxContainer
        ├── TitleLabel       — "피험자 정보 입력"
        ├── IDLabel          — "피험자 ID *"
        ├── IDInput          — LineEdit (placeholder 포함)
        ├── ExperienceLabel  — "경력 (년수)"
        ├── ExperienceInput  — SpinBox (0~50년, suffix "년")
        ├── WarningLabel     — 빨간색 경고 (기본 hidden)
        └── SubmitButton     — "시뮬레이션 시작" (초기 disabled)
```

### GazeTracker (Presentation)

**시그널**
- `gaze_sampled(direction: Vector3, timestamp: int)` — 샘플링 주기마다 시선 방향과 Unix ms 타임스탬프 전달

**@export 속성**
- `sample_interval_ms: float = 100.0` — 샘플링 주기(ms), 인스펙터에서 변경 가능 (SPEC-INP-003)

**메서드**
- `start_tracking(camera: Camera3D)` — 추적 시작 (camera=null이면 에러 로그 출력 후 비활성화)
- `stop_tracking()` — 추적 중단, 카메라 참조 해제
- `get_current_gaze() -> Vector3` — 현재 시선 방향 반환 (비활성 시 Vector3.ZERO)

**예외 처리**
- `start_tracking` 호출 시 camera=null → `push_error` 후 추적 미시작
- `_process` 중 카메라 인스턴스 무효화 → `push_error` 후 `stop_tracking()` 자동 호출
- 타임스탬프: `Time.get_ticks_msec()` 사용 (EEG 동기화 SPEC-DAT-003 호환)

---

## 의존성 방향 준수

- `SubjectInfoUI` → `SubjectData` (Domain): 허용
- `GazeTracker` → Godot 내장 `Camera3D`, `Time`: 허용
- Presentation이 Infrastructure를 참조하지 않음: 준수

---

## 미구현 항목

없음. Phase 2 범위(SPEC-SES-001, SPEC-INP-003) 전체 완료.

---

# Dev 구현 리포트 — Phase 4

**작성일**: 2026-04-01  
**담당자**: Dev Agent

---

## 구현된 Spec ID 목록

| Spec ID | 설명 | 상태 |
|---|---|---|
| SPEC-SCN-001 | 시나리오 설정 파일 (JSON 템플릿 + 난이도별 예시) | 완료 |
| SPEC-HAZ-002 | 위험 요소 난이도 파라미터 (기존 구현 확인 + 시나리오 JSON 연동) | 완료 |
| SPEC-DAT-003 | 뇌파(EEG) 동기화용 타임스탬프 로깅 (EventLogger) | 완료 |
| SPEC-DAT-004 | 사용자 행동 로깅 (이동 경로, 시선, 오탐) (BehaviorLogger) | 완료 |

---

## 버그 수정

| 버그 ID | 파일 | 변경 내용 |
|---|---|---|
| BUG-003 | `scripts/presentation/input/gaze_tracker.gd` | `Time.get_ticks_msec()` → `int(Time.get_unix_time_from_system() * 1000)` — 세션 상대 시간이 아닌 Unix epoch ms로 교체 |

---

## 생성된 파일 목록

### Domain Layer

| 파일 | 클래스명 | 역할 |
|---|---|---|
| `scripts/domain/models/behavior_sample.gd` | `BehaviorSample` | 행동 샘플(위치/시선/오탐) 데이터 Resource |

### Infrastructure Layer

| 파일 | 클래스명 | 역할 |
|---|---|---|
| `scripts/infrastructure/event_logger.gd` | `EventLogger` | EEG 동기화용 이벤트 + 타임스탬프 CSV 기록 |
| `scripts/infrastructure/behavior_logger.gd` | `BehaviorLogger` | 이동 경로·시선·오탐 CSV 기록 |

### Resources (시나리오 JSON)

| 파일 | 설명 |
|---|---|
| `resources/scenarios/scenario_template.json` | 시나리오 템플릿 (연구자 복사·수정용) |
| `resources/scenarios/mvp_easy.json` | 쉬운 시나리오 — 크랙 3개, difficulty 0.2~0.4 |
| `resources/scenarios/mvp_hard.json` | 어려운 시나리오 — 크랙 3개, difficulty 0.7~0.9 |

### 수정된 파일

| 파일 | 변경 내용 |
|---|---|
| `scripts/presentation/input/gaze_tracker.gd` | BUG-003 수정: 타임스탬프를 Unix epoch ms로 변경 |

---

## 공개 인터페이스

### EventLogger (Infrastructure)

**이벤트 타입 상수**
- `EVENT_SESSION_START = "SESSION_START"`
- `EVENT_SESSION_END = "SESSION_END"`
- `EVENT_HAZARD_DISCOVERED = "HAZARD_DISCOVERED"`
- `EVENT_MARK_ATTEMPT = "MARK_ATTEMPT"`
- `EVENT_MOVEMENT_START = "MOVEMENT_START"`
- `EVENT_MOVEMENT_STOP = "MOVEMENT_STOP"`

**메서드**
- `log_session_start(data: Dictionary)` — 세션 시작 기준 시간 설정 + SESSION_START 기록 (이 메서드를 통해 세션 시작 기록 권장)
- `log_event(type: String, data: Dictionary)` — 이벤트 + epoch_ms / relative_ms 기록
- `get_session_start_epoch() -> int` — 세션 시작 절대 시간 (Unix ms)
- `set_log_path(path: String)` — 주기적 flush 대상 경로 설정
- `flush()` — 버퍼를 파일에 추가 기록(append), 버퍼 초기화
- `save_event_log(path: String)` — 경로 확정 후 최종 flush

**저장 CSV 형식**
```
epoch_ms,relative_ms,event_type,data_json
1743505822000,0,SESSION_START,"{""scenario_id"":""mvp_easy""}"
```

**예외 처리**
- 경로 미설정 상태에서 `flush()` 호출 → `push_warning` 후 건너뜀
- 디렉토리 없으면 자동 생성

### BehaviorLogger (Infrastructure)

**@export 속성**
- `position_sample_interval_ms: float = 200.0` — 이동 샘플링 주기(ms)
- `gaze_sample_interval_ms: float = 100.0` — 시선 샘플링 참조 주기(ms)

**메서드**
- `start_logging(player: Node3D = null)` — 로깅 시작, player가 있으면 주기적 위치 샘플링 활성화
- `stop_logging()` — 로깅 중단
- `record_position(pos: Vector3, timestamp: int)` — 위치 샘플 기록
- `record_gaze(direction: Vector3, timestamp: int)` — 시선 방향 샘플 기록
- `record_false_positive(pos: Vector3, dir: Vector3, timestamp: int)` — 오탐 기록 (로깅 비활성화 상태에서도 기록)
- `set_log_path(path: String)` — 주기적 flush 대상 경로 설정
- `flush_buffer()` — 버퍼를 파일에 추가 기록(append), 버퍼 초기화
- `save_behavior_log(path: String)` — 경로 확정 후 최종 flush

**저장 CSV 형식**
```
epoch_ms,sample_type,x,y,z,dir_x,dir_y,dir_z
1743505822200,position,0.0,1.7,0.0,,,
1743505822300,gaze,,,,0.0,0.0,-1.0
1743505870000,false_positive,0.0,1.7,2.0,0.0,0.0,1.0
```

**예외 처리**
- player 인스턴스 무효화 → `push_error` 후 위치 샘플링 자동 중단
- 버퍼 2000건 초과 → 즉시 flush + 위치 샘플링 주기 2배 조정 (성능 보호)

### BehaviorSample (Domain)

**열거형 SampleType**
- `POSITION` — 이동 경로 샘플
- `GAZE` — 시선 방향 샘플
- `FALSE_POSITIVE` — 오탐 샘플

**팩토리 메서드**
- `BehaviorSample.make_position(pos: Vector3, ts: int) -> BehaviorSample`
- `BehaviorSample.make_gaze(dir: Vector3, ts: int) -> BehaviorSample`
- `BehaviorSample.make_false_positive(pos: Vector3, dir: Vector3, ts: int) -> BehaviorSample`

**메서드**
- `to_csv_row() -> String` — CSV 행 문자열 반환

### 시나리오 JSON 스키마 (SPEC-SCN-001 / SPEC-HAZ-002)

**필수 키**
- `scenario_id: String` — 고유 식별자
- `site_type: String` — 현장 유형 (기본 `"building_frame"`)
- `time_limit_seconds: int` — 세션 제한 시간(초)
- `hazards[].id: String` — 위험 요소 ID
- `hazards[].type: String` — 위험 요소 유형 (예: `"crack"`)
- `hazards[].position: [x, y, z]` — 월드 좌표
- `hazards[].difficulty: float` — SPEC-HAZ-002: 0.0(쉬움) ~ 1.0(어려움), 범위 밖 입력은 clamp 처리

**선택 키**
- `random_placement: bool` — true이면 `hazards` 무시, `random_config` 사용
- `random_seed: int` — 0이면 시스템 시간 기반 시드
- `hazards[].rotation: [x, y, z]` — 오일러 각(도)
- `hazards[].params.length/width/branches` — 크랙 전용 파라미터

---

## SPEC-HAZ-002 확인 결과

기존 코드(`base_hazard.gd`, `crack_hazard.gd`, `hazard_rules.gd`)에 이미 난이도 파라미터 시스템이 구현되어 있음을 확인:
- `BaseHazard.difficulty: float` — 0.0~1.0 필드 존재
- `CrackHazard._apply_difficulty()` — `HazardRules.calculate_difficulty_visual_params()`를 통해 scale/opacity/color_blend 산출 및 적용
- `HazardData.from_dict()` — JSON의 `difficulty` 키 파싱 지원

추가 작업: 시나리오 JSON에서 `hazards[].difficulty`를 지정하는 예시 파일 3종 제공.

---

## 의존성 방향 준수

- `EventLogger` (Infrastructure) → Godot 내장 `Time`, `FileAccess`, `JSON`: 허용
- `BehaviorLogger` (Infrastructure) → `BehaviorSample` (Domain): 허용
- `BehaviorSample` (Domain) → 외부 의존 없음: 준수
- Infrastructure가 Presentation을 참조하지 않음: 준수

---

## 미구현 항목

없음. Phase 4 범위 전체 완료.

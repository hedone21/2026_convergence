# Senior Dev 구현 리포트 — Phase 1

## 구현 일자
2026-04-01

## 구현된 Spec ID 목록

| Spec ID | 제목 | 충족 상태 |
|---------|------|----------|
| SPEC-VR-001 | VR 환경 초기화 및 세션 시작 | ✅ 구현 완료 |
| SPEC-VR-002 | 데스크톱 모드 폴백 | ✅ 구현 완료 |

### SPEC-VR-001 충족 상세
- OpenXR 인터페이스 탐색 및 초기화 (`VRInitializer.initialize_openxr()`)
- 스테레오 렌더링 활성화 (`viewport.use_xr = true`)
- XROrigin3D, XRCamera3D (머리 추적), XRController3D 좌/우 구성 (`vr_rig.tscn`)
- 초기화 실패 시 에러 로그 출력 후 데스크톱 모드 전환

### SPEC-VR-002 충족 상세
- VR 초기화 실패 시 자동 데스크톱 모드 전환 + 사유 로그 출력
- `--desktop` 커맨드라인 플래그로 강제 데스크톱 모드 진입
- WASD 키보드 이동 구현 (카메라 방향 기준)
- 마우스 시점 제어 (좌우/상하 회전, 수직 ±90도 제한)
- 마우스 좌클릭 마킹 (`mark_requested` 시그널 발행)
- CharacterBody3D 기반 물리 이동 + 중력 적용

---

## 생성된 파일 목록

### 프로젝트 설정
| 파일 | 설명 |
|------|------|
| `project.godot` | Godot 4 프로젝트 설정 (OpenXR 활성화, GameManager Autoload 등록, 메인 씬 지정) |

### Application Layer
| 파일 | 클래스명 | 설명 |
|------|---------|------|
| `scripts/application/game_manager.gd` | GameManager | Autoload. VR/데스크톱 모드 결정 및 리그 생성 |

### Presentation Layer
| 파일 | 클래스명 | 설명 |
|------|---------|------|
| `scripts/presentation/vr/rig_interface.gd` | RigInterface | 추상 베이스 클래스. VR/데스크톱 리그 공통 인터페이스 |
| `scripts/presentation/vr/vr_initializer.gd` | VRInitializer | OpenXR 초기화 유틸리티 (RefCounted, static) |
| `scripts/presentation/vr/vr_rig_controller.gd` | VRRigController | VR 리그. XROrigin3D 기반, 조이스틱 이동, 트리거 마킹 |
| `scripts/presentation/vr/desktop_rig_controller.gd` | DesktopRigController | 데스크톱 리그. CharacterBody3D 기반, WASD+마우스 |

### Scenes
| 파일 | 설명 |
|------|------|
| `scenes/main.tscn` | 메인 씬 (PlayerRig, SiteContainer, HazardContainer, UILayer 슬롯) |
| `scenes/vr_rig/vr_rig.tscn` | VR 리그 씬 (XROrigin3D + XRCamera3D + 좌/우 XRController3D) |
| `scenes/vr_rig/desktop_rig.tscn` | 데스크톱 리그 씬 (CharacterBody3D + Camera3D + CollisionShape3D) |

---

## 공개 인터페이스

### GameManager (Autoload)

**시그널:**
| 시그널 | 파라미터 | 발행 시점 |
|--------|---------|----------|
| `vr_initialized` | 없음 | VR 초기화 성공 후 |
| `desktop_mode_activated` | `reason: String` | 데스크톱 모드 전환 시 (사유 포함) |
| `game_ready` | 없음 | 모든 초기화 완료 후 |

**속성:**
| 속성 | 타입 | 설명 |
|------|------|------|
| `is_vr_mode` | `bool` | VR 모드 활성 여부 |
| `current_rig` | `RigInterface` | 현재 활성 리그 인스턴스 |

**메서드:**
| 메서드 | 반환 | 설명 |
|--------|------|------|
| `get_camera()` | `Camera3D` | 현재 모드의 카메라 반환 |
| `quit_application()` | `void` | 안전 종료 |

### RigInterface (추상 베이스)

**시그널:**
| 시그널 | 파라미터 | 설명 |
|--------|---------|------|
| `mark_requested` | `ray_origin: Vector3, ray_direction: Vector3` | 마킹 입력 발생 시 |

**가상 메서드 (서브클래스 구현 필수):**
| 메서드 | 반환 | 설명 |
|--------|------|------|
| `get_camera()` | `Camera3D` | 활성 카메라 |
| `get_ray_origin()` | `Vector3` | 마킹 레이 시작점 |
| `get_ray_direction()` | `Vector3` | 마킹 레이 방향 |
| `get_player_position()` | `Vector3` | 플레이어 월드 위치 |
| `apply_movement(dir, delta)` | `void` | 이동 적용 |

### VRInitializer (유틸리티)

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `initialize_openxr()` (static) | `Dictionary` | `{success: bool, interface?: XRInterface, reason?: String}` |

---

## 아키텍처 준수 사항

- **의존 방향**: Application(GameManager) → Presentation(RigInterface, VRRigController, DesktopRigController). 역방향 의존 없음.
- **추상화**: GameManager는 `RigInterface` 타입으로만 리그를 참조. 구체 타입(VR/Desktop)에 직접 의존하지 않음.
- **개방-폐쇄 원칙**: 새 리그 타입 추가 시 `RigInterface`를 상속 구현하고, 씬을 추가하면 됨.
- **리스코프 치환**: VRRigController와 DesktopRigController 모두 RigInterface 자리에 투명하게 교체 가능.

---

## 다음 Phase에서 연결할 사항

1. **SessionManager 연결**: `GameManager.game_ready` 시그널을 `SessionManager`가 구독하여 세션 흐름 시작
2. **InputManager 연결**: `GameManager.is_vr_mode`를 참조하여 입력 모드(VR/Desktop) 설정
3. **MarkingSystem 연결**: `RigInterface.mark_requested` 시그널을 `MarkingSystem`이 구독하여 레이캐스트 마킹 처리
4. **Locomotion 연결**: 현재 리그 내부에서 직접 이동 처리하고 있으나, InputManager를 통한 추상화 레이어 추가 가능
5. **UILayer**: 메인 씬의 UILayer에 SubjectInfoUI, SessionHUD, ResultUI 추가
6. **SiteContainer**: 환경 씬(BuildingFrameSite) 동적 로드 연결
7. **HazardContainer**: ScenarioManager에 의한 위험 요소 동적 생성 연결
8. **Autoload 추가 등록**: SessionManager, ScenarioManager, HazardManager, EvaluationManager, InputManager를 project.godot에 등록

---

# Senior Dev 구현 리포트 — Phase 2

## 구현 일자
2026-04-01

## 구현된 Spec ID 목록

| Spec ID | 제목 | 충족 상태 |
|---------|------|----------|
| SPEC-ENV-001 | 건물 골조 현장 3D 환경 | ✅ 구현 완료 |

### SPEC-ENV-001 충족 상세

**성공 조건 충족:**
- 기둥 최소 4개: 3x3 그리드에서 중앙 제외 **8개 기둥** 생성 (StaticBody3D + CollisionShape3D)
- 보 최소 4개: X방향 6개 + Z방향 6개 = **총 12개 보** 생성 (기둥 상단 연결)
- 슬래브 최소 1개: **1개 전체 면적 슬래브** 생성 (기둥 + 보 상단)
- 바닥 충돌 판정: StaticBody3D + BoxShape3D (20m x 0.3m x 20m) 바닥면 존재, 플레이어가 떨어지지 않음
- 구조물 충돌 판정: 모든 기둥, 보, 슬래브, 벽체에 StaticBody3D + CollisionShape3D 부착, 플레이어가 통과 불가
- 씬 로드 시 에러 없음: `building_frame.tscn`이 `building_frame_site.gd` 스크립트를 연결하여 `_ready()`에서 절차적 생성

**구조물 구성:**
- 바닥면: 20m x 20m, 두께 0.3m, 바닥 상단이 y=0
- 기둥 8개: 0.5m x 4.0m x 0.5m, 3x3 그리드 간격 배치 (중앙 제외)
- 보 12개: X방향 6개 + Z방향 6개, 기둥 상단(y=4.0~4.5m)에서 연결
- 슬래브 1개: 20m x 0.2m x 20m, 보 상단(y=4.6m)
- 벽체 5개: 남쪽(출입구 개구부 2m 분할 2개), 북쪽, 동쪽, 서쪽, 높이 3.5m
- 조명: DirectionalLight3D (태양광, 그림자 활성), WorldEnvironment (앰비언트 + 하늘색 배경)

**SOLID 준수:**
- O/L (개방-폐쇄): `BaseSite` 추상 클래스를 상속하여 `BuildingFrameSite` 구현. 새 현장 유형은 `BaseSite`를 상속하면 됨
- L (리스코프 치환): `BuildingFrameSite`는 `BaseSite` 자리에 투명 교체 가능
- get_valid_surfaces(), get_spawn_bounds(), get_site_type() 가상 메서드 구현

---

## 생성된 파일 목록

### Presentation Layer
| 파일 | 클래스명 | 설명 |
|------|---------|------|
| `scripts/presentation/environment/base_site.gd` | BaseSite | 추상 베이스. Node3D 상속. get_valid_surfaces(), get_spawn_bounds(), get_site_type() 가상 메서드 정의 |
| `scripts/presentation/environment/building_frame_site.gd` | BuildingFrameSite | BaseSite 상속. 건물 골조 현장 절차적 생성 (기둥 8, 보 12, 슬래브 1, 벽체 5, 바닥, 조명) |

### Scenes
| 파일 | 설명 |
|------|------|
| `scenes/environment/building_frame.tscn` | 건물 골조 현장 씬. BuildingFrameSite 스크립트 연결 |

---

## 공개 인터페이스

### BaseSite (추상 베이스)

**가상 메서드 (서브클래스 구현 필수):**
| 메서드 | 반환 | 설명 |
|--------|------|------|
| `get_valid_surfaces()` | `Array` | 위험 요소 배치 가능 표면 목록. 각 항목: `{ "node": Node3D, "surface_type": String, "aabb": AABB }` |
| `get_spawn_bounds()` | `AABB` | 배치 가능 전체 영역 |
| `get_site_type()` | `String` | 현장 유형 식별 문자열 |

### BuildingFrameSite

**상속**: BaseSite
**자동 생성 노드 트리:**
```
BuildingFrameSite (Node3D)
  +-- Floor (StaticBody3D)
  +-- Columns (Node3D)
  |     +-- Column_01 ~ Column_08 (StaticBody3D)
  +-- Beams (Node3D)
  |     +-- Beam_01 ~ Beam_12 (StaticBody3D)
  +-- Slabs (Node3D)
  |     +-- Slab_01 (StaticBody3D)
  +-- Walls (Node3D)
  |     +-- Wall_South_Left, Wall_South_Right, Wall_North, Wall_East, Wall_West (StaticBody3D)
  +-- SunLight (DirectionalLight3D)
  +-- SiteEnvironment (WorldEnvironment)
```

---

## 아키텍처 준수 사항

- **레이어**: Presentation Layer (`scripts/presentation/environment/`)에 위치
- **의존 방향**: BaseSite -> Node3D (Godot), BuildingFrameSite -> BaseSite. 상위 레이어 의존 없음
- **확장성**: 새 현장(터널, 교량 등) 추가 시 BaseSite를 상속하고 씬 파일 추가만 필요. ScenarioManager가 `building_frame.tscn`을 SiteContainer에 동적 로드하는 구조

---

## 다음 Phase에서 연결할 사항

1. **ScenarioManager -> SiteContainer**: ScenarioManager가 `scenes/environment/building_frame.tscn`을 메인 씬의 SiteContainer 노드에 동적 인스턴스화
2. **HazardManager -> get_valid_surfaces()**: 위험 요소(크랙 등) 배치 시 BuildingFrameSite.get_valid_surfaces()로 배치 가능한 표면 조회
3. **RandomPlacement -> get_spawn_bounds()**: 위험 요소 랜덤 배치 시 바운딩 박스 참조
4. **WorldEnvironment 충돌 방지**: main.tscn에 이미 WorldEnvironment가 있으므로, BuildingFrameSite 로드 시 기존 것을 비활성화하거나 SiteEnvironment를 제거하는 로직 필요

---

# Senior Dev 구현 리포트 -- Phase 3

## 구현 일자
2026-04-01

## 구현된 Spec ID 목록

| Spec ID | 제목 | 충족 상태 |
|---------|------|----------|
| SPEC-ENV-002 | 크랙 절차적 생성 시스템 | ✅ 구현 완료 |
| SPEC-HAZ-001 | 위험 요소 기본 시스템 (배치 및 상태 관리) | ✅ 구현 완료 |
| SPEC-INP-001 | 조이스틱 기반 이동 | ✅ 구현 완료 |
| SPEC-INP-002 | 컨트롤러 버튼 마킹 | ✅ 구현 완료 |
| SPEC-DAT-002 | 발견율 및 반응 시간 산출 | ✅ 구현 완료 |

### SPEC-ENV-002 충족 상세

**성공 조건 충족:**
- 크랙 생성 요청 시 지정된 표면 위치에 크랙 비주얼이 생성된다 (CrackGenerator.generate_crack_mesh)
- 크랙 파라미터(길이, 폭, 분기 수)를 변경하면 시각적 결과가 달라진다 (랜덤 변동 포함)
- MVP에서 최소 3개의 크랙이 서로 다른 위치에 배치 가능하다 (HazardManager.spawn_hazard 반복 호출)
- 크랙이 구조물 표면에 자연스럽게 부착된다 (position.y = 0.001 오프셋으로 Z-fighting 방지)
- 동일 파라미터로 생성해도 매번 다른 결과가 나온다 (randf_range 기반 절차적 변동)

**절차적 생성 구현:**
- CrackGenerator: 경로 점 생성 -> 방향 랜덤 편향 -> 삼각형 스트립 메시 생성
- 메인 크랙 경로 (8 세그먼트) + 분기 크랙 (4 세그먼트씩)
- 양 끝 테이퍼링 (20% 구간에서 폭 점감)
- 난이도에 따라 색상 혼합도 + 불투명도 + 스케일 조절

### SPEC-HAZ-001 충족 상세

**성공 조건 충족:**
- 위험 요소가 탐지 가능 영역을 가진다 (Area3D + CollisionShape3D, collision_layer=32)
- 위험 요소의 초기 상태가 "미발견(UNDISCOVERED)"이다
- 마킹 이벤트 수신 시 상태가 "발견(DISCOVERED)"으로 변경된다 (BaseHazard.discover())
- 발견 시 시각적 피드백(녹색 하이라이트 + 발광 마커)이 표시된다
- 이미 발견된 위험 요소를 재마킹해도 에러 없이 무시된다 (discover()가 false 반환)
- 현재 씬의 모든 위험 요소 목록을 조회할 수 있다 (get_all_hazards, get_discovered_hazards, get_undiscovered_hazards)
- 위험 요소가 0개인 씬에서 경고 로그 출력 (check_empty_hazards)

**상속 구조:**
- BaseHazard (Area3D) -> CrackHazard -> (향후 CorrosionHazard, LeakHazard 확장)
- SOLID O: 새 유형 추가 시 BaseHazard 상속만으로 확장
- SOLID L: 서브클래스가 BaseHazard 자리에 투명 교체

### SPEC-INP-001 충족 상세

**성공 조건 충족:**
- VR: 왼쪽 조이스틱 전방/좌우 이동, 오른쪽 조이스틱 스냅 턴 (30도 단위, 쿨다운 0.25초)
- 데스크톱: WASD 키보드 이동 (기존 DesktopRigController 유지)
- 이동 속도 설정 가능 (Locomotion.set_speed, 기본 3.0 m/s)
- 충돌 판정: CharacterBody3D.move_and_slide() (데스크톱), 위치 직접 이동 (VR)
- 바닥 위에서만 이동 (중력 적용)
- Locomotion 클래스가 RigInterface에 위임하여 VR/데스크톱 모두 지원

### SPEC-INP-002 충족 상세

**성공 조건 충족:**
- 트리거 버튼(VR) / 마우스 좌클릭(데스크톱) 입력 시 카메라 중심에서 전방으로 레이캐스트 수행
- 광선이 위험 요소(BaseHazard)의 탐지 영역에 적중하면 발견 처리 (MarkingSystem -> HazardManager)
- 광선이 미적중하면 오탐(false positive)으로 기록
- 마킹 성공 시 시각적 피드백 (녹색 하이라이트 + 발견 인디케이터)
- 최대 탐지 거리 설정 가능 (기본 50m)
- 허공 마킹 시 오탐 기록 + 광선 끝점 위치 기록

**마킹 흐름:**
1. 사용자 입력 -> RigInterface.mark_requested 시그널
2. InputManager._on_mark_requested -> MarkingSystem.perform_mark()
3. PhysicsDirectSpaceState3D.intersect_ray로 판정
4. 적중 대상이 BaseHazard이면 mark_succeeded -> HazardManager.attempt_mark_hazard()
5. 미적중이면 mark_failed -> HazardManager.record_false_positive()

### SPEC-DAT-002 충족 상세

**성공 조건 충족:**
- 발견율 = (발견 수 / 전체 수) * 100, 소수점 1자리 (snappedf 사용)
- 반응 시간 = (발견 시각 - 세션 시작 시각), 밀리초 단위
- 미발견 위험 요소의 반응 시간은 -1.0 (미측정)
- 발견율 범위 0.0~100.0 클램프
- 반응 시간 음수 방어 (0.0으로 보정)
- 위험 요소 0개 세션 시 0%로 기록 + 경고 로그
- 실시간 산출: evaluation_updated 시그널로 매 발견 시 갱신
- 세션 종료 시: evaluation_finalized 시그널로 최종 결과 발행

**아키텍처 분리:**
- EvaluationService (Domain, RefCounted): 순수 계산 로직, 씬 트리 비의존
- EvaluationManager (Application, Autoload): 조율, HazardManager 시그널 구독, 타임스탬프 관리

---

## 생성된 파일 목록

### 프로젝트 설정
| 파일 | 변경 내용 |
|------|----------|
| `project.godot` | HazardManager, InputManager, EvaluationManager Autoload 등록 추가 |

### Domain Layer
| 파일 | 클래스명 | 설명 |
|------|---------|------|
| `scripts/domain/models/hazard_data.gd` | HazardData | Resource. 위험 요소 설정 데이터 (ID, 유형, 난이도, 위치, 크랙 파라미터) |
| `scripts/domain/services/evaluation_service.gd` | EvaluationService | RefCounted. 순수 평가 계산 (발견율, 반응 시간, 평균 반응 시간) |
| `scripts/domain/services/hazard_rules.gd` | HazardRules | RefCounted. 위험 요소 판정 규칙 (탐지 범위, 난이도 비주얼 파라미터) |

### Application Layer
| 파일 | 클래스명 | 설명 |
|------|---------|------|
| `scripts/application/hazard_manager.gd` | HazardManager | Autoload. 위험 요소 생성/관리/상태 추적, 발견 처리 |
| `scripts/application/input_manager.gd` | InputManager | Autoload. VR/데스크톱 입력 추상화, MarkingSystem/Locomotion 관리 |
| `scripts/application/evaluation_manager.gd` | EvaluationManager | Autoload. 발견율/반응시간 실시간 산출, EvaluationService 위임 |

### Presentation Layer
| 파일 | 클래스명 | 설명 |
|------|---------|------|
| `scripts/presentation/hazards/base_hazard.gd` | BaseHazard | Area3D 상속. 위험 요소 추상 베이스 (상태 관리, 가상 메서드) |
| `scripts/presentation/hazards/crack_hazard.gd` | CrackHazard | BaseHazard 상속. 크랙 위험 요소 (절차적 비주얼, 난이도 조절) |
| `scripts/presentation/hazards/crack_generator.gd` | CrackGenerator | RefCounted. 크랙 메시 절차적 생성 유틸리티 |
| `scripts/presentation/input/locomotion.gd` | Locomotion | RefCounted. 이동 시스템 (속도 관리, 스냅 턴, RigInterface 위임) |
| `scripts/presentation/input/marking_system.gd` | MarkingSystem | Node. 레이캐스트 마킹 (PhysicsDirectSpaceState3D 기반) |

### Scenes
| 파일 | 설명 |
|------|------|
| `scenes/hazards/crack_hazard.tscn` | 크랙 위험 요소 씬 (Area3D, collision_layer=32) |

---

## 공개 인터페이스

### HazardManager (Autoload)

**시그널:**
| 시그널 | 파라미터 | 발행 시점 |
|--------|---------|----------|
| `hazard_spawned` | `hazard: BaseHazard` | 위험 요소 생성 시 |
| `hazard_discovered` | `hazard: BaseHazard` | 위험 요소 발견 시 |
| `false_positive` | `position: Vector3, direction: Vector3` | 오탐 마킹 시 |
| `all_hazards_discovered` | 없음 | 모든 위험 요소 발견 시 |

**메서드:**
| 메서드 | 반환 | 설명 |
|--------|------|------|
| `spawn_hazard(data)` | `BaseHazard` | 위험 요소 생성 |
| `attempt_mark_hazard(hazard, position)` | `MarkingResult` | 마킹 시도 처리 |
| `record_false_positive(position, direction)` | `MarkingResult` | 오탐 기록 |
| `get_all_hazards()` | `Array[BaseHazard]` | 전체 위험 요소 |
| `get_discovered_hazards()` | `Array[BaseHazard]` | 발견된 위험 요소 |
| `get_undiscovered_hazards()` | `Array[BaseHazard]` | 미발견 위험 요소 |
| `get_discovery_rate()` | `float` | 현재 발견율 (0~100) |
| `clear_hazards()` | `void` | 모든 위험 요소 제거 |

### InputManager (Autoload)

**시그널:**
| 시그널 | 파라미터 | 발행 시점 |
|--------|---------|----------|
| `mark_requested` | `ray_origin, ray_direction: Vector3` | 마킹 입력 발생 시 |
| `movement_input` | `direction: Vector3, delta: float` | 이동 입력 발생 시 |
| `snap_turn_input` | `degrees: float` | 스냅 턴 입력 발생 시 |

**속성:**
| 속성 | 타입 | 설명 |
|------|------|------|
| `marking_system` | `MarkingSystem` | 마킹 시스템 인스턴스 |
| `locomotion` | `Locomotion` | 이동 시스템 인스턴스 |

### EvaluationManager (Autoload)

**시그널:**
| 시그널 | 파라미터 | 발행 시점 |
|--------|---------|----------|
| `evaluation_updated` | `discovery_rate, avg_reaction_ms: float` | 발견 시 갱신 |
| `evaluation_finalized` | `discovery_rate, avg_reaction_ms: float, reaction_times: Dictionary` | 세션 종료 시 |

**메서드:**
| 메서드 | 반환 | 설명 |
|--------|------|------|
| `start_evaluation(hazard_count)` | `void` | 평가 시작 |
| `finalize_evaluation()` | `void` | 평가 종료 및 결과 확정 |
| `get_discovery_rate()` | `float` | 현재 발견율 |
| `get_avg_reaction_time_ms()` | `float` | 현재 평균 반응 시간 |
| `get_reaction_time(hazard_id)` | `float` | 특정 위험 요소 반응 시간 |

### BaseHazard (추상 베이스)

**시그널:**
| 시그널 | 파라미터 | 설명 |
|--------|---------|------|
| `state_changed` | `new_state: HazardState` | 상태 변경 시 |

**메서드:**
| 메서드 | 반환 | 설명 |
|--------|------|------|
| `discover()` | `bool` | 발견 처리 (중복 시 false) |
| `is_discovered()` | `bool` | 발견 여부 |
| `get_hazard_data()` | `HazardData` | 데이터 반환 |
| `apply_hazard_data(data)` | `void` | 데이터 적용 |

**가상 메서드 (서브클래스 오버라이드):**
| 메서드 | 설명 |
|--------|------|
| `_apply_difficulty()` | 난이도에 따른 비주얼 조정 |
| `_show_discovered_feedback()` | 발견 시 피드백 |

### EvaluationService (Domain, RefCounted)

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `calculate_discovery_rate(discovered, total)` | `float` | 발견율 (0~100, 소수점 1자리) |
| `calculate_reaction_time(start_ms, discovery_ms)` | `float` | 개별 반응 시간 (ms) |
| `calculate_avg_reaction_time(times)` | `float` | 평균 반응 시간 (ms) |

### HazardRules (Domain, RefCounted)

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `is_within_detection_range(player_pos, hazard_pos, range)` | `bool` | 탐지 범위 판정 |
| `calculate_difficulty_visual_params(difficulty)` | `Dictionary` | 난이도 비주얼 파라미터 (scale, opacity, color_blend) |

### CrackGenerator (RefCounted)

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `generate_crack_mesh(length, width, branches)` | `ArrayMesh` | 크랙 메시 절차적 생성 |
| `create_crack_material(opacity, color_blend)` | `StandardMaterial3D` | 크랙 머티리얼 생성 |

### Locomotion (RefCounted)

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `bind_rig(rig)` | `void` | 리그 연결 |
| `apply_movement(direction, delta)` | `void` | 이동 적용 |
| `apply_snap_turn(degrees)` | `void` | 스냅 턴 |
| `set_speed(speed)` | `void` | 이동 속도 변경 |
| `is_grounded()` | `bool` | 바닥 접촉 여부 |

---

## 아키텍처 준수 사항

- **레이어 분리**:
  - Domain (evaluation_service.gd, hazard_rules.gd, hazard_data.gd): Godot 노드 비의존, RefCounted/Resource만 사용
  - Application (hazard_manager.gd, input_manager.gd, evaluation_manager.gd): Autoload, 유스케이스 조율
  - Presentation (base_hazard.gd, crack_hazard.gd, crack_generator.gd, locomotion.gd, marking_system.gd): 시각화/입력

- **의존 방향**:
  - Application -> Domain (EvaluationManager -> EvaluationService, HazardManager -> HazardRules)
  - Application -> Presentation (InputManager -> MarkingSystem/Locomotion, HazardManager -> BaseHazard)
  - Presentation -> Domain (CrackHazard -> HazardRules)
  - 역방향 의존 없음 (Domain은 상위 레이어에 의존하지 않음)

- **SOLID 원칙**:
  - S: 각 클래스가 단일 책임 (EvaluationService=계산, EvaluationManager=조율, MarkingSystem=레이캐스트)
  - O: BaseHazard 상속으로 새 위험 요소 유형 추가 가능
  - L: CrackHazard가 BaseHazard 자리에 투명 교체
  - I: hazard_discovered, false_positive, evaluation_updated 등 이벤트별 시그널 분리
  - D: HazardManager는 BaseHazard 추상 타입에 의존, InputManager는 RigInterface에 의존

- **시그널 기반 통신**:
  - RigInterface.mark_requested -> InputManager -> MarkingSystem -> HazardManager -> EvaluationManager
  - 각 레이어 간 시그널로 느슨하게 결합

---

## 다음 Phase에서 연결할 사항

1. **ScenarioManager -> HazardManager**: 시나리오 JSON의 hazards 배열을 순회하며 HazardManager.spawn_hazard() 호출
2. **SessionManager -> EvaluationManager**: 세션 시작 시 start_evaluation(), 종료 시 finalize_evaluation() 호출
3. **SessionManager -> SessionData**: EvaluationManager의 결과를 SessionData에 반영하여 SessionLogger로 저장
4. **BehaviorLogger**: InputManager의 movement_input, mark_requested 시그널을 구독하여 행동 로깅
5. **EventLogger**: HazardManager의 hazard_discovered, false_positive 시그널 구독
6. **ScenarioManager -> RandomPlacement**: SPEC-SCN-002 위험 요소 랜덤 배치 시 BuildingFrameSite.get_valid_surfaces() 활용
7. **VR 컨트롤러 연결 끊김 처리**: SPEC-INP-001 예외 처리 — 재연결 시 자동 복구 메시지

---

# Senior Dev 구현 리포트 -- Phase 4

## 구현 일자
2026-04-01

## 구현된 Spec ID 목록

| Spec ID | 제목 | 충족 상태 |
|---------|------|----------|
| SPEC-SCN-002 | 위험 요소 랜덤 배치 | ✅ 구현 완료 |
| SPEC-SES-003 | 세션 흐름 제어 (시작-진행-종료) | ✅ 구현 완료 |

### SPEC-SCN-002 충족 상세

**성공 조건 충족:**
- 시나리오 설정에서 `random_placement=true`일 때 위험 요소가 랜덤 위치에 배치된다
- BaseSite.get_valid_surfaces()를 활용하여 구조물 표면 위에만 배치 (기둥, 벽, 보, 슬래브 표면)
- `random_seed`를 지정하면 RandomNumberGenerator.seed를 설정하여 동일한 배치가 재현된다
- `min_spacing` 파라미터로 위험 요소 간 최소 간격을 보장 (distance_to 기반 검증)
- `random_config`에서 `hazard_count`, `types`, `min_spacing`, `difficulty_range` 지정 가능

**예외 처리:**
- 유효한 배치 위치가 부족할 경우 가능한 만큼만 배치하고 실패한 개수를 경고 로그로 출력
- 배치 시도당 최대 50회 반복 후 건너뜀 (무한 루프 방지)
- `random_seed=0`이면 시스템 시간 기반 시드 자동 생성

**검증 로직 (ScenarioValidator):**
- `random_config.hazard_count` 양의 정수 검증
- `random_config.types` 배열 존재 및 유효 타입 검증
- `random_config.min_spacing` 0 이상 검증
- `random_config.difficulty_range` [min, max] 형식 및 0.0~1.0 범위 검증

### SPEC-SES-003 충족 상세

**성공 조건 충족:**
- 세션 상태가 `INITIALIZING -> SUBJECT_INPUT -> RUNNING -> RESULT -> ENDED` 순서로 전환된다
- 각 상태 전환 시 `state_changed(old, new)` 시그널이 발행된다
- 초기화: 시나리오 로드, 위험 요소 배치 (ScenarioManager.apply_scenario)
- 정보입력: SubjectInfoUI.info_submitted 시그널 구독, 피험자 정보 대기
- 진행: SessionTimer 시작, EvaluationManager.start_evaluation() 호출
- 결과: SessionLogger.save_session_result() 호출, EvaluationManager.finalize_evaluation() 호출
- 종료: proceed_to_next()로 새 세션 또는 완전 종료 선택

**자동 종료 트리거:**
- SPEC-SES-002: 타이머 만료 시 `end_session("time_up")` 자동 호출
- SPEC-HAZ-001: 모든 위험 요소 발견 시 `end_session("all_discovered")` 자동 호출
- 수동 조기 종료: `request_early_end()` -> `end_session("manual")`

**상태 전이 방어:**
- 유효하지 않은 상태 전이 시도 시 무시하고 경고 로그 출력
- `_valid_transitions` Dictionary로 허용된 전이만 실행
- 비정상 종료(RUNNING 아닌 상태에서 end_session 호출) 시 경고 후 무시

---

## 생성된 파일 목록

### 프로젝트 설정
| 파일 | 변경 내용 |
|------|----------|
| `project.godot` | ScenarioManager, SessionManager Autoload 등록 추가 |

### Domain Layer
| 파일 | 클래스명 | 설명 |
|------|---------|------|
| `scripts/domain/models/scenario_data.gd` | ScenarioData | Resource. 시나리오 설정 데이터 (ID, 현장유형, 시간제한, 랜덤배치 설정, 위험요소 목록) |
| `scripts/domain/services/scenario_validator.gd` | ScenarioValidator | RefCounted. 시나리오 JSON 스키마 검증 (필수 필드, 타입, 범위, random_config 검증) |

### Application Layer
| 파일 | 클래스명 | 설명 |
|------|---------|------|
| `scripts/application/scenario_manager.gd` | ScenarioManager | Autoload. 시나리오 로딩/검증/랜덤 배치/적용 |
| `scripts/application/session_manager.gd` | SessionManager | Autoload. 세션 상태 머신, 타이머 연동, 자동 종료 |

### Resources
| 파일 | 설명 |
|------|------|
| `resources/scenarios/mvp_test_01.json` | MVP 테스트 시나리오 (크랙 3개, 300초, random_seed=42) |

---

## 공개 인터페이스

### ScenarioManager (Autoload)

**시그널:**
| 시그널 | 파라미터 | 발행 시점 |
|--------|---------|----------|
| `scenario_loaded` | `data: ScenarioData` | 시나리오 로드 완료 시 |
| `scenario_load_failed` | `error: String` | 시나리오 로드 실패 시 |
| `hazards_placed` | 없음 | 위험 요소 배치 완료 시 |

**메서드:**
| 메서드 | 반환 | 설명 |
|--------|------|------|
| `load_scenario(path)` | `ScenarioData` | JSON 파일 로드 및 검증 |
| `load_default_scenario()` | `ScenarioData` | 기본 시나리오 로드 |
| `validate_scenario(data)` | `Array[String]` | 스키마 검증 (에러 목록) |
| `generate_random_placement(config, site)` | `Array[HazardData]` | 랜덤 배치 생성 |
| `apply_scenario()` | `void` | 시나리오를 씬에 적용 |
| `get_site_type()` | `String` | 현장 유형 반환 |

### SessionManager (Autoload)

**시그널:**
| 시그널 | 파라미터 | 발행 시점 |
|--------|---------|----------|
| `state_changed` | `old: SessionState, new: SessionState` | 상태 전환 시 |
| `session_started` | 없음 | 시뮬레이션 진행 시작 시 |
| `session_ended` | `reason: String` | 세션 종료 시 |
| `subject_info_submitted` | `data: SubjectData` | 피험자 정보 제출 시 |
| `timer_updated` | `remaining_seconds: float` | 매초 타이머 갱신 시 |

**메서드:**
| 메서드 | 반환 | 설명 |
|--------|------|------|
| `start_new_session()` | `void` | 새 세션 시작 |
| `submit_subject_info(data)` | `void` | 피험자 정보 제출 -> RUNNING |
| `end_session(reason)` | `void` | 세션 종료 -> RESULT |
| `request_early_end()` | `void` | 조기 종료 요청 |
| `proceed_to_next(start_new)` | `void` | 결과 -> 다음 단계 |
| `get_elapsed_time()` | `float` | 경과 시간 (ms) |
| `get_state_name()` | `String` | 현재 상태 이름 |

**상태 열거형 (SessionState):**
| 상태 | 설명 |
|------|------|
| `INITIALIZING` | 씬 로드, 시나리오 적용 |
| `SUBJECT_INPUT` | 피험자 정보 입력 대기 |
| `RUNNING` | 시뮬레이션 진행 중 |
| `RESULT` | 결과 표시/저장 |
| `ENDED` | 종료 |

### ScenarioValidator (Domain, RefCounted)

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `validate(data)` | `Array[String]` | 시나리오 데이터 검증 (빈 배열이면 유효) |

### ScenarioData (Domain, Resource)

| 속성 | 타입 | 설명 |
|------|------|------|
| `scenario_id` | `String` | 시나리오 고유 ID |
| `site_type` | `String` | 현장 유형 키 |
| `time_limit_seconds` | `int` | 시간 제한 (초) |
| `random_placement` | `bool` | 랜덤 배치 모드 여부 |
| `random_seed` | `int` | 랜덤 시드 |
| `hazards` | `Array[HazardData]` | 위험 요소 목록 |
| `random_config` | `Dictionary` | 랜덤 배치 설정 |

---

## 아키텍처 준수 사항

- **레이어 분리**:
  - Domain (scenario_data.gd, scenario_validator.gd): Godot 노드 비의존, Resource/RefCounted만 사용
  - Application (scenario_manager.gd, session_manager.gd): Autoload, 유스케이스 조율
  - Presentation (SubjectInfoUI, SessionTimer): 기존 UI와 시그널 기반 연동

- **의존 방향**:
  - Application -> Domain (ScenarioManager -> ScenarioValidator, ScenarioData)
  - Application -> Application (SessionManager -> ScenarioManager, HazardManager, EvaluationManager)
  - Presentation -> Application (SubjectInfoUI.info_submitted -> SessionManager)
  - 역방향 의존 없음

- **SOLID 원칙**:
  - S: ScenarioManager=시나리오 관리, SessionManager=세션 생명주기, ScenarioValidator=검증만
  - O: ScenarioValidator.VALID_SITE_TYPES/VALID_HAZARD_TYPES 확장으로 새 유형 대응
  - L: ScenarioData가 고정/랜덤 모드 모두 동일 인터페이스
  - I: scenario_loaded/scenario_load_failed, state_changed/session_started/session_ended 시그널 분리
  - D: ScenarioManager는 BaseSite 추상에 의존, SessionManager는 SessionData(Domain)에 의존

- **시그널 기반 통신**:
  - GameManager.game_ready -> SessionManager.start_new_session (향후 연결)
  - SubjectInfoUI.info_submitted -> SessionManager.submit_subject_info
  - SessionTimer.timer_expired -> SessionManager.end_session("time_up")
  - HazardManager.all_hazards_discovered -> SessionManager.end_session("all_discovered")
  - SessionManager.session_ended -> SessionLogger.save_session_result

---

## 다음 Phase에서 연결할 사항

1. **GameManager -> SessionManager**: game_ready 시그널에서 SessionManager.start_new_session() 자동 호출
2. **ResultUI -> SessionManager**: 결과 화면에서 SessionManager.proceed_to_next() 호출
3. **BehaviorLogger**: SessionManager.session_started 시그널 구독하여 로깅 시작/종료
4. **EventLogger**: SessionManager.state_changed 구독하여 상태 전환 타임스탬프 기록
5. **SiteContainer 동적 로딩**: ScenarioManager.get_site_type()에 따라 적절한 현장 씬 동적 로드
6. **고정 배치 모드 테스트**: random_placement=false인 시나리오 JSON으로 위험 요소 수동 배치 테스트

---

# Senior Dev 구현 리포트 -- Phase 5: 시각 품질 개선

## 구현 일자
2026-04-01

## 개선 요약

건물 골조 현장의 시각 품질을 3개 축으로 개선하였다:
1. PBR 콘크리트 텍스처 적용 (프로시저럴 NoiseTexture2D 기반)
2. 크랙 비주얼을 Decal 노드 기반으로 교체 (SurfaceTool 메시 -> Decal 투영)
3. 환경 조명 전면 개선 (SSAO, SSIL, ProceduralSky, Fog, Glow, ACES 톤매핑)

---

## 1. PBR 콘크리트 텍스처 시스템

### ConcreteMaterial 팩토리 (신규)

`scripts/presentation/environment/concrete_material.gd`

외부 이미지 파일 없이 NoiseTexture2D + FastNoiseLite만으로 PBR 콘크리트 머티리얼을 생성하는 팩토리 클래스.

**머티리얼 유형 3가지:**

| 메서드 | 용도 | Albedo 색상 | Roughness | UV Scale |
|--------|------|-------------|-----------|----------|
| `create_concrete_material()` | 기둥, 벽체, 슬래브 | Color(0.75, 0.73, 0.70) | 0.88 | 2.0x |
| `create_floor_material()` | 바닥 | Color(0.62, 0.60, 0.58) | 0.95 | 3.0x |
| `create_rebar_material()` | 보, 철근 구조물 | Color(0.80, 0.78, 0.76) | 0.82 | 1.5x |

**PBR 텍스처 구성:**

| 채널 | 노이즈 유형 | 주파수 | 프랙탈 | 해상도 |
|------|------------|--------|--------|--------|
| Albedo | Simplex Smooth FBM | 0.015 | 4 octave | 256px |
| Roughness | Cellular (Distance) | 0.025 | 없음 | 256px |
| Normal | Simplex Smooth FBM | 0.03 | 3 octave | 256px |

- Albedo: Gradient 색상 램프(Color(0.65,0.63,0.61) ~ Color(0.85,0.83,0.80))로 회색 톤 범위 제한
- Normal: as_normal_map=true, bump_strength=4.0으로 미세한 표면 요철 표현
- 모든 텍스처: seamless=true, seamless_blend_skirt=0.15로 타일링 경계 제거

**성능 고려:**
- 텍스처 해상도 256px (Quest 72fps 유지 목표)
- 머티리얼 캐싱: BuildingFrameSite._init_materials()에서 3종 머티리얼을 1회 생성 후 모든 구조물이 공유 -> 드로우콜 절감

### BuildingFrameSite 적용

`scripts/presentation/environment/building_frame_site.gd` 수정:

- `_init_materials()` 추가: `_ready()`에서 PBR 머티리얼 사전 캐시
- `_create_structural_element_pbr()` / `_create_box_mesh_pbr()` 추가: PBR 머티리얼을 받는 새 헬퍼
- 기존 단색 헬퍼(`_create_structural_element`, `_create_box_mesh`) 유지 (폴백/하위호환)
- 모든 구조물 생성 호출을 PBR 버전으로 전환:
  - 기둥 8개, 슬래브 1개, 벽체 5개: `_mat_concrete`
  - 보 12개: `_mat_rebar` (약간 더 밝은 톤)
  - 바닥 1개: `_mat_floor` (더 어둡고 거친)

---

## 2. 크랙 비주얼 Decal 교체

### CrackTextureGenerator (신규)

`scripts/presentation/hazards/crack_texture_generator.gd`

Decal에 사용할 크랙 패턴 텍스처를 프로시저럴로 생성하는 유틸리티.

**핵심 기법:**
- Cellular 노이즈 + `RETURN_DISTANCE2_SUB`: 셀 경계에서 얇은 선을 생성하여 크랙 패턴 표현
- Gradient 색상 램프: 셀 경계(값 0.0~0.15) = 어두운 크랙색(불투명), 셀 내부(값 0.35~1.0) = 완전 투명
- 노멀맵: 동일 Cellular 패턴에 bump_strength=8.0으로 크랙 깊이감 표현

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `create_crack_albedo_texture()` | `NoiseTexture2D` | 크랙 albedo (Cellular, Gradient 투명 처리) |
| `create_crack_normal_texture()` | `NoiseTexture2D` | 크랙 노멀맵 (깊이감) |

### CrackHazard Decal 전환

`scripts/presentation/hazards/crack_hazard.gd` 수정:

**변경 전:** MeshInstance3D + SurfaceTool 기반 삼각형 스트립 메시
**변경 후:** Decal 노드 기반 표면 투영

**주요 변경:**
- `_crack_visual: MeshInstance3D` -> `_crack_decal: Decal`
- `_generator: CrackGenerator` -> `_texture_generator: CrackTextureGenerator`
- `_build_visual()`: Decal.new() 생성, texture_albedo/texture_normal 설정, upper_fade/lower_fade/normal_fade 설정
- `_apply_difficulty()`: Decal.size(XZ) 스케일 + Decal.modulate(alpha) 투명도로 난이도 표현
- `_show_discovered_feedback()`: Decal.modulate를 녹색으로 변경
- `_rebuild_visual()`: 텍스처 재생성(랜덤 시드 변경)

**유지된 인터페이스 (하위호환):**
- `apply_hazard_data(data: HazardData)` 시그니처 동일
- `_apply_difficulty()` 시그니처 동일
- `_show_discovered_feedback()` 시그니처 동일
- `_build_collision()`, `_build_discovered_indicator()` 변경 없음
- `crack_length`, `crack_width`, `crack_branches` 프로퍼티 유지
- BaseHazard 상속 구조 및 시그널 유지

**Decal 이점:**
- Z-fighting 문제 근본 해결 (메시 대신 투영 방식)
- 구조물 곡면/모서리에도 자연스럽게 표시 가능
- GPU 프로젝션 기반으로 메시 생성 오버헤드 제거

---

## 3. 환경 조명 개선

### 조명 구성

`scripts/presentation/environment/building_frame_site.gd`의 `_create_lighting()` 전면 개선:

**DirectionalLight3D (태양광):**
- 에너지: 1.2 -> 1.3
- 색상: Color(1.0, 0.98, 0.95) -> Color(1.0, 0.96, 0.90) (약간 더 따뜻한 톤)
- shadow_blur = 1.0 (부드러운 그림자)
- directional_shadow_max_distance = 50.0

**FillLight (보조광, 신규):**
- 반대편 방향(-150도), 에너지 0.3, 쿨톤 Color(0.85, 0.90, 1.0)
- 그림자 없음 (성능 절감)
- 그림자 영역의 디테일 보존

**WorldEnvironment:**

| 설정 | 변경 전 | 변경 후 |
|------|---------|---------|
| 배경 | BG_COLOR (단색 하늘색) | BG_SKY (ProceduralSkyMaterial) |
| 앰비언트 소스 | AMBIENT_SOURCE_COLOR | AMBIENT_SOURCE_SKY |
| 톤매핑 | ACES | ACES (유지, tonemap_white=6.0 추가) |
| SSAO | 비활성 | 활성 (radius=1.0, intensity=2.0) |
| SSIL | 비활성 | 활성 (radius=5.0, intensity=1.0) |
| Glow | 비활성 | 활성 (intensity=0.3, SOFTLIGHT) |
| Fog | 비활성 | 활성 (density=0.002, 대기 원근감) |
| 반사광 | 없음 | REFLECTION_SOURCE_SKY |

**ProceduralSkyMaterial 설정:**
- sky_top: Color(0.35, 0.55, 0.85), sky_horizon: Color(0.65, 0.75, 0.88)
- ground_bottom: Color(0.35, 0.30, 0.25), ground_horizon: Color(0.65, 0.70, 0.72)
- radiance_size = RADIANCE_SIZE_256 (Quest 성능 고려)

### main.tscn 동기화

`scenes/main.tscn` 업데이트:
- WorldEnvironment에 동일 Environment 설정 (SSAO, SSIL, ProceduralSky, ACES, Glow, Fog)
- DirectionalLight3D에 따뜻한 톤 + 그림자 품질 설정
- BuildingFrameSite가 자체 WorldEnvironment를 생성하므로, main.tscn의 설정은 BuildingFrameSite 미사용 시 폴백

---

## 생성된 파일 목록

### Presentation Layer (신규)
| 파일 | 클래스명 | 설명 |
|------|---------|------|
| `scripts/presentation/environment/concrete_material.gd` | ConcreteMaterial | PBR 콘크리트 머티리얼 팩토리. NoiseTexture2D 기반 albedo/roughness/normal 생성 |
| `scripts/presentation/hazards/crack_texture_generator.gd` | CrackTextureGenerator | Decal용 크랙 텍스처 생성기. Cellular 노이즈 + Gradient 기반 |

### Presentation Layer (수정)
| 파일 | 변경 내용 |
|------|----------|
| `scripts/presentation/environment/building_frame_site.gd` | PBR 머티리얼 적용, 조명 전면 개선 (SSAO, SSIL, ProceduralSky, FillLight) |
| `scripts/presentation/hazards/crack_hazard.gd` | SurfaceTool 메시 -> Decal 기반 크랙 비주얼로 전환 |

### Scenes (수정)
| 파일 | 변경 내용 |
|------|----------|
| `scenes/main.tscn` | WorldEnvironment에 SSAO/SSIL/ProceduralSky/Glow/Fog 설정 추가 |
| `scenes/hazards/crack_hazard.tscn` | 변경 없음 (스크립트 레벨에서 Decal 전환) |

---

## 공개 인터페이스

### ConcreteMaterial (RefCounted)

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `create_concrete_material()` | `StandardMaterial3D` | 일반 콘크리트 PBR (기둥, 벽체, 슬래브) |
| `create_floor_material()` | `StandardMaterial3D` | 바닥용 PBR (어둡고 거친) |
| `create_rebar_material()` | `StandardMaterial3D` | 보/철근 PBR (밝고 매끈) |

### CrackTextureGenerator (RefCounted)

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `create_crack_albedo_texture()` | `NoiseTexture2D` | Decal albedo (Cellular + Gradient 투명) |
| `create_crack_normal_texture()` | `NoiseTexture2D` | Decal 노멀맵 (깊이감) |

### CrackHazard (변경된 내부)

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 비주얼 노드 | `_crack_visual: MeshInstance3D` | `_crack_decal: Decal` |
| 생성기 | `_generator: CrackGenerator` | `_texture_generator: CrackTextureGenerator` |
| 난이도 조절 | mesh.scale + material.albedo_color.a | Decal.size + Decal.modulate.a |
| 발견 피드백 | material_override 교체 | Decal.modulate 색상 변경 |

**공개 인터페이스 변경 없음** (BaseHazard 계약 유지):
- `apply_hazard_data(data)`, `discover()`, `is_discovered()`, `state_changed` 시그널 등 모두 동일

---

## 아키텍처 준수 사항

- **레이어 분리**: ConcreteMaterial, CrackTextureGenerator 모두 Presentation Layer에 위치. Domain/Application 레이어에 의존 없음
- **의존 방향**: BuildingFrameSite -> ConcreteMaterial, CrackHazard -> CrackTextureGenerator. 역방향 없음
- **개방-폐쇄**: ConcreteMaterial을 확장하여 새 머티리얼 유형 추가 가능. CrackTextureGenerator도 독립 확장 가능
- **리스코프 치환**: CrackHazard는 여전히 BaseHazard 자리에 투명 교체 가능 (Decal 전환이 외부 인터페이스에 영향 없음)
- **성능**: 텍스처 256px, 머티리얼 캐싱, Sky radiance 256으로 Quest VR 성능 고려

---

## 다음 Phase에서 연결할 사항

1. **WorldEnvironment 충돌 해소**: main.tscn과 BuildingFrameSite 양쪽에 WorldEnvironment가 있으므로, ScenarioManager가 현장 로드 시 main.tscn의 WorldEnvironment를 비활성화하는 로직 필요
2. **Decal cull_mask 설정**: 크랙 Decal이 특정 구조물에만 투영되도록 cull_mask 레이어 분리 고려
3. **LOD 시스템**: 원거리 구조물에 대해 텍스처 해상도를 동적으로 낮추는 LOD 검토
4. **VR 성능 프로파일링**: Quest 실기기에서 SSAO/SSIL 활성 상태의 프레임 레이트 측정 후, 필요 시 비활성화 옵션 제공

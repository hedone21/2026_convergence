# VR 건설 현장 안전 점검 시뮬레이션

건설 현장 관리자의 위험 요소 탐지 역량을 평가하기 위한 VR 시뮬레이션입니다.
대학 연구 프로젝트로 개발되었으며, 피험자가 VR 환경에서 크랙, 붕괴 조짐 등의 위험 요소를 발견하고 마킹하는 과정을 측정합니다.

## 기술 스택

- Godot 4.3 (GDScript)
- OpenXR (Meta Quest 시리즈)
- 렌더러: GL Compatibility

## 요구사항

- [Godot 4.3](https://godotengine.org/download/) 이상
- VR 실행 시: Meta Quest 시리즈 + Quest Link 또는 Air Link
- 데스크톱 모드에서도 실행 가능 (키보드/마우스)

## 실행 방법

### 에디터에서 실행

```bash
# 프로젝트 열기
godot --editor --path .

# 에디터 없이 바로 실행
godot --path .
```

### VR 실행

1. Meta Quest를 PC에 연결 (Quest Link / Air Link)
2. SteamVR 또는 Oculus 런타임 실행
3. Godot 에디터에서 F5 또는 커맨드라인으로 실행

### 데스크톱 모드

VR 디바이스 없이 실행하면 데스크톱 리그로 자동 전환됩니다. 별도 설정 없이 그대로 실행하면 됩니다.

```bash
godot --path .
```

| 조작 | 키 |
|------|-----|
| 이동 | W / A / S / D |
| 시점 회전 | 마우스 |
| 위험 요소 마킹 | 마우스 좌클릭 |
| 마우스 커서 해제 | ESC |
| 마우스 커서 재캡처 | 화면 좌클릭 |

## 사용 흐름

1. **피험자 정보 입력** - ID와 경력 연수를 입력
2. **시뮬레이션 진행** - 건물 골조 현장을 탐색하며 위험 요소를 찾아 마킹
3. **결과 기록** - 발견율, 반응 시간 등이 `data/sessions/`에 자동 저장

## 프로젝트 구조

```
convergence/
├── scenes/            # 씬 파일 (.tscn)
│   ├── main.tscn      # 메인 씬
│   ├── environment/   # 건설 현장 환경
│   ├── hazards/       # 위험 요소
│   ├── ui/            # UI (피험자 정보 입력 등)
│   └── vr_rig/        # VR/데스크톱 리그
├── scripts/           # GDScript 소스
│   ├── application/   # 매니저 (GameManager, SessionManager 등)
│   ├── domain/        # 도메인 모델 및 서비스
│   ├── infrastructure/# 로깅, 데이터 저장
│   └── presentation/  # UI, VR, 환경, 위험 요소 렌더링
├── data/sessions/     # 세션별 로그 데이터 (CSV/JSON)
├── tests/             # GUT 기반 테스트
├── docs/              # 요구사항, 스펙, 아키텍처 문서
└── resources/         # 리소스 (머티리얼, 텍스처 등)
```

## 테스트

[GUT](https://github.com/bitwes/Gut) 프레임워크를 사용합니다.

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

## 라이선스

본 프로젝트는 대학 연구 목적으로 개발되었습니다.

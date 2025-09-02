# 📁 BossPong 프로젝트 구조

## 프로젝트 개요
PingFighter (핑파이터)는 Python/Pygame 기반의 아케이드 스타일 핑퐁 게임입니다.
보스 배틀, 파워업, 특수 능력 시스템을 포함한 확장된 게임플레이를 제공합니다.

## 🏗️ 리팩토링 진행 상태
- ✅ 유틸리티 모듈 분리 완료
- ✅ 렌더링 시스템 모듈화 완료  
- ✅ 게임 로직 분리 진행 중
- 🔄 메인 파일 통합 대기

## 📂 디렉토리 구조

```
bosspong/
│
├── 📄 pingfighter.py          # [레거시] 메인 게임 파일 (21,988줄) - READ ONLY
├── 📄 CLAUDE.md               # Claude Code 가이드라인
├── 📄 README.md               # 프로젝트 문서
├── 📄 requirements.txt        # 기본 의존성
├── 📄 requirements_ai.txt     # AI 관련 의존성
├── 📄 PingFighter.spec        # PyInstaller 설정
│
├── 🎮 게임 코어 모듈/
│   ├── 📁 core/              # 핵심 시스템
│   ├── 📁 entities/          # 게임 객체 (ball, paddle, boss)
│   ├── 📁 managers/          # 시스템 매니저
│   └── 📁 game_logic/        # 게임 로직
│       ├── draw_objects_module.py  # [레거시] 렌더링 (2,894줄)
│       ├── main_loop_module.py     # [레거시] 메인 루프 (1,116줄)
│       ├── 🆕 game_loop.py        # 리팩토링된 게임 루프
│       ├── 🆕 game_config.py      # 게임 설정 관리
│       └── 🆕 game_events.py      # 이벤트 시스템
│
├── 🎨 렌더링 시스템/ [신규]
│   └── 📁 rendering/
│       ├── 🆕 render_manager.py   # 통합 렌더 매니저
│       ├── 🆕 ball_renderer.py    # 공 렌더링
│       ├── 🆕 paddle_renderer.py  # 패들 렌더링
│       ├── 🆕 ui_renderer.py      # UI 렌더링
│       └── 🆕 effect_renderer.py  # 이펙트 렌더링
│
├── 🛠️ 유틸리티/ [신규]
│   └── 📁 utils/
│       ├── 🆕 color_utils.py      # 색상 유틸리티
│       ├── 🆕 math_utils.py       # 수학 함수
│       ├── 🆕 draw_utils.py       # 그리기 도우미
│       ├── 🆕 particle_utils.py   # 파티클 시스템
│       └── 🆕 game_constants.py   # 게임 상수
│
├── 🎮 게임 시스템/
│   ├── 📁 modes/             # 게임 모드
│   ├── 📁 stages/            # 스테이지별 설정
│   ├── 📁 events/            # 스테이지 이벤트
│   ├── 📁 items/             # 아이템 아이콘 (PNG)
│   └── 📁 item_effects/      # 아이템 효과 모듈
│
├── 🖼️ UI 시스템/
│   ├── 📁 ui/                # UI 컴포넌트
│   ├── 📁 backgrounds/       # 배경 시스템
│   └── 📁 presentation/      # 프레젠테이션 레이어
│
├── 🤖 AI 시스템/
│   └── 📁 ai/                # 보스 AI 및 난이도
│
├── 🌐 네트워크/
│   └── 📁 network/           # 멀티플레이어 (개발 중)
│
├── 🎵 리소스/
│   ├── 📁 sounds/            # 사운드 효과
│   ├── 📁 fonts/             # 폰트 파일
│   └── 📁 images/            # 이미지 리소스
│
├── 🧪 테스트/
│   ├── 📄 test_refactored_utils.py     # 유틸리티 테스트
│   ├── 📄 test_rendering_system.py     # 렌더링 테스트
│   └── 📄 sample_refactored_game.py    # 샘플 게임
│
└── 🔧 설정 및 유틸리티/
    ├── 📄 cleanup.py          # 프로젝트 정리 스크립트
    ├── 📄 academy_save.json   # 저장 데이터
    └── 📁 .venv/              # 가상 환경
```

## 🔑 주요 모듈 설명

### 📦 신규 모듈 (리팩토링)

#### `/utils/` - 유틸리티 모듈
- **color_utils.py**: 스테이지 색상, 네온 효과, 색상 블렌딩
- **math_utils.py**: 거리 계산, 각도, 벡터, 이징 함수
- **draw_utils.py**: DrawHelper 클래스, 고급 그리기 함수
- **particle_utils.py**: 파티클 시스템, 이펙트
- **game_constants.py**: 게임 상수 정의

#### `/rendering/` - 렌더링 시스템
- **render_manager.py**: 모든 렌더러 통합 관리
- **ball_renderer.py**: 공 렌더링, 트레일, 특수 효과
- **paddle_renderer.py**: 플레이어/보스 패들 렌더링
- **ui_renderer.py**: HUD, 점수, 게이지, 메시지
- **effect_renderer.py**: 폭발, 레이저, 화면 효과

#### `/game_logic/` - 게임 로직 (신규)
- **game_loop.py**: 메인 게임 루프 관리
- **game_config.py**: 스테이지별 설정, 난이도
- **game_events.py**: 이벤트 기반 아키텍처

### 📚 기존 모듈

#### `/entities/` - 게임 엔티티
- ball.py, paddle.py, boss.py

#### `/managers/` - 시스템 매니저  
- sound_manager.py, physics_manager.py, dash_manager.py

#### `/item_effects/` - 아이템 효과
- 각 아이템별 독립적인 효과 모듈

## 🚀 실행 방법

### 개발 환경
```bash
# 가상환경 활성화
source .venv/bin/activate

# 레거시 게임 실행
python3 pingfighter.py

# 리팩토링된 모듈 테스트
python3 test_rendering_system.py
python3 sample_refactored_game.py
```

### 빌드
```bash
# macOS 앱 빌드
pyinstaller PingFighter.spec

# Windows 실행파일 빌드
python3 build_windows.py
```

### 프로젝트 정리
```bash
# 캐시 파일 제거
python3 cleanup.py
```

## 📊 코드 통계
- 총 Python 파일: 100+ 개
- 총 코드 라인: 30,000+ 줄
- 모듈화된 파일: 50+ 개
- 리팩토링 진행률: 약 30%

## 🎯 리팩토링 목표
1. ✅ 유틸리티 함수 분리
2. ✅ 렌더링 시스템 모듈화
3. ✅ 게임 루프 분리
4. 🔄 이벤트 시스템 통합
5. 🔄 설정 관리 통합
6. 🔄 최종 통합 및 최적화

## 📝 개발 노트
- pingfighter.py는 레거시 코드로 참조용으로만 사용
- 모든 신규 개발은 모듈화된 파일로 진행
- 점진적 리팩토링으로 안정성 우선
- 기존 게임플레이 유지하면서 구조 개선

## 🔧 다음 단계
1. 게임 상태 관리 시스템 통합
2. 이벤트 시스템 완전 통합  
3. 설정 파일 외부화
4. 테스트 커버리지 확대
5. 성능 최적화 및 프로파일링

---
*마지막 업데이트: 2024년 (리팩토링 진행 중)*
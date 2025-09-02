# PingFighter Developer Guide

## 프로젝트 개요

PingFighter (핑파이터)는 클래식 Pong을 현대적으로 재해석한 아케이드 게임입니다.

### 기술 스택
- **언어**: Python 3.8+
- **프레임워크**: Pygame 2.0+
- **빌드 도구**: PyInstaller 6.0+
- **아키텍처**: 이벤트 기반 모듈형 아키텍처

## 프로젝트 구조

```
bosspong/
├── bosspong.py             # 메인 게임 파일 (22,276줄)
├── items.py                # 아이템 시스템
├── option.py               # 게임 옵션
├── gacha.py                # 가챠 시스템
├── opening.py              # 오프닝 애니메이션
├── skill.py                # 스킬 시스템
├── academy.py              # 아카데미 모드
├── cinematic.py            # 시네마틱 장면
├── ui_manager.py           # UI 관리
├── effects_manager.py      # 이펙트 관리
├── physics_manager.py      # 물리 엔진
├── dash_manager.py         # 대시 시스템
├── ui/                     # UI 컴포넌트
│   ├── hud_display.py      # HUD 표시
│   ├── menu_system.py      # 메뉴 시스템
│   └── dialog_system.py    # 다이얼로그
├── core/                   # 핵심 시스템
│   ├── game_state.py       # 게임 상태 관리
│   ├── events.py           # 이벤트 시스템
│   ├── bridge.py           # 시스템 브리지
│   ├── profiler.py         # 성능 프로파일러
│   └── event_handlers.py   # 이벤트 핸들러
├── config/                 # 설정 파일
│   ├── constants.py        # 상수 정의
│   ├── game_settings.py    # 게임 설정
│   └── stage_configs.py    # 스테이지 설정
├── backgrounds/            # 배경 애니메이션
│   └── animated_background*.py
├── sounds/                 # 사운드 리소스
├── items/                  # 아이템 리소스
└── scenes/                 # 장면 리소스
```

## 주요 시스템

### 1. 게임 루프

```python
if __name__ == "__main__":
    # 오프닝 애니메이션
    opening.show_opening_animation(SCREEN, WIDTH, HEIGHT)
    # 메인 게임 루프
    game_loop()
```

### 2. 이벤트 시스템

```python
from core.events import EventManager, EventType, emit_event

# 이벤트 발생
emit_event(EventType.GAME_START, {'stage': 1})

# 이벤트 구독
event_manager.subscribe(EventType.GAME_START, on_game_start)
```

### 3. 게임 상태 관리

```python
from core.game_state import GameState

game_state = GameState.get_instance()
game_state.set('current_stage', 1)
stage = game_state.get('current_stage')
```

### 4. 아이템 시스템

- **패시브 아이템**: 항상 효과 발동
- **액티브 아이템**: 사용시 효과 발동
- **특수 아이템**: 조건부 발동

### 5. AI 시스템

```python
# 기본 AI
boss_ai = BossAI()
decision = boss_ai.make_decision(game_state)

# ML AI (옵션)
if AI_AVAILABLE:
    from boss_ai_integration import EnhancedBossAI
    boss_ai = EnhancedBossAI()
```

## 빌드 및 배포

### 개발 환경 설정

```bash
# 가상환경 생성
python -m venv .venv
source .venv/bin/activate

# 의존성 설치
pip install -r requirements.txt

# 게임 실행
python bosspong.py
```

### 빌드 (PyInstaller)

```bash
# macOS 앱번들 생성
pyinstaller PingFighter_Complete.spec --clean

# 결과물
dist/PingFighter.app  # macOS 앱번들
dist/PingFighter      # 실행 파일
```

### 배포 체크리스트

- [ ] 버전 번호 업데이트
- [ ] 변경사항 문서화
- [ ] 모든 리소스 파일 포함 확인
- [ ] 테스트 (단위/통합/E2E)
- [ ] 빌드 및 코드 서명
- [ ] 배포 패키지 생성

## 디버깅

### 프로파일러 사용

```python
# 게임 중 7번 키로 프로파일러 토글
profiler.visible = True/False
```

### 로그 확인

```python
# 디버그 모드 활성화
DEBUG = True

# 로그 출력
print(f"🎯 Debug: {variable}")
```

### 일반적인 문제 해결

1. **리소스 파일 못 찾음**
   - 경로 확인: 상대 경로 vs 절대 경로
   - PyInstaller 빌드시 datas 설정 확인

2. **성능 문제**
   - 프로파일러로 병목 지점 확인
   - 파티클 수 조정
   - 프레임 제한 확인

3. **AI 모듈 로드 실패**
   - TensorFlow 설치 확인
   - 기본 AI로 폴백

## 테스트

### 단위 테스트

```bash
python -m pytest tests/
```

### 통합 테스트

```bash
python tests/test_framework.py
```

### 테스트 커버리지

```bash
pytest --cov=. --cov-report=html
```

## 성능 최적화

### 메모리 관리
- 파티클 시스템 제한
- 리소스 캐싱
- 불필요한 객체 정리

### 렌더링 최적화
- 더티 렉트 업데이트
- 레이어드 렌더링
- 스프라이트 배칭

### 게임플레이 최적화
- 충돌 검사 최적화
- AI 계산 캐싱
- 이벤트 큐 관리

## 기여 가이드라인

### 코드 스타일
- PEP 8 준수
- 의미있는 변수명 사용
- 주석과 독스트링 작성

### 커밋 메시지
```
[타입] 제목

- 변경사항 1
- 변경사항 2

이슈: #123
```

타입: feat, fix, docs, style, refactor, test, chore

### Pull Request
1. 기능 브랜치 생성
2. 변경사항 구현
3. 테스트 작성
4. PR 생성 및 리뷰 요청

## 라이선스

MIT License

## 연락처

문제 발생시 GitHub Issues에 보고해주세요.
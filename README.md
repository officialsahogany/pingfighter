# PingFighter (핑파이터) 🏓

스테이지별 보스와 대결하는 아케이드 스타일의 탁구 게임

## 🎮 게임 소개

PingFighter은 클래식 Pong 게임을 현대적으로 재해석한 액션 게임입니다. 6개의 스테이지에서 각기 다른 능력을 가진 보스들과 대결하며, 다양한 파워업과 특수 능력을 활용해 승리를 쟁취하세요!

### 주요 특징
- 🤖 6개의 유니크한 보스 AI
- 💥 다양한 파워업 아이템
- 🎯 특수 능력 시스템 (대시, 차지샷)
- 📈 동적 난이도 조절
- 🏆 메달 및 업적 시스템
- 🎨 화려한 시각 효과

## 🚀 시작하기

### 요구 사항
- Python 3.8 이상
- Pygame 2.0 이상

### 설치 방법

1. 저장소 클론
```bash
git clone https://github.com/yourusername/pingfighter.git
cd pingfighter
```

2. 가상 환경 설정 (권장)
```bash
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
```

3. 의존성 설치
```bash
pip install -r requirements.txt
```

### 실행 방법

#### 1. 원본 버전 (22,275줄 단일 파일) - 오리지널
```bash
python3 pingfighter.py
```
- 오리지널 22,000줄 코드
- 모든 기능이 하나의 파일에 포함
- 즉시 게임 실행
- 실험적 모던 루프를 사용하려면 `--modern-loop` 플래그를 추가하세요.
  ```bash
  python3 pingfighter.py --modern-loop
  ```

#### 2. 플레이 가능한 모듈화 버전
```bash
python3 playable_pingfighter.py
```
- 모듈화된 시스템을 사용하는 플레이 가능 버전
- 446줄로 최적화
- 원본과 동일한 게임플레이

#### 3. 모듈화 아키텍처 버전
```bash
python3 pingfighter_modular.py
```
- 완전히 모듈화된 새로운 아키텍처
- 67개의 독립 모듈
- 확장 가능한 구조

## 🎯 게임 방법

### 조작법
- **← / → 또는 A / D**: 패들 이동
- **Shift**: 대시
- **Space**: 차지샷
- **ESC**: 일시정지/메뉴
- **7**: 프로파일러 토글 (디버그)

### 게임 모드
- **스토리 모드**: 6개 스테이지를 순서대로 클리어
- **아케이드 모드**: 원하는 스테이지 선택 플레이
- **아카데미**: 튜토리얼 및 연습 모드

### 보스 소개
1. **Training Bot** - 초보자를 위한 연습용 보스
2. **Speed Demon** - 빠른 반응 속도
3. **Trickster** - 예측 불가능한 움직임
4. **Guardian** - 철벽 방어
5. **Destroyer** - 강력한 공격
6. **Final Boss** - 모든 능력을 갖춘 최종 보스

## 🏗️ 프로젝트 구조

### 아키텍처 개선
- **레거시**: 단일 파일 22,275줄
- **신규**: 모듈화된 30+ 파일, ~5,000줄 (77% 감소)

```
pingfighter/
├── pingfighter.py         # 메인 게임 (843줄)
├── core/               # 핵심 시스템
│   ├── events.py       # 이벤트 시스템
│   ├── global_manager.py # 전역 상태 관리
│   └── error_boundary.py # 에러 처리
├── game_logic/         # 게임 로직
│   ├── collision.py    # 충돌 처리
│   ├── physics.py      # 물리 엔진
│   ├── round_manager.py # 라운드 관리
│   ├── stage_features.py # 스테이지별 특수 기능
│   ├── special_items.py # 13개 특수 아이템
│   ├── perfect_timing.py # 프레임 정밀 입력
│   └── power_smashing.py # 파워 스매싱
├── entities/           # 게임 엔티티
│   ├── ball.py        # 공
│   ├── paddle.py      # 패들
│   └── entity.py      # 엔티티 매니저
├── ai/                # AI 시스템
│   ├── boss_ai.py     # 보스 AI
│   ├── boss_skills.py # 4개 보스 타입별 스킬
│   └── ai_difficulty.py # 난이도 조절
├── managers/          # 매니저 시스템
│   ├── sound_manager.py # 사운드 관리
│   ├── effects_manager.py # 시각 효과
│   └── resource_manager.py # 리소스 관리
├── network/           # 네트워크
│   └── network_manager.py # 멀티플레이어
├── ui/                # UI 시스템
│   ├── menu_system.py # 메뉴
│   ├── settings_ui.py # 설정
│   └── academy_ui.py  # 튜토리얼
└── tests/             # 테스트
    └── test_*.py      # 유닛 테스트
```

## 🧪 테스트

테스트 실행:
```bash
python -m pytest tests/
```

또는:
```bash
python tests/test_framework.py
```

## 📊 성능 최적화

게임은 다음과 같은 최적화 기술을 사용합니다:
- 이벤트 기반 아키텍처로 모듈 간 느슨한 결합
- 싱글톤 패턴으로 메모리 효율성 향상
- 실시간 프로파일링으로 성능 모니터링
- 동적 난이도 조절로 최적의 게임 플로우 유지

## 🤝 기여하기

기여를 환영합니다! 다음 절차를 따라주세요:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 🙏 감사의 말

- Pygame 커뮤니티
- 모든 테스터와 기여자들

## 📞 문의

프로젝트 관련 문의사항은 Issues 탭을 이용해주세요.

---

**Enjoy the game! 🎮**

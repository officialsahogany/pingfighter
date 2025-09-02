# 🎮 BossPong 새 기능 개발 가이드

## ⚠️ 중요 규칙
**bosspong.py (18,841줄)는 더 이상 수정하지 않습니다!**
모든 새 기능은 `new_features/` 폴더에 추가하세요.

## 📁 프로젝트 구조

```
bosspong/
├── bosspong.py           # ⛔ 수정 금지! (레거시 코드)
├── main_new.py           # ✅ 새로운 메인 진입점
└── new_features/         # ✅ 모든 새 기능은 여기에!
    ├── modes/           # 게임 모드
    ├── bosses/          # 새 보스
    ├── items/           # 새 아이템
    ├── skills/          # 새 스킬
    ├── ui/              # UI 개선
    └── systems/         # 시스템 (업적, 리더보드 등)
```

## 🚀 새 기능 추가 방법

### 1. 새 게임 모드 추가
```python
# new_features/modes/my_mode.py
class MyNewMode:
    def __init__(self):
        # 초기화
        pass
    
    def run(self):
        # 게임 루프
        pass

# main_new.py에 추가
from new_features.modes.my_mode import MyNewMode
```

### 2. 새 보스 추가
```python
# new_features/bosses/dragon_boss.py
class DragonBoss:
    def __init__(self):
        self.health = 1000
        self.pattern = ["fire_breath", "tail_sweep", "fly"]
    
    def update(self):
        # 보스 AI
        pass
```

### 3. 기존 기능 재사용
```python
# bosspong.py의 기능을 import해서 사용
from bosspong import play_paddle_sound, create_energy_particle

# 하지만 bosspong.py 자체는 수정하지 않음!
```

## 💡 개발 팁

### DO ✅
- 새 파일 생성하기
- 모듈화된 구조 사용
- 독립적인 테스트 작성
- 문서화 잘하기

### DON'T ❌
- bosspong.py 수정하기
- 기존 코드 복사-붙여넣기
- 전역 변수 남발
- 의존성 꼬이게 만들기

## 🎯 예시: 새 아이템 추가

```python
# new_features/items/legendary_items.py
class ThunderHammer:
    """전설의 천둥 망치"""
    
    def __init__(self):
        self.name = "Thunder Hammer"
        self.damage_boost = 2.5
        self.special_effect = "lightning_strike"
    
    def apply(self, player):
        """플레이어에게 효과 적용"""
        player.damage *= self.damage_boost
        # 번개 효과 추가
        self.create_lightning_effect()
    
    def create_lightning_effect(self):
        # 시각 효과
        pass
```

## 🔧 실행 방법

```bash
# 새로운 진입점으로 실행
python main_new.py

# 또는 직접 기존 게임 실행
python bosspong.py
```

## 📝 커밋 메시지 규칙

```
✨ feat: 새 서바이벌 모드 추가
🐛 fix: 서바이벌 모드 스코어 버그 수정
📝 docs: 새 기능 가이드 업데이트
♻️ refactor: 모드 시스템 구조 개선
```

## 🤝 기여 방법

1. `new_features/` 폴더에 새 모듈 생성
2. 독립적으로 테스트
3. main_new.py에 연결
4. 문서 업데이트
5. PR 생성

---

**Remember: bosspong.py는 건드리지 마세요! 🚫**
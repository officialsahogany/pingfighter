# 전설 아이템 획득 애니메이션 통합 가이드

## 개요
전설 아이템을 획득했을 때 화면이 일시정지되고 2초간 극적인 애니메이션을 재생하는 시스템입니다.

## 주요 기능
- ⏸️ 화면 일시정지 (1.8초)
- ⚡ 번개 효과
- 💥 폭발 파티클
- 🌟 나선형 황금 파티클
- 📝 "전설!" + 아이템 이름 표시
- 🔊 충격파 효과
- 💫 화면 흔들림 & 플래시

## 파일 구조
```
effects/
├── legendary_acquisition.py  # 핵심 애니메이션 클래스
└── legendary_integration.py  # 게임 통합 헬퍼 함수
```

## 통합 방법

### 1. 기본 통합 (간단한 방법)

```python
# 게임 초기화 부분에 추가
from effects.legendary_integration import (
    initialize_legendary_effects,
    trigger_legendary_acquisition,
    update_legendary_effect,
    draw_legendary_effect,
    should_pause_for_legendary
)

# 초기화
initialize_legendary_effects(WIDTH, HEIGHT)

# 게임 업데이트 루프에서
def update_game(dt):
    # 전설 아이템 효과로 인한 일시정지 체크
    if should_pause_for_legendary():
        update_legendary_effect(dt)
        return  # 다른 게임 로직 건너뛰기
    
    # 일반 게임 로직
    # ...
    
    # 전설 아이템 효과 업데이트 (일시정지 없는 마지막 단계)
    update_legendary_effect(dt)

# 렌더링에서
def render():
    # 게임 객체 그리기
    # ...
    
    # 전설 아이템 효과 그리기 (최상단 레이어)
    draw_legendary_effect(screen, font_large, font_huge)
```

### 2. 아이템 획득 시 트리거

```python
# 아이템 충돌/획득 처리 부분에서
def handle_item_pickup(item):
    # 전설 아이템 체크 및 효과 트리거
    legendary_items = {
        'ragnarok_hammer': '라그나로크',
        'infinity_gauntlet': '인피니티 건틀릿',
        'phoenix_feather': '불사조의 깃털',
        'chronos_clock': '크로노스의 시계',
        'excalibur_blade': '엑스칼리버',
        '전설의벨트': '전설의 벨트'
    }
    
    if item['name'] in legendary_items:
        trigger_legendary_acquisition(
            item['name'], 
            legendary_items[item['name']]
        )
    
    # 또는 rarity 체크
    if item.get('rarity') == 'legendary':
        trigger_legendary_acquisition(
            item['name'],
            item.get('korean_name', item['name'])
        )
```

### 3. 자동 통합 (데코레이터 사용)

```python
from effects.legendary_integration import integrate_legendary_effect_to_game

@integrate_legendary_effect_to_game
def update_game(dt):
    # 일반 게임 로직
    # 데코레이터가 자동으로 전설 아이템 효과 처리
    pass
```

## 커스터마이징

### 색상 변경
```python
# legendary_acquisition.py에서
self.LEGENDARY_RED = (255, 50, 50)     # 메인 색상
self.LEGENDARY_GOLD = (255, 215, 0)    # 보조 색상
self.LEGENDARY_WHITE = (255, 255, 255) # 플래시 색상
```

### 애니메이션 시간 조정
```python
# legendary_acquisition.py에서
self.total_duration = 2000  # 2초 → 원하는 밀리초로 변경
```

### 효과 강도 조정
```python
self.screen_shake = 20  # 화면 흔들림 강도
self.screen_flash = 255  # 플래시 밝기
```

## 테스트
```bash
# 단독 테스트
python3 test_legendary_effect.py

# 게임에서 테스트
# SPACE 키로 효과 트리거 가능
```

## 주의사항

1. **폰트 전달**: `draw_legendary_effect()`에 font_large는 필수, font_huge는 선택사항
2. **델타 타임**: update에 전달하는 dt는 밀리초 단위
3. **일시정지 처리**: `should_pause_for_legendary()`가 True일 때 게임 로직 중단 필요
4. **레이어 순서**: 효과는 최상단 레이어에 그려야 함

## 성능 고려사항

- 파티클 수: 기본 150개 (초기 100 + 지속 50)
- 번개 효과: 동시 최대 3개
- 메모리: 약 2-3MB 추가 사용
- CPU: 일반적으로 1-2% 추가 사용

## 문제 해결

### 효과가 안 보이는 경우
- 렌더링 순서 확인 (최상단에 그려야 함)
- 폰트 객체 전달 확인

### 일시정지가 안 되는 경우
- `should_pause_for_legendary()` 체크 위치 확인
- 게임 로직이 조건문 안에 있는지 확인

### 프레임 드랍
- 파티클 수 줄이기
- 번개 효과 빈도 줄이기
# PingFighter 아키텍처 개선 계획

## 1. 현재 상태 분석
- **파일 크기**: 22,177줄 (단일 파일)
- **전역 변수**: 200+ 개
- **함수 수**: 300+ 개
- **주요 문제**: 강한 결합도, 상태 관리 어려움, 테스트 불가능

## 2. 목표 아키텍처

### 2.1 Core 모듈 구조
```
bosspong/
├── core/
│   ├── __init__.py
│   ├── game.py          # Game 클래스 (메인 게임 루프)
│   ├── state.py         # GameState 클래스 (전역 상태 관리)
│   ├── events.py        # EventManager 클래스
│   └── constants.py     # 게임 상수들
│
├── entities/
│   ├── __init__.py
│   ├── player.py        # Player 클래스
│   ├── boss.py          # Boss 기본 클래스
│   ├── bosses/          # 각 보스별 클래스
│   │   ├── stage1_boss.py
│   │   ├── stage2_boss.py
│   │   └── ...
│   ├── ball.py          # Ball 클래스
│   └── items.py         # Item 클래스들
│
├── systems/
│   ├── __init__.py
│   ├── physics.py       # 물리 시스템
│   ├── collision.py     # 충돌 처리
│   ├── input.py         # 입력 처리
│   ├── sound.py         # 사운드 시스템
│   └── effects.py       # 이펙트 시스템
│
├── ui/
│   ├── __init__.py
│   ├── hud.py           # HUD 시스템
│   ├── menus.py         # 메뉴 시스템
│   ├── dialogs.py       # 대화창
│   └── renderer.py      # 렌더링 시스템
│
├── scenes/
│   ├── __init__.py
│   ├── main_menu.py     # 메인 메뉴 씬
│   ├── game_scene.py    # 게임 플레이 씬
│   ├── pause_menu.py    # 일시정지 씬
│   └── victory.py       # 승리 화면 씬
│
└── main.py              # 진입점

```

## 3. 핵심 클래스 설계

### 3.1 GameState 클래스
```python
class GameState:
    """전역 상태를 관리하는 싱글톤 클래스"""
    
    def __init__(self):
        # 게임 상태
        self.current_stage = 1
        self.round_wins = 0
        self.round_losses = 0
        self.game_paused = False
        
        # 플레이어 상태
        self.player_score = 0
        self.player_lives = 3
        self.special_gauge = 0
        
        # 아이템 상태
        self.items_obtained = {}
        self.passive_items = []
        
        # 보스 상태
        self.boss_health = 100
        self.boss_phase = 1
        
    def reset_round(self):
        """라운드 초기화"""
        pass
        
    def save_state(self):
        """상태 저장"""
        pass
        
    def load_state(self):
        """상태 로드"""
        pass
```

### 3.2 EventManager 클래스
```python
class EventManager:
    """이벤트 시스템 - 모듈 간 통신"""
    
    def __init__(self):
        self.listeners = {}
        
    def subscribe(self, event_type, callback):
        """이벤트 구독"""
        if event_type not in self.listeners:
            self.listeners[event_type] = []
        self.listeners[event_type].append(callback)
        
    def emit(self, event_type, data=None):
        """이벤트 발생"""
        if event_type in self.listeners:
            for callback in self.listeners[event_type]:
                callback(data)
```

### 3.3 Scene 기반 시스템
```python
class Scene:
    """씬 기본 클래스"""
    
    def __init__(self, game):
        self.game = game
        self.active = False
        
    def enter(self):
        """씬 진입 시"""
        pass
        
    def exit(self):
        """씬 종료 시"""
        pass
        
    def update(self, dt):
        """업데이트"""
        pass
        
    def render(self, screen):
        """렌더링"""
        pass
        
    def handle_event(self, event):
        """이벤트 처리"""
        pass
```

## 4. 단계별 마이그레이션 계획

### Phase 1: 기초 구조 생성 (1-2일)
1. 디렉토리 구조 생성
2. GameState 클래스 구현
3. 전역 변수를 GameState로 이동
4. 기존 코드와 호환성 유지

### Phase 2: Entity 시스템 (2-3일)
1. Player 클래스 생성
2. Boss 기본 클래스 생성
3. Ball 클래스 생성
4. 각 엔티티의 update/render 메서드 구현

### Phase 3: System 분리 (2-3일)
1. Physics 시스템 분리
2. Collision 시스템 분리
3. Input 시스템 분리
4. Sound/Effect 시스템 분리

### Phase 4: Scene 시스템 (2-3일)
1. Scene 기본 클래스 구현
2. MainMenu 씬 구현
3. GameScene 씬 구현
4. 씬 전환 시스템 구현

### Phase 5: UI 완전 분리 (1-2일)
1. Renderer 시스템 구현
2. HUD 완전 분리
3. Menu 시스템 완전 분리
4. Dialog 시스템 완전 분리

## 5. 예시: GameState 사용

### Before (현재):
```python
global player_score, round_wins, special_gauge
player_score += 10
round_wins += 1
special_gauge = min(100, special_gauge + 20)
```

### After (개선 후):
```python
game_state = GameState.get_instance()
game_state.player_score += 10
game_state.round_wins += 1
game_state.special_gauge = min(100, game_state.special_gauge + 20)
```

## 6. 이벤트 시스템 예시

### 이벤트 발생:
```python
event_manager.emit('player_scored', {'points': 10})
event_manager.emit('round_won', {'stage': current_stage})
event_manager.emit('item_collected', {'item_type': 'speedboost'})
```

### 이벤트 구독:
```python
# UI 모듈에서
event_manager.subscribe('player_scored', self.update_score_display)

# Sound 모듈에서  
event_manager.subscribe('item_collected', self.play_item_sound)

# GameState에서
event_manager.subscribe('round_won', self.handle_round_win)
```

## 7. 장점

1. **모듈화**: 각 시스템이 독립적으로 작동
2. **테스트 가능**: 각 모듈을 개별적으로 테스트 가능
3. **유지보수성**: 기능별로 파일이 분리되어 관리 용이
4. **확장성**: 새로운 보스, 아이템, 씬 추가가 쉬움
5. **재사용성**: 컴포넌트를 다른 프로젝트에서도 사용 가능

## 8. 주의사항

1. **점진적 마이그레이션**: 한 번에 모든 것을 바꾸지 말고 단계적으로
2. **호환성 유지**: 기존 코드가 계속 작동하도록 래퍼 함수 제공
3. **테스트**: 각 단계마다 게임이 정상 작동하는지 확인
4. **백업**: 각 단계 전에 백업 생성

## 9. 우선순위

1. **긴급**: GameState 클래스 (전역 변수 관리)
2. **중요**: Entity 시스템 (Player, Boss, Ball)
3. **유용**: Scene 시스템 (화면 전환 관리)
4. **개선**: Event 시스템 (모듈 간 통신)
5. **최적화**: Renderer 분리 (성능 개선)
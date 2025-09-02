"""
게임 이벤트 시스템 - 이벤트 기반 아키텍처
"""
from typing import Dict, Any, List, Callable
from enum import Enum, auto

class EventType(Enum):
    """이벤트 타입 정의"""
    # 게임 상태
    GAME_START = auto()
    GAME_PAUSE = auto()
    GAME_RESUME = auto()
    GAME_OVER = auto()
    STAGE_CLEAR = auto()
    STAGE_FAILED = auto()
    
    # 스코어
    PLAYER_SCORE = auto()
    BOSS_SCORE = auto()
    COMBO_INCREASE = auto()
    COMBO_RESET = auto()
    
    # 충돌
    BALL_HIT_PADDLE = auto()
    BALL_HIT_WALL = auto()
    BALL_HIT_ITEM = auto()
    BALL_GOAL = auto()
    
    # 아이템
    ITEM_SPAWN = auto()
    ITEM_COLLECTED = auto()
    ITEM_EXPIRED = auto()
    POWERUP_ACTIVATED = auto()
    POWERUP_EXPIRED = auto()
    
    # 보스
    BOSS_RAGE_MODE = auto()
    BOSS_SPECIAL_ATTACK = auto()
    BOSS_DEFEATED = auto()
    
    # 플레이어
    PLAYER_DASH = auto()
    PLAYER_CHARGE = auto()
    PLAYER_SPECIAL = auto()
    
    # 시스템
    FPS_DROP = auto()
    ACHIEVEMENT_UNLOCKED = auto()
    SETTING_CHANGED = auto()

class GameEvent:
    """게임 이벤트 클래스"""
    
    def __init__(self, event_type: EventType, data: Dict[str, Any] = None):
        """이벤트 초기화
        
        Args:
            event_type: 이벤트 타입
            data: 이벤트 데이터
        """
        self.type = event_type
        self.data = data or {}
        self.timestamp = None  # 이벤트 발생 시간
        self.handled = False  # 처리 완료 여부
    
    def __repr__(self):
        return f"GameEvent({self.type.name}, {self.data})"

class EventManager:
    """이벤트 관리자 - 이벤트 발행/구독 시스템"""
    
    def __init__(self):
        """이벤트 관리자 초기화"""
        self.listeners: Dict[EventType, List[Callable]] = {}
        self.event_queue: List[GameEvent] = []
        self.event_history: List[GameEvent] = []
        self.max_history = 100
        
    def subscribe(self, event_type: EventType, callback: Callable):
        """이벤트 구독
        
        Args:
            event_type: 구독할 이벤트 타입
            callback: 이벤트 발생 시 호출될 콜백 함수
        """
        if event_type not in self.listeners:
            self.listeners[event_type] = []
        
        if callback not in self.listeners[event_type]:
            self.listeners[event_type].append(callback)
    
    def unsubscribe(self, event_type: EventType, callback: Callable):
        """이벤트 구독 해제
        
        Args:
            event_type: 구독 해제할 이벤트 타입
            callback: 제거할 콜백 함수
        """
        if event_type in self.listeners:
            if callback in self.listeners[event_type]:
                self.listeners[event_type].remove(callback)
    
    def emit(self, event: GameEvent):
        """이벤트 발행
        
        Args:
            event: 발행할 이벤트
        """
        import time
        event.timestamp = time.time()
        self.event_queue.append(event)
    
    def emit_immediate(self, event: GameEvent):
        """즉시 이벤트 발행 (큐를 거치지 않음)
        
        Args:
            event: 발행할 이벤트
        """
        import time
        event.timestamp = time.time()
        self._process_event(event)
    
    def process_events(self):
        """큐에 있는 이벤트들 처리"""
        while self.event_queue:
            event = self.event_queue.pop(0)
            self._process_event(event)
    
    def _process_event(self, event: GameEvent):
        """단일 이벤트 처리
        
        Args:
            event: 처리할 이벤트
        """
        # 이벤트 히스토리에 추가
        self.event_history.append(event)
        if len(self.event_history) > self.max_history:
            self.event_history.pop(0)
        
        # 리스너들에게 이벤트 전달
        if event.type in self.listeners:
            for callback in self.listeners[event.type]:
                try:
                    callback(event)
                except Exception as e:
                    print(f"이벤트 처리 중 오류: {event.type.name} - {e}")
        
        event.handled = True
    
    def clear_queue(self):
        """이벤트 큐 비우기"""
        self.event_queue.clear()
    
    def get_history(self, event_type: EventType = None) -> List[GameEvent]:
        """이벤트 히스토리 조회
        
        Args:
            event_type: 특정 타입만 필터링 (None이면 전체)
            
        Returns:
            이벤트 리스트
        """
        if event_type:
            return [e for e in self.event_history if e.type == event_type]
        return self.event_history.copy()

class EventHandlers:
    """기본 이벤트 핸들러 모음"""
    
    @staticmethod
    def handle_player_score(event: GameEvent):
        """플레이어 득점 처리"""
        score = event.data.get('score', 1)
        print(f"플레이어 득점! +{score}")
    
    @staticmethod
    def handle_boss_score(event: GameEvent):
        """보스 득점 처리"""
        score = event.data.get('score', 1)
        print(f"보스 득점! +{score}")
    
    @staticmethod
    def handle_combo_increase(event: GameEvent):
        """콤보 증가 처리"""
        combo = event.data.get('combo', 0)
        multiplier = event.data.get('multiplier', 1.0)
        print(f"콤보 {combo}x! (배율: {multiplier:.1f}x)")
    
    @staticmethod
    def handle_item_collected(event: GameEvent):
        """아이템 획득 처리"""
        item_type = event.data.get('item_type', 'unknown')
        print(f"아이템 획득: {item_type}")
    
    @staticmethod
    def handle_boss_rage_mode(event: GameEvent):
        """보스 분노 모드 처리"""
        stage = event.data.get('stage', 1)
        print(f"보스 분노 모드 발동! (스테이지 {stage})")
    
    @staticmethod
    def handle_achievement_unlocked(event: GameEvent):
        """업적 해제 처리"""
        achievement = event.data.get('achievement', 'unknown')
        print(f"🏆 업적 해제: {achievement}")

class GameEventSystem:
    """게임 이벤트 시스템 통합 관리"""
    
    def __init__(self):
        """이벤트 시스템 초기화"""
        self.manager = EventManager()
        self._register_default_handlers()
        
    def _register_default_handlers(self):
        """기본 이벤트 핸들러 등록"""
        handlers = EventHandlers()
        
        # 스코어 이벤트
        self.manager.subscribe(EventType.PLAYER_SCORE, handlers.handle_player_score)
        self.manager.subscribe(EventType.BOSS_SCORE, handlers.handle_boss_score)
        self.manager.subscribe(EventType.COMBO_INCREASE, handlers.handle_combo_increase)
        
        # 아이템 이벤트
        self.manager.subscribe(EventType.ITEM_COLLECTED, handlers.handle_item_collected)
        
        # 보스 이벤트
        self.manager.subscribe(EventType.BOSS_RAGE_MODE, handlers.handle_boss_rage_mode)
        
        # 시스템 이벤트
        self.manager.subscribe(EventType.ACHIEVEMENT_UNLOCKED, handlers.handle_achievement_unlocked)
    
    def emit_player_score(self, score: int = 1):
        """플레이어 득점 이벤트 발행"""
        self.manager.emit(GameEvent(EventType.PLAYER_SCORE, {'score': score}))
    
    def emit_boss_score(self, score: int = 1):
        """보스 득점 이벤트 발행"""
        self.manager.emit(GameEvent(EventType.BOSS_SCORE, {'score': score}))
    
    def emit_combo(self, combo: int, multiplier: float):
        """콤보 이벤트 발행"""
        self.manager.emit(GameEvent(EventType.COMBO_INCREASE, {
            'combo': combo,
            'multiplier': multiplier
        }))
    
    def emit_ball_hit(self, target: str, position: tuple):
        """공 충돌 이벤트 발행"""
        event_type = EventType.BALL_HIT_PADDLE if target == 'paddle' else EventType.BALL_HIT_WALL
        self.manager.emit(GameEvent(event_type, {
            'target': target,
            'position': position
        }))
    
    def emit_item_event(self, action: str, item_type: str, position: tuple = None):
        """아이템 이벤트 발행"""
        event_map = {
            'spawn': EventType.ITEM_SPAWN,
            'collect': EventType.ITEM_COLLECTED,
            'expire': EventType.ITEM_EXPIRED
        }
        
        event_type = event_map.get(action, EventType.ITEM_SPAWN)
        self.manager.emit(GameEvent(event_type, {
            'item_type': item_type,
            'position': position
        }))
    
    def emit_powerup_event(self, action: str, powerup_type: str, duration: float = 0):
        """파워업 이벤트 발행"""
        event_type = EventType.POWERUP_ACTIVATED if action == 'activate' else EventType.POWERUP_EXPIRED
        self.manager.emit(GameEvent(event_type, {
            'powerup_type': powerup_type,
            'duration': duration
        }))
    
    def emit_boss_event(self, action: str, stage: int, data: Dict[str, Any] = None):
        """보스 이벤트 발행"""
        event_map = {
            'rage': EventType.BOSS_RAGE_MODE,
            'special': EventType.BOSS_SPECIAL_ATTACK,
            'defeat': EventType.BOSS_DEFEATED
        }
        
        event_type = event_map.get(action, EventType.BOSS_RAGE_MODE)
        event_data = {'stage': stage}
        if data:
            event_data.update(data)
        
        self.manager.emit(GameEvent(event_type, event_data))
    
    def emit_game_state_event(self, state: str, data: Dict[str, Any] = None):
        """게임 상태 이벤트 발행"""
        state_map = {
            'start': EventType.GAME_START,
            'pause': EventType.GAME_PAUSE,
            'resume': EventType.GAME_RESUME,
            'over': EventType.GAME_OVER,
            'stage_clear': EventType.STAGE_CLEAR,
            'stage_failed': EventType.STAGE_FAILED
        }
        
        event_type = state_map.get(state, EventType.GAME_START)
        self.manager.emit(GameEvent(event_type, data or {}))
    
    def process(self):
        """이벤트 처리"""
        self.manager.process_events()

# 전역 이벤트 시스템 인스턴스
event_system = GameEventSystem()

def get_event_system() -> GameEventSystem:
    """전역 이벤트 시스템 반환"""
    return event_system
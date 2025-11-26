"""
EventManager - 이벤트 시스템
모듈 간 느슨한 결합을 위한 이벤트 기반 통신
"""

from typing import Callable, Dict, List, Any
from enum import Enum


class EventType(Enum):
    """이벤트 타입 정의"""
    # 게임 상태 이벤트
    GAME_START = "game_start"
    GAME_PAUSE = "game_pause"
    GAME_RESUME = "game_resume"
    GAME_OVER = "game_over"
    
    # 라운드 이벤트
    ROUND_START = "round_start"
    ROUND_END = "round_end"
    ROUND_WIN = "round_win"
    ROUND_LOSE = "round_lose"
    
    # 점수 이벤트
    PLAYER_SCORE = "player_score"
    AI_SCORE = "ai_score"
    MEDAL_EARNED = "medal_earned"
    SCORE_UPDATE = "score_update"
    DEUCE_MODE = "deuce_mode"
    
    # 충돌 이벤트
    COLLISION = "collision"
    BALL_HIT_PLAYER = "ball_hit_player"
    BALL_HIT_BOSS = "ball_hit_boss"
    BALL_HIT_WALL = "ball_hit_wall"
    BALL_OUT_OF_BOUNDS = "ball_out_of_bounds"
    
    # 아이템 이벤트
    ITEM_SPAWNED = "item_spawned"
    ITEM_COLLECTED = "item_collected"
    ITEM_ACTIVATED = "item_activated"
    ITEM_EXPIRED = "item_expired"
    
    # 특수 능력 이벤트
    SPECIAL_CHARGED = "special_charged"
    SPECIAL_ACTIVATED = "special_activated"
    SPECIAL_ENDED = "special_ended"
    SKILL_ACTIVATED = "skill_activated"
    SKILL_DEACTIVATED = "skill_deactivated"
    ITEM_USED = "item_used"
    
    # 대시 이벤트
    DASH_START = "dash_start"
    DASH_END = "dash_end"
    DASH_STARTED = "dash_started"
    DASH_ENDED = "dash_ended"
    DASH_RECHARGED = "dash_recharged"
    
    # 보스 이벤트
    BOSS_PHASE_CHANGED = "boss_phase_changed"
    BOSS_SPECIAL_ATTACK = "boss_special_attack"
    BOSS_SPECIAL = "boss_special"
    BOSS_ACTION = "boss_action"
    BOSS_DEFEATED = "boss_defeated"
    
    # 난이도 이벤트
    DIFFICULTY_CHANGED = "difficulty_changed"
    
    # UI 이벤트
    MENU_OPENED = "menu_opened"
    MENU_CLOSED = "menu_closed"
    BUTTON_CLICKED = "button_clicked"
    DIALOG_SHOWN = "dialog_shown"
    DIALOG_HIDDEN = "dialog_hidden"
    SETTINGS_CHANGED = "settings_changed"
    
    # 사운드 이벤트
    PLAY_SOUND = "play_sound"
    PLAY_MUSIC = "play_music"
    STOP_MUSIC = "stop_music"
    
    # 효과 이벤트
    SCREEN_SHAKE = "screen_shake"
    PARTICLE_SPAWN = "particle_spawn"
    EXPLOSION = "explosion"
    CREATE_LIGHT_SHARDS_EXPLOSION = "create_light_shards_explosion"
    
    # 에러 이벤트
    ERROR_OCCURRED = "error_occurred"
    ERROR_RECOVERED = "error_recovered"
    ERROR_FALLBACK = "error_fallback"
    ROUND_RESTART = "round_restart"
    NETWORK_ERROR = "network_error"
    NETWORK_OFFLINE = "network_offline"
    SAVE_TO_MEMORY = "save_to_memory"


class Event:
    """이벤트 데이터 클래스"""
    
    def __init__(self, event_type: EventType, data: Dict[str, Any] = None):
        self.type = event_type
        self.data = data or {}
        self.handled = False
        
    def __str__(self):
        return f"Event({self.type.value}, {self.data})"


class EventManager:
    """이벤트 관리자 - 싱글톤"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(EventManager, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        self._initialized = True
        
        # 이벤트 타입별 리스너 목록
        self.listeners: Dict[EventType, List[Callable]] = {}
        
        # 이벤트 큐 (지연 처리용)
        self.event_queue: List[Event] = []
        
        # 이벤트 히스토리 (디버깅용)
        self.event_history: List[Event] = []
        self.history_max_size = 100
        
    def subscribe(self, event_type: EventType, callback: Callable):
        """이벤트 구독
        
        Args:
            event_type: 구독할 이벤트 타입
            callback: 이벤트 발생 시 호출될 함수
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
                
    def emit(self, event_type: EventType, data: Dict[str, Any] = None, immediate: bool = True):
        """이벤트 발생
        
        Args:
            event_type: 발생시킬 이벤트 타입
            data: 이벤트와 함께 전달할 데이터
            immediate: True면 즉시 처리, False면 큐에 추가
        """
        event = Event(event_type, data)
        
        # 히스토리에 추가
        self.event_history.append(event)
        if len(self.event_history) > self.history_max_size:
            self.event_history.pop(0)
        
        if immediate:
            self._process_event(event)
        else:
            self.event_queue.append(event)
            
    def process_queue(self):
        """큐에 있는 이벤트들 처리"""
        while self.event_queue:
            event = self.event_queue.pop(0)
            self._process_event(event)
            
    def _process_event(self, event: Event):
        """단일 이벤트 처리
        
        Args:
            event: 처리할 이벤트
        """
        if event.type in self.listeners:
            for callback in self.listeners[event.type]:
                try:
                    callback(event)
                    if event.handled:
                        break  # 이벤트가 처리되면 중단
                except Exception as e:
                    print(f"Error processing event {event.type}: {e}")
                    
    def clear_listeners(self, event_type: EventType = None):
        """리스너 제거
        
        Args:
            event_type: 특정 이벤트 타입의 리스너만 제거. None이면 모두 제거
        """
        if event_type:
            if event_type in self.listeners:
                self.listeners[event_type].clear()
        else:
            self.listeners.clear()
            
    def get_history(self) -> List[Event]:
        """이벤트 히스토리 반환"""
        return self.event_history.copy()
        
    @classmethod
    def get_instance(cls):
        """싱글톤 인스턴스 반환"""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance


# 헬퍼 함수들
def emit_event(event_type: EventType, data: Dict[str, Any] = None):
    """간편한 이벤트 발생 함수"""
    EventManager.get_instance().emit(event_type, data)
    
def subscribe(event_type: EventType, callback: Callable):
    """간편한 이벤트 구독 함수"""
    EventManager.get_instance().subscribe(event_type, callback)
    
def unsubscribe(event_type: EventType, callback: Callable):
    """간편한 이벤트 구독 해제 함수"""
    EventManager.get_instance().unsubscribe(event_type, callback)


# 사용 예시:
if __name__ == "__main__":
    # 이벤트 매니저 인스턴스
    event_manager = EventManager.get_instance()
    
    # 이벤트 핸들러 정의
    def on_player_score(event: Event):
        print(f"Player scored! Points: {event.data.get('points', 0)}")
        
    def on_item_collected(event: Event):
        item_type = event.data.get('item_type', 'unknown')
        print(f"Item collected: {item_type}")
        
    # 이벤트 구독
    event_manager.subscribe(EventType.PLAYER_SCORE, on_player_score)
    event_manager.subscribe(EventType.ITEM_COLLECTED, on_item_collected)
    
    # 이벤트 발생
    event_manager.emit(EventType.PLAYER_SCORE, {'points': 10})
    event_manager.emit(EventType.ITEM_COLLECTED, {'item_type': 'speedboost'})
    
    # 간편한 방법
    emit_event(EventType.ROUND_WIN, {'stage': 1})
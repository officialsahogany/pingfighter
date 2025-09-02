# -*- coding: utf-8 -*-
"""
고급 이벤트 버스 시스템
발행-구독 패턴 기반의 비동기 이벤트 처리
"""

import asyncio
import threading
from typing import Dict, List, Callable, Any, Optional, Set
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from queue import Queue, PriorityQueue
import weakref
from functools import wraps


class EventPriority(Enum):
    """이벤트 우선순위"""
    CRITICAL = 0
    HIGH = 1
    NORMAL = 2
    LOW = 3


@dataclass
class Event:
    """이벤트 데이터 클래스"""
    type: str
    data: Any = None
    timestamp: datetime = field(default_factory=datetime.now)
    priority: EventPriority = EventPriority.NORMAL
    source: Any = None
    propagate: bool = True  # 이벤트 전파 여부
    
    def __lt__(self, other):
        """우선순위 큐에서 정렬을 위한 비교"""
        return self.priority.value < other.priority.value


class EventBus:
    """고급 이벤트 버스
    
    - 동기/비동기 이벤트 처리
    - 우선순위 기반 이벤트 큐
    - 약한 참조로 메모리 누수 방지
    - 이벤트 필터링 및 변환
    - 이벤트 히스토리 추적
    """
    
    def __init__(self, async_mode: bool = False):
        """이벤트 버스 초기화
        
        Args:
            async_mode: 비동기 모드 활성화 여부
        """
        self._subscribers: Dict[str, List[weakref.ref]] = {}
        self._event_queue: PriorityQueue = PriorityQueue()
        self._event_history: List[Event] = []
        self._filters: List[Callable[[Event], bool]] = []
        self._transformers: List[Callable[[Event], Event]] = []
        self._async_mode = async_mode
        self._running = False
        self._max_history = 100
        
        # 비동기 모드 설정
        if async_mode:
            self._loop = asyncio.new_event_loop()
            self._thread = threading.Thread(target=self._run_async_loop)
            self._thread.daemon = True
            self._thread.start()
    
    def subscribe(self, event_type: str, handler: Callable, 
                 weak: bool = True, priority: int = 0) -> None:
        """이벤트 구독
        
        Args:
            event_type: 구독할 이벤트 타입
            handler: 이벤트 핸들러
            weak: 약한 참조 사용 여부
            priority: 핸들러 우선순위 (낮을수록 먼저 실행)
        """
        if event_type not in self._subscribers:
            self._subscribers[event_type] = []
        
        # 약한 참조 또는 강한 참조
        if weak:
            ref = weakref.ref(handler, self._create_cleanup_callback(event_type))
        else:
            ref = lambda: handler  # 강한 참조는 람다로 래핑
        
        # 우선순위에 따라 삽입
        self._subscribers[event_type].append((priority, ref))
        self._subscribers[event_type].sort(key=lambda x: x[0])
    
    def unsubscribe(self, event_type: str, handler: Callable) -> None:
        """이벤트 구독 해제
        
        Args:
            event_type: 구독 해제할 이벤트 타입
            handler: 제거할 핸들러
        """
        if event_type not in self._subscribers:
            return
        
        self._subscribers[event_type] = [
            (priority, ref) for priority, ref in self._subscribers[event_type]
            if ref() != handler
        ]
    
    def publish(self, event: Event) -> None:
        """이벤트 발행
        
        Args:
            event: 발행할 이벤트
        """
        # 필터 적용
        for filter_func in self._filters:
            if not filter_func(event):
                return
        
        # 변환 적용
        for transformer in self._transformers:
            event = transformer(event)
        
        # 히스토리 추가
        self._add_to_history(event)
        
        # 큐에 추가
        self._event_queue.put(event)
        
        # 즉시 처리 또는 큐 처리
        if not self._async_mode:
            self._process_event_queue()
    
    def publish_async(self, event_type: str, data: Any = None, 
                     priority: EventPriority = EventPriority.NORMAL) -> None:
        """비동기 이벤트 발행
        
        Args:
            event_type: 이벤트 타입
            data: 이벤트 데이터
            priority: 우선순위
        """
        event = Event(type=event_type, data=data, priority=priority)
        
        if self._async_mode:
            asyncio.run_coroutine_threadsafe(
                self._async_publish(event),
                self._loop
            )
        else:
            self.publish(event)
    
    async def _async_publish(self, event: Event) -> None:
        """비동기 이벤트 발행 내부 구현"""
        self.publish(event)
    
    def _process_event_queue(self) -> None:
        """이벤트 큐 처리"""
        while not self._event_queue.empty():
            event = self._event_queue.get()
            self._dispatch_event(event)
    
    def _dispatch_event(self, event: Event) -> None:
        """이벤트 디스패치
        
        Args:
            event: 디스패치할 이벤트
        """
        if event.type not in self._subscribers:
            return
        
        # 구독자들에게 이벤트 전달
        dead_refs = []
        for priority, ref in self._subscribers[event.type]:
            handler = ref()
            if handler is None:
                dead_refs.append((priority, ref))
                continue
            
            try:
                # 핸들러 실행
                result = handler(event)
                
                # 이벤트 전파 중단 체크
                if result is False or not event.propagate:
                    break
                    
            except Exception as e:
                print(f"이벤트 핸들러 오류: {event.type} - {e}")
        
        # 죽은 참조 제거
        for dead_ref in dead_refs:
            self._subscribers[event.type].remove(dead_ref)
    
    def add_filter(self, filter_func: Callable[[Event], bool]) -> None:
        """이벤트 필터 추가
        
        Args:
            filter_func: 필터 함수 (False 반환 시 이벤트 차단)
        """
        self._filters.append(filter_func)
    
    def add_transformer(self, transformer: Callable[[Event], Event]) -> None:
        """이벤트 변환기 추가
        
        Args:
            transformer: 변환 함수
        """
        self._transformers.append(transformer)
    
    def _add_to_history(self, event: Event) -> None:
        """이벤트 히스토리에 추가"""
        self._event_history.append(event)
        
        # 최대 크기 유지
        if len(self._event_history) > self._max_history:
            self._event_history = self._event_history[-self._max_history:]
    
    def get_history(self, event_type: Optional[str] = None, 
                   limit: int = 10) -> List[Event]:
        """이벤트 히스토리 조회
        
        Args:
            event_type: 특정 타입만 필터링
            limit: 최대 개수
            
        Returns:
            이벤트 리스트
        """
        history = self._event_history
        
        if event_type:
            history = [e for e in history if e.type == event_type]
        
        return history[-limit:]
    
    def _create_cleanup_callback(self, event_type: str):
        """약한 참조 정리 콜백 생성"""
        def cleanup(ref):
            if event_type in self._subscribers:
                self._subscribers[event_type] = [
                    (p, r) for p, r in self._subscribers[event_type] if r != ref
                ]
        return cleanup
    
    def _run_async_loop(self):
        """비동기 이벤트 루프 실행"""
        asyncio.set_event_loop(self._loop)
        self._loop.run_forever()
    
    def clear(self, event_type: Optional[str] = None) -> None:
        """구독자 제거
        
        Args:
            event_type: 특정 타입만 제거 (None이면 모두 제거)
        """
        if event_type:
            self._subscribers.pop(event_type, None)
        else:
            self._subscribers.clear()
    
    def stop(self) -> None:
        """이벤트 버스 정지"""
        self._running = False
        if self._async_mode:
            self._loop.call_soon_threadsafe(self._loop.stop)
            self._thread.join(timeout=1)


class EventEmitter:
    """이벤트 발행 믹스인 클래스"""
    
    def __init__(self):
        self._event_bus = get_event_bus()
    
    def emit(self, event_type: str, data: Any = None, 
            priority: EventPriority = EventPriority.NORMAL) -> None:
        """이벤트 발행"""
        event = Event(
            type=event_type,
            data=data,
            priority=priority,
            source=self
        )
        self._event_bus.publish(event)


def on_event(event_type: str, priority: int = 0):
    """이벤트 핸들러 데코레이터
    
    Args:
        event_type: 구독할 이벤트 타입
        priority: 핸들러 우선순위
    """
    def decorator(func):
        # 자동으로 이벤트 버스에 등록
        get_event_bus().subscribe(event_type, func, priority=priority)
        
        @wraps(func)
        def wrapper(*args, **kwargs):
            return func(*args, **kwargs)
        
        return wrapper
    return decorator


# 전역 이벤트 버스
_event_bus = EventBus()


def get_event_bus() -> EventBus:
    """전역 이벤트 버스 반환"""
    return _event_bus


# 사전 정의된 이벤트 타입들
class GameEvents:
    """게임 이벤트 타입 상수"""
    # 게임 상태
    GAME_START = "game.start"
    GAME_PAUSE = "game.pause"
    GAME_RESUME = "game.resume"
    GAME_OVER = "game.over"
    
    # 플레이어
    PLAYER_HIT = "player.hit"
    PLAYER_SCORE = "player.score"
    PLAYER_POWERUP = "player.powerup"
    PLAYER_DEATH = "player.death"
    
    # 보스
    BOSS_HIT = "boss.hit"
    BOSS_PHASE_CHANGE = "boss.phase_change"
    BOSS_DEFEATED = "boss.defeated"
    
    # 아이템
    ITEM_SPAWN = "item.spawn"
    ITEM_COLLECT = "item.collect"
    ITEM_EXPIRE = "item.expire"
    
    # 시스템
    LEVEL_COMPLETE = "level.complete"
    ACHIEVEMENT_UNLOCK = "achievement.unlock"
    SETTINGS_CHANGE = "settings.change"
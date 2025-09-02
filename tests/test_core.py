"""
Core System Tests - 코어 시스템 테스트
GameState, EventManager, Bridge 테스트
"""

import unittest
from tests.test_framework import GameTestCase, MockEvent
from core.game_state import GameState
from core.events import EventManager, EventType, Event


class TestGameState(GameTestCase):
    """GameState 테스트"""
    
    def setUp(self):
        super().setUp()
        self.game_state = GameState.get_instance()
        self.game_state.reset()
        
    def test_singleton(self):
        """싱글톤 패턴 테스트"""
        state1 = GameState.get_instance()
        state2 = GameState.get_instance()
        self.assertIs(state1, state2)
        
    def test_get_set(self):
        """get/set 메서드 테스트"""
        self.game_state.set('test_key', 'test_value')
        self.assertEqual(self.game_state.get('test_key'), 'test_value')
        
    def test_default_value(self):
        """기본값 테스트"""
        value = self.game_state.get('nonexistent', 'default')
        self.assertEqual(value, 'default')
        
    def test_update(self):
        """update 메서드 테스트"""
        updates = {
            'key1': 'value1',
            'key2': 42,
            'key3': [1, 2, 3]
        }
        self.game_state.update(updates)
        
        self.assertEqual(self.game_state.get('key1'), 'value1')
        self.assertEqual(self.game_state.get('key2'), 42)
        self.assertEqual(self.game_state.get('key3'), [1, 2, 3])
        
    def test_reset(self):
        """리셋 테스트"""
        self.game_state.set('test', 123)
        self.game_state.reset()
        self.assertIsNone(self.game_state.get('test'))


class TestEventManager(GameTestCase):
    """EventManager 테스트"""
    
    def setUp(self):
        super().setUp()
        self.event_manager = EventManager.get_instance()
        self.event_manager.clear_listeners()
        self.received_events = []
        
    def test_singleton(self):
        """싱글톤 패턴 테스트"""
        manager1 = EventManager.get_instance()
        manager2 = EventManager.get_instance()
        self.assertIs(manager1, manager2)
        
    def test_subscribe_emit(self):
        """이벤트 구독 및 발생 테스트"""
        def handler(event):
            self.received_events.append(event)
            
        self.event_manager.subscribe(EventType.GAME_START, handler)
        self.event_manager.emit(EventType.GAME_START, {'test': 'data'})
        
        self.assertEqual(len(self.received_events), 1)
        self.assertEqual(self.received_events[0].type, EventType.GAME_START)
        self.assertEqual(self.received_events[0].data['test'], 'data')
        
    def test_unsubscribe(self):
        """구독 해제 테스트"""
        def handler(event):
            self.received_events.append(event)
            
        self.event_manager.subscribe(EventType.GAME_START, handler)
        self.event_manager.unsubscribe(EventType.GAME_START, handler)
        self.event_manager.emit(EventType.GAME_START)
        
        self.assertEqual(len(self.received_events), 0)
        
    def test_multiple_handlers(self):
        """다중 핸들러 테스트"""
        counter = {'count': 0}
        
        def handler1(event):
            counter['count'] += 1
            
        def handler2(event):
            counter['count'] += 10
            
        self.event_manager.subscribe(EventType.GAME_START, handler1)
        self.event_manager.subscribe(EventType.GAME_START, handler2)
        self.event_manager.emit(EventType.GAME_START)
        
        self.assertEqual(counter['count'], 11)
        
    def test_event_queue(self):
        """이벤트 큐 테스트"""
        def handler(event):
            self.received_events.append(event)
            
        self.event_manager.subscribe(EventType.GAME_START, handler)
        
        # 큐에 추가 (즉시 처리하지 않음)
        self.event_manager.emit(EventType.GAME_START, immediate=False)
        self.assertEqual(len(self.received_events), 0)
        
        # 큐 처리
        self.event_manager.process_queue()
        self.assertEqual(len(self.received_events), 1)


class TestEventTypes(GameTestCase):
    """EventType 테스트"""
    
    def test_event_types_exist(self):
        """필수 이벤트 타입 존재 확인"""
        required_events = [
            'GAME_START', 'GAME_PAUSE', 'GAME_RESUME', 'GAME_OVER',
            'ROUND_START', 'ROUND_END', 'PLAYER_SCORE', 'AI_SCORE',
            'BALL_HIT_PLAYER', 'BALL_HIT_BOSS', 'BALL_HIT_WALL'
        ]
        
        for event_name in required_events:
            self.assertTrue(hasattr(EventType, event_name), 
                          f"EventType.{event_name} does not exist")
            
    def test_event_type_values(self):
        """이벤트 타입 값 확인"""
        # 이벤트 타입이 문자열 값을 가지는지 확인
        self.assertIsInstance(EventType.GAME_START.value, str)
        self.assertIsInstance(EventType.GAME_OVER.value, str)
        
        # 이벤트 타입이 고유한 값을 가지는지 확인
        event_values = set()
        for event in EventType:
            self.assertNotIn(event.value, event_values, 
                           f"Duplicate event value: {event.value}")
            event_values.add(event.value)


class TestIntegration(GameTestCase):
    """통합 테스트"""
    
    def test_game_state_with_events(self):
        """GameState와 EventManager 통합 테스트"""
        game_state = GameState.get_instance()
        event_manager = EventManager.get_instance()
        event_manager.clear_listeners()
        
        # 이벤트 핸들러에서 GameState 업데이트
        def on_score(event):
            current_score = game_state.get('player_score', 0)
            game_state.set('player_score', current_score + event.data.get('points', 1))
            
        event_manager.subscribe(EventType.PLAYER_SCORE, on_score)
        
        # 초기 점수
        game_state.set('player_score', 0)
        
        # 점수 이벤트 발생
        event_manager.emit(EventType.PLAYER_SCORE, {'points': 10})
        self.assertEqual(game_state.get('player_score'), 10)
        
        # 또 다른 점수 이벤트
        event_manager.emit(EventType.PLAYER_SCORE, {'points': 5})
        self.assertEqual(game_state.get('player_score'), 15)


if __name__ == '__main__':
    unittest.main()
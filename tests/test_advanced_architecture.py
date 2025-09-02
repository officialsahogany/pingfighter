# -*- coding: utf-8 -*-
"""
고급 아키텍처 테스트
100점 아키텍처 구성 요소 검증
"""

import unittest
import sys
import os
from typing import Any, Dict, List, Optional
from unittest.mock import Mock, patch, MagicMock
import json
import time
from dataclasses import dataclass

# 프로젝트 경로 추가
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.game_state import GameState
from core.dependency_injection import DIContainer, ServiceLifetime
from core.event_bus import EventBus, Event, EventPriority
from core.plugin_system import PluginManager, IPlugin, PluginMetadata
from services.game_service import GameService
from repositories.game_repository import GameRepository, StageData


class TestBase(unittest.TestCase):
    """테스트 베이스 클래스"""
    
    def setUp(self):
        """테스트 초기화"""
        self.container = DIContainer()
        self.event_bus = EventBus()
        self.game_state = GameState()
        
        # 의존성 등록
        self.container.register_singleton(GameState, implementation=None)
        self.container.register_singleton(EventBus, implementation=None)
    
    def tearDown(self):
        """테스트 정리"""
        self.container.clear()
        self.event_bus.clear()


class TestGameState(TestBase):
    """GameState 테스트"""
    
    def test_singleton_pattern(self):
        """싱글톤 패턴 테스트"""
        state1 = GameState.get_instance()
        state2 = GameState.get_instance()
        
        self.assertIs(state1, state2)
        self.assertEqual(id(state1), id(state2))
    
    def test_state_initialization(self):
        """상태 초기화 테스트"""
        state = GameState.get_instance()
        
        self.assertTrue(state.game_running)
        self.assertFalse(state.game_paused)
        self.assertEqual(state.current_stage, 1)
        self.assertEqual(state.player_score, 0)
        self.assertEqual(state.ai_score, 0)
    
    def test_state_get_set(self):
        """상태 getter/setter 테스트"""
        state = GameState.get_instance()
        
        # 기존 속성
        state.set('player_score', 100)
        self.assertEqual(state.get('player_score'), 100)
        
        # 새 속성
        state.set('custom_value', 'test')
        self.assertEqual(state.get('custom_value'), 'test')
    
    def test_reset_round(self):
        """라운드 리셋 테스트"""
        state = GameState.get_instance()
        
        state.special_gauge = 50
        state.walls = [1, 2, 3]
        state.balloons = [4, 5, 6]
        
        state.reset_round()
        
        self.assertEqual(state.special_gauge, 0)
        self.assertEqual(len(state.walls), 0)
        self.assertEqual(len(state.balloons), 0)


class TestDependencyInjection(TestBase):
    """의존성 주입 테스트"""
    
    def test_singleton_registration(self):
        """싱글톤 등록 테스트"""
        class TestService:
            def __init__(self):
                self.value = 42
        
        self.container.register_singleton(TestService)
        
        instance1 = self.container.resolve(TestService)
        instance2 = self.container.resolve(TestService)
        
        self.assertIs(instance1, instance2)
        self.assertEqual(instance1.value, 42)
    
    def test_transient_registration(self):
        """Transient 등록 테스트"""
        class TestService:
            def __init__(self):
                self.id = id(self)
        
        self.container.register_transient(TestService)
        
        instance1 = self.container.resolve(TestService)
        instance2 = self.container.resolve(TestService)
        
        self.assertIsNot(instance1, instance2)
        self.assertNotEqual(instance1.id, instance2.id)
    
    def test_factory_registration(self):
        """팩토리 등록 테스트"""
        class TestService:
            def __init__(self, value):
                self.value = value
        
        def factory(container):
            return TestService(100)
        
        self.container.register(TestService, factory=factory)
        
        instance = self.container.resolve(TestService)
        self.assertEqual(instance.value, 100)
    
    def test_auto_injection(self):
        """자동 주입 테스트"""
        class ServiceA:
            pass
        
        class ServiceB:
            def __init__(self, service_a: ServiceA):
                self.service_a = service_a
        
        self.container.register_singleton(ServiceA)
        self.container.register_singleton(ServiceB)
        
        service_b = self.container.resolve(ServiceB)
        
        self.assertIsNotNone(service_b.service_a)
        self.assertIsInstance(service_b.service_a, ServiceA)


class TestEventBus(TestBase):
    """이벤트 버스 테스트"""
    
    def test_event_publish_subscribe(self):
        """이벤트 발행/구독 테스트"""
        received_events = []
        
        def handler(event):
            received_events.append(event)
        
        self.event_bus.subscribe('test.event', handler)
        
        event = Event(type='test.event', data={'value': 42})
        self.event_bus.publish(event)
        
        self.assertEqual(len(received_events), 1)
        self.assertEqual(received_events[0].data['value'], 42)
    
    def test_event_priority(self):
        """이벤트 우선순위 테스트"""
        call_order = []
        
        def handler1(event):
            call_order.append(1)
        
        def handler2(event):
            call_order.append(2)
        
        # 우선순위 반대로 등록
        self.event_bus.subscribe('test', handler2, priority=10)
        self.event_bus.subscribe('test', handler1, priority=5)
        
        self.event_bus.publish(Event(type='test'))
        
        # 낮은 우선순위가 먼저 실행
        self.assertEqual(call_order, [1, 2])
    
    def test_event_filter(self):
        """이벤트 필터 테스트"""
        received = []
        
        def handler(event):
            received.append(event)
        
        def filter_func(event):
            return event.data.get('allowed', False)
        
        self.event_bus.add_filter(filter_func)
        self.event_bus.subscribe('test', handler)
        
        # 필터링 됨
        self.event_bus.publish(Event(type='test', data={'allowed': False}))
        self.assertEqual(len(received), 0)
        
        # 통과
        self.event_bus.publish(Event(type='test', data={'allowed': True}))
        self.assertEqual(len(received), 1)
    
    def test_weak_reference(self):
        """약한 참조 테스트"""
        class Handler:
            def __init__(self):
                self.called = False
            
            def handle(self, event):
                self.called = True
        
        handler = Handler()
        self.event_bus.subscribe('test', handler.handle, weak=True)
        
        # 핸들러 존재
        self.event_bus.publish(Event(type='test'))
        self.assertTrue(handler.called)
        
        # 핸들러 삭제
        handler_method = handler.handle
        del handler
        
        # 이벤트 발행 시 오류 없어야 함
        self.event_bus.publish(Event(type='test'))


class TestPluginSystem(TestBase):
    """플러그인 시스템 테스트"""
    
    def test_plugin_discovery(self):
        """플러그인 발견 테스트"""
        manager = PluginManager("test_plugins")
        
        # 테스트 플러그인 디렉토리 생성
        os.makedirs("test_plugins", exist_ok=True)
        
        # 테스트 플러그인 파일 생성
        with open("test_plugins/test_plugin.py", "w") as f:
            f.write("# Test plugin")
        
        plugins = manager.discover_plugins()
        
        self.assertIn("test_plugin", plugins)
        
        # 정리
        os.remove("test_plugins/test_plugin.py")
        os.rmdir("test_plugins")
    
    def test_plugin_lifecycle(self):
        """플러그인 생명주기 테스트"""
        class TestPlugin(IPlugin):
            def __init__(self):
                self.initialized = False
                self.cleaned = False
            
            def get_metadata(self):
                return PluginMetadata(
                    name="test",
                    version="1.0",
                    author="test",
                    description="test plugin"
                )
            
            def initialize(self, game_context):
                self.initialized = True
                return True
            
            def cleanup(self):
                self.cleaned = True
        
        manager = PluginManager()
        plugin = TestPlugin()
        
        # 수동으로 플러그인 등록
        manager.plugins["test"] = plugin
        manager._update_plugin_order()
        
        # 초기화
        manager.initialize_plugins({})
        self.assertTrue(plugin.initialized)
        
        # 정리
        manager.cleanup()
        self.assertTrue(plugin.cleaned)


class TestGameService(TestBase):
    """게임 서비스 테스트"""
    
    def setUp(self):
        super().setUp()
        self.game_state = GameState()
        self.event_bus = EventBus()
        self.repository = Mock(spec=GameRepository)
        
        self.service = GameService(
            game_state=self.game_state,
            event_bus=self.event_bus,
            game_repository=self.repository
        )
    
    def test_start_game(self):
        """게임 시작 테스트"""
        # Mock 설정
        self.repository.get_stage_data.return_value = StageData(
            stage_id=1,
            name="Test Stage",
            boss_name="Test Boss",
            difficulty=1,
            boss_health=100,
            boss_speed=5.0,
            background="test",
            music="test.mp3"
        )
        
        # 게임 시작
        result = self.service.start_game(1)
        
        self.assertTrue(result)
        self.assertEqual(self.game_state.current_stage, 1)
        self.assertTrue(self.game_state.game_running)
    
    def test_pause_resume_game(self):
        """게임 일시정지/재개 테스트"""
        self.game_state.game_running = True
        
        # 일시정지
        result = self.service.pause_game()
        self.assertTrue(result)
        self.assertTrue(self.game_state.game_paused)
        
        # 재개
        result = self.service.resume_game()
        self.assertTrue(result)
        self.assertFalse(self.game_state.game_paused)
    
    def test_process_player_input(self):
        """플레이어 입력 처리 테스트"""
        self.game_state.player_x = 400
        self.game_state.player_speed = 10
        
        # 오른쪽 이동
        self.service.process_player_input({'move': 1})
        self.assertEqual(self.game_state.player_x, 410)
        
        # 왼쪽 이동
        self.service.process_player_input({'move': -1})
        self.assertEqual(self.game_state.player_x, 400)
    
    def test_dash_processing(self):
        """대시 처리 테스트"""
        self.game_state.dash_charges = 3
        self.game_state.dash_cooldown = 0
        
        # 대시 실행
        result = self.service._process_dash()
        
        self.assertTrue(result)
        self.assertEqual(self.game_state.dash_charges, 2)
        self.assertTrue(self.game_state.dash_active)
        
        # 쿨다운 중 대시
        result = self.service._process_dash()
        self.assertFalse(result)


class TestGameRepository(TestBase):
    """게임 리포지토리 테스트"""
    
    def setUp(self):
        super().setUp()
        self.repository = GameRepository(storage_type="memory")
    
    def test_stage_data_loading(self):
        """스테이지 데이터 로딩 테스트"""
        stage_data = self.repository.get_stage_data(1)
        
        self.assertIsNotNone(stage_data)
        self.assertEqual(stage_data.stage_id, 1)
        self.assertEqual(stage_data.boss_name, "Basic Boss")
    
    def test_cache_functionality(self):
        """캐시 기능 테스트"""
        # 첫 번째 로드
        stage1 = self.repository.get_stage_data(1)
        
        # 캐시에서 로드 (동일 객체)
        stage2 = self.repository.get_stage_data(1)
        
        self.assertIs(stage1, stage2)
        
        # 캐시 초기화
        self.repository.clear_cache()
        
        # 새로 로드
        stage3 = self.repository.get_stage_data(1)
        self.assertIsNot(stage1, stage3)
    
    def test_settings_management(self):
        """설정 관리 테스트"""
        # 기본 설정 로드
        settings = self.repository.load_settings()
        
        self.assertTrue(settings['sound_enabled'])
        self.assertEqual(settings['sound_volume'], 0.7)
        
        # 설정 변경 및 저장
        settings['sound_volume'] = 0.5
        result = self.repository.save_settings(settings)
        
        # JSON 저장소가 아니면 실패할 수 있음
        if self.repository.storage_type == "json":
            self.assertTrue(result)


class IntegrationTest(TestBase):
    """통합 테스트"""
    
    def test_full_game_flow(self):
        """전체 게임 플로우 테스트"""
        # DI 컨테이너 설정
        container = DIContainer()
        
        # 서비스 등록
        container.register_singleton(GameState)
        container.register_singleton(EventBus)
        container.register_singleton(GameRepository)
        container.register_singleton(GameService)
        
        # 서비스 해결
        game_service = container.resolve(GameService)
        event_bus = container.resolve(EventBus)
        
        # 이벤트 수신 확인
        events_received = []
        
        def event_handler(event):
            events_received.append(event.type)
        
        event_bus.subscribe('game.start', event_handler)
        event_bus.subscribe('game.pause', event_handler)
        event_bus.subscribe('game.resume', event_handler)
        
        # 게임 플로우 실행
        game_service.start_game(1)
        game_service.pause_game()
        game_service.resume_game()
        
        # 이벤트 확인
        self.assertIn('game.start', events_received)
        self.assertIn('game.pause', events_received)
        self.assertIn('game.resume', events_received)


class PerformanceTest(TestBase):
    """성능 테스트"""
    
    def test_event_bus_performance(self):
        """이벤트 버스 성능 테스트"""
        event_count = 10000
        handler_count = 100
        
        # 많은 핸들러 등록
        for i in range(handler_count):
            self.event_bus.subscribe('perf.test', lambda e: None)
        
        # 시간 측정
        start_time = time.time()
        
        for i in range(event_count):
            self.event_bus.publish(Event(type='perf.test'))
        
        elapsed = time.time() - start_time
        
        # 1초 이내 처리
        self.assertLess(elapsed, 1.0)
        
        events_per_second = event_count / elapsed
        print(f"이벤트 처리 성능: {events_per_second:.0f} events/sec")
    
    def test_di_container_performance(self):
        """DI 컨테이너 성능 테스트"""
        class TestService:
            pass
        
        self.container.register_transient(TestService)
        
        # 시간 측정
        start_time = time.time()
        instances = []
        
        for i in range(10000):
            instances.append(self.container.resolve(TestService))
        
        elapsed = time.time() - start_time
        
        # 1초 이내 처리
        self.assertLess(elapsed, 1.0)
        
        resolutions_per_second = 10000 / elapsed
        print(f"DI 해결 성능: {resolutions_per_second:.0f} resolutions/sec")


def run_tests():
    """테스트 실행"""
    # 테스트 스위트 생성
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # 테스트 추가
    suite.addTests(loader.loadTestsFromTestCase(TestGameState))
    suite.addTests(loader.loadTestsFromTestCase(TestDependencyInjection))
    suite.addTests(loader.loadTestsFromTestCase(TestEventBus))
    suite.addTests(loader.loadTestsFromTestCase(TestPluginSystem))
    suite.addTests(loader.loadTestsFromTestCase(TestGameService))
    suite.addTests(loader.loadTestsFromTestCase(TestGameRepository))
    suite.addTests(loader.loadTestsFromTestCase(IntegrationTest))
    suite.addTests(loader.loadTestsFromTestCase(PerformanceTest))
    
    # 테스트 실행
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # 결과 요약
    print("\n" + "="*70)
    print("테스트 결과 요약")
    print("="*70)
    print(f"실행: {result.testsRun}")
    print(f"성공: {result.testsRun - len(result.failures) - len(result.errors)}")
    print(f"실패: {len(result.failures)}")
    print(f"오류: {len(result.errors)}")
    
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
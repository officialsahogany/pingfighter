"""
Test Base - 테스트 기본 클래스
모든 테스트의 베이스 클래스 및 유틸리티
"""

import unittest
import pygame
import tempfile
import shutil
from pathlib import Path
from typing import Any, Optional
from unittest.mock import Mock, MagicMock, patch

# 프로젝트 모듈
from core.global_manager import GlobalManager
from core.events import EventManager, EventType
from core.game_state import GameState


class BaseTest(unittest.TestCase):
    """테스트 기본 클래스"""
    
    @classmethod
    def setUpClass(cls):
        """클래스 레벨 설정"""
        # Pygame 초기화 (한 번만)
        if not pygame.get_init():
            pygame.init()
            
    def setUp(self):
        """각 테스트 전 실행"""
        # 싱글톤 리셋
        self.reset_singletons()
        
        # 임시 디렉토리 생성
        self.temp_dir = tempfile.mkdtemp()
        self.temp_path = Path(self.temp_dir)
        
        # Mock 화면 생성
        self.mock_screen = MagicMock(spec=pygame.Surface)
        self.mock_screen.get_width.return_value = 600
        self.mock_screen.get_height.return_value = 750
        
        # GlobalManager 초기화
        self.global_manager = GlobalManager.get_instance()
        self.global_manager.set('screen', self.mock_screen)
        self.global_manager.set('WIDTH', 600)
        self.global_manager.set('HEIGHT', 750)
        self.global_manager.set('fps', 60)
        
        # EventManager 초기화
        self.event_manager = EventManager.get_instance()
        
        # GameState 초기화
        self.game_state = GameState.get_instance()
        
    def tearDown(self):
        """각 테스트 후 실행"""
        # 임시 디렉토리 삭제
        if self.temp_dir and Path(self.temp_dir).exists():
            shutil.rmtree(self.temp_dir)
            
        # 싱글톤 리셋
        self.reset_singletons()
        
    def reset_singletons(self):
        """싱글톤 인스턴스 리셋"""
        # GlobalManager 리셋
        GlobalManager._instance = None
        
        # EventManager 리셋
        EventManager._instance = None
        
        # GameState 리셋
        GameState._instance = None
        
    def create_mock_surface(self, width: int = 64, height: int = 64) -> Mock:
        """Mock Surface 생성"""
        mock_surface = Mock(spec=pygame.Surface)
        mock_surface.get_width.return_value = width
        mock_surface.get_height.return_value = height
        mock_surface.get_rect.return_value = pygame.Rect(0, 0, width, height)
        mock_surface.get_size.return_value = (width, height)
        return mock_surface
        
    def create_mock_rect(self, x: int = 0, y: int = 0, 
                        width: int = 50, height: int = 50) -> pygame.Rect:
        """Mock Rect 생성"""
        return pygame.Rect(x, y, width, height)
        
    def create_temp_file(self, filename: str, content: str = "") -> Path:
        """임시 파일 생성"""
        file_path = self.temp_path / filename
        file_path.write_text(content)
        return file_path
        
    def assert_event_emitted(self, event_type: EventType, 
                           timeout: float = 1.0) -> Optional[Any]:
        """이벤트 발생 확인"""
        # 이벤트 히스토리 확인
        history = self.event_manager.get_history()
        for event in history:
            if event.type == event_type:
                return event.data
        return None
        
    def assert_no_event_emitted(self, event_type: EventType):
        """이벤트 미발생 확인"""
        history = self.event_manager.get_history()
        for event in history:
            if event.type == event_type:
                self.fail(f"Event {event_type} was emitted but should not have been")
                
    def simulate_key_press(self, key: int):
        """키 입력 시뮬레이션"""
        event = pygame.event.Event(pygame.KEYDOWN, {'key': key})
        pygame.event.post(event)
        
    def simulate_key_release(self, key: int):
        """키 해제 시뮬레이션"""
        event = pygame.event.Event(pygame.KEYUP, {'key': key})
        pygame.event.post(event)
        
    def simulate_mouse_click(self, x: int, y: int, button: int = 1):
        """마우스 클릭 시뮬레이션"""
        event = pygame.event.Event(pygame.MOUSEBUTTONDOWN, {
            'pos': (x, y),
            'button': button
        })
        pygame.event.post(event)
        
    def advance_time(self, seconds: float):
        """시간 진행 시뮬레이션"""
        # pygame.time.Clock의 tick을 시뮬레이션
        dt = seconds
        return dt


class MockComponent:
    """테스트용 Mock 컴포넌트"""
    
    def __init__(self, name: str = "MockComponent"):
        self.name = name
        self.update_called = False
        self.render_called = False
        self.reset_called = False
        
    def update(self, dt: float):
        """업데이트"""
        self.update_called = True
        
    def render(self, screen: pygame.Surface):
        """렌더링"""
        self.render_called = True
        
    def reset(self):
        """리셋"""
        self.reset_called = True
        
    def was_called(self) -> bool:
        """호출 여부 확인"""
        return self.update_called or self.render_called or self.reset_called


def run_tests(test_module=None):
    """테스트 실행 헬퍼"""
    if test_module:
        suite = unittest.TestLoader().loadTestsFromModule(test_module)
    else:
        suite = unittest.TestLoader().discover('tests', pattern='test_*.py')
        
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # 결과 요약
    print("\n" + "="*50)
    print("📊 테스트 결과 요약")
    print(f"  실행: {result.testsRun}개")
    print(f"  성공: {result.testsRun - len(result.failures) - len(result.errors)}개")
    print(f"  실패: {len(result.failures)}개")
    print(f"  에러: {len(result.errors)}개")
    print("="*50)
    
    return result.wasSuccessful()
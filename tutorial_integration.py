"""
튜토리얼 통합 헬퍼 모듈
pingfighter.py와 새로운 튜토리얼 시스템을 연결
"""

import pygame
import logging
from typing import Optional
from tutorial import TutorialManager, GameInterfaceImpl

logger = logging.getLogger(__name__)


class TutorialIntegration:
    """튜토리얼 시스템 통합 클래스"""
    
    def __init__(self, globals_dict: dict):
        """
        초기화
        
        Args:
            globals_dict: pingfighter.py의 globals() 딕셔너리
        """
        self.globals_dict = globals_dict
        self.tutorial_manager: Optional[TutorialManager] = None
        self.game_interface = None
        self.is_tutorial_mode = False
        
    def initialize(self):
        """튜토리얼 시스템 초기화"""
        try:
            # 게임 인터페이스 생성
            self.game_interface = GameInterfaceImpl(self.globals_dict)
            
            # 튜토리얼 매니저 생성
            self.tutorial_manager = TutorialManager(self.game_interface)
            
            logger.info("Tutorial system initialized successfully")
            return True
        except Exception as e:
            logger.error(f"Failed to initialize tutorial system: {e}")
            return False
    
    def start_tutorial(self) -> bool:
        """
        튜토리얼 시작
        
        Returns:
            bool: 시작 성공 여부
        """
        if not self.tutorial_manager:
            if not self.initialize():
                return False
        
        # 튜토리얼 시작
        if self.tutorial_manager.start():
            self.is_tutorial_mode = True
            
            # 게임 상태 설정
            self.globals_dict['tutorial_mode'] = True
            self.globals_dict['current_stage'] = -1  # 튜토리얼 스테이지
            
            return True
        return False
    
    def update(self, dt: float):
        """
        튜토리얼 업데이트
        
        Args:
            dt: 델타 타임
        """
        if self.tutorial_manager and self.is_tutorial_mode:
            self.tutorial_manager.update(dt)
    
    def render(self, screen: pygame.Surface):
        """
        튜토리얼 렌더링
        
        Args:
            screen: 화면
        """
        if self.tutorial_manager and self.is_tutorial_mode:
            self.tutorial_manager.render(screen)
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """
        이벤트 처리
        
        Args:
            event: pygame 이벤트
            
        Returns:
            bool: 이벤트 처리 여부
        """
        if self.tutorial_manager and self.is_tutorial_mode:
            return self.tutorial_manager.handle_event(event)
        return False
    
    def on_game_event(self, event_type: str, data: dict = None):
        """
        게임 이벤트 전달
        
        Args:
            event_type: 이벤트 타입
            data: 이벤트 데이터
        """
        if self.tutorial_manager and self.is_tutorial_mode:
            self.tutorial_manager.on_game_event(event_type, data)
    
    def is_active(self) -> bool:
        """
        튜토리얼 활성 상태
        
        Returns:
            bool: 활성 여부
        """
        return self.is_tutorial_mode
    
    def end_tutorial(self):
        """튜토리얼 종료"""
        if self.tutorial_manager:
            self.is_tutorial_mode = False
            self.globals_dict['tutorial_mode'] = False
            self.globals_dict['current_stage'] = 0
            
            # 게임 상태 리셋
            self.game_interface.reset_game_state()
            
    def skip_tutorial(self):
        """튜토리얼 건너뛰기"""
        if self.tutorial_manager:
            self.tutorial_manager.skip()
            self.end_tutorial()


# 전역 인스턴스
_tutorial_integration: Optional[TutorialIntegration] = None


def get_tutorial_integration(globals_dict: dict = None) -> TutorialIntegration:
    """
    튜토리얼 통합 인스턴스 반환
    
    Args:
        globals_dict: pingfighter.py의 globals() (최초 호출 시 필요)
        
    Returns:
        TutorialIntegration: 튜토리얼 통합 인스턴스
    """
    global _tutorial_integration
    
    if _tutorial_integration is None:
        if globals_dict is None:
            raise ValueError("globals_dict is required for first initialization")
        _tutorial_integration = TutorialIntegration(globals_dict)
    
    return _tutorial_integration


# pingfighter.py에서 호출할 함수들

def init_tutorial_system(globals_dict: dict) -> bool:
    """
    튜토리얼 시스템 초기화 (pingfighter.py에서 호출)
    
    Args:
        globals_dict: pingfighter.py의 globals()
        
    Returns:
        bool: 초기화 성공 여부
    """
    integration = get_tutorial_integration(globals_dict)
    return integration.initialize()


def show_tutorial_dialog() -> bool:
    """
    튜토리얼 대화 표시 (기존 함수 대체)
    
    Returns:
        bool: 튜토리얼 시작 여부
    """
    integration = get_tutorial_integration()
    return integration.start_tutorial()


def update_tutorial(dt: float):
    """튜토리얼 업데이트 (메인 루프에서 호출)"""
    integration = get_tutorial_integration()
    if integration.is_active():
        integration.update(dt)


def render_tutorial(screen: pygame.Surface):
    """튜토리얼 렌더링 (메인 루프에서 호출)"""
    integration = get_tutorial_integration()
    if integration.is_active():
        integration.render(screen)


def handle_tutorial_event(event: pygame.event.Event) -> bool:
    """튜토리얼 이벤트 처리"""
    integration = get_tutorial_integration()
    if integration.is_active():
        return integration.handle_event(event)
    return False


def notify_tutorial_event(event_type: str, data: dict = None):
    """튜토리얼에 게임 이벤트 알림"""
    integration = get_tutorial_integration()
    if integration.is_active():
        integration.on_game_event(event_type, data)


# 기존 튜토리얼 함수들을 대체하는 더미 함수들
# (기존 코드와의 호환성 유지)

def draw_tutorial_ui():
    """기존 함수 대체"""
    pass

def draw_tutorial_progress_bar():
    """기존 함수 대체"""
    pass

def draw_tutorial_dash_counter():
    """기존 함수 대체"""
    pass

def draw_tutorial_drive_counter():
    """기존 함수 대체"""
    pass

def draw_tutorial_power_counter():
    """기존 함수 대체"""
    pass

def draw_tutorial_success_feedback():
    """기존 함수 대체"""
    pass

def show_tutorial_intro_dialogue():
    """기존 함수 대체"""
    return True

def show_tutorial_miss_dialogue():
    """기존 함수 대체"""
    pass

def show_tutorial_dash_dialogue():
    """기존 함수 대체"""
    return True

def show_tutorial_drive_dialogue():
    """기존 함수 대체"""
    return True

def show_tutorial_power_practice_dialogue():
    """기존 함수 대체"""
    return True
"""
챕터 베이스 클래스
모든 튜토리얼 챕터의 기본 클래스
"""

import pygame
import logging
from abc import ABC, abstractmethod
from typing import Optional, Dict, Any
from ..game_interface import GameInterface
from ..state import TutorialState
from ..dialogue import DialogueSystem, DialogueLine, DialogueType

logger = logging.getLogger(__name__)


class BaseChapter(ABC):
    """튜토리얼 챕터 추상 베이스 클래스"""
    
    def __init__(self, game_interface: GameInterface, 
                 tutorial_state: TutorialState,
                 dialogue_system: DialogueSystem):
        """
        초기화
        
        Args:
            game_interface: 게임 인터페이스
            tutorial_state: 튜토리얼 상태
            dialogue_system: 대화 시스템
        """
        self.game = game_interface
        self.state = tutorial_state
        self.dialogue = dialogue_system
        
        # 챕터 상태
        self.is_started = False
        self.is_completed = False
        
        # 타이머
        self.timer = 0.0
        self.event_timer = 0.0
        
        logger.info(f"{self.__class__.__name__} initialized")
    
    @abstractmethod
    def start(self):
        """챕터 시작"""
        self.is_started = True
        self.is_completed = False
        self.timer = 0.0
        
        # 챕터 상태 초기화
        chapter_state = self.state.get_current_chapter_state()
        chapter_state.started = True
        chapter_state.reset()
        
        logger.info(f"{self.__class__.__name__} started")
    
    @abstractmethod
    def update(self, dt: float):
        """
        챕터 업데이트
        
        Args:
            dt: 델타 타임
        """
        self.timer += dt
        
        # 완료 체크
        if not self.is_completed and self.check_completion():
            self.complete()
    
    @abstractmethod
    def render(self, screen: pygame.Surface):
        """
        챕터 렌더링
        
        Args:
            screen: 화면
        """
        pass
    
    @abstractmethod
    def handle_event(self, event: pygame.event.Event) -> bool:
        """
        이벤트 처리
        
        Args:
            event: pygame 이벤트
            
        Returns:
            bool: 이벤트 처리 여부
        """
        return False
    
    @abstractmethod
    def on_game_event(self, event_type: str, data: Optional[Dict[str, Any]] = None):
        """
        게임 이벤트 처리
        
        Args:
            event_type: 이벤트 타입
            data: 이벤트 데이터
        """
        pass
    
    @abstractmethod
    def check_completion(self) -> bool:
        """
        완료 조건 체크
        
        Returns:
            bool: 완료 여부
        """
        chapter_state = self.state.get_current_chapter_state()
        return chapter_state.is_complete()
    
    def complete(self):
        """챕터 완료 처리"""
        self.is_completed = True
        
        # 상태 업데이트
        chapter_state = self.state.get_current_chapter_state()
        chapter_state.completed = True
        chapter_state.progress = 1.0
        
        logger.info(f"{self.__class__.__name__} completed")
    
    def is_complete(self) -> bool:
        """
        완료 여부 반환
        
        Returns:
            bool: 완료 여부
        """
        return self.is_completed
    
    @abstractmethod
    def show_intro_dialogue(self):
        """인트로 대화 표시"""
        pass
    
    @abstractmethod
    def show_completion_dialogue(self):
        """완료 대화 표시"""
        pass
    
    def show_helper_dialogue(self):
        """도우미 대화 표시"""
        chapter_state = self.state.get_current_chapter_state()
        if not chapter_state.helper_shown:
            chapter_state.helper_shown = True
            self.state.ui_states['helper_visible'] = True
    
    def hide_helper(self):
        """도우미 숨기기"""
        self.state.ui_states['helper_visible'] = False
    
    def show_feedback(self, message: str, level: str = "normal"):
        """
        피드백 표시
        
        Args:
            message: 피드백 메시지
            level: 피드백 레벨
        """
        self.state.ui_states['feedback_active'] = True
        self.state.ui_states['feedback_message'] = message
        self.state.ui_states['feedback_level'] = level
        self.state.ui_states['feedback_timer'] = 2.0
    
    def update_progress(self):
        """진행도 업데이트"""
        chapter_state = self.state.get_current_chapter_state()
        
        # 각 챕터별 진행도 계산
        if hasattr(chapter_state, 'target_count'):
            progress = chapter_state.success_count / chapter_state.target_count
        else:
            progress = 0.0
        
        chapter_state.progress = min(1.0, progress)
        self.state.update_chapter_progress(chapter_state.progress)
    
    def reset_game_state(self):
        """게임 상태 초기화"""
        self.game.reset_game_state()
    
    def pause_game(self):
        """게임 일시정지"""
        self.game.pause_game()
    
    def resume_game(self):
        """게임 재개"""
        self.game.resume_game()
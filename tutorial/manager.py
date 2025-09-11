"""
튜토리얼 매니저 모듈
튜토리얼 시스템의 메인 관리자 클래스
"""

import pygame
import logging
from typing import Optional, Dict, Any, List, Callable
from .state import TutorialState, TutorialChapter
from .game_interface import GameInterface
from .ui import TutorialUI
from .dialogue import DialogueSystem

logger = logging.getLogger(__name__)


class TutorialManager:
    """튜토리얼 시스템 통합 관리 클래스"""
    
    def __init__(self, game_interface: GameInterface):
        """
        초기화
        
        Args:
            game_interface: 게임과의 인터페이스 객체
        """
        self.game = game_interface
        self.state = TutorialState()
        self.ui = TutorialUI(game_interface)
        self.dialogue = DialogueSystem(game_interface)
        
        # 챕터 핸들러 매핑
        self.chapter_handlers: Dict[TutorialChapter, 'BaseChapter'] = {}
        self._init_chapters()
        
        # 이벤트 핸들러
        self.event_handlers: Dict[str, List[Callable]] = {
            'hit': [],
            'miss': [],
            'dash': [],
            'half_dash': [],
            'drive': [],
            'power_smash': [],
            'serve': [],
        }
        
        # 업데이트 플래그
        self.needs_update = True
        self.dialogue_active = False
        
        logger.info("TutorialManager initialized")
    
    def _init_chapters(self):
        """챕터 핸들러 초기화"""
        try:
            from .chapters import (
                IntroChapter, Chapter1Serve, Chapter2Dash,
                Chapter3Drive, Chapter4Power, CompleteChapter
            )
            
            self.chapter_handlers = {
                TutorialChapter.INTRO: IntroChapter(self.game, self.state, self.dialogue),
                TutorialChapter.CHAPTER_1_SERVE: Chapter1Serve(self.game, self.state, self.dialogue),
                TutorialChapter.CHAPTER_2_DASH: Chapter2Dash(self.game, self.state, self.dialogue),
                TutorialChapter.CHAPTER_3_DRIVE: Chapter3Drive(self.game, self.state, self.dialogue),
                TutorialChapter.CHAPTER_4_POWER: Chapter4Power(self.game, self.state, self.dialogue),
                TutorialChapter.COMPLETE: CompleteChapter(self.game, self.state, self.dialogue),
            }
        except ImportError as e:
            logger.warning(f"Could not import chapter modules: {e}")
            # 챕터 모듈이 없어도 기본 동작은 가능하도록
    
    def start(self) -> bool:
        """
        튜토리얼 시작
        
        Returns:
            bool: 시작 성공 여부
        """
        try:
            # 초기 대화 표시
            if self.dialogue.show_tutorial_dialog():
                self.state.start_tutorial()
                self.game.pause_game()
                
                # 인트로 챕터 시작
                if TutorialChapter.INTRO in self.chapter_handlers:
                    self.chapter_handlers[TutorialChapter.INTRO].start()
                
                logger.info("Tutorial started successfully")
                return True
            else:
                logger.info("User declined tutorial")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start tutorial: {e}")
            return False
    
    def update(self, dt: float):
        """
        튜토리얼 업데이트
        
        Args:
            dt: 델타 타임 (초)
        """
        if not self.state.is_active or self.state.is_paused:
            return
        
        try:
            # 현재 챕터 업데이트
            current_chapter = self.state.current_chapter
            if current_chapter in self.chapter_handlers:
                handler = self.chapter_handlers[current_chapter]
                handler.update(dt)
                
                # 챕터 완료 체크
                if handler.is_complete():
                    self._on_chapter_complete()
            
            # UI 업데이트
            self.ui.update(dt, self.state)
            
            # 피드백 타이머 업데이트
            if self.state.ui_states['feedback_active']:
                self.state.ui_states['feedback_timer'] -= dt
                if self.state.ui_states['feedback_timer'] <= 0:
                    self.state.ui_states['feedback_active'] = False
            
            # 애니메이션 업데이트
            if self.state.animation_states['celebration_active']:
                self.state.animation_states['celebration_timer'] -= dt
                if self.state.animation_states['celebration_timer'] <= 0:
                    self.state.animation_states['celebration_active'] = False
                    
        except Exception as e:
            logger.error(f"Error updating tutorial: {e}")
    
    def render(self, screen: pygame.Surface):
        """
        튜토리얼 UI 렌더링
        
        Args:
            screen: 렌더링할 화면
        """
        if not self.state.is_active:
            return
        
        try:
            # 현재 챕터 렌더링
            current_chapter = self.state.current_chapter
            if current_chapter in self.chapter_handlers:
                self.chapter_handlers[current_chapter].render(screen)
            
            # UI 오버레이 렌더링
            self.ui.render(screen, self.state)
            
            # 대화 렌더링
            if self.dialogue_active:
                self.dialogue.render(screen)
                
        except Exception as e:
            logger.error(f"Error rendering tutorial: {e}")
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """
        이벤트 처리
        
        Args:
            event: pygame 이벤트
            
        Returns:
            bool: 이벤트 처리 여부
        """
        if not self.state.is_active:
            return False
        
        # 대화 시스템이 이벤트 처리
        if self.dialogue_active:
            return self.dialogue.handle_event(event)
        
        # 현재 챕터가 이벤트 처리
        current_chapter = self.state.current_chapter
        if current_chapter in self.chapter_handlers:
            return self.chapter_handlers[current_chapter].handle_event(event)
        
        return False
    
    def on_game_event(self, event_type: str, data: Optional[Dict[str, Any]] = None):
        """
        게임 이벤트 처리
        
        Args:
            event_type: 이벤트 타입 (hit, miss, dash, etc.)
            data: 이벤트 데이터
        """
        if not self.state.is_active:
            return
        
        try:
            # 현재 챕터에 이벤트 전달
            current_chapter = self.state.current_chapter
            if current_chapter in self.chapter_handlers:
                self.chapter_handlers[current_chapter].on_game_event(event_type, data)
            
            # 등록된 이벤트 핸들러 실행
            if event_type in self.event_handlers:
                for handler in self.event_handlers[event_type]:
                    handler(data)
            
            # 상태 업데이트
            self._update_state_on_event(event_type, data)
            
        except Exception as e:
            logger.error(f"Error handling game event {event_type}: {e}")
    
    def _update_state_on_event(self, event_type: str, data: Optional[Dict[str, Any]]):
        """이벤트에 따른 상태 업데이트"""
        state = self.state.get_current_chapter_state()
        
        if event_type == 'hit':
            state.hit_count += 1
            self.show_feedback("좋아요!", "normal")
            
        elif event_type == 'miss':
            state.miss_count += 1
            self.show_feedback("다시 시도해보세요", "warning")
            
        elif event_type == 'dash':
            if hasattr(state, 'dash_count'):
                state.dash_count += 1
                self.show_feedback("대쉬 성공!", "success")
                
        elif event_type == 'half_dash':
            if hasattr(state, 'half_dash_count'):
                state.half_dash_count += 1
                self.show_feedback("하프대쉬 성공!", "success")
                
        elif event_type == 'drive':
            if hasattr(state, 'drive_count'):
                state.drive_count += 1
                self.show_feedback("드라이브 성공!", "great")
                
        elif event_type == 'power_smash':
            if hasattr(state, 'power_count'):
                state.power_count += 1
                self.show_feedback("파워스매싱!", "perfect")
    
    def show_feedback(self, message: str, level: str = "normal"):
        """
        피드백 메시지 표시
        
        Args:
            message: 표시할 메시지
            level: 피드백 레벨 (normal, warning, success, great, perfect)
        """
        self.state.ui_states['feedback_active'] = True
        self.state.ui_states['feedback_message'] = message
        self.state.ui_states['feedback_level'] = level
        self.state.ui_states['feedback_timer'] = 2.0  # 2초간 표시
        
        # 사운드 재생
        sound_map = {
            'success': 'success',
            'great': 'great',
            'perfect': 'perfect',
            'warning': 'warning',
        }
        
        if level in sound_map:
            self.game.play_sound(sound_map[level])
    
    def _on_chapter_complete(self):
        """챕터 완료 처리"""
        logger.info(f"Chapter {self.state.current_chapter.name} completed")
        
        # 현재 챕터 완료 표시
        self.state.mark_chapter_complete()
        
        # 완료 대화 표시
        current_chapter = self.state.current_chapter
        if current_chapter in self.chapter_handlers:
            self.chapter_handlers[current_chapter].show_completion_dialogue()
        
        # 다음 챕터로 진행
        if self.state.current_chapter != TutorialChapter.COMPLETE:
            self.state.advance_chapter()
            
            # 새 챕터 시작
            new_chapter = self.state.current_chapter
            if new_chapter in self.chapter_handlers:
                self.chapter_handlers[new_chapter].start()
        else:
            # 튜토리얼 완료
            self._complete_tutorial()
    
    def _complete_tutorial(self):
        """튜토리얼 완료 처리"""
        logger.info("Tutorial completed!")
        
        # 완료 대화 표시
        self.dialogue.show_completion_dialogue()
        
        # 상태 정리
        self.state.end_tutorial()
        
        # 게임 재개
        self.game.resume_game()
        
        # 완료 이벤트 발생
        self.on_tutorial_complete()
    
    def on_tutorial_complete(self):
        """튜토리얼 완료 후 호출되는 콜백"""
        # 게임에서 오버라이드하여 사용
        pass
    
    def pause(self):
        """튜토리얼 일시정지"""
        self.state.is_paused = True
        logger.info("Tutorial paused")
    
    def resume(self):
        """튜토리얼 재개"""
        self.state.is_paused = False
        logger.info("Tutorial resumed")
    
    def skip(self):
        """튜토리얼 건너뛰기"""
        if self.dialogue.confirm_skip():
            self.state.end_tutorial()
            self.game.resume_game()
            logger.info("Tutorial skipped by user")
    
    def reset(self):
        """튜토리얼 초기화"""
        self.state.reset()
        self.dialogue_active = False
        logger.info("Tutorial reset")
    
    def get_progress(self) -> float:
        """
        전체 진행도 반환
        
        Returns:
            float: 0.0 ~ 1.0 사이의 진행도
        """
        return self.state.overall_progress
    
    def is_active(self) -> bool:
        """
        튜토리얼 활성 상태 반환
        
        Returns:
            bool: 활성 여부
        """
        return self.state.is_active
    
    def get_current_chapter(self) -> TutorialChapter:
        """
        현재 챕터 반환
        
        Returns:
            TutorialChapter: 현재 챕터
        """
        return self.state.current_chapter
    
    def save(self) -> Dict[str, Any]:
        """
        저장 데이터 생성
        
        Returns:
            Dict: 저장용 데이터
        """
        return self.state.get_save_data()
    
    def load(self, data: Dict[str, Any]):
        """
        저장 데이터 로드
        
        Args:
            data: 저장된 데이터
        """
        self.state.load_save_data(data)
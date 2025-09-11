"""
챕터 2: 대쉬
대쉬와 하프대쉬, 연속대쉬 학습
"""

import pygame
from typing import Optional, Dict, Any
from .base import BaseChapter
from ..dialogue import DialogueLine, DialogueType
from ..state import DashChapterState


class Chapter2Dash(BaseChapter):
    """대쉬 챕터 클래스"""
    
    def start(self):
        """챕터 시작"""
        super().start()
        self.show_intro_dialogue()
        
        # UI 설정
        self.state.ui_states['progress_bar_visible'] = True
        self.state.ui_states['counter_visible'] = True
        
        # 게임 설정
        self.game.set_ball_speed(4.0)
        self.game.set_rolling_charges(3)  # 대쉬 토큰 3개
    
    def update(self, dt: float):
        """챕터 업데이트"""
        super().update(dt)
        
        chapter_state = self.state.get_current_chapter_state()
        if not isinstance(chapter_state, DashChapterState):
            return
        
        # 대쉬 토큰 설명
        if not chapter_state.dash_token_dialogue_shown and self.timer > 10.0:
            chapter_state.dash_token_dialogue_shown = True
            self.show_dash_token_dialogue()
        
        self.update_progress()
    
    def render(self, screen: pygame.Surface):
        """챕터 렌더링"""
        # 대쉬 키 가이드
        if self.state.ui_states.get('helper_visible'):
            self._draw_dash_guide(screen)
    
    def _draw_dash_guide(self, screen: pygame.Surface):
        """대쉬 가이드 표시"""
        width, height = self.game.get_screen_dimensions()
        font = self.game.get_font(24)
        
        guides = [
            "Space - 일반 대쉬",
            "Shift - 하프대쉬",
            "연속으로 - 연속대쉬"
        ]
        
        y = height // 2
        for guide in guides:
            text = font.render(guide, True, (0, 255, 255))
            text_rect = text.get_rect(centerx=width // 2, y=y)
            screen.blit(text, text_rect)
            y += 40
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                self.game.handle_player_input("dash")
                return True
            elif event.key in [pygame.K_LSHIFT, pygame.K_RSHIFT]:
                self.game.handle_player_input("half_dash")
                return True
        return False
    
    def on_game_event(self, event_type: str, data: Optional[Dict[str, Any]] = None):
        """게임 이벤트 처리"""
        chapter_state = self.state.get_current_chapter_state()
        if not isinstance(chapter_state, DashChapterState):
            return
        
        if event_type == 'dash':
            chapter_state.dash_count += 1
            self.show_feedback("대쉬 성공!", "success")
            
        elif event_type == 'half_dash':
            chapter_state.half_dash_count += 1
            self.show_feedback("하프대쉬 성공!", "success")
            
        elif event_type == 'consecutive_dash':
            chapter_state.consecutive_dash_count += 1
            self.show_feedback("연속대쉬 성공!", "great")
    
    def check_completion(self) -> bool:
        """완료 조건 체크"""
        chapter_state = self.state.get_current_chapter_state()
        if isinstance(chapter_state, DashChapterState):
            return chapter_state.is_complete()
        return False
    
    def show_intro_dialogue(self):
        """인트로 대화 표시"""
        dialogues = [
            DialogueLine("조교", "Chapter 2: 대쉬 시스템", DialogueType.INFO),
            DialogueLine("조교", "대쉬는 패들을 빠르게 이동시키는 기술입니다."),
            DialogueLine("조교", "Space키로 일반 대쉬, Shift키로 하프대쉬를 사용할 수 있습니다."),
            DialogueLine("조교", "연속으로 사용하면 연속대쉬가 발동됩니다!"),
        ]
        self.dialogue.start_dialogue(dialogues)
    
    def show_dash_token_dialogue(self):
        """대쉬 토큰 설명"""
        dialogues = [
            DialogueLine("조교", "대쉬 토큰 시스템을 알려드릴게요.", DialogueType.INFO),
            DialogueLine("조교", "화면 하단의 원들이 대쉬 토큰입니다."),
            DialogueLine("조교", "토큰을 소비하여 대쉬를 사용하고, 시간이 지나면 자동 충전됩니다."),
        ]
        self.dialogue.start_dialogue(dialogues)
    
    def show_completion_dialogue(self):
        """완료 대화 표시"""
        dialogues = [
            DialogueLine("조교", "대쉬 마스터가 되셨군요!", DialogueType.SUCCESS),
            DialogueLine("조교", "이제 강력한 스매시 기술인 드라이브를 배워봅시다!"),
        ]
        self.dialogue.start_dialogue(dialogues)
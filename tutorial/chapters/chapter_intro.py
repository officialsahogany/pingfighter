"""
인트로 챕터
튜토리얼 시작과 기본 설명
"""

import pygame
from typing import Optional, Dict, Any
from .base import BaseChapter
from ..dialogue import DialogueLine, DialogueType


class IntroChapter(BaseChapter):
    """인트로 챕터 클래스"""
    
    def start(self):
        """챕터 시작"""
        super().start()
        
        # 인트로 대화 표시
        self.show_intro_dialogue()
        
        # UI 설정
        self.state.ui_states['progress_bar_visible'] = False
        
    def update(self, dt: float):
        """챕터 업데이트"""
        super().update(dt)
        
        # 대화가 끝나면 자동으로 다음 챕터로
        if not self.dialogue.is_dialogue_active() and self.timer > 1.0:
            self.complete()
    
    def render(self, screen: pygame.Surface):
        """챕터 렌더링"""
        # 배경 효과
        self._draw_intro_background(screen)
    
    def _draw_intro_background(self, screen: pygame.Surface):
        """인트로 배경 그리기"""
        width, height = self.game.get_screen_dimensions()
        
        # 타이틀
        title_font = self.game.get_font(60)
        title = title_font.render("PingFighter 튜토리얼", True, (0, 255, 255))
        title_rect = title.get_rect(centerx=width // 2, centery=height // 3)
        screen.blit(title, title_rect)
        
        # 부제목
        subtitle_font = self.game.get_font(30)
        subtitle = subtitle_font.render("기본 조작법을 배워보세요!", True, (255, 255, 255))
        subtitle_rect = subtitle.get_rect(centerx=width // 2, centery=height // 3 + 80)
        screen.blit(subtitle, subtitle_rect)
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리"""
        return False
    
    def on_game_event(self, event_type: str, data: Optional[Dict[str, Any]] = None):
        """게임 이벤트 처리"""
        pass
    
    def check_completion(self) -> bool:
        """완료 조건 체크"""
        # 대화가 끝나면 완료
        return not self.dialogue.is_dialogue_active() and self.timer > 1.0
    
    def show_intro_dialogue(self):
        """인트로 대화 표시"""
        dialogues = [
            DialogueLine("조교", "안녕하세요! PingFighter 튜토리얼에 오신 것을 환영합니다!"),
            DialogueLine("조교", "저는 여러분의 튜토리얼 진행을 도와드릴 조교입니다."),
            DialogueLine("조교", "지금부터 게임의 기본 조작법을 하나씩 배워보겠습니다."),
            DialogueLine("조교", "먼저 가장 기본인 공 치기부터 시작해볼까요?"),
        ]
        self.dialogue.start_dialogue(dialogues)
    
    def show_completion_dialogue(self):
        """완료 대화 표시"""
        # 인트로는 별도의 완료 대화 없음
        pass
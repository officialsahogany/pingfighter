"""
챕터 3: 드라이브
특수 게이지와 드라이브 스매시 학습
"""

import pygame
from typing import Optional, Dict, Any
from .base import BaseChapter
from ..dialogue import DialogueLine, DialogueType
from ..state import DriveChapterState


class Chapter3Drive(BaseChapter):
    """드라이브 챕터 클래스"""
    
    def start(self):
        """챕터 시작"""
        super().start()
        self.show_intro_dialogue()
        
        # UI 설정
        self.state.ui_states['progress_bar_visible'] = True
        self.state.ui_states['counter_visible'] = True
        
        # 게임 설정
        self.game.set_ball_speed(4.5)
        self.game.set_special_gauge(100)  # 시작 게이지
    
    def update(self, dt: float):
        """챕터 업데이트"""
        super().update(dt)
        
        chapter_state = self.state.get_current_chapter_state()
        if not isinstance(chapter_state, DriveChapterState):
            return
        
        # 게이지 체크
        gauge = self.game.get_special_gauge()
        if gauge >= 160 and not chapter_state.gauge_reached_160:
            chapter_state.gauge_reached_160 = True
            self.show_gauge_reached_dialogue()
        
        self.update_progress()
    
    def render(self, screen: pygame.Surface):
        """챕터 렌더링"""
        # 드라이브 가이드
        gauge = self.game.get_special_gauge()
        if gauge >= 160:
            self._draw_drive_guide(screen)
    
    def _draw_drive_guide(self, screen: pygame.Surface):
        """드라이브 가이드 표시"""
        width, height = self.game.get_screen_dimensions()
        font = self.game.get_font(28)
        
        text = font.render("Z키로 드라이브!", True, (0, 255, 0))
        text_rect = text.get_rect(centerx=width // 2, y=height - 150)
        
        # 깜빡임 효과
        if int(self.timer * 2) % 2 == 0:
            screen.blit(text, text_rect)
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_z:
                gauge = self.game.get_special_gauge()
                if gauge >= 160:
                    self.game.handle_player_input("drive")
                    return True
        return False
    
    def on_game_event(self, event_type: str, data: Optional[Dict[str, Any]] = None):
        """게임 이벤트 처리"""
        chapter_state = self.state.get_current_chapter_state()
        if not isinstance(chapter_state, DriveChapterState):
            return
        
        if event_type == 'drive':
            chapter_state.drive_count += 1
            self.show_feedback("드라이브 성공!", "great")
            
            # 게이지 소비
            current_gauge = self.game.get_special_gauge()
            self.game.set_special_gauge(max(0, current_gauge - 160))
        
        elif event_type == 'hit':
            # 게이지 증가
            current_gauge = self.game.get_special_gauge()
            self.game.set_special_gauge(min(300, current_gauge + 20))
    
    def check_completion(self) -> bool:
        """완료 조건 체크"""
        chapter_state = self.state.get_current_chapter_state()
        if isinstance(chapter_state, DriveChapterState):
            return chapter_state.is_complete()
        return False
    
    def show_intro_dialogue(self):
        """인트로 대화 표시"""
        dialogues = [
            DialogueLine("조교", "Chapter 3: 드라이브 스매시", DialogueType.INFO),
            DialogueLine("조교", "공을 칠 때마다 특수 게이지가 차오릅니다."),
            DialogueLine("조교", "게이지가 160 이상이 되면 Z키로 강력한 드라이브를 날릴 수 있습니다!"),
            DialogueLine("조교", "3번의 드라이브를 성공시켜보세요."),
        ]
        self.dialogue.start_dialogue(dialogues)
    
    def show_gauge_reached_dialogue(self):
        """게이지 도달 대화"""
        dialogues = [
            DialogueLine("조교", "게이지가 충분히 찼습니다!", DialogueType.SUCCESS),
            DialogueLine("조교", "지금 Z키를 눌러 드라이브를 사용해보세요!"),
        ]
        self.dialogue.start_dialogue(dialogues)
    
    def show_completion_dialogue(self):
        """완료 대화 표시"""
        dialogues = [
            DialogueLine("조교", "드라이브를 완벽하게 익히셨네요!", DialogueType.SUCCESS),
            DialogueLine("조교", "마지막으로 가장 강력한 기술, 파워스매싱을 배워봅시다!"),
        ]
        self.dialogue.start_dialogue(dialogues)
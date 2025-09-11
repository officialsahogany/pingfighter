"""
챕터 4: 파워스매싱
최강 기술 파워스매싱 학습
"""

import pygame
from typing import Optional, Dict, Any
from .base import BaseChapter
from ..dialogue import DialogueLine, DialogueType
from ..state import PowerChapterState


class Chapter4Power(BaseChapter):
    """파워스매싱 챕터 클래스"""
    
    def start(self):
        """챕터 시작"""
        super().start()
        self.show_intro_dialogue()
        
        # UI 설정
        self.state.ui_states['progress_bar_visible'] = True
        self.state.ui_states['counter_visible'] = True
        
        # 게임 설정
        self.game.set_ball_speed(5.0)
        self.game.set_special_gauge(300)  # 시작 게이지
    
    def update(self, dt: float):
        """챕터 업데이트"""
        super().update(dt)
        
        chapter_state = self.state.get_current_chapter_state()
        if not isinstance(chapter_state, PowerChapterState):
            return
        
        # 게이지 체크
        gauge = self.game.get_special_gauge()
        if gauge >= 500 and not chapter_state.gauge_reached_500:
            chapter_state.gauge_reached_500 = True
            self.show_gauge_reached_dialogue()
        
        # 시범 보이기
        if not chapter_state.demonstration_shown and self.timer > 5.0:
            chapter_state.demonstration_shown = True
            self.show_demonstration()
        
        self.update_progress()
    
    def render(self, screen: pygame.Surface):
        """챕터 렌더링"""
        # 파워스매싱 가이드
        gauge = self.game.get_special_gauge()
        if gauge >= 500:
            self._draw_power_guide(screen)
    
    def _draw_power_guide(self, screen: pygame.Surface):
        """파워스매싱 가이드 표시"""
        width, height = self.game.get_screen_dimensions()
        font = self.game.get_font(32)
        
        text = font.render("X키로 파워스매싱!", True, (255, 0, 100))
        text_rect = text.get_rect(centerx=width // 2, y=height - 150)
        
        # 펄스 효과
        import math
        scale = 1.0 + math.sin(self.timer * 3) * 0.1
        scaled_text = pygame.transform.scale(text,
                                            (int(text_rect.width * scale),
                                             int(text_rect.height * scale)))
        scaled_rect = scaled_text.get_rect(center=text_rect.center)
        screen.blit(scaled_text, scaled_rect)
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_x:
                gauge = self.game.get_special_gauge()
                if gauge >= 500:
                    self.game.handle_player_input("power_smash")
                    return True
        return False
    
    def on_game_event(self, event_type: str, data: Optional[Dict[str, Any]] = None):
        """게임 이벤트 처리"""
        chapter_state = self.state.get_current_chapter_state()
        if not isinstance(chapter_state, PowerChapterState):
            return
        
        if event_type == 'power_smash':
            chapter_state.power_count += 1
            self.show_feedback("파워스매싱!!!", "perfect")
            
            # 게이지 소비
            current_gauge = self.game.get_special_gauge()
            self.game.set_special_gauge(max(0, current_gauge - 500))
            
            # 축하 효과
            if chapter_state.power_count >= chapter_state.target_power:
                self.state.animation_states['celebration_active'] = True
                self.state.animation_states['celebration_timer'] = 3.0
        
        elif event_type == 'hit':
            # 게이지 증가
            current_gauge = self.game.get_special_gauge()
            self.game.set_special_gauge(min(600, current_gauge + 30))
    
    def check_completion(self) -> bool:
        """완료 조건 체크"""
        chapter_state = self.state.get_current_chapter_state()
        if isinstance(chapter_state, PowerChapterState):
            return chapter_state.is_complete()
        return False
    
    def show_intro_dialogue(self):
        """인트로 대화 표시"""
        dialogues = [
            DialogueLine("조교", "Chapter 4: 파워스매싱", DialogueType.INFO),
            DialogueLine("조교", "이제 가장 강력한 기술을 배울 차례입니다!"),
            DialogueLine("조교", "게이지가 500 이상일 때 X키로 파워스매싱을 사용할 수 있습니다."),
            DialogueLine("조교", "파워스매싱은 막을 수 없는 필살기입니다!"),
        ]
        self.dialogue.start_dialogue(dialogues)
    
    def show_demonstration(self):
        """시범 보이기"""
        dialogues = [
            DialogueLine("조교", "제가 먼저 시범을 보여드리겠습니다.", DialogueType.INFO),
            DialogueLine("조교", "잘 보세요... 파워스매싱!!!"),
        ]
        self.dialogue.start_dialogue(dialogues)
        
        # 시범 애니메이션 (실제 구현 시)
        # self.play_demonstration_animation()
    
    def show_gauge_reached_dialogue(self):
        """게이지 도달 대화"""
        dialogues = [
            DialogueLine("조교", "게이지가 500을 넘었습니다!", DialogueType.SUCCESS),
            DialogueLine("조교", "지금이 파워스매싱을 사용할 절호의 기회입니다!"),
        ]
        self.dialogue.start_dialogue(dialogues)
    
    def show_completion_dialogue(self):
        """완료 대화 표시"""
        dialogues = [
            DialogueLine("조교", "놀랍습니다! 파워스매싱까지 완벽하게 마스터하셨네요!", DialogueType.SUCCESS),
            DialogueLine("조교", "이제 모든 기본 기술을 익히셨습니다!"),
        ]
        self.dialogue.start_dialogue(dialogues)
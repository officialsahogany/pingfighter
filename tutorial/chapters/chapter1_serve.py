"""
챕터 1: 서브와 기본 타격
기본적인 공 치기를 학습
"""

import pygame
from typing import Optional, Dict, Any
from .base import BaseChapter
from ..dialogue import DialogueLine, DialogueType


class Chapter1Serve(BaseChapter):
    """서브 챕터 클래스"""
    
    def start(self):
        """챕터 시작"""
        super().start()
        
        # 대화 표시
        self.show_intro_dialogue()
        
        # UI 설정
        self.state.ui_states['progress_bar_visible'] = True
        self.state.ui_states['counter_visible'] = True
        
        # 게임 설정
        self.reset_game_state()
        self.game.set_ball_speed(3.0)  # 느린 속도로 시작
        
    def update(self, dt: float):
        """챕터 업데이트"""
        super().update(dt)
        
        chapter_state = self.state.get_current_chapter_state()
        
        # 도우미 표시 조건
        if chapter_state.hit_count == 0 and self.timer > 5.0:
            self.show_helper_dialogue()
        
        # 진행도 업데이트
        self.update_progress()
    
    def render(self, screen: pygame.Surface):
        """챕터 렌더링"""
        # 서브 알림 표시
        if self.game.is_serving():
            self._draw_serve_reminder(screen)
    
    def _draw_serve_reminder(self, screen: pygame.Surface):
        """서브 알림 화살표"""
        ball_x, ball_y = self.game.get_ball_position()
        
        # 화살표 그리기
        arrow_color = (0, 255, 255)
        pygame.draw.lines(screen, arrow_color, False, 
                         [(ball_x - 20, ball_y - 50),
                          (ball_x, ball_y - 30),
                          (ball_x + 20, ball_y - 50)], 3)
        
        # 텍스트
        font = self.game.get_font(20)
        text = font.render("클릭하여 서브!", True, arrow_color)
        text_rect = text.get_rect(centerx=ball_x, y=ball_y - 80)
        screen.blit(text, text_rect)
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리"""
        if event.type == pygame.MOUSEBUTTONDOWN:
            if self.game.is_serving():
                # 서브 처리
                self.game.start_serve("player")
                return True
        return False
    
    def on_game_event(self, event_type: str, data: Optional[Dict[str, Any]] = None):
        """게임 이벤트 처리"""
        chapter_state = self.state.get_current_chapter_state()
        
        if event_type == 'hit':
            chapter_state.hit_count += 1
            chapter_state.success_count += 1
            
            # 피드백
            if chapter_state.hit_count == 1:
                self.show_feedback("첫 타격 성공!", "success")
            elif chapter_state.hit_count == 5:
                self.show_feedback("잘하고 있어요!", "great")
            elif chapter_state.hit_count == 10:
                self.show_feedback("완벽해요!", "perfect")
            else:
                self.show_feedback("좋아요!", "normal")
            
            # 속도 점진적 증가
            if chapter_state.hit_count % 3 == 0:
                current_speed = self.game.get_ball_speed()
                self.game.set_ball_speed(min(5.0, current_speed + 0.5))
        
        elif event_type == 'miss':
            chapter_state.miss_count += 1
            self.show_feedback("다시 시도해보세요", "warning")
    
    def check_completion(self) -> bool:
        """완료 조건 체크"""
        chapter_state = self.state.get_current_chapter_state()
        return chapter_state.hit_count >= 10
    
    def show_intro_dialogue(self):
        """인트로 대화 표시"""
        dialogues = [
            DialogueLine("조교", "Chapter 1: 서브와 기본 타격", DialogueType.INFO),
            DialogueLine("조교", "공이 날아오면 마우스로 클릭하여 타격해보세요."),
            DialogueLine("조교", "타이밍이 중요합니다! 공이 패들 근처에 왔을 때 클릭하세요."),
            DialogueLine("조교", "10번 성공적으로 타격하면 다음 단계로 넘어갑니다."),
        ]
        self.dialogue.start_dialogue(dialogues)
    
    def show_completion_dialogue(self):
        """완료 대화 표시"""
        dialogues = [
            DialogueLine("조교", "훌륭합니다! 기본 타격을 마스터하셨네요!", DialogueType.SUCCESS),
            DialogueLine("조교", "이제 더 고급 기술인 대쉬를 배워보겠습니다."),
        ]
        self.dialogue.start_dialogue(dialogues)
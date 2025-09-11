"""
완료 챕터
튜토리얼 완료 및 마무리
"""

import pygame
from typing import Optional, Dict, Any
from .base import BaseChapter
from ..dialogue import DialogueLine, DialogueType


class CompleteChapter(BaseChapter):
    """완료 챕터 클래스"""
    
    def start(self):
        """챕터 시작"""
        super().start()
        self.show_intro_dialogue()
        
        # UI 설정
        self.state.ui_states['progress_bar_visible'] = True
        
        # 축하 애니메이션
        self.state.animation_states['celebration_active'] = True
        self.state.animation_states['celebration_timer'] = 5.0
    
    def update(self, dt: float):
        """챕터 업데이트"""
        super().update(dt)
        
        # 대화가 끝나면 튜토리얼 종료
        if not self.dialogue.is_dialogue_active() and self.timer > 2.0:
            self.complete()
    
    def render(self, screen: pygame.Surface):
        """챕터 렌더링"""
        self._draw_completion_screen(screen)
    
    def _draw_completion_screen(self, screen: pygame.Surface):
        """완료 화면 그리기"""
        width, height = self.game.get_screen_dimensions()
        
        # 축하 메시지
        title_font = self.game.get_font(60)
        title = title_font.render("튜토리얼 완료!", True, (255, 215, 0))
        title_rect = title.get_rect(centerx=width // 2, centery=height // 3)
        screen.blit(title, title_rect)
        
        # 통계 표시
        self._draw_statistics(screen)
    
    def _draw_statistics(self, screen: pygame.Surface):
        """통계 표시"""
        width, height = self.game.get_screen_dimensions()
        font = self.game.get_font(24)
        
        # 전체 통계 수집
        total_hits = 0
        total_misses = 0
        
        for chapter_state in self.state.chapter_states.values():
            total_hits += chapter_state.hit_count
            total_misses += chapter_state.miss_count
        
        accuracy = (total_hits / (total_hits + total_misses) * 100) if (total_hits + total_misses) > 0 else 0
        
        stats = [
            f"총 타격 수: {total_hits}",
            f"총 실수: {total_misses}",
            f"정확도: {accuracy:.1f}%",
            f"완료 시간: {self.state.animation_states.get('total_time', 0):.1f}초"
        ]
        
        y = height // 2
        for stat in stats:
            text = font.render(stat, True, (255, 255, 255))
            text_rect = text.get_rect(centerx=width // 2, y=y)
            screen.blit(text, text_rect)
            y += 35
    
    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE or event.key == pygame.K_RETURN:
                if self.timer > 2.0:
                    self.complete()
                    return True
        return False
    
    def on_game_event(self, event_type: str, data: Optional[Dict[str, Any]] = None):
        """게임 이벤트 처리"""
        pass
    
    def check_completion(self) -> bool:
        """완료 조건 체크"""
        # 일정 시간 후 자동 완료
        return self.timer > 10.0
    
    def show_intro_dialogue(self):
        """인트로 대화 표시"""
        dialogues = [
            DialogueLine("조교", "축하합니다! 🎉", DialogueType.SUCCESS),
            DialogueLine("조교", "모든 기본 기술을 완벽하게 마스터하셨습니다!"),
            DialogueLine("조교", "이제 실전에서 배운 기술들을 마음껏 활용해보세요."),
            DialogueLine("조교", "당신의 승리를 기원합니다! 화이팅!"),
        ]
        self.dialogue.start_dialogue(dialogues)
    
    def show_completion_dialogue(self):
        """완료 대화 표시"""
        # 이미 인트로에서 처리
        pass
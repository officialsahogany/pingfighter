"""
UI Manager - UI 관리 시스템
게임 내 UI 요소들을 관리
"""

import pygame
from typing import Dict, Optional, Tuple
from core.global_manager import GlobalManager
from core.events import EventType, emit_event


class UIManager:
    """UI 관리 클래스"""
    
    def __init__(self, screen: pygame.Surface):
        """초기화
        
        Args:
            screen: 게임 화면
        """
        self.screen = screen
        self.global_manager = GlobalManager.get_instance()
        
        # 폰트
        self.font_small = pygame.font.Font(None, 24)
        self.font_medium = pygame.font.Font(None, 36)
        self.font_large = pygame.font.Font(None, 48)
        
        # UI 상태
        self.round_end_timer = 0
        self.round_end_message = ""
        self.notifications = []
        
    def show_round_end(self, winner: Optional[str] = None):
        """라운드 종료 UI 표시
        
        Args:
            winner: 승자 ('player' 또는 'boss')
        """
        if winner == 'player':
            self.round_end_message = "ROUND WON!"
        elif winner == 'boss':
            self.round_end_message = "ROUND LOST!"
        else:
            self.round_end_message = "ROUND END"
            
        self.round_end_timer = 120  # 2초간 표시
        
    def show_notification(self, message: str, duration: float = 2.0):
        """알림 메시지 표시
        
        Args:
            message: 표시할 메시지
            duration: 표시 시간 (초)
        """
        self.notifications.append({
            'message': message,
            'timer': duration * 60,
            'alpha': 255
        })
        
    def update(self, dt: float):
        """UI 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 라운드 종료 타이머
        if self.round_end_timer > 0:
            self.round_end_timer -= 1
            
        # 알림 업데이트
        for notif in self.notifications[:]:
            notif['timer'] -= 1
            if notif['timer'] <= 30:  # 마지막 0.5초간 페이드아웃
                notif['alpha'] = int(255 * (notif['timer'] / 30))
            if notif['timer'] <= 0:
                self.notifications.remove(notif)
                
    def render(self, screen: pygame.Surface):
        """UI 렌더링
        
        Args:
            screen: 게임 화면
        """
        # 라운드 종료 메시지
        if self.round_end_timer > 0:
            text = self.font_large.render(self.round_end_message, True, (255, 255, 255))
            text_rect = text.get_rect(center=(
                self.global_manager.get('WIDTH', 600) // 2,
                self.global_manager.get('HEIGHT', 750) // 2
            ))
            
            # 배경 어둡게 - SRCALPHA로 macOS/Windows 모두 알파 블렌딩 지원
            overlay = pygame.Surface(screen.get_size(), pygame.SRCALPHA)
            overlay.fill((0, 0, 0, 128))
            screen.blit(overlay, (0, 0))
            
            # 텍스트 표시
            screen.blit(text, text_rect)
            
        # 알림 메시지
        y_offset = 100
        for notif in self.notifications:
            text = self.font_medium.render(notif['message'], True, (255, 255, 255))
            text.set_alpha(notif['alpha'])
            text_rect = text.get_rect(center=(
                self.global_manager.get('WIDTH', 600) // 2,
                y_offset
            ))
            screen.blit(text, text_rect)
            y_offset += 40
            
    def render_hud(self, screen: pygame.Surface, game_state: Dict):
        """HUD 렌더링
        
        Args:
            screen: 게임 화면
            game_state: 게임 상태 정보
        """
        width = self.global_manager.get('WIDTH', 600)
        height = self.global_manager.get('HEIGHT', 750)
        
        # 점수
        score_text = f"Score: {game_state.get('player_score', 0)}"
        text = self.font_medium.render(score_text, True, (255, 255, 255))
        screen.blit(text, (10, height - 40))
        
        # 스테이지
        stage_text = f"Stage {game_state.get('current_stage', 1)}"
        text = self.font_medium.render(stage_text, True, (255, 215, 0))
        screen.blit(text, (width - 150, height - 40))
        
        # FPS
        fps = int(self.global_manager.get('clock', pygame.time.Clock()).get_fps())
        fps_text = f"FPS: {fps}"
        text = self.font_small.render(fps_text, True, (100, 100, 100))
        screen.blit(text, (width - 80, 10))
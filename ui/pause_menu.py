"""
⏸️ Pause Menu
일시정지 메뉴 시스템
"""

import pygame
from typing import Optional, Tuple, List


class PauseMenu:
    """
    ⏸️ 일시정지 메뉴 클래스
    
    게임 일시정지 시 표시되는 메뉴를 관리합니다.
    """
    
    def __init__(self, screen: pygame.Surface):
        """
        일시정지 메뉴 초기화
        
        Args:
            screen: 렌더링할 화면
        """
        self.screen = screen
        self.screen_width = screen.get_width()
        self.screen_height = screen.get_height()
        
        # 메뉴 옵션
        self.options = [
            {"text": "재개", "action": "resume"},
            {"text": "다시 시작", "action": "restart"},
            {"text": "설정", "action": "settings"},
            {"text": "메인 메뉴", "action": "quit"}
        ]
        
        self.selected_index = 0
        self.visible = False
        
        # 폰트
        self.title_font = pygame.font.Font(None, 48)
        self.option_font = pygame.font.Font(None, 36)
        
        # 색상
        self.bg_color = (0, 0, 0, 180)  # 반투명 검정
        self.text_color = (255, 255, 255)
        self.selected_color = (255, 255, 0)
        
        # 애니메이션
        self.fade_alpha = 0
        self.fade_speed = 10
        
    def show(self):
        """메뉴 표시"""
        self.visible = True
        self.selected_index = 0
        self.fade_alpha = 0
    
    def hide(self):
        """메뉴 숨기기"""
        self.visible = False
        self.fade_alpha = 0
    
    def update(self, dt: float) -> Optional[str]:
        """
        메뉴 업데이트
        
        Args:
            dt: 델타 타임
            
        Returns:
            선택된 액션 또는 None
        """
        if not self.visible:
            return None
        
        # 페이드 인 애니메이션
        if self.fade_alpha < 255:
            self.fade_alpha = min(255, self.fade_alpha + self.fade_speed)
        
        # 키 입력 처리
        keys = pygame.key.get_pressed()
        
        # 메뉴 탐색
        if keys[pygame.K_UP]:
            self.selected_index = (self.selected_index - 1) % len(self.options)
        elif keys[pygame.K_DOWN]:
            self.selected_index = (self.selected_index + 1) % len(self.options)
        elif keys[pygame.K_RETURN] or keys[pygame.K_SPACE]:
            return self.options[self.selected_index]["action"]
        elif keys[pygame.K_ESCAPE]:
            return "resume"
        
        return None
    
    def handle_click(self, pos: Tuple[int, int]) -> Optional[str]:
        """
        마우스 클릭 처리
        
        Args:
            pos: 클릭 위치
            
        Returns:
            선택된 액션 또는 None
        """
        if not self.visible:
            return None
        
        # 옵션 영역 체크
        for i, option in enumerate(self.options):
            rect = self._get_option_rect(i)
            if rect.collidepoint(pos):
                self.selected_index = i
                return option["action"]
        
        return None
    
    def _get_option_rect(self, index: int) -> pygame.Rect:
        """옵션 영역 반환"""
        y_start = self.screen_height // 2 - 50
        y_pos = y_start + index * 60
        
        # 텍스트 크기 계산
        text = self.option_font.render(self.options[index]["text"], True, self.text_color)
        text_rect = text.get_rect(center=(self.screen_width // 2, y_pos))
        
        # 클릭 영역 확장
        return text_rect.inflate(100, 20)
    
    def render(self):
        """메뉴 렌더링"""
        if not self.visible:
            return
        
        # 반투명 배경
        overlay = pygame.Surface((self.screen_width, self.screen_height))
        overlay.set_alpha(self.fade_alpha * 0.7)
        overlay.fill((0, 0, 0))
        self.screen.blit(overlay, (0, 0))
        
        # 메뉴 박스
        box_width = 400
        box_height = 350
        box_x = (self.screen_width - box_width) // 2
        box_y = (self.screen_height - box_height) // 2
        
        # 박스 배경
        box_surface = pygame.Surface((box_width, box_height))
        box_surface.set_alpha(self.fade_alpha * 0.9)
        box_surface.fill((20, 20, 40))
        self.screen.blit(box_surface, (box_x, box_y))
        
        # 박스 테두리
        if self.fade_alpha >= 255:
            pygame.draw.rect(self.screen, (100, 100, 255), 
                           (box_x, box_y, box_width, box_height), 3)
        
        # 타이틀
        title_text = self.title_font.render("일시정지", True, self.text_color)
        title_rect = title_text.get_rect(center=(self.screen_width // 2, box_y + 50))
        title_text.set_alpha(self.fade_alpha)
        self.screen.blit(title_text, title_rect)
        
        # 구분선
        if self.fade_alpha >= 255:
            pygame.draw.line(self.screen, (100, 100, 100),
                           (box_x + 50, box_y + 90),
                           (box_x + box_width - 50, box_y + 90), 2)
        
        # 메뉴 옵션
        y_start = self.screen_height // 2 - 50
        for i, option in enumerate(self.options):
            y_pos = y_start + i * 60
            
            # 선택된 항목 하이라이트
            if i == self.selected_index:
                # 하이라이트 배경
                highlight_rect = pygame.Rect(box_x + 50, y_pos - 25, box_width - 100, 50)
                highlight_surface = pygame.Surface((highlight_rect.width, highlight_rect.height))
                highlight_surface.set_alpha(self.fade_alpha * 0.3)
                highlight_surface.fill((100, 100, 255))
                self.screen.blit(highlight_surface, highlight_rect)
                
                color = self.selected_color
                
                # 화살표 표시
                arrow_text = self.option_font.render("▶", True, color)
                arrow_rect = arrow_text.get_rect(center=(box_x + 80, y_pos))
                arrow_text.set_alpha(self.fade_alpha)
                self.screen.blit(arrow_text, arrow_rect)
            else:
                color = self.text_color
            
            # 옵션 텍스트
            text = self.option_font.render(option["text"], True, color)
            text_rect = text.get_rect(center=(self.screen_width // 2, y_pos))
            text.set_alpha(self.fade_alpha)
            self.screen.blit(text, text_rect)
        
        # 도움말
        if self.fade_alpha >= 255:
            help_font = pygame.font.Font(None, 20)
            help_text = help_font.render("↑↓: 선택  Enter: 확인  ESC: 재개", True, (150, 150, 150))
            help_rect = help_text.get_rect(center=(self.screen_width // 2, box_y + box_height - 30))
            self.screen.blit(help_text, help_rect)
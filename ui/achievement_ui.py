"""
Achievement UI - 성취 UI
도전과제 표시 인터페이스
"""

import pygame
import math
from typing import Optional, List
from core.events import EventType, emit_event, subscribe
from core.global_manager import GlobalManager
from achievement.achievement_system import get_achievement_manager, AchievementCategory, AchievementRarity


class AchievementUI:
    """성취 UI 시스템"""
    
    def __init__(self, screen: pygame.Surface):
        """성취 UI 초기화
        
        Args:
            screen: 화면 Surface
        """
        self.screen = screen
        self.global_manager = GlobalManager.get_instance()
        self.achievement_manager = get_achievement_manager()
        
        # UI 상태
        self.active = False
        self.current_category = None  # None이면 전체
        self.selected_index = 0
        self.scroll_offset = 0
        
        # 알림 큐
        self.notification_queue = []
        self.current_notification = None
        self.notification_timer = 0
        self.notification_duration = 3.0
        
        # 폰트
        try:
            self.font_title = pygame.font.Font("NanumSquareEB.ttf", 36)
            self.font_category = pygame.font.Font("NanumSquareB.ttf", 24)
            self.font_name = pygame.font.Font("NanumSquareB.ttf", 20)
            self.font_desc = pygame.font.Font("NanumSquareR.ttf", 16)
            self.font_small = pygame.font.Font("NanumSquareR.ttf", 14)
        except:
            self.font_title = pygame.font.Font(None, 36)
            self.font_category = pygame.font.Font(None, 24)
            self.font_name = pygame.font.Font(None, 20)
            self.font_desc = pygame.font.Font(None, 16)
            self.font_small = pygame.font.Font(None, 14)
            
        # 애니메이션
        self.animation_timer = 0
        self.fade_alpha = 0
        
        # 이벤트 구독
        subscribe(EventType.MENU_OPENED, self.on_achievement_unlocked)
        
    def on_achievement_unlocked(self, event):
        """성취 달성 이벤트 처리"""
        if event.data.get('type') == 'achievement_unlocked':
            achievement = event.data.get('achievement')
            if achievement:
                self.show_notification(achievement)
                
    def show_notification(self, achievement):
        """성취 알림 표시
        
        Args:
            achievement: 달성한 성취
        """
        self.notification_queue.append(achievement)
        
    def open(self):
        """성취 UI 열기"""
        self.active = True
        self.fade_alpha = 0
        self.selected_index = 0
        self.scroll_offset = 0
        emit_event(EventType.MENU_OPENED, {'type': 'achievements'})
        
    def close(self):
        """성취 UI 닫기"""
        self.active = False
        
    def handle_event(self, event: pygame.event.Event):
        """이벤트 처리
        
        Args:
            event: pygame 이벤트
        """
        if not self.active:
            return
            
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.close()
                
            elif event.key == pygame.K_TAB:
                # 카테고리 전환
                categories = [None] + list(AchievementCategory)
                if self.current_category in categories:
                    idx = categories.index(self.current_category)
                    self.current_category = categories[(idx + 1) % len(categories)]
                else:
                    self.current_category = None
                self.selected_index = 0
                self.scroll_offset = 0
                
            elif event.key == pygame.K_UP:
                self.selected_index = max(0, self.selected_index - 1)
                self._adjust_scroll()
                
            elif event.key == pygame.K_DOWN:
                achievements = self.achievement_manager.get_achievement_list(self.current_category)
                self.selected_index = min(len(achievements) - 1, self.selected_index + 1)
                self._adjust_scroll()
                
    def _adjust_scroll(self):
        """스크롤 위치 조정"""
        # 화면에 표시되는 최대 항목 수
        max_visible = 10
        
        # 선택된 항목이 화면 밖에 있으면 스크롤
        if self.selected_index < self.scroll_offset:
            self.scroll_offset = self.selected_index
        elif self.selected_index >= self.scroll_offset + max_visible:
            self.scroll_offset = self.selected_index - max_visible + 1
            
    def update(self, dt: float):
        """업데이트
        
        Args:
            dt: 델타 타임
        """
        # 애니메이션
        self.animation_timer += dt
        
        # UI 페이드 인
        if self.active and self.fade_alpha < 255:
            self.fade_alpha = min(255, self.fade_alpha + 500 * dt)
            
        # 알림 처리
        if not self.current_notification and self.notification_queue:
            self.current_notification = self.notification_queue.pop(0)
            self.notification_timer = 0
            
        if self.current_notification:
            self.notification_timer += dt
            if self.notification_timer >= self.notification_duration:
                self.current_notification = None
                
    def render(self, screen: pygame.Surface):
        """렌더링
        
        Args:
            screen: 화면 Surface
        """
        # 성취 UI 렌더링
        if self.active:
            self._render_achievement_list(screen)
            
        # 알림 렌더링
        if self.current_notification:
            self._render_notification(screen)
            
    def _render_achievement_list(self, screen: pygame.Surface):
        """성취 목록 렌더링"""
        # 배경 (반투명)
        overlay = pygame.Surface((self.global_manager.get('WIDTH', 600), 
                                 self.global_manager.get('HEIGHT', 750)))
        overlay.set_alpha(200)
        overlay.fill((0, 0, 0))
        screen.blit(overlay, (0, 0))
        
        # 패널
        panel_width = 500
        panel_height = 600
        panel_x = (self.global_manager.get('WIDTH', 600) - panel_width) // 2
        panel_y = (self.global_manager.get('HEIGHT', 750) - panel_height) // 2
        
        # SRCALPHA로 macOS/Windows 모두 알파 블렌딩 지원
        panel_surface = pygame.Surface((panel_width, panel_height), pygame.SRCALPHA)
        panel_surface.fill((30, 30, 30, int(self.fade_alpha)))
        pygame.draw.rect(panel_surface, (100, 100, 100), 
                        (0, 0, panel_width, panel_height), 2)
        screen.blit(panel_surface, (panel_x, panel_y))
        
        # 제목
        title_text = self.font_title.render("도전과제", True, (255, 255, 255))
        title_rect = title_text.get_rect(center=(panel_x + panel_width // 2, panel_y + 30))
        screen.blit(title_text, title_rect)
        
        # 완료율
        completion_rate = self.achievement_manager.get_completion_rate()
        rate_text = f"완료율: {completion_rate * 100:.1f}%"
        rate_surface = self.font_desc.render(rate_text, True, (200, 200, 200))
        rate_rect = rate_surface.get_rect(center=(panel_x + panel_width // 2, panel_y + 60))
        screen.blit(rate_surface, rate_rect)
        
        # 카테고리 표시
        if self.current_category:
            cat_text = f"카테고리: {self.current_category.value}"
        else:
            cat_text = "카테고리: 전체"
        cat_surface = self.font_category.render(cat_text, True, (150, 150, 255))
        screen.blit(cat_surface, (panel_x + 20, panel_y + 90))
        
        # 성취 목록
        achievements = self.achievement_manager.get_achievement_list(self.current_category)
        y = panel_y + 130
        
        for i, achievement in enumerate(achievements[self.scroll_offset:self.scroll_offset + 10]):
            actual_index = i + self.scroll_offset
            
            # 선택된 항목 강조
            if actual_index == self.selected_index:
                pygame.draw.rect(screen, (50, 50, 50),
                               (panel_x + 10, y - 5, panel_width - 20, 50))
                               
            # 진행도
            progress = self.achievement_manager.get_achievement_progress(achievement.id)
            
            # 아이콘
            icon_surface = self.font_title.render(achievement.icon, True, (255, 255, 255))
            screen.blit(icon_surface, (panel_x + 20, y))
            
            # 이름
            color = achievement.rarity.value[1] if progress.completed else (100, 100, 100)
            name_surface = self.font_name.render(achievement.name, True, color)
            screen.blit(name_surface, (panel_x + 70, y))
            
            # 설명
            desc_color = (200, 200, 200) if progress.completed else (100, 100, 100)
            
            # 숨김 성취 처리
            if achievement.hidden and not progress.completed:
                desc_text = "???"
            else:
                desc_text = achievement.description
                
            desc_surface = self.font_desc.render(desc_text, True, desc_color)
            screen.blit(desc_surface, (panel_x + 70, y + 22))
            
            # 진행도 바
            if not progress.completed and not achievement.hidden:
                bar_width = 150
                bar_height = 4
                bar_x = panel_x + panel_width - bar_width - 20
                bar_y = y + 20
                
                # 배경
                pygame.draw.rect(screen, (50, 50, 50),
                               (bar_x, bar_y, bar_width, bar_height))
                               
                # 진행도
                progress_percent = progress.get_progress_percentage(achievement.requirement)
                if progress_percent > 0:
                    pygame.draw.rect(screen, (100, 200, 100),
                                   (bar_x, bar_y, 
                                    int(bar_width * progress_percent), bar_height))
                                    
                # 퍼센트 텍스트
                percent_text = f"{progress_percent * 100:.0f}%"
                percent_surface = self.font_small.render(percent_text, True, (150, 150, 150))
                screen.blit(percent_surface, (bar_x + bar_width + 5, bar_y - 2))
                
            # 완료 체크
            elif progress.completed:
                check_surface = self.font_name.render("✓", True, (100, 255, 100))
                screen.blit(check_surface, 
                          (panel_x + panel_width - 40, y + 10))
                          
            y += 55
            
        # 스크롤바
        if len(achievements) > 10:
            scrollbar_x = panel_x + panel_width - 10
            scrollbar_y = panel_y + 130
            scrollbar_height = 450
            
            # 스크롤바 배경
            pygame.draw.rect(screen, (50, 50, 50),
                           (scrollbar_x, scrollbar_y, 5, scrollbar_height))
                           
            # 스크롤바 핸들
            handle_height = max(20, scrollbar_height * 10 / len(achievements))
            handle_y = scrollbar_y + (self.scroll_offset / len(achievements)) * scrollbar_height
            
            pygame.draw.rect(screen, (150, 150, 150),
                           (scrollbar_x, int(handle_y), 5, int(handle_height)))
                           
    def _render_notification(self, screen: pygame.Surface):
        """성취 알림 렌더링"""
        if not self.current_notification:
            return
            
        # 알림 위치
        notif_width = 400
        notif_height = 100
        notif_x = (self.global_manager.get('WIDTH', 600) - notif_width) // 2
        notif_y = 100
        
        # 페이드 효과
        alpha = 255
        if self.notification_timer < 0.5:
            # 페이드 인
            alpha = int(self.notification_timer * 2 * 255)
        elif self.notification_timer > self.notification_duration - 0.5:
            # 페이드 아웃
            remaining = self.notification_duration - self.notification_timer
            alpha = int(remaining * 2 * 255)
            
        # 배경 - SRCALPHA로 macOS/Windows 모두 알파 블렌딩 지원
        notif_surface = pygame.Surface((notif_width, notif_height), pygame.SRCALPHA)
        notif_surface.fill((40, 40, 40, alpha))
        
        # 테두리 (희귀도 색상)
        border_color = self.current_notification.rarity.value[1]
        pygame.draw.rect(notif_surface, border_color,
                       (0, 0, notif_width, notif_height), 3)
                       
        screen.blit(notif_surface, (notif_x, notif_y))
        
        # 내용
        if alpha > 0:
            # "성취 달성!" 텍스트
            header_text = self.font_category.render("성취 달성!", True, (255, 255, 100))
            header_rect = header_text.get_rect(center=(notif_x + notif_width // 2, notif_y + 20))
            header_text.set_alpha(alpha)
            screen.blit(header_text, header_rect)
            
            # 아이콘과 이름
            icon_text = self.font_title.render(self.current_notification.icon, True, (255, 255, 255))
            icon_text.set_alpha(alpha)
            screen.blit(icon_text, (notif_x + 20, notif_y + 35))
            
            name_color = self.current_notification.rarity.value[1]
            name_text = self.font_name.render(self.current_notification.name, True, name_color)
            name_text.set_alpha(alpha)
            screen.blit(name_text, (notif_x + 70, notif_y + 45))
            
            # 설명
            desc_text = self.font_desc.render(self.current_notification.description, True, (200, 200, 200))
            desc_text.set_alpha(alpha)
            screen.blit(desc_text, (notif_x + 70, notif_y + 70))


# 싱글톤 인스턴스
_achievement_ui = None

def get_achievement_ui(screen: pygame.Surface) -> AchievementUI:
    """성취 UI 싱글톤 반환"""
    global _achievement_ui
    if _achievement_ui is None:
        _achievement_ui = AchievementUI(screen)
    return _achievement_ui
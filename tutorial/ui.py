"""
튜토리얼 UI 렌더링 모듈
튜토리얼 관련 모든 UI 요소를 담당
"""

import pygame
import math
import logging
from typing import Tuple, Optional, Dict, Any
from .game_interface import GameInterface
from .state import TutorialState, TutorialChapter, DashChapterState, DriveChapterState, PowerChapterState

logger = logging.getLogger(__name__)


class TutorialUI:
    """튜토리얼 UI 렌더링 클래스"""
    
    # 색상 정의
    BLACK = (0, 0, 0)
    WHITE = (255, 255, 255)
    CYAN = (0, 255, 255)
    GREEN = (0, 255, 0)
    YELLOW = (255, 255, 0)
    RED = (255, 0, 0)
    ORANGE = (255, 165, 0)
    PURPLE = (128, 0, 128)
    GRAY = (128, 128, 128)
    DARK_GRAY = (64, 64, 64)
    
    # 챕터별 색상
    CHAPTER_COLORS = {
        TutorialChapter.INTRO: (128, 128, 128),
        TutorialChapter.CHAPTER_1_SERVE: (0, 150, 255),
        TutorialChapter.CHAPTER_2_DASH: (255, 100, 0),
        TutorialChapter.CHAPTER_3_DRIVE: (0, 255, 100),
        TutorialChapter.CHAPTER_4_POWER: (255, 0, 100),
        TutorialChapter.COMPLETE: (255, 215, 0),
    }
    
    def __init__(self, game_interface: GameInterface):
        """
        초기화
        
        Args:
            game_interface: 게임 인터페이스
        """
        self.game = game_interface
        self.width, self.height = game_interface.get_screen_dimensions()
        
        # 애니메이션 타이머
        self.animation_timer = 0.0
        self.pulse_timer = 0.0
        
        # 캐시된 서페이스
        self.cached_surfaces = {}
        
        logger.info("TutorialUI initialized")
    
    def update(self, dt: float, state: TutorialState):
        """
        UI 업데이트
        
        Args:
            dt: 델타 타임
            state: 튜토리얼 상태
        """
        self.animation_timer += dt
        self.pulse_timer += dt
        
        # 카운터 애니메이션 업데이트
        if state.ui_states.get('counter_visible'):
            state.animation_states['counter_animation'] += dt * 2
    
    def render(self, screen: pygame.Surface, state: TutorialState):
        """
        UI 렌더링
        
        Args:
            screen: 렌더링할 화면
            state: 튜토리얼 상태
        """
        try:
            # 진행도 바
            if state.ui_states.get('progress_bar_visible'):
                self.draw_progress_bar(screen, state)
            
            # 챕터별 UI
            if state.current_chapter == TutorialChapter.CHAPTER_1_SERVE:
                self.draw_serve_ui(screen, state)
            elif state.current_chapter == TutorialChapter.CHAPTER_2_DASH:
                self.draw_dash_ui(screen, state)
            elif state.current_chapter == TutorialChapter.CHAPTER_3_DRIVE:
                self.draw_drive_ui(screen, state)
            elif state.current_chapter == TutorialChapter.CHAPTER_4_POWER:
                self.draw_power_ui(screen, state)
            
            # 피드백 메시지
            if state.ui_states.get('feedback_active'):
                self.draw_feedback(screen, state)
            
            # 도우미 UI
            if state.ui_states.get('helper_visible'):
                self.draw_helper(screen, state)
            
            # 축하 애니메이션
            if state.animation_states.get('celebration_active'):
                self.draw_celebration(screen, state)
                
        except Exception as e:
            logger.error(f"Error rendering UI: {e}")
    
    def draw_progress_bar(self, screen: pygame.Surface, state: TutorialState):
        """전체 진행도 바 그리기"""
        bar_width = self.width - 100
        bar_height = 30
        bar_x = 50
        bar_y = 20
        
        # 배경
        pygame.draw.rect(screen, self.DARK_GRAY, 
                        (bar_x, bar_y, bar_width, bar_height), 
                        border_radius=15)
        
        # 챕터별 구분선과 진행도
        chapters = [
            TutorialChapter.CHAPTER_1_SERVE,
            TutorialChapter.CHAPTER_2_DASH,
            TutorialChapter.CHAPTER_3_DRIVE,
            TutorialChapter.CHAPTER_4_POWER,
        ]
        
        chapter_width = bar_width // len(chapters)
        
        for i, chapter in enumerate(chapters):
            x = bar_x + i * chapter_width
            
            # 챕터 상태 확인
            chapter_state = state.chapter_states.get(chapter)
            color = self.CHAPTER_COLORS.get(chapter, self.GRAY)
            
            if chapter_state and chapter_state.completed:
                # 완료된 챕터
                pygame.draw.rect(screen, color,
                               (x, bar_y, chapter_width - 2, bar_height),
                               border_radius=10)
            elif chapter == state.current_chapter:
                # 현재 챕터 - 진행도 표시
                progress = chapter_state.progress if chapter_state else 0
                fill_width = int((chapter_width - 2) * progress)
                
                # 펄스 애니메이션
                pulse = math.sin(self.pulse_timer * 3) * 0.2 + 0.8
                animated_color = tuple(int(c * pulse) for c in color)
                
                pygame.draw.rect(screen, animated_color,
                               (x, bar_y, fill_width, bar_height),
                               border_radius=10)
            
            # 구분선
            if i < len(chapters) - 1:
                pygame.draw.line(screen, self.WHITE,
                               (x + chapter_width, bar_y + 5),
                               (x + chapter_width, bar_y + bar_height - 5), 2)
        
        # 테두리
        pygame.draw.rect(screen, self.WHITE,
                        (bar_x, bar_y, bar_width, bar_height),
                        width=2, border_radius=15)
        
        # 챕터 이름 표시
        font = self.game.get_font(16)
        chapter_names = ["서브", "대쉬", "드라이브", "파워"]
        
        for i, name in enumerate(chapter_names):
            x = bar_x + i * chapter_width + chapter_width // 2
            text = font.render(name, True, self.WHITE)
            text_rect = text.get_rect(centerx=x, centery=bar_y + bar_height // 2)
            screen.blit(text, text_rect)
    
    def draw_serve_ui(self, screen: pygame.Surface, state: TutorialState):
        """서브 챕터 UI"""
        chapter_state = state.get_current_chapter_state()
        
        # 타격 카운터
        self.draw_counter(screen, "타격", chapter_state.hit_count, 
                         chapter_state.target_count, self.CYAN)
        
        # 서브 알림
        if state.ui_states.get('serve_reminder_visible'):
            self.draw_serve_reminder(screen)
    
    def draw_dash_ui(self, screen: pygame.Surface, state: TutorialState):
        """대쉬 챕터 UI"""
        chapter_state = state.get_current_chapter_state()
        if not isinstance(chapter_state, DashChapterState):
            return
        
        # 대쉬 카운터들
        y_offset = 100
        
        # 일반 대쉬
        self.draw_mini_counter(screen, self.width - 200, y_offset,
                              "대쉬", chapter_state.dash_count,
                              chapter_state.target_dash, self.ORANGE)
        
        # 하프대쉬
        self.draw_mini_counter(screen, self.width - 200, y_offset + 60,
                              "하프대쉬", chapter_state.half_dash_count,
                              chapter_state.target_half_dash, self.YELLOW)
        
        # 연속대쉬
        self.draw_mini_counter(screen, self.width - 200, y_offset + 120,
                              "연속대쉬", chapter_state.consecutive_dash_count,
                              chapter_state.target_consecutive, self.RED)
    
    def draw_drive_ui(self, screen: pygame.Surface, state: TutorialState):
        """드라이브 챕터 UI"""
        chapter_state = state.get_current_chapter_state()
        if not isinstance(chapter_state, DriveChapterState):
            return
        
        # 드라이브 카운터
        self.draw_counter(screen, "드라이브", chapter_state.drive_count,
                         chapter_state.target_drives, self.GREEN)
        
        # 게이지 표시
        gauge = self.game.get_special_gauge()
        max_gauge = 160 if not chapter_state.gauge_reached_160 else 300
        
        self.draw_gauge_bar(screen, gauge, max_gauge)
    
    def draw_power_ui(self, screen: pygame.Surface, state: TutorialState):
        """파워스매싱 챕터 UI"""
        chapter_state = state.get_current_chapter_state()
        if not isinstance(chapter_state, PowerChapterState):
            return
        
        # 파워스매싱 카운터
        self.draw_counter(screen, "파워스매싱", chapter_state.power_count,
                         chapter_state.target_power, self.PURPLE)
        
        # 게이지 표시
        gauge = self.game.get_special_gauge()
        max_gauge = 500 if not chapter_state.gauge_reached_500 else 600
        
        self.draw_gauge_bar(screen, gauge, max_gauge)
    
    def draw_counter(self, screen: pygame.Surface, label: str, current: int, 
                    target: int, color: Tuple[int, int, int]):
        """카운터 UI 그리기"""
        x = self.width - 250
        y = 100
        
        # 배경
        bg_rect = pygame.Rect(x - 10, y - 10, 220, 80)
        pygame.draw.rect(screen, (*self.BLACK, 180), bg_rect, border_radius=10)
        pygame.draw.rect(screen, color, bg_rect, width=2, border_radius=10)
        
        # 라벨
        font = self.game.get_font(24)
        label_text = font.render(label, True, color)
        screen.blit(label_text, (x, y))
        
        # 카운터
        counter_font = self.game.get_font(36)
        counter_text = f"{current}/{target}"
        counter_surface = counter_font.render(counter_text, True, self.WHITE)
        screen.blit(counter_surface, (x, y + 30))
        
        # 진행도 바
        bar_width = 200
        bar_height = 8
        bar_y = y + 65
        
        pygame.draw.rect(screen, self.DARK_GRAY, (x, bar_y, bar_width, bar_height))
        
        progress = min(1.0, current / target)
        fill_width = int(bar_width * progress)
        pygame.draw.rect(screen, color, (x, bar_y, fill_width, bar_height))
    
    def draw_mini_counter(self, screen: pygame.Surface, x: int, y: int,
                         label: str, current: int, target: int, color: Tuple[int, int, int]):
        """작은 카운터 UI"""
        # 배경
        bg_rect = pygame.Rect(x - 5, y - 5, 180, 50)
        pygame.draw.rect(screen, (*self.BLACK, 180), bg_rect, border_radius=5)
        pygame.draw.rect(screen, color, bg_rect, width=1, border_radius=5)
        
        # 텍스트
        font = self.game.get_font(20)
        text = f"{label}: {current}/{target}"
        text_surface = font.render(text, True, color)
        screen.blit(text_surface, (x, y))
        
        # 체크마크
        if current >= target:
            check_font = self.game.get_font(24)
            check = check_font.render("✓", True, self.GREEN)
            screen.blit(check, (x + 150, y))
    
    def draw_gauge_bar(self, screen: pygame.Surface, current: float, max_value: float):
        """게이지 바 그리기"""
        x = 50
        y = self.height - 100
        width = 300
        height = 30
        
        # 배경
        pygame.draw.rect(screen, self.DARK_GRAY, (x, y, width, height), border_radius=5)
        
        # 채우기
        progress = min(1.0, current / max_value)
        fill_width = int(width * progress)
        
        # 색상 그라데이션
        if progress < 0.3:
            color = self.YELLOW
        elif progress < 0.7:
            color = self.ORANGE
        else:
            color = self.RED
        
        pygame.draw.rect(screen, color, (x, y, fill_width, height), border_radius=5)
        
        # 테두리
        pygame.draw.rect(screen, self.WHITE, (x, y, width, height), width=2, border_radius=5)
        
        # 수치 표시
        font = self.game.get_font(20)
        text = f"{int(current)}/{int(max_value)}"
        text_surface = font.render(text, True, self.WHITE)
        text_rect = text_surface.get_rect(centerx=x + width // 2, centery=y + height // 2)
        screen.blit(text_surface, text_rect)
    
    def draw_feedback(self, screen: pygame.Surface, state: TutorialState):
        """피드백 메시지 그리기"""
        message = state.ui_states.get('feedback_message', '')
        level = state.ui_states.get('feedback_level', 'normal')
        timer = state.ui_states.get('feedback_timer', 0)
        
        if not message:
            return
        
        # 색상 결정
        color_map = {
            'normal': self.WHITE,
            'warning': self.YELLOW,
            'success': self.GREEN,
            'great': self.CYAN,
            'perfect': self.PURPLE,
        }
        color = color_map.get(level, self.WHITE)
        
        # 페이드 효과
        alpha = min(255, int(timer * 255))
        
        # 텍스트 렌더링
        font = self.game.get_font(48)
        text = font.render(message, True, color)
        text_rect = text.get_rect(centerx=self.width // 2, centery=self.height // 2 - 100)
        
        # 그림자 효과
        shadow = font.render(message, True, self.BLACK)
        shadow_rect = text_rect.copy()
        shadow_rect.x += 3
        shadow_rect.y += 3
        
        # 투명도 적용
        text.set_alpha(alpha)
        shadow.set_alpha(alpha // 2)
        
        screen.blit(shadow, shadow_rect)
        screen.blit(text, text_rect)
    
    def draw_helper(self, screen: pygame.Surface, state: TutorialState):
        """도우미 오버레이 그리기"""
        # 반투명 배경
        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        overlay.fill((*self.BLACK, 100))
        screen.blit(overlay, (0, 0))
        
        # 도우미 메시지
        messages = self._get_helper_messages(state)
        
        y_offset = self.height // 2 - len(messages) * 30
        font = self.game.get_font(24)
        
        for message in messages:
            text = font.render(message, True, self.CYAN)
            text_rect = text.get_rect(centerx=self.width // 2, y=y_offset)
            screen.blit(text, text_rect)
            y_offset += 40
    
    def _get_helper_messages(self, state: TutorialState) -> list:
        """현재 챕터에 맞는 도우미 메시지 반환"""
        if state.current_chapter == TutorialChapter.CHAPTER_1_SERVE:
            return ["공이 오면 클릭하여 타격하세요!"]
        elif state.current_chapter == TutorialChapter.CHAPTER_2_DASH:
            return ["Space - 대쉬", "Shift - 하프대쉬", "연속으로 눌러 연속대쉬!"]
        elif state.current_chapter == TutorialChapter.CHAPTER_3_DRIVE:
            return ["게이지가 160 이상일 때", "Z키로 드라이브!"]
        elif state.current_chapter == TutorialChapter.CHAPTER_4_POWER:
            return ["게이지가 500 이상일 때", "X키로 파워스매싱!"]
        return []
    
    def draw_celebration(self, screen: pygame.Surface, state: TutorialState):
        """축하 애니메이션"""
        timer = state.animation_states.get('celebration_timer', 0)
        
        # 별 파티클 효과
        for i in range(20):
            angle = (self.animation_timer + i * 0.3) * 2
            radius = 100 + math.sin(angle) * 50
            x = self.width // 2 + math.cos(angle) * radius
            y = self.height // 2 + math.sin(angle) * radius
            
            size = int(5 + math.sin(angle * 2) * 3)
            pygame.draw.circle(screen, self.YELLOW, (int(x), int(y)), size)
        
        # 축하 메시지
        font = self.game.get_font(60)
        text = font.render("완료!", True, self.YELLOW)
        text_rect = text.get_rect(centerx=self.width // 2, centery=self.height // 2)
        
        # 펄스 효과
        scale = 1 + math.sin(self.animation_timer * 5) * 0.1
        scaled_text = pygame.transform.scale(text, 
                                            (int(text_rect.width * scale),
                                             int(text_rect.height * scale)))
        scaled_rect = scaled_text.get_rect(center=text_rect.center)
        
        screen.blit(scaled_text, scaled_rect)
    
    def draw_serve_reminder(self, screen: pygame.Surface):
        """서브 알림 화살표"""
        # 화살표 위치 계산
        ball_x, ball_y = self.game.get_ball_position()
        
        # 애니메이션
        bounce = math.sin(self.animation_timer * 3) * 10
        
        # 화살표 그리기
        arrow_points = [
            (ball_x - 20, ball_y - 50 + bounce),
            (ball_x, ball_y - 30 + bounce),
            (ball_x + 20, ball_y - 50 + bounce),
        ]
        pygame.draw.lines(screen, self.CYAN, False, arrow_points, 3)
        
        # 텍스트
        font = self.game.get_font(20)
        text = font.render("클릭하여 서브!", True, self.CYAN)
        text_rect = text.get_rect(centerx=ball_x, y=ball_y - 80 + bounce)
        screen.blit(text, text_rect)
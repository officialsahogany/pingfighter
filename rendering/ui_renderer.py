"""
UI Renderer - UI 렌더링 모듈
점수, 게이지, 메뉴, HUD 등 UI 요소 렌더링
"""
import pygame
import math
from typing import Tuple, Optional, Dict, Any, List
from utils.color_utils import get_stage_color, blend_colors, get_neon_color
from utils.draw_utils import draw_gradient_rect, draw_glow_effect

class UIRenderer:
    """UI 렌더링 클래스"""
    
    def __init__(self, screen: pygame.Surface):
        """초기화
        
        Args:
            screen: 렌더링할 화면
        """
        self.screen = screen
        self.width = screen.get_width()
        self.height = screen.get_height()
        
        # 폰트 설정
        self._init_fonts()
        
        # 애니메이션 상태
        self.gauge_animation_phase = 0
        self.score_pulse_timer = 0
        self.combo_animation_timer = 0
        
    def _init_fonts(self):
        """폰트 초기화"""
        try:
            # 네오둥근모 폰트 우선 사용
            self.large_font = pygame.font.Font("NeoFont.ttf", 48)
            self.medium_font = pygame.font.Font("NeoFont.ttf", 32)
            self.small_font = pygame.font.Font("NeoFont.ttf", 20)
            self.tiny_font = pygame.font.Font("NeoFont.ttf", 16)
        except:
            # 폴백 폰트
            self.large_font = pygame.font.Font(None, 48)
            self.medium_font = pygame.font.Font(None, 32)
            self.small_font = pygame.font.Font(None, 20)
            self.tiny_font = pygame.font.Font(None, 16)
    
    def render_score(self, player_score: int, boss_score: int, 
                    stage: int = 1, position: str = "top"):
        """점수 표시
        
        Args:
            player_score: 플레이어 점수
            boss_score: 보스 점수
            stage: 현재 스테이지
            position: 표시 위치 ("top", "center", "bottom")
        """
        stage_color = get_stage_color(stage)
        
        # 점수 텍스트
        score_text = f"{boss_score} - {player_score}"
        rendered_text = self.medium_font.render(score_text, True, (255, 255, 255))
        
        # 위치 계산
        text_rect = rendered_text.get_rect()
        if position == "top":
            text_rect.center = (self.width // 2, 50)
        elif position == "center":
            text_rect.center = (self.width // 2, self.height // 2)
        else:  # bottom
            text_rect.center = (self.width // 2, self.height - 50)
        
        # 배경 박스
        bg_rect = text_rect.inflate(40, 20)
        self._draw_ui_panel(bg_rect, stage_color, alpha=180)
        
        # 점수 표시
        self.screen.blit(rendered_text, text_rect)
        
        # 스테이지 표시
        stage_text = self.tiny_font.render(f"STAGE {stage}", True, stage_color)
        stage_rect = stage_text.get_rect()
        stage_rect.center = (text_rect.centerx, text_rect.bottom + 20)
        self.screen.blit(stage_text, stage_rect)
    
    def render_gauge(self, gauge_value: float, max_gauge: float,
                    gauge_type: str = "special", 
                    position: Tuple[int, int] = None):
        """게이지 바 렌더링
        
        Args:
            gauge_value: 현재 게이지 값
            max_gauge: 최대 게이지 값
            gauge_type: 게이지 타입 ("special", "health", "charge")
            position: 표시 위치 (None이면 기본 위치)
        """
        # 기본 위치 설정
        if position is None:
            if gauge_type == "special":
                position = (50, self.height - 50)
            elif gauge_type == "health":
                position = (self.width // 2 - 100, 30)
            else:
                position = (50, self.height - 100)
        
        # 게이지 크기
        gauge_width = 200
        gauge_height = 20
        
        # 게이지 색상
        colors = {
            "special": [(0, 100, 255), (0, 200, 255)],
            "health": [(255, 0, 0), (255, 100, 0)],
            "charge": [(255, 255, 0), (255, 200, 0)]
        }
        color_empty, color_full = colors.get(gauge_type, [(100, 100, 100), (200, 200, 200)])
        
        # 배경 바
        bg_rect = pygame.Rect(position[0], position[1], gauge_width, gauge_height)
        pygame.draw.rect(self.screen, (50, 50, 50), bg_rect, border_radius=10)
        pygame.draw.rect(self.screen, (100, 100, 100), bg_rect, 2, border_radius=10)
        
        # 채워진 부분
        if max_gauge > 0:
            fill_ratio = min(1.0, gauge_value / max_gauge)
            fill_width = int(gauge_width * fill_ratio)
            
            if fill_width > 0:
                fill_rect = pygame.Rect(position[0], position[1], fill_width, gauge_height)
                
                # 그라데이션 효과
                draw_gradient_rect(self.screen, fill_rect, 
                                 blend_colors(color_empty, color_full, 0.3),
                                 color_full)
                
                # 글로우 효과
                if fill_ratio > 0.8:
                    glow_rect = fill_rect.inflate(4, 4)
                    glow_surf = pygame.Surface((glow_rect.width, glow_rect.height), 
                                              pygame.SRCALPHA)
                    pygame.draw.rect(glow_surf, (*color_full, 50), glow_surf.get_rect(),
                                   border_radius=10)
                    self.screen.blit(glow_surf, glow_rect.topleft, 
                                   special_flags=pygame.BLEND_ADD)
        
        # 게이지 구분선
        for i in range(1, 5):
            line_x = position[0] + (gauge_width // 5) * i
            pygame.draw.line(self.screen, (80, 80, 80),
                           (line_x, position[1] + 5),
                           (line_x, position[1] + gauge_height - 5))
        
        # 게이지 라벨
        label_text = gauge_type.upper()
        label = self.tiny_font.render(label_text, True, (200, 200, 200))
        label_rect = label.get_rect()
        label_rect.midleft = (position[0] + gauge_width + 10, position[1] + gauge_height // 2)
        self.screen.blit(label, label_rect)
        
        # 수치 표시
        value_text = f"{int(gauge_value)}/{int(max_gauge)}"
        value_rendered = self.tiny_font.render(value_text, True, (255, 255, 255))
        value_rect = value_rendered.get_rect()
        value_rect.center = (position[0] + gauge_width // 2, position[1] + gauge_height // 2)
        self.screen.blit(value_rendered, value_rect)
    
    def render_combo(self, combo_count: int, combo_multiplier: float):
        """콤보 표시
        
        Args:
            combo_count: 콤보 횟수
            combo_multiplier: 콤보 배수
        """
        if combo_count <= 0:
            return
        
        # 콤보 텍스트
        combo_text = f"COMBO x{combo_count}"
        multiplier_text = f"×{combo_multiplier:.1f}"
        
        # 색상 (콤보가 높을수록 붉은색)
        color_intensity = min(1.0, combo_count / 20)
        combo_color = blend_colors((255, 255, 0), (255, 0, 0), color_intensity)
        
        # 크기 (콤보가 높을수록 크게)
        font_size = min(48, 24 + combo_count)
        try:
            combo_font = pygame.font.Font("NeoFont.ttf", font_size)
        except:
            combo_font = pygame.font.Font(None, font_size)
        
        # 렌더링
        combo_surface = combo_font.render(combo_text, True, combo_color)
        multiplier_surface = self.small_font.render(multiplier_text, True, (255, 255, 255))
        
        # 위치
        combo_rect = combo_surface.get_rect()
        combo_rect.center = (self.width // 2, 150)
        
        multiplier_rect = multiplier_surface.get_rect()
        multiplier_rect.center = (self.width // 2, combo_rect.bottom + 20)
        
        # 애니메이션 효과
        if self.combo_animation_timer > 0:
            scale = 1.0 + math.sin(self.combo_animation_timer * 0.5) * 0.1
            combo_surface = pygame.transform.scale(combo_surface,
                                                  (int(combo_rect.width * scale),
                                                   int(combo_rect.height * scale)))
            combo_rect = combo_surface.get_rect(center=combo_rect.center)
            self.combo_animation_timer -= 1
        
        # 그림자 효과
        shadow_surf = combo_surface.copy()
        shadow_surf.fill((0, 0, 0, 100), special_flags=pygame.BLEND_RGBA_MULT)
        self.screen.blit(shadow_surf, (combo_rect.x + 3, combo_rect.y + 3))
        
        # 텍스트 표시
        self.screen.blit(combo_surface, combo_rect)
        self.screen.blit(multiplier_surface, multiplier_rect)
    
    def render_timer(self, time_seconds: int, warning_threshold: int = 30):
        """타이머 표시
        
        Args:
            time_seconds: 남은 시간 (초)
            warning_threshold: 경고 표시 임계값 (초)
        """
        # 시간 포맷
        minutes = time_seconds // 60
        seconds = time_seconds % 60
        time_text = f"{minutes:02d}:{seconds:02d}"
        
        # 색상 (시간이 적으면 빨간색)
        if time_seconds <= warning_threshold:
            color = blend_colors((255, 255, 0), (255, 0, 0), 
                                1 - (time_seconds / warning_threshold))
            # 깜빡임 효과
            if time_seconds <= 10 and pygame.time.get_ticks() % 500 < 250:
                color = (255, 255, 255)
        else:
            color = (255, 255, 255)
        
        # 렌더링
        timer_surface = self.medium_font.render(time_text, True, color)
        timer_rect = timer_surface.get_rect()
        timer_rect.center = (self.width // 2, 100)
        
        # 배경
        bg_rect = timer_rect.inflate(30, 15)
        self._draw_ui_panel(bg_rect, (50, 50, 50), alpha=150)
        
        # 타이머 표시
        self.screen.blit(timer_surface, timer_rect)
        
        # 아이콘
        clock_radius = 8
        clock_center = (timer_rect.left - 20, timer_rect.centery)
        pygame.draw.circle(self.screen, color, clock_center, clock_radius, 2)
        # 시계 바늘
        angle = -math.pi / 2 + (pygame.time.get_ticks() % 1000) / 1000 * math.pi * 2
        hand_end = (clock_center[0] + math.cos(angle) * (clock_radius - 2),
                   clock_center[1] + math.sin(angle) * (clock_radius - 2))
        pygame.draw.line(self.screen, color, clock_center, hand_end, 2)
    
    def render_message(self, message: str, duration: int = 0,
                      position: str = "center", size: str = "medium",
                      color: Optional[Tuple[int, int, int]] = None):
        """메시지 표시
        
        Args:
            message: 표시할 메시지
            duration: 표시 시간 (0이면 계속 표시)
            position: 위치 ("top", "center", "bottom")
            size: 크기 ("small", "medium", "large")
            color: 텍스트 색상
        """
        # 폰트 선택
        fonts = {
            "small": self.small_font,
            "medium": self.medium_font,
            "large": self.large_font
        }
        font = fonts.get(size, self.medium_font)
        
        # 색상
        if color is None:
            color = (255, 255, 255)
        
        # 렌더링
        text_surface = font.render(message, True, color)
        text_rect = text_surface.get_rect()
        
        # 위치
        if position == "top":
            text_rect.center = (self.width // 2, 150)
        elif position == "center":
            text_rect.center = (self.width // 2, self.height // 2)
        else:  # bottom
            text_rect.center = (self.width // 2, self.height - 150)
        
        # 배경
        bg_rect = text_rect.inflate(40, 20)
        self._draw_ui_panel(bg_rect, (0, 0, 0), alpha=180)
        
        # 텍스트 표시
        self.screen.blit(text_surface, text_rect)
    
    def render_power_up_indicator(self, power_ups: Dict[str, float]):
        """파워업 인디케이터
        
        Args:
            power_ups: 활성 파워업 딕셔너리 {name: remaining_time}
        """
        if not power_ups:
            return
        
        # 시작 위치
        x = self.width - 150
        y = 100
        
        for power_name, remaining_time in power_ups.items():
            # 아이콘 영역
            icon_rect = pygame.Rect(x, y, 120, 30)
            
            # 배경
            bg_color = self._get_powerup_color(power_name)
            bg_alpha = 100 + int(55 * (remaining_time % 1))  # 펄스 효과
            
            bg_surf = pygame.Surface((icon_rect.width, icon_rect.height), pygame.SRCALPHA)
            pygame.draw.rect(bg_surf, (*bg_color, bg_alpha), bg_surf.get_rect(),
                           border_radius=5)
            self.screen.blit(bg_surf, icon_rect.topleft)
            
            # 테두리
            pygame.draw.rect(self.screen, bg_color, icon_rect, 2, border_radius=5)
            
            # 이름
            name_text = self.tiny_font.render(power_name.replace("_", " ").upper(), 
                                             True, (255, 255, 255))
            name_rect = name_text.get_rect()
            name_rect.midleft = (icon_rect.left + 5, icon_rect.centery)
            self.screen.blit(name_text, name_rect)
            
            # 시간
            time_text = self.tiny_font.render(f"{remaining_time:.1f}s", True, (255, 255, 255))
            time_rect = time_text.get_rect()
            time_rect.midright = (icon_rect.right - 5, icon_rect.centery)
            self.screen.blit(time_text, time_rect)
            
            y += 35
    
    def render_mini_map(self, player_pos: Tuple[float, float],
                       boss_pos: Tuple[float, float],
                       ball_pos: Tuple[float, float],
                       items: List[Tuple[float, float]] = None):
        """미니맵 렌더링
        
        Args:
            player_pos: 플레이어 위치
            boss_pos: 보스 위치
            ball_pos: 공 위치
            items: 아이템 위치 리스트
        """
        # 미니맵 크기와 위치
        map_width = 150
        map_height = 100
        map_x = self.width - map_width - 10
        map_y = self.height - map_height - 10
        
        # 배경
        map_rect = pygame.Rect(map_x, map_y, map_width, map_height)
        map_surf = pygame.Surface((map_width, map_height), pygame.SRCALPHA)
        pygame.draw.rect(map_surf, (0, 0, 0, 150), map_surf.get_rect())
        pygame.draw.rect(map_surf, (100, 100, 100), map_surf.get_rect(), 1)
        
        # 스케일 계산
        scale_x = map_width / self.width
        scale_y = map_height / self.height
        
        # 플레이어 표시
        player_mini_x = int(player_pos[0] * scale_x)
        player_mini_y = int(player_pos[1] * scale_y)
        pygame.draw.rect(map_surf, (0, 255, 0),
                        (player_mini_x - 3, player_mini_y - 1, 6, 2))
        
        # 보스 표시
        boss_mini_x = int(boss_pos[0] * scale_x)
        boss_mini_y = int(boss_pos[1] * scale_y)
        pygame.draw.rect(map_surf, (255, 0, 0),
                        (boss_mini_x - 3, boss_mini_y - 1, 6, 2))
        
        # 공 표시
        ball_mini_x = int(ball_pos[0] * scale_x)
        ball_mini_y = int(ball_pos[1] * scale_y)
        pygame.draw.circle(map_surf, (255, 255, 255),
                         (ball_mini_x, ball_mini_y), 2)
        
        # 아이템 표시
        if items:
            for item_pos in items:
                item_mini_x = int(item_pos[0] * scale_x)
                item_mini_y = int(item_pos[1] * scale_y)
                pygame.draw.circle(map_surf, (255, 255, 0),
                                 (item_mini_x, item_mini_y), 1)
        
        # 미니맵 그리기
        self.screen.blit(map_surf, map_rect.topleft)
    
    def _draw_ui_panel(self, rect: pygame.Rect, color: Tuple[int, int, int],
                      alpha: int = 200):
        """UI 패널 그리기
        
        Args:
            rect: 패널 영역
            color: 패널 색상
            alpha: 투명도
        """
        panel_surf = pygame.Surface((rect.width, rect.height), pygame.SRCALPHA)
        
        # 배경
        pygame.draw.rect(panel_surf, (*color, alpha), panel_surf.get_rect(),
                        border_radius=10)
        
        # 테두리
        border_color = blend_colors(color, (255, 255, 255), 0.3)
        pygame.draw.rect(panel_surf, (*border_color, alpha), panel_surf.get_rect(),
                        2, border_radius=10)
        
        self.screen.blit(panel_surf, rect.topleft)
    
    def _get_powerup_color(self, powerup_name: str) -> Tuple[int, int, int]:
        """파워업별 색상 반환"""
        colors = {
            "wide_paddle": (100, 200, 255),
            "sticky_paddle": (200, 100, 255),
            "shield": (100, 255, 200),
            "speed_up": (255, 200, 100),
            "slow_ball": (100, 100, 255),
            "multi_ball": (255, 100, 100),
            "laser": (255, 0, 0),
            "magnet": (200, 200, 255)
        }
        return colors.get(powerup_name, (200, 200, 200))
    
    def trigger_combo_animation(self):
        """콤보 애니메이션 트리거"""
        self.combo_animation_timer = 30
    
    def trigger_score_pulse(self):
        """점수 펄스 애니메이션 트리거"""
        self.score_pulse_timer = 20
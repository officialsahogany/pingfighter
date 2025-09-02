"""
HUD 디스플레이 모듈
- 점수 표시
- 메달 점수 표시
- 대시 관련 시각 효과
"""

import pygame
import math
import random
import sys
import os
# 상위 디렉토리를 경로에 추가하여 pixel_font_manager import 가능하게 함
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from pixel_font_manager import get_font, FontStyle

# 대시 스피릿 레이저 관련 상수
DASH_SPIRIT_LASER_DURATION = 360  # 6초 (60fps 기준)


class HUDDisplay:
    """HUD 표시 시스템"""
    
    def __init__(self, screen, width, height, draw_field_func=None, draw_objects_func=None):
        self.screen = screen
        self.width = width
        self.height = height
        self.draw_field_func = draw_field_func
        self.draw_objects_func = draw_objects_func
        
        # 폰트 초기화 - 네오둥근모 픽셀 폰트 사용
        self.font_title = FontStyle.title()  # 48pt 픽셀 폰트 (ROUND SCORE)
        self.font_score = get_font(140)  # 140pt 픽셀 폰트 (숫자)
        self.font_subtitle = FontStyle.menu()  # 28pt 픽셀 폰트 (PLAYER, BOSS)
        self.font_vs = get_font(36)  # 36pt 픽셀 폰트 (VS)
        self.font_medal = FontStyle.body()  # 24pt 픽셀 폰트 (메달 점수)
            
        # 색상 정의
        self.WHITE = (255, 255, 255)
        self.BLACK = (0, 0, 0)
        
    def show_score(self, player_score, ai_score):
        """현대적인 선 스타일 점수판"""
        
        # 키 이벤트 큐 비우기 - 대쉬 버그 방지
        pygame.event.clear()
        pygame.event.pump()
        
        # 점수판 크기 및 위치 설정
        board_width = 700
        board_height = 400
        board_x = (self.width - board_width) // 2
        board_y = (self.height - board_height) // 2
        
        # 폰트 설정
        font_title = self.font_title
        font_score = self.font_score
        font_subtitle = self.font_subtitle
        font_vs = self.font_vs
        
        # 색상 설정
        bg_color = (15, 15, 25)  # 매우 어두운 배경
        border_color = (100, 150, 255)  # 파란색 테두리
        line_color = (80, 120, 200)  # 선 색상
        player_color = (0, 255, 200)  # 민트색
        boss_color = (255, 80, 120)  # 핑크색
        accent_color = (255, 200, 50)  # 골드 액센트
        
        # 애니메이션 변수
        animation_timer = 0
        line_offset = 0
        
        clock = pygame.time.Clock()
        
        # 페이드인 애니메이션
        for alpha in range(0, 256, 20):
            # 배경 그리기
            if self.draw_field_func:
                self.draw_field_func()
            if self.draw_objects_func:
                self.draw_objects_func()
            
            # 반투명 오버레이
            overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            overlay.fill((0, 0, 0, 180))
            self.screen.blit(overlay, (0, 0))
            
            # 메인 점수판
            board_surface = pygame.Surface((board_width, board_height), pygame.SRCALPHA)
            
            # 배경 (그라데이션)
            for y in range(board_height):
                gradient_alpha = int(220 - (y / board_height) * 40)
                pygame.draw.line(board_surface, (*bg_color, gradient_alpha), 
                               (0, y), (board_width, y))
            
            # 외부 테두리 (두꺼운 선)
            pygame.draw.rect(board_surface, border_color, 
                            (0, 0, board_width, board_height), 4, border_radius=20)
            
            # 내부 테두리 (얇은 선)
            pygame.draw.rect(board_surface, line_color, 
                            (8, 8, board_width-16, board_height-16), 2, border_radius=16)
            
            # 네온 글로우 효과
            for i in range(4):
                glow_alpha = int(alpha * 0.2 * (0.5 + 0.5 * math.sin(animation_timer * 0.1 + i)))
                glow_surface = pygame.Surface((board_width, board_height), pygame.SRCALPHA)
                glow_x = 100 + i * 150
                glow_y = 50 + i * 80
                glow_radius = 30 + int(math.sin(animation_timer * 0.2 + i) * 10)
                pygame.draw.circle(glow_surface, (*accent_color, glow_alpha), (glow_x, glow_y), glow_radius)
                board_surface.blit(glow_surface, (0, 0))
            
            # 수직 선들 (장식)
            for i in range(5):
                line_alpha = int(alpha * 0.2)
                x = 100 + i * 120
                pygame.draw.line(board_surface, (*line_color, line_alpha), 
                               (x, 30), (x, board_height-30), 1)
            
            # 제목
            title_text = font_title.render("ROUND SCORE", True, accent_color)
            title_rect = title_text.get_rect(center=(board_width // 2, 60))
            title_text.set_alpha(alpha)
            board_surface.blit(title_text, title_rect)
            
            # 점수 표시
            player_alpha = min(255, alpha * 1.5)
            boss_alpha = min(255, alpha * 1.5)
            
            # 플레이어 점수
            player_text = font_score.render(str(player_score), True, player_color)
            player_text.set_alpha(player_alpha)
            player_rect = player_text.get_rect(center=(board_width // 3, board_height // 2 + 40))
            board_surface.blit(player_text, player_rect)
            
            # VS 텍스트
            vs_text = font_vs.render("VS", True, accent_color)
            vs_text.set_alpha(alpha)
            vs_rect = vs_text.get_rect(center=(board_width // 2, board_height // 2 + 40))
            board_surface.blit(vs_text, vs_rect)
            
            # 보스 점수
            boss_text = font_score.render(str(ai_score), True, boss_color)
            boss_text.set_alpha(boss_alpha)
            boss_rect = boss_text.get_rect(center=(2 * board_width // 3, board_height // 2 + 40))
            board_surface.blit(boss_text, boss_rect)
            
            # 라벨
            player_label = font_subtitle.render("PLAYER", True, player_color)
            player_label.set_alpha(alpha)
            player_label_rect = player_label.get_rect(center=(board_width // 3, board_height - 60))
            board_surface.blit(player_label, player_label_rect)
            
            boss_label = font_subtitle.render("BOSS", True, boss_color)
            boss_label.set_alpha(alpha)
            boss_label_rect = boss_label.get_rect(center=(2 * board_width // 3, board_height - 60))
            board_surface.blit(boss_label, boss_label_rect)
            
            # 하단 장식선
            pygame.draw.line(board_surface, accent_color, 
                            (50, board_height-80), (board_width-50, board_height-80), 3)
            
            # 점수판을 화면에 그리기
            board_surface.set_alpha(alpha)
            self.screen.blit(board_surface, (board_x, board_y))
            
            pygame.display.flip()
            clock.tick(60)
            animation_timer += 1
        
        # 점수판 표시 시간
        for _ in range(90):  # 1.5초간 표시
            # 배경 그리기
            if self.draw_field_func:
                self.draw_field_func()
            if self.draw_objects_func:
                self.draw_objects_func()
            
            # 반투명 오버레이
            overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            overlay.fill((0, 0, 0, 180))
            self.screen.blit(overlay, (0, 0))
            
            # 메인 점수판
            board_surface = pygame.Surface((board_width, board_height), pygame.SRCALPHA)
            
            # 배경 (그라데이션)
            for y in range(board_height):
                gradient_alpha = int(220 - (y / board_height) * 40)
                pygame.draw.line(board_surface, (*bg_color, gradient_alpha), 
                               (0, y), (board_width, y))
            
            # 외부 테두리 (두꺼운 선)
            pygame.draw.rect(board_surface, border_color, 
                            (0, 0, board_width, board_height), 4, border_radius=20)
            
            # 내부 테두리 (얇은 선)
            pygame.draw.rect(board_surface, line_color, 
                            (8, 8, board_width-16, board_height-16), 2, border_radius=16)
            
            # 네온 글로우 효과
            for i in range(4):
                glow_alpha = int(220 * (0.5 + 0.5 * math.sin(animation_timer * 0.1 + i)))
                glow_surface = pygame.Surface((board_width, board_height), pygame.SRCALPHA)
                glow_x = 100 + i * 150
                glow_y = 50 + i * 80
                glow_radius = 30 + int(math.sin(animation_timer * 0.2 + i) * 10)
                pygame.draw.circle(glow_surface, (*accent_color, glow_alpha), (glow_x, glow_y), glow_radius)
                board_surface.blit(glow_surface, (0, 0))
            
            # 수직 선들 (장식)
            for i in range(5):
                line_alpha = 50
                x = 100 + i * 120
                pygame.draw.line(board_surface, (*line_color, line_alpha), 
                               (x, 30), (x, board_height-30), 1)
            
            # 제목
            title_text = font_title.render("ROUND SCORE", True, accent_color)
            title_rect = title_text.get_rect(center=(board_width // 2, 60))
            board_surface.blit(title_text, title_rect)
            
            # 점수 표시
            # 플레이어 점수
            player_text = font_score.render(str(player_score), True, player_color)
            player_rect = player_text.get_rect(center=(board_width // 3, board_height // 2 + 40))
            board_surface.blit(player_text, player_rect)
            
            # VS 텍스트
            vs_text = font_vs.render("VS", True, accent_color)
            vs_rect = vs_text.get_rect(center=(board_width // 2, board_height // 2 + 40))
            board_surface.blit(vs_text, vs_rect)
            
            # 보스 점수
            boss_text = font_score.render(str(ai_score), True, boss_color)
            boss_rect = boss_text.get_rect(center=(2 * board_width // 3, board_height // 2 + 40))
            board_surface.blit(boss_text, boss_rect)
            
            # 라벨
            player_label = font_subtitle.render("PLAYER", True, player_color)
            player_label_rect = player_label.get_rect(center=(board_width // 3, board_height - 60))
            board_surface.blit(player_label, player_label_rect)
            
            boss_label = font_subtitle.render("BOSS", True, boss_color)
            boss_label_rect = boss_label.get_rect(center=(2 * board_width // 3, board_height - 60))
            board_surface.blit(boss_label, boss_label_rect)
            
            # 하단 장식선
            pygame.draw.line(board_surface, accent_color, 
                            (50, board_height-80), (board_width-50, board_height-80), 3)
            
            # 점수판을 화면에 그리기
            self.screen.blit(board_surface, (board_x, board_y))
            
            pygame.display.flip()
            clock.tick(60)
            animation_timer += 1
    
    def draw_medal_score(self, medal_score):
        """메달 점수 표시"""
        medal_text = f"🏅 {medal_score}"
        text_surface = self.font_medal.render(medal_text, True, (255, 215, 0))
        text_rect = text_surface.get_rect()
        text_rect.topright = (self.width - 20, 20)
        
        # 배경 박스
        padding = 10
        bg_rect = text_rect.inflate(padding * 2, padding)
        pygame.draw.rect(self.screen, (0, 0, 0, 128), bg_rect)
        pygame.draw.rect(self.screen, (255, 215, 0), bg_rect, 2)
        
        self.screen.blit(text_surface, text_rect)
        
    def draw_dash_spirit_lasers(self, player_rect, dash_spirits):
        """대시 스피릿 레이저 그리기 - 매우 얇고 긴 타원형"""
        for laser in dash_spirits:
            # 레이저가 유효한 경우에만 그리기
            if laser.get('remaining_time', 0) > 0:
                start_x = int(laser['start_x'])
                start_y = int(laser['start_y'])
                end_x = int(laser['end_x'])
                end_y = int(laser['end_y'])
                alpha = laser.get('alpha', 255)
                
                # 알파값이 너무 낮으면 그리지 않음
                if alpha < 10:
                    continue
                
                # 타원의 중심점과 크기 계산
                center_x = (start_x + end_x) // 2
                center_y = (start_y + end_y) // 2
                
                # 타원의 가로 반경 (레이저 길이의 절반)
                ellipse_width = abs(end_x - start_x) // 2
                # 타원의 세로 반경 (매우 얇게 - 3~8 픽셀)
                ellipse_height = 5  # 기본 높이
                
                # 타원을 그리기 위한 rect 생성
                if ellipse_width > 0:
                    # 외부 글로우 타원들 (여러 층으로 그려서 글로우 효과)
                    for i in range(5, 0, -1):
                        glow_alpha = min(255, int(alpha * 0.2 / i))
                        glow_color = (100, 200, 255)
                        
                        if glow_alpha > 0:
                            # 글로우 타원 (점점 큰 타원으로 글로우 효과)
                            glow_height = ellipse_height + i * 2
                            glow_rect = pygame.Rect(center_x - ellipse_width - i*2,
                                                   center_y - glow_height,
                                                   (ellipse_width + i*2) * 2,
                                                   glow_height * 2)
                            
                            # 타원 그리기 (filled=False로 외곽선만)
                            try:
                                glow_surface = pygame.Surface((glow_rect.width, glow_rect.height), pygame.SRCALPHA)
                                pygame.draw.ellipse(glow_surface, (*glow_color, glow_alpha),
                                                  (0, 0, glow_rect.width, glow_rect.height))
                                self.screen.blit(glow_surface, glow_rect.topleft)
                            except:
                                pass
                    
                    # 메인 레이저 타원 (채워진 타원)
                    main_rect = pygame.Rect(center_x - ellipse_width,
                                           center_y - ellipse_height,
                                           ellipse_width * 2,
                                           ellipse_height * 2)
                    
                    # 메인 타원 색상 (밝은 청백색)
                    main_color = (200, 230, 255)
                    main_alpha = min(255, alpha)
                    
                    try:
                        main_surface = pygame.Surface((main_rect.width, main_rect.height), pygame.SRCALPHA)
                        pygame.draw.ellipse(main_surface, (*main_color, main_alpha),
                                          (0, 0, main_rect.width, main_rect.height))
                        self.screen.blit(main_surface, main_rect.topleft)
                    except:
                        pass
                    
                    # 코어 타원 (더 밝고 작은 중심부)
                    core_height = ellipse_height - 2
                    core_width = ellipse_width - 10
                    if core_width > 0 and core_height > 0:
                        core_rect = pygame.Rect(center_x - core_width,
                                               center_y - core_height,
                                               core_width * 2,
                                               core_height * 2)
                        
                        core_color = (255, 255, 255)
                        core_alpha = min(255, int(alpha * 0.8))
                        
                        try:
                            core_surface = pygame.Surface((core_rect.width, core_rect.height), pygame.SRCALPHA)
                            pygame.draw.ellipse(core_surface, (*core_color, core_alpha),
                                              (0, 0, core_rect.width, core_rect.height))
                            self.screen.blit(core_surface, core_rect.topleft)
                        except:
                            pass
                
                # 레이저 시작 부분 이펙트 (원형 발광)
                if laser.get('remaining_time', 0) > DASH_SPIRIT_LASER_DURATION - 10:
                    # 생성 초기 충격파 효과
                    impact_radius = (10 - (DASH_SPIRIT_LASER_DURATION - laser['remaining_time'])) * 3
                    pygame.draw.circle(self.screen, (150, 220, 255, 100),
                                     (start_x, start_y), impact_radius, 2)
                
                # 타원 주변 스파크 효과
                for _ in range(3):
                    # 타원 경로상의 랜덤 위치
                    t = random.random()
                    spark_x = int(start_x + t * (end_x - start_x) + random.randint(-3, 3))
                    spark_y = center_y + random.randint(-ellipse_height-2, ellipse_height+2)
                    spark_size = random.randint(1, 2)
                    spark_alpha = int(alpha * random.uniform(0.5, 1.0))
                    pygame.draw.circle(self.screen, (200, 230, 255, spark_alpha),
                                     (spark_x, spark_y), spark_size)


# 싱글톤 인스턴스
_hud_display = None

def init_hud_display(screen, width, height, draw_field_func=None, draw_objects_func=None):
    """HUD 디스플레이 초기화"""
    global _hud_display
    _hud_display = HUDDisplay(screen, width, height, draw_field_func, draw_objects_func)
    return _hud_display

# 호환성을 위한 래퍼 함수들
def show_score(screen, player_score, ai_score, width=600, height=750, draw_field_func=None, draw_objects_func=None):
    """점수 표시 (호환성 래퍼)"""
    global _hud_display
    if _hud_display is None:
        _hud_display = HUDDisplay(screen, width, height, draw_field_func, draw_objects_func)
    else:
        # 함수가 전달되면 업데이트
        if draw_field_func is not None:
            _hud_display.draw_field_func = draw_field_func
        if draw_objects_func is not None:
            _hud_display.draw_objects_func = draw_objects_func
    _hud_display.show_score(player_score, ai_score)

def draw_medal_score(screen, medal_score, width=600, height=750):
    """메달 점수 표시 (호환성 래퍼)"""
    global _hud_display
    if _hud_display is None:
        _hud_display = HUDDisplay(screen, width, height)
    _hud_display.draw_medal_score(medal_score)

def draw_dash_spirit_lasers(screen, player_rect, dash_spirits, width=600, height=750):
    """대시 스피릿 레이저 그리기 (호환성 래퍼)"""
    global _hud_display
    if _hud_display is None:
        _hud_display = HUDDisplay(screen, width, height)
    _hud_display.draw_dash_spirit_lasers(player_rect, dash_spirits)
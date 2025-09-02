"""
레트로 스타일 게임 종료 화면 - 네오 둥근모 폰트 사용
"""
import pygame
import math
import random
from typing import Tuple, Dict, Any

class RetroGameOverScreen:
    """레트로 픽셀 스타일 게임 종료 화면"""
    
    # 레트로 색상 팔레트
    COLORS = {
        'background': (10, 10, 20),      # 매우 어두운 남색
        'primary': (0, 255, 200),         # 민트 그린
        'secondary': (255, 255, 0),       # 노란색
        'accent': (255, 0, 128),          # 핫 핑크
        'white': (255, 255, 255),
        'gray': (128, 128, 128),
        'dark_gray': (64, 64, 64),
        'grid': (30, 30, 50),             # 그리드 색상
        'radar_green': (0, 255, 100),     # 레이더 녹색
        'grade_s': (255, 215, 0),         # S등급 - 금색
        'grade_a': (255, 100, 100),       # A등급 - 빨간색
        'grade_b': (100, 200, 255),       # B등급 - 파란색  
        'grade_c': (100, 255, 100),       # C등급 - 녹색
        'grade_d': (200, 200, 200),       # D등급 - 회색
        'grade_f': (128, 128, 128),       # F등급 - 어두운 회색
    }
    
    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        
        # 폰트 로드
        self.fonts = self._load_fonts()
        
        # 애니메이션 타이머
        self.animation_timer = 0
        self.radar_angle = 0
        
        # 스캔라인 효과
        self.scanline_y = 0
        
    def _load_fonts(self) -> Dict[str, pygame.font.Font]:
        """네오 둥근모 폰트 로드"""
        fonts = {}
        try:
            # 네오 둥근모 폰트 사용
            fonts['title'] = pygame.font.Font("NeoDGM.ttf", 48)
            fonts['subtitle'] = pygame.font.Font("NeoDGM.ttf", 24)
            fonts['normal'] = pygame.font.Font("NeoDGM.ttf", 20)
            fonts['small'] = pygame.font.Font("NeoDGM.ttf", 16)
            fonts['tiny'] = pygame.font.Font("NeoDGM.ttf", 14)
            fonts['grade'] = pygame.font.Font("NeoDGM.ttf", 36)
        except:
            # 폴백 폰트
            fonts['title'] = pygame.font.Font(None, 48)
            fonts['subtitle'] = pygame.font.Font(None, 24)
            fonts['normal'] = pygame.font.Font(None, 20)
            fonts['small'] = pygame.font.Font(None, 16)
            fonts['tiny'] = pygame.font.Font(None, 14)
            fonts['grade'] = pygame.font.Font(None, 36)
        return fonts
    
    def _draw_retro_border(self, surface: pygame.Surface, rect: pygame.Rect, 
                           color: Tuple[int, int, int], width: int = 2):
        """레트로 스타일 테두리 그리기"""
        # 이중 테두리 효과
        pygame.draw.rect(surface, color, rect, width)
        inner_rect = pygame.Rect(rect.x + 4, rect.y + 4, rect.width - 8, rect.height - 8)
        pygame.draw.rect(surface, (*color, 128), inner_rect, 1)
    
    def _draw_pixel_text(self, surface: pygame.Surface, text: str, pos: Tuple[int, int],
                        font: pygame.font.Font, color: Tuple[int, int, int], 
                        shadow: bool = True, center: bool = False):
        """픽셀 스타일 텍스트 그리기"""
        # 그림자 효과
        if shadow:
            shadow_surf = font.render(text, False, self.COLORS['dark_gray'])
            shadow_rect = shadow_surf.get_rect()
            if center:
                shadow_rect.center = (pos[0] + 2, pos[1] + 2)
            else:
                shadow_rect.topleft = (pos[0] + 2, pos[1] + 2)
            surface.blit(shadow_surf, shadow_rect)
        
        # 메인 텍스트
        text_surf = font.render(text, False, color)
        text_rect = text_surf.get_rect()
        if center:
            text_rect.center = pos
        else:
            text_rect.topleft = pos
        surface.blit(text_surf, text_rect)
    
    def _draw_radar_chart(self, surface: pygame.Surface, center: Tuple[int, int], 
                         radius: int, stats: Dict[str, float]):
        """레트로 스타일 레이더 차트"""
        # 배경 그리드
        for i in range(5):
            r = radius * (i + 1) / 5
            pygame.draw.circle(surface, self.COLORS['grid'], center, int(r), 1)
        
        # 축 그리기
        angles = [0, math.pi * 2/3, math.pi * 4/3]  # 3개 축
        labels = ["스킬 활용", "대쉬 활용", "아이템 활용"]
        values = [stats.get('skill', 0), stats.get('dash', 0), stats.get('item', 0)]
        
        for i, angle in enumerate(angles):
            end_x = center[0] + radius * math.cos(angle - math.pi/2)
            end_y = center[1] + radius * math.sin(angle - math.pi/2)
            pygame.draw.line(surface, self.COLORS['grid'], center, (end_x, end_y), 1)
            
            # 라벨
            label_x = center[0] + (radius + 20) * math.cos(angle - math.pi/2)
            label_y = center[1] + (radius + 20) * math.sin(angle - math.pi/2)
            self._draw_pixel_text(surface, labels[i], (label_x, label_y),
                                 self.fonts['tiny'], self.COLORS['gray'], 
                                 shadow=False, center=True)
            
            # 등급 표시
            grade = self._get_grade(values[i])
            grade_x = center[0] + (radius + 35) * math.cos(angle - math.pi/2)
            grade_y = center[1] + (radius + 35) * math.sin(angle - math.pi/2)
            grade_color = self.COLORS[f'grade_{grade.lower()}']
            self._draw_pixel_text(surface, f"({grade})", (grade_x, grade_y),
                                 self.fonts['tiny'], grade_color, 
                                 shadow=False, center=True)
        
        # 데이터 폴리곤
        points = []
        for i, angle in enumerate(angles):
            value = values[i] / 100 * radius  # 0-100 범위를 반지름에 맞게 조정
            x = center[0] + value * math.cos(angle - math.pi/2)
            y = center[1] + value * math.sin(angle - math.pi/2)
            points.append((x, y))
        
        # 반투명 채우기
        if len(points) >= 3:
            # 폴리곤 그리기
            polygon_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            pygame.draw.polygon(polygon_surf, (*self.COLORS['radar_green'], 80), points)
            surface.blit(polygon_surf, (0, 0))
            
            # 테두리
            pygame.draw.polygon(surface, self.COLORS['radar_green'], points, 2)
            
            # 포인트 강조
            for point in points:
                pygame.draw.circle(surface, self.COLORS['primary'], 
                                 (int(point[0]), int(point[1])), 4)
        
        # 스캔 애니메이션
        scan_angle = self.radar_angle % (math.pi * 2)
        scan_x = center[0] + radius * math.cos(scan_angle)
        scan_y = center[1] + radius * math.sin(scan_angle)
        
        # 스캔 라인 (페이드 효과)
        for i in range(5):
            alpha = 255 - i * 50
            fade_angle = scan_angle - i * 0.1
            fade_x = center[0] + radius * math.cos(fade_angle)
            fade_y = center[1] + radius * math.sin(fade_angle)
            
            scan_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            pygame.draw.line(scan_surf, (*self.COLORS['radar_green'], alpha), 
                           center, (fade_x, fade_y), 2 - i // 2)
            surface.blit(scan_surf, (0, 0))
    
    def _get_grade(self, score: float) -> str:
        """점수에 따른 등급 반환"""
        if score >= 90:
            return 'S'
        elif score >= 80:
            return 'A'
        elif score >= 70:
            return 'B'
        elif score >= 60:
            return 'C'
        elif score >= 50:
            return 'D'
        else:
            return 'F'
    
    def _draw_scanlines(self, surface: pygame.Surface):
        """CRT 스캔라인 효과"""
        for y in range(0, self.height, 4):
            alpha = 20 + 10 * math.sin(y / 10 + self.animation_timer)
            line_surf = pygame.Surface((self.width, 2), pygame.SRCALPHA)
            line_surf.fill((0, 0, 0, alpha))
            surface.blit(line_surf, (0, y))
    
    def update(self, dt: float):
        """애니메이션 업데이트"""
        self.animation_timer += dt
        self.radar_angle += dt * 2  # 레이더 회전
        self.scanline_y = (self.scanline_y + 2) % self.height
    
    def draw(self, surface: pygame.Surface, game_stats: Dict[str, Any]):
        """게임 종료 화면 그리기"""
        # 배경
        surface.fill(self.COLORS['background'])
        
        # 픽셀 그리드 패턴
        for x in range(0, self.width, 20):
            pygame.draw.line(surface, self.COLORS['grid'], (x, 0), (x, self.height), 1)
        for y in range(0, self.height, 20):
            pygame.draw.line(surface, self.COLORS['grid'], (0, y), (self.width, y), 1)
        
        # 제목 섹션
        title_rect = pygame.Rect(50, 30, self.width - 100, 80)
        self._draw_retro_border(surface, title_rect, self.COLORS['primary'])
        
        # 제목
        self._draw_pixel_text(surface, "게임 종료 - 최종 실력 평가", 
                            (self.width // 2, 70),
                            self.fonts['title'], self.COLORS['white'], 
                            center=True)
        
        # 스테이지 정보
        stage_text = f"도달 스테이지: {game_stats.get('stage', 6)} (난이도 보정: {game_stats.get('difficulty', 3.0)}x)"
        self._draw_pixel_text(surface, stage_text, 
                            (self.width // 2, 130),
                            self.fonts['subtitle'], self.COLORS['secondary'], 
                            center=True)
        
        # 왼쪽 패널 - 등급 정보
        left_panel = pygame.Rect(50, 170, 250, 320)
        self._draw_retro_border(surface, left_panel, self.COLORS['accent'])
        
        # 등급 제목
        self._draw_pixel_text(surface, "[ 평가 등급 ]", 
                            (175, 185),
                            self.fonts['normal'], self.COLORS['accent'], 
                            center=True)
        
        # 각 항목 등급
        grades = [
            ("스킬 활용 능력", game_stats.get('skill_grade', 'F'), game_stats.get('skill_score', 0)),
            ("대쉬 활용 능력", game_stats.get('dash_grade', 'F'), game_stats.get('dash_score', 0)),
            ("아이템 활용 능력", game_stats.get('item_grade', 'F'), game_stats.get('item_score', 0)),
            ("가드 능력", game_stats.get('guard_grade', 'C'), game_stats.get('guard_score', 60))
        ]
        
        y_offset = 220
        for name, grade, score in grades:
            # 항목명
            self._draw_pixel_text(surface, f"{name}:", 
                                (70, y_offset),
                                self.fonts['small'], self.COLORS['white'])
            
            # 등급
            grade_color = self.COLORS[f'grade_{grade.lower()}']
            self._draw_pixel_text(surface, grade, 
                                (250, y_offset),
                                self.fonts['grade'], grade_color,
                                center=True)
            
            # 점수 바
            bar_rect = pygame.Rect(70, y_offset + 25, 160, 8)
            pygame.draw.rect(surface, self.COLORS['dark_gray'], bar_rect)
            fill_width = int(160 * score / 100)
            fill_rect = pygame.Rect(70, y_offset + 25, fill_width, 8)
            pygame.draw.rect(surface, grade_color, fill_rect)
            
            y_offset += 70
        
        # 오른쪽 패널 - 레이더 차트
        right_panel = pygame.Rect(350, 170, 200, 200)
        self._draw_retro_border(surface, right_panel, self.COLORS['primary'])
        
        # 레이더 차트
        radar_stats = {
            'skill': game_stats.get('skill_score', 0),
            'dash': game_stats.get('dash_score', 0),
            'item': game_stats.get('item_score', 0)
        }
        self._draw_radar_chart(surface, (450, 270), 80, radar_stats)
        
        # 하단 정보 패널
        bottom_panel = pygame.Rect(50, 400, 500, 120)
        self._draw_retro_border(surface, bottom_panel, self.COLORS['secondary'])
        
        # 전체 점수
        total_score = game_stats.get('total_score', 439)
        max_score = game_stats.get('max_score', 2000)
        score_text = f"전체 실력 점수: {total_score}/{max_score}"
        self._draw_pixel_text(surface, score_text, 
                            (self.width // 2, 420),
                            self.fonts['subtitle'], self.COLORS['primary'], 
                            center=True)
        
        # 점수 구성
        breakdown = f"점수 구성: 스킬 {game_stats.get('skill_points', 77)} + "\
                   f"대쉬 {game_stats.get('dash_points', 75)} + "\
                   f"아이템 {game_stats.get('item_points', 37)}"
        self._draw_pixel_text(surface, breakdown, 
                            (self.width // 2, 450),
                            self.fonts['small'], self.COLORS['gray'], 
                            center=True)
        
        # 보너스 정보
        bonus_text = f"보너스: +{game_stats.get('bonus', 300)} (승리스테이지) | "\
                    f"페널티: -{game_stats.get('penalty', 1800)} (가드 능력)"
        self._draw_pixel_text(surface, bonus_text, 
                            (self.width // 2, 470),
                            self.fonts['small'], self.COLORS['gray'], 
                            center=True)
        
        # 종합 등급
        overall_grade = self._get_grade(total_score / max_score * 100)
        grade_color = self.COLORS[f'grade_{overall_grade.lower()}']
        
        grade_box = pygame.Rect(self.width - 150, 420, 100, 80)
        self._draw_retro_border(surface, grade_box, grade_color, 3)
        
        self._draw_pixel_text(surface, "종합", 
                            (self.width - 100, 440),
                            self.fonts['small'], self.COLORS['white'], 
                            center=True)
        self._draw_pixel_text(surface, overall_grade, 
                            (self.width - 100, 470),
                            self.fonts['title'], grade_color, 
                            center=True)
        
        # 안내 메시지
        help_text = "[ SPACE or ESC to continue ]"
        pulse = abs(math.sin(self.animation_timer * 3))
        help_color = (
            int(self.COLORS['white'][0] * (0.5 + pulse * 0.5)),
            int(self.COLORS['white'][1] * (0.5 + pulse * 0.5)),
            int(self.COLORS['white'][2] * (0.5 + pulse * 0.5))
        )
        self._draw_pixel_text(surface, help_text, 
                            (self.width // 2, self.height - 30),
                            self.fonts['normal'], help_color, 
                            center=True)
        
        # CRT 스캔라인 효과
        self._draw_scanlines(surface)
        
        # 화면 플리커 효과 (랜덤하게)
        if random.random() < 0.02:  # 2% 확률로 플리커
            flicker_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            flicker_surf.fill((255, 255, 255, 10))
            surface.blit(flicker_surf, (0, 0))
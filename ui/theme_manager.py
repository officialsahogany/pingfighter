"""
테마 및 색상 관리 시스템
일관된 색상 팔레트와 테마 전환 기능을 제공합니다.
"""
import pygame
from typing import Dict, Tuple, Optional

class ThemeManager:
    """통합 테마 및 색상 관리 시스템"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def __init__(self):
        if not hasattr(self, 'initialized'):
            self.initialized = True
            self.current_theme = 'default'
            self.themes = self._init_themes()
            self.custom_colors = {}
    
    def _init_themes(self) -> Dict[str, Dict[str, Tuple[int, int, int]]]:
        """테마 정의"""
        return {
            'default': {
                # 기본 색상
                'primary': (0, 123, 255),      # 밝은 파란색
                'secondary': (108, 117, 125),   # 회색
                'success': (40, 167, 69),       # 녹색
                'danger': (220, 53, 69),        # 빨간색
                'warning': (255, 193, 7),       # 노란색
                'info': (23, 162, 184),         # 청록색
                
                # UI 색상
                'background': (20, 20, 30),      # 어두운 배경
                'surface': (30, 30, 45),         # 카드/패널 배경
                'text_primary': (255, 255, 255), # 주 텍스트
                'text_secondary': (180, 180, 190), # 보조 텍스트
                'text_disabled': (100, 100, 110), # 비활성 텍스트
                
                # 게임 요소 색상
                'player': (100, 149, 237),      # 플레이어 (코너플라워 블루)
                'boss': (255, 69, 0),            # 보스 (레드 오렌지)
                'ball': (255, 255, 255),        # 공
                'item': (255, 215, 0),           # 아이템 (골드)
                'powerup': (138, 43, 226),      # 파워업 (블루바이올렛)
                
                # 효과 색상
                'glow_soft': (100, 200, 255, 128),  # 부드러운 발광
                'glow_intense': (255, 255, 100, 200), # 강한 발광
                'shadow': (0, 0, 0, 128),            # 그림자
                'highlight': (255, 255, 255, 64),    # 하이라이트
                
                # 게이지 색상
                'health_high': (0, 255, 0),     # 체력 높음
                'health_mid': (255, 255, 0),    # 체력 중간
                'health_low': (255, 0, 0),      # 체력 낮음
                'mana': (0, 100, 255),           # 마나/스킬
                'shield': (150, 150, 255),       # 방어막
            },
            
            'dark': {
                # 다크 테마
                'primary': (138, 180, 248),
                'secondary': (150, 150, 160),
                'success': (129, 201, 149),
                'danger': (244, 143, 177),
                'warning': (255, 214, 102),
                'info': (129, 212, 250),
                
                'background': (18, 18, 18),
                'surface': (30, 30, 30),
                'text_primary': (240, 240, 240),
                'text_secondary': (180, 180, 180),
                'text_disabled': (100, 100, 100),
                
                'player': (129, 212, 250),
                'boss': (244, 143, 177),
                'ball': (255, 255, 255),
                'item': (255, 235, 59),
                'powerup': (186, 104, 200),
                
                'glow_soft': (100, 150, 200, 100),
                'glow_intense': (200, 200, 150, 180),
                'shadow': (0, 0, 0, 150),
                'highlight': (255, 255, 255, 50),
                
                'health_high': (129, 201, 149),
                'health_mid': (255, 214, 102),
                'health_low': (244, 143, 177),
                'mana': (129, 212, 250),
                'shield': (179, 157, 219),
            },
            
            'retro': {
                # 레트로 네온 테마
                'primary': (255, 0, 255),        # 마젠타
                'secondary': (0, 255, 255),      # 시안
                'success': (0, 255, 0),          # 라임
                'danger': (255, 0, 0),           # 레드
                'warning': (255, 255, 0),        # 옐로우
                'info': (0, 128, 255),           # 블루
                
                'background': (0, 0, 20),
                'surface': (10, 10, 40),
                'text_primary': (255, 255, 255),
                'text_secondary': (200, 200, 255),
                'text_disabled': (100, 100, 150),
                
                'player': (0, 255, 255),
                'boss': (255, 0, 255),
                'ball': (255, 255, 255),
                'item': (255, 255, 0),
                'powerup': (255, 0, 255),
                
                'glow_soft': (255, 0, 255, 100),
                'glow_intense': (0, 255, 255, 200),
                'shadow': (0, 0, 0, 200),
                'highlight': (255, 255, 255, 100),
                
                'health_high': (0, 255, 0),
                'health_mid': (255, 255, 0),
                'health_low': (255, 0, 0),
                'mana': (0, 128, 255),
                'shield': (255, 0, 255),
            }
        }
    
    def get_color(self, color_name: str) -> Tuple[int, int, int]:
        """현재 테마에서 색상 가져오기"""
        theme = self.themes.get(self.current_theme, self.themes['default'])
        
        # 커스텀 색상 확인
        if color_name in self.custom_colors:
            return self.custom_colors[color_name]
        
        # 테마 색상 확인
        if color_name in theme:
            color = theme[color_name]
            # RGBA를 RGB로 변환 (필요한 경우)
            if len(color) == 4:
                return color[:3]
            return color
        
        # 기본값 반환
        return (255, 255, 255)
    
    def get_color_with_alpha(self, color_name: str, alpha: int = 255) -> Tuple[int, int, int, int]:
        """알파값이 포함된 색상 가져오기"""
        color = self.get_color(color_name)
        return (*color, alpha)
    
    def set_theme(self, theme_name: str):
        """테마 변경"""
        if theme_name in self.themes:
            self.current_theme = theme_name
            return True
        return False
    
    def add_custom_color(self, name: str, color: Tuple[int, int, int]):
        """커스텀 색상 추가"""
        self.custom_colors[name] = color
    
    def blend_colors(self, color1_name: str, color2_name: str, ratio: float = 0.5) -> Tuple[int, int, int]:
        """두 색상을 블렌딩"""
        color1 = self.get_color(color1_name)
        color2 = self.get_color(color2_name)
        
        return tuple(int(c1 * (1 - ratio) + c2 * ratio) for c1, c2 in zip(color1, color2))
    
    def get_gradient(self, start_color: str, end_color: str, steps: int = 10) -> list:
        """그라디언트 색상 리스트 생성"""
        start = self.get_color(start_color)
        end = self.get_color(end_color)
        
        gradient = []
        for i in range(steps):
            ratio = i / (steps - 1) if steps > 1 else 0
            color = tuple(int(s * (1 - ratio) + e * ratio) for s, e in zip(start, end))
            gradient.append(color)
        
        return gradient
    
    def get_health_color(self, health_percentage: float) -> Tuple[int, int, int]:
        """체력 비율에 따른 색상 반환"""
        if health_percentage > 0.6:
            return self.get_color('health_high')
        elif health_percentage > 0.3:
            return self.get_color('health_mid')
        else:
            return self.get_color('health_low')
    
    def apply_brightness(self, color_name: str, brightness: float) -> Tuple[int, int, int]:
        """색상 밝기 조절 (0.0 = 검은색, 1.0 = 원본, 2.0 = 2배 밝기)"""
        color = self.get_color(color_name)
        return tuple(min(255, int(c * brightness)) for c in color)

# 싱글톤 인스턴스
theme_manager = ThemeManager()
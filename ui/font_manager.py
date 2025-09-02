"""
폰트 관리 시스템
통합된 폰트 로딩 및 캐싱을 제공합니다.
"""
import pygame
import os
from typing import Dict, Optional

class FontManager:
    """중앙화된 폰트 관리 시스템"""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def __init__(self):
        if not hasattr(self, 'initialized'):
            self.initialized = True
            self.fonts: Dict[str, pygame.font.Font] = {}
            self.font_cache: Dict[tuple, pygame.font.Font] = {}
            self.default_font = "NanumSquareR.ttf"
            self.bold_font = "NanumSquareB.ttf"
            self._init_fonts()
    
    def _init_fonts(self):
        """기본 폰트 세트 초기화"""
        try:
            # 타이틀 폰트들
            self.fonts['title_large'] = pygame.font.Font(self.bold_font, 64)
            self.fonts['title'] = pygame.font.Font(self.bold_font, 48)
            self.fonts['title_small'] = pygame.font.Font(self.bold_font, 40)
            
            # 헤딩 폰트들
            self.fonts['heading_large'] = pygame.font.Font(self.bold_font, 36)
            self.fonts['heading'] = pygame.font.Font(self.bold_font, 32)
            self.fonts['heading_small'] = pygame.font.Font(self.bold_font, 28)
            
            # 본문 폰트들
            self.fonts['body_large'] = pygame.font.Font(self.default_font, 24)
            self.fonts['body'] = pygame.font.Font(self.default_font, 20)
            self.fonts['body_small'] = pygame.font.Font(self.default_font, 18)
            
            # 작은 텍스트
            self.fonts['caption'] = pygame.font.Font(self.default_font, 16)
            self.fonts['caption_small'] = pygame.font.Font(self.default_font, 14)
            self.fonts['tiny'] = pygame.font.Font(self.default_font, 12)
            
            # 특수 용도
            self.fonts['score'] = pygame.font.Font(self.bold_font, 45)
            self.fonts['timer'] = pygame.font.Font(self.bold_font, 36)
            self.fonts['button'] = pygame.font.Font(self.default_font, 22)
            self.fonts['menu'] = pygame.font.Font(self.bold_font, 28)
            self.fonts['dialog'] = pygame.font.Font(self.default_font, 20)
            
        except FileNotFoundError as e:
            print(f"⚠️ 폰트 파일을 찾을 수 없습니다: {e}")
            self._fallback_fonts()
    
    def _fallback_fonts(self):
        """폰트 파일이 없을 경우 시스템 폰트 사용"""
        sizes = {
            'title_large': 64, 'title': 48, 'title_small': 40,
            'heading_large': 36, 'heading': 32, 'heading_small': 28,
            'body_large': 24, 'body': 20, 'body_small': 18,
            'caption': 16, 'caption_small': 14, 'tiny': 12,
            'score': 45, 'timer': 36, 'button': 22,
            'menu': 28, 'dialog': 20
        }
        
        for name, size in sizes.items():
            self.fonts[name] = pygame.font.Font(None, size)
    
    def get(self, font_type: str) -> pygame.font.Font:
        """폰트 타입으로 폰트 객체 가져오기"""
        return self.fonts.get(font_type, self.fonts['body'])
    
    def get_custom(self, size: int, bold: bool = False) -> pygame.font.Font:
        """커스텀 크기의 폰트 가져오기 (캐싱됨)"""
        cache_key = (size, bold)
        
        if cache_key not in self.font_cache:
            try:
                font_file = self.bold_font if bold else self.default_font
                self.font_cache[cache_key] = pygame.font.Font(font_file, size)
            except:
                self.font_cache[cache_key] = pygame.font.Font(None, size)
        
        return self.font_cache[cache_key]
    
    def render(self, text: str, font_type: str, color: tuple, 
               antialias: bool = True) -> pygame.Surface:
        """텍스트를 렌더링하여 Surface 반환"""
        font = self.get(font_type)
        return font.render(text, antialias, color)
    
    def render_multiline(self, text: str, font_type: str, color: tuple,
                        max_width: int = None, line_spacing: int = 5) -> list:
        """여러 줄 텍스트 렌더링"""
        font = self.get(font_type)
        words = text.split(' ')
        lines = []
        current_line = []
        
        for word in words:
            test_line = ' '.join(current_line + [word])
            text_width = font.size(test_line)[0]
            
            if max_width and text_width > max_width:
                if current_line:
                    lines.append(' '.join(current_line))
                    current_line = [word]
                else:
                    lines.append(word)
            else:
                current_line.append(word)
        
        if current_line:
            lines.append(' '.join(current_line))
        
        # Surface 리스트 생성
        rendered_lines = []
        for line in lines:
            rendered_lines.append(font.render(line, True, color))
        
        return rendered_lines
    
    def get_text_size(self, text: str, font_type: str) -> tuple:
        """텍스트의 크기 계산"""
        font = self.get(font_type)
        return font.size(text)

# 싱글톤 인스턴스
font_manager = FontManager()
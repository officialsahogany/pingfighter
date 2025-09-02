"""
사이버펑크 테마 메인 메뉴 배경 - Frontend Persona 최적화
"""
import pygame
import math
import random
from typing import List, Tuple, Dict, Optional

class CyberpunkThemeBackground:
    """최적화된 사이버펑크 스타일 배경 관리 클래스"""
    
    # 사이버펑크 네온 색상 팔레트
    PALETTE = {
        'primary': (0, 255, 255),        # Cyan
        'secondary': (255, 0, 128),      # Hot Pink  
        'accent': (128, 0, 255),         # Purple
        'warning': (255, 128, 0),        # Orange
        'success': (0, 255, 128),        # Green
        'background': (10, 10, 30),      # Deep Blue
        'surface': (20, 20, 50),         # Dark Blue
        'white': (255, 255, 255),
        'black': (0, 0, 0)
    }
    
    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.time = 0
        self.frame_count = 0
        
        # 성능 최적화를 위한 캐싱
        self.static_background = None
        self.grid_cache = None
        self.should_redraw_static = True
        
        # 간소화된 장식 요소
        self.decorative_elements = self._create_decorative_elements()
        
        # 파티클 시스템 (최적화)
        self.particles = []
        self._init_particles(30)  # 30개로 제한
        
        # 애니메이션 타이밍
        self.animation_speed = 1.0
        self.pulse_phase = 0
        
    def _create_decorative_elements(self) -> List[dict]:
        """간소화된 장식 요소 생성"""
        elements = []
        
        # 작은 네온 원들 (행성 대신)
        for i in range(5):
            elements.append({
                'type': 'neon_circle',
                'x': random.randint(100, self.width - 100),
                'y': random.randint(100, self.height - 200),
                'radius': random.randint(10, 25),
                'color': random.choice(['primary', 'secondary', 'accent']),
                'pulse_speed': random.uniform(0.5, 1.5),
                'pulse_phase': random.uniform(0, math.pi * 2),
                'glow_intensity': random.uniform(0.5, 1.0)
            })
        
        # 네온 라인들
        for i in range(3):
            elements.append({
                'type': 'neon_line',
                'start_x': random.randint(0, self.width),
                'start_y': random.randint(50, 150),
                'end_x': random.randint(0, self.width),
                'end_y': random.randint(50, 150),
                'color': 'primary',
                'width': 2,
                'pulse': True
            })
        
        return elements
    
    def _init_particles(self, count: int):
        """파티클 초기화 (성능 최적화)"""
        self.particles = []
        for _ in range(count):
            self.particles.append({
                'x': random.randint(0, self.width),
                'y': random.randint(0, self.height),
                'vx': random.uniform(-0.5, 0.5),
                'vy': random.uniform(-1, -0.2),  # 위로 올라가는 효과
                'size': random.randint(1, 2),
                'color': random.choice(['primary', 'accent']),
                'alpha': random.uniform(0.3, 0.8),
                'life': 1.0
            })
    
    def _draw_static_background(self, surface: pygame.Surface):
        """정적 배경 요소 그리기 (캐싱)"""
        if self.static_background is None:
            self.static_background = pygame.Surface((self.width, self.height))
            
            # 그라데이션 배경
            for y in range(self.height):
                ratio = y / self.height
                # 사이버펑크 그라데이션 (위: 진한 보라, 아래: 검은색)
                r = int(10 + ratio * 10)
                g = int(10 + ratio * 10)
                b = int(30 - ratio * 20)
                pygame.draw.line(self.static_background, (r, g, b), (0, y), (self.width, y))
        
        surface.blit(self.static_background, (0, 0))
    
    def _draw_grid(self, surface: pygame.Surface):
        """네온 그리드 그리기 (캐싱)"""
        if self.grid_cache is None:
            self.grid_cache = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            
            # 수평선
            for y in range(0, self.height, 50):
                alpha = 20 if y % 100 == 0 else 10
                color = (*self.PALETTE['primary'][:3], alpha)
                pygame.draw.line(self.grid_cache, color, (0, y), (self.width, y))
            
            # 수직선  
            for x in range(0, self.width, 50):
                alpha = 20 if x % 100 == 0 else 10
                color = (*self.PALETTE['primary'][:3], alpha)
                pygame.draw.line(self.grid_cache, color, (x, 0), (x, self.height))
        
        surface.blit(self.grid_cache, (0, 0))
    
    def _draw_decorative_elements(self, surface: pygame.Surface):
        """장식 요소 그리기"""
        for element in self.decorative_elements:
            if element['type'] == 'neon_circle':
                # 펄스 효과 계산
                pulse = math.sin(self.time * element['pulse_speed'] + element['pulse_phase'])
                radius = element['radius'] + pulse * 3
                
                # 네온 글로우 효과
                color = self.PALETTE[element['color']]
                glow_surf = pygame.Surface((int(radius * 4), int(radius * 4)), pygame.SRCALPHA)
                
                # 여러 레이어로 글로우 효과
                for i in range(3):
                    glow_radius = radius + (3 - i) * 5
                    alpha = int(30 * element['glow_intensity'] * (i + 1) / 3)
                    pygame.draw.circle(glow_surf, (*color, alpha),
                                     (int(radius * 2), int(radius * 2)), int(glow_radius))
                
                surface.blit(glow_surf, (int(element['x'] - radius * 2), 
                                        int(element['y'] - radius * 2)))
                
                # 중심 원
                pygame.draw.circle(surface, color, 
                                 (int(element['x']), int(element['y'])), int(radius))
            
            elif element['type'] == 'neon_line':
                if element['pulse']:
                    alpha = int(128 + 127 * math.sin(self.time * 2))
                    color = (*self.PALETTE[element['color']], alpha)
                else:
                    color = self.PALETTE[element['color']]
                
                pygame.draw.line(surface, color,
                               (element['start_x'], element['start_y']),
                               (element['end_x'], element['end_y']),
                               element['width'])
    
    def _draw_particles(self, surface: pygame.Surface):
        """파티클 효과 그리기 (최적화)"""
        for particle in self.particles:
            if particle['life'] > 0:
                alpha = int(particle['alpha'] * particle['life'] * 255)
                color = self.PALETTE[particle['color']]
                
                # 간단한 원으로 그리기 (성능 최적화)
                if alpha > 10:
                    particle_surf = pygame.Surface((particle['size'] * 4, particle['size'] * 4), pygame.SRCALPHA)
                    pygame.draw.circle(particle_surf, (*color, alpha),
                                     (particle['size'] * 2, particle['size'] * 2), particle['size'])
                    surface.blit(particle_surf, (int(particle['x'] - particle['size'] * 2),
                                                int(particle['y'] - particle['size'] * 2)))
    
    def update(self, dt: float):
        """배경 업데이트 (30 FPS 제한)"""
        self.time += dt
        self.frame_count += 1
        
        # 30 FPS로 제한 (성능 최적화)
        if self.frame_count % 2 == 0:
            return
        
        # 파티클 업데이트
        for particle in self.particles:
            if particle['life'] > 0:
                particle['x'] += particle['vx']
                particle['y'] += particle['vy']
                particle['life'] -= dt * 0.2
                
                # 화면 밖으로 나가면 재활용
                if particle['y'] < 0:
                    particle['y'] = self.height
                    particle['x'] = random.randint(0, self.width)
                    particle['life'] = 1.0
                
                if particle['x'] < 0:
                    particle['x'] = self.width
                elif particle['x'] > self.width:
                    particle['x'] = 0
        
        # 펄스 페이즈 업데이트
        self.pulse_phase += dt
    
    def draw(self, surface: pygame.Surface):
        """배경 그리기"""
        # 1. 정적 배경 (캐싱)
        self._draw_static_background(surface)
        
        # 2. 그리드 (캐싱)
        self._draw_grid(surface)
        
        # 3. 장식 요소
        self._draw_decorative_elements(surface)
        
        # 4. 파티클 효과
        self._draw_particles(surface)
    
    def get_menu_backdrop_rect(self) -> pygame.Rect:
        """메뉴 배경 영역 반환 (중앙 카드 스타일)"""
        menu_width = 400
        menu_height = 300
        menu_x = (self.width - menu_width) // 2
        menu_y = (self.height - menu_height) // 2 + 50
        return pygame.Rect(menu_x, menu_y, menu_width, menu_height)
    
    def draw_menu_backdrop(self, surface: pygame.Surface, selected_index: int = -1):
        """메뉴 배경 카드 그리기"""
        rect = self.get_menu_backdrop_rect()
        
        # 반투명 배경
        backdrop = pygame.Surface((rect.width, rect.height), pygame.SRCALPHA)
        pygame.draw.rect(backdrop, (*self.PALETTE['surface'], 180), (0, 0, rect.width, rect.height))
        
        # 네온 테두리
        border_color = self.PALETTE['primary'] if selected_index >= 0 else self.PALETTE['accent']
        pygame.draw.rect(backdrop, border_color, (0, 0, rect.width, rect.height), 2)
        
        # 글로우 효과
        glow_surf = pygame.Surface((rect.width + 20, rect.height + 20), pygame.SRCALPHA)
        for i in range(3):
            alpha = 30 - i * 10
            offset = i * 3
            pygame.draw.rect(glow_surf, (*border_color, alpha),
                           (offset, offset, rect.width + 20 - offset * 2, rect.height + 20 - offset * 2), 2)
        
        surface.blit(glow_surf, (rect.x - 10, rect.y - 10))
        surface.blit(backdrop, (rect.x, rect.y))
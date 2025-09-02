"""
Unified Rendering System - Phase 101
통합 렌더링 시스템으로 모든 draw 함수들을 모듈화
"""

import pygame
import math
import random
from .draw_helper import DrawHelper

class UnifiedRenderer:
    """통합 렌더링 시스템"""
    
    def __init__(self, screen, width=600, height=750):
        self.screen = screen
        self.width = width
        self.height = height
        self.dh = DrawHelper(screen)
        self.shake_offset = (0, 0)
        
    def set_shake(self, offset_x, offset_y):
        """화면 흔들림 설정"""
        self.shake_offset = (offset_x, offset_y)
        
    def draw_with_shake(self, surface, pos):
        """흔들림 효과와 함께 서피스 그리기"""
        x, y = pos
        shake_x, shake_y = self.shake_offset
        self.screen.blit(surface, (x + shake_x, y + shake_y))
        
    def draw_rect_with_shake(self, color, rect, width=0):
        """흔들림 효과와 함께 사각형 그리기"""
        shake_x, shake_y = self.shake_offset
        adjusted_rect = pygame.Rect(
            rect.x + shake_x, 
            rect.y + shake_y,
            rect.width, 
            rect.height
        )
        self.dh.rect(color, adjusted_rect, width)
        
    def draw_circle_with_shake(self, color, pos, radius, width=0):
        """흔들림 효과와 함께 원 그리기"""
        x, y = pos
        shake_x, shake_y = self.shake_offset
        self.dh.circle(color, (x + shake_x, y + shake_y), radius, width)
        
    def draw_glow_circle(self, pos, radius, color, glow_intensity=3):
        """발광 효과가 있는 원 그리기"""
        for i in range(glow_intensity):
            alpha = 50 - (i * 10)
            glow_radius = radius + (i * 5)
            glow_surface = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
            
            glow_color = (*color, alpha)
            pygame.draw.circle(glow_surface, glow_color, (glow_radius, glow_radius), glow_radius)
            
            x, y = pos
            self.screen.blit(glow_surface, (x - glow_radius, y - glow_radius))
        
        self.dh.circle(color, pos, radius)
        
    def draw_gradient_rect(self, rect, color1, color2, vertical=True):
        """그라데이션 사각형 그리기"""
        x, y, w, h = rect.x, rect.y, rect.width, rect.height
        
        if vertical:
            for i in range(h):
                ratio = i / h
                r = int(color1[0] * (1 - ratio) + color2[0] * ratio)
                g = int(color1[1] * (1 - ratio) + color2[1] * ratio)
                b = int(color1[2] * (1 - ratio) + color2[2] * ratio)
                self.dh.line((r, g, b), (x, y + i), (x + w, y + i))
        else:
            for i in range(w):
                ratio = i / w
                r = int(color1[0] * (1 - ratio) + color2[0] * ratio)
                g = int(color1[1] * (1 - ratio) + color2[1] * ratio)
                b = int(color1[2] * (1 - ratio) + color2[2] * ratio)
                self.dh.line((r, g, b), (x + i, y), (x + i, y + h))
                
    def draw_trail_effect(self, trail_list, base_color, fade_rate=0.9):
        """잔상 효과 그리기"""
        for i, pos in enumerate(trail_list):
            alpha = int(255 * (fade_rate ** (len(trail_list) - i)))
            size = max(1, int(10 * (i / len(trail_list))))
            
            trail_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            color_with_alpha = (*base_color, alpha)
            pygame.draw.circle(trail_surface, color_with_alpha, (size, size), size)
            
            x, y = pos
            self.screen.blit(trail_surface, (x - size, y - size))
            
    def draw_particle_burst(self, center, particle_list, base_color):
        """파티클 폭발 효과"""
        for particle in particle_list:
            x, y, vx, vy, life, size = particle
            if life <= 0:
                continue
                
            alpha = int(255 * (life / 100))
            particle_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            
            color_with_alpha = (*base_color, alpha)
            pygame.draw.circle(particle_surface, color_with_alpha, (size, size), size)
            
            self.screen.blit(particle_surface, (int(x - size), int(y - size)))
            
    def draw_energy_ball(self, pos, radius, color, energy_level=1.0):
        """에너지 볼 효과"""
        # 외부 글로우
        self.draw_glow_circle(pos, int(radius * 1.5), color, 5)
        
        # 내부 코어
        core_radius = int(radius * 0.7)
        self.dh.circle((255, 255, 255), pos, core_radius)
        
        # 에너지 링
        if energy_level > 0.5:
            ring_surface = pygame.Surface((radius * 4, radius * 4), pygame.SRCALPHA)
            for i in range(3):
                ring_radius = radius + (i * 10)
                alpha = int(100 * energy_level * (1 - i * 0.3))
                ring_color = (*color, alpha)
                pygame.draw.circle(ring_surface, ring_color, (radius * 2, radius * 2), 
                                 ring_radius, 2)
            
            x, y = pos
            self.screen.blit(ring_surface, (x - radius * 2, y - radius * 2))
            
    def draw_lightning_effect(self, start_pos, end_pos, color=(255, 255, 100), branches=3):
        """번개 효과"""
        x1, y1 = start_pos
        x2, y2 = end_pos
        
        # 메인 번개
        segments = 10
        points = []
        for i in range(segments + 1):
            t = i / segments
            x = x1 + (x2 - x1) * t + random.randint(-20, 20)
            y = y1 + (y2 - y1) * t + random.randint(-20, 20)
            points.append((x, y))
            
        # 번개 그리기
        for i in range(len(points) - 1):
            self.dh.line(color, points[i], points[i + 1], 3)
            # 글로우 효과
            glow_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            pygame.draw.line(glow_surface, (*color, 50), points[i], points[i + 1], 8)
            self.screen.blit(glow_surface, (0, 0))
            
    def draw_shield_effect(self, center, radius, color=(100, 200, 255), strength=1.0):
        """보호막 효과"""
        x, y = center
        
        # 육각형 쉴드
        shield_surface = pygame.Surface((radius * 4, radius * 4), pygame.SRCALPHA)
        
        for i in range(6):
            angle1 = i * math.pi / 3
            angle2 = (i + 1) * math.pi / 3
            
            x1 = radius * 2 + radius * math.cos(angle1)
            y1 = radius * 2 + radius * math.sin(angle1)
            x2 = radius * 2 + radius * math.cos(angle2)
            y2 = radius * 2 + radius * math.sin(angle2)
            
            alpha = int(150 * strength)
            pygame.draw.line(shield_surface, (*color, alpha), (x1, y1), (x2, y2), 3)
            
        self.screen.blit(shield_surface, (x - radius * 2, y - radius * 2))
        
        # 중심 글로우
        if strength > 0.5:
            self.draw_glow_circle(center, int(radius * 0.3), color, 2)
            
    def draw_explosion_ring(self, center, radius, color, thickness=5):
        """폭발 링 효과"""
        x, y = center
        
        ring_surface = pygame.Surface((radius * 2 + 20, radius * 2 + 20), pygame.SRCALPHA)
        
        # 여러 개의 링
        for i in range(3):
            ring_radius = radius - (i * thickness)
            if ring_radius > 0:
                alpha = 255 - (i * 80)
                ring_color = (*color, alpha)
                pygame.draw.circle(ring_surface, ring_color, 
                                 (radius + 10, radius + 10), ring_radius, thickness)
                
        self.screen.blit(ring_surface, (x - radius - 10, y - radius - 10))
        
    def draw_smoke_effect(self, pos, radius, color=(128, 128, 128), density=0.5):
        """연기 효과"""
        x, y = pos
        
        smoke_surface = pygame.Surface((radius * 4, radius * 4), pygame.SRCALPHA)
        
        # 여러 개의 연기 구름
        for i in range(5):
            offset_x = random.randint(-radius, radius)
            offset_y = random.randint(-radius, radius)
            smoke_radius = random.randint(radius // 2, radius)
            alpha = int(100 * density * random.uniform(0.5, 1.0))
            
            smoke_color = (*color, alpha)
            pygame.draw.circle(smoke_surface, smoke_color,
                             (radius * 2 + offset_x, radius * 2 + offset_y),
                             smoke_radius)
                             
        self.screen.blit(smoke_surface, (x - radius * 2, y - radius * 2))
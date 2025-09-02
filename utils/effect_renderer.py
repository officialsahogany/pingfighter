"""
통합 이펙트 렌더러
중복된 draw 함수들을 하나로 통합
"""
import pygame
import math
import random

class EffectRenderer:
    """모든 이펙트 렌더링을 통합 관리"""
    
    @staticmethod
    def draw_particles(surface, particles, default_color=(255, 255, 255)):
        """범용 파티클 렌더링"""
        for particle in particles:
            # 리스트 형식과 딕셔너리 형식 모두 지원
            if isinstance(particle, dict):
                life = particle.get('life', 0)
            elif isinstance(particle, (list, tuple)) and len(particle) > 4:
                # 리스트 형식: [x, y, vx, vy, alpha/life, ...]
                life = particle[4] if len(particle) > 4 else 0
            else:
                continue
                
            if life > 0:
                # 데이터 추출 (딕셔너리 또는 리스트)
                if isinstance(particle, dict):
                    x = particle.get('x', 0)
                    y = particle.get('y', 0)
                    size = particle.get('size', 3)
                    color = particle.get('color', default_color)
                    alpha = min(255, particle.get('alpha', 255))
                else:  # 리스트/튜플
                    x = particle[0] if len(particle) > 0 else 0
                    y = particle[1] if len(particle) > 1 else 0
                    alpha = particle[4] if len(particle) > 4 else 255
                    size = particle[5] if len(particle) > 5 else 3
                    color = particle[6] if len(particle) > 6 else default_color
                
                particle_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(particle_surface, (*color, alpha), (size, size), size)
                surface.blit(particle_surface, (x - size, y - size))
    
    @staticmethod
    def draw_glow(surface, pos, radius, color, intensity=0.5):
        """범용 글로우 효과"""
        glow_surface = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
        for i in range(radius, 0, -2):
            alpha = int((1 - i/radius) * 255 * intensity)
            pygame.draw.circle(glow_surface, (*color, alpha), (radius, radius), i)
        surface.blit(glow_surface, (pos[0] - radius, pos[1] - radius), special_flags=pygame.BLEND_ADD)
    
    @staticmethod
    def draw_explosion(surface, pos, radius, color=(255, 100, 0), particles=20):
        """범용 폭발 효과"""
        # 중심 플래시
        EffectRenderer.draw_glow(surface, pos, radius, color, 0.8)
        
        # 파티클 생성
        explosion_particles = []
        for _ in range(particles):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(2, radius/10)
            explosion_particles.append({
                'x': pos[0],
                'y': pos[1],
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': random.randint(20, 40),
                'size': random.randint(2, 5),
                'color': color,
                'alpha': 255
            })
        return explosion_particles
    
    @staticmethod
    def draw_trail(surface, positions, color, width=3, fade=True):
        """범용 트레일 효과"""
        if len(positions) < 2:
            return
        
        for i in range(1, len(positions)):
            alpha = int((i / len(positions)) * 255) if fade else 255
            start = positions[i-1]
            end = positions[i]
            
            # 알파 블렌딩을 위한 라인 그리기
            if alpha < 255:
                temp = pygame.Surface((abs(end[0]-start[0])+width, abs(end[1]-start[1])+width), pygame.SRCALPHA)
                pygame.draw.line(temp, (*color, alpha), (0, 0), (end[0]-start[0], end[1]-start[1]), width)
                surface.blit(temp, start)
            else:
                pygame.draw.line(surface, color, start, end, width)
    
    @staticmethod
    def draw_ring(surface, pos, radius, color, width=3, alpha=255):
        """범용 링 효과"""
        if alpha < 255:
            ring_surface = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
            pygame.draw.circle(ring_surface, (*color, alpha), (radius, radius), radius, width)
            surface.blit(ring_surface, (pos[0] - radius, pos[1] - radius))
        else:
            pygame.draw.circle(surface, color, pos, radius, width)
    
    @staticmethod
    def draw_shockwave(surface, pos, radius, max_radius, color=(255, 255, 255)):
        """범용 충격파 효과"""
        if radius < max_radius:
            alpha = int(255 * (1 - radius / max_radius))
            EffectRenderer.draw_ring(surface, pos, radius, color, 3, alpha)
            return radius + max_radius / 20  # 성장 속도
        return max_radius
"""
메인 메뉴 배경 개선 모듈
세련된 우주 테마 배경을 제공합니다.
"""
import pygame
import math
import random
from typing import List, Tuple

class SpaceBackground:
    """우주 배경 관리 클래스"""
    
    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.time = 0
        
        # 별 생성
        self.stars = self._create_stars()
        
        # 행성 데이터
        self.planets = self._create_planets()
        
        # 성운 효과
        self.nebula_particles = self._create_nebula_particles()
        
        # 그리드 라인 (옵션)
        self.show_grid = True
        self.grid_alpha = 30
        
        # 파티클 효과
        self.particles = []
        self.max_particles = 50
    
    def _create_stars(self) -> List[dict]:
        """별 생성"""
        stars = []
        star_counts = {
            'small': 150,   # 작은 별
            'medium': 50,   # 중간 별
            'large': 10     # 큰 별
        }
        
        for size, count in star_counts.items():
            for _ in range(count):
                star = {
                    'x': random.randint(0, self.width),
                    'y': random.randint(0, self.height),
                    'size': size,
                    'brightness': random.uniform(0.3, 1.0),
                    'twinkle_speed': random.uniform(0.5, 2.0),
                    'twinkle_offset': random.uniform(0, math.pi * 2)
                }
                stars.append(star)
        
        return stars
    
    def _create_planets(self) -> List[dict]:
        """행성 생성 - 더 작고 우아하게"""
        planets = [
            # 왼쪽 위 - 작은 붉은 행성
            {
                'x': self.width * 0.15,
                'y': self.height * 0.2,
                'radius': 35,  # 크기 축소
                'color': (180, 60, 50),
                'glow_color': (255, 100, 80),
                'ring': True,
                'ring_color': (200, 80, 60, 60),
                'orbit_speed': 0.3,
                'orbit_radius': 10,
                'z_order': 2
            },
            # 오른쪽 위 - 보라색 행성
            {
                'x': self.width * 0.85,
                'y': self.height * 0.25,
                'radius': 28,  # 크기 축소
                'color': (120, 80, 180),
                'glow_color': (180, 120, 255),
                'ring': False,
                'orbit_speed': -0.2,
                'orbit_radius': 8,
                'z_order': 1
            },
            # 왼쪽 아래 - 청록색 행성
            {
                'x': self.width * 0.2,
                'y': self.height * 0.75,
                'radius': 30,  # 크기 축소
                'color': (50, 120, 140),
                'glow_color': (80, 200, 220),
                'ring': False,
                'orbit_speed': 0.15,
                'orbit_radius': 5,
                'z_order': 1
            },
            # 오른쪽 아래 - 작은 위성
            {
                'x': self.width * 0.8,
                'y': self.height * 0.8,
                'radius': 15,  # 매우 작은 크기
                'color': (200, 200, 210),
                'glow_color': (255, 255, 255),
                'ring': False,
                'orbit_speed': 0.5,
                'orbit_radius': 3,
                'z_order': 0
            },
            # 중앙 상단 멀리 - 배경 행성
            {
                'x': self.width * 0.5,
                'y': self.height * 0.15,
                'radius': 20,  # 배경용 작은 크기
                'color': (80, 80, 100),
                'glow_color': (120, 120, 150),
                'ring': False,
                'orbit_speed': 0.1,
                'orbit_radius': 2,
                'z_order': 0
            }
        ]
        
        # 초기 궤도 각도 설정
        for planet in planets:
            planet['orbit_angle'] = random.uniform(0, math.pi * 2)
            planet['base_x'] = planet['x']
            planet['base_y'] = planet['y']
        
        return planets
    
    def _create_nebula_particles(self) -> List[dict]:
        """성운 파티클 생성"""
        particles = []
        for _ in range(30):
            particle = {
                'x': random.randint(0, self.width),
                'y': random.randint(0, self.height),
                'radius': random.randint(50, 150),
                'color': random.choice([
                    (100, 50, 150, 20),   # 보라색
                    (50, 100, 150, 20),   # 청색
                    (150, 50, 100, 20)    # 분홍색
                ]),
                'drift_x': random.uniform(-0.2, 0.2),
                'drift_y': random.uniform(-0.1, 0.1)
            }
            particles.append(particle)
        
        return particles
    
    def update(self, dt: float):
        """배경 업데이트"""
        self.time += dt
        
        # 행성 궤도 업데이트
        for planet in self.planets:
            planet['orbit_angle'] += planet['orbit_speed'] * dt
            offset_x = math.cos(planet['orbit_angle']) * planet['orbit_radius']
            offset_y = math.sin(planet['orbit_angle']) * planet['orbit_radius'] * 0.5
            planet['x'] = planet['base_x'] + offset_x
            planet['y'] = planet['base_y'] + offset_y
        
        # 성운 파티클 움직임
        for particle in self.nebula_particles:
            particle['x'] += particle['drift_x']
            particle['y'] += particle['drift_y']
            
            # 화면 밖으로 나가면 반대편에서 나타남
            if particle['x'] < -particle['radius']:
                particle['x'] = self.width + particle['radius']
            elif particle['x'] > self.width + particle['radius']:
                particle['x'] = -particle['radius']
            
            if particle['y'] < -particle['radius']:
                particle['y'] = self.height + particle['radius']
            elif particle['y'] > self.height + particle['radius']:
                particle['y'] = -particle['radius']
        
        # 떠다니는 파티클 생성
        if len(self.particles) < self.max_particles and random.random() < 0.1:
            self.particles.append(self._create_floating_particle())
        
        # 파티클 업데이트
        for particle in self.particles[:]:
            particle['lifetime'] -= dt
            particle['y'] -= particle['speed'] * dt
            particle['x'] += math.sin(self.time * 2 + particle['offset']) * 0.5
            
            if particle['lifetime'] <= 0 or particle['y'] < -10:
                self.particles.remove(particle)
    
    def _create_floating_particle(self) -> dict:
        """떠다니는 파티클 생성"""
        return {
            'x': random.randint(0, self.width),
            'y': self.height + 10,
            'speed': random.uniform(10, 30),
            'size': random.uniform(1, 3),
            'color': random.choice([
                (100, 200, 255),  # 청색
                (255, 200, 100),  # 노란색
                (200, 100, 255)   # 보라색
            ]),
            'lifetime': random.uniform(10, 20),
            'offset': random.uniform(0, math.pi * 2)
        }
    
    def draw(self, surface: pygame.Surface):
        """배경 그리기"""
        # 기본 배경 (깊은 우주)
        surface.fill((8, 12, 24))
        
        # 그라데이션 오버레이
        self._draw_gradient_overlay(surface)
        
        # 성운 효과
        self._draw_nebula(surface)
        
        # 그리드 라인
        if self.show_grid:
            self._draw_grid(surface)
        
        # 별 그리기
        self._draw_stars(surface)
        
        # 행성 그리기 (z_order 순서대로)
        sorted_planets = sorted(self.planets, key=lambda p: p['z_order'])
        for planet in sorted_planets:
            self._draw_planet(surface, planet)
        
        # 떠다니는 파티클
        self._draw_particles(surface)
    
    def _draw_gradient_overlay(self, surface: pygame.Surface):
        """그라데이션 오버레이"""
        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        # 상단에서 하단으로 그라데이션
        for y in range(self.height):
            alpha = int(30 * (1 - y / self.height))
            color = (20, 30, 60, alpha)
            pygame.draw.line(overlay, color, (0, y), (self.width, y))
        
        surface.blit(overlay, (0, 0))
    
    def _draw_grid(self, surface: pygame.Surface):
        """그리드 라인 그리기"""
        grid_color = (50, 100, 150, self.grid_alpha)
        grid_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        # 수평선
        for y in range(0, self.height, 50):
            pygame.draw.line(grid_surface, grid_color, (0, y), (self.width, y), 1)
        
        # 수직선 (원근감)
        center_x = self.width // 2
        for x in range(-self.width, self.width * 2, 100):
            start_x = center_x + (x - center_x) * 0.5
            end_x = center_x + (x - center_x) * 2
            pygame.draw.line(grid_surface, grid_color, 
                           (start_x, 0), (end_x, self.height), 1)
        
        surface.blit(grid_surface, (0, 0))
    
    def _draw_nebula(self, surface: pygame.Surface):
        """성운 효과 그리기"""
        nebula_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        for particle in self.nebula_particles:
            # 부드러운 원형 그라데이션
            for i in range(particle['radius'], 0, -5):
                alpha = particle['color'][3] * (i / particle['radius'])
                color = (*particle['color'][:3], int(alpha))
                pygame.draw.circle(nebula_surface, color,
                                 (int(particle['x']), int(particle['y'])), i)
        
        surface.blit(nebula_surface, (0, 0))
    
    def _draw_stars(self, surface: pygame.Surface):
        """별 그리기"""
        for star in self.stars:
            # 반짝임 효과
            twinkle = math.sin(self.time * star['twinkle_speed'] + star['twinkle_offset'])
            brightness = star['brightness'] + twinkle * 0.3
            brightness = max(0.1, min(1.0, brightness))
            
            color = tuple(int(255 * brightness) for _ in range(3))
            
            if star['size'] == 'small':
                surface.set_at((int(star['x']), int(star['y'])), color)
            elif star['size'] == 'medium':
                pygame.draw.circle(surface, color, 
                                 (int(star['x']), int(star['y'])), 1)
            else:  # large
                pygame.draw.circle(surface, color,
                                 (int(star['x']), int(star['y'])), 2)
                # 십자 효과
                pygame.draw.line(surface, (*color[:2], color[2] // 2),
                               (star['x'] - 4, star['y']),
                               (star['x'] + 4, star['y']), 1)
                pygame.draw.line(surface, (*color[:2], color[2] // 2),
                               (star['x'], star['y'] - 4),
                               (star['x'], star['y'] + 4), 1)
    
    def _draw_planet(self, surface: pygame.Surface, planet: dict):
        """행성 그리기"""
        x, y = int(planet['x']), int(planet['y'])
        
        # 글로우 효과
        glow_surface = pygame.Surface((planet['radius'] * 4, planet['radius'] * 4), pygame.SRCALPHA)
        for i in range(planet['radius'] * 2, 0, -2):
            alpha = 30 * (i / (planet['radius'] * 2))
            glow_color = (*planet['glow_color'], int(alpha))
            pygame.draw.circle(glow_surface, glow_color,
                             (planet['radius'] * 2, planet['radius'] * 2), i)
        
        surface.blit(glow_surface, (x - planet['radius'] * 2, y - planet['radius'] * 2))
        
        # 행성 본체
        pygame.draw.circle(surface, planet['color'], (x, y), planet['radius'])
        
        # 하이라이트
        highlight_offset = planet['radius'] // 3
        highlight_radius = planet['radius'] // 4
        highlight_color = tuple(min(255, c + 50) for c in planet['color'])
        pygame.draw.circle(surface, highlight_color,
                         (x - highlight_offset, y - highlight_offset),
                         highlight_radius)
        
        # 고리 (있는 경우)
        if planet.get('ring'):
            ring_width = planet['radius'] * 2
            ring_height = planet['radius'] // 2
            ring_surface = pygame.Surface((ring_width * 2, ring_height * 2), pygame.SRCALPHA)
            
            # 고리 그리기
            for i in range(3):
                ring_rect = pygame.Rect(
                    ring_width // 2 - planet['radius'] - 10 - i * 5,
                    ring_height // 2,
                    (planet['radius'] + 10 + i * 5) * 2,
                    ring_height
                )
                pygame.draw.ellipse(ring_surface, planet['ring_color'],
                                  ring_rect, 2)
            
            surface.blit(ring_surface, (x - ring_width, y - ring_height // 2))
    
    def _draw_particles(self, surface: pygame.Surface):
        """떠다니는 파티클 그리기"""
        for particle in self.particles:
            alpha = min(255, int(255 * (particle['lifetime'] / 20)))
            color = (*particle['color'], alpha)
            
            particle_surface = pygame.Surface((particle['size'] * 2, particle['size'] * 2), pygame.SRCALPHA)
            pygame.draw.circle(particle_surface, color,
                             (int(particle['size']), int(particle['size'])),
                             int(particle['size']))
            
            surface.blit(particle_surface,
                        (int(particle['x'] - particle['size']),
                         int(particle['y'] - particle['size'])))
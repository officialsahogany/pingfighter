"""
심플하고 세련된 사이버펑크 메인 메뉴 배경
"""
import pygame
import math
import random
from typing import List, Tuple

class SimpleMenuBackground:
    """심플한 사이버펑크 스타일 배경 관리 클래스 + 애니 감성"""

    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.time = 0

        # 사이버펑크 색상 팔레트 (차분한 톤)
        self.colors = {
            'bg_top': (15, 25, 45),      # 상단 (어두운 남색)
            'bg_bottom': (25, 35, 55),    # 하단 (약간 밝은 남색)
            'grid': (0, 100, 150, 15),    # 은은한 그리드
            'neon_cyan': (0, 200, 255),
            'neon_purple': (150, 100, 255),
            'particle': (100, 200, 255, 50)
        }

        # 심플한 공전 행성들
        self.planets = self._create_planets()

        # 배경 파티클 (최소화)
        self.particles = []
        for _ in range(15):
            self.particles.append({
                'x': random.randint(0, width),
                'y': random.randint(0, height),
                'vx': random.uniform(-0.2, 0.2),
                'vy': random.uniform(-0.2, 0.2),
                'size': 1,
                'alpha': random.randint(20, 60)
            })

        # === 애니 감성 요소들 ===
        # 키라키라 반짝이 효과
        self.sparkles = []
        for _ in range(30):
            self.sparkles.append({
                'x': random.randint(0, width),
                'y': random.randint(0, height),
                'size': random.uniform(2, 6),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(2, 5),
                'color': random.choice([
                    (255, 200, 255),  # 핑크
                    (200, 255, 255),  # 시안
                    (255, 255, 200),  # 옐로우
                    (255, 220, 240),  # 라이트 핑크
                ])
            })

        # 하트/별 파티클
        self.cute_particles = []
        for _ in range(12):
            self.cute_particles.append({
                'x': random.randint(0, width),
                'y': random.randint(0, height),
                'vx': random.uniform(-0.3, 0.3),
                'vy': random.uniform(-0.5, -0.1),  # 위로 떠오름
                'type': random.choice(['heart', 'star', 'sparkle']),
                'size': random.uniform(8, 16),
                'alpha': random.randint(100, 200),
                'rotation': random.uniform(0, math.pi * 2),
                'rot_speed': random.uniform(-0.02, 0.02),
                'color': random.choice([
                    (255, 150, 200),  # 핑크
                    (200, 150, 255),  # 퍼플
                    (255, 220, 180),  # 피치
                ])
            })

        # 무지개빛 오로라 웨이브
        self.aurora_waves = []
        for i in range(5):
            self.aurora_waves.append({
                'y_offset': random.uniform(0, height * 0.4),
                'amplitude': random.uniform(20, 50),
                'frequency': random.uniform(0.003, 0.008),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(0.3, 0.8),
                'hue_offset': i * 60,  # 무지개 색상 오프셋
                'alpha': random.randint(15, 35)
            })

        # 별똥별 (유성)
        self.shooting_stars = []
    
    def _create_planets(self) -> List[dict]:
        """귀여운 애니 스타일 행성들 생성 - 하트, 별, 사탕, 리본 테마"""
        center_x = self.width // 2
        center_y = self.height // 2

        planets = [
            # 중심 - 큰 핑크 하트 (태양 대신)
            {
                'type': 'heart_sun',
                'name': '사랑의 별',
                'x': center_x,
                'y': center_y,
                'radius': 80,
                'color': (255, 100, 150),       # 핑크
                'color2': (255, 150, 180),      # 연핑크
                'color3': (255, 80, 130),       # 진핑크
                'glow_color': (255, 150, 200),
                'orbit_radius': 0,
                'orbit_speed': 0,
                'orbit_angle': 0,
                'rotation': 0,
                'rotation_speed': 0.005,
                'pulse': True,
                'pulse_phase': 0,
                'sparkles': [],  # 반짝이 효과
                'hearts_orbit': []  # 주변 미니 하트들
            },
            # 라벤더 별 행성
            {
                'type': 'star_planet',
                'name': '라벤더 스타',
                'radius': 35,
                'color': (200, 150, 255),  # 라벤더
                'color2': (230, 200, 255),
                'glow_color': (220, 180, 255),
                'orbit_radius': 130,
                'orbit_speed': 0.4,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.02,
                'trail': [],
                'star_points': 5,
                'twinkle_phase': random.uniform(0, math.pi * 2)
            },
            # 민트 구슬 행성
            {
                'type': 'candy_planet',
                'name': '민트 캔디',
                'radius': 30,
                'color': (150, 255, 220),  # 민트
                'color2': (200, 255, 240),
                'glow_color': (180, 255, 230),
                'orbit_radius': 170,
                'orbit_speed': 0.32,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.015,
                'trail': [],
                'stripes': True,  # 사탕 줄무늬
                'stripe_color': (255, 255, 255)
            },
            # 피치 하트 행성
            {
                'type': 'heart_planet',
                'name': '피치 하트',
                'radius': 40,
                'color': (255, 180, 150),  # 피치
                'color2': (255, 200, 180),
                'glow_color': (255, 200, 170),
                'orbit_radius': 220,
                'orbit_speed': 0.25,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.01,
                'trail': [],
                'mini_hearts': []  # 주변 미니 하트들
            },
            # 레몬 별 행성
            {
                'type': 'star_planet',
                'name': '레몬 스타',
                'radius': 32,
                'color': (255, 255, 150),  # 레몬 옐로우
                'color2': (255, 255, 200),
                'glow_color': (255, 255, 180),
                'orbit_radius': 270,
                'orbit_speed': 0.2,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.018,
                'trail': [],
                'star_points': 6,
                'twinkle_phase': random.uniform(0, math.pi * 2)
            },
            # 코튼캔디 행성 (리본 고리)
            {
                'type': 'ribbon_planet',
                'name': '코튼캔디',
                'radius': 55,
                'color': (255, 180, 220),  # 핑크
                'color2': (200, 180, 255),  # 보라
                'glow_color': (255, 200, 230),
                'orbit_radius': 340,
                'orbit_speed': 0.12,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.025,
                'trail': [],
                'ribbons': {
                    'inner_radius': 65,
                    'outer_radius': 90,
                    'colors': [(255, 150, 200), (200, 150, 255), (150, 200, 255)],
                    'rotation': 0,
                    'rotation_speed': 0.015
                }
            },
            # 하늘색 보석 행성
            {
                'type': 'gem_planet',
                'name': '스카이 젬',
                'radius': 38,
                'color': (150, 200, 255),  # 스카이 블루
                'color2': (200, 230, 255),
                'glow_color': (180, 220, 255),
                'orbit_radius': 400,
                'orbit_speed': 0.09,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.012,
                'trail': [],
                'facets': 8,  # 보석 면 개수
                'shimmer_phase': random.uniform(0, math.pi * 2)
            },
            # 보라색 별 행성
            {
                'type': 'star_planet',
                'name': '바이올렛 스타',
                'radius': 36,
                'color': (180, 100, 255),  # 바이올렛
                'color2': (220, 150, 255),
                'glow_color': (200, 130, 255),
                'orbit_radius': 460,
                'orbit_speed': 0.065,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': -0.015,
                'trail': [],
                'star_points': 4,
                'twinkle_phase': random.uniform(0, math.pi * 2)
            },
            # 핑크 작은 하트
            {
                'type': 'mini_heart',
                'name': '쁘띠 하트',
                'radius': 20,
                'color': (255, 150, 180),  # 베이비 핑크
                'color2': (255, 180, 200),
                'glow_color': (255, 170, 200),
                'orbit_radius': 510,
                'orbit_speed': 0.05,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.008,
                'trail': [],
                'wobble': True  # 흔들림 효과
            }
        ]

        # 행성별 특수 효과 초기화
        for planet in planets:
            if planet['type'] == 'heart_sun':
                # 중심 하트 주변 반짝이
                for _ in range(15):
                    planet['sparkles'].append({
                        'angle': random.uniform(0, math.pi * 2),
                        'distance': random.uniform(1.1, 1.8),
                        'size': random.uniform(3, 8),
                        'phase': random.uniform(0, math.pi * 2),
                        'speed': random.uniform(1.5, 3.0)
                    })
                # 주변 미니 하트들
                for i in range(6):
                    planet['hearts_orbit'].append({
                        'angle': i * math.pi / 3,
                        'distance': random.uniform(1.3, 1.6),
                        'size': random.uniform(8, 15),
                        'speed': random.uniform(0.3, 0.6),
                        'color': random.choice([
                            (255, 150, 200), (255, 200, 220), (255, 180, 210)
                        ])
                    })
            elif planet['type'] == 'heart_planet':
                # 하트 행성 주변 미니 하트
                for _ in range(4):
                    planet['mini_hearts'].append({
                        'angle': random.uniform(0, math.pi * 2),
                        'distance': random.uniform(1.5, 2.5),
                        'size': random.uniform(5, 10),
                        'speed': random.uniform(0.8, 1.5)
                    })
            elif planet['type'] == 'ribbon_planet':
                # 리본 파티클
                planet['ribbon_particles'] = []
                for _ in range(30):
                    planet['ribbon_particles'].append({
                        'angle': random.uniform(0, math.pi * 2),
                        'radius': random.uniform(planet['ribbons']['inner_radius'],
                                                planet['ribbons']['outer_radius']),
                        'speed': random.uniform(0.01, 0.03),
                        'size': random.uniform(2, 5),
                        'color_idx': random.randint(0, 2)
                    })

        return planets
    
    def update(self, dt: float):
        """배경 업데이트"""
        self.time += dt

        # 행성 공전 업데이트
        center_x = self.width // 2
        center_y = self.height // 2

        for planet in self.planets:
            # 자전 업데이트 (모든 행성)
            planet['rotation'] += planet.get('rotation_speed', 0.01) * 60 * dt

            if planet['type'] == 'heart_sun':
                # 중심 하트 펄스 효과
                if planet.get('pulse'):
                    planet['pulse_phase'] = planet.get('pulse_phase', 0) + dt * 2
                    planet['current_radius'] = planet['radius'] + math.sin(planet['pulse_phase']) * 5

                # 반짝이 업데이트
                for sparkle in planet.get('sparkles', []):
                    sparkle['phase'] += sparkle['speed'] * dt
                    sparkle['angle'] += 0.3 * dt  # 천천히 회전

                # 주변 하트 회전
                for heart in planet.get('hearts_orbit', []):
                    heart['angle'] += heart['speed'] * dt

            elif planet['orbit_radius'] > 0:
                # 행성 공전
                planet['orbit_angle'] += planet['orbit_speed'] * dt
                planet['x'] = center_x + math.cos(planet['orbit_angle']) * planet['orbit_radius']
                planet['y'] = center_y + math.sin(planet['orbit_angle']) * planet['orbit_radius'] * 0.5

                # 궤적 추가 (반짝이는 파티클 느낌)
                if 'trail' in planet:
                    if len(planet['trail']) > 20:
                        planet['trail'].pop(0)
                    planet['trail'].append((planet['x'], planet['y']))

                # 특수 효과 업데이트
                if planet['type'] == 'star_planet':
                    # 별 반짝임
                    planet['twinkle_phase'] = planet.get('twinkle_phase', 0) + dt * 3

                elif planet['type'] == 'heart_planet':
                    # 미니 하트들 회전
                    for heart in planet.get('mini_hearts', []):
                        heart['angle'] += heart['speed'] * dt

                elif planet['type'] == 'ribbon_planet':
                    # 리본 고리 회전
                    if 'ribbons' in planet:
                        planet['ribbons']['rotation'] += planet['ribbons']['rotation_speed'] * 60 * dt
                    # 리본 파티클 업데이트
                    for particle in planet.get('ribbon_particles', []):
                        particle['angle'] += particle['speed']

                elif planet['type'] == 'gem_planet':
                    # 보석 반짝임
                    planet['shimmer_phase'] = planet.get('shimmer_phase', 0) + dt * 4

                elif planet['type'] == 'candy_planet':
                    # 사탕 줄무늬 회전 (자전으로 처리됨)
                    pass

                elif planet['type'] == 'mini_heart':
                    # 흔들림 효과
                    if planet.get('wobble'):
                        planet['wobble_phase'] = planet.get('wobble_phase', 0) + dt * 5
        
        # 파티클 업데이트
        for particle in self.particles:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']

            if particle['x'] < 0:
                particle['x'] = self.width
            elif particle['x'] > self.width:
                particle['x'] = 0
            if particle['y'] < 0:
                particle['y'] = self.height
            elif particle['y'] > self.height:
                particle['y'] = 0

        # === 애니 감성 요소 업데이트 ===
        # 키라키라 반짝이 업데이트
        for sparkle in self.sparkles:
            sparkle['phase'] += sparkle['speed'] * dt
            # 랜덤하게 위치 변경 (깜빡임 효과)
            if random.random() < 0.005:
                sparkle['x'] = random.randint(0, self.width)
                sparkle['y'] = random.randint(0, self.height)

        # 하트/별 파티클 업데이트
        for p in self.cute_particles:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['rotation'] += p['rot_speed']

            # 화면 밖으로 나가면 리셋
            if p['y'] < -50 or p['x'] < -50 or p['x'] > self.width + 50:
                p['x'] = random.randint(0, self.width)
                p['y'] = self.height + random.randint(10, 100)
                p['alpha'] = random.randint(100, 200)

        # 별똥별 업데이트 및 생성
        if random.random() < 0.008:  # 가끔 별똥별 생성
            self.shooting_stars.append({
                'x': random.randint(0, self.width),
                'y': random.randint(0, int(self.height * 0.3)),
                'vx': random.uniform(8, 15),
                'vy': random.uniform(4, 8),
                'life': 1.0,
                'length': random.randint(30, 80),
                'color': random.choice([
                    (255, 200, 255),  # 핑크
                    (200, 255, 255),  # 시안
                    (255, 255, 200),  # 옐로우
                ])
            })

        # 별똥별 이동 및 소멸
        for star in self.shooting_stars[:]:
            star['x'] += star['vx']
            star['y'] += star['vy']
            star['life'] -= dt * 1.5
            if star['life'] <= 0 or star['x'] > self.width or star['y'] > self.height:
                self.shooting_stars.remove(star)
    
    def draw(self, surface: pygame.Surface):
        """배경 그리기"""

        # 1. 그라데이션 배경 (세로 줄무늬 방지를 위해 fill + blit 방식 사용)
        # 먼저 전체 배경을 단색으로 채우기
        surface.fill(self.colors['bg_top'])

        # 그라데이션 오버레이 생성 (캐시하여 재사용)
        if not hasattr(self, '_gradient_surface') or self._gradient_surface is None:
            self._gradient_surface = pygame.Surface((self.width, self.height))
            for y in range(self.height):
                ratio = y / self.height
                r = int(self.colors['bg_top'][0] + ratio * (self.colors['bg_bottom'][0] - self.colors['bg_top'][0]))
                g = int(self.colors['bg_top'][1] + ratio * (self.colors['bg_bottom'][1] - self.colors['bg_top'][1]))
                b = int(self.colors['bg_top'][2] + ratio * (self.colors['bg_bottom'][2] - self.colors['bg_top'][2]))
                pygame.draw.rect(self._gradient_surface, (r, g, b), (0, y, self.width, 1))

        surface.blit(self._gradient_surface, (0, 0))
        
        # 2. 은은한 격자 패턴 (비활성화 - 세로줄 아티팩트 확인용)
        # grid_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        # for x in range(0, self.width, 40):
        #     pygame.draw.line(grid_surface, self.colors['grid'], (x, 0), (x, self.height))
        # for y in range(0, self.height, 40):
        #     pygame.draw.line(grid_surface, self.colors['grid'], (0, y), (self.width, y))
        # surface.blit(grid_surface, (0, 0))
        
        # 3. 배경 파티클
        for particle in self.particles:
            pygame.draw.circle(surface, (*self.colors['particle'][:3], particle['alpha']),
                             (int(particle['x']), int(particle['y'])), particle['size'])
        
        # 4. 궤도 그리기
        center_x = self.width // 2
        center_y = self.height // 2
        orbit_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        for planet in self.planets:
            if planet['orbit_radius'] > 0:
                # 궤도 선 (타원, 은은하게)
                orbit_rect = pygame.Rect(
                    center_x - planet['orbit_radius'],
                    center_y - planet['orbit_radius'] * 0.5,
                    planet['orbit_radius'] * 2,
                    planet['orbit_radius']
                )
                pygame.draw.ellipse(orbit_surface, (50, 100, 150, 20), orbit_rect, 1)
        
        surface.blit(orbit_surface, (0, 0))
        
        # 5. 귀여운 애니 스타일 행성 그리기
        sorted_planets = sorted(self.planets, key=lambda p: p.get('y', center_y))

        for planet in sorted_planets:
            x, y = planet.get('x', center_x), planet.get('y', center_y)

            if planet['type'] == 'heart_sun':
                # 중심 - 큰 핑크 하트
                radius = planet.get('current_radius', planet['radius'])
                self._draw_heart_sun(surface, x, y, radius, planet)

            elif planet['type'] == 'star_planet':
                # 별 모양 행성
                self._draw_star_planet(surface, x, y, planet)

            elif planet['type'] == 'candy_planet':
                # 사탕 행성
                self._draw_candy_planet(surface, x, y, planet)

            elif planet['type'] == 'heart_planet':
                # 하트 행성
                self._draw_heart_planet(surface, x, y, planet)

            elif planet['type'] == 'ribbon_planet':
                # 리본 고리 행성
                self._draw_ribbon_planet(surface, x, y, planet)

            elif planet['type'] == 'gem_planet':
                # 보석 행성
                self._draw_gem_planet(surface, x, y, planet)

            elif planet['type'] == 'mini_heart':
                # 작은 하트 행성
                self._draw_mini_heart(surface, x, y, planet)

            else:
                # 기본 귀여운 행성 (폴백)
                self._draw_cute_planet_default(surface, x, y, planet)

        # 애니 감성 효과는 start_menu.py에서 맨 마지막에 별도로 그림
        # (star_field, neon_particles, scan_lines 위에 그려지도록)

    def _draw_heart_sun(self, surface: pygame.Surface, x: float, y: float, radius: float, planet: dict):
        """중심 핑크 하트 그리기"""
        # 다층 글로우 효과 (핑크빛)
        for i in range(4):
            glow_radius = radius + 20 + i * 15
            glow_alpha = 50 - i * 10
            glow_surf = pygame.Surface((int(glow_radius * 2.5), int(glow_radius * 2.5)), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*planet['glow_color'], glow_alpha),
                             (int(glow_radius * 1.25), int(glow_radius * 1.25)), int(glow_radius))
            surface.blit(glow_surf, (int(x - glow_radius * 1.25), int(y - glow_radius * 1.25)))

        # 큰 하트 그리기
        heart_surf = pygame.Surface((int(radius * 3), int(radius * 3)), pygame.SRCALPHA)
        self._draw_big_heart(heart_surf, radius * 1.5, radius * 1.5, radius, planet['color'], planet['color2'])
        surface.blit(heart_surf, (int(x - radius * 1.5), int(y - radius * 1.5)))

        # 반짝이 효과
        for sparkle in planet.get('sparkles', []):
            pulse = abs(math.sin(sparkle['phase']))
            sp_x = x + math.cos(sparkle['angle']) * radius * sparkle['distance']
            sp_y = y + math.sin(sparkle['angle']) * radius * sparkle['distance'] * 0.7
            sp_size = int(sparkle['size'] * (0.5 + pulse * 0.5))
            sp_alpha = int(200 * pulse + 55)
            if sp_size > 0:
                # 키라키라 십자가
                pygame.draw.line(surface, (255, 255, 255, sp_alpha),
                               (int(sp_x - sp_size), int(sp_y)), (int(sp_x + sp_size), int(sp_y)), 2)
                pygame.draw.line(surface, (255, 255, 255, sp_alpha),
                               (int(sp_x), int(sp_y - sp_size)), (int(sp_x), int(sp_y + sp_size)), 2)

        # 주변 미니 하트들
        for heart in planet.get('hearts_orbit', []):
            h_x = x + math.cos(heart['angle']) * radius * heart['distance']
            h_y = y + math.sin(heart['angle']) * radius * heart['distance'] * 0.6
            h_size = int(heart['size'])
            mini_heart_surf = pygame.Surface((h_size * 3, h_size * 3), pygame.SRCALPHA)
            self._draw_heart(mini_heart_surf, h_size * 1.5, h_size * 1.5, h_size, (*heart['color'], 200))
            surface.blit(mini_heart_surf, (int(h_x - h_size * 1.5), int(h_y - h_size * 1.5)))

    def _draw_big_heart(self, surface: pygame.Surface, cx: float, cy: float, size: float, color: Tuple, color2: Tuple):
        """큰 하트 그리기 (그라데이션 효과)"""
        # 외곽 글로우
        for glow in range(3):
            glow_size = size + 5 + glow * 3
            glow_alpha = 60 - glow * 15
            points = []
            for i in range(40):
                t = i / 40 * 2 * math.pi
                hx = 16 * (math.sin(t) ** 3)
                hy = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
                points.append((cx + hx * glow_size / 18, cy + hy * glow_size / 18))
            if len(points) > 2:
                pygame.draw.polygon(surface, (*color2, glow_alpha), points)

        # 메인 하트
        points = []
        for i in range(40):
            t = i / 40 * 2 * math.pi
            hx = 16 * (math.sin(t) ** 3)
            hy = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
            points.append((cx + hx * size / 18, cy + hy * size / 18))
        if len(points) > 2:
            pygame.draw.polygon(surface, color, points)

        # 하이라이트
        highlight_size = size * 0.3
        pygame.draw.circle(surface, (255, 255, 255, 100),
                         (int(cx - size * 0.25), int(cy - size * 0.3)), int(highlight_size))
        pygame.draw.circle(surface, (255, 255, 255, 60),
                         (int(cx - size * 0.15), int(cy - size * 0.2)), int(highlight_size * 0.6))

    def _draw_star_planet(self, surface: pygame.Surface, x: float, y: float, planet: dict):
        """별 모양 행성 그리기"""
        radius = planet['radius']
        points = planet.get('star_points', 5)
        twinkle = abs(math.sin(planet.get('twinkle_phase', 0)))

        # 궤적 그리기
        self._draw_cute_trail(surface, planet)

        # 글로우 효과
        glow_radius = radius + 10 + twinkle * 5
        glow_surf = pygame.Surface((int(glow_radius * 3), int(glow_radius * 3)), pygame.SRCALPHA)
        for i in range(3):
            gr = glow_radius - i * 3
            ga = int(40 - i * 10 + twinkle * 20)
            pygame.draw.circle(glow_surf, (*planet['glow_color'], ga),
                             (int(glow_radius * 1.5), int(glow_radius * 1.5)), int(gr))
        surface.blit(glow_surf, (int(x - glow_radius * 1.5), int(y - glow_radius * 1.5)))

        # 별 본체
        star_surf = pygame.Surface((int(radius * 3), int(radius * 3)), pygame.SRCALPHA)
        star_points = []
        for i in range(points * 2):
            r = radius if i % 2 == 0 else radius * 0.4
            angle = i * math.pi / points - math.pi / 2 + planet['rotation']
            star_points.append((
                radius * 1.5 + math.cos(angle) * r,
                radius * 1.5 + math.sin(angle) * r
            ))
        if len(star_points) > 2:
            pygame.draw.polygon(star_surf, planet['color'], star_points)
            # 밝은 테두리
            pygame.draw.polygon(star_surf, planet['color2'], star_points, 2)

        # 하이라이트
        pygame.draw.circle(star_surf, (255, 255, 255, 120),
                         (int(radius * 1.2), int(radius * 1.2)), int(radius * 0.25))

        surface.blit(star_surf, (int(x - radius * 1.5), int(y - radius * 1.5)))

        # 반짝임 광선
        if twinkle > 0.7:
            line_len = radius * (0.5 + twinkle * 0.5)
            pygame.draw.line(surface, (255, 255, 255, int(150 * twinkle)),
                           (int(x - line_len), int(y)), (int(x + line_len), int(y)), 2)
            pygame.draw.line(surface, (255, 255, 255, int(150 * twinkle)),
                           (int(x), int(y - line_len)), (int(x), int(y + line_len)), 2)

    def _draw_candy_planet(self, surface: pygame.Surface, x: float, y: float, planet: dict):
        """사탕 줄무늬 행성 그리기"""
        radius = planet['radius']

        # 궤적 그리기
        self._draw_cute_trail(surface, planet)

        # 글로우
        glow_radius = radius + 8
        glow_surf = pygame.Surface((int(glow_radius * 2.5), int(glow_radius * 2.5)), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*planet['glow_color'], 40),
                         (int(glow_radius * 1.25), int(glow_radius * 1.25)), int(glow_radius))
        surface.blit(glow_surf, (int(x - glow_radius * 1.25), int(y - glow_radius * 1.25)))

        # 사탕 본체
        candy_surf = pygame.Surface((int(radius * 2.5), int(radius * 2.5)), pygame.SRCALPHA)
        cx, cy = radius * 1.25, radius * 1.25

        # 베이스 원
        pygame.draw.circle(candy_surf, planet['color'], (int(cx), int(cy)), radius)

        # 줄무늬
        stripe_color = planet.get('stripe_color', (255, 255, 255))
        for i in range(6):
            stripe_angle = planet['rotation'] + i * math.pi / 3
            for j in range(-2, 3):
                offset = j * radius * 0.3
                sx1 = cx + math.cos(stripe_angle) * offset - math.sin(stripe_angle) * radius
                sy1 = cy + math.sin(stripe_angle) * offset + math.cos(stripe_angle) * radius
                sx2 = cx + math.cos(stripe_angle) * offset + math.sin(stripe_angle) * radius
                sy2 = cy + math.sin(stripe_angle) * offset - math.cos(stripe_angle) * radius
                pygame.draw.line(candy_surf, (*stripe_color, 150), (int(sx1), int(sy1)), (int(sx2), int(sy2)), 3)

        # 원형 마스크 적용 (클리핑)
        mask_surf = pygame.Surface((int(radius * 2.5), int(radius * 2.5)), pygame.SRCALPHA)
        pygame.draw.circle(mask_surf, (255, 255, 255, 255), (int(cx), int(cy)), radius)
        candy_surf.blit(mask_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)

        # 하이라이트
        pygame.draw.circle(candy_surf, (255, 255, 255, 100),
                         (int(cx - radius * 0.3), int(cy - radius * 0.3)), int(radius * 0.25))

        surface.blit(candy_surf, (int(x - radius * 1.25), int(y - radius * 1.25)))

    def _draw_heart_planet(self, surface: pygame.Surface, x: float, y: float, planet: dict):
        """하트 모양 행성 그리기"""
        radius = planet['radius']

        # 궤적 그리기
        self._draw_cute_trail(surface, planet)

        # 글로우
        glow_radius = radius + 10
        glow_surf = pygame.Surface((int(glow_radius * 2.5), int(glow_radius * 2.5)), pygame.SRCALPHA)
        for i in range(2):
            pygame.draw.circle(glow_surf, (*planet['glow_color'], 35 - i * 15),
                             (int(glow_radius * 1.25), int(glow_radius * 1.25)), int(glow_radius - i * 5))
        surface.blit(glow_surf, (int(x - glow_radius * 1.25), int(y - glow_radius * 1.25)))

        # 하트 본체
        heart_surf = pygame.Surface((int(radius * 3), int(radius * 3)), pygame.SRCALPHA)
        self._draw_heart(heart_surf, radius * 1.5, radius * 1.5, radius, (*planet['color'], 255))

        # 하이라이트
        pygame.draw.circle(heart_surf, (255, 255, 255, 100),
                         (int(radius * 1.2), int(radius * 1.2)), int(radius * 0.2))

        surface.blit(heart_surf, (int(x - radius * 1.5), int(y - radius * 1.5)))

        # 주변 미니 하트들
        for heart in planet.get('mini_hearts', []):
            h_x = x + math.cos(heart['angle']) * radius * heart['distance']
            h_y = y + math.sin(heart['angle']) * radius * heart['distance'] * 0.6
            h_size = int(heart['size'])
            mini_surf = pygame.Surface((h_size * 3, h_size * 3), pygame.SRCALPHA)
            self._draw_heart(mini_surf, h_size * 1.5, h_size * 1.5, h_size, (*planet['color'], 150))
            surface.blit(mini_surf, (int(h_x - h_size * 1.5), int(h_y - h_size * 1.5)))

    def _draw_ribbon_planet(self, surface: pygame.Surface, x: float, y: float, planet: dict):
        """리본 고리 행성 그리기 (코튼캔디)"""
        radius = planet['radius']

        # 궤적 그리기
        self._draw_cute_trail(surface, planet)

        # 리본 고리 (뒤쪽)
        if 'ribbons' in planet:
            ribbons = planet['ribbons']
            ribbon_surf = pygame.Surface((int(ribbons['outer_radius'] * 3), int(ribbons['outer_radius'] * 2)), pygame.SRCALPHA)

            for i, color in enumerate(ribbons['colors']):
                ring_r = ribbons['inner_radius'] + i * 8
                ring_rotation = ribbons['rotation'] + i * 0.2

                # 뒤쪽 고리 반만 그리기
                for angle in range(180, 360, 5):
                    rad = math.radians(angle + math.degrees(ring_rotation))
                    px = ribbons['outer_radius'] * 1.5 + ring_r * math.cos(rad)
                    py = ribbons['outer_radius'] - ring_r * math.sin(rad) * 0.35
                    alpha = int(80 + math.sin(rad * 3) * 30)
                    pygame.draw.circle(ribbon_surf, (*color, alpha), (int(px), int(py)), 3)

            surface.blit(ribbon_surf, (int(x - ribbons['outer_radius'] * 1.5), int(y - ribbons['outer_radius'])))

        # 글로우
        glow_radius = radius + 12
        glow_surf = pygame.Surface((int(glow_radius * 2.5), int(glow_radius * 2.5)), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*planet['glow_color'], 35),
                         (int(glow_radius * 1.25), int(glow_radius * 1.25)), int(glow_radius))
        surface.blit(glow_surf, (int(x - glow_radius * 1.25), int(y - glow_radius * 1.25)))

        # 행성 본체 (그라데이션)
        for i in range(int(radius)):
            ratio = i / radius
            r = int(planet['color'][0] * (1 - ratio * 0.2) + planet['color2'][0] * ratio * 0.2)
            g = int(planet['color'][1] * (1 - ratio * 0.2) + planet['color2'][1] * ratio * 0.2)
            b = int(planet['color'][2] * (1 - ratio * 0.2) + planet['color2'][2] * ratio * 0.2)
            pygame.draw.circle(surface, (r, g, b), (int(x), int(y)), radius - i)

        # 하이라이트
        pygame.draw.circle(surface, (255, 255, 255, 80),
                         (int(x - radius * 0.3), int(y - radius * 0.3)), int(radius * 0.25))

        # 리본 고리 (앞쪽)
        if 'ribbons' in planet:
            ribbons = planet['ribbons']
            front_ribbon = pygame.Surface((int(ribbons['outer_radius'] * 3), int(ribbons['outer_radius'] * 2)), pygame.SRCALPHA)

            for i, color in enumerate(ribbons['colors']):
                ring_r = ribbons['inner_radius'] + i * 8
                ring_rotation = ribbons['rotation'] + i * 0.2

                # 앞쪽 고리 반만 그리기
                for angle in range(0, 180, 5):
                    rad = math.radians(angle + math.degrees(ring_rotation))
                    px = ribbons['outer_radius'] * 1.5 + ring_r * math.cos(rad)
                    py = ribbons['outer_radius'] - ring_r * math.sin(rad) * 0.35
                    alpha = int(150 + math.sin(rad * 3) * 50)
                    pygame.draw.circle(front_ribbon, (*color, alpha), (int(px), int(py)), 4)

            surface.blit(front_ribbon, (int(x - ribbons['outer_radius'] * 1.5), int(y - ribbons['outer_radius'])))

    def _draw_gem_planet(self, surface: pygame.Surface, x: float, y: float, planet: dict):
        """보석 행성 그리기"""
        radius = planet['radius']
        facets = planet.get('facets', 8)
        shimmer = abs(math.sin(planet.get('shimmer_phase', 0)))

        # 궤적 그리기
        self._draw_cute_trail(surface, planet)

        # 글로우 (반짝임에 따라 변화)
        glow_radius = radius + 8 + shimmer * 5
        glow_surf = pygame.Surface((int(glow_radius * 3), int(glow_radius * 3)), pygame.SRCALPHA)
        glow_alpha = int(30 + shimmer * 30)
        pygame.draw.circle(glow_surf, (*planet['glow_color'], glow_alpha),
                         (int(glow_radius * 1.5), int(glow_radius * 1.5)), int(glow_radius))
        surface.blit(glow_surf, (int(x - glow_radius * 1.5), int(y - glow_radius * 1.5)))

        # 보석 면 그리기
        gem_surf = pygame.Surface((int(radius * 3), int(radius * 3)), pygame.SRCALPHA)
        cx, cy = radius * 1.5, radius * 1.5

        # 다각형 보석
        points = []
        for i in range(facets):
            angle = i * 2 * math.pi / facets + planet['rotation']
            points.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius * 0.8))

        if len(points) > 2:
            # 베이스
            pygame.draw.polygon(gem_surf, planet['color'], points)
            # 밝은 테두리
            pygame.draw.polygon(gem_surf, planet['color2'], points, 3)

            # 빛 반사 면들
            for i in range(0, facets, 2):
                next_i = (i + 1) % facets
                facet_points = [points[i], points[next_i], (cx, cy)]
                facet_color = tuple(min(255, c + 40) for c in planet['color'])
                pygame.draw.polygon(gem_surf, (*facet_color, 100), facet_points)

        # 중심 하이라이트
        pygame.draw.circle(gem_surf, (255, 255, 255, int(100 + shimmer * 80)),
                         (int(cx - radius * 0.2), int(cy - radius * 0.2)), int(radius * 0.3))

        # 반짝임 광선
        if shimmer > 0.6:
            line_alpha = int(200 * shimmer)
            line_len = radius * 0.8
            pygame.draw.line(gem_surf, (255, 255, 255, line_alpha),
                           (int(cx - line_len), int(cy)), (int(cx + line_len), int(cy)), 1)
            pygame.draw.line(gem_surf, (255, 255, 255, line_alpha),
                           (int(cx), int(cy - line_len)), (int(cx), int(cy + line_len)), 1)

        surface.blit(gem_surf, (int(x - radius * 1.5), int(y - radius * 1.5)))

    def _draw_mini_heart(self, surface: pygame.Surface, x: float, y: float, planet: dict):
        """작은 하트 행성 그리기"""
        radius = planet['radius']
        wobble_phase = planet.get('wobble_phase', 0)

        # 흔들림 효과
        wobble_x = math.sin(wobble_phase) * 3 if planet.get('wobble') else 0
        wobble_y = math.cos(wobble_phase * 0.7) * 2 if planet.get('wobble') else 0
        x += wobble_x
        y += wobble_y

        # 궤적 그리기
        self._draw_cute_trail(surface, planet)

        # 글로우
        glow_surf = pygame.Surface((int(radius * 4), int(radius * 4)), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*planet['glow_color'], 40),
                         (int(radius * 2), int(radius * 2)), int(radius + 5))
        surface.blit(glow_surf, (int(x - radius * 2), int(y - radius * 2)))

        # 하트 본체
        heart_surf = pygame.Surface((int(radius * 3), int(radius * 3)), pygame.SRCALPHA)
        self._draw_heart(heart_surf, radius * 1.5, radius * 1.5, radius, (*planet['color'], 255))

        # 하이라이트
        pygame.draw.circle(heart_surf, (255, 255, 255, 120),
                         (int(radius * 1.2), int(radius * 1.2)), int(radius * 0.2))

        surface.blit(heart_surf, (int(x - radius * 1.5), int(y - radius * 1.5)))

    def _draw_cute_planet_default(self, surface: pygame.Surface, x: float, y: float, planet: dict):
        """기본 귀여운 행성 (폴백)"""
        radius = planet['radius']

        # 궤적 그리기
        self._draw_cute_trail(surface, planet)

        # 글로우
        glow_radius = radius + 8
        glow_surf = pygame.Surface((int(glow_radius * 2.5), int(glow_radius * 2.5)), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*planet['glow_color'], 35),
                         (int(glow_radius * 1.25), int(glow_radius * 1.25)), int(glow_radius))
        surface.blit(glow_surf, (int(x - glow_radius * 1.25), int(y - glow_radius * 1.25)))

        # 행성 본체
        pygame.draw.circle(surface, planet['color'], (int(x), int(y)), radius)

        # 하이라이트
        pygame.draw.circle(surface, (255, 255, 255, 80),
                         (int(x - radius * 0.3), int(y - radius * 0.3)), int(radius * 0.25))

    def _draw_cute_trail(self, surface: pygame.Surface, planet: dict):
        """귀여운 반짝이 궤적 그리기"""
        trail = planet.get('trail', [])
        if len(trail) > 1:
            for i, pos in enumerate(trail):
                # 별 모양 파티클로 궤적 표현
                alpha = int(80 * (i / len(trail)))
                size = 2 + (i / len(trail)) * 2
                if alpha > 10:
                    color = (*planet['glow_color'], alpha)
                    pygame.draw.circle(surface, color, (int(pos[0]), int(pos[1])), int(size))

    def _draw_anime_effects(self, surface: pygame.Surface):
        """애니 감성 효과 그리기"""

        # 1. 무지개빛 오로라 웨이브 (맨 뒤에 그리기)
        aurora_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        for wave in self.aurora_waves:
            # HSV에서 RGB로 변환 (무지개 색상)
            hue = (self.time * wave['speed'] * 30 + wave['hue_offset']) % 360
            rgb = self._hsv_to_rgb(hue, 0.6, 1.0)

            # 웨이브 형태로 그리기
            points = []
            for x in range(0, self.width, 8):
                y = wave['y_offset'] + math.sin(x * wave['frequency'] + self.time * wave['speed'] + wave['phase']) * wave['amplitude']
                points.append((x, y))

            if len(points) > 2:
                # 그라데이션 오로라 라인
                for i in range(len(points) - 1):
                    alpha = int(wave['alpha'] * (1 - abs(i - len(points) // 2) / (len(points) // 2) * 0.5))
                    pygame.draw.line(aurora_surf, (*rgb, max(5, alpha)),
                                   points[i], points[i + 1], 3)
        surface.blit(aurora_surf, (0, 0))

        # 2. 별똥별 (유성) 그리기
        for star in self.shooting_stars:
            # 꼬리 길이
            tail_length = int(star['length'] * star['life'])
            if tail_length > 0:
                # 꼬리 그라데이션
                for i in range(min(5, tail_length // 10)):
                    t_alpha = int(200 * star['life'] * (1 - i * 0.18))
                    t_width = max(1, 4 - i)
                    t_x = star['x'] - star['vx'] * i * 3
                    t_y = star['y'] - star['vy'] * i * 3
                    if t_alpha > 0:
                        pygame.draw.circle(surface, (*star['color'], t_alpha),
                                         (int(t_x), int(t_y)), t_width)

                # 별똥별 본체
                head_alpha = int(255 * star['life'])
                pygame.draw.circle(surface, (*star['color'], head_alpha),
                                 (int(star['x']), int(star['y'])), 3)
                # 밝은 중심
                pygame.draw.circle(surface, (255, 255, 255, head_alpha),
                                 (int(star['x']), int(star['y'])), 1)

        # 3. 키라키라 반짝이 효과 (십자가 모양 별)
        for sparkle in self.sparkles:
            # 펄스 효과
            pulse = abs(math.sin(sparkle['phase']))
            size = int(sparkle['size'] * (0.5 + pulse * 0.8))
            alpha = int(150 * pulse + 50)

            if size > 0 and alpha > 0:
                sx, sy = int(sparkle['x']), int(sparkle['y'])
                color = (*sparkle['color'], alpha)

                # 십자가 모양 (키라키라)
                # 가로선
                pygame.draw.line(surface, color, (sx - size, sy), (sx + size, sy), 1)
                # 세로선
                pygame.draw.line(surface, color, (sx, sy - size), (sx, sy + size), 1)
                # 대각선 (작게)
                diag_size = size // 2
                pygame.draw.line(surface, color, (sx - diag_size, sy - diag_size), (sx + diag_size, sy + diag_size), 1)
                pygame.draw.line(surface, color, (sx - diag_size, sy + diag_size), (sx + diag_size, sy - diag_size), 1)

                # 중심 밝은 점
                if pulse > 0.7:
                    pygame.draw.circle(surface, (255, 255, 255, int(alpha * 0.8)), (sx, sy), 2)

        # 4. 하트/별 파티클 그리기
        for p in self.cute_particles:
            px, py = int(p['x']), int(p['y'])
            size = int(p['size'])
            alpha = p['alpha']

            particle_surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
            center = size * 1.5

            if p['type'] == 'heart':
                # 하트 모양 그리기
                self._draw_heart(particle_surf, center, center, size, (*p['color'], alpha))
            elif p['type'] == 'star':
                # 별 모양 그리기
                self._draw_star(particle_surf, center, center, size, (*p['color'], alpha))
            else:  # sparkle
                # 작은 반짝임
                pygame.draw.circle(particle_surf, (*p['color'], alpha),
                                 (int(center), int(center)), size // 2)
                # 십자 빛
                pygame.draw.line(particle_surf, (*p['color'], alpha // 2),
                               (int(center - size), int(center)), (int(center + size), int(center)), 1)
                pygame.draw.line(particle_surf, (*p['color'], alpha // 2),
                               (int(center), int(center - size)), (int(center), int(center + size)), 1)

            # 회전 적용
            if p['rotation'] != 0:
                particle_surf = pygame.transform.rotate(particle_surf, math.degrees(p['rotation']))

            # 화면에 그리기
            rect = particle_surf.get_rect(center=(px, py))
            surface.blit(particle_surf, rect)

    def _draw_heart(self, surface: pygame.Surface, cx: float, cy: float, size: int, color: Tuple):
        """하트 모양 그리기"""
        # 하트 좌표 계산
        points = []
        for i in range(30):
            t = i / 30 * 2 * math.pi
            # 하트 방정식
            x = 16 * (math.sin(t) ** 3)
            y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
            # 스케일 조정
            x = cx + x * size / 20
            y = cy + y * size / 20
            points.append((x, y))

        if len(points) > 2:
            pygame.draw.polygon(surface, color, points)
            # 하이라이트
            highlight_color = (min(255, color[0] + 50), min(255, color[1] + 50), min(255, color[2] + 50), color[3] // 2)
            pygame.draw.circle(surface, highlight_color, (int(cx - size * 0.2), int(cy - size * 0.2)), size // 4)

    def _draw_star(self, surface: pygame.Surface, cx: float, cy: float, size: int, color: Tuple):
        """별 모양 그리기"""
        # 5각 별 좌표 계산
        points = []
        for i in range(10):
            # 외곽과 내곽 번갈아가며
            radius = size if i % 2 == 0 else size * 0.4
            angle = i * math.pi / 5 - math.pi / 2  # 위쪽부터 시작
            x = cx + math.cos(angle) * radius
            y = cy + math.sin(angle) * radius
            points.append((x, y))

        if len(points) > 2:
            pygame.draw.polygon(surface, color, points)
            # 중심 하이라이트
            highlight_color = (255, 255, 255, color[3] // 2)
            pygame.draw.circle(surface, highlight_color, (int(cx), int(cy)), size // 3)

    def _hsv_to_rgb(self, h: float, s: float, v: float) -> Tuple[int, int, int]:
        """HSV를 RGB로 변환"""
        h = h % 360
        c = v * s
        x = c * (1 - abs((h / 60) % 2 - 1))
        m = v - c

        if h < 60:
            r, g, b = c, x, 0
        elif h < 120:
            r, g, b = x, c, 0
        elif h < 180:
            r, g, b = 0, c, x
        elif h < 240:
            r, g, b = 0, x, c
        elif h < 300:
            r, g, b = x, 0, c
        else:
            r, g, b = c, 0, x

        return (int((r + m) * 255), int((g + m) * 255), int((b + m) * 255))
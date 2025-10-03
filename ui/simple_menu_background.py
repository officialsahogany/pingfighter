"""
심플하고 세련된 사이버펑크 메인 메뉴 배경
"""
import pygame
import math
import random
from typing import List, Tuple

class SimpleMenuBackground:
    """심플한 사이버펑크 스타일 배경 관리 클래스"""
    
    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.time = 0
        
        # 사이버펑크 색상 팔레트 (차분한 톤)
        self.colors = {
            'bg_top': (6, 10, 24),        # 상단 딥코스믹 네이비
            'bg_mid': (24, 12, 44),       # 중간층 자색 포그
            'bg_bottom': (10, 6, 28),     # 하단 미드나잇 퍼플
            'grid': (24, 70, 140, 28),    # 메인 라인
            'grid_soft': (14, 36, 90, 18),  # 서브 라인
            'neon_cyan': (180, 235, 255),
            'neon_purple': (200, 150, 255),
            'particle': (120, 200, 255, 70),
            'accent_gold': (255, 208, 150),
            'orbit': (120, 110, 220, 40),
            'orbit_alt': (255, 208, 150, 38)
        }

        # 프리렌더된 럭셔리 레이어
        self.gradient_surface = self._create_gradient_surface()
        self.vignette_surface = self._create_vignette_surface()
        self.grid_overlay = self._create_grid_overlay()
        self.nebula_layers = self._create_nebula_layers()
        self.star_layers = self._create_star_layers()
        self.light_columns = self._create_light_columns()
        self.glass_highlight_surface = self._create_glass_highlight_surface()
        self.frame_surface = self._create_frame_surface()
        self.particle_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)

        # 심플한 공전 행성들
        self.planets = self._create_planets()

        # 배경 파티클 (최소화)
        self.particles = []
        for _ in range(24):
            self.particles.append({
                'x': random.uniform(0, width),
                'y': random.uniform(0, height),
                'vx': random.uniform(-0.12, 0.12),
                'vy': random.uniform(-0.08, 0.08),
                'size': random.choice([1, 1, 2]),
                'alpha': random.randint(40, 110)
            })
    
    def _create_planets(self) -> List[dict]:
        """태양계 9개 행성을 리얼리스틱하게 생성"""
        center_x = self.width // 2
        center_y = self.height // 2
        
        planets = [
            # 태양 (중심) - 초대형 크기
            {
                'type': 'sun',
                'name': 'Sun',
                'x': center_x,
                'y': center_y,
                'radius': 100,  # 더 크게
                'color': (255, 100, 50),      # 붉은 태양
                'color2': (255, 80, 30),       # 진한 주황색
                'color3': (200, 50, 20),       # 어두운 붉은색
                'glow_color': (255, 120, 60),  # 붉은 글로우
                'orbit_radius': 0,
                'orbit_speed': 0,
                'orbit_angle': 0,
                'rotation': 0,
                'rotation_speed': 0.003,
                'pulse': True,
                'pulse_phase': 0,
                'surface_detail': [],
                'corona': [],  # 코로나 효과
                'flares': []   # 태양 플레어
            },
            # 수성 (Mercury) - 회색, 크레이터
            {
                'type': 'mercury',
                'name': 'Mercury',
                'radius': 24,  # 12 -> 24
                'color': (169, 169, 169),  # 회색
                'color2': (128, 128, 128),  # 크레이터
                'glow_color': (200, 200, 200),
                'orbit_radius': 120,
                'orbit_speed': 0.48,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.003,
                'trail': [],
                'craters': []
            },
            # 금성 (Venus) - 노란/주황색
            {
                'type': 'venus',
                'name': 'Venus',
                'radius': 36,  # 18 -> 36
                'color': (255, 198, 73),  # 황금색
                'color2': (255, 160, 60),  # 주황색 구름
                'glow_color': (255, 200, 100),
                'orbit_radius': 160,
                'orbit_speed': 0.35,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': -0.002,  # 역방향 자전
                'trail': [],
                'atmosphere': True
            },
            # 지구 (Earth) - 파랑/녹색
            {
                'type': 'earth',
                'name': 'Earth',
                'radius': 40,  # 20 -> 40
                'color': (70, 130, 180),  # 바다색
                'color2': (34, 139, 34),  # 대륙색
                'glow_color': (150, 200, 255),
                'orbit_radius': 210,
                'orbit_speed': 0.3,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.02,
                'trail': [],
                'clouds': []
            },
            # 화성 (Mars) - 붉은색
            {
                'type': 'mars',
                'name': 'Mars',
                'radius': 30,  # 15 -> 30
                'color': (193, 68, 14),  # 화성 붉은색
                'color2': (150, 50, 10),  # 어두운 부분
                'glow_color': (255, 150, 100),
                'orbit_radius': 260,
                'orbit_speed': 0.24,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.018,
                'trail': [],
                'polar_caps': True
            },
            # 목성 (Jupiter) - 줄무늬와 대적점
            {
                'type': 'jupiter',
                'name': 'Jupiter',
                'radius': 70,  # 35 -> 70
                'color': (209, 182, 135),  # 목성 베이지
                'color2': (165, 124, 82),  # 줄무늬
                'glow_color': (220, 200, 160),
                'orbit_radius': 340,
                'orbit_speed': 0.13,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.045,  # 빠른 자전
                'trail': [],
                'bands': [],
                'red_spot': {'angle': 0, 'size': 16}  # 8 -> 16
            },
            # 토성 (Saturn) - 고리가 있는 행성
            {
                'type': 'saturn',
                'name': 'Saturn',
                'radius': 60,  # 30 -> 60
                'color': (250, 228, 190),  # 연한 황금색
                'color2': (220, 200, 150),  # 띠
                'glow_color': (255, 240, 200),
                'orbit_radius': 420,
                'orbit_speed': 0.097,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.04,
                'trail': [],
                'rings': {
                    'inner_radius': 70,  # 35 -> 70
                    'outer_radius': 100,  # 50 -> 100
                    'color': (220, 200, 170, 100),
                    'rotation': 0,  # 고리 회전 각도
                    'rotation_speed': 0.01  # 고리 회전 속도
                }
            },
            # 천왕성 (Uranus) - 청록색
            {
                'type': 'uranus',
                'name': 'Uranus',
                'radius': 44,  # 22 -> 44
                'color': (100, 200, 220),  # 청록색
                'color2': (80, 180, 200),
                'glow_color': (150, 220, 240),
                'orbit_radius': 480,
                'orbit_speed': 0.069,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': -0.015,  # 역방향 자전
                'trail': [],
                'tilt': True  # 기울어진 자전축
            },
            # 해왕성 (Neptune) - 진한 파랑
            {
                'type': 'neptune',
                'name': 'Neptune',
                'radius': 42,  # 21 -> 42
                'color': (60, 100, 200),  # 진한 파랑
                'color2': (40, 80, 180),
                'glow_color': (100, 150, 255),
                'orbit_radius': 530,
                'orbit_speed': 0.054,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.016,
                'trail': [],
                'storms': []
            },
            # 명왕성 (Pluto) - 작고 갈색
            {
                'type': 'pluto',
                'name': 'Pluto',
                'radius': 16,  # 8 -> 16
                'color': (188, 143, 143),  # 연한 갈색
                'color2': (160, 120, 120),
                'glow_color': (200, 160, 160),
                'orbit_radius': 570,
                'orbit_speed': 0.047,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.003,
                'trail': []
            }
        ]
        
        # 행성별 특수 효과 초기화
        for planet in planets:
            if planet['type'] == 'sun':
                # 태양 코로나와 플레어 초기화
                for _ in range(12):
                    planet['corona'].append({
                        'angle': random.uniform(0, math.pi * 2),
                        'length': random.uniform(1.3, 2.0),
                        'width': random.uniform(0.08, 0.2),
                        'speed': random.uniform(0.01, 0.04)
                    })
                for _ in range(8):
                    planet['flares'].append({
                        'angle': random.uniform(0, math.pi * 2),
                        'strength': random.uniform(0.6, 1.0),
                        'phase': random.uniform(0, math.pi * 2)
                    })
            elif planet['type'] == 'mercury':
                # 수성 크레이터
                for _ in range(10):
                    planet['craters'].append({
                        'angle': random.uniform(0, math.pi * 2),
                        'distance': random.uniform(0.2, 0.8),
                        'size': random.uniform(0.1, 0.3)
                    })
            elif planet['type'] == 'earth':
                # 지구 구름
                for _ in range(8):
                    planet['clouds'].append({
                        'angle': random.uniform(0, math.pi * 2),
                        'lat': random.uniform(-0.5, 0.5),
                        'size': random.uniform(0.15, 0.35),
                        'opacity': random.uniform(0.4, 0.8)
                    })
            elif planet['type'] == 'saturn':
                # 토성 고리 파티클 추가
                planet['ring_particles'] = []
                for _ in range(50):
                    planet['ring_particles'].append({
                        'angle': random.uniform(0, math.pi * 2),
                        'radius': random.uniform(planet['rings']['inner_radius'], planet['rings']['outer_radius']),
                        'speed': random.uniform(0.005, 0.02),
                        'size': random.uniform(1, 3),
                        'brightness': random.uniform(0.5, 1.0)
                    })
            elif planet['type'] == 'jupiter':
                # 목성 줄무늬 패턴과 고리 추가
                planet['faint_rings'] = {
                    'radius': planet['radius'] * 1.4,
                    'width': 3,
                    'rotation': 0,
                    'rotation_speed': 0.015,
                    'color': (150, 120, 100, 40)
                }
                for i in range(12):
                    planet['bands'].append({
                        'y_offset': -0.9 + i * 0.15,
                        'color_shift': random.uniform(-40, 40)
                    })
            elif planet['type'] == 'neptune':
                # 해왕성 폭풍
                for _ in range(3):
                    planet['storms'].append({
                        'angle': random.uniform(0, math.pi * 2),
                        'size': random.uniform(0.2, 0.35)
                    })
        
        return planets

    def _create_gradient_surface(self) -> pygame.Surface:
        """천천히 번지는 트라이톤 그라데이션을 프리렌더"""
        surface = pygame.Surface((self.width, self.height))
        mid_y = max(1, int(self.height * 0.55))
        bottom_span = max(1, self.height - mid_y)

        for y in range(self.height):
            if y <= mid_y:
                ratio = y / mid_y
                r = int(self.colors['bg_top'][0] + (self.colors['bg_mid'][0] - self.colors['bg_top'][0]) * ratio)
                g = int(self.colors['bg_top'][1] + (self.colors['bg_mid'][1] - self.colors['bg_top'][1]) * ratio)
                b = int(self.colors['bg_top'][2] + (self.colors['bg_mid'][2] - self.colors['bg_top'][2]) * ratio)
            else:
                ratio = (y - mid_y) / bottom_span
                r = int(self.colors['bg_mid'][0] + (self.colors['bg_bottom'][0] - self.colors['bg_mid'][0]) * ratio)
                g = int(self.colors['bg_mid'][1] + (self.colors['bg_bottom'][1] - self.colors['bg_mid'][1]) * ratio)
                b = int(self.colors['bg_mid'][2] + (self.colors['bg_bottom'][2] - self.colors['bg_mid'][2]) * ratio)
            pygame.draw.line(surface, (r, g, b), (0, y), (self.width, y))

        return surface

    def _create_vignette_surface(self) -> pygame.Surface:
        """화면 외곽을 다크 퍼플로 감싸는 비네팅"""
        vignette = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        steps = 12
        for i in range(steps):
            padding_x = int(self.width * 0.04 * i)
            padding_y = int(self.height * 0.05 * i)
            rect = pygame.Rect(padding_x, padding_y, self.width - padding_x * 2, self.height - padding_y * 2)
            if rect.width <= 0 or rect.height <= 0:
                break
            alpha = min(200, 22 + i * 14)
            pygame.draw.rect(vignette, (8, 8, 18, alpha), rect, border_radius=max(12, 44 - i * 2))
        return vignette

    def _create_grid_overlay(self) -> pygame.Surface:
        """고급스러운 네온 라인 격자"""
        grid = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        spacing = 48
        primary = self.colors['grid']
        secondary = self.colors['grid_soft']

        for x in range(0, self.width, spacing):
            alpha = primary[3] + (8 if (x // spacing) % 3 == 0 else 0)
            pygame.draw.line(
                grid,
                (primary[0], primary[1], primary[2], min(255, alpha)),
                (x, 0),
                (x, self.height),
            )

        for y in range(0, self.height, spacing):
            alpha = secondary[3] + (6 if (y // spacing) % 2 == 0 else 0)
            pygame.draw.line(
                grid,
                (secondary[0], secondary[1], secondary[2], min(255, alpha)),
                (0, y),
                (self.width, y),
            )

        # 사선 포물선 느낌의 얇은 라인으로 파라락스 착시 부여
        for offset in range(-self.width, self.width, spacing * 3):
            start = (offset, self.height)
            end = (offset + self.height, 0)
            pygame.draw.line(grid, (90, 140, 220, 22), start, end, width=1)

        return grid

    def _draw_soft_circle(
        self,
        target: pygame.Surface,
        color: Tuple[int, int, int, int],
        center: Tuple[int, int],
        radius: int,
        *,
        falloff: float = 1.8,
        step: int = 6,
    ) -> None:
        """알파가 자연스럽게 감쇠하는 원형 하이라이트"""
        if radius <= 0:
            return
        step = max(1, step)
        circle_surface = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
        for r in range(radius, 0, -step):
            ratio = r / radius
            alpha = int(color[3] * (ratio ** falloff))
            if alpha <= 0:
                continue
            pygame.draw.circle(
                circle_surface,
                (color[0], color[1], color[2], alpha),
                (radius, radius),
                r,
            )
        target.blit(circle_surface, (center[0] - radius, center[1] - radius), special_flags=pygame.BLEND_ADD)

    def _create_nebula_layers(self) -> List[dict]:
        """고급 성운 두 겹"""
        layers: List[dict] = []
        base_width = max(self.width, int(self.width * 1.35))
        base_height = max(int(self.height * 0.7), 260)
        palettes = [
            [
                (120, 70, 200, 28),
                (70, 120, 255, 20),
                (255, 120, 200, 18),
                (60, 205, 220, 16),
            ],
            [
                (255, 190, 140, 18),
                (140, 200, 255, 20),
                (180, 120, 255, 22),
                (255, 120, 170, 16),
            ],
        ]

        for idx, palette in enumerate(palettes):
            nebula = pygame.Surface((base_width, base_height), pygame.SRCALPHA)
            for _ in range(70):
                color = random.choice(palette)
                radius = random.randint(int(base_width * 0.08), int(base_width * 0.15))
                pos = (
                    random.randint(radius, base_width - radius),
                    random.randint(radius, base_height - radius),
                )
                self._draw_soft_circle(nebula, color, pos, radius, falloff=1.95, step=6)

            base_x = -base_width // 4 if idx == 0 else self.width - int(base_width * 0.75)
            base_y = -base_height // 6 if idx == 0 else int(self.height * 0.08)
            layers.append(
                {
                    'surface': nebula,
                    'base_x': base_x,
                    'base_y': base_y,
                    'phase': random.uniform(0, math.pi * 2),
                    'speed': random.uniform(0.25, 0.45),
                    'amplitude': random.uniform(14, 24),
                }
            )

        return layers

    def _create_star_layers(self) -> List[dict]:
        """패럴럭스가 적용된 스타필드"""
        layers: List[dict] = []
        base_density = max(40, (self.width * self.height) // 11000)
        layer_specs = [
            {'count': int(base_density * 1.1), 'speed': 12.0, 'color': (185, 225, 255)},
            {'count': int(base_density * 0.7), 'speed': 20.0, 'color': (160, 200, 255)},
            {'count': max(20, int(base_density * 0.45)), 'speed': 32.0, 'color': (255, 215, 175)},
        ]

        for spec in layer_specs:
            layer_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            stars = []
            for _ in range(spec['count']):
                stars.append(
                    {
                        'x': random.uniform(0, self.width),
                        'y': random.uniform(0, self.height),
                        'size': random.choice([1, 1, 2]),
                        'alpha': random.randint(120, 220),
                        'twinkle': random.uniform(0, math.pi * 2),
                        'twinkle_speed': random.uniform(0.8, 1.6),
                        'parallax': random.uniform(0.6, 1.4),
                        'vy': random.uniform(-4.0, 4.0),
                    }
                )

            layers.append(
                {
                    'surface': layer_surface,
                    'stars': stars,
                    'speed': spec['speed'],
                    'color': spec['color'],
                }
            )

        return layers

    def _create_light_columns(self) -> List[dict]:
        """은은한 라이트 필라 3겹"""
        columns: List[dict] = []
        specs = [
            {'x_ratio': 0.22, 'width_ratio': 0.18, 'color': (130, 180, 255), 'speed': 0.6, 'amplitude': self.width * 0.02},
            {'x_ratio': 0.5, 'width_ratio': 0.24, 'color': (255, 210, 170), 'speed': 0.45, 'amplitude': self.width * 0.018},
            {'x_ratio': 0.78, 'width_ratio': 0.16, 'color': (140, 220, 255), 'speed': 0.72, 'amplitude': self.width * 0.02},
        ]

        for spec in specs:
            width = max(48, int(self.width * spec['width_ratio']))
            column_surface = pygame.Surface((width, self.height), pygame.SRCALPHA)
            for y in range(self.height):
                vertical_ratio = 1.0 - abs((y / max(1, self.height)) - 0.35) * 1.9
                vertical_ratio = max(0.0, vertical_ratio)
                alpha = int(120 * (vertical_ratio ** 1.8))
                if alpha <= 0:
                    continue
                pygame.draw.line(
                    column_surface,
                    (spec['color'][0], spec['color'][1], spec['color'][2], alpha),
                    (0, y),
                    (width, y),
                )

            horizontal_mask = pygame.Surface((width, 1), pygame.SRCALPHA)
            for x in range(width):
                horizontal_ratio = 1.0 - abs((x / max(1, width)) - 0.5) * 1.9
                horizontal_ratio = max(0.0, horizontal_ratio)
                alpha = int(255 * (horizontal_ratio ** 1.8))
                horizontal_mask.set_at((x, 0), (255, 255, 255, max(0, min(255, alpha))))
            horizontal_mask = pygame.transform.smoothscale(horizontal_mask, (width, self.height))
            column_surface.blit(horizontal_mask, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)

            columns.append(
                {
                    'surface': column_surface,
                    'base_x': int(self.width * spec['x_ratio']),
                    'phase': random.uniform(0, math.pi * 2),
                    'speed': spec['speed'],
                    'amplitude': spec['amplitude'],
                }
            )

        return columns

    def _create_glass_highlight_surface(self) -> pygame.Surface:
        """메인 로고 영역을 강조하는 글라스 하이라이트"""
        height = max(80, int(self.height * 0.38))
        highlight = pygame.Surface((self.width, height), pygame.SRCALPHA)
        for y in range(height):
            ratio = y / max(1, height)
            alpha = int(90 * max(0.0, 1.0 - ratio ** 1.6))
            color = (255, 255, 255, alpha)
            pygame.draw.line(highlight, color, (0, y), (self.width, y))

        ellipse_mask = pygame.Surface((self.width, height), pygame.SRCALPHA)
        pygame.draw.ellipse(
            ellipse_mask,
            (255, 255, 255, 220),
            (-int(self.width * 0.12), -height // 2, int(self.width * 1.24), height * 2),
        )
        highlight.blit(ellipse_mask, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
        return highlight

    def _create_frame_surface(self) -> pygame.Surface:
        """가느다란 금속 프레임"""
        frame = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        outer_rect = frame.get_rect()
        pygame.draw.rect(frame, (255, 220, 180, 36), outer_rect, width=2, border_radius=42)
        inner_rect = outer_rect.inflate(-26, -26)
        if inner_rect.width > 0 and inner_rect.height > 0:
            pygame.draw.rect(frame, (120, 200, 255, 20), inner_rect, width=1, border_radius=30)
        return frame
    
    def update(self, dt: float):
        """배경 업데이트"""

        self.time += dt

        # 럭셔리 배경 레이어 애니메이션
        for nebula in self.nebula_layers:
            nebula['phase'] += nebula['speed'] * dt

        for column in self.light_columns:
            column['phase'] += column['speed'] * dt

        for layer in self.star_layers:
            for star in layer['stars']:
                star['x'] -= layer['speed'] * star['parallax'] * dt
                star['y'] += star['vy'] * dt * 0.1

                if star['x'] < -5:
                    star['x'] = self.width + random.uniform(0, self.width * 0.15)
                    star['y'] = random.uniform(0, self.height)
                elif star['x'] > self.width + 5:
                    star['x'] = -random.uniform(0, self.width * 0.15)
                    star['y'] = random.uniform(0, self.height)

                if star['y'] < -5:
                    star['y'] = self.height + random.uniform(0, 10)
                elif star['y'] > self.height + 5:
                    star['y'] = -random.uniform(0, 10)

                star['twinkle'] += star['twinkle_speed'] * dt * 1.6

# 행성 공전 업데이트
        center_x = self.width // 2
        center_y = self.height // 2
        
        for planet in self.planets:
            # 자전 업데이트 (모든 행성)
            planet['rotation'] += planet.get('rotation_speed', 0.01) * 60 * dt
            
            if planet['type'] == 'sun':
                # 태양 펄스 효과 (미세하게)
                if planet['pulse']:
                    planet['current_radius'] = planet['radius'] + math.sin(self.time * 2) * 3
            else:
                # 행성 공전
                planet['orbit_angle'] += planet['orbit_speed'] * dt
                planet['x'] = center_x + math.cos(planet['orbit_angle']) * planet['orbit_radius']
                planet['y'] = center_y + math.sin(planet['orbit_angle']) * planet['orbit_radius'] * 0.5
                
                # 궤적 추가 (짧게)
                if len(planet['trail']) > 15:
                    planet['trail'].pop(0)
                planet['trail'].append((planet['x'], planet['y']))
                
                # 특수 효과 업데이트
                if planet['type'] == 'jupiter' and 'red_spot' in planet:
                    planet['red_spot']['angle'] += 0.01  # 대적점 회전
                elif planet['type'] == 'earth' and 'clouds' in planet:
                    for cloud in planet['clouds']:
                        cloud['angle'] += 0.005  # 구름 이동
                elif planet['type'] == 'saturn' and 'rings' in planet:
                    # 토성 고리 회전 애니메이션
                    planet['rings']['rotation'] += planet['rings']['rotation_speed'] * 60 * dt
                    # 고리 파티클 업데이트
                    if 'ring_particles' in planet:
                        for particle in planet['ring_particles']:
                            particle['angle'] += particle['speed']
                            particle['brightness'] = 0.5 + math.sin(self.time * 2 + particle['angle']) * 0.5
                elif planet['type'] == 'jupiter' and 'faint_rings' in planet:
                    # 목성 희미한 고리 회전
                    planet['faint_rings']['rotation'] += planet['faint_rings']['rotation_speed'] * 60 * dt
        
        # 파티클 업데이트
        for particle in self.particles:
            particle['x'] += particle['vx'] * dt * 60
            particle['y'] += particle['vy'] * dt * 60
            
            if particle['x'] < 0:
                particle['x'] = self.width
            elif particle['x'] > self.width:
                particle['x'] = 0
            if particle['y'] < 0:
                particle['y'] = self.height
            elif particle['y'] > self.height:
                particle['y'] = 0
    
    def draw(self, surface: pygame.Surface):
        """배경 그리기"""
        

# 1. 프리렌더 코스믹 그라데이션
surface.blit(self.gradient_surface, (0, 0))

# 2. 성운과 라이트 필라
for nebula in self.nebula_layers:
    sway = math.sin(nebula['phase']) * nebula['amplitude']
    offset_x = int(nebula['base_x'] + sway)
    offset_y = int(nebula['base_y'] + sway * 0.25)
    surface.blit(nebula['surface'], (offset_x, offset_y), special_flags=pygame.BLEND_ADD)

for column in self.light_columns:
    offset = math.sin(column['phase']) * column['amplitude']
    x_pos = int(column['base_x'] + offset - column['surface'].get_width() // 2)
    surface.blit(column['surface'], (x_pos, 0), special_flags=pygame.BLEND_ADD)

# 3. 스타필드 패럴럭스
for layer in self.star_layers:
    layer_surface = layer['surface']
    layer_surface.fill((0, 0, 0, 0))
    for star in layer['stars']:
        twinkle = 0.6 + 0.4 * math.sin(star['twinkle'])
        alpha = max(0, min(255, int(star['alpha'] * twinkle)))
        if alpha <= 0:
            continue
        pygame.draw.circle(
            layer_surface,
            (layer['color'][0], layer['color'][1], layer['color'][2], alpha),
            (int(star['x']), int(star['y'])),
            star['size'],
        )
    surface.blit(layer_surface, (0, 0), special_flags=pygame.BLEND_ADD)

# 4. 글래스 하이라이트와 격자
surface.blit(self.grid_overlay, (0, 0), special_flags=pygame.BLEND_ADD)
surface.blit(self.glass_highlight_surface, (0, int(self.height * 0.08)), special_flags=pygame.BLEND_ADD)

# 5. 부유 파티클 글로우
self.particle_surface.fill((0, 0, 0, 0))
for particle in self.particles:
    twinkle = 0.5 + 0.5 * math.sin(self.time * 0.002 + particle['x'] * 0.01 + particle['y'] * 0.01)
    alpha = max(10, min(180, int(particle['alpha'] * twinkle)))
    pygame.draw.circle(
        self.particle_surface,
        (self.colors['particle'][0], self.colors['particle'][1], self.colors['particle'][2], alpha),
        (int(particle['x']), int(particle['y'])),
        particle['size'],
    )
surface.blit(self.particle_surface, (0, 0), special_flags=pygame.BLEND_ADD)

# 6. 비네팅
surface.blit(self.vignette_surface, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)

        # 7. 궤도 그리기
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
                color = self.colors['orbit'] if (planet['orbit_radius'] // 60) % 2 == 0 else self.colors['orbit_alt']
                pygame.draw.ellipse(orbit_surface, color, orbit_rect, 1)
        
        surface.blit(orbit_surface, (0, 0))
        
        # 8. 행성 그리기
        sorted_planets = sorted(self.planets, key=lambda p: p.get('y', center_y))
        
        for planet in sorted_planets:
            x, y = planet.get('x', center_x), planet.get('y', center_y)
            
            if planet['type'] == 'sun':
                # 태양 - 더 화려하게
                radius = planet.get('current_radius', planet['radius'])
                
                # 다층 글로우 효과
                for i in range(3):
                    glow_radius = radius + 15 + i * 10
                    glow_alpha = 40 - i * 10
                    glow_surf = pygame.Surface((int(glow_radius * 2), int(glow_radius * 2)), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surf, (*planet['glow_color'], glow_alpha),
                                     (glow_radius, glow_radius), glow_radius)
                    surface.blit(glow_surf, (int(x - glow_radius), int(y - glow_radius)))
                
                # 초고급 태양 렌더링 (여러 레이어)
                # 1. 외부 코로나 레이어
                for layer in range(3):
                    corona_radius = radius + 30 + layer * 15
                    corona_alpha = 15 - layer * 4
                    corona_surf = pygame.Surface((int(corona_radius * 2.2), int(corona_radius * 2.2)), pygame.SRCALPHA)
                    for i in range(int(corona_radius)):
                        ratio = i / corona_radius
                        alpha = int(corona_alpha * (1 - ratio ** 1.5))
                        if alpha > 0:
                            # 코로나 색상 - 붉은 타오르는 효과
                            hue_shift = math.sin(self.time * 2 + layer) * 30
                            r = min(255, 255)
                            g = min(255, 100 + hue_shift)
                            b = min(255, 30 + hue_shift * 0.3)
                            pygame.draw.circle(corona_surf, (r, g, b, alpha),
                                             (int(corona_radius * 1.1), int(corona_radius * 1.1)), corona_radius - i)
                    surface.blit(corona_surf, (int(x - corona_radius * 1.1), int(y - corona_radius * 1.1)))
                
                # 2. 태양 본체 (다층 그라데이션)
                for i in range(int(radius)):
                    ratio = i / radius
                    # 복잡한 그라데이션 패턴 - 붉은 태양
                    brightness = 1.0 - (ratio ** 2.5) * 0.6
                    # 색온도 변화 - 중심은 백색, 가장자리는 진한 붉은색
                    temp_shift = math.sin(ratio * math.pi * 2) * 0.15
                    # 중심부에서 백색에 가깝게
                    core_white = 1.0 - ratio * 0.7
                    r = int(255 * brightness)
                    g = int((255 * core_white + 100 * (1 - core_white)) * brightness * (0.8 + temp_shift))
                    b = int((255 * core_white + 50 * (1 - core_white)) * brightness * (0.4 + temp_shift * 0.5))
                    pygame.draw.circle(surface, (min(255, r), min(255, g), min(255, b)), 
                                     (int(x), int(y)), radius - i)
                
                # 3. 태양 표면 디테일 (플라즈마 패턴)
                for i in range(8):
                    plasma_angle = planet['rotation'] + i * 0.785  # 45도씩
                    plasma_dist = radius * 0.7
                    plasma_x = x + math.cos(plasma_angle) * plasma_dist * math.sin(self.time * 3 + i)
                    plasma_y = y + math.sin(plasma_angle) * plasma_dist * 0.6
                    plasma_size = int(radius * 0.15 * (1 + math.sin(self.time * 4 + i) * 0.3))
                    # 플라즈마 색상 - 붉은 타오르는 효과
                    plasma_intensity = 1.0 + math.sin(self.time * 5 + i * 2) * 0.3
                    plasma_color = (
                        min(255, int(255 * plasma_intensity)),
                        min(255, int(120 * plasma_intensity)),
                        min(255, int(60 * plasma_intensity))
                    )
                    # 플라즈마 그라데이션
                    for p in range(plasma_size):
                        p_ratio = p / plasma_size if plasma_size > 0 else 0
                        p_alpha = 1.0 - p_ratio
                        p_color = tuple(int(c * p_alpha) for c in plasma_color)
                        pygame.draw.circle(surface, p_color, (int(plasma_x), int(plasma_y)), plasma_size - p)
                
                # 4. 태양 플레어 (동적 효과)
                for i in range(3):
                    flare_angle = self.time * 0.5 + i * 2.1
                    flare_length = radius * (1.5 + math.sin(self.time * 2 + i) * 0.3)
                    flare_start_x = x + math.cos(flare_angle) * radius * 0.9
                    flare_start_y = y + math.sin(flare_angle) * radius * 0.9
                    flare_end_x = x + math.cos(flare_angle) * flare_length
                    flare_end_y = y + math.sin(flare_angle) * flare_length
                    
                    # 플레어 그라데이션
                    for j in range(5):
                        alpha = 80 - j * 15
                        width = 5 - j
                        if width > 0 and alpha > 0:
                            flare_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
                            pygame.draw.line(flare_surf, (255, 150, 80, alpha),
                                           (int(flare_start_x), int(flare_start_y)),
                                           (int(flare_end_x), int(flare_end_y)), width)
                            surface.blit(flare_surf, (0, 0))
                
                # 태양 흑점
                for i in range(3):
                    spot_angle = planet['rotation'] + i * 2.1
                    spot_x = x + math.cos(spot_angle) * radius * 0.5
                    spot_y = y + math.sin(spot_angle) * radius * 0.3
                    pygame.draw.circle(surface, (180, 140, 50), 
                                     (int(spot_x), int(spot_y)), 3)
            
            elif planet['type'] == 'earth':
                # 지구형 행성
                radius = planet['radius']
                
                # 대기 글로우
                glow_radius = radius + 8
                glow_surf = pygame.Surface((int(glow_radius * 2), int(glow_radius * 2)), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*planet['glow_color'], 25),
                                 (glow_radius, glow_radius), glow_radius)
                surface.blit(glow_surf, (int(x - glow_radius), int(y - glow_radius)))
                
                # 초고급 지구 렌더링
                # 1. 대기층 (여러 겹)
                for atmo in range(3):
                    atmo_radius = radius + 5 + atmo * 3
                    atmo_alpha = 35 - atmo * 10
                    atmo_surf = pygame.Surface((int(atmo_radius * 2.2), int(atmo_radius * 2.2)), pygame.SRCALPHA)
                    for i in range(int(atmo_radius)):
                        ratio = i / atmo_radius
                        alpha = int(atmo_alpha * (1 - ratio ** 2))
                        if alpha > 0:
                            # 대기 산란 효과 (파란빛)
                            pygame.draw.circle(atmo_surf, (150, 200, 255, alpha),
                                             (int(atmo_radius * 1.1), int(atmo_radius * 1.1)), atmo_radius - i)
                    surface.blit(atmo_surf, (int(x - atmo_radius * 1.1), int(y - atmo_radius * 1.1)))
                
                # 2. 행성 본체 (고급 쉐이딩)
                for i in range(int(radius)):
                    ratio = i / radius
                    # 프레넬 효과를 적용한 리얼한 구체 쉐이딩
                    brightness = math.sqrt(1.0 - ratio ** 2) if ratio < 1 else 0
                    # 대기 산란 색상 혼합
                    edge_blue = ratio ** 3 * 0.3  # 가장자리는 더 파랗게
                    r = int(planet['color'][0] * brightness * (1 - edge_blue * 0.5))
                    g = int(planet['color'][1] * brightness * (1 - edge_blue * 0.3))
                    b = int(planet['color'][2] * brightness * (1 + edge_blue))
                    pygame.draw.circle(surface, (min(255, r), min(255, g), min(255, b)), (int(x), int(y)), radius - i)
                
                # 3. 대륙 (리얼한 지형)
                for i in range(5):  # 더 많은 대륙
                    continent_angle = planet['rotation'] + i * 1.256  # 황금비
                    # 3D 구면 좌표 변환
                    lat = math.sin(continent_angle * 2) * 0.7
                    lon = continent_angle
                    
                    # 구면에서의 실제 위치 계산
                    visible = math.cos(lon) > -0.3  # 보이는 면 확인
                    if visible:
                        continent_x = x + math.cos(lon) * radius * 0.7 * math.cos(lat)
                        continent_y = y + math.sin(lat) * radius * 0.5
                        
                        # 거리에 따른 크기 조절 (원근감)
                        depth_scale = (math.cos(lon) + 1) * 0.5
                        continent_size = int(radius * 0.4 * depth_scale)
                        
                        if continent_size > 2:
                            # 대륙 그라데이션
                            for j in range(continent_size // 2):
                                ratio = j / (continent_size // 2)
                                brightness = 1 - ratio * 0.3
                                cont_color = tuple(int(c * brightness) for c in planet['color2'])
                                pygame.draw.ellipse(surface, cont_color,
                                                  (int(continent_x - continent_size/2 + j), 
                                                   int(continent_y - continent_size/3 + j/2),
                                                   continent_size - j*2, int((continent_size - j*2) * 0.6)))
                
                # 4. 구름층 (리얼한 구름)
                if 'clouds' in planet:
                    cloud_surf = pygame.Surface((int(radius * 2.5), int(radius * 2.5)), pygame.SRCALPHA)
                    for cloud in planet['clouds']:
                        cloud_angle = planet['rotation'] * 1.2 + cloud['angle']
                        # 구름도 3D 구면 좌표
                        if math.cos(cloud_angle) > -0.2:
                            cloud_x = radius * 1.25 + math.cos(cloud_angle) * radius * 0.9
                            cloud_y = radius * 1.25 + math.sin(cloud_angle) * radius * cloud['lat'] * 0.7
                            
                            # 구름 레이어 (부드러운 효과)
                            for layer in range(3):
                                cloud_size = int(radius * cloud['size'] * (1.5 - layer * 0.3))
                                cloud_alpha = int(cloud['opacity'] * 80 * (1 - layer * 0.3))
                                if cloud_size > 0 and cloud_alpha > 0:
                                    pygame.draw.ellipse(cloud_surf, (255, 255, 255, cloud_alpha),
                                                      (int(cloud_x - cloud_size), int(cloud_y - cloud_size/2),
                                                       cloud_size * 2, cloud_size))
                    surface.blit(cloud_surf, (int(x - radius * 1.25), int(y - radius * 1.25)))
                
                # 5. 도시 불빛 (밤 부분)
                night_angle = planet['rotation'] + math.pi
                if math.cos(night_angle) > 0.3:  # 밤인 부분
                    for i in range(8):
                        city_angle = night_angle + random.uniform(-0.5, 0.5)
                        city_x = x + math.cos(city_angle) * radius * 0.6
                        city_y = y + math.sin(city_angle) * radius * random.uniform(-0.3, 0.3)
                        # 도시 불빛 (노란빛)
                        city_glow = pygame.Surface((10, 10), pygame.SRCALPHA)
                        pygame.draw.circle(city_glow, (255, 230, 150, 40), (5, 5), 3)
                        surface.blit(city_glow, (int(city_x - 5), int(city_y - 5)))
                
                # 6. 스페큘러 하이라이트 (태양 반사)
                # 여러 레이어로 부드러운 반사광
                for i in range(5):
                    h_radius = radius // (2.5 + i * 0.5)
                    h_alpha = 70 - i * 12
                    h_offset = radius // 2.8 - i * 2
                    if h_alpha > 0 and h_radius > 0:
                        highlight_surf = pygame.Surface((int(h_radius * 3), int(h_radius * 3)), pygame.SRCALPHA)
                        # 그라데이션 하이라이트
                        for j in range(int(h_radius)):
                            ratio = j / h_radius
                            alpha = int(h_alpha * (1 - ratio ** 1.5))
                            if alpha > 0:
                                pygame.draw.circle(highlight_surf, (255, 255, 255, alpha),
                                                 (int(h_radius * 1.5), int(h_radius * 1.5)), h_radius - j)
                        surface.blit(highlight_surf, (int(x - h_offset - h_radius * 1.5), 
                                                     int(y - h_offset - h_radius * 1.5)))
            
            elif planet['type'] == 'mars':
                # 화성형 행성
                radius = planet['radius']
                
                # 은은한 글로우
                glow_radius = radius + 6
                glow_surf = pygame.Surface((int(glow_radius * 2), int(glow_radius * 2)), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*planet['glow_color'], 20),
                                 (glow_radius, glow_radius), glow_radius)
                surface.blit(glow_surf, (int(x - glow_radius), int(y - glow_radius)))
                
                # 행성 본체 (고급 3D 그라데이션)
                for i in range(int(radius)):
                    ratio = i / radius
                    brightness = 1.0 - (ratio ** 2) * 0.45
                    r = int(planet['color'][0] * brightness)
                    g = int(planet['color'][1] * brightness)
                    b = int(planet['color'][2] * brightness)
                    pygame.draw.circle(surface, (r, g, b), (int(x), int(y)), radius - i)
                
                # 표면 무늬 (자전 효과)
                for i in range(5):
                    pattern_angle = planet['rotation'] + i * 1.2
                    pattern_x = x + math.cos(pattern_angle) * radius * 0.5
                    pattern_y = y + math.sin(pattern_angle) * radius * 0.3
                    pygame.draw.circle(surface, planet['color2'], 
                                     (int(pattern_x), int(pattern_y)), radius // 5)
                
                # 극관 (흰색)
                if planet.get('polar_caps'):
                    # 북극
                    pygame.draw.ellipse(surface, (240, 240, 240),
                                      (int(x - radius * 0.3), int(y - radius),
                                       int(radius * 0.6), int(radius * 0.3)))
                    # 남극
                    pygame.draw.ellipse(surface, (240, 240, 240),
                                      (int(x - radius * 0.3), int(y + radius * 0.7),
                                       int(radius * 0.6), int(radius * 0.3)))
                
                # 고급 3D 하이라이트
                for i in range(3):
                    h_radius = radius // (3 + i)
                    h_alpha = 35 - i * 10
                    h_offset = radius // 3 - i * 2
                    pygame.draw.circle(surface, (255, 200, 150, h_alpha),
                                     (int(x - h_offset), int(y - h_offset)),
                                     h_radius)
            
            elif planet['type'] == 'mercury':
                # 수성 (회색, 크레이터)
                radius = planet['radius']
                
                # 행성 본체 (고급 3D 그라데이션)
                for i in range(int(radius)):
                    ratio = i / radius
                    brightness = 1.0 - (ratio ** 2) * 0.45
                    r = int(planet['color'][0] * brightness)
                    g = int(planet['color'][1] * brightness)
                    b = int(planet['color'][2] * brightness)
                    pygame.draw.circle(surface, (r, g, b), (int(x), int(y)), radius - i)
                
                # 크레이터 (자전 효과)
                if 'craters' in planet:
                    for crater in planet['craters']:
                        crater_angle = planet['rotation'] + crater['angle']
                        if math.cos(crater_angle) > 0:  # 보이는 면에만
                            crater_x = x + math.cos(crater_angle) * radius * crater['distance']
                            crater_y = y + math.sin(crater_angle) * radius * crater['distance'] * 0.5
                            crater_size = int(radius * crater['size'])
                            pygame.draw.circle(surface, planet['color2'], 
                                             (int(crater_x), int(crater_y)), crater_size)
                
                # 고급 3D 하이라이트
                for i in range(2):
                    h_radius = radius // (4 + i)
                    h_alpha = 30 - i * 10
                    h_offset = radius // 3 - i * 2
                    pygame.draw.circle(surface, (220, 220, 220, h_alpha),
                                     (int(x - h_offset), int(y - h_offset)),
                                     h_radius)
            
            elif planet['type'] == 'venus':
                # 금성 (황금색, 두꺼운 대기)
                radius = planet['radius']
                
                # 두꺼운 대기 글로우
                for i in range(3):
                    glow_radius = radius + 5 + i * 3
                    glow_alpha = 30 - i * 8
                    glow_surf = pygame.Surface((int(glow_radius * 2), int(glow_radius * 2)), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surf, (*planet['glow_color'], glow_alpha),
                                     (glow_radius, glow_radius), glow_radius)
                    surface.blit(glow_surf, (int(x - glow_radius), int(y - glow_radius)))
                
                # 행성 본체 (그라데이션)
                for i in range(int(radius)):
                    ratio = i / radius
                    r = int(planet['color'][0] * (1 - ratio * 0.3))
                    g = int(planet['color'][1] * (1 - ratio * 0.3))
                    b = int(planet['color'][2] * (1 - ratio * 0.3))
                    pygame.draw.circle(surface, (r, g, b), (int(x), int(y)), radius - i)
                
                # 대기 소용돌이 패턴
                for i in range(3):
                    swirl_angle = planet['rotation'] * 2 + i * 2.1
                    swirl_x = x + math.cos(swirl_angle) * radius * 0.6
                    swirl_y = y + math.sin(swirl_angle) * radius * 0.4
                    pygame.draw.circle(surface, planet['color2'], 
                                     (int(swirl_x), int(swirl_y)), radius // 4)
                
                # 고급 3D 하이라이트
                for i in range(3):
                    h_radius = radius // (3 + i)
                    h_alpha = 40 - i * 10
                    h_offset = radius // 3 - i * 3
                    pygame.draw.circle(surface, (255, 255, 200, h_alpha),
                                     (int(x - h_offset), int(y - h_offset)),
                                     h_radius)
            
            elif planet['type'] == 'saturn':
                # 토성 (고리 행성)
                radius = planet['radius']
                
                # 초고급 토성 고리 (뒤쪽) - 수천 개의 입자로 구성
                if 'rings' in planet:
                    ring_rotation = planet['rings']['rotation']
                    ring_surf = pygame.Surface((int(planet['rings']['outer_radius'] * 3), 
                                               int(planet['rings']['outer_radius'] * 2)), pygame.SRCALPHA)
                    
                    # 고리를 여러 섹션으로 나누어 렌더링
                    for section in range(3):  # 내부, 중간, 외부 고리
                        section_start = planet['rings']['inner_radius'] + section * 25
                        section_end = section_start + 20
                        
                        # 각 섹션 내의 세부 고리
                        for i in range(10):
                            ring_radius = section_start + i * 2
                            
                            # 고리 입자 밀도 변화
                            density = math.sin(i * 0.5 + section) * 0.5 + 0.5
                            
                            # 회전과 시간에 따른 반짝임
                            shimmer = math.sin(ring_rotation * 2 + i * 0.3 + section) * 30
                            wave = math.cos(self.time * 3 + ring_radius * 0.05) * 20
                            
                            # 색상 계산 (얼음과 암석 입자)
                            base_brightness = 200 + shimmer + wave
                            ring_color = (
                                min(255, int(base_brightness * 1.1)),
                                min(255, int(base_brightness * 1.0)),
                                min(255, int(base_brightness * 0.85))
                            )
                            ring_alpha = int(80 * density + abs(shimmer * 0.5))
                            
                            # 고리 그리기 (타원형)
                            if ring_alpha > 10:
                                # 여러 개의 얇은 선으로 고리 표현
                                for sub in range(3):
                                    sub_radius = ring_radius + sub * 0.5
                                    sub_alpha = ring_alpha - sub * 20
                                    if sub_alpha > 0:
                                        pygame.draw.ellipse(ring_surf, ring_color + (sub_alpha,),
                                                          (int(planet['rings']['outer_radius'] * 1.5 - sub_radius),
                                                           int(planet['rings']['outer_radius'] - sub_radius * 0.35),
                                                           int(sub_radius * 2), int(sub_radius * 0.7)), 1)
                    
                    # 고리 파티클 그리기
                    if 'ring_particles' in planet:
                        for particle in planet['ring_particles']:
                            # 회전 적용
                            px = x + math.cos(particle['angle'] + ring_rotation) * particle['radius']
                            py = y + math.sin(particle['angle'] + ring_rotation) * particle['radius'] * 0.35
                            
                            # 앞뒤 구분 (3D 효과)
                            depth = math.sin(particle['angle'] + ring_rotation)
                            if depth < 0:  # 뒤쪽 파티클
                                alpha = int(particle['brightness'] * 50 * abs(depth))
                                color = (200, 180, 150, alpha)
                                pygame.draw.circle(ring_surf, color,
                                                 (int(px - x + planet['rings']['outer_radius'] * 1.5),
                                                  int(py - y + planet['rings']['outer_radius'] * 0.5)),
                                                 int(particle['size']))
                    
                    surface.blit(ring_surf, (int(x - planet['rings']['outer_radius'] * 1.5), 
                                            int(y - planet['rings']['outer_radius'] * 0.5)))
                
                # 행성 본체 (고급 3D 그라데이션)
                for i in range(int(radius)):
                    ratio = i / radius
                    brightness = 1.0 - (ratio ** 2) * 0.45
                    r = int(planet['color'][0] * brightness)
                    g = int(planet['color'][1] * brightness)
                    b = int(planet['color'][2] * brightness)
                    pygame.draw.circle(surface, (r, g, b), (int(x), int(y)), radius - i)
                
                # 가로 띠
                for i in range(3):
                    band_y = y + (i - 1) * radius * 0.5
                    band_color = tuple(max(0, min(255, c - i * 15)) for c in planet['color2'])
                    pygame.draw.ellipse(surface, band_color,
                                      (int(x - radius * 0.9), int(band_y - 3),
                                       int(radius * 1.8), 6))
                
                # 초고급 토성 고리 (앞쪽) - 더 밝고 선명하게
                if 'rings' in planet:
                    ring_rotation = planet['rings']['rotation']
                    front_ring_surf = pygame.Surface((int(planet['rings']['outer_radius'] * 3), 
                                                     int(planet['rings']['outer_radius'] * 2)), pygame.SRCALPHA)
                    
                    # 앞쪽 고리 - 더 밝고 선명한 부분
                    for section in range(3):
                        section_start = planet['rings']['inner_radius'] + section * 25
                        
                        for i in range(10):
                            ring_radius = section_start + i * 2
                            
                            # 앞쪽은 더 밝게
                            shimmer = math.cos(ring_rotation * 3 + i * 0.4 + section) * 40
                            wave = math.sin(self.time * 4 + ring_radius * 0.06) * 30
                            
                            base_brightness = 240 + shimmer + wave
                            ring_color = (
                                min(255, int(base_brightness * 1.1)),
                                min(255, int(base_brightness * 1.05)),
                                min(255, int(base_brightness * 0.95))
                            )
                            ring_alpha = int(120 + abs(shimmer))
                            
                            # 앞쪽 고리는 부분적으로만 그리기 (arc)
                            if ring_alpha > 20:
                                for sub in range(2):
                                    sub_radius = ring_radius + sub * 0.3
                                    sub_alpha = ring_alpha - sub * 30
                                    if sub_alpha > 0:
                                        # 앞쪽 부분만 (20% ~ 80%)
                                        pygame.draw.arc(front_ring_surf, ring_color + (sub_alpha,),
                                                       (int(planet['rings']['outer_radius'] * 1.5 - sub_radius),
                                                        int(planet['rings']['outer_radius'] - sub_radius * 0.35),
                                                        int(sub_radius * 2), int(sub_radius * 0.7)),
                                                       math.pi * 0.2, math.pi * 0.8, 2)
                    
                    # 앞쪽 고리 파티클 그리기 (더 밝게)
                    if 'ring_particles' in planet:
                        for particle in planet['ring_particles']:
                            # 회전 적용
                            px = x + math.cos(particle['angle'] + ring_rotation) * particle['radius']
                            py = y + math.sin(particle['angle'] + ring_rotation) * particle['radius'] * 0.35
                            
                            # 앞뒤 구분 (3D 효과)
                            depth = math.sin(particle['angle'] + ring_rotation)
                            if depth >= 0:  # 앞쪽 파티클만
                                alpha = int(particle['brightness'] * 150 * depth)
                                color = (255, 240, 200, min(255, alpha))
                                # 밝은 파티클
                                pygame.draw.circle(front_ring_surf, color,
                                                 (int(px - x + planet['rings']['outer_radius'] * 1.5),
                                                  int(py - y + planet['rings']['outer_radius'] * 0.5)),
                                                 int(particle['size'] * 1.5))
                                # 중심 밝은 점
                                pygame.draw.circle(front_ring_surf, (255, 255, 255, min(255, alpha // 2)),
                                                 (int(px - x + planet['rings']['outer_radius'] * 1.5),
                                                  int(py - y + planet['rings']['outer_radius'] * 0.5)),
                                                 max(1, int(particle['size'] * 0.5)))
                    
                    surface.blit(front_ring_surf, (int(x - planet['rings']['outer_radius'] * 1.5), 
                                                  int(y - planet['rings']['outer_radius'] * 0.5)))
                
                # 고급 3D 하이라이트
                for i in range(3):
                    h_radius = radius // (3 + i)
                    h_alpha = 40 - i * 10
                    h_offset = radius // 3 - i * 3
                    pygame.draw.circle(surface, (255, 240, 200, h_alpha),
                                     (int(x - h_offset), int(y - h_offset)),
                                     h_radius)
            
            elif planet['type'] == 'uranus':
                # 천왕성 (청록색, 기울어진 자전축)
                radius = planet['radius']
                
                # 은은한 글로우
                glow_radius = radius + 8
                glow_surf = pygame.Surface((int(glow_radius * 2), int(glow_radius * 2)), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*planet['glow_color'], 20),
                                 (glow_radius, glow_radius), glow_radius)
                surface.blit(glow_surf, (int(x - glow_radius), int(y - glow_radius)))
                
                # 행성 본체 (그라데이션)
                for i in range(int(radius)):
                    ratio = i / radius
                    r = int(planet['color'][0] * (1 - ratio * 0.2))
                    g = int(planet['color'][1] * (1 - ratio * 0.2))
                    b = int(planet['color'][2] * (1 - ratio * 0.2))
                    pygame.draw.circle(surface, (r, g, b), (int(x), int(y)), radius - i)
                
                # 세로 띠 (기울어진 자전축 표현)
                for i in range(3):
                    band_angle = planet['rotation'] + i * 1.2
                    if math.cos(band_angle) > 0:
                        band_x = x + math.cos(band_angle) * radius * 0.7
                        pygame.draw.line(surface, planet['color2'],
                                       (int(band_x), int(y - radius * 0.8)),
                                       (int(band_x), int(y + radius * 0.8)), 2)
                
                # 고급 3D 하이라이트
                for i in range(3):
                    h_radius = radius // (3 + i)
                    h_alpha = 35 - i * 10
                    h_offset = radius // 3 - i * 2
                    pygame.draw.circle(surface, (200, 255, 255, h_alpha),
                                     (int(x - h_offset), int(y - h_offset)),
                                     h_radius)
            
            elif planet['type'] == 'neptune':
                # 해왕성 (진한 파랑, 폭풍)
                radius = planet['radius']
                
                # 은은한 글로우
                glow_radius = radius + 8
                glow_surf = pygame.Surface((int(glow_radius * 2), int(glow_radius * 2)), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*planet['glow_color'], 25),
                                 (glow_radius, glow_radius), glow_radius)
                surface.blit(glow_surf, (int(x - glow_radius), int(y - glow_radius)))
                
                # 행성 본체 (고급 3D 그라데이션)
                for i in range(int(radius)):
                    ratio = i / radius
                    brightness = 1.0 - (ratio ** 2) * 0.45
                    r = int(planet['color'][0] * brightness)
                    g = int(planet['color'][1] * brightness)
                    b = int(planet['color'][2] * brightness)
                    pygame.draw.circle(surface, (r, g, b), (int(x), int(y)), radius - i)
                
                # 대기 패턴
                for i in range(4):
                    pattern_angle = planet['rotation'] * 1.5 + i * 1.5
                    pattern_x = x + math.cos(pattern_angle) * radius * 0.6
                    pattern_y = y + math.sin(pattern_angle) * radius * 0.4
                    pygame.draw.circle(surface, planet['color2'], 
                                     (int(pattern_x), int(pattern_y)), radius // 5)
                
                # 폭풍 (Great Dark Spot 비슷)
                if 'storms' in planet:
                    for storm in planet['storms']:
                        storm_angle = planet['rotation'] + storm['angle']
                        if math.cos(storm_angle) > 0:
                            storm_x = x + math.cos(storm_angle) * radius * 0.5
                            storm_y = y + math.sin(storm_angle) * radius * 0.2
                            storm_size = int(radius * storm['size'])
                            pygame.draw.ellipse(surface, (30, 60, 120),
                                              (int(storm_x - storm_size), int(storm_y - storm_size/2),
                                               storm_size * 2, storm_size))
                
                # 고급 3D 하이라이트
                for i in range(3):
                    h_radius = radius // (3 + i)
                    h_alpha = 40 - i * 10
                    h_offset = radius // 3 - i * 2
                    pygame.draw.circle(surface, (150, 200, 255, h_alpha),
                                     (int(x - h_offset), int(y - h_offset)),
                                     h_radius)
            
            elif planet['type'] == 'pluto':
                # 명왕성 (작고 갈색)
                radius = planet['radius']
                
                # 행성 본체 (고급 3D 그라데이션)
                for i in range(int(radius)):
                    ratio = i / radius
                    brightness = 1.0 - (ratio ** 2) * 0.45
                    r = int(planet['color'][0] * brightness)
                    g = int(planet['color'][1] * brightness)
                    b = int(planet['color'][2] * brightness)
                    pygame.draw.circle(surface, (r, g, b), (int(x), int(y)), radius - i)
                
                # 표면 디테일
                for i in range(2):
                    detail_angle = planet['rotation'] + i * 3.14
                    if math.cos(detail_angle) > 0:
                        detail_x = x + math.cos(detail_angle) * radius * 0.4
                        detail_y = y + math.sin(detail_angle) * radius * 0.3
                        pygame.draw.circle(surface, planet['color2'], 
                                         (int(detail_x), int(detail_y)), radius // 3)
                
                # 고급 3D 하이라이트
                for i in range(2):
                    h_radius = radius // (4 + i * 2)
                    h_alpha = 25 - i * 10
                    h_offset = radius // 4 - i
                    pygame.draw.circle(surface, (220, 200, 200, h_alpha),
                                     (int(x - h_offset), int(y - h_offset)),
                                     h_radius)
            
            elif planet['type'] == 'jupiter':
                # 목성형 가스 행성
                radius = planet['radius']
                
                # 희미한 고리 (뒤쪽)
                if 'faint_rings' in planet:
                    ring_surf = pygame.Surface((int(radius * 3), int(radius * 3)), pygame.SRCALPHA)
                    ring_rotation = planet['faint_rings']['rotation']
                    
                    # 고리 그리기
                    for i in range(int(planet['faint_rings']['width'])):
                        ring_radius = planet['faint_rings']['radius'] + i
                        alpha = planet['faint_rings']['color'][3] - i * 10
                        if alpha > 0:
                            # 회전 효과를 위한 변형
                            for angle in range(0, 360, 5):
                                rad = math.radians(angle + math.degrees(ring_rotation))
                                px = radius * 1.5 + ring_radius * math.cos(rad)
                                py = radius * 1.5 + ring_radius * math.sin(rad) * 0.4
                                
                                # 뒤쪽만 그리기
                                if math.sin(rad) < 0:
                                    pygame.draw.circle(ring_surf, (*planet['faint_rings']['color'][:3], alpha),
                                                     (int(px), int(py)), 2)
                    
                    surface.blit(ring_surf, (int(x - radius * 1.5), int(y - radius * 1.5)))
                
                # 은은한 글로우
                glow_radius = radius + 10
                glow_surf = pygame.Surface((int(glow_radius * 2), int(glow_radius * 2)), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*planet['glow_color'], 25),
                                 (glow_radius, glow_radius), glow_radius)
                surface.blit(glow_surf, (int(x - glow_radius), int(y - glow_radius)))
                
                # 행성 본체 (고급 3D 그라데이션)
                for i in range(int(radius)):
                    ratio = i / radius
                    brightness = 1.0 - (ratio ** 2) * 0.45
                    r = int(planet['color'][0] * brightness)
                    g = int(planet['color'][1] * brightness)
                    b = int(planet['color'][2] * brightness)
                    pygame.draw.circle(surface, (r, g, b), (int(x), int(y)), radius - i)
                
                # 가로 줄무늬 (목성 특징)
                if 'bands' in planet:
                    for band in planet['bands']:
                        band_y = y + radius * band['y_offset']
                        band_color = tuple(max(0, min(255, c + band['color_shift'])) 
                                         for c in planet['color2'])
                        band_width = radius * 1.8 * math.cos(math.asin(min(1, max(-1, band['y_offset']))))
                        if band_width > 0:
                            pygame.draw.ellipse(surface, band_color,
                                              (int(x - band_width/2), int(band_y - 2),
                                               int(band_width), 4))
                
                # 대적점 (Great Red Spot)
                if 'red_spot' in planet:
                    spot_angle = planet['rotation'] + planet['red_spot']['angle']
                    if math.cos(spot_angle) > 0:  # 보이는 면에만
                        spot_x = x + math.cos(spot_angle) * radius * 0.5
                        spot_y = y + radius * 0.2
                        spot_size = planet['red_spot']['size']
                        pygame.draw.ellipse(surface, (200, 100, 80),
                                          (int(spot_x - spot_size), int(spot_y - spot_size/2),
                                           spot_size * 2, spot_size))
                
                # 희미한 고리 (앞쪽)
                if 'faint_rings' in planet:
                    front_ring_surf = pygame.Surface((int(radius * 3), int(radius * 3)), pygame.SRCALPHA)
                    ring_rotation = planet['faint_rings']['rotation']
                    
                    # 앞쪽 고리 그리기 (더 밝게)
                    for i in range(int(planet['faint_rings']['width'])):
                        ring_radius = planet['faint_rings']['radius'] + i
                        alpha = planet['faint_rings']['color'][3] + 20 - i * 10
                        if alpha > 0:
                            for angle in range(0, 360, 5):
                                rad = math.radians(angle + math.degrees(ring_rotation))
                                px = radius * 1.5 + ring_radius * math.cos(rad)
                                py = radius * 1.5 + ring_radius * math.sin(rad) * 0.4
                                
                                # 앞쪽만 그리기
                                if math.sin(rad) >= 0:
                                    pygame.draw.circle(front_ring_surf, (*planet['faint_rings']['color'][:3], min(255, alpha + 10)),
                                                     (int(px), int(py)), 2)
                    
                    surface.blit(front_ring_surf, (int(x - radius * 1.5), int(y - radius * 1.5)))
                
                # 고급 3D 하이라이트
                for i in range(3):
                    h_radius = radius // (3 + i)
                    h_alpha = 40 - i * 10
                    h_offset = radius // 3 - i * 2
                    pygame.draw.circle(surface, (255, 240, 200, h_alpha),
                                     (int(x - h_offset), int(y - h_offset)),
                                     h_radius)
            
            else:
                # 행성 궤적 (은은하게)
                if len(planet['trail']) > 1:
                    for i in range(len(planet['trail']) - 1):
                        alpha = int(10 * (i / len(planet['trail'])))
                        pygame.draw.circle(surface, (*planet['glow_color'], alpha),
                                         (int(planet['trail'][i][0]), int(planet['trail'][i][1])), 1)
                
                # 행성
                radius = planet['radius']
                
                # 은은한 글로우
                glow_radius = radius + 5
                glow_surf = pygame.Surface((int(glow_radius * 2), int(glow_radius * 2)), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*planet['glow_color'], 20),
                                 (glow_radius, glow_radius), glow_radius)
                surface.blit(glow_surf, (int(x - glow_radius), int(y - glow_radius)))
                
                # 행성 본체
                pygame.draw.circle(surface, planet['color'], (int(x), int(y)), radius)
                
                # 하이라이트
                highlight_offset = radius // 3
                pygame.draw.circle(surface, (255, 255, 255, 40),
                                 (int(x - highlight_offset), int(y - highlight_offset)),
                                 radius // 3)

        surface.blit(self.frame_surface, (0, 0), special_flags=pygame.BLEND_ADD)


# downtown/renderer.py
# 번화가 렌더링 시스템

import pygame
import pygame.freetype
import math
import random
import os
from .constants import (
    SCREEN_WIDTH, SCREEN_HEIGHT, TILE_SIZE,
    MAP_WIDTH, MAP_HEIGHT, TileType,
    Colors, PLANET_THEMES, PlanetTheme,
    resource_path
)

class DowntownRenderer:
    """
    번화가 렌더링 시스템 (고품질)
    - 타일 맵 렌더링
    - 배경 및 파티클
    - UI 요소
    - 카메라 시스템
    - 고급 조명 시스템
    - 동적 그림자 시스템
    """

    def __init__(self):
        # 카메라 (세로 스크롤 최적화)
        self.camera_x = 0
        self.camera_y = 0
        self.target_camera_x = 0
        self.target_camera_y = 0
        self.camera_smoothing = 0.08  # 더 부드러운 추적
        self.camera_lead_y = 100  # 플레이어 아래쪽에 더 많은 공간 (앞을 보여줌)

        # 테마
        self.theme_data = PLANET_THEMES[PlanetTheme.CYBER_CITY]

        # 파티클
        self.particles = []
        self.max_particles = 100

        # 배경 별
        self.stars = []
        self._generate_stars()

        # 타일 캐시
        self.tile_surfaces = {}

        # 애니메이션
        self.animation_timer = 0

        # 미니맵
        self.minimap_size = 90  # 150에서 40% 축소
        self.minimap_size_expanded = 180  # 확대된 미니맵 크기 (2배)
        self.minimap_expanded = False  # 미니맵 확대 상태
        self.minimap_surface = None
        self.minimap_hovered_building = None  # 마우스 호버 중인 건물

        # ========================================
        # 고급 조명 시스템
        # ========================================
        self.global_light_color = (255, 245, 220)  # 따뜻한 햇빛
        self.global_light_intensity = 0.8
        self.ambient_light = (40, 50, 70)  # 주변광 (약간 푸른빛)

        # 동적 광원 리스트
        self.light_sources = []
        self.max_light_sources = 20

        # 조명 레이어 서피스
        self.lighting_surface = None
        self.shadow_surface = None

        # 낮/밤 사이클 (0.0 = 낮, 1.0 = 밤)
        self.day_night_cycle = 0.3  # 저녁 느낌
        self.day_night_speed = 0.02  # 사이클 속도

        # 그림자 설정
        self.shadow_angle = 45  # 그림자 각도 (도)
        self.shadow_length_multiplier = 0.5  # 그림자 길이
        self.shadow_softness = 3  # 그림자 부드러움

        # 대기 효과
        self.fog_enabled = True
        self.fog_density = 0.15
        self.fog_color = (60, 70, 100)

        # 글로벌 포스트 프로세싱
        self.bloom_enabled = True
        self.bloom_intensity = 0.3
        self.vignette_enabled = True
        self.vignette_intensity = 0.4

    def set_theme(self, theme_data):
        """테마 설정"""
        self.theme_data = theme_data
        self._generate_stars()
        self.tile_surfaces.clear()

    def _generate_stars(self):
        """배경 별 생성"""
        self.stars.clear()
        for _ in range(50):
            self.stars.append({
                'x': random.randint(0, SCREEN_WIDTH),
                'y': random.randint(0, SCREEN_HEIGHT),
                'size': random.randint(1, 3),
                'brightness': random.random(),
                'speed': random.uniform(0.1, 0.5)
            })

    def update(self, dt, player_x, player_y):
        """업데이트"""
        self.animation_timer += dt

        # 카메라 타겟 설정 (플레이어 중심, 약간 앞쪽을 더 보여줌)
        self.target_camera_x = player_x - SCREEN_WIDTH // 2
        # 플레이어가 아래로 내려갈 때 앞쪽(아래)을 더 많이 보여줌
        self.target_camera_y = player_y - SCREEN_HEIGHT // 2 + self.camera_lead_y

        # 카메라 경계 제한 (긴 맵에서 부드럽게 제한)
        max_cam_x = max(0, MAP_WIDTH * TILE_SIZE - SCREEN_WIDTH)
        max_cam_y = max(0, MAP_HEIGHT * TILE_SIZE - SCREEN_HEIGHT)
        self.target_camera_x = max(0, min(self.target_camera_x, max_cam_x))
        self.target_camera_y = max(0, min(self.target_camera_y, max_cam_y))

        # 부드러운 카메라 이동
        self.camera_x += (self.target_camera_x - self.camera_x) * self.camera_smoothing
        self.camera_y += (self.target_camera_y - self.camera_y) * self.camera_smoothing

        # 파티클 업데이트
        self._update_particles(dt)

        # 별 업데이트
        self._update_stars(dt)

    def _update_particles(self, dt):
        """파티클 업데이트 (고품질 물리)"""
        for p in self.particles[:]:
            p['life'] -= dt

            # 고급 물리: 중력, 저항, 가속도
            gravity = p.get('gravity', 0)
            drag = p.get('drag', 0.98)
            accel_x = p.get('accel_x', 0)
            accel_y = p.get('accel_y', 0)

            # 속도 업데이트
            p['vx'] = p.get('vx', 0) * drag + accel_x * dt
            p['vy'] = (p.get('vy', 0) + gravity * dt) * drag + accel_y * dt

            # 위치 업데이트
            p['x'] += p.get('vx', 0) * dt
            p['y'] += p.get('vy', 0) * dt

            # 회전 업데이트
            if 'rotation' in p:
                p['rotation'] += p.get('rot_speed', 0) * dt

            # 크기 변화
            if 'size_decay' in p:
                p['size'] = max(0.1, p.get('size', 1) * p['size_decay'])

            # 알파 변화
            if 'alpha_decay' in p:
                p['alpha'] = max(0, p.get('alpha', 255) * p['alpha_decay'])

            # 색상 전이
            if 'color_end' in p and 'color_start' in p:
                progress = 1 - (p['life'] / p.get('max_life', 1))
                p['color'] = self._lerp_color(p['color_start'], p['color_end'], progress)

            # 트레일 효과
            if p.get('has_trail'):
                if 'trail' not in p:
                    p['trail'] = []
                p['trail'].append((p['x'], p['y']))
                if len(p['trail']) > p.get('trail_length', 10):
                    p['trail'].pop(0)

            if p['life'] <= 0:
                self.particles.remove(p)

        # 환경 파티클 추가
        if len(self.particles) < self.max_particles:
            particle_type = self.theme_data.get('particles', 'stars')
            self._spawn_environment_particle(particle_type)

    def _lerp_color(self, color1, color2, t):
        """색상 보간"""
        return tuple(int(c1 + (c2 - c1) * t) for c1, c2 in zip(color1, color2))

    def _sanitize_color(self, color):
        """pygame이 허용하는 (r, g, b) 튜플로 정규화"""
        try:
            if color is None:
                raise ValueError
            seq = list(color)
            if len(seq) < 3:
                raise ValueError
            r, g, b = seq[0], seq[1], seq[2]
            r = max(0, min(255, int(r)))
            g = max(0, min(255, int(g)))
            b = max(0, min(255, int(b)))
            return (r, g, b)
        except Exception:
            return (255, 255, 255)

    def _spawn_environment_particle(self, particle_type):
        """환경 파티클 생성 (고품질)"""
        if random.random() > 0.15:
            return

        particle = {
            'x': random.randint(0, SCREEN_WIDTH) + self.camera_x,
            'y': -10 + self.camera_y,
            'life': random.uniform(2, 5),
            'max_life': random.uniform(2, 5),
            'type': particle_type,
            'alpha': 255,
        }

        if particle_type == 'neon_rain':
            # 네온 비 (고품질)
            particle['vy'] = random.uniform(150, 250)
            particle['vx'] = random.uniform(-15, 15)
            particle['gravity'] = 50
            particle['drag'] = 0.99
            base_color = random.choice([
                Colors.NEON_CYAN, Colors.NEON_PINK, Colors.NEON_PURPLE
            ])
            particle['color'] = base_color
            particle['color_start'] = base_color
            particle['color_end'] = tuple(min(255, c + 50) for c in base_color)
            particle['length'] = random.randint(15, 40)
            particle['has_trail'] = True
            particle['trail_length'] = 5
            particle['glow'] = True
            particle['glow_radius'] = random.randint(3, 6)

        elif particle_type == 'snow':
            # 눈 (고품질 - 부드러운 낙하)
            particle['vy'] = random.uniform(20, 60)
            particle['vx'] = random.uniform(-30, 30)
            particle['accel_x'] = random.uniform(-20, 20)  # 바람에 흔들림
            particle['gravity'] = 10
            particle['drag'] = 0.95
            particle['color'] = (255, 255, 255)
            particle['size'] = random.uniform(2, 6)
            particle['size_decay'] = 0.998
            particle['alpha'] = random.randint(180, 255)
            particle['alpha_decay'] = 0.995
            particle['sparkle'] = random.random() < 0.3
            particle['rotation'] = random.uniform(0, 360)
            particle['rot_speed'] = random.uniform(-60, 60)

        elif particle_type == 'leaves':
            # 나뭇잎 (고품질 - 자연스러운 낙하)
            particle['vy'] = random.uniform(15, 40)
            particle['vx'] = random.uniform(-40, 40)
            particle['accel_x'] = random.uniform(-30, 30)  # 흔들림
            particle['accel_y'] = random.uniform(-5, 5)
            particle['gravity'] = 20
            particle['drag'] = 0.92
            leaf_colors = [
                ((100, 180, 80), (60, 120, 40)),    # 초록 → 진한 초록
                ((150, 200, 100), (100, 150, 60)),  # 연두 → 초록
                ((200, 150, 50), (150, 80, 30)),    # 노랑 → 갈색
                ((220, 100, 50), (150, 50, 30)),    # 주황 → 갈색
                ((180, 50, 50), (100, 30, 30)),     # 빨강 → 진한 빨강
            ]
            colors = random.choice(leaf_colors)
            particle['color'] = colors[0]
            particle['color_start'] = colors[0]
            particle['color_end'] = colors[1]
            particle['size'] = random.uniform(4, 8)
            particle['rotation'] = random.uniform(0, 360)
            particle['rot_speed'] = random.uniform(-120, 120)
            particle['shape'] = random.choice(['oval', 'maple', 'oak'])

        elif particle_type == 'sand':
            # 모래 (고품질 - 바람에 날림)
            particle['y'] = SCREEN_HEIGHT + self.camera_y  # 아래에서 시작
            particle['vy'] = random.uniform(-20, -50)
            particle['vx'] = random.uniform(60, 120)
            particle['gravity'] = 30
            particle['drag'] = 0.96
            sand_colors = [
                (194, 178, 128), (210, 190, 140), (180, 165, 115),
                (200, 185, 130), (170, 155, 105)
            ]
            particle['color'] = random.choice(sand_colors)
            particle['size'] = random.uniform(1, 4)
            particle['size_decay'] = 0.99
            particle['alpha'] = random.randint(150, 255)
            particle['alpha_decay'] = 0.98

        elif particle_type == 'stars' or particle_type == 'sparkle':
            # 반짝이는 별빛/스파클 (고품질)
            particle['x'] = random.randint(0, SCREEN_WIDTH) + self.camera_x
            particle['y'] = random.randint(0, SCREEN_HEIGHT) + self.camera_y
            particle['vx'] = random.uniform(-5, 5)
            particle['vy'] = random.uniform(-5, 5)
            particle['gravity'] = 0
            particle['drag'] = 0.99
            particle['life'] = random.uniform(0.5, 1.5)
            particle['max_life'] = particle['life']
            star_colors = [
                (255, 255, 255), (255, 255, 200), (200, 220, 255),
                (255, 220, 200), (220, 255, 220)
            ]
            particle['color'] = random.choice(star_colors)
            particle['size'] = random.uniform(1, 3)
            particle['twinkle'] = True
            particle['twinkle_speed'] = random.uniform(5, 15)

        elif particle_type == 'fireflies':
            # 반딧불이 (고품질)
            particle['x'] = random.randint(0, SCREEN_WIDTH) + self.camera_x
            particle['y'] = random.randint(SCREEN_HEIGHT // 2, SCREEN_HEIGHT) + self.camera_y
            particle['vx'] = random.uniform(-20, 20)
            particle['vy'] = random.uniform(-20, 20)
            particle['accel_x'] = random.uniform(-10, 10)
            particle['accel_y'] = random.uniform(-10, 10)
            particle['gravity'] = 0
            particle['drag'] = 0.95
            particle['life'] = random.uniform(3, 6)
            particle['max_life'] = particle['life']
            particle['color'] = (180, 255, 100)
            particle['color_start'] = (180, 255, 100)
            particle['color_end'] = (100, 200, 50)
            particle['size'] = random.uniform(2, 4)
            particle['glow'] = True
            particle['glow_radius'] = random.randint(8, 15)
            particle['pulse'] = True
            particle['pulse_speed'] = random.uniform(3, 8)
            particle['has_trail'] = True
            particle['trail_length'] = 8

        elif particle_type == 'embers':
            # 불꽃 잔해 (고품질)
            particle['x'] = random.randint(0, SCREEN_WIDTH) + self.camera_x
            particle['y'] = SCREEN_HEIGHT + self.camera_y
            particle['vx'] = random.uniform(-30, 30)
            particle['vy'] = random.uniform(-80, -150)
            particle['gravity'] = -20  # 위로 상승
            particle['drag'] = 0.97
            particle['life'] = random.uniform(1.5, 3)
            particle['max_life'] = particle['life']
            ember_colors = [
                ((255, 200, 50), (255, 100, 0)),
                ((255, 150, 50), (200, 50, 0)),
                ((255, 220, 100), (255, 150, 50)),
            ]
            colors = random.choice(ember_colors)
            particle['color'] = colors[0]
            particle['color_start'] = colors[0]
            particle['color_end'] = colors[1]
            particle['size'] = random.uniform(2, 5)
            particle['size_decay'] = 0.995
            particle['glow'] = True
            particle['glow_radius'] = random.randint(4, 8)
            particle['has_trail'] = True
            particle['trail_length'] = 6

        self.particles.append(particle)

    def _update_stars(self, dt):
        """별 업데이트"""
        for star in self.stars:
            star['brightness'] = 0.5 + 0.5 * math.sin(
                self.animation_timer * star['speed'] + star['x']
            )

    def draw_background(self, screen):
        """배경 그리기"""
        # 기본 배경색
        screen.fill(self.theme_data['bg_color'])

        # 별 그리기
        for star in self.stars:
            alpha = int(255 * star['brightness'])
            color = (*self.theme_data.get('accent_color', Colors.TEXT_WHITE)[:3],)
            brightness = int(star['brightness'] * 255)
            star_color = (brightness, brightness, brightness)
            pygame.draw.circle(screen, star_color,
                             (int(star['x']), int(star['y'])),
                             star['size'])

        # 그라데이션 오버레이 (하단)
        gradient_height = 200
        for i in range(gradient_height):
            alpha = int(80 * (i / gradient_height))
            line_y = SCREEN_HEIGHT - gradient_height + i
            pygame.draw.line(screen, (*self.theme_data['ground_color'], alpha),
                           (0, line_y), (SCREEN_WIDTH, line_y))

    def draw_tiles(self, screen, downtown_map):
        """타일 맵 그리기"""
        # 화면에 보이는 타일만 렌더링
        start_tile_x = max(0, int(self.camera_x // TILE_SIZE))
        start_tile_y = max(0, int(self.camera_y // TILE_SIZE))
        end_tile_x = min(MAP_WIDTH, int((self.camera_x + SCREEN_WIDTH) // TILE_SIZE) + 2)
        end_tile_y = min(MAP_HEIGHT, int((self.camera_y + SCREEN_HEIGHT) // TILE_SIZE) + 2)

        for y in range(start_tile_y, end_tile_y):
            for x in range(start_tile_x, end_tile_x):
                tile_type = downtown_map.get_tile(x, y)
                self._draw_tile(screen, x, y, tile_type)

    def _draw_tile(self, screen, tx, ty, tile_type):
        """개별 타일 그리기"""
        x = tx * TILE_SIZE - int(self.camera_x)
        y = ty * TILE_SIZE - int(self.camera_y)

        if tile_type == TileType.EMPTY:
            # 빈 타일도 바닥으로 채워서 화면 가장자리 빈 공간 방지
            self._draw_ground_tile(screen, x, y, tx, ty)

        elif tile_type == TileType.GROUND:
            self._draw_ground_tile(screen, x, y, tx, ty)

        elif tile_type == TileType.ROAD:
            self._draw_road_tile(screen, x, y, tx, ty)

        elif tile_type == TileType.SPAWN:
            self._draw_spawn_tile(screen, x, y, tx, ty)

        elif tile_type == TileType.EXIT:
            self._draw_exit_tile(screen, x, y, tx, ty)

        elif tile_type == TileType.DECORATION:
            self._draw_ground_tile(screen, x, y, tx, ty)  # 바닥 먼저
            self._draw_decoration_tile(screen, x, y, tx, ty)  # 꽃/장식 추가

        elif tile_type == TileType.BUILDING:
            # 건물 뒤에도 바닥 타일을 그려서 배경이 비치는 것을 방지
            self._draw_ground_tile(screen, x, y, tx, ty)
            # 건물 자체는 별도 레이어에서 처리

    def _draw_ground_tile(self, screen, x, y, tx=None, ty=None):
        """바닥 타일 - 잔디/풀밭 스타일 (캐싱 적용)"""
        color = self.theme_data['ground_color']

        # 타일 좌표로 패턴 변형 (랜덤하지만 일관된 패턴)
        # tx, ty가 전달되면 사용, 아니면 화면 좌표에서 계산 (하위 호환성)
        tile_x = tx if tx is not None else x // TILE_SIZE
        tile_y = ty if ty is not None else y // TILE_SIZE
        pattern_seed = (tile_x * 7 + tile_y * 13) % 4

        # 캐시 키 생성 (패턴 포함)
        cache_key = ('ground_grass', color, pattern_seed)

        # 캐시된 타일이 있으면 사용
        if cache_key in self.tile_surfaces:
            screen.blit(self.tile_surfaces[cache_key], (x, y))
            return

        # 새 타일 생성
        tile_surf = pygame.Surface((TILE_SIZE, TILE_SIZE), pygame.SRCALPHA)

        # 기본 잔디색
        base_r, base_g, base_b = color
        tile_surf.fill(color)

        # 잔디 텍스처 패턴
        grass_dark = (max(0, base_r - 15), max(0, base_g - 10), max(0, base_b - 15))
        grass_light = (min(255, base_r + 10), min(255, base_g + 15), min(255, base_b + 5))

        # 작은 풀 디테일 추가
        random.seed(tile_x * 100 + tile_y)
        for _ in range(8):
            gx = random.randint(2, TILE_SIZE - 4)
            gy = random.randint(2, TILE_SIZE - 4)
            grass_color = grass_dark if random.random() > 0.5 else grass_light
            # 작은 풀잎 모양
            pygame.draw.line(tile_surf, grass_color, (gx, gy + 3), (gx, gy), 1)
            pygame.draw.line(tile_surf, grass_color, (gx, gy + 3), (gx + 1, gy + 1), 1)

        # 약간의 색상 변화 (패턴별)
        if pattern_seed == 1:
            overlay = pygame.Surface((TILE_SIZE, TILE_SIZE), pygame.SRCALPHA)
            overlay.fill((0, 10, 0, 20))
            tile_surf.blit(overlay, (0, 0))
        elif pattern_seed == 2:
            overlay = pygame.Surface((TILE_SIZE, TILE_SIZE), pygame.SRCALPHA)
            overlay.fill((10, 5, 0, 15))
            tile_surf.blit(overlay, (0, 0))

        # 캐시에 저장
        self.tile_surfaces[cache_key] = tile_surf
        screen.blit(tile_surf, (x, y))

    def _draw_road_tile(self, screen, x, y, tx=None, ty=None):
        """도로 타일 - 육각형 돌길 스타일 (캐싱 적용)"""
        color = self.theme_data['road_color']

        # 타일 좌표로 패턴 결정 (tx, ty가 전달되면 사용)
        tile_x = tx if tx is not None else x // TILE_SIZE
        tile_y = ty if ty is not None else y // TILE_SIZE
        pattern_seed = (tile_x * 11 + tile_y * 17) % 6

        # 캐시 키 생성 (패턴 포함)
        cache_key = ('road_hex', color, pattern_seed)

        # 캐시된 타일이 있으면 사용
        if cache_key in self.tile_surfaces:
            screen.blit(self.tile_surfaces[cache_key], (x, y))
            return

        # 새 타일 생성
        tile_surf = pygame.Surface((TILE_SIZE, TILE_SIZE), pygame.SRCALPHA)

        # 기본 색상
        base_r, base_g, base_b = color

        # 약간 어두운 배경 (틈새 색상)
        gap_color = (max(0, base_r - 30), max(0, base_g - 25), max(0, base_b - 20))
        tile_surf.fill(gap_color)

        # 육각형 돌 그리기
        stone_color = color
        stone_light = (min(255, base_r + 15), min(255, base_g + 12), min(255, base_b + 10))
        stone_dark = (max(0, base_r - 20), max(0, base_g - 18), max(0, base_b - 15))

        # 육각형 크기 및 배치 (타일 내에 작은 육각형들)
        hex_size = 10  # 육각형 반지름
        hex_h = hex_size * 1.732  # 높이 (sqrt(3))

        # 육각형 패턴 (2x2 배열로 타일을 채움)
        random.seed(tile_x * 50 + tile_y + pattern_seed)

        positions = [
            (TILE_SIZE // 4, TILE_SIZE // 4),
            (TILE_SIZE * 3 // 4, TILE_SIZE // 4),
            (TILE_SIZE // 4, TILE_SIZE * 3 // 4),
            (TILE_SIZE * 3 // 4, TILE_SIZE * 3 // 4),
            (TILE_SIZE // 2, TILE_SIZE // 2),
        ]

        for cx, cy in positions:
            # 약간의 위치 변형
            cx += random.randint(-3, 3)
            cy += random.randint(-3, 3)

            # 육각형 포인트 계산
            hex_points = []
            for i in range(6):
                angle = math.pi / 6 + i * math.pi / 3  # 30도 회전된 육각형
                px = cx + hex_size * math.cos(angle)
                py = cy + hex_size * math.sin(angle)
                hex_points.append((px, py))

            # 색상 변형
            color_var = random.randint(-10, 10)
            current_stone = (
                max(0, min(255, base_r + color_var)),
                max(0, min(255, base_g + color_var - 3)),
                max(0, min(255, base_b + color_var - 5))
            )

            # 육각형 그리기
            pygame.draw.polygon(tile_surf, current_stone, hex_points)

            # 하이라이트 (위쪽 면)
            highlight_points = [hex_points[5], hex_points[0], hex_points[1]]
            pygame.draw.lines(tile_surf, stone_light, False, highlight_points, 1)

            # 그림자 (아래쪽 면)
            shadow_points = [hex_points[2], hex_points[3], hex_points[4]]
            pygame.draw.lines(tile_surf, stone_dark, False, shadow_points, 1)

        # 캐시에 저장
        self.tile_surfaces[cache_key] = tile_surf
        screen.blit(tile_surf, (x, y))

    def _draw_spawn_tile(self, screen, x, y, tx=None, ty=None):
        """스폰 타일 - 기본 도로만 (오오라는 별도 레이어에서)"""
        # 기본 도로만 그리기
        self._draw_road_tile(screen, x, y, tx, ty)

    def _draw_exit_tile(self, screen, x, y, tx=None, ty=None):
        """출구 타일 - 기본 도로만 (오오라는 별도 레이어에서)"""
        # 기본 도로만 그리기
        self._draw_road_tile(screen, x, y, tx, ty)

    def _draw_decoration_tile(self, screen, x, y, tx=None, ty=None):
        """장식 타일 - 꽃밭, 화단 스타일 (캐싱 적용)"""
        # 타일 좌표로 패턴 결정 (tx, ty가 전달되면 사용)
        tile_x = tx if tx is not None else x // TILE_SIZE
        tile_y = ty if ty is not None else y // TILE_SIZE
        pattern_seed = (tile_x * 23 + tile_y * 31) % 8

        # 캐시 키 생성
        cache_key = ('decoration_flower', pattern_seed)

        # 캐시된 타일이 있으면 사용
        if cache_key in self.tile_surfaces:
            screen.blit(self.tile_surfaces[cache_key], (x, y))
            return

        # 새 타일 생성
        tile_surf = pygame.Surface((TILE_SIZE, TILE_SIZE), pygame.SRCALPHA)

        # 꽃 색상 팔레트 (파스텔 톤)
        flower_palettes = [
            # 빨강/핑크 계열
            [(255, 150, 150), (255, 100, 130), (255, 180, 180), (220, 80, 100)],
            # 파랑/보라 계열
            [(150, 150, 255), (130, 100, 255), (180, 180, 255), (100, 80, 220)],
            # 노랑/주황 계열
            [(255, 220, 100), (255, 180, 50), (255, 240, 150), (230, 160, 30)],
            # 혼합 (빨강+파랑)
            [(255, 130, 180), (180, 130, 255), (255, 180, 200), (200, 150, 255)],
            # 혼합 (빨강+노랑)
            [(255, 150, 100), (255, 200, 100), (255, 100, 80), (255, 180, 120)],
            # 보라/핑크
            [(220, 100, 220), (255, 150, 200), (200, 80, 180), (255, 180, 220)],
            # 파랑 계열
            [(100, 180, 255), (80, 150, 230), (150, 200, 255), (60, 130, 200)],
            # 다양한 색상 혼합
            [(255, 100, 100), (100, 100, 255), (255, 200, 100), (255, 150, 200)],
        ]

        # 이 타일의 꽃 색상
        random.seed(tile_x * 200 + tile_y + pattern_seed)
        flower_colors = flower_palettes[pattern_seed]

        # 꽃 그리기 (여러 개)
        num_flowers = random.randint(6, 12)
        for _ in range(num_flowers):
            fx = random.randint(4, TILE_SIZE - 4)
            fy = random.randint(4, TILE_SIZE - 4)
            flower_color = random.choice(flower_colors)
            flower_type = random.randint(0, 3)

            if flower_type == 0:
                # 작은 꽃 (5개 꽃잎)
                petal_size = random.randint(2, 4)
                for i in range(5):
                    angle = i * 2 * math.pi / 5
                    px = fx + int(math.cos(angle) * petal_size)
                    py = fy + int(math.sin(angle) * petal_size)
                    pygame.draw.circle(tile_surf, flower_color, (px, py), 2)
                # 중앙
                pygame.draw.circle(tile_surf, (255, 230, 100), (fx, fy), 2)

            elif flower_type == 1:
                # 튤립 스타일
                pygame.draw.ellipse(tile_surf, flower_color,
                                   (fx - 2, fy - 4, 5, 6))
                # 줄기
                pygame.draw.line(tile_surf, (80, 140, 60),
                               (fx, fy + 2), (fx, fy + 6), 1)

            elif flower_type == 2:
                # 작은 점 꽃 (라벤더 스타일)
                for i in range(3):
                    py_offset = i * 2
                    pygame.draw.circle(tile_surf, flower_color,
                                      (fx, fy - py_offset), 2)
                # 줄기
                pygame.draw.line(tile_surf, (80, 140, 60),
                               (fx, fy + 1), (fx, fy + 5), 1)

            else:
                # 단순 원형 꽃
                pygame.draw.circle(tile_surf, flower_color, (fx, fy), 3)
                # 중앙
                center_color = (
                    min(255, flower_color[0] + 40),
                    min(255, flower_color[1] + 40),
                    min(255, flower_color[2] - 20)
                )
                pygame.draw.circle(tile_surf, center_color, (fx, fy), 1)

        # 풀잎 몇 개 추가
        grass_color = (80, 150, 70)
        grass_light = (100, 180, 80)
        for _ in range(4):
            gx = random.randint(2, TILE_SIZE - 2)
            gy = random.randint(TILE_SIZE - 8, TILE_SIZE - 2)
            g_color = grass_color if random.random() > 0.5 else grass_light
            # 풀잎
            pygame.draw.line(tile_surf, g_color, (gx, gy), (gx - 1, gy - 5), 1)
            pygame.draw.line(tile_surf, g_color, (gx, gy), (gx + 1, gy - 4), 1)

        # 캐시에 저장
        self.tile_surfaces[cache_key] = tile_surf
        screen.blit(tile_surf, (x, y))

    def draw_particles(self, screen):
        """파티클 그리기 (고품질)"""
        for p in self.particles:
            px = p['x'] - self.camera_x
            py = p['y'] - self.camera_y

            # 화면 밖이면 건너뜀
            if px < -100 or px > SCREEN_WIDTH + 100 or py < -100 or py > SCREEN_HEIGHT + 100:
                continue

            # 기본 알파 계산
            base_alpha = p.get('alpha', 255)
            life_alpha = min(255, int(255 * (p['life'] / p.get('max_life', 3))))
            alpha = int(base_alpha * life_alpha / 255)

            # 트레일 먼저 그리기
            if p.get('has_trail') and 'trail' in p:
                self._draw_particle_trail(screen, p, alpha)

            if p['type'] == 'neon_rain':
                # 네온 비 (고품질)
                self._draw_neon_rain(screen, p, px, py, alpha)

            elif p['type'] == 'snow':
                # 눈 (고품질)
                self._draw_snow_particle(screen, p, px, py, alpha)

            elif p['type'] == 'leaves':
                # 나뭇잎 (고품질)
                self._draw_leaf_particle(screen, p, px, py, alpha)

            elif p['type'] == 'sand':
                # 모래 (고품질)
                self._draw_sand_particle(screen, p, px, py, alpha)

            elif p['type'] == 'stars' or p['type'] == 'sparkle':
                # 별빛/스파클 (고품질)
                self._draw_star_particle(screen, p, px, py, alpha)

            elif p['type'] == 'fireflies':
                # 반딧불이 (고품질)
                self._draw_firefly_particle(screen, p, px, py, alpha)

            elif p['type'] == 'embers':
                # 불꽃 잔해 (고품질)
                self._draw_ember_particle(screen, p, px, py, alpha)

            else:
                # 기본 파티클
                self._draw_default_particle(screen, p, px, py, alpha)

    def _draw_particle_trail(self, screen, p, alpha):
        """파티클 트레일 그리기"""
        trail = p.get('trail', [])
        if len(trail) < 2:
            return

        color = self._sanitize_color(p.get('color', (255, 255, 255)))
        for i in range(len(trail) - 1):
            t1 = trail[i]
            t2 = trail[i + 1]
            trail_alpha = int(alpha * (i + 1) / len(trail) * 0.5)
            if trail_alpha > 0:
                x1 = t1[0] - self.camera_x
                y1 = t1[1] - self.camera_y
                x2 = t2[0] - self.camera_x
                y2 = t2[1] - self.camera_y
                trail_surf = pygame.Surface((abs(x2 - x1) + 10, abs(y2 - y1) + 10), pygame.SRCALPHA)
                pygame.draw.line(trail_surf, (*color[:3], trail_alpha),
                               (5, 5), (abs(x2 - x1) + 5, abs(y2 - y1) + 5),
                               max(1, int(p.get('size', 2) * 0.5)))
                screen.blit(trail_surf, (min(x1, x2) - 5, min(y1, y2) - 5))

    def _draw_neon_rain(self, screen, p, px, py, alpha):
        """네온 비 파티클 (고품질)"""
        color = p.get('color', Colors.NEON_CYAN)
        length = p.get('length', 20)

        # 색상 값을 정수로 변환하고 범위 제한
        r = max(0, min(255, int(color[0])))
        g = max(0, min(255, int(color[1])))
        b = max(0, min(255, int(color[2])))
        base_alpha = max(0, min(255, int(alpha)))

        # 글로우 효과
        if p.get('glow'):
            glow_radius = p.get('glow_radius', 4)
            glow_surf = pygame.Surface((glow_radius * 4, length + glow_radius * 4), pygame.SRCALPHA)
            for rad in range(glow_radius, 0, -1):
                glow_alpha = max(0, min(255, int(base_alpha * 0.3 * rad / glow_radius)))
                pygame.draw.line(glow_surf, (r, g, b, glow_alpha),
                               (glow_radius * 2, glow_radius),
                               (glow_radius * 2, length + glow_radius), rad * 2)
            screen.blit(glow_surf, (px - glow_radius * 2, py - glow_radius))

        # 메인 빗줄기 (그라데이션)
        for i in range(int(length)):
            progress = i / length
            line_alpha = max(0, min(255, int(base_alpha * (1 - progress * 0.5))))
            pygame.draw.line(screen, (r, g, b), (px, py + i), (px, py + i + 1), 2)

        # 빛나는 끝부분
        pygame.draw.circle(screen, (r, g, b), (int(px), int(py)), 2)

    def _draw_snow_particle(self, screen, p, px, py, alpha):
        """눈 파티클 (고품질)"""
        size = int(p.get('size', 3))
        if size < 1:
            return
        color = p.get('color', (255, 255, 255))

        # color를 정수로 변환하고 범위 제한
        r = max(0, min(255, int(color[0])))
        g = max(0, min(255, int(color[1])))
        b = max(0, min(255, int(color[2])))
        base_alpha = max(0, min(255, int(alpha)))

        if base_alpha <= 0:
            return

        # 눈송이 서피스
        snow_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
        center = size * 2

        # 부드러운 원형 눈송이
        for rad in range(size, 0, -1):
            ring_alpha = max(0, min(255, int(base_alpha * rad / size)))
            pygame.draw.circle(snow_surf, (r, g, b, ring_alpha), (center, center), rad)

        # 스파클 효과
        if p.get('sparkle'):
            sparkle_intensity = abs(math.sin(self.animation_timer * p.get('twinkle_speed', 10)))
            sparkle_alpha = max(0, min(255, int(base_alpha * sparkle_intensity * 0.8)))
            if sparkle_alpha > 0:
                # 십자 반짝임
                pygame.draw.line(snow_surf, (255, 255, 255, sparkle_alpha),
                               (center - size, center), (center + size, center), 1)
                pygame.draw.line(snow_surf, (255, 255, 255, sparkle_alpha),
                               (center, center - size), (center, center + size), 1)

        # 회전 적용
        if 'rotation' in p:
            snow_surf = pygame.transform.rotate(snow_surf, p['rotation'])

        screen.blit(snow_surf, (px - snow_surf.get_width() // 2, py - snow_surf.get_height() // 2))

    def _draw_leaf_particle(self, screen, p, px, py, alpha):
        """나뭇잎 파티클 (고품질)"""
        size = int(p.get('size', 6))
        if size < 1:
            return  # 너무 작은 파티클은 그리지 않음
        color = p.get('color', (100, 180, 80))
        shape = p.get('shape', 'oval')

        leaf_surf = pygame.Surface((size * 3, size * 2), pygame.SRCALPHA)

        # color와 alpha를 정수로 변환하고 범위 제한 (0-255)
        r = max(0, min(255, int(color[0])))
        g = max(0, min(255, int(color[1])))
        b = max(0, min(255, int(color[2])))
        a = max(0, min(255, int(alpha)))

        if a <= 0:
            return  # 완전 투명하면 그리지 않음

        if shape == 'oval':
            # 타원형 잎
            pygame.draw.ellipse(leaf_surf, (r, g, b, a), (0, 0, size * 3, size * 2))
            # 잎맥
            vein_color = (min(255, r + 30), min(255, g + 30), min(255, b + 30), a // 2)
            pygame.draw.line(leaf_surf, vein_color,
                           (size // 2, size), (size * 2 + size // 2, size), 1)
        elif shape == 'maple':
            # 단풍잎 (간단화) - 모든 좌표를 정수로 변환
            points = [
                (int(size * 1.5), 0), (int(size * 2), int(size * 0.5)), (int(size * 3), int(size * 0.5)),
                (int(size * 2.5), size), (int(size * 3), int(size * 1.5)), (int(size * 2), int(size * 1.5)),
                (int(size * 1.5), int(size * 2)), (size, int(size * 1.5)), (0, int(size * 1.5)),
                (int(size * 0.5), size), (0, int(size * 0.5)), (size, int(size * 0.5))
            ]
            pygame.draw.polygon(leaf_surf, (r, g, b, a), points)
        else:  # oak
            # 참나무 잎 (간단화) - 모든 좌표를 정수로 변환
            for i in range(3):
                cx = int(size * (0.5 + i))
                pygame.draw.ellipse(leaf_surf, (r, g, b, a),
                                  (int(cx - size * 0.4), int(size * 0.2 * i), int(size * 0.8), int(size * 1.5)))

        # 회전 적용
        rotated = pygame.transform.rotate(leaf_surf, p.get('rotation', 0))
        screen.blit(rotated, (px - rotated.get_width() // 2, py - rotated.get_height() // 2))

    def _draw_sand_particle(self, screen, p, px, py, alpha):
        """모래 파티클 (고품질)"""
        size = max(1, int(p.get('size', 2)))
        color = p.get('color', (194, 178, 128))

        # color와 alpha를 정수로 변환하고 범위 제한 (0-255)
        cr = max(0, min(255, int(color[0])))
        cg = max(0, min(255, int(color[1])))
        cb = max(0, min(255, int(color[2])))
        base_alpha = max(0, min(255, int(alpha)))

        if base_alpha <= 0:
            return

        # 부드러운 원형 모래 알갱이
        sand_surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
        center = size * 3 // 2

        for r in range(size, 0, -1):
            ring_alpha = max(0, min(255, int(base_alpha * r / size)))
            pygame.draw.circle(sand_surf, (cr, cg, cb, ring_alpha), (center, center), r)

        screen.blit(sand_surf, (px - center, py - center))

    def _draw_star_particle(self, screen, p, px, py, alpha):
        """별빛 파티클 (고품질)"""
        size = max(1, int(p.get('size', 2)))
        color = p.get('color', (255, 255, 255))

        # color를 정수로 변환하고 범위 제한 (0-255)
        cr = max(0, min(255, int(color[0])))
        cg = max(0, min(255, int(color[1])))
        cb = max(0, min(255, int(color[2])))

        # 트윙클 효과
        if p.get('twinkle'):
            twinkle = abs(math.sin(self.animation_timer * p.get('twinkle_speed', 10)))
            alpha = int(alpha * (0.3 + 0.7 * twinkle))
            size = max(1, int(size * (0.5 + 0.5 * twinkle)))

        base_alpha = max(0, min(255, int(alpha)))
        if base_alpha <= 0:
            return

        star_surf = pygame.Surface((size * 6, size * 6), pygame.SRCALPHA)
        center = size * 3

        # 글로우
        for r in range(size * 2, 0, -1):
            glow_alpha = max(0, min(255, int(base_alpha * 0.3 * r / (size * 2))))
            pygame.draw.circle(star_surf, (cr, cg, cb, glow_alpha), (center, center), r)

        # 십자 빛
        pygame.draw.line(star_surf, (cr, cg, cb, base_alpha),
                        (center - size * 2, center), (center + size * 2, center), 1)
        pygame.draw.line(star_surf, (cr, cg, cb, base_alpha),
                        (center, center - size * 2), (center, center + size * 2), 1)

        # 코어
        pygame.draw.circle(star_surf, (cr, cg, cb, base_alpha), (center, center), size)

        screen.blit(star_surf, (px - center, py - center))

    def _draw_firefly_particle(self, screen, p, px, py, alpha):
        """반딧불이 파티클 (고품질)"""
        size = max(1, int(p.get('size', 3)))
        color = p.get('color', (180, 255, 100))

        # color를 정수로 변환하고 범위 제한 (0-255)
        cr = max(0, min(255, int(color[0])))
        cg = max(0, min(255, int(color[1])))
        cb = max(0, min(255, int(color[2])))

        # 펄스 효과
        if p.get('pulse'):
            pulse = abs(math.sin(self.animation_timer * p.get('pulse_speed', 5)))
            alpha = int(alpha * (0.4 + 0.6 * pulse))

        base_alpha = max(0, min(255, int(alpha)))
        if base_alpha <= 0:
            return

        # 글로우
        glow_radius = int(p.get('glow_radius', 10))
        glow_surf = pygame.Surface((glow_radius * 4, glow_radius * 4), pygame.SRCALPHA)
        center = glow_radius * 2

        for r in range(glow_radius, 0, -1):
            glow_alpha = max(0, min(255, int(base_alpha * 0.5 * r / glow_radius)))
            pygame.draw.circle(glow_surf, (cr, cg, cb, glow_alpha), (center, center), r)

        # 코어 (밝은 중심)
        pygame.draw.circle(glow_surf, (255, 255, 200, base_alpha), (center, center), size)

        screen.blit(glow_surf, (px - center, py - center))

    def _draw_ember_particle(self, screen, p, px, py, alpha):
        """불꽃 잔해 파티클 (고품질)"""
        size = max(1, int(p.get('size', 3)))
        color = p.get('color', (255, 200, 50))

        # color와 alpha를 정수로 변환하고 범위 제한 (0-255)
        cr = max(0, min(255, int(color[0])))
        cg = max(0, min(255, int(color[1])))
        cb = max(0, min(255, int(color[2])))
        base_alpha = max(0, min(255, int(alpha)))

        if base_alpha <= 0:
            return

        ember_surf = pygame.Surface((size * 6, size * 6), pygame.SRCALPHA)
        center = size * 3

        # 글로우 (붉은빛)
        glow_radius = int(p.get('glow_radius', 6))
        for r in range(glow_radius, 0, -1):
            glow_alpha = max(0, min(255, int(base_alpha * 0.4 * r / glow_radius)))
            glow_r = min(255, cr + 30)
            glow_g = max(0, cg - 30)
            glow_b = max(0, cb - 30)
            pygame.draw.circle(ember_surf, (glow_r, glow_g, glow_b, glow_alpha), (center, center), r)

        # 코어 (밝은 중심)
        pygame.draw.circle(ember_surf, (cr, cg, cb, base_alpha), (center, center), size)
        core_alpha = max(0, min(255, base_alpha + 50))
        pygame.draw.circle(ember_surf, (255, 255, 200, core_alpha), (center, center), max(1, size // 2))

        screen.blit(ember_surf, (px - center, py - center))

    def _draw_default_particle(self, screen, p, px, py, alpha):
        """기본 파티클 (폴백)"""
        size = max(1, int(p.get('size', 2)))
        color = p.get('color', (255, 255, 255))

        # color와 alpha를 정수로 변환하고 범위 제한 (0-255)
        r = max(0, min(255, int(color[0])))
        g = max(0, min(255, int(color[1])))
        b = max(0, min(255, int(color[2])))
        a = max(0, min(255, int(alpha)))

        if a <= 0:
            return

        surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
        pygame.draw.circle(surf, (r, g, b, a), (size, size), size)
        screen.blit(surf, (px - size, py - size))

    def toggle_minimap_expanded(self):
        """미니맵 확대/축소 토글"""
        self.minimap_expanded = not self.minimap_expanded
        return self.minimap_expanded

    def get_minimap_rect(self):
        """현재 미니맵의 영역 반환 (클릭 감지용)"""
        current_size = self.minimap_size_expanded if self.minimap_expanded else self.minimap_size
        minimap_x = SCREEN_WIDTH - current_size - 20
        minimap_y = SCREEN_HEIGHT - current_size - 20
        return pygame.Rect(minimap_x, minimap_y, current_size, current_size)

    def get_building_at_minimap_pos(self, mouse_pos, buildings):
        """미니맵에서 마우스 위치에 해당하는 건물 반환"""
        minimap_rect = self.get_minimap_rect()
        if not minimap_rect.collidepoint(mouse_pos):
            return None

        current_size = self.minimap_size_expanded if self.minimap_expanded else self.minimap_size
        minimap_x = minimap_rect.x
        minimap_y = minimap_rect.y

        # 스케일 계산
        scale_x = current_size / (MAP_WIDTH * TILE_SIZE)
        scale_y = current_size / (MAP_HEIGHT * TILE_SIZE)

        # 마우스 위치를 미니맵 내 상대 좌표로 변환
        rel_x = mouse_pos[0] - minimap_x
        rel_y = mouse_pos[1] - minimap_y

        # 각 건물과 충돌 검사
        for building in buildings.buildings:
            bx = building.x * scale_x
            by = building.y * scale_y
            bw = building.width * scale_x
            bh = building.height * scale_y

            if bx <= rel_x <= bx + bw and by <= rel_y <= by + bh:
                return building

        return None

    def _draw_minimap_building_icon(self, screen, building, x, y, w, h, is_expanded):
        """미니맵에 건물별 미니 아이콘 그리기"""
        building_type = building.type
        color = building.info.get('color', (100, 100, 100))

        # 크기 스케일 (확대 시 더 세밀하게)
        scale = 1.8 if is_expanded else 1.0
        cx, cy = x + w / 2, y + h / 2  # 중심점

        # 건물 타입별 미니 아이콘 그리기
        if building_type == "casino":
            # 카지노: 네온 빛나는 다이아몬드/카드 모양
            pygame.draw.rect(screen, color, (x, y, w, h), border_radius=2)
            # 중앙에 작은 다이아몬드
            diamond_size = max(3, int(4 * scale))
            points = [(cx, cy - diamond_size), (cx + diamond_size, cy),
                     (cx, cy + diamond_size), (cx - diamond_size, cy)]
            pygame.draw.polygon(screen, (255, 255, 100), points)

        elif building_type == "colosseum":
            # 콜로세움: 원형 경기장
            pygame.draw.ellipse(screen, color, (x, y, w, h))
            inner_margin = max(1, int(2 * scale))
            pygame.draw.ellipse(screen, (60, 50, 40),
                              (x + inner_margin, y + inner_margin,
                               w - inner_margin * 2, h - inner_margin * 2))

        elif building_type == "blacksmith":
            # 대장간: 모루/망치 모양 (삼각형 지붕 + 굴뚝)
            pygame.draw.rect(screen, color, (x, y + h * 0.3, w, h * 0.7))
            # 삼각형 지붕
            roof_points = [(x, y + h * 0.3), (cx, y), (x + w, y + h * 0.3)]
            pygame.draw.polygon(screen, (80, 40, 20), roof_points)
            # 굴뚝
            chimney_w = max(2, int(3 * scale))
            pygame.draw.rect(screen, (50, 50, 50),
                           (x + w * 0.7, y - h * 0.2, chimney_w, h * 0.4))

        elif building_type == "magic_store":
            # 마법 성소: 별/달 모양
            pygame.draw.rect(screen, color, (x, y, w, h), border_radius=3)
            # 중앙에 달 모양
            moon_r = max(2, int(3 * scale))
            pygame.draw.circle(screen, (200, 200, 255), (int(cx), int(cy)), moon_r)

        elif building_type == "pet_shop":
            # 펫샵: 집 모양 + 발자국
            pygame.draw.rect(screen, color, (x, y + h * 0.35, w, h * 0.65))
            # 삼각형 지붕
            roof_points = [(x - 1, y + h * 0.35), (cx, y), (x + w + 1, y + h * 0.35)]
            pygame.draw.polygon(screen, (80, 140, 60), roof_points)
            # 작은 발자국 점
            paw_r = max(1, int(2 * scale))
            pygame.draw.circle(screen, (255, 255, 255), (int(cx), int(cy + h * 0.15)), paw_r)

        elif building_type == "elder":
            # 현자/피라미드: 삼각형 피라미드
            pyramid_points = [(x, y + h), (cx, y), (x + w, y + h)]
            pygame.draw.polygon(screen, color, pyramid_points)
            # 눈 모양
            eye_y = y + h * 0.4
            pygame.draw.circle(screen, (255, 255, 200), (int(cx), int(eye_y)), max(1, int(2 * scale)))

        elif building_type == "minigame":
            # 아케이드: 게임기 모양
            pygame.draw.rect(screen, color, (x, y, w, h), border_radius=2)
            # 화면 부분
            screen_margin = max(1, int(2 * scale))
            pygame.draw.rect(screen, (0, 50, 0),
                           (x + screen_margin, y + screen_margin,
                            w - screen_margin * 2, h * 0.5))

        elif building_type == "tavern":
            # 선술집: 집 모양 + 간판
            pygame.draw.rect(screen, color, (x, y + h * 0.3, w, h * 0.7))
            # 삼각형 지붕
            roof_points = [(x - 1, y + h * 0.3), (cx, y), (x + w + 1, y + h * 0.3)]
            pygame.draw.polygon(screen, (139, 90, 43), roof_points)
            # 문
            door_w = max(2, int(3 * scale))
            pygame.draw.rect(screen, (80, 50, 20),
                           (cx - door_w / 2, y + h * 0.6, door_w, h * 0.4))

        elif building_type == "bank":
            # 은행: 기둥이 있는 건물
            pygame.draw.rect(screen, color, (x, y, w, h))
            # 기둥들
            pillar_count = 2 if is_expanded else 1
            pillar_w = max(1, int(2 * scale))
            for i in range(pillar_count + 1):
                px = x + (w / (pillar_count + 1)) * (i + 0.5)
                pygame.draw.line(screen, (255, 255, 200),
                               (int(px), int(y + 2)), (int(px), int(y + h - 2)), pillar_w)

        elif building_type == "mystery":
            # 미스터리: 물음표/소용돌이
            pygame.draw.circle(screen, color, (int(cx), int(cy)), int(min(w, h) / 2))
            # 물음표 점
            pygame.draw.circle(screen, (255, 255, 255), (int(cx), int(cy)), max(1, int(2 * scale)))

        elif building_type == "gacha":
            # 가챠샵: 캡슐머신 모양
            pygame.draw.rect(screen, color, (x, y + h * 0.2, w, h * 0.8), border_radius=2)
            # 둥근 상단
            pygame.draw.ellipse(screen, (255, 200, 50), (x, y, w, h * 0.4))
            # 별
            star_r = max(1, int(2 * scale))
            pygame.draw.circle(screen, (255, 255, 255), (int(cx), int(cy - h * 0.1)), star_r)

        elif building_type == "academy":
            # 아카데미: 탑/성 모양
            # 메인 건물
            pygame.draw.rect(screen, color, (x + w * 0.2, y + h * 0.3, w * 0.6, h * 0.7))
            # 3개의 탑
            tower_w = w * 0.25
            pygame.draw.rect(screen, (130, 80, 220), (x, y + h * 0.15, tower_w, h * 0.85))
            pygame.draw.rect(screen, (140, 90, 230), (cx - tower_w / 2, y, tower_w, h))
            pygame.draw.rect(screen, (130, 80, 220), (x + w - tower_w, y + h * 0.15, tower_w, h * 0.85))

        elif building_type == "item_shop":
            # 아이템 상점: 상점 모양 + 검 아이콘
            pygame.draw.rect(screen, color, (x, y + h * 0.25, w, h * 0.75))
            # 지붕
            roof_points = [(x - 1, y + h * 0.25), (cx, y), (x + w + 1, y + h * 0.25)]
            pygame.draw.polygon(screen, (180, 140, 80), roof_points)
            # 작은 검 모양
            sword_len = max(2, int(4 * scale))
            pygame.draw.line(screen, (200, 200, 200),
                           (int(cx), int(cy - sword_len / 2)),
                           (int(cx), int(cy + sword_len / 2)), max(1, int(scale)))

        else:
            # 기본: 단순 사각형
            pygame.draw.rect(screen, color, (x, y, w, h), border_radius=1)

    def draw_minimap(self, screen, downtown_map, player, buildings, mouse_pos=None):
        """미니맵 그리기 (우측 하단) - 확대/축소 및 툴팁 지원"""
        # 현재 미니맵 크기 결정
        current_size = self.minimap_size_expanded if self.minimap_expanded else self.minimap_size

        minimap_x = SCREEN_WIDTH - current_size - 20
        minimap_y = SCREEN_HEIGHT - current_size - 20

        # 미니맵 배경
        minimap_rect = pygame.Rect(minimap_x, minimap_y, current_size, current_size)

        # 확대 상태일 때 반투명 배경 추가
        if self.minimap_expanded:
            bg_surf = pygame.Surface((current_size, current_size), pygame.SRCALPHA)
            pygame.draw.rect(bg_surf, (15, 15, 35, 230), (0, 0, current_size, current_size), border_radius=15)
            screen.blit(bg_surf, (minimap_x, minimap_y))
            pygame.draw.rect(screen, Colors.NEON_CYAN, minimap_rect, 3, border_radius=15)
        else:
            bg_surf = pygame.Surface((current_size, current_size), pygame.SRCALPHA)
            pygame.draw.rect(bg_surf, (20, 20, 40, 200), (0, 0, current_size, current_size), border_radius=10)
            screen.blit(bg_surf, (minimap_x, minimap_y))
            pygame.draw.rect(screen, Colors.NEON_CYAN, minimap_rect, 2, border_radius=10)

        # 스케일 계산
        scale_x = current_size / (MAP_WIDTH * TILE_SIZE)
        scale_y = current_size / (MAP_HEIGHT * TILE_SIZE)

        # 도로 표시
        for y in range(MAP_HEIGHT):
            for x in range(MAP_WIDTH):
                tile = downtown_map.get_tile(x, y)
                if tile == TileType.ROAD:
                    mx = minimap_x + x * TILE_SIZE * scale_x
                    my = minimap_y + y * TILE_SIZE * scale_y
                    pygame.draw.rect(screen, (80, 80, 100),
                                   (mx, my, TILE_SIZE * scale_x, TILE_SIZE * scale_y))

        # 마우스 호버 중인 건물 확인 (확대 상태에서만)
        hovered_building = None
        if self.minimap_expanded and mouse_pos:
            hovered_building = self.get_building_at_minimap_pos(mouse_pos, buildings)
            self.minimap_hovered_building = hovered_building

        # 건물 표시 (미니 아이콘으로)
        for building in buildings.buildings:
            mx = minimap_x + building.x * scale_x
            my = minimap_y + building.y * scale_y
            mw = building.width * scale_x
            mh = building.height * scale_y
            color = building.info['color']

            # 호버 중인 건물은 하이라이트
            if hovered_building and building == hovered_building:
                highlight_rect = pygame.Rect(mx - 2, my - 2, mw + 4, mh + 4)
                pygame.draw.rect(screen, Colors.NEON_YELLOW, highlight_rect, 2, border_radius=2)

            # 건물 미니 아이콘 그리기
            self._draw_minimap_building_icon(screen, building, mx, my, mw, mh, self.minimap_expanded)

        # 플레이어 표시
        player_size = 6 if self.minimap_expanded else 4
        px = minimap_x + player.x * scale_x
        py = minimap_y + player.y * scale_y
        pygame.draw.circle(screen, Colors.NEON_GREEN, (int(px), int(py)), player_size)

        # 출구 표시
        exit_size = 5 if self.minimap_expanded else 3
        exit_pos = downtown_map.get_exit_pixel_pos()
        ex = minimap_x + exit_pos[0] * scale_x
        ey = minimap_y + exit_pos[1] * scale_y
        pulse = abs(math.sin(self.animation_timer * 3))
        pygame.draw.circle(screen, Colors.NEON_ORANGE, (int(ex), int(ey)), int(exit_size + 2 * pulse))

        # 확대 상태 표시 (M키 힌트)
        if not self.minimap_expanded:
            korean_font = self._get_korean_font(10)
            if korean_font:
                hint_surf, _ = korean_font.render("M", (150, 150, 150))
                screen.blit(hint_surf, (minimap_x + current_size - 15, minimap_y + 5))
        else:
            korean_font = self._get_korean_font(12)
            if korean_font:
                hint_surf, _ = korean_font.render("M키: 닫기", (150, 150, 150))
                screen.blit(hint_surf, (minimap_x + 5, minimap_y + current_size - 18))

        # 툴팁 그리기 (확대 상태에서 건물 호버 시)
        if self.minimap_expanded and hovered_building and mouse_pos:
            self._draw_minimap_tooltip(screen, hovered_building, mouse_pos)

    def _get_emoji_font(self, size=18):
        """이모지 지원 폰트 로드 (시스템 폰트 사용)"""
        cache_key = f'emoji_font_{size}'
        if not hasattr(self, '_font_cache'):
            self._font_cache = {}

        if cache_key in self._font_cache:
            return self._font_cache[cache_key]

        font = None
        import sys

        # 시스템별 이모지 지원 폰트
        if sys.platform == 'darwin':  # macOS
            emoji_fonts = [
                '/System/Library/Fonts/Apple Color Emoji.ttc',
                '/System/Library/Fonts/AppleSDGothicNeo.ttc',
                '/Library/Fonts/Arial Unicode.ttf',
            ]
        else:  # Windows
            emoji_fonts = [
                'C:/Windows/Fonts/seguiemj.ttf',  # Segoe UI Emoji
                'C:/Windows/Fonts/segoeui.ttf',
                'C:/Windows/Fonts/malgun.ttf',
            ]

        for font_path in emoji_fonts:
            try:
                if os.path.exists(font_path):
                    font = pygame.freetype.Font(font_path, size)
                    break
            except Exception:
                continue

        # 폴백: 기본 시스템 폰트
        if font is None:
            try:
                font = pygame.freetype.SysFont('Arial', size)
            except Exception:
                pass

        self._font_cache[cache_key] = font
        return font

    def _draw_minimap_tooltip(self, screen, building, mouse_pos):
        """미니맵에서 건물 호버 시 툴팁 표시"""
        if not building or not building.info:
            return

        # 폰트 크기 증가
        title_font = self._get_korean_font(18)  # 14 → 18
        desc_font = self._get_korean_font(14)   # 12 → 14
        emoji_font = self._get_emoji_font(20)   # 이모지용 폰트

        if not title_font:
            return

        building_info = building.info
        name = building_info.get('name', '???')
        description = building_info.get('description', '')
        color = building_info.get('color', Colors.NEON_CYAN)
        icon = building_info.get('icon', '')

        # 이름 렌더링 (이모지 없이)
        name_surf, name_rect = title_font.render(name, Colors.TEXT_WHITE)

        # 이모지 렌더링 (별도)
        icon_width = 0
        icon_surf = None
        if icon and emoji_font:
            try:
                icon_surf, icon_rect = emoji_font.render(icon, Colors.TEXT_WHITE)
                icon_width = icon_rect.width + 8  # 아이콘과 텍스트 사이 간격
            except Exception:
                icon_surf = None
                icon_width = 0

        # 설명이 길면 줄바꿈 (18자마다)
        desc_lines = []
        if description:
            words = description
            if len(words) > 18:
                for i in range(0, len(words), 18):
                    desc_lines.append(words[i:i+18])
            else:
                desc_lines.append(words)

        # 툴팁 크기 계산
        tooltip_width = max(name_rect.width + icon_width + 30, 220)
        tooltip_height = 45 + len(desc_lines) * 20

        # 툴팁 위치 (마우스 옆, 화면 밖으로 나가지 않게)
        tooltip_x = mouse_pos[0] + 15
        tooltip_y = mouse_pos[1] - tooltip_height - 10

        # 화면 경계 체크
        if tooltip_x + tooltip_width > SCREEN_WIDTH:
            tooltip_x = mouse_pos[0] - tooltip_width - 15
        if tooltip_y < 0:
            tooltip_y = mouse_pos[1] + 20

        # 툴팁 배경
        tooltip_surf = pygame.Surface((tooltip_width, tooltip_height), pygame.SRCALPHA)
        pygame.draw.rect(tooltip_surf, (20, 20, 40, 245),
                        (0, 0, tooltip_width, tooltip_height), border_radius=10)
        pygame.draw.rect(tooltip_surf, color,
                        (0, 0, tooltip_width, tooltip_height), 2, border_radius=10)
        screen.blit(tooltip_surf, (tooltip_x, tooltip_y))

        # 이모지 그리기
        text_start_x = tooltip_x + 12
        if icon_surf:
            screen.blit(icon_surf, (text_start_x, tooltip_y + 10))
            text_start_x += icon_width

        # 건물 이름
        screen.blit(name_surf, (text_start_x, tooltip_y + 12))

        # 설명
        desc_y = tooltip_y + 38
        if desc_font:
            for line in desc_lines:
                desc_surf, _ = desc_font.render(line, Colors.TEXT_GRAY)
                screen.blit(desc_surf, (tooltip_x + 12, desc_y))
                desc_y += 18

    def draw_interaction_hint(self, screen, building_info, font=None):
        """상호작용 힌트 UI (한글 폰트 지원)"""
        if not building_info:
            return

        # 한글 폰트 로드 (pygame.freetype 사용)
        korean_font = self._get_korean_font(18)

        # 패널 위치
        panel_width = 300
        panel_height = 100
        panel_x = SCREEN_WIDTH // 2 - panel_width // 2
        panel_y = SCREEN_HEIGHT - panel_height - 30

        # 배경
        panel_surf = pygame.Surface((panel_width, panel_height), pygame.SRCALPHA)
        pygame.draw.rect(panel_surf, (20, 20, 40, 230),
                        (0, 0, panel_width, panel_height), border_radius=15)

        # 테두리
        pygame.draw.rect(panel_surf, building_info.get('color', Colors.NEON_CYAN),
                        (0, 0, panel_width, panel_height), 3, border_radius=15)

        screen.blit(panel_surf, (panel_x, panel_y))

        # 건물 정보 (한글 폰트 사용)
        if korean_font:
            # 이름
            name_surf, name_rect = korean_font.render(building_info.get('name', '???'), Colors.TEXT_WHITE)
            screen.blit(name_surf, (panel_x + 20, panel_y + 15))

            # AP 비용 - 열쇠 아이콘 + 숫자
            ap_cost = building_info.get('ap_cost', 1)
            key_x = panel_x + panel_width - 55
            key_y = panel_y + 22
            self._draw_mini_key(screen, key_x, key_y, 14)
            # 숫자
            ap_num_surf, ap_num_rect = korean_font.render(f"x{ap_cost}", Colors.UI_ACCENT)
            screen.blit(ap_num_surf, (key_x + 12, panel_y + 13))

            # 설명
            desc = building_info.get('description', '')
            if len(desc) > 25:
                desc = desc[:25] + "..."
            desc_surf, desc_rect = korean_font.render(desc, Colors.TEXT_GRAY)
            screen.blit(desc_surf, (panel_x + 20, panel_y + 45))

            # 조작 힌트 (SPACE로 변경)
            hint_surf, hint_rect = korean_font.render("[SPACE] 입장", Colors.NEON_GREEN)
            screen.blit(hint_surf, (panel_x + panel_width // 2 - hint_rect.width // 2, panel_y + 70))

    def _get_korean_font(self, size=18):
        """한글 폰트 로드 (캐싱)"""
        cache_key = f'korean_font_{size}'
        if not hasattr(self, '_font_cache'):
            self._font_cache = {}

        if cache_key in self._font_cache:
            return self._font_cache[cache_key]

        font = None

        # 1차 시도: 네오둥근모 프로 픽셀 폰트
        try:
            pixel_font_path = resource_path("PFStardust.ttf")
            if os.path.exists(pixel_font_path):
                font = pygame.freetype.Font(pixel_font_path, size)
        except Exception:
            pass

        # 2차 시도: NanumSquare 폴백
        if font is None:
            try:
                font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
                if os.path.exists(font_path):
                    font = pygame.freetype.Font(font_path, size)
            except Exception:
                pass

        # 3차 시도: 시스템 폰트 (macOS/Windows)
        if font is None:
            try:
                # macOS
                if os.path.exists("/System/Library/Fonts/AppleSDGothicNeo.ttc"):
                    font = pygame.freetype.Font("/System/Library/Fonts/AppleSDGothicNeo.ttc", size)
                # Windows
                elif os.path.exists("C:/Windows/Fonts/malgun.ttf"):
                    font = pygame.freetype.Font("C:/Windows/Fonts/malgun.ttf", size)
            except Exception:
                pass

        # 4차 시도: 기본 폰트
        if font is None:
            try:
                font = pygame.freetype.SysFont("malgungothic", size)
            except Exception:
                font = pygame.freetype.SysFont(None, size)

        self._font_cache[cache_key] = font
        return font

    def _draw_mini_key(self, screen, x, y, size):
        """미니 열쇠 아이콘 그리기 (상호작용 힌트용)"""
        # 열쇠 서피스 생성 (세로로 긴 클래식 비율)
        key_w = int(size * 1.0)
        key_h = int(size * 2.0)
        key_surf = pygame.Surface((key_w, key_h), pygame.SRCALPHA)

        # 앤틱 브론즈/골드 색상
        bronze_main = (175, 140, 85)
        bronze_dark = (110, 85, 45)
        bronze_light = (210, 180, 120)
        bronze_edge = (90, 65, 30)

        cx = key_w // 2

        # 상단 8자형 고리 (간소화)
        loop_r = int(key_w * 0.30)
        loop_thickness = max(2, int(size * 0.12))
        loop_y = loop_r + 1

        # 왼쪽 고리
        left_loop_x = cx - int(loop_r * 0.5)
        pygame.draw.circle(key_surf, bronze_edge, (left_loop_x, loop_y), loop_r + 1, loop_thickness + 1)
        pygame.draw.circle(key_surf, bronze_main, (left_loop_x, loop_y), loop_r, loop_thickness)

        # 오른쪽 고리
        right_loop_x = cx + int(loop_r * 0.5)
        pygame.draw.circle(key_surf, bronze_edge, (right_loop_x, loop_y), loop_r + 1, loop_thickness + 1)
        pygame.draw.circle(key_surf, bronze_main, (right_loop_x, loop_y), loop_r, loop_thickness)

        # 열쇠 몸통
        shaft_w = int(key_w * 0.22)
        shaft_top = loop_y + loop_r - 1
        shaft_bottom = int(key_h * 0.75)
        shaft_x = cx - shaft_w // 2

        pygame.draw.rect(key_surf, bronze_edge, (shaft_x - 1, shaft_top, shaft_w + 2, shaft_bottom - shaft_top + 2))
        pygame.draw.rect(key_surf, bronze_main, (shaft_x, shaft_top, shaft_w, shaft_bottom - shaft_top))
        pygame.draw.line(key_surf, bronze_light, (shaft_x + 1, shaft_top + 2), (shaft_x + 1, shaft_bottom - 2), 1)

        # 열쇠 이빨
        teeth_y = shaft_bottom
        teeth_w = int(key_w * 0.35)
        teeth_h = int(key_h * 0.22)

        pygame.draw.rect(key_surf, bronze_edge, (shaft_x - 1, teeth_y, shaft_w + 2, teeth_h + 1))
        pygame.draw.rect(key_surf, bronze_main, (shaft_x, teeth_y, shaft_w, teeth_h))

        # 이빨
        tooth_y = teeth_y + int(teeth_h * 0.3)
        tooth_h = int(teeth_h * 0.4)
        pygame.draw.rect(key_surf, bronze_edge, (shaft_x + shaft_w - 1, tooth_y, teeth_w + 1, tooth_h))
        pygame.draw.rect(key_surf, bronze_main, (shaft_x + shaft_w, tooth_y, teeth_w, tooth_h - 1))

        screen.blit(key_surf, (x - key_w // 2, y - key_h // 2))

    def get_camera_offset(self):
        """카메라 오프셋 반환"""
        return (int(self.camera_x), int(self.camera_y))

    # ========================================================================
    # 고급 조명 시스템 메서드들
    # ========================================================================

    def add_light_source(self, x, y, radius, color, intensity=1.0, flicker=False):
        """동적 광원 추가"""
        if len(self.light_sources) >= self.max_light_sources:
            return None

        light = {
            'x': x,
            'y': y,
            'radius': radius,
            'color': color,
            'intensity': intensity,
            'flicker': flicker,
            'flicker_offset': random.random() * 10,
            'active': True
        }
        self.light_sources.append(light)
        return light

    def remove_light_source(self, light):
        """광원 제거"""
        if light in self.light_sources:
            self.light_sources.remove(light)

    def clear_light_sources(self):
        """모든 동적 광원 제거"""
        self.light_sources.clear()

    def update_lighting(self, dt, buildings=None):
        """조명 시스템 업데이트"""
        # 낮/밤 사이클 업데이트 (선택적)
        # self.day_night_cycle = (self.day_night_cycle + dt * self.day_night_speed) % 1.0

        # 광원 플리커 업데이트
        for light in self.light_sources:
            if light['flicker']:
                # 자연스러운 깜빡임 효과
                light['current_intensity'] = light['intensity'] * (
                    0.8 + 0.2 * math.sin(self.animation_timer * 8 + light['flicker_offset'])
                )
            else:
                light['current_intensity'] = light['intensity']

        # 건물에서 자동으로 광원 생성 (창문 불빛 등)
        if buildings:
            self._update_building_lights(buildings)

    def _update_building_lights(self, buildings):
        """건물 기반 자동 광원 생성"""
        # 기존 건물 광원 제거
        self.light_sources = [l for l in self.light_sources if not l.get('is_building_light')]

        # 각 건물에서 광원 생성
        for building in buildings.buildings:
            # 건물 중심에 약한 조명
            center_x = building.x + building.width // 2
            center_y = building.y + building.height // 2

            # 건물 타입에 따른 조명 색상
            light_color = self._get_building_light_color(building.building_type)

            light = {
                'x': center_x,
                'y': center_y,
                'radius': max(building.width, building.height) * 1.2,
                'color': light_color,
                'intensity': 0.6,
                'flicker': True,
                'flicker_offset': hash(str(building.x) + str(building.y)) % 100 / 10,
                'active': True,
                'is_building_light': True
            }
            self.light_sources.append(light)

    def _get_building_light_color(self, building_type):
        """건물 타입에 따른 조명 색상"""
        color_map = {
            'shop': (255, 220, 150),      # 따뜻한 상점 조명
            'blacksmith': (255, 150, 100), # 붉은 대장간 불빛
            'inn': (255, 200, 120),        # 아늑한 여관 조명
            'tavern': (255, 180, 100),     # 따뜻한 선술집
            'bank': (255, 230, 180),       # 고급스러운 금빛
            'arcade': (100, 200, 255),     # 네온 블루
            'gacha': (255, 180, 255),      # 화려한 핑크
            'mystery': (180, 100, 255),    # 신비로운 보라
            'elder': (255, 220, 100),      # 황금빛
        }
        return color_map.get(building_type, (255, 255, 200))

    def draw_lighting_layer(self, screen):
        """조명 레이어 렌더링 (메인 렌더링 후 호출)"""
        # 조명 서피스 생성
        if self.lighting_surface is None or self.lighting_surface.get_size() != screen.get_size():
            self.lighting_surface = pygame.Surface(screen.get_size(), pygame.SRCALPHA)

        # 기본 주변광으로 채우기 (어두운 레이어)
        darkness_level = 0.3 + self.day_night_cycle * 0.4
        ambient_r = int(self.ambient_light[0] * (1 - darkness_level))
        ambient_g = int(self.ambient_light[1] * (1 - darkness_level))
        ambient_b = int(self.ambient_light[2] * (1 - darkness_level))
        darkness_alpha = int(255 * darkness_level)

        self.lighting_surface.fill((ambient_r, ambient_g, ambient_b, darkness_alpha))

        # 각 광원에서 빛 그리기 (감산 블렌딩으로 어둠 제거)
        for light in self.light_sources:
            if not light.get('active', True):
                continue

            lx = light['x'] - self.camera_x
            ly = light['y'] - self.camera_y
            radius = light['radius']
            color = light['color']
            intensity = light.get('current_intensity', light['intensity'])

            # 화면 밖 체크
            if lx + radius < 0 or lx - radius > SCREEN_WIDTH:
                continue
            if ly + radius < 0 or ly - radius > SCREEN_HEIGHT:
                continue

            # 광원 서피스 (부드러운 원형 그라데이션)
            self._draw_light_gradient(self.lighting_surface, int(lx), int(ly),
                                     int(radius), color, intensity)

        # 글로벌 조명 적용 (부드러운 햇빛/달빛)
        self._apply_global_light()

        # 조명 레이어 블렌딩
        screen.blit(self.lighting_surface, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)

    def _draw_light_gradient(self, surface, x, y, radius, color, intensity):
        """부드러운 원형 그라데이션 광원"""
        light_surf = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)

        for r in range(radius, 0, -2):
            # 거리에 따른 감쇠 (부드러운 가장자리)
            falloff = (r / radius) ** 0.5
            alpha = int(255 * (1 - falloff) * intensity)

            # 색상 블렌딩
            light_color = (
                min(255, int(color[0] * intensity + 255 * (1 - intensity))),
                min(255, int(color[1] * intensity + 255 * (1 - intensity))),
                min(255, int(color[2] * intensity + 255 * (1 - intensity))),
                min(255, alpha + 128)
            )

            pygame.draw.circle(light_surf, light_color, (radius, radius), r)

        # 감산 블렌딩으로 어둠 제거
        surface.blit(light_surf, (x - radius, y - radius), special_flags=pygame.BLEND_RGBA_ADD)

    def _apply_global_light(self):
        """글로벌 조명 (태양/달) 적용"""
        # 화면 상단에서 오는 빛 그라데이션
        height = SCREEN_HEIGHT // 3
        for i in range(height):
            progress = i / height
            alpha = int(30 * (1 - progress) * self.global_light_intensity)
            color = (*self.global_light_color[:3], alpha)
            pygame.draw.line(self.lighting_surface, color, (0, i), (SCREEN_WIDTH, i))

    def draw_shadows(self, screen, buildings):
        """건물 그림자 렌더링"""
        if self.shadow_surface is None or self.shadow_surface.get_size() != screen.get_size():
            self.shadow_surface = pygame.Surface(screen.get_size(), pygame.SRCALPHA)

        self.shadow_surface.fill((0, 0, 0, 0))  # 투명 초기화

        # 그림자 방향 계산
        shadow_rad = math.radians(self.shadow_angle)
        shadow_dx = math.cos(shadow_rad) * self.shadow_length_multiplier
        shadow_dy = math.sin(shadow_rad) * self.shadow_length_multiplier

        for building in buildings.buildings:
            bx = building.x - self.camera_x
            by = building.y - self.camera_y
            bw = building.width
            bh = building.height

            # 그림자 길이 (건물 높이에 비례)
            shadow_len = bh * self.shadow_length_multiplier

            # 그림자 폴리곤 점들
            shadow_points = [
                (bx, by + bh),  # 건물 하단 좌
                (bx + bw, by + bh),  # 건물 하단 우
                (bx + bw + shadow_dx * shadow_len, by + bh + shadow_dy * shadow_len),  # 그림자 끝 우
                (bx + shadow_dx * shadow_len, by + bh + shadow_dy * shadow_len),  # 그림자 끝 좌
            ]

            # 부드러운 그림자 (여러 레이어)
            for layer in range(self.shadow_softness):
                offset = layer * 2
                alpha = int(40 / (layer + 1))
                expanded_points = [
                    (p[0] + (1 if i % 2 else -1) * offset,
                     p[1] + offset)
                    for i, p in enumerate(shadow_points)
                ]
                pygame.draw.polygon(self.shadow_surface, (0, 0, 0, alpha), expanded_points)

            # 메인 그림자
            pygame.draw.polygon(self.shadow_surface, (0, 0, 0, 60), shadow_points)

        # 그림자 레이어 블렌딩
        screen.blit(self.shadow_surface, (0, 0))

    def draw_fog_layer(self, screen):
        """대기 안개 효과"""
        if not self.fog_enabled:
            return

        fog_surface = pygame.Surface(screen.get_size(), pygame.SRCALPHA)

        # 바닥에서 위로 갈수록 옅어지는 안개
        fog_height = int(SCREEN_HEIGHT * 0.6)
        for i in range(fog_height):
            progress = i / fog_height
            alpha = int(self.fog_density * 255 * (1 - progress ** 2))
            y = SCREEN_HEIGHT - fog_height + i
            fog_color = (*self.fog_color, alpha)
            pygame.draw.line(fog_surface, fog_color, (0, y), (SCREEN_WIDTH, y))

        # 약간의 노이즈 추가
        for _ in range(50):
            nx = random.randint(0, SCREEN_WIDTH)
            ny = random.randint(SCREEN_HEIGHT - fog_height, SCREEN_HEIGHT)
            size = random.randint(20, 60)
            alpha = int(self.fog_density * 80 * random.random())
            fog_blob = pygame.Surface((size, size // 2), pygame.SRCALPHA)
            pygame.draw.ellipse(fog_blob, (*self.fog_color, alpha), (0, 0, size, size // 2))
            fog_surface.blit(fog_blob, (nx - size // 2, ny - size // 4))

        screen.blit(fog_surface, (0, 0))

    def draw_vignette(self, screen):
        """화면 가장자리 비네트 효과"""
        if not self.vignette_enabled:
            return

        vignette = pygame.Surface(screen.get_size(), pygame.SRCALPHA)

        # 가장자리에서 중심으로 갈수록 투명해지는 어둠
        cx, cy = SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2
        max_dist = math.sqrt(cx ** 2 + cy ** 2)

        # 효율적인 비네트 (원형 그라데이션)
        for ring in range(20, 0, -1):
            progress = ring / 20
            radius = int(max_dist * progress)
            alpha = int(self.vignette_intensity * 255 * (1 - progress) ** 2)

            if alpha > 0:
                pygame.draw.circle(vignette, (0, 0, 0, alpha), (cx, cy), radius, 10)

        # 코너 강화 (더 어두운 코너)
        corner_size = 150
        for corner_x, corner_y in [(0, 0), (SCREEN_WIDTH, 0),
                                   (0, SCREEN_HEIGHT), (SCREEN_WIDTH, SCREEN_HEIGHT)]:
            corner_surf = pygame.Surface((corner_size, corner_size), pygame.SRCALPHA)
            for i in range(corner_size):
                alpha = int(self.vignette_intensity * 150 * (1 - i / corner_size))
                pygame.draw.circle(corner_surf, (0, 0, 0, alpha),
                                 (corner_size // 2, corner_size // 2), corner_size - i)

            # 코너에 맞게 위치 조정
            blit_x = corner_x - corner_size // 2 if corner_x == 0 else corner_x - corner_size // 2
            blit_y = corner_y - corner_size // 2 if corner_y == 0 else corner_y - corner_size // 2
            vignette.blit(corner_surf, (blit_x, blit_y))

        screen.blit(vignette, (0, 0))

    def draw_bloom_effect(self, screen, bright_areas=None):
        """블룸 효과 (밝은 영역 글로우)"""
        if not self.bloom_enabled:
            return

        bloom_surface = pygame.Surface(screen.get_size(), pygame.SRCALPHA)

        # 광원 위치에 블룸 추가
        for light in self.light_sources:
            lx = int(light['x'] - self.camera_x)
            ly = int(light['y'] - self.camera_y)
            radius = int(light['radius'] * 0.5)
            color = light['color']
            intensity = light.get('current_intensity', light['intensity']) * self.bloom_intensity

            # 화면 밖 체크
            if lx + radius < 0 or lx - radius > SCREEN_WIDTH:
                continue
            if ly + radius < 0 or ly - radius > SCREEN_HEIGHT:
                continue

            # 부드러운 글로우
            for r in range(radius, 0, -5):
                alpha = int(30 * intensity * (r / radius))
                glow_color = (*color, alpha)
                pygame.draw.circle(bloom_surface, glow_color, (lx, ly), r)

        # 블룸 블렌딩 (가산)
        screen.blit(bloom_surface, (0, 0), special_flags=pygame.BLEND_RGBA_ADD)

    def draw_god_rays(self, screen):
        """신성한 빛줄기 효과 (갓레이)"""
        # 화면 상단에서 내려오는 빛줄기
        num_rays = 5
        ray_width = 30
        ray_alpha = 15

        ray_surface = pygame.Surface(screen.get_size(), pygame.SRCALPHA)

        for i in range(num_rays):
            # 빛줄기 위치 (천천히 이동)
            ray_x = (SCREEN_WIDTH * (i + 0.5) / num_rays +
                    math.sin(self.animation_timer * 0.3 + i) * 50)

            # 빛줄기 폴리곤
            top_x = ray_x + math.sin(self.animation_timer * 0.5 + i) * 20
            points = [
                (top_x - ray_width // 2, 0),
                (top_x + ray_width // 2, 0),
                (ray_x + ray_width, SCREEN_HEIGHT),
                (ray_x - ray_width, SCREEN_HEIGHT),
            ]

            # 그라데이션 빛줄기
            for layer in range(3):
                layer_alpha = ray_alpha - layer * 4
                layer_color = (255, 250, 200, max(0, layer_alpha))
                layer_width = ray_width + layer * 10
                layer_points = [
                    (top_x - layer_width // 2, 0),
                    (top_x + layer_width // 2, 0),
                    (ray_x + layer_width, SCREEN_HEIGHT),
                    (ray_x - layer_width, SCREEN_HEIGHT),
                ]
                pygame.draw.polygon(ray_surface, layer_color, layer_points)

        screen.blit(ray_surface, (0, 0), special_flags=pygame.BLEND_RGBA_ADD)

    def draw_spawn_exit_auras(self, screen, downtown_map):
        """스폰/출구 오오라 그리기 (별도 레이어 - 모든 타일 위에)"""
        # 화면에 보이는 타일만 렌더링
        start_tile_x = max(0, int(self.camera_x // TILE_SIZE))
        start_tile_y = max(0, int(self.camera_y // TILE_SIZE))
        end_tile_x = min(MAP_WIDTH, int((self.camera_x + SCREEN_WIDTH) // TILE_SIZE) + 2)
        end_tile_y = min(MAP_HEIGHT, int((self.camera_y + SCREEN_HEIGHT) // TILE_SIZE) + 2)

        for y in range(start_tile_y, end_tile_y):
            for x in range(start_tile_x, end_tile_x):
                tile_type = downtown_map.get_tile(x, y)
                screen_x = x * TILE_SIZE - int(self.camera_x)
                screen_y = y * TILE_SIZE - int(self.camera_y)

                if tile_type == TileType.SPAWN:
                    self._draw_spawn_aura(screen, screen_x, screen_y)
                elif tile_type == TileType.EXIT:
                    self._draw_exit_aura(screen, screen_x, screen_y)

    def _draw_spawn_aura(self, screen, x, y):
        """스폰 포인트 오오라 효과"""
        # 애니메이션 값
        pulse = abs(math.sin(self.animation_timer * 2))
        rotate_angle = self.animation_timer * 60  # 회전 애니메이션
        marker_size = int(TILE_SIZE * 0.7 + TILE_SIZE * 0.1 * pulse)

        center_x = x + TILE_SIZE // 2
        center_y = y + TILE_SIZE // 2

        # 1. 다층 글로우 효과
        for i in range(4):
            glow_size = marker_size + 25 - i * 5
            glow_alpha = int(40 + 20 * pulse) - i * 10
            glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
            glow_color = (50 + i * 30, 255 - i * 20, 100 + i * 20, max(0, glow_alpha))
            pygame.draw.circle(glow_surf, glow_color, (glow_size, glow_size), glow_size)
            screen.blit(glow_surf, (center_x - glow_size, center_y - glow_size))

        # 2. 회전하는 마법진 효과
        magic_surf = pygame.Surface((marker_size * 2, marker_size * 2), pygame.SRCALPHA)
        magic_center = marker_size

        # 외곽 원
        pygame.draw.circle(magic_surf, (*Colors.NEON_GREEN, 200),
                          (magic_center, magic_center), marker_size // 2, 2)

        # 내부 패턴 (회전하는 삼각형들)
        for i in range(3):
            angle = math.radians(rotate_angle + i * 120)
            inner_r = marker_size // 3
            px = magic_center + int(math.cos(angle) * inner_r)
            py = magic_center + int(math.sin(angle) * inner_r)
            pygame.draw.circle(magic_surf, (*Colors.NEON_GREEN, 180), (px, py), 3)

        # 중심 코어
        core_pulse = int(4 + 2 * pulse)
        pygame.draw.circle(magic_surf, Colors.NEON_GREEN, (magic_center, magic_center), core_pulse)
        pygame.draw.circle(magic_surf, (200, 255, 200), (magic_center, magic_center), core_pulse - 2)

        screen.blit(magic_surf, (center_x - marker_size, center_y - marker_size))

        # 3. 상승하는 파티클 효과
        for i in range(3):
            particle_y = (self.animation_timer * 30 + i * 15) % 25
            particle_alpha = int(150 * (1 - particle_y / 25))
            particle_x = center_x + int(math.sin(self.animation_timer * 3 + i) * 8)
            if particle_alpha > 0:
                particle_surf = pygame.Surface((4, 4), pygame.SRCALPHA)
                pygame.draw.circle(particle_surf, (*Colors.NEON_GREEN, particle_alpha), (2, 2), 2)
                screen.blit(particle_surf, (particle_x - 2, center_y - particle_y - 5))

    def _draw_exit_aura(self, screen, x, y):
        """출구 포인트 오오라 효과"""
        # 애니메이션 값
        pulse = abs(math.sin(self.animation_timer * 3))
        wave = math.sin(self.animation_timer * 4)
        arrow_color = Colors.NEON_ORANGE

        center_x = x + TILE_SIZE // 2
        center_y = y + TILE_SIZE // 2

        # 1. 다층 글로우 효과 (원형 웨이브)
        for i in range(3):
            wave_offset = (self.animation_timer * 2 + i * 0.5) % 1.0
            glow_size = int(TILE_SIZE * 0.4 + TILE_SIZE * 0.5 * wave_offset)
            glow_alpha = int(80 * (1 - wave_offset))
            if glow_alpha > 0:
                glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*arrow_color, glow_alpha),
                                 (glow_size, glow_size), glow_size, 2)
                screen.blit(glow_surf, (center_x - glow_size, center_y - glow_size))

        # 2. 중앙 글로우 베이스
        base_glow_size = int(TILE_SIZE * 0.6)
        base_glow = pygame.Surface((base_glow_size * 2, base_glow_size * 2), pygame.SRCALPHA)
        for r in range(base_glow_size, 0, -2):
            alpha = int(60 * (r / base_glow_size) * (0.7 + 0.3 * pulse))
            pygame.draw.circle(base_glow, (*arrow_color, alpha),
                             (base_glow_size, base_glow_size), r)
        screen.blit(base_glow, (center_x - base_glow_size, center_y - base_glow_size))

        # 3. 3D 화살표 (위쪽 방향 - 진행 방향)
        arrow_surf = pygame.Surface((TILE_SIZE, TILE_SIZE), pygame.SRCALPHA)
        arrow_center = TILE_SIZE // 2

        # 화살표 크기 (맥동)
        scale = 0.8 + 0.1 * pulse
        arrow_size = int(12 * scale)

        # 화살표 점 (위쪽 방향)
        arrow_points = [
            (arrow_center, arrow_center - arrow_size),  # 상단 꼭지점
            (arrow_center - arrow_size, arrow_center + 2),  # 좌하단
            (arrow_center - 4, arrow_center + 2),  # 좌하단 내부
            (arrow_center - 4, arrow_center + arrow_size),  # 좌하단 꼬리
            (arrow_center + 4, arrow_center + arrow_size),  # 우하단 꼬리
            (arrow_center + 4, arrow_center + 2),  # 우하단 내부
            (arrow_center + arrow_size, arrow_center + 2),  # 우하단
        ]

        # 그림자
        shadow_points = [(p[0] + 2, p[1] + 2) for p in arrow_points]
        pygame.draw.polygon(arrow_surf, (0, 0, 0, 80), shadow_points)

        # 메인 화살표
        pygame.draw.polygon(arrow_surf, arrow_color, arrow_points)

        # 하이라이트 (밝은 가장자리)
        highlight_color = tuple(min(255, c + 60) for c in arrow_color)
        pygame.draw.polygon(arrow_surf, highlight_color, arrow_points, 2)

        # 내부 광택
        inner_highlight = [
            (arrow_center, arrow_center - arrow_size + 4),
            (arrow_center - 3, arrow_center),
            (arrow_center + 3, arrow_center),
        ]
        pygame.draw.polygon(arrow_surf, (*highlight_color, 150), inner_highlight)

        screen.blit(arrow_surf, (x, y))

        # 4. 반짝이는 별 파티클
        for i in range(4):
            angle = self.animation_timer * 2 + i * (math.pi / 2)
            dist = 12 + 3 * wave
            star_x = center_x + int(math.cos(angle) * dist)
            star_y = center_y + int(math.sin(angle) * dist)
            star_alpha = int(100 + 80 * math.sin(self.animation_timer * 5 + i))
            star_surf = pygame.Surface((6, 6), pygame.SRCALPHA)
            # 4각 별
            pygame.draw.line(star_surf, (*Colors.TEXT_WHITE, star_alpha), (3, 0), (3, 6), 1)
            pygame.draw.line(star_surf, (*Colors.TEXT_WHITE, star_alpha), (0, 3), (6, 3), 1)
            screen.blit(star_surf, (star_x - 3, star_y - 3))

    def draw_post_processing(self, screen, buildings=None):
        """포스트 프로세싱 효과 일괄 적용"""
        # 1. 건물 그림자 (타일/건물 렌더링 후)
        if buildings:
            self.draw_shadows(screen, buildings)

        # 2. 조명 레이어
        self.draw_lighting_layer(screen)

        # 3. 블룸 효과
        self.draw_bloom_effect(screen)

        # 4. 안개
        self.draw_fog_layer(screen)

        # 5. 갓레이 (선택적)
        # self.draw_god_rays(screen)

        # 6. 비네트 (마지막)
        self.draw_vignette(screen)

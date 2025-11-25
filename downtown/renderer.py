# downtown/renderer.py
# 번화가 렌더링 시스템

import pygame
import math
import random
from .constants import (
    SCREEN_WIDTH, SCREEN_HEIGHT, TILE_SIZE,
    MAP_WIDTH, MAP_HEIGHT, TileType,
    Colors, PLANET_THEMES, PlanetTheme
)

class DowntownRenderer:
    """
    번화가 렌더링 시스템
    - 타일 맵 렌더링
    - 배경 및 파티클
    - UI 요소
    - 카메라 시스템
    """

    def __init__(self):
        # 카메라
        self.camera_x = 0
        self.camera_y = 0
        self.target_camera_x = 0
        self.target_camera_y = 0
        self.camera_smoothing = 0.1

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
        self.minimap_size = 150
        self.minimap_surface = None

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

        # 카메라 타겟 설정 (플레이어 중심)
        self.target_camera_x = player_x - SCREEN_WIDTH // 2
        self.target_camera_y = player_y - SCREEN_HEIGHT // 2

        # 카메라 경계 제한
        max_cam_x = MAP_WIDTH * TILE_SIZE - SCREEN_WIDTH
        max_cam_y = MAP_HEIGHT * TILE_SIZE - SCREEN_HEIGHT
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
        """파티클 업데이트"""
        for p in self.particles[:]:
            p['life'] -= dt
            p['x'] += p.get('vx', 0) * dt
            p['y'] += p.get('vy', 0) * dt

            if p['life'] <= 0:
                self.particles.remove(p)

        # 환경 파티클 추가
        if len(self.particles) < self.max_particles:
            particle_type = self.theme_data.get('particles', 'stars')
            self._spawn_environment_particle(particle_type)

    def _spawn_environment_particle(self, particle_type):
        """환경 파티클 생성"""
        if random.random() > 0.1:
            return

        particle = {
            'x': random.randint(0, SCREEN_WIDTH) + self.camera_x,
            'y': -10 + self.camera_y,
            'life': random.uniform(2, 5),
            'type': particle_type
        }

        if particle_type == 'neon_rain':
            particle['vy'] = random.uniform(100, 200)
            particle['vx'] = random.uniform(-10, 10)
            particle['color'] = random.choice([
                Colors.NEON_CYAN, Colors.NEON_PINK, Colors.NEON_PURPLE
            ])
            particle['length'] = random.randint(10, 30)

        elif particle_type == 'snow':
            particle['vy'] = random.uniform(30, 80)
            particle['vx'] = random.uniform(-20, 20)
            particle['color'] = (255, 255, 255)
            particle['size'] = random.randint(2, 5)

        elif particle_type == 'leaves':
            particle['vy'] = random.uniform(20, 50)
            particle['vx'] = random.uniform(-30, 30)
            particle['color'] = random.choice([
                (100, 180, 80), (150, 200, 100), (80, 150, 60)
            ])
            particle['rotation'] = random.uniform(0, 360)
            particle['rot_speed'] = random.uniform(-180, 180)

        elif particle_type == 'sand':
            particle['vy'] = random.uniform(10, 30)
            particle['vx'] = random.uniform(50, 100)
            particle['color'] = (194, 178, 128)
            particle['size'] = random.randint(1, 3)

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
            return  # 빈 타일은 건너뜀

        elif tile_type == TileType.GROUND:
            self._draw_ground_tile(screen, x, y)

        elif tile_type == TileType.ROAD:
            self._draw_road_tile(screen, x, y)

        elif tile_type == TileType.SPAWN:
            self._draw_spawn_tile(screen, x, y)

        elif tile_type == TileType.EXIT:
            self._draw_exit_tile(screen, x, y)

        elif tile_type == TileType.DECORATION:
            self._draw_ground_tile(screen, x, y)  # 바닥 먼저
            # 장식은 별도 레이어에서 처리

        elif tile_type == TileType.BUILDING:
            pass  # 건물은 별도 레이어에서 처리

    def _draw_ground_tile(self, screen, x, y):
        """바닥 타일 - RPG 스타일 잔디/흙 바닥"""
        color = self.theme_data['ground_color']

        # 타일 좌표 계산 (패턴용)
        tx = (x // TILE_SIZE) if TILE_SIZE > 0 else 0
        ty = (y // TILE_SIZE) if TILE_SIZE > 0 else 0

        # 기본 바닥색 (약간 어두운 톤)
        base_color = tuple(max(0, c - 15) for c in color)
        pygame.draw.rect(screen, base_color, (x, y, TILE_SIZE, TILE_SIZE))

        # 타일 패턴 (체크무늬 효과로 깊이감)
        if (tx + ty) % 2 == 0:
            lighter = tuple(min(255, c + 8) for c in base_color)
            pygame.draw.rect(screen, lighter, (x + 2, y + 2, TILE_SIZE - 4, TILE_SIZE - 4))

        # 잔디/돌 텍스처 점들
        random.seed(tx * 1000 + ty)  # 일관된 패턴
        for _ in range(3):
            dx = random.randint(4, TILE_SIZE - 4)
            dy = random.randint(4, TILE_SIZE - 4)
            dot_color = tuple(min(255, c + random.randint(-10, 15)) for c in color)
            pygame.draw.circle(screen, dot_color, (x + dx, y + dy), 1)

        # 부드러운 테두리 (어두운 톤)
        border_color = tuple(max(0, c - 25) for c in color)
        pygame.draw.rect(screen, border_color, (x, y, TILE_SIZE, TILE_SIZE), 1)

    def _draw_road_tile(self, screen, x, y):
        """도로 타일 - RPG 스타일 돌길/포장도로"""
        color = self.theme_data['road_color']

        # 타일 좌표
        tx = (x // TILE_SIZE) if TILE_SIZE > 0 else 0
        ty = (y // TILE_SIZE) if TILE_SIZE > 0 else 0

        # 밝은 도로 기본색 (일반 바닥보다 확실히 밝게)
        bright_color = tuple(min(255, c + 40) for c in color)
        pygame.draw.rect(screen, bright_color, (x, y, TILE_SIZE, TILE_SIZE))

        # 돌 포장 패턴 (벽돌 스타일)
        stone_dark = tuple(max(0, c - 10) for c in bright_color)
        stone_light = tuple(min(255, c + 15) for c in bright_color)

        # 가로 돌 패턴
        half = TILE_SIZE // 2
        if (tx + ty) % 2 == 0:
            # 패턴 A: 위아래 분할
            pygame.draw.rect(screen, stone_light, (x + 2, y + 2, TILE_SIZE - 4, half - 3))
            pygame.draw.rect(screen, stone_dark, (x + 2, y + half + 1, TILE_SIZE - 4, half - 3))
        else:
            # 패턴 B: 좌우 분할 + 중앙
            pygame.draw.rect(screen, stone_dark, (x + 2, y + 2, half - 3, TILE_SIZE - 4))
            pygame.draw.rect(screen, stone_light, (x + half + 1, y + 2, half - 3, TILE_SIZE - 4))

        # 돌 사이 틈 (어두운 선)
        gap_color = tuple(max(0, c - 30) for c in color)
        pygame.draw.line(screen, gap_color, (x, y + half), (x + TILE_SIZE, y + half), 1)
        pygame.draw.line(screen, gap_color, (x + half, y), (x + half, y + TILE_SIZE), 1)

        # 외곽 하이라이트 (위/왼쪽 밝게)
        highlight = tuple(min(255, c + 25) for c in bright_color)
        pygame.draw.line(screen, highlight, (x, y), (x + TILE_SIZE - 1, y), 1)
        pygame.draw.line(screen, highlight, (x, y), (x, y + TILE_SIZE - 1), 1)

        # 외곽 그림자 (아래/오른쪽 어둡게)
        shadow = tuple(max(0, c - 20) for c in color)
        pygame.draw.line(screen, shadow, (x, y + TILE_SIZE - 1), (x + TILE_SIZE, y + TILE_SIZE - 1), 1)
        pygame.draw.line(screen, shadow, (x + TILE_SIZE - 1, y), (x + TILE_SIZE - 1, y + TILE_SIZE), 1)

    def _draw_spawn_tile(self, screen, x, y):
        """스폰 타일"""
        # 기본 도로
        self._draw_road_tile(screen, x, y)

        # 스폰 마커
        pulse = abs(math.sin(self.animation_timer * 2))
        marker_size = int(TILE_SIZE * 0.6 + TILE_SIZE * 0.1 * pulse)

        center_x = x + TILE_SIZE // 2
        center_y = y + TILE_SIZE // 2

        # 글로우
        glow_surf = pygame.Surface((marker_size + 20, marker_size + 20), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*Colors.NEON_GREEN, 100),
                          (marker_size // 2 + 10, marker_size // 2 + 10),
                          marker_size // 2 + 10)
        screen.blit(glow_surf, (center_x - marker_size // 2 - 10,
                                center_y - marker_size // 2 - 10))

        # 마커
        pygame.draw.circle(screen, Colors.NEON_GREEN,
                          (center_x, center_y), marker_size // 2, 3)

    def _draw_exit_tile(self, screen, x, y):
        """출구 타일"""
        # 기본 도로
        self._draw_road_tile(screen, x, y)

        # 출구 마커 (화살표)
        pulse = abs(math.sin(self.animation_timer * 3))
        arrow_color = Colors.NEON_ORANGE

        center_x = x + TILE_SIZE // 2
        center_y = y + TILE_SIZE // 2

        # 글로우
        glow_size = int(TILE_SIZE * 0.8)
        glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*arrow_color, int(100 * pulse)),
                        (0, 0, glow_size, glow_size), border_radius=5)
        screen.blit(glow_surf, (center_x - glow_size // 2, center_y - glow_size // 2))

        # 화살표
        arrow_points = [
            (center_x + 15, center_y),
            (center_x - 5, center_y - 12),
            (center_x - 5, center_y - 5),
            (center_x - 15, center_y - 5),
            (center_x - 15, center_y + 5),
            (center_x - 5, center_y + 5),
            (center_x - 5, center_y + 12),
        ]
        pygame.draw.polygon(screen, arrow_color, arrow_points)
        pygame.draw.polygon(screen, Colors.TEXT_WHITE, arrow_points, 2)

    def draw_particles(self, screen):
        """파티클 그리기"""
        for p in self.particles:
            px = p['x'] - self.camera_x
            py = p['y'] - self.camera_y

            # 화면 밖이면 건너뜀
            if px < -50 or px > SCREEN_WIDTH + 50 or py < -50 or py > SCREEN_HEIGHT + 50:
                continue

            alpha = min(255, int(255 * (p['life'] / 3)))

            if p['type'] == 'neon_rain':
                # 네온 비
                color = (*p['color'], alpha)
                end_y = py + p['length']
                pygame.draw.line(screen, color[:3], (px, py), (px, end_y), 2)

            elif p['type'] == 'snow':
                # 눈
                surf = pygame.Surface((p['size'] * 2, p['size'] * 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, (*p['color'], alpha),
                                 (p['size'], p['size']), p['size'])
                screen.blit(surf, (px - p['size'], py - p['size']))

            elif p['type'] == 'leaves':
                # 나뭇잎
                surf = pygame.Surface((10, 6), pygame.SRCALPHA)
                pygame.draw.ellipse(surf, (*p['color'], alpha), (0, 0, 10, 6))
                rotated = pygame.transform.rotate(surf, p['rotation'])
                screen.blit(rotated, (px - 5, py - 3))
                p['rotation'] += p['rot_speed'] * 0.016

            elif p['type'] == 'sand':
                # 모래
                pygame.draw.circle(screen, p['color'], (int(px), int(py)), p['size'])

    def draw_minimap(self, screen, downtown_map, player, buildings):
        """미니맵 그리기"""
        minimap_x = SCREEN_WIDTH - self.minimap_size - 20
        minimap_y = 20

        # 미니맵 배경
        minimap_rect = pygame.Rect(minimap_x, minimap_y,
                                   self.minimap_size, self.minimap_size)
        pygame.draw.rect(screen, (20, 20, 40, 200), minimap_rect, border_radius=10)
        pygame.draw.rect(screen, Colors.NEON_CYAN, minimap_rect, 2, border_radius=10)

        # 스케일 계산
        scale_x = self.minimap_size / (MAP_WIDTH * TILE_SIZE)
        scale_y = self.minimap_size / (MAP_HEIGHT * TILE_SIZE)

        # 도로 표시
        for y in range(MAP_HEIGHT):
            for x in range(MAP_WIDTH):
                tile = downtown_map.get_tile(x, y)
                if tile == TileType.ROAD:
                    mx = minimap_x + x * TILE_SIZE * scale_x
                    my = minimap_y + y * TILE_SIZE * scale_y
                    pygame.draw.rect(screen, (80, 80, 100),
                                   (mx, my, TILE_SIZE * scale_x, TILE_SIZE * scale_y))

        # 건물 표시
        for building in buildings.buildings:
            mx = minimap_x + building.x * scale_x
            my = minimap_y + building.y * scale_y
            mw = building.width * scale_x
            mh = building.height * scale_y
            color = building.info['color']
            pygame.draw.rect(screen, color, (mx, my, mw, mh))

        # 플레이어 표시
        px = minimap_x + player.x * scale_x
        py = minimap_y + player.y * scale_y
        pygame.draw.circle(screen, Colors.NEON_GREEN, (int(px), int(py)), 4)

        # 출구 표시
        exit_pos = downtown_map.get_exit_pixel_pos()
        ex = minimap_x + exit_pos[0] * scale_x
        ey = minimap_y + exit_pos[1] * scale_y
        pulse = abs(math.sin(self.animation_timer * 3))
        pygame.draw.circle(screen, Colors.NEON_ORANGE, (int(ex), int(ey)), int(3 + 2 * pulse))

    def draw_interaction_hint(self, screen, building_info, font):
        """상호작용 힌트 UI"""
        if not building_info:
            return

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

        # 건물 정보
        if font:
            # 이름
            name_text = font.render(building_info.get('name', '???'), True, Colors.TEXT_WHITE)
            screen.blit(name_text, (panel_x + 20, panel_y + 15))

            # AP 비용
            ap_cost = building_info.get('ap_cost', 1)
            ap_text = font.render(f"AP: {ap_cost}", True, Colors.UI_ACCENT)
            screen.blit(ap_text, (panel_x + panel_width - 80, panel_y + 15))

            # 설명
            desc = building_info.get('description', '')
            if len(desc) > 35:
                desc = desc[:35] + "..."
            desc_text = font.render(desc, True, Colors.TEXT_GRAY)
            screen.blit(desc_text, (panel_x + 20, panel_y + 45))

            # 조작 힌트
            hint_text = font.render("[Z] 입장", True, Colors.NEON_GREEN)
            screen.blit(hint_text, (panel_x + panel_width // 2 - 30, panel_y + 70))

    def get_camera_offset(self):
        """카메라 오프셋 반환"""
        return (int(self.camera_x), int(self.camera_y))

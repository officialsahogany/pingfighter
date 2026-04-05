# -*- coding: utf-8 -*-
"""
네메시스 해상전투 필러 배경
- 게임 내 실제 스테이지 5 (네메시스) = 코드 상 current_stage == 6
- 게임 화면 주변을 바다/해군 전함 테마로 장식
- 게임 맵의 해수면(game_height // 2)과 일치하도록 설계
"""

import math
import random
import pygame


class NemesisOceanFrame:
    """네메시스 해상전투 스타일 필러 배경 - 게임 맵 해수면과 연동"""

    # 색상 팔레트 (메인 배경 AnimatedBackgroundStage6와 통일)
    COLORS = {
        # 하늘: 폭풍 황혼 (메인 배경과 동일)
        'sky_top': (15, 20, 45),            # 깊은 네이비
        'sky_mid': (40, 35, 65),            # 인디고-퍼플
        'horizon_color': (180, 120, 60),    # 머금은 앰버 노을
        # 바다: 깊고 위협적 (메인 배경과 동일)
        'ocean_surface': (10, 40, 80),      # 다크 네이비
        'ocean_deep': (5, 15, 40),          # 심연
        'wave_foam': (180, 200, 220),       # 차가운 흰 거품
        # 파도 톤
        'wave': (15, 50, 90),               # 어두운 파도
        'wave_light': (25, 70, 110),        # 약간 밝은 파도
        'foam': (140, 170, 190),            # 물거품
        'white_foam': (180, 200, 215),      # 차가운 거품
        # 전함 금속 (더 어둡게)
        'metal': (55, 60, 75),
        'metal_light': (75, 80, 95),
        'metal_dark': (30, 35, 50),
        'gold_trim': (140, 110, 60),
        'cyan_glow': (0, 180, 220),         # 시안 (메인 배경과 동일)
        'cyan_dim': (0, 80, 110),           # 어두운 시안
        # 표시등
        'red_light': (200, 50, 40),
        'green_light': (50, 160, 70),
        'radar_green': (40, 200, 80),
    }

    def __init__(self, screen_width: int, screen_height: int,
                 game_width: int, game_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        # 게임 영역 위치
        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        # 해수면 위치 계산 (게임 영역 내 중앙 = game_height // 2)
        # 전체 화면에서의 해수면 Y 좌표
        self.horizon_y = self.game_y + game_height // 2

        # 애니메이션
        self.time = 0.0

        # 파도 효과
        self.waves = []
        self._create_waves()

        # 물거품 파티클
        self.foam_particles = []

        # 구름
        self.clouds = []
        self._create_clouds()

        # 레이더 스캔 각도
        self.radar_angle = 0

        # 경고등 상태
        self.warning_flash = 0

        # 캐시된 프레임
        self._frame_surface = None
        self._create_frame()

        # === 성능 최적화: 캐시 ===
        # 구름 Surface 캐시 (크기별)
        self._cloud_cache = {}
        # 파도 Surface 캐시 (좌/우 필러)
        self._wave_cache_left = None
        self._wave_cache_right = None
        self._wave_cache_phase = 0
        self._wave_update_interval = 6  # 6프레임마다 파도 업데이트 (성능 최적화: 3→6)

    def _create_waves(self):
        """파도 레이어 생성 (성능 최적화: 5→3 레이어)"""
        # 해수면 아래에 파도 레이어 생성
        for i in range(3):
            self.waves.append({
                'y_offset': i * 45,  # 간격 증가 (30→45)
                'amplitude': random.uniform(5, 15),
                'frequency': random.uniform(0.01, 0.03),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(0.02, 0.04)
            })

    def _create_clouds(self):
        """구름 생성 (성능 최적화: 6→4개)"""
        for _ in range(4):
            self.clouds.append({
                'x': random.randint(0, self.screen_width),
                'y': random.randint(20, max(self.horizon_y - 100, 21)),
                'size': random.randint(30, 70),
                'speed': random.uniform(0.05, 0.2),
                'opacity': random.randint(40, 80)
            })

    def _create_frame(self):
        """프레임 생성"""
        self._frame_surface = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        # 하늘 + 바다 배경 (해수면 기준)
        self._draw_sky_ocean_background(self._frame_surface)

        # 전함 금속 테두리
        self._draw_metal_border(self._frame_surface)

        # 리벳/볼트 장식
        self._draw_rivets(self._frame_surface)

        # 게임 영역 주변 장갑판
        self._draw_armor_plates(self._frame_surface)

        # 전함 디테일
        self._draw_ship_details(self._frame_surface)

    def _draw_sky_ocean_background(self, surface: pygame.Surface):
        """하늘 + 바다 배경 (게임 맵 해수면과 일치, 메인 배경과 동일 팔레트)"""
        sky_top = self.COLORS['sky_top']
        sky_mid = self.COLORS['sky_mid']
        horizon_color = self.COLORS['horizon_color']
        ocean_surface = self.COLORS['ocean_surface']
        ocean_deep = self.COLORS['ocean_deep']

        # === 하늘 2단계 그라데이션 (메인 배경과 동일 구조) ===
        mid_y = self.horizon_y // 2
        # 상단: sky_top → sky_mid
        for y in range(0, mid_y, 2):
            f = y / max(mid_y - 1, 1)
            color = tuple(int(sky_top[c] + (sky_mid[c] - sky_top[c]) * f) for c in range(3))
            pygame.draw.line(surface, (*color, 255), (0, y), (self.screen_width, y), 2)
        # 하단: sky_mid → horizon_color
        for y in range(mid_y, self.horizon_y, 2):
            f = (y - mid_y) / max(self.horizon_y - mid_y - 1, 1)
            color = tuple(int(sky_mid[c] + (horizon_color[c] - sky_mid[c]) * f) for c in range(3))
            pygame.draw.line(surface, (*color, 255), (0, y), (self.screen_width, y), 2)

        # === 바다 그라데이션 (해수면에서 아래로) ===
        ocean_height = self.screen_height - self.horizon_y
        for y in range(self.horizon_y, self.screen_height, 2):
            f = (y - self.horizon_y) / max(ocean_height - 1, 1)
            color = tuple(int(ocean_surface[c] + (ocean_deep[c] - ocean_surface[c]) * f) for c in range(3))
            pygame.draw.line(surface, (*color, 255), (0, y), (self.screen_width, y), 2)

        # === 수평선 강조 ===
        pygame.draw.line(surface, (*horizon_color, 255),
                        (0, self.horizon_y), (self.screen_width, self.horizon_y), 3)
        # 수평선 글로우
        for i in range(1, 4):
            alpha = 100 - i * 25
            pygame.draw.line(surface, (*horizon_color, alpha),
                           (0, self.horizon_y - i), (self.screen_width, self.horizon_y - i), 1)
            pygame.draw.line(surface, (*ocean_surface, alpha),
                           (0, self.horizon_y + i), (self.screen_width, self.horizon_y + i), 1)

        # 게임 영역은 투명하게
        game_rect = pygame.Rect(self.game_x, self.game_y, self.game_width, self.game_height)
        pygame.draw.rect(surface, (0, 0, 0, 0), game_rect)

    def _draw_metal_border(self, surface: pygame.Surface):
        """전함 금속 테두리"""
        border_width = 12
        metal = self.COLORS['metal']
        metal_light = self.COLORS['metal_light']
        metal_dark = self.COLORS['metal_dark']

        # 외곽 금속 프레임
        for i in range(border_width):
            t = i / border_width
            if t < 0.2:
                color = metal_dark
            elif t < 0.6:
                color = metal
            elif t < 0.8:
                color = metal_light
            else:
                color = metal

            rect = pygame.Rect(i, i, self.screen_width - i * 2, self.screen_height - i * 2)
            pygame.draw.rect(surface, (*color, 255), rect, 1)

        # 사이버펑크 네온 라인
        cyan = self.COLORS['cyan_glow']
        pygame.draw.rect(surface, (*cyan, 150),
                        pygame.Rect(4, 4, self.screen_width - 8, self.screen_height - 8), 2)

    def _draw_rivets(self, surface: pygame.Surface):
        """리벳/볼트 장식"""
        metal_light = self.COLORS['metal_light']
        metal_dark = self.COLORS['metal_dark']

        rivet_spacing = 35
        rivet_size = 3

        # 상하 리벳
        for x in range(rivet_spacing, self.screen_width - rivet_spacing, rivet_spacing):
            # 상단
            pygame.draw.circle(surface, (*metal_dark, 255), (x, 7), rivet_size)
            pygame.draw.circle(surface, (*metal_light, 200), (x - 1, 6), rivet_size - 1)
            # 하단
            pygame.draw.circle(surface, (*metal_dark, 255), (x, self.screen_height - 7), rivet_size)
            pygame.draw.circle(surface, (*metal_light, 200), (x - 1, self.screen_height - 8), rivet_size - 1)

        # 좌우 리벳
        for y in range(rivet_spacing, self.screen_height - rivet_spacing, rivet_spacing):
            # 좌측
            pygame.draw.circle(surface, (*metal_dark, 255), (7, y), rivet_size)
            pygame.draw.circle(surface, (*metal_light, 200), (6, y - 1), rivet_size - 1)
            # 우측
            pygame.draw.circle(surface, (*metal_dark, 255), (self.screen_width - 7, y), rivet_size)
            pygame.draw.circle(surface, (*metal_light, 200), (self.screen_width - 8, y - 1), rivet_size - 1)

    def _draw_armor_plates(self, surface: pygame.Surface):
        """게임 영역 주변 장갑판"""
        margin = 10
        plate_width = 6

        metal = self.COLORS['metal']
        metal_light = self.COLORS['metal_light']
        metal_dark = self.COLORS['metal_dark']
        cyan = self.COLORS['cyan_glow']

        inner_rect = pygame.Rect(
            self.game_x - margin - plate_width,
            self.game_y - margin - plate_width,
            self.game_width + (margin + plate_width) * 2,
            self.game_height + (margin + plate_width) * 2
        )

        # 장갑판 그라데이션
        for i in range(plate_width):
            t = i / plate_width
            if t < 0.3:
                color = metal_light
            elif t < 0.7:
                color = metal
            else:
                color = metal_dark

            rect = inner_rect.inflate(-i * 2, -i * 2)
            pygame.draw.rect(surface, (*color, 255), rect, 1)

        # 사이버펑크 글로우 테두리
        pygame.draw.rect(surface, (*cyan, 180), inner_rect, 2)

        # 모서리 볼트
        bolt_positions = [
            (inner_rect.left + 8, inner_rect.top + 8),
            (inner_rect.right - 8, inner_rect.top + 8),
            (inner_rect.left + 8, inner_rect.bottom - 8),
            (inner_rect.right - 8, inner_rect.bottom - 8),
        ]

        for bx, by in bolt_positions:
            pygame.draw.circle(surface, (*metal_dark, 255), (bx, by), 5)
            pygame.draw.circle(surface, (*metal_light, 220), (bx - 1, by - 1), 3)
            pygame.draw.circle(surface, (*cyan, 200), (bx, by), 2)

    def _draw_ship_details(self, surface: pygame.Surface):
        """전함 디테일"""
        if self.game_x < 50:
            return

        # 좌측 컨트롤 패널
        self._draw_control_panel(surface, 15, self.game_y + 40, 'left')

        # 우측 컨트롤 패널
        self._draw_control_panel(surface, self.screen_width - 15, self.game_y + 40, 'right')

        # 레이더 제거됨 (좌측 하단)
        # if self.game_x > 80:
        #     self._draw_radar_display(surface, self.game_x // 2,
        #                             self.game_y + self.game_height - 70)

    def _draw_control_panel(self, surface: pygame.Surface, x: int, y: int, side: str):
        """컨트롤 패널"""
        panel_width = min(45, self.game_x - 25)
        panel_height = 120

        if side == 'right':
            x = x - panel_width

        metal = self.COLORS['metal']
        metal_dark = self.COLORS['metal_dark']
        cyan = self.COLORS['cyan_glow']

        # 패널 배경
        panel_rect = pygame.Rect(x, y, panel_width, panel_height)
        pygame.draw.rect(surface, (*metal_dark, 230), panel_rect)
        pygame.draw.rect(surface, (*cyan, 150), panel_rect, 1)

        # 표시등들
        light_colors = [
            self.COLORS['red_light'],
            self.COLORS['green_light'],
            self.COLORS['cyan_glow'],
        ]

        for i, color in enumerate(light_colors):
            ly = y + 18 + i * 22
            lx = x + panel_width // 2

            pygame.draw.circle(surface, (*metal_dark, 255), (lx, ly), 7)
            pygame.draw.circle(surface, (*color, 150), (lx, ly), 5)

        # 게이지 바
        gauge_y = y + 90
        gauge_width = panel_width - 12
        pygame.draw.rect(surface, (*metal_dark, 255),
                        (x + 6, gauge_y, gauge_width, 10))
        pygame.draw.rect(surface, (*cyan, 180),
                        (x + 8, gauge_y + 2, int(gauge_width * 0.7), 6))

    def _draw_radar_display(self, surface: pygame.Surface, cx: int, cy: int):
        """레이더 디스플레이"""
        radar_size = min(50, self.game_x // 2 - 15)

        metal_dark = self.COLORS['metal_dark']
        radar_green = self.COLORS['radar_green']

        # 레이더 배경
        pygame.draw.circle(surface, (*metal_dark, 250), (cx, cy), radar_size)
        pygame.draw.circle(surface, (20, 40, 30, 255), (cx, cy), radar_size - 3)

        # 레이더 그리드
        for r in range(1, 4):
            pygame.draw.circle(surface, (*radar_green, 40), (cx, cy),
                             int(radar_size * r / 4), 1)

        # 십자선
        pygame.draw.line(surface, (*radar_green, 60),
                        (cx - radar_size + 4, cy), (cx + radar_size - 4, cy), 1)
        pygame.draw.line(surface, (*radar_green, 60),
                        (cx, cy - radar_size + 4), (cx, cy + radar_size - 4), 1)

        # 테두리
        pygame.draw.circle(surface, (*self.COLORS['cyan_glow'], 200), (cx, cy), radar_size, 2)

    def _draw_animated_clouds(self, surface: pygame.Surface):
        """구름 애니메이션 (최적화: 캐시 사용)"""
        for cloud in self.clouds:
            # 하늘 영역에만 (해수면 위)
            if cloud['y'] < self.horizon_y - 20:
                # 캐시된 구름 Surface 가져오기
                cloud_surf = self._get_cached_cloud(cloud['size'], cloud['opacity'])
                surface.blit(cloud_surf, (int(cloud['x']), int(cloud['y'])))

    def _get_cached_cloud(self, size: int, opacity: int) -> pygame.Surface:
        """캐시된 구름 Surface 반환"""
        # 크기 버킷팅 (10px 단위)
        size_bucket = (size // 10) * 10
        # 투명도 버킷팅 (20 단위)
        opacity_bucket = (opacity // 20) * 20
        cache_key = (size_bucket, opacity_bucket)

        if cache_key in self._cloud_cache:
            return self._cloud_cache[cache_key]

        # 새 구름 Surface 생성
        cloud_surface = pygame.Surface((size_bucket * 2, size_bucket), pygame.SRCALPHA)
        for i in range(3):
            cx = size_bucket // 2 + i * size_bucket // 3
            cy = size_bucket // 2
            radius = size_bucket // 3
            pygame.draw.circle(cloud_surface, (255, 255, 255, opacity_bucket),
                             (cx, cy), radius)

        # 캐시 크기 제한
        if len(self._cloud_cache) > 50:
            self._cloud_cache.clear()

        self._cloud_cache[cache_key] = cloud_surface
        return cloud_surface

    def _draw_animated_waves(self, surface: pygame.Surface):
        """애니메이션 파도 효과 (최적화: 간격 증가 + 캐시)"""
        # 프레임 카운터 업데이트
        if not hasattr(self, '_wave_frame_counter'):
            self._wave_frame_counter = 0
        self._wave_frame_counter += 1

        # 파도 캐시 업데이트 필요 여부
        need_update = (self._wave_frame_counter % self._wave_update_interval == 0 or
                      self._wave_cache_left is None)

        if need_update:
            self._update_wave_cache()

        # 캐시된 파도 블릿
        if self._wave_cache_left is not None and self.game_x > 20:
            surface.blit(self._wave_cache_left, (0, self.horizon_y))
        if self._wave_cache_right is not None:
            right_start = self.game_x + self.game_width
            surface.blit(self._wave_cache_right, (right_start, self.horizon_y))

    def _update_wave_cache(self):
        """파도 캐시 업데이트"""
        ocean_surface = self.COLORS['ocean_surface']
        wave_foam = self.COLORS['wave_foam']

        # 파도가 그려지는 Y 범위 계산
        max_y_offset = max(w['y_offset'] + w['amplitude'] for w in self.waves) + 20
        wave_height = int(max_y_offset) + 30

        # 좌측 파도 캐시
        if self.game_x > 20:
            if self._wave_cache_left is None:
                self._wave_cache_left = pygame.Surface((self.game_x, wave_height), pygame.SRCALPHA)
            self._wave_cache_left.fill((0, 0, 0, 0))

            for wave in self.waves:
                y_base = wave['y_offset']
                # 간격을 20px로 늘림 (성능 최적화: 10 → 20)
                for x in range(0, self.game_x - 10, 20):
                    y = y_base + wave['amplitude'] * math.sin(x * wave['frequency'] + wave['phase'])
                    pygame.draw.circle(self._wave_cache_left, (*ocean_surface, 60),
                                     (x, int(y)), 8)  # 간격 증가에 따라 크기도 약간 증가

        # 우측 파도 캐시
        right_start = self.game_x + self.game_width
        right_width = self.screen_width - right_start
        if right_width > 20:
            if self._wave_cache_right is None:
                self._wave_cache_right = pygame.Surface((right_width, wave_height), pygame.SRCALPHA)
            self._wave_cache_right.fill((0, 0, 0, 0))

            for wave in self.waves:
                y_base = wave['y_offset']
                # 간격을 20px로 늘림 (성능 최적화: 10 → 20)
                for x in range(10, right_width, 20):
                    y = y_base + wave['amplitude'] * math.sin((x + right_start) * wave['frequency'] + wave['phase'])
                    pygame.draw.circle(self._wave_cache_right, (*ocean_surface, 60),
                                     (x, int(y)), 8)  # 간격 증가에 따라 크기도 약간 증가

    def _draw_foam_particles(self, surface: pygame.Surface):
        """물거품 파티클"""
        for foam in self.foam_particles:
            alpha = int(foam['alpha'])
            if alpha > 0:
                pygame.draw.circle(surface, (*self.COLORS['white_foam'], alpha),
                                 (int(foam['x']), int(foam['y'])), foam['size'])

    def _draw_radar_sweep(self, surface: pygame.Surface):
        """레이더 스윕 효과"""
        if self.game_x < 80:
            return

        cx = self.game_x // 2
        cy = self.game_y + self.game_height - 70
        radar_size = min(50, self.game_x // 2 - 15)

        # 스윕 잔상
        for i in range(8):
            angle = self.radar_angle - i * 0.06
            ex = cx + int(math.cos(angle) * (radar_size - 4))
            ey = cy + int(math.sin(angle) * (radar_size - 4))
            alpha = 120 - i * 15
            if alpha > 0:
                pygame.draw.line(surface, (*self.COLORS['radar_green'], alpha),
                               (cx, cy), (ex, ey), max(1, 2 - i // 4))

    def _draw_warning_lights(self, surface: pygame.Surface):
        """경고등 깜빡임 (성능 최적화: 6→4개)"""
        if self.game_x < 50:
            return

        flash = self.warning_flash > 0.5

        # 좌측 경고등 (2개로 축소)
        lx = 15 + min(45, self.game_x - 25) // 2
        for i in range(2):
            ly = self.game_y + 40 + 18 + i * 28

            if i == 0:
                color = self.COLORS['red_light'] if flash else (80, 30, 30)
            else:
                color = self.COLORS['green_light']

            pygame.draw.circle(surface, (*color, 255), (lx, ly), 4)

        # 우측 경고등 (2개로 축소)
        rx = self.screen_width - 15 - min(45, self.game_x - 25) // 2
        for i in range(2):
            ry = self.game_y + 40 + 18 + i * 28

            if i == 0:
                color = self.COLORS['red_light'] if flash else (80, 30, 30)
            else:
                color = self.COLORS['green_light']

            pygame.draw.circle(surface, (*color, 255), (rx, ry), 4)

    def _spawn_foam(self):
        """물거품 생성 (해수면 아래에서만, 성능 최적화: 0.02→0.01, 25→12)"""
        if random.random() < 0.01 and len(self.foam_particles) < 12:
            if self.game_x > 20:
                # 좌측 또는 우측 필러에서 생성
                if random.random() < 0.5:
                    x = random.randint(5, self.game_x - 15)
                else:
                    x = random.randint(self.game_x + self.game_width + 15, self.screen_width - 5)

                # 해수면 아래에서만 생성
                y = random.randint(self.horizon_y + 20, self.screen_height - 20)

                self.foam_particles.append({
                    'x': x,
                    'y': y,
                    'vx': random.uniform(-0.2, 0.2),
                    'vy': random.uniform(-0.8, -0.2),  # 위로 떠오름
                    'size': random.randint(2, 4),
                    'alpha': random.randint(80, 150),
                    'decay': random.uniform(0.3, 1.0),
                })

    def update(self, dt: float):
        """업데이트"""
        self.time += dt

        # 파도 업데이트
        for wave in self.waves:
            wave['phase'] += wave['speed']

        # 구름 업데이트
        for cloud in self.clouds:
            cloud['x'] += cloud['speed']
            if cloud['x'] > self.screen_width + cloud['size']:
                cloud['x'] = -cloud['size']
                cloud['y'] = random.randint(20, max(self.horizon_y - 100, 21))

        # 레이더 회전 제거됨
        # self.radar_angle += dt * 2
        # if self.radar_angle > math.pi * 2:
        #     self.radar_angle -= math.pi * 2

        # 경고등 깜빡임
        self.warning_flash += dt
        if self.warning_flash > 1.0:
            self.warning_flash = 0

        # 물거품 파티클
        self._spawn_foam()
        for foam in self.foam_particles[:]:
            foam['x'] += foam['vx']
            foam['y'] += foam['vy']
            foam['alpha'] -= foam['decay']

            # 해수면에 도달하면 제거
            if foam['alpha'] <= 0 or foam['y'] < self.horizon_y:
                self.foam_particles.remove(foam)

    def draw(self, surface: pygame.Surface):
        """전체 렌더링"""
        # 캐시된 프레임
        if self._frame_surface:
            surface.blit(self._frame_surface, (0, 0))

        # 구름 애니메이션
        self._draw_animated_clouds(surface)

        # 파도 애니메이션
        self._draw_animated_waves(surface)

        # 물거품 파티클
        self._draw_foam_particles(surface)

        # 레이더 스윕 제거됨
        # self._draw_radar_sweep(surface)

        # 경고등 깜빡임
        self._draw_warning_lights(surface)

        # 게임 영역 테두리 글로우
        self._draw_game_border_glow(surface)

    def _draw_game_border_glow(self, surface: pygame.Surface):
        """게임 영역 테두리 글로우 효과 (성능 최적화: 2→1 레이어)"""
        pulse = int(15 + 8 * math.sin(self.time * 1.5))
        cyan = self.COLORS['cyan_glow']

        if pulse > 0:
            rect = pygame.Rect(
                self.game_x - 10,
                self.game_y - 10,
                self.game_width + 20,
                self.game_height + 20
            )
            pygame.draw.rect(surface, (*cyan, pulse), rect, 1)

    def resize(self, screen_width: int, screen_height: int,
               game_width: int, game_height: int):
        """화면 크기 변경 - 치수 업데이트 + 캐시/요소 재생성"""
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2
        self.horizon_y = self.game_y + game_height // 2

        # 동적 요소 재생성
        self.waves.clear()
        self._create_waves()
        self.foam_particles.clear()
        self.clouds.clear()
        self._create_clouds()

        # 캐시 초기화
        self._cloud_cache.clear()
        self._wave_cache_left = None
        self._wave_cache_right = None

        # 정적 프레임 재생성
        self._frame_surface = None
        self._create_frame()

    def trigger_excitement(self, level: float = 1.5):
        """효과 트리거 (득점 시) - 확률 게이트 우회하여 즉시 스폰"""
        count = int(12 * level)
        for _ in range(count):
            self._spawn_foam_forced()

    def _spawn_foam_forced(self):
        """확률 조건 없이 물거품 즉시 생성"""
        if len(self.foam_particles) >= 30:  # 버스트용 상한
            return
        if self.game_x <= 20:
            return
        if random.random() < 0.5:
            x = random.randint(5, self.game_x - 15)
        else:
            x = random.randint(self.game_x + self.game_width + 15,
                              self.screen_width - 5)
        self.foam_particles.append({
            'x': x,
            'y': random.randint(self.horizon_y + 20, self.screen_height - 20),
            'vx': random.uniform(-0.3, 0.3),
            'vy': random.uniform(-1.2, -0.3),
            'size': random.randint(2, 5),
            'alpha': random.randint(100, 200),
            'decay': random.uniform(0.5, 1.5),
        })


# 호환성을 위한 클래스 별칭
Stage5PillarBackground = NemesisOceanFrame


# 전역 인스턴스
_nemesis_ocean_bg = None


def init_nemesis_ocean_background(screen_width: int, screen_height: int,
                                   game_width: int, game_height: int) -> NemesisOceanFrame:
    global _nemesis_ocean_bg
    _nemesis_ocean_bg = NemesisOceanFrame(screen_width, screen_height, game_width, game_height)
    return _nemesis_ocean_bg


def get_nemesis_ocean_background() -> NemesisOceanFrame:
    return _nemesis_ocean_bg

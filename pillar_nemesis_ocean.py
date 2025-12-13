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

    # 게임 맵과 동일한 색상 팔레트
    COLORS = {
        # 하늘 색상 (게임 맵과 동일)
        'sky_blue': (135, 206, 235),        # 하늘색
        'horizon_color': (255, 200, 150),   # 수평선 노을색
        # 바다 색상 (게임 맵과 동일)
        'ocean_surface': (0, 119, 190),     # 바다 표면
        'ocean_deep': (0, 80, 140),         # 바다 깊은 부분
        'wave_foam': (255, 255, 255),       # 파도 거품
        # 추가 색상
        'wave': (45, 100, 160),             # 파도색
        'wave_light': (75, 140, 200),       # 밝은 파도
        'foam': (200, 230, 245),            # 물거품
        'white_foam': (240, 248, 255),      # 하얀 거품
        # 전함 금속
        'metal': (80, 90, 105),
        'metal_light': (120, 130, 145),
        'metal_dark': (50, 55, 65),
        'gold_trim': (180, 150, 80),
        'cyan_glow': (0, 200, 220),         # 네온 청록색
        # 표시등
        'red_light': (180, 60, 60),
        'green_light': (60, 180, 80),
        'radar_green': (50, 255, 100),
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

    def _create_waves(self):
        """파도 레이어 생성"""
        # 해수면 아래에 파도 레이어 생성
        for i in range(5):
            self.waves.append({
                'y_offset': i * 30,  # 해수면 기준 오프셋
                'amplitude': random.uniform(5, 15),
                'frequency': random.uniform(0.01, 0.03),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(0.02, 0.04)
            })

    def _create_clouds(self):
        """구름 생성"""
        for _ in range(6):
            self.clouds.append({
                'x': random.randint(0, self.screen_width),
                'y': random.randint(20, self.horizon_y - 100),
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
        """하늘 + 바다 배경 (게임 맵 해수면과 일치)"""
        sky_blue = self.COLORS['sky_blue']
        horizon_color = self.COLORS['horizon_color']
        ocean_surface = self.COLORS['ocean_surface']
        ocean_deep = self.COLORS['ocean_deep']

        # === 하늘 그라데이션 (위에서 해수면까지) ===
        for y in range(0, self.horizon_y, 2):
            factor = y / max(1, self.horizon_y)
            # 하늘색에서 수평선 색으로 그라데이션
            color = (
                int(sky_blue[0] + (horizon_color[0] - sky_blue[0]) * factor),
                int(sky_blue[1] + (horizon_color[1] - sky_blue[1]) * factor),
                int(sky_blue[2] + (horizon_color[2] - sky_blue[2]) * factor),
                255
            )
            pygame.draw.line(surface, color, (0, y), (self.screen_width, y), 2)

        # === 바다 그라데이션 (해수면에서 아래로) ===
        ocean_height = self.screen_height - self.horizon_y
        for y in range(self.horizon_y, self.screen_height, 2):
            factor = (y - self.horizon_y) / max(1, ocean_height)
            color = (
                int(ocean_surface[0] + (ocean_deep[0] - ocean_surface[0]) * factor),
                int(ocean_surface[1] + (ocean_deep[1] - ocean_surface[1]) * factor),
                int(ocean_surface[2] + (ocean_deep[2] - ocean_surface[2]) * factor),
                255
            )
            pygame.draw.line(surface, color, (0, y), (self.screen_width, y), 2)

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

        # 레이더 (좌측 하단)
        if self.game_x > 80:
            self._draw_radar_display(surface, self.game_x // 2,
                                    self.game_y + self.game_height - 70)

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
        """구름 애니메이션"""
        for cloud in self.clouds:
            # 하늘 영역에만 (해수면 위)
            if cloud['y'] < self.horizon_y - 20:
                cloud_surface = pygame.Surface((cloud['size'] * 2, cloud['size']), pygame.SRCALPHA)
                # 구름 모양
                for i in range(3):
                    cx = cloud['size'] // 2 + i * cloud['size'] // 3
                    cy = cloud['size'] // 2
                    radius = cloud['size'] // 3
                    pygame.draw.circle(cloud_surface, (255, 255, 255, cloud['opacity']),
                                     (cx, cy), radius)
                surface.blit(cloud_surface, (int(cloud['x']), int(cloud['y'])))

    def _draw_animated_waves(self, surface: pygame.Surface):
        """애니메이션 파도 효과 (해수면 아래)"""
        ocean_surface = self.COLORS['ocean_surface']
        wave_foam = self.COLORS['wave_foam']

        for wave in self.waves:
            wave_y = self.horizon_y + wave['y_offset']

            # 필러 영역에만 그리기
            if self.game_x > 20:
                # 좌측 필러
                for x in range(0, self.game_x - 10, 5):
                    y = wave_y + wave['amplitude'] * math.sin(x * wave['frequency'] + wave['phase'])
                    pygame.draw.circle(surface, (*ocean_surface, 60),
                                     (x, int(y)), 6)
                    # 거품
                    if random.random() < 0.05:
                        pygame.draw.circle(surface, (*wave_foam, 80),
                                         (x, int(y) - 3), 2)

                # 우측 필러
                for x in range(self.game_x + self.game_width + 10, self.screen_width, 5):
                    y = wave_y + wave['amplitude'] * math.sin(x * wave['frequency'] + wave['phase'])
                    pygame.draw.circle(surface, (*ocean_surface, 60),
                                     (x, int(y)), 6)
                    if random.random() < 0.05:
                        pygame.draw.circle(surface, (*wave_foam, 80),
                                         (x, int(y) - 3), 2)

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
        """경고등 깜빡임"""
        if self.game_x < 50:
            return

        flash = self.warning_flash > 0.5

        # 좌측 경고등
        lx = 15 + min(45, self.game_x - 25) // 2
        for i in range(3):
            ly = self.game_y + 40 + 18 + i * 22

            if i == 0:
                color = self.COLORS['red_light'] if flash else (80, 30, 30)
            elif i == 1:
                color = self.COLORS['green_light']
            else:
                color = self.COLORS['cyan_glow'] if not flash else (0, 100, 110)

            pygame.draw.circle(surface, (*color, 255), (lx, ly), 4)

        # 우측 경고등
        rx = self.screen_width - 15 - min(45, self.game_x - 25) // 2
        for i in range(3):
            ry = self.game_y + 40 + 18 + i * 22

            if i == 0:
                color = self.COLORS['red_light'] if flash else (80, 30, 30)
            elif i == 1:
                color = self.COLORS['green_light']
            else:
                color = self.COLORS['cyan_glow'] if not flash else (0, 100, 110)

            pygame.draw.circle(surface, (*color, 255), (rx, ry), 4)

    def _spawn_foam(self):
        """물거품 생성 (해수면 아래에서만)"""
        if random.random() < 0.02 and len(self.foam_particles) < 25:
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
                cloud['y'] = random.randint(20, self.horizon_y - 100)

        # 레이더 회전
        self.radar_angle += dt * 2
        if self.radar_angle > math.pi * 2:
            self.radar_angle -= math.pi * 2

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

        # 레이더 스윕
        self._draw_radar_sweep(surface)

        # 경고등 깜빡임
        self._draw_warning_lights(surface)

        # 게임 영역 테두리 글로우
        self._draw_game_border_glow(surface)

    def _draw_game_border_glow(self, surface: pygame.Surface):
        """게임 영역 테두리 글로우 효과"""
        pulse = int(15 + 8 * math.sin(self.time * 1.5))
        cyan = self.COLORS['cyan_glow']

        for i in range(2):
            alpha = pulse - i * 6
            if alpha > 0:
                rect = pygame.Rect(
                    self.game_x - 10 - i,
                    self.game_y - 10 - i,
                    self.game_width + 20 + i * 2,
                    self.game_height + 20 + i * 2
                )
                pygame.draw.rect(surface, (*cyan, alpha), rect, 1)

    def resize(self, screen_width: int, screen_height: int,
               game_width: int, game_height: int):
        """화면 크기 변경"""
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2
        self.horizon_y = self.game_y + game_height // 2

        self.waves = []
        self._create_waves()
        self.foam_particles = []
        self.clouds = []
        self._create_clouds()

        self._frame_surface = None
        self._create_frame()

    def trigger_excitement(self, level: float = 1.5):
        """효과 트리거 (득점 시)"""
        for _ in range(int(12 * level)):
            self._spawn_foam()


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

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
        """리벳/볼트 장식 (일부 빠진/손상된 리벳으로 비대칭 질감)"""
        ml = self.COLORS['metal_light']
        md = self.COLORS['metal_dark']
        sp = 35
        r = 3

        # 손상 패턴용 시드 (일관된 비대칭)
        damage_seed = 42

        # 상하 리벳
        idx = 0
        for x in range(sp, self.screen_width - sp, sp):
            idx += 1
            # 우측 상단 일부 리벳 빠짐 (손상 표현)
            skip = ((idx * damage_seed) % 17 == 0)
            if not skip:
                pygame.draw.circle(surface, (*md, 255), (x, 7), r)
                pygame.draw.circle(surface, (*ml, 200), (x - 1, 6), r - 1)
            else:
                # 빠진 리벳 자국 (어두운 홈)
                pygame.draw.circle(surface, (20, 22, 35, 150), (x, 7), r - 1)

            pygame.draw.circle(surface, (*md, 255), (x, self.screen_height - 7), r)
            pygame.draw.circle(surface, (*ml, 200), (x - 1, self.screen_height - 8), r - 1)

        # 좌우 리벳
        idx = 0
        for y in range(sp, self.screen_height - sp, sp):
            idx += 1
            # 좌측: 정상
            pygame.draw.circle(surface, (*md, 255), (7, y), r)
            pygame.draw.circle(surface, (*ml, 200), (6, y - 1), r - 1)
            # 우측: 일부 손상
            skip = ((idx * damage_seed) % 13 == 0)
            if not skip:
                pygame.draw.circle(surface, (*md, 255), (self.screen_width - 7, y), r)
                pygame.draw.circle(surface, (*ml, 200), (self.screen_width - 8, y - 1), r - 1)
            else:
                pygame.draw.circle(surface, (20, 22, 35, 150), (self.screen_width - 7, y), r - 1)

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
        """전함 외장 구조물 디테일"""
        if self.game_x < 50:
            return

        pw = min(45, self.game_x - 25)

        # 좌측: 장갑 해치 (정상 상태)
        self._draw_armor_hatch(surface, 15, self.game_y + 30, pw, 'left')
        # 좌측 하단: 정비 포트
        self._draw_maintenance_port(surface, 15, self.game_y + self.game_height - 100, pw)

        # 우측: 장갑 해치 (손상 상태 - 메인 배경의 파손 타워와 연결)
        self._draw_armor_hatch(surface, self.screen_width - 15 - pw,
                              self.game_y + 30, pw, 'right')
        # 우측 하단: 손상된 패널
        self._draw_damaged_panel(surface, self.screen_width - 15 - pw,
                                self.game_y + self.game_height - 120, pw)

        # 좌우 장갑판 이음새 (수평 용접선)
        self._draw_hull_seams(surface)

    def _draw_armor_hatch(self, surface, x, y, pw, side):
        """장갑 해치 - 전함 외장 정비구 스타일"""
        md = self.COLORS['metal_dark']
        ml = self.COLORS['metal_light']
        m = self.COLORS['metal']
        cyan = self.COLORS['cyan_glow']

        hatch_h = 80
        # 해치 본체 (어두운 금속판)
        rect = pygame.Rect(x, y, pw, hatch_h)
        pygame.draw.rect(surface, (*md, 220), rect)
        # 해치 테두리 (밝은 엣지 - 볼록 효과)
        pygame.draw.rect(surface, (*m, 200), rect, 1)
        # 상단 밝은 엣지 (빛 받는 면)
        pygame.draw.line(surface, (*ml, 160),
                        (x + 1, y + 1), (x + pw - 1, y + 1), 1)

        # 볼트 4개 (모서리)
        for bx, by in [(x + 5, y + 5), (x + pw - 5, y + 5),
                       (x + 5, y + hatch_h - 5), (x + pw - 5, y + hatch_h - 5)]:
            pygame.draw.circle(surface, (*md, 255), (bx, by), 3)
            pygame.draw.circle(surface, (*ml, 180), (bx, by - 1), 2)

        # 중앙 수평 이음새 (해치 분할선)
        mid_y = y + hatch_h // 2
        pygame.draw.line(surface, (*md, 255), (x + 3, mid_y), (x + pw - 3, mid_y), 1)
        pygame.draw.line(surface, (*ml, 80), (x + 3, mid_y + 1), (x + pw - 3, mid_y + 1), 1)

        # 경고등 1개 (작은, 해치 상단 중앙)
        pygame.draw.circle(surface, (*md, 255), (x + pw // 2, y + 18), 4)
        light_color = self.COLORS['red_light'] if side == 'right' else self.COLORS['green_light']
        pygame.draw.circle(surface, (*light_color, 120), (x + pw // 2, y + 18), 3)

        # 우측 해치에만 손상 흔적 (메인 배경 파손 타워와 연결)
        if side == 'right':
            # 대각선 스크래치
            pygame.draw.line(surface, (*ml, 60),
                           (x + 8, y + 25), (x + pw - 10, y + hatch_h - 15), 1)
            # 작은 찌그러짐 (어두운 점)
            pygame.draw.circle(surface, (20, 22, 35, 80), (x + pw // 3, y + 50), 3)

    def _draw_maintenance_port(self, surface, x, y, pw):
        """정비 포트 - 작은 원형 해치"""
        md = self.COLORS['metal_dark']
        ml = self.COLORS['metal_light']
        m = self.COLORS['metal']

        port_r = min(pw // 3, 12)
        cx = x + pw // 2
        cy = y + port_r + 5

        # 외곽 링
        pygame.draw.circle(surface, (*m, 200), (cx, cy), port_r + 3)
        pygame.draw.circle(surface, (*md, 230), (cx, cy), port_r)
        # 볼트 링 (4개)
        for angle_deg in [0, 90, 180, 270]:
            bx = cx + int(math.cos(math.radians(angle_deg)) * (port_r + 1))
            by = cy + int(math.sin(math.radians(angle_deg)) * (port_r + 1))
            pygame.draw.circle(surface, (*ml, 150), (bx, by), 2)
        # 십자 마크
        pygame.draw.line(surface, (*ml, 60),
                        (cx - port_r + 3, cy), (cx + port_r - 3, cy), 1)
        pygame.draw.line(surface, (*ml, 60),
                        (cx, cy - port_r + 3), (cx, cy + port_r - 3), 1)

    def _draw_damaged_panel(self, surface, x, y, pw):
        """손상된 외장 패널 (우측 하단 - 전투 손상 표현)"""
        md = self.COLORS['metal_dark']
        ml = self.COLORS['metal_light']

        panel_h = 60
        rect = pygame.Rect(x, y, pw, panel_h)
        pygame.draw.rect(surface, (*md, 200), rect)
        pygame.draw.rect(surface, (20, 25, 38, 180), rect, 1)

        # 비대칭 스크래치 3개
        pygame.draw.line(surface, (*ml, 40),
                        (x + 5, y + 10), (x + pw - 8, y + 25), 1)
        pygame.draw.line(surface, (*ml, 30),
                        (x + 12, y + 30), (x + pw - 5, y + 42), 1)
        pygame.draw.line(surface, (25, 20, 35, 50),
                        (x + 3, y + 45), (x + 20, y + 52), 1)

        # 찌그러진 패널 이음새 (비뚤어진 수평선)
        pygame.draw.line(surface, (*md, 150),
                        (x + 2, y + panel_h // 2 - 2),
                        (x + pw - 2, y + panel_h // 2 + 1), 1)

        # 물때/녹 흔적 (어두운 점들)
        for dx, dy in [(8, 48), (15, 38), (pw - 12, 50)]:
            pygame.draw.circle(surface, (18, 25, 30, 40), (x + dx, y + dy), 2)

    def _draw_hull_seams(self, surface):
        """좌우 필러 질감 (규칙적 구조선 대신 비대칭 풍화/재료감)"""
        md = self.COLORS['metal_dark']
        ml = self.COLORS['metal_light']
        lx_end = self.game_x - 18
        rx_start = self.game_x + self.game_width + 18
        rx_end = self.screen_width - 3

        # --- 수평 이음새 (2개만, 매우 희미하게 - 장갑판 경계 암시) ---
        for ratio in [0.33, 0.67]:
            sy = int(self.screen_height * ratio)
            # 좌측 (전폭이 아닌 부분적 이음새)
            seg_end = lx_end - random.randint(5, 15)
            pygame.draw.line(surface, (*md, 20), (8, sy), (seg_end, sy), 1)
            # 우측
            seg_start = rx_start + random.randint(3, 10)
            pygame.draw.line(surface, (*md, 20), (seg_start, sy), (rx_end - 5, sy), 1)

        # --- 수직 분할선 제거 (디버그 그리드처럼 보이므로) ---

        # --- 좌측 풍화 질감 (해수면 근처 물때 - 불규칙 간격) ---
        for dy in [0, 6, 15, 22, 33]:
            wy = self.horizon_y + 8 + dy
            # 불규칙한 시작/끝 (전폭 안 채움)
            wx1 = 5 + (dy * 3) % 12
            wx2 = lx_end - 8 - (dy * 7) % 15
            wa = max(8, 18 - dy // 3)
            pygame.draw.line(surface, (8, 30, 50, wa), (wx1, wy), (wx2, wy), 1)

        # --- 우측 풍화 질감 (더 진한 물때 + 비대칭 스크래치) ---
        for dy in [0, 5, 12, 18, 28, 38]:
            wy = self.horizon_y + 6 + dy
            wx1 = rx_start + 3 + (dy * 5) % 10
            wx2 = rx_end - 5 - (dy * 3) % 12
            wa = max(10, 22 - dy // 3)
            pygame.draw.line(surface, (8, 25, 45, wa), (wx1, wy), (wx2, wy), 1)

        # 우측에 비대칭 대각선 스크래치 2개 (선체 긁힘)
        pygame.draw.line(surface, (*ml, 12),
                        (rx_start + 10, self.horizon_y - 40),
                        (rx_start + 25, self.horizon_y - 10), 1)
        pygame.draw.line(surface, (*ml, 8),
                        (rx_end - 20, self.horizon_y + 60),
                        (rx_end - 8, self.horizon_y + 90), 1)

    def _draw_animated_clouds(self, surface: pygame.Surface):
        """구름 애니메이션 (최적화: 캐시 사용)"""
        for cloud in self.clouds:
            # 하늘 영역에만 (해수면 위)
            if cloud['y'] < self.horizon_y - 20:
                # 캐시된 구름 Surface 가져오기
                cloud_surf = self._get_cached_cloud(cloud['size'], cloud['opacity'])
                surface.blit(cloud_surf, (int(cloud['x']), int(cloud['y'])))

    def _get_cached_cloud(self, size: int, opacity: int) -> pygame.Surface:
        """캐시된 구름 Surface 반환 (메인 배경과 동일한 어두운 폭풍구름 스타일)"""
        sb = (size // 10) * 10
        ob = min((opacity // 20) * 20, 40)  # 투명도 상한 낮춤 (더 은은하게)
        key = (sb, ob)

        if key in self._cloud_cache:
            return self._cloud_cache[key]

        # 길쭉한 타원 구름 (둥근 원 3개 → 어두운 타원, 메인 배경과 동일)
        cw = sb * 2
        ch = max(sb // 2, 10)  # 높이를 절반으로 (길쭉하게)
        cloud_surface = pygame.Surface((cw + 10, ch + 6), pygame.SRCALPHA)
        # 외곽 어두운 타원
        pygame.draw.ellipse(cloud_surface, (20, 20, 30, ob),
                          (3, 2, cw, ch))
        # 내부 약간 밝은 코어
        inner_w = cw * 2 // 3
        inner_x = 3 + (cw - inner_w) // 2
        pygame.draw.ellipse(cloud_surface, (30, 30, 45, ob // 2),
                          (inner_x, 4, inner_w, ch - 4))

        if len(self._cloud_cache) > 50:
            self._cloud_cache.clear()
        self._cloud_cache[key] = cloud_surface
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
        """해치 위 경고등 깜빡임 (장갑 해치의 상태등과 연동)"""
        if self.game_x < 50:
            return

        flash = self.warning_flash > 0.5
        pw = min(45, self.game_x - 25)

        # 좌측 해치 경고등 (녹색 = 정상)
        lx = 15 + pw // 2
        ly = self.game_y + 48
        color = self.COLORS['green_light'] if flash else (25, 60, 30)
        pygame.draw.circle(surface, (*color, 200), (lx, ly), 3)

        # 우측 해치 경고등 (적색 = 손상, 점멸)
        rx = self.screen_width - 15 - pw // 2
        ry = self.game_y + 48
        color = self.COLORS['red_light'] if flash else (60, 20, 15)
        pygame.draw.circle(surface, (*color, 200), (rx, ry), 3)

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

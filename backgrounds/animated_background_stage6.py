# -*- coding: utf-8 -*-
"""
스테이지 6 배경 (실제 스테이지 5 네메시스): 바다 위 사이버펑크 아레나
해상 전투 경기장 - 폭풍우 치는 황혼 바다 위 다층 데크 스타디움

렌더링 스택 (뒤→앞):
  1.  하늘 그라데이션    - 폭풍 황혼 (네이비→인디고→앰버)
  2.  원거리 함선 실루엣  - 수평선 위 희미한 군함들
  3.  구름              - 어둡고 불길한 먹구름
  4.  수평선 안개        - 하늘/바다 분리 대기 효과
  5.  바다 그라데이션    - 깊은 인디고 바다
  6.  배경 파도          - 작고 먼 파도 레이어
  7.  플랫폼 그림자      - 수면 위 어두운 타원
  8.  플로팅 아레나      - 다층 데크 + 안테나 타워 사이버펑크 스타디움
  9.  레이더 스윕        - 중앙 안테나에서 회전하는 스캔 빔
  10. 홀로그램 스캔라인  - 수평 간섭 라인
  11. 불꽃 라인          - 미드필드 불타는 라인 + 파티클 (절제된)
  12. 전경 파도          - 크고 가까운 파도 (깊이감 분리)
  13. 테두리            - 얇은 네온 트림 (비침습적)

성능: 모든 그라데이션 numpy 캐시, 서피스 사전 할당,
실루엣 사전 렌더링, 파티클 글로우 모듈 LRU 캐시.
"""

import pygame
import pygame.surfarray
import math
import random
import numpy as np
from collections import OrderedDict

# ============================================================
# Surface 캐시 시스템 (OrderedDict LRU)
# ============================================================
_surface_cache = OrderedDict()

def _get_cached_surface(width: int, height: int) -> pygame.Surface:
    """LRU 캐시에서 초기화된 SRCALPHA Surface 반환"""
    key = (width, height)
    if key not in _surface_cache:
        if len(_surface_cache) > 100:
            _surface_cache.popitem(last=False)  # 가장 오래된 것만 제거
        _surface_cache[key] = pygame.Surface((width, height), pygame.SRCALPHA)
    else:
        _surface_cache.move_to_end(key)  # 사용된 항목을 최신으로 갱신
    surface = _surface_cache[key]
    surface.fill((0, 0, 0, 0))
    return surface

# 화면 크기 - config에서 가져오기
try:
    from config.constants import PILLAR_UI_WIDTH, GAME_PLAY_WIDTH, SCREEN_HEIGHT
    PILLAR_OFFSET = PILLAR_UI_WIDTH  # 80px
    GAME_WIDTH = GAME_PLAY_WIDTH  # 600px
    HEIGHT = SCREEN_HEIGHT  # 750px
except ImportError:
    PILLAR_OFFSET = 80
    GAME_WIDTH = 600
    HEIGHT = 750


class AnimatedBackgroundStage6:
    """
    스테이지 5 네메시스 배경 (리디자인)

    디자인 목표:
      - 강한 중심 실루엣 (다층 데크 아레나, 평면 직사각형 아님)
      - 3레이어 깊이감: 전경 파도 / 중경 아레나 / 배경 하늘
      - 서사적 긴장감: 원거리 군함, 레이더 스윕, 홀로그램 글리치
      - 배경을 압도하지 않는 절제된 테두리
      - 시안 네온은 포인트만, 플랫폼 본체는 다크 건메탈
    """

    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.time = 0
        self.cx = width // 2       # 중앙 x
        self.cy = height // 2      # 중앙 y (미드필드)

        # ------------------------------------------------------------------
        #  색상 팔레트 (더 어둡고 드라마틱)
        # ------------------------------------------------------------------
        # 하늘: 폭풍 황혼
        self.sky_top = (15, 20, 45)           # 깊은 네이비
        self.sky_mid = (40, 35, 65)           # 인디고-퍼플
        self.horizon_color = (180, 120, 60)   # 머금은 앰버 노을
        # 바다: 깊고 위협적
        self.ocean_surface = (10, 40, 80)     # 다크 네이비
        self.ocean_deep = (5, 15, 40)         # 심연
        self.wave_foam = (180, 200, 220)      # 차가운 흰 거품
        # 네온 악센트 (절제해서 사용)
        self.cyan_accent = (0, 180, 220)      # 시안 (엣지만)
        self.cyan_dim = (0, 80, 110)          # 어두운 시안 (보조)
        # 플랫폼 본체
        self.gunmetal = (30, 35, 50)          # 다크 건메탈
        self.gunmetal_light = (45, 50, 65)    # 밝은 건메탈 (상층 데크)
        self.gunmetal_edge = (55, 60, 75)     # 엣지 하이라이트
        # 불꽃 (톤 다운)
        self.fire_colors = [
            (255, 100, 50),   # 밝은 주황
            (255, 80, 30),    # 진한 주황
            (200, 60, 20),    # 붉은 주황
            (150, 40, 10),    # 어두운 빨강
        ]

        # ------------------------------------------------------------------
        #  사전 할당 서피스
        # ------------------------------------------------------------------
        self._glow_surface = pygame.Surface((width, height), pygame.SRCALPHA)
        self._wave_surface = pygame.Surface((width, 50), pygame.SRCALPHA)
        self._fg_wave_surface = pygame.Surface((width, 60), pygame.SRCALPHA)
        self._shadow_surface = pygame.Surface((width, 80), pygame.SRCALPHA)
        self._platform_surface = pygame.Surface((width, height // 3), pygame.SRCALPHA)
        self._haze_surface = pygame.Surface((width, 40), pygame.SRCALPHA)
        self._ship_surface = pygame.Surface((width, 60), pygame.SRCALPHA)
        self._scanline_surface = pygame.Surface((width, height), pygame.SRCALPHA)
        self._transparent = (0, 0, 0, 0)

        # ------------------------------------------------------------------
        #  그라데이션 캐시
        # ------------------------------------------------------------------
        self._sky_gradient_cache = None
        self._ocean_gradient_cache = None
        self._init_gradient_caches()

        # ------------------------------------------------------------------
        #  정적 요소 사전 렌더링
        # ------------------------------------------------------------------
        self._init_horizon_haze()
        self._init_distant_ships()
        self._init_platform_static()

        # ------------------------------------------------------------------
        #  배경 파도 (5레이어, 작은 진폭 - 먼 느낌)
        # ------------------------------------------------------------------
        self.bg_waves = []
        for i in range(5):
            self.bg_waves.append({
                'y': self.cy + 20 + i * 25,
                'amplitude': random.uniform(3, 8),
                'frequency': random.uniform(0.01, 0.025),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(0.015, 0.03),
            })

        # ------------------------------------------------------------------
        #  전경 파도 (2레이어, 큰 진폭 - 깊이감 생성)
        # ------------------------------------------------------------------
        self.fg_waves = []
        for i in range(2):
            self.fg_waves.append({
                'y': height - 80 + i * 35,
                'amplitude': random.uniform(8, 18),
                'frequency': random.uniform(0.008, 0.02),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(0.025, 0.045),
            })

        # ------------------------------------------------------------------
        #  구름 (더 어둡고 불길한)
        # ------------------------------------------------------------------
        self.clouds = []
        self._cloud_surfaces = []
        for _ in range(5):
            cloud_w = random.randint(60, 130)
            cloud_h = random.randint(20, 40)
            self.clouds.append({
                'x': random.randint(-cloud_w, width),
                'y': random.randint(30, self.cy - 80),
                'w': cloud_w,
                'h': cloud_h,
                'speed': random.uniform(0.08, 0.25),
                'opacity': random.randint(20, 45),
            })
            self._cloud_surfaces.append(
                pygame.Surface((cloud_w + 20, cloud_h + 10), pygame.SRCALPHA)
            )

        # ------------------------------------------------------------------
        #  레이더 스윕
        # ------------------------------------------------------------------
        self.radar_angle = 0.0
        self.radar_speed = 0.02

        # ------------------------------------------------------------------
        #  홀로그램 스캔라인
        # ------------------------------------------------------------------
        self.scanline_offset = 0

        # ------------------------------------------------------------------
        #  불꽃 라인 파티클 시스템 (절제된)
        # ------------------------------------------------------------------
        self.fire_line_particles = []
        self.fire_glow_phase = 0.0
        self.center_circle_radius = min(width, height) // 10
        self.stadium_line_y = self.cy

    # ======================================================================
    #  1회성 사전 렌더링
    # ======================================================================

    def _init_gradient_caches(self):
        """하늘/바다 그라데이션 numpy 사전 렌더링 (1회 계산)"""
        half_h = self.height // 2
        denom = max(half_h - 1, 1)
        factors = np.arange(half_h, dtype=np.float32) / denom

        # 하늘: 2단계 그라데이션 (네이비 → 인디고 → 앰버)
        self._sky_gradient_cache = pygame.Surface((self.width, half_h))
        arr = np.zeros((self.width, half_h, 3), dtype=np.uint8)
        mid_point = half_h // 2
        f1 = np.arange(mid_point, dtype=np.float32) / max(mid_point - 1, 1)
        f2 = np.arange(half_h - mid_point, dtype=np.float32) / max(half_h - mid_point - 1, 1)

        for ch in range(3):
            upper = (self.sky_top[ch] + (self.sky_mid[ch] - self.sky_top[ch]) * f1).astype(np.uint8)
            lower = (self.sky_mid[ch] + (self.horizon_color[ch] - self.sky_mid[ch]) * f2).astype(np.uint8)
            arr[:, :mid_point, ch] = upper
            arr[:, mid_point:, ch] = lower

        pygame.surfarray.blit_array(self._sky_gradient_cache, arr)

        # 바다: ocean_surface → ocean_deep
        self._ocean_gradient_cache = pygame.Surface((self.width, half_h))
        arr2 = np.zeros((self.width, half_h, 3), dtype=np.uint8)
        for ch in range(3):
            arr2[:, :, ch] = (self.ocean_surface[ch] +
                              (self.ocean_deep[ch] - self.ocean_surface[ch]) * factors).astype(np.uint8)
        pygame.surfarray.blit_array(self._ocean_gradient_cache, arr2)

    def _init_horizon_haze(self):
        """수평선 대기 안개 밴드 사전 렌더링"""
        self._haze_surface.fill(self._transparent)
        haze_h = self._haze_surface.get_height()
        for y in range(haze_h):
            alpha = int(40 * (1.0 - abs(y - haze_h // 2) / (haze_h // 2)))
            pygame.draw.line(self._haze_surface, (180, 140, 80, alpha),
                           (0, y), (self.width, y))

    def _init_distant_ships(self):
        """수평선 위 원거리 군함 실루엣 사전 렌더링"""
        self._ship_surface.fill(self._transparent)
        ship_color = (25, 20, 35, 60)  # 매우 희미한 대기감
        w = self.width

        # 함선 1: 대형 항공모함 (좌측)
        ship1_x = int(w * 0.12)
        ship1_w = int(w * 0.12)
        ship1_y = 35
        hull_pts = [
            (ship1_x, ship1_y),
            (ship1_x + ship1_w, ship1_y),
            (ship1_x + ship1_w - 8, ship1_y + 12),
            (ship1_x + 5, ship1_y + 12),
        ]
        pygame.draw.polygon(self._ship_surface, ship_color, hull_pts)
        bridge_x = ship1_x + ship1_w // 3
        pygame.draw.rect(self._ship_surface, ship_color,
                        (bridge_x, ship1_y - 18, 15, 18))
        pygame.draw.rect(self._ship_surface, ship_color,
                        (bridge_x + 3, ship1_y - 25, 8, 7))
        pygame.draw.line(self._ship_surface, ship_color,
                        (bridge_x + 7, ship1_y - 25), (bridge_x + 7, ship1_y - 35), 1)

        # 함선 2: 구축함 (우측)
        ship2_x = int(w * 0.75)
        ship2_w = int(w * 0.08)
        ship2_y = 38
        hull_pts2 = [
            (ship2_x, ship2_y),
            (ship2_x + ship2_w, ship2_y),
            (ship2_x + ship2_w + 5, ship2_y + 8),
            (ship2_x - 3, ship2_y + 8),
        ]
        pygame.draw.polygon(self._ship_surface, ship_color, hull_pts2)
        pygame.draw.rect(self._ship_surface, ship_color,
                        (ship2_x + ship2_w // 3, ship2_y - 12, 10, 12))

        # 함선 3: 소형 함정 (우측 끝, 거의 안 보임)
        ship3_x = int(w * 0.9)
        pygame.draw.rect(self._ship_surface, (20, 18, 30, 35),
                        (ship3_x, 40, int(w * 0.04), 5))
        pygame.draw.rect(self._ship_surface, (20, 18, 30, 35),
                        (ship3_x + 8, 34, 4, 6))

    def _init_platform_static(self):
        """다층 데크 아레나 플랫폼 정적 사전 렌더링"""
        surf = self._platform_surface
        surf.fill(self._transparent)
        w = self.width

        base_y = surf.get_height() // 2  # 플랫폼 서피스 중앙
        deck_w = int(w * 0.55)           # 메인 데크 폭
        deck_x = (w - deck_w) // 2       # 중앙 정렬

        upper_w = int(w * 0.38)          # 상층 데크 폭
        upper_x = (w - upper_w) // 2

        ring_w = int(w * 0.65)           # 외곽 링 폭
        ring_x = (w - ring_w) // 2

        # --- 외곽 링 (아레나 주변 타원형 프레임) ---
        pygame.draw.ellipse(surf, self.gunmetal_edge,
                          (ring_x, base_y - 8, ring_w, 30), 2)
        pygame.draw.ellipse(surf, (*self.cyan_dim, 60),
                          (ring_x + 2, base_y - 6, ring_w - 4, 26), 1)

        # --- 메인 데크 (원근감을 위한 사다리꼴) ---
        deck_inset = 15
        deck_h = 28
        deck_pts = [
            (deck_x + deck_inset, base_y - deck_h // 2),
            (deck_x + deck_w - deck_inset, base_y - deck_h // 2),
            (deck_x + deck_w, base_y + deck_h // 2),
            (deck_x, base_y + deck_h // 2),
        ]
        pygame.draw.polygon(surf, self.gunmetal, deck_pts)
        pygame.draw.polygon(surf, self.gunmetal_edge, deck_pts, 1)
        pygame.draw.line(surf, (*self.cyan_accent, 120),
                        deck_pts[0], deck_pts[1], 1)

        # --- 상층 데크 (좁은 계층) ---
        upper_h = 12
        upper_pts = [
            (upper_x + 8, base_y - deck_h // 2 - upper_h),
            (upper_x + upper_w - 8, base_y - deck_h // 2 - upper_h),
            (upper_x + upper_w, base_y - deck_h // 2),
            (upper_x, base_y - deck_h // 2),
        ]
        pygame.draw.polygon(surf, self.gunmetal_light, upper_pts)
        pygame.draw.polygon(surf, self.gunmetal_edge, upper_pts, 1)

        # --- 관중석 실루엣 범프 ---
        crowd_y = base_y - deck_h // 2 - upper_h
        for i in range(12):
            bx = upper_x + 15 + i * ((upper_w - 30) // 12)
            bh = random.randint(3, 6)
            pygame.draw.rect(surf, (25, 28, 40), (bx, crowd_y - bh, 4, bh))

        # --- 안테나 타워 (양쪽) ---
        tower_h = 45
        lt_x = deck_x + 20
        lt_base_y = base_y - deck_h // 2 - upper_h
        pygame.draw.line(surf, self.gunmetal_edge,
                        (lt_x, lt_base_y), (lt_x, lt_base_y - tower_h), 2)
        pygame.draw.line(surf, self.gunmetal_edge,
                        (lt_x - 5, lt_base_y - tower_h + 10),
                        (lt_x + 5, lt_base_y - tower_h + 10), 1)
        pygame.draw.circle(surf, self.cyan_accent, (lt_x, lt_base_y - tower_h), 2)

        rt_x = deck_x + deck_w - 20
        pygame.draw.line(surf, self.gunmetal_edge,
                        (rt_x, lt_base_y), (rt_x, lt_base_y - tower_h), 2)
        pygame.draw.line(surf, self.gunmetal_edge,
                        (rt_x - 5, lt_base_y - tower_h + 10),
                        (rt_x + 5, lt_base_y - tower_h + 10), 1)
        pygame.draw.circle(surf, self.cyan_accent, (rt_x, lt_base_y - tower_h), 2)

        # --- 중앙 안테나 (더 높은 메인 레이더 마스트) ---
        center_tower_h = 55
        ct_base_y = base_y - deck_h // 2 - upper_h
        pygame.draw.line(surf, self.gunmetal_edge,
                        (self.cx, ct_base_y), (self.cx, ct_base_y - center_tower_h), 2)
        dish_y = ct_base_y - center_tower_h + 8
        pygame.draw.polygon(surf, self.gunmetal_edge, [
            (self.cx - 8, dish_y),
            (self.cx + 8, dish_y),
            (self.cx, dish_y - 6),
        ])
        pygame.draw.circle(surf, (255, 60, 40), (self.cx, ct_base_y - center_tower_h), 2)

        # --- 하부 지지대 (데크 아래 수중으로) ---
        strut_count = 5
        for i in range(strut_count):
            sx = deck_x + (deck_w // (strut_count + 1)) * (i + 1)
            pygame.draw.line(surf, (20, 25, 40, 150),
                           (sx, base_y + deck_h // 2),
                           (sx, base_y + deck_h // 2 + 25), 2)

        # --- 네온 패널 악센트 (데크 면 얇은 수평 스트립) ---
        panel_y = base_y + 2
        for i in range(3):
            py = panel_y + i * 6
            px1 = deck_x + 30 + i * 20
            px2 = deck_x + deck_w - 30 - i * 20
            pygame.draw.line(surf, (*self.cyan_accent, 50 + i * 20),
                           (px1, py), (px2, py), 1)

        # 레이더 스윕 참조용 측정값 저장
        self._platform_base_y_local = base_y
        self._platform_deck_h = deck_h
        self._platform_upper_h = upper_h
        self._center_tower_h = center_tower_h

    # ======================================================================
    #  업데이트
    # ======================================================================

    def update(self):
        """모든 애니메이션 상태를 1프레임 진행"""
        self.time += 1
        self.fire_glow_phase += 0.04
        self.radar_angle += self.radar_speed
        self.scanline_offset = (self.scanline_offset + 1) % self.height

        # 배경 파도
        for wave in self.bg_waves:
            wave['phase'] += wave['speed']

        # 전경 파도
        for wave in self.fg_waves:
            wave['phase'] += wave['speed']

        # 구름 이동
        for cloud in self.clouds:
            cloud['x'] += cloud['speed']
            if cloud['x'] > self.width + cloud['w']:
                cloud['x'] = -cloud['w'] - random.randint(0, 50)
                cloud['y'] = random.randint(30, self.cy - 80)

        # 불꽃 파티클
        self._update_fire_lines()

    # ======================================================================
    #  그리기 (모든 레이어 합성)
    # ======================================================================

    def draw(self, screen):
        """
        3레이어 깊이 분리로 전체 배경 렌더링.

        원경: 하늘 → 원거리 함선 → 구름 → 수평선 안개
        중경: 바다 → 배경 파도 → 플랫폼 그림자 → 아레나 → 레이더 → 불꽃
        근경: 전경 파도 → 홀로그램 스캔라인 → 테두리
        """
        # --- 원경 레이어 ---
        screen.blit(self._sky_gradient_cache, (0, 0))
        screen.blit(self._ship_surface, (0, self.cy - 60))
        self._draw_clouds(screen)
        screen.blit(self._haze_surface, (0, self.cy - 20))

        # 수평선 (은은하고 따뜻한)
        pygame.draw.line(screen, (*self.horizon_color, 180),
                        (0, self.cy), (self.width, self.cy), 1)

        # --- 중경 레이어 ---
        screen.blit(self._ocean_gradient_cache, (0, self.cy))
        self._draw_waves(screen, self.bg_waves, self._wave_surface, alpha=35)

        # 플랫폼
        platform_y = self.cy - self._platform_surface.get_height() // 2 + 30
        self._draw_platform_shadow(screen, platform_y)
        screen.blit(self._platform_surface, (0, platform_y))
        self._draw_radar_sweep(screen, platform_y)

        # 불꽃 라인 (절제된 - 플랫폼 위에 그리되 지배적이지 않게)
        self._draw_fire_lines(screen)

        # --- 근경 레이어 ---
        self._draw_waves(screen, self.fg_waves, self._fg_wave_surface,
                        alpha=55, circle_r=12, step=6, foam_interval=60)
        self._draw_scanlines(screen)
        self._draw_border(screen)

    # ======================================================================
    #  레이어 렌더러
    # ======================================================================

    def _draw_clouds(self, screen):
        """어둡고 불길한 먹구름"""
        for idx, cloud in enumerate(self.clouds):
            surf = self._cloud_surfaces[idx]
            surf.fill(self._transparent)
            cw, ch = cloud['w'], cloud['h']
            opacity = cloud['opacity']
            pygame.draw.ellipse(surf, (20, 20, 30, opacity),
                              (5, 3, cw, ch))
            inner_w = cw * 2 // 3
            inner_x = 5 + (cw - inner_w) // 2
            pygame.draw.ellipse(surf, (30, 30, 45, opacity // 2),
                              (inner_x, 5, inner_w, ch - 4))
            screen.blit(surf, (int(cloud['x']), cloud['y']))

    def _draw_waves(self, screen, wave_list, surface, alpha=40,
                    circle_r=8, step=8, foam_interval=80):
        """애니메이션 사인파 바다 레이어 (배경/전경 공용)"""
        ocean_color = (*self.ocean_surface, alpha)
        foam_color = (*self.wave_foam, alpha + 15)
        w = self.width

        for wave in wave_list:
            surface.fill(self._transparent)
            amp = wave['amplitude']
            freq = wave['frequency']
            phase = wave['phase']

            for x in range(0, w, step):
                y = surface.get_height() // 2 + amp * math.sin(x * freq + phase)
                iy = int(y)
                pygame.draw.circle(surface, ocean_color, (x, iy), circle_r)
                if foam_interval > 0 and x % foam_interval < step:
                    pygame.draw.circle(surface, foam_color, (x, iy - 4), 3)

            screen.blit(surface, (0, wave['y']))

    def _draw_platform_shadow(self, screen, platform_y):
        """아레나 아래 수면 위 어두운 그림자 타원"""
        self._shadow_surface.fill(self._transparent)
        shadow_w = int(self.width * 0.5)
        shadow_x = (self.width - shadow_w) // 2
        base_y = self._platform_base_y_local + self._platform_deck_h // 2
        pygame.draw.ellipse(self._shadow_surface, (0, 0, 0, 25),
                          (shadow_x, 15, shadow_w, 50))
        screen.blit(self._shadow_surface, (0, platform_y + base_y + 30))

    def _draw_radar_sweep(self, screen, platform_y):
        """중앙 안테나에서 회전하는 레이더 스캔 빔"""
        origin_y = (platform_y + self._platform_base_y_local
                    - self._platform_deck_h // 2
                    - self._platform_upper_h
                    - self._center_tower_h)
        origin_x = self.cx

        sweep_len = min(self.width, self.height) // 4
        end_x = origin_x + math.cos(self.radar_angle) * sweep_len
        end_y = origin_y + math.sin(self.radar_angle) * sweep_len * 0.4

        sweep_surface = _get_cached_surface(self.width, self.height)
        spread = 12
        perp_x = -math.sin(self.radar_angle) * spread
        perp_y = math.cos(self.radar_angle) * spread * 0.4

        pts = [
            (int(origin_x), int(origin_y)),
            (int(end_x + perp_x), int(end_y + perp_y)),
            (int(end_x - perp_x), int(end_y - perp_y)),
        ]
        pygame.draw.polygon(sweep_surface, (*self.cyan_accent, 12), pts)
        pygame.draw.line(sweep_surface, (*self.cyan_accent, 30),
                        (int(origin_x), int(origin_y)),
                        (int(end_x), int(end_y)), 1)
        screen.blit(sweep_surface, (0, 0))

    def _draw_scanlines(self, screen):
        """은은한 수평 홀로그램 간섭 라인"""
        self._scanline_surface.fill(self._transparent)
        for y in range(self.scanline_offset % 6, self.height, 6):
            alpha = 8 + int(4 * math.sin(y * 0.05 + self.time * 0.03))
            pygame.draw.line(self._scanline_surface, (0, 200, 220, alpha),
                           (0, y), (self.width, y))
        screen.blit(self._scanline_surface, (0, 0))

    def _draw_border(self, screen):
        """얇고 비침습적 네온 테두리 (4px + 1px 시안 악센트)"""
        t = 4
        w, h = self.width, self.height
        base = (10, 15, 30)
        accent = (*self.cyan_dim, 100)

        # 외곽 프레임
        pygame.draw.rect(screen, base, (0, 0, w, t))
        pygame.draw.rect(screen, base, (0, h - t, w, t))
        pygame.draw.rect(screen, base, (0, 0, t, h))
        pygame.draw.rect(screen, base, (w - t, 0, t, h))

        # 내부 악센트 라인
        pygame.draw.rect(screen, accent, (t, t, w - 2 * t, 1))
        pygame.draw.rect(screen, accent, (t, h - t - 1, w - 2 * t, 1))
        pygame.draw.rect(screen, accent, (t, t, 1, h - 2 * t))
        pygame.draw.rect(screen, accent, (w - t - 1, t, 1, h - 2 * t))

        # 코너 도트 (작은)
        for corner_x, corner_y in [(t, t), (w - t, t), (t, h - t), (w - t, h - t)]:
            pygame.draw.circle(screen, self.cyan_accent, (corner_x, corner_y), 2)

    # ======================================================================
    #  불꽃 라인 파티클 시스템 (절제된 강도)
    # ======================================================================

    def _update_fire_lines(self):
        """미드필드 라인 불꽃 파티클 생성/업데이트"""
        if random.random() < 0.2:  # 낮춘 스폰율 (기존 0.3)
            angle = random.uniform(0, math.pi * 2)
            x = self.cx + math.cos(angle) * self.center_circle_radius
            y = self.stadium_line_y + math.sin(angle) * self.center_circle_radius
            self._create_fire_particle(x, y)

            if random.random() < 0.4:
                x = random.randint(self.width // 6, self.width * 5 // 6)
                self._create_fire_particle(x, self.stadium_line_y)

        for particle in self.fire_line_particles[:]:
            particle['y'] -= particle['vy']
            particle['x'] += particle['vx']
            particle['life'] -= 1
            particle['size'] *= 0.94

            if particle['life'] <= 0 or particle['size'] < 0.5:
                self.fire_line_particles.remove(particle)

    def _create_fire_particle(self, x, y):
        """불꽃 파티클 생성 (최대 80개, 기존 100에서 축소)"""
        if len(self.fire_line_particles) < 80:
            self.fire_line_particles.append({
                'x': x, 'y': y,
                'vx': random.uniform(-0.4, 0.4),
                'vy': random.uniform(0.4, 1.5),
                'size': random.uniform(1.5, 3.5),
                'life': random.randint(15, 35),
                'color': random.choice(self.fire_colors),
                'glow': random.uniform(0.5, 0.9),
            })

    def _draw_fire_lines(self, screen):
        """불타는 미드필드 라인 + 글로우 (아레나를 압도하지 않도록 절제)"""
        glow = (math.sin(self.fire_glow_phase) + 1) * 0.25 + 0.35  # 0.35~0.85

        # 센터 서클 글로우 (기존 3겹 → 2겹)
        for i in range(2):
            alpha = int(18 * glow * (1 - i * 0.4))
            radius = self.center_circle_radius + i * 2
            color = (180 + int(55 * glow), 50 + int(30 * glow), 15)

            gs = radius * 2 + 16
            glow_surface = _get_cached_surface(gs, gs)
            pygame.draw.circle(glow_surface, (*color, alpha),
                             (radius + 8, radius + 8), radius, 2 + i)
            screen.blit(glow_surface, (self.cx - radius - 8,
                                       self.stadium_line_y - radius - 8))

        # 서클 아웃라인
        main_color = (230, int(80 + 40 * glow), 40)
        pygame.draw.circle(screen, main_color,
                          (self.cx, self.stadium_line_y),
                          self.center_circle_radius, 1)

        # 미드필드 점선
        dash_len = 18
        gap_len = 14
        margin = self.width // 6
        current_x = margin
        while current_x < self.width - margin:
            dash_end = min(current_x + dash_len, self.width - margin)
            alpha = int(15 * glow)
            gs = _get_cached_surface(dash_len + 8, 8)
            color = (180 + int(55 * glow), 50 + int(30 * glow), 15)
            pygame.draw.line(gs, (*color, alpha), (4, 4), (dash_len + 4, 4), 2)
            screen.blit(gs, (current_x - 4, self.stadium_line_y - 4))

            pygame.draw.line(screen, main_color,
                           (current_x, self.stadium_line_y),
                           (dash_end, self.stadium_line_y), 1)
            current_x += dash_len + gap_len

        # 불꽃 파티클
        for p in self.fire_line_particles:
            ga = int(p['glow'] * p['life'] * 1.2)
            if ga > 0:
                gs_size = max(1, int(p['size'] * 1.5) * 2)
                gs = _get_cached_surface(gs_size, gs_size)
                center = gs_size // 2
                pygame.draw.circle(gs, (*p['color'], min(ga, 80)),
                                 (center, center), center)
                screen.blit(gs, (p['x'] - center, p['y'] - center))
            pygame.draw.circle(screen, p['color'],
                             (int(p['x']), int(p['y'])), int(p['size']))

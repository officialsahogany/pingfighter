# -*- coding: utf-8 -*-
"""
우주 행성 맵 - 시네마틱 고퀄리티 애니메이션
Phase 1: 1인칭 콕핏 워프 (별이 중앙→바깥 방사)
Phase 2: 카메라 풀백 → 3인칭 전환 (우주선 등장)
Phase 3: 3인칭 횡스크롤 비행 (성운/행성/별 5레이어)
Phase 4: 목표 행성 접근 & 감속
Phase 5: 도착 연출
Phase 6: 줌아웃 → 탑뷰 은하 맵
"""

import pygame
import math
import random
import sys

try:
    from pixel_font_manager import get_font
except ImportError:
    get_font = lambda s, **kw: pygame.font.Font(None, s)

try:
    from config.planet_configs import PLANET_CONFIGS
except ImportError:
    PLANET_CONFIGS = {}


def _t(key, fallback=""):
    try:
        from localization.manager import get_localization_manager
        return get_localization_manager().get(key, fallback)
    except Exception:
        return fallback


# ═══════════════════════════════════════════════════════════
#  유틸리티
# ═══════════════════════════════════════════════════════════
def _ease_in_out(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def _ease_out_cubic(t):
    t = max(0.0, min(1.0, t))
    return 1.0 - (1.0 - t) ** 3


def _clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v)))


# ═══════════════════════════════════════════════════════════
#  탑뷰 은하 맵 행성 배치
# ═══════════════════════════════════════════════════════════
class _DetailedPlanet:
    def __init__(self, w, h):
        self.x = w + random.randint(80, 400)
        self.y = random.randint(80, h - 80)
        self.radius = random.randint(20, 65)
        self.speed = random.uniform(0.8, 3.0)
        ptypes = [
            {'base': (50, 80, 160), 'atm': (70, 120, 200), 'bands': True,
             'band_c': (40, 60, 140)},
            {'base': (160, 100, 50), 'atm': (200, 150, 80), 'craters': True},
            {'base': (80, 160, 100), 'atm': (120, 200, 140)},
            {'base': (180, 60, 60), 'atm': (220, 100, 60), 'bands': True,
             'band_c': (140, 40, 40)},
            {'base': (100, 60, 160), 'atm': (150, 100, 220)},
            {'base': (60, 140, 160), 'atm': (80, 180, 200), 'bands': True,
             'band_c': (40, 120, 140)},
            {'base': (150, 150, 170), 'atm': (200, 200, 220)},
        ]
        pt = random.choice(ptypes)
        self.base_color = pt['base']
        self.atm_color = pt['atm']
        self.has_bands = pt.get('bands', False)
        self.band_color = pt.get('band_c', (100, 100, 100))
        self.has_craters = pt.get('craters', False)
        self.has_ring = random.random() < 0.3
        self.ring_color = tuple(min(255, c + 50) for c in self.base_color)
        self.has_moon = random.random() < 0.2
        self.moon_angle = random.uniform(0, math.pi * 2)
        self.moon_dist = self.radius * 1.8
        self.surface = self._render()

    def _render(self):
        margin = 40
        size = (self.radius + margin) * 2
        surf = pygame.Surface((size, size), pygame.SRCALPHA)
        cx, cy = size // 2, size // 2
        r = self.radius
        # 대기 글로우
        for i in range(20, 0, -2):
            a = max(1, 15 - i)
            pygame.draw.circle(surf, (*self.atm_color, a), (cx, cy), r + i)
        # 본체
        pygame.draw.circle(surf, self.base_color, (cx, cy), r)
        # 밴드
        if self.has_bands:
            for by in range(-r + 8, r, max(6, random.randint(8, 14))):
                bw = int(math.sqrt(max(0, r * r - by * by)))
                if bw < 3:
                    continue
                ba = random.randint(20, 50)
                pygame.draw.line(surf, (*self.band_color, ba),
                                 (cx - bw, cy + by), (cx + bw, cy + by), 2)
        # 크레이터
        if self.has_craters:
            for _ in range(random.randint(2, 5)):
                ca = random.uniform(0, math.pi * 2)
                cd = random.uniform(0, r * 0.7)
                cr = random.randint(2, max(3, r // 6))
                darker = tuple(max(0, c - 30) for c in self.base_color)
                pygame.draw.circle(surf, (*darker, 60),
                                   (cx + int(cd * math.cos(ca)),
                                    cy + int(cd * math.sin(ca))), cr)
        # 하이라이트
        hl = tuple(min(255, c + 80) for c in self.base_color)
        hl_r = max(4, r // 3)
        for i in range(hl_r, 0, -1):
            a = max(1, int(40 * i / hl_r))
            pygame.draw.circle(surf, (*hl, a),
                               (cx - r // 3, cy - r // 3), i)
        # 대기 경계
        pygame.draw.circle(surf, (*self.atm_color, 80), (cx, cy), r, 1)
        # 고리
        if self.has_ring:
            rw = int(r * 2.6)
            rh = max(8, r // 3)
            rs = pygame.Surface((rw, rh), pygame.SRCALPHA)
            for ri in range(3):
                off = ri * 2
                a = max(1, 40 - ri * 10)
                pygame.draw.ellipse(rs, (*self.ring_color, a),
                                    (off, off, rw - off * 2, rh - off * 2), 1)
            surf.blit(rs, (cx - rw // 2, cy - rh // 2))
        return surf


# ═══════════════════════════════════════════════════════════
#  속도 라인
# ═══════════════════════════════════════════════════════════
class _EngineParticle:
    __slots__ = ('x', 'y', 'vx', 'vy', 'life', 'max_life', 'size', 'color')

    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.vx = random.uniform(-4, -1)
        self.vy = random.uniform(-1.5, 1.5)
        self.life = random.uniform(0.3, 0.8)
        self.max_life = self.life
        self.size = random.uniform(1.5, 4.0)
        t = random.random()
        if t < 0.3:
            self.color = (255, 255, 200)
        elif t < 0.6:
            self.color = (255, 180, 50)
        else:
            self.color = (255, 80, 20)


# ═══════════════════════════════════════════════════════════
#  메인 SpaceMap 클래스
# ═══════════════════════════════════════════════════════════
class SpaceMap:
    def __init__(self, screen, width, height):
        self.screen = screen
        self.W = width
        self.H = height
        self.clock = pygame.time.Clock()
        self.time = 0.0

        # 폰트
        try:
            self.font_big = get_font(34, style="bold")
            self.font_med = get_font(22, style="bold")
            self.font_sm = get_font(14, style="bold")
            self.font_xs = get_font(12, style="regular")
            self.font_hud = get_font(11, style="regular")
        except Exception:
            self.font_big = pygame.font.Font(None, 42)
            self.font_med = pygame.font.Font(None, 28)
            self.font_sm = pygame.font.Font(None, 18)
            self.font_xs = pygame.font.Font(None, 14)
            self.font_hud = pygame.font.Font(None, 14)

        self.engine_particles = []

    def _spawn_engine_particles(self, x, y, count=2):
        for _ in range(count):
            self.engine_particles.append(
                _EngineParticle(x, y + random.uniform(-3, 3)))

    def _draw_ship(self, surf, x, y, scale=1.0, engine_power=1.0):
        s = scale
        ix, iy = int(x), int(y)

        # ===== 엔진 후광 (대형 글로우 + 컬러 레이어) =====
        if engine_power > 0.1:
            # 외곽 넓은 블루 글로우
            gr = int(28 * s * engine_power)
            gs = pygame.Surface((gr * 2 + 4, gr * 2 + 4), pygame.SRCALPHA)
            gc = gr + 2
            for rr in range(gr, 0, -1):
                t = rr / gr
                a = max(1, int(30 * engine_power * t))
                pygame.draw.circle(gs, (60, 120, 255, a), (gc, gc), rr)
            # 내부 하얀 코어 글로우
            cr2 = max(3, int(gr * 0.35))
            for rr in range(cr2, 0, -1):
                a = max(1, int(50 * engine_power * rr / cr2))
                pygame.draw.circle(gs, (200, 220, 255, a), (gc, gc), rr)
            surf.blit(gs, (ix - int(15 * s) - gc, iy - gc))

        # ===== 엔진 불꽃 (5레이어 — 플라즈마 ~ 배기가스) =====
        if engine_power > 0.1:
            # 엔진 노즐 위치 (상/중/하 3구)
            nozzle_offsets = [int(-3 * s), 0, int(3 * s)]
            for noff in nozzle_offsets:
                nz_y = iy + noff
                fl = random.randint(10, max(11, int(35 * engine_power)))
                # L5: 가장 바깥 — 어두운 적색 배기
                pygame.draw.line(surf, (180, 40, 10),
                                 (ix - int(14 * s), nz_y + random.randint(-1, 1)),
                                 (ix - int((14 + fl * 1.1) * s),
                                  nz_y + random.randint(-3, 3)),
                                 max(1, int(1 * s)))
                # L4: 주황 화염
                pygame.draw.line(surf, (255, 120, 30),
                                 (ix - int(13 * s), nz_y),
                                 (ix - int((13 + fl * 0.85) * s), nz_y),
                                 max(1, int(2 * s)))
                # L3: 밝은 노랑
                pygame.draw.line(surf, (255, 200, 60),
                                 (ix - int(12 * s), nz_y),
                                 (ix - int((12 + fl * 0.6) * s), nz_y),
                                 max(1, int(2 * s)))
                # L2: 하얀 코어
                pygame.draw.line(surf, (220, 230, 255),
                                 (ix - int(12 * s), nz_y),
                                 (ix - int((12 + fl * 0.35) * s), nz_y),
                                 max(1, int(3 * s)))
                # L1: 가장 안쪽 — 블루 플라즈마
                pygame.draw.line(surf, (150, 190, 255),
                                 (ix - int(11 * s), nz_y),
                                 (ix - int((11 + fl * 0.15) * s), nz_y),
                                 max(1, int(2 * s)))
            # 랜덤 불꽃 스파크
            for _ in range(max(1, int(4 * engine_power))):
                sp_x = ix - int(random.randint(15, 25) * s)
                sp_y = iy + random.randint(int(-5 * s), int(5 * s))
                pygame.draw.circle(surf, (255, random.randint(120, 255),
                                          random.randint(20, 80)),
                                   (sp_x, sp_y), max(1, int(s)))

        # ===== 주 선체 (3레이어 — 어두운 하단 + 본체 + 밝은 상단) =====
        # 하단 그림자 면 (어두운 배 밑)
        body_dark = [
            (ix + int(24 * s), iy + int(1 * s)),
            (ix + int(14 * s), iy + int(5 * s)),
            (ix - int(5 * s), iy + int(9 * s)),
            (ix - int(13 * s), iy + int(7 * s)),
            (ix - int(13 * s), iy + int(1 * s)),
            (ix + int(14 * s), iy + int(1 * s)),
        ]
        pygame.draw.polygon(surf, (110, 120, 145), body_dark)

        # 본체 (미드톤)
        body = [
            (ix + int(26 * s), iy),
            (ix + int(16 * s), iy - int(6 * s)),
            (ix - int(5 * s), iy - int(9 * s)),
            (ix - int(13 * s), iy - int(7 * s)),
            (ix - int(13 * s), iy + int(7 * s)),
            (ix - int(5 * s), iy + int(9 * s)),
            (ix + int(16 * s), iy + int(6 * s)),
        ]
        pygame.draw.polygon(surf, (170, 185, 210), body)

        # 상단 하이라이트 면 (3D 라이팅)
        hl = [
            (ix + int(24 * s), iy - int(1 * s)),
            (ix + int(14 * s), iy - int(5 * s)),
            (ix - int(4 * s), iy - int(7 * s)),
            (ix - int(4 * s), iy - int(2 * s)),
            (ix + int(14 * s), iy - int(1 * s)),
        ]
        pygame.draw.polygon(surf, (215, 228, 248), hl)

        # 선체 중앙 스트라이프 (패널 라인)
        pygame.draw.line(surf, (140, 155, 180),
                         (ix + int(22 * s), iy),
                         (ix - int(12 * s), iy), 1)
        # 패널 분할 세로선
        for px_off in [-2, 5, 12]:
            px = ix + int(px_off * s)
            pygame.draw.line(surf, (150, 165, 190),
                             (px, iy - int(4 * s)),
                             (px, iy + int(4 * s)), 1)

        # ===== 엔진 나셀 (좌측 엔진 하우징 — 3D 원통형) =====
        nac_x = ix - int(10 * s)
        nac_w = int(5 * s)
        nac_h = int(14 * s)
        # 어두운 면
        pygame.draw.ellipse(surf, (80, 90, 120),
                            (nac_x - nac_w, iy - nac_h // 2, nac_w * 2, nac_h))
        # 하이라이트 (상단 절반)
        pygame.draw.ellipse(surf, (120, 135, 170),
                            (nac_x - nac_w, iy - nac_h // 2,
                             nac_w * 2, nac_h // 2))
        # 노즐 구멍 (3개)
        for noff in [-3, 0, 3]:
            pygame.draw.circle(surf, (30, 35, 55),
                               (ix - int(13 * s), iy + int(noff * s)),
                               max(1, int(2 * s)))
            pygame.draw.circle(surf, (80, 100, 160),
                               (ix - int(13 * s), iy + int(noff * s)),
                               max(1, int(2 * s)), 1)

        # ===== 상단 윙 (3D — 그림자/본체/하이라이트) =====
        wt = [(ix - int(2 * s), iy - int(9 * s)),
              (ix - int(9 * s), iy - int(20 * s)),
              (ix - int(16 * s), iy - int(18 * s)),
              (ix - int(13 * s), iy - int(9 * s))]
        pygame.draw.polygon(surf, (100, 115, 155), wt)  # 기본 면
        # 윙 상면 하이라이트
        wt_hl = [(ix - int(2 * s), iy - int(9 * s)),
                 (ix - int(9 * s), iy - int(20 * s)),
                 (ix - int(7 * s), iy - int(19 * s)),
                 (ix - int(2 * s), iy - int(10 * s))]
        pygame.draw.polygon(surf, (150, 170, 210), wt_hl)
        pygame.draw.polygon(surf, (130, 150, 195), wt, 1)
        # 내비 라이트 (빨간) + 글로우
        nav_x = ix - int(11 * s)
        nav_y = iy - int(19 * s)
        nav_gs = pygame.Surface((12, 12), pygame.SRCALPHA)
        for gi in range(5, 0, -1):
            pygame.draw.circle(nav_gs, (255, 50, 50, max(1, 40 - gi * 6)),
                               (6, 6), gi)
        surf.blit(nav_gs, (nav_x - 6, nav_y - 6))
        pygame.draw.circle(surf, (255, 80, 80), (nav_x, nav_y),
                           max(1, int(2 * s)))
        # 윙 끝 무기 포드
        pygame.draw.line(surf, (90, 100, 130),
                         (ix - int(15 * s), iy - int(17 * s)),
                         (ix - int(18 * s), iy - int(17 * s)),
                         max(1, int(2 * s)))

        # ===== 하단 윙 (3D 미러) =====
        wb = [(ix - int(2 * s), iy + int(9 * s)),
              (ix - int(9 * s), iy + int(20 * s)),
              (ix - int(16 * s), iy + int(18 * s)),
              (ix - int(13 * s), iy + int(9 * s))]
        pygame.draw.polygon(surf, (90, 105, 140), wb)  # 하단은 더 어둡게
        # 윙 하면 엣지 라이트
        wb_hl = [(ix - int(13 * s), iy + int(9 * s)),
                 (ix - int(16 * s), iy + int(18 * s)),
                 (ix - int(15 * s), iy + int(17 * s)),
                 (ix - int(13 * s), iy + int(10 * s))]
        pygame.draw.polygon(surf, (120, 135, 175), wb_hl)
        pygame.draw.polygon(surf, (110, 130, 170), wb, 1)
        # 내비 라이트 (초록) + 글로우
        nav_x2 = ix - int(11 * s)
        nav_y2 = iy + int(19 * s)
        nav_gs2 = pygame.Surface((12, 12), pygame.SRCALPHA)
        for gi in range(5, 0, -1):
            pygame.draw.circle(nav_gs2, (50, 255, 50, max(1, 40 - gi * 6)),
                               (6, 6), gi)
        surf.blit(nav_gs2, (nav_x2 - 6, nav_y2 - 6))
        pygame.draw.circle(surf, (80, 255, 80), (nav_x2, nav_y2),
                           max(1, int(2 * s)))
        # 윙 끝 무기 포드
        pygame.draw.line(surf, (90, 100, 130),
                         (ix - int(15 * s), iy + int(17 * s)),
                         (ix - int(18 * s), iy + int(17 * s)),
                         max(1, int(2 * s)))

        # ===== 콕핏 캐노피 (다층 유리 반사) =====
        cp = [(ix + int(22 * s), iy),
              (ix + int(14 * s), iy - int(4 * s)),
              (ix + int(7 * s), iy - int(3 * s)),
              (ix + int(7 * s), iy + int(3 * s)),
              (ix + int(14 * s), iy + int(4 * s))]
        # 어두운 유리 배경
        pygame.draw.polygon(surf, (30, 80, 160), cp)
        # 유리 하이라이트 (상부)
        cp_hl = [(ix + int(21 * s), iy - int(1 * s)),
                 (ix + int(14 * s), iy - int(3 * s)),
                 (ix + int(8 * s), iy - int(2 * s)),
                 (ix + int(14 * s), iy - int(1 * s))]
        pygame.draw.polygon(surf, (100, 200, 255), cp_hl)
        # 캐노피 프레임
        pygame.draw.polygon(surf, (150, 180, 220), cp, 1)
        # 유리 반사 라인 (대각선 빛줄기)
        pygame.draw.line(surf, (180, 230, 255),
                         (ix + int(19 * s), iy - int(1 * s)),
                         (ix + int(12 * s), iy - int(3 * s)), 1)
        pygame.draw.line(surf, (140, 200, 240),
                         (ix + int(16 * s), iy),
                         (ix + int(10 * s), iy - int(2 * s)), 1)
        # HUD 빛 (콕핏 내부에서 나오는 미약한 빛)
        hud_gs = pygame.Surface((int(10 * s), int(6 * s)), pygame.SRCALPHA)
        hud_gs.fill((50, 200, 255, 8))
        surf.blit(hud_gs, (ix + int(8 * s), iy - int(3 * s)))

        # ===== 안테나/센서 (기수 첨단) =====
        pygame.draw.line(surf, (190, 205, 230),
                         (ix + int(26 * s), iy),
                         (ix + int(30 * s), iy), max(1, int(1 * s)))
        # 안테나 끝 점
        pygame.draw.circle(surf, (100, 200, 255),
                           (ix + int(30 * s), iy), max(1, int(1 * s)))

        # ===== 선체 외곽선 (주요 엣지) =====
        pygame.draw.polygon(surf, (80, 95, 130), body, 1)

        # ===== 러닝 라이트 (깜빡이는 표시등) =====
        blink = math.sin(self.time * 4) > 0.0  # 점멸
        if blink:
            # 선수 백색 라이트
            bw_gs = pygame.Surface((8, 8), pygame.SRCALPHA)
            pygame.draw.circle(bw_gs, (255, 255, 255, 60), (4, 4), 3)
            pygame.draw.circle(bw_gs, (255, 255, 255, 180), (4, 4), 1)
            surf.blit(bw_gs, (ix + int(24 * s) - 4, iy - 4))
            # 선미 호박색 라이트
            ba_gs = pygame.Surface((8, 8), pygame.SRCALPHA)
            pygame.draw.circle(ba_gs, (255, 180, 50, 50), (4, 4), 3)
            pygame.draw.circle(ba_gs, (255, 200, 80, 150), (4, 4), 1)
            surf.blit(ba_gs, (ix - int(12 * s) - 4, iy - 4))

        # ===== 실드 글로우 (이중 타원 에너지 쉴드) =====
        sr = int(28 * s)
        sa = _clamp(12 + 10 * math.sin(self.time * 3))
        ss = pygame.Surface((sr * 2 + 4, int(sr * 1.2) + 4), pygame.SRCALPHA)
        sc_x, sc_y = sr + 2, int(sr * 0.6) + 2
        # 외곽 쉴드
        pygame.draw.ellipse(ss, (60, 150, 255, sa),
                            (0, 0, sr * 2 + 4, int(sr * 1.2) + 4), 1)
        # 내곽 쉴드
        inner_a = max(1, sa // 2)
        pygame.draw.ellipse(ss, (100, 200, 255, inner_a),
                            (4, 2, sr * 2 - 4, int(sr * 1.2)), 1)
        surf.blit(ss, (ix + int(3 * s) - sc_x, iy - sc_y))

        # ===== 반사 하이라이트 (선체 위 빛 스펙) =====
        if s > 0.5:
            ref = pygame.Surface((int(20 * s), int(4 * s)), pygame.SRCALPHA)
            ref.fill((255, 255, 255, 12))
            surf.blit(ref, (ix + int(2 * s), iy - int(6 * s)))

        # 엔진 파티클 스폰
        if engine_power > 0.3:
            self._spawn_engine_particles(ix - int(14 * s), iy,
                                         max(1, int(3 * engine_power)))

    # ──────────────────────────────────────────────
    #  착륙 시퀀스: 수직 우주선
    # ──────────────────────────────────────────────
    def _draw_planet_surface(self, surf, planet_num, t, alpha=255):
        """행성 표면 렌더러 디스패처. t = 0(고공) ~ 1(지표면)."""
        renderer = self._SURFACE_RENDERERS.get(planet_num)
        if renderer:
            getattr(self, renderer)(surf, t, alpha)
        else:
            # 폴백: 테마 컬러 기반 단순 지형
            cfg = PLANET_CONFIGS.get(planet_num, {})
            base = cfg.get("theme_color", (80, 100, 80))
            self._draw_surface_generic(surf, base, t, alpha)

    def _draw_surface_generic(self, surf, base_color, t, alpha=255):
        """범용 표면 — 컬러 기반 단순 지형 + 구름."""
        W, H = surf.get_width(), surf.get_height()
        # 지형 배경
        surf.fill((*base_color, alpha))
        random.seed(7777)
        # 지형 패치
        for _ in range(25):
            px = random.randint(0, W)
            py = random.randint(0, H)
            pr = random.randint(30, 120)
            c = tuple(min(255, max(0, base_color[i] + random.randint(-30, 30)))
                      for i in range(3))
            ps = pygame.Surface((pr * 2, pr * 2), pygame.SRCALPHA)
            pygame.draw.circle(ps, (*c, min(255, int(alpha * 0.7))),
                               (pr, pr), pr)
            surf.blit(ps, (px - pr, py - pr))
        random.seed()
        # 구름
        cloud_a = max(0, int(220 * (1.0 - t * 2.5) * alpha / 255))
        if cloud_a > 3:
            random.seed(8888)
            for _ in range(15):
                cx = random.randint(-40, W + 40)
                cy = random.randint(-20, H + 20)
                cw = random.randint(60, 180)
                ch = random.randint(20, 50)
                cs = pygame.Surface((cw, ch), pygame.SRCALPHA)
                pygame.draw.ellipse(cs, (255, 255, 255, min(255, cloud_a)),
                                    (0, 0, cw, ch))
                surf.blit(cs, (cx - cw // 2, cy - ch // 2))
            random.seed()

    def _draw_surface_joseon(self, surf, t, alpha=255):
        """조선시대 행성 표면 — 초고퀄리티.
        t: 0(고공) ~ 1(지표면). 실제 Stage 1 맵 색상 반영."""
        W, H = surf.get_width(), surf.get_height()
        _cz_x, _cz_y = W // 2, H // 2
        _cz_hw, _cz_hh = 150, 120
        def _in_center(px, py):
            return abs(px - _cz_x) < _cz_hw and abs(py - _cz_y) < _cz_hh

        # ===== 기본 지형 — HD 1px 스무스 그라디언트 =====
        sky_blend = max(0.0, 1.0 - t * 3)
        for row in range(H):
            fy = row / H
            gr = int((100 + fy * 42) * (1 - sky_blend) + (162 + fy * 18) * sky_blend)
            gg = int((125 + fy * 38) * (1 - sky_blend) + (172 + fy * 12) * sky_blend)
            gb = int((42 + fy * 22) * (1 - sky_blend) + (202 - fy * 22) * sky_blend)
            pygame.draw.line(surf, (min(255, gr), min(255, gg), min(255, gb), alpha),
                             (0, row), (W, row))

        random.seed(1137)

        # ===== 논밭/초원 패치 (HD 다층 + 색상 다양화) =====
        for _ in range(95):
            px = random.randint(-60, W + 60)
            py = random.randint(-60, H + 60)
            pr = random.randint(22, 210)
            g = random.randint(78, 178)
            vtype = random.randint(0, 3)
            if vtype == 0:
                c = (max(0, g - 30 + random.randint(-15, 15)),
                     max(0, min(255, g + 8 + random.randint(-10, 10))),
                     max(0, g // 3 + random.randint(-5, 10)))
            elif vtype == 1:
                c = (max(0, min(255, g + 22)), max(0, min(255, g + 8)),
                     max(0, min(255, g // 4 + 5)))
            elif vtype == 2:
                c = (max(0, min(255, g - 12)), max(0, min(255, g + 22)),
                     max(0, min(255, g // 3 + 12)))
            else:
                c = (max(0, min(255, g - 5)), max(0, min(255, g - 28)),
                     max(0, min(255, g // 5 + 2)))
            ps = pygame.Surface((pr * 2, pr * 2), pygame.SRCALPHA)
            for li in range(pr, max(1, pr // 4), -max(1, pr // 8)):
                la = max(1, int(55 * alpha / 255 * li / pr))
                pygame.draw.circle(ps, (*c, la), (pr, pr), li)
            surf.blit(ps, (px - pr, py - pr))

        # ===== 미세 지면 질감 (흙알갱이/잔디끝) =====
        for _ in range(280):
            gx = random.randint(0, W - 1)
            gy = random.randint(0, H - 1)
            ga = random.randint(16, 38)
            gc = random.choice([
                (92, 85, 58), (82, 98, 52), (102, 92, 65),
                (75, 68, 48), (86, 102, 55), (70, 88, 45)])
            pygame.draw.circle(surf, (*gc, ga), (gx, gy), 1)

        # ===== 산맥 — 원경 (수묵화 실루엣 + 대기원근법) =====
        for _ in range(10):
            mx = random.randint(-80, W + 80)
            my = random.randint(-70, H // 5)
            mw = random.randint(120, 380)
            mh = random.randint(55, 175)
            mc_g = 60 + random.randint(0, 30)
            mc = (mc_g - 15, mc_g + 15, mc_g - 20)
            ma = min(255, int(130 * alpha / 255))
            ms = pygame.Surface((mw * 2, mh + 4), pygame.SRCALPHA)
            tri_pts = [(mw, 0), (0, mh), (mw * 2, mh)]
            pygame.draw.polygon(ms, (*mc, ma), tri_pts)
            # 산 하부 부드러운 블렌딩
            pygame.draw.ellipse(ms, (*mc, ma // 2),
                                (mw // 4, mh // 3, mw * 3 // 2, mh))
            # 능선 하이라이트 (햇빛 받는 면)
            hl_c = (min(255, mc[0] + 25), min(255, mc[1] + 20), min(255, mc[2] + 15))
            pygame.draw.line(ms, (*hl_c, ma // 2), (mw, 2), (mw // 3, mh * 2 // 3), 1)
            surf.blit(ms, (mx - mw, my - mh // 3))
            # 산기슭 안개
            fog_s = pygame.Surface((mw * 2, 20), pygame.SRCALPHA)
            for fi in range(20):
                fa = max(1, int(ma // 3 * (1 - fi / 20)))
                pygame.draw.line(fog_s, (180, 195, 210, fa),
                                 (0, fi), (mw * 2, fi))
            surf.blit(fog_s, (mx - mw, my + mh // 2 - 5))

        # ===== 수평 안개띠 (원경~중경 사이) =====
        for fi in range(4):
            fy = H // 8 + fi * H // 12
            fw = W + 60
            fh = random.randint(8, 18)
            fog_band = pygame.Surface((fw, fh), pygame.SRCALPHA)
            for row in range(fh):
                band_a = max(1, int(35 * math.sin(math.pi * row / fh)))
                pygame.draw.line(fog_band, (195, 205, 218, band_a),
                                 (0, row), (fw, row))
            surf.blit(fog_band, (-30, fy))

        # ===== 산맥 — 중경 (뚜렷한 삼각형 + 눈 + 능선 + 수목선) =====
        for _ in range(7):
            mx = random.randint(0, W)
            my = random.randint(0, H // 3)
            mw = random.randint(90, 260)
            mh = random.randint(50, 130)
            mc_g = random.randint(30, 65)
            mc = (mc_g, mc_g + 40 + random.randint(0, 20), mc_g - 5)
            peak_x = mx + random.randint(-mw // 5, mw // 5)
            tri = [(peak_x, my - mh // 2),
                   (mx - mw, my + mh // 2),
                   (mx + mw, my + mh // 2)]
            pygame.draw.polygon(surf, mc, tri)
            # 왼쪽 밝은 면 (햇빛)
            hl_c = (min(255, mc[0] + 40), min(255, mc[1] + 35), mc[2] + 20)
            pygame.draw.line(surf, hl_c, tri[0], (mx - mw // 3, my + mh // 4), 2)
            # 오른쪽 그림자 면
            sh_c = (max(0, mc[0] - 15), max(0, mc[1] - 15), max(0, mc[2] - 10))
            sh_tri = [tri[0], (mx + mw // 4, my + mh // 4), tri[2]]
            sh_s = pygame.Surface((mw * 2 + 2, mh + 2), pygame.SRCALPHA)
            sh_pts = [(p[0] - mx + mw, p[1] - my + mh // 2) for p in sh_tri]
            pygame.draw.polygon(sh_s, (*sh_c, 80), sh_pts)
            surf.blit(sh_s, (mx - mw, my - mh // 2))
            # 설선 (눈 덮인 정상)
            if mh > 55:
                snow_pts = [tri[0],
                            (peak_x - mw // 5, my - mh // 2 + mh // 3),
                            (peak_x + mw // 6, my - mh // 2 + mh // 4)]
                pygame.draw.polygon(surf, (235, 240, 238), snow_pts)
                pygame.draw.polygon(surf, (220, 225, 230), snow_pts, 1)
                # 설선 아래 밝은 선
                pygame.draw.line(surf, (210, 215, 220),
                                 snow_pts[1], snow_pts[2], 1)
            # 수목선 (산 하단 나무 실루엣)
            if mw > 100:
                tree_y = my + mh // 4
                for ti in range(mx - mw // 2, mx + mw // 2, random.randint(4, 8)):
                    th = random.randint(4, 10)
                    tg = random.randint(25, 50)
                    tc = (tg, tg + 30, tg - 5)
                    pygame.draw.polygon(surf, tc,
                                        [(ti, tree_y - th), (ti - 3, tree_y), (ti + 3, tree_y)])

        # ===== 개울 (HD — 둑 + 물결 + 반사 + 징검다리 + 물고기) =====
        for stream_i in range(2):
            pts_s = []
            y_off = 65 + stream_i * (H // 3)
            for step in range(60):
                st = step / 59
                sx = int(W * st)
                sy = y_off + int(68 * math.sin(st * math.pi * 2.5 + stream_i))
                pts_s.append((sx, sy))
            if len(pts_s) > 2:
                # 넓은 둑 (진흙 — 2겹)
                pts_bank_l = [(p[0], p[1] + 6) for p in pts_s]
                pts_bank_r = [(p[0], p[1] - 6) for p in pts_s]
                pygame.draw.lines(surf, (78, 62, 38), False, pts_bank_l, 4)
                pygame.draw.lines(surf, (82, 68, 42), False, pts_bank_r, 4)
                # 둑 위 풀
                for bi in range(5, len(pts_s) - 5, 6):
                    bx, by = pts_s[bi]
                    for side in [-1, 1]:
                        pygame.draw.line(surf, (55, 95, 40),
                                         (bx, by + side * 6),
                                         (bx + random.randint(-2, 2), by + side * 6 - 4), 1)
                # 물 (넓은 + 그라데이션)
                pygame.draw.lines(surf, (30, 68, 122), False, pts_s, 10)
                pygame.draw.lines(surf, (48, 95, 155), False, pts_s, 7)
                pygame.draw.lines(surf, (60, 110, 170), False, pts_s, 4)
                # 수면 반사 (밝은 하이라이트)
                pts_hl = [(p[0], p[1] - 2) for p in pts_s]
                pygame.draw.lines(surf, (95, 158, 215), False, pts_hl, 1)
                # 물결 무늬
                for si in range(3, len(pts_s) - 3, 4):
                    wx, wy = pts_s[si]
                    wl = random.randint(3, 7)
                    pygame.draw.line(surf, (120, 180, 228),
                                     (wx - wl, wy - 2), (wx + wl, wy - 2), 1)
                # 징검다리 (한쪽 개울에만)
                if stream_i == 0:
                    for si in range(len(pts_s) // 3, len(pts_s) // 3 + 5):
                        if si < len(pts_s):
                            sx, sy = pts_s[si]
                            if si % 2 == 0:
                                pygame.draw.ellipse(surf, (105, 100, 88),
                                                    (sx - 3, sy - 2, 7, 5))
                                pygame.draw.ellipse(surf, (120, 115, 102),
                                                    (sx - 2, sy - 1, 5, 3))
                # 돌 (개울 가장자리)
                for _ in range(5):
                    ri = random.randint(5, len(pts_s) - 5)
                    rx, ry = pts_s[ri]
                    rr = random.randint(2, 6)
                    pygame.draw.circle(surf, (68, 62, 55), (rx, ry), rr)
                    pygame.draw.circle(surf, (88, 82, 72), (rx - 1, ry - 1), max(1, rr - 1))
                    # 이끼
                    if rr > 3:
                        pygame.draw.circle(surf, (58, 82, 45, 80), (rx, ry - 1), max(1, rr - 2))
                # 물고기 (작은 실루엣)
                for _ in range(random.randint(1, 3)):
                    fi = random.randint(8, len(pts_s) - 8)
                    fx, fy = pts_s[fi]
                    fd = random.choice([-1, 1])
                    pygame.draw.polygon(surf, (55, 80, 45),
                                        [(fx, fy), (fx + fd * 4, fy - 1), (fx + fd * 4, fy + 1)])
                    pygame.draw.line(surf, (45, 70, 38),
                                     (fx + fd * 4, fy), (fx + fd * 6, fy - 1), 1)

        # ===== 연못 (HD — 거울반사 + 잉어 + 연꽃, 중앙 회피) =====
        for _ in range(4):
            px = random.randint(60, W - 60)
            py = random.randint(H // 3, H * 2 // 3)
            if _in_center(px, py):
                continue
            pw = random.randint(35, 72)
            ph = random.randint(20, 42)
            # 둑 (풀 테두리 + 진흙)
            pygame.draw.ellipse(surf, (70, 60, 38),
                                (px - pw // 2 - 5, py - ph // 2 - 3, pw + 10, ph + 6))
            pygame.draw.ellipse(surf, (72, 88, 48),
                                (px - pw // 2 - 4, py - ph // 2 - 2, pw + 8, ph + 4))
            # 물 표면 (그라데이션)
            pond_s = pygame.Surface((pw, ph), pygame.SRCALPHA)
            for row in range(ph):
                frac = row / ph
                pa = int(125 + frac * 65)
                r = int(38 + frac * 12)
                g = int(82 + frac * 15)
                b = int(125 + frac * 20)
                pygame.draw.line(pond_s, (r, g, b, pa), (0, row), (pw, row))
            surf.blit(pond_s, (px - pw // 2, py - ph // 2))
            # 수면 반사 (타원형 하이라이트)
            hl_s = pygame.Surface((pw // 2, ph // 3 + 2), pygame.SRCALPHA)
            pygame.draw.ellipse(hl_s, (108, 168, 208, 55),
                                (0, 0, pw // 2, ph // 3 + 2))
            surf.blit(hl_s, (px - pw // 4, py - ph // 4))
            # 잔물결 (동심원)
            if pw > 40:
                for ri in range(random.randint(1, 2)):
                    rcx = px + random.randint(-pw // 4, pw // 4)
                    rcy = py + random.randint(-ph // 4, ph // 4)
                    for rr in range(2, 6, 2):
                        pygame.draw.circle(surf, (100, 160, 200, 30), (rcx, rcy), rr, 1)
            # 연잎 (입체적)
            for _ in range(random.randint(2, 4)):
                lx = px + random.randint(-pw // 3, pw // 3)
                ly = py + random.randint(-ph // 4, ph // 4)
                lr = random.randint(3, 5)
                pygame.draw.circle(surf, (42, 98, 48), (lx, ly), lr)
                pygame.draw.circle(surf, (55, 115, 58), (lx, ly), max(1, lr - 1))
                # 잎맥
                pygame.draw.line(surf, (38, 85, 42), (lx, ly), (lx + lr, ly), 1)
            # 연꽃 (큰 연못)
            if pw > 45:
                fx = px + random.randint(-pw // 5, pw // 5)
                fy = py + random.randint(-ph // 5, ph // 5)
                for pi in range(5):
                    ang = pi * 72
                    dx = int(3 * math.cos(math.radians(ang)))
                    dy = int(2 * math.sin(math.radians(ang)))
                    pygame.draw.circle(surf, (245, 185, 195), (fx + dx, fy + dy), 2)
                pygame.draw.circle(surf, (255, 235, 130), (fx, fy), 1)
            # 잉어 (큰 연못에만)
            if pw > 50:
                for _ in range(random.randint(1, 2)):
                    kx = px + random.randint(-pw // 4, pw // 4)
                    ky = py + random.randint(-ph // 5, ph // 5)
                    kd = random.choice([-1, 1])
                    kc = random.choice([(205, 100, 42), (220, 170, 55), (200, 200, 195)])
                    pygame.draw.ellipse(surf, kc, (kx - 2, ky - 1, 5, 3))
                    pygame.draw.polygon(surf, kc,
                                        [(kx + kd * 3, ky), (kx + kd * 5, ky - 1), (kx + kd * 5, ky + 1)])

        # ===== 돌담/성벽 (중앙 회피) =====
        for _ in range(6):
            wx = random.randint(30, W - 30)
            wy = random.randint(H // 4, H * 3 // 4)
            if _in_center(wx, wy):
                continue
            wlen = random.randint(30, 80)
            wh = random.randint(3, 6)
            angle = random.choice([0, 1])  # 가로/세로
            if angle == 0:  # 가로
                pygame.draw.rect(surf, (100, 95, 85), (wx, wy, wlen, wh))
                pygame.draw.rect(surf, (120, 115, 105), (wx, wy, wlen, max(1, wh - 1)))
                # 석재 줄눈
                for si in range(wx + 4, wx + wlen - 2, max(5, wlen // 10)):
                    pygame.draw.line(surf, (80, 75, 68), (si, wy), (si, wy + wh), 1)
                # 담 위 기와
                for si in range(wx, wx + wlen, max(3, wlen // 12)):
                    pygame.draw.rect(surf, (55, 52, 48), (si, wy - 2, 3, 2))
            else:  # 세로
                pygame.draw.rect(surf, (100, 95, 85), (wx, wy, wh, wlen))
                pygame.draw.rect(surf, (120, 115, 105), (wx, wy, max(1, wh - 1), wlen))
                for si in range(wy + 4, wy + wlen - 2, max(5, wlen // 10)):
                    pygame.draw.line(surf, (80, 75, 68), (wx, si), (wx + wh, si), 1)

        # ===== 풀숲/수풀 (HD 3D 다층, 중앙 회피) =====
        for _ in range(55):
            bx = random.randint(5, W - 5)
            by = random.randint(H // 6, H - 10)
            if _in_center(bx, by):
                continue
            bsize = random.randint(5, 20)
            g_v = random.randint(-20, 20)
            bush_dk = (max(0, 30 + g_v), max(0, min(255, 78 + g_v)), max(0, 22 + g_v))
            bush_c = (max(0, 42 + g_v), max(0, min(255, 98 + g_v)), max(0, 32 + g_v))
            bush_c2 = (max(0, 58 + g_v), max(0, min(255, 118 + g_v)), max(0, 42 + g_v))
            bush_hl = (min(255, bush_c2[0] + 35), min(255, bush_c2[1] + 28), min(255, bush_c2[2] + 18))
            # 그림자 (소프트)
            sh_s = pygame.Surface((bsize * 3, bsize), pygame.SRCALPHA)
            pygame.draw.ellipse(sh_s, (0, 0, 0, 22), (0, 0, bsize * 3, bsize))
            surf.blit(sh_s, (bx - bsize * 3 // 2, by + bsize // 2))
            # 어두운 하부 (깊이감)
            for ci in range(random.randint(2, 3)):
                ox = random.randint(-bsize // 2, bsize // 2)
                oy = random.randint(0, bsize // 3)
                r = bsize - abs(ci) * 2 + random.randint(0, 2)
                if r < 2:
                    r = 2
                pygame.draw.circle(surf, bush_dk, (bx + ox, by + oy), r)
            # 수풀 본체 (3~5개 원 겹침)
            for ci in range(random.randint(3, 5)):
                ox = random.randint(-bsize // 2, bsize // 2)
                oy = random.randint(-bsize // 2, bsize // 3)
                r = bsize - abs(ci) + random.randint(0, 3)
                if r < 2:
                    r = 2
                pygame.draw.circle(surf, bush_c, (bx + ox, by + oy), r)
                pygame.draw.circle(surf, bush_c2, (bx + ox - 1, by + oy - 1), max(1, r - 1))
            # 하이라이트 (상부 좌측 — 햇빛)
            pygame.draw.circle(surf, bush_hl, (bx - 1, by - 2), max(1, bsize // 3))
            if bsize > 10:
                pygame.draw.circle(surf, bush_hl, (bx - bsize // 4, by - bsize // 4), max(1, bsize // 5))
            # 열매 (큰 수풀에만 — 빨간/보라 점)
            if bsize > 12 and random.random() < 0.35:
                bc = random.choice([(195, 55, 42), (155, 42, 110), (210, 150, 45)])
                for _ in range(random.randint(2, 4)):
                    bex = bx + random.randint(-bsize // 3, bsize // 3)
                    bey = by + random.randint(-bsize // 3, bsize // 4)
                    pygame.draw.circle(surf, bc, (bex, bey), 1)

        # ===== 소나무 숲 (HD 풍성, 중앙 회피) =====
        for _ in range(28):
            px = random.randint(10, W - 10)
            py_t = random.randint(H // 6, H * 2 // 3)
            if _in_center(px, py_t):
                continue
            ph = random.randint(20, 50)
            pw = random.randint(10, 20)
            # 그림자 (더 부드럽게)
            sh_s = pygame.Surface((pw * 3, 8), pygame.SRCALPHA)
            pygame.draw.ellipse(sh_s, (0, 0, 0, 22), (0, 0, pw * 3, 8))
            surf.blit(sh_s, (px - pw * 3 // 2, py_t + ph - 2))
            # 뿌리 (지면 근처)
            for ri in range(random.randint(2, 4)):
                rdx = random.choice([-1, 1]) * random.randint(2, 6)
                pygame.draw.line(surf, (62, 42, 22),
                                 (px, py_t + ph - 2), (px + rdx, py_t + ph + 1), 1)
            # 줄기 (나무껍질 질감)
            pygame.draw.line(surf, (48, 32, 16), (px + 1, py_t + 2), (px + 1, py_t + ph), 4)
            pygame.draw.line(surf, (75, 52, 28), (px, py_t), (px, py_t + ph), 3)
            pygame.draw.line(surf, (95, 68, 38), (px - 1, py_t + 2), (px - 1, py_t + ph - 2), 1)
            # 나무껍질 마디
            for bi in range(py_t + 5, py_t + ph - 3, max(4, ph // 6)):
                pygame.draw.line(surf, (42, 28, 14), (px - 1, bi), (px + 2, bi), 1)
            # 5단 수관 (더 풍성한 겹겹이)
            for layer_i in range(5):
                ly = py_t - layer_i * ph // 7
                lw = pw - layer_i * 2 + random.randint(-1, 1)
                lh_l = ph // 4 + random.randint(0, 3)
                g_var = random.randint(-15, 15)
                tc = (max(0, min(255, 28 + g_var)),
                      max(0, min(255, 72 + g_var)),
                      max(0, min(255, 22 + g_var)))
                tri = [(px + random.randint(-1, 1), ly - lh_l),
                       (px - lw, ly + 2), (px + lw, ly + 2)]
                pygame.draw.polygon(surf, tc, tri)
                # 하이라이트 (왼쪽 — 햇빛면)
                hl = (min(255, tc[0] + 35), min(255, tc[1] + 30), min(255, tc[2] + 18))
                pygame.draw.line(surf, hl, tri[0], tri[1], 1)
                # 어두운 면 (오른쪽)
                dk = (max(0, tc[0] - 14), max(0, tc[1] - 14), max(0, tc[2] - 10))
                pygame.draw.line(surf, dk, tri[0], tri[2], 1)
                # 잎 디테일 (내부 텍스처)
                if lw > 5:
                    for _ in range(random.randint(2, 4)):
                        dx = random.randint(-lw + 2, lw - 2)
                        dy = random.randint(-lh_l // 2, 0)
                        ld = (max(0, tc[0] + random.randint(-8, 8)),
                              max(0, min(255, tc[1] + random.randint(-8, 8))),
                              max(0, tc[2] + random.randint(-5, 5)))
                        pygame.draw.circle(surf, ld, (px + dx, ly + dy), 1)
            # 솔방울 (큰 나무만)
            if ph > 32:
                for _ in range(random.randint(1, 3)):
                    cx = px + random.randint(-pw // 2, pw // 2)
                    cy = py_t + random.randint(0, ph // 3)
                    pygame.draw.ellipse(surf, (85, 58, 28), (cx - 1, cy, 3, 4))
                    pygame.draw.circle(surf, (72, 48, 22), (cx, cy + 1), 1)

        # ===== 대나무 숲 (HD 질감 + 바람 효과, 중앙 회피) =====
        for _ in range(18):
            bx = random.randint(20, W - 20)
            by = random.randint(H // 4, H - 40)
            if _in_center(bx, by):
                continue
            bh = random.randint(30, 62)
            wind_dx = random.randint(-3, 3)
            # 그림자
            pygame.draw.ellipse(surf, (0, 0, 0, 15),
                                (bx - 3, by + bh, 6, 3))
            # 줄기 (그라데이션 — 아래 짙게 위로 밝게)
            for si in range(bh):
                frac = si / bh
                bend = int(wind_dx * frac * frac)
                gc = (max(0, int(65 + frac * 30)),
                      max(0, min(255, int(105 + frac * 40))),
                      max(0, int(40 + frac * 25)))
                pygame.draw.line(surf, gc,
                                 (bx + bend, by + si), (bx + bend + 1, by + si), 2)
            # 하이라이트 줄 (반사)
            for si in range(0, bh, 2):
                frac = si / bh
                bend = int(wind_dx * frac * frac)
                pygame.draw.line(surf, (105, 155, 75),
                                 (bx + bend - 1, by + si), (bx + bend - 1, by + si), 1)
            # 마디 (뚜렷하게)
            for ni in range(3, bh, max(5, bh // 6)):
                frac = ni / bh
                bend = int(wind_dx * frac * frac)
                pygame.draw.line(surf, (48, 85, 32),
                                 (bx + bend - 2, by + ni), (bx + bend + 3, by + ni), 1)
                # 마디 돌기
                pygame.draw.circle(surf, (55, 92, 38), (bx + bend - 2, by + ni), 1)
                pygame.draw.circle(surf, (55, 92, 38), (bx + bend + 3, by + ni), 1)
            # 잎 (방향성 있는 잎사귀)
            for _ in range(random.randint(5, 10)):
                lni = random.randint(1, max(1, bh // 5 - 1))
                lby = by + lni * max(5, bh // 5)
                if lby > by + bh:
                    lby = by + bh - 5
                frac = (lby - by) / bh
                lbend = int(wind_dx * frac * frac)
                ldir = random.choice([-1, 1])
                ldx = ldir * random.randint(8, 22)
                ldy = random.randint(-8, 2)
                lc = (max(0, 58 + random.randint(-8, 8)),
                      max(0, min(255, 105 + random.randint(-10, 15))),
                      max(0, 38 + random.randint(-5, 5)))
                pygame.draw.line(surf, lc, (bx + lbend, lby),
                                 (bx + lbend + ldx, lby + ldy), 1)
                # 잎 끝 (뾰족하게)
                pygame.draw.line(surf, lc,
                                 (bx + lbend + ldx, lby + ldy),
                                 (bx + lbend + ldx + ldir * 3, lby + ldy - 2), 1)

        # ===== 벚꽃 나무 (HD 풍성한 꽃구름 + 꽃잎 비산, 중앙 회피) =====
        detail_a = min(255, int(255 * max(0, t * 2 - 0.2)))
        if detail_a > 10:
            for _ in range(35):
                fx = random.randint(20, W - 20)
                fy = random.randint(H // 6, H - 30)
                if _in_center(fx, fy):
                    continue
                trunk_h = random.randint(18, 48)
                # 그림자 (더 부드럽게)
                sh_s = pygame.Surface((trunk_h + 12, 10), pygame.SRCALPHA)
                pygame.draw.ellipse(sh_s, (0, 0, 0, 25), (0, 0, trunk_h + 12, 10))
                surf.blit(sh_s, (fx - 6, fy + trunk_h))
                # 줄기 (HD 나무껍질 — 가로줄 질감)
                pygame.draw.line(surf, (48, 32, 14), (fx + 1, fy + 2), (fx + 1, fy + trunk_h), 6)
                pygame.draw.line(surf, (92, 65, 32), (fx, fy), (fx, fy + trunk_h), 4)
                pygame.draw.line(surf, (125, 92, 52), (fx - 1, fy + 2), (fx - 1, fy + trunk_h - 2), 1)
                # 나무껍질 가로줄
                for bki in range(fy + 4, fy + trunk_h - 2, max(3, trunk_h // 8)):
                    pygame.draw.line(surf, (65, 42, 20), (fx - 2, bki), (fx + 3, bki), 1)
                # 가지 (곡선 — 더 자연스럽게)
                for bi in range(random.randint(5, 8)):
                    bx_e = fx + random.randint(-30, 30)
                    by_e = fy - random.randint(-3, 16)
                    mid_x = (fx + bx_e) // 2 + random.randint(-8, 8)
                    mid_y = (fy + by_e) // 2 - random.randint(3, 12)
                    pygame.draw.line(surf, (78, 52, 25), (fx, fy + 3), (mid_x, mid_y), 2)
                    pygame.draw.line(surf, (85, 58, 30), (mid_x, mid_y), (bx_e, by_e), 1)
                    # 잔가지
                    if abs(bx_e - fx) > 10:
                        sx = (mid_x + bx_e) // 2 + random.randint(-4, 4)
                        sy = (mid_y + by_e) // 2 - random.randint(0, 5)
                        pygame.draw.line(surf, (85, 58, 30), (sx, sy),
                                         (sx + random.randint(-6, 6), sy - random.randint(2, 6)), 1)
                # 벚꽃 구름 (HD — 더 많은 레이어 + 색상 다양)
                for _ in range(random.randint(14, 28)):
                    bx_p = fx + random.randint(-32, 32)
                    by_p = fy + random.randint(-35, 5)
                    br = random.randint(3, 16)
                    ba = min(255, int(detail_a * 0.8))
                    bs = pygame.Surface((br * 2 + 10, br * 2 + 10), pygame.SRCALPHA)
                    bc = br + 5
                    # 다층 글로우
                    for gi in range(br + 4, 0, -1):
                        ga = max(1, int(ba * gi / (br + 4) * 0.5))
                        ptype = random.randint(0, 2)
                        if ptype == 0:
                            pnk = (255, 155 + random.randint(0, 80),
                                   175 + random.randint(0, 55), ga)
                        elif ptype == 1:
                            pnk = (255, 200 + random.randint(0, 40),
                                   210 + random.randint(0, 30), ga)
                        else:
                            pnk = (255, 130 + random.randint(0, 60),
                                   155 + random.randint(0, 50), ga)
                        pygame.draw.circle(bs, pnk, (bc, bc), gi)
                    surf.blit(bs, (bx_p - bc, by_p - bc))
                # 꽃송이 디테일 (큰 나무)
                if trunk_h > 25:
                    for _ in range(random.randint(5, 12)):
                        px_f = fx + random.randint(-22, 22)
                        py_f = fy + random.randint(-25, -2)
                        # 5잎 꽃
                        for pi in range(5):
                            ang = pi * 72 + random.randint(-10, 10)
                            dx = int(2 * math.cos(math.radians(ang)))
                            dy = int(2 * math.sin(math.radians(ang)))
                            pygame.draw.circle(surf, (255, 195, 210, min(255, ba)),
                                               (px_f + dx, py_f + dy), 1)
                        pygame.draw.circle(surf, (255, 235, 140), (px_f, py_f), 1)
            # ===== 흩날리는 꽃잎 (지면 위 비산) =====
            for _ in range(80):
                px = random.randint(5, W - 5)
                py = random.randint(5, H - 5)
                pa = min(255, int(detail_a * random.uniform(0.3, 0.7)))
                pc = random.choice([
                    (255, 190, 200), (255, 210, 215), (255, 175, 190),
                    (255, 220, 225), (255, 200, 210)])
                ps = random.randint(1, 3)
                if ps == 1:
                    pygame.draw.circle(surf, (*pc, pa), (px, py), 1)
                else:
                    dx = random.randint(-2, 2)
                    dy = random.randint(-1, 1)
                    pygame.draw.line(surf, (*pc, pa),
                                     (px, py), (px + dx, py + dy), 1)

        # ===== 헬퍼: 기와지붕 (궁궐급 디테일) =====
        def _draw_tiled_roof(sx, sy, rw, rh, double=False, palace=False):
            """기와지붕. palace=True면 합각/팔작 지붕 + 잡상."""
            # --- 겹처마 (하층 지붕, double일 때) ---
            if double and rh > 12:
                sub_w = rw - 4
                sub_h = rh // 3 + 2
                # 하층 지붕면
                sub_l = [(sx - sub_w // 2, sy),
                         (sx - sub_w // 2 + sub_w // 6, sy - sub_h // 2),
                         (sx + sub_w // 2 - sub_w // 6, sy - sub_h // 2),
                         (sx + sub_w // 2, sy)]
                pygame.draw.polygon(surf, (52, 50, 46), sub_l)
                # 하층 처마 곡선
                pygame.draw.arc(surf, (60, 56, 50),
                                (sx - sub_w // 2 - 3, sy - sub_h,
                                 sub_w + 6, sub_h * 2), 0, math.pi, 2)
                # 하층 금장
                pygame.draw.arc(surf, (180, 145, 58),
                                (sx - sub_w // 2 - 4, sy - sub_h - 1,
                                 sub_w + 8, sub_h * 2 + 2), 0, math.pi, 1)
            # --- 주 지붕 (팔작/맞배) ---
            if palace and rw > 30:
                # 팔작지붕: 사다리꼴 상부 + 삼각형 합각
                top_w = rw * 2 // 3
                roof_trap = [(sx - top_w // 2, sy - rh),
                             (sx + top_w // 2, sy - rh),
                             (sx + rw // 2, sy),
                             (sx - rw // 2, sy)]
                pygame.draw.polygon(surf, (40, 40, 38), roof_trap)
                # 좌측 밝은 면
                pygame.draw.polygon(surf, (58, 56, 52),
                                    [roof_trap[0], roof_trap[3],
                                     (sx - rw // 4, sy - rh // 3)])
                # 합각 삼각형 (좌우 측면 — 벽 보이는 부분)
                gable_h = rh // 3
                # 좌
                gable_l = [(sx - rw // 2, sy),
                           (sx - top_w // 2, sy - rh),
                           (sx - rw // 2, sy - rh + gable_h)]
                pygame.draw.polygon(surf, (200, 182, 142), gable_l)
                pygame.draw.polygon(surf, (160, 75, 40), gable_l, 1)
                # 우
                gable_r = [(sx + rw // 2, sy),
                           (sx + top_w // 2, sy - rh),
                           (sx + rw // 2, sy - rh + gable_h)]
                pygame.draw.polygon(surf, (190, 172, 135), gable_r)
                pygame.draw.polygon(surf, (160, 75, 40), gable_r, 1)
                # 합각 내부 문양 (X자 장식)
                gcx = (gable_l[0][0] + gable_l[1][0] + gable_l[2][0]) // 3
                gcy = (gable_l[0][1] + gable_l[1][1] + gable_l[2][1]) // 3
                pygame.draw.line(surf, (140, 62, 32), (gcx - 3, gcy - 2), (gcx + 3, gcy + 2), 1)
                pygame.draw.line(surf, (140, 62, 32), (gcx + 3, gcy - 2), (gcx - 3, gcy + 2), 1)
            else:
                # 맞배지붕 (삼각형)
                roof_pts = [(sx, sy - rh),
                            (sx - rw // 2, sy),
                            (sx + rw // 2, sy)]
                pygame.draw.polygon(surf, (40, 40, 38), roof_pts)
                pygame.draw.polygon(surf, (58, 56, 52),
                                    [roof_pts[0], roof_pts[1], (sx - 2, sy)])
            # --- 기와 골 (가로 줄) ---
            rows = max(3, rh // 5)
            for ri in range(rows):
                ry_l = sy - rh + (ri + 1) * rh // (rows + 1)
                frac = (ri + 1) / (rows + 1)
                hw = int(rw // 2 * (1.0 - frac * 0.3))
                pygame.draw.line(surf, (52, 50, 45), (sx - hw, ry_l), (sx + hw, ry_l), 1)
                # 기와 세로 점선 (암키와 표현)
                if rw > 40:
                    for ti in range(sx - hw + 4, sx + hw - 2, max(4, rw // 12)):
                        pygame.draw.line(surf, (48, 46, 42),
                                         (ti, ry_l - 1), (ti, ry_l + 1), 1)
            # --- 처마 곡선 (날렵한 추녀) ---
            pygame.draw.arc(surf, (55, 52, 46),
                            (sx - rw // 2 - 5, sy - rh, rw + 10, rh * 2),
                            0, math.pi, max(2, rw // 16))
            # 금장 처마
            pygame.draw.arc(surf, (188, 152, 65),
                            (sx - rw // 2 - 6, sy - rh - 1, rw + 12, rh * 2 + 2),
                            0, math.pi, 1)
            # --- 용마루 (두꺼운 마룻대 + 양성/양성바름) ---
            ridge_hw = rw // 4
            pygame.draw.line(surf, (68, 65, 58),
                             (sx - ridge_hw, sy - rh + 2),
                             (sx + ridge_hw, sy - rh + 2), 4)
            # 양성바름 (석회 흰선)
            pygame.draw.line(surf, (180, 175, 165),
                             (sx - ridge_hw + 1, sy - rh + 1),
                             (sx + ridge_hw - 1, sy - rh + 1), 1)
            # 보주/절병통
            pygame.draw.circle(surf, (218, 180, 88), (sx, sy - rh), 3)
            pygame.draw.circle(surf, (245, 215, 120), (sx, sy - rh), 2)
            # --- 치미/취두 (좌우 꼬리 장식) ---
            pygame.draw.line(surf, (65, 60, 52),
                             (sx - rw // 2, sy), (sx - rw // 2 - 4, sy - 6), 2)
            pygame.draw.line(surf, (65, 60, 52),
                             (sx + rw // 2, sy), (sx + rw // 2 + 4, sy - 6), 2)
            # 치미 끝 금장
            pygame.draw.circle(surf, (195, 160, 65),
                               (sx - rw // 2 - 4, sy - 6), 1)
            pygame.draw.circle(surf, (195, 160, 65),
                               (sx + rw // 2 + 4, sy - 6), 1)
            # --- 잡상 (palace일 때 — 추녀 위 작은 동물 장식) ---
            if palace and rw > 40:
                for side in [-1, 1]:
                    jx_s = sx + side * (rw // 2 - 6)
                    jy_s = sy - 3
                    for ji in range(min(3, rw // 20)):
                        jxx = jx_s - side * ji * 4
                        pygame.draw.rect(surf, (75, 70, 62), (jxx - 1, jy_s - 2, 3, 2))

        # ===== 헬퍼: 단청 무늬 (화려한 머리초/뇌록) =====
        def _draw_dancheong(sx, sy, w, rows=7):
            """처마 아래 단청 장식. rows가 클수록 화려."""
            dc_colors = [
                (158, 35, 25), (205, 165, 68), (35, 50, 108),
                (45, 115, 55), (188, 75, 35), (130, 42, 82), (210, 132, 48),
            ]
            for di in range(min(rows, len(dc_colors))):
                if sy + 1 + di < sy + 50:
                    pygame.draw.line(surf, dc_colors[di],
                                     (sx - w // 2, sy + 1 + di),
                                     (sx + w // 2, sy + 1 + di), 1)
            # 머리초 패턴 (좌우 끝에 짧은 장식 줄)
            if w > 20 and rows >= 5:
                for side in [-1, 1]:
                    ex = sx + side * (w // 2 - 2)
                    pygame.draw.rect(surf, (158, 35, 25),
                                     (ex - 2, sy + 1, 4, min(rows, 5)))
                    pygame.draw.rect(surf, (210, 168, 70),
                                     (ex - 1, sy + 2, 2, min(rows - 2, 3)))

        # ===== 헬퍼: 빨간 기둥 (초석+두공 포함) =====
        def _draw_red_pillars(sx, sy_top, sy_bot, bw, spacing=None, with_gongpo=False):
            sp = spacing or max(7, bw // 4)
            for col_off in range(-bw // 2 + 4, bw // 2, sp):
                px = sx + col_off
                # 초석 (기둥 받침돌)
                pygame.draw.rect(surf, (100, 95, 85),
                                 (px - 3, sy_bot, 6, 3))
                # 기둥 본체 (3단 질감)
                pygame.draw.line(surf, (100, 28, 18), (px + 1, sy_top), (px + 1, sy_bot), 5)
                pygame.draw.line(surf, (138, 48, 32), (px, sy_top), (px, sy_bot), 3)
                pygame.draw.line(surf, (175, 78, 52), (px - 1, sy_top + 1), (px - 1, sy_bot - 1), 1)
                # 기둥 머리 장식 (주두)
                pygame.draw.rect(surf, (125, 42, 28), (px - 3, sy_top - 1, 6, 2))
                # 공포 (두공 — 기둥 상부 받침 구조)
                if with_gongpo:
                    pygame.draw.rect(surf, (110, 38, 25), (px - 4, sy_top - 3, 8, 2))
                    pygame.draw.rect(surf, (135, 52, 35), (px - 3, sy_top - 2, 6, 1))

        # ===== 궁궐/전각 (대형 건축물, 중앙 회피) =====
        for _ in range(8):
            bx = random.randint(55, W - 55)
            by = random.randint(H // 4, H * 3 // 4)
            if _in_center(bx, by):
                continue
            bw = random.randint(50, 115)
            bh = random.randint(24, 55)
            is_big = bw > 70
            # 그림자 (넓고 부드럽게)
            sh_s = pygame.Surface((bw + 32, 16), pygame.SRCALPHA)
            pygame.draw.ellipse(sh_s, (0, 0, 0, 20), (0, 0, bw + 32, 16))
            surf.blit(sh_s, (bx - bw // 2 - 16, by + bh + max(5, bh // 3)))
            # === 기단 (3단 석축 + 줄눈 + 계단 + 답도) ===
            base_h = max(6, bh // 3)
            for bi, bc in enumerate([(48, 45, 40), (62, 58, 50), (78, 74, 65)]):
                offs = (2 - bi) * 2
                pygame.draw.rect(surf, bc,
                                 (bx - bw // 2 - 6 + offs, by + bh + bi,
                                  bw + 12 - offs * 2, base_h - bi))
            # 석축 줄눈 (가로+세로)
            for gi in range(0, bw + 10, max(4, bw // 10)):
                pygame.draw.line(surf, (38, 35, 28),
                                 (bx - bw // 2 - 5 + gi, by + bh),
                                 (bx - bw // 2 - 5 + gi, by + bh + base_h), 1)
            for gi in range(base_h):
                if gi % 3 == 0:
                    pygame.draw.line(surf, (38, 35, 28),
                                     (bx - bw // 2 - 5, by + bh + gi),
                                     (bx + bw // 2 + 5, by + bh + gi), 1)
            # 계단 (정면 — 3단)
            stair_w = max(10, bw // 4)
            for si in range(4):
                sw = stair_w - si * 2
                pygame.draw.rect(surf, (88, 84, 76),
                                 (bx - sw // 2, by + bh + base_h - si * 2, sw, 2))
            # 답도 (계단 가운데 장식 돌판)
            if stair_w > 10:
                pygame.draw.rect(surf, (110, 105, 95),
                                 (bx - 2, by + bh + 1, 4, base_h + 2))
                pygame.draw.circle(surf, (130, 120, 100), (bx, by + bh + base_h // 2 + 1), 1)
            # === 벽체 (황토 회벽) ===
            pygame.draw.rect(surf, (218, 200, 158), (bx - bw // 2, by, bw, bh))
            # 벽체 테두리
            pygame.draw.rect(surf, (195, 178, 138), (bx - bw // 2, by, bw, bh), 1)
            # === 문/창 — 꽃살문 + 교창 ===
            if bw > 38:
                win_l = bx - bw // 2 + 5
                win_r = bx + bw // 2 - 5
                win_t = by + max(8, bh // 4)
                win_b = by + bh - 3
                # 문틀 (빨간 나무)
                pygame.draw.rect(surf, (125, 65, 32), (win_l - 1, win_t - 1,
                                 win_r - win_l + 2, win_b - win_t + 2), 1)
                # 격자 (꽃살문 — 대각선 포함)
                cell_w = max(4, bw // 8)
                cell_h = max(4, bh // 5)
                for wi in range(win_l, win_r, cell_w):
                    for wj in range(win_t, win_b, cell_h):
                        cw = min(cell_w - 1, win_r - wi)
                        ch = min(cell_h - 1, win_b - wj)
                        if cw > 2 and ch > 2:
                            # 종이면 (미색)
                            pygame.draw.rect(surf, (232, 225, 208), (wi, wj, cw, ch))
                            # 살대 (세로+가로)
                            pygame.draw.rect(surf, (165, 142, 105), (wi, wj, cw, ch), 1)
                            # 꽃살 대각선 (큰 칸만)
                            if cw > 4 and ch > 4:
                                pygame.draw.line(surf, (158, 135, 98),
                                                 (wi, wj), (wi + cw, wj + ch), 1)
                # 큰 건물: 중앙 대문 (쌍여닫이)
                if is_big:
                    dw = max(8, bw // 5)
                    dh = bh - max(8, bh // 4)
                    dl = bx - dw // 2
                    dt = by + max(8, bh // 4)
                    # 문짝 (어두운 나무)
                    pygame.draw.rect(surf, (88, 48, 22), (dl, dt, dw, dh))
                    # 문짝 나눔선 (가운데)
                    pygame.draw.line(surf, (60, 32, 15),
                                     (bx, dt), (bx, dt + dh), 1)
                    # 문짝 판자 질감
                    for pi in range(dl + 2, dl + dw - 1, max(2, dw // 4)):
                        pygame.draw.line(surf, (75, 40, 18),
                                         (pi, dt + 1), (pi, dt + dh - 1), 1)
                    # 문틀
                    pygame.draw.rect(surf, (115, 62, 30), (dl, dt, dw, dh), 1)
                    # 문고리 (금색 둥근 고리)
                    for mx_off in [-dw // 4, dw // 4]:
                        pygame.draw.circle(surf, (205, 175, 82),
                                           (bx + mx_off, dt + dh // 2), 2)
                        pygame.draw.circle(surf, (230, 200, 105),
                                           (bx + mx_off, dt + dh // 2), 1)
                    # 문 상부 빗살 (교창)
                    for li in range(dl + 1, dl + dw, max(2, dw // 6)):
                        pygame.draw.line(surf, (100, 55, 25),
                                         (li, dt), (li, dt + 3), 1)
            # === 단청 (화려한 머리초) ===
            _draw_dancheong(bx, by, bw - 2, rows=7 if is_big else 5)
            # === 기둥 (공포 포함) ===
            _draw_red_pillars(bx, by + max(8, bh // 4), by + bh, bw,
                              with_gongpo=is_big)
            # === 기와지붕 (팔작지붕 — 궁궐급) ===
            rw = bw + 24
            rh = max(16, bh + 8)
            _draw_tiled_roof(bx, by, rw, rh, double=is_big, palace=is_big)

        # ===== 한옥/민가 (HD 작은 건물, 중앙 회피) =====
        for _ in range(10):
            hx = random.randint(40, W - 40)
            hy = random.randint(H // 5, H * 4 // 5)
            if _in_center(hx, hy):
                continue
            hw = random.randint(24, 52)
            hh = random.randint(14, 32)
            # 그림자 (부드러운 타원)
            sh_s = pygame.Surface((hw + 18, 10), pygame.SRCALPHA)
            pygame.draw.ellipse(sh_s, (0, 0, 0, 22), (0, 0, hw + 18, 10))
            surf.blit(sh_s, (hx - hw // 2 - 9, hy + hh + 2))
            # 기단 (2단 돌 + 줄눈)
            pygame.draw.rect(surf, (78, 74, 65),
                             (hx - hw // 2 - 3, hy + hh + 1, hw + 6, 4))
            pygame.draw.rect(surf, (92, 87, 78),
                             (hx - hw // 2 - 2, hy + hh, hw + 4, 3))
            for gi in range(hx - hw // 2 - 1, hx + hw // 2 + 1, max(4, hw // 8)):
                pygame.draw.line(surf, (65, 60, 52), (gi, hy + hh), (gi, hy + hh + 4), 1)
            # 벽 (흰 회벽 — 약간의 질감)
            pygame.draw.rect(surf, (228, 220, 202), (hx - hw // 2, hy, hw, hh))
            # 회벽 질감 (미세한 얼룩)
            for _ in range(hw // 4):
                tx = hx - hw // 2 + random.randint(1, hw - 2)
                ty = hy + random.randint(1, hh - 2)
                pygame.draw.circle(surf, (218, 210, 192, 80), (tx, ty), 1)
            # 나무 뼈대 (격자형 — 심벽)
            pygame.draw.line(surf, (110, 78, 42),
                             (hx, hy), (hx, hy + hh), 1)
            pygame.draw.line(surf, (110, 78, 42),
                             (hx - hw // 2, hy + hh // 2),
                             (hx + hw // 2, hy + hh // 2), 1)
            # 벽체 테두리
            pygame.draw.rect(surf, (105, 75, 40), (hx - hw // 2, hy, hw, hh), 1)
            # 창호 (한쪽에 창호지 창)
            if hw > 28:
                ww = max(5, hw // 5)
                wh = max(5, hh // 2)
                wx = hx - hw // 4 - ww // 2
                wy = hy + (hh - wh) // 2
                pygame.draw.rect(surf, (235, 228, 212), (wx, wy, ww, wh))
                pygame.draw.rect(surf, (120, 85, 45), (wx, wy, ww, wh), 1)
                # 창살 (가로+세로)
                pygame.draw.line(surf, (115, 80, 42), (wx + ww // 2, wy), (wx + ww // 2, wy + wh), 1)
                pygame.draw.line(surf, (115, 80, 42), (wx, wy + wh // 2), (wx + ww, wy + wh // 2), 1)
            # 문 (나무문 + 문틀 + 고리)
            dw = max(5, hw // 5)
            dh = max(7, hh * 2 // 3)
            dl = hx - dw // 2
            dt = hy + hh - dh
            pygame.draw.rect(surf, (92, 58, 28), (dl, dt, dw, dh))
            pygame.draw.rect(surf, (112, 72, 35), (dl, dt, dw, dh), 1)
            # 문 판자 질감
            for pi in range(dl + 2, dl + dw - 1, max(2, dw // 3)):
                pygame.draw.line(surf, (78, 48, 22), (pi, dt + 1), (pi, dt + dh - 1), 1)
            # 문고리
            pygame.draw.circle(surf, (165, 140, 65), (dl + dw // 2, dt + dh // 2), 1)
            # 굴뚝 (큰 한옥만)
            if hw > 38:
                cx = hx + hw // 3
                cy = hy + hh - 3
                pygame.draw.rect(surf, (92, 85, 75), (cx, cy - 8, 4, 8))
                pygame.draw.rect(surf, (78, 72, 62), (cx - 1, cy - 9, 6, 2))
            # 초가지붕 / 기와지붕
            rw = hw + 12
            rh = max(9, hh // 2 + 5)
            is_thatch = random.random() < 0.5
            if is_thatch:
                # 초가지붕 (HD — 짚 질감 풍성)
                roof_pts = [(hx, hy - rh),
                            (hx - rw // 2, hy + 1),
                            (hx + rw // 2, hy + 1)]
                pygame.draw.polygon(surf, (142, 122, 65), roof_pts)
                pygame.draw.polygon(surf, (162, 138, 75),
                                    [roof_pts[0], roof_pts[1], (hx, hy)])
                # 짚 질감 (촘촘한 가로선)
                for si in range(rh):
                    sy_l = hy - rh + si + 1
                    frac = si / rh
                    shw = int(rw // 2 * frac)
                    sc = random.choice([(128, 108, 55), (135, 115, 60), (140, 120, 65)])
                    pygame.draw.line(surf, sc, (hx - shw, sy_l), (hx + shw, sy_l), 1)
                # 용마루 (두꺼운 짚 뭉치)
                pygame.draw.line(surf, (155, 135, 72),
                                 (hx - rw // 5, hy - rh + 1),
                                 (hx + rw // 5, hy - rh + 1), 4)
                pygame.draw.line(surf, (170, 148, 82),
                                 (hx - rw // 5, hy - rh),
                                 (hx + rw // 5, hy - rh), 2)
                # 처마 끝 (짚 늘어짐)
                for si in range(hx - rw // 2, hx + rw // 2, max(3, rw // 8)):
                    pygame.draw.line(surf, (125, 105, 52),
                                     (si, hy + 1), (si + random.randint(-1, 1), hy + 3), 1)
            else:
                _draw_tiled_roof(hx, hy, rw, rh)

        # ===== 정자 — 사모정 (HD, 중앙 회피) =====
        for _ in range(4):
            jx = random.randint(55, W - 55)
            jy = random.randint(H // 3, H * 2 // 3)
            if _in_center(jx, jy):
                continue
            jw = random.randint(22, 36)
            jh = random.randint(15, 24)
            # 그림자
            sh_s = pygame.Surface((jw + 14, 8), pygame.SRCALPHA)
            pygame.draw.ellipse(sh_s, (0, 0, 0, 22), (0, 0, jw + 14, 8))
            surf.blit(sh_s, (jx - jw // 2 - 7, jy + jh + 2))
            # 초석 (4개 모서리 돌)
            for cx, cy in [(jx - jw // 2 + 1, jy + jh), (jx + jw // 2 - 1, jy + jh)]:
                pygame.draw.rect(surf, (95, 90, 80), (cx - 2, cy, 4, 3))
            # 마루 (나무 바닥 — 결 표현)
            pygame.draw.rect(surf, (168, 145, 102), (jx - jw // 2, jy, jw, jh))
            pygame.draw.rect(surf, (150, 130, 90), (jx - jw // 2, jy, jw, jh), 1)
            # 마루 널 (촘촘한 가로줄)
            for mi in range(jy + 2, jy + jh, max(2, jh // 6)):
                pygame.draw.line(surf, (142, 122, 84),
                                 (jx - jw // 2 + 1, mi), (jx + jw // 2 - 1, mi), 1)
            # 난간 (빨간 난간 — 상하 가로대 + 세로살)
            pygame.draw.line(surf, (138, 48, 32),
                             (jx - jw // 2, jy), (jx + jw // 2, jy), 1)
            pygame.draw.line(surf, (138, 48, 32),
                             (jx - jw // 2, jy + jh), (jx + jw // 2, jy + jh), 1)
            for ni in range(jx - jw // 2 + 3, jx + jw // 2 - 1, max(3, jw // 6)):
                pygame.draw.line(surf, (140, 50, 35), (ni, jy), (ni, jy + 2), 1)
                pygame.draw.line(surf, (140, 50, 35), (ni, jy + jh - 2), (ni, jy + jh), 1)
            # 기둥 4개 (초석 위 — 빨간 기둥)
            for cx, cy in [(jx - jw // 2 + 1, jy + 1), (jx + jw // 2 - 1, jy + 1),
                           (jx - jw // 2 + 1, jy + jh - 1), (jx + jw // 2 - 1, jy + jh - 1)]:
                pygame.draw.circle(surf, (130, 45, 28), (cx, cy), 2)
                pygame.draw.circle(surf, (168, 65, 42), (cx, cy), 1)
            # 사모지붕 (HD — 기와골 + 단청)
            roof_r = jw // 2 + 7
            roof_h = jh // 2 + 6
            roof_pts_j = [(jx, jy - roof_h),
                          (jx - roof_r, jy + 1),
                          (jx + roof_r, jy + 1)]
            pygame.draw.polygon(surf, (45, 43, 40), roof_pts_j)
            # 밝은 면
            pygame.draw.polygon(surf, (60, 56, 50),
                                [roof_pts_j[0], roof_pts_j[1], (jx - 2, jy)])
            # 기와골 (가로줄)
            for ri in range(3):
                ry = jy - roof_h + (ri + 1) * roof_h // 4
                frac = (ri + 1) / 4
                rhw = int(roof_r * frac)
                pygame.draw.line(surf, (52, 50, 45), (jx - rhw, ry), (jx + rhw, ry), 1)
            # 추녀 곡선 (날렵한)
            pygame.draw.arc(surf, (55, 52, 46),
                            (jx - roof_r - 3, jy - roof_h, roof_r * 2 + 6, roof_h * 2 + 2),
                            0, math.pi, 2)
            # 금장 처마
            pygame.draw.arc(surf, (185, 150, 62),
                            (jx - roof_r - 4, jy - roof_h - 1, roof_r * 2 + 8, roof_h * 2 + 4),
                            0, math.pi, 1)
            # 단청 (처마 아래)
            _draw_dancheong(jx, jy, jw - 2, rows=3)
            # 보주 (꼭대기 장식)
            pygame.draw.circle(surf, (215, 178, 82), (jx, jy - roof_h), 3)
            pygame.draw.circle(surf, (245, 210, 115), (jx, jy - roof_h), 1)
            # 치미 (좌우)
            pygame.draw.line(surf, (62, 58, 50),
                             (jx - roof_r, jy + 1), (jx - roof_r - 3, jy - 3), 1)
            pygame.draw.line(surf, (62, 58, 50),
                             (jx + roof_r, jy + 1), (jx + roof_r + 3, jy - 3), 1)

        # ===== 팔각정 (연못/개울 옆, 중앙 회피) =====
        for _ in range(2):
            ox = random.randint(65, W - 65)
            oy = random.randint(H // 3, H * 2 // 3)
            if _in_center(ox, oy):
                continue
            orad = random.randint(15, 24)
            # 원형 마루
            pygame.draw.circle(surf, (168, 148, 108), (ox, oy), orad)
            pygame.draw.circle(surf, (148, 128, 92), (ox, oy), orad, 1)
            # 마루 결
            for mi in range(-orad + 2, orad - 1, 3):
                hw_l = int(math.sqrt(max(0, orad * orad - mi * mi)))
                if hw_l > 1:
                    pygame.draw.line(surf, (140, 122, 85),
                                     (ox - hw_l, oy + mi), (ox + hw_l, oy + mi), 1)
            # 기둥 8개
            for ang in range(0, 360, 45):
                cx = ox + int(orad * 0.72 * math.cos(math.radians(ang)))
                cy = oy + int(orad * 0.72 * math.sin(math.radians(ang)))
                pygame.draw.circle(surf, (135, 45, 30), (cx, cy), 2)
                pygame.draw.circle(surf, (165, 65, 42), (cx, cy), 1)
            # 팔각 지붕 (2층)
            roof_pts_8 = []
            for ang in range(0, 360, 45):
                rx = ox + int((orad + 7) * math.cos(math.radians(ang)))
                ry = oy + int((orad + 7) * math.sin(math.radians(ang))) - orad
                roof_pts_8.append((rx, ry))
            if len(roof_pts_8) >= 3:
                pygame.draw.polygon(surf, (48, 46, 42), roof_pts_8)
                pygame.draw.polygon(surf, (62, 58, 52), roof_pts_8, 1)
            # 2층 지붕 (작은)
            roof2 = []
            for ang in range(0, 360, 45):
                rx = ox + int((orad - 2) * math.cos(math.radians(ang)))
                ry = oy + int((orad - 2) * math.sin(math.radians(ang))) - orad - 4
                roof2.append((rx, ry))
            if len(roof2) >= 3:
                pygame.draw.polygon(surf, (55, 52, 48), roof2)
            # 보주
            pygame.draw.circle(surf, (215, 178, 82), (ox, oy - orad - 4), 3)
            pygame.draw.circle(surf, (245, 210, 110), (ox, oy - orad - 4), 1)

        # ===== 누각/문루 (성문 위 2층 건물, 중앙 회피) =====
        for _ in range(2):
            nx = random.randint(60, W - 60)
            ny = random.randint(H // 4, H * 2 // 3)
            if _in_center(nx, ny):
                continue
            nw = random.randint(35, 65)
            nh = random.randint(28, 48)
            # 석축 성벽 (아래)
            gate_h = nh // 2
            pygame.draw.rect(surf, (72, 68, 60),
                             (nx - nw // 2 - 3, ny + nh - gate_h, nw + 6, gate_h + 4))
            pygame.draw.rect(surf, (88, 84, 74),
                             (nx - nw // 2 - 1, ny + nh - gate_h, nw + 2, gate_h + 2))
            # 성문 아치
            arch_w = max(6, nw // 4)
            arch_h = max(8, gate_h - 2)
            pygame.draw.rect(surf, (28, 25, 20),
                             (nx - arch_w // 2, ny + nh - arch_h + 2, arch_w, arch_h))
            pygame.draw.arc(surf, (88, 84, 74),
                            (nx - arch_w // 2, ny + nh - arch_h - arch_w // 4,
                             arch_w, arch_w // 2), 0, math.pi, 2)
            # 줄눈
            for gi in range(0, nw + 4, max(5, nw // 8)):
                pygame.draw.line(surf, (58, 54, 48),
                                 (nx - nw // 2 - 2 + gi, ny + nh - gate_h),
                                 (nx - nw // 2 - 2 + gi, ny + nh + 4), 1)
            # 상부 건물 (누각)
            upper_h = nh - gate_h - 2
            if upper_h > 6:
                pygame.draw.rect(surf, (210, 192, 152),
                                 (nx - nw // 2 + 2, ny, nw - 4, upper_h))
                _draw_dancheong(nx, ny, nw - 6, 3)
                _draw_red_pillars(nx, ny + 4, ny + upper_h, nw - 4, max(6, nw // 5))
            # 지붕
            _draw_tiled_roof(nx, ny, nw + 18, max(12, upper_h + 4), double=True)

        # ===== 탑 (석탑/목탑, 중앙 회피) =====
        for _ in range(3):
            tx = random.randint(50, W - 50)
            ty = random.randint(H // 4, H * 3 // 4)
            if _in_center(tx, ty):
                continue
            layers = random.randint(3, 5)
            tw_base = random.randint(12, 22)
            th_layer = random.randint(5, 9)
            # 기단
            pygame.draw.rect(surf, (82, 78, 70),
                             (tx - tw_base // 2 - 3, ty + layers * th_layer, tw_base + 6, 4))
            # 층별
            for li in range(layers):
                lw = tw_base - li * 3
                ly = ty + (layers - 1 - li) * th_layer
                if lw < 4:
                    lw = 4
                # 몸돌
                pygame.draw.rect(surf, (155, 148, 135),
                                 (tx - lw // 2, ly + 2, lw, th_layer - 2))
                pygame.draw.rect(surf, (135, 128, 118),
                                 (tx - lw // 2, ly + 2, lw, th_layer - 2), 1)
                # 옥개석 (처마)
                ow = lw + 6
                pygame.draw.rect(surf, (108, 102, 92),
                                 (tx - ow // 2, ly, ow, 3))
                # 귀꽃
                pygame.draw.circle(surf, (90, 85, 78), (tx - ow // 2, ly + 1), 1)
                pygame.draw.circle(surf, (90, 85, 78), (tx + ow // 2, ly + 1), 1)
            # 상륜부 (꼭대기 장식)
            top_y = ty - 2
            pygame.draw.line(surf, (100, 95, 85), (tx, top_y), (tx, top_y + 6), 2)
            pygame.draw.circle(surf, (195, 165, 75), (tx, top_y - 1), 2)

        # ===== 석등 (돌탑 장식, 중앙 회피) =====
        for _ in range(5):
            lx = random.randint(35, W - 35)
            ly = random.randint(H // 3, H * 2 // 3)
            if _in_center(lx, ly):
                continue
            # 기단 (2단)
            pygame.draw.rect(surf, (95, 90, 82), (lx - 5, ly + 10, 10, 3))
            pygame.draw.rect(surf, (105, 100, 92), (lx - 4, ly + 8, 8, 3))
            # 간주석 (가운데 기둥)
            pygame.draw.rect(surf, (115, 110, 100), (lx - 2, ly + 2, 4, 7))
            # 화사석 (불빛 칸)
            pygame.draw.rect(surf, (128, 122, 112), (lx - 4, ly - 1, 8, 4))
            pygame.draw.rect(surf, (225, 185, 85), (lx - 3, ly, 6, 2))  # 불빛
            # 옥개석 (지붕돌)
            pygame.draw.polygon(surf, (82, 78, 70),
                                [(lx, ly - 5), (lx - 7, ly - 1), (lx + 7, ly - 1)])
            pygame.draw.circle(surf, (165, 142, 62), (lx, ly - 5), 1)

        # ===== 길/산책로 (HD — 판석 텍스처 + 경계석 + 이끼) =====
        path_pts = []
        for step in range(50):
            st = step / 49
            px_p = W // 6 + int(W * 4 // 6 * st)
            py_p = H * 2 // 3 + int(42 * math.sin(st * math.pi * 1.8))
            path_pts.append((px_p, py_p))
        if len(path_pts) > 2:
            # 길 바탕 (넓은 흙길)
            pygame.draw.lines(surf, (98, 85, 58), False, path_pts, 10)
            # 판석 (밝은 돌)
            pygame.draw.lines(surf, (148, 135, 108), False, path_pts, 7)
            # 중앙선 (밟힌 부분)
            pygame.draw.lines(surf, (165, 152, 128), False, path_pts, 3)
            # 경계석 (양쪽 테두리)
            pts_l = [(p[0], p[1] + 4) for p in path_pts]
            pts_r = [(p[0], p[1] - 4) for p in path_pts]
            pygame.draw.lines(surf, (85, 78, 62), False, pts_l, 2)
            pygame.draw.lines(surf, (85, 78, 62), False, pts_r, 2)
            # 판석 줄눈 (가로 끊김)
            for si in range(3, len(path_pts) - 3, 3):
                gx, gy = path_pts[si]
                pygame.draw.line(surf, (115, 102, 78),
                                 (gx, gy - 3), (gx, gy + 3), 1)
            # 자갈/이끼 점
            for si in range(2, len(path_pts) - 2, 2):
                gx, gy = path_pts[si]
                for _ in range(4):
                    dx = random.randint(-4, 4)
                    dy = random.randint(-2, 2)
                    gc = random.choice([(132, 118, 92), (120, 108, 85), (62, 85, 48)])
                    pygame.draw.circle(surf, gc, (gx + dx, gy + dy), 1)

        # ===== 돌다리/나무다리 (개울 위, 중앙 회피) =====
        for _ in range(2):
            bx = random.randint(80, W - 80)
            by = random.randint(H // 5, H * 2 // 3)
            if _in_center(bx, by):
                continue
            bl = random.randint(18, 35)
            is_stone = random.random() < 0.5
            if is_stone:
                # 돌다리
                pygame.draw.rect(surf, (105, 100, 90), (bx - bl // 2, by - 3, bl, 7))
                pygame.draw.rect(surf, (120, 115, 105), (bx - bl // 2, by - 2, bl, 5))
                # 난간
                pygame.draw.rect(surf, (95, 90, 82), (bx - bl // 2, by - 5, bl, 2))
                # 돌 줄눈
                for si in range(bx - bl // 2 + 4, bx + bl // 2 - 2, max(4, bl // 6)):
                    pygame.draw.line(surf, (82, 78, 70), (si, by - 2), (si, by + 2), 1)
            else:
                # 나무다리
                pygame.draw.rect(surf, (110, 78, 42), (bx - bl // 2, by - 2, bl, 5))
                pygame.draw.rect(surf, (130, 95, 55), (bx - bl // 2, by - 1, bl, 3))
                # 널빤지 결
                for si in range(bx - bl // 2 + 3, bx + bl // 2 - 1, max(3, bl // 8)):
                    pygame.draw.line(surf, (95, 68, 35), (si, by - 1), (si, by + 2), 1)
                # 난간 기둥
                pygame.draw.line(surf, (90, 62, 30),
                                 (bx - bl // 2, by - 4), (bx - bl // 2, by + 2), 2)
                pygame.draw.line(surf, (90, 62, 30),
                                 (bx + bl // 2, by - 4), (bx + bl // 2, by + 2), 2)

        # ===== 논 (HD — 물 반사 + 벼 줄 + 논둑 + 허수아비, 중앙 회피) =====
        for _ in range(10):
            rx = random.randint(20, W - 90)
            ry = random.randint(H // 3, H - 50)
            if _in_center(rx + 30, ry + 15):
                continue
            rw_f = random.randint(40, 95)
            rh_f = random.randint(26, 52)
            # 논둑 (진흙 + 풀)
            pygame.draw.rect(surf, (75, 95, 35), (rx - 4, ry - 4, rw_f + 8, rh_f + 8))
            pygame.draw.rect(surf, (88, 108, 42), (rx - 2, ry - 2, rw_f + 4, rh_f + 4))
            pygame.draw.rect(surf, (95, 118, 48), (rx - 2, ry - 2, rw_f + 4, rh_f + 4), 1)
            # 물면 (HD 그라데이션)
            water_s = pygame.Surface((rw_f, rh_f), pygame.SRCALPHA)
            for wy in range(rh_f):
                frac = wy / rh_f
                wa = int(58 + frac * 30)
                wr = int(58 + frac * 10)
                wg = int(100 + frac * 15)
                wb = int(72 + frac * 12)
                pygame.draw.line(water_s, (wr, wg, wb, wa), (0, wy), (rw_f, wy))
            surf.blit(water_s, (rx, ry))
            # 벼 줄 (세로 — 개별 벼 표현)
            for ri in range(rx + 3, rx + rw_f - 2, max(3, rw_f // 12)):
                for rj in range(ry + 2, ry + rh_f - 2, max(3, rh_f // 8)):
                    gc = (max(0, 78 + random.randint(-5, 8)),
                          max(0, min(255, 125 + random.randint(-5, 8))),
                          max(0, 42 + random.randint(-5, 5)))
                    pygame.draw.line(surf, (*gc, 85), (ri, rj), (ri, rj + 2), 1)
            # 수면 반사 (하이라이트)
            pygame.draw.line(surf, (112, 162, 192, 42),
                             (rx + 2, ry + rh_f // 3), (rx + rw_f - 2, ry + rh_f // 3), 1)
            pygame.draw.line(surf, (105, 155, 185, 30),
                             (rx + 3, ry + rh_f * 2 // 3), (rx + rw_f - 3, ry + rh_f * 2 // 3), 1)
        # 허수아비 (논 근처 1개)
        scarecrow_x = random.randint(W // 4, W * 3 // 4)
        scarecrow_y = random.randint(H // 2, H * 3 // 4)
        if not _in_center(scarecrow_x, scarecrow_y):
            # 지팡이
            pygame.draw.line(surf, (95, 68, 35), (scarecrow_x, scarecrow_y - 14),
                             (scarecrow_x, scarecrow_y + 5), 2)
            # 가로대
            pygame.draw.line(surf, (92, 65, 32), (scarecrow_x - 5, scarecrow_y - 8),
                             (scarecrow_x + 5, scarecrow_y - 8), 2)
            # 머리 (짚 뭉치)
            pygame.draw.circle(surf, (148, 128, 68), (scarecrow_x, scarecrow_y - 14), 3)
            # 옷 (천 조각)
            pygame.draw.rect(surf, (125, 82, 45), (scarecrow_x - 3, scarecrow_y - 10, 6, 5))

        # ===== 꽃밭 (HD — 야생화 + 풀 + 나비 + 반딧불, 중앙 회피) =====
        for _ in range(75):
            fx = random.randint(5, W - 5)
            fy = random.randint(H // 5, H - 8)
            if _in_center(fx, fy):
                continue
            ftype = random.randint(0, 5)
            if ftype == 0:
                # 코스모스/국화 (5잎 꽃)
                fc = random.choice([
                    (255, 200, 80), (255, 115, 95), (215, 175, 255),
                    (255, 255, 175), (255, 155, 195), (255, 170, 90),
                    (255, 130, 170), (180, 220, 255), (255, 210, 140),
                ])
                fr = random.randint(2, 5)
                # 줄기
                pygame.draw.line(surf, (55, 85, 38), (fx, fy + fr), (fx, fy + fr + random.randint(3, 7)), 1)
                # 꽃잎 (5방향)
                for pi in range(5):
                    ang = pi * 72 + random.randint(-8, 8)
                    dx = int(fr * math.cos(math.radians(ang)))
                    dy = int(fr * math.sin(math.radians(ang)))
                    pygame.draw.circle(surf, fc, (fx + dx, fy + dy), max(1, fr - 1))
                # 꽃술
                pygame.draw.circle(surf, (255, 235, 120), (fx, fy), max(1, fr // 2))
            elif ftype == 1:
                # 풀 이파리 (바람에 흔들리는)
                gh = random.randint(4, 10)
                gc = (max(0, 52 + random.randint(-15, 15)),
                      max(0, min(255, 108 + random.randint(-15, 15))),
                      max(0, 32 + random.randint(-10, 10)))
                dx = random.randint(-4, 4)
                # 풀 3~4줄기
                for gi in range(random.randint(2, 4)):
                    ox = gi * 2 - 2
                    odx = dx + random.randint(-1, 1)
                    pygame.draw.line(surf, gc, (fx + ox, fy), (fx + ox + odx, fy - gh + random.randint(-1, 1)), 1)
            elif ftype == 2:
                # 잔디 점 (클러스터)
                gc = (max(0, 60 + random.randint(-20, 20)),
                      max(0, min(255, 110 + random.randint(-20, 20))),
                      max(0, 30 + random.randint(-10, 10)))
                for _ in range(random.randint(2, 4)):
                    pygame.draw.circle(surf, gc,
                                       (fx + random.randint(-2, 2), fy + random.randint(-1, 1)), 1)
            elif ftype == 3:
                # 들국화 (작은 노란 점)
                pygame.draw.circle(surf, (235, 210, 85), (fx, fy), 2)
                pygame.draw.circle(surf, (255, 235, 120), (fx, fy), 1)
                pygame.draw.line(surf, (58, 88, 38), (fx, fy + 2), (fx, fy + 5), 1)
            elif ftype == 4:
                # 달맞이꽃 (연보라)
                pygame.draw.circle(surf, (195, 165, 220), (fx, fy), 2)
                pygame.draw.circle(surf, (215, 190, 240), (fx, fy), 1)
                pygame.draw.line(surf, (52, 82, 35), (fx, fy + 2), (fx, fy + 4), 1)
            else:
                # 무궁화 (한국 국화)
                pygame.draw.circle(surf, (240, 170, 195), (fx, fy), 3)
                for pi in range(5):
                    ang = pi * 72
                    dx = int(2.5 * math.cos(math.radians(ang)))
                    dy = int(2.5 * math.sin(math.radians(ang)))
                    pygame.draw.circle(surf, (235, 155, 180), (fx + dx, fy + dy), 1)
                pygame.draw.circle(surf, (180, 50, 75), (fx, fy), 1)
                pygame.draw.line(surf, (52, 78, 35), (fx, fy + 3), (fx, fy + 7), 1)
        # 나비 (꽃밭 위를 나는)
        for _ in range(6):
            bx = random.randint(30, W - 30)
            by = random.randint(H // 4, H * 3 // 4)
            if _in_center(bx, by):
                continue
            bc = random.choice([
                (255, 225, 100), (255, 180, 120), (200, 220, 255), (255, 190, 210)])
            # 날개 (좌우 삼각형)
            pygame.draw.polygon(surf, (*bc, 180),
                                [(bx, by), (bx - 3, by - 2), (bx - 2, by + 2)])
            pygame.draw.polygon(surf, (*bc, 180),
                                [(bx, by), (bx + 3, by - 2), (bx + 2, by + 2)])
            # 몸통
            pygame.draw.line(surf, (30, 25, 18), (bx, by - 1), (bx, by + 1), 1)
            # 더듬이
            pygame.draw.line(surf, (30, 25, 18), (bx, by - 1), (bx - 1, by - 3), 1)
            pygame.draw.line(surf, (30, 25, 18), (bx, by - 1), (bx + 1, by - 3), 1)

        # ===== 바위 산개 (HD 이끼+이끼류+질감, 중앙 회피) =====
        for _ in range(22):
            rx = random.randint(10, W - 10)
            ry = random.randint(H // 3, H - 15)
            if _in_center(rx, ry):
                continue
            rw = random.randint(4, 15)
            rh = random.randint(3, 10)
            # 그림자
            pygame.draw.ellipse(surf, (0, 0, 0, 18),
                                (rx + 1, ry + rh // 2, rw, rh // 2 + 2))
            # 바위 본체 (다층)
            pygame.draw.ellipse(surf, (58, 55, 48), (rx, ry, rw, rh))
            pygame.draw.ellipse(surf, (82, 78, 68), (rx + 1, ry, rw - 2, max(1, rh - 1)))
            # 하이라이트 (상부 좌측)
            if rw > 5:
                pygame.draw.ellipse(surf, (105, 100, 88),
                                    (rx + 1, ry, max(2, rw // 2), max(1, rh // 2)))
            # 이끼 (초록 패치)
            if rw > 5:
                pygame.draw.ellipse(surf, (55, 88, 45, 90),
                                    (rx + 1, ry, max(2, rw // 2), max(1, rh // 2)))
            # 지의류 (작은 점)
            if rw > 8:
                for _ in range(random.randint(1, 3)):
                    lx = rx + random.randint(1, rw - 2)
                    ly = ry + random.randint(0, max(0, rh - 2))
                    pygame.draw.circle(surf, (128, 125, 105), (lx, ly), 1)

        # ===== 석등 (돌탑 장식, 중앙 회피) =====
        for _ in range(4):
            lx = random.randint(40, W - 40)
            ly = random.randint(H // 3, H * 2 // 3)
            if _in_center(lx, ly):
                continue
            # 기단
            pygame.draw.rect(surf, (100, 95, 88), (lx - 4, ly + 8, 8, 4))
            # 몸통
            pygame.draw.rect(surf, (120, 115, 105), (lx - 3, ly + 2, 6, 6))
            # 불빛 칸 (따뜻한 노란색)
            pygame.draw.rect(surf, (220, 180, 80), (lx - 2, ly + 3, 4, 3))
            # 지붕
            pygame.draw.polygon(surf, (80, 75, 68),
                                [(lx, ly - 2), (lx - 5, ly + 2), (lx + 5, ly + 2)])
            pygame.draw.circle(surf, (160, 140, 60), (lx, ly - 2), 1)

        random.seed()

        # ===== 구름 레이어 (HD 볼류메트릭 + 금빛 테두리) =====
        cloud_a = max(0, int(210 * (1.0 - t * 2.2) * alpha / 255))
        if cloud_a > 3:
            random.seed(2024)
            for _ in range(30):
                cx_c = random.randint(-80, W + 80)
                cy_c = random.randint(-40, H + 40)
                cw_c = random.randint(100, 350)
                ch_c = random.randint(30, 95)
                cs = pygame.Surface((cw_c, ch_c), pygame.SRCALPHA)
                # 다층 볼류메트릭 (9겹)
                for ci in range(9):
                    coff = ci * 3
                    ca = max(1, int(cloud_a * (1.0 - ci * 0.10)))
                    if cw_c - coff * 2 > 4 and ch_c - coff * 2 > 4:
                        pygame.draw.ellipse(
                            cs, (255, 255, 255, min(255, ca)),
                            (coff, coff, cw_c - coff * 2, ch_c - coff * 2))
                # 뭉게 구름 덩어리 (볼륨감)
                for _ in range(3):
                    bx = random.randint(cw_c // 6, cw_c * 5 // 6)
                    by = random.randint(ch_c // 4, ch_c * 3 // 4)
                    br = random.randint(ch_c // 4, ch_c // 2)
                    ba = max(1, cloud_a // 3)
                    pygame.draw.circle(cs, (255, 255, 255, min(255, ba)), (bx, by), br)
                # 금빛 테두리 (석양 빛)
                edge_a = max(1, cloud_a // 4)
                pygame.draw.ellipse(cs, (255, 218, 195, edge_a),
                                    (0, ch_c // 3, cw_c, ch_c // 2))
                # 하이라이트 (상부 — 밝은 흰색)
                hl_a = max(1, cloud_a // 3)
                if cw_c > 60 and ch_c > 20:
                    pygame.draw.ellipse(cs, (255, 255, 255, min(255, hl_a)),
                                        (cw_c // 4, 2, cw_c // 2, ch_c // 3))
                # 그림자 (더 부드럽게)
                shadow_s = pygame.Surface((cw_c, ch_c // 2 + 4), pygame.SRCALPHA)
                sha = max(1, cloud_a // 5)
                pygame.draw.ellipse(shadow_s, (0, 0, 0, sha),
                                    (5, 0, cw_c - 10, ch_c // 2))
                surf.blit(shadow_s, (cx_c - cw_c // 2 + 4, cy_c + ch_c // 3))
                surf.blit(cs, (cx_c - cw_c // 2, cy_c - ch_c // 2))
            random.seed()

        # ===== 금빛 대기 오버레이 + 햇살 광선 =====
        haze_a = max(0, int(75 * (1.0 - t * 2.5) * alpha / 255))
        if haze_a > 2:
            haze = pygame.Surface((W, H), pygame.SRCALPHA)
            haze.fill((200, 190, 170, haze_a))
            surf.blit(haze, (0, 0))
            # 사선 햇살 광선 (골든아워)
            ray_a = max(0, int(haze_a * 0.6))
            if ray_a > 2:
                ray_s = pygame.Surface((W, H), pygame.SRCALPHA)
                sun_x = W * 3 // 4
                sun_y = -30
                for ri in range(8):
                    ang = 55 + ri * 8
                    end_x = sun_x + int(W * 1.2 * math.cos(math.radians(ang)))
                    end_y = sun_y + int(H * 1.5 * math.sin(math.radians(ang)))
                    rw = random.randint(8, 22)
                    ra = max(1, ray_a - ri * 2)
                    for rj in range(-rw // 2, rw // 2):
                        pygame.draw.line(ray_s, (255, 235, 185, max(1, ra // 3)),
                                         (sun_x + rj, sun_y), (end_x + rj, end_y), 1)
                surf.blit(ray_s, (0, 0))

        # ===== 지면 안개 (낮게 깔린 미스트) =====
        mist_a = max(0, int(40 * (1.0 - t * 3.0) * alpha / 255))
        if mist_a > 2:
            mist_s = pygame.Surface((W, H // 3), pygame.SRCALPHA)
            for row in range(H // 3):
                frac = row / (H // 3)
                ma = max(1, int(mist_a * (1 - frac * frac)))
                pygame.draw.line(mist_s, (210, 215, 225, ma),
                                 (0, row), (W, row))
            surf.blit(mist_s, (0, H * 2 // 3))

    # ──────────────────────────────────────────────────────────
    #  조선시대 스타일 경기장 외곽 테두리 (인셋 — 경기장 위에 겹침)
    # ──────────────────────────────────────────────────────────
    def _draw_joseon_arena_border(self, screen, ix, iy, ig_w, ig_h, arena_scale):
        """경기장 가장자리 위에 조선시대 양식의 프레임을 덧그린다.
        인셋 방식: 경기장 영역 안쪽+바깥쪽 양쪽으로 걸치되,
        화면 밖으로 나가지 않도록 클리핑."""
        if arena_scale < 0.08 or ig_w < 12 or ig_h < 12:
            return

        # ── 스케일 비례 두께 ──
        bw = max(6, int(28 * arena_scale))       # 나무 프레임 두께
        tile_h = max(4, int(14 * arena_scale))    # 기와 높이
        dc_w = max(2, int(8 * arena_scale))       # 단청 띠 두께
        corner_r = max(6, int(22 * arena_scale))  # 모서리 장식

        # 프레임은 경기장 가장자리 중심으로 안/밖 반반
        half_in = bw // 2
        half_out = bw - half_in

        # 서피스 크기 = 경기장 + 바깥 여유
        sw = ig_w + half_out * 2 + 4
        sh = ig_h + half_out * 2 + tile_h + 4
        brd = pygame.Surface((sw, sh), pygame.SRCALPHA)

        # brd 내 경기장의 로컬 좌표
        ax = half_out + 2            # 경기장 좌측
        ay = half_out + tile_h + 2   # 경기장 상단
        aw = ig_w                    # 경기장 너비
        ah = ig_h                    # 경기장 높이

        # 색상
        dark_wood = (55, 32, 18)
        mid_wood = (88, 55, 28)
        light_wood = (120, 78, 38)
        gold = (195, 155, 45)
        gold_hi = (225, 195, 85)

        # ===== 1) 나무 프레임 — 네 변을 경기장 가장자리에 걸쳐 그림 =====
        # 상변 (기와 바로 아래)
        fy = ay - half_out
        pygame.draw.rect(brd, dark_wood, (ax - half_out, fy, aw + bw, bw))
        pygame.draw.rect(brd, mid_wood, (ax - half_out + 2, fy + 2, aw + bw - 4, bw - 4))
        # 하변
        fy_b = ay + ah - half_in
        pygame.draw.rect(brd, dark_wood, (ax - half_out, fy_b, aw + bw, bw))
        pygame.draw.rect(brd, mid_wood, (ax - half_out + 2, fy_b + 2, aw + bw - 4, bw - 4))
        # 좌변
        fx_l = ax - half_out
        pygame.draw.rect(brd, dark_wood, (fx_l, ay - half_out, bw, ah + bw))
        pygame.draw.rect(brd, mid_wood, (fx_l + 2, ay - half_out + 2, bw - 4, ah + bw - 4))
        # 우변
        fx_r = ax + aw - half_in
        pygame.draw.rect(brd, dark_wood, (fx_r, ay - half_out, bw, ah + bw))
        pygame.draw.rect(brd, mid_wood, (fx_r + 2, ay - half_out + 2, bw - 4, ah + bw - 4))

        # 나무 하이라이트 (내곽 가장자리 밝은 선)
        pygame.draw.rect(brd, (*light_wood, 160),
                         (ax - 1, ay - 1, aw + 2, ah + 2), 1)

        # 나무결 (스케일 클 때만)
        if arena_scale > 0.3:
            grain_step = max(4, int(6 * arena_scale))
            # 좌변 세로결
            for gx in range(fx_l + 3, fx_l + bw - 2, grain_step):
                pygame.draw.line(brd, (*light_wood, 45),
                                 (gx, ay - half_out), (gx, ay + ah + half_out), 1)
            # 우변 세로결
            for gx in range(fx_r + 3, fx_r + bw - 2, grain_step):
                pygame.draw.line(brd, (*light_wood, 45),
                                 (gx, ay - half_out), (gx, ay + ah + half_out), 1)
            # 상변 가로결
            for gy in range(ay - half_out + 3, ay - half_out + bw - 2, grain_step):
                pygame.draw.line(brd, (*light_wood, 45),
                                 (ax - half_out, gy), (ax + aw + half_out, gy), 1)
            # 하변 가로결
            for gy in range(fy_b + 3, fy_b + bw - 2, grain_step):
                pygame.draw.line(brd, (*light_wood, 45),
                                 (ax - half_out, gy), (ax + aw + half_out, gy), 1)

        # ===== 2) 단청 띠 (주홍-녹청-군청-황금) =====
        dc_colors = [
            (190, 48, 38),   # 주홍
            (38, 128, 62),   # 녹청
            (48, 72, 158),   # 군청
            (205, 165, 48),  # 황금
        ]
        if dc_w >= 2 and arena_scale > 0.15:
            stripe = max(1, dc_w // len(dc_colors))
            # 상변 단청 (프레임 안쪽 가장자리)
            for ci, dc in enumerate(dc_colors):
                dy = ay - half_out + 2 + ci * stripe
                if dy + stripe > ay + half_in:
                    break
                pygame.draw.rect(brd, (*dc, 200),
                                 (ax + half_in, dy, aw - bw, stripe))
            # 하변 단청
            for ci, dc in enumerate(dc_colors):
                dy = fy_b + bw - 2 - (ci + 1) * stripe
                if dy < fy_b:
                    break
                pygame.draw.rect(brd, (*dc, 200),
                                 (ax + half_in, dy, aw - bw, stripe))
            # 좌변 단청
            for ci, dc in enumerate(dc_colors):
                dx = fx_l + 2 + ci * stripe
                if dx + stripe > ax:
                    break
                pygame.draw.rect(brd, (*dc, 200),
                                 (dx, ay + half_in, stripe, ah - bw))
            # 우변 단청
            for ci, dc in enumerate(dc_colors):
                dx = fx_r + bw - 2 - (ci + 1) * stripe
                if dx < ax + aw:
                    break
                pygame.draw.rect(brd, (*dc, 200),
                                 (dx, ay + half_in, stripe, ah - bw))

        # ===== 3) 기와 지붕 (상단 — 프레임 위) =====
        if tile_h >= 3:
            tile_dark = (42, 38, 32)
            tile_mid = (68, 60, 50)
            tile_light = (92, 84, 72)
            tile_top = ay - half_out - tile_h
            tile_left = ax - half_out
            tile_w_full = aw + bw

            # 기와 배경
            pygame.draw.rect(brd, tile_dark,
                             (tile_left, tile_top, tile_w_full, tile_h))
            # 기와 한 장씩
            tw = max(4, int(10 * arena_scale))
            for tx in range(tile_left, tile_left + tile_w_full, tw):
                cw = min(tw, tile_left + tile_w_full - tx)
                if cw < 2:
                    break
                pygame.draw.rect(brd, tile_mid,
                                 (tx + 1, tile_top + 1, cw - 1, tile_h - 2))
                # 상단 하이라이트
                pygame.draw.line(brd, tile_light,
                                 (tx + 1, tile_top + 1),
                                 (tx + cw - 1, tile_top + 1), 1)
                # 홈 선
                pygame.draw.line(brd, tile_dark,
                                 (tx, tile_top), (tx, tile_top + tile_h), 1)

            # 처마 선
            pygame.draw.line(brd, tile_light,
                             (tile_left, tile_top + tile_h - 1),
                             (tile_left + tile_w_full, tile_top + tile_h - 1), 1)

            # 추녀 (양 끝 올림)
            if arena_scale > 0.3 and tile_w_full > 40:
                lift = max(2, int(6 * arena_scale))
                span = min(lift * 4, tile_w_full // 5)
                for ei in range(span):
                    curve = int(lift * (1.0 - ei / span) ** 2)
                    ey = tile_top + tile_h - 1 - curve
                    # 왼쪽
                    pygame.draw.line(brd, tile_mid,
                                     (tile_left + ei, ey),
                                     (tile_left + ei, ey + max(1, curve // 2)), 1)
                    # 오른쪽
                    pygame.draw.line(brd, tile_mid,
                                     (tile_left + tile_w_full - 1 - ei, ey),
                                     (tile_left + tile_w_full - 1 - ei,
                                      ey + max(1, curve // 2)), 1)

        # ===== 4) 모서리 장식 (금테 + 꽃문양) =====
        if corner_r >= 5 and arena_scale > 0.18:
            corners = [
                (ax - half_out, ay - half_out),
                (ax + aw + half_out - corner_r, ay - half_out),
                (ax - half_out, ay + ah + half_out - corner_r),
                (ax + aw + half_out - corner_r, ay + ah + half_out - corner_r),
            ]
            for cx, cy in corners:
                # 금색 사각
                pygame.draw.rect(brd, gold, (cx, cy, corner_r, corner_r))
                pygame.draw.rect(brd, dark_wood,
                                 (cx + 2, cy + 2, corner_r - 4, corner_r - 4))
                # 꽃 문양
                ccx = cx + corner_r // 2
                ccy = cy + corner_r // 2
                pr = max(2, corner_r // 3)
                pygame.draw.circle(brd, gold_hi, (ccx, ccy), pr)
                # 꽃잎 (4방향)
                if pr >= 3:
                    for ang in range(0, 360, 90):
                        dx = int(pr * 0.7 * math.cos(math.radians(ang)))
                        dy = int(pr * 0.7 * math.sin(math.radians(ang)))
                        pygame.draw.circle(brd, (190, 48, 38),
                                           (ccx + dx, ccy + dy), max(1, pr // 2))
                    pygame.draw.circle(brd, gold_hi, (ccx, ccy), max(1, pr // 2))

        # ===== 5) 외곽 금선 =====
        pygame.draw.rect(brd, (*gold, 220),
                         (ax - half_out - 1, ay - half_out - 1,
                          aw + bw + 2, ah + bw + 2), 1)

        # ── 최종 블릿 ──
        blit_x = ix - half_out - 2
        blit_y = iy - half_out - tile_h - 2
        screen.blit(brd, (blit_x, blit_y))

    def _draw_jungle_arena_border(self, screen, ix, iy, ig_w, ig_h, arena_scale):
        """경기장 가장자리 위에 정글/늪지 양식의 초고퀄리티 프레임.
        두꺼운 돌담 + 악어비늘 + 밀림덩굴 + 초가캐노피 + 해골장식 + 횃불.
        Stage 2 악어장군 테마."""
        if arena_scale < 0.08 or ig_w < 12 or ig_h < 12:
            return

        # ── 스케일 비례 두께 (스테이지1 대비 두껍게) ──
        bw = max(8, int(42 * arena_scale))         # 돌 프레임 두께 ↑
        canopy_h = max(6, int(26 * arena_scale))    # 초가 캐노피 높이 ↑
        corner_r = max(8, int(32 * arena_scale))    # 모서리 장식 ↑
        torch_margin = max(8, int(22 * arena_scale))  # 횃불 여유 공간

        half_in = bw // 2
        half_out = bw - half_in

        # 서피스 크기 (횃불+캐노피 포함 여유)
        margin = torch_margin + 6
        sw = ig_w + half_out * 2 + margin * 2
        sh = ig_h + half_out * 2 + canopy_h + margin + 4
        brd = pygame.Surface((sw, sh), pygame.SRCALPHA)

        # brd 내 경기장 로컬 좌표
        ax = half_out + margin
        ay = half_out + canopy_h + 2
        aw = ig_w
        ah = ig_h

        # ── 색상 팔레트 (풍부한 정글/습지) ──
        rock_dk = (32, 35, 26)
        rock_md = (52, 58, 42)
        rock_lt = (72, 78, 58)
        rock_hl = (92, 98, 72)
        rock_shadow = (22, 24, 18)
        moss_dk = (18, 48, 14)
        moss_md = (30, 72, 22)
        moss_br = (48, 100, 35)
        vine_dk = (16, 48, 12)
        vine_md = (28, 70, 20)
        vine_br = (45, 105, 32)
        vine_hl = (65, 135, 50)
        bone_c = (185, 175, 145)
        bone_dk = (135, 125, 100)
        gold_tr = (170, 145, 50)
        gold_hi = (205, 180, 75)
        skull_w = (200, 190, 165)
        skull_sh = (125, 115, 92)
        tooth_w = (215, 210, 195)
        tooth_sh = (165, 155, 135)
        croc_dk = (28, 62, 22)
        croc_md = (42, 88, 35)
        croc_lt = (60, 115, 48)
        croc_eye = (200, 180, 40)

        # ===== 0) 프레임 뒤 글로우 (습지 안개 분위기) =====
        glow_r = max(bw, 20)
        glow_s = pygame.Surface((aw + glow_r * 2, ah + glow_r * 2), pygame.SRCALPHA)
        for gi in range(glow_r, 0, -2):
            ga = max(1, int(18 * gi / glow_r))
            pygame.draw.rect(glow_s, (30, 60, 25, ga),
                             (glow_r - gi, glow_r - gi,
                              aw + gi * 2, ah + gi * 2), 2)
        brd.blit(glow_s, (ax - glow_r, ay - glow_r))

        # ===== 1) 돌 프레임 — 두꺼운 다층 암석 (3단 레이어) =====
        fy = ay - half_out
        fy_b = ay + ah - half_in
        fx_l = ax - half_out
        fx_r = ax + aw - half_in

        # 레이어 1: 가장 바깥 (어두운 석재)
        for rect_args in [
            (ax - half_out, fy, aw + bw, bw),       # 상
            (ax - half_out, fy_b, aw + bw, bw),     # 하
            (fx_l, fy, bw, ah + bw),                 # 좌
            (fx_r, fy, bw, ah + bw),                 # 우
        ]:
            pygame.draw.rect(brd, rock_shadow, rect_args)

        # 레이어 2: 중간 (밝은 돌)
        inset = 2
        for rect_args in [
            (ax - half_out + inset, fy + inset, aw + bw - inset * 2, bw - inset * 2),
            (ax - half_out + inset, fy_b + inset, aw + bw - inset * 2, bw - inset * 2),
            (fx_l + inset, fy + inset, bw - inset * 2, ah + bw - inset * 2),
            (fx_r + inset, fy + inset, bw - inset * 2, ah + bw - inset * 2),
        ]:
            pygame.draw.rect(brd, rock_dk, rect_args)

        # 레이어 3: 돌 텍스처 (불규칙 돌 블록 + 모르타르)
        random.seed(9101)
        stone_w = max(6, int(12 * arena_scale))
        stone_h = max(4, int(8 * arena_scale))

        def _draw_stones_on_rect(rx, ry, rw, rh, horizontal=True):
            """사각형 영역에 돌 질감 채움"""
            if rw < 4 or rh < 4:
                return
            row = 0
            while row < rh:
                sh_cur = min(stone_h + random.randint(-1, 1), rh - row)
                if sh_cur < 2:
                    break
                col = 0
                offset = (row // max(1, stone_h)) % 2 * (stone_w // 2)
                while col < rw:
                    sw_cur = min(stone_w + random.randint(-2, 2), rw - col)
                    if sw_cur < 2:
                        break
                    sx = rx + col
                    sy = ry + row
                    # 돌 베이스
                    rc = random.choice([rock_md, rock_lt, rock_dk,
                                        (55, 60, 45), (65, 72, 52), (48, 52, 38)])
                    pygame.draw.rect(brd, rc, (sx, sy, sw_cur, sh_cur))
                    # 밝은 면 (상단/좌측)
                    hl = (min(255, rc[0] + 18), min(255, rc[1] + 15), min(255, rc[2] + 10))
                    pygame.draw.line(brd, hl, (sx, sy), (sx + sw_cur - 1, sy), 1)
                    pygame.draw.line(brd, hl, (sx, sy), (sx, sy + sh_cur - 1), 1)
                    # 그림자 면 (하단/우측)
                    sh_c = (max(0, rc[0] - 15), max(0, rc[1] - 12), max(0, rc[2] - 10))
                    pygame.draw.line(brd, sh_c, (sx + sw_cur - 1, sy),
                                     (sx + sw_cur - 1, sy + sh_cur - 1), 1)
                    pygame.draw.line(brd, sh_c, (sx, sy + sh_cur - 1),
                                     (sx + sw_cur - 1, sy + sh_cur - 1), 1)
                    # 모르타르 줄눈
                    pygame.draw.rect(brd, rock_shadow, (sx, sy, sw_cur, sh_cur), 1)
                    col += sw_cur
                row += sh_cur

        # 네 변에 돌 블록 그리기
        _draw_stones_on_rect(ax - half_out + 1, fy + 1, aw + bw - 2, bw - 2)
        _draw_stones_on_rect(ax - half_out + 1, fy_b + 1, aw + bw - 2, bw - 2)
        _draw_stones_on_rect(fx_l + 1, fy + bw, bw - 2, ah - bw)
        _draw_stones_on_rect(fx_r + 1, fy + bw, bw - 2, ah - bw)
        random.seed()

        # 내곽/외곽 테두리 선
        pygame.draw.rect(brd, (*rock_hl, 160),
                         (ax - 1, ay - 1, aw + 2, ah + 2), 1)
        pygame.draw.rect(brd, (*rock_shadow, 180),
                         (ax - half_out - 1, fy - 1, aw + bw + 2, ah + bw + 2), 1)

        # ===== 2) 악어비늘 패턴 띠 (돌 프레임 안쪽 2줄) =====
        if arena_scale > 0.15:
            scale_band = max(3, int(8 * arena_scale))
            scale_size = max(3, int(5 * arena_scale))

            def _draw_croc_scales(sx, sy, sw_band, sh_band, horizontal=True):
                """악어 비늘 패턴 띠"""
                if sw_band < 4 or sh_band < 4:
                    return
                ss = pygame.Surface((sw_band, sh_band), pygame.SRCALPHA)
                ss.fill((*croc_dk, 180))
                # 비늘 그리기
                if horizontal:
                    row = 1
                    while row < sh_band - 1:
                        col = (row // max(1, scale_size)) % 2 * (scale_size // 2)
                        while col < sw_band - 1:
                            sc = random.choice([croc_md, croc_lt, croc_dk])
                            sc_w = min(scale_size, sw_band - col - 1)
                            sc_h = min(max(2, scale_size - 1), sh_band - row - 1)
                            if sc_w > 1 and sc_h > 1:
                                pygame.draw.ellipse(ss, (*sc, 200),
                                                    (col, row, sc_w, sc_h))
                                # 비늘 하이라이트
                                if sc_w > 2 and sc_h > 2:
                                    pygame.draw.ellipse(ss, (*croc_lt, 80),
                                                        (col + 1, row, sc_w - 2, max(1, sc_h // 2)))
                            col += scale_size
                        row += max(2, scale_size - 1)
                brd.blit(ss, (sx, sy))

            # 내곽 바깥쪽 악어비늘 띠 (상/하/좌/우)
            off1 = max(3, int(5 * arena_scale))
            # 상변 비늘 (프레임 내부)
            _draw_croc_scales(ax + off1, ay - half_out + off1,
                              aw - off1 * 2, scale_band)
            # 하변 비늘
            _draw_croc_scales(ax + off1, ay + ah + half_in - off1 - scale_band,
                              aw - off1 * 2, scale_band)
            # 좌변 비늘
            _draw_croc_scales(fx_l + off1, ay + off1,
                              scale_band, ah - off1 * 2)
            # 우변 비늘
            _draw_croc_scales(fx_r + bw - off1 - scale_band, ay + off1,
                              scale_band, ah - off1 * 2)

        # ===== 3) 이끼/덩굴 대량 레이어 =====
        random.seed(9102)
        # 이끼 패치 (돌 위 — 대량으로)
        for _ in range(int(80 * arena_scale)):
            mx = ax - half_out + random.randint(0, aw + bw - 1)
            my = ay - half_out + random.randint(0, ah + bw - 1)
            in_court = (ax < mx < ax + aw and ay < my < ay + ah)
            if in_court:
                continue
            mr = random.randint(2, max(4, int(10 * arena_scale)))
            ms = pygame.Surface((mr * 2, mr * 2), pygame.SRCALPHA)
            mc = random.choice([moss_dk, moss_md, moss_br, (24, 58, 18), (35, 68, 25)])
            pygame.draw.circle(ms, (*mc, random.randint(50, 120)), (mr, mr), mr)
            # 이끼 표면 질감 (작은 밝은 점)
            if mr > 3:
                for _ in range(random.randint(1, 3)):
                    dx = random.randint(-mr + 2, mr - 2)
                    dy = random.randint(-mr + 2, mr - 2)
                    pygame.draw.circle(ms, (*moss_br, 60), (mr + dx, mr + dy), 1)
            brd.blit(ms, (mx - mr, my - mr))

        # 굵은 덩굴 (상단에서 늘어짐 — 대형 + 잎 풍성)
        for _ in range(int(24 * arena_scale)):
            vx = ax + random.randint(5, max(6, aw - 5))
            vy_start = ay - half_out + random.randint(0, max(1, bw // 3))
            vl = random.randint(max(8, int(14 * arena_scale)),
                                max(16, int(40 * arena_scale)))
            vine_thick = max(1, int(3 * arena_scale))
            for vi in range(vl):
                vx_o = vx + int(4 * math.sin(vi * 0.4 + vx * 0.08))
                vy_o = vy_start + vi
                cur_thick = max(1, vine_thick - vi // max(4, vl // 3))
                vc = vine_md if vi % 4 else vine_br
                pygame.draw.circle(brd, vc, (vx_o, vy_o), cur_thick)
                # 덩굴 하이라이트 (왼쪽 면)
                if cur_thick > 1:
                    pygame.draw.circle(brd, (*vine_hl, 60),
                                       (vx_o - 1, vy_o), max(1, cur_thick - 1))
                # 잎 (간헐적 — 양치류 스타일)
                if vi % max(3, vl // 6) == 0 and vi > 2:
                    leaf_r = max(3, int(5 * arena_scale))
                    side = random.choice([-1, 1])
                    # 잎줄기
                    lx = vx_o + side * (leaf_r + 1)
                    ly = vy_o + random.randint(-1, 1)
                    pygame.draw.line(brd, vine_dk, (vx_o, vy_o), (lx, ly), 1)
                    # 잎 (타원)
                    ls = pygame.Surface((leaf_r * 2, leaf_r), pygame.SRCALPHA)
                    lc = random.choice([moss_md, moss_br, vine_md])
                    pygame.draw.ellipse(ls, (*lc, 180), (0, 0, leaf_r * 2, leaf_r))
                    # 잎맥
                    pygame.draw.line(ls, (*vine_dk, 100),
                                     (1, leaf_r // 2), (leaf_r * 2 - 1, leaf_r // 2), 1)
                    brd.blit(ls, (lx - leaf_r, ly - leaf_r // 2))
                # 꽃/열매 (드물게)
                if vi > vl // 2 and random.random() < 0.06:
                    fc = random.choice([(255, 255, 220), (255, 200, 100),
                                        (255, 120, 180), (200, 100, 255)])
                    pygame.draw.circle(brd, fc, (vx_o + random.randint(-2, 2),
                                                  vy_o + 1), max(1, int(2 * arena_scale)))

        # 하단 벽 덩굴 (올라오는)
        for _ in range(int(14 * arena_scale)):
            vx = ax + random.randint(5, max(6, aw - 5))
            vy_start = ay + ah + half_out - 2
            vl = random.randint(max(6, int(10 * arena_scale)),
                                max(12, int(25 * arena_scale)))
            for vi in range(vl):
                vx_o = vx + int(3 * math.sin(vi * 0.5 + vx * 0.1))
                vr = max(1, int(2.5 * arena_scale) - vi // max(4, vl // 3))
                if vr < 1:
                    vr = 1
                vc = vine_dk if vi % 3 else vine_md
                pygame.draw.circle(brd, vc, (vx_o, vy_start - vi), vr)
                if vi % max(4, vl // 4) == 0 and vi > 2:
                    side = random.choice([-1, 1])
                    lr = max(2, int(4 * arena_scale))
                    pygame.draw.ellipse(brd, moss_md,
                                        (vx_o + side * 2, vy_start - vi - 1,
                                         lr * 2, lr))

        # 좌우 벽 덩굴 (두껍고 풍성하게)
        for side_base in [fx_l, fx_r + bw]:
            for _ in range(int(10 * arena_scale)):
                vy = ay + random.randint(max(1, int(5 * arena_scale)),
                                         max(6, ah - int(5 * arena_scale)))
                vl = random.randint(max(5, int(8 * arena_scale)),
                                    max(10, int(22 * arena_scale)))
                direction = 1 if side_base < ax else -1
                for vi in range(vl):
                    vx_o = side_base + direction * vi
                    vy_o = vy + int(3 * math.sin(vi * 0.5 + vy * 0.05))
                    vr = max(1, int(2 * arena_scale) - vi // max(3, vl // 3))
                    if vr < 1:
                        vr = 1
                    pygame.draw.circle(brd, vine_dk, (vx_o, vy_o), vr)
                    if vi % max(3, vl // 3) == 0 and vi > 1:
                        lr = max(2, int(3 * arena_scale))
                        pygame.draw.ellipse(brd, moss_md,
                                            (vx_o - lr, vy_o - lr // 2, lr * 2, lr))
        random.seed()

        # ===== 4) 초가/잎 캐노피 + 하단 캐노피 (상하 모두!) =====
        leaf_colors = [
            (62, 75, 30), (52, 68, 26), (72, 85, 36),
            (45, 60, 22), (80, 92, 40), (55, 70, 28),
            (68, 82, 34), (58, 72, 30),
        ]
        canopy_bot_h = max(4, int(16 * arena_scale))  # 하단 캐노피도 추가

        def _draw_leaf_canopy(c_top, c_left, c_w, c_h, droop_dir=1):
            """잎/짚 캐노피 렌더"""
            if c_h < 3 or c_w < 4:
                return
            random.seed(9103 + c_top)
            # 배경
            pygame.draw.rect(brd, (40, 52, 20), (c_left, c_top, c_w, c_h))
            # 나무 기둥 뼈대
            beam_h = max(2, int(4 * arena_scale))
            beam_y = c_top + c_h - beam_h if droop_dir > 0 else c_top
            pygame.draw.rect(brd, (55, 38, 18), (c_left, beam_y, c_w, beam_h))
            pygame.draw.rect(brd, (75, 55, 28), (c_left + 1, beam_y + 1, c_w - 2, max(1, beam_h - 2)))
            # 세로 나무 지지대 (3~4개)
            support_n = max(2, int(c_w / max(20, int(50 * arena_scale))))
            for si in range(support_n):
                sx = c_left + int(c_w * (si + 1) / (support_n + 1))
                pygame.draw.line(brd, (60, 42, 20), (sx, c_top), (sx, c_top + c_h), max(1, int(2 * arena_scale)))

            # 잎 타일 (넓은 잎 겹침)
            leaf_w = max(5, int(10 * arena_scale))
            leaf_h_tile = max(3, c_h - beam_h - 1)
            tile_y = c_top if droop_dir > 0 else c_top + beam_h
            for tx in range(c_left, c_left + c_w, leaf_w):
                cw_l = min(leaf_w, c_left + c_w - tx)
                if cw_l < 2:
                    break
                lc = random.choice(leaf_colors)
                pygame.draw.rect(brd, lc, (tx, tile_y, cw_l, leaf_h_tile))
                # 밝은 면
                lc_hl = (min(255, lc[0] + 22), min(255, lc[1] + 20), min(255, lc[2] + 14))
                if droop_dir > 0:
                    pygame.draw.line(brd, lc_hl, (tx, tile_y), (tx + cw_l - 1, tile_y), 1)
                else:
                    pygame.draw.line(brd, lc_hl, (tx, tile_y + leaf_h_tile - 1),
                                     (tx + cw_l - 1, tile_y + leaf_h_tile - 1), 1)
                # 줄눈
                pygame.draw.line(brd, (32, 40, 16), (tx, tile_y), (tx, tile_y + leaf_h_tile), 1)
                # 잎맥 (큰 스케일)
                if arena_scale > 0.3 and cw_l > 3:
                    mid_y = tile_y + leaf_h_tile // 2
                    pygame.draw.line(brd, (min(255, lc[0] - 8), min(255, lc[1] + 5), max(0, lc[2] - 5)),
                                     (tx + 1, mid_y), (tx + cw_l - 1, mid_y), 1)

            # 처마 매달림 (잎/짚이 삐져나옴)
            if arena_scale > 0.2:
                for tx in range(c_left + 2, c_left + c_w - 2,
                                max(2, int(4 * arena_scale))):
                    droop = random.randint(2, max(4, int(10 * arena_scale)))
                    dc = random.choice(leaf_colors)
                    for di in range(droop):
                        da = max(1, 220 - di * 30)
                        dy = c_top + c_h + di * droop_dir if droop_dir > 0 else c_top - di
                        pygame.draw.line(brd, (*dc, da), (tx, dy), (tx + 1, dy), 1)
                    # 끝에 물방울/이슬 (드물게)
                    if random.random() < 0.15 and droop > 3:
                        drop_y = c_top + c_h + droop * droop_dir if droop_dir > 0 else c_top - droop
                        pygame.draw.circle(brd, (140, 200, 180, 120), (tx, drop_y), 1)
            random.seed()

        # 상단 캐노피
        _draw_leaf_canopy(ay - half_out - canopy_h,
                          ax - half_out - 4, aw + bw + 8, canopy_h,
                          droop_dir=1)
        # 하단 캐노피
        _draw_leaf_canopy(ay + ah + half_out,
                          ax - half_out - 4, aw + bw + 8, canopy_bot_h,
                          droop_dir=-1)

        # ===== 5) 악어이빨 + 잇몸 테두리 (내곽 — 상/하/좌/우 모두!) =====
        if arena_scale > 0.15:
            tooth_h = max(4, int(8 * arena_scale))
            tooth_w = max(4, int(7 * arena_scale))
            gum_h = max(2, int(4 * arena_scale))  # 잇몸

            def _draw_teeth_row(start_x, end_x, base_y, direction, horiz=True):
                """이빨 한 줄 그리기. direction: 1=아래, -1=위"""
                # 잇몸 (분홍/붉은 띠)
                gum_y = base_y if direction > 0 else base_y - gum_h
                if horiz:
                    gum_w = end_x - start_x
                    pygame.draw.rect(brd, (120, 55, 45),
                                     (start_x, gum_y, gum_w, gum_h))
                    pygame.draw.rect(brd, (150, 72, 58),
                                     (start_x, gum_y + (1 if direction > 0 else 0),
                                      gum_w, max(1, gum_h - 1)))
                # 이빨
                for tx in range(start_x + 1, end_x - 1, tooth_w + max(1, int(2 * arena_scale))):
                    tw_a = min(tooth_w, end_x - tx - 1)
                    if tw_a < 2:
                        break
                    if direction > 0:
                        pts = [(tx, base_y + gum_h),
                               (tx + tw_a, base_y + gum_h),
                               (tx + tw_a // 2, base_y + gum_h + tooth_h)]
                    else:
                        pts = [(tx, base_y - gum_h),
                               (tx + tw_a, base_y - gum_h),
                               (tx + tw_a // 2, base_y - gum_h - tooth_h)]
                    pygame.draw.polygon(brd, tooth_w, pts)
                    # 이빨 그림자 (어두운 면)
                    pygame.draw.polygon(brd, tooth_sh, pts, 1)
                    # 이빨 하이라이트 (밝은 중앙선)
                    mid_x = tx + tw_a // 2
                    if direction > 0:
                        pygame.draw.line(brd, (235, 230, 220),
                                         (mid_x, base_y + gum_h + 1),
                                         (mid_x, base_y + gum_h + tooth_h - 2), 1)
                    else:
                        pygame.draw.line(brd, (235, 230, 220),
                                         (mid_x, base_y - gum_h - 1),
                                         (mid_x, base_y - gum_h - tooth_h + 2), 1)

            # 상단 이빨 (아래로)
            _draw_teeth_row(ax + 2, ax + aw - 2, ay - 1, 1)
            # 하단 이빨 (위로)
            _draw_teeth_row(ax + 2, ax + aw - 2, ay + ah, -1)
            # 좌측 이빨 (오른쪽으로) — 세로 배치
            if arena_scale > 0.25:
                for ty in range(ay + 2, ay + ah - 2,
                                tooth_w + max(1, int(2 * arena_scale))):
                    th_a = min(tooth_w, ay + ah - ty - 2)
                    if th_a < 2:
                        break
                    pts = [(ax - 1, ty),
                           (ax - 1, ty + th_a),
                           (ax + tooth_h - 1, ty + th_a // 2)]
                    pygame.draw.polygon(brd, tooth_w, pts)
                    pygame.draw.polygon(brd, tooth_sh, pts, 1)
                # 우측 이빨 (왼쪽으로)
                for ty in range(ay + 2, ay + ah - 2,
                                tooth_w + max(1, int(2 * arena_scale))):
                    th_a = min(tooth_w, ay + ah - ty - 2)
                    if th_a < 2:
                        break
                    pts = [(ax + aw, ty),
                           (ax + aw, ty + th_a),
                           (ax + aw - tooth_h, ty + th_a // 2)]
                    pygame.draw.polygon(brd, tooth_w, pts)
                    pygame.draw.polygon(brd, tooth_sh, pts, 1)

        # ===== 6) 모서리 — 악어 눈 + 해골 + 뼈 (대형 장식) =====
        if corner_r >= 6 and arena_scale > 0.15:
            corners = [
                (ax - half_out, fy, 0),       # 좌상
                (ax + aw + half_in - corner_r, fy, 1),  # 우상
                (ax - half_out, fy_b + bw - corner_r, 2),  # 좌하
                (ax + aw + half_in - corner_r, fy_b + bw - corner_r, 3),  # 우하
            ]
            for ccx, ccy, ci in corners:
                # 돌 베이스 (둥근 코너)
                cs = pygame.Surface((corner_r, corner_r), pygame.SRCALPHA)
                pygame.draw.rect(cs, rock_dk, (0, 0, corner_r, corner_r))
                pygame.draw.rect(cs, rock_md, (1, 1, corner_r - 2, corner_r - 2))
                pygame.draw.rect(cs, rock_lt, (2, 2, corner_r - 4, corner_r - 4))
                brd.blit(cs, (ccx, ccy))

                scx = ccx + corner_r // 2
                scy = ccy + corner_r // 2

                if ci < 2:  # 상단 코너: 악어 눈
                    er = max(3, corner_r // 3)
                    # 눈 글로우
                    eg = pygame.Surface((er * 4, er * 4), pygame.SRCALPHA)
                    pygame.draw.circle(eg, (*croc_eye, 40), (er * 2, er * 2), er * 2)
                    brd.blit(eg, (scx - er * 2, scy - er * 2))
                    # 눈 (노란색 + 세로 동공)
                    pygame.draw.circle(brd, croc_eye, (scx, scy), er)
                    pygame.draw.circle(brd, (220, 200, 60), (scx, scy), max(1, er - 1))
                    # 세로 동공
                    pygame.draw.line(brd, (15, 10, 5),
                                     (scx, scy - er + 1), (scx, scy + er - 1),
                                     max(1, int(2 * arena_scale)))
                    # 눈 테두리
                    pygame.draw.circle(brd, croc_dk, (scx, scy), er, 1)
                    # 눈꺼풀 (상단 반원)
                    pygame.draw.arc(brd, croc_dk,
                                    (scx - er - 1, scy - er - 1, er * 2 + 2, er * 2 + 2),
                                    0.2, math.pi - 0.2, max(1, int(2 * arena_scale)))
                else:  # 하단 코너: 해골
                    sr = max(3, corner_r // 3)
                    # 두개골
                    pygame.draw.circle(brd, skull_w, (scx, scy - 1), sr)
                    pygame.draw.circle(brd, skull_sh, (scx, scy - 1), sr, 1)
                    # 턱
                    if sr >= 3:
                        jaw_w = sr * 2 - 2
                        jaw_h = max(2, sr // 2)
                        pygame.draw.rect(brd, skull_w,
                                         (scx - jaw_w // 2, scy + 1, jaw_w, jaw_h))
                        # 눈구멍
                        eo = max(1, sr // 2)
                        er_e = max(1, sr // 3)
                        pygame.draw.circle(brd, (20, 15, 10), (scx - eo, scy - 1), er_e)
                        pygame.draw.circle(brd, (20, 15, 10), (scx + eo, scy - 1), er_e)
                        # 붉은 눈빛
                        pygame.draw.circle(brd, (180, 40, 30, 120), (scx - eo, scy - 1), max(1, er_e - 1))
                        pygame.draw.circle(brd, (180, 40, 30, 120), (scx + eo, scy - 1), max(1, er_e - 1))
                        # 코
                        pygame.draw.polygon(brd, (20, 15, 10),
                                            [(scx, scy), (scx - 1, scy + 1), (scx + 1, scy + 1)])
                    # 교차 뼈
                    if corner_r >= 12:
                        bl = max(3, corner_r // 3)
                        bw_bone = max(1, int(2 * arena_scale))
                        by_b = scy + sr + 1
                        pygame.draw.line(brd, bone_c,
                                         (scx - bl, by_b), (scx + bl, by_b + bl), bw_bone)
                        pygame.draw.line(brd, bone_c,
                                         (scx + bl, by_b), (scx - bl, by_b + bl), bw_bone)
                        # 뼈 끝 둥근 마디
                        for bx_e, by_e in [(scx - bl, by_b), (scx + bl, by_b),
                                           (scx - bl, by_b + bl), (scx + bl, by_b + bl)]:
                            pygame.draw.circle(brd, bone_c, (bx_e, by_e), max(1, bw_bone))

                # 금테
                pygame.draw.rect(brd, (*gold_tr, 200),
                                 (ccx, ccy, corner_r, corner_r), 1)

        # ===== 7) 외곽 테두리 (금선 + 녹색 발광선) =====
        # 금선
        pygame.draw.rect(brd, (*gold_tr, 200),
                         (ax - half_out - 2, fy - 2,
                          aw + bw + 4, ah + bw + 4), 2)
        # 금선 내부 하이라이트
        pygame.draw.rect(brd, (*gold_hi, 100),
                         (ax - half_out - 1, fy - 1,
                          aw + bw + 2, ah + bw + 2), 1)
        # 녹색 발광 (내곽)
        inner_glow = pygame.Surface((aw + 4, ah + 4), pygame.SRCALPHA)
        pygame.draw.rect(inner_glow, (40, 160, 80, 60),
                         (0, 0, aw + 4, ah + 4), 2)
        brd.blit(inner_glow, (ax - 2, ay - 2))

        # ===== 8) 횃불 (양쪽 2개씩 = 총 4개, 대형) =====
        if arena_scale > 0.2:
            torch_h = max(12, int(30 * arena_scale))
            torch_thick = max(2, int(4 * arena_scale))
            flame_r = max(4, int(8 * arena_scale))

            # 횃불 위치 (좌/우 각 2개)
            torch_positions = []
            for side_off in [ax - half_out - torch_margin // 2,
                             ax + aw + half_out + torch_margin // 2 - torch_thick]:
                for vy_frac in [0.25, 0.75]:
                    ty_t = ay + int(ah * vy_frac) - torch_h // 2
                    torch_positions.append((side_off, ty_t))

            for tx_t, ty_t in torch_positions:
                tcx = tx_t + torch_thick // 2
                # 횃불 기둥 (굵은 나무 + 철 링)
                # 그림자
                sh_s = pygame.Surface((torch_thick + 6, 4), pygame.SRCALPHA)
                pygame.draw.ellipse(sh_s, (0, 0, 0, 30), (0, 0, torch_thick + 6, 4))
                brd.blit(sh_s, (tcx - torch_thick // 2 - 3, ty_t + torch_h + 1))
                # 기둥 본체
                pygame.draw.line(brd, (50, 35, 15),
                                 (tcx, ty_t + flame_r), (tcx, ty_t + torch_h),
                                 torch_thick + 2)
                pygame.draw.line(brd, (70, 50, 25),
                                 (tcx, ty_t + flame_r + 1), (tcx, ty_t + torch_h - 1),
                                 torch_thick)
                # 하이라이트 (왼쪽 밝은선)
                pygame.draw.line(brd, (90, 68, 35),
                                 (tcx - torch_thick // 2, ty_t + flame_r + 2),
                                 (tcx - torch_thick // 2, ty_t + torch_h - 2), 1)
                # 철 링 (2개)
                for ring_y in [ty_t + flame_r + 2, ty_t + torch_h - max(2, int(4 * arena_scale))]:
                    rw = torch_thick + 4
                    pygame.draw.rect(brd, (60, 60, 65), (tcx - rw // 2, ring_y, rw, 2))
                    pygame.draw.rect(brd, (80, 82, 88), (tcx - rw // 2, ring_y, rw, 1))

                # 불꽃 받침대 (넓은 컵)
                cup_w = max(4, torch_thick + 4)
                cup_h = max(2, int(4 * arena_scale))
                pygame.draw.rect(brd, (55, 55, 60),
                                 (tcx - cup_w // 2, ty_t + flame_r - cup_h,
                                  cup_w, cup_h))

                # 불꽃 (다층 — 대형)
                fcx = tcx
                fcy = ty_t + flame_r // 2
                # 넓은 글로우 (주황)
                gw = flame_r * 5
                g_s = pygame.Surface((gw, gw), pygame.SRCALPHA)
                pygame.draw.circle(g_s, (255, 120, 20, 25), (gw // 2, gw // 2), gw // 2)
                brd.blit(g_s, (fcx - gw // 2, fcy - gw // 2))
                # 중간 글로우 (노랑)
                gw2 = flame_r * 3
                g_s2 = pygame.Surface((gw2, gw2), pygame.SRCALPHA)
                pygame.draw.circle(g_s2, (255, 180, 40, 45), (gw2 // 2, gw2 // 2), gw2 // 2)
                brd.blit(g_s2, (fcx - gw2 // 2, fcy - gw2 // 2))
                # 불꽃 본체 (빨강→주황→노랑→흰)
                for fi, (fc, fr_f) in enumerate([
                    ((180, 50, 15), flame_r),
                    ((220, 90, 20), max(1, flame_r - 1)),
                    ((255, 160, 40), max(1, flame_r - 2)),
                    ((255, 220, 90), max(1, flame_r // 2)),
                    ((255, 250, 200), max(1, flame_r // 3)),
                ]):
                    pygame.draw.circle(brd, fc, (fcx, fcy - fi), fr_f)
                # 불꽃 팁 (삼각형 — 흔들리는 느낌)
                tip_h = max(3, flame_r)
                pygame.draw.polygon(brd, (255, 200, 60),
                                    [(fcx - 2, fcy - flame_r + 2),
                                     (fcx + 2, fcy - flame_r + 2),
                                     (fcx, fcy - flame_r - tip_h)])
                # 불티 (작은 점)
                random.seed(int(tx_t * 100 + ty_t))
                for _ in range(random.randint(2, 5)):
                    px = fcx + random.randint(-flame_r, flame_r)
                    py = fcy - flame_r - random.randint(0, tip_h + 3)
                    pc = random.choice([(255, 200, 80), (255, 160, 40), (255, 120, 20)])
                    pygame.draw.circle(brd, pc, (px, py), 1)
                random.seed()

        # ── 최종 블릿 ──
        blit_x = ix - half_out - margin
        blit_y = iy - half_out - canopy_h - 2
        screen.blit(brd, (blit_x, blit_y))

    def _draw_menhera_arena_border(self, screen, ix, iy, ig_w, ig_h, arena_scale):
        """경기장 가장자리 위에 멘헤라 플러시 프레임.
        그런지 더티 핑크 + 체인 + 반창고 + 면도날 + 곰인형 + 하트 + 네온.
        pillar_menhera.py 색상 팔레트 기반."""
        bw = max(8, int(38 * arena_scale))
        lace_h = max(4, int(18 * arena_scale))
        ribbon_w = max(3, int(10 * arena_scale))
        corner_r = max(8, int(30 * arena_scale))
        margin = max(2, int(6 * arena_scale))
        half_out = bw // 2 + margin

        brd_w = ig_w + half_out * 2 + margin * 2
        brd_h = ig_h + half_out * 2 + lace_h * 2 + margin * 2
        brd = pygame.Surface((brd_w, brd_h), pygame.SRCALPHA)

        ox = half_out + margin
        oy = half_out + lace_h + margin
        fw, fh = ig_w, ig_h

        random.seed(31370)

        # ===== 1. 외곽 글로우 (네온 핑크 + 시안) =====
        for gi in range(4):
            glow_a = 38 - gi * 9
            gc_choice = [(255, 100, 180), (100, 220, 255), (200, 120, 255)]
            gc = gc_choice[gi % 3]
            pygame.draw.rect(brd, (*gc, max(1, glow_a)),
                             (ox - bw // 2 - 4 - gi * 2, oy - bw // 2 - 4 - gi * 2,
                              fw + bw + 8 + gi * 4, fh + bw + 8 + gi * 4), 2)

        # ===== 2. 메인 프레임 — 3레이어 그런지 핑크 (pillar_menhera 색상) =====
        # 레이어 1: 어두운 프레임 엣지 (frame_edge_dark)
        frame_edge = (80, 50, 60)
        pygame.draw.rect(brd, frame_edge,
                         (ox - bw // 2, oy - bw // 2, fw + bw, fh + bw))
        # 레이어 2: 더러운 핑크 (frame_pink_dark)
        frame_pink_dark = (140, 80, 100)
        inner_m = max(2, bw // 6)
        pygame.draw.rect(brd, frame_pink_dark,
                         (ox - bw // 2 + inner_m, oy - bw // 2 + inner_m,
                          fw + bw - inner_m * 2, fh + bw - inner_m * 2))
        # 레이어 3: 밝은 핑크 (frame_pink_mid)
        frame_pink_mid = (180, 120, 140)
        inner_m2 = max(3, bw // 3)
        pygame.draw.rect(brd, frame_pink_mid,
                         (ox - bw // 2 + inner_m2, oy - bw // 2 + inner_m2,
                          fw + bw - inner_m2 * 2, fh + bw - inner_m2 * 2))
        # 내부 컷아웃
        pygame.draw.rect(brd, (0, 0, 0, 0), (ox, oy, fw, fh))

        # ===== 3. 그런지 얼룩 + 긁힌 자국 (더러운 질감) =====
        stain_colors = [(90, 55, 65), (100, 60, 50), (120, 70, 85), (140, 80, 100)]
        for _ in range(40):
            sx = random.randint(ox - bw // 2, ox + fw + bw // 2)
            sy = random.randint(oy - bw // 2, oy + fh + bw // 2)
            # 내부 영역 제외
            if ox < sx < ox + fw and oy < sy < oy + fh:
                continue
            sr = random.randint(3, max(4, int(12 * arena_scale)))
            sc = stain_colors[random.randint(0, 3)]
            sa = random.randint(20, 50)
            stain_s = pygame.Surface((sr * 2, sr * 2), pygame.SRCALPHA)
            pygame.draw.circle(stain_s, (*sc, sa), (sr, sr), sr)
            brd.blit(stain_s, (sx - sr, sy - sr))
        # 긁힌 자국
        for _ in range(25):
            sx = random.randint(ox - bw // 2, ox + fw + bw // 2)
            sy = random.randint(oy - bw // 2, oy + fh + bw // 2)
            if ox < sx < ox + fw and oy < sy < oy + fh:
                continue
            sl = random.randint(6, max(7, int(25 * arena_scale)))
            ang = random.uniform(-0.8, 0.8)
            ex = sx + int(sl * math.cos(ang))
            ey = sy + int(sl * math.sin(ang))
            pygame.draw.line(brd, (120, 70, 85, 35), (sx, sy), (ex, ey),
                             max(1, int(arena_scale * 1.5)))

        # ===== 4. 리본 띠 (상하단 — hot_pink) =====
        ribbon_pink = (255, 105, 180)
        ribbon_dark = (200, 100, 130)
        ribbon_light = (255, 200, 220)
        # 상단 리본
        ry_top = oy - bw // 2 - 1
        pygame.draw.rect(brd, ribbon_dark,
                         (ox - bw // 2, ry_top, fw + bw, ribbon_w))
        pygame.draw.rect(brd, ribbon_pink,
                         (ox - bw // 2, ry_top + 1, fw + bw, ribbon_w - 2))
        pygame.draw.line(brd, ribbon_light,
                         (ox - bw // 2, ry_top + 1),
                         (ox + fw + bw // 2, ry_top + 1), 1)
        # 하단 리본
        ry_bot = oy + fh + bw // 2 - ribbon_w + 1
        pygame.draw.rect(brd, ribbon_dark,
                         (ox - bw // 2, ry_bot, fw + bw, ribbon_w))
        pygame.draw.rect(brd, ribbon_pink,
                         (ox - bw // 2, ry_bot + 1, fw + bw, ribbon_w - 2))
        pygame.draw.line(brd, ribbon_light,
                         (ox - bw // 2, ry_bot + 1),
                         (ox + fw + bw // 2, ry_bot + 1), 1)
        # 리본 나비매듭 (4개 코너)
        bow_positions = [
            (ox - bw // 4, ry_top + ribbon_w // 2),
            (ox + fw + bw // 4, ry_top + ribbon_w // 2),
            (ox - bw // 4, ry_bot + ribbon_w // 2),
            (ox + fw + bw // 4, ry_bot + ribbon_w // 2),
        ]
        bow_r = max(4, int(12 * arena_scale))
        for bx, by in bow_positions:
            pygame.draw.ellipse(brd, (255, 150, 180),
                                (bx - bow_r * 2, by - bow_r, bow_r * 2, bow_r * 2))
            pygame.draw.ellipse(brd, (255, 150, 180),
                                (bx, by - bow_r, bow_r * 2, bow_r * 2))
            pygame.draw.ellipse(brd, ribbon_light,
                                (bx - bow_r * 2 + 2, by - bow_r + 2,
                                 bow_r * 2 - 4, bow_r - 2))
            pygame.draw.circle(brd, ribbon_dark, (bx, by), max(2, bow_r // 2))
            pygame.draw.circle(brd, ribbon_pink, (bx, by), max(1, bow_r // 3))
            tail_len = max(4, int(14 * arena_scale))
            pygame.draw.line(brd, ribbon_dark, (bx, by),
                             (bx - bow_r, by + tail_len), max(1, int(2 * arena_scale)))
            pygame.draw.line(brd, ribbon_dark, (bx, by),
                             (bx + bow_r, by + tail_len), max(1, int(2 * arena_scale)))

        # ===== 5. 레이스 프릴 (상하단 — pillar 색상) =====
        lace_colors = [(210, 160, 175), (180, 120, 140), (230, 180, 200)]
        ly_top = oy - bw // 2 - lace_h
        for lx in range(ox - bw // 2 - 2, ox + fw + bw // 2 + 2, max(3, int(8 * arena_scale))):
            lc = lace_colors[random.randint(0, 2)]
            lr = max(3, int(random.uniform(5, 10) * arena_scale))
            pygame.draw.circle(brd, lc, (lx, ly_top + lace_h // 2), lr)
            pygame.draw.circle(brd, (min(255, lc[0] + 15), min(255, lc[1] + 15), min(255, lc[2] + 15)),
                               (lx, ly_top + lace_h // 2), max(1, lr - 2))
            if random.random() < 0.35:
                pygame.draw.circle(brd, (0, 0, 0, 0),
                                   (lx, ly_top + lace_h // 2), max(1, lr // 3))
        ly_bot = oy + fh + bw // 2
        for lx in range(ox - bw // 2 - 2, ox + fw + bw // 2 + 2, max(3, int(8 * arena_scale))):
            lc = lace_colors[random.randint(0, 2)]
            lr = max(3, int(random.uniform(5, 10) * arena_scale))
            pygame.draw.circle(brd, lc, (lx, ly_bot + lace_h // 2), lr)
            pygame.draw.circle(brd, (min(255, lc[0] + 15), min(255, lc[1] + 15), min(255, lc[2] + 15)),
                               (lx, ly_bot + lace_h // 2), max(1, lr - 2))

        # ===== 6. 체인 (좌우 프레임 — pillar 핵심 요소) =====
        chain_dark = (50, 50, 55)
        chain_mid = (90, 90, 100)
        chain_light = (140, 140, 155)
        chain_hl = (180, 180, 195)
        for side in [-1, 1]:
            base_x = ox + (fw + bw // 3 if side > 0 else -bw // 3)
            link_h = max(4, int(8 * arena_scale))
            link_w = max(3, int(5 * arena_scale))
            cy_c = oy - bw // 4
            link_idx = 0
            while cy_c < oy + fh + bw // 4:
                cx_c = base_x + int(math.sin(cy_c * 0.06 + side) * max(1, bw // 8))
                # 체인 고리 (타원)
                if link_idx % 2 == 0:
                    pygame.draw.ellipse(brd, chain_dark,
                                        (cx_c - link_w, cy_c, link_w * 2, link_h))
                    pygame.draw.ellipse(brd, chain_mid,
                                        (cx_c - link_w + 1, cy_c + 1, link_w * 2 - 2, link_h - 2))
                    # 하이라이트
                    pygame.draw.ellipse(brd, chain_light,
                                        (cx_c - link_w + 1, cy_c + 1,
                                         max(1, link_w), max(1, link_h // 2)), 1)
                else:
                    pygame.draw.ellipse(brd, chain_dark,
                                        (cx_c - link_w + 1, cy_c - 1,
                                         link_w * 2 - 2, link_h + 2))
                    pygame.draw.ellipse(brd, chain_mid,
                                        (cx_c - link_w + 2, cy_c, link_w * 2 - 4, link_h))
                cy_c += link_h - 1
                link_idx += 1

        # ===== 7. 하트 장식 (프레임 위에 분포 — pillar heart 색상) =====
        heart_positions = []
        for hx in range(ox, ox + fw, max(6, int(30 * arena_scale))):
            hy = oy - bw // 2 + random.randint(-bw // 4, bw // 4)
            heart_positions.append((hx + random.randint(-3, 3), hy))
        for hx in range(ox, ox + fw, max(6, int(35 * arena_scale))):
            hy = oy + fh + bw // 2 + random.randint(-bw // 4, bw // 4)
            heart_positions.append((hx + random.randint(-3, 3), hy))
        for hy in range(oy, oy + fh, max(6, int(40 * arena_scale))):
            heart_positions.append((ox - bw // 4 + random.randint(-3, 3), hy))
            heart_positions.append((ox + fw + bw // 4 + random.randint(-3, 3), hy))

        heart_colors = [(255, 120, 160), (255, 80, 100), (255, 200, 180), (180, 80, 100)]
        for hx, hy in heart_positions:
            hs = max(2, int(random.uniform(4, 8) * arena_scale))
            hc = heart_colors[random.randint(0, 3)]
            pygame.draw.circle(brd, hc, (hx - hs // 3, hy - hs // 4), max(1, hs // 2))
            pygame.draw.circle(brd, hc, (hx + hs // 3, hy - hs // 4), max(1, hs // 2))
            pygame.draw.polygon(brd, hc,
                                [(hx - hs, hy), (hx + hs, hy), (hx, hy + hs)])
            pygame.draw.circle(brd, (min(255, hc[0] + 30), min(255, hc[1] + 30), min(255, hc[2] + 30)),
                               (hx - hs // 4, hy - hs // 3), max(1, hs // 4))

        # ===== 8. 반창고 + X자 (pillar 핵심 요소 — beige+blood) =====
        bandage_base = (240, 215, 185)
        bandage_pad = (255, 235, 215)
        bandage_blood = (160, 50, 60)
        # 상하단 반창고
        for _ in range(14):
            bx = random.randint(ox - bw // 2 + 3, ox + fw + bw // 2 - 3)
            by_lo = oy - bw // 2 + 2
            by_hi = oy - 2
            bb_lo = oy + fh + 2
            bb_hi = oy + fh + bw // 2 - 2
            if by_lo < by_hi and bb_lo < bb_hi:
                by = random.choice([random.randint(by_lo, by_hi), random.randint(bb_lo, bb_hi)])
            elif by_lo < by_hi:
                by = random.randint(by_lo, by_hi)
            elif bb_lo < bb_hi:
                by = random.randint(bb_lo, bb_hi)
            else:
                continue
            bl = max(4, int(random.uniform(7, 14) * arena_scale))
            bwd = max(2, int(3 * arena_scale))
            # 반창고 직사각 (대각선)
            pygame.draw.line(brd, bandage_base, (bx - bl, by - bl // 2),
                             (bx + bl, by + bl // 2), bwd)
            # 패드 (중앙)
            pygame.draw.circle(brd, bandage_pad, (bx, by), max(1, bwd))
            # 피 자국 (일부)
            if random.random() < 0.3:
                pygame.draw.circle(brd, bandage_blood, (bx + random.randint(-2, 2),
                                   by + random.randint(-1, 1)), max(1, bwd // 2))
        # 좌우 반창고
        for _ in range(10):
            bl_lo = ox - bw // 2 + 2
            bl_hi = ox - 2
            br_lo = ox + fw + 2
            br_hi = ox + fw + bw // 2 - 2
            if bl_lo < bl_hi and br_lo < br_hi:
                bx = random.choice([random.randint(bl_lo, bl_hi), random.randint(br_lo, br_hi)])
            elif bl_lo < bl_hi:
                bx = random.randint(bl_lo, bl_hi)
            elif br_lo < br_hi:
                bx = random.randint(br_lo, br_hi)
            else:
                continue
            by = random.randint(oy + 5, max(oy + 6, oy + fh - 5))
            bl = max(3, int(random.uniform(6, 11) * arena_scale))
            bwd = max(2, int(3 * arena_scale))
            # X자 반창고
            pygame.draw.line(brd, bandage_base, (bx - bl, by - bl),
                             (bx + bl, by + bl), bwd)
            pygame.draw.line(brd, bandage_base, (bx - bl, by + bl),
                             (bx + bl, by - bl), bwd)
            pygame.draw.circle(brd, bandage_pad, (bx, by), max(1, bwd))

        # ===== 9. 면도날 (프레임 곳곳 — pillar 핵심 요소) =====
        razor_metal = (200, 205, 215)
        razor_dark = (140, 145, 155)
        razor_edge = (230, 235, 245)
        for _ in range(8):
            rx = random.randint(ox - bw // 2 + 4, ox + fw + bw // 2 - 4)
            ry_lo = oy - bw // 2 + 3
            ry_hi = oy - 3
            rb_lo = oy + fh + 3
            rb_hi = oy + fh + bw // 2 - 3
            if ry_lo < ry_hi and rb_lo < rb_hi:
                ry = random.choice([random.randint(ry_lo, ry_hi), random.randint(rb_lo, rb_hi)])
            elif ry_lo < ry_hi:
                ry = random.randint(ry_lo, ry_hi)
            elif rb_lo < rb_hi:
                ry = random.randint(rb_lo, rb_hi)
            else:
                continue
            rw = max(4, int(random.uniform(6, 10) * arena_scale))
            rh = max(2, int(random.uniform(3, 5) * arena_scale))
            # 면도날 본체
            pygame.draw.rect(brd, razor_metal, (rx - rw, ry - rh, rw * 2, rh * 2))
            # 구멍
            pygame.draw.circle(brd, razor_dark, (rx, ry), max(1, rh // 2))
            # 날 (밝은 엣지)
            pygame.draw.line(brd, razor_edge, (rx - rw, ry - rh), (rx + rw, ry - rh), 1)
            pygame.draw.line(brd, razor_edge, (rx - rw, ry + rh), (rx + rw, ry + rh), 1)

        # ===== 10. 코너 — 곰인형 (상단, 풀바디) + 알약 (하단) =====
        # 상단 코너: 곰인형 (bear_black + bear_pink)
        bear_positions = [
            (ox - bw // 4, oy - bw // 4),
            (ox + fw + bw // 4, oy - bw // 4),
        ]
        for bi, (bx_b, by_b) in enumerate(bear_positions):
            br = corner_r
            body_c = (30, 25, 30) if bi == 0 else (255, 180, 200)
            belly_c = (min(255, body_c[0] + 45), min(255, body_c[1] + 40),
                       min(255, body_c[2] + 35))
            eye_c = (200, 60, 80)
            # 다리 (앉은 자세)
            leg_w = max(2, br // 3)
            leg_h = max(3, br // 2)
            pygame.draw.ellipse(brd, body_c,
                                (bx_b - br // 2 - 1, by_b + br // 2, leg_w + 2, leg_h))
            pygame.draw.ellipse(brd, body_c,
                                (bx_b + br // 2 - leg_w, by_b + br // 2, leg_w + 2, leg_h))
            # 팔
            arm_w = max(2, br // 4)
            arm_h = max(3, br // 2)
            pygame.draw.ellipse(brd, body_c,
                                (bx_b - br - arm_w + 2, by_b - br // 4, arm_w + 1, arm_h))
            pygame.draw.ellipse(brd, body_c,
                                (bx_b + br - 2, by_b - br // 4, arm_w + 1, arm_h))
            # 몸통 (타원)
            pygame.draw.ellipse(brd, body_c,
                                (bx_b - br * 2 // 3, by_b - br // 4,
                                 br * 4 // 3, br + br // 3))
            # 배 (밝은)
            pygame.draw.ellipse(brd, belly_c,
                                (bx_b - br // 4, by_b + br // 6,
                                 br // 2, br // 2))
            # 귀
            ear_r = max(2, br // 3)
            for ear_side in [-1, 1]:
                ear_x = bx_b + ear_side * br // 2
                ear_y = by_b - br // 2 - ear_r // 2
                pygame.draw.circle(brd, body_c, (ear_x, ear_y), ear_r)
                pygame.draw.circle(brd, (255, 150, 180),
                                   (ear_x, ear_y), max(1, ear_r - 2))
            # 머리
            pygame.draw.circle(brd, body_c, (bx_b, by_b), br)
            # 주둥이 (밝은 타원)
            muzzle_w = max(3, br // 2)
            muzzle_h = max(2, br // 3)
            pygame.draw.ellipse(brd, belly_c,
                                (bx_b - muzzle_w // 2, by_b + br // 6,
                                 muzzle_w, muzzle_h))
            # X 눈
            ex_sz = max(2, br // 4)
            for side in [-1, 1]:
                ex_x = bx_b + side * br // 3
                ex_y = by_b - br // 6
                pygame.draw.line(brd, eye_c,
                                 (ex_x - ex_sz, ex_y - ex_sz),
                                 (ex_x + ex_sz, ex_y + ex_sz), max(1, int(arena_scale * 1.5)))
                pygame.draw.line(brd, eye_c,
                                 (ex_x + ex_sz, ex_y - ex_sz),
                                 (ex_x - ex_sz, ex_y + ex_sz), max(1, int(arena_scale * 1.5)))
            # 코
            pygame.draw.circle(brd, eye_c, (bx_b, by_b + br // 4), max(1, br // 6))
            # 입 (슬픈)
            mouth_w = max(2, br // 4)
            pygame.draw.arc(brd, (180, 40, 60),
                            (bx_b - mouth_w, by_b + br // 3, mouth_w * 2, max(2, br // 4)),
                            3.14, 6.28, 1)
            # 눈물 (한쪽)
            tear_x_b = bx_b - br // 3
            tear_y_b = by_b + ex_sz
            pygame.draw.ellipse(brd, (100, 180, 255),
                                (tear_x_b - 1, tear_y_b, 2, max(2, br // 4)))
            # 반창고 (곰 몸에)
            bd_x_b = bx_b + random.randint(-br // 3, br // 3)
            bd_y_b = by_b + random.randint(0, br // 3)
            bd_l_b = max(3, br // 4)
            pygame.draw.line(brd, (210, 185, 155),
                             (bd_x_b - bd_l_b, bd_y_b), (bd_x_b + bd_l_b, bd_y_b),
                             max(1, int(arena_scale * 1.5)))
            # 리본 (핑크 곰만)
            if bi == 1:
                rb_r = max(2, br // 3)
                rb_x = bx_b + br // 2
                rb_y = by_b - br // 2
                rb_c = (255, 80, 120)
                pygame.draw.ellipse(brd, rb_c,
                                    (rb_x - rb_r * 2, rb_y - rb_r, rb_r * 2, rb_r * 2))
                pygame.draw.ellipse(brd, rb_c,
                                    (rb_x, rb_y - rb_r, rb_r * 2, rb_r * 2))
                pygame.draw.circle(brd, (200, 60, 90), (rb_x, rb_y), max(1, rb_r // 2))
                # 리본 꼬리
                pygame.draw.line(brd, rb_c, (rb_x, rb_y),
                                 (rb_x - rb_r, rb_y + rb_r * 2),
                                 max(1, int(arena_scale)))
                pygame.draw.line(brd, rb_c, (rb_x, rb_y),
                                 (rb_x + rb_r, rb_y + rb_r * 2),
                                 max(1, int(arena_scale)))

        # 하단 코너: 알약 캡슐
        pill_positions = [
            (ox - bw // 4, oy + fh + bw // 4),
            (ox + fw + bw // 4, oy + fh + bw // 4),
        ]
        pill_r = max(4, int(10 * arena_scale))
        pill_colors = [(255, 180, 200), (180, 200, 240), (255, 240, 180)]
        for pi_idx, (px, py) in enumerate(pill_positions):
            pw = pill_r * 3
            ph = pill_r
            pc = pill_colors[pi_idx % 3]
            # 캡슐 좌측 (컬러)
            pygame.draw.ellipse(brd, pc,
                                (px - pw // 2, py - ph, pw // 2, ph * 2))
            # 캡슐 우측 (하양)
            pygame.draw.ellipse(brd, (245, 245, 250),
                                (px, py - ph, pw // 2, ph * 2))
            # 구분선
            pygame.draw.line(brd, (200, 100, 140),
                             (px, py - ph), (px, py + ph), max(1, int(arena_scale)))
            # 하이라이트
            pygame.draw.ellipse(brd, (255, 200, 220),
                                (px - pw // 4, py - ph + 2, pw // 4, max(1, ph // 2)))

        # ===== 11. 꿰맨 자국 / 스티칭 (프레임 전체 테두리) =====
        stitch_step = max(4, int(10 * arena_scale))
        stitch_c = (230, 180, 200)
        stitch_w = max(1, int(1.5 * arena_scale))
        # 상단 스티칭
        for sx_s in range(ox - bw // 3, ox + fw + bw // 3, stitch_step):
            sy_s = oy - bw // 3
            pygame.draw.line(brd, stitch_c,
                             (sx_s, sy_s - 2), (sx_s + stitch_step // 2, sy_s + 2), stitch_w)
        # 하단 스티칭
        for sx_s in range(ox - bw // 3, ox + fw + bw // 3, stitch_step):
            sy_s = oy + fh + bw // 3
            pygame.draw.line(brd, stitch_c,
                             (sx_s, sy_s - 2), (sx_s + stitch_step // 2, sy_s + 2), stitch_w)
        # 좌측 스티칭
        for sy_s in range(oy - bw // 3, oy + fh + bw // 3, stitch_step):
            sx_s = ox - bw // 3
            pygame.draw.line(brd, stitch_c,
                             (sx_s - 2, sy_s), (sx_s + 2, sy_s + stitch_step // 2), stitch_w)
        # 우측 스티칭
        for sy_s in range(oy - bw // 3, oy + fh + bw // 3, stitch_step):
            sx_s = ox + fw + bw // 3
            pygame.draw.line(brd, stitch_c,
                             (sx_s - 2, sy_s), (sx_s + 2, sy_s + stitch_step // 2), stitch_w)

        # ===== 12. 안전핀 (프레임 위 — 반창고와 함께) =====
        for _ in range(10):
            pin_x = random.randint(ox - bw // 2 + 4, ox + fw + bw // 2 - 4)
            pin_lo = oy - bw // 2 + 2
            pin_hi = oy + fh + bw // 2 - 6
            if pin_lo >= pin_hi:
                continue
            pin_y = random.randint(pin_lo, pin_hi)
            if ox + 3 < pin_x < ox + fw - 3 and oy + 3 < pin_y < oy + fh - 3:
                continue
            pin_len = max(4, int(8 * arena_scale))
            pin_c = (190, 195, 205)
            pin_hl = (220, 225, 235)
            # 핀 직선부
            pygame.draw.line(brd, pin_c,
                             (pin_x, pin_y), (pin_x + pin_len, pin_y), max(1, int(arena_scale)))
            # 갈고리
            hook_h = max(2, int(3 * arena_scale))
            pygame.draw.line(brd, pin_c,
                             (pin_x + pin_len, pin_y),
                             (pin_x + pin_len - 2, pin_y + hook_h), max(1, int(arena_scale)))
            pygame.draw.line(brd, pin_c,
                             (pin_x + pin_len - 2, pin_y + hook_h),
                             (pin_x + pin_len - 4, pin_y), max(1, int(arena_scale)))
            # 머리 (동그란 고리)
            pin_head_r = max(2, int(3 * arena_scale))
            pygame.draw.circle(brd, pin_c, (pin_x, pin_y), pin_head_r, max(1, int(arena_scale)))
            pygame.draw.circle(brd, pin_hl, (pin_x - 1, pin_y - 1), max(1, pin_head_r // 2))

        # ===== 13. 눈물 드립 (프레임 하단에서 아래로 흘러내림) =====
        for _ in range(8):
            drip_x = random.randint(ox, ox + fw)
            drip_y = oy + fh + bw // 2
            drip_len = max(4, int(random.uniform(8, 20) * arena_scale))
            drip_c = random.choice([
                (100, 160, 255), (140, 180, 255), (255, 100, 160),
            ])
            for di in range(drip_len):
                da = max(1, 50 - di * 3)
                dx_off = int(math.sin(di * 0.2) * 1)
                pygame.draw.circle(brd, (*drip_c, da),
                                   (drip_x + dx_off, drip_y + di), max(1, int(arena_scale)))
            # 끝 물방울
            pygame.draw.circle(brd, (*drip_c, 60),
                               (drip_x, drip_y + drip_len), max(1, int(2 * arena_scale)))

        # ===== 14. 깨진 하트 (프레임 좌우) =====
        for _ in range(4):
            bhx_lo = ox - bw // 2 + 3
            bhx_hi = ox - 3
            bhr_lo = ox + fw + 3
            bhr_hi = ox + fw + bw // 2 - 3
            if bhx_lo < bhx_hi and bhr_lo < bhr_hi:
                bhx = random.choice([random.randint(bhx_lo, bhx_hi),
                                     random.randint(bhr_lo, bhr_hi)])
            elif bhx_lo < bhx_hi:
                bhx = random.randint(bhx_lo, bhx_hi)
            elif bhr_lo < bhr_hi:
                bhx = random.randint(bhr_lo, bhr_hi)
            else:
                continue
            bhy = random.randint(oy + 10, max(oy + 11, oy + fh - 10))
            bh_sz = max(3, int(6 * arena_scale))
            bh_c = (200, 50, 80)
            # 하트 (작은)
            bhr_r = max(1, bh_sz // 2)
            pygame.draw.circle(brd, bh_c, (bhx - bhr_r + 1, bhy - bhr_r // 2), bhr_r)
            pygame.draw.circle(brd, bh_c, (bhx + bhr_r - 1, bhy - bhr_r // 2), bhr_r)
            pygame.draw.polygon(brd, bh_c,
                                [(bhx - bh_sz + 1, bhy), (bhx + bh_sz - 1, bhy),
                                 (bhx, bhy + bh_sz)])
            # 금 (지그재그)
            crack_c2 = (40, 20, 30)
            pygame.draw.line(brd, crack_c2,
                             (bhx, bhy - bhr_r),
                             (bhx + random.randint(-2, 2), bhy + bh_sz), 1)

        # ===== 15. 체인 자물쇠 (좌우 체인 중간에 추가) =====
        for side in [-1, 1]:
            lock_x = ox + (fw + bw // 3 if side > 0 else -bw // 3)
            lock_y = oy + fh // 2
            lk_w = max(4, int(7 * arena_scale))
            lk_h = max(5, int(9 * arena_scale))
            # 걸쇠
            pygame.draw.arc(brd, chain_mid,
                            (lock_x - lk_w // 3, lock_y - lk_h,
                             lk_w * 2 // 3, lk_h // 2), 0, 3.14, max(1, int(arena_scale)))
            # 본체
            pygame.draw.rect(brd, (180, 150, 50),
                             (lock_x - lk_w // 2, lock_y - lk_h // 2, lk_w, lk_h))
            pygame.draw.rect(brd, (200, 170, 60),
                             (lock_x - lk_w // 2, lock_y - lk_h // 2, lk_w, lk_h), 1)
            # 열쇠구멍
            pygame.draw.circle(brd, (30, 25, 20),
                               (lock_x, lock_y - lk_h // 6), max(1, lk_w // 5))
            pygame.draw.line(brd, (30, 25, 20),
                             (lock_x, lock_y - lk_h // 6),
                             (lock_x, lock_y + lk_h // 4), 1)

        # ===== 16. 내부 테두리 + 네온 글로우 =====
        # 코너 X 장식 (pillar 스타일)
        corners_x = [
            (ox - 3, oy - 3), (ox + fw + 3, oy - 3),
            (ox - 3, oy + fh + 3), (ox + fw + 3, oy + fh + 3),
        ]
        xsz = max(3, int(8 * arena_scale))
        for cx_x, cy_x in corners_x:
            pygame.draw.line(brd, (255, 105, 180),
                             (cx_x - xsz, cy_x - xsz), (cx_x + xsz, cy_x + xsz),
                             max(1, int(2 * arena_scale)))
            pygame.draw.line(brd, (255, 105, 180),
                             (cx_x + xsz, cy_x - xsz), (cx_x - xsz, cy_x + xsz),
                             max(1, int(2 * arena_scale)))
        # 내부 테두리선 (어두운 엣지)
        pygame.draw.rect(brd, frame_edge,
                         (ox - 3, oy - 3, fw + 6, fh + 6), max(1, int(3 * arena_scale)))
        # 핑크 네온 글로우 (2중)
        for ngi in range(2):
            glow_s = pygame.Surface((fw + 8 + ngi * 4, fh + 8 + ngi * 4), pygame.SRCALPHA)
            neon_glow_c = (255, 100, 180) if ngi == 0 else (100, 200, 255)
            pygame.draw.rect(glow_s, (*neon_glow_c, max(1, 65 - ngi * 35)),
                             (0, 0, fw + 8 + ngi * 4, fh + 8 + ngi * 4),
                             max(1, int((3 - ngi) * arena_scale)))
            brd.blit(glow_s, (ox - 4 - ngi * 2, oy - 4 - ngi * 2))

        # ===== 17. 네온 사인 글로우 (프레임 상하단 — 증가) =====
        neon_colors = [(255, 100, 180), (100, 220, 255), (200, 120, 255),
                       (255, 80, 120), (80, 255, 200)]
        for _ in range(10):
            nx = random.randint(ox, ox + fw)
            ny = random.choice([oy - bw // 3, oy + fh + bw // 3])
            nc = neon_colors[random.randint(0, len(neon_colors) - 1)]
            nr = max(3, int(random.uniform(4, 9) * arena_scale))
            # 4중 글로우
            for gi in range(4):
                gs = pygame.Surface((nr * 4 + gi * 4, nr * 4 + gi * 4), pygame.SRCALPHA)
                pygame.draw.circle(gs, (*nc, max(1, 35 - gi * 8)),
                                   (nr * 2 + gi * 2, nr * 2 + gi * 2), nr + gi * 2)
                brd.blit(gs, (nx - nr * 2 - gi * 2, ny - nr * 2 - gi * 2))
            pygame.draw.circle(brd, nc, (nx, ny), max(1, nr // 2))

        # ===== 18. 반짝이 파티클 (밀도 증가) =====
        for _ in range(45):
            sx = random.randint(ox - bw // 2, ox + fw + bw // 2)
            sy = random.choice([
                random.randint(max(0, oy - bw // 2 - lace_h), max(1, oy - 1)),
                random.randint(oy + fh + 1, min(brd_h - 1, oy + fh + bw // 2 + lace_h))
            ])
            sr = max(1, int(random.uniform(1, 3) * arena_scale))
            sa = random.randint(100, 230)
            sc = random.choice([
                (255, 200, 230), (255, 255, 255), (200, 220, 255),
                (255, 180, 200), (255, 150, 220), (220, 200, 255),
            ])
            ss = pygame.Surface((sr * 4, sr * 4), pygame.SRCALPHA)
            pygame.draw.circle(ss, (*sc, sa // 2), (sr * 2, sr * 2), sr * 2)
            pygame.draw.circle(ss, (255, 255, 255, min(255, sa)),
                               (sr * 2, sr * 2), sr)
            brd.blit(ss, (sx - sr * 2, sy - sr * 2))

        # ===== 19. 좌우 하트 네온 라인 (프레임 내부 가장자리) =====
        for side_h in [-1, 1]:
            h_base_x = ox + (fw + 2 if side_h > 0 else -bw // 4)
            for hy_i in range(oy + 10, oy + fh - 10, max(8, int(25 * arena_scale))):
                h_r_n = max(2, int(4 * arena_scale))
                h_c_n = random.choice([(255, 80, 140), (255, 120, 180), (255, 60, 100)])
                # 미니 하트
                pygame.draw.circle(brd, h_c_n,
                                   (h_base_x - h_r_n // 2, hy_i), max(1, h_r_n // 2))
                pygame.draw.circle(brd, h_c_n,
                                   (h_base_x + h_r_n // 2, hy_i), max(1, h_r_n // 2))
                pygame.draw.polygon(brd, h_c_n,
                                    [(h_base_x - h_r_n, hy_i + 1),
                                     (h_base_x + h_r_n, hy_i + 1),
                                     (h_base_x, hy_i + h_r_n + 1)])

        random.seed()

        # ── 최종 블릿 ──
        blit_x = ix - half_out - margin
        blit_y = iy - half_out - lace_h - margin
        screen.blit(brd, (blit_x, blit_y))

    def _draw_temple_arena_border(self, screen, ix, iy, ig_w, ig_h, arena_scale):
        """경기장 가장자리 위에 티베트/소림 사원 양식의 초고퀄리티 프레임.
        흑요석/화강암 석조 + 만다라 + 연꽃 + 별빛 + 등롱."""
        bw = max(8, int(40 * arena_scale))
        frieze_h = max(4, int(16 * arena_scale))
        corner_r = max(8, int(28 * arena_scale))
        margin = max(2, int(6 * arena_scale))
        half_out = bw // 2 + margin

        brd_w = ig_w + half_out * 2 + margin * 2
        brd_h = ig_h + half_out * 2 + frieze_h * 2 + margin * 2
        brd = pygame.Surface((brd_w, brd_h), pygame.SRCALPHA)

        ox = half_out + margin
        oy = half_out + frieze_h + margin
        fw, fh = ig_w, ig_h

        random.seed(41370)

        # ===== 1. 외곽 글로우 (보라빛 + 달빛) =====
        for gi in range(4):
            glow_a = 35 - gi * 8
            gc = (60 + gi * 8, 50 + gi * 7, 100 + gi * 10)
            pygame.draw.rect(brd, (*gc, max(1, glow_a)),
                             (ox - bw // 2 - 4 - gi * 2, oy - bw // 2 - 4 - gi * 2,
                              fw + bw + 8 + gi * 4, fh + bw + 8 + gi * 4), 2)

        # ===== 2. 메인 프레임 — 3레이어 흑요석/화강암 =====
        # 레이어 1: 가장 어두운 석재
        stone_deep = (15, 12, 22)
        pygame.draw.rect(brd, stone_deep,
                         (ox - bw // 2, oy - bw // 2, fw + bw, fh + bw))
        # 레이어 2: 중간 석재
        stone_mid = (35, 30, 48)
        inner_m = max(2, bw // 6)
        pygame.draw.rect(brd, stone_mid,
                         (ox - bw // 2 + inner_m, oy - bw // 2 + inner_m,
                          fw + bw - inner_m * 2, fh + bw - inner_m * 2))
        # 레이어 3: 밝은 석재
        stone_light = (55, 50, 70)
        inner_m2 = max(3, bw // 3)
        pygame.draw.rect(brd, stone_light,
                         (ox - bw // 2 + inner_m2, oy - bw // 2 + inner_m2,
                          fw + bw - inner_m2 * 2, fh + bw - inner_m2 * 2))
        # 내부 컷아웃
        pygame.draw.rect(brd, (0, 0, 0, 0), (ox, oy, fw, fh))

        # ===== 3. 석재 블록 패턴 (프레임 표면 — 어두운 화강암) =====
        block_gap_h = max(4, int(8 * arena_scale))
        block_gap_w = max(6, int(14 * arena_scale))
        block_c1 = (45, 40, 58)
        block_c2 = (38, 34, 50)
        mortar_c = (22, 18, 32)
        # 상하단 블록
        for side_y, side_h in [(oy - bw // 2, bw // 2), (oy + fh, bw // 2)]:
            row = 0
            by = side_y + 1
            while by < side_y + side_h - 1:
                bx = ox - bw // 2 + (block_gap_w // 2 if row % 2 else 0) + 1
                while bx < ox + fw + bw // 2 - 2:
                    bw_r = block_gap_w + random.randint(-2, 2)
                    bc = block_c1 if random.random() > 0.4 else block_c2
                    pygame.draw.rect(brd, bc,
                                     (bx, by, bw_r - 1, block_gap_h - 1))
                    # 달빛 하이라이트 (상단)
                    pygame.draw.line(brd, (bc[0] + 12, bc[1] + 10, bc[2] + 14),
                                     (bx, by), (bx + bw_r - 2, by), 1)
                    # 모르타르
                    pygame.draw.line(brd, mortar_c,
                                     (bx + bw_r - 1, by), (bx + bw_r - 1, by + block_gap_h - 1), 1)
                    bx += bw_r
                by += block_gap_h
                row += 1
        # 좌우 블록
        for side_x, side_w in [(ox - bw // 2, bw // 2), (ox + fw, bw // 2)]:
            row = 0
            by = oy + 1
            while by < oy + fh - 1:
                bx = side_x + 1
                while bx < side_x + side_w - 1:
                    bw_r = min(side_w - 2, block_gap_w + random.randint(-2, 2))
                    bc = block_c1 if random.random() > 0.4 else block_c2
                    bh_r = block_gap_h + random.randint(-1, 1)
                    pygame.draw.rect(brd, bc,
                                     (bx, by, bw_r - 1, bh_r - 1))
                    pygame.draw.line(brd, (bc[0] + 12, bc[1] + 10, bc[2] + 14),
                                     (bx, by), (bx + bw_r - 2, by), 1)
                    bx += bw_r
                by += block_gap_h + random.randint(-1, 1)
                row += 1

        # ===== 4. 만다라 띠 (상하단 프리즈 — 어두운 금+보라) =====
        gold = (108, 90, 48)
        gold_bright = (153, 141, 84)
        gold_dark = (80, 65, 35)
        # 상단 프리즈
        fy_top = oy - bw // 2 - frieze_h
        pygame.draw.rect(brd, (28, 24, 40),
                         (ox - bw // 2, fy_top, fw + bw, frieze_h))
        pygame.draw.rect(brd, (35, 30, 48),
                         (ox - bw // 2 + 1, fy_top + 1, fw + bw - 2, frieze_h - 2))
        # 프리즈 만다라 문양 (반복 원형 패턴)
        mandala_gap = max(6, int(18 * arena_scale))
        for mx in range(ox - bw // 2 + mandala_gap, ox + fw + bw // 2, mandala_gap):
            mr = max(2, int(5 * arena_scale))
            pygame.draw.circle(brd, gold_bright, (mx, fy_top + frieze_h // 2), mr)
            pygame.draw.circle(brd, gold_dark, (mx, fy_top + frieze_h // 2), mr, 1)
            # 내부 꽃잎
            for pi in range(6):
                ang = pi * math.pi / 3
                px = mx + int(mr * 0.5 * math.cos(ang))
                py = fy_top + frieze_h // 2 + int(mr * 0.5 * math.sin(ang))
                pygame.draw.circle(brd, gold, (px, py), max(1, mr // 3))
        # 하단 프리즈
        fy_bot = oy + fh + bw // 2
        pygame.draw.rect(brd, (28, 24, 40),
                         (ox - bw // 2, fy_bot, fw + bw, frieze_h))
        pygame.draw.rect(brd, (35, 30, 48),
                         (ox - bw // 2 + 1, fy_bot + 1, fw + bw - 2, frieze_h - 2))
        for mx in range(ox - bw // 2 + mandala_gap, ox + fw + bw // 2, mandala_gap):
            mr = max(2, int(5 * arena_scale))
            pygame.draw.circle(brd, gold_bright, (mx, fy_bot + frieze_h // 2), mr)
            pygame.draw.circle(brd, gold_dark, (mx, fy_bot + frieze_h // 2), mr, 1)
            for pi in range(6):
                ang = pi * math.pi / 3
                px = mx + int(mr * 0.5 * math.cos(ang))
                py = fy_bot + frieze_h // 2 + int(mr * 0.5 * math.sin(ang))
                pygame.draw.circle(brd, gold, (px, py), max(1, mr // 3))

        # ===== 5. 기둥 (좌우 4쌍 — 어두운 석조 기둥) =====
        col_count = 4
        col_w = max(3, int(6 * arena_scale))
        for ci in range(col_count):
            col_y = oy + (ci + 1) * fh // (col_count + 1) - 10
            col_h = max(10, int(24 * arena_scale))
            for side_x in [ox - bw // 3, ox + fw + bw // 3]:
                # 기단
                pygame.draw.rect(brd, stone_deep,
                                 (side_x - col_w - 2, col_y + col_h, col_w * 2 + 4,
                                  max(2, int(4 * arena_scale))))
                # 기둥 본체 (어두운 석재)
                pygame.draw.rect(brd, (42, 38, 55),
                                 (side_x - col_w, col_y, col_w * 2, col_h))
                # 달빛 하이라이트 (좌측 반)
                pygame.draw.rect(brd, (55, 50, 68),
                                 (side_x - col_w, col_y, col_w, col_h))
                # 주두 (상단 장식 — 어두운 금)
                cap_h = max(2, int(3 * arena_scale))
                pygame.draw.rect(brd, gold_dark,
                                 (side_x - col_w - 1, col_y - cap_h,
                                  col_w * 2 + 2, cap_h))
                pygame.draw.rect(brd, gold,
                                 (side_x - col_w, col_y - cap_h + 1,
                                  col_w * 2, cap_h - 1))
                # 세로 홈
                for fi in range(max(1, col_w)):
                    fx = side_x - col_w + 1 + fi * 2
                    if fx < side_x + col_w:
                        pygame.draw.line(brd, (35, 30, 48),
                                         (fx, col_y + 2), (fx, col_y + col_h - 2), 1)

        # ===== 6. 용/봉황 조각 (좌우 프레임 — 동양 스타일) =====
        dragon_c = (70, 60, 90)
        dragon_dark = (50, 42, 68)
        dragon_gold = (108, 90, 48)
        for side in [-1, 1]:
            base_x = ox + (fw + bw // 3 if side > 0 else -bw // 3)
            # 용 몸통 (S자 곡선)
            dragon_pts = []
            ny = oy - bw // 4
            while ny < oy + fh + bw // 4:
                nx = base_x + int(math.sin(ny * 0.04 + side) * bw // 6)
                dragon_pts.append((nx, ny))
                ny += max(2, int(3 * arena_scale))
            if len(dragon_pts) > 2:
                pygame.draw.lines(brd, dragon_c, False, dragon_pts,
                                  max(3, int(5 * arena_scale)))
                # 비늘 패턴
                for i in range(0, len(dragon_pts) - 1, 2):
                    nx, ny = dragon_pts[i]
                    sr = max(1, int(2 * arena_scale))
                    pygame.draw.circle(brd, dragon_dark, (nx, ny), sr)
                    pygame.draw.circle(brd, dragon_gold, (nx, ny), max(1, sr - 1))
            # 용 머리 (상단)
            if dragon_pts:
                hx, hy = dragon_pts[0]
                hr = max(4, int(8 * arena_scale))
                # 머리
                pygame.draw.polygon(brd, dragon_c,
                                    [(hx - hr, hy), (hx, hy - hr * 2), (hx + hr, hy)])
                # 갈기
                pygame.draw.ellipse(brd, dragon_gold,
                                    (hx - hr - 2, hy - hr, hr * 2 + 4, hr))
                # 눈 (붉은빛)
                pygame.draw.circle(brd, (160, 40, 40), (hx - hr // 3, hy - hr), max(1, hr // 4))
                pygame.draw.circle(brd, (160, 40, 40), (hx + hr // 3, hy - hr), max(1, hr // 4))
                pygame.draw.circle(brd, (20, 8, 8), (hx - hr // 3, hy - hr), max(1, hr // 6))
                pygame.draw.circle(brd, (20, 8, 8), (hx + hr // 3, hy - hr), max(1, hr // 6))

        # ===== 7. 코너 장식 — 만다라 (상단) + 연꽃 (하단) =====
        # 상단 만다라
        mandala_pos = [
            (ox - bw // 4, oy - bw // 4),
            (ox + fw + bw // 4, oy - bw // 4),
        ]
        for mx, my in mandala_pos:
            mr = corner_r
            # 동심원 (보라+금)
            for ri in range(4):
                rr = mr - ri * max(2, mr // 5)
                if rr < 2:
                    break
                pygame.draw.circle(brd, gold if ri % 2 == 0 else (50, 42, 68),
                                   (mx, my), rr, max(1, int(arena_scale)))
            # 12방사선
            for i in range(12):
                ang = i * math.pi / 6
                lx = mx + int(mr * math.cos(ang))
                ly = my + int(mr * math.sin(ang))
                pygame.draw.line(brd, gold_bright, (mx, my), (lx, ly), 1)
                pygame.draw.circle(brd, gold, (lx, ly), max(1, int(2 * arena_scale)))
            # 중앙 보석 (보라빛)
            pygame.draw.circle(brd, (100, 50, 130), (mx, my), max(2, mr // 4))
            pygame.draw.circle(brd, (140, 80, 170), (mx, my), max(1, mr // 6))

        # 하단 연꽃
        lotus_pos = [
            (ox - bw // 4, oy + fh + bw // 4),
            (ox + fw + bw // 4, oy + fh + bw // 4),
        ]
        for lx_l, ly_l in lotus_pos:
            lr = max(4, int(10 * arena_scale))
            # 연잎 (어두운 녹색)
            pygame.draw.ellipse(brd, (25, 50, 35),
                                (lx_l - lr - 2, ly_l - lr // 3, lr * 2 + 4, lr))
            # 연꽃 꽃잎 (핑크/보라)
            for pi in range(6):
                ang = pi * math.pi / 3 - math.pi / 6
                px_p = lx_l + int(lr * 0.6 * math.cos(ang))
                py_p = ly_l - lr // 4 + int(lr * 0.4 * math.sin(ang))
                pr = max(2, lr // 3)
                petal_c = (140, 90, 110) if pi % 2 == 0 else (100, 70, 140)
                pygame.draw.circle(brd, petal_c, (px_p, py_p), pr)
            # 중심 (금색)
            pygame.draw.circle(brd, gold_bright, (lx_l, ly_l - lr // 4), max(1, lr // 4))

        # ===== 8. 보석 장식 (프레임 곳곳 — 보라/남색 톤) =====
        gem_colors = [(100, 50, 130), (40, 80, 160), (50, 120, 100),
                      (130, 50, 100), (108, 90, 48)]
        # 안전한 범위 계산 (arena_scale이 작을 때 randint 에러 방지)
        gem_top_lo = oy - bw // 2 + 3
        gem_top_hi = oy - 2
        gem_bot_lo = oy + fh + 2
        gem_bot_hi = oy + fh + bw // 2 - 3
        gem_left_lo = ox - bw // 2 + 3
        gem_left_hi = ox - 2
        gem_right_lo = ox + fw + 2
        gem_right_hi = ox + fw + bw // 2 - 3
        for _ in range(20):
            gx = random.randint(ox - bw // 2 + 3, max(ox - bw // 2 + 3, ox + fw + bw // 2 - 3))
            if gem_top_lo < gem_top_hi and gem_bot_lo < gem_bot_hi:
                gy = random.choice([
                    random.randint(gem_top_lo, gem_top_hi),
                    random.randint(gem_bot_lo, gem_bot_hi)
                ])
            elif gem_top_lo < gem_top_hi:
                gy = random.randint(gem_top_lo, gem_top_hi)
            elif gem_bot_lo < gem_bot_hi:
                gy = random.randint(gem_bot_lo, gem_bot_hi)
            else:
                continue
            gc = gem_colors[random.randint(0, 4)]
            gr = max(2, int(random.uniform(2, 5) * arena_scale))
            # 보석 (다이아몬드 형태)
            pygame.draw.polygon(brd, gc,
                                [(gx, gy - gr), (gx + gr, gy),
                                 (gx, gy + gr), (gx - gr, gy)])
            # 하이라이트
            pygame.draw.circle(brd, (min(255, gc[0] + 50), min(255, gc[1] + 50),
                                     min(255, gc[2] + 50)),
                               (gx - gr // 3, gy - gr // 3), max(1, gr // 3))
            # 테두리
            pygame.draw.polygon(brd, gold_dark,
                                [(gx, gy - gr), (gx + gr, gy),
                                 (gx, gy + gr), (gx - gr, gy)], 1)
        # 좌우 보석
        for _ in range(12):
            if gem_left_lo < gem_left_hi and gem_right_lo < gem_right_hi:
                gx = random.choice([
                    random.randint(gem_left_lo, gem_left_hi),
                    random.randint(gem_right_lo, gem_right_hi)
                ])
            elif gem_left_lo < gem_left_hi:
                gx = random.randint(gem_left_lo, gem_left_hi)
            elif gem_right_lo < gem_right_hi:
                gx = random.randint(gem_right_lo, gem_right_hi)
            else:
                continue
            gy = random.randint(oy + 5, max(oy + 5, oy + fh - 5))
            gc = gem_colors[random.randint(0, 4)]
            gr = max(2, int(random.uniform(2, 4) * arena_scale))
            pygame.draw.polygon(brd, gc,
                                [(gx, gy - gr), (gx + gr, gy),
                                 (gx, gy + gr), (gx - gr, gy)])
            pygame.draw.circle(brd, (min(255, gc[0] + 50), min(255, gc[1] + 50),
                                     min(255, gc[2] + 50)),
                               (gx - gr // 3, gy - gr // 3), max(1, gr // 3))

        # ===== 9. 내부 금선 + 보라빛 글로우 라인 =====
        pygame.draw.rect(brd, gold,
                         (ox - 2, oy - 2, fw + 4, fh + 4), max(1, int(2 * arena_scale)))
        pygame.draw.rect(brd, gold_bright,
                         (ox - 1, oy - 1, fw + 2, fh + 2), 1)
        # 보라빛 글로우
        glow_s = pygame.Surface((fw + 8, fh + 8), pygame.SRCALPHA)
        pygame.draw.rect(glow_s, (80, 60, 120, 50),
                         (0, 0, fw + 8, fh + 8), max(1, int(3 * arena_scale)))
        brd.blit(glow_s, (ox - 4, oy - 4))

        # ===== 10. 별빛 파티클 (프레임 위 — 은빛/보라빛) =====
        for _ in range(25):
            sx = random.randint(ox - bw // 2, ox + fw + bw // 2)
            sy = random.choice([
                random.randint(oy - bw // 2 - frieze_h, oy - 1),
                random.randint(oy + fh + 1, oy + fh + bw // 2 + frieze_h)
            ])
            sr = max(1, int(random.uniform(1, 3) * arena_scale))
            sa = random.randint(50, 140)
            sc = (160 + random.randint(0, 60), 150 + random.randint(0, 60),
                  200 + random.randint(0, 55), sa)
            ss = pygame.Surface((sr * 4, sr * 4), pygame.SRCALPHA)
            pygame.draw.circle(ss, sc, (sr * 2, sr * 2), sr * 2)
            pygame.draw.circle(ss, (220, 215, 255, min(255, sa + 30)),
                               (sr * 2, sr * 2), sr)
            brd.blit(ss, (sx - sr * 2, sy - sr * 2))

        random.seed()

        # ── 최종 블릿 ──
        blit_x = ix - half_out - margin
        blit_y = iy - half_out - frieze_h - margin
        screen.blit(brd, (blit_x, blit_y))

    def _draw_surface_jungle(self, surf, t, alpha=255):
        """정글/늪지 행성 표면 — 초고퀄리티. Stage 2 악어장군 테마.
        t: 0(고공) ~ 1(지표면). 스테이지1 조선 지형과 동급 디테일."""
        W, H = surf.get_width(), surf.get_height()
        _cz_x, _cz_y = W // 2, H // 2
        _cz_hw, _cz_hh = 150, 120

        def _in_center(px, py):
            return abs(px - _cz_x) < _cz_hw and abs(py - _cz_y) < _cz_hh

        # ===== 기본 지형 — HD 1px 스무스 그라디언트 =====
        sky_blend = max(0.0, 1.0 - t * 3)
        for row in range(H):
            fy = row / H
            gr = int((22 + fy * 25) * (1 - sky_blend) + (55 + fy * 35) * sky_blend)
            gg = int((40 + fy * 32) * (1 - sky_blend) + (95 + fy * 35) * sky_blend)
            gb = int((18 + fy * 15) * (1 - sky_blend) + (60 + fy * 28) * sky_blend)
            pygame.draw.line(surf, (min(255, gr), min(255, gg), min(255, gb), alpha),
                             (0, row), (W, row))

        random.seed(2137)

        # ===== 습지/늪 패치 (HD 다층 + 색상 다양화) =====
        for _ in range(95):
            px = random.randint(-60, W + 60)
            py = random.randint(-60, H + 60)
            pr = random.randint(22, 180)
            g = random.randint(12, 50)
            vtype = random.randint(0, 3)
            if vtype == 0:
                c = (max(0, g - 8), max(0, min(255, g + 15)), max(0, g - 12))
            elif vtype == 1:
                c = (max(0, g + 5), max(0, min(255, g + 8)), max(0, g - 8))
            elif vtype == 2:
                c = (max(0, g - 5), max(0, min(255, g + 22)), max(0, g - 3))
            else:
                c = (max(0, g - 2), max(0, min(255, g - 5)), max(0, g - 15))
            ps = pygame.Surface((pr * 2, pr * 2), pygame.SRCALPHA)
            for li in range(pr, max(1, pr // 4), -max(1, pr // 8)):
                la = max(1, int(55 * alpha / 255 * li / pr))
                pygame.draw.circle(ps, (*c, la), (pr, pr), li)
            surf.blit(ps, (px - pr, py - pr))

        # ===== 미세 지면 질감 (이끼/부엽토/습지 입자) =====
        for _ in range(300):
            gx = random.randint(0, W - 1)
            gy = random.randint(0, H - 1)
            ga = random.randint(14, 38)
            gc = random.choice([
                (25, 42, 18), (32, 55, 22), (18, 35, 15),
                (38, 30, 18), (28, 48, 20), (20, 38, 16)])
            pygame.draw.circle(surf, (*gc, ga), (gx, gy), 1)

        # ===== 열대 산맥 — 원경 (안개 속 밀림 능선 + 대기원근법, 초빼곡) =====
        for _ in range(22):
            mx = random.randint(-80, W + 80)
            my = random.randint(-70, H // 5)
            mw = random.randint(130, 400)
            mh = random.randint(50, 160)
            mc_g = 25 + random.randint(0, 25)
            mc = (mc_g - 8, mc_g + 20, mc_g - 10)
            ma = min(255, int(120 * alpha / 255))
            ms = pygame.Surface((mw * 2, mh + 4), pygame.SRCALPHA)
            # 부드러운 산 실루엣 (둥근 봉우리)
            tri_pts = [(mw, 0), (0, mh), (mw * 2, mh)]
            pygame.draw.polygon(ms, (*mc, ma), tri_pts)
            pygame.draw.ellipse(ms, (*mc, ma // 2),
                                (mw // 4, mh // 3, mw * 3 // 2, mh))
            # 밀림 질감 (산 위 나무 실루엣)
            for _ in range(mw // 8):
                ttx = random.randint(mw // 3, mw * 5 // 3)
                tty = random.randint(mh // 4, mh * 2 // 3)
                ttr = random.randint(4, 12)
                ttc = (max(0, mc[0] - 5), max(0, mc[1] + 8), max(0, mc[2] - 3))
                pygame.draw.circle(ms, (*ttc, ma // 2), (ttx, tty), ttr)
            # 능선 하이라이트 (안개빛)
            hl_c = (min(255, mc[0] + 20), min(255, mc[1] + 18), min(255, mc[2] + 12))
            pygame.draw.line(ms, (*hl_c, ma // 3), (mw, 2), (mw // 3, mh * 2 // 3), 1)
            surf.blit(ms, (mx - mw, my - mh // 3))
            # 산기슭 안개
            fog_s = pygame.Surface((mw * 2, 22), pygame.SRCALPHA)
            for fi in range(22):
                fa = max(1, int(ma // 3 * (1 - fi / 22)))
                pygame.draw.line(fog_s, (130, 170, 120, fa),
                                 (0, fi), (mw * 2, fi))
            surf.blit(fog_s, (mx - mw, my + mh // 2 - 5))

        # ===== 수평 안개띠 (원경~중경 — 열대 습기) =====
        for fi in range(5):
            fy_f = H // 8 + fi * H // 10
            fw = W + 60
            fh = random.randint(10, 22)
            fog_band = pygame.Surface((fw, fh), pygame.SRCALPHA)
            for row in range(fh):
                band_a = max(1, int(30 * math.sin(math.pi * row / fh)))
                pygame.draw.line(fog_band, (120, 160, 110, band_a),
                                 (0, row), (fw, row))
            surf.blit(fog_band, (-30, fy_f))

        # ===== 늪지/강 (HD — 둑+물결+반사+수련+악어+통나무) =====
        for river_i in range(2):
            pts_r = []
            y_base = H // 5 + river_i * H * 2 // 5
            amp = 85 + river_i * 45
            for step in range(60):
                st = step / 59
                sx = int(W * st)
                sy = y_base + int(amp * math.sin(st * math.pi * 2.2 + river_i * 1.5))
                pts_r.append((sx, sy))
            if len(pts_r) > 2:
                # 넓은 둑 (진흙 — 2겹)
                pts_bank_l = [(p[0], p[1] + 7) for p in pts_r]
                pts_bank_r = [(p[0], p[1] - 7) for p in pts_r]
                pygame.draw.lines(surf, (52, 40, 22), False, pts_bank_l, 5)
                pygame.draw.lines(surf, (58, 48, 28), False, pts_bank_r, 5)
                # 둑 위 풀
                for bi in range(5, len(pts_r) - 5, 4):
                    bx, by = pts_r[bi]
                    for side in [-1, 1]:
                        for _ in range(random.randint(1, 3)):
                            gx_g = bx + random.randint(-2, 2)
                            pygame.draw.line(surf, (35, 78, 28),
                                             (gx_g, by + side * 7),
                                             (gx_g + random.randint(-3, 3),
                                              by + side * 7 - random.randint(3, 7)), 1)
                # 물 (넓은 + 그라데이션)
                pygame.draw.lines(surf, (28, 58, 40), False, pts_r, 12)
                pygame.draw.lines(surf, (38, 72, 50), False, pts_r, 8)
                pygame.draw.lines(surf, (48, 88, 60), False, pts_r, 4)
                # 수면 반사 하이라이트
                pts_hl = [(p[0], p[1] - 3) for p in pts_r]
                pygame.draw.lines(surf, (70, 115, 78), False, pts_hl, 1)
                # 물결 무늬
                for si in range(3, len(pts_r) - 3, 3):
                    wx, wy = pts_r[si]
                    wl = random.randint(4, 9)
                    pygame.draw.line(surf, (85, 130, 90),
                                     (wx - wl, wy - 2), (wx + wl, wy - 2), 1)
                # 수련/릴리패드 (HD)
                for si in range(3, len(pts_r) - 3, 4):
                    wx, wy = pts_r[si]
                    lr = random.randint(4, 8)
                    # 릴리패드 (어두운 타원 + 밝은 내부 + V갈라짐)
                    ls = pygame.Surface((lr * 2 + 2, lr + 2), pygame.SRCALPHA)
                    pygame.draw.ellipse(ls, (25, 80, 35), (0, 0, lr * 2 + 2, lr + 2))
                    pygame.draw.ellipse(ls, (45, 110, 50), (1, 1, lr * 2, lr))
                    pygame.draw.line(ls, (0, 0, 0, 0), (lr + 1, lr // 2 + 1),
                                     (lr * 2, 0), 1)
                    # 잎맥
                    pygame.draw.line(ls, (35, 88, 38), (1, lr // 2), (lr * 2, lr // 2), 1)
                    surf.blit(ls, (wx - lr - 1, wy - lr // 2 - 1))
                    # 연꽃
                    if random.random() > 0.6:
                        for pi in range(5):
                            ang = pi * 72 + random.randint(-8, 8)
                            dx = int(2.5 * math.cos(math.radians(ang)))
                            dy = int(1.5 * math.sin(math.radians(ang)))
                            pygame.draw.circle(surf, (250, 245, 230), (wx + dx, wy + dy), 1)
                        pygame.draw.circle(surf, (255, 220, 100), (wx, wy), 1)
                # 악어 실루엣 (강 위 — river_i==0만)
                if river_i == 0:
                    for _ in range(random.randint(1, 3)):
                        ci = random.randint(10, len(pts_r) - 10)
                        cx, cy = pts_r[ci]
                        if _in_center(cx, cy):
                            continue
                        cd = random.choice([-1, 1])
                        # 몸통
                        pygame.draw.ellipse(surf, (30, 55, 28),
                                            (cx - 4, cy - 1, 9, 3))
                        # 꼬리
                        pygame.draw.line(surf, (28, 50, 25),
                                         (cx + cd * 5, cy), (cx + cd * 9, cy + 1), 1)
                        # 머리
                        pygame.draw.ellipse(surf, (35, 60, 30),
                                            (cx - cd * 6, cy - 1, 4, 3))
                        # 눈
                        pygame.draw.circle(surf, (180, 165, 35),
                                           (cx - cd * 5, cy - 1), 1)
                # 통나무 (강 위 부유)
                for _ in range(random.randint(1, 2)):
                    li_idx = random.randint(5, len(pts_r) - 5)
                    lx, ly = pts_r[li_idx]
                    ll = random.randint(8, 18)
                    pygame.draw.line(surf, (62, 45, 22), (lx, ly), (lx + ll, ly + 1), 3)
                    pygame.draw.line(surf, (78, 58, 30), (lx, ly - 1), (lx + ll, ly), 1)
                    # 이끼
                    for _ in range(random.randint(1, 3)):
                        mx_l = lx + random.randint(2, ll - 2)
                        pygame.draw.circle(surf, (38, 72, 30), (mx_l, ly - 1), 1)
                # 돌 (강변)
                for _ in range(4):
                    ri = random.randint(5, len(pts_r) - 5)
                    rx, ry = pts_r[ri]
                    rr = random.randint(3, 7)
                    pygame.draw.circle(surf, (52, 48, 40), (rx, ry + 6), rr)
                    pygame.draw.circle(surf, (68, 64, 55), (rx - 1, ry + 5), max(1, rr - 1))
                    if rr > 4:
                        pygame.draw.circle(surf, (42, 68, 35, 80), (rx, ry + 5), max(1, rr - 2))

        # ===== 늪지 연못 (HD — 거울반사+수련+개구리, 중앙 회피, 초빼곡) =====
        for _ in range(8):
            px = random.randint(60, W - 60)
            py = random.randint(H // 3, H * 2 // 3)
            if _in_center(px, py):
                continue
            pw = random.randint(40, 80)
            ph = random.randint(25, 50)
            # 둑 (진흙+풀 테두리)
            pygame.draw.ellipse(surf, (48, 38, 22),
                                (px - pw // 2 - 5, py - ph // 2 - 3, pw + 10, ph + 6))
            pygame.draw.ellipse(surf, (52, 68, 35),
                                (px - pw // 2 - 4, py - ph // 2 - 2, pw + 8, ph + 4))
            # 물 표면 (그라데이션 — 탁한 녹색)
            pond_s = pygame.Surface((pw, ph), pygame.SRCALPHA)
            for row in range(ph):
                frac = row / ph
                pa = int(120 + frac * 60)
                r = int(25 + frac * 10)
                g = int(58 + frac * 18)
                b = int(35 + frac * 12)
                pygame.draw.line(pond_s, (r, g, b, pa), (0, row), (pw, row))
            surf.blit(pond_s, (px - pw // 2, py - ph // 2))
            # 수면 반사
            hl_s = pygame.Surface((pw // 2, ph // 3 + 2), pygame.SRCALPHA)
            pygame.draw.ellipse(hl_s, (65, 105, 72, 45),
                                (0, 0, pw // 2, ph // 3 + 2))
            surf.blit(hl_s, (px - pw // 4, py - ph // 4))
            # 잔물결 (동심원)
            if pw > 40:
                for _ in range(random.randint(1, 3)):
                    rcx = px + random.randint(-pw // 4, pw // 4)
                    rcy = py + random.randint(-ph // 4, ph // 4)
                    for rr in range(2, 7, 2):
                        pygame.draw.circle(surf, (70, 110, 75, 25), (rcx, rcy), rr, 1)
            # 수련
            for _ in range(random.randint(3, 6)):
                lx = px + random.randint(-pw // 3, pw // 3)
                ly = py + random.randint(-ph // 4, ph // 4)
                lr = random.randint(3, 6)
                pygame.draw.circle(surf, (30, 82, 38), (lx, ly), lr)
                pygame.draw.circle(surf, (48, 108, 52), (lx, ly), max(1, lr - 1))
                pygame.draw.line(surf, (25, 72, 32), (lx, ly), (lx + lr, ly), 1)
            # 연꽃 (큰 연못)
            if pw > 50:
                fx = px + random.randint(-pw // 5, pw // 5)
                fy_f = py + random.randint(-ph // 5, ph // 5)
                for pi in range(6):
                    ang = pi * 60
                    dx = int(3 * math.cos(math.radians(ang)))
                    dy = int(2 * math.sin(math.radians(ang)))
                    pygame.draw.circle(surf, (245, 235, 220), (fx + dx, fy_f + dy), 2)
                    pygame.draw.circle(surf, (255, 200, 210), (fx + dx, fy_f + dy), 1)
                pygame.draw.circle(surf, (255, 230, 100), (fx, fy_f), 1)
            # 개구리 (작은 실루엣 — 큰 연못에만)
            if pw > 55:
                for _ in range(random.randint(0, 2)):
                    frx = px + random.randint(-pw // 3, pw // 3)
                    fry = py + random.randint(ph // 6, ph // 3)
                    pygame.draw.ellipse(surf, (28, 62, 25), (frx - 2, fry - 1, 5, 3))
                    pygame.draw.circle(surf, (35, 75, 30), (frx - 1, fry - 1), 1)
                    pygame.draw.circle(surf, (35, 75, 30), (frx + 1, fry - 1), 1)

        # ===== 거대 열대나무 원경 (밀림 캐노피 — 대기원근법, 초빼곡) =====
        for _ in range(30):
            tx = random.randint(-50, W + 50)
            ty = random.randint(-40, H // 4)
            tw = random.randint(20, 50)
            th = random.randint(40, 100)
            g_v = random.randint(18, 40)
            tc = (g_v - 5, g_v + 28, g_v - 8)
            tc_hl = (min(255, tc[0] + 15), min(255, tc[1] + 12), min(255, tc[2] + 8))
            # 줄기 (두꺼운 열대목)
            pygame.draw.line(surf, (42, 28, 15), (tx + 1, ty + th // 3), (tx + 1, ty + th), 5)
            pygame.draw.line(surf, (58, 42, 22), (tx, ty + th // 3), (tx, ty + th), 3)
            pygame.draw.line(surf, (72, 55, 30), (tx - 1, ty + th // 3 + 2), (tx - 1, ty + th - 2), 1)
            # 판근 (열대나무 특유의 넓은 뿌리)
            for ri in range(random.randint(2, 4)):
                rdx = random.choice([-1, 1]) * random.randint(4, 12)
                pygame.draw.line(surf, (50, 35, 18),
                                 (tx, ty + th - 2), (tx + rdx, ty + th + 3), 2)
            # 거대 수관 (다층 — 8~12개 원)
            for ci in range(random.randint(8, 14)):
                cx_c = tx + random.randint(-tw, tw)
                cy_c = ty + random.randint(-tw // 2, tw // 3)
                cr = random.randint(12, 30)
                cs = pygame.Surface((cr * 2, cr * 2), pygame.SRCALPHA)
                for ri in range(cr, 0, -1):
                    ra = max(1, int(95 * ri / cr * alpha / 255))
                    pygame.draw.circle(cs, (*tc, ra), (cr, cr), ri)
                surf.blit(cs, (cx_c - cr, cy_c - cr))
            # 수관 하이라이트 (상부 — 햇빛)
            for _ in range(random.randint(2, 4)):
                hx = tx + random.randint(-tw // 2, tw // 2)
                hy = ty + random.randint(-tw // 2, -tw // 4)
                hr = random.randint(5, 12)
                hs = pygame.Surface((hr * 2, hr * 2), pygame.SRCALPHA)
                pygame.draw.circle(hs, (*tc_hl, 40), (hr, hr), hr)
                surf.blit(hs, (hx - hr, hy - hr))

        # ===== 정글 나무 중경 (HD — 나무껍질+덩굴+기생식물, 중앙 회피, 초빼곡) =====
        for _ in range(50):
            tx = random.randint(15, W - 15)
            ty = random.randint(H // 6, H - 35)
            if _in_center(tx, ty):
                continue
            th = random.randint(25, 62)
            tw = random.randint(14, 32)
            # 그림자 (소프트)
            sh_s = pygame.Surface((tw * 3, 8), pygame.SRCALPHA)
            pygame.draw.ellipse(sh_s, (0, 0, 0, 22), (0, 0, tw * 3, 8))
            surf.blit(sh_s, (tx - tw * 3 // 2, ty + th))
            # 줄기 (HD 나무껍질 — 가로줄 질감)
            pygame.draw.line(surf, (42, 28, 12), (tx + 1, ty), (tx + 1, ty + th), 5)
            pygame.draw.line(surf, (68, 48, 25), (tx, ty), (tx, ty + th), 3)
            pygame.draw.line(surf, (88, 65, 35), (tx - 1, ty + 2), (tx - 1, ty + th - 2), 1)
            # 나무껍질 마디
            for bi in range(ty + 4, ty + th - 3, max(4, th // 7)):
                pygame.draw.line(surf, (35, 22, 10), (tx - 2, bi), (tx + 3, bi), 1)
            # 이끼 (줄기 위 — 불규칙 녹색 패치)
            for mi in range(0, th, max(3, th // 6)):
                mw_m = random.randint(1, 3)
                ms_c = random.choice([(30, 65, 25), (38, 78, 30), (25, 55, 20)])
                pygame.draw.rect(surf, ms_c, (tx - mw_m, ty + mi, mw_m * 2 + 1, 2))
            # 판근
            for _ in range(random.randint(2, 4)):
                rdx = random.choice([-1, 1]) * random.randint(3, 8)
                pygame.draw.line(surf, (55, 38, 18),
                                 (tx, ty + th - 1), (tx + rdx, ty + th + 2), 2)
            # 수관 (5단 — 더 풍성하게)
            for ci in range(random.randint(6, 12)):
                cx_c = tx + random.randint(-tw, tw)
                cy_c = ty + random.randint(-tw, tw // 4)
                cr = random.randint(8, 20)
                g_v = 25 + random.randint(0, 40)
                cs = pygame.Surface((cr * 2 + 2, cr * 2 + 2), pygame.SRCALPHA)
                for ri in range(cr, 0, -1):
                    ra = max(1, int(75 * ri / cr))
                    pygame.draw.circle(cs, (g_v, g_v + 38, g_v - 8, ra),
                                       (cr + 1, cr + 1), ri)
                surf.blit(cs, (cx_c - cr - 1, cy_c - cr - 1))
            # 수관 하이라이트
            for _ in range(random.randint(1, 3)):
                hx = tx + random.randint(-tw // 2, tw // 2)
                hy = ty + random.randint(-tw, -tw // 3)
                hr = random.randint(3, 8)
                hs = pygame.Surface((hr * 2, hr * 2), pygame.SRCALPHA)
                pygame.draw.circle(hs, (55, 120, 45, 35), (hr, hr), hr)
                surf.blit(hs, (hx - hr, hy - hr))
            # 덩굴 (줄기에서 아래로 — HD 곡선 + 잎)
            for _ in range(random.randint(2, 5)):
                vx = tx + random.randint(-tw // 3, tw // 3)
                vy = ty + random.randint(0, th // 3)
                vl = random.randint(10, 28)
                prev = (vx, vy)
                for vi in range(1, vl):
                    nx = vx + int(4 * math.sin(vi * 0.5 + vx * 0.1))
                    ny = vy + vi
                    pygame.draw.line(surf, (30, 68, 25), prev, (nx, ny), 1)
                    prev = (nx, ny)
                    # 잎 (간헐적)
                    if vi % max(4, vl // 5) == 0:
                        side = random.choice([-1, 1])
                        lr = random.randint(2, 4)
                        pygame.draw.ellipse(surf, (40, 95, 32),
                                            (nx + side * 2, ny - 1, lr * 2, lr))
            # 기생식물/착생식물 (큰 나무에만)
            if th > 35 and random.random() < 0.4:
                ep_y = ty + random.randint(th // 4, th * 2 // 3)
                ep_side = random.choice([-1, 1])
                ep_x = tx + ep_side * random.randint(2, 4)
                for _ in range(random.randint(3, 6)):
                    el = random.randint(3, 8)
                    ea = random.uniform(-math.pi / 3, math.pi / 3) + (math.pi / 2 * ep_side)
                    ex = ep_x + int(el * math.cos(ea))
                    ey = ep_y + int(el * math.sin(ea) * 0.6)
                    pygame.draw.line(surf, (45, 95, 35), (ep_x, ep_y), (ex, ey), 1)
                    pygame.draw.circle(surf, (55, 115, 42), (ex, ey), 2)
                # 꽃 (드물게)
                if random.random() < 0.3:
                    fc = random.choice([(255, 100, 80), (255, 200, 60),
                                        (220, 80, 180), (180, 60, 255)])
                    pygame.draw.circle(surf, fc, (ep_x, ep_y - 2), 2)
                    pygame.draw.circle(surf, (255, 255, 200), (ep_x, ep_y - 2), 1)

        # ===== 야자수 (HD 키 큰 열대 나무 — 중앙 회피) =====
        detail_a = min(255, int(255 * max(0, t * 2 - 0.2)))
        if detail_a > 10:
            for _ in range(28):
                px = random.randint(15, W - 15)
                py = random.randint(H // 5, H - 40)
                if _in_center(px, py):
                    continue
                p_h = random.randint(35, 72)
                # 곡선 줄기 (HD — 그라데이션 + 마디)
                trunk_pts = [(px, py + p_h)]
                sway = random.randint(-18, 18)
                for ti in range(8):
                    frac = ti / 7.0
                    tx_t = px + int(sway * frac * frac)
                    ty_t = py + int(p_h * (1.0 - frac))
                    trunk_pts.append((tx_t, ty_t))
                if len(trunk_pts) > 2:
                    pygame.draw.lines(surf, (72, 50, 25), False, trunk_pts, 4)
                    pygame.draw.lines(surf, (98, 72, 38), False, trunk_pts, 2)
                    pygame.draw.lines(surf, (118, 92, 52), False, trunk_pts, 1)
                    # 마디 줄
                    for mi in range(1, len(trunk_pts) - 1):
                        mx_m, my_m = trunk_pts[mi]
                        pygame.draw.line(surf, (60, 40, 20),
                                         (mx_m - 2, my_m), (mx_m + 2, my_m), 1)
                # 야자 잎 (방사형 — HD 잎살)
                top_x = trunk_pts[-1][0]
                top_y = trunk_pts[-1][1]
                for li in range(random.randint(7, 11)):
                    angle = math.pi * 2 * li / 9 + random.uniform(-0.3, 0.3)
                    leaf_l = random.randint(18, 38)
                    # 베지에 곡선 잎 (중간점 포함)
                    mid_x = top_x + int(leaf_l * 0.5 * math.cos(angle))
                    mid_y = top_y + int(leaf_l * 0.3 * math.sin(angle)) - random.randint(3, 8)
                    ex = top_x + int(leaf_l * math.cos(angle))
                    ey = top_y + int(leaf_l * math.sin(angle) * 0.5) + random.randint(0, 5)
                    lc_main = random.choice([(25, 75, 20), (30, 82, 25), (22, 68, 18)])
                    lc_hl = (min(255, lc_main[0] + 20), min(255, lc_main[1] + 18),
                             min(255, lc_main[2] + 12))
                    pygame.draw.line(surf, lc_main, (top_x, top_y), (mid_x, mid_y), 2)
                    pygame.draw.line(surf, lc_main, (mid_x, mid_y), (ex, ey), 1)
                    # 잎살 (좌우 교대)
                    for si in range(5):
                        sf = (si + 1) / 6.0
                        sx_l = int(top_x + (ex - top_x) * sf)
                        sy_l = int(top_y + (ey - top_y) * sf)
                        perp = angle + math.pi / 2
                        fl = random.randint(4, 9)
                        for side in [-1, 1]:
                            fx = sx_l + int(fl * math.cos(perp) * side)
                            fy_l = sy_l + int(fl * math.sin(perp) * side * 0.5)
                            pygame.draw.line(surf, lc_hl if side > 0 else lc_main,
                                             (sx_l, sy_l), (fx, fy_l), 1)
                # 코코넛 (HD — 입체)
                for _ in range(random.randint(1, 4)):
                    cx_n = top_x + random.randint(-5, 5)
                    cy_n = top_y + random.randint(1, 6)
                    pygame.draw.circle(surf, (82, 60, 30), (cx_n, cy_n), 3)
                    pygame.draw.circle(surf, (105, 78, 42), (cx_n - 1, cy_n - 1), 2)
                    pygame.draw.circle(surf, (125, 98, 55), (cx_n - 1, cy_n - 1), 1)

        # ===== 대나무 숲 (HD 질감+바람효과+마디, 중앙 회피, 초빼곡) =====
        for _ in range(35):
            bx = random.randint(20, W - 20)
            by = random.randint(H // 4, H - 40)
            if _in_center(bx, by):
                continue
            bh = random.randint(30, 65)
            wind_dx = random.randint(-4, 4)
            pygame.draw.ellipse(surf, (0, 0, 0, 15), (bx - 3, by + bh, 6, 3))
            for si in range(bh):
                frac = si / bh
                bend = int(wind_dx * frac * frac)
                gc = (max(0, int(50 + frac * 35)),
                      max(0, min(255, int(88 + frac * 45))),
                      max(0, int(30 + frac * 28)))
                pygame.draw.line(surf, gc, (bx + bend, by + si), (bx + bend + 1, by + si), 2)
            # 하이라이트 줄 (반사)
            for si in range(0, bh, 2):
                frac = si / bh
                bend = int(wind_dx * frac * frac)
                pygame.draw.line(surf, (90, 142, 65), (bx + bend - 1, by + si), (bx + bend - 1, by + si), 1)
            # 마디
            for ni in range(3, bh, max(5, bh // 6)):
                frac = ni / bh
                bend = int(wind_dx * frac * frac)
                pygame.draw.line(surf, (40, 72, 28), (bx + bend - 2, by + ni), (bx + bend + 3, by + ni), 1)
                pygame.draw.circle(surf, (48, 82, 35), (bx + bend - 2, by + ni), 1)
                pygame.draw.circle(surf, (48, 82, 35), (bx + bend + 3, by + ni), 1)
            # 잎
            for _ in range(random.randint(5, 10)):
                lni = random.randint(1, max(1, bh // 5 - 1))
                lby = by + lni * max(5, bh // 5)
                if lby > by + bh:
                    lby = by + bh - 5
                frac = (lby - by) / bh
                lbend = int(wind_dx * frac * frac)
                ldir = random.choice([-1, 1])
                ldx = ldir * random.randint(8, 22)
                ldy = random.randint(-8, 2)
                lc = (max(0, 48 + random.randint(-8, 8)),
                      max(0, min(255, 95 + random.randint(-10, 15))),
                      max(0, 30 + random.randint(-5, 5)))
                pygame.draw.line(surf, lc, (bx + lbend, lby),
                                 (bx + lbend + ldx, lby + ldy), 1)
                pygame.draw.line(surf, lc, (bx + lbend + ldx, lby + ldy),
                                 (bx + lbend + ldx + ldir * 3, lby + ldy - 2), 1)

        # ===== 오두막/원주민 건축물 (HD — 중앙 회피, 초빼곡) =====
        for _ in range(16):
            bx = random.randint(60, W - 60)
            by = random.randint(H // 3, H * 3 // 4)
            if _in_center(bx, by):
                continue
            bw = random.randint(28, 58)
            bh = random.randint(16, 32)
            # 그림자 (소프트)
            sh_s = pygame.Surface((bw + 14, 7), pygame.SRCALPHA)
            pygame.draw.ellipse(sh_s, (0, 0, 0, 28), (0, 0, bw + 14, 7))
            surf.blit(sh_s, (bx - bw // 2 - 7, by + bh + 3))
            # 고상식 기둥 (4개)
            for col_off in [-bw // 2 + 3, -bw // 4, bw // 4, bw // 2 - 3]:
                pygame.draw.line(surf, (62, 42, 20),
                                 (bx + col_off, by + 3), (bx + col_off, by + bh + 5), 2)
                pygame.draw.line(surf, (78, 55, 28),
                                 (bx + col_off - 1, by + 4), (bx + col_off - 1, by + bh + 4), 1)
            # 바닥 (고상식 — 나무판)
            pygame.draw.rect(surf, (85, 62, 32), (bx - bw // 2 - 2, by + bh, bw + 4, 3))
            # 벽체 (대나무/짚)
            pygame.draw.rect(surf, (105, 85, 50), (bx - bw // 2, by, bw, bh))
            pygame.draw.rect(surf, (90, 72, 42), (bx - bw // 2, by, bw, bh), 1)
            # 대나무 세로줄 텍스처
            for bi in range(bx - bw // 2 + 3, bx + bw // 2, max(3, bw // 8)):
                pygame.draw.line(surf, (85, 68, 38), (bi, by + 2), (bi, by + bh - 1), 1)
            # 가로 엮기
            for ri in range(by + 3, by + bh - 2, max(4, bh // 5)):
                pygame.draw.line(surf, (95, 78, 45), (bx - bw // 2 + 2, ri), (bx + bw // 2 - 2, ri), 1)
            # 초가지붕 (삼각형 — 야자잎/짚, HD)
            rw = bw + 16
            rh = max(10, bh * 2 // 3)
            roof_pts = [(bx, by - rh), (bx - rw // 2, by + 2), (bx + rw // 2, by + 2)]
            pygame.draw.polygon(surf, (82, 75, 35), roof_pts)
            # 지붕 밝은 면 (왼쪽)
            hl_pts = [roof_pts[0], roof_pts[1], (bx, by + 1)]
            hl_s = pygame.Surface((rw + 2, rh + 4), pygame.SRCALPHA)
            hl_local = [(p[0] - bx + rw // 2 + 1, p[1] - by + rh + 2) for p in hl_pts]
            if all(0 <= p[0] <= rw + 2 and 0 <= p[1] <= rh + 4 for p in hl_local):
                pygame.draw.polygon(hl_s, (105, 95, 50, 45), hl_local)
                surf.blit(hl_s, (bx - rw // 2 - 1, by - rh - 2))
            # 지붕 줄 질감
            for ri in range(by - rh + 3, by + 1, max(2, rh // 6)):
                frac = (ri - (by - rh)) / rh
                hw = int(rw * frac // 2)
                rc_r = random.choice([(70, 65, 30), (78, 72, 35), (65, 58, 28)])
                pygame.draw.line(surf, rc_r, (bx - hw, ri), (bx + hw, ri), 1)
            # 처마 끝 매달림 (짚/잎)
            for xi in range(bx - rw // 2 + 2, bx + rw // 2 - 2, max(3, rw // 10)):
                dl = random.randint(2, 5)
                dc = random.choice([(72, 68, 32), (80, 75, 38)])
                for di in range(dl):
                    da = max(1, 180 - di * 40)
                    pygame.draw.line(surf, (*dc, da), (xi, by + 2 + di), (xi + 1, by + 2 + di), 1)
            # 문
            dw = max(5, bw // 5)
            dh = max(6, bh * 2 // 3)
            pygame.draw.rect(surf, (35, 25, 12), (bx - dw // 2, by + bh - dh, dw, dh))
            pygame.draw.rect(surf, (55, 40, 22), (bx - dw // 2, by + bh - dh, dw, dh), 1)
            # 횃불 (오두막 옆)
            if bw > 35:
                for t_side in [-1, 1]:
                    t_x = bx + t_side * (bw // 2 + 5)
                    t_y = by + bh // 2
                    pygame.draw.line(surf, (58, 40, 18), (t_x, t_y), (t_x, t_y + 8), 2)
                    pygame.draw.circle(surf, (220, 120, 30), (t_x, t_y - 1), 2)
                    pygame.draw.circle(surf, (255, 180, 50), (t_x, t_y - 1), 1)

        # ===== 풀숲/수풀 (HD 3D 다층, 중앙 회피, 초빼곡) =====
        for _ in range(90):
            bx = random.randint(3, W - 3)
            by = random.randint(H // 7, H - 5)
            if _in_center(bx, by):
                continue
            bsize = random.randint(5, 22)
            g_v = random.randint(-18, 18)
            bush_dk = (max(0, 20 + g_v), max(0, min(255, 55 + g_v)), max(0, 15 + g_v))
            bush_c = (max(0, 32 + g_v), max(0, min(255, 75 + g_v)), max(0, 22 + g_v))
            bush_c2 = (max(0, 45 + g_v), max(0, min(255, 98 + g_v)), max(0, 32 + g_v))
            bush_hl = (min(255, bush_c2[0] + 30), min(255, bush_c2[1] + 25), min(255, bush_c2[2] + 15))
            sh_s = pygame.Surface((bsize * 3, bsize), pygame.SRCALPHA)
            pygame.draw.ellipse(sh_s, (0, 0, 0, 20), (0, 0, bsize * 3, bsize))
            surf.blit(sh_s, (bx - bsize * 3 // 2, by + bsize // 2))
            for ci in range(random.randint(2, 3)):
                ox = random.randint(-bsize // 2, bsize // 2)
                oy = random.randint(0, bsize // 3)
                r = max(2, bsize - abs(ci) * 2 + random.randint(0, 2))
                pygame.draw.circle(surf, bush_dk, (bx + ox, by + oy), r)
            for ci in range(random.randint(3, 6)):
                ox = random.randint(-bsize // 2, bsize // 2)
                oy = random.randint(-bsize // 2, bsize // 3)
                r = max(2, bsize - abs(ci) + random.randint(0, 3))
                pygame.draw.circle(surf, bush_c, (bx + ox, by + oy), r)
                pygame.draw.circle(surf, bush_c2, (bx + ox - 1, by + oy - 1), max(1, r - 1))
            pygame.draw.circle(surf, bush_hl, (bx - 1, by - 2), max(1, bsize // 3))
            # 열매/꽃
            if bsize > 12 and random.random() < 0.3:
                bc = random.choice([(200, 55, 40), (160, 40, 110), (215, 155, 40), (255, 100, 70)])
                for _ in range(random.randint(2, 5)):
                    bex = bx + random.randint(-bsize // 3, bsize // 3)
                    bey = by + random.randint(-bsize // 3, bsize // 4)
                    pygame.draw.circle(surf, bc, (bex, bey), 1)

        # ===== 버섯/양치류/열매 디테일 (HD, 중앙 회피, 초빼곡) =====
        for _ in range(60):
            mx = random.randint(10, W - 10)
            my = random.randint(H // 5, H - 15)
            if _in_center(mx, my):
                continue
            mtype = random.randint(0, 3)
            if mtype == 0:
                # 큰 독버섯 (HD — 줄기+갓+점+글로우)
                mr = random.randint(5, 11)
                pygame.draw.line(surf, (185, 175, 155), (mx, my + 2), (mx, my + mr + 3), 2)
                pygame.draw.line(surf, (200, 190, 170), (mx - 1, my + 3), (mx - 1, my + mr + 2), 1)
                mc_r = 50 + random.randint(0, 70)
                pygame.draw.ellipse(surf, (185, mc_r, 28),
                                    (mx - mr, my - mr // 2, mr * 2, mr))
                pygame.draw.ellipse(surf, (200, mc_r + 20, 38),
                                    (mx - mr + 1, my - mr // 2, mr * 2 - 2, mr - 1))
                for _ in range(random.randint(3, 6)):
                    dx = random.randint(-mr + 2, mr - 2)
                    dy = random.randint(-mr // 2 + 1, mr // 2 - 1)
                    pygame.draw.circle(surf, (255, 250, 230), (mx + dx, my + dy), 1)
                # 글로우 (발광 버섯)
                if random.random() < 0.3:
                    gs = pygame.Surface((mr * 4, mr * 3), pygame.SRCALPHA)
                    pygame.draw.ellipse(gs, (150, 255, 100, 15), (0, 0, mr * 4, mr * 3))
                    surf.blit(gs, (mx - mr * 2, my - mr))
            elif mtype == 1:
                # 양치류 (HD 부채꼴)
                for fi in range(random.randint(5, 9)):
                    angle = -math.pi / 2 + (fi - 4) * 0.22
                    fl = random.randint(10, 22)
                    fx = mx + int(fl * math.cos(angle))
                    fy_f = my + int(fl * math.sin(angle))
                    lc = (30 + random.randint(0, 15), 78 + random.randint(0, 20), 25 + random.randint(0, 10))
                    pygame.draw.line(surf, lc, (mx, my), (fx, fy_f), 1)
                    for si in range(2, fl, 2):
                        sf = si / fl
                        sx = int(mx + (fx - mx) * sf)
                        sy = int(my + (fy_f - my) * sf)
                        perp = angle + math.pi / 2
                        fl_s = max(2, int(4 * (1 - sf)))
                        for side in [-1, 1]:
                            lx = sx + int(fl_s * math.cos(perp) * side)
                            ly = sy + int(fl_s * math.sin(perp) * side)
                            pygame.draw.line(surf, (42, 98, 32), (sx, sy), (lx, ly), 1)
            elif mtype == 2:
                # 열대 꽃 (밝은 점 + 꽃잎)
                fc = random.choice([(255, 95, 75), (255, 195, 45),
                                    (225, 75, 195), (255, 145, 45), (180, 55, 255)])
                pr_f = random.randint(3, 6)
                for pi in range(5):
                    ang = pi * 72 + random.randint(-10, 10)
                    dx = int(pr_f * 0.6 * math.cos(math.radians(ang)))
                    dy = int(pr_f * 0.4 * math.sin(math.radians(ang)))
                    pygame.draw.circle(surf, fc, (mx + dx, my + dy), max(1, pr_f // 2))
                pygame.draw.circle(surf, (255, 240, 130), (mx, my), max(1, pr_f // 3))
            else:
                # 나뭇잎 더미 (지면)
                for _ in range(random.randint(3, 7)):
                    lx = mx + random.randint(-5, 5)
                    ly = my + random.randint(-3, 3)
                    la = random.randint(0, 360)
                    ll = random.randint(3, 6)
                    lc = random.choice([(45, 35, 18), (55, 42, 22), (38, 58, 25), (50, 40, 20)])
                    ex = lx + int(ll * math.cos(math.radians(la)))
                    ey = ly + int(ll * 0.5 * math.sin(math.radians(la)))
                    pygame.draw.line(surf, lc, (lx, ly), (ex, ey), 1)

        # ===== 이끼 낀 바위 (HD, 중앙 회피, 초빼곡) =====
        for _ in range(32):
            rx = random.randint(15, W - 15)
            ry = random.randint(H // 5, H - 20)
            if _in_center(rx, ry):
                continue
            rw_r = random.randint(5, 18)
            rh_r = random.randint(4, 12)
            # 바위 본체
            pygame.draw.ellipse(surf, (48, 45, 38), (rx, ry, rw_r, rh_r))
            pygame.draw.ellipse(surf, (65, 62, 52), (rx + 1, ry, rw_r - 2, rh_r - 1))
            # 밝은 면 (좌상)
            pygame.draw.ellipse(surf, (82, 78, 65), (rx + 1, ry, max(2, rw_r // 2), max(2, rh_r // 2)))
            # 어두운 면 (우하)
            pygame.draw.arc(surf, (35, 32, 28), (rx, ry, rw_r, rh_r), -0.5, 1.5, 1)
            # 이끼 (상부)
            if rw_r > 6:
                pygame.draw.ellipse(surf, (38, 72, 32, 90),
                                    (rx + 1, ry + 1, rw_r - 3, max(2, rh_r // 2)))
                # 이끼 디테일
                for _ in range(random.randint(1, 3)):
                    dx = random.randint(2, max(3, rw_r - 3))
                    pygame.draw.circle(surf, (45, 82, 38), (rx + dx, ry + 2), 1)

        # ===== 토템 기둥 / 부족 장식 (HD) =====
        for _ in range(10):
            tx_t = random.randint(25, W - 25)
            ty_t = random.randint(int(H * 0.4), H - 20)
            if _in_center(tx_t, ty_t):
                continue
            totem_h = random.randint(22, 42)
            totem_w = max(4, totem_h // 5)
            # 기둥 본체
            pygame.draw.rect(surf, (72, 48, 25), (tx_t - totem_w // 2, ty_t - totem_h, totem_w, totem_h))
            pygame.draw.rect(surf, (88, 62, 32), (tx_t - totem_w // 2, ty_t - totem_h, max(1, totem_w // 3), totem_h))
            # 조각 얼굴 (2~3개 층)
            face_count = max(1, totem_h // 12)
            for fi in range(face_count):
                fy_t = ty_t - totem_h + fi * (totem_h // face_count) + 3
                fw = totem_w + 2
                # 눈
                pygame.draw.circle(surf, (200, 180, 80), (tx_t - totem_w // 4, fy_t + 2), 1)
                pygame.draw.circle(surf, (200, 180, 80), (tx_t + totem_w // 4, fy_t + 2), 1)
                # 입
                pygame.draw.line(surf, (180, 60, 30), (tx_t - totem_w // 3, fy_t + 5),
                                 (tx_t + totem_w // 3, fy_t + 5), 1)
                # 장식 돌출
                pygame.draw.rect(surf, (62, 42, 20), (tx_t - fw // 2, fy_t, fw, 2))
            # 꼭대기 장식
            pygame.draw.polygon(surf, (68, 45, 22),
                                [(tx_t - totem_w // 2 - 1, ty_t - totem_h),
                                 (tx_t, ty_t - totem_h - 5),
                                 (tx_t + totem_w // 2 + 1, ty_t - totem_h)])

        # ===== 야생동물 (새, 뱀, 원숭이 실루엣) =====
        for _ in range(22):
            ax = random.randint(10, W - 10)
            ay = random.randint(int(H * 0.15), H - 10)
            if _in_center(ax, ay):
                continue
            atype = random.randint(0, 3)
            if atype == 0:
                # 새 (나는 실루엣)
                wing_w = random.randint(5, 12)
                pygame.draw.line(surf, (25, 42, 20), (ax - wing_w, ay + 2), (ax, ay), 1)
                pygame.draw.line(surf, (25, 42, 20), (ax, ay), (ax + wing_w, ay + 2), 1)
            elif atype == 1:
                # 앵무새 (나뭇가지 위)
                bird_c = random.choice([(200, 55, 40), (40, 160, 50), (50, 100, 220), (220, 180, 30)])
                pygame.draw.circle(surf, bird_c, (ax, ay), 2)
                pygame.draw.circle(surf, (min(255, bird_c[0] + 30), min(255, bird_c[1] + 20),
                                          min(255, bird_c[2] + 20)), (ax, ay - 2), 1)
                # 꼬리
                pygame.draw.line(surf, bird_c, (ax + 1, ay + 1), (ax + 4, ay + 3), 1)
                # 부리
                pygame.draw.line(surf, (220, 180, 50), (ax - 2, ay - 2), (ax - 3, ay - 2), 1)
            elif atype == 2:
                # 뱀 (S자 곡선)
                snake_c = random.choice([(50, 120, 40), (100, 60, 30), (140, 110, 50)])
                s_pts = []
                sx_s, sy_s = ax, ay
                for si in range(8):
                    sx_s += random.randint(1, 3)
                    sy_s += int(2 * math.sin(si * 1.2))
                    s_pts.append((sx_s, sy_s))
                if len(s_pts) > 2:
                    pygame.draw.lines(surf, snake_c, False, s_pts, 1)
                    # 머리
                    pygame.draw.circle(surf, snake_c, s_pts[0], 1)
            else:
                # 원숭이 (나뭇가지 매달림)
                mk_c = (75, 50, 30)
                # 몸
                pygame.draw.ellipse(surf, mk_c, (ax - 2, ay - 3, 4, 5))
                # 머리
                pygame.draw.circle(surf, mk_c, (ax, ay - 4), 2)
                # 꼬리 (아래로 커브)
                pygame.draw.arc(surf, mk_c, (ax + 1, ay, 5, 8), -1.5, 1.5, 1)
                # 팔 (위로 — 나뭇가지 잡음)
                pygame.draw.line(surf, mk_c, (ax - 1, ay - 2), (ax - 3, ay - 6), 1)
                pygame.draw.line(surf, mk_c, (ax + 1, ay - 2), (ax + 3, ay - 6), 1)

        # ===== 지면 뿌리/덩굴망 (밀림 바닥 가득) =====
        for _ in range(40):
            rx = random.randint(5, W - 5)
            ry = random.randint(int(H * 0.3), H - 5)
            if _in_center(rx, ry):
                continue
            root_c = random.choice([(42, 30, 15), (50, 35, 18), (38, 28, 14)])
            # 뿌리 (여러 방향으로 뻗음)
            for _ in range(random.randint(2, 5)):
                ang = random.uniform(0, math.pi * 2)
                r_len = random.randint(6, 20)
                r_pts = [(rx, ry)]
                cx_r, cy_r = rx, ry
                for si in range(4):
                    cx_r += int(r_len / 4 * math.cos(ang + random.uniform(-0.5, 0.5)))
                    cy_r += int(r_len / 4 * math.sin(ang + random.uniform(-0.5, 0.5)))
                    r_pts.append((cx_r, cy_r))
                if len(r_pts) > 2:
                    pygame.draw.lines(surf, root_c, False, r_pts, 1)

        # ===== 대형 열대 잎 (몬스테라/바나나잎 느낌) =====
        for _ in range(25):
            lx = random.randint(10, W - 10)
            ly = random.randint(int(H * 0.2), H - 10)
            if _in_center(lx, ly):
                continue
            leaf_type = random.randint(0, 1)
            lc = random.choice([(28, 68, 22), (35, 80, 28), (22, 60, 18), (40, 90, 32)])
            if leaf_type == 0:
                # 넓은 타원형 잎 (바나나잎)
                l_len = random.randint(12, 28)
                l_w = max(4, l_len // 3)
                ang = random.uniform(-0.5, 0.5)
                ex_l = lx + int(l_len * math.cos(ang))
                ey_l = ly + int(l_len * math.sin(ang))
                # 잎 몸체
                leaf_s = pygame.Surface((l_len + 4, l_w * 2 + 4), pygame.SRCALPHA)
                pygame.draw.ellipse(leaf_s, (*lc, min(255, int(alpha * 0.6))),
                                    (2, 2, l_len, l_w * 2))
                # 중심맥
                pygame.draw.line(leaf_s, (lc[0] - 5, lc[1] + 10, lc[2] - 3, min(255, int(alpha * 0.7))),
                                 (2, l_w + 2), (l_len, l_w + 2), 1)
                # 측맥
                for vi in range(3, l_len - 2, max(3, l_len // 5)):
                    pygame.draw.line(leaf_s, (lc[0] - 3, lc[1] + 8, lc[2] - 2, min(255, int(alpha * 0.5))),
                                     (vi, l_w + 2), (vi + 2, 3), 1)
                    pygame.draw.line(leaf_s, (lc[0] - 3, lc[1] + 8, lc[2] - 2, min(255, int(alpha * 0.5))),
                                     (vi, l_w + 2), (vi + 2, l_w * 2 - 1), 1)
                surf.blit(leaf_s, (lx - 2, ly - l_w - 2))
            else:
                # 갈라진 잎 (몬스테라 느낌)
                l_r = random.randint(8, 16)
                leaf_s = pygame.Surface((l_r * 2 + 4, l_r * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(leaf_s, (*lc, min(255, int(alpha * 0.55))),
                                   (l_r + 2, l_r + 2), l_r)
                # 구멍/갈라짐
                for _ in range(random.randint(2, 4)):
                    hx = l_r + 2 + random.randint(-l_r // 2, l_r // 2)
                    hy = l_r + 2 + random.randint(-l_r // 2, l_r // 2)
                    hr = random.randint(2, max(2, l_r // 3))
                    pygame.draw.circle(leaf_s, (0, 0, 0, 0), (hx, hy), hr)
                # 줄기
                pygame.draw.line(leaf_s, (lc[0] - 5, lc[1] + 8, lc[2] - 3, min(255, int(alpha * 0.6))),
                                 (l_r + 2, l_r * 2 + 2), (l_r + 2, l_r + 2), 1)
                surf.blit(leaf_s, (lx - l_r - 2, ly - l_r - 2))

        # ===== 꽃 군락 (열대 꽃밭) =====
        for _ in range(18):
            fx = random.randint(10, W - 10)
            fy_c = random.randint(int(H * 0.35), H - 8)
            if _in_center(fx, fy_c):
                continue
            cluster_r = random.randint(8, 18)
            fc = random.choice([(255, 95, 75), (255, 195, 45), (225, 75, 195),
                                (255, 145, 45), (180, 55, 255), (255, 100, 100)])
            for _ in range(random.randint(4, 10)):
                dx_f = random.randint(-cluster_r, cluster_r)
                dy_f = random.randint(-cluster_r // 2, cluster_r // 2)
                fr = random.randint(1, 3)
                pygame.draw.circle(surf, (*fc, min(255, int(alpha * 0.7))),
                                   (fx + dx_f, fy_c + dy_f), fr)
                # 꽃잎 (큰 꽃)
                if fr > 1:
                    for pi in range(4):
                        pa = pi * 90 + random.randint(-15, 15)
                        ppx = fx + dx_f + int(2 * math.cos(math.radians(pa)))
                        ppy = fy_c + dy_f + int(1.5 * math.sin(math.radians(pa)))
                        pygame.draw.circle(surf, (*fc, min(255, int(alpha * 0.5))), (ppx, ppy), 1)

        # ===== 늪 이끼/부유물/수초 (물 위 가득) =====
        for _ in range(20):
            sx_m = random.randint(10, W - 10)
            sy_m = random.randint(int(H * 0.25), H - 10)
            if _in_center(sx_m, sy_m):
                continue
            # 이끼 패치
            mc_i = random.choice([(25, 58, 20), (30, 65, 25), (20, 50, 16)])
            mr_i = random.randint(5, 14)
            ms_i = pygame.Surface((mr_i * 2, mr_i), pygame.SRCALPHA)
            pygame.draw.ellipse(ms_i, (*mc_i, min(255, int(alpha * 0.4))),
                                (0, 0, mr_i * 2, mr_i))
            surf.blit(ms_i, (sx_m - mr_i, sy_m - mr_i // 2))
            # 수초 (위로 뻗는 풀)
            for _ in range(random.randint(2, 5)):
                gx = sx_m + random.randint(-mr_i, mr_i)
                gh = random.randint(5, 14)
                gc_g = random.choice([(30, 72, 25), (25, 65, 20), (35, 80, 28)])
                pygame.draw.line(surf, gc_g, (gx, sy_m), (gx + random.randint(-3, 3), sy_m - gh), 1)

        # ===== 매달린 덩굴 장식 (나무 사이) =====
        for _ in range(18):
            vx1 = random.randint(20, W // 2)
            vx2 = random.randint(W // 2, W - 20)
            vy = int(H * random.uniform(0.15, 0.5))
            if _in_center((vx1 + vx2) // 2, vy):
                continue
            v_pts = []
            for step in range(12):
                t_v = step / 11
                vx_p = int(vx1 + (vx2 - vx1) * t_v)
                sag = int(15 * math.sin(t_v * math.pi))
                v_pts.append((vx_p, vy + sag))
            if len(v_pts) > 2:
                pygame.draw.lines(surf, (30, 65, 25), False, v_pts, 1)
            # 잎 (덩굴 위)
            for step in range(1, 11, 2):
                t_v = step / 11
                vx_p = int(vx1 + (vx2 - vx1) * t_v)
                sag = int(15 * math.sin(t_v * math.pi))
                lc = random.choice([(35, 78, 28), (42, 90, 32), (30, 72, 25)])
                lr_v = random.randint(2, 4)
                pygame.draw.ellipse(surf, lc, (vx_p - lr_v, vy + sag - 1, lr_v * 2, lr_v))

        random.seed()

        # ===== 반딧불이 (지표 가까울 때만) =====
        if t > 0.5:
            firefly_a = min(255, int(180 * (t - 0.5) * 2))
            random.seed(5050)
            for _ in range(55):
                fx = random.randint(10, W - 10)
                fy_f = random.randint(H // 4, H - 20)
                if _in_center(fx, fy_f):
                    continue
                fs = pygame.Surface((8, 8), pygame.SRCALPHA)
                pygame.draw.circle(fs, (200, 255, 120, min(255, firefly_a)), (4, 4), 3)
                pygame.draw.circle(fs, (255, 255, 200, min(255, firefly_a // 2)), (4, 4), 1)
                surf.blit(fs, (fx - 4, fy_f - 4))
            random.seed()

        # ===== 안개/습기 레이어 (HD — 다층 + 색상 변화) =====
        mist_a = max(0, int(110 * (1.0 - t * 1.8) * alpha / 255))
        if mist_a > 3:
            random.seed(3030)
            for _ in range(24):
                mx = random.randint(-80, W + 80)
                my = random.randint(-40, H + 40)
                mw = random.randint(90, 280)
                mh = random.randint(22, 65)
                ms = pygame.Surface((mw, mh), pygame.SRCALPHA)
                mc = random.choice([(160, 190, 150), (140, 175, 130), (170, 200, 160)])
                for ci in range(6):
                    co = ci * 3
                    ca = max(1, int(mist_a * (1.0 - ci * 0.15)))
                    if mw - co * 2 > 4 and mh - co * 2 > 4:
                        pygame.draw.ellipse(
                            ms, (*mc, min(255, ca)),
                            (co, co, mw - co * 2, mh - co * 2))
                surf.blit(ms, (mx - mw // 2, my - mh // 2))
            random.seed()

        # ===== 구름 (열대성 적운 — HD 두꺼운 다층) =====
        cloud_a = max(0, int(190 * (1.0 - t * 2.2) * alpha / 255))
        if cloud_a > 3:
            random.seed(4040)
            for _ in range(22):
                cx_c = random.randint(-60, W + 60)
                cy_c = random.randint(-30, H + 30)
                cw_c = random.randint(90, 280)
                ch_c = random.randint(28, 75)
                cs = pygame.Surface((cw_c, ch_c), pygame.SRCALPHA)
                for ci in range(6):
                    co = ci * 3
                    ca = max(1, int(cloud_a * (1.0 - ci * 0.14)))
                    if cw_c - co * 2 > 4 and ch_c - co * 2 > 4:
                        pygame.draw.ellipse(
                            cs, (225, 230, 220, min(255, ca)),
                            (co, co, cw_c - co * 2, ch_c - co * 2))
                # 구름 하단 어두운 (비구름)
                bot_h = max(3, ch_c // 3)
                pygame.draw.ellipse(cs, (150, 162, 148, max(1, cloud_a // 3)),
                                    (5, ch_c - bot_h, cw_c - 10, bot_h))
                # 상단 밝은 (햇빛 반사)
                top_h = max(2, ch_c // 4)
                pygame.draw.ellipse(cs, (245, 248, 240, max(1, cloud_a // 4)),
                                    (8, 2, cw_c - 16, top_h))
                surf.blit(cs, (cx_c - cw_c // 2, cy_c - ch_c // 2))
            random.seed()

        # ===== 대기 오버레이 (습한 열대 공기) =====
        haze_a = max(0, int(75 * (1.0 - t * 2.5) * alpha / 255))
        if haze_a > 2:
            haze = pygame.Surface((W, H), pygame.SRCALPHA)
            haze.fill((125, 160, 115, haze_a))
            surf.blit(haze, (0, 0))

    def _draw_surface_menhera(self, surf, t, alpha=255):
        """멘헤라/아키하바라 행성 표면 — 초고퀄리티. Stage 3 멘헤라걸 테마.
        t: 0(고공) ~ 1(지표면). 더티 핑크+보라빛 아키하바라 도시 야경.
        pillar_menhera.py 매칭: 그런지 핑크, 곰인형, 반창고, 알약, 체인, 면도날."""
        W, H = surf.get_width(), surf.get_height()
        _cz_x, _cz_y = W // 2, H // 2
        _cz_hw, _cz_hh = 150, 120
        def _in_center(px, py):
            return abs(px - _cz_x) < _cz_hw and abs(py - _cz_y) < _cz_hh

        # ===== 기본 지형 — HD 1px 스무스 그라디언트 (더티핑크 + 보라 도시 야경) =====
        sky_top = (22, 8, 38)         # 깊은 남보라 밤하늘
        sky_mid = (52, 18, 58)        # 핑크빛 도시 하늘 (빛 공해)
        ground_mid = (38, 20, 42)     # 어두운 아스팔트 (핑크 틴트)
        ground_bot = (28, 14, 32)     # 가장 어두운 도로
        for y in range(H):
            fy = y / max(1, H - 1)
            if fy < 0.3:
                ft = fy / 0.3
                r = int(sky_top[0] + (sky_mid[0] - sky_top[0]) * ft)
                g = int(sky_top[1] + (sky_mid[1] - sky_top[1]) * ft)
                b = int(sky_top[2] + (sky_mid[2] - sky_top[2]) * ft)
            elif fy < 0.6:
                ft = (fy - 0.3) / 0.3
                r = int(sky_mid[0] + (ground_mid[0] - sky_mid[0]) * ft)
                g = int(sky_mid[1] + (ground_mid[1] - sky_mid[1]) * ft)
                b = int(sky_mid[2] + (ground_mid[2] - sky_mid[2]) * ft)
            else:
                ft = (fy - 0.6) / 0.4
                r = int(ground_mid[0] + (ground_bot[0] - ground_mid[0]) * ft)
                g = int(ground_mid[1] + (ground_bot[1] - ground_mid[1]) * ft)
                b = int(ground_mid[2] + (ground_bot[2] - ground_mid[2]) * ft)
            pygame.draw.line(surf, (r, g, b, alpha), (0, y), (W, y))

        # ===== 별 (100개 — 일부 하트/핑크빛) =====
        random.seed(31369)
        star_a = max(0, int(alpha * (1.0 - t * 1.5)))
        if star_a > 5:
            for _ in range(100):
                sx = random.randint(0, W)
                sy = random.randint(0, int(H * 0.35))
                if _in_center(sx, sy):
                    continue
                s_type = random.random()
                if s_type < 0.12:
                    # 하트 모양 별 (12%)
                    hs_r = random.randint(2, 4)
                    hc = random.choice([(255, 150, 200), (255, 120, 180), (255, 180, 220)])
                    h_s = pygame.Surface((hs_r * 4, hs_r * 4), pygame.SRCALPHA)
                    hcx, hcy = hs_r * 2, hs_r * 2
                    pygame.draw.circle(h_s, (*hc, min(255, star_a)),
                                       (hcx - hs_r // 2, hcy - hs_r // 3), hs_r)
                    pygame.draw.circle(h_s, (*hc, min(255, star_a)),
                                       (hcx + hs_r // 2, hcy - hs_r // 3), hs_r)
                    pygame.draw.polygon(h_s, (*hc, min(255, star_a)),
                                        [(hcx - hs_r - 1, hcy), (hcx + hs_r + 1, hcy),
                                         (hcx, hcy + hs_r + 1)])
                    # 글로우
                    pygame.draw.circle(h_s, (*hc, min(255, star_a // 4)),
                                       (hcx, hcy), hs_r * 2)
                    surf.blit(h_s, (sx - hs_r * 2, sy - hs_r * 2))
                elif s_type < 0.35:
                    # 밝은 핑크 별 (십자형)
                    sr = random.randint(1, 3)
                    sc = random.choice([(255, 200, 230), (240, 180, 220), (255, 220, 240)])
                    sa = min(255, star_a + random.randint(0, 40))
                    pygame.draw.line(surf, (*sc, sa), (sx - sr, sy), (sx + sr, sy), 1)
                    pygame.draw.line(surf, (*sc, sa), (sx, sy - sr), (sx, sy + sr), 1)
                    if sr > 1:
                        d = max(1, sr - 1)
                        sc2 = (sc[0], sc[1] - 10, sc[2] - 10)
                        pygame.draw.line(surf, (*sc2, sa // 2),
                                         (sx - d, sy - d), (sx + d, sy + d), 1)
                        pygame.draw.line(surf, (*sc2, sa // 2),
                                         (sx + d, sy - d), (sx - d, sy + d), 1)
                else:
                    # 일반 별 (점)
                    sr = 1
                    sc = random.choice([
                        (220, 200, 240), (255, 230, 250), (200, 180, 230),
                        (240, 210, 255), (180, 170, 210),
                    ])
                    sa = min(255, star_a - random.randint(0, 40))
                    if sa > 3:
                        pygame.draw.circle(surf, (*sc, sa), (sx, sy), sr)

        # ===== 초승달 (어두운 핑크 글로우 — 멘헤라 분위기) =====
        if star_a > 10:
            moon_x = int(W * 0.78)
            moon_y = int(H * 0.1)
            moon_r = max(8, W // 30)
            # 6중 핑크/보라 글로우
            for gi in range(6):
                gr = moon_r + 8 + gi * 6
                gc = (200 - gi * 12, 80 - gi * 8, 140 - gi * 8)
                ga = max(1, 25 - gi * 4)
                gs = pygame.Surface((gr * 2, gr * 2), pygame.SRCALPHA)
                pygame.draw.circle(gs, (*gc, ga), (gr, gr), gr)
                surf.blit(gs, (moon_x - gr, moon_y - gr))
            # 달 본체 (밝은 핑크/라벤더)
            pygame.draw.circle(surf, (250, 230, 245, min(255, star_a)),
                               (moon_x, moon_y), moon_r)
            # 반달 그림자 (초승달 형태)
            shadow_off = max(3, moon_r // 3)
            pygame.draw.circle(surf, (22, 8, 38, min(255, star_a)),
                               (moon_x + shadow_off, moon_y - shadow_off // 2),
                               max(4, moon_r - 2))
            # 달 테두리 빛
            pygame.draw.circle(surf, (255, 200, 230, min(255, star_a // 2)),
                               (moon_x, moon_y), moon_r + 1, 1)
        random.seed()

        random.seed(31371)

        # ===== 지형 패치 (아스팔트/보도블록/타일) =====
        patch_colors = [
            (30, 20, 40), (38, 25, 48), (28, 18, 36),
            (42, 28, 52), (35, 22, 44),
        ]
        for _ in range(90):
            px = random.randint(0, W)
            py = random.randint(0, H)
            pr = random.randint(18, 85)
            if _in_center(px, py):
                continue
            pc = patch_colors[random.randint(0, 4)]
            ps = pygame.Surface((pr * 2, pr * 2), pygame.SRCALPHA)
            pygame.draw.circle(ps, (*pc, min(255, int(alpha * 0.5))),
                               (pr, pr), pr)
            surf.blit(ps, (px - pr, py - pr))

        # ===== 미세 지면 질감 (콘크리트 균열/도로 마킹) =====
        for _ in range(300):
            tx = random.randint(0, W)
            ty = random.randint(0, H)
            tc = (random.randint(25, 55), random.randint(15, 38),
                  random.randint(30, 60))
            tr = random.randint(1, 2)
            pygame.draw.circle(surf, (*tc, min(255, int(alpha * 0.5))),
                               (tx, ty), tr)

        # ===== 원경 — 고층 빌딩 스카이라인 (2단 깊이) =====
        skyline_a = max(0, int(alpha * 0.4))
        if skyline_a > 2:
            # 1단 (가장 먼 — 흐릿한 대형 빌딩, 빼곡)
            for ci in range(18):
                cx = int(W * (0.01 + ci * 0.055 + random.uniform(-0.02, 0.02)))
                base_y = int(H * random.uniform(0.1, 0.28))
                b_h = random.randint(80, 200)
                b_w = random.randint(18, 50)
                if _in_center(cx, base_y):
                    continue
                sc = (14 + random.randint(0, 8), 8 + random.randint(0, 5),
                      20 + random.randint(0, 10))
                pygame.draw.rect(surf, (*sc, max(1, skyline_a // 2)),
                                 (cx - b_w // 2, base_y - b_h, b_w, b_h))
                # 창문 격자 (희미)
                for wy in range(base_y - b_h + 5, base_y - 3, max(4, b_h // 15)):
                    for wx in range(cx - b_w // 2 + 3, cx + b_w // 2 - 2, max(4, b_w // 6)):
                        if random.random() < 0.4:
                            wc = (140 + random.randint(0, 40), 100 + random.randint(0, 30),
                                  180 + random.randint(0, 40))
                            pygame.draw.rect(surf, (*wc, max(1, skyline_a // 3)),
                                             (wx, wy, 2, 2))

            # 2단 (가까운 — 뚜렷한 빌딩, 빼곡)
            for ci in range(22):
                cx = int(W * (0.005 + ci * 0.046 + random.uniform(-0.015, 0.015)))
                base_y = int(H * random.uniform(0.18, 0.4))
                b_h = random.randint(55, 170)
                b_w = random.randint(14, 42)
                if _in_center(cx, base_y):
                    continue
                sc = (20 + random.randint(0, 12), 12 + random.randint(0, 8),
                      28 + random.randint(0, 15))
                pygame.draw.rect(surf, (*sc, skyline_a),
                                 (cx - b_w // 2, base_y - b_h, b_w, b_h))
                # 밝은 면
                pygame.draw.rect(surf, (sc[0] + 8, sc[1] + 5, sc[2] + 8, skyline_a),
                                 (cx - b_w // 2, base_y - b_h, max(1, b_w // 4), b_h))
                # 옥상 안테나/첨탑
                if random.random() < 0.5:
                    ant_h = random.randint(8, 30)
                    pygame.draw.line(surf, (*sc, skyline_a),
                                     (cx, base_y - b_h), (cx, base_y - b_h - ant_h), 1)
                    pygame.draw.circle(surf, (255, 40, 40, min(255, skyline_a + 50)),
                                       (cx, base_y - b_h - ant_h), max(1, 2))
                    # 항공등 글로우
                    glow_s = pygame.Surface((8, 8), pygame.SRCALPHA)
                    pygame.draw.circle(glow_s, (255, 40, 40, 30), (4, 4), 4)
                    surf.blit(glow_s, (cx - 4, base_y - b_h - ant_h - 4))
                # 창문 불빛 (격자)
                for wy in range(base_y - b_h + 4, base_y - 2, max(3, b_h // 14)):
                    for wx in range(cx - b_w // 2 + 2, cx + b_w // 2 - 1, max(3, b_w // 6)):
                        if random.random() < 0.55:
                            wc = random.choice([
                                (180, 140, 220), (200, 160, 255), (160, 120, 200),
                                (220, 180, 255), (140, 100, 180), (255, 200, 240),
                            ])
                            pygame.draw.rect(surf, (*wc, min(255, skyline_a + 15)),
                                             (wx, wy, 2, 2))
                # 네온 간판 (원경 빌딩에도)
                if random.random() < 0.6:
                    ns_y = base_y - random.randint(b_h // 3, b_h * 2 // 3)
                    ns_w = min(b_w - 2, random.randint(8, 20))
                    ns_h = random.randint(3, 6)
                    nc = random.choice([
                        (255, 80, 180), (80, 200, 255), (255, 200, 50),
                        (180, 80, 255), (80, 255, 160),
                    ])
                    ns_s = pygame.Surface((ns_w + 6, ns_h + 6), pygame.SRCALPHA)
                    pygame.draw.rect(ns_s, (*nc, min(255, skyline_a + 20)),
                                     (3, 3, ns_w, ns_h))
                    pygame.draw.rect(ns_s, (*nc, max(1, skyline_a // 3)),
                                     (0, 0, ns_w + 6, ns_h + 6))
                    surf.blit(ns_s, (cx - ns_w // 2 - 3, ns_y - 3))

        # ===== 수평 네온 빛 번짐 (핑크+보라 빛 공해) =====
        for fi in range(9):
            fog_y = int(H * (0.12 + fi * 0.09))
            fog_a = max(0, int(45 * math.sin(fi * 0.9 + 0.2) * alpha / 255))
            if fog_a > 1:
                fc = random.choice([
                    (100, 40, 90), (120, 50, 110), (80, 30, 75),
                    (110, 45, 100), (130, 55, 120), (90, 35, 80),
                    (140, 60, 100), (100, 50, 85),
                ])
                fog_h = max(1, int(24 + fi * 5))
                fog_s = pygame.Surface((W, fog_h), pygame.SRCALPHA)
                fog_s.fill((*fc, fog_a))
                surf.blit(fog_s, (0, fog_y))

        # ===== 도로 (HD — 차선, 횡단보도, 맨홀, 가드레일) =====
        for ri in range(3):
            road_x = int(W * (0.18 + ri * 0.3 + random.uniform(-0.04, 0.04)))
            road_y_start = int(H * 0.2)
            road_y_end = int(H * 0.96)
            road_w = random.randint(16, 26)
            r_pts = []
            ry = road_y_start
            while ry < road_y_end:
                rx = road_x + int(math.sin(ry * 0.013 + ri * 2.5) * 18)
                r_pts.append((rx, ry))
                ry += 2
            # 아스팔트
            for px, py in r_pts:
                if _in_center(px, py):
                    continue
                pygame.draw.line(surf, (25, 16, 32, alpha),
                                 (px - road_w // 2, py), (px + road_w // 2, py), 1)
            # 도로 경계선 (흰색)
            for px, py in r_pts[::3]:
                if not _in_center(px, py):
                    pygame.draw.circle(surf, (70, 65, 80, min(255, int(alpha * 0.4))),
                                       (px - road_w // 2, py), 1)
                    pygame.draw.circle(surf, (70, 65, 80, min(255, int(alpha * 0.4))),
                                       (px + road_w // 2, py), 1)
            # 중앙선 (노란 점선)
            for i in range(0, len(r_pts), 10):
                if i + 3 < len(r_pts):
                    px, py = r_pts[i]
                    if not _in_center(px, py):
                        pygame.draw.line(surf, (190, 170, 50, min(255, int(alpha * 0.5))),
                                         (px, py), (px, py + 5), 1)
            # 횡단보도 (도로 위 흰 줄무늬)
            for i in range(0, len(r_pts), max(1, len(r_pts) // 3)):
                px, py = r_pts[i]
                if _in_center(px, py):
                    continue
                for ci in range(-road_w // 2 + 2, road_w // 2 - 1, 4):
                    pygame.draw.rect(surf, (80, 75, 90, min(255, int(alpha * 0.4))),
                                     (px + ci, py - 1, 3, 3))
            # 맨홀 (일부 위치)
            for i in range(0, len(r_pts), max(1, len(r_pts) // 4)):
                px, py = r_pts[i]
                if not _in_center(px, py) and random.random() < 0.5:
                    mr = max(2, road_w // 6)
                    pygame.draw.circle(surf, (32, 22, 38, alpha), (px, py), mr)
                    pygame.draw.circle(surf, (40, 28, 45, alpha), (px, py), mr, 1)
                    pygame.draw.line(surf, (38, 26, 42, alpha),
                                     (px - mr + 1, py), (px + mr - 1, py), 1)
            # 웅덩이 네온 반사
            for i in range(0, len(r_pts), max(1, len(r_pts) // 6)):
                px, py = r_pts[i]
                if _in_center(px, py):
                    continue
                pw = random.randint(5, road_w - 5)
                pc = random.choice([
                    (120, 60, 180), (140, 70, 200), (100, 50, 160),
                    (180, 80, 220), (80, 140, 200),
                ])
                ps = pygame.Surface((pw, 4), pygame.SRCALPHA)
                ps.fill((*pc, min(255, int(alpha * 0.2))))
                surf.blit(ps, (px - pw // 2, py - 1))
            # 가드레일 (도로 한쪽)
            if ri == 0:
                for i in range(0, len(r_pts), 4):
                    px, py = r_pts[i]
                    if not _in_center(px, py):
                        pygame.draw.line(surf, (55, 50, 62, alpha),
                                         (px - road_w // 2 - 3, py),
                                         (px - road_w // 2 - 3, py + 3), 1)

        # ===== 중경 건물 — 아키하바라 상가/빌딩 (초고퀄리티, 빼곡) =====
        # 일본어 간판 텍스트 패턴 (카타카나/한자 느낌의 픽셀 블록)
        jp_signs = [
            # 각 항목: [(dx,dy,w,h), ...] 로 구성된 픽셀 글리프
            [(0,0,1,5),(1,0,3,1),(1,2,3,1),(3,0,1,5)],   # ア
            [(0,0,3,1),(1,1,1,4),(0,2,3,1)],               # エ
            [(0,0,1,5),(1,2,2,1),(3,0,1,5)],               # ド
            [(0,0,4,1),(2,0,1,5),(0,4,4,1)],               # ナ
            [(0,0,1,5),(0,0,4,1),(0,4,4,1),(3,0,1,5)],     # 口
            [(0,0,4,1),(0,0,1,5),(2,0,1,5),(0,2,4,1)],     # 目
            [(0,0,1,5),(1,0,3,1),(1,4,3,1)],               # コ
            [(0,0,4,1),(2,1,1,4),(0,2,3,1)],               # カ
            [(0,2,4,1),(2,0,1,5)],                          # 十
            [(0,0,4,1),(0,0,1,3),(0,2,4,1),(3,2,1,3),(0,4,4,1)],  # 電
        ]
        for bi in range(20):
            bx = int(W * (0.01 + bi * 0.05 + random.uniform(-0.012, 0.012)))
            by = int(H * random.uniform(0.28, 0.86))
            if _in_center(bx, by):
                continue
            b_w = random.randint(22, 55)
            b_h = random.randint(48, 120)
            wall_c = random.choice([
                (55, 35, 65), (65, 40, 72), (48, 30, 55),
                (72, 45, 80), (58, 38, 68), (62, 38, 70),
            ])
            # 그림자
            shadow_s = pygame.Surface((b_w + 6, 6), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_s, (0, 0, 0, min(255, int(alpha * 0.35))),
                                (0, 0, b_w + 6, 6))
            surf.blit(shadow_s, (bx - b_w // 2 - 3, by - 1))
            # 벽체 (메인)
            pygame.draw.rect(surf, (*wall_c, alpha),
                             (bx - b_w // 2, by - b_h, b_w, b_h))
            # 벽 텍스처 (수평 타일 줄)
            for ty in range(by - b_h + 3, by - 1, max(3, b_h // 16)):
                pygame.draw.line(surf, (wall_c[0] - 4, wall_c[1] - 3, wall_c[2] - 3, alpha),
                                 (bx - b_w // 2, ty), (bx + b_w // 2, ty), 1)
            # 밝은 면 (좌측)
            pygame.draw.rect(surf, (wall_c[0] + 14, wall_c[1] + 9, wall_c[2] + 11, alpha),
                             (bx - b_w // 2, by - b_h, max(2, b_w // 5), b_h))
            # 어두운 면 (우측)
            pygame.draw.rect(surf, (wall_c[0] - 6, wall_c[1] - 4, wall_c[2] - 5, alpha),
                             (bx + b_w // 2 - max(2, b_w // 6), by - b_h,
                              max(2, b_w // 6), b_h))
            # 옥상 (두께 있는 파라펫)
            pygame.draw.rect(surf, (wall_c[0] - 10, wall_c[1] - 7, wall_c[2] - 8, alpha),
                             (bx - b_w // 2 - 1, by - b_h - 3, b_w + 2, 4))
            pygame.draw.line(surf, (wall_c[0] + 5, wall_c[1] + 3, wall_c[2] + 4, alpha),
                             (bx - b_w // 2 - 1, by - b_h - 3),
                             (bx + b_w // 2 + 1, by - b_h - 3), 1)
            # 옥상 장비 (에어컨 실외기 + 급수탱크 + 안테나)
            for _ in range(random.randint(2, 4)):
                eqx = bx + random.randint(-b_w // 3, b_w // 3)
                eq_type = random.randint(0, 2)
                if eq_type == 0:
                    # 에어컨 실외기
                    pygame.draw.rect(surf, (48, 45, 52, alpha),
                                     (eqx - 3, by - b_h - 6, 7, 4))
                    pygame.draw.rect(surf, (55, 52, 58, alpha),
                                     (eqx - 2, by - b_h - 5, 5, 2))
                elif eq_type == 1:
                    # 급수탱크
                    pygame.draw.rect(surf, (42, 40, 48, alpha),
                                     (eqx - 2, by - b_h - 9, 5, 7))
                    pygame.draw.line(surf, (50, 48, 55, alpha),
                                     (eqx - 2, by - b_h - 9),
                                     (eqx + 3, by - b_h - 9), 1)
                else:
                    # 안테나
                    pygame.draw.line(surf, (50, 48, 55, alpha),
                                     (eqx, by - b_h - 3), (eqx, by - b_h - 12), 1)

            # ===== 네온 간판 — 일본어 간판 + 다중 레이어 글로우 =====
            sign_count = random.randint(3, 6)
            for si in range(sign_count):
                is_vertical = random.random() < 0.35  # 35% 세로 간판
                neon_c = random.choice([
                    (255, 80, 180), (80, 200, 255), (255, 200, 50),
                    (180, 80, 255), (80, 255, 160), (255, 100, 100),
                    (255, 150, 50), (100, 255, 255), (255, 60, 120),
                    (120, 255, 200), (255, 180, 80), (200, 100, 255),
                ])
                if is_vertical:
                    # ===== 세로 네온 간판 (아키하바라 특유) =====
                    v_w = random.randint(6, 10)
                    v_h = random.randint(20, max(22, b_h * 2 // 3))
                    side = random.choice([-1, 1])
                    vx = bx + side * (b_w // 2 + random.randint(0, 3))
                    vy = by - b_h + random.randint(3, max(4, b_h - v_h - 3))
                    # 간판 배경
                    sign_bg = (20 + random.randint(0, 10), 8 + random.randint(0, 5),
                               25 + random.randint(0, 10))
                    pygame.draw.rect(surf, (*sign_bg, alpha), (vx, vy, v_w, v_h))
                    # 테두리
                    pygame.draw.rect(surf, (*neon_c, min(255, int(alpha * 0.8))),
                                     (vx, vy, v_w, v_h), 1)
                    # 세로 일본어 글리프 (위→아래)
                    char_count = max(1, v_h // 8)
                    for ci in range(char_count):
                        cy_t = vy + 2 + ci * max(6, (v_h - 4) // char_count)
                        if cy_t + 5 > vy + v_h - 1:
                            break
                        glyph = random.choice(jp_signs)
                        gx_off = vx + (v_w - 4) // 2
                        for dx, dy, dw, dh in glyph:
                            pygame.draw.rect(surf, (*neon_c, alpha),
                                             (gx_off + dx, cy_t + dy, dw, dh))
                    # 3중 글로우
                    for gi in range(3):
                        gw = v_w + 4 + gi * 4
                        gh = v_h + 4 + gi * 4
                        ga = max(1, 40 - gi * 12)
                        gs = pygame.Surface((gw, gh), pygame.SRCALPHA)
                        pygame.draw.rect(gs, (*neon_c, ga), (0, 0, gw, gh))
                        surf.blit(gs, (vx - 2 - gi * 2, vy - 2 - gi * 2))
                else:
                    # ===== 가로 네온 간판 (일본어 텍스트 포함) =====
                    sy = by - b_h + random.randint(5, max(6, b_h - 12))
                    sw = random.randint(max(5, b_w // 2), b_w - 3)
                    sh = random.randint(6, 14)
                    sx = bx - sw // 2 + random.randint(-2, 2)
                    # 간판 배경
                    sign_bg = (25 + random.randint(0, 10), 10 + random.randint(0, 5),
                               30 + random.randint(0, 10))
                    pygame.draw.rect(surf, (*sign_bg, alpha), (sx, sy, sw, sh))
                    # 간판 테두리
                    pygame.draw.rect(surf, (*neon_c, min(255, int(alpha * 0.8))),
                                     (sx, sy, sw, sh), 1)
                    # 일본어 글리프 텍스트 (가로 배열)
                    char_count = max(1, sw // 7)
                    tx_s = sx + 2
                    text_y_base = sy + max(1, (sh - 5) // 2)
                    for ci in range(char_count):
                        if tx_s + 5 > sx + sw - 1:
                            break
                        glyph = random.choice(jp_signs)
                        for dx, dy, dw, dh in glyph:
                            pygame.draw.rect(surf, (*neon_c, alpha),
                                             (tx_s + dx, text_y_base + dy, dw, dh))
                        tx_s += random.randint(5, 7)
                    # 3중 글로우 (내→외)
                    for gi in range(3):
                        gw = sw + 4 + gi * 4
                        gh = sh + 4 + gi * 4
                        ga = max(1, 38 - gi * 11)
                        gs = pygame.Surface((gw, gh), pygame.SRCALPHA)
                        pygame.draw.rect(gs, (*neon_c, ga), (0, 0, gw, gh))
                        surf.blit(gs, (sx - 2 - gi * 2, sy - 2 - gi * 2))

            # 창문 (HD — 커튼/블라인드 다양화)
            for wy in range(by - b_h + 4, by - 3, max(4, b_h // 12)):
                for wx in range(bx - b_w // 2 + 3, bx + b_w // 2 - 3, max(4, b_w // 7)):
                    ww, wh = max(2, b_w // 11), max(3, b_h // 15)
                    if random.random() < 0.55:
                        wc = random.choice([
                            (160, 130, 200), (180, 150, 220), (140, 110, 180),
                            (200, 170, 240), (120, 90, 160), (220, 190, 255),
                        ])
                        pygame.draw.rect(surf, (*wc, min(255, int(alpha * 0.7))),
                                         (wx, wy, ww, wh))
                        # 창틀
                        pygame.draw.rect(surf, (wall_c[0] + 5, wall_c[1] + 3,
                                                wall_c[2] + 4, alpha),
                                         (wx, wy, ww, wh), 1)
                    else:
                        # 어두운 창
                        pygame.draw.rect(surf, (20, 12, 25, min(255, int(alpha * 0.6))),
                                         (wx, wy, ww, wh))

            # 1층 상점 (HD — 캐노피 + 쇼윈도 + 간판)
            shop_h = max(10, b_h // 5)
            # 차양/캐노피
            canopy_c = random.choice([
                (180, 50, 100), (50, 100, 180), (180, 120, 50),
                (100, 50, 150), (50, 150, 100),
            ])
            pygame.draw.polygon(surf, (*canopy_c, min(255, int(alpha * 0.8))),
                                [(bx - b_w // 2 - 2, by - shop_h),
                                 (bx + b_w // 2 + 2, by - shop_h),
                                 (bx + b_w // 2 + 5, by - shop_h + 4),
                                 (bx - b_w // 2 - 5, by - shop_h + 4)])
            # 줄무늬
            for stripe_x in range(bx - b_w // 2, bx + b_w // 2, max(3, b_w // 6)):
                pygame.draw.line(surf, (canopy_c[0] - 20, canopy_c[1] - 15,
                                        canopy_c[2] - 10, min(255, int(alpha * 0.5))),
                                 (stripe_x, by - shop_h),
                                 (stripe_x + 2, by - shop_h + 4), 1)
            # 쇼윈도 (밝은 빛)
            shop_c = random.choice([
                (200, 130, 230), (180, 110, 210), (220, 150, 250),
                (160, 100, 200),
            ])
            pygame.draw.rect(surf, (*shop_c, min(255, int(alpha * 0.55))),
                             (bx - b_w // 2 + 1, by - shop_h + 5, b_w - 2, shop_h - 6))
            # 문
            door_w = max(5, b_w // 5)
            door_h = max(7, shop_h - 6)
            pygame.draw.rect(surf, (50, 35, 58, alpha),
                             (bx - door_w // 2, by - door_h, door_w, door_h))
            pygame.draw.line(surf, (70, 55, 78, alpha),
                             (bx, by - door_h), (bx, by), 1)

        # ===== 독립 네온사인/광고판 (빌딩 사이사이 추가) =====
        for ni in range(14):
            nx = random.randint(10, W - 10)
            ny = int(H * random.uniform(0.25, 0.75))
            if _in_center(nx, ny):
                continue
            n_type = random.randint(0, 2)
            neon_c = random.choice([
                (255, 80, 180), (80, 220, 255), (255, 200, 50),
                (200, 80, 255), (80, 255, 160), (255, 60, 100),
                (100, 255, 255), (255, 140, 60),
            ])
            if n_type == 0:
                # 독립 세로 네온 기둥
                nw = random.randint(5, 8)
                nh = random.randint(18, 40)
                pygame.draw.rect(surf, (20, 10, 25, alpha), (nx, ny, nw, nh))
                pygame.draw.rect(surf, (*neon_c, min(255, int(alpha * 0.85))),
                                 (nx, ny, nw, nh), 1)
                # 세로 글리프
                char_c = max(1, nh // 8)
                for ci in range(char_c):
                    cy_n = ny + 2 + ci * max(6, (nh - 4) // char_c)
                    if cy_n + 5 > ny + nh - 1:
                        break
                    glyph = random.choice(jp_signs)
                    for dx, dy, dw, dh in glyph:
                        pygame.draw.rect(surf, (*neon_c, alpha),
                                         (nx + (nw - 4) // 2 + dx, cy_n + dy, dw, dh))
                # 글로우
                for gi in range(3):
                    gs = pygame.Surface((nw + 6 + gi * 4, nh + 6 + gi * 4), pygame.SRCALPHA)
                    pygame.draw.rect(gs, (*neon_c, max(1, 35 - gi * 10)),
                                     (0, 0, nw + 6 + gi * 4, nh + 6 + gi * 4))
                    surf.blit(gs, (nx - 3 - gi * 2, ny - 3 - gi * 2))
            elif n_type == 1:
                # 대형 가로 광고판 (일본어)
                nw = random.randint(18, 40)
                nh = random.randint(8, 14)
                pygame.draw.rect(surf, (22, 12, 28, alpha), (nx - nw // 2, ny, nw, nh))
                pygame.draw.rect(surf, (*neon_c, min(255, int(alpha * 0.9))),
                                 (nx - nw // 2, ny, nw, nh), 1)
                # 가로 글리프
                tx = nx - nw // 2 + 2
                ty = ny + max(1, (nh - 5) // 2)
                for ci in range(max(1, nw // 7)):
                    if tx + 5 > nx + nw // 2 - 1:
                        break
                    glyph = random.choice(jp_signs)
                    for dx, dy, dw, dh in glyph:
                        pygame.draw.rect(surf, (*neon_c, alpha),
                                         (tx + dx, ty + dy, dw, dh))
                    tx += random.randint(5, 7)
                # 글로우
                for gi in range(3):
                    gs = pygame.Surface((nw + 6 + gi * 4, nh + 6 + gi * 4), pygame.SRCALPHA)
                    pygame.draw.rect(gs, (*neon_c, max(1, 32 - gi * 9)),
                                     (0, 0, nw + 6 + gi * 4, nh + 6 + gi * 4))
                    surf.blit(gs, (nx - nw // 2 - 3 - gi * 2, ny - 3 - gi * 2))
            else:
                # 화살표/아이콘 네온 (화살표 형태)
                arr_w = random.randint(8, 15)
                arr_h = random.randint(6, 10)
                pts = [(nx, ny), (nx + arr_w, ny + arr_h // 2),
                       (nx, ny + arr_h)]
                pygame.draw.polygon(surf, (*neon_c, min(255, int(alpha * 0.8))), pts)
                pygame.draw.polygon(surf, (*neon_c, min(255, int(alpha * 0.5))), pts, 1)
                gs = pygame.Surface((arr_w + 10, arr_h + 10), pygame.SRCALPHA)
                pygame.draw.ellipse(gs, (*neon_c, 20), (0, 0, arr_w + 10, arr_h + 10))
                surf.blit(gs, (nx - 5, ny - 5))

        # ===== 자판기 (HD — 다층 디테일) =====
        for vi in range(12):
            vx = random.randint(12, W - 12)
            vy = random.randint(int(H * 0.46), H - 6)
            if _in_center(vx, vy):
                continue
            vm_w = random.randint(7, 11)
            vm_h = random.randint(14, 22)
            vm_c = random.choice([
                (200, 50, 50), (50, 50, 200), (50, 180, 50),
                (200, 200, 50), (180, 50, 180), (50, 150, 200),
            ])
            # 본체
            pygame.draw.rect(surf, (*vm_c, alpha),
                             (vx - vm_w // 2, vy - vm_h, vm_w, vm_h))
            # 테두리
            pygame.draw.rect(surf, (vm_c[0] - 30, vm_c[1] - 30, vm_c[2] - 30, alpha),
                             (vx - vm_w // 2, vy - vm_h, vm_w, vm_h), 1)
            # 진열부 (상단 2/3)
            dh = vm_h * 2 // 3
            pygame.draw.rect(surf, (225, 235, 245, min(255, int(alpha * 0.85))),
                             (vx - vm_w // 2 + 1, vy - vm_h + 1, vm_w - 2, dh))
            # 음료 캔 격자
            for row in range(max(1, dh // 4)):
                for col in range(max(1, (vm_w - 2) // 3)):
                    can_x = vx - vm_w // 2 + 2 + col * 3
                    can_y = vy - vm_h + 2 + row * 4
                    can_c = (random.randint(80, 255), random.randint(40, 220),
                             random.randint(40, 220))
                    pygame.draw.rect(surf, (*can_c, alpha), (can_x, can_y, 2, 3))
                    # 캔 하이라이트
                    pygame.draw.line(surf, (min(255, can_c[0] + 40),
                                            min(255, can_c[1] + 40),
                                            min(255, can_c[2] + 40), alpha),
                                     (can_x, can_y), (can_x, can_y + 1), 1)
            # 하단 (코인슬롯 + 배출구)
            pygame.draw.rect(surf, (vm_c[0] - 15, vm_c[1] - 15, vm_c[2] - 15, alpha),
                             (vx - vm_w // 2 + 1, vy - vm_h + dh + 1,
                              vm_w - 2, vm_h - dh - 2))
            # 배출구
            pygame.draw.rect(surf, (30, 25, 35, alpha),
                             (vx - vm_w // 4, vy - 4, vm_w // 2, 3))
            # 글로우 (3중)
            for gi in range(3):
                gw = vm_w + 4 + gi * 4
                gh = vm_h + 2 + gi * 3
                gs = pygame.Surface((gw, gh), pygame.SRCALPHA)
                pygame.draw.rect(gs, (200, 220, 255, max(1, 22 - gi * 7)),
                                 (0, 0, gw, gh))
                surf.blit(gs, (vx - gw // 2, vy - vm_h - 1 - gi))

        # ===== 전광판/대형 LED 스크린 (HD — 다중 글로우) =====
        for si in range(5):
            sx = int(W * (0.08 + si * 0.18 + random.uniform(-0.03, 0.03)))
            sy = int(H * random.uniform(0.18, 0.52))
            if _in_center(sx, sy):
                continue
            sc_w = random.randint(22, 45)
            sc_h = random.randint(16, 30)
            # 스크린 테두리 (메탈릭)
            pygame.draw.rect(surf, (60, 58, 68, alpha),
                             (sx - sc_w // 2 - 2, sy - sc_h // 2 - 2,
                              sc_w + 4, sc_h + 4))
            # 스크린 배경
            pygame.draw.rect(surf, (8, 4, 12, alpha),
                             (sx - sc_w // 2, sy - sc_h // 2, sc_w, sc_h))
            # 컬러 콘텐츠 (블록 패턴 — 더 선명)
            block_size = max(2, sc_w // 10)
            for by_s in range(sc_h - 2):
                for bx_s in range(0, sc_w - 2, block_size):
                    bc = random.choice([
                        (220 + random.randint(0, 35), random.randint(40, 160),
                         random.randint(80, 255)),
                        (random.randint(40, 160), random.randint(80, 255),
                         220 + random.randint(0, 35)),
                        (random.randint(80, 255), 220 + random.randint(0, 35),
                         random.randint(40, 160)),
                    ])
                    ba = min(255, int(alpha * random.uniform(0.5, 0.9)))
                    pygame.draw.rect(surf, (*bc, ba),
                                     (sx - sc_w // 2 + 1 + bx_s,
                                      sy - sc_h // 2 + 1 + by_s,
                                      block_size, 1))
            # 스캔라인 효과
            for sl_y in range(sy - sc_h // 2, sy + sc_h // 2, 2):
                pygame.draw.line(surf, (0, 0, 0, 15),
                                 (sx - sc_w // 2, sl_y), (sx + sc_w // 2, sl_y), 1)
            # 다중 글로우
            gc = random.choice([
                (180, 80, 220), (80, 150, 255), (220, 120, 180),
                (100, 200, 255), (255, 100, 200),
            ])
            for gi in range(4):
                gw = sc_w + 10 + gi * 8
                gh = sc_h + 8 + gi * 6
                gs = pygame.Surface((gw, gh), pygame.SRCALPHA)
                pygame.draw.ellipse(gs, (*gc, max(1, 22 - gi * 5)),
                                    (0, 0, gw, gh))
                surf.blit(gs, (sx - gw // 2, sy - gh // 2))

        # ===== 가로등 (HD — 다중 글로우 + 빛 원뿔) =====
        for li in range(12):
            lx = int(W * (0.05 + li * 0.08 + random.uniform(-0.015, 0.015)))
            ly = int(H * random.uniform(0.4, 0.92))
            if _in_center(lx, ly):
                continue
            lamp_h = random.randint(28, 52)
            # 기둥
            pygame.draw.line(surf, (62, 57, 72, alpha),
                             (lx, ly), (lx, ly - lamp_h), 2)
            pygame.draw.line(surf, (78, 72, 88, alpha),
                             (lx - 1, ly), (lx - 1, ly - lamp_h), 1)
            # 등부
            lamp_w = max(4, random.randint(5, 8))
            lamp_bh = max(3, random.randint(4, 6))
            pygame.draw.rect(surf, (72, 68, 82, alpha),
                             (lx - lamp_w // 2, ly - lamp_h - lamp_bh,
                              lamp_w, lamp_bh))
            # 빛 원뿔 (아래로)
            cone_s = pygame.Surface((lamp_w * 4, lamp_h // 2), pygame.SRCALPHA)
            gc = random.choice([
                (200, 140, 255), (180, 120, 240), (220, 160, 255),
            ])
            pygame.draw.polygon(cone_s, (*gc, 15),
                                [(lamp_w * 2 - lamp_w // 2, 0),
                                 (lamp_w * 2 + lamp_w // 2, 0),
                                 (lamp_w * 4, lamp_h // 2),
                                 (0, lamp_h // 2)])
            surf.blit(cone_s, (lx - lamp_w * 2, ly - lamp_h))
            # 글로우 (4중)
            glow_r = random.randint(8, 14)
            glow_s = pygame.Surface((glow_r * 5, glow_r * 5), pygame.SRCALPHA)
            for gi in range(5):
                gr = glow_r * (5 - gi) // 3
                ga = 18 + gi * 12
                pygame.draw.circle(glow_s, (*gc, min(255, ga)),
                                   (glow_r * 5 // 2, glow_r * 5 // 2), gr)
            pygame.draw.circle(glow_s, (245, 235, 255, min(255, int(alpha * 0.85))),
                               (glow_r * 5 // 2, glow_r * 5 // 2), max(2, glow_r // 4))
            surf.blit(glow_s, (lx - glow_r * 5 // 2, ly - lamp_h - glow_r * 5 // 2 - 2))

        # ===== 전선/전깃줄 (HD — 다중 라인 + 참새) =====
        for wi in range(7):
            wx1 = random.randint(5, W // 2)
            wx2 = random.randint(W // 2, W - 5)
            wy = int(H * random.uniform(0.22, 0.52))
            if _in_center((wx1 + wx2) // 2, wy):
                continue
            for offset in range(random.randint(2, 4)):
                wire_pts = []
                for step in range(14):
                    t_w = step / 13
                    wx = int(wx1 + (wx2 - wx1) * t_w)
                    sag = int(12 * math.sin(t_w * math.pi)) + offset * 3
                    wire_pts.append((wx, wy + sag))
                if len(wire_pts) > 2:
                    pygame.draw.lines(surf, (28, 23, 36, min(255, int(alpha * 0.55))),
                                      False, wire_pts, 1)

        # ===== 아케이드/게임센터 (HD — 네온 아치 입구) =====
        for ai in range(5):
            ax = int(W * (0.06 + ai * 0.19 + random.uniform(-0.04, 0.04)))
            ay = int(H * random.uniform(0.5, 0.86))
            if _in_center(ax, ay):
                continue
            aw = random.randint(20, 35)
            ah = random.randint(28, 50)
            # 건물
            pygame.draw.rect(surf, (48, 28, 55, alpha),
                             (ax - aw // 2, ay - ah, aw, ah))
            pygame.draw.rect(surf, (55, 32, 62, alpha),
                             (ax - aw // 2, ay - ah, max(2, aw // 5), ah))
            # 대형 네온 간판 (아치형)
            sign_h = max(7, ah // 4)
            neon_c = random.choice([
                (255, 50, 150), (50, 200, 255), (255, 200, 0),
            ])
            pygame.draw.rect(surf, (*neon_c, alpha),
                             (ax - aw // 2 - 2, ay - ah - sign_h, aw + 4, sign_h))
            # 네온 테두리
            pygame.draw.rect(surf, (min(255, neon_c[0] + 30), min(255, neon_c[1] + 30),
                                    min(255, neon_c[2] + 30), alpha),
                             (ax - aw // 2 - 2, ay - ah - sign_h, aw + 4, sign_h), 1)
            # 글로우 (4중)
            for gi in range(4):
                gw = aw + 8 + gi * 6
                gh = sign_h + 6 + gi * 4
                gs = pygame.Surface((gw, gh), pygame.SRCALPHA)
                pygame.draw.rect(gs, (*neon_c, max(1, 30 - gi * 7)), (0, 0, gw, gh))
                surf.blit(gs, (ax - gw // 2, ay - ah - sign_h - 3 - gi * 2))
            # 입구 (밝은 내부 빛)
            entrance_h = max(8, ah // 4)
            entrance_s = pygame.Surface((aw // 2 + 4, entrance_h + 4), pygame.SRCALPHA)
            entrance_s.fill((200, 170, 240, min(255, int(alpha * 0.5))))
            surf.blit(entrance_s, (ax - aw // 4 - 2, ay - entrance_h - 2))

        # ===== 인물 실루엣 (HD — 다양한 포즈/의상, 붐비는 거리) =====
        for pi in range(30):
            px = random.randint(8, W - 8)
            py = random.randint(int(H * 0.52), H - 4)
            if _in_center(px, py):
                continue
            p_h = random.randint(9, 18)
            p_w = max(3, p_h // 3)
            p_c = (22 + random.randint(0, 18), 14 + random.randint(0, 10),
                   28 + random.randint(0, 18))
            # 몸통
            pygame.draw.ellipse(surf, (*p_c, min(255, int(alpha * 0.55))),
                                (px - p_w // 2, py - p_h // 3, p_w, p_h * 2 // 3))
            # 머리
            head_r = max(2, p_w // 2 + 1)
            pygame.draw.circle(surf, (*p_c, min(255, int(alpha * 0.55))),
                               (px, py - p_h // 2 - head_r + 2), head_r)
            # 다리
            pygame.draw.line(surf, (*p_c, min(255, int(alpha * 0.45))),
                             (px - 1, py + p_h // 4), (px - 2, py + p_h // 2), 1)
            pygame.draw.line(surf, (*p_c, min(255, int(alpha * 0.45))),
                             (px + 1, py + p_h // 4), (px + 2, py + p_h // 2), 1)
            # 밝은 머리카락/의상 (30%)
            if random.random() < 0.35:
                hair_c = random.choice([
                    (220, 100, 180), (100, 180, 255), (255, 200, 100),
                    (180, 80, 255), (255, 120, 120), (100, 255, 200),
                ])
                pygame.draw.circle(surf, (*hair_c, min(255, int(alpha * 0.45))),
                                   (px, py - p_h // 2 - head_r + 2), head_r)

        # ===== 도시 소품 (HD — 볼라드, 우체통, 자전거) =====
        for di in range(22):
            dx = random.randint(8, W - 8)
            dy = random.randint(int(H * 0.52), H - 4)
            if _in_center(dx, dy):
                continue
            dtype = random.randint(0, 4)
            if dtype == 0:
                # 교통표지판 (HD)
                pole_h = random.randint(12, 22)
                pygame.draw.line(surf, (62, 60, 68, alpha),
                                 (dx, dy), (dx, dy - pole_h), 1)
                sign_type = random.randint(0, 1)
                if sign_type == 0:
                    sr = max(2, random.randint(3, 5))
                    sc = random.choice([(50, 50, 200), (200, 50, 50)])
                    pygame.draw.circle(surf, (*sc, alpha), (dx, dy - pole_h - sr), sr)
                    pygame.draw.circle(surf, (sc[0] + 30, sc[1] + 30, sc[2] + 30, alpha),
                                       (dx, dy - pole_h - sr), max(1, sr - 1), 1)
                else:
                    sw, sh = max(4, random.randint(5, 8)), max(3, random.randint(4, 6))
                    sc = random.choice([(50, 100, 200), (200, 180, 50)])
                    pygame.draw.rect(surf, (*sc, alpha),
                                     (dx - sw // 2, dy - pole_h - sh, sw, sh))
            elif dtype == 1:
                # 우체통 (일본식 빨간)
                bin_w = max(4, random.randint(4, 7))
                bin_h = max(5, random.randint(7, 12))
                pygame.draw.rect(surf, (180, 40, 40, alpha),
                                 (dx - bin_w // 2, dy - bin_h, bin_w, bin_h))
                pygame.draw.ellipse(surf, (200, 50, 50, alpha),
                                    (dx - bin_w // 2 - 1, dy - bin_h - 2, bin_w + 2, 4))
            elif dtype == 2:
                # 전봇대 (HD)
                pole_h = random.randint(32, 55)
                pygame.draw.line(surf, (52, 48, 58, alpha),
                                 (dx, dy), (dx, dy - pole_h), 2)
                pygame.draw.line(surf, (62, 58, 68, alpha),
                                 (dx + 1, dy), (dx + 1, dy - pole_h), 1)
                for ai_p in range(random.randint(1, 3)):
                    arm_w = random.randint(8, 16)
                    arm_y = dy - pole_h + 5 + ai_p * random.randint(6, 12)
                    pygame.draw.line(surf, (52, 48, 58, alpha),
                                     (dx - arm_w // 2, arm_y),
                                     (dx + arm_w // 2, arm_y), 1)
                pygame.draw.rect(surf, (46, 42, 52, alpha),
                                 (dx - 2, dy - pole_h + 15, 5, 5))
            elif dtype == 3:
                # 볼라드
                pygame.draw.rect(surf, (65, 60, 72, alpha),
                                 (dx - 1, dy - 6, 3, 6))
                pygame.draw.circle(surf, (75, 70, 82, alpha), (dx, dy - 7), 2)
            else:
                # 자전거
                pygame.draw.circle(surf, (50, 45, 55, alpha), (dx - 3, dy - 2), 3, 1)
                pygame.draw.circle(surf, (50, 45, 55, alpha), (dx + 3, dy - 2), 3, 1)
                pygame.draw.line(surf, (55, 50, 60, alpha),
                                 (dx - 3, dy - 2), (dx + 1, dy - 5), 1)
                pygame.draw.line(surf, (55, 50, 60, alpha),
                                 (dx + 3, dy - 2), (dx + 1, dy - 5), 1)

        # ===== 멘헤라 곰인형 (X눈 — 초고퀄리티 풀바디, 액세서리) =====
        for bi_m in range(14):
            bx_m = random.randint(18, W - 18)
            by_m = random.randint(int(H * 0.32), H - 12)
            if _in_center(bx_m, by_m):
                continue
            bear_s = random.randint(9, 18)
            bear_c = random.choice([
                (30, 25, 30), (255, 180, 200), (140, 80, 100),
                (120, 100, 80), (200, 160, 180), (80, 60, 70),
            ])
            bs_w, bs_h = bear_s * 3, bear_s * 4
            bs = pygame.Surface((bs_w, bs_h), pygame.SRCALPHA)
            cx_b, cy_b = bs_w // 2, bs_h // 3
            ba = min(255, int(alpha * 0.85))
            # 다리 (2개)
            leg_w = max(2, bear_s // 3)
            leg_h = max(4, bear_s // 2)
            pygame.draw.ellipse(bs, (*bear_c, ba),
                                (cx_b - bear_s // 2 - 1, cy_b + bear_s - 2, leg_w + 2, leg_h + 2))
            pygame.draw.ellipse(bs, (*bear_c, ba),
                                (cx_b + bear_s // 2 - leg_w, cy_b + bear_s - 2, leg_w + 2, leg_h + 2))
            # 몸통
            pygame.draw.ellipse(bs, (*bear_c, ba),
                                (cx_b - bear_s // 2, cy_b, bear_s, bear_s + 2))
            # 배 (밝은 부분)
            belly_c = (min(255, bear_c[0] + 40), min(255, bear_c[1] + 35),
                       min(255, bear_c[2] + 30))
            belly_r = max(2, bear_s // 4)
            pygame.draw.ellipse(bs, (*belly_c, max(1, ba // 2)),
                                (cx_b - belly_r, cy_b + bear_s // 3, belly_r * 2, belly_r * 2))
            # 팔 (2개)
            arm_w = max(2, bear_s // 4)
            arm_h = max(3, bear_s // 2)
            pygame.draw.ellipse(bs, (*bear_c, ba),
                                (cx_b - bear_s // 2 - arm_w + 1, cy_b + 2, arm_w + 1, arm_h))
            pygame.draw.ellipse(bs, (*bear_c, ba),
                                (cx_b + bear_s // 2 - 1, cy_b + 2, arm_w + 1, arm_h))
            # 머리
            head_r_m = max(4, bear_s * 2 // 5)
            pygame.draw.circle(bs, (*bear_c, ba), (cx_b, cy_b - head_r_m + 4), head_r_m)
            # 귀
            ear_r_m = max(2, head_r_m // 2)
            for ear_side in [-1, 1]:
                ear_x = cx_b + ear_side * (head_r_m - 2)
                ear_y = cy_b - head_r_m - ear_r_m + 6
                pygame.draw.circle(bs, (*bear_c, ba), (ear_x, ear_y), ear_r_m)
                # 귀 안쪽 (핑크)
                pygame.draw.circle(bs, (255, 150, 180, max(1, ba - 30)),
                                   (ear_x, ear_y), max(1, ear_r_m - 2))
            # X 눈 (멘헤라)
            ey_y = cy_b - head_r_m + 5
            xr = max(1, head_r_m // 3)
            x_c = (220, 40, 70, min(255, int(alpha * 0.95)))
            for ex_side in [-1, 1]:
                ex_x = cx_b + ex_side * (head_r_m // 3 + 1)
                pygame.draw.line(bs, x_c, (ex_x - xr, ey_y - xr),
                                 (ex_x + xr, ey_y + xr), max(1, bear_s // 8))
                pygame.draw.line(bs, x_c, (ex_x + xr, ey_y - xr),
                                 (ex_x - xr, ey_y + xr), max(1, bear_s // 8))
            # 입 (슬픈 곡선)
            mouth_y = cy_b - head_r_m + head_r_m * 2 // 3 + 3
            mouth_w = max(3, head_r_m // 2)
            pygame.draw.arc(bs, (180, 40, 60, min(255, int(alpha * 0.8))),
                            (cx_b - mouth_w, mouth_y, mouth_w * 2, max(2, head_r_m // 3)),
                            3.14, 6.28, 1)
            # 눈물 (한쪽)
            if random.random() < 0.5:
                tear_x = cx_b - head_r_m // 3
                tear_y = ey_y + xr + 1
                pygame.draw.ellipse(bs, (100, 180, 255, min(255, int(alpha * 0.6))),
                                    (tear_x - 1, tear_y, 2, max(2, head_r_m // 3)))
            # 반창고 (몸에 붙은)
            if random.random() < 0.4:
                bd_x = cx_b + random.randint(-bear_s // 3, bear_s // 3)
                bd_y = cy_b + random.randint(0, bear_s // 2)
                bd_l = max(3, bear_s // 3)
                pygame.draw.line(bs, (210, 185, 155, min(255, int(alpha * 0.7))),
                                 (bd_x - bd_l, bd_y - bd_l // 2),
                                 (bd_x + bd_l, bd_y + bd_l // 2), max(1, bear_s // 8))
            # 리본/나비 (일부 곰에)
            if random.random() < 0.35:
                rb_x = cx_b + head_r_m - 2
                rb_y = cy_b - head_r_m
                rb_r = max(2, head_r_m // 3)
                rb_c = random.choice([(255, 80, 120), (255, 150, 200), (200, 80, 255)])
                pygame.draw.circle(bs, (*rb_c, ba), (rb_x - rb_r, rb_y), rb_r)
                pygame.draw.circle(bs, (*rb_c, ba), (rb_x + rb_r, rb_y), rb_r)
                pygame.draw.circle(bs, (min(255, rb_c[0] - 30), max(0, rb_c[1] - 20),
                                        max(0, rb_c[2] - 20), ba),
                                   (rb_x, rb_y), max(1, rb_r // 2))
            surf.blit(bs, (bx_m - bs_w // 2, by_m - bs_h // 2))
            # 핑크 글로우
            g_s = pygame.Surface((bear_s * 5, bear_s * 5), pygame.SRCALPHA)
            pygame.draw.circle(g_s, (200, 80, 120, 15),
                               (bear_s * 5 // 2, bear_s * 5 // 2), bear_s * 5 // 2)
            surf.blit(g_s, (bx_m - bear_s * 5 // 2, by_m - bear_s * 5 // 2))

        # ===== 멘헤라 하트 네온 (일반 + 깨진/피 묻은 하트) =====
        for hi in range(12):
            hx = random.randint(10, W - 10)
            hy = random.randint(int(H * 0.22), int(H * 0.82))
            if _in_center(hx, hy):
                continue
            h_sz = random.randint(6, 16)
            h_c = random.choice([
                (255, 60, 120), (255, 100, 160), (255, 40, 100),
                (220, 50, 90), (255, 80, 140), (200, 40, 80),
            ])
            is_broken = random.random() < 0.3
            hs_w = h_sz * 2 + 6
            hs = pygame.Surface((hs_w, hs_w), pygame.SRCALPHA)
            cx_h, cy_h = hs_w // 2, hs_w // 2
            hr = max(2, h_sz * 2 // 5)
            ha = min(255, int(alpha * 0.85))
            # 하트 본체
            pygame.draw.circle(hs, (*h_c, ha), (cx_h - hr + 1, cy_h - hr // 2), hr)
            pygame.draw.circle(hs, (*h_c, ha), (cx_h + hr - 1, cy_h - hr // 2), hr)
            pygame.draw.polygon(hs, (*h_c, ha),
                                [(cx_h - h_sz + 1, cy_h - 1),
                                 (cx_h + h_sz - 1, cy_h - 1),
                                 (cx_h, cy_h + h_sz)])
            # 하이라이트
            hl_c = (min(255, h_c[0] + 30), min(255, h_c[1] + 30), min(255, h_c[2] + 30))
            pygame.draw.circle(hs, (*hl_c, max(1, ha // 3)),
                               (cx_h - hr // 2, cy_h - hr), max(1, hr // 3))
            if is_broken:
                # 깨진 금 (지그재그)
                crack_c = (40, 20, 30, min(255, int(alpha * 0.8)))
                mid_x = cx_h
                pts = [(mid_x, cy_h - hr)]
                for ci_c in range(4):
                    pts.append((mid_x + random.randint(-3, 3),
                                cy_h - hr + (ci_c + 1) * (h_sz + hr) // 4))
                if len(pts) > 1:
                    pygame.draw.lines(hs, crack_c, False, pts, max(1, h_sz // 6))
                # 피 방울 (하단)
                for _ in range(random.randint(1, 3)):
                    drip_x = cx_h + random.randint(-h_sz // 3, h_sz // 3)
                    drip_y = cy_h + h_sz + random.randint(0, h_sz // 2)
                    drip_r = max(1, random.randint(1, 3))
                    pygame.draw.circle(hs, (180, 30, 50, min(255, int(alpha * 0.6))),
                                       (drip_x, drip_y), drip_r)
                    # 드립 줄기
                    pygame.draw.line(hs, (160, 30, 45, min(255, int(alpha * 0.4))),
                                     (drip_x, cy_h + h_sz), (drip_x, drip_y), 1)
            # 4중 글로우
            for gi in range(4):
                g_r = h_sz + 3 + gi * 3
                gs = pygame.Surface((g_r * 2, g_r * 2), pygame.SRCALPHA)
                pygame.draw.circle(gs, (*h_c, max(1, 30 - gi * 7)),
                                   (g_r, g_r), g_r)
                surf.blit(gs, (hx - g_r, hy - g_r))
            surf.blit(hs, (hx - hs_w // 2, hy - hs_w // 2))

        # ===== 반창고/붕대 (초고퀄 — 텍스처+구멍+피) =====
        for bdi in range(18):
            bdx = random.randint(5, W - 5)
            bdy = random.randint(int(H * 0.28), H - 5)
            if _in_center(bdx, bdy):
                continue
            is_x = random.random() < 0.3
            bd_len = random.randint(10, 24)
            bd_w = max(2, bd_len // 4)
            bd_c = (210, 185, 155)
            bd_pad = (190, 160, 130)
            bd_blood = (180, 50, 50)
            bd_a = min(255, int(alpha * 0.6))
            if is_x:
                pygame.draw.line(surf, (*bd_c, bd_a),
                                 (bdx - bd_len // 2, bdy - bd_len // 2),
                                 (bdx + bd_len // 2, bdy + bd_len // 2), bd_w)
                pygame.draw.line(surf, (*bd_c, bd_a),
                                 (bdx + bd_len // 2, bdy - bd_len // 2),
                                 (bdx - bd_len // 2, bdy + bd_len // 2), bd_w)
                # 반창고 구멍 (가로줄)
                for stripe in range(-bd_len // 2 + 2, bd_len // 2, max(2, bd_len // 6)):
                    pygame.draw.line(surf, (*bd_pad, max(1, bd_a // 2)),
                                     (bdx + stripe - 1, bdy + stripe - bd_w),
                                     (bdx + stripe - 1, bdy + stripe + bd_w), 1)
                pygame.draw.circle(surf, (*bd_blood, max(1, int(alpha * 0.4))),
                                   (bdx, bdy), max(1, bd_w))
                # 주변 피 흔적
                if random.random() < 0.4:
                    for _ in range(random.randint(1, 3)):
                        bsx = bdx + random.randint(-bd_len // 3, bd_len // 3)
                        bsy = bdy + random.randint(-2, bd_len // 3)
                        pygame.draw.circle(surf, (*bd_blood, max(1, int(alpha * 0.25))),
                                           (bsx, bsy), 1)
            else:
                angle = random.choice([0, 1])
                if angle == 0:
                    pygame.draw.rect(surf, (*bd_c, bd_a),
                                     (bdx - bd_len // 2, bdy - bd_w // 2, bd_len, bd_w))
                    # 둥근 끝
                    pygame.draw.circle(surf, (*bd_c, bd_a),
                                       (bdx - bd_len // 2, bdy), max(1, bd_w // 2))
                    pygame.draw.circle(surf, (*bd_c, bd_a),
                                       (bdx + bd_len // 2, bdy), max(1, bd_w // 2))
                    # 패드
                    pad_w = max(3, bd_len // 3)
                    pygame.draw.rect(surf, (*bd_pad, max(1, bd_a - 20)),
                                     (bdx - pad_w // 2, bdy - bd_w // 2, pad_w, bd_w))
                    # 구멍 텍스처
                    for stripe in range(bdx - bd_len // 2 + 2, bdx + bd_len // 2 - 1,
                                        max(2, bd_len // 8)):
                        pygame.draw.line(surf, (*bd_pad, max(1, bd_a // 3)),
                                         (stripe, bdy - bd_w // 2),
                                         (stripe, bdy + bd_w // 2), 1)
                else:
                    pygame.draw.rect(surf, (*bd_c, bd_a),
                                     (bdx - bd_w // 2, bdy - bd_len // 2, bd_w, bd_len))
                    pygame.draw.circle(surf, (*bd_c, bd_a),
                                       (bdx, bdy - bd_len // 2), max(1, bd_w // 2))
                    pygame.draw.circle(surf, (*bd_c, bd_a),
                                       (bdx, bdy + bd_len // 2), max(1, bd_w // 2))
                    pad_h = max(3, bd_len // 3)
                    pygame.draw.rect(surf, (*bd_pad, max(1, bd_a - 20)),
                                     (bdx - bd_w // 2, bdy - pad_h // 2, bd_w, pad_h))

        # ===== 알약/캡슐 + 약병 (멘헤라 의약품) =====
        for pli in range(15):
            plx = random.randint(8, W - 8)
            ply = random.randint(int(H * 0.38), H - 5)
            if _in_center(plx, ply):
                continue
            p_type = random.random()
            pa = min(255, int(alpha * 0.7))
            if p_type < 0.6:
                # 캡슐
                pill_w = random.randint(6, 12)
                pill_h = max(3, pill_w // 2)
                pc1 = random.choice([
                    (255, 100, 150), (100, 200, 255), (255, 200, 80),
                    (200, 100, 255), (255, 150, 200), (80, 220, 180),
                ])
                pc2 = (240, 235, 230)
                pill_rot = random.choice([0, 1])
                if pill_rot == 0:
                    pygame.draw.ellipse(surf, (*pc1, pa),
                                        (plx - pill_w // 2, ply - pill_h // 2,
                                         pill_w // 2, pill_h))
                    pygame.draw.ellipse(surf, (*pc2, pa),
                                        (plx, ply - pill_h // 2,
                                         pill_w // 2, pill_h))
                    # 구분선
                    pygame.draw.line(surf, (200, 100, 140, max(1, pa // 2)),
                                     (plx, ply - pill_h // 2), (plx, ply + pill_h // 2), 1)
                    # 하이라이트
                    pygame.draw.line(surf, (255, 240, 240, max(1, pa // 3)),
                                     (plx - pill_w // 4, ply - pill_h // 2 + 1),
                                     (plx + pill_w // 4, ply - pill_h // 2 + 1), 1)
                else:
                    pygame.draw.ellipse(surf, (*pc1, pa),
                                        (plx - pill_h // 2, ply - pill_w // 2,
                                         pill_h, pill_w // 2))
                    pygame.draw.ellipse(surf, (*pc2, pa),
                                        (plx - pill_h // 2, ply,
                                         pill_h, pill_w // 2))
            elif p_type < 0.8:
                # 약병
                bw_p = random.randint(5, 9)
                bh_p = random.randint(8, 14)
                # 병 몸체
                pygame.draw.rect(surf, (200, 220, 240, pa),
                                 (plx - bw_p // 2, ply - bh_p, bw_p, bh_p))
                # 뚜껑
                cap_h = max(2, bh_p // 5)
                pygame.draw.rect(surf, (240, 240, 250, pa),
                                 (plx - bw_p // 2 - 1, ply - bh_p - cap_h,
                                  bw_p + 2, cap_h))
                # 라벨
                label_h = max(2, bh_p // 3)
                lbl_c = random.choice([(255, 100, 150), (100, 180, 255), (200, 100, 255)])
                pygame.draw.rect(surf, (*lbl_c, max(1, pa - 30)),
                                 (plx - bw_p // 2 + 1, ply - bh_p + cap_h + 1,
                                  bw_p - 2, label_h))
                # 십자 마크
                cx_p = plx
                cy_p = ply - bh_p + cap_h + 1 + label_h // 2
                pygame.draw.line(surf, (255, 255, 255, max(1, pa // 2)),
                                 (cx_p - 1, cy_p), (cx_p + 1, cy_p), 1)
                pygame.draw.line(surf, (255, 255, 255, max(1, pa // 2)),
                                 (cx_p, cy_p - 1), (cx_p, cy_p + 1), 1)
            else:
                # 주사기
                syr_len = random.randint(10, 18)
                syr_w = max(2, syr_len // 5)
                # 실린더
                pygame.draw.rect(surf, (220, 230, 240, pa),
                                 (plx - syr_w // 2, ply - syr_len, syr_w, syr_len))
                # 피스톤 손잡이
                pygame.draw.rect(surf, (180, 190, 200, pa),
                                 (plx - syr_w, ply - 2, syr_w * 2, 3))
                # 바늘
                pygame.draw.line(surf, (200, 205, 215, pa),
                                 (plx, ply - syr_len), (plx, ply - syr_len - max(3, syr_len // 3)), 1)
                # 액체 (핑크)
                liq_h = max(2, syr_len // 3)
                pygame.draw.rect(surf, (255, 100, 150, max(1, pa - 40)),
                                 (plx - syr_w // 2 + 1, ply - liq_h - 2, syr_w - 2, liq_h))

        # ===== 체인/쇠사슬 (HD — 두꺼운 링크 + 자물쇠) =====
        for chi in range(8):
            ch_x1 = random.randint(10, W - 60)
            ch_x2 = ch_x1 + random.randint(35, 90)
            ch_y = random.randint(int(H * 0.22), int(H * 0.68))
            if _in_center((ch_x1 + ch_x2) // 2, ch_y):
                continue
            ch_dark = (45, 45, 52)
            ch_mid = (80, 80, 90)
            ch_light = (140, 140, 155)
            cha = min(255, int(alpha * 0.7))
            link_count = max(5, (ch_x2 - ch_x1) // 5)
            for li_c in range(link_count):
                t_c = li_c / max(1, link_count - 1)
                lx = int(ch_x1 + (ch_x2 - ch_x1) * t_c)
                sag = int(18 * math.sin(t_c * math.pi))
                ly = ch_y + sag
                lr_x = max(2, 4)
                lr_y = max(2, 3)
                if li_c % 2 == 0:
                    pygame.draw.ellipse(surf, (*ch_dark, cha),
                                        (lx - lr_x, ly - lr_y, lr_x * 2, lr_y * 2))
                    pygame.draw.ellipse(surf, (*ch_mid, max(1, cha - 30)),
                                        (lx - lr_x + 1, ly - lr_y + 1,
                                         lr_x * 2 - 2, lr_y * 2 - 2), 1)
                else:
                    pygame.draw.ellipse(surf, (*ch_dark, cha),
                                        (lx - lr_x + 1, ly - lr_y + 1,
                                         lr_x * 2 - 2, lr_y * 2 - 2))
                # 광택
                pygame.draw.circle(surf, (*ch_light, max(1, cha // 2)),
                                   (lx - 1, ly - 1), 1)
            # 자물쇠 (체인 중앙에 매달림)
            if random.random() < 0.45:
                lock_x = (ch_x1 + ch_x2) // 2
                lock_sag = int(18 * math.sin(0.5 * math.pi))
                lock_y = ch_y + lock_sag + 3
                lk_w = max(4, 6)
                lk_h = max(5, 7)
                # 걸쇠 (반원)
                pygame.draw.arc(surf, (*ch_mid, cha),
                                (lock_x - lk_w // 3, lock_y - lk_h // 2,
                                 lk_w * 2 // 3, lk_h // 2), 0, 3.14, 1)
                # 본체
                pygame.draw.rect(surf, (180, 150, 50, cha),
                                 (lock_x - lk_w // 2, lock_y, lk_w, lk_h))
                pygame.draw.rect(surf, (200, 170, 60, max(1, cha - 30)),
                                 (lock_x - lk_w // 2, lock_y, lk_w, lk_h), 1)
                # 열쇠구멍
                pygame.draw.circle(surf, (30, 25, 20, cha),
                                   (lock_x, lock_y + lk_h // 3), max(1, lk_w // 5))
                pygame.draw.line(surf, (30, 25, 20, cha),
                                 (lock_x, lock_y + lk_h // 3),
                                 (lock_x, lock_y + lk_h * 2 // 3), 1)

        # ===== 면도날 (HD — 광택 + 피 묻은 날) =====
        for rzi in range(8):
            rzx = random.randint(15, W - 15)
            rzy = random.randint(int(H * 0.28), int(H * 0.78))
            if _in_center(rzx, rzy):
                continue
            rz_sz = random.randint(7, 14)
            rz_h = max(3, rz_sz * 2 // 3)
            rza = min(255, int(alpha * 0.6))
            # 본체
            pygame.draw.rect(surf, (200, 205, 215, rza),
                             (rzx - rz_sz, rzy - rz_h // 2, rz_sz * 2, rz_h))
            # 광택 (상단 밝은 면)
            pygame.draw.rect(surf, (230, 235, 245, max(1, rza - 20)),
                             (rzx - rz_sz, rzy - rz_h // 2, rz_sz * 2, max(1, rz_h // 3)))
            # 테두리
            pygame.draw.rect(surf, (160, 165, 175, max(1, rza - 20)),
                             (rzx - rz_sz, rzy - rz_h // 2, rz_sz * 2, rz_h), 1)
            # 구멍 (2개)
            hole_r = max(1, rz_sz // 5)
            pygame.draw.circle(surf, (30, 20, 40, rza),
                               (rzx - rz_sz // 3, rzy), hole_r)
            pygame.draw.circle(surf, (30, 20, 40, rza),
                               (rzx + rz_sz // 3, rzy), hole_r)
            # 구멍 하이라이트
            pygame.draw.circle(surf, (240, 242, 248, max(1, rza // 3)),
                               (rzx - rz_sz // 3 - 1, rzy - 1), max(1, hole_r - 1))
            # 날 엣지
            pygame.draw.line(surf, (245, 248, 252, rza),
                             (rzx - rz_sz, rzy - rz_h // 2),
                             (rzx + rz_sz, rzy - rz_h // 2), 1)
            # 피 자국 (날에)
            if random.random() < 0.5:
                for _ in range(random.randint(1, 3)):
                    bx_r = rzx + random.randint(-rz_sz + 2, rz_sz - 2)
                    by_r = rzy - rz_h // 2 + random.randint(-1, 1)
                    pygame.draw.circle(surf, (180, 40, 45, max(1, int(alpha * 0.35))),
                                       (bx_r, by_r), 1)
                    # 피 드립
                    drip_len = random.randint(2, 6)
                    pygame.draw.line(surf, (160, 35, 40, max(1, int(alpha * 0.25))),
                                     (bx_r, by_r), (bx_r, by_r + drip_len), 1)

        # ===== 핑크 그런지 스플래터 (건물/도로 — 밀도 증가) =====
        for spi in range(25):
            spx = random.randint(5, W - 5)
            spy = random.randint(int(H * 0.18), H - 3)
            if _in_center(spx, spy):
                continue
            sp_c = random.choice([
                (140, 80, 100), (180, 120, 140), (160, 90, 110),
                (120, 60, 80), (200, 140, 160), (100, 50, 65),
            ])
            sp_r = random.randint(5, 18)
            sp_s = pygame.Surface((sp_r * 2, sp_r * 2), pygame.SRCALPHA)
            for _ in range(random.randint(4, 8)):
                sx_o = random.randint(-sp_r // 2, sp_r // 2)
                sy_o = random.randint(-sp_r // 2, sp_r // 2)
                sr_o = random.randint(2, max(3, sp_r * 2 // 3))
                pygame.draw.circle(sp_s, (*sp_c, max(1, int(alpha * 0.2))),
                                   (sp_r + sx_o, sp_r + sy_o), sr_o)
            # 드립 줄기 (스플래터에서 아래로)
            if random.random() < 0.35:
                drip_x = sp_r + random.randint(-sp_r // 3, sp_r // 3)
                drip_len = random.randint(5, max(6, sp_r * 2))
                pygame.draw.line(sp_s, (*sp_c, max(1, int(alpha * 0.15))),
                                 (drip_x, sp_r + sp_r // 2),
                                 (drip_x + random.randint(-2, 2), sp_r + sp_r // 2 + drip_len), 1)
            surf.blit(sp_s, (spx - sp_r, spy - sp_r))

        # ===== 의료 십자 네온 + 하트 모니터 (병원/약국) =====
        for mci in range(6):
            mcx = random.randint(20, W - 20)
            mcy = random.randint(int(H * 0.28), int(H * 0.72))
            if _in_center(mcx, mcy):
                continue
            mc_sz = random.randint(6, 12)
            mc_c = random.choice([
                (255, 60, 100), (60, 200, 255), (200, 60, 255), (255, 200, 80),
            ])
            mc_a = min(255, int(alpha * 0.8))
            if random.random() < 0.6:
                # 십자가
                pygame.draw.rect(surf, (*mc_c, mc_a),
                                 (mcx - mc_sz // 3, mcy - mc_sz, mc_sz * 2 // 3, mc_sz * 2))
                pygame.draw.rect(surf, (*mc_c, mc_a),
                                 (mcx - mc_sz, mcy - mc_sz // 3, mc_sz * 2, mc_sz * 2 // 3))
                # 테두리
                pygame.draw.rect(surf, (min(255, mc_c[0] + 30), min(255, mc_c[1] + 30),
                                        min(255, mc_c[2] + 30), max(1, mc_a // 2)),
                                 (mcx - mc_sz, mcy - mc_sz, mc_sz * 2, mc_sz * 2), 1)
            else:
                # 하트 모니터 파형 (ECG)
                ecg_w = mc_sz * 3
                ecg_pts = []
                for ei in range(ecg_w):
                    ex = mcx - ecg_w // 2 + ei
                    ep = ei / max(1, ecg_w)
                    if 0.3 < ep < 0.4:
                        ey_ecg = mcy - mc_sz
                    elif 0.4 < ep < 0.5:
                        ey_ecg = mcy + mc_sz // 2
                    elif 0.5 < ep < 0.55:
                        ey_ecg = mcy - mc_sz * 2 // 3
                    else:
                        ey_ecg = mcy
                    ecg_pts.append((ex, ey_ecg))
                if len(ecg_pts) > 2:
                    pygame.draw.lines(surf, (*mc_c, mc_a), False, ecg_pts, 1)
            # 4중 글로우
            for gi in range(4):
                g_r = mc_sz + 3 + gi * 3
                gs = pygame.Surface((g_r * 2, g_r * 2), pygame.SRCALPHA)
                pygame.draw.circle(gs, (*mc_c, max(1, 25 - gi * 6)),
                                   (g_r, g_r), g_r)
                surf.blit(gs, (mcx - g_r, mcy - g_r))

        # ===== 안전핀 (건물 벽/반창고 근처) =====
        for spi_n in range(10):
            spx_n = random.randint(10, W - 10)
            spy_n = random.randint(int(H * 0.3), H - 8)
            if _in_center(spx_n, spy_n):
                continue
            pin_len = random.randint(8, 16)
            pin_a = min(255, int(alpha * 0.6))
            pin_c = (180, 185, 195)
            # 핀 바디 (직선)
            pygame.draw.line(surf, (*pin_c, pin_a),
                             (spx_n, spy_n), (spx_n + pin_len, spy_n), 1)
            # 핀 하단 (갈고리)
            pygame.draw.line(surf, (*pin_c, pin_a),
                             (spx_n + pin_len, spy_n), (spx_n + pin_len - 2, spy_n + 3), 1)
            pygame.draw.line(surf, (*pin_c, pin_a),
                             (spx_n + pin_len - 2, spy_n + 3), (spx_n + pin_len - 4, spy_n), 1)
            # 핀 머리 (원)
            pygame.draw.circle(surf, (*pin_c, pin_a), (spx_n, spy_n), max(1, 2))
            # 하이라이트
            pygame.draw.circle(surf, (220, 225, 235, max(1, pin_a // 2)),
                               (spx_n, spy_n), 1)

        # ===== 눈물 줄기 (건물 벽에서 흘러내리는) =====
        for tdi in range(8):
            tdx = random.randint(15, W - 15)
            tdy_start = random.randint(int(H * 0.25), int(H * 0.55))
            if _in_center(tdx, tdy_start):
                continue
            tear_len = random.randint(20, 60)
            tear_a = min(255, int(alpha * 0.35))
            tear_c = random.choice([
                (100, 160, 255), (140, 180, 255), (80, 140, 240),
            ])
            # 줄기 (약간 흔들림)
            pts = []
            for ti in range(tear_len):
                tx_t = tdx + int(math.sin(ti * 0.15 + tdi) * 2)
                ty_t = tdy_start + ti
                pts.append((tx_t, ty_t))
            if len(pts) > 2:
                pygame.draw.lines(surf, (*tear_c, tear_a), False, pts, 1)
            # 끝 물방울
            pygame.draw.circle(surf, (*tear_c, min(255, tear_a + 20)),
                               (pts[-1][0], pts[-1][1]), max(1, 2))

        # ===== 울고 있는 눈 그래피티 (건물 벽) =====
        for egi in range(5):
            egx = random.randint(20, W - 20)
            egy = random.randint(int(H * 0.3), int(H * 0.7))
            if _in_center(egx, egy):
                continue
            e_sz = random.randint(6, 12)
            e_a = min(255, int(alpha * 0.55))
            e_c = random.choice([
                (255, 100, 160), (100, 200, 255), (200, 100, 255),
            ])
            # 눈 윤곽 (아몬드형)
            pygame.draw.ellipse(surf, (*e_c, e_a),
                                (egx - e_sz, egy - e_sz // 2, e_sz * 2, e_sz))
            # 동공
            pupil_r = max(2, e_sz // 3)
            pygame.draw.circle(surf, (30, 20, 40, e_a), (egx, egy), pupil_r)
            # 동공 하이라이트
            pygame.draw.circle(surf, (255, 255, 255, max(1, e_a // 2)),
                               (egx - pupil_r // 2, egy - pupil_r // 2), max(1, pupil_r // 3))
            # 눈물 (2줄)
            for tear_side in [-1, 1]:
                tear_sx = egx + tear_side * (e_sz // 3)
                tear_sy = egy + e_sz // 2
                tear_len_e = random.randint(6, max(7, e_sz))
                for ti in range(tear_len_e):
                    tx_e = tear_sx + int(math.sin(ti * 0.3) * tear_side)
                    ty_e = tear_sy + ti
                    ta = max(1, int(e_a * (1.0 - ti / tear_len_e) * 0.6))
                    pygame.draw.circle(surf, (100, 180, 255, ta), (tx_e, ty_e), 1)

        # ===== 카오모지 네온사인 (╥_╥) (._.) =====
        kaomoji_patterns = [
            # (╥_╥) — 3x5 패턴
            [(0,0,1,1),(0,1,1,1),(0,2,1,1),(0,3,1,1),(0,4,1,1),
             (1,2,1,1),
             (2,0,1,1),(2,1,1,1),(2,2,1,1),(2,3,1,1),(2,4,1,1)],
            # T_T — 간단
            [(0,0,3,1),(1,0,1,3), (4,0,3,1),(5,0,1,3), (3,2,1,1)],
            # ;_; — 세미콜론 눈물
            [(0,0,1,1),(0,2,1,1),(0,3,1,1), (2,2,1,1),
             (4,0,1,1),(4,2,1,1),(4,3,1,1)],
        ]
        for kmi in range(6):
            kmx = random.randint(15, W - 30)
            kmy = random.randint(int(H * 0.28), int(H * 0.72))
            if _in_center(kmx, kmy):
                continue
            km_c = random.choice([
                (255, 80, 160), (80, 220, 255), (255, 200, 80), (200, 80, 255),
            ])
            km_a = min(255, int(alpha * 0.75))
            km_scale = random.randint(2, 3)
            pattern = random.choice(kaomoji_patterns)
            # 배경 패널
            max_dx = max(dx + dw for dx, dy, dw, dh in pattern) * km_scale
            max_dy = max(dy + dh for dx, dy, dw, dh in pattern) * km_scale
            pygame.draw.rect(surf, (20, 10, 28, max(1, km_a - 40)),
                             (kmx - 2, kmy - 2, max_dx + 4, max_dy + 4))
            pygame.draw.rect(surf, (*km_c, max(1, km_a // 2)),
                             (kmx - 2, kmy - 2, max_dx + 4, max_dy + 4), 1)
            # 글리프
            for dx, dy, dw, dh in pattern:
                pygame.draw.rect(surf, (*km_c, km_a),
                                 (kmx + dx * km_scale, kmy + dy * km_scale,
                                  dw * km_scale, dh * km_scale))
            # 글로우
            g_w = max_dx + 10
            g_h = max_dy + 10
            gs = pygame.Surface((g_w, g_h), pygame.SRCALPHA)
            pygame.draw.rect(gs, (*km_c, 18), (0, 0, g_w, g_h))
            surf.blit(gs, (kmx - 5, kmy - 5))

        # ===== 일기장/메모 조각 (날아다니는 종이) =====
        for nti in range(6):
            ntx = random.randint(10, W - 10)
            nty = random.randint(int(H * 0.35), H - 10)
            if _in_center(ntx, nty):
                continue
            note_w = random.randint(8, 16)
            note_h = random.randint(10, 18)
            note_a = min(255, int(alpha * 0.45))
            # 종이
            pygame.draw.rect(surf, (240, 235, 225, note_a),
                             (ntx - note_w // 2, nty - note_h // 2, note_w, note_h))
            # 줄
            for li_n in range(nty - note_h // 2 + 3, nty + note_h // 2 - 1,
                              max(2, note_h // 5)):
                pygame.draw.line(surf, (180, 200, 220, max(1, note_a // 2)),
                                 (ntx - note_w // 2 + 1, li_n),
                                 (ntx + note_w // 2 - 1, li_n), 1)
            # 글씨 (아무렇게나 — 핑크/빨강)
            ink_c = random.choice([(200, 60, 80), (180, 40, 60), (220, 80, 100)])
            for _ in range(random.randint(2, 4)):
                lx_n = ntx - note_w // 2 + random.randint(2, max(3, note_w - 4))
                ly_n = nty - note_h // 2 + random.randint(3, max(4, note_h - 3))
                ll = random.randint(3, max(4, note_w - 4))
                pygame.draw.line(surf, (*ink_c, max(1, note_a - 10)),
                                 (lx_n, ly_n), (lx_n + ll, ly_n + random.randint(-1, 1)), 1)
            # 구겨진 모서리
            pygame.draw.polygon(surf, (220, 215, 205, max(1, note_a - 10)),
                                [(ntx + note_w // 2 - 3, nty - note_h // 2),
                                 (ntx + note_w // 2, nty - note_h // 2),
                                 (ntx + note_w // 2, nty - note_h // 2 + 3)])

        # ===== 네온 반사 파티클 (도시 밤 분위기 — 핑크 강조) =====
        if t > 0.25:
            sparkle_count = int(50 * min(1.0, (t - 0.25) / 0.5))
            for _ in range(sparkle_count):
                sx = random.randint(0, W)
                sy = random.randint(0, H)
                sr = max(1, random.randint(1, 2))
                sa = random.randint(70, 200)
                sc = random.choice([
                    (255, 80, 140), (255, 120, 180), (200, 100, 255),
                    (255, 60, 120), (100, 200, 255), (255, 150, 200),
                    (220, 80, 160), (255, 100, 160),
                ])
                spark_s = pygame.Surface((sr * 4, sr * 4), pygame.SRCALPHA)
                pygame.draw.circle(spark_s, (*sc, sa // 3),
                                   (sr * 2, sr * 2), sr * 2)
                pygame.draw.circle(spark_s, (*sc, min(255, sa)),
                                   (sr * 2, sr * 2), sr)
                surf.blit(spark_s, (sx - sr * 2, sy - sr * 2))

        # ===== 안개/스모그 (핑크빛 도시 스모그) =====
        mist_a = max(0, int(110 * (1.0 - t * 2.0) * alpha / 255))
        if mist_a > 2:
            random.seed(31379)
            for _ in range(24):
                mx = random.randint(-40, W + 40)
                my = random.randint(-20, H + 20)
                mw = random.randint(55, 180)
                mh = random.randint(16, 45)
                mc = random.choice([
                    (65, 30, 60), (75, 35, 70), (55, 25, 50),
                    (70, 32, 65), (80, 38, 72), (60, 28, 55),
                ])
                ms = pygame.Surface((mw, mh), pygame.SRCALPHA)
                pygame.draw.ellipse(ms, (*mc, min(255, mist_a)),
                                    (0, 0, mw, mh))
                inner_w = mw * 2 // 3
                inner_h = mh * 2 // 3
                pygame.draw.ellipse(ms, (*mc, min(255, mist_a // 2)),
                                    (mw // 6, mh // 6, inner_w, inner_h))
                surf.blit(ms, (mx - mw // 2, my - mh // 2))
            random.seed()

        # ===== 구름 (HD 다층 — 핑크빛 도시 야경) =====
        cloud_a = max(0, int(170 * (1.0 - t * 2.5) * alpha / 255))
        if cloud_a > 3:
            random.seed(31380)
            for _ in range(18):
                cx_c = random.randint(-40, W + 40)
                cy_c = random.randint(-20, H + 20)
                cw_c = random.randint(50, 165)
                ch_c = random.randint(12, 40)
                cc = random.choice([
                    (55, 28, 55), (65, 32, 65), (48, 22, 48),
                    (58, 26, 58), (70, 35, 60),
                ])
                cs = pygame.Surface((cw_c, ch_c), pygame.SRCALPHA)
                pygame.draw.ellipse(cs, (*cc, min(255, cloud_a)),
                                    (0, 0, cw_c, ch_c))
                top_h = max(2, ch_c // 4)
                pygame.draw.ellipse(cs, (cc[0] + 14, cc[1] + 7, cc[2] + 11,
                                         max(1, cloud_a // 3)),
                                    (8, 2, cw_c - 16, top_h))
                surf.blit(cs, (cx_c - cw_c // 2, cy_c - ch_c // 2))
            random.seed()

        # ===== 대기 오버레이 (더티핑크+보라 도시 야경 분위기) =====
        haze_a = max(0, int(55 * (1.0 - t * 2.5) * alpha / 255))
        if haze_a > 2:
            haze = pygame.Surface((W, H), pygame.SRCALPHA)
            haze.fill((50, 20, 48, haze_a))
            surf.blit(haze, (0, 0))

    def _draw_surface_temple(self, surf, t, alpha=255):
        """사원 행성 표면 — 초고퀄리티. Stage 4 퐁크 테마.
        t: 0(고공) ~ 1(지표면). 달빛 비추는 밤의 티베트/소림 사원."""
        W, H = surf.get_width(), surf.get_height()
        _cz_x, _cz_y = W // 2, H // 2
        _cz_hw, _cz_hh = 150, 120
        def _in_center(px, py):
            return abs(px - _cz_x) < _cz_hw and abs(py - _cz_y) < _cz_hh

        # ===== 기본 지형 — HD 1px 스무스 그라디언트 (어두운 보라-남색 밤하늘) =====
        sky_top = (8, 5, 18)         # 깊은 밤하늘
        sky_mid = (20, 15, 40)       # 보라빛 중간
        ground_mid = (28, 22, 45)    # 어두운 보라 대지
        ground_bot = (18, 14, 30)    # 짙은 어둠
        for y in range(H):
            fy = y / max(1, H - 1)
            if fy < 0.3:
                ft = fy / 0.3
                r = int(sky_top[0] + (sky_mid[0] - sky_top[0]) * ft)
                g = int(sky_top[1] + (sky_mid[1] - sky_top[1]) * ft)
                b = int(sky_top[2] + (sky_mid[2] - sky_top[2]) * ft)
            elif fy < 0.6:
                ft = (fy - 0.3) / 0.3
                r = int(sky_mid[0] + (ground_mid[0] - sky_mid[0]) * ft)
                g = int(sky_mid[1] + (ground_mid[1] - sky_mid[1]) * ft)
                b = int(sky_mid[2] + (ground_mid[2] - sky_mid[2]) * ft)
            else:
                ft = (fy - 0.6) / 0.4
                r = int(ground_mid[0] + (ground_bot[0] - ground_mid[0]) * ft)
                g = int(ground_mid[1] + (ground_bot[1] - ground_mid[1]) * ft)
                b = int(ground_mid[2] + (ground_bot[2] - ground_mid[2]) * ft)
            pygame.draw.line(surf, (r, g, b, alpha), (0, y), (W, y))

        random.seed(41371)

        # ===== 별 (밤하늘 — 다양한 크기/밝기) =====
        star_a = max(0, int(alpha * max(0.3, 1.0 - t * 1.5)))
        if star_a > 2:
            for _ in range(120):
                sx = random.randint(0, W)
                sy = random.randint(0, int(H * 0.55))
                sr = random.randint(1, 2)
                sb = random.randint(120, 255)
                sc = random.choice([
                    (240, 235, 255), (180, 200, 255), (255, 245, 220),
                    (200, 210, 255), (255, 230, 200),
                ])
                spark_s = pygame.Surface((sr * 4, sr * 4), pygame.SRCALPHA)
                pygame.draw.circle(spark_s, (*sc, min(255, star_a * sb // 255)),
                                   (sr * 2, sr * 2), sr)
                # 십자 글로우 (밝은 별만)
                if sb > 200 and sr > 1:
                    for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
                        pygame.draw.circle(spark_s, (*sc, min(255, star_a * sb // 510)),
                                           (sr * 2 + dx * 2, sr * 2 + dy * 2), 1)
                surf.blit(spark_s, (sx - sr * 2, sy - sr * 2))

        # ===== 달 (크림/금색 — 화면 우상단) =====
        moon_x = int(W * 0.78)
        moon_y = int(H * 0.12)
        moon_r = 28
        # 달빛 글로우 (다중 레이어)
        for gi in range(6):
            gr = moon_r + gi * 12
            ga = max(1, 25 - gi * 4)
            glow_s = pygame.Surface((gr * 2 + 4, gr * 2 + 4), pygame.SRCALPHA)
            pygame.draw.circle(glow_s, (255, 248, 220, min(255, int(ga * alpha / 255))),
                               (gr + 2, gr + 2), gr)
            surf.blit(glow_s, (moon_x - gr - 2, moon_y - gr - 2))
        # 달 본체
        pygame.draw.circle(surf, (255, 248, 220, alpha), (moon_x, moon_y), moon_r)
        pygame.draw.circle(surf, (245, 238, 200, alpha), (moon_x, moon_y), moon_r - 2)
        # 달 크레이터
        pygame.draw.circle(surf, (235, 225, 190, min(255, int(alpha * 0.6))),
                           (moon_x - 6, moon_y - 4), 5)
        pygame.draw.circle(surf, (230, 220, 185, min(255, int(alpha * 0.5))),
                           (moon_x + 8, moon_y + 6), 4)
        pygame.draw.circle(surf, (232, 222, 188, min(255, int(alpha * 0.4))),
                           (moon_x + 2, moon_y - 8), 3)

        # ===== 지형 패치 (어두운 돌/흙) =====
        patch_colors = [
            (25, 20, 38),    # 어두운 보라 돌
            (32, 28, 48),    # 짙은 보라
            (22, 18, 35),    # 그림자
            (35, 30, 50),    # 중간 보라
            (28, 25, 42),    # 어두운 석재
        ]
        for _ in range(85):
            px = random.randint(0, W)
            py = random.randint(0, H)
            pr = random.randint(20, 85)
            if _in_center(px, py):
                continue
            pc = patch_colors[random.randint(0, 4)]
            ps = pygame.Surface((pr * 2, pr * 2), pygame.SRCALPHA)
            pygame.draw.circle(ps, (*pc, min(255, int(alpha * 0.5))),
                               (pr, pr), pr)
            surf.blit(ps, (px - pr, py - pr))

        # ===== 미세 지면 질감 (돌/자갈/이끼) =====
        texture_colors = [
            (40, 35, 55), (35, 30, 50), (45, 40, 60),
            (30, 26, 42), (38, 34, 52), (42, 38, 58),
        ]
        for _ in range(280):
            tx = random.randint(0, W)
            ty = random.randint(0, H)
            tc = texture_colors[random.randint(0, 5)]
            tr = random.randint(1, 3)
            pygame.draw.circle(surf, (*tc, min(255, int(alpha * 0.6))),
                               (tx, ty), tr)

        # ===== 원경 — 사원 첨탑 실루엣 (빼곡, 2단 깊이 — 어둡고 보라빛) =====
        temple_a = max(0, int(alpha * 0.35))
        if temple_a > 2:
            # 1단 (가장 먼 — 흐릿한 대형 사원 실루엣)
            for ci in range(12):
                cx = int(W * (0.02 + ci * 0.085 + random.uniform(-0.03, 0.03)))
                base_y = int(H * random.uniform(0.08, 0.22))
                if _in_center(cx, base_y):
                    continue
                sc = (18 + random.randint(0, 8), 14 + random.randint(0, 6),
                      28 + random.randint(0, 10))
                # 흐릿한 사원 몸체
                b_w = random.randint(20, 45)
                b_h = random.randint(30, 70)
                pygame.draw.rect(surf, (*sc, max(1, temple_a // 2)),
                                 (cx - b_w // 2, base_y - b_h, b_w, b_h))
                # 겹지붕 (동양식)
                for ri in range(2):
                    rw = b_w + 8 - ri * 4
                    ry = base_y - b_h + ri * b_h // 3
                    pygame.draw.polygon(surf, (*sc, max(1, temple_a // 2)),
                                        [(cx - rw // 2, ry + 5),
                                         (cx, ry - 3),
                                         (cx + rw // 2, ry + 5)])
                # 희미한 붉은 등불 빛
                if random.random() < 0.4:
                    pygame.draw.circle(surf, (180, 40, 30, max(1, temple_a // 3)),
                                       (cx, base_y - b_h // 2), 2)
            # 2단 (가까운 — 뚜렷한 사원 실루엣)
            for ci in range(18):
                cx = int(W * (0.01 + ci * 0.056 + random.uniform(-0.02, 0.02)))
                base_y = int(H * random.uniform(0.12, 0.32))
                if _in_center(cx, base_y):
                    continue
                sc = (25 + random.randint(0, 12), 20 + random.randint(0, 10),
                      38 + random.randint(0, 12))
                ttype = random.randint(0, 2)
                if ttype == 0:
                    # 티베트 사원 (직선적 + 겹지붕)
                    tw = random.randint(20, 40)
                    th = random.randint(30, 60)
                    pygame.draw.rect(surf, (*sc, temple_a),
                                     (cx - tw // 2, base_y - th, tw, th))
                    # 겹지붕 (3단)
                    for ri in range(3):
                        rw = tw + 10 - ri * 3
                        ry = base_y - th + ri * th // 4
                        pygame.draw.polygon(surf, (sc[0] + 5, sc[1] + 3, sc[2] + 4, temple_a),
                                            [(cx - rw // 2, ry + 4),
                                             (cx, ry - 2),
                                             (cx + rw // 2, ry + 4)])
                    # 지붕 꼭대기 장식
                    pygame.draw.circle(surf, (108, 90, 48, min(255, temple_a + 15)),
                                       (cx, base_y - th - 3), max(1, 2))
                elif ttype == 1:
                    # 탑형 (다층)
                    pw = random.randint(14, 28)
                    ph = random.randint(50, 90)
                    pygame.draw.rect(surf, (*sc, temple_a),
                                     (cx - pw // 2, base_y - ph, pw, ph))
                    # 각 층 지붕
                    for si in range(4):
                        sw = pw + 6 - si * 2
                        sy = base_y - si * ph // 4
                        pygame.draw.polygon(surf, (sc[0] + 4, sc[1] + 3, sc[2] + 5, temple_a),
                                            [(cx - sw // 2, sy),
                                             (cx, sy - 5),
                                             (cx + sw // 2, sy)])
                else:
                    # 소림 스타일 (넓은 기단 + 높은 탑)
                    bw_t = random.randint(30, 50)
                    bh_t = random.randint(15, 25)
                    pygame.draw.rect(surf, (*sc, temple_a),
                                     (cx - bw_t // 2, base_y - bh_t, bw_t, bh_t))
                    tw = random.randint(10, 18)
                    th = random.randint(30, 55)
                    pygame.draw.rect(surf, (*sc, temple_a),
                                     (cx - tw // 2, base_y - bh_t - th, tw, th))
                    # 첨탑
                    pygame.draw.polygon(surf, (*sc, temple_a),
                                        [(cx - 3, base_y - bh_t - th),
                                         (cx, base_y - bh_t - th - 12),
                                         (cx + 3, base_y - bh_t - th)])
                # 달빛 하이라이트 (건물 좌측)
                if random.random() < 0.5:
                    hl_y = base_y - random.randint(10, 40)
                    pygame.draw.line(surf, (60, 55, 80, min(255, temple_a)),
                                     (cx - 8, hl_y), (cx - 8, hl_y + 10), 1)

        # ===== 수평 안개띠 (사원~중경 사이, 보라빛 달안개) =====
        for fi in range(5):
            fog_y = int(H * (0.18 + fi * 0.13))
            fog_a = max(0, int(35 * math.sin(fi * 1.3 + 0.3) * alpha / 255))
            if fog_a > 1:
                fog_s = pygame.Surface((W, max(1, int(22 + fi * 5))), pygame.SRCALPHA)
                fog_s.fill((35, 28, 55, fog_a))
                surf.blit(fog_s, (0, fog_y))

        # ===== 달빛 비추는 연못 (은빛 달빛 반사) =====
        for pi in range(3):
            pond_x = int(W * (0.2 + pi * 0.28 + random.uniform(-0.06, 0.06)))
            pond_y = int(H * random.uniform(0.5, 0.85))
            pond_w = random.randint(25, 45)
            pond_h = random.randint(18, 30)
            if _in_center(pond_x, pond_y):
                continue
            # 돌 테두리
            for si in range(3):
                pygame.draw.rect(surf, (45 - si * 5, 40 - si * 4, 55 - si * 5, alpha),
                                 (pond_x - pond_w // 2 - si * 3,
                                  pond_y - pond_h // 2 - si * 2,
                                  pond_w + si * 6, pond_h + si * 4), 1)
            # 물 (어두운 남색)
            water_s = pygame.Surface((pond_w, pond_h), pygame.SRCALPHA)
            water_s.fill((18, 22, 45, min(255, int(alpha * 0.7))))
            surf.blit(water_s, (pond_x - pond_w // 2, pond_y - pond_h // 2))
            # 달빛 반사
            pygame.draw.ellipse(surf, (180, 200, 255, min(255, int(alpha * 0.2))),
                                (pond_x - pond_w // 4, pond_y - pond_h // 4,
                                 pond_w // 2, pond_h // 4))
            # 연꽃 (핑크/보라)
            for _ in range(random.randint(2, 5)):
                lx = pond_x + random.randint(-pond_w // 3, pond_w // 3)
                ly = pond_y + random.randint(-pond_h // 3, pond_h // 3)
                lr = random.randint(2, 4)
                # 연잎
                pygame.draw.circle(surf, (25, 55, 35, min(255, int(alpha * 0.7))),
                                   (lx + random.randint(-3, 3), ly), lr + 1)
                # 연꽃
                petal_c = random.choice([(140, 90, 110), (100, 70, 140)])
                for pi_f in range(5):
                    ang = pi_f * math.pi * 2 / 5
                    ppx = lx + int(lr * 0.5 * math.cos(ang))
                    ppy = ly + int(lr * 0.5 * math.sin(ang))
                    pygame.draw.circle(surf, (*petal_c, min(255, int(alpha * 0.8))),
                                       (ppx, ppy), max(1, lr // 3))
                pygame.draw.circle(surf, (200, 180, 120, alpha),
                                   (lx, ly), max(1, lr // 4))

        # ===== 사원 건물 (HD 중경 — 어두운 석조 + 붉은 지붕 + 등롱) =====
        # 티베트/한자 풍 픽셀 문양 (사원 벽면 장식용)
        tibetan_glyphs = [
            [(0,0,4,1),(0,0,1,5),(2,2,2,1)],              # 옴 느낌
            [(0,0,1,5),(0,0,3,1),(2,1,1,4),(0,4,3,1)],    # 문자1
            [(1,0,2,1),(0,1,1,3),(3,1,1,3),(1,4,2,1)],    # 문자2
            [(0,0,4,1),(0,0,1,5),(0,2,3,1),(0,4,4,1)],    # 문자3
            [(0,0,1,5),(2,0,1,5),(0,2,4,1)],              # 문자4
            [(0,0,4,1),(2,0,1,3),(0,3,4,1),(0,3,1,2)],    # 문자5
            [(1,0,1,5),(0,0,3,1),(0,4,3,1)],              # 문자6
            [(0,0,4,1),(0,0,1,3),(0,2,4,1),(3,2,1,3),(0,4,4,1)], # 복잡 문자
        ]
        for bi in range(14):
            bx = int(W * (0.02 + bi * 0.07 + random.uniform(-0.02, 0.02)))
            by = int(H * random.uniform(0.32, 0.82))
            if _in_center(bx, by):
                continue
            b_w = random.randint(28, 58)
            b_h = random.randint(45, 100)
            wall_c = random.choice([
                (38, 35, 48), (42, 38, 52), (35, 32, 45),
                (45, 42, 55), (40, 36, 50),
            ])
            # 그림자
            shadow_s = pygame.Surface((b_w + 6, 6), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_s, (0, 0, 0, min(255, int(alpha * 0.3))),
                                (0, 0, b_w + 6, 6))
            surf.blit(shadow_s, (bx - b_w // 2 - 3, by - 1))
            # 기단 (3단 계단 — 어두운 석재)
            for si in range(3):
                sw = b_w + (3 - si) * 4
                sh = max(2, int(3 * (1 + si * 0.3)))
                sc_base = (wall_c[0] - 5 + si * 3, wall_c[1] - 4 + si * 2,
                           wall_c[2] - 3 + si * 3)
                pygame.draw.rect(surf, (*sc_base, alpha),
                                 (bx - sw // 2, by - si * sh, sw, sh))
            # 벽체 (어두운 회색-보라)
            pygame.draw.rect(surf, (*wall_c, alpha),
                             (bx - b_w // 2, by - b_h, b_w, b_h - 8))
            # 달빛 면 (좌측 밝은 반사)
            pygame.draw.rect(surf, (wall_c[0] + 10, wall_c[1] + 8, wall_c[2] + 12, alpha),
                             (bx - b_w // 2, by - b_h, b_w // 3, b_h - 8))
            # 기둥 (4개)
            col_gap = b_w // 5
            for ci in range(4):
                cx_col = bx - b_w // 2 + (ci + 1) * col_gap
                pw = max(1, b_w // 18)
                pygame.draw.line(surf, (wall_c[0] + 15, wall_c[1] + 12, wall_c[2] + 18, alpha),
                                 (cx_col, by - 8), (cx_col, by - b_h + 5), max(2, pw))
            # 지붕 (어두운 붉은색 — 티베트 스타일)
            roof_c = random.choice([(55, 30, 35), (60, 35, 40), (50, 28, 32)])
            roof_w = b_w + 10
            roof_h = max(6, b_h // 5)
            pygame.draw.polygon(surf, (*roof_c, alpha),
                                [(bx - roof_w // 2, by - b_h + 2),
                                 (bx, by - b_h - roof_h),
                                 (bx + roof_w // 2, by - b_h + 2)])
            # 지붕 하이라이트 (달빛)
            pygame.draw.line(surf, (roof_c[0] + 15, roof_c[1] + 10, roof_c[2] + 12, alpha),
                             (bx - roof_w // 2, by - b_h + 2),
                             (bx, by - b_h - roof_h), 1)
            # 금 장식 (지붕 꼭대기)
            pygame.draw.circle(surf, (108, 90, 48, alpha),
                               (bx, by - b_h - roof_h), max(1, 2))
            # 만다라 문양 (벽면)
            for _ in range(random.randint(2, 4)):
                dx = bx + random.randint(-b_w // 3, b_w // 3)
                dy = by - random.randint(12, b_h - 10)
                dr = max(2, random.randint(2, 5))
                pygame.draw.circle(surf, (70, 65, 85, alpha), (dx, dy), dr, 1)
                if dr > 3:
                    pygame.draw.circle(surf, (80, 75, 95, alpha), (dx, dy), max(1, dr - 2), 1)
            # 벽면 문자 패널
            panel_count = random.randint(1, 3)
            for pi_p in range(panel_count):
                py_p = by - b_h + random.randint(b_h // 4, max(b_h // 4 + 1, b_h * 3 // 4))
                pw = min(b_w - 6, random.randint(12, 28))
                ph = random.randint(6, 10)
                px_p = bx - pw // 2 + random.randint(-3, 3)
                pygame.draw.rect(surf, (wall_c[0] - 5, wall_c[1] - 4, wall_c[2] - 3, alpha),
                                 (px_p, py_p, pw, ph))
                pygame.draw.rect(surf, (70, 65, 85, alpha),
                                 (px_p, py_p, pw, ph), 1)
                tx_g = px_p + 2
                ty_g = py_p + max(1, (ph - 5) // 2)
                for ci_g in range(max(1, pw // 7)):
                    if tx_g + 5 > px_p + pw - 1:
                        break
                    glyph = random.choice(tibetan_glyphs)
                    for dx, dy, dw, dh in glyph:
                        pygame.draw.rect(surf, (80, 75, 100, min(255, int(alpha * 0.7))),
                                         (tx_g + dx, ty_g + dy, dw, dh))
                    tx_g += random.randint(5, 7)
            # 문 (HD — 아치 + 장식)
            door_w = max(5, b_w // 4)
            door_h = max(10, b_h // 4)
            pygame.draw.rect(surf, (15, 12, 25, alpha),
                             (bx - door_w // 2, by - door_h - 8, door_w, door_h))
            pygame.draw.rect(surf, (70, 65, 85, alpha),
                             (bx - door_w // 2, by - door_h - 8, door_w, door_h), 1)
            # 문 안쪽 따뜻한 빛
            door_glow = pygame.Surface((door_w + 4, door_h + 4), pygame.SRCALPHA)
            pygame.draw.rect(door_glow, (180, 100, 40, 20), (0, 0, door_w + 4, door_h + 4))
            surf.blit(door_glow, (bx - door_w // 2 - 2, by - door_h - 10))
            # 빨간 등롱 (사원 입구)
            if random.random() < 0.6:
                for lside in [-1, 1]:
                    lx_l = bx + lside * (b_w // 3)
                    ly_l = by - b_h + b_h // 4
                    # 등롱 본체
                    lr_l = max(2, random.randint(3, 5))
                    pygame.draw.ellipse(surf, (200, 45, 30, min(255, int(alpha * 0.85))),
                                        (lx_l - lr_l, ly_l - lr_l, lr_l * 2, lr_l * 2 + 2))
                    # 글로우
                    glow_s = pygame.Surface((lr_l * 5, lr_l * 5), pygame.SRCALPHA)
                    pygame.draw.circle(glow_s, (255, 60, 40, 30),
                                       (lr_l * 5 // 2, lr_l * 5 // 2), lr_l * 2)
                    surf.blit(glow_s, (lx_l - lr_l * 5 // 2, ly_l - lr_l * 5 // 2))

        # ===== 수호 사자상 (석조 — 어두운 돌) =====
        for gi in range(6):
            gx = int(W * (0.08 + gi * 0.16 + random.uniform(-0.04, 0.04)))
            gy = int(H * random.uniform(0.55, 0.88))
            if _in_center(gx, gy):
                continue
            g_h = random.randint(10, 18)
            g_w = max(6, g_h * 2 // 3)
            gc = (55, 50, 70)
            # 기단
            pygame.draw.rect(surf, (45, 40, 58, alpha),
                             (gx - g_w // 2 - 2, gy - 2, g_w + 4, 3))
            # 몸통
            pygame.draw.ellipse(surf, (*gc, alpha),
                                (gx - g_w // 2, gy - g_h, g_w, g_h))
            # 머리
            head_r = max(2, g_w // 3)
            pygame.draw.circle(surf, (*gc, alpha),
                               (gx, gy - g_h - head_r + 3), head_r)
            # 달빛 하이라이트
            pygame.draw.circle(surf, (gc[0] + 20, gc[1] + 18, gc[2] + 22, alpha),
                               (gx - 1, gy - g_h - head_r + 2), max(1, head_r - 1), 1)

        # ===== 나무 실루엣 (어두운 소나무/대나무) =====
        for ti in range(18):
            tx = int(W * (0.02 + ti * 0.055 + random.uniform(-0.02, 0.02)))
            ty = int(H * random.uniform(0.35, 0.92))
            if _in_center(tx, ty):
                continue
            tree_type = random.randint(0, 2)
            trunk_h = random.randint(35, 70)
            trunk_c = (18 + random.randint(0, 8), 22 + random.randint(0, 8),
                       16 + random.randint(0, 6))

            if tree_type == 0:
                # 소나무 실루엣 (삼각 캐노피)
                pygame.draw.line(surf, (*trunk_c, alpha),
                                 (tx, ty), (tx, ty - trunk_h), max(2, 3))
                # 삼각 캐노피 (3단)
                for ci in range(3):
                    cw = 12 + (2 - ci) * 6
                    ch = max(6, trunk_h // 4)
                    cy = ty - trunk_h + ci * ch // 2 + 3
                    pygame.draw.polygon(surf, (15 + ci * 3, 20 + ci * 3, 12 + ci * 2, alpha),
                                        [(tx - cw // 2, cy + ch),
                                         (tx, cy),
                                         (tx + cw // 2, cy + ch)])
            elif tree_type == 1:
                # 대나무 (가늘고 높은)
                for bi_bam in range(random.randint(2, 4)):
                    bx_b = tx + random.randint(-4, 4)
                    pygame.draw.line(surf, (20, 28, 18, alpha),
                                     (bx_b, ty), (bx_b, ty - trunk_h), 1)
                    # 마디
                    for ni in range(3, trunk_h - 3, max(5, trunk_h // 6)):
                        pygame.draw.line(surf, (25, 35, 22, alpha),
                                         (bx_b - 1, ty - ni), (bx_b + 1, ty - ni), 1)
                    # 잎
                    if random.random() < 0.6:
                        lfy = ty - trunk_h + random.randint(0, trunk_h // 3)
                        for _ in range(random.randint(2, 4)):
                            l_ang = random.uniform(-0.8, 0.8)
                            ll = random.randint(5, 12)
                            pygame.draw.line(surf, (18, 25, 16, alpha),
                                             (bx_b, lfy),
                                             (bx_b + int(ll * math.cos(l_ang)),
                                              lfy + int(ll * math.sin(l_ang))), 1)
            else:
                # 넓은 나무 실루엣
                pygame.draw.line(surf, (*trunk_c, alpha),
                                 (tx, ty), (tx, ty - trunk_h), max(2, 3))
                # 둥근 캐노피
                for ci in range(random.randint(4, 8)):
                    cr = random.randint(6, 14)
                    c_off_x = random.randint(-12, 12)
                    c_off_y = random.randint(-10, 4)
                    cc = (12 + random.randint(0, 8), 16 + random.randint(0, 8),
                          10 + random.randint(0, 6))
                    pygame.draw.circle(surf, (*cc, min(255, int(alpha * 0.75))),
                                       (tx + c_off_x, ty - trunk_h + c_off_y), cr)

        # ===== 만다라 / 석조 문양 (지면 장식) =====
        for mi in range(14):
            mx = random.randint(20, W - 20)
            my = random.randint(int(H * 0.5), H - 15)
            if _in_center(mx, my):
                continue
            mr = random.randint(8, 18)
            mc = (60, 55, 80, min(255, int(alpha * 0.4)))
            # 동심원
            for ri in range(3):
                rr = mr - ri * max(2, mr // 4)
                if rr < 2:
                    break
                ms = pygame.Surface((rr * 2 + 2, rr * 2 + 2), pygame.SRCALPHA)
                pygame.draw.circle(ms, mc, (rr + 1, rr + 1), rr, 1)
                surf.blit(ms, (mx - rr - 1, my - rr - 1))
            # 방사선
            for i in range(8):
                ang = i * math.pi / 4
                lx = mx + int(mr * 0.8 * math.cos(ang))
                ly = my + int(mr * 0.8 * math.sin(ang))
                ls = pygame.Surface((abs(lx - mx) * 2 + 4, abs(ly - my) * 2 + 4), pygame.SRCALPHA)
                pygame.draw.line(ls, (70, 65, 90, min(255, int(alpha * 0.3))),
                                 (ls.get_width() // 2, ls.get_height() // 2),
                                 (ls.get_width() // 2 + lx - mx, ls.get_height() // 2 + ly - my), 1)
                surf.blit(ls, (min(mx, lx) - 2, min(my, ly) - 2))

        # ===== 빨간 등롱 (독립 — 사원 사이) =====
        for li in range(12):
            lx_la = random.randint(15, W - 15)
            ly_la = random.randint(int(H * 0.35), H - 15)
            if _in_center(lx_la, ly_la):
                continue
            # 등롱 줄
            pole_h = random.randint(15, 30)
            pygame.draw.line(surf, (30, 25, 40, alpha),
                             (lx_la, ly_la), (lx_la, ly_la - pole_h), 1)
            # 등롱
            lr_la = max(2, random.randint(3, 6))
            lantern_y = ly_la - pole_h
            pygame.draw.ellipse(surf, (200, 45, 30, min(255, int(alpha * 0.85))),
                                (lx_la - lr_la, lantern_y - lr_la,
                                 lr_la * 2, lr_la * 2 + 3))
            # 등롱 줄무늬
            pygame.draw.line(surf, (220, 60, 40, alpha),
                             (lx_la - lr_la, lantern_y), (lx_la + lr_la, lantern_y), 1)
            # 글로우
            glow_s = pygame.Surface((lr_la * 6, lr_la * 6), pygame.SRCALPHA)
            pygame.draw.circle(glow_s, (255, 60, 40, 25),
                               (lr_la * 3, lr_la * 3), lr_la * 3)
            pygame.draw.circle(glow_s, (255, 80, 50, 45),
                               (lr_la * 3, lr_la * 3), lr_la * 2)
            surf.blit(glow_s, (lx_la - lr_la * 3, lantern_y - lr_la * 3))

        # ===== 향로 / 촛불 (사원 주변 — 따뜻한 빛) =====
        for ii in range(16):
            ix_i = random.randint(15, W - 15)
            iy_i = random.randint(int(H * 0.45), H - 8)
            if _in_center(ix_i, iy_i):
                continue
            itype = random.randint(0, 1)
            if itype == 0:
                # 향로 (어두운 석재)
                ir = max(3, random.randint(4, 8))
                pygame.draw.ellipse(surf, (55, 50, 65, alpha),
                                    (ix_i - ir, iy_i - ir // 3, ir * 2, ir))
                pygame.draw.rect(surf, (45, 40, 55, alpha),
                                 (ix_i - ir // 2, iy_i + ir // 2, ir, max(2, ir // 3)))
                # 연기 (은빛)
                for si in range(3):
                    sy = iy_i - ir // 3 - si * max(3, ir // 2)
                    sx = ix_i + random.randint(-2, 2) + si * random.randint(-2, 2)
                    smoke_s = pygame.Surface((6, 6), pygame.SRCALPHA)
                    sa = max(1, 60 - si * 18)
                    pygame.draw.circle(smoke_s, (150, 140, 170, sa), (3, 3), 3)
                    surf.blit(smoke_s, (sx - 3, sy - 3))
            else:
                # 촛불
                candle_h = random.randint(5, 12)
                pygame.draw.rect(surf, (180, 160, 120, alpha),
                                 (ix_i - 1, iy_i - candle_h, 3, candle_h))
                # 불꽃
                flame_s = pygame.Surface((8, 10), pygame.SRCALPHA)
                pygame.draw.ellipse(flame_s, (255, 180, 50, 180), (1, 0, 6, 8))
                pygame.draw.ellipse(flame_s, (255, 230, 140, 220), (2, 2, 4, 5))
                surf.blit(flame_s, (ix_i - 3, iy_i - candle_h - 8))
                # 글로우 (따뜻한 빛)
                glow_s = pygame.Surface((16, 16), pygame.SRCALPHA)
                pygame.draw.circle(glow_s, (255, 180, 60, 35), (8, 8), 8)
                surf.blit(glow_s, (ix_i - 7, iy_i - candle_h - 12))

        # ===== 석등/석탑 (작은 돌 구조물 — 어두운 석재) =====
        for li in range(14):
            lx = random.randint(20, W - 20)
            ly = random.randint(int(H * 0.5), H - 10)
            if _in_center(lx, ly):
                continue
            lantern_h = random.randint(14, 28)
            lw = max(4, lantern_h // 3)
            stone_c = (50, 45, 65)
            # 기단
            pygame.draw.rect(surf, (*stone_c, alpha),
                             (lx - lw, ly - 3, lw * 2, 3))
            # 기둥
            pygame.draw.rect(surf, (stone_c[0] + 8, stone_c[1] + 6, stone_c[2] + 10, alpha),
                             (lx - lw // 3, ly - lantern_h, lw * 2 // 3, lantern_h - 3))
            # 등불 부분
            lamp_h = max(4, lantern_h // 4)
            pygame.draw.rect(surf, (65, 58, 80, alpha),
                             (lx - lw // 2 - 1, ly - lantern_h - lamp_h,
                              lw + 2, lamp_h))
            # 빛 (따뜻한 빛)
            light_s = pygame.Surface((lw * 2, lamp_h * 2), pygame.SRCALPHA)
            pygame.draw.ellipse(light_s, (255, 180, 80, 40),
                                (0, 0, lw * 2, lamp_h * 2))
            surf.blit(light_s, (lx - lw, ly - lantern_h - lamp_h - lamp_h // 2))
            # 지붕 (뾰족)
            roof_h = max(3, lantern_h // 5)
            pygame.draw.polygon(surf, (*stone_c, alpha),
                                [(lx - lw // 2 - 2, ly - lantern_h - lamp_h),
                                 (lx, ly - lantern_h - lamp_h - roof_h),
                                 (lx + lw // 2 + 2, ly - lantern_h - lamp_h)])

        # ===== 기도 깃발 (티베트 스타일 — 오색) =====
        for fi in range(18):
            fx = random.randint(10, W - 10)
            fy = random.randint(int(H * 0.3), H - 15)
            if _in_center(fx, fy):
                continue
            flag_h = random.randint(6, 12)
            flag_w = random.randint(4, 8)
            pole_h = random.randint(15, 30)
            # 깃대
            pygame.draw.line(surf, (35, 30, 45, alpha),
                             (fx, fy), (fx, fy - pole_h), max(1, 2))
            # 깃발 (티베트 오색)
            flag_c = random.choice([
                (180, 50, 40), (220, 180, 50), (50, 100, 180),
                (180, 180, 180), (50, 130, 50),
            ])
            flag_pts = [
                (fx, fy - pole_h),
                (fx + flag_w + int(math.sin(fy * 0.1) * 2), fy - pole_h + flag_h // 3),
                (fx + flag_w - 1, fy - pole_h + flag_h * 2 // 3),
                (fx, fy - pole_h + flag_h),
            ]
            pygame.draw.polygon(surf, (*flag_c, min(255, int(alpha * 0.6))), flag_pts)

        # ===== 석조 참배로 (HD — 어두운 돌길) =====
        for pi_r in range(4):
            path_x = int(W * (0.15 + pi_r * 0.22 + random.uniform(-0.04, 0.04)))
            path_y_s = int(H * 0.45)
            path_y_e = int(H * 0.95)
            path_w = random.randint(10, 16)
            py_r = path_y_s
            while py_r < path_y_e:
                px_r = path_x + int(math.sin(py_r * 0.02 + pi_r * 2) * 12)
                if not _in_center(px_r, py_r):
                    pygame.draw.line(surf, (40, 36, 55, min(255, int(alpha * 0.4))),
                                     (px_r - path_w // 2, py_r), (px_r + path_w // 2, py_r), 1)
                    if py_r % 6 == 0:
                        pygame.draw.line(surf, (50, 45, 65, min(255, int(alpha * 0.3))),
                                         (px_r - path_w // 2, py_r), (px_r + path_w // 2, py_r), 1)
                py_r += 2

        # ===== 종탑 / 범종 (어두운 석재) =====
        for bi_b in range(4):
            bx_b = int(W * (0.1 + bi_b * 0.25 + random.uniform(-0.05, 0.05)))
            by_b = int(H * random.uniform(0.5, 0.85))
            if _in_center(bx_b, by_b):
                continue
            bell_h = random.randint(18, 32)
            bell_w = max(8, bell_h // 2)
            # 기둥 (2개)
            pygame.draw.line(surf, (42, 38, 55, alpha),
                             (bx_b - bell_w // 2, by_b), (bx_b - bell_w // 2, by_b - bell_h), 2)
            pygame.draw.line(surf, (42, 38, 55, alpha),
                             (bx_b + bell_w // 2, by_b), (bx_b + bell_w // 2, by_b - bell_h), 2)
            # 지붕 (어두운 붉은)
            pygame.draw.polygon(surf, (50, 28, 32, alpha),
                                [(bx_b - bell_w // 2 - 3, by_b - bell_h),
                                 (bx_b, by_b - bell_h - 6),
                                 (bx_b + bell_w // 2 + 3, by_b - bell_h)])
            # 종 (어두운 금색)
            bell_r = max(3, bell_w // 3)
            pygame.draw.circle(surf, (108, 90, 48, alpha),
                               (bx_b, by_b - bell_h + bell_h // 3), bell_r)
            pygame.draw.circle(surf, (130, 110, 60, alpha),
                               (bx_b, by_b - bell_h + bell_h // 3), max(1, bell_r - 1), 1)

        # ===== 참배자 실루엣 (어두운) =====
        for pi_d in range(16):
            dx_d = random.randint(10, W - 10)
            dy_d = random.randint(int(H * 0.5), H - 5)
            if _in_center(dx_d, dy_d):
                continue
            d_h = random.randint(8, 15)
            d_w = max(3, d_h // 3)
            d_c = (22 + random.randint(0, 12), 18 + random.randint(0, 10),
                   30 + random.randint(0, 12))
            # 몸 (로브)
            pygame.draw.ellipse(surf, (*d_c, min(255, int(alpha * 0.5))),
                                (dx_d - d_w // 2, dy_d - d_h // 3, d_w, d_h * 2 // 3))
            # 머리
            head_r = max(2, d_w // 2)
            pygame.draw.circle(surf, (*d_c, min(255, int(alpha * 0.5))),
                               (dx_d, dy_d - d_h // 2 - head_r + 2), head_r)
            # 승려 로브 (어두운 적갈색 — 일부만)
            if random.random() < 0.4:
                robe_c = random.choice([(100, 45, 25), (90, 40, 20), (110, 50, 30)])
                pygame.draw.ellipse(surf, (*robe_c, min(255, int(alpha * 0.3))),
                                    (dx_d - d_w // 2, dy_d - d_h // 3, d_w, d_h * 2 // 3))

        # ===== 반딧불 파티클 (은빛 + 보라빛) =====
        if t > 0.4:
            spark_count = int(35 * min(1.0, (t - 0.4) / 0.4))
            for _ in range(spark_count):
                sx = random.randint(0, W)
                sy = random.randint(int(H * 0.3), H)
                sr = max(1, random.randint(1, 2))
                sa = random.randint(80, 180)
                sc = random.choice([
                    (180, 200, 255), (200, 180, 255), (240, 235, 255),
                    (150, 170, 220),
                ])
                spark_s = pygame.Surface((sr * 4, sr * 4), pygame.SRCALPHA)
                pygame.draw.circle(spark_s, (*sc, sa // 3),
                                   (sr * 2, sr * 2), sr * 2)
                pygame.draw.circle(spark_s, (*sc, min(255, sa)),
                                   (sr * 2, sr * 2), sr)
                surf.blit(spark_s, (sx - sr * 2, sy - sr * 2))

        # ===== 안개/미스트 (보라빛 밤안개) =====
        mist_a = max(0, int(100 * (1.0 - t * 2.0) * alpha / 255))
        if mist_a > 2:
            random.seed(41379)
            for _ in range(18):
                mx = random.randint(-40, W + 40)
                my = random.randint(-20, H + 20)
                mw = random.randint(60, 170)
                mh = random.randint(18, 45)
                mc = random.choice([
                    (25, 20, 42), (30, 25, 48), (22, 18, 38),
                    (28, 22, 45),
                ])
                ms = pygame.Surface((mw, mh), pygame.SRCALPHA)
                pygame.draw.ellipse(ms, (*mc, min(255, mist_a)),
                                    (0, 0, mw, mh))
                inner_w = mw * 2 // 3
                inner_h = mh * 2 // 3
                pygame.draw.ellipse(ms, (*mc, min(255, mist_a // 2)),
                                    (mw // 6, mh // 6, inner_w, inner_h))
                surf.blit(ms, (mx - mw // 2, my - mh // 2))
            random.seed()

        # ===== 구름 (HD 다층 — 어두운 보라빛) =====
        cloud_a = max(0, int(150 * (1.0 - t * 2.5) * alpha / 255))
        if cloud_a > 3:
            random.seed(41380)
            for _ in range(16):
                cx_c = random.randint(-40, W + 40)
                cy_c = random.randint(-20, H + 20)
                cw_c = random.randint(50, 150)
                ch_c = random.randint(14, 40)
                cc = random.choice([
                    (18, 14, 32), (22, 18, 38), (15, 12, 28),
                    (20, 16, 35),
                ])
                cs = pygame.Surface((cw_c, ch_c), pygame.SRCALPHA)
                pygame.draw.ellipse(cs, (*cc, min(255, cloud_a)),
                                    (0, 0, cw_c, ch_c))
                top_h = max(2, ch_c // 4)
                pygame.draw.ellipse(cs, (cc[0] + 10, cc[1] + 8, cc[2] + 12,
                                         max(1, cloud_a // 3)),
                                    (8, 2, cw_c - 16, top_h))
                surf.blit(cs, (cx_c - cw_c // 2, cy_c - ch_c // 2))
            random.seed()

        # ===== 대기 오버레이 (보라빛 밤 분위기) =====
        haze_a = max(0, int(45 * (1.0 - t * 2.5) * alpha / 255))
        if haze_a > 2:
            haze = pygame.Surface((W, H), pygame.SRCALPHA)
            haze.fill((15, 10, 30, haze_a))
            surf.blit(haze, (0, 0))

    def _draw_surface_colosseum(self, surf, t, alpha=255):
        """투기장/콜로세움 행성 표면 — 초고퀄리티. Stage 30 테마.
        t: 0(고공) ~ 1(지표면). 로마 콜로세움 + 이집트 장식 + 모래 지형.
        pillar_colosseum.py 매칭: 베이지/탄/골드 팔레트."""
        W, H = surf.get_width(), surf.get_height()
        _cz_x, _cz_y = W // 2, H // 2
        _cz_hw, _cz_hh = 150, 120
        def _in_center(px, py):
            return abs(px - _cz_x) < _cz_hw and abs(py - _cz_y) < _cz_hh

        # ===== 기본 지형 — HD 그라디언트 (따듯한 모래/석조 야경) =====
        sky_top = (15, 12, 28)        # 깊은 밤하늘 (보라빛)
        sky_mid = (35, 28, 48)        # 따뜻한 밤하늘
        ground_mid = (95, 80, 58)     # 모래빛 대지
        ground_bot = (75, 62, 42)     # 어두운 모래
        for y in range(H):
            fy = y / max(1, H - 1)
            if fy < 0.3:
                ft = fy / 0.3
                r = int(sky_top[0] + (sky_mid[0] - sky_top[0]) * ft)
                g = int(sky_top[1] + (sky_mid[1] - sky_top[1]) * ft)
                b = int(sky_top[2] + (sky_mid[2] - sky_top[2]) * ft)
            elif fy < 0.55:
                ft = (fy - 0.3) / 0.25
                r = int(sky_mid[0] + (ground_mid[0] - sky_mid[0]) * ft)
                g = int(sky_mid[1] + (ground_mid[1] - sky_mid[1]) * ft)
                b = int(sky_mid[2] + (ground_mid[2] - sky_mid[2]) * ft)
            else:
                ft = (fy - 0.55) / 0.45
                r = int(ground_mid[0] + (ground_bot[0] - ground_mid[0]) * ft)
                g = int(ground_mid[1] + (ground_bot[1] - ground_mid[1]) * ft)
                b = int(ground_mid[2] + (ground_bot[2] - ground_mid[2]) * ft)
            pygame.draw.line(surf, (r, g, b, alpha), (0, y), (W, y))

        # ===== 별 (60개 — 따뜻한 밤하늘) =====
        random.seed(30001)
        star_a = max(0, int(alpha * (1.0 - t * 1.8)))
        if star_a > 5:
            for _ in range(60):
                sx = random.randint(0, W)
                sy = random.randint(0, int(H * 0.3))
                if _in_center(sx, sy):
                    continue
                sr = 1
                sc = random.choice([
                    (255, 240, 200), (255, 230, 180), (240, 220, 190),
                    (255, 250, 220), (230, 210, 175),
                ])
                sa = min(255, star_a - random.randint(0, 40))
                if sa > 3:
                    pygame.draw.circle(surf, (*sc, sa), (sx, sy), sr)
                    # 밝은 별 십자
                    if random.random() < 0.2:
                        cr = random.randint(1, 2)
                        pygame.draw.line(surf, (*sc, max(1, sa // 2)),
                                         (sx - cr, sy), (sx + cr, sy), 1)
                        pygame.draw.line(surf, (*sc, max(1, sa // 2)),
                                         (sx, sy - cr), (sx, sy + cr), 1)
        random.seed()

        random.seed(30010)

        # ===== 모래 지형 패치 =====
        sand_colors = [
            (125, 105, 75), (145, 120, 88), (110, 92, 65),
            (155, 130, 95), (135, 112, 80), (165, 140, 105),
        ]
        for _ in range(100):
            px = random.randint(0, W)
            py = random.randint(0, H)
            pr = random.randint(18, 80)
            if _in_center(px, py):
                continue
            pc = sand_colors[random.randint(0, 5)]
            ps = pygame.Surface((pr * 2, pr * 2), pygame.SRCALPHA)
            pygame.draw.circle(ps, (*pc, min(255, int(alpha * 0.4))),
                               (pr, pr), pr)
            surf.blit(ps, (px - pr, py - pr))

        # ===== 미세 모래 질감 =====
        for _ in range(350):
            tx = random.randint(0, W)
            ty = random.randint(0, H)
            tc = (random.randint(80, 150), random.randint(65, 125),
                  random.randint(45, 90))
            pygame.draw.circle(surf, (*tc, min(255, int(alpha * 0.4))),
                               (tx, ty), random.randint(1, 2))

        # ===== 원경 — 콜로세움 외벽 스카이라인 (3단 깊이) =====
        skyline_a = max(0, int(alpha * 0.45))
        if skyline_a > 2:
            # 1단: 먼 산/언덕
            for ci in range(10):
                hx = int(W * (0.02 + ci * 0.1 + random.uniform(-0.03, 0.03)))
                hy = int(H * random.uniform(0.15, 0.25))
                hw = random.randint(60, 150)
                hh = random.randint(30, 70)
                if _in_center(hx, hy):
                    continue
                hc = (25 + random.randint(0, 10), 20 + random.randint(0, 8),
                      35 + random.randint(0, 12))
                hs = pygame.Surface((hw, hh), pygame.SRCALPHA)
                pygame.draw.ellipse(hs, (*hc, max(1, skyline_a // 2)),
                                    (0, hh // 4, hw, hh))
                surf.blit(hs, (hx - hw // 2, hy - hh // 2))

            # 2단: 먼 로마 건축물 실루엣
            for ci in range(14):
                cx = int(W * (0.01 + ci * 0.072 + random.uniform(-0.02, 0.02)))
                base_y = int(H * random.uniform(0.2, 0.35))
                b_h = random.randint(50, 140)
                b_w = random.randint(16, 42)
                if _in_center(cx, base_y):
                    continue
                sc = (55 + random.randint(0, 15), 45 + random.randint(0, 12),
                      32 + random.randint(0, 10))
                pygame.draw.rect(surf, (*sc, max(1, skyline_a // 2)),
                                 (cx - b_w // 2, base_y - b_h, b_w, b_h))
                # 아치 창문
                for wy in range(base_y - b_h + 6, base_y - 3, max(5, b_h // 10)):
                    for wx in range(cx - b_w // 2 + 3, cx + b_w // 2 - 2, max(5, b_w // 4)):
                        if random.random() < 0.5:
                            arc_h = max(3, b_h // 15)
                            arc_w = max(2, b_w // 8)
                            # 아치 (반원 + 직사각)
                            pygame.draw.rect(surf, (35, 28, 22, max(1, skyline_a // 3)),
                                             (wx, wy, arc_w, arc_h))
                            pygame.draw.arc(surf, (35, 28, 22, max(1, skyline_a // 3)),
                                            (wx, wy - arc_h // 2, arc_w, arc_h),
                                            0, 3.14, 1)
                # 꼭대기 삼각 박공
                if random.random() < 0.4:
                    pygame.draw.polygon(surf, (*sc, max(1, skyline_a // 2)),
                                        [(cx - b_w // 2 - 2, base_y - b_h),
                                         (cx + b_w // 2 + 2, base_y - b_h),
                                         (cx, base_y - b_h - random.randint(8, 22))])

            # 3단: 큰 콜로세움 구조물 (2개)
            for side in [-1, 1]:
                col_cx = int(W * (0.22 if side < 0 else 0.78))
                col_cy = int(H * 0.3)
                col_w = random.randint(60, 100)
                col_h = random.randint(50, 90)
                if _in_center(col_cx, col_cy):
                    continue
                col_c = (70 + random.randint(0, 12), 58 + random.randint(0, 10),
                         42 + random.randint(0, 8))
                # 타원형 콜로세움 윤곽
                pygame.draw.ellipse(surf, (*col_c, skyline_a),
                                    (col_cx - col_w // 2, col_cy - col_h // 2,
                                     col_w, col_h))
                # 내부 어둠
                inner_w = col_w * 3 // 4
                inner_h = col_h * 3 // 4
                pygame.draw.ellipse(surf, (col_c[0] - 20, col_c[1] - 16,
                                           col_c[2] - 12, max(1, skyline_a - 20)),
                                    (col_cx - inner_w // 2, col_cy - inner_h // 2,
                                     inner_w, inner_h))
                # 아치 링 (콜로세움 외벽)
                arch_count = max(6, col_w // 6)
                for ai in range(arch_count):
                    angle = (ai / arch_count) * math.pi * 2
                    ax = col_cx + int(col_w // 2 * 0.85 * math.cos(angle))
                    ay = col_cy + int(col_h // 2 * 0.85 * math.sin(angle))
                    pygame.draw.circle(surf, (col_c[0] - 10, col_c[1] - 8,
                                              col_c[2] - 6, max(1, skyline_a // 2)),
                                       (ax, ay), max(1, col_w // 20))

        # ===== 수평 더스트 밴드 (모래 먼지 빛 번짐) =====
        for fi in range(6):
            fog_y = int(H * (0.2 + fi * 0.1))
            fog_a = max(0, int(30 * math.sin(fi * 1.1 + 0.5) * alpha / 255))
            if fog_a > 1:
                fc = random.choice([
                    (100, 80, 50), (120, 95, 60), (90, 72, 45),
                    (110, 88, 55), (130, 105, 65),
                ])
                fog_h = max(1, int(20 + fi * 5))
                fog_s = pygame.Surface((W, fog_h), pygame.SRCALPHA)
                fog_s.fill((*fc, fog_a))
                surf.blit(fog_s, (0, fog_y))

        # ===== 도로/통로 (석조 포장도로 — 로마 비아) =====
        for ri in range(2):
            road_x = int(W * (0.3 + ri * 0.4 + random.uniform(-0.05, 0.05)))
            road_y_start = int(H * 0.25)
            road_y_end = int(H * 0.96)
            road_w = random.randint(14, 22)
            r_pts = []
            ry = road_y_start
            while ry < road_y_end:
                rx = road_x + int(math.sin(ry * 0.01 + ri * 3) * 12)
                r_pts.append((rx, ry))
                ry += 2
            # 석재 포장
            for px, py in r_pts:
                if _in_center(px, py):
                    continue
                pygame.draw.line(surf, (90, 78, 58, alpha),
                                 (px - road_w // 2, py), (px + road_w // 2, py), 1)
            # 경계석
            for px, py in r_pts[::4]:
                if not _in_center(px, py):
                    pygame.draw.circle(surf, (120, 105, 80, min(255, int(alpha * 0.5))),
                                       (px - road_w // 2, py), 1)
                    pygame.draw.circle(surf, (120, 105, 80, min(255, int(alpha * 0.5))),
                                       (px + road_w // 2, py), 1)
            # 벽돌 패턴
            for i in range(0, len(r_pts), 6):
                if i < len(r_pts):
                    px, py = r_pts[i]
                    if not _in_center(px, py):
                        pygame.draw.line(surf, (105, 90, 68, min(255, int(alpha * 0.4))),
                                         (px, py), (px, py + 3), 1)

        # ===== 중경 건물 — 로마 석조 건축물 (기둥, 아치, 신전) =====
        for bi in range(18):
            bx = int(W * (0.01 + bi * 0.055 + random.uniform(-0.015, 0.015)))
            by = int(H * random.uniform(0.3, 0.85))
            if _in_center(bx, by):
                continue
            b_w = random.randint(20, 52)
            b_h = random.randint(40, 110)
            wall_c = random.choice([
                (150, 130, 100), (165, 145, 112), (140, 120, 90),
                (175, 155, 120), (155, 135, 105), (160, 140, 108),
            ])
            # 그림자
            sh_s = pygame.Surface((b_w + 6, 6), pygame.SRCALPHA)
            pygame.draw.ellipse(sh_s, (0, 0, 0, min(255, int(alpha * 0.3))),
                                (0, 0, b_w + 6, 6))
            surf.blit(sh_s, (bx - b_w // 2 - 3, by - 1))
            # 벽체
            pygame.draw.rect(surf, (*wall_c, alpha),
                             (bx - b_w // 2, by - b_h, b_w, b_h))
            # 석재 줄 (수평)
            for ty in range(by - b_h + 4, by - 1, max(4, b_h // 12)):
                pygame.draw.line(surf, (wall_c[0] - 8, wall_c[1] - 6, wall_c[2] - 5, alpha),
                                 (bx - b_w // 2, ty), (bx + b_w // 2, ty), 1)
            # 밝은 면 (좌측)
            pygame.draw.rect(surf, (wall_c[0] + 12, wall_c[1] + 10, wall_c[2] + 8, alpha),
                             (bx - b_w // 2, by - b_h, max(2, b_w // 5), b_h))

            b_type = random.random()
            if b_type < 0.35:
                # 신전 (삼각 박공 + 기둥)
                # 박공
                pediment_h = max(5, b_h // 6)
                pygame.draw.polygon(surf, (wall_c[0] + 5, wall_c[1] + 3, wall_c[2] + 2, alpha),
                                    [(bx - b_w // 2 - 2, by - b_h),
                                     (bx + b_w // 2 + 2, by - b_h),
                                     (bx, by - b_h - pediment_h)])
                # 기둥 (2~4개)
                col_count = max(2, b_w // 12)
                for ci_p in range(col_count):
                    cx_p = bx - b_w // 2 + 3 + ci_p * max(4, (b_w - 6) // max(1, col_count - 1))
                    col_w = max(2, b_w // 12)
                    # 기둥 본체
                    pygame.draw.rect(surf, (wall_c[0] + 8, wall_c[1] + 6, wall_c[2] + 5, alpha),
                                     (cx_p, by - b_h + 3, col_w, b_h - 4))
                    # 주두 (기둥 머리)
                    pygame.draw.rect(surf, (wall_c[0] + 15, wall_c[1] + 12, wall_c[2] + 10, alpha),
                                     (cx_p - 1, by - b_h + 2, col_w + 2, 3))
                    # 기둥 세로 홈
                    pygame.draw.line(surf, (wall_c[0] - 4, wall_c[1] - 3, wall_c[2] - 2, alpha),
                                     (cx_p + col_w // 2, by - b_h + 5),
                                     (cx_p + col_w // 2, by - 2), 1)
            elif b_type < 0.65:
                # 아치 건물 (여러 아치)
                arch_count = max(2, b_w // 10)
                for ai in range(arch_count):
                    ax = bx - b_w // 2 + 3 + ai * max(4, (b_w - 6) // max(1, arch_count))
                    aw = max(3, (b_w - 6) // max(1, arch_count) - 2)
                    ah = max(6, b_h // 4)
                    ay = by - ah
                    # 아치 본체 (직사각 + 반원)
                    pygame.draw.rect(surf, (wall_c[0] - 20, wall_c[1] - 16, wall_c[2] - 12, alpha),
                                     (ax, ay, aw, ah))
                    pygame.draw.arc(surf, (wall_c[0] - 15, wall_c[1] - 12, wall_c[2] - 10, alpha),
                                    (ax, ay - ah // 2, aw, ah), 0, 3.14, 1)
                    # 키스톤 (아치 꼭대기)
                    pygame.draw.rect(surf, (160, 120, 50, alpha),
                                     (ax + aw // 2 - 1, ay - ah // 2, 3, 3))
            else:
                # 일반 석조 건물 (창문)
                for wy in range(by - b_h + 5, by - 4, max(4, b_h // 10)):
                    for wx in range(bx - b_w // 2 + 3, bx + b_w // 2 - 2, max(5, b_w // 5)):
                        if random.random() < 0.5:
                            ww = max(2, b_w // 10)
                            wh = max(3, b_h // 13)
                            # 아치형 창
                            pygame.draw.rect(surf, (40, 32, 22, min(255, int(alpha * 0.6))),
                                             (wx, wy, ww, wh))
                            pygame.draw.arc(surf, (40, 32, 22, min(255, int(alpha * 0.5))),
                                            (wx, wy - wh // 2, ww, wh), 0, 3.14, 1)
            # 꼭대기 장식선
            pygame.draw.rect(surf, (wall_c[0] - 10, wall_c[1] - 8, wall_c[2] - 6, alpha),
                             (bx - b_w // 2 - 1, by - b_h - 2, b_w + 2, 3))
            # 골드 코니스
            pygame.draw.line(surf, (200, 160, 80, min(255, int(alpha * 0.6))),
                             (bx - b_w // 2, by - b_h - 1),
                             (bx + b_w // 2, by - b_h - 1), 1)

        # ===== 횃불 (HD — 다중 글로우 + 불꽃) =====
        for li in range(10):
            lx = int(W * (0.06 + li * 0.09 + random.uniform(-0.02, 0.02)))
            ly = int(H * random.uniform(0.38, 0.9))
            if _in_center(lx, ly):
                continue
            torch_h = random.randint(24, 45)
            # 횃불대 (나무/금속)
            pygame.draw.line(surf, (80, 60, 40, alpha),
                             (lx, ly), (lx, ly - torch_h), 2)
            pygame.draw.line(surf, (100, 78, 52, alpha),
                             (lx + 1, ly), (lx + 1, ly - torch_h), 1)
            # 횃불 받침
            pygame.draw.rect(surf, (90, 70, 45, alpha),
                             (lx - 3, ly - torch_h - 2, 7, 4))
            # 불꽃 (다층)
            flame_h = random.randint(8, 16)
            flame_w = max(4, flame_h * 2 // 3)
            fs = pygame.Surface((flame_w * 2, flame_h * 2), pygame.SRCALPHA)
            # 외부 불꽃 (주황)
            pygame.draw.ellipse(fs, (255, 140, 30, min(255, int(alpha * 0.8))),
                                (flame_w // 4, flame_h // 2, flame_w * 3 // 2, flame_h))
            # 내부 불꽃 (노랑)
            pygame.draw.ellipse(fs, (255, 220, 80, min(255, int(alpha * 0.7))),
                                (flame_w // 3, flame_h * 2 // 3, flame_w, flame_h * 2 // 3))
            # 코어 (하양)
            pygame.draw.ellipse(fs, (255, 250, 200, min(255, int(alpha * 0.6))),
                                (flame_w * 2 // 5, flame_h, flame_w // 2, flame_h // 3))
            surf.blit(fs, (lx - flame_w, ly - torch_h - flame_h - 2))
            # 불꽃 글로우 (4중)
            for gi in range(4):
                gr = flame_h + 5 + gi * 6
                gs = pygame.Surface((gr * 2, gr * 2), pygame.SRCALPHA)
                gc = (255, 180 - gi * 20, 60 - gi * 15)
                pygame.draw.circle(gs, (*gc, max(1, 22 - gi * 5)),
                                   (gr, gr), gr)
                surf.blit(gs, (lx - gr, ly - torch_h - flame_h // 2 - gr))

        # ===== 오벨리스크/기둥 (독립) =====
        for oi in range(6):
            ox_o = random.randint(15, W - 15)
            oy_o = random.randint(int(H * 0.4), H - 8)
            if _in_center(ox_o, oy_o):
                continue
            ob_h = random.randint(30, 60)
            ob_w = max(3, random.randint(4, 8))
            ob_c = (170, 150, 118)
            # 기둥 본체
            pygame.draw.rect(surf, (*ob_c, alpha),
                             (ox_o - ob_w // 2, oy_o - ob_h, ob_w, ob_h))
            # 테이퍼 (위로 갈수록 좁아짐)
            pygame.draw.polygon(surf, (*ob_c, alpha),
                                [(ox_o - ob_w // 2, oy_o - ob_h),
                                 (ox_o + ob_w // 2, oy_o - ob_h),
                                 (ox_o + ob_w // 3, oy_o - ob_h - max(3, ob_h // 8)),
                                 (ox_o - ob_w // 3, oy_o - ob_h - max(3, ob_h // 8))])
            # 기둥 홈 (세로선)
            pygame.draw.line(surf, (ob_c[0] - 10, ob_c[1] - 8, ob_c[2] - 6, alpha),
                             (ox_o, oy_o - ob_h), (ox_o, oy_o), 1)
            # 주두
            pygame.draw.rect(surf, (ob_c[0] + 10, ob_c[1] + 8, ob_c[2] + 6, alpha),
                             (ox_o - ob_w // 2 - 1, oy_o - ob_h - 1, ob_w + 2, 3))
            # 기단
            pygame.draw.rect(surf, (ob_c[0] - 15, ob_c[1] - 12, ob_c[2] - 10, alpha),
                             (ox_o - ob_w // 2 - 2, oy_o - 2, ob_w + 4, 4))

        # ===== 석상/조각상 (로마 전사/신상) =====
        for si_s in range(5):
            stx = random.randint(20, W - 20)
            sty = random.randint(int(H * 0.42), H - 8)
            if _in_center(stx, sty):
                continue
            st_h = random.randint(18, 32)
            st_c = (170, 155, 135)
            st_a = min(255, int(alpha * 0.7))
            # 기단
            pygame.draw.rect(surf, (140, 125, 100, st_a),
                             (stx - 5, sty - 4, 10, 5))
            # 몸통
            pygame.draw.ellipse(surf, (*st_c, st_a),
                                (stx - 4, sty - st_h * 2 // 3, 8, st_h * 2 // 3))
            # 머리
            head_r = max(2, st_h // 8)
            pygame.draw.circle(surf, (*st_c, st_a),
                               (stx, sty - st_h + head_r), head_r)
            # 창/칼 (일부)
            if random.random() < 0.5:
                pygame.draw.line(surf, (180, 185, 195, st_a),
                                 (stx + 3, sty - st_h + head_r * 2),
                                 (stx + 3, sty - st_h - 4), 1)

        # ===== 관중 실루엣 (로마 시민) =====
        for pi in range(35):
            px = random.randint(8, W - 8)
            py = random.randint(int(H * 0.5), H - 4)
            if _in_center(px, py):
                continue
            p_h = random.randint(8, 16)
            p_w = max(3, p_h // 3)
            p_c = random.choice([
                (120, 50, 40), (50, 60, 120), (140, 110, 60),
                (80, 60, 40), (160, 140, 100), (100, 80, 55),
                (60, 80, 40), (120, 80, 60), (150, 120, 80),
            ])
            pa = min(255, int(alpha * 0.5))
            # 토가/의상
            pygame.draw.ellipse(surf, (*p_c, pa),
                                (px - p_w // 2, py - p_h // 3, p_w, p_h * 2 // 3))
            # 머리
            head_r_p = max(2, p_w // 2 + 1)
            skin_c = random.choice([
                (200, 170, 140), (180, 150, 120), (160, 130, 100),
                (220, 190, 160),
            ])
            pygame.draw.circle(surf, (*skin_c, pa),
                               (px, py - p_h // 2 - head_r_p + 2), head_r_p)

        # ===== 소품 (방패, 투구, 항아리, 깃발) =====
        for di in range(20):
            dx = random.randint(8, W - 8)
            dy = random.randint(int(H * 0.5), H - 4)
            if _in_center(dx, dy):
                continue
            dtype = random.randint(0, 3)
            da = min(255, int(alpha * 0.6))
            if dtype == 0:
                # 방패 (원형)
                sr = random.randint(3, 6)
                sc = random.choice([(160, 120, 50), (140, 50, 40), (50, 50, 120)])
                pygame.draw.circle(surf, (*sc, da), (dx, dy), sr)
                pygame.draw.circle(surf, (sc[0] + 20, sc[1] + 15, sc[2] + 10, da),
                                   (dx, dy), max(1, sr - 1), 1)
                # 움보 (중앙 돌기)
                pygame.draw.circle(surf, (200, 180, 120, da), (dx, dy), max(1, sr // 3))
            elif dtype == 1:
                # 깃발
                pole_h = random.randint(15, 28)
                pygame.draw.line(surf, (100, 85, 62, da),
                                 (dx, dy), (dx, dy - pole_h), 1)
                flag_c = random.choice([(180, 50, 40), (50, 50, 150), (200, 160, 60)])
                fw = max(4, random.randint(5, 10))
                fh = max(3, random.randint(4, 7))
                pygame.draw.rect(surf, (*flag_c, da),
                                 (dx + 1, dy - pole_h, fw, fh))
                # 깃발 줄무늬
                pygame.draw.line(surf, (flag_c[0] - 30, flag_c[1] - 20, flag_c[2] - 15, da),
                                 (dx + 1, dy - pole_h + fh // 2),
                                 (dx + 1 + fw, dy - pole_h + fh // 2), 1)
            elif dtype == 2:
                # 항아리/암포라
                jar_h = random.randint(6, 12)
                jar_w = max(3, jar_h // 2)
                jar_c = (180, 120, 70)
                pygame.draw.ellipse(surf, (*jar_c, da),
                                    (dx - jar_w // 2, dy - jar_h, jar_w, jar_h))
                # 목
                pygame.draw.rect(surf, (*jar_c, da),
                                 (dx - 1, dy - jar_h - 2, 3, 3))
                # 손잡이
                pygame.draw.arc(surf, (jar_c[0] - 10, jar_c[1] - 8, jar_c[2] - 5, da),
                                (dx - jar_w // 2 - 2, dy - jar_h, 4, jar_h // 2),
                                1.57, 4.71, 1)
            else:
                # 투구
                helm_r = random.randint(3, 5)
                pygame.draw.circle(surf, (160, 140, 100, da), (dx, dy), helm_r)
                pygame.draw.circle(surf, (180, 160, 120, da), (dx, dy), helm_r, 1)
                # 깃 (투구 위)
                pygame.draw.line(surf, (180, 50, 40, da),
                                 (dx, dy - helm_r), (dx, dy - helm_r - 4), 1)

        # ===== 이집트 히에로글리프 패턴 (지면 위 희미하게) =====
        for hgi in range(8):
            hgx = random.randint(15, W - 15)
            hgy = random.randint(int(H * 0.5), H - 10)
            if _in_center(hgx, hgy):
                continue
            hg_a = min(255, int(alpha * 0.2))
            hg_c = (175, 145, 80)
            hg_type = random.randint(0, 3)
            hg_s = random.randint(4, 8)
            if hg_type == 0:
                # 앙크 (생명의 열쇠)
                pygame.draw.circle(surf, (*hg_c, hg_a),
                                   (hgx, hgy - hg_s), max(1, hg_s // 2), 1)
                pygame.draw.line(surf, (*hg_c, hg_a),
                                 (hgx, hgy - hg_s + hg_s // 2),
                                 (hgx, hgy + hg_s), 1)
                pygame.draw.line(surf, (*hg_c, hg_a),
                                 (hgx - hg_s // 2, hgy),
                                 (hgx + hg_s // 2, hgy), 1)
            elif hg_type == 1:
                # 호루스의 눈
                pygame.draw.ellipse(surf, (*hg_c, hg_a),
                                    (hgx - hg_s, hgy - hg_s // 2, hg_s * 2, hg_s), 1)
                pygame.draw.circle(surf, (*hg_c, hg_a), (hgx, hgy), max(1, hg_s // 3))
                pygame.draw.line(surf, (*hg_c, hg_a),
                                 (hgx + hg_s, hgy), (hgx + hg_s + hg_s // 2, hgy + hg_s // 2), 1)
            elif hg_type == 2:
                # 스카라베 (풍뎅이)
                pygame.draw.ellipse(surf, (*hg_c, hg_a),
                                    (hgx - hg_s // 2, hgy - hg_s, hg_s, hg_s * 2), 1)
                pygame.draw.line(surf, (*hg_c, hg_a),
                                 (hgx - hg_s, hgy), (hgx + hg_s, hgy), 1)
            else:
                # 연꽃
                pygame.draw.line(surf, (*hg_c, hg_a),
                                 (hgx, hgy + hg_s), (hgx, hgy - hg_s), 1)
                for petal in [-1, 0, 1]:
                    pygame.draw.ellipse(surf, (*hg_c, hg_a),
                                        (hgx - hg_s // 3 + petal * hg_s // 3,
                                         hgy - hg_s - hg_s // 2,
                                         hg_s * 2 // 3, hg_s), 1)

        # ===== 네온 반사 파티클 (횃불 불씨) =====
        if t > 0.25:
            sparkle_count = int(40 * min(1.0, (t - 0.25) / 0.5))
            for _ in range(sparkle_count):
                sx = random.randint(0, W)
                sy = random.randint(0, H)
                sr = 1
                sa = random.randint(60, 180)
                sc = random.choice([
                    (255, 200, 100), (255, 180, 60), (255, 220, 140),
                    (255, 160, 50), (200, 160, 80), (255, 240, 180),
                ])
                spark_s = pygame.Surface((6, 6), pygame.SRCALPHA)
                pygame.draw.circle(spark_s, (*sc, sa // 3), (3, 3), 3)
                pygame.draw.circle(spark_s, (*sc, min(255, sa)), (3, 3), sr)
                surf.blit(spark_s, (sx - 3, sy - 3))

        # ===== 안개 (모래 먼지) =====
        mist_a = max(0, int(90 * (1.0 - t * 2.0) * alpha / 255))
        if mist_a > 2:
            random.seed(30019)
            for _ in range(18):
                mx = random.randint(-40, W + 40)
                my = random.randint(-20, H + 20)
                mw = random.randint(50, 160)
                mh = random.randint(14, 38)
                mc = random.choice([
                    (90, 75, 50), (100, 82, 55), (80, 65, 42),
                    (95, 78, 52), (110, 90, 60),
                ])
                ms = pygame.Surface((mw, mh), pygame.SRCALPHA)
                pygame.draw.ellipse(ms, (*mc, min(255, mist_a)), (0, 0, mw, mh))
                surf.blit(ms, (mx - mw // 2, my - mh // 2))
            random.seed()

        # ===== 구름 (따뜻한 야경) =====
        cloud_a = max(0, int(150 * (1.0 - t * 2.5) * alpha / 255))
        if cloud_a > 3:
            random.seed(30020)
            for _ in range(14):
                cx_c = random.randint(-40, W + 40)
                cy_c = random.randint(-20, H + 20)
                cw_c = random.randint(45, 140)
                ch_c = random.randint(10, 35)
                cc = random.choice([
                    (40, 32, 28), (50, 40, 35), (35, 28, 24),
                    (45, 36, 30),
                ])
                cs = pygame.Surface((cw_c, ch_c), pygame.SRCALPHA)
                pygame.draw.ellipse(cs, (*cc, min(255, cloud_a)), (0, 0, cw_c, ch_c))
                surf.blit(cs, (cx_c - cw_c // 2, cy_c - ch_c // 2))
            random.seed()

        # ===== 대기 오버레이 (따뜻한 모래 빛) =====
        haze_a = max(0, int(45 * (1.0 - t * 2.5) * alpha / 255))
        if haze_a > 2:
            haze = pygame.Surface((W, H), pygame.SRCALPHA)
            haze.fill((60, 45, 28, haze_a))
            surf.blit(haze, (0, 0))

    def _draw_colosseum_arena_border(self, screen, ix, iy, ig_w, ig_h, arena_scale):
        """경기장 가장자리 — 로마 콜로세움 파피루스+석조+골드 프레임.
        pillar_colosseum.py / animated_background_stage30.py 색상 매칭."""
        bw = max(8, int(40 * arena_scale))
        frieze_h = max(4, int(16 * arena_scale))
        corner_r = max(8, int(28 * arena_scale))
        margin = max(2, int(6 * arena_scale))
        half_out = bw // 2 + margin

        brd_w = ig_w + half_out * 2 + margin * 2
        brd_h = ig_h + half_out * 2 + frieze_h * 2 + margin * 2
        brd = pygame.Surface((brd_w, brd_h), pygame.SRCALPHA)

        ox = half_out + margin
        oy = half_out + frieze_h + margin
        fw, fh = ig_w, ig_h

        random.seed(30070)

        # ===== 1. 외곽 글로우 (따뜻한 골드/오렌지) =====
        for gi in range(4):
            glow_a = 35 - gi * 8
            gc = [(200, 160, 80), (255, 180, 60), (180, 140, 60)][gi % 3]
            pygame.draw.rect(brd, (*gc, max(1, glow_a)),
                             (ox - bw // 2 - 4 - gi * 2, oy - bw // 2 - 4 - gi * 2,
                              fw + bw + 8 + gi * 4, fh + bw + 8 + gi * 4), 2)

        # ===== 2. 메인 프레임 — 3레이어 석조 =====
        # 레이어 1: 어두운 외곽 (border_outer)
        pygame.draw.rect(brd, (90, 70, 45),
                         (ox - bw // 2, oy - bw // 2, fw + bw, fh + bw))
        # 레이어 2: 중간 석조 (stone_medium)
        inner_m = max(2, bw // 6)
        pygame.draw.rect(brd, (180, 160, 130),
                         (ox - bw // 2 + inner_m, oy - bw // 2 + inner_m,
                          fw + bw - inner_m * 2, fh + bw - inner_m * 2))
        # 레이어 3: 밝은 석조 (stone_light)
        inner_m2 = max(3, bw // 3)
        pygame.draw.rect(brd, (210, 190, 160),
                         (ox - bw // 2 + inner_m2, oy - bw // 2 + inner_m2,
                          fw + bw - inner_m2 * 2, fh + bw - inner_m2 * 2))
        # 내부 컷아웃
        pygame.draw.rect(brd, (0, 0, 0, 0), (ox, oy, fw, fh))

        # ===== 3. 석재 줄눈 텍스처 =====
        stone_step = max(3, int(6 * arena_scale))
        for sy_s in range(oy - bw // 2 + 2, oy + fh + bw // 2, stone_step):
            pygame.draw.line(brd, (160, 140, 108, 30),
                             (ox - bw // 2, sy_s), (ox + fw + bw // 2, sy_s), 1)
        for sx_s in range(ox - bw // 2 + 2, ox + fw + bw // 2, max(4, int(10 * arena_scale))):
            sy_off = random.randint(0, stone_step)
            for sy_s in range(oy - bw // 2 + 2 + sy_off, oy + fh + bw // 2,
                              stone_step * 2):
                pygame.draw.line(brd, (155, 135, 105, 25),
                                 (sx_s, sy_s), (sx_s, sy_s + stone_step), 1)

        # ===== 4. 골드 코니스 밴드 (상하단) =====
        gold_band_h = max(3, int(6 * arena_scale))
        gold_c = (200, 160, 80)
        gold_light = (230, 200, 120)
        gold_dark = (160, 120, 50)
        for band_y in [oy - bw // 2 + 1, oy + fh + bw // 2 - gold_band_h - 1]:
            pygame.draw.rect(brd, gold_dark,
                             (ox - bw // 2, band_y, fw + bw, gold_band_h))
            pygame.draw.rect(brd, gold_c,
                             (ox - bw // 2, band_y + 1, fw + bw, gold_band_h - 2))
            pygame.draw.line(brd, gold_light,
                             (ox - bw // 2, band_y + 1),
                             (ox + fw + bw // 2, band_y + 1), 1)

        # ===== 5. 파피루스 프릴 (상하단 — 이집트 스타일) =====
        pap_c = (145, 125, 85)
        pap_light = (165, 145, 105)
        pap_dark = (115, 95, 65)
        for side_y in [oy - bw // 2 - frieze_h, oy + fh + bw // 2]:
            pygame.draw.rect(brd, pap_c,
                             (ox - bw // 2 - 2, side_y, fw + bw + 4, frieze_h))
            # 파피루스 섬유 텍스처
            for _ in range(max(4, int(15 * arena_scale))):
                fx = random.randint(ox - bw // 2, ox + fw + bw // 2)
                fy = side_y + random.randint(1, max(2, frieze_h - 2))
                fl = random.randint(4, max(5, int(18 * arena_scale)))
                pygame.draw.line(brd, pap_light, (fx, fy), (fx + fl, fy), 1)
            # 테두리 (골드)
            pygame.draw.line(brd, gold_dark,
                             (ox - bw // 2 - 2, side_y),
                             (ox + fw + bw // 2 + 2, side_y), 1)
            pygame.draw.line(brd, gold_dark,
                             (ox - bw // 2 - 2, side_y + frieze_h - 1),
                             (ox + fw + bw // 2 + 2, side_y + frieze_h - 1), 1)

        # ===== 6. 히에로글리프 (파피루스 위) =====
        hiero_c = (175, 145, 80)
        hiero_dark = (120, 95, 55)
        hiero_step = max(8, int(24 * arena_scale))
        # 상단 히에로글리프
        for side_y in [oy - bw // 2 - frieze_h, oy + fh + bw // 2]:
            hx = ox - bw // 4
            hi_idx = 0
            while hx < ox + fw + bw // 4:
                hy = side_y + frieze_h // 2
                h_sz = max(2, int(4 * arena_scale))
                h_type = hi_idx % 4
                if h_type == 0:
                    # 앙크
                    pygame.draw.circle(brd, hiero_c, (hx, hy - h_sz), max(1, h_sz // 2), 1)
                    pygame.draw.line(brd, hiero_c, (hx, hy - h_sz // 2), (hx, hy + h_sz), 1)
                    pygame.draw.line(brd, hiero_c,
                                     (hx - h_sz // 2, hy), (hx + h_sz // 2, hy), 1)
                elif h_type == 1:
                    # 호루스의 눈
                    pygame.draw.ellipse(brd, hiero_c,
                                        (hx - h_sz, hy - h_sz // 2, h_sz * 2, h_sz), 1)
                    pygame.draw.circle(brd, hiero_dark, (hx, hy), max(1, h_sz // 3))
                elif h_type == 2:
                    # 스카라베
                    pygame.draw.ellipse(brd, hiero_c,
                                        (hx - h_sz // 2, hy - h_sz, h_sz, h_sz * 2), 1)
                    pygame.draw.line(brd, hiero_c,
                                     (hx - h_sz, hy), (hx + h_sz, hy), 1)
                else:
                    # 연꽃
                    pygame.draw.line(brd, hiero_c, (hx, hy + h_sz), (hx, hy - h_sz), 1)
                    for p in [-1, 0, 1]:
                        pygame.draw.arc(brd, hiero_c,
                                        (hx - h_sz // 2 + p * h_sz // 3,
                                         hy - h_sz * 2, h_sz, h_sz),
                                        0, 3.14, 1)
                hx += hiero_step
                hi_idx += 1

        # ===== 7. 코너 기둥 머리 (이오니아/코린트 양식) =====
        corners = [
            (ox - bw // 4, oy - bw // 4),
            (ox + fw + bw // 4, oy - bw // 4),
            (ox - bw // 4, oy + fh + bw // 4),
            (ox + fw + bw // 4, oy + fh + bw // 4),
        ]
        for cx_c, cy_c in corners:
            cr = corner_r
            # 주두 (사각형 + 볼류트)
            pygame.draw.rect(brd, (195, 180, 155),
                             (cx_c - cr, cy_c - cr // 2, cr * 2, cr))
            pygame.draw.rect(brd, (215, 200, 175),
                             (cx_c - cr + 2, cy_c - cr // 2 + 2, cr * 2 - 4, cr - 4))
            # 골드 테두리
            pygame.draw.rect(brd, gold_c,
                             (cx_c - cr, cy_c - cr // 2, cr * 2, cr), 1)
            # 중앙 로제트
            pygame.draw.circle(brd, gold_c, (cx_c, cy_c), max(2, cr // 3))
            pygame.draw.circle(brd, gold_light, (cx_c, cy_c), max(1, cr // 5))
            # 볼류트 (나선)
            for vol_s in [-1, 1]:
                vx = cx_c + vol_s * (cr - 2)
                pygame.draw.circle(brd, (185, 170, 145), (vx, cy_c), max(2, cr // 4))
                pygame.draw.circle(brd, (195, 180, 155), (vx, cy_c), max(1, cr // 6))

        # ===== 8. 횃불 장식 (좌우 프레임) =====
        for side in [-1, 1]:
            for ti_pos in range(3):
                tx = ox + (fw + bw // 3 if side > 0 else -bw // 3)
                ty_lo = oy + fh // 6
                ty_hi = oy + fh * 5 // 6
                if ty_lo >= ty_hi:
                    continue
                ty = ty_lo + ti_pos * max(4, (ty_hi - ty_lo) // 2)
                # 횃불대
                th = max(4, int(10 * arena_scale))
                pygame.draw.line(brd, (80, 60, 40), (tx, ty), (tx, ty - th), max(1, int(arena_scale)))
                # 불꽃
                fl_r = max(2, int(4 * arena_scale))
                pygame.draw.circle(brd, (255, 180, 60), (tx, ty - th - fl_r // 2), fl_r)
                pygame.draw.circle(brd, (255, 220, 100), (tx, ty - th - fl_r // 2),
                                   max(1, fl_r * 2 // 3))
                # 글로우
                for gi in range(3):
                    gr = fl_r + 3 + gi * 3
                    gs = pygame.Surface((gr * 2, gr * 2), pygame.SRCALPHA)
                    pygame.draw.circle(gs, (255, 180, 60, max(1, 25 - gi * 7)),
                                       (gr, gr), gr)
                    brd.blit(gs, (tx - gr, ty - th - fl_r // 2 - gr))

        # ===== 9. 내부 테두리 + 골드 글로우 =====
        # L-브래킷 코너 장식
        bracket_len = max(6, int(18 * arena_scale))
        bracket_w = max(1, int(2 * arena_scale))
        for (cx_b, cy_b), (dx_b, dy_b) in [
            ((ox, oy), (1, 1)), ((ox + fw, oy), (-1, 1)),
            ((ox, oy + fh), (1, -1)), ((ox + fw, oy + fh), (-1, -1)),
        ]:
            pygame.draw.line(brd, gold_c,
                             (cx_b, cy_b), (cx_b + dx_b * bracket_len, cy_b), bracket_w)
            pygame.draw.line(brd, gold_c,
                             (cx_b, cy_b), (cx_b, cy_b + dy_b * bracket_len), bracket_w)
            # 다이아몬드
            d_sz = max(2, int(3 * arena_scale))
            pygame.draw.polygon(brd, gold_light,
                                [(cx_b, cy_b - d_sz), (cx_b + d_sz, cy_b),
                                 (cx_b, cy_b + d_sz), (cx_b - d_sz, cy_b)])

        # 내부 테두리선
        pygame.draw.rect(brd, (90, 70, 45),
                         (ox - 2, oy - 2, fw + 4, fh + 4), max(1, int(2 * arena_scale)))
        # 골드 글로우
        glow_s = pygame.Surface((fw + 8, fh + 8), pygame.SRCALPHA)
        pygame.draw.rect(glow_s, (200, 160, 80, 60),
                         (0, 0, fw + 8, fh + 8), max(1, int(3 * arena_scale)))
        brd.blit(glow_s, (ox - 4, oy - 4))

        # ===== 10. 파티클 (골드 먼지) =====
        for _ in range(35):
            sx = random.randint(ox - bw // 2, ox + fw + bw // 2)
            sy = random.choice([
                random.randint(max(0, oy - bw // 2 - frieze_h), max(1, oy - 1)),
                random.randint(oy + fh + 1, min(brd_h - 1, oy + fh + bw // 2 + frieze_h))
            ])
            sr = max(1, int(random.uniform(1, 2) * arena_scale))
            sa = random.randint(80, 200)
            sc = random.choice([
                (255, 230, 160), (255, 200, 100), (230, 200, 140),
                (255, 240, 180), (200, 170, 90),
            ])
            ss = pygame.Surface((sr * 4, sr * 4), pygame.SRCALPHA)
            pygame.draw.circle(ss, (*sc, sa // 2), (sr * 2, sr * 2), sr * 2)
            pygame.draw.circle(ss, (255, 245, 200, min(255, sa)),
                               (sr * 2, sr * 2), sr)
            brd.blit(ss, (sx - sr * 2, sy - sr * 2))

        random.seed()

        # ── 최종 블릿 ──
        blit_x = ix - half_out - margin
        blit_y = iy - half_out - frieze_h - margin
        screen.blit(brd, (blit_x, blit_y))

    # ──────────────────────────────────────────────
    #  착륙 시퀀스: 경기장 (투기장)
    # ──────────────────────────────────────────────
    def _draw_landing_arena(self, surf, cx, cy, scale=1.0, planet_num=1):
        """핑파이터 경기장. 행성별 테마."""
        if planet_num == 1:
            self._draw_arena_joseon(surf, cx, cy, scale)
        elif planet_num == 2:
            self._draw_arena_jungle(surf, cx, cy, scale)
        else:
            # 범용 아레나
            self._draw_arena_generic(surf, cx, cy, scale, planet_num)

    def _draw_arena_generic(self, surf, cx, cy, scale, planet_num):
        """범용 경기장."""
        s = scale
        ix, iy = int(cx), int(cy)
        cfg = PLANET_CONFIGS.get(planet_num, {})
        tc = cfg.get("theme_color", (120, 120, 120))
        # 외벽
        ow = int(120 * s)
        oh = int(90 * s)
        pygame.draw.rect(surf, tc, (ix - ow // 2, iy - oh // 2, ow, oh))
        pygame.draw.rect(surf, tuple(min(255, c + 40) for c in tc),
                         (ix - ow // 2, iy - oh // 2, ow, oh), 2)
        # 코트
        cw = int(80 * s)
        ch_c = int(60 * s)
        pygame.draw.rect(surf, (200, 200, 190),
                         (ix - cw // 2, iy - ch_c // 2, cw, ch_c))
        pygame.draw.line(surf, (255, 255, 255),
                         (ix - cw // 2, iy), (ix + cw // 2, iy), 1)
        pygame.draw.rect(surf, (255, 255, 255),
                         (ix - cw // 2, iy - ch_c // 2, cw, ch_c), 1)

    def _draw_arena_joseon(self, surf, cx, cy, scale):
        """조선시대 핑파이터 경기장 — 초고퀄리티 Stage 1."""
        s = scale
        ix, iy = int(cx), int(cy)

        # ── 색상 팔레트 (Stage 1 참조) ──
        stone = (72, 68, 62)
        stone_light = (95, 90, 82)
        stone_dark = (52, 48, 42)
        grout = (42, 38, 34)
        dancheong_red = (140, 45, 35)
        dancheong_blue = (35, 55, 95)
        dancheong_green = (35, 90, 55)
        gold = (200, 160, 80)
        gold_bright = (230, 190, 100)
        gold_dark = (160, 120, 50)
        beige = (235, 220, 195)
        cream = (245, 235, 210)
        ink = (30, 25, 20)
        wood_red = (130, 50, 40)
        wood_red_hl = (160, 70, 55)

        # ── 전체 영역 크기 ──
        ow = int(180 * s)
        oh = int(150 * s)
        ox = ix - ow // 2
        oy = iy - oh // 2

        # ===== 0. 주변 정원 (경기장 바깥 — 나무, 관목, 돌) =====
        if s > 0.3:
            random.seed(5555)
            # 잔디/흙 패치 (경기장 주변)
            for _ in range(int(20 * s)):
                gx = ix + random.randint(-int(100 * s), int(100 * s))
                gy = iy + random.randint(-int(80 * s), int(80 * s))
                # 경기장 내부 스킵
                if abs(gx - ix) < ow // 2 + 5 and abs(gy - iy) < oh // 2 + 5:
                    continue
                gr = random.randint(max(3, int(8 * s)), max(5, int(20 * s)))
                gc_v = random.randint(90, 140)
                gs = pygame.Surface((gr * 2, gr * 2), pygame.SRCALPHA)
                pygame.draw.circle(gs, (gc_v - 30, gc_v, gc_v // 3, 35),
                                   (gr, gr), gr)
                surf.blit(gs, (gx - gr, gy - gr))
            # 소나무 (삼각형 — 경기장 주변)
            for _ in range(int(8 * s)):
                tx = ix + random.choice([-1, 1]) * random.randint(
                    int(75 * s), int(95 * s))
                ty = iy + random.randint(-int(50 * s), int(50 * s))
                th = max(8, int(random.randint(15, 30) * s))
                tw = max(4, th // 2)
                # 줄기
                pygame.draw.line(surf, (70, 50, 30),
                                 (tx, ty), (tx, ty + th), max(1, int(2 * s)))
                # 3단 수관
                for li in range(3):
                    ly = ty - li * th // 5
                    lw = tw - li * max(1, tw // 4)
                    lh_t = max(3, th // 4)
                    tri = [(tx, ly - lh_t), (tx - lw, ly + 1), (tx + lw, ly + 1)]
                    g_v = 35 + random.randint(0, 25)
                    pygame.draw.polygon(surf, (g_v, g_v + 35, g_v - 5), tri)
            # 정원석 (둥근 돌)
            for _ in range(int(6 * s)):
                rx = ix + random.choice([-1, 1]) * random.randint(
                    int(60 * s), int(85 * s))
                ry = iy + random.randint(-int(40 * s), int(40 * s))
                rr = max(2, int(random.randint(3, 7) * s))
                pygame.draw.ellipse(surf, stone_dark,
                                    (rx - rr, ry - rr // 2, rr * 2, rr))
                pygame.draw.ellipse(surf, stone_light,
                                    (rx - rr + 1, ry - rr // 2,
                                     rr * 2 - 2, rr - 1))
            # 벚꽃 나무 (경기장 좌우)
            for side in [-1, 1]:
                tx = ix + side * int(82 * s)
                ty = iy - int(15 * s)
                th = max(10, int(25 * s))
                # 줄기 + 하이라이트
                pygame.draw.line(surf, (65, 45, 25),
                                 (tx + 1, ty), (tx + 1, ty + th), max(2, int(3 * s)))
                pygame.draw.line(surf, (110, 80, 45),
                                 (tx, ty), (tx, ty + th), max(1, int(2 * s)))
                # 가지 + 꽃구름
                for bi in range(5):
                    bx_e = tx + random.randint(-int(15 * s), int(15 * s))
                    by_e = ty - random.randint(0, int(10 * s))
                    pygame.draw.line(surf, (95, 65, 35),
                                     (tx, ty + 3), (bx_e, by_e), 1)
                    for _ in range(random.randint(3, 7)):
                        fx = bx_e + random.randint(-6, 6)
                        fy = by_e + random.randint(-6, 4)
                        fr = max(1, random.randint(2, max(3, int(5 * s))))
                        fs = pygame.Surface((fr * 2 + 2, fr * 2 + 2),
                                            pygame.SRCALPHA)
                        for fi in range(fr, 0, -1):
                            fa = max(1, 60 * fi // fr)
                            pygame.draw.circle(
                                fs, (255, 180 + random.randint(0, 50),
                                     200 + random.randint(0, 30), fa),
                                (fr + 1, fr + 1), fi)
                        surf.blit(fs, (fx - fr - 1, fy - fr - 1))
            random.seed()

        # ===== 1. 외벽 기단 (화강암 석축 3단 + 그림자) =====
        base_h = max(5, int(12 * s))
        # 기단 그림자
        sh_s = pygame.Surface((ow + 12, 6), pygame.SRCALPHA)
        pygame.draw.ellipse(sh_s, (0, 0, 0, 35), (0, 0, ow + 12, 6))
        surf.blit(sh_s, (ox - 6, oy + oh + base_h))
        # 하단 석축 (어두운)
        pygame.draw.rect(surf, stone_dark,
                         (ox - 4, oy + oh, ow + 8, base_h + 2))
        # 중단 석축
        pygame.draw.rect(surf, stone,
                         (ox - 2, oy + oh - 1, ow + 4, base_h))
        # 상단 마감
        pygame.draw.rect(surf, stone_light,
                         (ox, oy + oh - 2, ow, 2))
        # 석축 줄눈
        for gi in range(0, ow + 6, max(5, int(10 * s))):
            pygame.draw.line(surf, grout,
                             (ox - 3 + gi, oy + oh),
                             (ox - 3 + gi, oy + oh + base_h), 1)
        # 수평 줄눈
        if base_h > 6:
            pygame.draw.line(surf, grout,
                             (ox - 4, oy + oh + base_h // 2),
                             (ox + ow + 4, oy + oh + base_h // 2), 1)

        # ===== 2. 성벽 (황토 + 석재 질감 + 그림자) =====
        pygame.draw.rect(surf, (165, 145, 110), (ox, oy, ow, oh))
        # 석재 질감
        random.seed(7777)
        for _ in range(int(35 * s)):
            px = ox + random.randint(2, max(3, ow - 4))
            py_s = oy + random.randint(2, max(3, oh - 4))
            pw = random.randint(3, max(4, int(12 * s)))
            ph = random.randint(2, max(3, int(8 * s)))
            sc = random.choice([stone_light, stone, (155, 140, 115),
                                (148, 132, 108)])
            ps = pygame.Surface((pw, ph), pygame.SRCALPHA)
            ps.fill((*sc, random.randint(35, 75)))
            surf.blit(ps, (px, py_s))
        random.seed()
        # 성벽 하이라이트 (상단)
        hl_s = pygame.Surface((ow, max(3, int(5 * s))), pygame.SRCALPHA)
        hl_s.fill((215, 200, 165, 75))
        surf.blit(hl_s, (ox, oy))
        # 성벽 하단 그림자
        sh_s2 = pygame.Surface((ow, max(2, int(4 * s))), pygame.SRCALPHA)
        sh_s2.fill((0, 0, 0, 25))
        surf.blit(sh_s2, (ox, oy + oh - max(2, int(4 * s))))

        # ===== 3. 금장 테두리 + 단청 + 뇌문 =====
        bw_l = max(1, int(2 * s))
        # 금테 3중
        pygame.draw.rect(surf, gold_dark, (ox - 1, oy - 1, ow + 2, oh + 2), bw_l + 2)
        pygame.draw.rect(surf, gold, (ox, oy, ow, oh), bw_l + 1)
        pygame.draw.rect(surf, gold_bright, (ox + 1, oy + 1, ow - 2, oh - 2), bw_l)
        # 단청 줄 (빨강/금/파랑/녹 교대 — 4줄)
        for offset_i, offset_v in enumerate([max(3, int(5 * s)),
                                             max(4, int(8 * s)),
                                             max(5, int(11 * s)),
                                             max(6, int(14 * s))]):
            colors = [dancheong_red, gold_dark, dancheong_blue, dancheong_green]
            dc = colors[offset_i % 4]
            da = 95 - offset_i * 12
            if ow - offset_v * 2 > 4 and oh - offset_v * 2 > 4:
                ds = pygame.Surface((ow - offset_v * 2, oh - offset_v * 2),
                                    pygame.SRCALPHA)
                pygame.draw.rect(ds, (*dc, max(10, da)),
                                 (0, 0, ow - offset_v * 2, oh - offset_v * 2), 1)
                surf.blit(ds, (ox + offset_v, oy + offset_v))

        # 뇌문 장식 — 코너 4곳 (이중 사각 + 단청 꽃무늬)
        tp = max(3, int(6 * s))
        for corner_x, corner_y in [(ox + tp + 3, oy + tp + 3),
                                    (ox + ow - tp - 3, oy + tp + 3),
                                    (ox + tp + 3, oy + oh - tp - 3),
                                    (ox + ow - tp - 3, oy + oh - tp - 3)]:
            # 외곽 금장
            pygame.draw.rect(surf, gold_bright,
                             (corner_x - tp, corner_y - tp, tp * 2, tp * 2), 1)
            # 내부 빨강
            inner_r = max(1, tp - 1)
            pygame.draw.rect(surf, dancheong_red,
                             (corner_x - inner_r, corner_y - inner_r,
                              inner_r * 2, inner_r * 2))
            # 중앙 금 십자
            pygame.draw.line(surf, gold,
                             (corner_x - 1, corner_y), (corner_x + 1, corner_y), 1)
            pygame.draw.line(surf, gold,
                             (corner_x, corner_y - 1), (corner_x, corner_y + 1), 1)
            # 청색 점 4개
            for dx, dy in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
                if inner_r > 2:
                    pygame.draw.rect(surf, dancheong_blue,
                                     (corner_x + dx * (inner_r - 2),
                                      corner_y + dy * (inner_r - 2), 1, 1))

        # ===== 4. 마당 바닥 (화강암 석조 타일 + 방사 그라데이션) =====
        yw = int(145 * s)
        yh = int(115 * s)
        yx = ix - yw // 2
        yy = iy - yh // 2
        # 베이스 석재
        pygame.draw.rect(surf, stone, (yx, yy, yw, yh))
        # 방사형 그라데이션 (중앙 밝게 — 12단계)
        for ring in range(12, 0, -1):
            frac = ring / 12.0
            rr = int(min(yw, yh) // 2 * frac)
            a = max(1, int(15 * (1.0 - frac)))
            gs = pygame.Surface((rr * 2 + 2, rr * 2 + 2), pygame.SRCALPHA)
            pygame.draw.circle(gs, (200, 190, 170, a), (rr + 1, rr + 1), rr)
            surf.blit(gs, (ix - rr - 1, iy - rr - 1))
        # 타일 줄눈 (벽돌 패턴)
        tile_sz = max(5, int(12 * s))
        for ty in range(yy, yy + yh, tile_sz):
            pygame.draw.line(surf, grout, (yx, ty), (yx + yw, ty), 1)
        row_n = 0
        for ty in range(yy, yy + yh, tile_sz):
            x_off = (row_n % 2) * (tile_sz // 2)
            for tx in range(yx + x_off, yx + yw, tile_sz):
                pygame.draw.line(surf, grout, (tx, ty), (tx, ty + tile_sz), 1)
            row_n += 1
        # 타일 색상 변주
        random.seed(8888)
        for _ in range(int(25 * s)):
            ptx = yx + random.randint(2, max(3, yw - 4))
            pty = yy + random.randint(2, max(3, yh - 4))
            ptw = random.randint(tile_sz - 2, tile_sz + 2)
            pth = random.randint(tile_sz - 2, tile_sz + 2)
            tc_choice = random.choice([stone_light, (82, 74, 65),
                                       (65, 65, 72), (88, 82, 75)])
            ts_s = pygame.Surface((ptw, pth), pygame.SRCALPHA)
            ts_s.fill((*tc_choice, random.randint(20, 50)))
            surf.blit(ts_s, (ptx, pty))
        random.seed()
        # 마당 테두리 (석재 경계선)
        pygame.draw.rect(surf, stone_dark, (yx, yy, yw, yh), 2)
        pygame.draw.rect(surf, stone_light, (yx + 1, yy + 1, yw - 2, yh - 2), 1)

        # ===== 5. 코트 (핑파이터 경기장 — 고퀄리티) =====
        cw = int(90 * s)
        ch_c = int(70 * s)
        court_x = ix - cw // 2
        court_y = iy - ch_c // 2
        # 코트 그림자
        csh = pygame.Surface((cw + 6, ch_c + 6), pygame.SRCALPHA)
        csh.fill((0, 0, 0, 20))
        surf.blit(csh, (court_x - 1, court_y + 2))
        # 코트 바닥 — 밝은 크림색
        pygame.draw.rect(surf, cream, (court_x, court_y, cw, ch_c))
        # 타일 텍스처 (체커)
        ct_sz = max(3, int(7 * s))
        for cty in range(court_y, court_y + ch_c, ct_sz):
            for ctx in range(court_x, court_x + cw, ct_sz):
                if (cty // ct_sz + ctx // ct_sz) % 2 == 0:
                    cs_t = pygame.Surface((ct_sz, ct_sz), pygame.SRCALPHA)
                    cs_t.fill((218, 203, 178, 28))
                    surf.blit(cs_t, (ctx, cty))
        # 나무결 텍스처 (수평선)
        for cty in range(court_y + 2, court_y + ch_c - 2, max(3, int(4 * s))):
            wa = random.randint(8, 20)
            pygame.draw.line(surf, (210, 195, 170, wa),
                             (court_x + 2, cty), (court_x + cw - 2, cty), 1)
        # 금장 코트 테두리 (3중)
        pygame.draw.rect(surf, gold_dark,
                         (court_x - 2, court_y - 2, cw + 4, ch_c + 4),
                         max(1, int(2 * s)))
        pygame.draw.rect(surf, gold,
                         (court_x - 1, court_y - 1, cw + 2, ch_c + 2),
                         max(1, int(1 * s)))
        pygame.draw.rect(surf, gold_bright,
                         (court_x, court_y, cw, ch_c), 1)
        # 중앙선 (금 + 단청)
        ml_w = max(1, int(2 * s))
        pygame.draw.line(surf, gold,
                         (court_x, iy), (court_x + cw, iy), ml_w)
        if s > 0.35:
            dl = max(1, int(1 * s))
            # 단청 줄 3색
            pygame.draw.line(surf, (*dancheong_red, 180),
                             (court_x + 2, iy - dl - 1),
                             (court_x + cw - 2, iy - dl - 1), 1)
            pygame.draw.line(surf, (*gold_dark, 140),
                             (court_x + 2, iy - dl - 2),
                             (court_x + cw - 2, iy - dl - 2), 1)
            pygame.draw.line(surf, (*dancheong_blue, 180),
                             (court_x + 2, iy + dl + 1),
                             (court_x + cw - 2, iy + dl + 1), 1)
            pygame.draw.line(surf, (*gold_dark, 140),
                             (court_x + 2, iy + dl + 2),
                             (court_x + cw - 2, iy + dl + 2), 1)
        # 서브 영역 선
        sv_off = max(3, int(12 * s))
        pygame.draw.line(surf, (*gold_dark, 120),
                         (court_x, court_y + sv_off),
                         (court_x + cw, court_y + sv_off), 1)
        pygame.draw.line(surf, (*gold_dark, 120),
                         (court_x, court_y + ch_c - sv_off),
                         (court_x + cw, court_y + ch_c - sv_off), 1)
        # 네트 시각화 (중앙선 위 점선)
        if s > 0.4:
            for nx in range(court_x + 3, court_x + cw - 2, max(3, int(5 * s))):
                pygame.draw.line(surf, (*stone_dark, 100),
                                 (nx, iy - max(1, int(2 * s))),
                                 (nx, iy + max(1, int(2 * s))), 1)

        # ===== 6. 태극 문양 + 건곤감리 (코트 중앙) =====
        if s > 0.3:
            tr = max(5, int(12 * s))
            # 태극 글로우 (이중)
            for gi in range(tr + 8, tr, -1):
                ga = max(1, int(20 * (gi - tr) / 8))
                gs = pygame.Surface((gi * 2 + 2, gi * 2 + 2), pygame.SRCALPHA)
                pygame.draw.circle(gs, (30, 30, 180, ga),
                                   (gi + 1, gi + 1), gi)
                surf.blit(gs, (ix - gi - 1, iy - gi - 1))
            # 태극 외곽원 (금 + 검정)
            pygame.draw.circle(surf, ink, (ix, iy), tr + 2, max(1, int(1 * s)))
            pygame.draw.circle(surf, gold, (ix, iy), tr + 1, max(1, int(1 * s)))
            # 빨강 반원 (상)
            pygame.draw.circle(surf, (200, 50, 50), (ix, iy), tr)
            # 파랑 하반원
            pygame.draw.rect(surf, (40, 70, 160),
                             (ix - tr, iy, tr * 2, tr))
            # S-커브 (음양)
            small_r = max(2, tr // 2)
            pygame.draw.circle(surf, (200, 50, 50),
                               (ix, iy + small_r), small_r)
            pygame.draw.circle(surf, (40, 70, 160),
                               (ix, iy - small_r), small_r)
            # 중심점
            dot_r = max(1, small_r // 2)
            pygame.draw.circle(surf, (200, 50, 50),
                               (ix, iy - small_r), dot_r)
            pygame.draw.circle(surf, (40, 70, 160),
                               (ix, iy + small_r), dot_r)
            # 건곤감리 (4괘 — 태극 주변)
            if s > 0.5:
                bar_l = max(3, int(6 * s))
                bar_w = max(1, int(1 * s))
                gap = max(2, int(3 * s))
                dist = tr + max(5, int(8 * s))
                # 건 (☰ 하늘) — 상
                for bi in range(3):
                    by_b = iy - dist - bi * gap
                    pygame.draw.line(surf, ink,
                                     (ix - bar_l, by_b), (ix + bar_l, by_b), bar_w)
                # 곤 (☷ 땅) — 하
                for bi in range(3):
                    by_b = iy + dist + bi * gap
                    pygame.draw.line(surf, ink,
                                     (ix - bar_l, by_b), (ix - 1, by_b), bar_w)
                    pygame.draw.line(surf, ink,
                                     (ix + 1, by_b), (ix + bar_l, by_b), bar_w)
                # 감 (☵ 물) — 좌
                for bi in range(3):
                    bx_b = ix - dist - bi * gap
                    if bi == 1:  # 중간만 실선
                        pygame.draw.line(surf, ink,
                                         (bx_b, iy - bar_l),
                                         (bx_b, iy + bar_l), bar_w)
                    else:  # 끊어진 선
                        pygame.draw.line(surf, ink,
                                         (bx_b, iy - bar_l),
                                         (bx_b, iy - 1), bar_w)
                        pygame.draw.line(surf, ink,
                                         (bx_b, iy + 1),
                                         (bx_b, iy + bar_l), bar_w)
                # 리 (☲ 불) — 우
                for bi in range(3):
                    bx_b = ix + dist + bi * gap
                    if bi == 1:  # 중간만 끊어진 선
                        pygame.draw.line(surf, ink,
                                         (bx_b, iy - bar_l),
                                         (bx_b, iy - 1), bar_w)
                        pygame.draw.line(surf, ink,
                                         (bx_b, iy + 1),
                                         (bx_b, iy + bar_l), bar_w)
                    else:  # 실선
                        pygame.draw.line(surf, ink,
                                         (bx_b, iy - bar_l),
                                         (bx_b, iy + bar_l), bar_w)

        # ===== 7. 기와지붕 본관 (상단 — 고퀄리티) =====
        main_w = int(100 * s)
        main_h = int(24 * s)
        main_y_pos = iy - int(48 * s)
        # 건물 그림자
        bsh = pygame.Surface((main_w + 20, 6), pygame.SRCALPHA)
        pygame.draw.ellipse(bsh, (0, 0, 0, 30),
                            (0, 0, main_w + 20, 6))
        surf.blit(bsh, (ix - main_w // 2 - 10, main_y_pos + main_h + max(2, int(4 * s))))
        # 기단 (2단 석축 + 줄눈)
        bh_m = max(3, int(5 * s))
        pygame.draw.rect(surf, stone_dark,
                         (ix - main_w // 2 - 3, main_y_pos + main_h,
                          main_w + 6, bh_m + 1))
        pygame.draw.rect(surf, stone,
                         (ix - main_w // 2 - 1, main_y_pos + main_h - 1,
                          main_w + 2, bh_m))
        pygame.draw.line(surf, stone_light,
                         (ix - main_w // 2 - 1, main_y_pos + main_h - 1),
                         (ix + main_w // 2 + 1, main_y_pos + main_h - 1), 1)
        # 석축 줄눈
        for gi in range(0, main_w + 4, max(5, int(8 * s))):
            pygame.draw.line(surf, grout,
                             (ix - main_w // 2 - 2 + gi, main_y_pos + main_h),
                             (ix - main_w // 2 - 2 + gi,
                              main_y_pos + main_h + bh_m), 1)
        # 벽체 (크림 + 격자 창살)
        pygame.draw.rect(surf, beige,
                         (ix - main_w // 2, main_y_pos, main_w, main_h))
        # 창살 격자
        if s > 0.4:
            win_gap = max(6, int(12 * s))
            for wi in range(ix - main_w // 2 + win_gap,
                            ix + main_w // 2 - 4, win_gap):
                win_h = max(3, main_h - 8)
                win_y = main_y_pos + 5
                pygame.draw.rect(surf, (180, 160, 125),
                                 (wi, win_y, max(3, int(5 * s)), win_h), 1)
                # 격자 가로줄
                for wj in range(win_y + 2, win_y + win_h - 1,
                                max(2, win_h // 3)):
                    pygame.draw.line(surf, (170, 150, 115),
                                     (wi, wj), (wi + max(3, int(5 * s)), wj), 1)
        # 단청 줄 (처마 아래 — 4색 줄)
        for di, dc in enumerate([dancheong_red, gold_dark,
                                  dancheong_blue, dancheong_green]):
            pygame.draw.line(surf, dc,
                             (ix - main_w // 2 + 3, main_y_pos + di + 1),
                             (ix + main_w // 2 - 3, main_y_pos + di + 1), 1)
        # 기둥 (나무 — 빨간색 + 하이라이트 + 주련)
        pillar_gap = max(8, main_w // 5)
        for col_off in range(-main_w // 2 + pillar_gap, main_w // 2, pillar_gap):
            pw_p = max(2, int(3 * s))
            # 기둥 본체
            pygame.draw.line(surf, wood_red,
                             (ix + col_off, main_y_pos + 5),
                             (ix + col_off, main_y_pos + main_h), pw_p)
            # 하이라이트
            pygame.draw.line(surf, wood_red_hl,
                             (ix + col_off - 1, main_y_pos + 5),
                             (ix + col_off - 1, main_y_pos + main_h), 1)
        # 기와지붕 (삼각형 + 아크 복합)
        rw = main_w + int(22 * s)
        rh = max(12, int(20 * s))
        # 지붕 그림자
        pygame.draw.arc(surf, stone_dark,
                        (ix - rw // 2 - 2, main_y_pos - rh - 2, rw + 4, rh * 2 + 4),
                        0, math.pi, max(3, int(5 * s)))
        # 지붕 본체 (회색 기와 — 삼각 + 아크)
        roof_pts = [(ix, main_y_pos - rh),
                    (ix - rw // 2, main_y_pos),
                    (ix + rw // 2, main_y_pos)]
        pygame.draw.polygon(surf, (50, 50, 48), roof_pts)
        # 하이라이트 면 (왼쪽)
        hl_pts = [roof_pts[0], roof_pts[1],
                  (ix, main_y_pos - 2)]
        pygame.draw.polygon(surf, (65, 63, 58), hl_pts)
        # 기와 줄 (지붕 위 수평선)
        for ri in range(1, rh, max(2, int(3 * s))):
            ry_l = main_y_pos - rh + ri
            rx_span = rw // 2 * ri // rh
            pygame.draw.line(surf, (58, 56, 52),
                             (ix - rx_span, ry_l),
                             (ix + rx_span, ry_l), 1)
        # 용마루 (꼭대기 장식 — 금 + 조각)
        pygame.draw.line(surf, (80, 75, 68),
                         (ix - rw // 4, main_y_pos - rh + 2),
                         (ix + rw // 4, main_y_pos - rh + 2), 2)
        # 용마루 중앙 장식 (금)
        pygame.draw.circle(surf, gold, (ix, main_y_pos - rh + 1), max(2, int(3 * s)))
        pygame.draw.circle(surf, gold_bright, (ix, main_y_pos - rh + 1),
                           max(1, int(2 * s)))
        # 처마 끝 (날개 곡선 + 금장)
        pygame.draw.arc(surf, (60, 58, 52),
                        (ix - rw // 2, main_y_pos - rh, rw, rh * 2),
                        0, math.pi, max(2, int(3 * s)))
        pygame.draw.arc(surf, gold_dark,
                        (ix - rw // 2 - 2, main_y_pos - rh - 1, rw + 4, rh * 2 + 2),
                        0, math.pi, 1)
        # 처마 끝 장식 (좌우 꼭짓점 — 치미)
        for side in [-1, 1]:
            cx_c = ix + side * rw // 2
            pygame.draw.circle(surf, gold, (cx_c, main_y_pos), max(1, int(2 * s)))

        # ===== 8. 좌우 문루 (작은 건물 — 향상) =====
        for side in [-1, 1]:
            gx = ix + side * int(62 * s)
            gy = iy + int(18 * s)
            gw = int(32 * s)
            gh = int(18 * s)
            # 그림자
            gsh = pygame.Surface((gw + 8, 4), pygame.SRCALPHA)
            pygame.draw.ellipse(gsh, (0, 0, 0, 25), (0, 0, gw + 8, 4))
            surf.blit(gsh, (gx - gw // 2 - 4, gy + gh + max(2, int(3 * s))))
            # 기단
            pygame.draw.rect(surf, stone,
                             (gx - gw // 2 - 1, gy + gh, gw + 2, max(2, int(3 * s))))
            # 벽체
            pygame.draw.rect(surf, beige, (gx - gw // 2, gy, gw, gh))
            # 단청 줄 (3색)
            pygame.draw.line(surf, dancheong_red,
                             (gx - gw // 2 + 1, gy + 1),
                             (gx + gw // 2 - 1, gy + 1), 1)
            pygame.draw.line(surf, gold_dark,
                             (gx - gw // 2 + 1, gy + 2),
                             (gx + gw // 2 - 1, gy + 2), 1)
            pygame.draw.line(surf, dancheong_blue,
                             (gx - gw // 2 + 1, gy + 3),
                             (gx + gw // 2 - 1, gy + 3), 1)
            # 기둥 + 하이라이트
            for co in [-gw // 3, 0, gw // 3]:
                pw_g = max(1, int(2 * s))
                pygame.draw.line(surf, wood_red,
                                 (gx + co, gy + 4),
                                 (gx + co, gy + gh), pw_g)
                pygame.draw.line(surf, wood_red_hl,
                                 (gx + co - 1, gy + 4),
                                 (gx + co - 1, gy + gh), 1)
            # 지붕 (삼각)
            grw = gw + int(12 * s)
            grh = max(7, int(14 * s))
            g_roof = [(gx, gy - grh // 2),
                      (gx - grw // 2, gy),
                      (gx + grw // 2, gy)]
            pygame.draw.polygon(surf, (52, 52, 48), g_roof)
            pygame.draw.polygon(surf, (65, 63, 58),
                                [g_roof[0], g_roof[1], (gx, gy - 1)])
            pygame.draw.arc(surf, gold_dark,
                            (gx - grw // 2 - 1, gy - grh - 1, grw + 2, grh * 2 + 2),
                            0, math.pi, 1)

        # ===== 9. 등롱 (4개 — 글로우 + 술 장식) =====
        lantern_positions = [
            (ix - int(52 * s), iy - int(30 * s)),
            (ix + int(52 * s), iy - int(30 * s)),
            (ix - int(52 * s), iy + int(40 * s)),
            (ix + int(52 * s), iy + int(40 * s)),
        ]
        for lx, ly in lantern_positions:
            # 등롱 기둥 (돌)
            pygame.draw.line(surf, stone_dark,
                             (lx, ly + max(3, int(4 * s))),
                             (lx, ly + int(20 * s)), max(1, int(2 * s)))
            pygame.draw.line(surf, stone,
                             (lx - 1, ly + max(3, int(4 * s))),
                             (lx - 1, ly + int(20 * s)), 1)
            # 등롱 몸체 크기
            lr = max(3, int(5 * s))
            lh_l = max(4, int(7 * s))
            # 글로우 (3단 소프트)
            glow_s = pygame.Surface((lr * 6 + 4, lh_l * 3 + 4), pygame.SRCALPHA)
            gw_cx = lr * 3 + 2
            gh_cy = lh_l * 3 // 2 + 2
            for gi in range(4, 0, -1):
                ga = max(1, 20 * gi)
                pygame.draw.ellipse(glow_s,
                                    (255, 130, 40, ga),
                                    (gw_cx - lr * gi, gh_cy - lh_l * gi // 2,
                                     lr * gi * 2, lh_l * gi))
            surf.blit(glow_s, (lx - lr * 3 - 2, ly - lh_l * 3 // 2 - 2))
            # 몸체 (빨간 사각 + 그라데이션)
            for li in range(lh_l):
                la_r = 160 + li * 30 // lh_l
                pygame.draw.line(surf, (la_r, 40, 30),
                                 (lx - lr, ly - lh_l // 2 + li),
                                 (lx + lr, ly - lh_l // 2 + li), 1)
            # 금장 테두리
            pygame.draw.rect(surf, gold_dark,
                             (lx - lr, ly - lh_l // 2, lr * 2, lh_l), 1)
            # 꼭대기 (지붕 장식)
            pygame.draw.line(surf, stone_dark,
                             (lx - lr - 2, ly - lh_l // 2),
                             (lx + lr + 2, ly - lh_l // 2), 1)
            pygame.draw.circle(surf, gold, (lx, ly - lh_l // 2 - 1), 1)
            # 술 장식 (하단 — 빨간 술)
            if s > 0.4:
                tassel_l = max(2, int(4 * s))
                pygame.draw.line(surf, (180, 40, 30),
                                 (lx, ly + lh_l // 2),
                                 (lx, ly + lh_l // 2 + tassel_l), 1)
                pygame.draw.circle(surf, (200, 50, 35),
                                   (lx, ly + lh_l // 2 + tassel_l), 1)

        # ===== 10. 벚꽃 장식 (코트 주변 — 풍성) =====
        if s > 0.4:
            random.seed(3456)
            for _ in range(int(18 * s)):
                bx = ix + random.randint(-int(70 * s), int(70 * s))
                by = iy + random.randint(-int(60 * s), int(60 * s))
                br = max(1, random.randint(1, max(2, int(3 * s))))
                ba = random.randint(90, 210)
                bs = pygame.Surface((br * 2 + 6, br * 2 + 6), pygame.SRCALPHA)
                bc_p = br + 3
                # 글로우 + 꽃잎
                pygame.draw.circle(bs, (255, 170, 190, ba // 4), (bc_p, bc_p), br + 2)
                pygame.draw.circle(bs, (255, 185, 205, ba // 2), (bc_p, bc_p), br + 1)
                pygame.draw.circle(bs, (255, 205, 215, ba), (bc_p, bc_p), br)
                surf.blit(bs, (bx - bc_p, by - bc_p))
            random.seed()

        # ===== 11. 깃발 (좌우 문루 옆 — 태극기풍) =====
        if s > 0.5:
            for side_f in [-1, 1]:
                fx = ix + side_f * int(70 * s)
                fy = iy - int(35 * s)
                fh = max(10, int(20 * s))
                # 깃대
                pygame.draw.line(surf, stone,
                                 (fx, fy), (fx, fy + fh), max(1, int(1 * s)))
                # 깃발 (삼각형)
                fw = max(5, int(10 * s))
                flag_pts = [(fx, fy),
                            (fx + side_f * fw, fy + fh // 3),
                            (fx, fy + fh * 2 // 3)]
                pygame.draw.polygon(surf, dancheong_red, flag_pts)
                pygame.draw.polygon(surf, gold, flag_pts, 1)

        # ===== 12. 착륙 패드 (도킹용 — 향상) =====
        if s > 0.35:
            pad_y = iy + int(48 * s)
            pad_r = max(5, int(10 * s))
            # 패드 글로우
            for gi in range(pad_r + 4, pad_r, -1):
                ga = max(1, 15 * (gi - pad_r))
                gs = pygame.Surface((gi * 2 + 2, gi * 2 + 2), pygame.SRCALPHA)
                pygame.draw.circle(gs, (100, 200, 150, ga),
                                   (gi + 1, gi + 1), gi)
                surf.blit(gs, (ix - gi - 1, pad_y - gi - 1))
            # 원형 패드
            pygame.draw.circle(surf, stone_light, (ix, pad_y), pad_r + 2)
            pygame.draw.circle(surf, stone, (ix, pad_y), pad_r)
            # 방향 마커 (십자 + 대각선)
            ml = max(2, pad_r - 2)
            pygame.draw.line(surf, gold, (ix - ml, pad_y), (ix + ml, pad_y), 1)
            pygame.draw.line(surf, gold, (ix, pad_y - ml), (ix, pad_y + ml), 1)
            dml = max(1, ml * 2 // 3)
            pygame.draw.line(surf, (*gold_dark, 120),
                             (ix - dml, pad_y - dml), (ix + dml, pad_y + dml), 1)
            pygame.draw.line(surf, (*gold_dark, 120),
                             (ix + dml, pad_y - dml), (ix - dml, pad_y + dml), 1)
            # 외곽 원 (이중)
            pygame.draw.circle(surf, gold_dark, (ix, pad_y), pad_r + 2, 1)
            pygame.draw.circle(surf, gold, (ix, pad_y), pad_r + 4, 1)

    def _draw_arena_jungle(self, surf, cx, cy, scale):
        """정글/늪지 핑파이터 경기장 — 실제 게임 이미지 기반 Stage 2 악어장군."""
        s = scale
        ix, iy = int(cx), int(cy)

        # ── 색상 팔레트 (실제 게임 스크린샷 기반) ──
        rock_dark = (40, 42, 35)
        rock_mid = (60, 65, 50)
        rock_light = (82, 85, 68)
        rock_hl = (95, 100, 80)
        vine_dark = (20, 55, 18)
        vine_mid = (35, 80, 28)
        vine_bright = (55, 115, 40)
        leaf_dark = (22, 58, 18)
        leaf_mid = (35, 85, 28)
        leaf_bright = (55, 120, 42)
        court_bg = (18, 28, 22)
        court_dark = (12, 20, 16)
        line_green = (40, 160, 100)
        line_bright = (60, 200, 120)
        croc_green = (50, 110, 45)
        croc_dark = (25, 60, 22)
        croc_bright = (75, 145, 60)
        wood_trunk = (50, 35, 18)
        wood_bark = (65, 48, 25)
        gold_trim = (180, 155, 60)

        # ── 전체 영역 크기 ──
        ow = int(180 * s)
        oh = int(150 * s)
        ox = ix - ow // 2
        oy = iy - oh // 2

        # ===== 0. 주변 — 수련/릴리패드 + 나무줄기 + 꽃 =====
        if s > 0.3:
            random.seed(6666)
            # 큰 나무 줄기 (좌/우 — 스크린샷의 굵은 나무)
            for side in [-1, 1]:
                trunk_x = ix + side * int(88 * s)
                trunk_w = max(6, int(14 * s))
                trunk_top = iy - int(70 * s)
                trunk_bot = iy + int(70 * s)
                # 줄기 본체 (굵은 갈색)
                pygame.draw.line(surf, wood_trunk,
                                 (trunk_x, trunk_top), (trunk_x, trunk_bot),
                                 trunk_w + 2)
                pygame.draw.line(surf, wood_bark,
                                 (trunk_x - 1, trunk_top), (trunk_x - 1, trunk_bot),
                                 trunk_w)
                # 나무결 하이라이트
                pygame.draw.line(surf, (80, 60, 35),
                                 (trunk_x - trunk_w // 3, trunk_top + 5),
                                 (trunk_x - trunk_w // 3, trunk_bot - 5), 1)
                # 이끼 (줄기 위 녹색)
                for mi in range(trunk_top, trunk_bot, max(4, int(8 * s))):
                    mw = random.randint(1, max(2, trunk_w // 3))
                    ms = pygame.Surface((mw * 2, 3), pygame.SRCALPHA)
                    ms.fill((*vine_dark, random.randint(40, 80)))
                    surf.blit(ms, (trunk_x - mw, mi))
                # 덩굴 (줄기에서 늘어짐)
                for _ in range(random.randint(2, 4)):
                    vx = trunk_x + random.randint(-trunk_w, trunk_w)
                    vy = trunk_top + random.randint(0, (trunk_bot - trunk_top) // 2)
                    vl = random.randint(max(5, int(10 * s)), max(8, int(25 * s)))
                    for vi in range(vl):
                        vx_o = vx + int(3 * math.sin(vi * 0.5))
                        pygame.draw.circle(surf, vine_mid, (vx_o, vy + vi),
                                           max(1, int(1 * s)))

            # 수련/릴리패드 (경기장 주변)
            for _ in range(int(12 * s)):
                lx = ix + random.randint(-int(95 * s), int(95 * s))
                ly = iy + random.randint(-int(75 * s), int(75 * s))
                if abs(lx - ix) < ow // 2 + 3 and abs(ly - iy) < oh // 2 + 3:
                    continue
                lr = max(3, int(random.randint(5, 14) * s))
                # 릴리패드 (녹색 타원)
                ls = pygame.Surface((lr * 2 + 2, lr + 2), pygame.SRCALPHA)
                pygame.draw.ellipse(ls, leaf_dark, (0, 0, lr * 2 + 2, lr + 2))
                pygame.draw.ellipse(ls, leaf_mid, (1, 1, lr * 2, lr))
                # V자 갈라진 부분
                pygame.draw.line(ls, (0, 0, 0, 0), (lr + 1, lr // 2 + 1),
                                 (lr * 2, 0), 1)
                surf.blit(ls, (lx - lr - 1, ly - lr // 2 - 1))
                # 꽃 (일부에만)
                if random.random() > 0.6:
                    fr = max(2, int(3 * s))
                    pygame.draw.circle(surf, (255, 255, 240), (lx, ly - 1), fr)
                    pygame.draw.circle(surf, (255, 220, 120), (lx, ly - 1),
                                       max(1, fr - 1))

            # 작은 덩굴 패치 (경기장 바깥)
            for _ in range(int(10 * s)):
                gx = ix + random.randint(-int(90 * s), int(90 * s))
                gy = iy + random.randint(-int(70 * s), int(70 * s))
                if abs(gx - ix) < ow // 2 + 5 and abs(gy - iy) < oh // 2 + 5:
                    continue
                gr = max(3, int(random.randint(4, 12) * s))
                gs = pygame.Surface((gr * 2, gr * 2), pygame.SRCALPHA)
                pygame.draw.circle(gs, (*vine_dark, 50), (gr, gr), gr)
                surf.blit(gs, (gx - gr, gy - gr))
            random.seed()

        # ===== 1. 외벽 (돌/바위 — 어두운 회녹색 암석) =====
        # 외벽 그림자
        sh_s = pygame.Surface((ow + 14, 7), pygame.SRCALPHA)
        pygame.draw.ellipse(sh_s, (0, 0, 0, 35), (0, 0, ow + 14, 7))
        surf.blit(sh_s, (ox - 7, oy + oh + 2))
        # 돌벽 베이스
        pygame.draw.rect(surf, rock_dark, (ox, oy, ow, oh))
        # 돌 질감 (불규칙 돌 패턴)
        random.seed(7771)
        for _ in range(int(50 * s)):
            rx = ox + random.randint(2, max(3, ow - 4))
            ry = oy + random.randint(2, max(3, oh - 4))
            rw_s = random.randint(4, max(5, int(14 * s)))
            rh_s = random.randint(3, max(4, int(10 * s)))
            rc = random.choice([rock_mid, rock_light, rock_dark,
                                (50, 55, 42), (70, 72, 58)])
            pygame.draw.ellipse(surf, rc, (rx, ry, rw_s, rh_s))
            pygame.draw.ellipse(surf, (max(0, rc[0] - 12), max(0, rc[1] - 12),
                                       max(0, rc[2] - 10)),
                                (rx, ry, rw_s, rh_s), 1)
        random.seed()
        # 돌벽 이끼 (녹색 얼룩)
        random.seed(7772)
        for _ in range(int(25 * s)):
            mx = ox + random.randint(3, max(4, ow - 6))
            my = oy + random.randint(3, max(4, oh - 6))
            mr = random.randint(2, max(3, int(8 * s)))
            ms_s = pygame.Surface((mr * 2, mr * 2), pygame.SRCALPHA)
            mc = random.choice([vine_dark, leaf_dark, (28, 65, 22)])
            pygame.draw.circle(ms_s, (*mc, random.randint(35, 65)), (mr, mr), mr)
            surf.blit(ms_s, (mx - mr, my - mr))
        random.seed()

        # ===== 2. 금장 + 덩굴 테두리 =====
        bw_l = max(1, int(2 * s))
        # 금 테두리 (외곽)
        pygame.draw.rect(surf, (120, 100, 40),
                         (ox - 1, oy - 1, ow + 2, oh + 2), bw_l + 2)
        pygame.draw.rect(surf, gold_trim,
                         (ox, oy, ow, oh), bw_l + 1)
        # 덩굴 테두리 줄 (내부 2줄 — 두꺼운 녹색)
        for offset_v in [max(3, int(6 * s)), max(5, int(11 * s))]:
            if ow - offset_v * 2 > 4 and oh - offset_v * 2 > 4:
                ds = pygame.Surface((ow - offset_v * 2, oh - offset_v * 2),
                                    pygame.SRCALPHA)
                dc = vine_mid if offset_v < 8 else vine_dark
                pygame.draw.rect(ds, (*dc, 80),
                                 (0, 0, ow - offset_v * 2, oh - offset_v * 2),
                                 max(1, int(2 * s)))
                surf.blit(ds, (ox + offset_v, oy + offset_v))
        # 덩굴 장식 (사방 벽 위에 덩굴 뭉치)
        if s > 0.35:
            random.seed(7773)
            # 상단 벽 위 덩굴 (늘어지는)
            for _ in range(int(14 * s)):
                vx = ox + random.randint(5, max(6, ow - 5))
                vy = oy + random.randint(2, max(3, int(8 * s)))
                vl = random.randint(max(4, int(6 * s)), max(8, int(20 * s)))
                for vi in range(vl):
                    vx_o = vx + int(2 * math.sin(vi * 0.7 + vx * 0.1))
                    vr = max(1, int(2 * s) - vi // max(3, vl // 3))
                    if vr < 1:
                        vr = 1
                    vc = vine_mid if vi % 3 else vine_bright
                    pygame.draw.circle(surf, vc, (vx_o, vy + vi), vr)
                    # 잎 (간헐적)
                    if vi % max(3, vl // 4) == 0 and vi > 0:
                        leaf_r = max(2, int(3 * s))
                        side_l = random.choice([-1, 1])
                        pygame.draw.ellipse(surf, leaf_mid,
                                            (vx_o + side_l * 2, vy + vi - 1,
                                             leaf_r * 2, leaf_r))
            # 좌우 벽 위 덩굴
            for side in [ox + 2, ox + ow - max(3, int(4 * s))]:
                for _ in range(int(6 * s)):
                    vy = oy + random.randint(int(8 * s), max(10, oh - int(8 * s)))
                    vl = random.randint(max(2, int(4 * s)), max(5, int(12 * s)))
                    for vi in range(vl):
                        pygame.draw.circle(surf, vine_dark,
                                           (side + vi // 2, vy + int(2 * math.sin(vi * 0.6))),
                                           max(1, int(1 * s)))
            random.seed()

        # 코너 장식 (악어 이빨/해골)
        tp = max(3, int(6 * s))
        for corner_x, corner_y in [(ox + tp + 3, oy + tp + 3),
                                    (ox + ow - tp - 3, oy + tp + 3),
                                    (ox + tp + 3, oy + oh - tp - 3),
                                    (ox + ow - tp - 3, oy + oh - tp - 3)]:
            # 해골 (실제 게임에 보이는 장식)
            tr = max(2, tp)
            pygame.draw.circle(surf, (180, 170, 140), (corner_x, corner_y), tr)
            pygame.draw.circle(surf, (140, 130, 100), (corner_x, corner_y), tr, 1)
            if tr > 2:
                pygame.draw.circle(surf, (30, 25, 20), (corner_x - 1, corner_y - 1), 1)
                pygame.draw.circle(surf, (30, 25, 20), (corner_x + 1, corner_y - 1), 1)

        # ===== 3. 코트 바닥 (매우 어두운 녹색/검정) =====
        cw = int(90 * s)
        ch_c = int(70 * s)
        court_x = ix - cw // 2
        court_y = iy - ch_c // 2
        # 코트 그림자
        csh = pygame.Surface((cw + 8, ch_c + 8), pygame.SRCALPHA)
        csh.fill((0, 0, 0, 30))
        surf.blit(csh, (court_x - 2, court_y + 2))
        # 코트 바닥 — 매우 어두운 녹흑색 (실제 게임)
        pygame.draw.rect(surf, court_bg, (court_x, court_y, cw, ch_c))
        # 미세 질감 (약간의 패턴 변주)
        random.seed(8882)
        for _ in range(int(20 * s)):
            ptx = court_x + random.randint(2, max(3, cw - 4))
            pty = court_y + random.randint(2, max(3, ch_c - 4))
            ptw = random.randint(3, max(4, int(10 * s)))
            pth = random.randint(2, max(3, int(6 * s)))
            tc = random.choice([court_dark, (15, 24, 18), (22, 32, 25)])
            ts_s = pygame.Surface((ptw, pth), pygame.SRCALPHA)
            ts_s.fill((*tc, random.randint(30, 60)))
            surf.blit(ts_s, (ptx, pty))
        random.seed()
        # 코트 테두리 (밝은 녹색 선 — 실제 게임처럼)
        pygame.draw.rect(surf, line_green,
                         (court_x, court_y, cw, ch_c), max(1, int(2 * s)))
        # 중앙선 (밝은 녹색)
        ml_w = max(1, int(2 * s))
        pygame.draw.line(surf, line_green,
                         (court_x, iy), (court_x + cw, iy), ml_w)
        # 서브 영역 선
        sv_off = max(3, int(12 * s))
        pygame.draw.line(surf, (*line_green, 120),
                         (court_x, court_y + sv_off),
                         (court_x + cw, court_y + sv_off), 1)
        pygame.draw.line(surf, (*line_green, 120),
                         (court_x, court_y + ch_c - sv_off),
                         (court_x + cw, court_y + ch_c - sv_off), 1)

        # ===== 4. 악어 얼굴 문양 (코트 중앙 — 큰 타원형) =====
        if s > 0.25:
            # 타원형 악어 얼굴 (스크린샷처럼 넓은 타원)
            face_w = max(12, int(35 * s))
            face_h = max(8, int(22 * s))
            # 외곽 글로우
            for gi in range(4, 0, -1):
                ga = max(1, 12 * gi)
                gs = pygame.Surface((face_w * 2 + gi * 6, face_h * 2 + gi * 6),
                                    pygame.SRCALPHA)
                pygame.draw.ellipse(gs, (30, 90, 35, ga),
                                    (0, 0, face_w * 2 + gi * 6, face_h * 2 + gi * 6))
                surf.blit(gs, (ix - face_w - gi * 3, iy - face_h - gi * 3))
            # 외곽 타원 (밝은 녹색 선)
            pygame.draw.ellipse(surf, line_green,
                                (ix - face_w, iy - face_h, face_w * 2, face_h * 2), 1)
            # 얼굴 본체 (밝은 녹색 그라데이션)
            face_s = pygame.Surface((face_w * 2, face_h * 2), pygame.SRCALPHA)
            for ri in range(min(face_w, face_h), 0, -1):
                frac = ri / min(face_w, face_h)
                rw_f = int(face_w * frac)
                rh_f = int(face_h * frac)
                if rw_f < 2 or rh_f < 2:
                    continue
                fa = max(1, int(120 * frac))
                fc_g = int(croc_green[1] - 30 * (1.0 - frac))
                pygame.draw.ellipse(face_s, (croc_dark[0], max(0, fc_g),
                                             croc_dark[2], fa),
                                    (face_w - rw_f, face_h - rh_f,
                                     rw_f * 2, rh_f * 2))
            surf.blit(face_s, (ix - face_w, iy - face_h))
            # 눈 (양쪽 — 흰 동그라미 + 검은 동공)
            eye_dist = max(4, int(8 * s))
            eye_r = max(2, int(4 * s))
            for ex_off in [-eye_dist, eye_dist]:
                # 흰자
                pygame.draw.circle(surf, (220, 225, 215),
                                   (ix + ex_off, iy - max(1, int(3 * s))), eye_r)
                # 동공
                pygame.draw.circle(surf, (10, 15, 10),
                                   (ix + ex_off, iy - max(1, int(3 * s))),
                                   max(1, eye_r - 1))
            # 콧구멍 (작은 점 2개)
            nose_d = max(2, int(3 * s))
            pygame.draw.circle(surf, croc_dark, (ix - nose_d, iy + max(1, int(2 * s))), 1)
            pygame.draw.circle(surf, croc_dark, (ix + nose_d, iy + max(1, int(2 * s))), 1)
            # 이빨 (하단 삼각형 톱니 — V V V V V)
            if s > 0.4:
                teeth_y = iy + max(3, int(7 * s))
                teeth_n = 5
                teeth_gap = max(2, int(4 * s))
                teeth_h = max(2, int(3 * s))
                start_x = ix - (teeth_n - 1) * teeth_gap // 2
                for ti in range(teeth_n):
                    tx_t = start_x + ti * teeth_gap
                    # 삼각형 이빨
                    pygame.draw.polygon(surf, (220, 225, 215),
                                        [(tx_t, teeth_y),
                                         (tx_t - max(1, teeth_gap // 3), teeth_y + teeth_h),
                                         (tx_t + max(1, teeth_gap // 3), teeth_y + teeth_h)])

        # ===== 5. 착륙장 (하단) =====
        if s > 0.3:
            pad_y = iy + int(55 * s)
            pad_r = max(5, int(14 * s))
            ps = pygame.Surface((pad_r * 2 + 8, pad_r * 2 + 8), pygame.SRCALPHA)
            pc = pad_r + 4
            for ri in range(pad_r + 3, 0, -1):
                ra = max(1, 35 - ri * 2)
                pygame.draw.circle(ps, (*rock_dark, ra), (pc, pc), ri)
            surf.blit(ps, (ix - pc, pad_y - pc))
            pygame.draw.circle(surf, rock_mid, (ix, pad_y), max(3, pad_r - 2))
            # X 표시
            dml = max(3, pad_r - 3)
            pygame.draw.line(surf, line_green, (ix - dml, pad_y - dml),
                             (ix + dml, pad_y + dml), max(1, int(2 * s)))
            pygame.draw.line(surf, line_green, (ix + dml, pad_y - dml),
                             (ix - dml, pad_y + dml), max(1, int(2 * s)))
            pygame.draw.circle(surf, line_green, (ix, pad_y), pad_r + 2, 1)

    # ──────────────────────────────────────────────
    #  목표 행성 (고퀄리티)
    # ──────────────────────────────────────────────
    # ──────────────────────────────────────────────
    #  행성별 고유 테마 렌더러
    # ──────────────────────────────────────────────

    def _draw_atmo_glow(self, surf, cx, cy, radius, glow, alpha=255):
        """공통: 대기 글로우"""
        gr = radius + 35
        gs = pygame.Surface((gr * 2 + 4, gr * 2 + 4), pygame.SRCALPHA)
        gcx = gr + 2
        for i in range(35, 0, -2):
            a = max(1, int(25 * alpha / 255 * (1 - i / 35)))
            pygame.draw.circle(gs, (*glow, a), (gcx, gcx), radius + i)
        surf.blit(gs, (cx - gr - 2, cy - gr - 2))

    def _draw_highlight(self, surf, cx, cy, radius, base, alpha=255):
        """공통: 하이라이트 (좌상단 빛 반사)"""
        hl = tuple(min(255, c + 90) for c in base)
        hr = max(5, radius // 2)
        hs = pygame.Surface((hr * 2 + 4, hr * 2 + 4), pygame.SRCALPHA)
        for i in range(hr, 0, -1):
            a = max(1, int(50 * i / hr * alpha / 255))
            pygame.draw.circle(hs, (*hl, a), (hr + 2, hr + 2), i)
        surf.blit(hs, (cx - radius // 3 - hr - 2, cy - radius // 3 - hr - 2))

    def _draw_ring(self, surf, cx, cy, radius, ring_c, alpha=255):
        """공통: 행성 고리"""
        if not ring_c or radius < 15:
            return
        rw = int(radius * 2.6)
        rh = max(8, radius // 3)
        rs = pygame.Surface((rw, rh), pygame.SRCALPHA)
        for ri in range(4):
            off = ri * 2
            a = max(1, (80 - ri * 15) * alpha // 255)
            pygame.draw.ellipse(rs, (*ring_c, a),
                                (off, off, rw - off * 2, rh - off * 2),
                                max(1, 2 - ri // 2))
        surf.blit(rs, (cx - rw // 2, cy - rh // 2))

    # ── 공통: 행성 내부 좌표 체크 ──
    @staticmethod
    def _in_planet(px, py, cx, cy, r):
        return (px - cx) ** 2 + (py - cy) ** 2 < r * r

    # ── 공통: 3D 구체 셰이딩 오버레이 ──
    def _draw_sphere_shading(self, surf, cx, cy, r, alpha=255):
        """행성 위에 초고퀄 3D 구 형태 셰이딩을 오버레이한다.
        강한 림 다크닝 + 방향성 광원 + 터미네이터 라인 +
        대형 스페큘러 + 대기 산란 + 위도/경도 그리드
        """
        if r < 6:
            return

        sz = r * 2 + 4
        rc = r + 2  # 임시 서피스 중앙

        # --- 광원 방향 (천천히 회전) ---
        light_ang = self.time * 0.08
        lx = math.cos(light_ang)
        ly = math.sin(light_ang) * 0.55

        # ====== 1. 강력한 림 다크닝 (가장자리 극도로 어둡게) ======
        rim = pygame.Surface((sz, sz), pygame.SRCALPHA)
        rim_bands = min(r, 35)
        for i in range(rim_bands):
            t = i / rim_bands  # 0 = 바깥, 1 = 안쪽
            band_r = r - int((1.0 - t) * r * 0.55)
            # 바깥 밴드일수록 어둡고 굵게
            darkness = int(180 * ((1.0 - t) ** 1.6))
            da = min(255, darkness * alpha // 255)
            thick = max(1, int(r * 0.55 / rim_bands) + 1)
            if da > 1 and band_r > 0:
                pygame.draw.circle(rim, (0, 0, 0, da), (rc, rc), band_r, thick)
        # 최외곽 추가 다크 링 (매우 어두운 테두리)
        for ei in range(max(2, r // 4)):
            ea = min(255, int(120 * alpha / 255))
            pygame.draw.circle(rim, (0, 0, 0, ea), (rc, rc), r - ei, 1)
        surf.blit(rim, (cx - rc, cy - rc))

        # ====== 2. 방향성 그림자 (어두운 반구 — 강력) ======
        shadow = pygame.Surface((sz, sz), pygame.SRCALPHA)
        # 그림자 중심을 광원 반대쪽으로 크게 오프셋
        sh_off = 0.45
        sh_cx = rc + int(-lx * r * sh_off)
        sh_cy = rc + int(-ly * r * sh_off)
        sh_layers = min(r, 25)
        for si in range(sh_layers):
            t = si / sh_layers  # 0 = 가장 바깥, 1 = 중심
            sh_r = int(r * (1.05 - t * 0.35))
            # 바깥 레이어일수록 강한 어둠
            sa = min(255, int(90 * (1.0 - t * 0.7) * alpha / 255))
            if sa > 1 and sh_r > 0:
                pygame.draw.circle(shadow, (0, 0, 0, sa), (sh_cx, sh_cy), sh_r)
        surf.blit(shadow, (cx - rc, cy - rc))

        # ====== 3. 터미네이터 라인 (낮/밤 경계의 미묘한 밝은 선) ======
        if r > 15:
            term = pygame.Surface((sz, sz), pygame.SRCALPHA)
            # 광원에 수직인 방향으로 호를 그림
            perp_ang = light_ang + math.pi / 2
            for ti in range(3):
                toff = (ti - 1) * max(1, r // 20)
                term_cx = rc + int(-lx * r * 0.05) + int(math.cos(perp_ang) * toff * 0.1)
                term_cy = rc + int(-ly * r * 0.05) + int(math.sin(perp_ang) * toff * 0.1)
                ta = min(255, int(22 * alpha / 255))
                # 반원 호
                start_a = perp_ang - math.pi * 0.45
                end_a = perp_ang + math.pi * 0.45
                tr = r - abs(toff) * 2
                if tr > 5:
                    pygame.draw.arc(term, (200, 210, 235, ta),
                                    (term_cx - tr, term_cy - tr, tr * 2, tr * 2),
                                    start_a, end_a, 1)
            surf.blit(term, (cx - rc, cy - rc))

        # ====== 4. 디퓨즈 라이트 (광원 방향 전체를 밝게) ======
        diffuse = pygame.Surface((sz, sz), pygame.SRCALPHA)
        diff_cx = rc + int(lx * r * 0.3)
        diff_cy = rc + int(ly * r * 0.3)
        diff_layers = min(r, 18)
        for di in range(diff_layers):
            t = di / diff_layers
            diff_r = int(r * (0.85 - t * 0.4))
            da = min(255, int(30 * (1.0 - t) * alpha / 255))
            if da > 1 and diff_r > 0:
                pygame.draw.circle(diffuse, (255, 255, 240, da),
                                   (diff_cx, diff_cy), diff_r)
        surf.blit(diffuse, (cx - rc, cy - rc))

        # ====== 5. 대형 스페큘러 하이라이트 (밝고 넓은 반짝임) ======
        spec_x = cx + int(lx * r * 0.38)
        spec_y = cy + int(ly * r * 0.38)
        spec_r = max(3, int(r * 0.3))
        spec_sz = spec_r * 2 + 12
        spec = pygame.Surface((spec_sz, spec_sz), pygame.SRCALPHA)
        sc = spec_sz // 2
        # 넓은 글로우
        for gi in range(spec_r + 5, 0, -1):
            t = gi / (spec_r + 5)
            ga = min(255, int(80 * t * t * alpha / 255))
            pygame.draw.circle(spec, (255, 255, 255, ga), (sc, sc), gi)
        # 날카로운 코어
        core_r = max(1, spec_r // 2)
        for ci in range(core_r, 0, -1):
            t = ci / core_r
            ca = min(255, int(160 * t * alpha / 255))
            pygame.draw.circle(spec, (255, 255, 255, ca), (sc, sc), ci)
        surf.blit(spec, (spec_x - sc, spec_y - sc))

        # 보조 스페큘러 (약간 오프셋 — 이중 반짝임)
        if r > 18:
            sub_x = cx + int(lx * r * 0.22)
            sub_y = cy + int(ly * r * 0.22)
            sub_r = max(2, int(r * 0.12))
            sub = pygame.Surface((sub_r * 2 + 6, sub_r * 2 + 6), pygame.SRCALPHA)
            ssc = sub_r + 3
            for si in range(sub_r + 2, 0, -1):
                sa = min(255, int(45 * si / (sub_r + 2) * alpha / 255))
                pygame.draw.circle(sub, (255, 255, 245, sa), (ssc, ssc), si)
            surf.blit(sub, (sub_x - ssc, sub_y - ssc))

        # ====== 6. 대기 산란 — 광원 쪽 림 글로우 (프레넬) ======
        if r > 10:
            atm = pygame.Surface((sz + 8, sz + 8), pygame.SRCALPHA)
            ac = rc + 4
            # 광원 쪽에만 밝은 테두리 (반원 호)
            atm_bands = max(3, r // 6)
            for ai in range(atm_bands):
                ar = r + 1 - ai
                if ar < r // 2:
                    break
                aa = min(255, int(55 * (1.0 - ai / atm_bands) * alpha / 255))
                # 광원 방향의 반원 호
                start = light_ang - math.pi * 0.55
                end = light_ang + math.pi * 0.55
                if ar > 2:
                    pygame.draw.arc(atm, (200, 220, 255, aa),
                                    (ac - ar, ac - ar, ar * 2, ar * 2),
                                    start, end, max(1, 2 - ai // 3))
            # 어두운 쪽에도 미미한 파란 림 (앰비언트 반사)
            for ai in range(max(1, atm_bands // 3)):
                ar = r + 1 - ai
                if ar < r // 2:
                    break
                aa = min(255, int(18 * alpha / 255))
                start = light_ang + math.pi * 0.6
                end = light_ang + math.pi * 1.4
                if ar > 2:
                    pygame.draw.arc(atm, (80, 120, 200, aa),
                                    (ac - ar, ac - ar, ar * 2, ar * 2),
                                    start, end, 1)
            surf.blit(atm, (cx - ac, cy - ac))

        # ====== 7. 위도/경도 그리드 라인 (구체 느낌 극대화) ======
        if r > 20:
            grid = pygame.Surface((sz, sz), pygame.SRCALPHA)
            ga = min(255, int(25 * alpha / 255))
            gc = (180, 200, 255, ga)

            # 위도선 (수평 타원들 — 구면 투영)
            lat_count = 5
            for li in range(1, lat_count):
                # y 위치: -r ~ +r 범위에서 등간격
                frac = li / lat_count  # 0.2, 0.4, 0.6, 0.8
                lat_y = rc + int(r * (frac * 2 - 1))
                # 이 위도에서의 가시 폭 (구면 삼각함수)
                cos_lat = math.sqrt(max(0, 1.0 - (frac * 2 - 1) ** 2))
                lat_w = int(r * cos_lat)
                if lat_w > 3:
                    lat_h = max(1, int(lat_w * 0.08) + 1)
                    pygame.draw.ellipse(grid, gc,
                                        (rc - lat_w, lat_y - lat_h,
                                         lat_w * 2, lat_h * 2), 1)

            # 경도선 (수직 타원들 — 자전 오프셋 적용)
            lon_count = 6
            rot_offset = (self.time * 0.3) % (math.pi * 2 / lon_count)
            for li in range(lon_count):
                ang = (li * math.pi / lon_count) + rot_offset
                # 이 경도선의 x 오프셋 (시점에서의 투영)
                cos_lon = math.cos(ang)
                lon_x = rc + int(r * cos_lon * 0.95)
                # 폭 = sin(ang) — 정면은 좁고 옆면은 넓게
                sin_lon = abs(math.sin(ang))
                lon_w = max(1, int(r * sin_lon * 0.15))
                lon_h = int(r * 0.92)
                if lon_h > 3:
                    pygame.draw.ellipse(grid, gc,
                                        (lon_x - lon_w, rc - lon_h,
                                         lon_w * 2, lon_h * 2), 1)
            # 그리드도 원형 마스크 적용
            gmask = pygame.Surface((sz, sz), pygame.SRCALPHA)
            pygame.draw.circle(gmask, (255, 255, 255, 255), (rc, rc), r - 1)
            grid.blit(gmask, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
            surf.blit(grid, (cx - rc, cy - rc))

    # ── 행성 1: 조선시대 (궁궐/곡선지붕/산/벚꽃/개울) ──
    def _draw_planet_joseon(self, surf, cx, cy, r, alpha=255):
        glow = (255, 200, 80)
        base = (160, 125, 55)
        self._draw_atmo_glow(surf, cx, cy, r, glow, alpha)
        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 12:
            random.seed(1137)
            # 부드러운 지형 (편심 원 패치 — 논밭/초원 질감)
            for _ in range(max(8, r // 3)):
                ox = random.randint(-r // 3, r // 3)
                oy = random.randint(-r // 3, r // 3)
                pr = random.randint(max(3, r // 6), max(5, r // 3))
                if not self._in_planet(cx + ox, cy + oy, cx, cy, r - 2):
                    continue
                g = random.randint(90, 170)
                pygame.draw.circle(surf, (g - 30, g, g // 3), (cx + ox, cy + oy), pr)
            # 개울 (사인 곡선)
            if r > 16:
                pts = []
                for step in range(16):
                    t = step / 15
                    sx = cx - int(r * 0.55) + int(r * 1.1 * t)
                    sy = cy + int(r * 0.22 * math.sin(t * math.pi * 3))
                    if self._in_planet(sx, sy, cx, cy, r - 2):
                        pts.append((sx, sy))
                if len(pts) > 2:
                    pygame.draw.lines(surf, (70, 120, 170), False, pts, max(1, r // 16))
                    pygame.draw.lines(surf, (95, 150, 205), False, pts, max(1, r // 28))
            # 둥근 산 (겹 타원 + 하이라이트 호)
            for _ in range(6):
                ang = random.uniform(0, math.pi * 2)
                d = random.uniform(r * 0.1, r * 0.7)
                mx = cx + int(d * math.cos(ang))
                my = cy + int(d * math.sin(ang))
                if not self._in_planet(mx, my, cx, cy, r - 3):
                    continue
                mw = max(4, int(r * random.uniform(0.12, 0.3)))
                mh = max(3, int(mw * 0.65))
                mc = (30 + random.randint(0, 40), 75 + random.randint(0, 50), 25)
                pygame.draw.ellipse(surf, mc, (mx - mw, my - mh, mw * 2, mh * 2))
                hl = (min(255, mc[0] + 35), min(255, mc[1] + 35), min(255, mc[2] + 25))
                pygame.draw.arc(surf, hl,
                                (mx - mw, my - mh, mw * 2, mh * 2),
                                math.pi * 0.15, math.pi * 0.85, 1)
            # 곡선 기와지붕 궁궐 (호+타원)
            if r > 22:
                for _ in range(3):
                    bx = cx + random.randint(-r // 2, r // 2)
                    by = cy + random.randint(-r // 2, r // 2)
                    if not self._in_planet(bx, by, cx, cy, r - 6):
                        continue
                    bw = max(5, int(r * 0.18))
                    bh = max(3, int(bw * 0.6))
                    pygame.draw.ellipse(surf, (195, 175, 135),
                                        (bx - bw // 2, by, bw, bh))
                    rw = bw + 4
                    rh = max(4, bh)
                    pygame.draw.arc(surf, (175, 35, 28),
                                    (bx - rw // 2, by - rh, rw, rh * 2),
                                    0, math.pi, max(2, r // 16))
                    pygame.draw.arc(surf, (145, 28, 22),
                                    (bx - rw // 2 - 1, by - rh + 1, rw + 2, rh * 2),
                                    0, math.pi, 1)
            # 벚꽃 클러스터 (핑크 원 구름)
            for _ in range(max(5, r // 4)):
                ang = random.uniform(0, math.pi * 2)
                d = random.uniform(r * 0.08, r * 0.85)
                fx = cx + int(d * math.cos(ang))
                fy = cy + int(d * math.sin(ang))
                if not self._in_planet(fx, fy, cx, cy, r - 2):
                    continue
                for _ in range(random.randint(2, 5)):
                    off = max(1, r // 14)
                    px = fx + random.randint(-off, off)
                    py = fy + random.randint(-off, off)
                    ps = max(1, random.randint(1, max(2, r // 18)))
                    pygame.draw.circle(surf, (255, random.randint(150, 230),
                                               random.randint(170, 230)), (px, py), ps)
            # 아치 다리 + 태극
            if r > 30:
                pygame.draw.arc(surf, (155, 135, 105),
                                (cx - r // 4, cy, r // 2, r // 4),
                                0, math.pi, max(1, r // 22))
                tr = max(3, r // 8)
                pygame.draw.circle(surf, (200, 50, 50),
                                   (cx - tr // 3, cy - tr // 3), tr * 2 // 3)
                pygame.draw.circle(surf, (40, 70, 160),
                                   (cx + tr // 3, cy + tr // 3), tr * 2 // 3)
            random.seed()
        self._draw_highlight(surf, cx, cy, r, base, alpha)
        pygame.draw.circle(surf, (255, 210, 120), (cx, cy), r + 1, 1)

    # ── 행성 2: 정글 (밀림캐노피/강/줄기/덩굴/안개) ──
    def _draw_planet_jungle(self, surf, cx, cy, r, alpha=255):
        glow = (100, 200, 80)
        base = (25, 70, 30)
        self._draw_atmo_glow(surf, cx, cy, r, glow, alpha)
        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 12:
            random.seed(2137)
            # 밀림 캐노피 (다양한 크기 겹원 + 잎 하이라이트 호)
            for _ in range(max(15, r)):
                ang = random.uniform(0, math.pi * 2)
                d = random.uniform(0, r * 0.88)
                px = cx + int(d * math.cos(ang))
                py = cy + int(d * math.sin(ang))
                if not self._in_planet(px, py, cx, cy, r - 2):
                    continue
                cr = max(2, int(r * random.uniform(0.04, 0.14)))
                g = random.randint(50, 180)
                pygame.draw.circle(surf, (g // 3, g, g // 4), (px, py), cr)
                pygame.draw.arc(surf, (g // 2, min(255, g + 50), g // 3),
                                (px - cr, py - cr, cr * 2, cr * 2),
                                math.pi * 0.2, math.pi * 1.1, 1)
            # 구불구불 강
            for _ in range(2):
                sa = random.uniform(0, math.pi * 2)
                pts = []
                for step in range(18):
                    t = step / 17
                    ang2 = sa + t * math.pi * random.uniform(0.8, 1.5)
                    d2 = r * (0.08 + t * 0.75)
                    px2 = cx + int(d2 * math.cos(ang2))
                    py2 = cy + int(d2 * math.sin(ang2))
                    if self._in_planet(px2, py2, cx, cy, r):
                        pts.append((px2, py2))
                if len(pts) > 2:
                    pygame.draw.lines(surf, (25, 55, 35), False, pts, max(2, r // 12))
                    pygame.draw.lines(surf, (45, 85, 55), False, pts, max(1, r // 20))
            # 거대 나무 줄기 + 수관
            if r > 20:
                for _ in range(3):
                    tx = cx + random.randint(-r // 2, r // 2)
                    ty = cy + random.randint(-r // 3, r // 3)
                    if not self._in_planet(tx, ty, cx, cy, r - 5):
                        continue
                    th = max(4, r // 4)
                    tw = max(2, r // 14)
                    pygame.draw.line(surf, (80, 50, 25),
                                     (tx, ty + th // 2), (tx, ty - th // 2), tw)
                    # 수관 (나무 꼭대기 둥근 캐노피)
                    ccr = max(3, tw * 3)
                    pygame.draw.circle(surf, (40, random.randint(100, 150), 35),
                                       (tx, ty - th // 2), ccr)
                    pygame.draw.circle(surf, (50, random.randint(130, 180), 40),
                                       (tx - ccr // 2, ty - th // 2 - ccr // 3),
                                       max(2, ccr * 2 // 3))
            # 덩굴 (곡선 + 끝 잎)
            if r > 20:
                for _ in range(5):
                    vx = cx + random.randint(-r // 2, r // 2)
                    vy = cy + random.randint(-r // 2, r // 2)
                    if not self._in_planet(vx, vy, cx, cy, r - 4):
                        continue
                    pts = [(vx, vy)]
                    for vi in range(5):
                        vx += random.randint(-max(1, r // 8), max(1, r // 8))
                        vy += max(1, r // 10)
                        pts.append((vx, vy))
                    pygame.draw.lines(surf, (50, 100, 30), False, pts, 1)
                    pygame.draw.circle(surf, (60, 140, 35), pts[-1], max(1, r // 20))
            # 악어 눈 쌍 (동공 포함)
            if r > 25:
                for _ in range(2):
                    ex = cx + random.randint(-r // 2, r // 2)
                    ey = cy + random.randint(0, r // 2)
                    if self._in_planet(ex, ey, cx, cy, r - 4):
                        es = max(1, r // 22)
                        pygame.draw.circle(surf, (220, 200, 30), (ex - es * 2, ey), es)
                        pygame.draw.circle(surf, (220, 200, 30), (ex + es * 2, ey), es)
                        pygame.draw.circle(surf, (40, 15, 0), (ex - es * 2, ey), max(1, es // 2))
                        pygame.draw.circle(surf, (40, 15, 0), (ex + es * 2, ey), max(1, es // 2))
            # 안개/이끼 (반투명 타원)
            if r > 20:
                for _ in range(5):
                    fx = cx + random.randint(-r + 5, r - 5)
                    fy = cy + random.randint(-r + 5, r - 5)
                    if not self._in_planet(fx, fy, cx, cy, r - 3):
                        continue
                    fr = max(3, int(r * random.uniform(0.08, 0.2)))
                    fs = pygame.Surface((fr * 2 + 4, fr * 2 + 4), pygame.SRCALPHA)
                    for ci in range(fr, 0, -2):
                        fa = max(1, int(12 * ci / fr))
                        pygame.draw.circle(fs, (100, 160, 80, fa), (fr + 2, fr + 2), ci)
                    surf.blit(fs, (fx - fr - 2, fy - fr - 2))
            random.seed()
        self._draw_highlight(surf, cx, cy, r, (50, 120, 50), alpha)
        self._draw_ring(surf, cx, cy, r, (80, 160, 70), alpha)
        pygame.draw.circle(surf, (80, 180, 60), (cx, cy), r + 1, 1)

    # ── 행성 3: 멘헤라 (소용돌이/하트/붕대/알약/눈물) ──
    def _draw_planet_menhera(self, surf, cx, cy, r, alpha=255):
        glow = (255, 120, 220)
        base = (160, 50, 130)
        self._draw_atmo_glow(surf, cx, cy, r, glow, alpha)
        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 12:
            random.seed(3137)
            # 소용돌이 텍스쳐 (나선 색 밴드)
            for sp in range(2):
                offset = sp * math.pi
                for step in range(60):
                    t = step / 59
                    ang = offset + t * math.pi * 6
                    d = t * r * 0.9
                    px = cx + int(d * math.cos(ang))
                    py = cy + int(d * math.sin(ang))
                    if self._in_planet(px, py, cx, cy, r - 1):
                        sc = (180 + random.randint(-20, 30), 40 + random.randint(0, 40),
                              140 + random.randint(-20, 30))
                        pygame.draw.circle(surf, sc, (px, py), max(1, r // 12))
            # 하트 (겹원 + 삼각)
            for _ in range(max(4, r // 7)):
                ang = random.uniform(0, math.pi * 2)
                d = random.uniform(r * 0.05, r * 0.8)
                hx = cx + int(d * math.cos(ang))
                hy = cy + int(d * math.sin(ang))
                if not self._in_planet(hx, hy, cx, cy, r - 3):
                    continue
                hs = max(2, int(r * random.uniform(0.06, 0.14)))
                hc = (255, random.randint(60, 180), random.randint(100, 200))
                pygame.draw.circle(surf, hc, (hx - hs // 3, hy - hs // 4), max(1, hs // 2))
                pygame.draw.circle(surf, hc, (hx + hs // 3, hy - hs // 4), max(1, hs // 2))
                pygame.draw.polygon(surf, hc,
                                    [(hx - hs, hy), (hx + hs, hy), (hx, hy + hs)])
            # 붕대 (X자 + 중앙 매듭)
            if r > 20:
                for _ in range(3):
                    bx = cx + random.randint(-r // 2, r // 2)
                    by2 = cy + random.randint(-r // 2, r // 2)
                    if not self._in_planet(bx, by2, cx, cy, r - 5):
                        continue
                    bl = max(3, r // 6)
                    bw = max(1, r // 22)
                    pygame.draw.line(surf, (245, 225, 205),
                                     (bx - bl, by2 - bl), (bx + bl, by2 + bl), bw)
                    pygame.draw.line(surf, (245, 225, 205),
                                     (bx - bl, by2 + bl), (bx + bl, by2 - bl), bw)
                    pygame.draw.circle(surf, (230, 210, 190), (bx, by2), max(1, bw + 1))
            # 알약 (타원 조합)
            if r > 25:
                for _ in range(2):
                    px = cx + random.randint(-r // 2, r // 2)
                    py = cy + random.randint(-r // 2, r // 2)
                    if not self._in_planet(px, py, cx, cy, r - 5):
                        continue
                    pw = max(3, r // 7)
                    ph = max(2, pw // 3)
                    pygame.draw.ellipse(surf, (255, 200, 200),
                                        (px - pw, py - ph, pw, ph * 2))
                    pygame.draw.ellipse(surf, (200, 80, 120),
                                        (px, py - ph, pw, ph * 2))
            # 눈물 (타원 물방울)
            for _ in range(max(4, r // 5)):
                tx = cx + random.randint(-r + 3, r - 3)
                ty = cy + random.randint(-r + 3, r - 3)
                if self._in_planet(tx, ty, cx, cy, r - 2):
                    tl = max(2, random.randint(2, max(3, r // 8)))
                    pygame.draw.ellipse(surf, (180, 200, 255),
                                        (tx - 1, ty, 2, tl))
            # 균열 (곡선 가지치기)
            if r > 20:
                for _ in range(3):
                    sx = cx + random.randint(-r // 3, r // 3)
                    sy = cy + random.randint(-r // 3, r // 3)
                    pts = [(sx, sy)]
                    for _ in range(6):
                        sx += random.randint(-max(1, r // 6), max(1, r // 6))
                        sy += random.randint(-max(1, r // 10), max(1, r // 5))
                        pts.append((sx, sy))
                    if len(pts) > 2:
                        pygame.draw.lines(surf, (80, 10, 60), False, pts, 1)
            random.seed()
        self._draw_highlight(surf, cx, cy, r, (200, 80, 170), alpha)
        self._draw_ring(surf, cx, cy, r, (200, 80, 180), alpha)
        pygame.draw.circle(surf, (220, 100, 200), (cx, cy), r + 1, 1)

    # ── 행성 4: 사원 (돔/기둥/만다라/향연기/계단) ──
    def _draw_planet_temple(self, surf, cx, cy, r, alpha=255):
        glow = (220, 180, 100)
        base = (140, 100, 60)
        self._draw_atmo_glow(surf, cx, cy, r, glow, alpha)
        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 12:
            random.seed(4137)
            # 사암 텍스쳐 (동심 편심원 + 미세 색변화)
            for ri in range(r - 2, max(2, r // 5), -max(2, r // 10)):
                ox = random.randint(-2, 2)
                oy = random.randint(-2, 2)
                shade = random.randint(-15, 15)
                col = (_clamp(138 + shade), _clamp(98 + shade), _clamp(58 + shade // 2))
                pygame.draw.circle(surf, col, (cx + ox, cy + oy), ri)
            # 돔 사원 (반원형 건물 + 기둥)
            if r > 18:
                for _ in range(3):
                    bx = cx + random.randint(-r // 2, r // 2)
                    by = cy + random.randint(-r // 3, r // 2)
                    if not self._in_planet(bx, by, cx, cy, r - 5):
                        continue
                    bw = max(4, int(r * 0.16))
                    # 돔 채우기
                    pygame.draw.ellipse(surf, (170, 140, 90),
                                        (bx - bw, by - bw // 3, bw * 2, bw))
                    # 돔 호
                    pygame.draw.arc(surf, (180, 150, 95),
                                    (bx - bw, by - bw, bw * 2, bw * 2),
                                    0, math.pi, max(2, r // 14))
                    # 기둥 (둥근 세로)
                    pw = max(1, r // 20)
                    ph = max(3, bw * 2 // 3)
                    pygame.draw.ellipse(surf, (185, 160, 105),
                                        (bx - bw + 2, by, pw * 2, ph))
                    pygame.draw.ellipse(surf, (185, 160, 105),
                                        (bx + bw - pw * 2 - 2, by, pw * 2, ph))
                    # 첨탑
                    pygame.draw.circle(surf, (210, 185, 120), (bx, by - bw), max(1, pw))
                    pygame.draw.line(surf, (200, 175, 110),
                                     (bx, by - bw), (bx, by - bw - max(2, bw // 3)), 1)
            # 계단 (호 형태)
            if r > 28:
                stx = cx + random.randint(-r // 4, r // 4)
                sty = cy + random.randint(r // 6, r // 3)
                for si in range(5):
                    sw = max(3, int(r * 0.2) - si * max(1, r // 15))
                    if sw < 2:
                        break
                    pygame.draw.arc(surf, (160, 130, 85),
                                    (stx - sw, sty - si * 2 - sw // 2, sw * 2, sw),
                                    0, math.pi, 1)
            # 만다라 (동심원 + 12방사선 + 끝 장식)
            if r > 28:
                for ri in range(4, 0, -1):
                    mr = max(2, r * ri // 12)
                    pygame.draw.circle(surf, (200, 170, 100), (cx, cy), mr, 1)
                for i in range(12):
                    ang = i * math.pi / 6
                    el = max(3, r // 3)
                    ex = cx + int(el * math.cos(ang))
                    ey = cy + int(el * math.sin(ang))
                    pygame.draw.line(surf, (190, 160, 90), (cx, cy), (ex, ey), 1)
                    pygame.draw.circle(surf, (210, 180, 110), (ex, ey), max(1, r // 22))
            # 향로 연기 (곡선 나선 + 뭉치)
            for _ in range(max(3, r // 6)):
                sx = cx + random.randint(-r // 2, r // 2)
                sy = cy + random.randint(-r + 5, r - 5)
                if not self._in_planet(sx, sy, cx, cy, r - 2):
                    continue
                pts = [(sx, sy)]
                for si in range(4):
                    sx += random.randint(-max(1, r // 12), max(1, r // 12))
                    sy -= max(1, r // 14)
                    pts.append((sx, sy))
                if len(pts) > 1:
                    pygame.draw.lines(surf, (195, 175, 140), False, pts, 1)
                sr = max(1, random.randint(1, max(2, r // 16)))
                pygame.draw.circle(surf, (200, 185, 150), (sx, sy), sr)
            random.seed()
        self._draw_highlight(surf, cx, cy, r, base, alpha)
        pygame.draw.circle(surf, (200, 160, 90), (cx, cy), r + 1, 1)

    # ── 행성 5: 해상전투 (대양/파도곡선/섬/범선/등대/소용돌이) ──
    def _draw_planet_ocean(self, surf, cx, cy, r, alpha=255):
        glow = (80, 150, 255)
        base = (30, 60, 140)
        self._draw_atmo_glow(surf, cx, cy, r, glow, alpha)
        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 12:
            random.seed(5137)
            # 바다 깊이 그라디언트 (동심원 음영)
            for ri in range(r - 2, max(2, r // 6), -max(2, r // 8)):
                t = ri / max(1, r)
                b = int(100 + 60 * t)
                g = int(50 + 40 * t)
                pygame.draw.circle(surf, (20 + int(15 * t), g, _clamp(b)),
                                   (cx, cy), ri)
            # 파도 곡선 (부드러운 사인파)
            for by in range(-r + 3, r, max(3, r // 8)):
                bw = int(math.sqrt(max(0, r * r - by * by)))
                if bw < 3:
                    continue
                pts = []
                wave_a = max(1, r // 16)
                phase = by * 0.08
                for sx in range(-bw, bw + 1, max(2, bw // 10)):
                    wy = by + int(wave_a * math.sin(sx * 0.12 + phase))
                    pts.append((cx + sx, cy + wy))
                if len(pts) > 1:
                    depth = abs(by) / max(1, r)
                    b = _clamp(140 + int(80 * (1 - depth)))
                    pygame.draw.lines(surf, (40, 70 + int(40 * depth), b),
                                      False, pts, 1)
            # 초록 섬 (부드러운 타원)
            for _ in range(4):
                ang = random.uniform(0, math.pi * 2)
                d = random.uniform(r * 0.15, r * 0.6)
                ix = cx + int(d * math.cos(ang))
                iy = cy + int(d * math.sin(ang))
                if not self._in_planet(ix, iy, cx, cy, r - 4):
                    continue
                iw = max(3, int(r * random.uniform(0.08, 0.18)))
                ih = max(2, int(iw * random.uniform(0.5, 0.8)))
                ic = (60 + random.randint(0, 40), 120 + random.randint(0, 40),
                      40 + random.randint(0, 25))
                pygame.draw.ellipse(surf, ic, (ix - iw, iy - ih, iw * 2, ih * 2))
                pygame.draw.ellipse(surf, (200, 190, 140),
                                    (ix - iw, iy - ih, iw * 2, ih * 2), 1)
            # 범선 (곡선 선체 + 호형 돛)
            if r > 22:
                for _ in range(3):
                    sx = cx + random.randint(-r // 2, r // 2)
                    sy = cy + random.randint(-r // 2, r // 2)
                    if not self._in_planet(sx, sy, cx, cy, r - 5):
                        continue
                    sw = max(4, r // 7)
                    sh = max(2, sw // 3)
                    pygame.draw.ellipse(surf, (100, 85, 65),
                                        (sx - sw // 2, sy, sw, sh))
                    mh = max(3, sw * 2 // 3)
                    pygame.draw.line(surf, (140, 130, 110),
                                     (sx, sy), (sx, sy - mh), 1)
                    pygame.draw.arc(surf, (230, 220, 200),
                                    (sx, sy - mh, max(2, sw // 2), mh),
                                    -math.pi * 0.1, math.pi * 1.1, max(1, r // 25))
            # 등대 (둥근 + 빛 방출)
            if r > 28:
                lx = cx + random.randint(-r // 4, r // 4)
                ly = cy + random.randint(-r // 4, r // 4)
                if self._in_planet(lx, ly, cx, cy, r - 5):
                    lh = max(5, r // 5)
                    lw = max(2, r // 16)
                    pygame.draw.ellipse(surf, (210, 200, 180),
                                        (lx - lw, ly - lh, lw * 2, lh))
                    for li in range(3):
                        la = -math.pi / 2 + (li - 1) * 0.3
                        lex = lx + int(max(4, lh * 0.6) * math.cos(la))
                        ley = ly - lh + int(max(4, lh * 0.6) * math.sin(la))
                        pygame.draw.line(surf, (255, 255, 180),
                                         (lx, ly - lh), (lex, ley), 1)
                    pygame.draw.circle(surf, (255, 255, 200), (lx, ly - lh), max(1, lw))
            # 소용돌이 (나선)
            if r > 25:
                for _ in range(2):
                    sa = random.uniform(0, math.pi * 2)
                    sd = random.uniform(r * 0.2, r * 0.5)
                    scx2 = cx + int(sd * math.cos(sa))
                    scy2 = cy + int(sd * math.sin(sa))
                    if not self._in_planet(scx2, scy2, cx, cy, r - 5):
                        continue
                    sr = max(3, r // 7)
                    pts = []
                    for si in range(16):
                        t = si / 15
                        sa2 = t * math.pi * 3
                        sd2 = sr * 0.08 + t * sr * 0.8
                        pts.append((scx2 + int(sd2 * math.cos(sa2)),
                                    scy2 + int(sd2 * math.sin(sa2))))
                    if len(pts) > 2:
                        pygame.draw.lines(surf, (60, 100, 180), False, pts, 1)
            # 물거품 (흰 점)
            for _ in range(max(3, r // 5)):
                fx = cx + random.randint(-r + 3, r - 3)
                fy = cy + random.randint(-r + 3, r - 3)
                if self._in_planet(fx, fy, cx, cy, r - 2):
                    pygame.draw.circle(surf, (200, 220, 255),
                                       (fx, fy), max(1, random.randint(1, max(2, r // 22))))
            random.seed()
        self._draw_highlight(surf, cx, cy, r, (50, 100, 180), alpha)
        self._draw_ring(surf, cx, cy, r, (60, 120, 200), alpha)
        pygame.draw.circle(surf, (80, 160, 255), (cx, cy), r + 1, 1)

    # ── 행성 6: 화염 (용암/화산/불꽃/균열곡선/잿빛) ──
    def _draw_planet_fire(self, surf, cx, cy, r, alpha=255):
        glow = (255, 100, 50)
        base = (80, 20, 10)
        # 붉은 글로우
        grr = r + 40
        gs = pygame.Surface((grr * 2 + 4, grr * 2 + 4), pygame.SRCALPHA)
        gcx = grr + 2
        for i in range(40, 0, -2):
            a = max(1, int(30 * alpha / 255 * (1 - i / 40)))
            pygame.draw.circle(gs, (_clamp(255 - i * 2), _clamp(80 - i), 20, a),
                               (gcx, gcx), r + i)
        surf.blit(gs, (cx - grr - 2, cy - grr - 2))
        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 12:
            random.seed(6137)
            # 용암 텍스쳐 (편심 뜨거운 원 패치)
            for _ in range(max(8, r // 3)):
                ox = random.randint(-r // 2, r // 2)
                oy = random.randint(-r // 2, r // 2)
                if not self._in_planet(cx + ox, cy + oy, cx, cy, r - 2):
                    continue
                pr = random.randint(max(2, r // 8), max(4, r // 3))
                heat = random.randint(0, 60)
                pygame.draw.circle(surf, (80 + heat, 15 + heat // 4, 5),
                                   (cx + ox, cy + oy), pr)
            # 용암 균열 (곡선 가지치기)
            for _ in range(max(6, r // 4)):
                sx = cx + random.randint(-r + 3, r - 3)
                sy = cy + random.randint(-r + 3, r - 3)
                if not self._in_planet(sx, sy, cx, cy, r - 2):
                    continue
                pts = [(sx, sy)]
                for _ in range(random.randint(3, 7)):
                    sx += random.randint(-max(1, r // 5), max(1, r // 5))
                    sy += random.randint(-max(1, r // 5), max(1, r // 5))
                    pts.append((sx, sy))
                if len(pts) > 1:
                    pygame.draw.lines(surf, (220, random.randint(80, 160), 15),
                                      False, pts, 1)
            # 용암 강 (밝은 곡선 — 글로우 + 코어)
            for _ in range(4):
                sa = random.uniform(0, math.pi * 2)
                pts = []
                for step in range(10):
                    t = step / 9
                    ang = sa + t * math.pi * random.uniform(0.5, 1.0)
                    d = r * (0.05 + t * 0.75)
                    px = cx + int(d * math.cos(ang))
                    py = cy + int(d * math.sin(ang))
                    pts.append((px, py))
                if len(pts) > 1:
                    pygame.draw.lines(surf, (200, random.randint(80, 130), 10),
                                      False, pts, max(2, r // 10))
                    pygame.draw.lines(surf, (255, random.randint(200, 255), random.randint(40, 100)),
                                      False, pts, max(1, r // 18))
            # 화산 (둥근 산 + 분화구 글로우)
            if r > 20:
                for _ in range(3):
                    vx = cx + random.randint(-r // 2, r // 2)
                    vy = cy + random.randint(-r // 2, r // 2)
                    if not self._in_planet(vx, vy, cx, cy, r - 5):
                        continue
                    vr = max(4, r // 5)
                    # 산체 (타원)
                    pygame.draw.ellipse(surf, (55, 12, 5),
                                        (vx - vr, vy - vr // 3, vr * 2, vr))
                    # 분화구 글로우 (동심 원)
                    cr = max(2, vr // 3)
                    for gi in range(cr, 0, -1):
                        ga = max(1, int(40 * gi / cr))
                        pygame.draw.circle(surf, (255, 150 + int(80 * gi / cr), 30, ga),
                                           (vx, vy - vr // 3 + cr // 2), gi)
                    for _ in range(2):
                        smx = vx + random.randint(-cr, cr)
                        smy = vy - vr // 3 - random.randint(1, max(2, vr // 2))
                        pygame.draw.circle(surf, (100, 70, 50), (smx, smy), max(1, cr // 3))
            # 불기둥 (호형 + 불꽃 글로우)
            if r > 25:
                for _ in range(3):
                    fx = cx + random.randint(-r // 2, r // 2)
                    fy = cy + random.randint(-r // 2, r // 2)
                    if not self._in_planet(fx, fy, cx, cy, r - 4):
                        continue
                    fh = max(4, r // 4)
                    pygame.draw.arc(surf, (255, 200, 50),
                                    (fx - max(1, r // 20), fy - fh,
                                     max(2, r // 10), fh),
                                    -math.pi * 0.1, math.pi * 1.1, max(1, r // 22))
                    pygame.draw.circle(surf, (255, 255, 120), (fx, fy - fh), max(1, r // 16))
                    pygame.draw.circle(surf, (255, 200, 50), (fx, fy - fh), max(1, r // 12))
            # 불꽃 파티클
            for _ in range(max(8, r // 3)):
                fx = cx + random.randint(-r + 2, r - 2)
                fy = cy + random.randint(-r + 2, r - 2)
                if self._in_planet(fx, fy, cx, cy, r - 1):
                    fs = max(1, random.randint(1, max(2, r // 20)))
                    pygame.draw.circle(surf, (255, random.randint(100, 230), 0), (fx, fy), fs)
            random.seed()
        self._draw_highlight(surf, cx, cy, r, (230, 100, 60), alpha)
        self._draw_ring(surf, cx, cy, r, (255, 80, 30), alpha)
        pygame.draw.circle(surf, (255, 120, 40), (cx, cy), r + 1, 1)

    # ── 행성 7: 테트리스 (네온블록/글로우격자/라인클리어) ──
    def _draw_planet_tetris(self, surf, cx, cy, r, alpha=255):
        glow = (160, 200, 255)
        base = (15, 18, 40)
        self._draw_atmo_glow(surf, cx, cy, r, glow, alpha)
        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 12:
            random.seed(7137)
            tetro_colors = [
                (0, 240, 240), (240, 240, 0), (160, 0, 240),
                (0, 240, 0), (240, 0, 0), (0, 0, 240), (240, 160, 0),
            ]
            block_sz = max(3, r // 8)
            # 네온 블록 (원형 경계 안)
            for gx in range(-r + 1, r, block_sz):
                for gy in range(-r + 1, r, block_sz):
                    bcx2 = cx + gx + block_sz // 2
                    bcy2 = cy + gy + block_sz // 2
                    if not self._in_planet(bcx2, bcy2, cx, cy, r - 1):
                        continue
                    if random.random() < 0.88:
                        col = random.choice(tetro_colors)
                        bx = cx + gx
                        by = cy + gy
                        dim = tuple(max(0, c * 2 // 5) for c in col)
                        pygame.draw.rect(surf, dim,
                                         (bx + 1, by + 1, block_sz - 2, block_sz - 2))
                        pygame.draw.rect(surf, col,
                                         (bx, by, block_sz - 1, block_sz - 1), 1)
                        hl = tuple(min(255, c + 80) for c in col)
                        pygame.draw.line(surf, hl, (bx + 1, by + 1),
                                         (bx + block_sz - 3, by + 1), 1)
                    else:
                        pygame.draw.rect(surf, (18, 22, 48),
                                         (cx + gx, cy + gy, block_sz - 1, block_sz - 1), 1)
            # 라인 클리어 (글로우 밴드)
            if r > 20:
                for _ in range(2):
                    ly = cy + random.randint(-r // 2, r // 2)
                    bw = int(math.sqrt(max(0, r * r - (ly - cy) ** 2)))
                    if bw > 3:
                        ls = pygame.Surface((bw * 2, block_sz + 2), pygame.SRCALPHA)
                        ls.fill((255, 255, 255, 25))
                        surf.blit(ls, (cx - bw, ly - 1))
            # 격자 오버레이 (부드러운)
            if r > 22:
                for gx in range(-r, r + 1, block_sz):
                    bw = int(math.sqrt(max(0, r * r - gx * gx)))
                    if bw > 1:
                        pygame.draw.line(surf, (30, 40, 80),
                                         (cx + gx, cy - bw), (cx + gx, cy + bw), 1)
                for gy in range(-r, r + 1, block_sz):
                    bw = int(math.sqrt(max(0, r * r - gy * gy)))
                    if bw > 1:
                        pygame.draw.line(surf, (30, 40, 80),
                                         (cx - bw, cy + gy), (cx + bw, cy + gy), 1)
            random.seed()
        self._draw_highlight(surf, cx, cy, r, (80, 110, 200), alpha)
        self._draw_ring(surf, cx, cy, r, (100, 150, 255), alpha)
        pygame.draw.circle(surf, (120, 180, 255), (cx, cy), r + 1, 1)
        if r > 20:
            pygame.draw.circle(surf, (80, 140, 255), (cx, cy), r + 3, 1)

    # ── 행성 8: 그림자 (안개도시/나선/달빛/수리검/칼날호) ──
    def _draw_planet_shadow(self, surf, cx, cy, r, alpha=255):
        glow = (100, 130, 180)
        base = (18, 20, 32)
        # 어두운 글로우
        grr = r + 35
        gs = pygame.Surface((grr * 2 + 4, grr * 2 + 4), pygame.SRCALPHA)
        gcx = grr + 2
        for i in range(35, 0, -2):
            a = max(1, int(20 * alpha / 255 * (1 - i / 35)))
            pygame.draw.circle(gs, (40, 45, 70, a), (gcx, gcx), r + i)
        surf.blit(gs, (cx - grr - 2, cy - grr - 2))
        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 12:
            random.seed(8137)
            # 어둠 소용돌이 (부드러운 나선)
            for sp in range(3):
                pts = []
                offset = sp * math.pi * 2 / 3
                for step in range(50):
                    t = step / 49
                    ang = offset + t * math.pi * 5
                    d = r * 0.05 + t * r * 0.75
                    px = cx + int(d * math.cos(ang))
                    py = cy + int(d * math.sin(ang))
                    if self._in_planet(px, py, cx, cy, r):
                        pts.append((px, py))
                if len(pts) > 2:
                    pygame.draw.lines(surf, (25 + sp * 5, 28 + sp * 5, 45 + sp * 5),
                                      False, pts, 1)
            # 도시 실루엣 (둥근 빌딩 타원 + 첨탑)
            if r > 20:
                sky_y = cy + r // 6
                for _ in range(max(5, r // 5)):
                    bx_off = random.randint(-r + 5, r - 5)
                    if not self._in_planet(cx + bx_off, sky_y, cx, cy, r - 2):
                        continue
                    bh = random.randint(max(3, r // 8), max(5, r // 3))
                    bw = max(2, r // 10)
                    bc = (22 + random.randint(0, 12), 25 + random.randint(0, 12),
                          40 + random.randint(0, 15))
                    pygame.draw.ellipse(surf, bc,
                                        (cx + bx_off - bw // 2, sky_y - bh, bw, bh))
                    if random.random() < 0.4:
                        pygame.draw.circle(surf, (40, 45, 65),
                                           (cx + bx_off, sky_y - bh - max(1, bh // 5)),
                                           max(1, bw // 4))
                    for wy in range(sky_y - bh + 2, sky_y - 1, max(2, bh // 3)):
                        if random.random() < 0.4:
                            pygame.draw.circle(surf, (180, 170, 80),
                                               (cx + bx_off, wy), 1)
            # 초승달 (글로우 + 마스킹)
            if r > 25:
                mx = cx + r // 4
                my = cy - r // 3
                mr = max(3, r // 6)
                for gi in range(mr + 3, 0, -1):
                    ga = max(1, int(15 * gi / (mr + 3)))
                    ms = pygame.Surface((gi * 2 + 4, gi * 2 + 4), pygame.SRCALPHA)
                    pygame.draw.circle(ms, (120, 130, 160, ga),
                                       (gi + 2, gi + 2), gi)
                    surf.blit(ms, (mx - gi - 2, my - gi - 2))
                pygame.draw.circle(surf, (190, 200, 220), (mx, my), mr)
                pygame.draw.circle(surf, base, (mx + mr // 2, my - mr // 4), mr)
            # 수리검 (부드러운 8각별)
            if r > 25:
                for _ in range(3):
                    sx = cx + random.randint(-r // 2, r // 2)
                    sy = cy + random.randint(-r // 2, r // 2)
                    if not self._in_planet(sx, sy, cx, cy, r - 5):
                        continue
                    sr = max(2, r // 10)
                    pts = []
                    for i in range(8):
                        ang = i * math.pi / 4
                        d = sr if i % 2 == 0 else max(1, sr // 2)
                        pts.append((sx + int(d * math.cos(ang)),
                                    sy + int(d * math.sin(ang))))
                    pygame.draw.polygon(surf, (70, 80, 110), pts)
                    pygame.draw.polygon(surf, (100, 115, 150), pts, 1)
            # 안개 (부드러운 반투명 구름)
            for _ in range(max(8, r // 3)):
                fx = cx + random.randint(-r + 3, r - 3)
                fy = cy + random.randint(-r + 3, r - 3)
                if not self._in_planet(fx, fy, cx, cy, r - 2):
                    continue
                fr = random.randint(max(2, r // 10), max(4, r // 4))
                fs = pygame.Surface((fr * 2 + 4, fr * 2 + 4), pygame.SRCALPHA)
                for ci in range(fr, 0, -2):
                    fa = max(1, int(8 * ci / fr))
                    pygame.draw.circle(fs, (28, 32, 52, fa), (fr + 2, fr + 2), ci)
                surf.blit(fs, (fx - fr - 2, fy - fr - 2))
            # 칼날 빛 (호형 반사)
            if r > 28:
                for _ in range(2):
                    ka = random.uniform(0, math.pi * 2)
                    kd = random.uniform(r * 0.15, r * 0.5)
                    kx = cx + int(kd * math.cos(ka))
                    ky = cy + int(kd * math.sin(ka))
                    kl = max(5, r // 3)
                    pygame.draw.arc(surf, (140, 155, 185),
                                    (kx - kl // 2, ky - kl // 4, kl, kl // 2),
                                    ka, ka + math.pi * 0.6, 1)
            random.seed()
        self._draw_highlight(surf, cx, cy, r, (40, 45, 70), alpha)
        pygame.draw.circle(surf, (50, 55, 80), (cx, cy), r + 1, 1)

    # ── 행성 테마 디스패처 ──
    _PLANET_RENDERERS = {
        1: '_draw_planet_joseon',
        2: '_draw_planet_jungle',
        3: '_draw_planet_menhera',
        4: '_draw_planet_temple',
        5: '_draw_planet_ocean',
        6: '_draw_planet_fire',
        7: '_draw_planet_tetris',
        8: '_draw_planet_shadow',
    }

    # 행성별 자전 속도 (도/초) — 성격에 맞게 차등
    _PLANET_ROT_SPEEDS = {
        1: 3.0,   # 조선 — 차분
        2: 2.5,   # 정글 — 느릿
        3: 4.0,   # 멘헤라 — 불안정
        4: 2.0,   # 사원 — 장중
        5: 3.5,   # 해양 — 파도리듬
        6: 4.5,   # 화염 — 격렬
        7: 0.5,   # 테트리스 — 거의 정지
        8: 1.5,   # 그림자 — 은밀
    }

    def _draw_dest_planet(self, surf, cx, cy, radius, planet_num, alpha=255):
        renderer_name = self._PLANET_RENDERERS.get(planet_num)
        if not renderer_name:
            # 폴백: 기본 렌더링
            config = PLANET_CONFIGS.get(planet_num, {})
            base = config.get("theme_color", (100, 100, 100))
            glow = config.get("glow_color", (150, 150, 150))
            self._draw_atmo_glow(surf, cx, cy, radius, glow, alpha)
            pygame.draw.circle(surf, base, (cx, cy), radius)
            self._draw_highlight(surf, cx, cy, radius, base, alpha)
            pygame.draw.circle(surf, glow, (cx, cy), radius + 1, 1)
            return

        # --- 회전 + 3D 구체 렌더링 ---
        pad = max(20, radius // 2)  # 회전 시 잘림 방지 여유
        size = (radius + pad) * 2
        # 임시 서피스에 행성을 중앙에 그린다
        tmp = pygame.Surface((size, size), pygame.SRCALPHA)
        tc = size // 2  # 임시 서피스 중앙
        getattr(self, renderer_name)(tmp, tc, tc, radius, alpha)

        # 자전 회전 적용
        rot_speed = self._PLANET_ROT_SPEEDS.get(planet_num, 2.0)
        rot_deg = (self.time * rot_speed) % 360
        if abs(rot_deg) > 0.01:
            rotated = pygame.transform.rotate(tmp, rot_deg)
        else:
            rotated = tmp

        # 원형 마스크 클리핑 (BLEND_RGBA_MIN 방식 — 빠름)
        clip_size = radius * 2 + 4
        mc = radius + 2  # 클립 서피스 중앙

        # 회전된 행성을 클립 서피스에 중앙 정렬 blit
        clipped = pygame.Surface((clip_size, clip_size), pygame.SRCALPHA)
        rr = rotated.get_rect()
        clipped.blit(rotated, (mc - rr.width // 2, mc - rr.height // 2))

        # 원형 마스크 생성: 원 안쪽만 (255,255,255,255), 바깥은 (0,0,0,0)
        mask = pygame.Surface((clip_size, clip_size), pygame.SRCALPHA)
        pygame.draw.circle(mask, (255, 255, 255, 255), (mc, mc), radius)

        # BLEND_RGBA_MIN 으로 원 바깥 알파를 0으로 제거
        clipped.blit(mask, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)

        surf.blit(clipped, (cx - mc, cy - mc))

        # 3D 구체 셰이딩 오버레이 (회전하지 않음 — 광원 고정감)
        self._draw_sphere_shading(surf, cx, cy, radius, alpha)

    # ──────────────────────────────────────────────
    #  콕핏 HUD 동적 요소
    # ──────────────────────────────────────────────
    def show_landing_scene(self, to_planet, duration=3.5, fade_out=True,
                           ingame_frame=None):
        """하늘에서 하강하며 지형이 드러나고 경기장이 커지는 착륙 장면.
        duration: 전체 시간(초). fade_out: False면 끝에 페이드아웃 없이 유지.
        ingame_frame: 실제 인게임 화면 Surface (경기장 대신 사용)."""
        clock = pygame.time.Clock()
        total_frames = int(duration * 60)
        FADE_IN = 20   # 초반 페이드인
        FADE_OUT = 25  # 끝 페이드아웃

        # 줌 캐시 (표면은 t값이 바뀔 때만 재렌더)
        _surf_cache_key = -1
        _surf_cached = None

        def _ease_out(x):
            return 1.0 - (1.0 - x) ** 2.5

        for frame in range(total_frames):
            for ev in pygame.event.get():
                if ev.type == pygame.QUIT:
                    return
                if ev.type == pygame.KEYDOWN:
                    if ev.key in (pygame.K_ESCAPE, pygame.K_SPACE, pygame.K_RETURN):
                        return

            t = frame / total_frames       # 0 → 1
            et = _ease_out(t)              # ease-out (처음 빠르고 끝에 느리게)

            # ── 하강 파라미터 ──
            # surface_detail: 0(고공/구름) → 1(지표면)
            surface_detail = min(1.0, et * 1.3)
            # 카메라 줌: 1.0(먼 곳) → 2.8(지표 클로즈업)
            cam_zoom = 1.0 + et * 1.8
            # 경기장 스케일
            if ingame_frame is not None:
                # 인게임 프레임: 1초간 작은 경기장 유지 → 이후 확대
                hold_ratio = 1.0 / duration  # ~0.286 (1초/3.5초)
                if t < hold_ratio:
                    arena_scale = 0.12
                else:
                    grow_t = (t - hold_ratio) / (1.0 - hold_ratio)
                    grow_et = 1.0 - (1.0 - grow_t) ** 2.5
                    arena_scale = 0.12 + 0.88 * grow_et
            else:
                # 커스텀 경기장: 15% 지점부터 등장
                arena_appear = max(0.0, (et - 0.15) / 0.85)
                arena_scale = arena_appear * 1.0

            # ── 표면 렌더 (캐시 — 10단계) ──
            cache_key = int(surface_detail * 10)
            if cache_key != _surf_cache_key:
                _surf_cached = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
                self._draw_planet_surface(_surf_cached, to_planet, surface_detail)
                _surf_cache_key = cache_key

            # ── 줌 적용: 표면을 확대해서 중앙 크롭 ──
            if cam_zoom > 1.01:
                zw = int(self.W / cam_zoom)
                zh = int(self.H / cam_zoom)
                crop_x = (self.W - zw) // 2
                crop_y = (self.H - zh) // 2
                cropped = _surf_cached.subsurface((crop_x, crop_y, zw, zh))
                scaled = pygame.transform.scale(cropped, (self.W, self.H))
                self.screen.blit(scaled, (0, 0))
            else:
                self.screen.blit(_surf_cached, (0, 0))

            # ── 경기장 (점점 커지며 등장) ──
            if arena_scale > 0.05:
                if ingame_frame is not None:
                    # 실제 인게임 화면을 경기장으로 사용
                    ig_w = int(self.W * arena_scale)
                    ig_h = int(self.H * arena_scale)
                    if ig_w > 4 and ig_h > 4:
                        scaled_ig = pygame.transform.smoothscale(
                            ingame_frame, (ig_w, ig_h))
                        ix = (self.W - ig_w) // 2
                        iy = (self.H - ig_h) // 2
                        self.screen.blit(scaled_ig, (ix, iy))
                        # 테마별 경기장 외곽 테두리
                        if to_planet == 1:
                            self._draw_joseon_arena_border(
                                self.screen, ix, iy, ig_w, ig_h, arena_scale)
                        elif to_planet == 2:
                            self._draw_jungle_arena_border(
                                self.screen, ix, iy, ig_w, ig_h, arena_scale)
                        elif to_planet == 3:
                            self._draw_menhera_arena_border(
                                self.screen, ix, iy, ig_w, ig_h, arena_scale)
                        elif to_planet == 4:
                            self._draw_temple_arena_border(
                                self.screen, ix, iy, ig_w, ig_h, arena_scale)
                        elif to_planet == 30:
                            self._draw_colosseum_arena_border(
                                self.screen, ix, iy, ig_w, ig_h, arena_scale)
                else:
                    # 폴백: 커스텀 경기장 드로잉
                    arena_surf = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
                    self._draw_landing_arena(arena_surf, self.W // 2, self.H // 2,
                                             arena_scale, to_planet)
                    if cam_zoom > 1.01:
                        zw_a = int(self.W / cam_zoom)
                        zh_a = int(self.H / cam_zoom)
                        crop_x_a = (self.W - zw_a) // 2
                        crop_y_a = (self.H - zh_a) // 2
                        cropped_a = arena_surf.subsurface(
                            (crop_x_a, crop_y_a, zw_a, zh_a))
                        scaled_a = pygame.transform.scale(cropped_a,
                                                          (self.W, self.H))
                        self.screen.blit(scaled_a, (0, 0))
                    else:
                        self.screen.blit(arena_surf, (0, 0))

            # ── 페이드인 (검은 화면에서) ──
            if frame < FADE_IN:
                fade_a = int(255 * (1.0 - frame / FADE_IN))
                fade_s = pygame.Surface((self.W, self.H))
                fade_s.fill((0, 0, 0))
                fade_s.set_alpha(fade_a)
                self.screen.blit(fade_s, (0, 0))

            # ── 페이드아웃 (마지막) ──
            if fade_out and frame > total_frames - FADE_OUT:
                fade_a = int(255 * (frame - (total_frames - FADE_OUT)) / FADE_OUT)
                fade_s = pygame.Surface((self.W, self.H))
                fade_s.fill((0, 0, 0))
                fade_s.set_alpha(fade_a)
                self.screen.blit(fade_s, (0, 0))

            pygame.display.flip()
            clock.tick(60)


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
def _compute_planet_positions(w, h, count=8):
    positions = []
    mt, mb = 90, 90
    uh = h - mt - mb
    cx = w // 2
    amp = 170
    for i in range(count):
        t = i / max(1, count - 1)
        y = mt + int(uh * t)
        x = cx + int(amp * math.sin(t * math.pi * 2 - math.pi * 0.5))
        if i == 0:
            x = cx
        positions.append((x, y))
    return positions


# ═══════════════════════════════════════════════════════════
#  1인칭 워프 스타 (중앙 → 바깥 방사)
# ═══════════════════════════════════════════════════════════
class _WarpStar:
    __slots__ = ('angle', 'dist', 'speed', 'max_dist',
                 'brightness', 'color', 'trail_len')

    def __init__(self, w, h, start_near=False):
        self.angle = random.uniform(0, math.pi * 2)
        self.max_dist = math.hypot(w, h) * 0.6
        self.dist = random.uniform(0, self.max_dist * 0.3) if start_near \
            else random.uniform(0, self.max_dist)
        self.speed = random.uniform(80, 300)
        self.brightness = random.randint(150, 255)
        ct = random.random()
        if ct < 0.4:
            self.color = (200, 210, 255)
        elif ct < 0.7:
            self.color = (255, 255, 240)
        elif ct < 0.85:
            self.color = (255, 230, 180)
        else:
            self.color = (255, 180, 150)
        self.trail_len = random.uniform(0.3, 1.0)


# ═══════════════════════════════════════════════════════════
#  횡스크롤 별 (패럴랙스)
# ═══════════════════════════════════════════════════════════
class _StarLayer:
    __slots__ = ('x', 'y', 'speed', 'size', 'brightness',
                 'color', 'twinkle_speed', 'twinkle_phase')

    def __init__(self, w, h, speed_range, size_range, color_mode='mixed'):
        self.x = random.uniform(0, w)
        self.y = random.uniform(0, h)
        self.speed = random.uniform(*speed_range)
        self.size = random.choice(size_range)
        self.brightness = random.randint(120, 255)
        self.twinkle_speed = random.uniform(1.5, 5.0)
        self.twinkle_phase = random.uniform(0, math.pi * 2)
        tints = {
            'blue': lambda: (
                random.randint(140, 195),
                random.randint(170, 225),
                random.randint(200, 255)),
            'warm': lambda: (
                random.randint(200, 255),
                random.randint(120, 200),
                random.randint(80, 150)),
        }
        if color_mode in tints:
            self.color = tints[color_mode]()
        else:
            self.color = random.choice([
                (255, 255, 240), (200, 220, 255), (255, 240, 200),
                (180, 200, 255), (255, 200, 180),
            ])


# ═══════════════════════════════════════════════════════════
#  성운 (네뷸라) — 반투명 가스 구름
# ═══════════════════════════════════════════════════════════
class _Nebula:
    def __init__(self, w, h, scroll_speed=0.5):
        self.x = random.uniform(-100, w + 200)
        self.y = random.uniform(0, h)
        self.radius = random.randint(60, 180)
        self.scroll_speed = scroll_speed
        palettes = [
            (80, 40, 160), (40, 80, 180), (30, 140, 160),
            (160, 50, 120), (50, 100, 140), (120, 60, 180),
            (40, 120, 100),
        ]
        self.color = random.choice(palettes)
        self.alpha_base = random.randint(8, 25)
        self.surface = self._render()

    def _render(self):
        size = self.radius * 2
        surf = pygame.Surface((size, size), pygame.SRCALPHA)
        cx, cy = self.radius, self.radius
        layers = random.randint(4, 8)
        for i in range(layers):
            r = self.radius - i * (self.radius // (layers + 1))
            if r < 5:
                break
            a = max(1, self.alpha_base - i * 2)
            ox = random.randint(-r // 4, r // 4)
            oy = random.randint(-r // 4, r // 4)
            pygame.draw.circle(surf, (*self.color, a), (cx + ox, cy + oy), r)
        return surf


# ═══════════════════════════════════════════════════════════
#  장식 행성 (횡스크롤) — 고퀄리티 프리렌더
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
class _SpeedLine:
    __slots__ = ('x', 'y', 'length', 'speed', 'alpha', 'color')

    def __init__(self, w, h):
        self.x = random.uniform(0, w)
        self.y = random.randint(0, h)
        self.length = random.randint(30, 120)
        self.speed = random.uniform(10, 22)
        self.alpha = random.randint(20, 70)
        b = random.randint(200, 255)
        self.color = (b - random.randint(30, 60),
                      b - random.randint(10, 30), b)


# ═══════════════════════════════════════════════════════════
#  엔진 파티클
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

        # 1인칭 워프 별
        self.warp_stars = [_WarpStar(width, height, True) for _ in range(200)]

        # 횡스크롤 별 5레이어
        self.stars_dust = [_StarLayer(width, height, (0.1, 0.4), [1], 'blue')
                           for _ in range(100)]
        self.stars_far = [_StarLayer(width, height, (0.5, 1.2), [1])
                          for _ in range(100)]
        self.stars_mid = [_StarLayer(width, height, (1.5, 3.5), [1, 2])
                          for _ in range(70)]
        self.stars_near = [_StarLayer(width, height, (4.0, 8.0), [2, 3], 'warm')
                           for _ in range(35)]
        self.stars_front = [_StarLayer(width, height, (8.0, 14.0), [2, 3, 4])
                            for _ in range(15)]

        # 성운
        self.nebulae = [_Nebula(width, height, random.uniform(0.2, 1.0))
                        for _ in range(5)]

        # 장식 행성 / 속도 라인 / 엔진 파티클
        self.scroll_planets = []
        self.speed_lines = [_SpeedLine(width, height) for _ in range(20)]
        self.engine_particles = []

        # 탑뷰 행성 좌표
        n = len(PLANET_CONFIGS) if PLANET_CONFIGS else 8
        self.planet_positions = _compute_planet_positions(width, height, n)

        # 오프스크린 버퍼
        self.map_surface = pygame.Surface((width, height), pygame.SRCALPHA)

        # 콕핏 프리렌더
        self.cockpit_surface = self._render_cockpit()

    # ──────────────────────────────────────────────
    #  콕핏 HUD 프리렌더
    # ──────────────────────────────────────────────
    def _render_cockpit(self):
        W, H = self.W, self.H
        surf = pygame.Surface((W, H), pygame.SRCALPHA)
        frame = (20, 35, 50, 210)
        frame_dk = (12, 22, 35, 220)
        border = (60, 140, 190, 200)
        border_hi = (90, 180, 230, 160)
        accent = (80, 200, 255, 140)
        accent_dim = (40, 100, 140, 100)
        rivet = (45, 70, 95, 160)

        # ===== 하단 콘솔 패널 (다층 3D) =====
        pts_b = [(0, H), (0, H - 120), (60, H - 140),
                 (W // 2 - 120, H - 100), (W // 2, H - 80),
                 (W // 2 + 120, H - 100), (W - 60, H - 140),
                 (W, H - 120), (W, H)]
        pygame.draw.polygon(surf, frame, pts_b)
        # 콘솔 상단 하이라이트 (3D 베벨)
        pts_b_hl = [(0, H - 118), (60, H - 138),
                    (W // 2 - 118, H - 98), (W // 2, H - 78),
                    (W // 2 + 118, H - 98), (W - 60, H - 138),
                    (W, H - 118)]
        pygame.draw.lines(surf, border_hi, False, pts_b_hl, 1)
        pygame.draw.lines(surf, border, False, pts_b[1:-1], 2)
        # 콘솔 내부 패널 라인
        for py_off in [H - 110, H - 90, H - 70]:
            pygame.draw.line(surf, (30, 50, 70, 80), (10, py_off), (W - 10, py_off), 1)

        # ===== 상단 패널 (두꺼운 HUD 바이저) =====
        pts_t = [(0, 0), (0, 75), (100, 58), (W // 2, 42),
                 (W - 100, 58), (W, 75), (W, 0)]
        pygame.draw.polygon(surf, frame, pts_t)
        # 바이저 하단 하이라이트
        pts_t_hl = [(0, 73), (100, 56), (W // 2, 40),
                    (W - 100, 56), (W, 73)]
        pygame.draw.lines(surf, border_hi, False, pts_t_hl, 1)
        pygame.draw.lines(surf, border, False, pts_t[1:-1], 2)
        # 상단 내부 스캔라인
        for sy in range(5, 38, 6):
            pygame.draw.line(surf, (25, 45, 65, 40), (80, sy), (W - 80, sy), 1)

        # ===== 좌우 프레임 (3D 두꺼운 기둥 + 리벳) =====
        for sx in [0, W - 42]:
            # 메인 프레임 (어두운 면)
            pygame.draw.rect(surf, frame_dk, (sx, 75, 42, H - 195))
            # 밝은 면 (안쪽 엣지)
            inner_x = sx + 40 if sx == 0 else sx + 1
            pygame.draw.rect(surf, (25, 42, 60, 180), (inner_x, 75, 2, H - 195))
            # 테두리 라인
            bx = sx + 41 if sx == 0 else sx
            pygame.draw.line(surf, border, (bx, 75), (bx, H - 120), 1)
            # 리벳 (장식 볼트)
            for ry in range(90, H - 140, 30):
                rx = sx + 6 if sx == 0 else sx + 34
                pygame.draw.circle(surf, rivet, (rx, ry), 2)
                pygame.draw.circle(surf, (60, 90, 120, 100), (rx - 1, ry - 1), 1)

        # ===== HUD 장식 — 좌측 파워 바 (그라디언트) =====
        for i in range(7):
            bw = 28 - i * 3
            by = 90 + i * 16
            # 바 배경
            pygame.draw.rect(surf, accent_dim, (6, by, bw, 4), border_radius=1)
            # 바 밝은 부분
            pygame.draw.rect(surf, accent, (6, by, max(2, bw - 4), 2), border_radius=1)

        # ===== 우상단 스캐너 (3D 링 + 눈금) =====
        scx, scy = W - 22, 115
        # 스캐너 배경
        sc_bg = pygame.Surface((36, 36), pygame.SRCALPHA)
        pygame.draw.circle(sc_bg, (10, 20, 35, 160), (18, 18), 16)
        surf.blit(sc_bg, (scx - 18, scy - 18))
        # 외곽 링
        pygame.draw.circle(surf, border, (scx, scy), 16, 2)
        pygame.draw.circle(surf, accent, (scx, scy), 17, 1)
        # 십자선
        pygame.draw.line(surf, accent_dim, (scx - 12, scy), (scx + 12, scy), 1)
        pygame.draw.line(surf, accent_dim, (scx, scy - 12), (scx, scy + 12), 1)
        # 눈금 틱 (4방향)
        for ang in [0, math.pi / 2, math.pi, math.pi * 1.5]:
            tx1 = scx + int(13 * math.cos(ang))
            ty1 = scy + int(13 * math.sin(ang))
            tx2 = scx + int(16 * math.cos(ang))
            ty2 = scy + int(16 * math.sin(ang))
            pygame.draw.line(surf, accent, (tx1, ty1), (tx2, ty2), 1)

        # ===== 좌하단 미니 디스플레이 (파형) =====
        disp_x, disp_y = 6, H - 160
        pygame.draw.rect(surf, (8, 18, 30, 180), (disp_x, disp_y, 30, 20))
        pygame.draw.rect(surf, accent_dim, (disp_x, disp_y, 30, 20), 1)
        # 간단한 사인파
        pts_wave = []
        for wi in range(28):
            wx = disp_x + 1 + wi
            wy = disp_y + 10 + int(6 * math.sin(wi * 0.5))
            pts_wave.append((wx, wy))
        if len(pts_wave) > 2:
            pygame.draw.lines(surf, (0, 200, 100, 120), False, pts_wave, 1)

        # ===== 하단 콘솔 버튼 (3D 버튼 + LED) =====
        for i in range(10):
            bx = W // 2 - 100 + i * 21
            # 버튼 그림자
            pygame.draw.rect(surf, (15, 35, 55, 120),
                             (bx + 1, H - 48, 16, 8), border_radius=2)
            # 버튼 본체
            pygame.draw.rect(surf, (35, 75, 110, 140),
                             (bx, H - 49, 16, 8), border_radius=2)
            # 버튼 하이라이트
            pygame.draw.rect(surf, (55, 100, 140, 80),
                             (bx + 1, H - 49, 14, 3), border_radius=1)
            # LED 표시등
            led_c = accent if i % 3 == 0 else (40, 80, 60, 100)
            pygame.draw.circle(surf, led_c, (bx + 8, H - 55), 2)

        # ===== 좌우 콘솔 장식 (토글 스위치) =====
        for tsx, flip in [(70, False), (W - 90, True)]:
            for ti in range(3):
                ty = H - 60 + ti * 12
                # 스위치 레일
                pygame.draw.rect(surf, (25, 45, 65, 150), (tsx, ty, 12, 4), border_radius=1)
                # 스위치 핸들
                handle_x = tsx + (8 if (ti + (1 if flip else 0)) % 2 == 0 else 1)
                pygame.draw.rect(surf, (70, 120, 160, 180),
                                 (handle_x, ty - 1, 4, 6), border_radius=1)

        # ===== 조준 십자 (멀티 레이어) =====
        cx, cy = W // 2, H // 2
        # 외곽 원
        pygame.draw.circle(surf, (40, 100, 160, 30), (cx, cy), 28, 1)
        # 내곽 원
        pygame.draw.circle(surf, (60, 160, 230, 50), (cx, cy), 18, 1)
        # 십자선 (두 단계)
        cc_outer = (60, 150, 220, 40)
        cc_inner = (80, 200, 255, 70)
        for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            # 외곽 선
            pygame.draw.line(surf, cc_outer,
                             (cx + dx * 35, cy + dy * 35),
                             (cx + dx * 14, cy + dy * 14), 1)
            # 내곽 선 (더 밝고 짧게)
            pygame.draw.line(surf, cc_inner,
                             (cx + dx * 12, cy + dy * 12),
                             (cx + dx * 6, cy + dy * 6), 1)
        # 중앙 점
        pygame.draw.circle(surf, (80, 200, 255, 45), (cx, cy), 2, 1)
        # 코너 마커
        for mx, my in [(1, 1), (1, -1), (-1, 1), (-1, -1)]:
            pygame.draw.line(surf, cc_outer,
                             (cx + mx * 22, cy + my * 22),
                             (cx + mx * 22, cy + my * 16), 1)
            pygame.draw.line(surf, cc_outer,
                             (cx + mx * 22, cy + my * 22),
                             (cx + mx * 16, cy + my * 22), 1)

        return surf

    # ──────────────────────────────────────────────
    #  이벤트 폴링
    # ──────────────────────────────────────────────
    def _poll_skip(self):
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if ev.type == pygame.KEYDOWN and ev.key in (
                    pygame.K_ESCAPE, pygame.K_SPACE):
                return True
        return False

    # ──────────────────────────────────────────────
    #  1인칭 워프 별
    # ──────────────────────────────────────────────
    def _update_warp_stars(self, dt, speed_mult=1.0):
        for s in self.warp_stars:
            s.dist += s.speed * dt * speed_mult
            if s.dist > s.max_dist:
                s.dist = random.uniform(0, 20)
                s.angle = random.uniform(0, math.pi * 2)
                s.speed = random.uniform(80, 300)

    def _draw_warp_stars(self, surf, intensity=1.0):
        cx, cy = self.W / 2, self.H / 2
        for s in self.warp_stars:
            x = cx + math.cos(s.angle) * s.dist
            y = cy + math.sin(s.angle) * s.dist
            if not (-5 < x < self.W + 5 and -5 < y < self.H + 5):
                continue
            dr = s.dist / s.max_dist
            b = _clamp(s.brightness * dr * intensity)
            if b < 5:
                continue
            sz = max(1, int(1 + dr * 3))
            cr = _clamp(s.color[0] * b / 255)
            cg = _clamp(s.color[1] * b / 255)
            cb = _clamp(s.color[2] * b / 255)
            col = (cr, cg, cb)
            # 트레일 (그라디언트 — 머리 밝고 꼬리 희미)
            if dr > 0.1:
                td = max(0, s.dist - s.speed * 0.02 * s.trail_len)
                tx = cx + math.cos(s.angle) * td
                ty = cy + math.sin(s.angle) * td
                # 메인 트레일
                pygame.draw.line(surf, col, (int(tx), int(ty)),
                                 (int(x), int(y)), max(1, sz))
                # 밝은 코어 트레일 (더 짧고 밝게)
                core_d = max(0, s.dist - s.speed * 0.01 * s.trail_len * 0.4)
                core_tx = cx + math.cos(s.angle) * core_d
                core_ty = cy + math.sin(s.angle) * core_d
                bright = (min(255, cr + 80), min(255, cg + 80), min(255, cb + 80))
                pygame.draw.line(surf, bright, (int(core_tx), int(core_ty)),
                                 (int(x), int(y)), max(1, sz - 1))
                # 글로우 트레일 (외곽 소프트)
                if sz >= 2 and b > 100:
                    glow_d = max(0, s.dist - s.speed * 0.015 * s.trail_len * 0.6)
                    glow_tx = cx + math.cos(s.angle) * glow_d
                    glow_ty = cy + math.sin(s.angle) * glow_d
                    gs = pygame.Surface((abs(int(x - glow_tx)) + sz * 4 + 8,
                                         abs(int(y - glow_ty)) + sz * 4 + 8),
                                        pygame.SRCALPHA)
                    ox = min(int(x), int(glow_tx)) - sz * 2 - 4
                    oy = min(int(y), int(glow_ty)) - sz * 2 - 4
                    ga = min(255, int(b * 0.12))
                    pygame.draw.line(gs, (cr, cg, cb, ga),
                                     (int(glow_tx) - ox, int(glow_ty) - oy),
                                     (int(x) - ox, int(y) - oy),
                                     max(1, sz + 2))
                    surf.blit(gs, (ox, oy))
            # 별 머리: 글로우 헤일로 + 밝은 코어
            if sz >= 2 and b > 60:
                hr = sz + 2
                hs = pygame.Surface((hr * 2 + 4, hr * 2 + 4), pygame.SRCALPHA)
                hc = hr + 2
                for hi in range(hr, 0, -1):
                    ha = min(255, int(35 * hi / hr * intensity))
                    pygame.draw.circle(hs, (cr, cg, cb, ha), (hc, hc), hi)
                surf.blit(hs, (int(x) - hc, int(y) - hc))
            pygame.draw.circle(surf, col, (int(x), int(y)), sz)
            # 초밝은 중심
            if sz >= 2:
                pygame.draw.circle(surf, (min(255, cr + 100), min(255, cg + 100),
                                          min(255, cb + 100)),
                                   (int(x), int(y)), max(1, sz // 2))

    # ──────────────────────────────────────────────
    #  횡스크롤 별 업데이트/그리기
    # ──────────────────────────────────────────────
    def _update_stars(self, layer, speed_mult=1.0):
        for s in layer:
            s.x -= s.speed * speed_mult
            if s.x < -5:
                s.x = self.W + random.uniform(0, 30)
                s.y = random.uniform(0, self.H)

    def _draw_stars_layer(self, surf, layer, alpha_mult=1.0):
        t = self.time
        for s in layer:
            twinkle = 0.7 + 0.3 * math.sin(t * s.twinkle_speed + s.twinkle_phase)
            b = s.brightness * twinkle * alpha_mult
            if b < 5:
                continue
            cr = _clamp(s.color[0] * b / 255)
            cg = _clamp(s.color[1] * b / 255)
            cb = _clamp(s.color[2] * b / 255)
            ix, iy = int(s.x), int(s.y)
            if not (0 <= ix < self.W and 0 <= iy < self.H):
                continue
            col = (cr, cg, cb)
            if s.size <= 1:
                # 작은 별도 약한 글로우
                if b > 120:
                    gs = pygame.Surface((6, 6), pygame.SRCALPHA)
                    ga = min(255, int(b * 0.15 * alpha_mult))
                    pygame.draw.circle(gs, (cr, cg, cb, ga), (3, 3), 2)
                    surf.blit(gs, (ix - 3, iy - 3))
                surf.set_at((ix, iy), col)
            else:
                # 소프트 글로우 헤일로 (별 주변 부드러운 빛)
                if b > 80:
                    halo_r = s.size + max(2, int(b / 40))
                    hs = pygame.Surface((halo_r * 2 + 4, halo_r * 2 + 4), pygame.SRCALPHA)
                    hc = halo_r + 2
                    for hi in range(halo_r, 0, -1):
                        ha = min(255, int(25 * (hi / halo_r) * alpha_mult))
                        pygame.draw.circle(hs, (cr, cg, cb, ha), (hc, hc), hi)
                    surf.blit(hs, (ix - hc, iy - hc))
                # 메인 별 (중심 밝게)
                pygame.draw.circle(surf, col, (ix, iy), s.size)
                if s.size >= 2:
                    # 밝은 코어
                    core_c = (min(255, cr + 60), min(255, cg + 60), min(255, cb + 60))
                    pygame.draw.circle(surf, core_c, (ix, iy), max(1, s.size - 1))
                # 큰 별: 4방향 광선 + 대각선 보조 광선
                if s.size >= 3 and b > 120:
                    # 메인 십자 광선
                    gl = s.size + 3 + int(b / 80)
                    ray_a = min(255, int(b * 0.6 * alpha_mult))
                    rs = pygame.Surface((gl * 2 + 4, gl * 2 + 4), pygame.SRCALPHA)
                    rc = gl + 2
                    # 수평 광선 (그라디언트)
                    for ri in range(gl, 0, -1):
                        ra = max(1, int(ray_a * ri / gl))
                        rs.set_at((rc + ri, rc), (cr, cg, cb, ra))
                        rs.set_at((rc - ri, rc), (cr, cg, cb, ra))
                        rs.set_at((rc, rc + ri), (cr, cg, cb, ra))
                        rs.set_at((rc, rc - ri), (cr, cg, cb, ra))
                    # 대각선 보조 광선 (짧고 약하게)
                    dgl = max(2, gl // 2)
                    for di in range(dgl, 0, -1):
                        da = max(1, int(ray_a * 0.4 * di / dgl))
                        for dx, dy in [(1, 1), (1, -1), (-1, 1), (-1, -1)]:
                            px = rc + dx * di
                            py = rc + dy * di
                            if 0 <= px < rs.get_width() and 0 <= py < rs.get_height():
                                rs.set_at((px, py), (cr, cg, cb, da))
                    surf.blit(rs, (ix - rc, iy - rc))
                # 초대형 별: 렌즈 플레어 링
                if s.size >= 4 and b > 180:
                    flare_r = s.size + 5
                    fs = pygame.Surface((flare_r * 2 + 4, flare_r * 2 + 4), pygame.SRCALPHA)
                    fc = flare_r + 2
                    fa = min(255, int(20 * alpha_mult))
                    pygame.draw.circle(fs, (cr, cg, cb, fa), (fc, fc), flare_r, 1)
                    pygame.draw.circle(fs, (cr, cg, cb, max(1, fa // 2)),
                                       (fc, fc), flare_r + 1, 1)
                    surf.blit(fs, (ix - fc, iy - fc))

    # ──────────────────────────────────────────────
    #  성운
    # ──────────────────────────────────────────────
    def _update_nebulae(self, speed_mult=1.0):
        for n in self.nebulae:
            n.x -= n.scroll_speed * speed_mult
            if n.x < -n.radius * 2 - 50:
                n.x = self.W + random.randint(50, 200)
                n.y = random.uniform(0, self.H)
                n.surface = n._render()

    # ──────────────────────────────────────────────
    #  우주 환경 이펙트 (고퀄리티)
    # ──────────────────────────────────────────────
    def _draw_warp_tunnel(self, surf, intensity, t):
        """워프 터널 — 동심원 + 에너지 링 + 색수차."""
        W, H = self.W, self.H
        cx, cy = W // 2, H // 2
        ts = pygame.Surface((W, H), pygame.SRCALPHA)
        # 동심원 (중앙에서 바깥으로 확장)
        for i in range(18, 0, -1):
            frac = i / 18.0
            r = int(max(W, H) * 0.7 * frac)
            phase_off = self.time * 3 + i * 0.5
            pulse = 0.5 + 0.5 * math.sin(phase_off)
            a = int(35 * intensity * frac * pulse)
            if a < 2 or r < 5:
                continue
            # 색수차 (빨강/파랑 오프셋)
            ra = max(1, int(a * 0.7))
            pygame.draw.circle(ts, (80, 140, 255, min(255, a)), (cx, cy), r, max(1, int(3 * frac)))
            pygame.draw.circle(ts, (160, 100, 255, min(255, ra)), (cx + 2, cy), r + 2, max(1, int(2 * frac)))
            pygame.draw.circle(ts, (100, 200, 255, min(255, ra)), (cx - 1, cy), r - 1, max(1, int(1 * frac + 1)))
        # 중앙 광원 (목적지 빛)
        for gi in range(30, 0, -3):
            ga = int(20 * intensity * gi / 30)
            pygame.draw.circle(ts, (200, 220, 255, min(255, ga)), (cx, cy), gi)
        # 에너지 스파크 (방사형)
        random.seed(int(self.time * 10) % 9999)
        for _ in range(int(12 * intensity)):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(40, max(W, H) * 0.45)
            sx_s = cx + int(math.cos(angle) * dist)
            sy_s = cy + int(math.sin(angle) * dist)
            sl = random.randint(5, 25)
            ex = sx_s + int(math.cos(angle) * sl)
            ey = sy_s + int(math.sin(angle) * sl)
            sa = int(90 * intensity * random.uniform(0.5, 1.0))
            pygame.draw.line(ts, (180, 200, 255, min(255, sa)),
                             (sx_s, sy_s), (ex, ey), 1)
        random.seed()
        surf.blit(ts, (0, 0))

    def _draw_cosmic_dust(self, surf, density, t):
        """우주 먼지 + 미립자 — 깊이감 있는 부유 파티클."""
        W, H = self.W, self.H
        ds = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(4242)
        for _ in range(int(60 * density)):
            # 3D 깊이 시뮬레이션
            depth = random.uniform(0.2, 1.0)
            bx = (random.uniform(-20, W + 20) - self.time * 15 * depth) % (W + 40) - 20
            by = random.uniform(-10, H + 10) + math.sin(self.time * 0.5 + bx * 0.01) * 8
            size = max(1, int(3 * depth))
            # 따뜻한/차가운 색상 혼합
            warmth = random.uniform(0, 1)
            r = int(150 + 100 * warmth)
            g = int(140 + 60 * warmth)
            b = int(200 - 80 * warmth)
            a = int(40 * density * depth)
            if a < 2:
                continue
            # 소프트 글로우
            gr = size + 2
            gs = pygame.Surface((gr * 2, gr * 2), pygame.SRCALPHA)
            pygame.draw.circle(gs, (r, g, b, min(255, a // 2)), (gr, gr), gr)
            pygame.draw.circle(gs, (r, g, b, min(255, a)), (gr, gr), size)
            ds.blit(gs, (int(bx) - gr, int(by) - gr))
        random.seed()
        surf.blit(ds, (0, 0))

    def _draw_god_rays(self, surf, cx, cy, intensity, color=(255, 240, 200)):
        """신성한 빛줄기 (볼류메트릭 고드레이)."""
        W, H = self.W, self.H
        rs = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(7070)
        for i in range(16):
            angle = (i / 16.0) * math.pi * 2 + self.time * 0.15
            spread = random.uniform(0.03, 0.08)
            length = random.uniform(0.4, 0.9) * max(W, H)
            base_a = int(18 * intensity * random.uniform(0.6, 1.0))
            if base_a < 2:
                continue
            # 각 빛줄기를 삼각형 폴리곤으로
            tip_x = cx + math.cos(angle) * length
            tip_y = cy + math.sin(angle) * length
            left_x = cx + math.cos(angle - spread) * 30
            left_y = cy + math.sin(angle - spread) * 30
            right_x = cx + math.cos(angle + spread) * 30
            right_y = cy + math.sin(angle + spread) * 30
            pts = [(int(left_x), int(left_y)),
                   (int(tip_x), int(tip_y)),
                   (int(right_x), int(right_y))]
            pygame.draw.polygon(rs, (*color, min(255, base_a)), pts)
            # 얇은 코어 (밝은 중심선)
            core_a = min(255, int(base_a * 1.5))
            pygame.draw.line(rs, (*color, core_a),
                             (cx, cy), (int(tip_x), int(tip_y)), 1)
        random.seed()
        # 중앙 글로우
        for gi in range(25, 0, -3):
            ga = int(15 * intensity * gi / 25)
            pygame.draw.circle(rs, (*color, min(255, ga)), (cx, cy), gi)
        surf.blit(rs, (0, 0))

    def _draw_aurora(self, surf, y_base, intensity, t):
        """오로라 / 대기 발광 — 물결치는 커튼."""
        W, H = self.W, self.H
        if intensity < 0.02:
            return
        aus = pygame.Surface((W, H), pygame.SRCALPHA)
        colors = [(50, 220, 130), (30, 150, 200), (120, 80, 220),
                  (200, 100, 180), (80, 200, 255)]
        for ci, col in enumerate(colors):
            pts = []
            y_off = y_base + ci * 12
            for x in range(0, W + 10, 6):
                wave1 = math.sin(x * 0.008 + t * 0.8 + ci * 1.5) * 30
                wave2 = math.sin(x * 0.015 - t * 1.2 + ci * 0.7) * 15
                wave3 = math.sin(x * 0.003 + t * 0.3) * 45
                y = y_off + wave1 + wave2 + wave3
                pts.append((x, int(y)))
            # 위 꼭짓점 → 아래 채움
            bottom_pts = [(x, int(y + 40 + ci * 8)) for x, y in reversed(pts)]
            poly = pts + bottom_pts
            if len(poly) > 3:
                a = int(25 * intensity * (1.0 - ci * 0.15))
                pygame.draw.polygon(aus, (*col, min(255, max(1, a))), poly)
        surf.blit(aus, (0, 0))

    def _draw_energy_wave(self, surf, cx, cy, radius, intensity, t):
        """에너지 충격파 — 행성 근처 중력장 시각화."""
        if intensity < 0.02 or radius < 5:
            return
        ews = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
        for i in range(4):
            phase = t * 2.0 + i * 1.57
            wave_r = radius + int(20 * math.sin(phase)) + i * 8
            if wave_r < 5:
                continue
            a = int(30 * intensity * (1.0 - i * 0.2) *
                    (0.5 + 0.5 * math.sin(phase * 0.7)))
            if a < 2:
                continue
            # 링
            pygame.draw.circle(ews, (100, 180, 255, min(255, a)),
                               (cx, cy), wave_r, max(1, 3 - i))
            # 외곽 글로우
            pygame.draw.circle(ews, (60, 120, 200, min(255, a // 2)),
                               (cx, cy), wave_r + 3, 1)
        surf.blit(ews, (0, 0))

    def _draw_nebulae(self, surf, alpha_mult=1.0):
        for n in self.nebulae:
            ns = n.surface
            if alpha_mult < 0.95:
                ns = ns.copy()
                ns.set_alpha(_clamp(255 * alpha_mult))
            surf.blit(ns, (int(n.x - n.radius), int(n.y - n.radius)))

    # ──────────────────────────────────────────────
    #  장식 행성
    # ──────────────────────────────────────────────
    def _update_scroll_planets(self, speed_mult=1.0):
        for p in self.scroll_planets:
            p.x -= p.speed * speed_mult
        self.scroll_planets = [p for p in self.scroll_planets
                               if p.x > -p.radius * 2 - 80]
        if len(self.scroll_planets) < 3 and random.random() < 0.008 * speed_mult:
            self.scroll_planets.append(_DetailedPlanet(self.W, self.H))

    def _draw_scroll_planets(self, surf):
        for p in self.scroll_planets:
            s = p.surface
            surf.blit(s, (int(p.x - s.get_width() // 2),
                          int(p.y - s.get_height() // 2)))
            if p.has_moon:
                mx = p.x + math.cos(self.time * 0.5 + p.moon_angle) * p.moon_dist
                my = p.y + math.sin(self.time * 0.5 + p.moon_angle) * p.moon_dist * 0.4
                mr = max(2, p.radius // 6)
                pygame.draw.circle(surf, (180, 180, 200), (int(mx), int(my)), mr)
                pygame.draw.circle(surf, (200, 200, 220),
                                   (int(mx) - 1, int(my) - 1), max(1, mr // 2))

    # ──────────────────────────────────────────────
    #  속도 라인
    # ──────────────────────────────────────────────
    def _update_speed_lines(self, speed_mult=1.0):
        for ln in self.speed_lines:
            ln.x -= ln.speed * speed_mult
            if ln.x + ln.length < 0:
                ln.x = self.W + random.randint(0, 150)
                ln.y = random.randint(0, self.H)
                ln.length = random.randint(30, 120)
                ln.alpha = random.randint(20, 70)

    def _draw_speed_lines(self, surf, alpha_mult=1.0):
        for ln in self.speed_lines:
            a = int(ln.alpha * alpha_mult)
            if a < 3:
                continue
            x1 = max(0, int(ln.x))
            x2 = min(self.W, int(ln.x + ln.length))
            if x2 <= x1:
                continue
            col = (_clamp(ln.color[0]), _clamp(ln.color[1]), _clamp(ln.color[2]))
            pygame.draw.line(surf, col, (x1, int(ln.y)), (x2, int(ln.y)), 1)

    # ──────────────────────────────────────────────
    #  엔진 파티클
    # ──────────────────────────────────────────────
    def _spawn_engine_particles(self, x, y, count=2):
        for _ in range(count):
            self.engine_particles.append(
                _EngineParticle(x, y + random.uniform(-3, 3)))

    def _update_engine_particles(self, dt):
        for p in self.engine_particles:
            p.x += p.vx * 60 * dt
            p.y += p.vy * 60 * dt
            p.life -= dt
            p.size *= 0.98
        self.engine_particles = [p for p in self.engine_particles
                                 if p.life > 0 and p.size > 0.3]

    def _draw_engine_particles(self, surf):
        for p in self.engine_particles:
            lr = p.life / p.max_life
            sz = max(1, int(p.size))
            r = _clamp(p.color[0] * lr)
            g = _clamp(p.color[1] * lr * 0.5)
            b = _clamp(p.color[2] * lr * 0.3)
            pygame.draw.circle(surf, (r, g, b), (int(p.x), int(p.y)), sz)

    # ──────────────────────────────────────────────
    #  고퀄리티 우주선 (횡스크롤 → 방향)
    # ──────────────────────────────────────────────
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
    def _draw_ship_vertical(self, surf, x, y, scale=1.0, engine_power=1.0):
        """우주선을 수직(노즈 위, 엔진 아래)으로 그린다."""
        ship_sz = int(80 * scale) + 30
        tmp = pygame.Surface((ship_sz * 2, ship_sz * 2), pygame.SRCALPHA)
        tc = ship_sz
        self._draw_ship(tmp, tc, tc, scale, engine_power)
        rotated = pygame.transform.rotate(tmp, 90)
        rr = rotated.get_rect(center=(int(x), int(y)))
        surf.blit(rotated, rr)

    # ──────────────────────────────────────────────
    #  착륙 시퀀스: 착륙 파티클
    # ──────────────────────────────────────────────
    def _spawn_landing_particles(self, x, y, count=2):
        """수직 하강용 엔진 파티클 (아래 방향)."""
        for _ in range(count):
            p = _EngineParticle(x + random.uniform(-4, 4), y)
            p.vx = random.uniform(-2.0, 2.0)
            p.vy = random.uniform(2.0, 7.0)   # 아래로
            p.life = random.uniform(0.2, 0.5)
            p.max_life = p.life
            self.engine_particles.append(p)

    # ──────────────────────────────────────────────
    #  착륙 시퀀스: 도킹 기지
    # ──────────────────────────────────────────────
    def _draw_docking_base(self, surf, cx, cy, scale=1.0, open_t=0.0):
        """착륙 도크 (팔각형 플랫폼 + 도킹 암 + 점멸등)."""
        s = scale
        ix, iy = int(cx), int(cy)

        # 플랫폼 (팔각형)
        pr = int(25 * s)
        pts = []
        for i in range(8):
            ang = i * math.pi / 4 + math.pi / 8
            pts.append((ix + int(pr * math.cos(ang)),
                        iy + int(pr * math.sin(ang))))
        pygame.draw.polygon(surf, (90, 100, 120), pts)
        pygame.draw.polygon(surf, (130, 145, 170), pts, max(1, int(2 * s)))
        # 내부 원형 패드
        pygame.draw.circle(surf, (70, 80, 100), (ix, iy), int(16 * s))
        pygame.draw.circle(surf, (110, 125, 150), (ix, iy), int(16 * s), 1)
        # 십자 마커
        ml = int(10 * s)
        mc = (80, 200, 255)
        pygame.draw.line(surf, mc, (ix - ml, iy), (ix + ml, iy), 1)
        pygame.draw.line(surf, mc, (ix, iy - ml), (ix, iy + ml), 1)

        # 도킹 암 (좌우 — open_t로 개방)
        arm_len = int(18 * s)
        arm_gap = int(8 * s * open_t)  # 0이면 닫힘, 열리면 벌어짐
        arm_y_top = iy - arm_gap
        arm_y_bot = iy + arm_gap
        arm_c = (150, 165, 190)
        pygame.draw.line(surf, arm_c,
                         (ix - arm_len, arm_y_top), (ix + arm_len, arm_y_top),
                         max(1, int(3 * s)))
        pygame.draw.line(surf, arm_c,
                         (ix - arm_len, arm_y_bot), (ix + arm_len, arm_y_bot),
                         max(1, int(3 * s)))
        # 암 끝 클램프
        for ax in [ix - arm_len, ix + arm_len]:
            pygame.draw.rect(surf, (120, 135, 160),
                             (ax - int(3 * s), arm_y_top - int(2 * s),
                              int(6 * s), arm_gap * 2 + int(4 * s)))

        # 점멸 착륙등 (4방위)
        blink = math.sin(self.time * 5) > 0
        for i in range(4):
            ang = i * math.pi / 2
            lx = ix + int((pr - 3) * math.cos(ang))
            ly = iy + int((pr - 3) * math.sin(ang))
            lc = (0, 255, 100) if blink else (0, 80, 40)
            gs = pygame.Surface((8, 8), pygame.SRCALPHA)
            pygame.draw.circle(gs, (*lc, 120), (4, 4), 3)
            pygame.draw.circle(gs, lc, (4, 4), 1)
            surf.blit(gs, (lx - 4, ly - 4))

        # 펄스 글로우 링
        pulse = 0.5 + 0.5 * math.sin(self.time * 3)
        ga = min(255, int(25 * pulse))
        gs2 = pygame.Surface((pr * 2 + 8, pr * 2 + 8), pygame.SRCALPHA)
        gc = pr + 4
        pygame.draw.circle(gs2, (80, 200, 255, ga), (gc, gc), pr + 2, 2)
        surf.blit(gs2, (ix - gc, iy - gc))

    # ──────────────────────────────────────────────
    #  착륙 시퀀스: 행성 표면 뷰
    # ──────────────────────────────────────────────
    _SURFACE_RENDERERS = {
        1: '_draw_surface_joseon',
    }

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
        """조선시대 행성 표면 — 고퀄리티 (화강암/단청/논밭/산/벚꽃/궁궐).
        t: 0(고공) ~ 1(지표면). 실제 Stage 1 맵 색상 반영."""
        W, H = surf.get_width(), surf.get_height()

        # ===== 기본 지형 — 자연 톤 그라디언트 =====
        # 하늘에서 땅으로 세로 그라디언트 (고도 느낌)
        sky_blend = max(0.0, 1.0 - t * 3)  # 높을수록 하늘빛
        for row in range(0, H, 4):
            fy = row / H
            # 상단: 하늘/안개, 하단: 풀/흙
            gr = int((110 + fy * 30) * (1 - sky_blend) + (140 + fy * 20) * sky_blend)
            gg = int((135 + fy * 25) * (1 - sky_blend) + (160 + fy * 15) * sky_blend)
            gb = int((50 + fy * 15) * (1 - sky_blend) + (120 + fy * 30) * sky_blend)
            pygame.draw.rect(surf, (min(255, gr), min(255, gg), min(255, gb), alpha),
                             (0, row, W, 5))

        random.seed(1137)

        # ===== 논밭/초원 패치 (부드러운 컬러 변주) =====
        for _ in range(50):
            px = random.randint(-80, W + 80)
            py = random.randint(-80, H + 80)
            pr = random.randint(40, 180)
            g = random.randint(80, 170)
            c = (g - 30 + random.randint(-10, 10),
                 g + random.randint(-10, 10),
                 g // 3 + random.randint(-5, 10))
            c = tuple(max(0, min(255, v)) for v in c)
            ps = pygame.Surface((pr * 2, pr * 2), pygame.SRCALPHA)
            # 다층 소프트 블러 패치
            for li in range(pr, max(1, pr // 3), -max(1, pr // 6)):
                la = max(1, int(40 * alpha / 255 * li / pr))
                pygame.draw.circle(ps, (*c, la), (pr, pr), li)
            surf.blit(ps, (px - pr, py - pr))

        # ===== 개울 (사인 곡선 — 3층 물결 + 반사광) =====
        for stream_i in range(2):
            pts_s = []
            y_off = 60 + stream_i * (H // 3)
            for step in range(40):
                st = step / 39
                sx = int(W * st)
                sy = y_off + int(70 * math.sin(st * math.pi * 2.5 + stream_i))
                pts_s.append((sx, sy))
            if len(pts_s) > 2:
                # 넓은 물 바닥
                pygame.draw.lines(surf, (45, 85, 140), False, pts_s, 6)
                # 중간 물
                pygame.draw.lines(surf, (65, 115, 175), False, pts_s, 3)
                # 밝은 반사
                pts_hl = [(p[0], p[1] - 1) for p in pts_s]
                pygame.draw.lines(surf, (100, 160, 215), False, pts_hl, 1)

        # ===== 산맥 (다층 — 원경/중경/근경) =====
        # 원경 산 (연하게)
        for _ in range(6):
            mx = random.randint(-50, W + 50)
            my = random.randint(-60, H // 4)
            mw = random.randint(100, 280)
            mh = random.randint(50, 130)
            mc = (45 + random.randint(0, 30), 80 + random.randint(0, 40), 40)
            ma = min(255, int(150 * alpha / 255))
            ms = pygame.Surface((mw * 2, mh + 2), pygame.SRCALPHA)
            pygame.draw.ellipse(ms, (*mc, ma), (0, 0, mw * 2, mh * 2))
            surf.blit(ms, (mx - mw, my - mh // 2))
        # 중경 산 (선명하게)
        for _ in range(5):
            mx = random.randint(0, W)
            my = random.randint(0, H // 3)
            mw = random.randint(80, 200)
            mh = random.randint(40, 100)
            mc = (30 + random.randint(0, 35), 70 + random.randint(0, 50), 28)
            pygame.draw.ellipse(surf, mc, (mx - mw, my - mh // 2, mw * 2, mh))
            # 하이라이트 아크
            hl_c = (min(255, mc[0] + 35), min(255, mc[1] + 35), mc[2] + 15)
            pygame.draw.arc(surf, hl_c,
                            (mx - mw, my - mh // 2, mw * 2, mh),
                            math.pi * 0.1, math.pi * 0.85, 2)
            # 눈 덮인 봉우리 (큰 산)
            if mh > 70 and mw > 120:
                snow_w = max(10, mw // 3)
                snow_h = max(5, mh // 4)
                pygame.draw.ellipse(surf, (240, 240, 235),
                                    (mx - snow_w // 2, my - mh // 2 - 2,
                                     snow_w, snow_h))

        # ===== 벚꽃 나무 클러스터 (디테일 — t에 따라 등장) =====
        detail_a = min(255, int(255 * max(0, t * 2 - 0.2)))
        if detail_a > 10:
            for _ in range(30):
                fx = random.randint(20, W - 20)
                fy = random.randint(H // 5, H - 30)
                trunk_h = random.randint(12, 30)
                # 나무 줄기 (갈색 + 그림자)
                pygame.draw.line(surf, (80, 55, 30),
                                 (fx + 1, fy), (fx + 1, fy + trunk_h), 3)
                pygame.draw.line(surf, (110, 80, 45),
                                 (fx, fy), (fx, fy + trunk_h), 2)
                # 가지
                for bi in range(random.randint(2, 4)):
                    bx_e = fx + random.randint(-15, 15)
                    by_e = fy - random.randint(0, 8)
                    pygame.draw.line(surf, (100, 70, 40),
                                     (fx, fy + 3), (bx_e, by_e), 1)
                # 벚꽃 구름 (소프트 글로우)
                for _ in range(random.randint(4, 10)):
                    bx = fx + random.randint(-18, 18)
                    by = fy + random.randint(-20, 3)
                    br = random.randint(3, 10)
                    ba = min(255, int(detail_a * 0.7))
                    bs = pygame.Surface((br * 2 + 4, br * 2 + 4), pygame.SRCALPHA)
                    bc = br + 2
                    # 글로우 겹침
                    for gi in range(br + 1, 0, -1):
                        ga = max(1, int(ba * gi / (br + 1) * 0.5))
                        pygame.draw.circle(bs, (255, random.randint(160, 240),
                                                random.randint(180, 230), ga),
                                           (bc, bc), gi)
                    surf.blit(bs, (bx - bc, by - bc))

        # ===== 궁궐/전통 건축물 (상세) =====
        for _ in range(8):
            bx = random.randint(40, W - 40)
            by = random.randint(H // 4, H * 3 // 4)
            bw = random.randint(30, 80)
            bh = random.randint(15, 40)
            # 기단 (석축)
            base_h = max(3, bh // 4)
            pygame.draw.rect(surf, (72, 68, 62),
                             (bx - bw // 2 - 2, by + bh, bw + 4, base_h))
            # 몸체 (벽체)
            pygame.draw.rect(surf, (195, 175, 135),
                             (bx - bw // 2, by, bw, bh))
            # 단청 무늬 줄 (처마 아래)
            dancheong_y = by + 2
            dw = bw - 4
            pygame.draw.line(surf, (140, 45, 35),
                             (bx - dw // 2, dancheong_y),
                             (bx + dw // 2, dancheong_y), 1)
            pygame.draw.line(surf, (35, 55, 95),
                             (bx - dw // 2, dancheong_y + 2),
                             (bx + dw // 2, dancheong_y + 2), 1)
            # 기와지붕 (다층 아크)
            rw = bw + int(12)
            rh = max(8, bh)
            # 지붕 본체
            pygame.draw.arc(surf, (55, 55, 50),
                            (bx - rw // 2, by - rh, rw, rh * 2),
                            0, math.pi, max(3, bw // 12))
            # 지붕 하이라이트
            pygame.draw.arc(surf, (85, 80, 72),
                            (bx - rw // 2 + 2, by - rh + 2, rw - 4, rh * 2 - 4),
                            0.1, math.pi - 0.1, max(1, bw // 18))
            # 처마 끝 곡선
            pygame.draw.arc(surf, (70, 65, 58),
                            (bx - rw // 2 - 2, by - rh - 1, rw + 4, rh * 2 + 2),
                            0, math.pi, 1)
            # 기둥 (나무)
            for col_off in range(-bw // 2 + 5, bw // 2, max(8, bw // 3)):
                pygame.draw.line(surf, (140, 45, 35),
                                 (bx + col_off, by + 3),
                                 (bx + col_off, by + bh), max(1, 2))

        # ===== 길/산책로 =====
        path_pts = []
        for step in range(25):
            st = step / 24
            px_p = W // 4 + int(W // 2 * st)
            py_p = H * 2 // 3 + int(30 * math.sin(st * math.pi * 1.5))
            path_pts.append((px_p, py_p))
        if len(path_pts) > 2:
            pygame.draw.lines(surf, (150, 135, 110), False, path_pts, 5)
            pygame.draw.lines(surf, (170, 155, 130), False, path_pts, 2)

        # ===== 논 (물 반사 직사각형) =====
        for _ in range(6):
            rx = random.randint(20, W - 80)
            ry = random.randint(H // 3, H - 50)
            rw_f = random.randint(30, 70)
            rh_f = random.randint(20, 40)
            # 논둑
            pygame.draw.rect(surf, (100, 120, 50),
                             (rx, ry, rw_f, rh_f), 1)
            # 물 표면
            water_s = pygame.Surface((rw_f - 2, rh_f - 2), pygame.SRCALPHA)
            water_s.fill((80, 120, 90, 60))
            surf.blit(water_s, (rx + 1, ry + 1))

        random.seed()

        # ===== 구름 레이어 (고도별 — 다층 소프트 클라우드) =====
        cloud_a = max(0, int(200 * (1.0 - t * 2.2) * alpha / 255))
        if cloud_a > 3:
            random.seed(2024)
            for _ in range(22):
                cx_c = random.randint(-80, W + 80)
                cy_c = random.randint(-40, H + 40)
                cw_c = random.randint(100, 280)
                ch_c = random.randint(30, 75)
                cs = pygame.Surface((cw_c, ch_c), pygame.SRCALPHA)
                # 5층 소프트 구름
                for ci in range(5):
                    coff = ci * 4
                    ca = max(1, int(cloud_a * (1.0 - ci * 0.18)))
                    if cw_c - coff * 2 > 4 and ch_c - coff * 2 > 4:
                        pygame.draw.ellipse(
                            cs, (255, 255, 255, min(255, ca)),
                            (coff, coff, cw_c - coff * 2, ch_c - coff * 2))
                # 구름 그림자
                shadow_s = pygame.Surface((cw_c, ch_c // 2), pygame.SRCALPHA)
                sha = max(1, cloud_a // 5)
                pygame.draw.ellipse(shadow_s, (0, 0, 0, sha),
                                    (5, 0, cw_c - 10, ch_c // 2))
                surf.blit(shadow_s, (cx_c - cw_c // 2 + 3, cy_c + ch_c // 3))
                surf.blit(cs, (cx_c - cw_c // 2, cy_c - ch_c // 2))
            random.seed()

        # ===== 안개/대기 오버레이 (고고도 — t 작을 때) =====
        haze_a = max(0, int(80 * (1.0 - t * 2.5) * alpha / 255))
        if haze_a > 2:
            haze = pygame.Surface((W, H), pygame.SRCALPHA)
            haze.fill((180, 195, 210, haze_a))
            surf.blit(haze, (0, 0))

    # ──────────────────────────────────────────────
    #  착륙 시퀀스: 경기장 (투기장)
    # ──────────────────────────────────────────────
    def _draw_landing_arena(self, surf, cx, cy, scale=1.0, planet_num=1):
        """핑파이터 경기장. 행성별 테마."""
        if planet_num == 1:
            self._draw_arena_joseon(surf, cx, cy, scale)
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
        """조선시대 핑파이터 경기장 — Stage 1 맵 스타일."""
        s = scale
        ix, iy = int(cx), int(cy)

        # ── 색상 팔레트 (Stage 1 참조) ──
        stone = (72, 68, 62)
        stone_light = (95, 90, 82)
        stone_dark = (52, 48, 42)
        grout = (42, 38, 34)
        dancheong_red = (140, 45, 35)
        dancheong_blue = (35, 55, 95)
        gold = (200, 160, 80)
        gold_bright = (230, 190, 100)
        gold_dark = (160, 120, 50)
        beige = (235, 220, 195)
        cream = (245, 235, 210)
        ink = (30, 25, 20)
        wood_red = (130, 50, 40)

        # ── 전체 영역 크기 ──
        ow = int(160 * s)
        oh = int(130 * s)
        ox = ix - ow // 2
        oy = iy - oh // 2

        # ===== 1. 외벽 기단 (화강암 석축 2단) =====
        base_h = max(4, int(10 * s))
        # 하단 석축 (어두운)
        pygame.draw.rect(surf, stone_dark,
                         (ox - 3, oy + oh, ow + 6, base_h + 2))
        # 상단 석축
        pygame.draw.rect(surf, stone,
                         (ox - 1, oy + oh - 1, ow + 2, base_h))
        # 석축 줄눈
        for gi in range(0, ow + 4, max(6, int(12 * s))):
            pygame.draw.line(surf, grout,
                             (ox - 2 + gi, oy + oh),
                             (ox - 2 + gi, oy + oh + base_h), 1)

        # ===== 2. 성벽 (황토 + 석재 질감) =====
        pygame.draw.rect(surf, (160, 140, 105), (ox, oy, ow, oh))
        # 성벽 석재 질감 (미세 패치)
        random.seed(7777)
        for _ in range(int(25 * s)):
            px = ox + random.randint(2, ow - 4)
            py_s = oy + random.randint(2, oh - 4)
            pw = random.randint(3, max(4, int(10 * s)))
            ph = random.randint(2, max(3, int(7 * s)))
            sc = random.choice([stone_light, stone, (150, 135, 110)])
            ps = pygame.Surface((pw, ph), pygame.SRCALPHA)
            ps.fill((*sc, random.randint(40, 80)))
            surf.blit(ps, (px, py_s))
        random.seed()

        # 성벽 하이라이트 (상단 — 빛 받는 면)
        hl_s = pygame.Surface((ow, max(2, int(4 * s))), pygame.SRCALPHA)
        hl_s.fill((210, 195, 160, 70))
        surf.blit(hl_s, (ox, oy))

        # ===== 3. 금장 테두리 + 단청 ─ Stage 1 스타일 =====
        bw = max(1, int(2 * s))
        # 금테 외곽
        pygame.draw.rect(surf, gold_dark, (ox, oy, ow, oh), bw + 1)
        pygame.draw.rect(surf, gold, (ox + 1, oy + 1, ow - 2, oh - 2), bw)
        # 단청 줄 (빨강/파랑 교대)
        for offset_i, offset_v in enumerate([max(2, int(4 * s)),
                                             max(3, int(7 * s)),
                                             max(4, int(10 * s))]):
            dc = dancheong_red if offset_i % 2 == 0 else dancheong_blue
            da = 90 - offset_i * 15
            ds = pygame.Surface((ow - offset_v * 2, oh - offset_v * 2), pygame.SRCALPHA)
            pygame.draw.rect(ds, (*dc, max(10, da)),
                             (0, 0, ow - offset_v * 2, oh - offset_v * 2), 1)
            surf.blit(ds, (ox + offset_v, oy + offset_v))

        # 뇌문(thunder pattern) 장식 — 코너 4곳
        tp = max(2, int(5 * s))
        for corner_x, corner_y in [(ox + tp + 2, oy + tp + 2),
                                    (ox + ow - tp - 2, oy + tp + 2),
                                    (ox + tp + 2, oy + oh - tp - 2),
                                    (ox + ow - tp - 2, oy + oh - tp - 2)]:
            # 금장 사각 장식
            pygame.draw.rect(surf, gold_bright,
                             (corner_x - tp, corner_y - tp, tp * 2, tp * 2), 1)
            # 내부 단청 사각
            inner_r = max(1, tp - 1)
            pygame.draw.rect(surf, dancheong_red,
                             (corner_x - inner_r, corner_y - inner_r,
                              inner_r * 2, inner_r * 2))
            # 중앙 청색 점
            pygame.draw.rect(surf, dancheong_blue,
                             (corner_x - 1, corner_y - 1, 2, 2))

        # ===== 4. 마당 바닥 (화강암 석조 타일) =====
        yw = int(130 * s)
        yh = int(100 * s)
        yx = ix - yw // 2
        yy = iy - yh // 2
        # 베이스 석재
        pygame.draw.rect(surf, stone, (yx, yy, yw, yh))
        # 방사형 그라데이션 (중앙 밝게)
        for ring in range(8, 0, -1):
            frac = ring / 8.0
            rr = int(min(yw, yh) // 2 * frac)
            a = max(1, int(12 * (1.0 - frac)))
            gs = pygame.Surface((rr * 2 + 2, rr * 2 + 2), pygame.SRCALPHA)
            pygame.draw.circle(gs, (195, 185, 165, a), (rr + 1, rr + 1), rr)
            surf.blit(gs, (ix - rr - 1, iy - rr - 1))
        # 타일 줄눈
        tile_sz = max(6, int(14 * s))
        for ty in range(yy, yy + yh, tile_sz):
            pygame.draw.line(surf, grout, (yx, ty), (yx + yw, ty), 1)
        row_n = 0
        for ty in range(yy, yy + yh, tile_sz):
            x_off = (row_n % 2) * (tile_sz // 2)
            for tx in range(yx + x_off, yx + yw, tile_sz):
                pygame.draw.line(surf, grout, (tx, ty), (tx, ty + tile_sz), 1)
            row_n += 1
        # 타일 색상 변화 (미세 — 밝은 패치)
        random.seed(8888)
        for _ in range(int(18 * s)):
            ptx = yx + random.randint(2, yw - 4)
            pty = yy + random.randint(2, yh - 4)
            ptw = random.randint(tile_sz - 2, tile_sz + 2)
            pth = random.randint(tile_sz - 2, tile_sz + 2)
            tc_choice = random.choice([stone_light, (82, 74, 65), (65, 65, 72)])
            ts = pygame.Surface((ptw, pth), pygame.SRCALPHA)
            ts.fill((*tc_choice, random.randint(25, 55)))
            surf.blit(ts, (ptx, pty))
        random.seed()

        # ===== 5. 코트 (핑파이터 경기장) =====
        cw = int(85 * s)
        ch_c = int(65 * s)
        court_x = ix - cw // 2
        court_y = iy - ch_c // 2
        # 코트 바닥 — 밝은 크림색
        pygame.draw.rect(surf, cream, (court_x, court_y, cw, ch_c))
        # 코트 내부 타일 텍스처
        ct_sz = max(4, int(8 * s))
        for cty in range(court_y, court_y + ch_c, ct_sz):
            for ctx in range(court_x, court_x + cw, ct_sz):
                if (cty // ct_sz + ctx // ct_sz) % 2 == 0:
                    cs = pygame.Surface((ct_sz, ct_sz), pygame.SRCALPHA)
                    cs.fill((220, 205, 180, 30))
                    surf.blit(cs, (ctx, cty))
        # 금장 코트 테두리
        pygame.draw.rect(surf, gold_dark,
                         (court_x - 1, court_y - 1, cw + 2, ch_c + 2), max(1, int(2 * s)))
        pygame.draw.rect(surf, gold,
                         (court_x, court_y, cw, ch_c), max(1, int(1 * s)))
        # 중앙선 (금)
        pygame.draw.line(surf, gold,
                         (court_x, iy), (court_x + cw, iy), max(1, int(1 * s)))
        # 중앙선 양쪽 단청 줄
        if s > 0.4:
            dl = max(1, int(1 * s))
            pygame.draw.line(surf, (*dancheong_red, 160),
                             (court_x + 2, iy - dl - 1),
                             (court_x + cw - 2, iy - dl - 1), 1)
            pygame.draw.line(surf, (*dancheong_blue, 160),
                             (court_x + 2, iy + dl + 1),
                             (court_x + cw - 2, iy + dl + 1), 1)
        # 서브 영역 선
        sv_off = max(3, int(10 * s))
        pygame.draw.line(surf, (*gold_dark, 120),
                         (court_x, court_y + sv_off),
                         (court_x + cw, court_y + sv_off), 1)
        pygame.draw.line(surf, (*gold_dark, 120),
                         (court_x, court_y + ch_c - sv_off),
                         (court_x + cw, court_y + ch_c - sv_off), 1)

        # ===== 6. 태극 문양 (코트 중앙) =====
        if s > 0.35:
            tr = max(4, int(10 * s))
            # 태극 글로우
            for gi in range(tr + 6, tr, -1):
                ga = max(1, int(25 * (gi - tr) / 6))
                gs = pygame.Surface((gi * 2 + 2, gi * 2 + 2), pygame.SRCALPHA)
                pygame.draw.circle(gs, (25, 25, 200, ga),
                                   (gi + 1, gi + 1), gi)
                surf.blit(gs, (ix - gi - 1, iy - gi - 1))
            # 태극 외곽원
            pygame.draw.circle(surf, gold, (ix, iy), tr + 1, max(1, int(1 * s)))
            # 빨강 반원 (상)
            pygame.draw.circle(surf, (200, 50, 50), (ix, iy), tr)
            # 파랑 하반원 덮기
            pygame.draw.rect(surf, (40, 70, 160),
                             (ix - tr, iy, tr * 2, tr))
            # S-커브 효과 (음양)
            small_r = max(2, tr // 2)
            pygame.draw.circle(surf, (200, 50, 50),
                               (ix, iy + small_r), small_r)
            pygame.draw.circle(surf, (40, 70, 160),
                               (ix, iy - small_r), small_r)
            # 중심점
            pygame.draw.circle(surf, (200, 50, 50),
                               (ix, iy - small_r), max(1, small_r // 2))
            pygame.draw.circle(surf, (40, 70, 160),
                               (ix, iy + small_r), max(1, small_r // 2))

        # ===== 7. 기와지붕 본관 (상단) =====
        main_w = int(90 * s)
        main_h = int(22 * s)
        main_y_pos = iy - int(42 * s)
        # 기단
        bh = max(2, int(4 * s))
        pygame.draw.rect(surf, stone,
                         (ix - main_w // 2 - 2, main_y_pos + main_h,
                          main_w + 4, bh))
        pygame.draw.line(surf, stone_light,
                         (ix - main_w // 2 - 2, main_y_pos + main_h),
                         (ix + main_w // 2 + 2, main_y_pos + main_h), 1)
        # 벽체 (크림)
        pygame.draw.rect(surf, beige,
                         (ix - main_w // 2, main_y_pos, main_w, main_h))
        # 단청 줄 (처마 아래)
        pygame.draw.line(surf, dancheong_red,
                         (ix - main_w // 2 + 2, main_y_pos + 1),
                         (ix + main_w // 2 - 2, main_y_pos + 1), 1)
        pygame.draw.line(surf, dancheong_blue,
                         (ix - main_w // 2 + 2, main_y_pos + 3),
                         (ix + main_w // 2 - 2, main_y_pos + 3), 1)
        pygame.draw.line(surf, gold_dark,
                         (ix - main_w // 2 + 2, main_y_pos + 2),
                         (ix + main_w // 2 - 2, main_y_pos + 2), 1)
        # 기둥 (나무 — 빨간색)
        pillar_gap = max(8, main_w // 5)
        for col_off in range(-main_w // 2 + pillar_gap, main_w // 2, pillar_gap):
            pw = max(1, int(2 * s))
            pygame.draw.line(surf, wood_red,
                             (ix + col_off, main_y_pos + 4),
                             (ix + col_off, main_y_pos + main_h), pw)
        # 기와지붕 (회색 다층)
        rw = main_w + int(18 * s)
        rh = max(10, int(18 * s))
        # 지붕 그림자
        pygame.draw.arc(surf, stone_dark,
                        (ix - rw // 2 - 1, main_y_pos - rh - 1, rw + 2, rh * 2 + 2),
                        0, math.pi, max(2, int(4 * s)))
        # 지붕 본체 (회색 기와)
        pygame.draw.arc(surf, (55, 55, 50),
                        (ix - rw // 2, main_y_pos - rh, rw, rh * 2),
                        0, math.pi, max(2, int(3 * s)))
        # 지붕 하이라이트
        pygame.draw.arc(surf, (85, 80, 72),
                        (ix - rw // 2 + 2, main_y_pos - rh + 2, rw - 4, rh * 2 - 4),
                        0.1, math.pi - 0.1, max(1, int(2 * s)))
        # 용마루 (꼭대기 라인)
        pygame.draw.line(surf, (70, 65, 58),
                         (ix - rw // 2 + 4, main_y_pos - rh // 2 + 1),
                         (ix + rw // 2 - 4, main_y_pos - rh // 2 + 1),
                         max(1, int(1 * s)))
        # 처마 끝 금장
        pygame.draw.arc(surf, gold_dark,
                        (ix - rw // 2 - 2, main_y_pos - rh - 1, rw + 4, rh * 2 + 2),
                        0, math.pi, 1)

        # ===== 8. 좌우 문루 (작은 건물) =====
        for side in [-1, 1]:
            gx = ix + side * int(55 * s)
            gy = iy + int(15 * s)
            gw = int(28 * s)
            gh = int(16 * s)
            # 기단
            pygame.draw.rect(surf, stone,
                             (gx - gw // 2 - 1, gy + gh, gw + 2, max(2, int(3 * s))))
            # 벽체
            pygame.draw.rect(surf, beige, (gx - gw // 2, gy, gw, gh))
            # 단청 줄
            pygame.draw.line(surf, dancheong_red,
                             (gx - gw // 2 + 1, gy + 1),
                             (gx + gw // 2 - 1, gy + 1), 1)
            # 기둥
            for co in [-gw // 3, gw // 3]:
                pygame.draw.line(surf, wood_red,
                                 (gx + co, gy + 2),
                                 (gx + co, gy + gh), max(1, int(1 * s)))
            # 지붕
            grw = gw + int(10 * s)
            grh = max(6, int(12 * s))
            pygame.draw.arc(surf, (55, 55, 50),
                            (gx - grw // 2, gy - grh, grw, grh * 2),
                            0, math.pi, max(1, int(2 * s)))
            pygame.draw.arc(surf, gold_dark,
                            (gx - grw // 2 - 1, gy - grh - 1, grw + 2, grh * 2 + 2),
                            0, math.pi, 1)

        # ===== 9. 등롱 (4개 — 코트 모서리) =====
        lantern_positions = [
            (ix - int(48 * s), iy - int(28 * s)),
            (ix + int(48 * s), iy - int(28 * s)),
            (ix - int(48 * s), iy + int(35 * s)),
            (ix + int(48 * s), iy + int(35 * s)),
        ]
        for lx, ly in lantern_positions:
            # 등롱 기둥
            pygame.draw.line(surf, stone,
                             (lx, ly + max(2, int(3 * s))),
                             (lx, ly + int(18 * s)), max(1, int(2 * s)))
            # 등롱 몸체 (빨간 사각)
            lr = max(2, int(4 * s))
            lh = max(3, int(6 * s))
            # 글로우
            glow_s = pygame.Surface((lr * 4 + 4, lh * 2 + 4), pygame.SRCALPHA)
            gw_c = lr * 2 + 2
            gh_c = lh + 2
            for gi in range(3, 0, -1):
                ga = max(1, 25 * gi)
                pygame.draw.rect(glow_s,
                                 (255, 120, 40, ga),
                                 (gw_c - lr * gi, gh_c - lh * gi // 2,
                                  lr * gi * 2, lh * gi), border_radius=1)
            surf.blit(glow_s, (lx - lr * 2 - 2, ly - lh - 2))
            # 몸체
            pygame.draw.rect(surf, (180, 40, 30),
                             (lx - lr, ly - lh // 2, lr * 2, lh))
            # 금장 테두리
            pygame.draw.rect(surf, gold_dark,
                             (lx - lr, ly - lh // 2, lr * 2, lh), 1)
            # 꼭대기
            pygame.draw.line(surf, stone_dark,
                             (lx - lr - 1, ly - lh // 2),
                             (lx + lr + 1, ly - lh // 2), 1)

        # ===== 10. 벚꽃 장식 (코트 주변) =====
        if s > 0.45:
            random.seed(3456)
            for _ in range(int(12 * s)):
                bx = ix + random.randint(-int(65 * s), int(65 * s))
                by = iy + random.randint(-int(55 * s), int(55 * s))
                br = max(1, random.randint(1, int(3 * s)))
                ba = random.randint(100, 200)
                bs = pygame.Surface((br * 2 + 4, br * 2 + 4), pygame.SRCALPHA)
                bc_p = br + 2
                # 꽃잎 글로우
                pygame.draw.circle(bs, (255, 180, 200, ba // 3), (bc_p, bc_p), br + 1)
                pygame.draw.circle(bs, (255, 200, 210, ba), (bc_p, bc_p), br)
                surf.blit(bs, (bx - bc_p, by - bc_p))
            random.seed()

        # ===== 11. 착륙 패드 (도킹용 — 코트 아래) =====
        if s > 0.4:
            pad_y = iy + int(42 * s)
            pad_r = max(4, int(8 * s))
            # 원형 패드
            pygame.draw.circle(surf, stone_light, (ix, pad_y), pad_r + 2)
            pygame.draw.circle(surf, stone, (ix, pad_y), pad_r)
            # 방향 마커 (십자)
            ml = max(2, pad_r - 2)
            pygame.draw.line(surf, gold, (ix - ml, pad_y), (ix + ml, pad_y), 1)
            pygame.draw.line(surf, gold, (ix, pad_y - ml), (ix, pad_y + ml), 1)
            # 외곽 원
            pygame.draw.circle(surf, gold_dark, (ix, pad_y), pad_r + 2, 1)

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
    def _draw_hud_dynamic(self, surf, speed_pct, target_name, distance_pct):
        hud = (80, 200, 255)
        dim = (40, 100, 140)

        # 속도 바
        bar_x, bar_y, bar_h = 8, 200, 200
        fill_h = int(bar_h * speed_pct)
        pygame.draw.rect(surf, dim, (bar_x, bar_y, 6, bar_h), 1)
        if fill_h > 0:
            pygame.draw.rect(surf, hud,
                             (bar_x + 1, bar_y + bar_h - fill_h, 4, fill_h))
        spd_s = self.font_hud.render(f"{int(speed_pct * 9999)}", True, hud)
        surf.blit(spd_s, (bar_x, bar_y + bar_h + 5))

        # 목표 (우상단)
        tgt = self.font_hud.render(f"TGT: {target_name}", True, hud)
        surf.blit(tgt, (self.W - 35 - tgt.get_width(), 80))
        dst = self.font_hud.render(
            f"DIST: {max(0, int(distance_pct * 100))}%", True,
            dim if distance_pct > 0.5 else hud)
        surf.blit(dst, (self.W - 35 - dst.get_width(), 95))

        # 하단 좌표
        coord = self.font_hud.render(
            f"X:{random.randint(1000, 9999)} "
            f"Y:{random.randint(1000, 9999)} "
            f"Z:{random.randint(100, 999)}", True, dim)
        surf.blit(coord, (self.W // 2 - coord.get_width() // 2, self.H - 35))

        # 스캐너 sweep
        scx, scy = self.W - 22, 110
        ang = self.time * 2
        pygame.draw.line(surf, hud, (scx, scy),
                         (scx + int(12 * math.cos(ang)),
                          scy + int(12 * math.sin(ang))), 1)

    # ──────────────────────────────────────────────
    #  탑뷰 은하 맵
    # ──────────────────────────────────────────────
    def _render_galaxy_map(self, cleared, target_planet):
        ms = self.map_surface
        ms.fill((5, 5, 15, 255))

        self._draw_stars_layer(ms, self.stars_dust, 0.5)
        self._draw_stars_layer(ms, self.stars_far)
        self._draw_stars_layer(ms, self.stars_mid)
        self._draw_nebulae(ms, 0.3)

        # 경로선
        for i in range(len(self.planet_positions) - 1):
            x1, y1 = self.planet_positions[i]
            x2, y2 = self.planet_positions[i + 1]
            col = (60, 100, 160) if (i + 1) in cleared else (25, 35, 55)
            dx, dy = x2 - x1, y2 - y1
            dist = math.hypot(dx, dy)
            if dist < 1:
                continue
            steps = int(dist / 7)
            for j in range(0, steps, 2):
                t = j / max(1, steps)
                pygame.draw.circle(ms, col,
                                   (int(x1 + dx * t), int(y1 + dy * t)), 1)

        # 행성들 (테마별 고유 렌더링)
        for i, (px, py) in enumerate(self.planet_positions):
            pn = i + 1
            cfg = PLANET_CONFIGS.get(pn, {})
            gc = cfg.get("glow_color", (150, 150, 150))
            rad = cfg.get("size", 28)
            nm = cfg.get("name", f"행성 {pn}")
            is_tgt = pn == target_planet
            is_clr = pn in cleared

            # 타겟 글로우
            if is_tgt:
                gr = rad + 14 + int(5 * math.sin(self.time * 3))
                gs = pygame.Surface((gr * 2 + 8, gr * 2 + 8), pygame.SRCALPHA)
                for rr in range(gr, rad, -2):
                    a = int(45 * (1 - (rr - rad) / (gr - rad)))
                    pygame.draw.circle(gs, (*gc, a), (gr + 4, gr + 4), rr)
                ms.blit(gs, (px - gr - 4, py - gr - 4))

            if is_clr:
                # 클리어: 테마 렌더링 후 어둡게 + 체크마크
                self._draw_dest_planet(ms, px, py, rad, pn)
                # 어둡게 오버레이
                dark_s = pygame.Surface((rad * 2 + 4, rad * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(dark_s, (0, 0, 0, 120),
                                   (rad + 2, rad + 2), rad)
                ms.blit(dark_s, (px - rad - 2, py - rad - 2))
                # 체크마크
                pygame.draw.line(ms, (100, 255, 100),
                                 (px - 8, py), (px - 2, py + 7), 3)
                pygame.draw.line(ms, (100, 255, 100),
                                 (px - 2, py + 7), (px + 10, py - 8), 3)
            else:
                # 테마별 렌더링
                self._draw_dest_planet(ms, px, py, rad, pn)

            # 외곽선
            oc = gc if is_tgt else (55, 65, 85)
            pygame.draw.circle(ms, oc, (px, py), rad, 1)
            # 이름 라벨
            ns = self.font_sm.render(nm, True, (190, 200, 220))
            ms.blit(ns, ns.get_rect(center=(px, py + rad + 15)))
            ss = self.font_xs.render(f"Stage {pn}", True, (110, 120, 140))
            ms.blit(ss, ss.get_rect(center=(px, py + rad + 28)))

    # ══════════════════════════════════════════════
    #  메인 공개 API
    # ══════════════════════════════════════════════
    def show_travel_animation(self, from_planet, to_planet,
                              cleared_planets=None):
        """
        시네마틱 우주 여행 (9단계)
        P1: 1인칭 콕핏 워프  P2: 시점 전환  P3: 3인칭 횡스크롤
        P4: 행성 접근  P5: 도착  P6: 클로즈업 줌인
        P7: 지표면+경기장  P8: 수직 착륙+도킹  P9: 크로스페이드 전환
        """
        if cleared_planets is None:
            cleared_planets = []

        tcfg = PLANET_CONFIGS.get(to_planet, {})
        tname = tcfg.get("name", f"행성 {to_planet}")

        FPS = 60
        # Phase 듀레이션 (초)
        DUR = {1: 3.0, 2: 2.0, 3: 3.0, 4: 2.0, 5: 1.5,
               6: 2.5, 7: 2.5, 8: 2.0, 9: 1.5}
        FRAMES = {k: int(v * FPS) for k, v in DUR.items()}

        # 우주선 크루즈 위치
        cruise_x = self.W * 0.28
        ship_yb = self.H * 0.48

        # 행성 위치
        pend_x = self.W * 0.62
        p_y = self.H * 0.45
        pr_sm, pr_big = 8, 65

        # 은하 맵 프리렌더
        self._render_galaxy_map(cleared_planets, to_planet)

        phase = 1
        frame = 0
        skipped = False
        _prev_phase_frame = None
        BLEND_FRAMES = 30  # 0.5초 크로스페이드

        # ── 연속 줌 시스템 (Phase 5-7을 하나의 줌으로 통합) ──
        _zoom_dur = DUR[5] + DUR[6] + DUR[7]   # 6.5초
        _z5 = DUR[5] / _zoom_dur               # ~0.231
        _z6 = (DUR[5] + DUR[6]) / _zoom_dur    # ~0.615
        _zoom_surf_cache = {}                   # 표면 렌더 캐시

        while True:
            dt = self.clock.tick(FPS) / 1000.0
            self.time += dt
            frame += 1

            if self._poll_skip():
                skipped = True
                break

            self._update_engine_particles(dt)
            self.screen.fill((2, 2, 8))

            # ════════════════ Phase 1: 1인칭 콕핏 워프 ════════════════
            if phase == 1:
                t = frame / FRAMES[1]
                warp_int = _ease_in_out(min(1.0, t * 1.5))

                # 워프 가속에 따른 배경 색조 변화 (깊은 우주 → 에너지 블루)
                bg_b = int(8 + 12 * warp_int)
                bg_p = int(2 + 5 * warp_int)
                self.screen.fill((bg_p, bg_p, bg_b))

                self._update_warp_stars(dt, 1.0 + t * 2.0)
                self._draw_warp_stars(self.screen, warp_int)
                self._draw_nebulae(self.screen, 0.3 * warp_int)

                # 워프 터널 (동심원 + 에너지 링)
                self._draw_warp_tunnel(self.screen, warp_int * 0.8, t)

                # 우주 먼지 (속도감)
                self._draw_cosmic_dust(self.screen, 0.3 * warp_int, t)

                # 목적지 빛줄기 (후반 강화)
                if t > 0.3:
                    ray_int = (t - 0.3) / 0.7 * warp_int * 0.5
                    gc = tcfg.get("glow_color", (200, 200, 200))
                    self._draw_god_rays(self.screen, self.W // 2, self.H // 2,
                                        ray_int, gc)

                # 에너지 충격파 (워프 펄스)
                if t > 0.15:
                    pulse_r = int(50 + 200 * (t - 0.15) / 0.85)
                    self._draw_energy_wave(self.screen, self.W // 2,
                                           self.H // 2, pulse_r,
                                           warp_int * 0.4, self.time)

                # 스캔라인 (더 밀도 높게 + 컬러)
                for _ in range(int(3 * warp_int)):
                    if random.random() < 0.4:
                        sly = random.randint(0, self.H)
                        sc_r = random.randint(15, 40)
                        sc_b = random.randint(50, 100)
                        pygame.draw.line(self.screen, (sc_r, sc_r + 15, sc_b),
                                         (0, sly), (self.W, sly), 1)

                # 콕핏 (증폭된 셰이크)
                shake_i = 0.5 + t * 2.5
                sx = random.uniform(-shake_i, shake_i)
                sy = random.uniform(-shake_i, shake_i)
                self.screen.blit(self.cockpit_surface, (int(sx), int(sy)))

                # 콕핏 윈도우 에지 글로우 (워프 에너지 반사)
                edge_a = int(30 * warp_int)
                if edge_a > 3:
                    eg = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
                    pygame.draw.rect(eg, (60, 120, 255, edge_a),
                                     (0, 0, self.W, self.H), 8)
                    pygame.draw.rect(eg, (100, 160, 255, edge_a // 2),
                                     (3, 3, self.W - 6, self.H - 6), 4)
                    self.screen.blit(eg, (0, 0))

                # 동적 HUD
                self._draw_hud_dynamic(self.screen,
                                       0.3 + t * 0.6, tname, 1.0 - t * 0.3)

                # 텍스트
                if t < 0.3:
                    wa = _clamp(t / 0.3 * 255)
                    ws = self.font_med.render("워프 드라이브 가동", True,
                                              (80, 200, 255))
                    ws.set_alpha(wa)
                    self.screen.blit(ws, ws.get_rect(
                        center=(self.W // 2, self.H * 0.25)))
                elif t > 0.7:
                    ea = _clamp((t - 0.7) / 0.3 * 255)
                    es = self.font_med.render(f"목표: {tname}", True,
                                              (255, 230, 150))
                    es.set_alpha(ea)
                    self.screen.blit(es, es.get_rect(
                        center=(self.W // 2, self.H * 0.25)))

                # 크로스페이드 오버레이
                if _prev_phase_frame is not None and frame <= BLEND_FRAMES:
                    _ba = int(255 * (1.0 - frame / BLEND_FRAMES) ** 1.5)
                    if _ba > 3:
                        _pf = _prev_phase_frame.copy()
                        _pf.set_alpha(_ba)
                        self.screen.blit(_pf, (0, 0))
                    if frame >= BLEND_FRAMES:
                        _prev_phase_frame = None

                pygame.display.flip()
                if frame >= FRAMES[1]:
                    _prev_phase_frame = self.screen.copy()
                    phase = 2
                    frame = 0

            # ════════════════ Phase 2: 시점 전환 ════════════════
            elif phase == 2:
                t = frame / FRAMES[2]
                et = _ease_in_out(t)

                # 배경 색조 전환 (워프 잔여 에너지 → 심우주)
                bg_fade = max(0.0, 1.0 - et * 1.5)
                bg_b = int(8 + 10 * bg_fade)
                bg_p = int(2 + 4 * bg_fade)
                self.screen.fill((bg_p, bg_p, bg_b))

                fp_alpha = max(0.0, 1.0 - et * 2.0)

                # 워프 별 페이드아웃
                if fp_alpha > 0.1:
                    self._update_warp_stars(dt, max(0.3, 2.0 - t * 3))
                    self._draw_warp_stars(self.screen, fp_alpha)

                # 워프 터널 잔상 (초반 페이드아웃)
                if fp_alpha > 0.2:
                    self._draw_warp_tunnel(self.screen, fp_alpha * 0.4, t * 0.5)

                # 횡스크롤 별 페이드인
                sa = min(1.0, et * 1.5)
                for layer in [self.stars_dust, self.stars_far,
                              self.stars_mid, self.stars_near]:
                    self._update_stars(layer, 0.5 + et)
                self._draw_stars_layer(self.screen, self.stars_dust, sa * 0.4)
                self._draw_stars_layer(self.screen, self.stars_far, sa)
                self._draw_stars_layer(self.screen, self.stars_mid, sa)
                self._draw_stars_layer(self.screen, self.stars_near, sa * 0.7)

                # 성운 전환 (더 깊고 장엄하게)
                self._update_nebulae(0.3 + et * 0.5)
                self._draw_nebulae(self.screen, sa * 0.6)

                # 우주 먼지 (전환 중 떠다니는 입자)
                self._draw_cosmic_dust(self.screen, 0.15 + sa * 0.2, self.time)

                # 콕핏 페이드아웃 + 에지 글로우 소멸
                if fp_alpha > 0.05:
                    cc = self.cockpit_surface.copy()
                    cc.set_alpha(_clamp(255 * fp_alpha))
                    self.screen.blit(cc, (0, 0))
                    # 콕핏 에지 글로우 잔상
                    edge_a = int(20 * fp_alpha)
                    if edge_a > 2:
                        eg = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
                        pygame.draw.rect(eg, (40, 90, 200, edge_a),
                                         (0, 0, self.W, self.H), 6)
                        self.screen.blit(eg, (0, 0))

                # 에너지 파동 (워프 해제 충격파 - 초반)
                if t < 0.4:
                    wave_r = int(100 + 300 * t / 0.4)
                    wave_i = max(0.0, 0.5 * (1.0 - t / 0.4))
                    self._draw_energy_wave(self.screen, self.W // 2,
                                           self.H // 2, wave_r,
                                           wave_i, self.time)

                # 우주선 등장 (중앙에서 → 크루즈 위치)
                if et > 0.3:
                    st = _ease_out_cubic((et - 0.3) / 0.7)
                    sx = self.W * 0.5 + (cruise_x - self.W * 0.5) * st
                    sy = self.H * 0.5 + (ship_yb - self.H * 0.5) * st
                    sc = 0.3 + st * 1.0
                    self._draw_ship(self.screen, sx, sy, sc, 0.5 + st * 0.5)
                    # 우주선 엔진 빛줄기
                    if st > 0.3:
                        gc = tcfg.get("glow_color", (200, 200, 200))
                        self._draw_god_rays(self.screen, int(sx), int(sy),
                                            st * 0.15, gc)

                self._update_speed_lines(et * 0.5)
                self._draw_speed_lines(self.screen, et * 0.5)
                self._draw_engine_particles(self.screen)

                if 0.2 < t < 0.8:
                    ta = int(255 * math.sin((t - 0.2) / 0.6 * math.pi))
                    ts = self.font_big.render("은하계 항해", True,
                                              (200, 210, 240))
                    ts.set_alpha(ta)
                    self.screen.blit(ts, ts.get_rect(
                        center=(self.W // 2, 35)))

                # 크로스페이드 오버레이
                if _prev_phase_frame is not None and frame <= BLEND_FRAMES:
                    _ba = int(255 * (1.0 - frame / BLEND_FRAMES) ** 1.5)
                    if _ba > 3:
                        _pf = _prev_phase_frame.copy()
                        _pf.set_alpha(_ba)
                        self.screen.blit(_pf, (0, 0))
                    if frame >= BLEND_FRAMES:
                        _prev_phase_frame = None

                pygame.display.flip()
                if frame >= FRAMES[2]:
                    _prev_phase_frame = self.screen.copy()
                    phase = 3
                    frame = 0

            # ════════════════ Phase 3: 3인칭 횡스크롤 ════════════════
            elif phase == 3:
                t = frame / FRAMES[3]

                for layer in [self.stars_dust, self.stars_far, self.stars_mid,
                              self.stars_near, self.stars_front]:
                    self._update_stars(layer, 1.0)
                self._update_nebulae(1.0)
                self._draw_nebulae(self.screen, 0.7)

                self._draw_stars_layer(self.screen, self.stars_dust, 0.3)
                self._draw_stars_layer(self.screen, self.stars_far)
                self._draw_stars_layer(self.screen, self.stars_mid)

                # 우주 먼지 (깊이감)
                self._draw_cosmic_dust(self.screen, 0.35, self.time)

                self._update_scroll_planets(1.0)
                self._draw_scroll_planets(self.screen)

                self._draw_stars_layer(self.screen, self.stars_near)
                self._draw_stars_layer(self.screen, self.stars_front, 0.8)

                # 오로라 (상단 먼 거리에서 희미하게)
                aurora_i = 0.15 + 0.1 * math.sin(self.time * 0.7)
                self._draw_aurora(self.screen, 30, aurora_i, self.time)

                self._update_speed_lines(1.0)
                self._draw_speed_lines(self.screen, min(1.0, t * 3))

                self._draw_engine_particles(self.screen)

                # 우주선 + 엔진 글로우
                bob = math.sin(self.time * 2.5) * 8
                self._draw_ship(self.screen, cruise_x, ship_yb + bob, 1.3, 1.0)

                # 우주선 주변 에너지 스트림 (미세한 빛줄기)
                gc = tcfg.get("glow_color", (200, 200, 200))
                self._draw_god_rays(self.screen, int(cruise_x - 40),
                                    int(ship_yb + bob),
                                    0.1 + 0.05 * math.sin(self.time * 2),
                                    gc)

                # 목적지 방향 빛 (우하단에서 은은하게)
                if t > 0.4:
                    dest_i = min(0.2, (t - 0.4) * 0.5)
                    self._draw_god_rays(self.screen, self.W + 50,
                                        int(self.H * 0.4),
                                        dest_i, gc)

                ts = self.font_big.render("은하계 항해", True, (200, 210, 240))
                self.screen.blit(ts, ts.get_rect(center=(self.W // 2, 35)))

                if t > 0.3:
                    ha = _clamp((t - 0.3) * 4 * 255)
                    gc = tcfg.get("glow_color", (200, 200, 200))
                    hs = self.font_med.render(f"목표: {tname}", True, gc)
                    hs.set_alpha(ha)
                    self.screen.blit(hs, hs.get_rect(
                        center=(self.W // 2, self.H - 40)))

                # 크로스페이드 오버레이
                if _prev_phase_frame is not None and frame <= BLEND_FRAMES:
                    _ba = int(255 * (1.0 - frame / BLEND_FRAMES) ** 1.5)
                    if _ba > 3:
                        _pf = _prev_phase_frame.copy()
                        _pf.set_alpha(_ba)
                        self.screen.blit(_pf, (0, 0))
                    if frame >= BLEND_FRAMES:
                        _prev_phase_frame = None

                pygame.display.flip()
                if frame >= FRAMES[3]:
                    _prev_phase_frame = self.screen.copy()
                    phase = 4
                    frame = 0

            # ════════════════ Phase 4: 행성 접근 ════════════════
            elif phase == 4:
                t = frame / FRAMES[4]
                slow = max(0.05, 1.0 - t * 0.9)

                for layer in [self.stars_dust, self.stars_far,
                              self.stars_mid, self.stars_near]:
                    self._update_stars(layer, slow)
                self._update_nebulae(slow)
                self._draw_nebulae(self.screen, 0.5 * slow)

                self._draw_stars_layer(self.screen, self.stars_dust, 0.3)
                self._draw_stars_layer(self.screen, self.stars_far)
                self._draw_stars_layer(self.screen, self.stars_mid)

                # 우주 먼지 (행성에 가까워지며 점차 희미)
                self._draw_cosmic_dust(self.screen,
                                       0.3 * max(0.1, 1.0 - t * 1.5),
                                       self.time)

                self._update_scroll_planets(slow)
                self._draw_scroll_planets(self.screen)
                self._draw_stars_layer(self.screen, self.stars_near)

                self._update_speed_lines(slow)
                self._draw_speed_lines(self.screen, max(0, 1.0 - t * 2))

                # 행성 진입
                ep = _ease_in_out(t)
                px = self.W + 100 + (pend_x - self.W - 100) * ep
                pr = pr_sm + (pr_big - pr_sm) * ep

                # 행성 대기 글로우 (접근할수록 강렬)
                if pr > 20:
                    gc = tcfg.get("glow_color", (200, 200, 200))
                    atmo_s = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
                    glow_r = int(pr * 1.6)
                    glow_a = min(50, int(60 * ep))
                    for gi in range(3):
                        gr = glow_r + gi * 8
                        ga = max(1, glow_a - gi * 15)
                        pygame.draw.circle(atmo_s,
                                           (gc[0], gc[1], gc[2], ga),
                                           (int(px), int(p_y)), gr, 3)
                    self.screen.blit(atmo_s, (0, 0))

                self._draw_dest_planet(self.screen, int(px), int(p_y),
                                       int(pr), to_planet)

                # 행성 에지에서 빛줄기 (중력 렌즈 효과)
                if ep > 0.3:
                    gc = tcfg.get("glow_color", (200, 200, 200))
                    lens_i = min(0.3, (ep - 0.3) * 0.6)
                    self._draw_god_rays(self.screen, int(px), int(p_y),
                                        lens_i, gc)

                # 오로라 (행성 근처에서 희미하게 발현)
                if ep > 0.5:
                    aurora_i = min(0.2, (ep - 0.5) * 0.4)
                    self._draw_aurora(self.screen,
                                      int(p_y - pr * 0.8),
                                      aurora_i, self.time)

                self._draw_engine_particles(self.screen)

                decel = max(0.0, 1.0 - t * 1.2)
                sx = cruise_x - 30 * (1 - decel)
                bob = math.sin(self.time * 2.5) * 8 * decel
                sc = max(0.8, 1.3 - t * 0.5)
                ep_e = max(0.2, 1.0 - t * 0.8)
                self._draw_ship(self.screen, sx, ship_yb + bob, sc, ep_e)

                # 에너지 파동 (감속 시 방출)
                if t > 0.3 and t < 0.7:
                    wave_t = (t - 0.3) / 0.4
                    wave_r = int(40 + 150 * wave_t)
                    wave_i = 0.25 * (1.0 - wave_t)
                    self._draw_energy_wave(self.screen, int(sx),
                                           int(ship_yb + bob), wave_r,
                                           wave_i, self.time)

                ts = self.font_big.render("은하계 항해", True, (200, 210, 240))
                self.screen.blit(ts, ts.get_rect(center=(self.W // 2, 35)))

                na = _clamp(t * 2 * 255)
                gc = tcfg.get("glow_color", (200, 200, 200))
                ns = self.font_med.render(tname, True, gc)
                ns.set_alpha(na)
                self.screen.blit(ns, ns.get_rect(
                    center=(int(px), int(p_y) + int(pr) + 28)))

                # 크로스페이드 오버레이
                if _prev_phase_frame is not None and frame <= BLEND_FRAMES:
                    _ba = int(255 * (1.0 - frame / BLEND_FRAMES) ** 1.5)
                    if _ba > 3:
                        _pf = _prev_phase_frame.copy()
                        _pf.set_alpha(_ba)
                        self.screen.blit(_pf, (0, 0))
                    if frame >= BLEND_FRAMES:
                        _prev_phase_frame = None

                pygame.display.flip()
                if frame >= FRAMES[4]:
                    _prev_phase_frame = self.screen.copy()
                    phase = 5
                    frame = 0

            # ════════════════════════════════════════════════════
            #  Phase 5-6-7: 연속 줌 시스템 (하나의 몰입 시퀀스)
            #  _zoom: 0.0(도착) → 1.0(지표면+경기장) 단일 파라미터
            # ════════════════════════════════════════════════════
            elif phase in (5, 6, 7):
                t = frame / FRAMES[phase]

                # ─── 글로벌 줌 값 계산 (3페이즈 통합) ───
                if phase == 5:
                    _zoom = t * _z5                          # 0 → 0.231
                elif phase == 6:
                    _zoom = _z5 + t * (DUR[6] / _zoom_dur)  # 0.231 → 0.615
                else:
                    _zoom = _z6 + t * (DUR[7] / _zoom_dur)  # 0.615 → 1.0
                ez = _ease_in_out(_zoom)

                # ─── 배경색: 우주 → 행성 테마 컬러로 점진 전환 ───
                tcol = tcfg.get("theme_color", (80, 100, 80))
                bg_blend = min(1.0, ez * 2.5)
                bg_r = int(2 * (1 - bg_blend) + tcol[0] * bg_blend * 0.25)
                bg_g = int(2 * (1 - bg_blend) + tcol[1] * bg_blend * 0.25)
                bg_b = int(8 * (1 - bg_blend) + tcol[2] * bg_blend * 0.25)
                self.screen.fill((min(255, bg_r), min(255, bg_g), min(255, bg_b)))

                # ─── 별/성운: 점진 페이드아웃 ───
                star_a = max(0.0, 1.0 - ez * 3.0)
                if star_a > 0.02:
                    self._draw_stars_layer(self.screen, self.stars_far, star_a * 0.5)
                    self._draw_stars_layer(self.screen, self.stars_mid, star_a)
                    # 우주 먼지 (별과 함께 사라짐)
                    self._draw_cosmic_dust(self.screen, 0.2 * star_a, self.time)
                neb_a = max(0.0, 0.3 * (1.0 - ez * 4.0))
                if neb_a > 0.02:
                    self._draw_nebulae(self.screen, neb_a)

                # ─── 대기권 오로라 (ez 0.1~0.5에서 빛나다 사라짐) ───
                if 0.05 < ez < 0.55:
                    aur_t = min(1.0, (ez - 0.05) * 4) * max(0.0, 1.0 - (ez - 0.3) * 4)
                    self._draw_aurora(self.screen, int(self.H * 0.15),
                                      0.25 * aur_t, self.time)

                # ─── 대기권 진동 셰이크 (중반부) ───
                shake_zone = max(0.0, min(1.0, (ez - 0.15) * 5)) * \
                             max(0.0, 1.0 - max(0.0, (ez - 0.45)) * 4)
                shake_amt = 6.0 * shake_zone
                shx = int(shake_amt * math.sin(self.time * 18))
                shy = int(shake_amt * math.cos(self.time * 22))

                # ─── 행성 구체 (계속 확대 → 화면 밖으로) ───
                # 행성 위치: pend_x → 중앙으로 이동
                planet_cx = pend_x + (self.W * 0.5 - pend_x) * min(1.0, ez * 4)
                planet_cy = p_y + (self.H * 0.5 - p_y) * min(1.0, ez * 4)
                # 반경: pr_big → 화면 초과 (연속 확대)
                planet_r = int(pr_big + (self.W * 1.8 - pr_big) * ez)
                # 구체 알파: ez 0.5 넘으면 페이드아웃
                sphere_a = max(0, int(255 * max(0.0, 1.0 - max(0.0, ez - 0.35) / 0.25)))
                if sphere_a > 5 and planet_r > 10:
                    # 성능: 반경 캡 300px, 초과분은 배경색 채움
                    capped_r = min(planet_r, 300)
                    self._draw_dest_planet(
                        self.screen, int(planet_cx) + shx,
                        int(planet_cy) + shy,
                        capped_r, to_planet, sphere_a)
                    if planet_r > 300:
                        fill_a = min(sphere_a, int(255 * (planet_r - 300) / 500))
                        fs = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
                        fs.fill((*tcol, fill_a))
                        self.screen.blit(fs, (0, 0))

                # ─── 대기권 진입 이펙트 (ez 0.15~0.5) ───
                if 0.12 < ez < 0.55:
                    atmo_zone = min(1.0, (ez - 0.12) * 5) * \
                                max(0.0, 1.0 - (ez - 0.35) * 5)
                    # 대기 마찰열 글로우 (화면 가장자리)
                    heat_a = int(40 * atmo_zone)
                    if heat_a > 3:
                        hs = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
                        tcol2 = tcfg.get("glow_color", (255, 150, 50))
                        pygame.draw.rect(hs, (tcol2[0], tcol2[1] // 2,
                                              tcol2[2] // 3, heat_a),
                                         (0, 0, self.W, self.H), 12)
                        pygame.draw.rect(hs, (255, 200, 100, heat_a // 2),
                                         (4, 4, self.W - 8, self.H - 8), 6)
                        self.screen.blit(hs, (shx, shy))
                    # 에너지 파동 (대기 충돌 파)
                    if atmo_zone > 0.3:
                        wave_r = int(80 + 200 * atmo_zone)
                        self._draw_energy_wave(self.screen, self.W // 2,
                                               self.H // 2, wave_r,
                                               0.3 * atmo_zone, self.time)

                # ─── 표면 뷰 (ez > 0.2에서 페이드인, 구체 위에 오버레이) ───
                if ez > 0.2:
                    surf_t = min(1.0, (ez - 0.2) / 0.4)  # 0.2→0.6: 0→1
                    surf_a = min(255, int(255 * surf_t))
                    surf_detail = 0.1 + min(1.0, (ez - 0.2) / 0.8) * 0.9
                    # 캐시: 6단계
                    cache_key = int(surf_detail * 5)
                    if cache_key not in _zoom_surf_cache:
                        _cs = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
                        self._draw_planet_surface(_cs, to_planet, surf_detail)
                        _zoom_surf_cache[cache_key] = _cs
                    cached_surf = _zoom_surf_cache[cache_key]

                    # 카메라 줌 (후반부: ez > 0.5)
                    cam_zoom = 1.0 + max(0.0, (ez - 0.5) / 0.5) * 0.4
                    cam_dy = int(max(0.0, (ez - 0.5) / 0.5) * 40)

                    if cam_zoom > 1.01:
                        zw = int(self.W * cam_zoom)
                        zh = int(self.H * cam_zoom)
                        zoomed = pygame.transform.scale(cached_surf, (zw, zh))
                        ox = (zw - self.W) // 2
                        oy = (zh - self.H) // 2 + cam_dy
                        zoomed.set_alpha(surf_a)
                        self.screen.blit(zoomed, (-ox + shx, -oy + shy))
                    else:
                        cached_surf.set_alpha(surf_a)
                        self.screen.blit(cached_surf, (shx, shy))

                # ─── 지면 위 대기 효과 (ez > 0.4) ───
                if ez > 0.4:
                    atmo_t = min(1.0, (ez - 0.4) / 0.4)
                    # 하늘에서 내려오는 빛줄기 (갓 레이)
                    gc = tcfg.get("glow_color", (200, 200, 200))
                    sky_ray_i = 0.15 * atmo_t
                    self._draw_god_rays(self.screen,
                                        self.W // 2 - 100 + shx,
                                        -30 + shy, sky_ray_i, gc)
                    # 지평선 글로우
                    if atmo_t > 0.3:
                        hz_a = int(30 * min(1.0, (atmo_t - 0.3) * 3))
                        hz_s = pygame.Surface((self.W, 80), pygame.SRCALPHA)
                        for hy in range(80):
                            ha = max(1, hz_a - hy * hz_a // 80)
                            pygame.draw.line(hz_s, (gc[0], gc[1], gc[2], ha),
                                             (0, hy), (self.W, hy))
                        self.screen.blit(hz_s,
                                         (0, self.H // 2 - 20 + shy))

                # ─── 경기장 (ez > 0.55에서 등장, 줌과 함께 확대) ───
                if ez > 0.55:
                    arena_t = (ez - 0.55) / 0.45   # 0→1
                    arena_a = min(255, int(255 * min(1.0, arena_t * 2.5)))
                    arena_base_scale = 0.25 + _ease_in_out(arena_t) * 0.75
                    cam_zoom_a = 1.0 + max(0.0, (ez - 0.5) / 0.5) * 0.4
                    arena_scale = arena_base_scale * cam_zoom_a
                    cam_dy_a = int(max(0.0, (ez - 0.5) / 0.5) * 40)
                    arena_cy = self.H // 2 + int(20 * (1 - arena_t)) - cam_dy_a // 2
                    if arena_a > 5:
                        arena_surf = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
                        self._draw_landing_arena(
                            arena_surf, self.W // 2, arena_cy,
                            arena_scale, to_planet)
                        arena_surf.set_alpha(arena_a)
                        self.screen.blit(arena_surf, (0, 0))

                    # 도킹 기지 (ez > 0.8)
                    if ez > 0.8:
                        dock_t = (ez - 0.8) / 0.2
                        dock_a = min(255, int(255 * dock_t * 2))
                        if dock_a > 5:
                            dock_surf = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
                            self._draw_docking_base(
                                dock_surf,
                                self.W // 2 + int(80 * arena_scale),
                                arena_cy + int(10 * arena_scale),
                                arena_scale * 0.8, 0.0)
                            dock_surf.set_alpha(dock_a)
                            self.screen.blit(dock_surf, (0, 0))

                # ─── 우주선 (줌 초반에만 표시, 점진 페이드아웃) ───
                ship_vis = max(0.0, 1.0 - max(0.0, ez - 0.1) * 3.3)
                if ship_vis > 0.03:
                    # 우주선 위치: 행성 왼쪽에서 행성 근처로
                    ship5_start = cruise_x - 30
                    sx_a = ship5_start + (planet_cx - 90 - ship5_start) * \
                           min(1.0, ez * 4)
                    sc_s = 0.8 + 0.1 * min(1.0, ez * 4)
                    if ship_vis < 1.0:
                        _ss = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
                        self._draw_ship(_ss, sx_a, ship_yb, sc_s,
                                        max(0.05, 0.2 * ship_vis))
                        _ss.set_alpha(int(255 * ship_vis))
                        self.screen.blit(_ss, (0, 0))
                    else:
                        self._draw_ship(self.screen, sx_a, ship_yb, sc_s, 0.2)
                    self._draw_engine_particles(self.screen)

                # ─── UI 텍스트 (줌 진행에 따라 전환) ───
                # "은하계 항해" (초반)
                title_a = max(0, int(255 * (1.0 - ez * 4)))
                if title_a > 5:
                    _ts = self.font_big.render("은하계 항해", True,
                                               (200, 210, 240))
                    _ts.set_alpha(title_a)
                    self.screen.blit(_ts, _ts.get_rect(
                        center=(self.W // 2, 35)))
                # "도착!" (줌 0.05~0.25)
                arrive_a = max(0, int(255 * min(1.0, ez * 8) *
                                     max(0.0, 1.0 - max(0.0, ez - 0.15) * 8)))
                if arrive_a > 5:
                    _at = self.font_big.render(f"{tname} 도착!", True,
                                               (255, 230, 150))
                    _at.set_alpha(arrive_a)
                    self.screen.blit(_at, _at.get_rect(
                        center=(self.W // 2, self.H * 0.72)))
                # "대기권 진입" (줌 0.15~0.45)
                atmo_a = max(0, int(255 * min(1.0, max(0.0, ez - 0.12) * 6) *
                                   max(0.0, 1.0 - max(0.0, ez - 0.35) * 6)))
                if atmo_a > 5:
                    _et = self.font_big.render("대기권 진입", True,
                                               (255, 200, 100))
                    _et.set_alpha(atmo_a)
                    self.screen.blit(_et, _et.get_rect(
                        center=(self.W // 2, self.H * 0.25)))
                # 행성 이름 (줌 0.6~)
                name_a = max(0, min(255, int(255 * max(0.0, ez - 0.55) * 4)))
                if name_a > 5:
                    _ns = self.font_big.render(tname, True, (255, 230, 150))
                    _ns.set_alpha(name_a)
                    self.screen.blit(_ns, _ns.get_rect(
                        center=(self.W // 2, int(self.H * 0.12))))

                # ─── 크로스페이드 오버레이 (Phase 4→5 전환용) ───
                if _prev_phase_frame is not None and frame <= BLEND_FRAMES:
                    _ba = int(255 * (1.0 - frame / BLEND_FRAMES) ** 1.5)
                    if _ba > 3:
                        _pf = _prev_phase_frame.copy()
                        _pf.set_alpha(_ba)
                        self.screen.blit(_pf, (0, 0))
                    if frame >= BLEND_FRAMES:
                        _prev_phase_frame = None

                pygame.display.flip()
                if frame >= FRAMES[phase]:
                    if phase == 7:
                        # Phase 7 끝: 착륙 배경 캐시, 표면 캐시 정리
                        self._landing_bg = self.screen.copy()
                        _zoom_surf_cache.clear()
                    _prev_phase_frame = self.screen.copy()
                    phase += 1
                    frame = 0

            # ════════════════ Phase 8: 우주선 수직 하강 + 도킹 ════════════════
            elif phase == 8:
                t = frame / FRAMES[8]
                et = _ease_out_cubic(t)

                # 정적 배경 (Phase 7 끝 캐싱)
                if hasattr(self, '_landing_bg') and self._landing_bg:
                    self.screen.blit(self._landing_bg, (0, 0))
                else:
                    self.screen.fill((130, 150, 60))

                # 대기 중 열 아지랑이 효과 (화면 미세 흔들림)
                heat_shim = max(0.0, 1.0 - et * 1.5) * 2.0
                if heat_shim > 0.3:
                    hsx = int(heat_shim * math.sin(self.time * 12))
                    hsy = int(heat_shim * 0.5 * math.cos(self.time * 15))
                else:
                    hsx, hsy = 0, 0

                # 하늘 빛줄기 (상단에서 내려오는 갓 레이)
                gc = tcfg.get("glow_color", (200, 200, 200))
                sky_int = max(0.0, 0.2 * (1.0 - et * 0.8))
                if sky_int > 0.02:
                    self._draw_god_rays(self.screen,
                                        self.W // 2 + hsx, -20 + hsy,
                                        sky_int, gc)

                # 도킹 기지 (암 개방 애니메이션)
                dock_open = max(0.0, min(1.0, (t - 0.4) * 3.0))
                # Phase 7 끝과 동일 좌표 (cam_zoom=1.4, arena_scale=1.4)
                dock_cx = self.W // 2 + int(80 * 1.4)
                dock_cy = self.H // 2 - 20 + int(10 * 1.4)
                self._draw_docking_base(
                    self.screen, dock_cx, dock_cy, 1.4 * 0.8, dock_open)

                # 우주선 하강
                ship_x = dock_cx
                ship_start_y = -60
                ship_end_y = dock_cy
                ship_y = ship_start_y + (ship_end_y - ship_start_y) * et
                ship_scale = 1.1 - et * 0.3  # 1.1 → 0.8
                engine_pwr = max(0.05, 1.0 - et * 0.9)

                # 그림자 (우주선 아래, 향상된 소프트 쉐도우)
                if et > 0.1:
                    shadow_a = min(80, int(80 * et))
                    shadow_w = int(30 * ship_scale * (0.5 + et * 0.5))
                    shadow_h = max(2, shadow_w // 4)
                    shadow_s = pygame.Surface(
                        (shadow_w * 2 + 8, shadow_h * 2 + 8), pygame.SRCALPHA)
                    # 이중 그림자 (소프트 + 코어)
                    pygame.draw.ellipse(
                        shadow_s, (0, 0, 0, shadow_a // 2),
                        (0, 0, shadow_w * 2 + 8, shadow_h * 2 + 8))
                    pygame.draw.ellipse(
                        shadow_s, (0, 0, 0, shadow_a),
                        (4, 4, shadow_w * 2, shadow_h * 2))
                    self.screen.blit(
                        shadow_s,
                        (int(ship_x - shadow_w - 4),
                         int(ship_end_y + 15 - shadow_h - 4)))

                # 엔진 글로우 (우주선 아래 빛)
                if engine_pwr > 0.1:
                    eng_r = int(15 + 25 * engine_pwr)
                    eng_a = int(40 * engine_pwr)
                    for ei in range(3):
                        er = eng_r + ei * 8
                        ea = max(1, eng_a - ei * 12)
                        pygame.draw.circle(self.screen,
                                           (100, 180, 255, min(255, ea)),
                                           (int(ship_x), int(ship_y + 20)),
                                           er, 2)

                # 착륙 먼지 파티클 (착지 직전 - 더 많은 파티클)
                if t > 0.5:
                    dust_cnt = max(1, int(5 * (t - 0.5) * 4))
                    self._spawn_landing_particles(
                        int(ship_x), int(ship_y + 20 * ship_scale), dust_cnt)
                self._update_engine_particles(dt)
                self._draw_engine_particles(self.screen)

                # 우주선 (도킹 직전까지 표시)
                ship_alpha_t = max(0.0, 1.0 - max(0, (t - 0.85)) * 7)
                if ship_alpha_t > 0.05:
                    ship_surf = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
                    bob = math.sin(self.time * 4) * max(0, 3 * (1.0 - et))
                    self._draw_ship_vertical(
                        ship_surf, ship_x, ship_y + bob,
                        ship_scale, engine_pwr)
                    ship_surf.set_alpha(max(1, int(255 * ship_alpha_t)))
                    self.screen.blit(ship_surf, (0, 0))

                # 도킹 플래시 (t > 0.85, 증폭된 다중 링)
                if t > 0.85:
                    flash_t = (t - 0.85) / 0.15
                    flash_r = int(50 * flash_t)
                    flash_a = max(0, int(255 * (1.0 - flash_t)))
                    if flash_a > 2 and flash_r > 0:
                        fs = pygame.Surface(
                            (flash_r * 2 + 8, flash_r * 2 + 8), pygame.SRCALPHA)
                        fc = flash_r + 4
                        # 외곽 글로우
                        for fi in range(flash_r, 0, -2):
                            fa = max(1, int(flash_a * fi / flash_r))
                            pygame.draw.circle(
                                fs, (255, 255, 255, fa), (fc, fc), fi)
                        # 내부 밝은 코어
                        core_r = max(1, flash_r // 3)
                        for ci in range(core_r, 0, -1):
                            ca = min(255, flash_a + 50)
                            pygame.draw.circle(
                                fs, (255, 255, 220, ca), (fc, fc), ci)
                        self.screen.blit(
                            fs, (dock_cx - fc, dock_cy - fc))
                    # 에너지 파동 (도킹 충격파)
                    wave_r = int(20 + 120 * flash_t)
                    self._draw_energy_wave(self.screen, dock_cx, dock_cy,
                                           wave_r, 0.4 * (1.0 - flash_t),
                                           self.time)

                # "착륙 완료" 텍스트 (글로우 추가)
                if t > 0.8:
                    land_a = min(255, int(255 * (t - 0.8) * 5))
                    # 텍스트 글로우
                    lt_glow = self.font_big.render("착륙 완료", True,
                                                    (100, 200, 100))
                    lt_glow.set_alpha(land_a // 3)
                    for gx, gy in [(-2, 0), (2, 0), (0, -2), (0, 2)]:
                        self.screen.blit(lt_glow, lt_glow.get_rect(
                            center=(self.W // 2 + gx, int(self.H * 0.2) + gy)))
                    lt = self.font_big.render("착륙 완료", True, (200, 255, 200))
                    lt.set_alpha(land_a)
                    self.screen.blit(lt, lt.get_rect(
                        center=(self.W // 2, int(self.H * 0.2))))

                # 크로스페이드 오버레이
                if _prev_phase_frame is not None and frame <= BLEND_FRAMES:
                    _ba = int(255 * (1.0 - frame / BLEND_FRAMES) ** 1.5)
                    if _ba > 3:
                        _pf = _prev_phase_frame.copy()
                        _pf.set_alpha(_ba)
                        self.screen.blit(_pf, (0, 0))
                    if frame >= BLEND_FRAMES:
                        _prev_phase_frame = None

                pygame.display.flip()
                if frame >= FRAMES[8]:
                    self._render_galaxy_map(cleared_planets, to_planet)
                    _prev_phase_frame = self.screen.copy()
                    phase = 9
                    frame = 0

            # ════════════════ Phase 9: 크로스페이드 전환 ════════════════
            elif phase == 9:
                t = frame / FRAMES[9]
                et = _ease_in_out(t)

                self.screen.fill((3, 3, 12))

                # 레이어 1: 착륙 장면 페이드아웃
                scene_a = max(0, int(255 * (1.0 - et * 2.0)))
                if scene_a > 5 and hasattr(self, '_landing_bg') and self._landing_bg:
                    bg_copy = self._landing_bg.copy()
                    bg_copy.set_alpha(scene_a)
                    self.screen.blit(bg_copy, (0, 0))

                # 우주 먼지 (맵 전환 중 분위기)
                self._draw_cosmic_dust(self.screen,
                                       0.15 * min(1.0, et * 2), self.time)

                # 레이어 2: 행성 전체 구체 (잠시 보였다 사라짐)
                planet_show_a = min(255, int(255 * min(et * 3, max(0, 2.5 - et * 2.5))))
                if planet_show_a > 5:
                    ti = to_planet - 1
                    if ti < len(self.planet_positions):
                        pcx, pcy = self.planet_positions[ti]
                    else:
                        pcx, pcy = self.W // 2, self.H // 2
                    pzoom = max(0.3, 1.0 - et * 0.7)
                    self._draw_dest_planet(
                        self.screen, pcx, pcy,
                        int(pr_big * pzoom), to_planet, planet_show_a)
                    # 행성 주변 빛줄기
                    if planet_show_a > 30:
                        gc = tcfg.get("glow_color", (200, 200, 200))
                        self._draw_god_rays(self.screen, pcx, pcy,
                                            0.1 * planet_show_a / 255, gc)

                # 레이어 3: 은하맵 페이드인
                map_a = min(255, int(255 * max(0, et * 2.0 - 0.5)))
                if map_a > 5:
                    mc = self.map_surface.copy()
                    mc.set_alpha(map_a)
                    self.screen.blit(mc, (0, 0))

                if map_a > 100:
                    # 제목 글로우
                    ts_g = self.font_big.render("은하계 항해", True,
                                                 (100, 120, 180))
                    ts_g.set_alpha(map_a // 3)
                    for gx, gy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                        self.screen.blit(ts_g, ts_g.get_rect(
                            center=(self.W // 2 + gx, 35 + gy)))
                    ts = self.font_big.render("은하계 항해", True,
                                              (200, 210, 240))
                    ts.set_alpha(map_a)
                    self.screen.blit(ts, ts.get_rect(
                        center=(self.W // 2, 35)))

                # 크로스페이드 오버레이
                if _prev_phase_frame is not None and frame <= BLEND_FRAMES:
                    _ba = int(255 * (1.0 - frame / BLEND_FRAMES) ** 1.5)
                    if _ba > 3:
                        _pf = _prev_phase_frame.copy()
                        _pf.set_alpha(_ba)
                        self.screen.blit(_pf, (0, 0))
                    if frame >= BLEND_FRAMES:
                        _prev_phase_frame = None

                pygame.display.flip()
                if frame >= FRAMES[9]:
                    break

        # 스킵 시 은하맵 한 프레임
        if skipped:
            self._render_galaxy_map(cleared_planets, to_planet)
            self.screen.blit(self.map_surface, (0, 0))
            ts = self.font_big.render("은하계 항해", True, (200, 210, 240))
            self.screen.blit(ts, ts.get_rect(center=(self.W // 2, 35)))
            pygame.display.flip()
            pygame.time.delay(300)

        # 캐시 정리
        if hasattr(self, '_landing_bg'):
            self._landing_bg = None

        pygame.event.clear()

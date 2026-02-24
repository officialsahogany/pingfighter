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
        2: '_draw_surface_jungle',
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
    #  조선시대 경기장 스타디움 (관중석 + 기와지붕 + 난간 + 기둥)
    # ──────────────────────────────────────────────────────────
    _joseon_stadium_cache = None   # (cache_key, surface)

    def _draw_joseon_arena_border(self, screen, ix, iy, ig_w, ig_h, arena_scale):
        """경기장 주변에 조선시대 스타디움을 그린다.
        관중석, 기와지붕, 나무 난간, 기둥, 깃발 포함."""
        if arena_scale < 0.08 or ig_w < 16 or ig_h < 16:
            return

        # 캐시 키 (10단계)
        cache_key = (int(arena_scale * 10), ig_w, ig_h)
        if self._joseon_stadium_cache and self._joseon_stadium_cache[0] == cache_key:
            cached_surf, cached_ox, cached_oy = self._joseon_stadium_cache[1]
            screen.blit(cached_surf, (cached_ox, cached_oy))
            return

        # ── 스타디움 치수 (경기장 대비 비율 — 컴팩트) ──
        stand_w = max(6, int(ig_w * 0.18))   # 좌/우 관중석 폭
        stand_top = max(6, int(ig_h * 0.15)) # 상단 관중석 높이
        stand_bot = max(6, int(ig_h * 0.13)) # 하단 관중석 높이
        rail_h = max(2, int(8 * arena_scale))   # 난간 높이
        roof_h = max(4, int(ig_h * 0.06))    # 기와지붕 높이
        pillar_w = max(3, int(12 * arena_scale))  # 기둥 폭

        # 전체 서피스 크기
        total_w = ig_w + stand_w * 2 + pillar_w * 2
        total_h = ig_h + stand_top + stand_bot + roof_h
        surf = pygame.Surface((total_w + 4, total_h + 4), pygame.SRCALPHA)

        # 서피스 내 경기장 로컬 좌표
        fx = pillar_w + stand_w + 2   # 경기장 좌측
        fy = roof_h + stand_top + 2    # 경기장 상단

        # ── 색상 팔레트 ──
        dk_wood = (55, 32, 18)
        md_wood = (92, 58, 30)
        lt_wood = (125, 82, 42)
        hi_wood = (158, 112, 58)
        stone_dk = (72, 68, 62)
        stone_md = (98, 92, 82)
        stone_lt = (118, 112, 100)
        cyan_wall = (65, 140, 155)
        cyan_dk = (48, 105, 118)
        seat_colors = [(95, 88, 78), (105, 98, 85), (88, 82, 72), (110, 102, 90)]
        banner_red = (175, 42, 35)
        banner_gold = (195, 155, 45)
        gold_hi = (225, 195, 85)
        dancheong = [(185, 45, 38), (38, 125, 60), (45, 70, 152), (200, 160, 45)]

        random.seed(7799)

        # ===== 1) 관중석 배경 (4면) =====
        # 상단 관중석
        pygame.draw.rect(surf, stone_dk,
                         (fx - stand_w, fy - stand_top, ig_w + stand_w * 2, stand_top))
        # 하단 관중석
        pygame.draw.rect(surf, stone_dk,
                         (fx - stand_w, fy + ig_h, ig_w + stand_w * 2, stand_bot))
        # 좌측 관중석
        pygame.draw.rect(surf, stone_dk,
                         (fx - stand_w, fy, stand_w, ig_h))
        # 우측 관중석
        pygame.draw.rect(surf, stone_dk,
                         (fx + ig_w, fy, stand_w, ig_h))

        # ===== 2) 관중석 계단식 줄 (row) + 관중 =====
        row_h = max(3, int(8 * arena_scale))

        def _draw_stand_rows(x, y, w, h, horizontal=True):
            """계단식 관중석 줄 그리기 + 관중 점"""
            num_rows = max(2, h // row_h)
            for ri in range(num_rows):
                ry = y + ri * (h // num_rows)
                rh = max(2, h // num_rows - 1)
                # 좌석 줄 배경 (번갈아 색상)
                sc = seat_colors[ri % len(seat_colors)]
                pygame.draw.rect(surf, sc, (x, ry, w, rh))
                # 줄 하단 그림자
                pygame.draw.line(surf, stone_dk, (x, ry + rh), (x + w, ry + rh), 1)
                # 관중 (작은 점들)
                if arena_scale > 0.15:
                    dot_step = max(2, int(4 / arena_scale))
                    for dx in range(2, w - 1, dot_step):
                        if random.random() < 0.7:  # 70% 좌석 점유
                            dy = random.randint(1, max(1, rh - 2))
                            # 머리 색상 (다양)
                            head_c = random.choice([
                                (45, 35, 28), (62, 48, 35), (38, 30, 22),
                                (180, 160, 140), (55, 42, 32), (72, 55, 38)])
                            dot_r = max(1, int(1.5 * arena_scale))
                            pygame.draw.circle(surf, head_c,
                                               (x + dx, ry + dy), dot_r)

        # 상단 관중석 줄
        _draw_stand_rows(fx - stand_w, fy - stand_top, ig_w + stand_w * 2, stand_top)
        # 하단 관중석 줄
        _draw_stand_rows(fx - stand_w, fy + ig_h, ig_w + stand_w * 2, stand_bot)
        # 좌측 관중석 줄
        _draw_stand_rows(fx - stand_w, fy, stand_w, ig_h)
        # 우측 관중석 줄
        _draw_stand_rows(fx + ig_w, fy, stand_w, ig_h)

        # ===== 3) 나무 난간 (경기장 바로 주변) =====
        # 상단 난간
        pygame.draw.rect(surf, dk_wood,
                         (fx - 2, fy - rail_h, ig_w + 4, rail_h))
        pygame.draw.rect(surf, md_wood,
                         (fx - 1, fy - rail_h + 1, ig_w + 2, rail_h - 2))
        # 난간 세로 살대
        if arena_scale > 0.2:
            bar_step = max(4, int(12 * arena_scale))
            for bx in range(fx, fx + ig_w, bar_step):
                pygame.draw.line(surf, lt_wood,
                                 (bx, fy - rail_h + 1), (bx, fy - 1), 1)
        # 하단 난간
        pygame.draw.rect(surf, dk_wood,
                         (fx - 2, fy + ig_h, ig_w + 4, rail_h))
        pygame.draw.rect(surf, md_wood,
                         (fx - 1, fy + ig_h + 1, ig_w + 2, rail_h - 2))
        if arena_scale > 0.2:
            for bx in range(fx, fx + ig_w, bar_step):
                pygame.draw.line(surf, lt_wood,
                                 (bx, fy + ig_h + 1), (bx, fy + ig_h + rail_h - 1), 1)
        # 좌측 난간
        pygame.draw.rect(surf, dk_wood,
                         (fx - rail_h - 2, fy - 2, rail_h, ig_h + 4))
        pygame.draw.rect(surf, md_wood,
                         (fx - rail_h - 1, fy - 1, rail_h - 2, ig_h + 2))
        # 우측 난간
        pygame.draw.rect(surf, dk_wood,
                         (fx + ig_w + 2, fy - 2, rail_h, ig_h + 4))
        pygame.draw.rect(surf, md_wood,
                         (fx + ig_w + 3, fy - 1, rail_h - 2, ig_h + 2))

        # 난간 상단 하이라이트
        pygame.draw.line(surf, hi_wood,
                         (fx - 2, fy - rail_h), (fx + ig_w + 2, fy - rail_h), 1)
        pygame.draw.line(surf, hi_wood,
                         (fx - 2, fy + ig_h + rail_h), (fx + ig_w + 2, fy + ig_h + rail_h), 1)

        # ===== 4) 시안색 담벼락 (난간 바로 바깥, 관중석 안쪽 경계) =====
        wall_h = max(2, int(6 * arena_scale))
        # 상단 벽
        pygame.draw.rect(surf, cyan_wall,
                         (fx - rail_h - 2, fy - rail_h - wall_h,
                          ig_w + rail_h * 2 + 4, wall_h))
        pygame.draw.line(surf, cyan_dk,
                         (fx - rail_h - 2, fy - rail_h - 1),
                         (fx + ig_w + rail_h + 2, fy - rail_h - 1), 1)
        # 하단 벽
        pygame.draw.rect(surf, cyan_wall,
                         (fx - rail_h - 2, fy + ig_h + rail_h,
                          ig_w + rail_h * 2 + 4, wall_h))

        # ===== 5) 기둥 (네 모서리) =====
        pl_h = stand_top + ig_h + stand_bot  # 기둥 전체 높이
        pl_y = fy - stand_top
        corners_x = [fx - stand_w - pillar_w, fx + ig_w + stand_w]
        for px in corners_x:
            # 기둥 본체
            pygame.draw.rect(surf, dk_wood,
                             (px, pl_y, pillar_w, pl_h))
            pygame.draw.rect(surf, md_wood,
                             (px + 1, pl_y + 1, pillar_w - 2, pl_h - 2))
            # 기둥 하이라이트 (왼쪽 면)
            pygame.draw.line(surf, lt_wood,
                             (px + 2, pl_y), (px + 2, pl_y + pl_h), 1)
            # 기둥 단청 띠 (위아래)
            if arena_scale > 0.2:
                for di, dc in enumerate(dancheong):
                    dh = max(1, int(3 * arena_scale))
                    # 상단 띠
                    pygame.draw.rect(surf, dc,
                                     (px + 1, pl_y + 2 + di * dh,
                                      pillar_w - 2, dh))
                    # 하단 띠
                    pygame.draw.rect(surf, dc,
                                     (px + 1, pl_y + pl_h - 2 - (di + 1) * dh,
                                      pillar_w - 2, dh))

        # ===== 6) 기와 지붕 (상단 전체) =====
        roof_y = fy - stand_top - roof_h
        roof_w = total_w
        tile_dk = (42, 38, 32)
        tile_md = (68, 60, 50)
        tile_lt = (92, 84, 72)

        # 지붕 배경
        pygame.draw.rect(surf, tile_dk, (2, roof_y, roof_w, roof_h))
        # 기와 골
        tw = max(4, int(10 * arena_scale))
        for tx in range(2, 2 + roof_w, tw):
            cw = min(tw, 2 + roof_w - tx)
            if cw < 2:
                break
            pygame.draw.rect(surf, tile_md,
                             (tx + 1, roof_y + 1, cw - 1, roof_h - 2))
            pygame.draw.line(surf, tile_lt,
                             (tx + 1, roof_y + 1), (tx + cw - 1, roof_y + 1), 1)
            pygame.draw.line(surf, tile_dk,
                             (tx, roof_y), (tx, roof_y + roof_h), 1)

        # 처마 선
        pygame.draw.line(surf, tile_lt,
                         (2, roof_y + roof_h - 1),
                         (2 + roof_w, roof_y + roof_h - 1), 1)

        # 추녀 (양 끝 올림)
        if arena_scale > 0.25:
            lift = max(3, int(8 * arena_scale))
            span = min(lift * 5, roof_w // 4)
            for ei in range(span):
                curve = int(lift * (1.0 - ei / span) ** 2)
                ey = roof_y + roof_h - 1 - curve
                pygame.draw.line(surf, tile_md,
                                 (2 + ei, ey), (2 + ei, ey + max(1, curve)), 1)
                pygame.draw.line(surf, tile_md,
                                 (2 + roof_w - 1 - ei, ey),
                                 (2 + roof_w - 1 - ei, ey + max(1, curve)), 1)

        # 지붕 위 용마루 (가운데 돌출)
        ridge_h = max(2, int(4 * arena_scale))
        ridge_w = max(20, roof_w // 3)
        rx = 2 + (roof_w - ridge_w) // 2
        pygame.draw.rect(surf, tile_dk, (rx, roof_y - ridge_h, ridge_w, ridge_h))
        pygame.draw.rect(surf, tile_md, (rx + 1, roof_y - ridge_h + 1,
                                          ridge_w - 2, ridge_h - 1))
        # 단청 장식 (용마루 아래)
        if arena_scale > 0.2:
            for di, dc in enumerate(dancheong):
                dh = max(1, int(2 * arena_scale))
                dy = roof_y - 1 - (di + 1) * dh
                pygame.draw.rect(surf, dc,
                                 (rx + 2, dy, ridge_w - 4, dh))

        # ===== 7) 현수막/깃발 (관중석 위) =====
        if arena_scale > 0.2:
            banner_w = max(6, int(20 * arena_scale))
            banner_h_px = max(4, int(12 * arena_scale))
            # 상단 관중석에 깃발들
            for bi in range(3, ig_w + stand_w * 2 - banner_w, max(banner_w * 3, 20)):
                bx = fx - stand_w + bi
                by = fy - stand_top + max(2, int(4 * arena_scale))
                bc = random.choice([banner_red, (38, 85, 145), (145, 42, 95),
                                    (42, 120, 55), banner_gold])
                pygame.draw.rect(surf, bc, (bx, by, banner_w, banner_h_px))
                pygame.draw.rect(surf, (min(255, bc[0] + 40),
                                         min(255, bc[1] + 40),
                                         min(255, bc[2] + 40)),
                                 (bx + 1, by + 1, banner_w - 2, banner_h_px - 2), 1)

        # ===== 8) 조명탑 (기둥 위 상단 양 끝) =====
        if arena_scale > 0.2:
            lamp_r = max(2, int(5 * arena_scale))
            for px in corners_x:
                lx = px + pillar_w // 2
                ly = pl_y - lamp_r
                # 등불 불빛 글로우
                glow_r = lamp_r * 3
                glow_s = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
                for gi in range(glow_r, 0, -1):
                    ga = max(1, int(40 * gi / glow_r))
                    pygame.draw.circle(glow_s, (255, 200, 80, ga),
                                       (glow_r, glow_r), gi)
                surf.blit(glow_s, (lx - glow_r, ly - glow_r))
                # 등불 본체
                pygame.draw.circle(surf, (255, 220, 120), (lx, ly), lamp_r)
                pygame.draw.circle(surf, (255, 240, 180), (lx, ly), max(1, lamp_r - 1))

        # ===== 9) 경기장 가장자리 금선 =====
        pygame.draw.rect(surf, (*banner_gold, 200),
                         (fx - 1, fy - 1, ig_w + 2, ig_h + 2), 1)

        random.seed()

        # ── 최종 블릿 & 캐시 ──
        blit_x = ix - (fx - 2)
        blit_y = iy - (fy - 2)
        self.__class__._joseon_stadium_cache = (cache_key, (surf, blit_x, blit_y))
        screen.blit(surf, (blit_x, blit_y))

    def _draw_surface_jungle(self, surf, t, alpha=255):
        """정글/늪지 행성 표면 — 고퀄리티. Stage 2 악어장군 테마.
        t: 0(고공) ~ 1(지표면)."""
        W, H = surf.get_width(), surf.get_height()
        # 경기장 중앙 회피
        _cz_x, _cz_y = W // 2, H // 2
        _cz_hw, _cz_hh = 150, 120

        def _in_center(px, py):
            return abs(px - _cz_x) < _cz_hw and abs(py - _cz_y) < _cz_hh

        # ===== 기본 지형 — 어두운 정글/습지 그라디언트 =====
        sky_blend = max(0.0, 1.0 - t * 3)
        for row in range(0, H, 3):
            fy = row / H
            # 매우 어두운 녹색~갈색 습지 (스크린샷 톤 기반)
            gr = int((18 + fy * 20) * (1 - sky_blend) + (50 + fy * 30) * sky_blend)
            gg = int((35 + fy * 28) * (1 - sky_blend) + (90 + fy * 30) * sky_blend)
            gb = int((15 + fy * 12) * (1 - sky_blend) + (55 + fy * 25) * sky_blend)
            pygame.draw.rect(surf, (min(255, gr), min(255, gg), min(255, gb), alpha),
                             (0, row, W, 4))

        random.seed(2137)

        # ===== 습지/늪 패치 (매우 어두운 물웅덩이) =====
        for _ in range(40):
            px = random.randint(-60, W + 60)
            py = random.randint(-60, H + 60)
            pr = random.randint(30, 150)
            g = random.randint(15, 55)
            c = (max(0, g - 12 + random.randint(-8, 8)),
                 max(0, g + 10 + random.randint(-8, 8)),
                 max(0, g - 15 + random.randint(-6, 6)))
            ps = pygame.Surface((pr * 2, pr * 2), pygame.SRCALPHA)
            for li in range(pr, max(1, pr // 3), -max(1, pr // 6)):
                la = max(1, int(50 * alpha / 255 * li / pr))
                pygame.draw.circle(ps, (*c, la), (pr, pr), li)
            surf.blit(ps, (px - pr, py - pr))

        # ===== 늪지/강 (넓은 사행천 — 진한 녹갈색) =====
        for river_i in range(2):
            pts_r = []
            y_base = H // 5 + river_i * H * 2 // 5
            amp = 80 + river_i * 40
            for step in range(50):
                st = step / 49
                sx = int(W * st)
                sy = y_base + int(amp * math.sin(st * math.pi * 2.0 + river_i * 1.5))
                pts_r.append((sx, sy))
            if len(pts_r) > 2:
                # 강둑 (진흙)
                pts_bank_l = [(p[0], p[1] + 6) for p in pts_r]
                pts_bank_r = [(p[0], p[1] - 6) for p in pts_r]
                pygame.draw.lines(surf, (55, 45, 25), False, pts_bank_l, 3)
                pygame.draw.lines(surf, (60, 50, 30), False, pts_bank_r, 3)
                # 넓은 물 (탁한 녹색)
                pygame.draw.lines(surf, (35, 65, 45), False, pts_r, 10)
                # 중간 물 (약간 밝게)
                pygame.draw.lines(surf, (45, 80, 55), False, pts_r, 6)
                # 수면 반사 (밝은 줄)
                pts_hl = [(p[0], p[1] - 2) for p in pts_r]
                pygame.draw.lines(surf, (65, 100, 70), False, pts_hl, 1)
                # 수련/부유물
                for si in range(4, len(pts_r) - 4, 5):
                    wx, wy = pts_r[si]
                    lr = random.randint(3, 6)
                    # 수련 잎 (타원)
                    pygame.draw.ellipse(surf, (30, 90, 40),
                                        (wx - lr, wy - lr // 2, lr * 2, lr))
                    pygame.draw.ellipse(surf, (50, 120, 55),
                                        (wx - lr + 1, wy - lr // 2, lr * 2 - 2, lr - 1))
                    # 작은 꽃
                    if random.random() > 0.5:
                        pygame.draw.circle(surf, (255, 255, 220), (wx, wy), 2)
                        pygame.draw.circle(surf, (255, 200, 100), (wx, wy), 1)

        # ===== 열대 나무 원경 (밀림 실루엣 — 화면 상단) =====
        for _ in range(12):
            tx = random.randint(-40, W + 40)
            ty = random.randint(-30, H // 4)
            tw = random.randint(15, 40)
            th = random.randint(30, 80)
            g_v = random.randint(20, 45)
            tc = (g_v, g_v + 30 + random.randint(0, 20), g_v - 5)
            # 줄기
            pygame.draw.line(surf, (50, 35, 20), (tx, ty), (tx, ty + th), 3)
            # 큰 수관 (원형 뭉치)
            for ci in range(random.randint(3, 6)):
                cx_c = tx + random.randint(-tw, tw)
                cy_c = ty + random.randint(-tw // 2, tw // 3)
                cr = random.randint(10, 25)
                cs = pygame.Surface((cr * 2, cr * 2), pygame.SRCALPHA)
                for ri in range(cr, 0, -1):
                    ra = max(1, int(100 * ri / cr * alpha / 255))
                    pygame.draw.circle(cs, (*tc, ra), (cr, cr), ri)
                surf.blit(cs, (cx_c - cr, cy_c - cr))

        # ===== 정글 나무 중경 (디테일 — 중앙 회피) =====
        for _ in range(22):
            tx = random.randint(15, W - 15)
            ty = random.randint(H // 6, H - 30)
            if _in_center(tx, ty):
                continue
            th = random.randint(20, 55)
            tw = random.randint(12, 28)
            # 나무 그림자
            sh_s = pygame.Surface((tw + 4, 5), pygame.SRCALPHA)
            pygame.draw.ellipse(sh_s, (0, 0, 0, 25), (0, 0, tw + 4, 5))
            surf.blit(sh_s, (tx - tw // 2 - 2, ty + th))
            # 줄기 (갈색 + 이끼)
            pygame.draw.line(surf, (55, 38, 18), (tx + 1, ty), (tx + 1, ty + th), 4)
            pygame.draw.line(surf, (75, 55, 30), (tx, ty), (tx, ty + th), 2)
            # 이끼 (줄기 위 녹색 점)
            for mi in range(0, th, max(5, th // 4)):
                pygame.draw.circle(surf, (40, 80, 35), (tx - 1, ty + mi), 1)
            # 수관 (다층 원형 — 열대림 느낌)
            for ci in range(random.randint(4, 8)):
                cx_c = tx + random.randint(-tw, tw)
                cy_c = ty + random.randint(-tw, 0)
                cr = random.randint(6, 16)
                g_v = 30 + random.randint(0, 40)
                cs = pygame.Surface((cr * 2 + 2, cr * 2 + 2), pygame.SRCALPHA)
                for ri in range(cr, 0, -1):
                    ra = max(1, int(70 * ri / cr))
                    pygame.draw.circle(cs, (g_v, g_v + 40, g_v - 10, ra),
                                       (cr + 1, cr + 1), ri)
                surf.blit(cs, (cx_c - cr - 1, cy_c - cr - 1))
            # 덩굴 (줄기에서 아래로)
            for _ in range(random.randint(1, 3)):
                vx = tx + random.randint(-tw // 2, tw // 2)
                vy = ty + random.randint(0, tw // 2)
                vl = random.randint(8, 20)
                pts_v = [(vx, vy)]
                for vi in range(1, 5):
                    pts_v.append((vx + random.randint(-3, 3),
                                  vy + vi * vl // 4))
                if len(pts_v) > 2:
                    pygame.draw.lines(surf, (35, 75, 30), False, pts_v, 1)

        # ===== 야자수 (키 큰 열대 나무 — 중앙 회피) =====
        detail_a = min(255, int(255 * max(0, t * 2 - 0.2)))
        if detail_a > 10:
            for _ in range(10):
                px = random.randint(30, W - 30)
                py = random.randint(H // 4, H - 50)
                if _in_center(px, py):
                    continue
                p_h = random.randint(30, 65)
                # 곡선 줄기
                trunk_pts = [(px, py + p_h)]
                sway = random.randint(-15, 15)
                for ti in range(5):
                    frac = ti / 4.0
                    tx_t = px + int(sway * frac * frac)
                    ty_t = py + int(p_h * (1.0 - frac))
                    trunk_pts.append((tx_t, ty_t))
                if len(trunk_pts) > 2:
                    pygame.draw.lines(surf, (90, 65, 35), False, trunk_pts, 3)
                    pygame.draw.lines(surf, (115, 85, 45), False, trunk_pts, 1)
                # 야자 잎 (방사형)
                top_x = trunk_pts[-1][0]
                top_y = trunk_pts[-1][1]
                for li in range(random.randint(5, 8)):
                    angle = math.pi * 2 * li / 7 + random.uniform(-0.3, 0.3)
                    leaf_l = random.randint(15, 30)
                    ex = top_x + int(leaf_l * math.cos(angle))
                    ey = top_y + int(leaf_l * math.sin(angle) * 0.5) - 5
                    mid_x = (top_x + ex) // 2
                    mid_y = (top_y + ey) // 2 - random.randint(2, 6)
                    pygame.draw.line(surf, (30, 80, 25), (top_x, top_y),
                                     (mid_x, mid_y), 2)
                    pygame.draw.line(surf, (30, 80, 25), (mid_x, mid_y),
                                     (ex, ey), 1)
                    # 잎 살 (좌우)
                    for si in range(3):
                        sf = (si + 1) / 4.0
                        sx_l = int(top_x + (ex - top_x) * sf)
                        sy_l = int(top_y + (ey - top_y) * sf)
                        perp = angle + math.pi / 2
                        fl = random.randint(3, 7)
                        for side in [-1, 1]:
                            fx = sx_l + int(fl * math.cos(perp) * side)
                            fy = sy_l + int(fl * math.sin(perp) * side * 0.5)
                            pygame.draw.line(surf, (40, 95, 30),
                                             (sx_l, sy_l), (fx, fy), 1)
                # 코코넛
                for _ in range(random.randint(0, 3)):
                    cx_n = top_x + random.randint(-4, 4)
                    cy_n = top_y + random.randint(0, 4)
                    pygame.draw.circle(surf, (100, 75, 40), (cx_n, cy_n), 2)
                    pygame.draw.circle(surf, (120, 95, 55), (cx_n, cy_n - 1), 1)

        # ===== 오두막/원주민 건축물 (중앙 회피) =====
        for _ in range(6):
            bx = random.randint(60, W - 60)
            by = random.randint(H // 3, H * 3 // 4)
            if _in_center(bx, by):
                continue
            bw = random.randint(25, 55)
            bh = random.randint(15, 30)
            # 그림자
            sh_s = pygame.Surface((bw + 10, 5), pygame.SRCALPHA)
            pygame.draw.ellipse(sh_s, (0, 0, 0, 30), (0, 0, bw + 10, 5))
            surf.blit(sh_s, (bx - bw // 2 - 5, by + bh + 3))
            # 기둥 (나무)
            for col_off in [-bw // 2 + 3, bw // 2 - 3]:
                pygame.draw.line(surf, (70, 50, 25),
                                 (bx + col_off, by + 3), (bx + col_off, by + bh + 2), 2)
            # 벽체 (대나무/짚)
            pygame.draw.rect(surf, (110, 90, 55), (bx - bw // 2, by, bw, bh))
            # 대나무 세로줄 텍스처
            for bi in range(bx - bw // 2 + 3, bx + bw // 2, max(4, bw // 7)):
                pygame.draw.line(surf, (90, 72, 40), (bi, by + 2), (bi, by + bh - 1), 1)
            # 초가지붕 (삼각형 — 풀/짚)
            rw = bw + 12
            rh = max(8, bh * 2 // 3)
            roof_pts = [(bx, by - rh),
                        (bx - rw // 2, by + 2),
                        (bx + rw // 2, by + 2)]
            pygame.draw.polygon(surf, (90, 80, 40), roof_pts)
            # 지붕 질감 (수평 짚 줄)
            for ri in range(by - rh + 3, by + 1, max(2, rh // 5)):
                frac = (ri - (by - rh)) / rh
                hw = int(rw * frac // 2)
                pygame.draw.line(surf, (75, 68, 35),
                                 (bx - hw, ri), (bx + hw, ri), 1)
            # 지붕 밝은 면 (왼쪽)
            hl_pts = [roof_pts[0], roof_pts[1], (bx, by + 1)]
            hl_s = pygame.Surface((rw, rh + 2), pygame.SRCALPHA)
            hl_pts_local = [(p[0] - bx + rw // 2, p[1] - by + rh) for p in hl_pts]
            if all(0 <= p[0] <= rw and 0 <= p[1] <= rh + 2 for p in hl_pts_local):
                pygame.draw.polygon(hl_s, (110, 100, 55, 40), hl_pts_local)
                surf.blit(hl_s, (bx - rw // 2, by - rh))
            # 문 (어두운 사각형)
            dw = max(4, bw // 5)
            dh = max(5, bh * 2 // 3)
            pygame.draw.rect(surf, (40, 30, 15),
                             (bx - dw // 2, by + bh - dh, dw, dh))

        # ===== 버섯/식물 디테일 (중앙 회피) =====
        for _ in range(20):
            mx = random.randint(10, W - 10)
            my = random.randint(H // 4, H - 15)
            if _in_center(mx, my):
                continue
            mtype = random.randint(0, 2)
            if mtype == 0:
                # 큰 버섯
                mr = random.randint(4, 9)
                # 줄기
                pygame.draw.line(surf, (190, 180, 160), (mx, my), (mx, my + mr + 2), 2)
                # 갓
                pygame.draw.ellipse(surf, (180, 50 + random.randint(0, 60), 30),
                                    (mx - mr, my - mr // 2, mr * 2, mr))
                # 점
                for _ in range(random.randint(2, 4)):
                    dx = random.randint(-mr + 2, mr - 2)
                    dy = random.randint(-mr // 2 + 1, mr // 2 - 1)
                    pygame.draw.circle(surf, (255, 255, 230), (mx + dx, my + dy), 1)
            elif mtype == 1:
                # 양치류 (부채꼴 잎)
                for fi in range(random.randint(4, 7)):
                    angle = -math.pi / 2 + (fi - 3) * 0.25
                    fl = random.randint(8, 18)
                    fx = mx + int(fl * math.cos(angle))
                    fy = my + int(fl * math.sin(angle))
                    pygame.draw.line(surf, (35, 85, 30), (mx, my), (fx, fy), 1)
                    # 잎맥
                    for si in range(2, fl, 3):
                        sf = si / fl
                        sx = int(mx + (fx - mx) * sf)
                        sy = int(my + (fy - my) * sf)
                        perp = angle + math.pi / 2
                        for side in [-1, 1]:
                            lx = sx + int(3 * math.cos(perp) * side)
                            ly = sy + int(3 * math.sin(perp) * side)
                            pygame.draw.line(surf, (45, 100, 35),
                                             (sx, sy), (lx, ly), 1)
            else:
                # 꽃/열매 (밝은 점)
                fc = random.choice([(255, 100, 80), (255, 200, 50),
                                    (220, 80, 200), (255, 150, 50)])
                pygame.draw.circle(surf, fc, (mx, my), random.randint(2, 4))
                pygame.draw.circle(surf, (255, 255, 255), (mx, my - 1), 1)

        # ===== 바위/돌 (습지, 중앙 회피) =====
        for _ in range(12):
            rx = random.randint(15, W - 15)
            ry = random.randint(H // 4, H - 20)
            if _in_center(rx, ry):
                continue
            rw = random.randint(4, 14)
            rh = random.randint(3, 9)
            # 이끼 낀 바위
            pygame.draw.ellipse(surf, (55, 52, 45), (rx, ry, rw, rh))
            pygame.draw.ellipse(surf, (70, 68, 58), (rx + 1, ry, rw - 2, rh - 1))
            # 이끼
            pygame.draw.ellipse(surf, (45, 75, 40, 80),
                                (rx + 1, ry + 1, rw - 3, rh // 2))

        random.seed()

        # ===== 안개/습기 레이어 =====
        mist_a = max(0, int(100 * (1.0 - t * 1.8) * alpha / 255))
        if mist_a > 3:
            random.seed(3030)
            for _ in range(18):
                mx = random.randint(-60, W + 60)
                my = random.randint(-30, H + 30)
                mw = random.randint(80, 250)
                mh = random.randint(20, 60)
                ms = pygame.Surface((mw, mh), pygame.SRCALPHA)
                # 습기 안개 (황록색)
                for ci in range(5):
                    co = ci * 3
                    ca = max(1, int(mist_a * (1.0 - ci * 0.18)))
                    if mw - co * 2 > 4 and mh - co * 2 > 4:
                        pygame.draw.ellipse(
                            ms, (180, 200, 170, min(255, ca)),
                            (co, co, mw - co * 2, mh - co * 2))
                surf.blit(ms, (mx - mw // 2, my - mh // 2))
            random.seed()

        # ===== 구름 (열대성 적운 — 두꺼운 회색빛) =====
        cloud_a = max(0, int(180 * (1.0 - t * 2.2) * alpha / 255))
        if cloud_a > 3:
            random.seed(4040)
            for _ in range(20):
                cx_c = random.randint(-60, W + 60)
                cy_c = random.randint(-30, H + 30)
                cw_c = random.randint(80, 260)
                ch_c = random.randint(25, 70)
                cs = pygame.Surface((cw_c, ch_c), pygame.SRCALPHA)
                for ci in range(5):
                    co = ci * 3
                    ca = max(1, int(cloud_a * (1.0 - ci * 0.15)))
                    if cw_c - co * 2 > 4 and ch_c - co * 2 > 4:
                        pygame.draw.ellipse(
                            cs, (230, 235, 225, min(255, ca)),
                            (co, co, cw_c - co * 2, ch_c - co * 2))
                # 구름 하단 어두운 (비구름 느낌)
                bot_h = max(3, ch_c // 3)
                pygame.draw.ellipse(cs, (160, 170, 155, max(1, cloud_a // 4)),
                                    (5, ch_c - bot_h, cw_c - 10, bot_h))
                surf.blit(cs, (cx_c - cw_c // 2, cy_c - ch_c // 2))
            random.seed()

        # ===== 대기 오버레이 (습한 공기 — 고도 높을 때) =====
        haze_a = max(0, int(70 * (1.0 - t * 2.5) * alpha / 255))
        if haze_a > 2:
            haze = pygame.Surface((W, H), pygame.SRCALPHA)
            haze.fill((140, 170, 130, haze_a))
            surf.blit(haze, (0, 0))

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
                    # 인게임 화면 크기 (점점 커짐)
                    ig_w = int(self.W * arena_scale)
                    ig_h = int(self.H * arena_scale)
                    if ig_w > 4 and ig_h > 4:
                        # ── 스타디움: 고정 크기 (화면의 55%) 먼저 그리기 ──
                        if to_planet == 1:
                            stad_scale = 0.55
                            stad_w = int(self.W * stad_scale)
                            stad_h = int(self.H * stad_scale)
                            stad_ix = (self.W - stad_w) // 2
                            stad_iy = (self.H - stad_h) // 2
                            self._draw_joseon_arena_border(
                                self.screen, stad_ix, stad_iy,
                                stad_w, stad_h, stad_scale)

                        # ── 인게임 화면: 위에 덮어서 점점 커짐 ──
                        scaled_ig = pygame.transform.smoothscale(
                            ingame_frame, (ig_w, ig_h))
                        ix = (self.W - ig_w) // 2
                        iy = (self.H - ig_h) // 2
                        self.screen.blit(scaled_ig, (ix, iy))
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

        # 스테이지 2부터는 Phase 1,2 생략 → Phase 3부터 시작
        if to_planet > 1:
            phase = 3
            # Phase 3 시작 시 필요한 별/성운 초기화
            for layer in [self.stars_dust, self.stars_far, self.stars_mid,
                          self.stars_near, self.stars_front]:
                self._update_stars(layer, 1.0)
            self._update_nebulae(1.0)
        else:
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

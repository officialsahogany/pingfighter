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
        frame = (20, 35, 50, 200)
        border = (60, 130, 180, 180)
        accent = (80, 200, 255, 120)

        # 하단 콘솔 패널
        pts_b = [(0, H), (0, H - 120), (60, H - 140),
                 (W // 2 - 120, H - 100), (W // 2, H - 80),
                 (W // 2 + 120, H - 100), (W - 60, H - 140),
                 (W, H - 120), (W, H)]
        pygame.draw.polygon(surf, frame, pts_b)
        pygame.draw.lines(surf, border, False, pts_b[1:-1], 2)

        # 상단 패널
        pts_t = [(0, 0), (0, 70), (100, 55), (W // 2, 40),
                 (W - 100, 55), (W, 70), (W, 0)]
        pygame.draw.polygon(surf, frame, pts_t)
        pygame.draw.lines(surf, border, False, pts_t[1:-1], 2)

        # 좌우 프레임
        for sx in [0, W - 40]:
            pygame.draw.rect(surf, (15, 25, 40, 180), (sx, 70, 40, H - 190))
            bx = sx + (39 if sx == 0 else 0)
            pygame.draw.line(surf, border, (bx, 70), (bx, H - 120), 1)

        # HUD 장식 — 좌측 바
        for i in range(5):
            pygame.draw.rect(surf, accent, (8, 90 + i * 18, 25 - i * 3, 3))

        # 우상단 스캐너
        cx, cy = W - 22, 110
        pygame.draw.circle(surf, accent, (cx, cy), 15, 1)
        pygame.draw.line(surf, accent, (cx - 10, cy), (cx + 10, cy), 1)
        pygame.draw.line(surf, accent, (cx, cy - 10), (cx, cy + 10), 1)

        # 하단 콘솔 버튼
        for i in range(8):
            bx = W // 2 - 80 + i * 22
            pygame.draw.rect(surf, (30, 70, 100, 100),
                             (bx, H - 50, 16, 8), border_radius=2)

        # 조준 십자
        cx, cy = W // 2, H // 2
        cc = (80, 200, 255, 60)
        pygame.draw.line(surf, cc, (cx - 30, cy), (cx - 10, cy), 1)
        pygame.draw.line(surf, cc, (cx + 10, cy), (cx + 30, cy), 1)
        pygame.draw.line(surf, cc, (cx, cy - 30), (cx, cy - 10), 1)
        pygame.draw.line(surf, cc, (cx, cy + 10), (cx, cy + 30), 1)
        pygame.draw.circle(surf, (60, 150, 220, 40), (cx, cy), 20, 1)

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
            col = (_clamp(s.color[0] * b / 255),
                   _clamp(s.color[1] * b / 255),
                   _clamp(s.color[2] * b / 255))
            # 트레일
            if dr > 0.1:
                td = max(0, s.dist - s.speed * 0.02 * s.trail_len)
                tx = cx + math.cos(s.angle) * td
                ty = cy + math.sin(s.angle) * td
                pygame.draw.line(surf, col, (int(tx), int(ty)),
                                 (int(x), int(y)), max(1, sz - 1))
            pygame.draw.circle(surf, col, (int(x), int(y)), sz)

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
            r = _clamp(s.color[0] * b / 255)
            g = _clamp(s.color[1] * b / 255)
            bl = _clamp(s.color[2] * b / 255)
            ix, iy = int(s.x), int(s.y)
            if not (0 <= ix < self.W and 0 <= iy < self.H):
                continue
            col = (r, g, bl)
            if s.size <= 1:
                surf.set_at((ix, iy), col)
            else:
                pygame.draw.circle(surf, col, (ix, iy), s.size)
                # 큰 별 십자 글로우
                if s.size >= 3 and b > 150:
                    gl = s.size + 2
                    pygame.draw.line(surf, col, (ix - gl, iy), (ix + gl, iy), 1)
                    pygame.draw.line(surf, col, (ix, iy - gl), (ix, iy + gl), 1)

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

        # 엔진 후광 (SRCALPHA 서피스)
        if engine_power > 0.1:
            gr = int(20 * s * engine_power)
            gs = pygame.Surface((gr * 2 + 4, gr * 2 + 4), pygame.SRCALPHA)
            for rr in range(gr, 0, -2):
                a = max(1, int(25 * engine_power * rr / gr))
                pygame.draw.circle(gs, (100, 150, 255, a),
                                   (gr + 2, gr + 2), rr)
            surf.blit(gs, (ix - int(15 * s) - gr - 2, iy - gr - 2))

        # 엔진 불꽃 (멀티 레이어)
        if engine_power > 0.1:
            for fi in range(3):
                fl = random.randint(10, max(11, int(30 * engine_power)))
                fy = iy + random.randint(-2, 2) + (fi - 1) * int(4 * s)
                pygame.draw.line(surf, (200, 220, 255),
                                 (ix - int(12 * s), fy),
                                 (ix - int((12 + fl * 0.3) * s), fy),
                                 max(1, int(2 * s)))
                pygame.draw.line(surf, (255, 180, 50),
                                 (ix - int(12 * s), fy),
                                 (ix - int((12 + fl * 0.7) * s), fy),
                                 max(1, int(3 * s)))
                pygame.draw.line(surf, (255, 80, 20),
                                 (ix - int(14 * s), fy),
                                 (ix - int((14 + fl) * s),
                                  fy + random.randint(-2, 2)),
                                 max(1, int(1 * s)))

        # 주 선체
        body = [
            (ix + int(25 * s), iy),
            (ix + int(15 * s), iy - int(5 * s)),
            (ix - int(5 * s), iy - int(8 * s)),
            (ix - int(12 * s), iy - int(6 * s)),
            (ix - int(12 * s), iy + int(6 * s)),
            (ix - int(5 * s), iy + int(8 * s)),
            (ix + int(15 * s), iy + int(5 * s)),
        ]
        pygame.draw.polygon(surf, (180, 195, 220), body)
        # 하이라이트
        hl = [
            (ix + int(22 * s), iy - int(1 * s)),
            (ix + int(12 * s), iy - int(4 * s)),
            (ix - int(3 * s), iy - int(6 * s)),
            (ix - int(3 * s), iy - int(2 * s)),
            (ix + int(12 * s), iy - int(1 * s)),
        ]
        pygame.draw.polygon(surf, (210, 225, 245), hl)

        # 상단 윙
        wt = [(ix - int(2 * s), iy - int(8 * s)),
              (ix - int(8 * s), iy - int(18 * s)),
              (ix - int(14 * s), iy - int(16 * s)),
              (ix - int(12 * s), iy - int(8 * s))]
        pygame.draw.polygon(surf, (120, 140, 180), wt)
        pygame.draw.polygon(surf, (150, 170, 210), wt, 1)
        pygame.draw.circle(surf, (255, 50, 50),
                           (ix - int(10 * s), iy - int(17 * s)),
                           max(1, int(2 * s)))

        # 하단 윙
        wb = [(ix - int(2 * s), iy + int(8 * s)),
              (ix - int(8 * s), iy + int(18 * s)),
              (ix - int(14 * s), iy + int(16 * s)),
              (ix - int(12 * s), iy + int(8 * s))]
        pygame.draw.polygon(surf, (120, 140, 180), wb)
        pygame.draw.polygon(surf, (150, 170, 210), wb, 1)
        pygame.draw.circle(surf, (50, 255, 50),
                           (ix - int(10 * s), iy + int(17 * s)),
                           max(1, int(2 * s)))

        # 콕핏 캐노피
        cp = [(ix + int(20 * s), iy),
              (ix + int(12 * s), iy - int(3 * s)),
              (ix + int(6 * s), iy - int(2 * s)),
              (ix + int(6 * s), iy + int(2 * s)),
              (ix + int(12 * s), iy + int(3 * s))]
        pygame.draw.polygon(surf, (80, 180, 255), cp)
        pygame.draw.line(surf, (160, 220, 255),
                         (ix + int(18 * s), iy - int(1 * s)),
                         (ix + int(10 * s), iy - int(2 * s)), 1)

        # 외곽선
        pygame.draw.polygon(surf, (100, 120, 160), body, 1)

        # 실드 글로우 (SRCALPHA 서피스)
        sr = int(22 * s)
        sa = _clamp(15 + 10 * math.sin(self.time * 3))
        ss = pygame.Surface((sr * 2 + 4, sr * 2 + 4), pygame.SRCALPHA)
        pygame.draw.circle(ss, (80, 180, 255, sa),
                           (sr + 2, sr + 2), sr, 1)
        surf.blit(ss, (ix + int(5 * s) - sr - 2, iy - sr - 2))

        # 엔진 파티클 스폰
        if engine_power > 0.3:
            self._spawn_engine_particles(ix - int(14 * s), iy,
                                         max(1, int(3 * engine_power)))

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

    # ── 행성 1: 조선시대 (기와/문양/황금빛 대기) ──
    def _draw_planet_joseon(self, surf, cx, cy, r, alpha=255):
        glow = (255, 200, 80)
        base = (180, 120, 50)
        self._draw_atmo_glow(surf, cx, cy, r, glow, alpha)
        # 본체 (따뜻한 황토)
        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 15:
            random.seed(1137)
            # 산맥 능선 (짙은 녹색/갈색 대륙)
            for _ in range(4):
                ang = random.uniform(0, math.pi * 2)
                d = random.uniform(r * 0.15, r * 0.55)
                cr = random.randint(max(3, r // 7), max(5, r // 4))
                land = (120 + random.randint(-20, 20),
                        100 + random.randint(-15, 15),
                        40 + random.randint(-10, 10))
                px = cx + int(d * math.cos(ang))
                py = cy + int(d * math.sin(ang))
                pygame.draw.circle(surf, land, (px, py), cr)
            # 기와 문양 패턴 (가로 곡선 줄)
            for by in range(-r + 8, r, max(4, r // 5)):
                bw = int(math.sqrt(max(0, r * r - by * by)))
                if bw < 4:
                    continue
                wave_amp = max(1, r // 15)
                pts = []
                for sx in range(-bw, bw + 1, max(3, bw // 8)):
                    wy = by + int(wave_amp * math.sin(sx * 0.15))
                    pts.append((cx + sx, cy + wy))
                if len(pts) > 1:
                    pygame.draw.lines(surf, (150, 95, 35, 40), False, pts, 1)
            # 태극 문양 (중앙 장식)
            if r > 35:
                tr = max(4, r // 6)
                pygame.draw.circle(surf, (200, 50, 50), (cx, cy - 1), tr)
                pygame.draw.circle(surf, (40, 70, 160), (cx, cy + 1), tr)
                pygame.draw.circle(surf, (200, 50, 50),
                                   (cx - tr // 2, cy - tr // 3), tr // 2)
                pygame.draw.circle(surf, (40, 70, 160),
                                   (cx + tr // 2, cy + tr // 3), tr // 2)
            random.seed()
        self._draw_highlight(surf, cx, cy, r, base, alpha)
        # 황금빛 대기 경계
        pygame.draw.circle(surf, (255, 210, 120), (cx, cy), r + 1, 1)

    # ── 행성 2: 정글 (밀림/늪/생물 문양) ──
    def _draw_planet_jungle(self, surf, cx, cy, r, alpha=255):
        glow = (100, 200, 80)
        base = (60, 130, 55)
        self._draw_atmo_glow(surf, cx, cy, r, glow, alpha)
        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 15:
            random.seed(2137)
            # 늪지/강 (어두운 녹색 곡선)
            for _ in range(3):
                start_a = random.uniform(0, math.pi * 2)
                pts = []
                for step in range(8):
                    t = step / 7
                    ang = start_a + t * math.pi * 0.8
                    d = r * (0.2 + t * 0.5)
                    px = cx + int(d * math.cos(ang))
                    py = cy + int(d * math.sin(ang))
                    pts.append((px, py))
                if len(pts) > 1:
                    pygame.draw.lines(surf, (30, 80, 40), False, pts,
                                      max(1, r // 15))
            # 초목 클러스터 (밝은 초록 원)
            for _ in range(6):
                ang = random.uniform(0, math.pi * 2)
                d = random.uniform(0, r * 0.7)
                cr = random.randint(max(2, r // 10), max(4, r // 6))
                green = (40 + random.randint(0, 60),
                         130 + random.randint(0, 60),
                         30 + random.randint(0, 30))
                px = cx + int(d * math.cos(ang))
                py = cy + int(d * math.sin(ang))
                pygame.draw.circle(surf, green, (px, py), cr)
            # 악어 비늘 패턴 (다이아몬드 격자)
            if r > 30:
                step = max(5, r // 5)
                for gx in range(-r, r, step):
                    for gy in range(-r, r, step):
                        if gx * gx + gy * gy > r * r * 0.7:
                            continue
                        pts = [(cx + gx, cy + gy - step // 3),
                               (cx + gx + step // 3, cy + gy),
                               (cx + gx, cy + gy + step // 3),
                               (cx + gx - step // 3, cy + gy)]
                        pygame.draw.polygon(surf, (50, 110, 45, 25), pts, 1)
            random.seed()
        self._draw_highlight(surf, cx, cy, r, base, alpha)
        self._draw_ring(surf, cx, cy, r, (80, 160, 70), alpha)
        pygame.draw.circle(surf, (80, 180, 60), (cx, cy), r + 1, 1)

    # ── 행성 3: 멘헤라 (핑크/하트/균열) ──
    def _draw_planet_menhera(self, surf, cx, cy, r, alpha=255):
        glow = (255, 120, 220)
        base = (180, 70, 150)
        self._draw_atmo_glow(surf, cx, cy, r, glow, alpha)
        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 15:
            random.seed(3137)
            # 핑크/보라 소용돌이 밴드
            for by in range(-r + 5, r, max(4, r // 5)):
                bw = int(math.sqrt(max(0, r * r - by * by)))
                if bw < 3:
                    continue
                wave = int(3 * math.sin(by * 0.3))
                col = (200 + random.randint(-20, 20),
                       50 + random.randint(0, 40),
                       170 + random.randint(-20, 20))
                pygame.draw.line(surf, col,
                                 (cx - bw + wave, cy + by),
                                 (cx + bw + wave, cy + by), 1)
            # 하트 문양들
            if r > 25:
                for _ in range(3):
                    ang = random.uniform(0, math.pi * 2)
                    d = random.uniform(r * 0.15, r * 0.55)
                    hx = cx + int(d * math.cos(ang))
                    hy = cy + int(d * math.sin(ang))
                    hs = max(3, r // 8)
                    # 하트: 원 2개 + 삼각형
                    pygame.draw.circle(surf, (255, 100, 150),
                                       (hx - hs // 3, hy - hs // 4), hs // 2)
                    pygame.draw.circle(surf, (255, 100, 150),
                                       (hx + hs // 3, hy - hs // 4), hs // 2)
                    pygame.draw.polygon(surf, (255, 100, 150), [
                        (hx - hs, hy), (hx + hs, hy),
                        (hx, hy + hs)])
            # 균열 (어두운 보라 선)
            if r > 30:
                for _ in range(2):
                    sx = cx + random.randint(-r // 2, r // 2)
                    sy = cy + random.randint(-r // 2, r // 2)
                    pts = [(sx, sy)]
                    for _ in range(4):
                        sx += random.randint(-r // 5, r // 5)
                        sy += random.randint(-r // 8, r // 4)
                        pts.append((sx, sy))
                    pygame.draw.lines(surf, (100, 20, 80), False, pts,
                                      max(1, r // 25))
            random.seed()
        self._draw_highlight(surf, cx, cy, r, base, alpha)
        self._draw_ring(surf, cx, cy, r, (200, 80, 180), alpha)
        pygame.draw.circle(surf, (220, 100, 200), (cx, cy), r + 1, 1)

    # ── 행성 4: 사원 (암석/고대 문명/만다라) ──
    def _draw_planet_temple(self, surf, cx, cy, r, alpha=255):
        glow = (220, 180, 100)
        base = (140, 100, 60)
        self._draw_atmo_glow(surf, cx, cy, r, glow, alpha)
        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 15:
            random.seed(4137)
            # 사암 밴드 (가로줄 + 약간의 색 변화)
            for by in range(-r + 4, r, max(3, r // 8)):
                bw = int(math.sqrt(max(0, r * r - by * by)))
                if bw < 3:
                    continue
                shade = random.randint(-15, 15)
                col = (_clamp(140 + shade), _clamp(100 + shade),
                       _clamp(60 + shade // 2))
                pygame.draw.line(surf, col,
                                 (cx - bw, cy + by), (cx + bw, cy + by), 2)
            # 크레이터 (고대 유적 구덩이)
            for _ in range(4):
                ang = random.uniform(0, math.pi * 2)
                d = random.uniform(r * 0.1, r * 0.6)
                cr = random.randint(max(2, r // 9), max(4, r // 5))
                dark = (100 + random.randint(-10, 10),
                        70 + random.randint(-10, 10),
                        35 + random.randint(-5, 5))
                px = cx + int(d * math.cos(ang))
                py = cy + int(d * math.sin(ang))
                pygame.draw.circle(surf, dark, (px, py), cr)
                # 크레이터 테두리 (밝은 부분)
                hl = tuple(min(255, c + 40) for c in dark)
                pygame.draw.arc(surf, hl,
                                (px - cr, py - cr, cr * 2, cr * 2),
                                math.pi * 0.8, math.pi * 1.8, 1)
            # 만다라 동심원 (중앙)
            if r > 35:
                for ri in range(3, 0, -1):
                    mr = max(2, r // 5 * ri // 3)
                    pygame.draw.circle(surf, (180, 150, 80, 40),
                                       (cx, cy), mr, 1)
                # 사방 십자 장식
                cr_len = max(3, r // 4)
                for ang in [0, math.pi / 2, math.pi, math.pi * 1.5]:
                    ex = cx + int(cr_len * math.cos(ang))
                    ey = cy + int(cr_len * math.sin(ang))
                    pygame.draw.line(surf, (200, 170, 90),
                                     (cx, cy), (ex, ey), 1)
            random.seed()
        self._draw_highlight(surf, cx, cy, r, base, alpha)
        pygame.draw.circle(surf, (200, 160, 90), (cx, cy), r + 1, 1)

    # ── 행성 5: 해상전투 (바다/파도/전함) ──
    def _draw_planet_ocean(self, surf, cx, cy, r, alpha=255):
        glow = (80, 150, 255)
        base = (50, 90, 160)
        self._draw_atmo_glow(surf, cx, cy, r, glow, alpha)
        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 15:
            random.seed(5137)
            # 바다 파도 (가로 물결선)
            for by in range(-r + 3, r, max(3, r // 7)):
                bw = int(math.sqrt(max(0, r * r - by * by)))
                if bw < 4:
                    continue
                pts = []
                wave_a = max(1, r // 12)
                for sx in range(-bw, bw + 1, max(2, bw // 10)):
                    wy = by + int(wave_a * math.sin(sx * 0.12 + by * 0.08))
                    pts.append((cx + sx, cy + wy))
                if len(pts) > 1:
                    shade = 20 + abs(by) % 30
                    pygame.draw.lines(surf, (30, 70 + shade, 180 + shade // 2),
                                      False, pts, 1)
            # 대륙 섬 (작은 녹색/갈색 원)
            for _ in range(3):
                ang = random.uniform(0, math.pi * 2)
                d = random.uniform(r * 0.2, r * 0.6)
                cr = random.randint(max(2, r // 12), max(3, r // 7))
                land = (60 + random.randint(0, 40),
                        100 + random.randint(0, 40),
                        40 + random.randint(0, 20))
                px = cx + int(d * math.cos(ang))
                py = cy + int(d * math.sin(ang))
                pygame.draw.circle(surf, land, (px, py), cr)
            # 구름/폭풍 소용돌이
            if r > 35:
                for _ in range(2):
                    sa = random.uniform(0, math.pi * 2)
                    sd = random.uniform(r * 0.2, r * 0.5)
                    sx = cx + int(sd * math.cos(sa))
                    sy = cy + int(sd * math.sin(sa))
                    sr = max(4, r // 6)
                    ss = pygame.Surface((sr * 2 + 4, sr * 2 + 4), pygame.SRCALPHA)
                    for ci in range(sr, 0, -2):
                        a = max(1, int(18 * ci / sr))
                        pygame.draw.circle(ss, (200, 220, 255, a),
                                           (sr + 2, sr + 2), ci)
                    surf.blit(ss, (sx - sr - 2, sy - sr - 2))
            random.seed()
        self._draw_highlight(surf, cx, cy, r, base, alpha)
        self._draw_ring(surf, cx, cy, r, (60, 120, 200), alpha)
        pygame.draw.circle(surf, (80, 160, 255), (cx, cy), r + 1, 1)

    # ── 행성 6: 화염 (용암/불꽃/균열) ──
    def _draw_planet_fire(self, surf, cx, cy, r, alpha=255):
        glow = (255, 100, 50)
        base = (200, 55, 55)
        # 불꽃 글로우 (더 넓고 붉게)
        grr = r + 40
        gs = pygame.Surface((grr * 2 + 4, grr * 2 + 4), pygame.SRCALPHA)
        gcx = grr + 2
        for i in range(40, 0, -2):
            a = max(1, int(30 * alpha / 255 * (1 - i / 40)))
            col_r = _clamp(255 - i * 2)
            col_g = _clamp(80 - i)
            pygame.draw.circle(gs, (col_r, col_g, 20, a), (gcx, gcx), r + i)
        surf.blit(gs, (cx - grr - 2, cy - grr - 2))

        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 15:
            random.seed(6137)
            # 용암 흐름 (밝은 주황/노랑 곡선)
            for _ in range(5):
                start_a = random.uniform(0, math.pi * 2)
                pts = []
                for step in range(6):
                    t = step / 5
                    ang = start_a + t * math.pi * 0.6 + random.uniform(-0.2, 0.2)
                    d = r * (0.1 + t * 0.6)
                    px = cx + int(d * math.cos(ang))
                    py = cy + int(d * math.sin(ang))
                    pts.append((px, py))
                if len(pts) > 1:
                    lava_b = random.randint(180, 255)
                    pygame.draw.lines(surf, (255, lava_b, 30), False, pts,
                                      max(1, r // 18))
            # 화산구 (짙은 빨간 원 + 밝은 테두리)
            for _ in range(3):
                ang = random.uniform(0, math.pi * 2)
                d = random.uniform(r * 0.1, r * 0.55)
                cr = random.randint(max(2, r // 10), max(4, r // 6))
                px = cx + int(d * math.cos(ang))
                py = cy + int(d * math.sin(ang))
                pygame.draw.circle(surf, (120, 20, 10), (px, py), cr)
                pygame.draw.circle(surf, (255, 160, 40), (px, py), cr, 1)
            # 불꽃 파티클 (행성 표면 위 작은 점)
            if r > 25:
                for _ in range(8):
                    fa = random.uniform(0, math.pi * 2)
                    fd = random.uniform(r * 0.3, r * 0.9)
                    fx = cx + int(fd * math.cos(fa))
                    fy = cy + int(fd * math.sin(fa))
                    if (fx - cx) ** 2 + (fy - cy) ** 2 < r * r:
                        fs = max(1, random.randint(1, r // 15))
                        pygame.draw.circle(surf,
                                           (255, random.randint(100, 200), 0),
                                           (fx, fy), fs)
            random.seed()
        self._draw_highlight(surf, cx, cy, r, (230, 100, 60), alpha)
        self._draw_ring(surf, cx, cy, r, (255, 80, 30), alpha)
        pygame.draw.circle(surf, (255, 120, 40), (cx, cy), r + 1, 1)

    # ── 행성 7: 테트리스 (네온/블록/픽셀) ──
    def _draw_planet_tetris(self, surf, cx, cy, r, alpha=255):
        glow = (160, 200, 255)
        base = (40, 50, 90)
        self._draw_atmo_glow(surf, cx, cy, r, glow, alpha)
        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 15:
            random.seed(7137)
            tetro_colors = [
                (0, 240, 240),    # I - 시안
                (240, 240, 0),    # O - 노랑
                (160, 0, 240),    # T - 보라
                (0, 240, 0),      # S - 초록
                (240, 0, 0),      # Z - 빨강
                (0, 0, 240),      # J - 파랑
                (240, 160, 0),    # L - 주황
            ]
            # 블록 격자 패턴
            block_sz = max(3, r // 7)
            for gx in range(-r + block_sz, r, block_sz + 1):
                for gy in range(-r + block_sz, r, block_sz + 1):
                    if gx * gx + gy * gy > (r - block_sz) ** 2:
                        continue
                    if random.random() < 0.35:
                        col = random.choice(tetro_colors)
                        bx = cx + gx - block_sz // 2
                        by = cy + gy - block_sz // 2
                        # 네온 블록
                        dim = tuple(max(0, c // 3) for c in col)
                        pygame.draw.rect(surf, dim,
                                         (bx, by, block_sz, block_sz))
                        pygame.draw.rect(surf, col,
                                         (bx, by, block_sz, block_sz), 1)
            # 네온 그리드 라인
            if r > 30:
                for gx in range(-r, r + 1, block_sz + 1):
                    bw = int(math.sqrt(max(0, r * r - gx * gx)))
                    if bw < 2:
                        continue
                    pygame.draw.line(surf, (60, 70, 120),
                                     (cx + gx, cy - bw), (cx + gx, cy + bw), 1)
                for gy in range(-r, r + 1, block_sz + 1):
                    bw = int(math.sqrt(max(0, r * r - gy * gy)))
                    if bw < 2:
                        continue
                    pygame.draw.line(surf, (60, 70, 120),
                                     (cx - bw, cy + gy), (cx + bw, cy + gy), 1)
            random.seed()
        self._draw_highlight(surf, cx, cy, r, (100, 130, 200), alpha)
        self._draw_ring(surf, cx, cy, r, (100, 150, 255), alpha)
        # 네온 대기 경계
        pygame.draw.circle(surf, (120, 180, 255), (cx, cy), r + 1, 1)
        if r > 20:
            pygame.draw.circle(surf, (80, 140, 255, 60), (cx, cy), r + 3, 1)

    # ── 행성 8: 그림자 (어둠/안개/닌자) ──
    def _draw_planet_shadow(self, surf, cx, cy, r, alpha=255):
        glow = (100, 130, 180)
        base = (35, 40, 60)
        # 어두운 글로우
        gr = r + 35
        gs = pygame.Surface((gr * 2 + 4, gr * 2 + 4), pygame.SRCALPHA)
        gcx = gr + 2
        for i in range(35, 0, -2):
            a = max(1, int(20 * alpha / 255 * (1 - i / 35)))
            pygame.draw.circle(gs, (60, 70, 100, a), (gcx, gcx), r + i)
        surf.blit(gs, (cx - gr - 2, cy - gr - 2))

        pygame.draw.circle(surf, base, (cx, cy), r)
        if r > 15:
            random.seed(8137)
            # 어둠 소용돌이 (동심 나선)
            if r > 25:
                pts = []
                for step in range(40):
                    t = step / 39
                    ang = t * math.pi * 4
                    d = r * 0.1 + t * r * 0.7
                    px = cx + int(d * math.cos(ang))
                    py = cy + int(d * math.sin(ang))
                    if (px - cx) ** 2 + (py - cy) ** 2 < r * r:
                        pts.append((px, py))
                if len(pts) > 2:
                    pygame.draw.lines(surf, (20, 25, 40), False, pts, 1)
            # 그림자 안개 (반투명 원)
            for _ in range(5):
                ang = random.uniform(0, math.pi * 2)
                d = random.uniform(0, r * 0.7)
                cr = random.randint(max(3, r // 6), max(5, r // 3))
                px = cx + int(d * math.cos(ang))
                py = cy + int(d * math.sin(ang))
                fs = pygame.Surface((cr * 2 + 4, cr * 2 + 4), pygame.SRCALPHA)
                for ci in range(cr, 0, -2):
                    fa = max(1, int(12 * ci / cr))
                    fog_b = 40 + random.randint(0, 30)
                    pygame.draw.circle(fs, (fog_b // 2, fog_b // 2, fog_b, fa),
                                       (cr + 2, cr + 2), ci)
                surf.blit(fs, (px - cr - 2, py - cr - 2))
            # 수리검 문양 (십자 + 사선)
            if r > 35:
                sr = max(4, r // 5)
                for ang_off in [0, math.pi / 4]:
                    for i in range(4):
                        ang = ang_off + i * math.pi / 2
                        ex = cx + int(sr * math.cos(ang))
                        ey = cy + int(sr * math.sin(ang))
                        pygame.draw.line(surf, (80, 90, 120),
                                         (cx, cy), (ex, ey), 1)
            random.seed()
        self._draw_highlight(surf, cx, cy, r, (60, 70, 100), alpha)
        pygame.draw.circle(surf, (70, 80, 110), (cx, cy), r + 1, 1)

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

    def _draw_dest_planet(self, surf, cx, cy, radius, planet_num, alpha=255):
        renderer_name = self._PLANET_RENDERERS.get(planet_num)
        if renderer_name:
            getattr(self, renderer_name)(surf, cx, cy, radius, alpha)
        else:
            # 폴백: 기본 렌더링
            config = PLANET_CONFIGS.get(planet_num, {})
            base = config.get("theme_color", (100, 100, 100))
            glow = config.get("glow_color", (150, 150, 150))
            self._draw_atmo_glow(surf, cx, cy, radius, glow, alpha)
            pygame.draw.circle(surf, base, (cx, cy), radius)
            self._draw_highlight(surf, cx, cy, radius, base, alpha)
            pygame.draw.circle(surf, glow, (cx, cy), radius + 1, 1)

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
        시네마틱 우주 여행 (6단계)
        P1: 1인칭 콕핏 워프  P2: 시점 전환  P3: 3인칭 횡스크롤
        P4: 행성 접근  P5: 도착  P6: 줌아웃 은하맵
        """
        if cleared_planets is None:
            cleared_planets = []

        tcfg = PLANET_CONFIGS.get(to_planet, {})
        tname = tcfg.get("name", f"행성 {to_planet}")

        FPS = 60
        # Phase 듀레이션 (초)
        DUR = {1: 3.0, 2: 2.0, 3: 3.0, 4: 2.0, 5: 1.5, 6: 1.5}
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

                self._update_warp_stars(dt, 1.0 + t * 2.0)
                self._draw_warp_stars(self.screen, warp_int)
                self._draw_nebulae(self.screen, 0.3 * warp_int)

                # 스캔라인
                if random.random() < 0.3:
                    sy = random.randint(0, self.H)
                    pygame.draw.line(self.screen, (30, 50, 80),
                                     (0, sy), (self.W, sy), 1)

                # 콕핏
                shake_i = 0.5 + t * 1.5
                sx = random.uniform(-shake_i, shake_i)
                sy = random.uniform(-shake_i, shake_i)
                self.screen.blit(self.cockpit_surface, (int(sx), int(sy)))

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

                pygame.display.flip()
                if frame >= FRAMES[1]:
                    phase = 2
                    frame = 0

            # ════════════════ Phase 2: 시점 전환 ════════════════
            elif phase == 2:
                t = frame / FRAMES[2]
                et = _ease_in_out(t)

                fp_alpha = max(0.0, 1.0 - et * 2.0)

                # 워프 별 페이드아웃
                if fp_alpha > 0.1:
                    self._update_warp_stars(dt, max(0.3, 2.0 - t * 3))
                    self._draw_warp_stars(self.screen, fp_alpha)

                # 횡스크롤 별 페이드인
                sa = min(1.0, et * 1.5)
                for layer in [self.stars_dust, self.stars_far,
                              self.stars_mid, self.stars_near]:
                    self._update_stars(layer, 0.5 + et)
                self._draw_stars_layer(self.screen, self.stars_dust, sa * 0.4)
                self._draw_stars_layer(self.screen, self.stars_far, sa)
                self._draw_stars_layer(self.screen, self.stars_mid, sa)
                self._draw_stars_layer(self.screen, self.stars_near, sa * 0.7)

                # 성운 전환
                self._update_nebulae(0.3 + et * 0.5)
                self._draw_nebulae(self.screen, sa * 0.5)

                # 콕핏 페이드아웃
                if fp_alpha > 0.05:
                    cc = self.cockpit_surface.copy()
                    cc.set_alpha(_clamp(255 * fp_alpha))
                    self.screen.blit(cc, (0, 0))

                # 우주선 등장 (중앙에서 → 크루즈 위치)
                if et > 0.3:
                    st = _ease_out_cubic((et - 0.3) / 0.7)
                    sx = self.W * 0.5 + (cruise_x - self.W * 0.5) * st
                    sy = self.H * 0.5 + (ship_yb - self.H * 0.5) * st
                    sc = 0.3 + st * 1.0
                    self._draw_ship(self.screen, sx, sy, sc, 0.5 + st * 0.5)

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

                pygame.display.flip()
                if frame >= FRAMES[2]:
                    phase = 3
                    frame = 0

            # ════════════════ Phase 3: 3인칭 횡스크롤 ════════════════
            elif phase == 3:
                t = frame / FRAMES[3]

                for layer in [self.stars_dust, self.stars_far, self.stars_mid,
                              self.stars_near, self.stars_front]:
                    self._update_stars(layer, 1.0)
                self._update_nebulae(1.0)
                self._draw_nebulae(self.screen, 0.6)

                self._draw_stars_layer(self.screen, self.stars_dust, 0.3)
                self._draw_stars_layer(self.screen, self.stars_far)
                self._draw_stars_layer(self.screen, self.stars_mid)

                self._update_scroll_planets(1.0)
                self._draw_scroll_planets(self.screen)

                self._draw_stars_layer(self.screen, self.stars_near)
                self._draw_stars_layer(self.screen, self.stars_front, 0.8)

                self._update_speed_lines(1.0)
                self._draw_speed_lines(self.screen, min(1.0, t * 3))

                self._draw_engine_particles(self.screen)

                bob = math.sin(self.time * 2.5) * 8
                self._draw_ship(self.screen, cruise_x, ship_yb + bob, 1.3, 1.0)

                ts = self.font_big.render("은하계 항해", True, (200, 210, 240))
                self.screen.blit(ts, ts.get_rect(center=(self.W // 2, 35)))

                if t > 0.3:
                    ha = _clamp((t - 0.3) * 4 * 255)
                    gc = tcfg.get("glow_color", (200, 200, 200))
                    hs = self.font_med.render(f"목표: {tname}", True, gc)
                    hs.set_alpha(ha)
                    self.screen.blit(hs, hs.get_rect(
                        center=(self.W // 2, self.H - 40)))

                pygame.display.flip()
                if frame >= FRAMES[3]:
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

                self._update_scroll_planets(slow)
                self._draw_scroll_planets(self.screen)
                self._draw_stars_layer(self.screen, self.stars_near)

                self._update_speed_lines(slow)
                self._draw_speed_lines(self.screen, max(0, 1.0 - t * 2))

                # 행성 진입
                ep = _ease_in_out(t)
                px = self.W + 100 + (pend_x - self.W - 100) * ep
                pr = pr_sm + (pr_big - pr_sm) * ep
                self._draw_dest_planet(self.screen, int(px), int(p_y),
                                       int(pr), to_planet)

                self._draw_engine_particles(self.screen)

                decel = max(0.0, 1.0 - t * 1.2)
                sx = cruise_x - 30 * (1 - decel)
                bob = math.sin(self.time * 2.5) * 8 * decel
                sc = max(0.8, 1.3 - t * 0.5)
                ep_e = max(0.2, 1.0 - t * 0.8)
                self._draw_ship(self.screen, sx, ship_yb + bob, sc, ep_e)

                ts = self.font_big.render("은하계 항해", True, (200, 210, 240))
                self.screen.blit(ts, ts.get_rect(center=(self.W // 2, 35)))

                na = _clamp(t * 2 * 255)
                gc = tcfg.get("glow_color", (200, 200, 200))
                ns = self.font_med.render(tname, True, gc)
                ns.set_alpha(na)
                self.screen.blit(ns, ns.get_rect(
                    center=(int(px), int(p_y) + int(pr) + 28)))

                pygame.display.flip()
                if frame >= FRAMES[4]:
                    phase = 5
                    frame = 0

            # ════════════════ Phase 5: 도착 연출 ════════════════
            elif phase == 5:
                t = frame / FRAMES[5]

                self._draw_stars_layer(self.screen, self.stars_dust, 0.3)
                self._draw_stars_layer(self.screen, self.stars_far)
                self._draw_stars_layer(self.screen, self.stars_mid)
                self._draw_nebulae(self.screen, 0.3)

                px_f = pend_x + (self.W * 0.5 - pend_x) * min(1.0, t * 2)
                pr_f = pr_big + 12 * min(1.0, t * 2)
                self._draw_dest_planet(self.screen, int(px_f), int(p_y),
                                       int(pr_f), to_planet)

                sx_a = cruise_x + (px_f - 90 - cruise_x) * min(1.0, t * 3)
                self._draw_ship(self.screen, sx_a, ship_yb, 0.9, 0.2)
                self._draw_engine_particles(self.screen)

                aa = _clamp(t * 3 * 255)
                at = self.font_big.render(f"{tname} 도착!", True,
                                          (255, 230, 150))
                at.set_alpha(aa)
                self.screen.blit(at, at.get_rect(
                    center=(self.W // 2, self.H * 0.72)))

                ts = self.font_big.render("은하계 항해", True, (200, 210, 240))
                self.screen.blit(ts, ts.get_rect(center=(self.W // 2, 35)))

                pygame.display.flip()
                if frame >= FRAMES[5]:
                    phase = 6
                    frame = 0
                    self._render_galaxy_map(cleared_planets, to_planet)

            # ════════════════ Phase 6: 줌아웃 은하 맵 ════════════════
            elif phase == 6:
                t = frame / FRAMES[6]
                et = _ease_in_out(t)

                scene_a = max(0, int(255 * (1.0 - et * 1.5)))
                map_a = min(255, int(255 * et * 1.5))

                self.screen.fill((3, 3, 12))
                mc = self.map_surface.copy()
                mc.set_alpha(map_a)
                self.screen.blit(mc, (0, 0))

                if scene_a > 10:
                    zoom = max(0.1, 1.0 - et)
                    sw = int(self.W * zoom)
                    sh = int(self.H * zoom)
                    if sw > 10 and sh > 10:
                        ti = to_planet - 1
                        if ti < len(self.planet_positions):
                            tcx, tcy = self.planet_positions[ti]
                        else:
                            tcx, tcy = self.W // 2, self.H // 2
                        zs = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
                        zs.fill((3, 3, 12))
                        self._draw_dest_planet(
                            zs, self.W // 2, self.H // 2,
                            int(pr_big * zoom), to_planet, scene_a)
                        scaled = pygame.transform.smoothscale(zs, (sw, sh))
                        scaled.set_alpha(scene_a)
                        self.screen.blit(scaled,
                                         (tcx - sw // 2, tcy - sh // 2))

                if map_a > 100:
                    ts = self.font_big.render("은하계 항해", True,
                                              (200, 210, 240))
                    ts.set_alpha(map_a)
                    self.screen.blit(ts, ts.get_rect(
                        center=(self.W // 2, 35)))

                pygame.display.flip()
                if frame >= FRAMES[6]:
                    break

        # 스킵 시 은하맵 한 프레임
        if skipped:
            self._render_galaxy_map(cleared_planets, to_planet)
            self.screen.blit(self.map_surface, (0, 0))
            ts = self.font_big.render("은하계 항해", True, (200, 210, 240))
            self.screen.blit(ts, ts.get_rect(center=(self.W // 2, 35)))
            pygame.display.flip()
            pygame.time.delay(300)

        pygame.event.clear()

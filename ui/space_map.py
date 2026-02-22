# -*- coding: utf-8 -*-
"""
우주 행성 맵 시스템 - 시네마틱 애니메이션
1) 왼쪽에서 우주선 출발 → 횡스크롤 비행 (별+행성 스쳐지남)
2) 목표 행성에 도착 (감속+확대)
3) 줌아웃 → 탑뷰 은하 맵으로 전환 (전체 행성 표시)
4) 보스 선출 룰렛으로 이어짐
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
#  탑뷰 은하 맵 행성 배치 (760×750 기준, S자 곡선)
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
#  파티클 / 오브젝트 클래스들
# ═══════════════════════════════════════════════════════════
class _StarLayer:
    """멀티-레이어 패럴랙스 별"""
    __slots__ = ('x', 'y', 'speed', 'size', 'brightness', 'color_tint')

    def __init__(self, w, h, speed_range, size_range):
        self.x = random.uniform(0, w)
        self.y = random.uniform(0, h)
        self.speed = random.uniform(*speed_range)
        self.size = random.choice(size_range)
        self.brightness = random.randint(100, 255)
        # 약간의 색조 변화
        tint = random.choice([(1.0, 1.0, 0.85), (0.85, 0.9, 1.0), (1.0, 0.9, 0.85), (0.9, 1.0, 1.0)])
        self.color_tint = tint


class _ScrollPlanet:
    """횡스크롤 중 배경에 지나가는 장식용 행성"""
    __slots__ = ('x', 'y', 'radius', 'color', 'ring', 'ring_color', 'speed', 'highlight_offset')

    def __init__(self, w, h):
        self.x = w + random.randint(50, 300)
        self.y = random.randint(60, h - 60)
        self.radius = random.randint(15, 55)
        r = random.randint(40, 220)
        g = random.randint(40, 220)
        b = random.randint(40, 220)
        self.color = (r, g, b)
        self.ring = random.random() < 0.35
        self.ring_color = (min(255, r + 40), min(255, g + 40), min(255, b + 40))
        self.speed = random.uniform(1.0, 3.5)
        self.highlight_offset = random.uniform(-0.3, -0.15)


class _SpeedLine:
    """속도감 연출 라인"""
    __slots__ = ('x', 'y', 'length', 'speed', 'alpha')

    def __init__(self, w, h):
        self.x = w + random.randint(0, 100)
        self.y = random.randint(0, h)
        self.length = random.randint(20, 80)
        self.speed = random.uniform(8, 18)
        self.alpha = random.randint(30, 90)


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
            self.font_big = get_font(32, style="bold")
            self.font_med = get_font(20, style="bold")
            self.font_sm = get_font(14, style="bold")
            self.font_xs = get_font(12, style="regular")
        except Exception:
            self.font_big = pygame.font.Font(None, 40)
            self.font_med = pygame.font.Font(None, 26)
            self.font_sm = pygame.font.Font(None, 18)
            self.font_xs = pygame.font.Font(None, 14)

        # 패럴랙스 별 레이어 (뒤→앞)
        self.stars_far = [_StarLayer(width, height, (0.3, 1.0), [1]) for _ in range(120)]
        self.stars_mid = [_StarLayer(width, height, (1.5, 3.5), [1, 2]) for _ in range(80)]
        self.stars_near = [_StarLayer(width, height, (4.0, 8.0), [2, 3]) for _ in range(40)]

        # 횡스크롤 장식 행성
        self.scroll_planets = []

        # 속도 라인
        self.speed_lines = [_SpeedLine(width, height) for _ in range(15)]

        # 탑뷰 행성 좌표
        n = len(PLANET_CONFIGS) if PLANET_CONFIGS else 8
        self.planet_positions = _compute_planet_positions(width, height, n)

        # 우주선 상태
        self.ship_x = -60.0
        self.ship_y = float(height // 2)
        self.ship_tilt = 0.0  # 상하 흔들림
        self.engine_flicker = 0

        # 오프스크린 버퍼 (줌 아웃 트랜지션용)
        self.map_surface = pygame.Surface((width, height), pygame.SRCALPHA)

    # ──────────────────────────────────────────────────────
    #  이벤트 폴링 (공통)
    # ──────────────────────────────────────────────────────
    def _poll_skip(self):
        """스킵 입력 확인. True면 스킵 요청."""
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if ev.type == pygame.KEYDOWN and ev.key in (pygame.K_ESCAPE, pygame.K_SPACE):
                return True
        return False

    # ──────────────────────────────────────────────────────
    #  횡스크롤 비행 렌더링 헬퍼
    # ──────────────────────────────────────────────────────
    def _update_stars(self, layer, speed_mult=1.0):
        for s in layer:
            s.x -= s.speed * speed_mult
            if s.x < -5:
                s.x = self.W + random.uniform(0, 20)
                s.y = random.uniform(0, self.H)

    def _draw_stars_on(self, surf, layer):
        for s in layer:
            b = s.brightness
            r = max(0, min(255, int(b * s.color_tint[0])))
            g = max(0, min(255, int(b * s.color_tint[1])))
            bl = max(0, min(255, int(b * s.color_tint[2])))
            ix, iy = int(s.x), int(s.y)
            if 0 <= ix < self.W and 0 <= iy < self.H:
                if s.size <= 1:
                    surf.set_at((ix, iy), (r, g, bl))
                else:
                    pygame.draw.circle(surf, (r, g, bl), (ix, iy), s.size)

    def _update_scroll_planets(self, speed_mult=1.0):
        for p in self.scroll_planets:
            p.x -= p.speed * speed_mult
        self.scroll_planets = [p for p in self.scroll_planets if p.x > -p.radius * 2 - 10]
        # 랜덤 스폰
        if random.random() < 0.012 * speed_mult:
            self.scroll_planets.append(_ScrollPlanet(self.W, self.H))

    def _draw_scroll_planet(self, surf, p):
        ix, iy = int(p.x), int(p.y)
        # 본체
        pygame.draw.circle(surf, p.color, (ix, iy), p.radius)
        # 하이라이트
        hx = ix + int(p.radius * p.highlight_offset)
        hy = iy + int(p.radius * p.highlight_offset)
        hl = tuple(min(255, c + 70) for c in p.color)
        pygame.draw.circle(surf, hl, (hx, hy), max(3, p.radius // 3))
        # 고리
        if p.ring:
            ring_surf = pygame.Surface((p.radius * 3, p.radius), pygame.SRCALPHA)
            rcx = p.radius * 3 // 2
            rcy = p.radius // 2
            pygame.draw.ellipse(ring_surf, (*p.ring_color, 100),
                                (rcx - p.radius - 6, rcy - 4, (p.radius + 6) * 2, 8), 2)
            surf.blit(ring_surf, (ix - p.radius * 3 // 2, iy - p.radius // 2))
        # 외곽선
        pygame.draw.circle(surf, tuple(max(0, c - 40) for c in p.color), (ix, iy), p.radius, 1)

    def _update_speed_lines(self, speed_mult=1.0):
        for ln in self.speed_lines:
            ln.x -= ln.speed * speed_mult
            if ln.x + ln.length < 0:
                ln.x = self.W + random.randint(0, 100)
                ln.y = random.randint(0, self.H)
                ln.length = random.randint(20, 80)
                ln.alpha = random.randint(30, 90)

    def _draw_speed_lines(self, surf, alpha_mult=1.0):
        for ln in self.speed_lines:
            a = int(ln.alpha * alpha_mult)
            if a < 5:
                continue
            line_surf = pygame.Surface((ln.length, 1), pygame.SRCALPHA)
            # 그라데이션 라인
            for px in range(int(ln.length)):
                t = px / max(1, ln.length)
                la = int(a * t)
                line_surf.set_at((px, 0), (200, 210, 255, la))
            surf.blit(line_surf, (int(ln.x), int(ln.y)))

    # ──────────────────────────────────────────────────────
    #  우주선 그리기 (횡스크롤 - 오른쪽을 향함)
    # ──────────────────────────────────────────────────────
    def _draw_ship_side(self, surf, x, y, scale=1.0):
        """횡스크롤 뷰 우주선 (→ 방향)"""
        s = scale
        ix, iy = int(x), int(y)
        # 엔진 불꽃 (왼쪽으로)
        self.engine_flicker = (self.engine_flicker + 1) % 4
        fl = random.randint(12, 28)
        fy_off = random.randint(-3, 3)
        # 메인 불꽃
        pygame.draw.line(surf, (255, 200, 50),
                         (ix - int(10 * s), iy + fy_off),
                         (ix - int((10 + fl) * s), iy + fy_off), max(1, int(4 * s)))
        # 보조 불꽃
        fl2 = random.randint(6, 16)
        pygame.draw.line(surf, (255, 100, 20),
                         (ix - int(10 * s), iy + random.randint(-2, 2)),
                         (ix - int((10 + fl2) * s), iy + random.randint(-4, 4)), max(1, int(2 * s)))
        # 선체 (삼각형)
        nose = (ix + int(20 * s), iy)
        top = (ix - int(12 * s), iy - int(10 * s))
        bot = (ix - int(12 * s), iy + int(10 * s))
        pygame.draw.polygon(surf, (200, 210, 240), [nose, top, bot])
        # 윙
        wing_top = (ix - int(8 * s), iy - int(14 * s))
        wing_bot = (ix - int(8 * s), iy + int(14 * s))
        pygame.draw.polygon(surf, (150, 160, 200),
                            [(ix - int(4 * s), iy - int(6 * s)), wing_top,
                             (ix - int(12 * s), iy - int(8 * s))])
        pygame.draw.polygon(surf, (150, 160, 200),
                            [(ix - int(4 * s), iy + int(6 * s)), wing_bot,
                             (ix - int(12 * s), iy + int(8 * s))])
        # 콕핏 (파란 점)
        pygame.draw.circle(surf, (100, 180, 255), (ix + int(6 * s), iy), max(2, int(3 * s)))
        # 외곽선
        pygame.draw.polygon(surf, (160, 170, 210), [nose, top, bot], 1)

    # ──────────────────────────────────────────────────────
    #  목표 행성 클로즈업 그리기
    # ──────────────────────────────────────────────────────
    def _draw_destination_planet(self, surf, cx, cy, radius, planet_num, alpha=255):
        config = PLANET_CONFIGS.get(planet_num, {})
        base = config.get("theme_color", (100, 100, 100))
        glow = config.get("glow_color", (150, 150, 150))
        ring_c = config.get("ring_color", None)

        # 글로우
        glow_r = radius + 20
        glow_surf = pygame.Surface((glow_r * 2 + 4, glow_r * 2 + 4), pygame.SRCALPHA)
        for r in range(glow_r, radius, -3):
            a = int(50 * alpha / 255 * (1 - (r - radius) / (glow_r - radius)))
            pygame.draw.circle(glow_surf, (*glow, a), (glow_r + 2, glow_r + 2), r)
        surf.blit(glow_surf, (cx - glow_r - 2, cy - glow_r - 2))

        # 본체
        pygame.draw.circle(surf, base, (cx, cy), radius)
        # 하이라이트
        hl = tuple(min(255, c + 70) for c in base)
        pygame.draw.circle(surf, hl, (cx - radius // 4, cy - radius // 4), max(4, radius // 3))
        # 대기 효과 (외곽 얇은 링)
        atm = tuple(min(255, c + 30) for c in glow)
        pygame.draw.circle(surf, atm, (cx, cy), radius + 2, 1)
        pygame.draw.circle(surf, (*atm, 60 * alpha // 255), (cx, cy), radius + 5, 1)
        # 고리
        if ring_c:
            rw = int(radius * 2.4)
            rh = max(6, radius // 4)
            ring_s = pygame.Surface((rw, rh), pygame.SRCALPHA)
            pygame.draw.ellipse(ring_s, (*ring_c, 120 * alpha // 255), (0, 0, rw, rh), 2)
            surf.blit(ring_s, (cx - rw // 2, cy - rh // 2))

    # ──────────────────────────────────────────────────────
    #  탑뷰 은하 맵 렌더링
    # ──────────────────────────────────────────────────────
    def _render_galaxy_map(self, cleared, target_planet):
        """탑뷰 맵을 self.map_surface 에 그린다."""
        ms = self.map_surface
        ms.fill((5, 5, 15, 255))
        # 별
        self._draw_stars_on(ms, self.stars_far)
        self._draw_stars_on(ms, self.stars_mid)
        # 경로선
        for i in range(len(self.planet_positions) - 1):
            x1, y1 = self.planet_positions[i]
            x2, y2 = self.planet_positions[i + 1]
            cleared_seg = (i + 1) in cleared
            col = (60, 100, 160) if cleared_seg else (25, 35, 55)
            dx, dy = x2 - x1, y2 - y1
            dist = math.hypot(dx, dy)
            if dist < 1:
                continue
            steps = int(dist / 7)
            for j in range(steps):
                if j % 2 == 0:
                    t = j / max(1, steps)
                    pygame.draw.circle(ms, col, (int(x1 + dx * t), int(y1 + dy * t)), 1)
        # 행성들
        for i, (px, py) in enumerate(self.planet_positions):
            pn = i + 1
            cfg = PLANET_CONFIGS.get(pn, {})
            bc = cfg.get("theme_color", (100, 100, 100))
            gc = cfg.get("glow_color", (150, 150, 150))
            rc = cfg.get("ring_color", None)
            rad = cfg.get("size", 28)
            nm = cfg.get("name", f"행성 {pn}")
            is_target = pn == target_planet
            is_clr = pn in cleared

            # 타겟 글로우
            if is_target:
                gr = rad + 14 + int(5 * math.sin(self.time * 3))
                gs = pygame.Surface((gr * 2 + 8, gr * 2 + 8), pygame.SRCALPHA)
                for rr in range(gr, rad, -2):
                    a = int(45 * (1 - (rr - rad) / (gr - rad)))
                    pygame.draw.circle(gs, (*gc, a), (gr + 4, gr + 4), rr)
                ms.blit(gs, (px - gr - 4, py - gr - 4))

            if is_clr:
                dark = tuple(max(0, c - 60) for c in bc)
                pygame.draw.circle(ms, dark, (px, py), rad)
                # 체크
                pygame.draw.line(ms, (100, 255, 100), (px - 8, py), (px - 2, py + 7), 3)
                pygame.draw.line(ms, (100, 255, 100), (px - 2, py + 7), (px + 10, py - 8), 3)
            else:
                pygame.draw.circle(ms, bc, (px, py), rad)
                hl = tuple(min(255, c + 60) for c in bc)
                pygame.draw.circle(ms, hl, (px - rad // 4, py - rad // 4), max(3, rad // 3))

            if rc and not is_clr:
                rw = int(rad * 2.2)
                rh = max(6, rad // 4)
                rsf = pygame.Surface((rw, rh), pygame.SRCALPHA)
                pygame.draw.ellipse(rsf, (*rc, 110), (0, 0, rw, rh), 2)
                ms.blit(rsf, (px - rw // 2, py - rh // 2))

            oc = gc if is_target else (55, 65, 85)
            pygame.draw.circle(ms, oc, (px, py), rad, 1)
            # 이름
            ns = self.font_sm.render(nm, True, (190, 200, 220))
            ms.blit(ns, ns.get_rect(center=(px, py + rad + 15)))
            ss = self.font_xs.render(f"Stage {pn}", True, (110, 120, 140))
            ms.blit(ss, ss.get_rect(center=(px, py + rad + 28)))

    # ──────────────────────────────────────────────────────
    #  메인 공개 API
    # ──────────────────────────────────────────────────────
    def show_travel_animation(self, from_planet, to_planet, cleared_planets=None):
        """
        시네마틱 우주 여행 애니메이션.
        Phase 1: 횡스크롤 비행 (왼→오)
        Phase 2: 목표 행성 접근 & 감속
        Phase 3: 도착 텍스트
        Phase 4: 줌아웃 → 탑뷰 은하 맵
        """
        if cleared_planets is None:
            cleared_planets = []

        target_cfg = PLANET_CONFIGS.get(to_planet, {})
        target_name = target_cfg.get("name", f"행성 {to_planet}")

        # ── Phase 1 설정: 횡스크롤 비행 ──
        FPS = 60
        PHASE1_SEC = 3.5
        PHASE1_FRAMES = int(PHASE1_SEC * FPS)
        # 우주선 시작 위치
        ship_start_x = -50.0
        ship_cruise_x = self.W * 0.30  # 크루즈 위치 (화면 30%)
        ship_y_base = self.H * 0.48

        # ── Phase 2 설정: 행성 접근 ──
        PHASE2_SEC = 2.0
        PHASE2_FRAMES = int(PHASE2_SEC * FPS)
        planet_start_x = self.W + 80  # 오른쪽 밖에서
        planet_end_x = self.W * 0.62
        planet_y = self.H * 0.45
        planet_radius_small = 10
        planet_radius_big = 60

        # ── Phase 3 설정: 도착 텍스트 ──
        PHASE3_SEC = 1.8
        PHASE3_FRAMES = int(PHASE3_SEC * FPS)

        # ── Phase 4 설정: 줌아웃 ──
        PHASE4_SEC = 1.5
        PHASE4_FRAMES = int(PHASE4_SEC * FPS)

        # 은하 맵 프리렌더
        self._render_galaxy_map(cleared_planets, to_planet)

        # ── 상태 ──
        phase = 1
        frame = 0
        total_frame = 0
        skipped = False

        while True:
            dt = self.clock.tick(FPS) / 1000.0
            self.time += dt
            total_frame += 1
            frame += 1

            if self._poll_skip():
                skipped = True
                break

            # 공통 배경
            self.screen.fill((3, 3, 12))

            # ════════════════════════════════════════
            #  Phase 1: 횡스크롤 비행
            # ════════════════════════════════════════
            if phase == 1:
                t = frame / PHASE1_FRAMES  # 0→1

                # 별 업데이트 & 그리기
                self._update_stars(self.stars_far, 1.0)
                self._update_stars(self.stars_mid, 1.0)
                self._update_stars(self.stars_near, 1.0)
                self._draw_stars_on(self.screen, self.stars_far)
                self._draw_stars_on(self.screen, self.stars_mid)
                self._draw_stars_on(self.screen, self.stars_near)

                # 장식 행성
                self._update_scroll_planets(1.0)
                for p in self.scroll_planets:
                    self._draw_scroll_planet(self.screen, p)

                # 속도 라인
                self._update_speed_lines(1.0)
                line_alpha = min(1.0, t * 3)  # 서서히 등장
                self._draw_speed_lines(self.screen, line_alpha)

                # 우주선 진입 (ease-out: 빠르게 들어와서 크루즈)
                ease = 1.0 - (1.0 - min(1.0, t * 2.0)) ** 3
                sx = ship_start_x + (ship_cruise_x - ship_start_x) * ease
                # 상하 부드러운 흔들림
                bobbing = math.sin(self.time * 2.5) * 8
                sy = ship_y_base + bobbing

                self._draw_ship_side(self.screen, sx, sy, 1.3)

                # "은하계 항해" 텍스트 (페이드인)
                txt_alpha = min(255, int(t * 4 * 255))
                ts = self.font_big.render("은하계 항해", True, (200, 210, 240))
                ts.set_alpha(txt_alpha)
                self.screen.blit(ts, ts.get_rect(center=(self.W // 2, 35)))

                # 하단 행성 이름 힌트
                if t > 0.4:
                    ha = min(255, int((t - 0.4) * 4 * 255))
                    hs = self.font_med.render(f"목표: {target_name}", True, target_cfg.get("glow_color", (200, 200, 200)))
                    hs.set_alpha(ha)
                    self.screen.blit(hs, hs.get_rect(center=(self.W // 2, self.H - 40)))

                pygame.display.flip()
                if frame >= PHASE1_FRAMES:
                    phase = 2
                    frame = 0

            # ════════════════════════════════════════
            #  Phase 2: 행성 접근 & 감속
            # ════════════════════════════════════════
            elif phase == 2:
                t = frame / PHASE2_FRAMES

                # 감속 효과 - 별/라인 속도 줄어듦
                slow = max(0.05, 1.0 - t * 0.9)
                self._update_stars(self.stars_far, slow)
                self._update_stars(self.stars_mid, slow)
                self._update_stars(self.stars_near, slow)
                self._draw_stars_on(self.screen, self.stars_far)
                self._draw_stars_on(self.screen, self.stars_mid)
                self._draw_stars_on(self.screen, self.stars_near)

                self._update_scroll_planets(slow)
                for p in self.scroll_planets:
                    self._draw_scroll_planet(self.screen, p)

                self._update_speed_lines(slow)
                self._draw_speed_lines(self.screen, max(0, 1.0 - t * 2))

                # 행성 진입 (오른쪽에서 + 점점 커짐)
                ease_p = t * t * (3 - 2 * t)  # smoothstep
                px = planet_start_x + (planet_end_x - planet_start_x) * ease_p
                pr = planet_radius_small + (planet_radius_big - planet_radius_small) * ease_p
                self._draw_destination_planet(self.screen, int(px), int(planet_y), int(pr), to_planet)

                # 우주선 감속
                ship_decel = max(0.0, 1.0 - t * 1.2)
                sx = ship_cruise_x - 30 * (1 - ship_decel)
                bobbing = math.sin(self.time * 2.5) * 8 * ship_decel
                sy = ship_y_base + bobbing
                ship_scale = max(0.8, 1.3 - t * 0.5)
                self._draw_ship_side(self.screen, sx, sy, ship_scale)

                # 타이틀
                ts = self.font_big.render("은하계 항해", True, (200, 210, 240))
                self.screen.blit(ts, ts.get_rect(center=(self.W // 2, 35)))

                # 행성 이름 (점점 밝아짐)
                na = min(255, int(t * 2 * 255))
                gc = target_cfg.get("glow_color", (200, 200, 200))
                ns = self.font_med.render(target_name, True, gc)
                ns.set_alpha(na)
                self.screen.blit(ns, ns.get_rect(center=(int(px), int(planet_y) + int(pr) + 25)))

                pygame.display.flip()
                if frame >= PHASE2_FRAMES:
                    phase = 3
                    frame = 0

            # ════════════════════════════════════════
            #  Phase 3: 도착 연출
            # ════════════════════════════════════════
            elif phase == 3:
                t = frame / PHASE3_FRAMES

                # 정지 상태 배경
                self._draw_stars_on(self.screen, self.stars_far)
                self._draw_stars_on(self.screen, self.stars_mid)

                # 행성 (중앙으로 이동 + 약간 더 커짐)
                px_final = planet_end_x + (self.W * 0.5 - planet_end_x) * min(1.0, t * 2)
                py_final = planet_y
                pr_final = planet_radius_big + 10 * min(1.0, t * 2)
                self._draw_destination_planet(self.screen, int(px_final), int(py_final), int(pr_final), to_planet)

                # 우주선 (행성 옆으로 이동)
                sx_arr = ship_cruise_x + (px_final - 80 - ship_cruise_x) * min(1.0, t * 3)
                self._draw_ship_side(self.screen, sx_arr, ship_y_base, 0.9)

                # "도착!" 텍스트
                arr_alpha = min(255, int(t * 3 * 255))
                arr_text = f"{target_name} 도착!"
                arr_s = self.font_big.render(arr_text, True, (255, 230, 150))
                arr_s.set_alpha(arr_alpha)
                self.screen.blit(arr_s, arr_s.get_rect(center=(self.W // 2, self.H * 0.72)))

                # 타이틀
                ts = self.font_big.render("은하계 항해", True, (200, 210, 240))
                self.screen.blit(ts, ts.get_rect(center=(self.W // 2, 35)))

                pygame.display.flip()
                if frame >= PHASE3_FRAMES:
                    phase = 4
                    frame = 0
                    # 은하 맵 최신 렌더링
                    self._render_galaxy_map(cleared_planets, to_planet)

            # ════════════════════════════════════════
            #  Phase 4: 줌아웃 → 탑뷰 은하 맵
            # ════════════════════════════════════════
            elif phase == 4:
                t = frame / PHASE4_FRAMES
                # ease-in-out
                et = t * t * (3 - 2 * t)

                # 이전 프레임 (도착 씬)을 축소하면서 은하 맵으로 전환
                # 줌아웃: 스케일 1.0 → 0.0, 은하맵 알파 0 → 255
                scene_alpha = max(0, int(255 * (1.0 - et * 1.5)))
                map_alpha = min(255, int(255 * et * 1.5))

                # 은하 맵 그리기
                self.screen.fill((3, 3, 12))
                map_copy = self.map_surface.copy()
                map_copy.set_alpha(map_alpha)
                self.screen.blit(map_copy, (0, 0))

                # 도착 씬 오버레이 (축소)
                if scene_alpha > 10:
                    zoom = max(0.1, 1.0 - et)
                    sw = int(self.W * zoom)
                    sh = int(self.H * zoom)
                    if sw > 10 and sh > 10:
                        # 목표 행성 위치를 중심으로 축소
                        tp_idx = to_planet - 1
                        if tp_idx < len(self.planet_positions):
                            tcx, tcy = self.planet_positions[tp_idx]
                        else:
                            tcx, tcy = self.W // 2, self.H // 2
                        zoom_surf = pygame.Surface((self.W, self.H), pygame.SRCALPHA)
                        zoom_surf.fill((3, 3, 12))
                        self._draw_destination_planet(zoom_surf, self.W // 2, self.H // 2, int(planet_radius_big * zoom), to_planet, scene_alpha)
                        scaled = pygame.transform.smoothscale(zoom_surf, (sw, sh))
                        scaled.set_alpha(scene_alpha)
                        ox = tcx - sw // 2
                        oy = tcy - sh // 2
                        self.screen.blit(scaled, (ox, oy))

                # 타이틀
                if map_alpha > 100:
                    ts = self.font_big.render("은하계 항해", True, (200, 210, 240))
                    ts.set_alpha(map_alpha)
                    self.screen.blit(ts, ts.get_rect(center=(self.W // 2, 35)))

                pygame.display.flip()
                if frame >= PHASE4_FRAMES:
                    break

        # 스킵 시에도 은하맵 한 프레임은 보여줌
        if skipped:
            self._render_galaxy_map(cleared_planets, to_planet)
            self.screen.blit(self.map_surface, (0, 0))
            ts = self.font_big.render("은하계 항해", True, (200, 210, 240))
            self.screen.blit(ts, ts.get_rect(center=(self.W // 2, 35)))
            pygame.display.flip()
            pygame.time.delay(300)

        pygame.event.clear()

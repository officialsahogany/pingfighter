"""
기묘한 약병 (Strange Vial) - 액티브 아이템
50% 확률로 거대화(패들 220% + 이속 -50%) 또는 축소(패들 -50% + 이속 +130%)
지속시간: 30초 (1800 프레임 @ 60fps)
"""
import random
import math
import pygame

# 상수
STRANGE_VIAL_DURATION_FRAMES = 1800  # 30초
STRANGE_VIAL_ENLARGE_PADDLE_MULT = 2.2   # 패들 220% (2.2배)
STRANGE_VIAL_ENLARGE_SPEED_MULT = 0.5    # 이속 -50% (50%만 적용)
STRANGE_VIAL_SHRINK_PADDLE_MULT = 0.5    # 패들 -50% (50%만 적용)
STRANGE_VIAL_SHRINK_SPEED_MULT = 2.3     # 이속 +130% (2.3배)

# 싱글톤 인스턴스
strange_vial_instance = None

# ─── 이펙트 색상 팔레트 ───
# 거대화: 연금술 에메랄드
_ENLARGE_COLORS = [
    (50, 220, 120),   # 에메랄드 그린
    (80, 255, 160),   # 밝은 민트
    (180, 255, 60),   # 라임
    (40, 180, 100),   # 다크 그린
]
# 축소화: 신비 바이올렛
_SHRINK_COLORS = [
    (180, 80, 255),   # 바이올렛
    (100, 200, 255),  # 시안
    (220, 160, 255),  # 라벤더
    (140, 120, 255),  # 퍼플 블루
]

# ─── 정다각형 꼭짓점 계산 (캐시) ───
_TWO_PI = math.pi * 2


def _polygon_points(cx, cy, radius, sides, rotation=0.0):
    """중심 (cx,cy) 기준 정다각형 꼭짓점 리스트 반환"""
    step = _TWO_PI / sides
    return [(cx + radius * math.cos(step * i + rotation),
             cy + radius * math.sin(step * i + rotation))
            for i in range(sides)]


class StrangeVial:
    def __init__(self):
        self.active = False
        self.timer = 0
        self.initial_timer = 0
        self.effect_type = None  # "enlarge" 또는 "shrink"
        self.paddle_multiplier = 1.0
        self.speed_multiplier = 1.0
        self._original_paddle_width = None
        self._original_player_speed = None
        # 이펙트 상태
        self._tick = 0
        self._geo_rings = []       # 기하학 링 (확장/수축하는 다각형)
        self._rune_particles = []  # 룬 파편 (떠다니는 기하학 조각)
        self._lattice_lines = []   # 격자 선분 (연결선)

    def activate(self, game_state=None, current_stage=None):
        """기묘한 약병 효과 발동 - 50% 확률로 거대화 또는 축소"""
        frames = STRANGE_VIAL_DURATION_FRAMES
        try:
            import academy
            caffeine_multiplier = academy.get_caffeine_duration_multiplier()
            frames = int(frames * caffeine_multiplier)
        except (ImportError, AttributeError):
            pass
        try:
            import pingfighter
            runtime_level = pingfighter.runtime_skill_levels.get("item_caffeine", 0)
            if runtime_level > 0:
                frames = int(frames * (1 + runtime_level * 0.25))
        except (ImportError, AttributeError):
            pass

        self.active = True
        self.timer = frames
        self.initial_timer = frames
        self._tick = 0
        self._geo_rings.clear()
        self._rune_particles.clear()
        self._lattice_lines.clear()

        if random.random() < 0.5:
            self.effect_type = "enlarge"
            self.paddle_multiplier = STRANGE_VIAL_ENLARGE_PADDLE_MULT
            self.speed_multiplier = STRANGE_VIAL_ENLARGE_SPEED_MULT
        else:
            self.effect_type = "shrink"
            self.paddle_multiplier = STRANGE_VIAL_SHRINK_PADDLE_MULT
            self.speed_multiplier = STRANGE_VIAL_SHRINK_SPEED_MULT

    def deactivate(self):
        self.active = False
        self.timer = 0
        self.initial_timer = 0
        self.effect_type = None
        self.paddle_multiplier = 1.0
        self.speed_multiplier = 1.0
        self._original_paddle_width = None
        self._original_player_speed = None
        self._geo_rings.clear()
        self._rune_particles.clear()
        self._lattice_lines.clear()

    def update(self, current_stage=None):
        if not self.active:
            return
        self.timer -= 1
        if self.timer <= 0:
            self.deactivate()

    def get_remaining_ratio(self):
        if not self.active or self.initial_timer <= 0:
            return 0.0
        return self.timer / self.initial_timer

    def get_paddle_multiplier(self):
        return self.paddle_multiplier if self.active else 1.0

    def get_speed_multiplier(self):
        return self.speed_multiplier if self.active else 1.0

    def is_enlarge(self):
        return self.active and self.effect_type == "enlarge"

    def is_shrink(self):
        return self.active and self.effect_type == "shrink"

    # ═══════════════════════════════════════════════════════
    #  기하학적 비주얼 이펙트 시스템
    # ═══════════════════════════════════════════════════════

    def draw_effects(self, screen, paddle_rect):
        """기묘한 약병 이펙트 렌더링"""
        if not self.active or paddle_rect is None:
            return

        self._tick += 1
        is_enlarge = (self.effect_type == "enlarge")
        colors = _ENLARGE_COLORS if is_enlarge else _SHRINK_COLORS
        cx, cy = paddle_rect.centerx, paddle_rect.centery

        # ── 1) 회전하는 기하학 링 (항상 표시) ──
        self._draw_rotating_geometry(screen, cx, cy, paddle_rect.width, colors, is_enlarge)
        # ── 2) 기하학 링 파티클 (확장/수축) ──
        self._spawn_geo_rings(cx, cy, paddle_rect.width, is_enlarge)
        self._update_draw_geo_rings(screen, colors, cx, cy, is_enlarge)
        # ── 3) 룬 파편 (떠다니는 작은 다각형 조각) ──
        self._spawn_rune_particles(cx, cy, paddle_rect.width, is_enlarge)
        self._update_draw_rune_particles(screen, colors, cx, cy, is_enlarge)
        # ── 4) 격자 연결선 ──
        self._draw_lattice_web(screen, cx, cy, paddle_rect.width, colors, is_enlarge)
        # ── 5) 패들 위 기하학 글로우 ──
        self._draw_geometric_glow(screen, paddle_rect, colors)

    # ── 회전하는 동심 다각형 + 연금술 문양 (핵심 비주얼) ──
    def _draw_rotating_geometry(self, screen, cx, cy, pw, colors, is_enlarge):
        """패들 중심에 회전하는 다중 다각형 + 꼭짓점 글로우 + 점선 원 + 나선"""
        t = self._tick
        base_r = max(pw * 0.45, 28)
        pulse = 0.5 + 0.5 * math.sin(t * 0.06)
        pulse2 = 0.5 + 0.5 * math.sin(t * 0.04 + 1.0)

        # ─ 배경: 점선 내접원 (연금술 서클) ─
        dashed_r = int(base_r * 0.95)
        dash_alpha = int(25 + 18 * pulse)
        num_dashes = 24
        dash_arc = _TWO_PI / num_dashes
        dashed_sz = dashed_r * 2 + 8
        if dashed_sz >= 8:
            dsurf = pygame.Surface((dashed_sz, dashed_sz), pygame.SRCALPHA)
            dc = dashed_sz // 2
            for i in range(num_dashes):
                if i % 2 == 0:
                    a1 = dash_arc * i + t * 0.008
                    a2 = a1 + dash_arc * 0.7
                    rect = pygame.Rect(dc - dashed_r, dc - dashed_r, dashed_r * 2, dashed_r * 2)
                    if rect.width > 0 and rect.height > 0:
                        pygame.draw.arc(dsurf, (*colors[1], dash_alpha), rect,
                                        a1, a2, 1)
            screen.blit(dsurf, (cx - dc, cy - dc))

        # ─ 점선 원 위 장식 점 (12개) ─
        dot_r_base = dashed_r + 1
        for i in range(12):
            angle = _TWO_PI / 12 * i + t * 0.008
            dx = cx + math.cos(angle) * dot_r_base
            dy = cy + math.sin(angle) * dot_r_base
            dot_bright = 0.5 + 0.5 * math.sin(t * 0.1 + i * 0.5)
            dot_a = int((20 + 25 * dot_bright) * (0.7 + 0.3 * pulse))
            if dot_a > 8:
                pygame.draw.circle(screen, (*colors[2], min(255, dot_a)),
                                   (int(dx), int(dy)), 2)

        # ─ 3겹 다각형 ─
        if is_enlarge:
            layers = [
                (6, base_r * 0.55, t * 0.025, colors[0]),
                (3, base_r * 0.82, -t * 0.018, colors[1]),
                (6, base_r * 1.12, t * 0.012, colors[2]),
            ]
        else:
            layers = [
                (5, base_r * 0.5, -t * 0.03, colors[0]),
                (8, base_r * 0.78, t * 0.02, colors[1]),
                (5, base_r * 1.08, -t * 0.013, colors[3]),
            ]

        all_vertices = []  # 꼭짓점 글로우용 수집
        for sides, radius, rot, color in layers:
            r = radius * (0.95 + 0.1 * pulse)
            alpha = int(55 + 45 * pulse)
            pts = _polygon_points(cx, cy, r, sides, rot)
            all_vertices.extend(pts)

            sz = int(r * 2 + 10)
            if sz < 4:
                continue
            surf = pygame.Surface((sz, sz), pygame.SRCALPHA)
            off = sz // 2
            local_pts = [(p[0] - cx + off, p[1] - cy + off) for p in pts]
            if len(local_pts) >= 3:
                pygame.draw.polygon(surf, (*color, alpha), local_pts, 1)
            screen.blit(surf, (cx - off, cy - off))

        # ─ 꼭짓점 글로우 (별처럼 빛남) ─
        for idx, (vx, vy) in enumerate(all_vertices):
            v_pulse = 0.4 + 0.6 * math.sin(t * 0.12 + idx * 0.7)
            v_alpha = int(50 * v_pulse + 30 * pulse)
            glow_size = int(4 + 3 * v_pulse)
            if v_alpha > 10 and glow_size > 1:
                gs = glow_size * 2 + 2
                gsurf = pygame.Surface((gs, gs), pygame.SRCALPHA)
                gc = gs // 2
                # 외곽 글로우
                pygame.draw.circle(gsurf, (*colors[0], int(v_alpha * 0.3)), (gc, gc), glow_size)
                # 코어
                pygame.draw.circle(gsurf, (255, 255, 255, int(v_alpha * 0.7)), (gc, gc),
                                   max(1, glow_size // 3))
                screen.blit(gsurf, (int(vx) - gc, int(vy) - gc))

        # ─ 나선형 연결선 (인접 레이어 꼭짓점 간 황금 나선) ─
        if len(all_vertices) > 6:
            spiral_alpha = int(18 + 14 * pulse2)
            spiral_color = colors[1] if is_enlarge else colors[2]
            # 레이어별 꼭짓점 수에 따라 인접 꼭짓점끼리 가느다란 선 연결
            layer_start = 0
            for sides, radius, rot, color in layers:
                r = radius * (0.95 + 0.1 * pulse)
                pts = _polygon_points(cx, cy, r, sides, rot)
                layer_end = layer_start + len(pts)
                # 현재 레이어 꼭짓점 → 다음 레이어 가장 가까운 꼭짓점 연결
                next_start = layer_end
                if next_start < len(all_vertices):
                    remaining = all_vertices[next_start:]
                    for pt in pts:
                        # 가장 가까운 것 1개만
                        best = None
                        best_d = 999999
                        for npt in remaining:
                            d = (pt[0] - npt[0]) ** 2 + (pt[1] - npt[1]) ** 2
                            if d < best_d:
                                best_d = d
                                best = npt
                        if best and best_d < 6000:
                            x1, y1 = int(pt[0]), int(pt[1])
                            x2, y2 = int(best[0]), int(best[1])
                            min_x = min(x1, x2) - 1
                            min_y = min(y1, y2) - 1
                            w = abs(x2 - x1) + 3
                            h = abs(y2 - y1) + 3
                            if w > 0 and h > 0:
                                lsurf = pygame.Surface((w, h), pygame.SRCALPHA)
                                pygame.draw.line(lsurf, (*spiral_color, spiral_alpha),
                                                 (x1 - min_x, y1 - min_y),
                                                 (x2 - min_x, y2 - min_y), 1)
                                screen.blit(lsurf, (min_x, min_y))
                layer_start = layer_end

        # ─ 중심 연금술 십자 ─
        cross_r = 5 + 2 * pulse
        cross_alpha = int(70 + 50 * pulse)
        cs = int(cross_r * 4) + 2
        cross_surf = pygame.Surface((cs, cs), pygame.SRCALPHA)
        cc = cs // 2
        cr = int(cross_r)
        # 십자
        pygame.draw.line(cross_surf, (*colors[0], cross_alpha), (cc - cr, cc), (cc + cr, cc), 1)
        pygame.draw.line(cross_surf, (*colors[0], cross_alpha), (cc, cc - cr), (cc, cc + cr), 1)
        # 대각선 (더 희미한)
        diag_a = int(cross_alpha * 0.4)
        dr = int(cr * 0.7)
        pygame.draw.line(cross_surf, (*colors[2], diag_a), (cc - dr, cc - dr), (cc + dr, cc + dr), 1)
        pygame.draw.line(cross_surf, (*colors[2], diag_a), (cc + dr, cc - dr), (cc - dr, cc + dr), 1)
        # 중심 코어 점
        pygame.draw.circle(cross_surf, (255, 255, 255, int(cross_alpha * 0.8)), (cc, cc), 2)
        screen.blit(cross_surf, (cx - cc, cy - cc))

    # ── 확장/수축하는 기하학 링 ──
    def _spawn_geo_rings(self, cx, cy, pw, is_enlarge):
        if self._tick % 22 == 0:
            sides = random.choice([3, 4, 6]) if is_enlarge else random.choice([5, 7, 8])
            self._geo_rings.append({
                'sides': sides,
                'r': 8.0 if is_enlarge else pw * 0.6,
                'rot': random.uniform(0, _TWO_PI),
                'rot_speed': random.uniform(-0.04, 0.04),
                'life': 0,
                'max_life': 40,
            })
            if len(self._geo_rings) > 8:
                self._geo_rings.pop(0)

    def _update_draw_geo_rings(self, screen, colors, cx, cy, is_enlarge):
        for ring in self._geo_rings[:]:
            ring['life'] += 1
            if ring['life'] >= ring['max_life']:
                self._geo_rings.remove(ring)
                continue

            p = ring['life'] / ring['max_life']
            ring['rot'] += ring['rot_speed']

            if is_enlarge:
                # 안에서 밖으로 확장
                r = 8 + p * 55
            else:
                # 밖에서 안으로 수축
                r = 55 * (1.0 - p) + 5

            # 페이드: 중간에 가장 밝고 양끝에서 투명
            fade = 1.0 - abs(p - 0.4) / 0.6
            fade = max(0.0, min(1.0, fade))
            alpha = int(100 * fade)
            thickness = 1 if p > 0.5 else 2

            color = colors[ring['sides'] % len(colors)]
            pts = _polygon_points(cx, cy, r, ring['sides'], ring['rot'])

            sz = int(r * 2 + 8)
            if sz < 4:
                continue
            surf = pygame.Surface((sz, sz), pygame.SRCALPHA)
            off = sz // 2
            local_pts = [(pt[0] - cx + off, pt[1] - cy + off) for pt in pts]
            if len(local_pts) >= 3:
                pygame.draw.polygon(surf, (*color, alpha), local_pts, thickness)
                # 꼭짓점에 작은 점
                for lp in local_pts:
                    if alpha > 30:
                        pygame.draw.circle(surf, (*color, min(255, alpha + 40)),
                                           (int(lp[0]), int(lp[1])), 2)
            screen.blit(surf, (cx - off, cy - off))

    # ── 룬 파편 (떠다니는 미니 도형) ──
    def _spawn_rune_particles(self, cx, cy, pw, is_enlarge):
        if random.random() < 0.18:
            hw = pw // 2
            if is_enlarge:
                # 패들 위에서 위로 떠오름
                sx = cx + random.randint(-hw, hw)
                sy = cy + random.randint(-6, 6)
                vy = random.uniform(-1.8, -0.6)
                vx = random.uniform(-0.4, 0.4)
            else:
                # 먼 곳에서 패들로 수렴
                angle = random.uniform(0, _TWO_PI)
                dist = random.uniform(50, 80)
                sx = cx + math.cos(angle) * dist
                sy = cy + math.sin(angle) * dist * 0.5
                dx, dy = cx - sx, cy - sy
                mag = max(1.0, math.hypot(dx, dy))
                speed = random.uniform(1.2, 2.2)
                vx = dx / mag * speed
                vy = dy / mag * speed

            self._rune_particles.append({
                'x': sx, 'y': sy, 'vx': vx, 'vy': vy,
                'sides': random.choice([3, 4, 5, 6]),
                'size': random.uniform(3, 7),
                'rot': random.uniform(0, _TWO_PI),
                'rot_speed': random.uniform(-0.1, 0.1),
                'life': random.randint(30, 55),
                'max_life': 55,
            })
            if len(self._rune_particles) > 25:
                self._rune_particles.pop(0)

    def _update_draw_rune_particles(self, screen, colors, cx, cy, is_enlarge):
        for rp in self._rune_particles[:]:
            rp['life'] -= 1
            if rp['life'] <= 0:
                self._rune_particles.remove(rp)
                continue

            rp['x'] += rp['vx']
            rp['y'] += rp['vy']
            rp['rot'] += rp['rot_speed']

            if not is_enlarge:
                # 수렴 가속
                dx, dy = cx - rp['x'], cy - rp['y']
                mag = max(1.0, math.hypot(dx, dy))
                rp['vx'] += dx / mag * 0.06
                rp['vy'] += dy / mag * 0.06

            ratio = rp['life'] / rp['max_life']
            alpha = int(160 * ratio)
            sz = max(2, int(rp['size'] * (0.6 + 0.4 * ratio)))
            color = colors[rp['sides'] % len(colors)]

            pts = _polygon_points(rp['x'], rp['y'], sz, rp['sides'], rp['rot'])

            # 글로우 후광
            glow_sz = sz + 5
            gs = int(glow_sz * 2 + 4)
            if gs >= 4:
                glow_surf = pygame.Surface((gs, gs), pygame.SRCALPHA)
                gc = gs // 2
                pygame.draw.circle(glow_surf, (*color, int(alpha * 0.15)), (gc, gc), int(glow_sz))
                screen.blit(glow_surf, (int(rp['x']) - gc, int(rp['y']) - gc))

            # 다각형 본체
            bsz = sz * 2 + 6
            ibsz = int(bsz)
            if ibsz >= 4:
                surf = pygame.Surface((ibsz, ibsz), pygame.SRCALPHA)
                off = ibsz // 2
                local_pts = [(p[0] - rp['x'] + off, p[1] - rp['y'] + off) for p in pts]
                if len(local_pts) >= 3:
                    pygame.draw.polygon(surf, (*color, alpha), local_pts, 1)
                screen.blit(surf, (int(rp['x']) - off, int(rp['y']) - off))

    # ── 격자 연결선 (룬 파편 사이 연결) ──
    def _draw_lattice_web(self, screen, cx, cy, pw, colors, is_enlarge):
        """가까운 룬 파편 사이에 얇은 연결선을 그려 기하학 격자 느낌"""
        particles = self._rune_particles
        if len(particles) < 2:
            return

        connect_dist = 60
        t = self._tick
        color = colors[1]
        pulse = 0.5 + 0.5 * math.sin(t * 0.05)
        base_alpha = int(25 + 20 * pulse)

        # 가장 가까운 쌍만 최대 6개 연결 (성능)
        drawn = 0
        for i in range(len(particles)):
            if drawn >= 6:
                break
            for j in range(i + 1, len(particles)):
                dx = particles[i]['x'] - particles[j]['x']
                dy = particles[i]['y'] - particles[j]['y']
                dist = math.hypot(dx, dy)
                if dist < connect_dist and dist > 5:
                    fade = 1.0 - dist / connect_dist
                    alpha = int(base_alpha * fade)
                    if alpha > 5:
                        x1, y1 = int(particles[i]['x']), int(particles[i]['y'])
                        x2, y2 = int(particles[j]['x']), int(particles[j]['y'])
                        # 경계 계산
                        min_x = min(x1, x2) - 2
                        min_y = min(y1, y2) - 2
                        w = abs(x2 - x1) + 4
                        h = abs(y2 - y1) + 4
                        if w > 0 and h > 0:
                            lsurf = pygame.Surface((w, h), pygame.SRCALPHA)
                            pygame.draw.line(lsurf, (*color, alpha),
                                             (x1 - min_x, y1 - min_y),
                                             (x2 - min_x, y2 - min_y), 1)
                            screen.blit(lsurf, (min_x, min_y))
                    drawn += 1

    # ── 패들 기하학 글로우 ──
    def _draw_geometric_glow(self, screen, pr, colors):
        """패들 주변 이중 육각형 글로우 + 호흡하는 빛"""
        t = self._tick
        pulse = 0.5 + 0.5 * math.sin(t * 0.07)
        color = colors[0]
        cx, cy = pr.centerx, pr.centery

        # 외곽 가로형 육각형 (패들보다 넓음)
        hw = pr.width // 2 + 14
        hh = pr.height // 2 + 10
        alpha = int(28 + 22 * pulse)
        hex_pts_outer = [
            (cx - hw, cy), (cx - hw * 0.5, cy - hh),
            (cx + hw * 0.5, cy - hh), (cx + hw, cy),
            (cx + hw * 0.5, cy + hh), (cx - hw * 0.5, cy + hh),
        ]
        sz_w = hw * 2 + 6
        sz_h = hh * 2 + 6
        if sz_w > 4 and sz_h > 4:
            surf = pygame.Surface((int(sz_w), int(sz_h)), pygame.SRCALPHA)
            off_x = cx - hw - 3
            off_y = cy - hh - 3
            local_hex = [(p[0] - off_x, p[1] - off_y) for p in hex_pts_outer]
            pygame.draw.polygon(surf, (*color, alpha), local_hex, 1)

            # 내접 육각형 (더 작고 더 밝은)
            hw2 = pr.width // 2 + 5
            hh2 = pr.height // 2 + 4
            alpha2 = int(18 + 16 * pulse)
            hex_pts_inner = [
                (cx - hw2, cy), (cx - hw2 * 0.5, cy - hh2),
                (cx + hw2 * 0.5, cy - hh2), (cx + hw2, cy),
                (cx + hw2 * 0.5, cy + hh2), (cx - hw2 * 0.5, cy + hh2),
            ]
            local_hex2 = [(p[0] - off_x, p[1] - off_y) for p in hex_pts_inner]
            pygame.draw.polygon(surf, (*colors[2], alpha2), local_hex2, 1)

            # 중앙 수평 가이드 라인 (초미세)
            guide_alpha = int(12 + 10 * pulse)
            mid_y = int(cy - off_y)
            pygame.draw.line(surf, (*colors[1], guide_alpha),
                             (int(cx - hw - off_x), mid_y),
                             (int(cx + hw - off_x), mid_y), 1)

            screen.blit(surf, (int(off_x), int(off_y)))


# ═══════════════════════════════════════════════════════
#  모듈 API
# ═══════════════════════════════════════════════════════

def get_strange_vial_instance():
    global strange_vial_instance
    if strange_vial_instance is None:
        strange_vial_instance = StrangeVial()
    return strange_vial_instance


def activate_strange_vial(game_state=None, current_stage=None):
    vial = get_strange_vial_instance()
    vial.activate(game_state, current_stage)
    return True


def deactivate_strange_vial():
    vial = get_strange_vial_instance()
    vial.deactivate()


def update_strange_vial(current_stage=None):
    vial = get_strange_vial_instance()
    vial.update(current_stage)


def draw_strange_vial_effects(screen, paddle_rect):
    """기묘한 약병 이펙트 그리기 (pingfighter.py에서 호출)

    pingfighter.py는 자체 전역 변수(strange_vial_active/effect_type)로 상태를 관리하므로,
    모듈 인스턴스의 active/effect_type을 pingfighter 전역 상태와 동기화한다.
    """
    vial = get_strange_vial_instance()
    try:
        import pingfighter as _pf
        vial.active = getattr(_pf, 'strange_vial_active', False)
        vial.effect_type = getattr(_pf, 'strange_vial_effect_type', None)
        vial.timer = getattr(_pf, 'strange_vial_timer', 0)
        vial.initial_timer = getattr(_pf, 'strange_vial_initial_timer', 0)
    except (ImportError, AttributeError):
        pass
    vial.draw_effects(screen, paddle_rect)

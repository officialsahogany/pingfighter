# -*- coding: utf-8 -*-
"""
아라크네 (Arachne) 프로시저럴 보스 스프라이트
고퀄리티 리얼리스틱 절지동물 — 4마디 다리, gait cycle, 고대비 복부 무늬
- MolewangBossSprite와 동일한 인터페이스
"""

import pygame
import math
import random

_sin = math.sin
_cos = math.cos
_pi = math.pi
_TAU = math.pi * 2


def _lerp(a, b, t):
    return a + (b - a) * t


def _smoothstep(t):
    """0→1 부드러운 가속/감속"""
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


class SpiderBossSprite:
    """아라크네 프로시저럴 보스 스프라이트"""

    # 각 다리 쌍의 기본 좌표 (w,h 비율)
    # (hip_dx, hip_dy, knee_dx, knee_dy, foot_dx, foot_dy)
    _LEG_TEMPLATES = [
        # 1쌍 (앞, 전방 대각선) — 가장 길다, 발차기 담당
        (0.09, -0.035,   0.30, -0.19,   0.35, 0.13),
        # 2쌍 (옆으로)
        (0.09, -0.005,   0.33, -0.10,   0.37, 0.22),
        # 3쌍 (약간 뒤쪽)
        (0.09,  0.025,   0.31, -0.01,   0.34, 0.32),
        # 4쌍 (뒤, 후방 대각선)
        (0.09,  0.050,   0.25,  0.07,   0.27, 0.39),
    ]

    # Swing 비율 (40% swing, 60% stance — 실제 거미에 가까움)
    _SWING_RATIO = 0.40

    def __init__(self):
        self.direction = 0
        self.prev_x = 0.0
        self.time = 0.0

        self.step_phase = 0.0
        self.body_bob = 0.0
        self.body_sway = 0.0
        self.velocity = 0.0

        self.direction_change_cooldown = 0.0
        self.direction_change_threshold = 0.15
        self.movement_accumulator = 0.0

        # 히트/발차기
        self.is_hit = False
        self.hit_timer = 0.0
        self.hit_duration = 0.45
        self.hit_direction = 1
        self.hit_intensity = 0.0

        # 교대 보행 — tetrapod gait + 순차 파동
        # 그룹A: L1→R2→L3→R4 (앞에서 뒤로 순차)
        # 그룹B: R1→L2→R3→L4 (0.5 위상차로 같은 순차)
        # idx: 0=L1, 1=R1, 2=L2, 3=R2, 4=L3, 5=R3, 6=L4, 7=R4
        self._leg_phase_offsets = [
            0.00,   # idx0: L1 — 그룹A 첫번째
            0.50,   # idx1: R1 — 그룹B 첫번째
            0.58,   # idx2: L2 — 그룹B 두번째
            0.08,   # idx3: R2 — 그룹A 두번째
            0.16,   # idx4: L3 — 그룹A 세번째
            0.66,   # idx5: R3 — 그룹B 세번째
            0.74,   # idx6: L4 — 그룹B 네번째
            0.24,   # idx7: R4 — 그룹A 네번째
        ]
        # 순차 지연은 오프셋에 이미 포함됨
        self._leg_pair_delay = [0.0, 0.0, 0.0, 0.0]

        # 미세 떨림
        self._leg_twitch = [0.0] * 8
        self._leg_twitch_timer = [random.uniform(0, 5) for _ in range(8)]

        # 랜덤 시드 (체모/강모 흔들림)
        self._hair_seeds = [random.uniform(0, 10) for _ in range(50)]

        # 독액 파티클 시스템 (히트 시 독아 주변에서 분사)
        self._venom_particles = []  # [(x, y, vx, vy, life, max_life, size)]

        # 체모 관성 (이동 방향에 따른 지연 효과)
        self._hair_inertia = 0.0  # -1.0 ~ 1.0, direction 기반 관성값

        # Dirty Flag 캐싱
        self._cached_frame = None
        self._cached_size = (0, 0)
        self._cache_dirty = True
        self._idle_frame_count = 0  # 정지 상태 프레임 카운터

    # ===================================================================
    #  업데이트
    # ===================================================================

    def update(self, current_x, dt=1/60):
        self.time += dt
        dx = current_x - self.prev_x

        if self.direction_change_cooldown > 0:
            self.direction_change_cooldown -= dt

        if abs(dx) > 2.0:
            new_dir = 1 if dx > 0 else -1
            self.movement_accumulator += dx
            if new_dir != self.direction and self.direction_change_cooldown <= 0:
                if abs(self.movement_accumulator) > 5.0:
                    self.direction = new_dir
                    self.direction_change_cooldown = self.direction_change_threshold
                    self.movement_accumulator = 0.0
            elif new_dir == self.direction:
                self.movement_accumulator = 0.0
        else:
            self.movement_accumulator *= 0.9
            if abs(self.movement_accumulator) < 1.0:
                self.direction = 0

        self.velocity = abs(dx) / max(dt, 0.001)

        if self.direction != 0:
            sp = min(self.velocity / 80.0, 2.0)
            # 비선형 가속: 저속은 느릿느릿, 고속은 폭발적 (거미 특유의 툭툭 끊기는 보행)
            acceleration_curve = math.pow(sp, 1.2)
            self.step_phase += dt * 6.0 * max(acceleration_curve, 0.4)
            self.body_bob = _sin(self.step_phase * _TAU * 0.5) * 0.025 * sp
            # 좌우 흔들림 (다리 짚음에 맞춰 약간 더 크게)
            self.body_sway = _sin(self.step_phase * _TAU * 0.25) * 0.020 * sp
        else:
            self.step_phase *= 0.95
            self.body_bob = _sin(self.time * 2.5) * 0.006
            self.body_sway *= 0.92

        if self.is_hit:
            self.hit_timer += dt
            if self.hit_timer / self.hit_duration >= 1.0:
                self.is_hit = False
                self.hit_timer = 0.0
                self.hit_intensity = 0.0
            else:
                self.hit_intensity = max(0, 1.0 - (self.hit_timer / self.hit_duration) * 1.5)

        for i in range(8):
            self._leg_twitch_timer[i] += dt
            if self.direction == 0:
                self._leg_twitch[i] = _sin(
                    self._leg_twitch_timer[i] * (2.0 + i * 0.4)) * 0.02
            else:
                self._leg_twitch[i] *= 0.88

        # 체모 관성 업데이트 (이동 방향에 부드럽게 추종)
        target_inertia = self.direction * min(self.velocity / 100.0, 1.0)
        self._hair_inertia += (target_inertia - self._hair_inertia) * 0.08
        self._hair_inertia *= 0.95  # 감쇠

        # 독액 파티클 업데이트
        alive = []
        for px, py, vx, vy, life, max_life, size in self._venom_particles:
            life -= dt
            if life > 0:
                px += vx * dt
                py += vy * dt
                vy += 120.0 * dt  # 중력
                alive.append((px, py, vx, vy, life, max_life, size))
        self._venom_particles = alive

        # Dirty Flag: 정지+비히트 상태에서 캐시 카운터 증가
        if self.direction == 0 and not self.is_hit and len(self._venom_particles) == 0:
            self._idle_frame_count += 1
        else:
            self._idle_frame_count = 0
            self._cache_dirty = True

        self.prev_x = current_x

    def trigger_hit(self, ball_x, boss_x):
        self.is_hit = True
        self.hit_timer = 0.0
        self.hit_intensity = 1.0
        self.hit_direction = 1 if ball_x > boss_x else -1
        # 독액 파티클 분사 (독아 부근에서 6~10개)
        for _ in range(random.randint(6, 10)):
            angle = random.uniform(-0.8, 0.8) + _pi * 0.5  # 아래쪽으로
            speed = random.uniform(40, 120)
            self._venom_particles.append((
                0.0, 0.0,                       # x, y (렌더링 시 독아 기준으로 오프셋)
                _cos(angle) * speed + self.hit_direction * 30,
                _sin(angle) * speed,
                random.uniform(0.25, 0.55),     # life
                0.55,                            # max_life
                random.uniform(1.2, 2.8),        # size
            ))

    # ===================================================================
    #  프레임 생성
    # ===================================================================

    def get_current_frame(self, scale_size=None):
        w, h = scale_size or (160, 160)
        w, h = max(20, int(w)), max(20, int(h))

        # Dirty Flag 캐싱: 정지+비히트+파티클 없음 → 4프레임마다만 갱신
        if (not self._cache_dirty
                and self._cached_frame is not None
                and self._cached_size == (w, h)
                and self._idle_frame_count > 4):
            return self._cached_frame

        surface = pygame.Surface((w, h), pygame.SRCALPHA)
        self._draw_character(surface, w, h)

        # 캐시 저장
        self._cached_frame = surface
        self._cached_size = (w, h)
        self._cache_dirty = False

        return surface

    def draw(self, surface, x, y, width=None, height=None, center=True):
        frame = self.get_current_frame((width, height) if width and height else None)
        if frame:
            if center:
                rect = frame.get_rect(center=(int(x), int(y)))
            else:
                rect = frame.get_rect(topleft=(int(x), int(y)))
            surface.blit(frame, rect)

    # ===================================================================
    #  메인 렌더링
    # ===================================================================

    def _draw_character(self, surface, w, h):
        bob = self.body_bob * h
        sway = self.body_sway * w
        p = self._get_palette(self.hit_intensity * 0.22 if self.is_hit else 0.0)

        bcx = int(w * 0.50 + sway)
        bcy = int(h * 0.36 + bob)

        # 레이어: 뒷다리 → 복부 → 페디셀 → 두흉부 → 앞다리 → 눈/독아/더듬이 → 체모 → 독액
        self._draw_legs(surface, bcx, bcy, w, h, p, back=True)
        self._draw_abdomen(surface, bcx, bcy, w, h, p)
        self._draw_pedicel(surface, bcx, bcy, w, h, p)
        self._draw_cephalothorax(surface, bcx, bcy, w, h, p)
        self._draw_legs(surface, bcx, bcy, w, h, p, back=False)
        self._draw_eyes(surface, bcx, bcy, w, h, p)
        self._draw_chelicerae(surface, bcx, bcy, w, h, p)
        self._draw_pedipalps(surface, bcx, bcy, w, h, p)
        self._draw_body_hair(surface, bcx, bcy, w, h, p)
        self._draw_venom_particles(surface, bcx, bcy, w, h)

    def _get_palette(self, flash=0.0):
        def _f(base):
            return tuple(min(255, int(c + (255 - c) * flash)) for c in base)
        return {
            "body_dark": _f((22, 15, 12)),
            "body": _f((40, 28, 22)),
            "body_mid": _f((52, 38, 30)),
            "body_light": _f((68, 50, 40)),
            "body_edge": _f((14, 10, 7)),
            "abd": _f((32, 24, 18)),
            "abd_dark": _f((18, 13, 10)),
            "abd_sheen": _f((80, 62, 50)),
            # 복부 무늬 — 밝은 주황/크림 (고대비)
            "abd_mark": _f((185, 120, 55)),
            "abd_mark2": _f((210, 145, 60)),
            "abd_dot": _f((160, 105, 45)),
            # 눈
            "eye": _f((6, 4, 4)),
            "eye_glow": _f((125, 32, 20)),
            "eye_shine": _f((235, 220, 200)),
            "eye2": _f((20, 12, 10)),
            # 독아
            "fang": _f((110, 30, 22)),
            "fang_tip": _f((195, 50, 30)),
            "fang_dark": _f((60, 18, 13)),
            # 다리
            "leg_base": _f((58, 32, 24)),
            "leg_mid": _f((48, 28, 20)),
            "leg_dark": _f((30, 18, 13)),
            "leg_light": _f((78, 52, 40)),
            "leg_band": _f((38, 22, 16)),
            "leg_joint": _f((70, 44, 32)),
            # 기타
            "hair": _f((48, 30, 22)),
            "hair_l": _f((62, 42, 32)),
            "pedi": _f((54, 34, 26)),
        }

    # ===================================================================
    #  복부 — 고대비 무늬 + 텍스처
    # ===================================================================

    def _draw_abdomen(self, surface, bcx, bcy, w, h, p):
        cx = bcx
        cy = int(bcy + h * 0.14)
        aw = int(w * 0.32)
        ah = int(h * 0.28)

        # 그림자
        pygame.draw.ellipse(surface, p["abd_dark"],
                           (cx - aw // 2 + 2, cy - ah // 2 + 2, aw, ah))
        # 본체
        pygame.draw.ellipse(surface, p["abd"],
                           (cx - aw // 2, cy - ah // 2, aw, ah))

        # ===== 무늬: 중앙 세로 줄 + 셰브론 3개 + 측면 점 =====

        # 중앙 세로줄 (등 중앙선)
        stripe_w = max(2, int(w * 0.012))
        s_top = cy - int(ah * 0.35)
        s_bot = cy + int(ah * 0.30)
        stripe_surf = pygame.Surface((stripe_w + 2, s_bot - s_top + 2), pygame.SRCALPHA)
        pygame.draw.line(stripe_surf, (*p["abd_mark"], 140),
                        (stripe_w // 2 + 1, 0),
                        (stripe_w // 2 + 1, s_bot - s_top),
                        stripe_w)
        surface.blit(stripe_surf, (cx - stripe_w // 2 - 1, s_top))

        # 셰브론 V무늬 3개 (밝은 크림/주황색)
        for i in range(3):
            vy = cy - int(ah * 0.22) + int(i * ah * 0.24)
            vw = int(aw * (0.50 - i * 0.07))
            thickness = max(2, int(w * 0.012))
            v_depth = int(h * 0.020)

            left_pts = [(cx, vy + v_depth), (cx - vw // 2, vy)]
            right_pts = [(cx, vy + v_depth), (cx + vw // 2, vy)]

            col = p["abd_mark"] if i % 2 == 0 else p["abd_mark2"]
            pygame.draw.line(surface, col, left_pts[0], left_pts[1], thickness)
            pygame.draw.line(surface, col, right_pts[0], right_pts[1], thickness)

        # 측면 점 4쌍 (좌우 대칭)
        for i in range(4):
            dy = cy - int(ah * 0.25) + int(i * ah * 0.18)
            dx_off = int(aw * (0.30 - i * 0.02))
            dot_r = max(1, int(w * 0.010))
            for side in [-1, 1]:
                dot_x = cx + side * dx_off
                pygame.draw.circle(surface, p["abd_dot"], (dot_x, dy), dot_r)

        # 키틴질 광택 (부드러운 큰 영역)
        hl_w = max(5, int(aw * 0.45))
        hl_h = max(4, int(ah * 0.30))
        hl_surf = pygame.Surface((hl_w, hl_h), pygame.SRCALPHA)
        pygame.draw.ellipse(hl_surf, (*p["abd_sheen"], 35),
                           (0, 0, hl_w, hl_h))
        surface.blit(hl_surf,
                    (cx - hl_w // 2 - int(w * 0.03),
                     cy - hl_h // 2 - int(h * 0.07)))

        # 핀포인트 하이라이트
        hl2_r = max(2, int(aw * 0.06))
        hl2_surf = pygame.Surface((hl2_r * 2, hl2_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(hl2_surf, (*p["body_light"], 50),
                          (hl2_r, hl2_r), hl2_r)
        surface.blit(hl2_surf,
                    (cx - hl2_r + int(w * 0.015),
                     cy - hl2_r - int(h * 0.08)))

        # 테두리
        pygame.draw.ellipse(surface, p["body_edge"],
                           (cx - aw // 2, cy - ah // 2, aw, ah),
                           max(1, int(w * 0.010)))

    # ===================================================================
    #  페디셀 (허리)
    # ===================================================================

    def _draw_pedicel(self, surface, bcx, bcy, w, h, p):
        py_ = int(bcy + h * 0.035)
        pw = max(4, int(w * 0.050))
        ph = max(4, int(h * 0.050))
        pygame.draw.ellipse(surface, p["body_dark"],
                           (bcx - pw // 2, py_ - ph // 2, pw, ph))
        # 미세 하이라이트
        pygame.draw.ellipse(surface, (*p["body_mid"][:3], 60),
                           (bcx - pw // 4, py_ - ph // 4, pw // 2, ph // 2))

    # ===================================================================
    #  두흉부
    # ===================================================================

    def _draw_cephalothorax(self, surface, bcx, bcy, w, h, p):
        cx = bcx
        cy = int(bcy - h * 0.04)
        cw = int(w * 0.22)
        ch = int(h * 0.15)

        # 그림자
        pygame.draw.ellipse(surface, p["body_dark"],
                           (cx - cw // 2 + 1, cy - ch // 2 + 1, cw, ch))
        # 본체
        pygame.draw.ellipse(surface, p["body"],
                           (cx - cw // 2, cy - ch // 2, cw, ch))

        # 방사 홈 (fovea + 4줄)
        fov_len = int(h * 0.04)
        pygame.draw.line(surface, p["body_dark"],
                        (cx, cy - int(h * 0.005)),
                        (cx, cy + fov_len),
                        max(1, int(w * 0.008)))
        for side in [-1, 1]:
            pygame.draw.line(surface, (*p["body_dark"][:3], 70),
                            (cx + side * int(cw * 0.1), cy - int(ch * 0.05)),
                            (cx + side * int(cw * 0.4), cy + int(ch * 0.2)),
                            1)

        # 광택
        hl_r = max(2, int(cw * 0.20))
        hl_s = pygame.Surface((hl_r * 2, hl_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(hl_s, (*p["body_light"], 45), (hl_r, hl_r), hl_r)
        surface.blit(hl_s, (cx - hl_r - int(w * 0.012),
                            cy - hl_r - int(h * 0.018)))

        # 테두리
        pygame.draw.ellipse(surface, p["body_edge"],
                           (cx - cw // 2, cy - ch // 2, cw, ch),
                           max(1, int(w * 0.008)))

    # ===================================================================
    #  눈 8개
    # ===================================================================

    def _draw_eyes(self, surface, bcx, bcy, w, h, p):
        cy = int(bcy - h * 0.04)

        # 주눈 AME 2개
        for side in [-1, 1]:
            ex = bcx + side * int(w * 0.032)
            ey = cy - int(h * 0.026)
            er = max(2, int(w * 0.026))
            pygame.draw.circle(surface, p["body_edge"], (ex, ey), er + 1)
            pygame.draw.circle(surface, p["eye"], (ex, ey), er)
            pygame.draw.circle(surface, p["eye_glow"], (ex, ey), max(1, er - 1))
            pygame.draw.circle(surface, p["eye"], (ex, ey), max(1, er - 2))
            sr = max(1, int(er * 0.38))
            pygame.draw.circle(surface, p["eye_shine"], (ex - 1, ey - 1), sr)
            if er > 3:
                pygame.draw.circle(surface, (*p["eye_shine"][:3], 130),
                                  (ex + int(er * 0.2), ey + int(er * 0.35)),
                                  max(1, sr - 1))

        # 보조눈 6개
        for sx, sy, sm in [
            (-0.054, -0.010, 0.75), (0.054, -0.010, 0.75),
            (-0.064, 0.008, 0.60), (0.064, 0.008, 0.60),
            (-0.038, 0.017, 0.55), (0.038, 0.017, 0.55),
        ]:
            ex = bcx + int(sx * w)
            ey = cy + int(sy * h) - int(h * 0.010)
            er = max(1, int(w * 0.014 * sm / 0.6))
            pygame.draw.circle(surface, p["body_edge"], (ex, ey), er + 1)
            pygame.draw.circle(surface, p["eye2"], (ex, ey), er)
            pygame.draw.circle(surface, p["eye_shine"], (ex, ey - 1), max(1, er // 2))

    # ===================================================================
    #  독아
    # ===================================================================

    def _draw_chelicerae(self, surface, bcx, bcy, w, h, p):
        cy = int(bcy - h * 0.04)
        base_y = cy + int(h * 0.054)

        spread = 0.0
        flash = 0
        if self.is_hit:
            prog = self.hit_timer / self.hit_duration
            if prog < 0.20:
                spread = w * 0.024 * (prog / 0.20)
                flash = int(180 * (1.0 - prog / 0.20))
            else:
                spread = w * 0.024 * max(0, 1.0 - (prog - 0.20) / 0.25)

        for side in [-1, 1]:
            bx = bcx + side * int(w * 0.026 + spread)
            by = base_y
            mx = bx + side * int(w * 0.030)
            my = by + int(h * 0.045)
            tx = bx + side * int(w * 0.022)
            ty = by + int(h * 0.078)

            fw = max(2, int(w * 0.020))
            pygame.draw.line(surface, p["fang_dark"],
                            (bx + 1, by + 1), (mx + 1, my + 1), fw + 2)
            pygame.draw.line(surface, p["fang"],
                            (bx, by), (mx, my), fw + 1)
            pygame.draw.line(surface, p["fang_dark"],
                            (mx + 1, my + 1), (tx + 1, ty + 1), max(1, fw))
            pygame.draw.line(surface, p["fang"],
                            (mx, my), (tx, ty), max(1, fw - 1))
            pygame.draw.circle(surface, p["fang_tip"],
                              (tx, ty), max(2, int(w * 0.010)))

            if flash > 0:
                fsw, fsh = fw * 5, int(h * 0.09)
                if fsw > 0 and fsh > 0:
                    fs = pygame.Surface((fsw, fsh), pygame.SRCALPHA)
                    pygame.draw.line(fs, (255, 110, 85, flash),
                                    (fsw // 2, 0), (fsw // 2, fsh), fw + 2)
                    surface.blit(fs, (bx - fsw // 2, by))

    # ===================================================================
    #  더듬이다리 (pedipalps)
    # ===================================================================

    def _draw_pedipalps(self, surface, bcx, bcy, w, h, p):
        cy = int(bcy - h * 0.04)
        by = cy + int(h * 0.038)

        for side in [-1, 1]:
            bx = bcx + side * int(w * 0.048)
            m1x = bx + side * int(w * 0.028)
            m1y = by + int(h * 0.028)
            m2x = m1x + side * int(w * 0.014)
            m2y = m1y + int(h * 0.032)

            pw = max(1, int(w * 0.014))
            pygame.draw.line(surface, p["leg_dark"], (bx, by), (m1x, m1y), pw + 1)
            pygame.draw.line(surface, p["pedi"], (bx, by), (m1x, m1y), pw)
            pygame.draw.line(surface, p["pedi"], (m1x, m1y), (m2x, m2y), max(1, pw - 1))
            pygame.draw.circle(surface, p["leg_joint"],
                              (m2x, m2y), max(1, int(w * 0.009)))

    # ===================================================================
    #  다리 — gait cycle + 4마디
    # ===================================================================

    def _draw_legs(self, surface, bcx, bcy, w, h, p, back=True):
        pairs = [2, 3] if back else [0, 1]
        for pi in pairs:
            tmpl = self._LEG_TEMPLATES[pi]
            li, ri = pi * 2, pi * 2 + 1
            for side, idx in [(-1, li), (1, ri)]:
                self._draw_single_leg(surface, bcx, bcy, w, h, p,
                                       tmpl, side, idx, pi)

    def _get_leg_cycle(self, leg_idx, pair_idx):
        """다리의 현재 gait cycle 위치 (0~1) 반환"""
        offset = self._leg_phase_offsets[leg_idx]
        delay = self._leg_pair_delay[pair_idx]
        # 전체 위상을 0~1로 정규화
        raw = (self.step_phase + offset + delay) % 1.0
        return raw

    def _draw_single_leg(self, surface, bcx, bcy, w, h, p,
                          tmpl, side, leg_idx, pair_idx):
        hip_dx, hip_dy, knee_dx, knee_dy, foot_dx, foot_dy = tmpl
        twitch = self._leg_twitch[leg_idx]

        # 히트 시 다리 경련 (Spasm) — 모든 다리에 무작위 떨림 추가
        if self.is_hit:
            twitch += random.uniform(-0.05, 0.05) * self.hit_intensity

        # 기본 좌표
        hip_x = bcx + side * int(hip_dx * w)
        hip_y = int(bcy + hip_dy * h)
        knee_x = bcx + side * int(knee_dx * w)
        knee_y = int(bcy + knee_dy * h)
        foot_x = bcx + side * int(foot_dx * w)
        foot_y = int(bcy + foot_dy * h)

        # ==== Gait Cycle 기반 걷기 (옆으로 짚는 실제 거미 보행) ====
        if self.direction != 0:
            sp = min(self.velocity / 100.0, 1.0)
            cycle = self._get_leg_cycle(leg_idx, pair_idx)
            SR = self._SWING_RATIO

            if cycle < SR:
                # SWING: 다리를 들어 옆으로(바깥쪽으로) 뻗기 (0→SR)
                t = cycle / SR                              # 0 → 1
                t_smooth = _smoothstep(t)
                lift = _sin(t * _pi)                        # 포물선 호

                # 수직: 다리 들어올리기
                foot_y -= int(lift * h * 0.13 * sp)
                knee_y -= int(lift * h * 0.07 * sp)

                # 측면(lateral): 바깥쪽으로 뻗기 — 거미가 옆으로 짚는 핵심
                lateral = _sin(t * _pi) * w * 0.09 * sp
                foot_x += int(side * lateral)
                knee_x += int(side * lateral * 0.35)

                # 전후: 약간 앞으로 내딛기
                foot_x += int(self.direction * t_smooth * w * 0.035 * sp)
                knee_x += int(self.direction * t_smooth * w * 0.018 * sp)
            else:
                # STANCE: 발이 바닥에 고정, 몸이 지나가며 안쪽으로 끌려오는 효과
                t = (cycle - SR) / (1.0 - SR)               # 0 → 1
                t_smooth = _smoothstep(t)

                # 측면(lateral): 바깥 위치에서 점점 안쪽으로 (몸이 지나감)
                lat_remain = (1.0 - t_smooth)
                foot_x += int(side * lat_remain * w * 0.045 * sp)
                knee_x += int(side * lat_remain * w * 0.015 * sp)

                # 전후: 앞쪽에서 점점 뒤쪽으로 밀기
                fwd = 1.0 - t_smooth
                foot_x += int(self.direction * fwd * w * 0.035 * sp)
                foot_x -= int(self.direction * t_smooth * w * 0.030 * sp)
                knee_x += int(self.direction * fwd * w * 0.018 * sp)
                knee_x -= int(self.direction * t_smooth * w * 0.012 * sp)

                # 지면 고정 (IK 흉내): 발끝 Y를 템플릿 기준 지면 높이에 고정
                ground_y = int(bcy + foot_dy * h)
                foot_y = ground_y

        # 대기 떨림
        if self.direction == 0:
            knee_x += int(twitch * w * 0.20)
            knee_y += int(twitch * h * 0.10)
            foot_x += int(twitch * w * 0.25)

        # ==== 히트 발차기 (1쌍만) ====
        if self.is_hit and pair_idx == 0:
            prog = self.hit_timer / self.hit_duration
            if prog < 0.20:
                kick = _sin((prog / 0.20) * _pi * 0.5)
                knee_y += int(kick * h * 0.18)
                knee_x += int(side * kick * w * 0.04)
                foot_y += int(kick * h * 0.28)
                foot_x -= int(side * kick * w * 0.10)
            else:
                kick = max(0, _cos(((prog - 0.20) / 0.80) * _pi * 0.5))
                knee_y += int(kick * h * 0.18)
                knee_x += int(side * kick * w * 0.04)
                foot_y += int(kick * h * 0.28)
                foot_x -= int(side * kick * w * 0.10)

        # ==== 중간 관절 (coxa, mid-tibia) ====
        coxa_x = int(_lerp(hip_x, knee_x, 0.22))
        coxa_y = int(_lerp(hip_y, knee_y, 0.22))
        mid_x = int(_lerp(knee_x, foot_x, 0.55))
        mid_y = int(_lerp(knee_y, foot_y, 0.55))

        # ==== 4마디 렌더링 (두께 그라데이션) ====
        w1 = max(2, int(w * 0.022))   # coxa
        w2 = max(2, int(w * 0.019))   # femur
        w3 = max(2, int(w * 0.015))   # tibia
        w4 = max(1, int(w * 0.010))   # tarsus
        jr = max(2, int(w * 0.012))

        # Coxa
        pygame.draw.line(surface, p["leg_dark"],
                        (hip_x, hip_y), (coxa_x, coxa_y), w1 + 2)
        pygame.draw.line(surface, p["leg_base"],
                        (hip_x, hip_y), (coxa_x, coxa_y), w1 + 1)
        pygame.draw.line(surface, p["leg_light"],
                        (hip_x, hip_y), (coxa_x, coxa_y), max(1, w1 - 1))

        # Coxa 관절
        pygame.draw.circle(surface, p["leg_dark"], (coxa_x, coxa_y), jr + 1)
        pygame.draw.circle(surface, p["leg_joint"], (coxa_x, coxa_y), jr)

        # Femur + 밴딩
        pygame.draw.line(surface, p["leg_dark"],
                        (coxa_x, coxa_y), (knee_x, knee_y), w2 + 2)
        pygame.draw.line(surface, p["leg_mid"],
                        (coxa_x, coxa_y), (knee_x, knee_y), w2 + 1)
        pygame.draw.line(surface, p["leg_light"],
                        (coxa_x, coxa_y), (knee_x, knee_y), max(1, w2 - 1))
        # 중앙 밴딩
        bx_ = int(_lerp(coxa_x, knee_x, 0.5))
        by_ = int(_lerp(coxa_y, knee_y, 0.5))
        pygame.draw.circle(surface, p["leg_band"], (bx_, by_), max(1, w2))

        # Knee 관절 (큼)
        pygame.draw.circle(surface, p["leg_dark"], (knee_x, knee_y), jr + 2)
        pygame.draw.circle(surface, p["leg_joint"], (knee_x, knee_y), jr + 1)
        pygame.draw.circle(surface, p["leg_light"], (knee_x - 1, knee_y - 1),
                          max(1, jr - 1))

        # Tibia
        pygame.draw.line(surface, p["leg_dark"],
                        (knee_x, knee_y), (mid_x, mid_y), w3 + 1)
        pygame.draw.line(surface, p["leg_mid"],
                        (knee_x, knee_y), (mid_x, mid_y), w3)
        pygame.draw.line(surface, p["leg_light"],
                        (knee_x, knee_y), (mid_x, mid_y), max(1, w3 - 1))

        # Mid 관절
        pygame.draw.circle(surface, p["leg_dark"], (mid_x, mid_y), max(1, jr - 1))
        pygame.draw.circle(surface, p["leg_joint"], (mid_x, mid_y), max(1, jr - 2))

        # Tarsus
        pygame.draw.line(surface, p["leg_dark"],
                        (mid_x, mid_y), (foot_x, foot_y), w4 + 1)
        pygame.draw.line(surface, p["leg_base"],
                        (mid_x, mid_y), (foot_x, foot_y), w4)

        # 발톱
        claw_x = foot_x + side * max(1, int(w * 0.012))
        claw_y = foot_y + max(1, int(h * 0.007))
        pygame.draw.line(surface, p["leg_dark"],
                        (foot_x, foot_y), (claw_x, claw_y),
                        max(1, int(w * 0.007)))

        # 다리 강모
        self._draw_leg_bristles(surface, coxa_x, coxa_y, knee_x, knee_y,
                                 mid_x, mid_y, w, p, side, leg_idx)

    def _draw_leg_bristles(self, surface, cx, cy, kx, ky, mx, my,
                            w, p, side, leg_idx):
        sl = max(2, int(w * 0.022))
        col = p["hair"]
        col_l = p["hair_l"]

        inertia = self._hair_inertia
        # Femur 강모 3개
        for i, t in enumerate([0.25, 0.50, 0.75]):
            sx = int(_lerp(cx, kx, t))
            sy = int(_lerp(cy, ky, t))
            si = leg_idx * 5 + i
            seed = self._hair_seeds[si % len(self._hair_seeds)]
            ang = _sin(self.time * 2.2 + seed) * 0.12 + side * 0.75
            ang -= inertia * 0.20  # 관성에 의한 방향 쏠림
            ln = sl * (0.8 + 0.3 * _sin(seed * 3))
            ex = sx + int(_sin(ang) * ln) * side
            ey = sy - int(abs(_cos(ang)) * ln * 0.6)
            pygame.draw.line(surface, col if i % 2 == 0 else col_l,
                            (sx, sy), (ex, ey), 1)

        # Tibia 강모 2개
        for i, t in enumerate([0.30, 0.65]):
            sx = int(_lerp(kx, mx, t))
            sy = int(_lerp(ky, my, t))
            si = leg_idx * 5 + 3 + i
            seed = self._hair_seeds[si % len(self._hair_seeds)]
            ang = _sin(self.time * 1.9 + seed) * 0.10 + side * 0.65
            ang -= inertia * 0.18  # 관성에 의한 방향 쏠림
            ln = sl * 0.7
            ex = sx + int(_sin(ang) * ln) * side
            ey = sy - int(abs(_cos(ang)) * ln * 0.5)
            pygame.draw.line(surface, col, (sx, sy), (ex, ey), 1)

    # ===================================================================
    #  몸체 체모
    # ===================================================================

    def _draw_body_hair(self, surface, bcx, bcy, w, h, p):
        ccy = int(bcy - h * 0.04)
        acy = int(bcy + h * 0.14)

        positions = [
            # 두흉부
            (bcx - int(w * 0.065), ccy - int(h * 0.025), 0.024, -0.5),
            (bcx + int(w * 0.065), ccy - int(h * 0.015), 0.024, -0.6),
            (bcx - int(w * 0.075), ccy + int(h * 0.012), 0.020, -0.3),
            (bcx + int(w * 0.075), ccy + int(h * 0.015), 0.020, -0.4),
            (bcx, ccy - int(h * 0.038), 0.022, -0.8),
            # 복부
            (bcx - int(w * 0.11), acy - int(h * 0.06), 0.030, -0.4),
            (bcx + int(w * 0.11), acy - int(h * 0.05), 0.030, -0.5),
            (bcx - int(w * 0.045), acy - int(h * 0.11), 0.026, -0.7),
            (bcx + int(w * 0.045), acy - int(h * 0.10), 0.026, -0.65),
            (bcx, acy - int(h * 0.08), 0.022, -0.85),
            (bcx - int(w * 0.09), acy + int(h * 0.02), 0.024, -0.2),
            (bcx + int(w * 0.09), acy + int(h * 0.01), 0.024, -0.25),
            (bcx - int(w * 0.045), acy + int(h * 0.08), 0.022, 0.3),
            (bcx + int(w * 0.045), acy + int(h * 0.07), 0.022, 0.35),
            (bcx, acy + int(h * 0.10), 0.020, 0.5),
            (bcx - int(w * 0.13), acy - int(h * 0.02), 0.022, -0.15),
            (bcx + int(w * 0.13), acy - int(h * 0.03), 0.022, -0.18),
        ]

        inertia = self._hair_inertia
        for i, (hx, hy, lr, ang) in enumerate(positions):
            si = i + 25
            seed = self._hair_seeds[si % len(self._hair_seeds)]
            hl = int(lr * w)
            wave = _sin(self.time * 2.5 + seed) * 0.08
            # 관성: 이동 반대 방향으로 체모가 쏠리는 효과
            inertia_offset = -inertia * 0.25 * (0.8 + 0.4 * _sin(seed))
            col = p["hair"] if i % 2 == 0 else p["hair_l"]
            ex = hx + int(_sin(ang + wave + inertia_offset) * hl)
            ey = hy + int(_cos(ang) * hl)
            pygame.draw.line(surface, col, (hx, hy), (ex, ey), 1)

    # ===================================================================
    #  독액 파티클 렌더링
    # ===================================================================

    def _draw_venom_particles(self, surface, bcx, bcy, w, h):
        if not self._venom_particles:
            return
        # 독아 기준점 (chelicerae 하단 부근)
        fang_base_y = int(bcy - h * 0.04) + int(h * 0.078)
        for px, py, vx, vy, life, max_life, size in self._venom_particles:
            alpha = max(0, min(255, int(255 * (life / max_life))))
            r = max(1, int(size * w * 0.006))
            sx = int(bcx + px * w * 0.01)
            sy = int(fang_base_y + py * h * 0.01)
            if 0 <= sx < w and 0 <= sy < h:
                # 독액: 연두~초록 반투명 방울
                venom_col = (80, 200, 50, alpha)
                ps = pygame.Surface((r * 2 + 2, r * 2 + 2), pygame.SRCALPHA)
                pygame.draw.circle(ps, venom_col, (r + 1, r + 1), r)
                # 광택 핀포인트
                if r > 1:
                    pygame.draw.circle(ps, (180, 255, 140, alpha // 2),
                                      (r, r), max(1, r // 2))
                surface.blit(ps, (sx - r - 1, sy - r - 1))


# ===================================================================
#  싱글톤 패턴
# ===================================================================

_spider_instance = None


def init_spider_boss_sprite():
    global _spider_instance
    try:
        _spider_instance = SpiderBossSprite()
        print("[Sprite] 아라크네 프로시저럴 스프라이트 초기화 완료")
        return _spider_instance
    except Exception as e:
        print(f"[Sprite] 아라크네 스프라이트 초기화 실패: {e}")
        _spider_instance = None
        return None


def get_spider_boss_sprite():
    global _spider_instance
    if _spider_instance is None:
        init_spider_boss_sprite()
    return _spider_instance


def reset_spider_boss_sprite():
    global _spider_instance
    if _spider_instance:
        _spider_instance.direction = 0
        _spider_instance.is_hit = False
        _spider_instance.hit_timer = 0.0
        _spider_instance.hit_intensity = 0.0
        _spider_instance.time = 0.0
        _spider_instance.step_phase = 0.0
        _spider_instance.body_bob = 0.0
        _spider_instance.body_sway = 0.0
        _spider_instance._venom_particles = []
        _spider_instance._hair_inertia = 0.0
        _spider_instance._cached_frame = None
        _spider_instance._cache_dirty = True
        _spider_instance._idle_frame_count = 0

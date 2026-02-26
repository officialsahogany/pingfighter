# -*- coding: utf-8 -*-
"""
아라크네 (Arachne) 프로시저럴 보스 스프라이트
고퀄리티 리얼리스틱 절지동물 — 4마디 다리, 복부 무늬, 더듬이각, 체모
- MolewangBossSprite와 동일한 인터페이스
"""

import pygame
import math
import random

_sin = math.sin
_cos = math.cos
_pi = math.pi
_lerp = lambda a, b, t: a + (b - a) * t


class SpiderBossSprite:
    """아라크네 프로시저럴 보스 스프라이트 — 고퀄리티 절지동물"""

    def __init__(self):
        # 애니메이션 상태
        self.direction = 0
        self.prev_x = 0.0
        self.time = 0.0

        # 걷기
        self.step_phase = 0.0
        self.body_bob = 0.0
        self.velocity = 0.0

        # 방향 전환 안정화
        self.direction_change_cooldown = 0.0
        self.direction_change_threshold = 0.15
        self.movement_accumulator = 0.0

        # 히트 애니메이션 (발차기)
        self.is_hit = False
        self.hit_timer = 0.0
        self.hit_duration = 0.45
        self.hit_direction = 1
        self.hit_intensity = 0.0

        # 교대 보행 위상 — tetrapod gait
        self._leg_phase_offsets = [
            0.0, _pi, _pi, 0.0,
            0.0, _pi, _pi, 0.0,
        ]

        # 미세 떨림
        self._leg_twitch = [0.0] * 8
        self._leg_twitch_timer = [random.uniform(0, 5) for _ in range(8)]

        # 체모 흔들림 시드
        self._hair_seeds = [random.uniform(0, 10) for _ in range(40)]

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
            speed_factor = min(self.velocity / 80.0, 2.0)
            self.step_phase += dt * 8.0 * max(speed_factor, 0.5)
            self.body_bob = _sin(self.step_phase * 2) * 0.04 * speed_factor
        else:
            self.step_phase *= 0.95
            self.body_bob = _sin(self.time * 2.5) * 0.008

        if self.is_hit:
            self.hit_timer += dt
            progress = self.hit_timer / self.hit_duration
            if progress >= 1.0:
                self.is_hit = False
                self.hit_timer = 0.0
                self.hit_intensity = 0.0
            else:
                self.hit_intensity = max(0, 1.0 - progress * 1.5)

        for i in range(8):
            self._leg_twitch_timer[i] += dt
            if self.direction == 0:
                self._leg_twitch[i] = _sin(
                    self._leg_twitch_timer[i] * (2.5 + i * 0.3)) * 0.025
            else:
                self._leg_twitch[i] *= 0.9

        self.prev_x = current_x

    def trigger_hit(self, ball_x, boss_x):
        self.is_hit = True
        self.hit_timer = 0.0
        self.hit_intensity = 1.0
        self.hit_direction = 1 if ball_x > boss_x else -1

    # ===================================================================
    #  프레임 생성
    # ===================================================================

    def get_current_frame(self, scale_size=None):
        w, h = scale_size or (120, 120)
        w, h = max(20, int(w)), max(20, int(h))
        surface = pygame.Surface((w, h), pygame.SRCALPHA)
        self._draw_character(surface, w, h)
        return surface

    def draw(self, surface, x, y, width=None, height=None, center=True):
        if width and height:
            frame = self.get_current_frame((width, height))
        else:
            frame = self.get_current_frame()
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
        bob_offset = self.body_bob * 0.04 * h
        p = self._get_palette(self.hit_intensity * 0.25 if self.is_hit else 0.0)

        bcx = int(w * 0.50)
        bcy = int(h * 0.36 + bob_offset)

        # 레이어: 뒷다리 → 복부 → 두흉부 → 앞다리 → 눈/독아/더듬이다리 → 체모
        self._draw_legs(surface, bcx, bcy, w, h, p, back=True)
        self._draw_abdomen(surface, bcx, bcy, w, h, p)
        self._draw_cephalothorax(surface, bcx, bcy, w, h, p)
        self._draw_legs(surface, bcx, bcy, w, h, p, back=False)
        self._draw_eyes(surface, bcx, bcy, w, h, p)
        self._draw_chelicerae(surface, bcx, bcy, w, h, p)
        self._draw_pedipalps(surface, bcx, bcy, w, h, p)
        self._draw_body_hair(surface, bcx, bcy, w, h, p)

    def _get_palette(self, flash=0.0):
        def _f(base):
            return tuple(min(255, int(c + (255 - c) * flash)) for c in base)
        return {
            "body_dark": _f((20, 14, 11)),
            "body": _f((38, 26, 21)),
            "body_mid": _f((48, 34, 27)),
            "body_light": _f((62, 46, 36)),
            "body_edge": _f((12, 8, 6)),
            "abdomen": _f((30, 22, 18)),
            "abdomen_dark": _f((16, 12, 9)),
            "abdomen_mid": _f((42, 32, 25)),
            "abdomen_sheen": _f((75, 58, 48)),
            "abdomen_mark": _f((55, 35, 22)),
            "eye_main": _f((6, 4, 4)),
            "eye_glow": _f((110, 28, 18)),
            "eye_shine": _f((230, 215, 195)),
            "eye_secondary": _f((18, 10, 8)),
            "fang": _f((105, 28, 20)),
            "fang_tip": _f((185, 45, 28)),
            "fang_dark": _f((58, 18, 12)),
            "leg_base": _f((55, 30, 22)),
            "leg_mid": _f((45, 24, 18)),
            "leg_dark": _f((28, 16, 12)),
            "leg_light": _f((72, 48, 36)),
            "leg_band": _f((35, 20, 15)),
            "leg_joint": _f((65, 40, 28)),
            "hair": _f((45, 28, 20)),
            "hair_light": _f((60, 38, 28)),
            "pedipalp": _f((50, 30, 22)),
        }

    # ===================================================================
    #  복부 — 셰브론 무늬 + 텍스처
    # ===================================================================

    def _draw_abdomen(self, surface, bcx, bcy, w, h, p):
        abd_cx = bcx
        abd_cy = int(bcy + h * 0.13)
        abd_w = int(w * 0.30)
        abd_h = int(h * 0.26)

        # 그림자
        pygame.draw.ellipse(surface, p["abdomen_dark"],
                           (abd_cx - abd_w // 2 + 2,
                            abd_cy - abd_h // 2 + 2,
                            abd_w, abd_h))
        # 본체
        pygame.draw.ellipse(surface, p["abdomen"],
                           (abd_cx - abd_w // 2,
                            abd_cy - abd_h // 2,
                            abd_w, abd_h))

        # 셰브론 무늬 (V자 줄무늬 3개)
        for i in range(3):
            vy = abd_cy - int(abd_h * 0.20) + int(i * abd_h * 0.22)
            vw = int(abd_w * (0.40 - i * 0.06))
            pts = [
                (abd_cx - vw // 2, vy - int(h * 0.012)),
                (abd_cx, vy + int(h * 0.018)),
                (abd_cx + vw // 2, vy - int(h * 0.012)),
            ]
            # 무늬 그리기 (반투명)
            mark_surf = pygame.Surface((abd_w + 4, int(h * 0.05)), pygame.SRCALPHA)
            ox = abd_cx - abd_w // 2 - 2
            oy = vy - int(h * 0.015)
            adj_pts = [(px - ox, py - oy) for px, py in pts]
            if all(0 <= px < mark_surf.get_width() and 0 <= py < mark_surf.get_height()
                   for px, py in adj_pts):
                pygame.draw.lines(mark_surf, (*p["abdomen_mark"], 90),
                                 False, adj_pts, max(1, int(w * 0.010)))
                surface.blit(mark_surf, (ox, oy))

        # 키틴질 광택 (크고 부드러운)
        hl_w = max(4, int(abd_w * 0.40))
        hl_h = max(3, int(abd_h * 0.30))
        hl_surf = pygame.Surface((hl_w, hl_h), pygame.SRCALPHA)
        pygame.draw.ellipse(hl_surf, (*p["abdomen_sheen"], 40),
                           (0, 0, hl_w, hl_h))
        surface.blit(hl_surf,
                    (abd_cx - hl_w // 2 - int(w * 0.035),
                     abd_cy - hl_h // 2 - int(h * 0.07)))
        # 작은 핀포인트 하이라이트
        hl2_r = max(2, int(abd_w * 0.07))
        hl2_surf = pygame.Surface((hl2_r * 2, hl2_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(hl2_surf, (*p["body_light"], 55),
                          (hl2_r, hl2_r), hl2_r)
        surface.blit(hl2_surf,
                    (abd_cx - hl2_r + int(w * 0.015),
                     abd_cy - hl2_r - int(h * 0.08)))

        # 테두리 (이중)
        pygame.draw.ellipse(surface, p["body_edge"],
                           (abd_cx - abd_w // 2,
                            abd_cy - abd_h // 2,
                            abd_w, abd_h), max(1, int(w * 0.010)))
        # 미세 내부 테두리
        inner_w = abd_w - int(w * 0.016)
        inner_h = abd_h - int(h * 0.016)
        if inner_w > 4 and inner_h > 4:
            inner_surf = pygame.Surface((inner_w, inner_h), pygame.SRCALPHA)
            pygame.draw.ellipse(inner_surf, (*p["abdomen_dark"], 30),
                               (0, 0, inner_w, inner_h), 1)
            surface.blit(inner_surf,
                        (abd_cx - inner_w // 2, abd_cy - inner_h // 2))

    # ===================================================================
    #  두흉부
    # ===================================================================

    def _draw_cephalothorax(self, surface, bcx, bcy, w, h, p):
        ceph_cx = bcx
        ceph_cy = int(bcy - h * 0.04)
        ceph_w = int(w * 0.20)
        ceph_h = int(h * 0.14)

        # 그림자
        pygame.draw.ellipse(surface, p["body_dark"],
                           (ceph_cx - ceph_w // 2 + 1,
                            ceph_cy - ceph_h // 2 + 1,
                            ceph_w, ceph_h))
        # 본체
        pygame.draw.ellipse(surface, p["body"],
                           (ceph_cx - ceph_w // 2,
                            ceph_cy - ceph_h // 2,
                            ceph_w, ceph_h))
        # 중앙 홈 (fovea)
        fov_len = int(h * 0.035)
        pygame.draw.line(surface, p["body_dark"],
                        (ceph_cx, ceph_cy - int(h * 0.005)),
                        (ceph_cx, ceph_cy + fov_len),
                        max(1, int(w * 0.008)))
        # 방사 줄무늬 (2개)
        for side in [-1, 1]:
            sx = ceph_cx + side * int(ceph_w * 0.15)
            sy = ceph_cy - int(ceph_h * 0.1)
            ex = ceph_cx + side * int(ceph_w * 0.38)
            ey = ceph_cy + int(ceph_h * 0.25)
            line_surf = pygame.Surface((ceph_w, ceph_h), pygame.SRCALPHA)
            ox, oy = ceph_cx - ceph_w // 2, ceph_cy - ceph_h // 2
            pygame.draw.line(line_surf, (*p["body_dark"], 50),
                            (sx - ox, sy - oy), (ex - ox, ey - oy), 1)
            surface.blit(line_surf, (ox, oy))
        # 광택
        hl_r = max(2, int(ceph_w * 0.18))
        hl_surf = pygame.Surface((hl_r * 2, hl_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(hl_surf, (*p["body_light"], 45),
                          (hl_r, hl_r), hl_r)
        surface.blit(hl_surf,
                    (ceph_cx - hl_r - int(w * 0.012),
                     ceph_cy - hl_r - int(h * 0.018)))
        # 테두리
        pygame.draw.ellipse(surface, p["body_edge"],
                           (ceph_cx - ceph_w // 2,
                            ceph_cy - ceph_h // 2,
                            ceph_w, ceph_h), max(1, int(w * 0.008)))
        # 페디셀 (좁은 허리)
        ped_cy = int(bcy + h * 0.035)
        ped_w = max(3, int(w * 0.05))
        ped_h = max(3, int(h * 0.045))
        pygame.draw.ellipse(surface, p["body_dark"],
                           (bcx - ped_w // 2, ped_cy - ped_h // 2,
                            ped_w, ped_h))

    # ===================================================================
    #  눈 8개
    # ===================================================================

    def _draw_eyes(self, surface, bcx, bcy, w, h, p):
        ceph_cy = int(bcy - h * 0.04)

        # 주눈 2개 (AME — Anterior Median Eyes)
        for side in [-1, 1]:
            ex = bcx + side * int(w * 0.030)
            ey = ceph_cy - int(h * 0.025)
            er = max(2, int(w * 0.024))
            # 눈구멍 (어두운 테두리)
            pygame.draw.circle(surface, p["body_edge"], (ex, ey), er + 1)
            pygame.draw.circle(surface, p["eye_main"], (ex, ey), er)
            # 붉은 홍채
            pygame.draw.circle(surface, p["eye_glow"], (ex, ey), max(1, er - 1))
            pygame.draw.circle(surface, p["eye_main"], (ex, ey), max(1, er - 2))
            # 하이라이트 (2개 — 큰/작은)
            sh_r = max(1, int(er * 0.35))
            pygame.draw.circle(surface, p["eye_shine"],
                              (ex - 1, ey - 1), sh_r)
            if er > 3:
                pygame.draw.circle(surface, (*p["eye_shine"][:3], 140),
                                  (ex + int(er * 0.2), ey + int(er * 0.3)),
                                  max(1, sh_r - 1))

        # 보조눈 6개 (ALE, PLE, PME)
        sec = [
            (-0.052, -0.010, 0.70),   # ALE left
            (0.052, -0.010, 0.70),    # ALE right
            (-0.062, 0.008, 0.55),    # PLE left
            (0.062, 0.008, 0.55),     # PLE right
            (-0.035, 0.016, 0.50),    # PME left
            (0.035, 0.016, 0.50),     # PME right
        ]
        for sx, sy, size_mult in sec:
            ex = bcx + int(sx * w)
            ey = ceph_cy + int(sy * h) - int(h * 0.010)
            er = max(1, int(w * 0.013 * size_mult / 0.55))
            pygame.draw.circle(surface, p["body_edge"], (ex, ey), er + 1)
            pygame.draw.circle(surface, p["eye_secondary"], (ex, ey), er)
            pygame.draw.circle(surface, p["eye_shine"], (ex, ey - 1), max(1, er // 2))

    # ===================================================================
    #  독아 (chelicerae)
    # ===================================================================

    def _draw_chelicerae(self, surface, bcx, bcy, w, h, p):
        ceph_cy = int(bcy - h * 0.04)
        fang_base_y = ceph_cy + int(h * 0.052)

        spread = 0.0
        fang_flash = 0
        if self.is_hit:
            prog = self.hit_timer / self.hit_duration
            if prog < 0.20:
                spread = w * 0.022 * (prog / 0.20)
                fang_flash = int(180 * (1.0 - prog / 0.20))
            else:
                spread = w * 0.022 * max(0, 1.0 - (prog - 0.20) / 0.25)

        for side in [-1, 1]:
            base_x = bcx + side * int(w * 0.024 + spread)
            base_y = fang_base_y
            mid_x = base_x + side * int(w * 0.028)
            mid_y = base_y + int(h * 0.042)
            tip_x = base_x + side * int(w * 0.020)
            tip_y = base_y + int(h * 0.072)

            fw = max(2, int(w * 0.018))
            # 기저부 (두툼)
            pygame.draw.line(surface, p["fang_dark"],
                            (base_x + 1, base_y + 1), (mid_x + 1, mid_y + 1), fw + 2)
            pygame.draw.line(surface, p["fang"],
                            (base_x, base_y), (mid_x, mid_y), fw + 1)
            # 끝 (가늘고 날카롭게)
            pygame.draw.line(surface, p["fang_dark"],
                            (mid_x + 1, mid_y + 1), (tip_x + 1, tip_y + 1), max(1, fw))
            pygame.draw.line(surface, p["fang"],
                            (mid_x, mid_y), (tip_x, tip_y), max(1, fw - 1))
            # 독 끝
            pygame.draw.circle(surface, p["fang_tip"],
                              (tip_x, tip_y), max(2, int(w * 0.009)))

            if fang_flash > 0:
                fs_w = fw * 5
                fs_h = int(h * 0.08)
                if fs_w > 0 and fs_h > 0:
                    fs = pygame.Surface((fs_w, fs_h), pygame.SRCALPHA)
                    pygame.draw.line(fs, (255, 100, 80, fang_flash),
                                    (fs_w // 2, 0), (fs_w // 2, fs_h), fw + 2)
                    surface.blit(fs, (base_x - fs_w // 2, base_y))

    # ===================================================================
    #  더듬이다리 (pedipalps) — 독아 양옆 작은 부속지
    # ===================================================================

    def _draw_pedipalps(self, surface, bcx, bcy, w, h, p):
        ceph_cy = int(bcy - h * 0.04)
        base_y = ceph_cy + int(h * 0.035)

        for side in [-1, 1]:
            bx = bcx + side * int(w * 0.045)
            by = base_y
            # 1마디
            m1x = bx + side * int(w * 0.025)
            m1y = by + int(h * 0.025)
            # 2마디 (끝)
            m2x = m1x + side * int(w * 0.012)
            m2y = m1y + int(h * 0.030)

            pw = max(1, int(w * 0.012))
            pygame.draw.line(surface, p["pedipalp"],
                            (bx, by), (m1x, m1y), pw + 1)
            pygame.draw.line(surface, p["pedipalp"],
                            (m1x, m1y), (m2x, m2y), pw)
            # 끝 둥글게
            pygame.draw.circle(surface, p["leg_joint"],
                              (m2x, m2y), max(1, int(w * 0.008)))

    # ===================================================================
    #  다리 시스템 — 4마디 고퀄리티 + 자연스러운 배치
    # ===================================================================

    # 다리 좌표 (w,h 비율) — 이전보다 20% 덜 벌어짐
    # (hip_dx, hip_dy, knee_dx, knee_dy, foot_dx, foot_dy)
    _LEG_TEMPLATES = [
        # 1쌍 (앞) — 전방 대각선
        (0.09, -0.04,   0.30, -0.20,   0.36, 0.14),
        # 2쌍 — 옆으로
        (0.09, -0.01,   0.34, -0.11,   0.38, 0.24),
        # 3쌍 — 약간 뒤쪽
        (0.09,  0.02,   0.32, -0.02,   0.35, 0.34),
        # 4쌍 (뒤) — 후방 대각선
        (0.09,  0.05,   0.26,  0.07,   0.28, 0.40),
    ]

    def _draw_legs(self, surface, bcx, bcy, w, h, p, back=True):
        """back=True면 3,4쌍(뒤 레이어), False면 1,2쌍(앞 레이어)"""
        pairs = [2, 3] if back else [0, 1]
        for pair_idx in pairs:
            tmpl = self._LEG_TEMPLATES[pair_idx]
            left_idx = pair_idx * 2
            right_idx = pair_idx * 2 + 1
            for side, leg_idx in [(-1, left_idx), (1, right_idx)]:
                self._draw_single_leg(surface, bcx, bcy, w, h, p,
                                       tmpl, side, leg_idx, pair_idx)

    def _draw_single_leg(self, surface, bcx, bcy, w, h, p,
                          tmpl, side, leg_idx, pair_idx):
        """4마디 다리 (coxa→femur→tibia→tarsus) + swing/stance 보행 + 발차기"""
        hip_dx, hip_dy, knee_dx, knee_dy, foot_dx, foot_dy = tmpl
        phase_offset = self._leg_phase_offsets[leg_idx]
        twitch = self._leg_twitch[leg_idx]

        # 기본 좌표
        hip_x = bcx + side * int(hip_dx * w)
        hip_y = int(bcy + hip_dy * h)
        knee_x = bcx + side * int(knee_dx * w)
        knee_y = int(bcy + knee_dy * h)
        foot_x = bcx + side * int(foot_dx * w)
        foot_y = int(bcy + foot_dy * h)

        # ==== 걷기 애니메이션 (swing/stance) ====
        if self.direction != 0:
            sp = min(self.velocity / 100.0, 1.0)
            phase = _sin(self.step_phase + phase_offset)

            if phase > 0:
                # SWING: 들어올려 앞으로
                lift = phase
                foot_y -= int(lift * h * 0.11 * sp)
                foot_x += int(self.direction * lift * w * 0.05 * sp)
                knee_y -= int(lift * h * 0.07 * sp)
                knee_x += int(self.direction * lift * w * 0.025 * sp)
            else:
                # STANCE: 바닥에서 뒤로 밀기
                push = -phase
                foot_x -= int(self.direction * push * w * 0.035 * sp)
                knee_x -= int(self.direction * push * w * 0.015 * sp)

        # 대기 떨림
        if self.direction == 0:
            knee_x += int(twitch * w * 0.25)
            knee_y += int(twitch * h * 0.12)
            foot_x += int(twitch * w * 0.3)

        # ==== 히트 발차기 (1쌍만) ====
        if self.is_hit and pair_idx == 0:
            prog = self.hit_timer / self.hit_duration
            if prog < 0.20:
                kick = _sin((prog / 0.20) * _pi * 0.5)
                knee_y += int(kick * h * 0.18)
                knee_x += int(side * kick * w * 0.04)
                foot_y += int(kick * h * 0.30)
                foot_x -= int(side * kick * w * 0.10)
            else:
                kick = max(0, _cos(((prog - 0.20) / 0.80) * _pi * 0.5))
                knee_y += int(kick * h * 0.18)
                knee_x += int(side * kick * w * 0.04)
                foot_y += int(kick * h * 0.30)
                foot_x -= int(side * kick * w * 0.10)

        # ==== 중간 관절 계산 (coxa, mid-tibia) ====
        coxa_x = int(_lerp(hip_x, knee_x, 0.22))
        coxa_y = int(_lerp(hip_y, knee_y, 0.22))
        mid_x = int(_lerp(knee_x, foot_x, 0.55))
        mid_y = int(_lerp(knee_y, foot_y, 0.55))

        # ==== 렌더링 — 4마디 ====
        # 두께 (기저→끝 점점 가늘어짐)
        w1 = max(2, int(w * 0.020))   # coxa (가장 두꺼움)
        w2 = max(2, int(w * 0.017))   # femur
        w3 = max(2, int(w * 0.013))   # tibia
        w4 = max(1, int(w * 0.009))   # tarsus (가장 가늘음)
        jr = max(2, int(w * 0.011))   # 관절 크기

        # --- Coxa (hip → coxa) ---
        pygame.draw.line(surface, p["leg_dark"],
                        (hip_x, hip_y), (coxa_x, coxa_y), w1 + 2)
        pygame.draw.line(surface, p["leg_base"],
                        (hip_x, hip_y), (coxa_x, coxa_y), w1 + 1)
        pygame.draw.line(surface, p["leg_light"],
                        (hip_x, hip_y), (coxa_x, coxa_y), max(1, w1 - 1))

        # Coxa-Femur 관절
        pygame.draw.circle(surface, p["leg_dark"], (coxa_x, coxa_y), jr + 1)
        pygame.draw.circle(surface, p["leg_joint"], (coxa_x, coxa_y), jr)

        # --- Femur (coxa → knee) ---
        pygame.draw.line(surface, p["leg_dark"],
                        (coxa_x, coxa_y), (knee_x, knee_y), w2 + 2)
        pygame.draw.line(surface, p["leg_mid"],
                        (coxa_x, coxa_y), (knee_x, knee_y), w2 + 1)
        pygame.draw.line(surface, p["leg_light"],
                        (coxa_x, coxa_y), (knee_x, knee_y), max(1, w2 - 1))
        # 밴딩 (어두운 줄무늬)
        band_x = int(_lerp(coxa_x, knee_x, 0.5))
        band_y = int(_lerp(coxa_y, knee_y, 0.5))
        pygame.draw.circle(surface, p["leg_band"], (band_x, band_y),
                          max(1, w2))

        # Knee 관절 (가장 큰 관절)
        pygame.draw.circle(surface, p["leg_dark"], (knee_x, knee_y), jr + 2)
        pygame.draw.circle(surface, p["leg_joint"], (knee_x, knee_y), jr + 1)
        # 관절 하이라이트
        pygame.draw.circle(surface, p["leg_light"], (knee_x - 1, knee_y - 1),
                          max(1, jr - 1))

        # --- Tibia (knee → mid) ---
        pygame.draw.line(surface, p["leg_dark"],
                        (knee_x, knee_y), (mid_x, mid_y), w3 + 1)
        pygame.draw.line(surface, p["leg_mid"],
                        (knee_x, knee_y), (mid_x, mid_y), w3)
        pygame.draw.line(surface, p["leg_light"],
                        (knee_x, knee_y), (mid_x, mid_y), max(1, w3 - 1))

        # Mid 관절
        pygame.draw.circle(surface, p["leg_dark"], (mid_x, mid_y), max(1, jr - 1))
        pygame.draw.circle(surface, p["leg_joint"], (mid_x, mid_y), max(1, jr - 2))

        # --- Tarsus (mid → foot) ---
        pygame.draw.line(surface, p["leg_dark"],
                        (mid_x, mid_y), (foot_x, foot_y), w4 + 1)
        pygame.draw.line(surface, p["leg_base"],
                        (mid_x, mid_y), (foot_x, foot_y), w4)

        # 발끝 발톱
        claw_x = foot_x + side * max(1, int(w * 0.010))
        claw_y = foot_y + max(1, int(h * 0.006))
        pygame.draw.line(surface, p["leg_dark"],
                        (foot_x, foot_y), (claw_x, claw_y),
                        max(1, int(w * 0.006)))

        # 다리 가시/강모
        self._draw_leg_bristles(surface, hip_x, hip_y, coxa_x, coxa_y,
                                 knee_x, knee_y, mid_x, mid_y,
                                 foot_x, foot_y, w, h, p, side, leg_idx)

    def _draw_leg_bristles(self, surface, hx, hy, cx, cy, kx, ky,
                            mx, my, fx, fy, w, h, p, side, leg_idx):
        """다리 강모 — femur과 tibia에 가시"""
        sl = max(2, int(w * 0.022))
        col = p["hair"]
        col_l = p["hair_light"]

        # Femur 강모 (3개)
        for i, t in enumerate([0.25, 0.50, 0.75]):
            sx = int(_lerp(cx, kx, t))
            sy = int(_lerp(cy, ky, t))
            seed = self._hair_seeds[leg_idx * 4 + i] if leg_idx * 4 + i < len(self._hair_seeds) else 0
            ang = _sin(self.time * 2.2 + seed) * 0.12 + side * 0.75
            length = sl * (0.8 + 0.4 * _sin(seed * 3))
            ex = sx + int(_sin(ang) * length) * side
            ey = sy - int(abs(_cos(ang)) * length * 0.6)
            pygame.draw.line(surface, col if i % 2 == 0 else col_l,
                            (sx, sy), (ex, ey), 1)

        # Tibia 강모 (2개)
        for i, t in enumerate([0.30, 0.65]):
            sx = int(_lerp(kx, mx, t))
            sy = int(_lerp(ky, my, t))
            seed_idx = leg_idx * 4 + 3 + i
            seed = self._hair_seeds[seed_idx] if seed_idx < len(self._hair_seeds) else 0
            ang = _sin(self.time * 1.9 + seed) * 0.10 + side * 0.65
            length = sl * 0.7
            ex = sx + int(_sin(ang) * length) * side
            ey = sy - int(abs(_cos(ang)) * length * 0.5)
            pygame.draw.line(surface, col, (sx, sy), (ex, ey), 1)

    # ===================================================================
    #  몸체 체모 — 밀도 높은 강모
    # ===================================================================

    def _draw_body_hair(self, surface, bcx, bcy, w, h, p):
        ceph_cy = int(bcy - h * 0.04)
        abd_cy = int(bcy + h * 0.13)

        positions = [
            # 두흉부 (짧고 밀집)
            (bcx - int(w * 0.06), ceph_cy - int(h * 0.025), 0.022, -0.5),
            (bcx + int(w * 0.06), ceph_cy - int(h * 0.015), 0.022, -0.6),
            (bcx - int(w * 0.07), ceph_cy + int(h * 0.01), 0.018, -0.3),
            (bcx + int(w * 0.07), ceph_cy + int(h * 0.015), 0.018, -0.4),
            (bcx, ceph_cy - int(h * 0.035), 0.020, -0.8),
            # 복부 (길고 많이)
            (bcx - int(w * 0.10), abd_cy - int(h * 0.06), 0.028, -0.4),
            (bcx + int(w * 0.10), abd_cy - int(h * 0.05), 0.028, -0.5),
            (bcx - int(w * 0.04), abd_cy - int(h * 0.10), 0.025, -0.7),
            (bcx + int(w * 0.04), abd_cy - int(h * 0.09), 0.025, -0.65),
            (bcx, abd_cy - int(h * 0.07), 0.020, -0.85),
            (bcx - int(w * 0.08), abd_cy + int(h * 0.02), 0.022, -0.2),
            (bcx + int(w * 0.08), abd_cy + int(h * 0.01), 0.022, -0.25),
            (bcx - int(w * 0.04), abd_cy + int(h * 0.07), 0.020, 0.3),
            (bcx + int(w * 0.04), abd_cy + int(h * 0.06), 0.020, 0.35),
            (bcx, abd_cy + int(h * 0.09), 0.018, 0.5),
            # 측면 추가
            (bcx - int(w * 0.12), abd_cy - int(h * 0.02), 0.020, -0.15),
            (bcx + int(w * 0.12), abd_cy - int(h * 0.03), 0.020, -0.18),
        ]

        for i, (hx, hy, length_r, angle) in enumerate(positions):
            seed = self._hair_seeds[i + 20] if i + 20 < len(self._hair_seeds) else i * 0.7
            h_len = int(length_r * w)
            wave = _sin(self.time * 2.5 + seed) * 0.08
            col = p["hair"] if i % 2 == 0 else p["hair_light"]
            ex = hx + int(_sin(angle + wave) * h_len)
            ey = hy + int(_cos(angle) * h_len)
            pygame.draw.line(surface, col, (hx, hy), (ex, ey), 1)


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

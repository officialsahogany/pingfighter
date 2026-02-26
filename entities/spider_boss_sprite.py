# -*- coding: utf-8 -*-
"""
아라크네 (Arachne) 프로시저럴 보스 스프라이트
리얼리스틱 절지동물 디자인 — 콤팩트한 몸체 + 넓게 펼쳐진 8다리
- MolewangBossSprite와 동일한 인터페이스
"""

import pygame
import math
import random

_sin = math.sin
_cos = math.cos
_pi = math.pi


class SpiderBossSprite:
    """아라크네 프로시저럴 보스 스프라이트 — 리얼리스틱 절지동물"""

    def __init__(self):
        # 애니메이션 상태
        self.direction = 0       # -1: 왼쪽, 0: 정지, 1: 오른쪽
        self.prev_x = 0.0
        self.time = 0.0

        # 걷기
        self.step_phase = 0.0
        self.lean = 0.0
        self.body_bob = 0.0
        self.velocity = 0.0

        # 방향 전환 안정화
        self.direction_change_cooldown = 0.0
        self.direction_change_threshold = 0.15
        self.movement_accumulator = 0.0

        # 히트 애니메이션
        self.is_hit = False
        self.hit_timer = 0.0
        self.hit_duration = 0.40
        self.hit_direction = 1
        self.hit_intensity = 0.0

        # 다리 위상 오프셋 (8개 다리, 교대 보행)
        # 그룹A(0,3,4,7) vs 그룹B(1,2,5,6) — 교대
        self._leg_phase_offsets = [
            0.0, _pi, _pi, 0.0,
            0.0, _pi, _pi, 0.0,
        ]

        # 다리 미세 떨림 (대기 시)
        self._leg_twitch = [0.0] * 8
        self._leg_twitch_timer = [random.uniform(0, 5)] * 8

        # 프레임 캐시
        self._surface_cache = {}

    def _get_surface(self, w, h):
        key = (w, h)
        if key not in self._surface_cache:
            self._surface_cache[key] = pygame.Surface((w, h), pygame.SRCALPHA)
        else:
            self._surface_cache[key].fill((0, 0, 0, 0))
        return self._surface_cache[key]

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

        # 걷기 위상
        if self.direction != 0:
            speed_factor = min(self.velocity / 80.0, 2.0)
            self.step_phase += dt * 10.0 * max(speed_factor, 0.5)
            target_lean = self.direction * 0.10 * min(speed_factor, 1.0)
            self.lean += (target_lean - self.lean) * min(dt * 6.0, 1.0)
            self.body_bob = _sin(self.step_phase * 2) * 0.06 * speed_factor
        else:
            self.step_phase *= 0.95
            self.lean *= 0.92
            self.body_bob = _sin(self.time * 2.5) * 0.015

        # 히트 애니메이션
        if self.is_hit:
            self.hit_timer += dt
            progress = self.hit_timer / self.hit_duration
            if progress >= 1.0:
                self.is_hit = False
                self.hit_timer = 0.0
                self.hit_intensity = 0.0
            else:
                self.hit_intensity = max(0, 1.0 - progress * 1.5)

        # 다리 미세 떨림
        for i in range(8):
            self._leg_twitch_timer[i] += dt
            if self.direction == 0:
                self._leg_twitch[i] = _sin(
                    self._leg_twitch_timer[i] * (2.5 + i * 0.3)) * 0.03
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
    #  렌더링 — 비율 기반 좌표계
    # ===================================================================

    def _draw_character(self, surface, w, h):
        lean_offset = self.lean * 0.05 * w
        bob_offset = self.body_bob * 0.04 * h

        p = self._get_palette(self.hit_intensity * 0.3 if self.is_hit else 0.0)

        # 히트 squash/stretch
        squash_y = 1.0
        stretch_x = 1.0
        if self.is_hit:
            prog = self.hit_timer / self.hit_duration
            if prog < 0.15:
                t = prog / 0.15
                squash_y = 1.0 - 0.25 * t
                stretch_x = 1.0 + 0.12 * t
            elif prog < 0.30:
                t = (prog - 0.15) / 0.15
                squash_y = 0.75 + 0.35 * t
                stretch_x = 1.12 - 0.12 * t
            else:
                t = (prog - 0.30) / 0.70
                squash_y = 1.10 - 0.10 * min(t * 2, 1.0)
                stretch_x = 1.0

        # 몸체 중심 — 프레임 상단 1/3에 위치 (다리를 아래로 펼칠 공간 확보)
        bcx = int(w * 0.50 + lean_offset)
        bcy = int(h * 0.35 + bob_offset)

        # 레이어 순서: 다리(뒤) → 복부 → 두흉부 → 눈 → 독아 → 다리(앞) → 가시
        self._draw_legs_back(surface, bcx, bcy, w, h, p, squash_y)
        self._draw_abdomen(surface, bcx, bcy, w, h, p, squash_y, stretch_x)
        self._draw_cephalothorax(surface, bcx, bcy, w, h, p, squash_y, stretch_x)
        self._draw_eyes(surface, bcx, bcy, w, h, p, squash_y)
        self._draw_chelicerae(surface, bcx, bcy, w, h, p, squash_y)
        self._draw_legs_front(surface, bcx, bcy, w, h, p, squash_y)
        self._draw_body_hair(surface, bcx, bcy, w, h, p, squash_y)

    def _get_palette(self, flash=0.0):
        def _f(base):
            return tuple(min(255, int(c + (255 - c) * flash)) for c in base)

        return {
            # 몸체 — 거의 검정에 가까운 어두운 톤
            "body_dark": _f((18, 12, 10)),
            "body": _f((35, 24, 20)),
            "body_light": _f((58, 42, 34)),
            "body_edge": _f((12, 8, 6)),
            # 복부 — 검은색 계열 + 광택
            "abdomen": _f((28, 20, 16)),
            "abdomen_dark": _f((14, 10, 8)),
            "abdomen_sheen": _f((72, 55, 45)),
            # 눈 — 검은 눈, 붉은 반사
            "eye_main": _f((8, 5, 5)),
            "eye_secondary": _f((15, 8, 8)),
            "eye_shine": _f((220, 200, 180)),
            "eye_glow": _f((120, 30, 20)),
            # 독아 — 선명한 빨간색
            "fang": _f((100, 25, 18)),
            "fang_tip": _f((180, 40, 25)),
            "fang_dark": _f((55, 15, 10)),
            # 다리 — 어두운 적갈색/마룬
            "leg": _f((50, 25, 20)),
            "leg_light": _f((70, 42, 32)),
            "leg_dark": _f((28, 16, 12)),
            "leg_joint": _f((60, 34, 25)),
            # 체모/가시
            "hair": _f((40, 24, 18)),
        }

    # ------- 복부 (abdomen) — 콤팩트한 검은 구체 -------
    def _draw_abdomen(self, surface, bcx, bcy, w, h, p, squash_y, stretch_x):
        # 복부: 두흉부 뒤쪽 (아래쪽), 몸체의 60%
        abd_cx = bcx
        abd_cy = int(bcy + h * 0.12 * squash_y)
        abd_w = int(w * 0.28 * stretch_x)
        abd_h = int(h * 0.24 * squash_y)

        # 그림자
        pygame.draw.ellipse(surface, p["abdomen_dark"],
                           (abd_cx - abd_w // 2 + 1,
                            abd_cy - abd_h // 2 + 1,
                            abd_w, abd_h))
        # 본체
        pygame.draw.ellipse(surface, p["abdomen"],
                           (abd_cx - abd_w // 2,
                            abd_cy - abd_h // 2,
                            abd_w, abd_h))
        # 키틴질 광택 하이라이트 (좌상단)
        hl_w = max(3, int(abd_w * 0.35))
        hl_h = max(2, int(abd_h * 0.25))
        hl_surf = pygame.Surface((hl_w, hl_h), pygame.SRCALPHA)
        pygame.draw.ellipse(hl_surf, (*p["abdomen_sheen"], 50),
                           (0, 0, hl_w, hl_h))
        surface.blit(hl_surf,
                    (abd_cx - hl_w // 2 - int(w * 0.04),
                     abd_cy - hl_h // 2 - int(h * 0.06)))
        # 작은 2차 하이라이트
        hl2_r = max(2, int(abd_w * 0.08))
        hl2_surf = pygame.Surface((hl2_r * 2, hl2_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(hl2_surf, (*p["body_light"], 45),
                          (hl2_r, hl2_r), hl2_r)
        surface.blit(hl2_surf,
                    (abd_cx - hl2_r + int(w * 0.02),
                     abd_cy - hl2_r - int(h * 0.07)))
        # 테두리
        pygame.draw.ellipse(surface, p["body_edge"],
                           (abd_cx - abd_w // 2,
                            abd_cy - abd_h // 2,
                            abd_w, abd_h), max(1, int(w * 0.008)))

    # ------- 두흉부 (cephalothorax) — 앞쪽 작은 몸체 -------
    def _draw_cephalothorax(self, surface, bcx, bcy, w, h, p, squash_y, stretch_x):
        ceph_cx = bcx
        ceph_cy = int(bcy - h * 0.04 * squash_y)
        ceph_w = int(w * 0.18 * stretch_x)
        ceph_h = int(h * 0.13 * squash_y)

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
        # 광택
        hl_r = max(2, int(ceph_w * 0.2))
        hl_surf = pygame.Surface((hl_r * 2, hl_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(hl_surf, (*p["body_light"], 50),
                          (hl_r, hl_r), hl_r)
        surface.blit(hl_surf,
                    (ceph_cx - hl_r - int(w * 0.01),
                     ceph_cy - hl_r - int(h * 0.015)))
        # 테두리
        pygame.draw.ellipse(surface, p["body_edge"],
                           (ceph_cx - ceph_w // 2,
                            ceph_cy - ceph_h // 2,
                            ceph_w, ceph_h), max(1, int(w * 0.006)))
        # 페디셀 (연결부)
        ped_cy = int(bcy + h * 0.03 * squash_y)
        ped_w = max(3, int(w * 0.05))
        ped_h = max(3, int(h * 0.05 * squash_y))
        pygame.draw.ellipse(surface, p["body_dark"],
                           (bcx - ped_w // 2, ped_cy - ped_h // 2,
                            ped_w, ped_h))

    # ------- 눈 8개 -------
    def _draw_eyes(self, surface, bcx, bcy, w, h, p, squash_y):
        ceph_cy = int(bcy - h * 0.04 * squash_y)

        # 주눈 2개 (크고 중앙)
        for side in [-1, 1]:
            ex = bcx + side * int(w * 0.028)
            ey = ceph_cy - int(h * 0.022 * squash_y)
            er = max(2, int(w * 0.022))
            pygame.draw.circle(surface, p["eye_main"], (ex, ey), er)
            pygame.draw.circle(surface, p["eye_glow"], (ex, ey), max(1, er - 1))
            pygame.draw.circle(surface, p["eye_main"], (ex, ey), max(1, er - 2))
            sh_r = max(1, int(er * 0.35))
            pygame.draw.circle(surface, p["eye_shine"],
                              (ex - 1, ey - 1), sh_r)

        # 보조눈 6개
        sec_positions = [
            (-0.048, -0.008), (0.048, -0.008),
            (-0.058, 0.012), (0.058, 0.012),
            (-0.038, 0.018), (0.038, 0.018),
        ]
        for sx, sy in sec_positions:
            ex = bcx + int(sx * w)
            ey = ceph_cy + int(sy * h * squash_y) - int(h * 0.012)
            er = max(1, int(w * 0.012))
            pygame.draw.circle(surface, p["eye_secondary"], (ex, ey), er)
            pygame.draw.circle(surface, p["eye_shine"], (ex, ey - 1), max(1, er // 2))

    # ------- 독아 (chelicerae) -------
    def _draw_chelicerae(self, surface, bcx, bcy, w, h, p, squash_y):
        ceph_cy = int(bcy - h * 0.04 * squash_y)
        fang_base_y = ceph_cy + int(h * 0.05 * squash_y)

        spread = 0.0
        fang_flash = 0
        if self.is_hit:
            prog = self.hit_timer / self.hit_duration
            if prog < 0.25:
                spread = w * 0.02 * (prog / 0.25)
                fang_flash = int(200 * (1.0 - prog / 0.25))
            else:
                spread = w * 0.02 * max(0, 1.0 - (prog - 0.25) / 0.3)

        for side in [-1, 1]:
            base_x = bcx + side * int(w * 0.022 + spread)
            base_y = fang_base_y
            mid_x = base_x + side * int(w * 0.025)
            mid_y = base_y + int(h * 0.04)
            tip_x = base_x + side * int(w * 0.018)
            tip_y = base_y + int(h * 0.065)

            fw = max(2, int(w * 0.016))
            pygame.draw.line(surface, p["fang_dark"],
                            (base_x + 1, base_y + 1), (mid_x + 1, mid_y + 1), fw + 1)
            pygame.draw.line(surface, p["fang_dark"],
                            (mid_x + 1, mid_y + 1), (tip_x + 1, tip_y + 1), max(1, fw - 1))
            pygame.draw.line(surface, p["fang"],
                            (base_x, base_y), (mid_x, mid_y), fw)
            pygame.draw.line(surface, p["fang"],
                            (mid_x, mid_y), (tip_x, tip_y), max(1, fw - 1))
            pygame.draw.circle(surface, p["fang_tip"],
                              (tip_x, tip_y), max(2, int(w * 0.008)))

            if fang_flash > 0:
                fs_w = fw * 4
                fs_h = int(h * 0.07)
                if fs_w > 0 and fs_h > 0:
                    fs = pygame.Surface((fs_w, fs_h), pygame.SRCALPHA)
                    pygame.draw.line(fs, (255, 100, 80, fang_flash),
                                    (fs_w // 2, 0), (fs_w // 2, fs_h), fw + 2)
                    surface.blit(fs, (base_x - fs_w // 2, base_y))

    # ===================================================================
    #  다리 시스템 — 명시적 좌표 기반
    # ===================================================================
    #
    # 각 다리의 3점(hip, knee, foot)을 프레임 비율로 직접 지정
    # → 확실하게 프레임 전체를 활용하는 거미 실루엣
    #
    # 다리 배치 (위에서 봤을 때):
    #   1쌍(앞): 앞쪽 대각선, 가장 길다
    #   2쌍:     약간 앞쪽
    #   3쌍:     약간 뒤쪽
    #   4쌍(뒤): 뒤쪽 대각선

    # 각 다리 쌍의 기본 좌표 (w,h 비율)
    # (hip_dx, hip_dy, knee_dx, knee_dy, foot_dx, foot_dy)
    # dx는 중심에서의 X 오프셋(한쪽, 반대편은 미러), dy는 body center에서의 Y 오프셋
    _LEG_TEMPLATES = [
        # 1쌍 (앞, 앞쪽 대각선으로 넓게) — 가장 긴 다리
        (0.08, -0.04,   0.38, -0.22,   0.44, 0.18),
        # 2쌍 (앞쪽 옆으로)
        (0.08, -0.01,   0.42, -0.12,   0.46, 0.28),
        # 3쌍 (뒤쪽 옆으로)
        (0.08,  0.02,   0.40, -0.04,   0.42, 0.38),
        # 4쌍 (뒤, 뒤쪽 대각선)
        (0.08,  0.05,   0.32,  0.08,   0.34, 0.46),
    ]

    def _draw_legs_back(self, surface, bcx, bcy, w, h, p, squash_y):
        """뒤쪽 레이어 — 3,4쌍"""
        self._draw_leg_pair(surface, bcx, bcy, w, h, p, squash_y, pair_idx=2)
        self._draw_leg_pair(surface, bcx, bcy, w, h, p, squash_y, pair_idx=3)

    def _draw_legs_front(self, surface, bcx, bcy, w, h, p, squash_y):
        """앞쪽 레이어 — 1,2쌍"""
        self._draw_leg_pair(surface, bcx, bcy, w, h, p, squash_y, pair_idx=0)
        self._draw_leg_pair(surface, bcx, bcy, w, h, p, squash_y, pair_idx=1)

    def _draw_leg_pair(self, surface, bcx, bcy, w, h, p, squash_y, pair_idx):
        """한 쌍 (좌+우) 렌더링"""
        tmpl = self._LEG_TEMPLATES[pair_idx]
        left_idx = pair_idx * 2
        right_idx = pair_idx * 2 + 1
        for side, leg_idx in [(-1, left_idx), (1, right_idx)]:
            self._draw_single_leg(surface, bcx, bcy, w, h, p, squash_y,
                                   tmpl, side, leg_idx, pair_idx)

    def _draw_single_leg(self, surface, bcx, bcy, w, h, p, squash_y,
                          tmpl, side, leg_idx, pair_idx):
        """단일 다리 — 명시적 3점 좌표 + 걷기 애니메이션"""
        hip_dx, hip_dy, knee_dx, knee_dy, foot_dx, foot_dy = tmpl
        phase_offset = self._leg_phase_offsets[leg_idx]
        twitch = self._leg_twitch[leg_idx]

        # 걷기 움직임
        walk_phase = 0.0
        walk_amount = 0.0
        if self.direction != 0:
            walk_phase = _sin(self.step_phase + phase_offset)
            walk_amount = min(self.velocity / 100.0, 1.0)

        # 기본 좌표 계산 (side로 미러)
        hip_x = bcx + side * int(hip_dx * w)
        hip_y = int(bcy + hip_dy * h * squash_y)

        knee_x = bcx + side * int(knee_dx * w)
        knee_y = int(bcy + knee_dy * h * squash_y)

        foot_x = bcx + side * int(foot_dx * w)
        foot_y = int(bcy + foot_dy * h * squash_y)

        # 걷기 애니메이션 적용
        if self.direction != 0:
            # 무릎 높이 변화
            knee_lift = max(0, walk_phase) * walk_amount * h * 0.06
            knee_y -= int(knee_lift)
            knee_x += int(self.direction * walk_phase * walk_amount * w * 0.03)

            # 발 들기/놓기
            foot_lift = max(0, walk_phase) * walk_amount * h * 0.08
            foot_y -= int(foot_lift)
            foot_x += int(self.direction * walk_phase * walk_amount * w * 0.04)

        # 대기 미세 떨림
        knee_x += int(twitch * w * 0.3)
        knee_y += int(twitch * h * 0.15)
        foot_x += int(twitch * w * 0.4)

        # ---- 렌더링 ----
        leg_w = max(2, int(w * 0.018))
        joint_r = max(2, int(w * 0.012))

        # Coxa → Knee (femur, 두꺼운 상단 마디)
        pygame.draw.line(surface, p["leg_dark"],
                        (hip_x, hip_y), (knee_x, knee_y), leg_w + 2)
        pygame.draw.line(surface, p["leg"],
                        (hip_x, hip_y), (knee_x, knee_y), leg_w + 1)
        pygame.draw.line(surface, p["leg_light"],
                        (hip_x, hip_y), (knee_x, knee_y), max(1, leg_w - 1))

        # 무릎 관절
        pygame.draw.circle(surface, p["leg_dark"], (knee_x, knee_y), joint_r + 1)
        pygame.draw.circle(surface, p["leg_joint"], (knee_x, knee_y), joint_r)

        # Knee → Foot (tibia, 가늘어지는 하단 마디)
        pygame.draw.line(surface, p["leg_dark"],
                        (knee_x, knee_y), (foot_x, foot_y), leg_w + 1)
        pygame.draw.line(surface, p["leg"],
                        (knee_x, knee_y), (foot_x, foot_y), leg_w)
        pygame.draw.line(surface, p["leg_light"],
                        (knee_x, knee_y), (foot_x, foot_y), max(1, leg_w - 2))

        # 발끝
        pygame.draw.circle(surface, p["leg_dark"],
                          (foot_x, foot_y), max(1, int(w * 0.006)))

        # 다리 가시 (femur, tibia에 각 2개)
        self._draw_leg_hair(surface, hip_x, hip_y, knee_x, knee_y,
                            foot_x, foot_y, w, h, p, side, leg_idx)

    def _draw_leg_hair(self, surface, hx, hy, kx, ky, fx, fy,
                        w, h, p, side, leg_idx):
        """다리 마디 가시/털"""
        spine_len = max(2, int(w * 0.025))
        col = p["hair"]

        # femur 구간 가시 2개
        for t in [0.3, 0.65]:
            sx = int(hx + (kx - hx) * t)
            sy = int(hy + (ky - hy) * t)
            ang = _sin(self.time * 2 + leg_idx) * 0.1 + side * 0.7
            ex = sx + int(_sin(ang) * spine_len) * side
            ey = sy - int(abs(_cos(ang)) * spine_len * 0.6)
            pygame.draw.line(surface, col, (sx, sy), (ex, ey), 1)

        # tibia 구간 가시 2개
        for t in [0.25, 0.55]:
            sx = int(kx + (fx - kx) * t)
            sy = int(ky + (fy - ky) * t)
            ang = _sin(self.time * 1.8 + leg_idx * 0.5) * 0.1 + side * 0.6
            ex = sx + int(_sin(ang) * spine_len * 0.7) * side
            ey = sy - int(abs(_cos(ang)) * spine_len * 0.4)
            pygame.draw.line(surface, col, (sx, sy), (ex, ey), 1)

    # ------- 몸체 체모 -------
    def _draw_body_hair(self, surface, bcx, bcy, w, h, p, squash_y):
        ceph_cy = int(bcy - h * 0.04 * squash_y)
        abd_cy = int(bcy + h * 0.12 * squash_y)

        positions = [
            # 두흉부
            (bcx - int(w * 0.05), ceph_cy - int(h * 0.02), 0.025, -0.5),
            (bcx + int(w * 0.05), ceph_cy - int(h * 0.01), 0.025, -0.6),
            # 복부
            (bcx - int(w * 0.08), abd_cy - int(h * 0.06), 0.03, -0.4),
            (bcx + int(w * 0.08), abd_cy - int(h * 0.05), 0.03, -0.5),
            (bcx - int(w * 0.03), abd_cy - int(h * 0.09), 0.025, -0.7),
            (bcx + int(w * 0.03), abd_cy - int(h * 0.08), 0.025, -0.6),
            (bcx, abd_cy + int(h * 0.07), 0.02, 0.5),
            (bcx - int(w * 0.06), abd_cy + int(h * 0.04), 0.02, 0.3),
            (bcx + int(w * 0.06), abd_cy + int(h * 0.03), 0.02, 0.4),
        ]

        col = p["hair"]
        for hx, hy, length_r, angle in positions:
            h_len = int(length_r * w)
            ex = hx + int(_sin(angle + _sin(self.time * 2.5 + hx * 0.1) * 0.08) * h_len)
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
        _spider_instance.lean = 0.0
        _spider_instance.body_bob = 0.0

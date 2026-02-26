# -*- coding: utf-8 -*-
"""
아라크네 (Arachne) 프로시저럴 보스 스프라이트
리얼리스틱 절지동물 디자인 — 큰 검은 복부, 어두운 적갈색 다리, 붉은 독아
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
        # 좌측 4개: 0,2,4,6  우측 4개: 1,3,5,7
        # 그룹A(0,3,4,7) vs 그룹B(1,2,5,6) — 교대
        self._leg_phase_offsets = [
            0.0, _pi, _pi, 0.0,
            0.0, _pi, _pi, 0.0,
        ]
        # 각 다리 기본 각도 (라디안) — 넓게 펼쳐진 절지동물 자세
        # 왼쪽 앞→뒤: 0,2,4,6 / 오른쪽 앞→뒤: 1,3,5,7
        self._leg_base_angles = [
            -1.05, 1.05,     # 1쌍 (앞, 가장 넓게)
            -0.55, 0.55,     # 2쌍
            0.10, -0.10,     # 3쌍
            0.60, -0.60,     # 4쌍 (뒤)
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
                    self._leg_twitch_timer[i] * (2.5 + i * 0.3)) * 0.04
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
        b = w / 10.0
        cx = w // 2
        cy = int(h * 0.48)

        self._draw_character(surface, cx, cy, b, w, h)
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
    #  렌더링
    # ===================================================================

    def _draw_character(self, surface, cx, cy, b, w, h):
        lean_offset = int(self.lean * 2.0 * b)
        bob_offset = int(self.body_bob * 1.5 * b)

        p = self._get_palette(self.hit_intensity * 0.3 if self.is_hit else 0.0)

        # 히트 squash/stretch
        squash_y = 1.0
        stretch_x = 1.0
        if self.is_hit:
            prog = self.hit_timer / self.hit_duration
            if prog < 0.15:
                t = prog / 0.15
                squash_y = 1.0 - 0.3 * t
                stretch_x = 1.0 + 0.15 * t
            elif prog < 0.30:
                t = (prog - 0.15) / 0.15
                squash_y = 0.7 + 0.45 * t
                stretch_x = 1.15 - 0.15 * t
            else:
                t = (prog - 0.30) / 0.70
                squash_y = 1.15 - 0.15 * min(t * 2, 1.0)
                stretch_x = 1.0

        gcx = cx + lean_offset
        gcy = cy + bob_offset

        # 레이어 순서: 다리(뒤) → 복부 → 두흉부 → 눈 → 독아 → 다리(앞) → 체모/가시
        self._draw_legs_back(surface, gcx, gcy, b, p, squash_y)
        self._draw_abdomen(surface, gcx, gcy, b, p, squash_y, stretch_x)
        self._draw_cephalothorax(surface, gcx, gcy, b, p, squash_y, stretch_x)
        self._draw_eyes(surface, gcx, gcy, b, p, squash_y)
        self._draw_chelicerae(surface, gcx, gcy, b, p, squash_y)
        self._draw_legs_front(surface, gcx, gcy, b, p, squash_y)
        self._draw_spines(surface, gcx, gcy, b, p, squash_y)

    def _get_palette(self, flash=0.0):
        def _f(base):
            return tuple(min(255, int(c + (255 - c) * flash)) for c in base)

        return {
            # 몸체 — 거의 검정에 가까운 어두운 톤
            "body_dark": _f((18, 12, 10)),
            "body": _f((32, 22, 18)),
            "body_light": _f((55, 40, 32)),
            "body_edge": _f((12, 8, 6)),
            # 복부 — 검은색 계열 + 미묘한 광택
            "abdomen": _f((25, 18, 15)),
            "abdomen_dark": _f((14, 10, 8)),
            "abdomen_light": _f((50, 38, 30)),
            "abdomen_sheen": _f((70, 55, 45)),     # 키틴질 광택
            "abdomen_marking": _f((80, 15, 10)),    # 붉은 무늬 (은은하게)
            "abdomen_marking2": _f((100, 25, 15)),
            # 눈 — 검은 눈, 붉은 반사
            "eye_main": _f((8, 5, 5)),
            "eye_secondary": _f((15, 8, 8)),
            "eye_shine": _f((220, 200, 180)),
            "eye_glow": _f((120, 30, 20)),          # 붉은 눈 빛
            # 독아 — 선명한 빨간색
            "fang": _f((90, 20, 15)),
            "fang_tip": _f((180, 30, 20)),
            "fang_dark": _f((50, 12, 10)),
            # 다리 — 어두운 적갈색/마룬
            "leg": _f((45, 22, 18)),
            "leg_light": _f((65, 38, 28)),
            "leg_dark": _f((25, 14, 10)),
            "leg_joint": _f((55, 30, 22)),
            "leg_segment": _f((38, 20, 16)),         # 마디 사이
            # 체모/가시
            "hair": _f((35, 20, 15)),
            "spine": _f((55, 30, 20)),               # 다리 가시
        }

    # ------- 복부 (abdomen) — 크고 둥근 검은 몸체 -------
    def _draw_abdomen(self, surface, cx, cy, b, p, squash_y, stretch_x):
        # 복부: 두흉부 뒤쪽 (아래쪽)에 매우 큰 구형
        abd_cx = cx
        abd_cy = int(cy + 1.5 * b * squash_y)
        abd_w = int(3.8 * b * stretch_x)    # 더 넓게
        abd_h = int(3.4 * b * squash_y)     # 더 크게

        # 그림자 (아래쪽)
        shadow_h = int(abd_h * 0.15)
        shadow_surf = pygame.Surface((abd_w + 4, shadow_h), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40),
                           (0, 0, abd_w + 4, shadow_h))
        surface.blit(shadow_surf,
                    (abd_cx - abd_w // 2 - 2,
                     abd_cy + abd_h // 2 - shadow_h // 2))

        # 복부 본체 — 어두운 그림자 레이어
        pygame.draw.ellipse(surface, p["abdomen_dark"],
                           (abd_cx - abd_w // 2 + 2,
                            abd_cy - abd_h // 2 + 2,
                            abd_w, abd_h))
        # 복부 본체
        pygame.draw.ellipse(surface, p["abdomen"],
                           (abd_cx - abd_w // 2,
                            abd_cy - abd_h // 2,
                            abd_w, abd_h))

        # 키틴질 광택 하이라이트 (왼쪽 위)
        hl_w = int(abd_w * 0.35)
        hl_h = int(abd_h * 0.25)
        hl_surf = pygame.Surface((hl_w, hl_h), pygame.SRCALPHA)
        pygame.draw.ellipse(hl_surf, (*p["abdomen_sheen"], 55),
                           (0, 0, hl_w, hl_h))
        surface.blit(hl_surf,
                    (abd_cx - hl_w // 2 - int(0.5 * b),
                     abd_cy - hl_h // 2 - int(0.7 * b)))

        # 두 번째 하이라이트 (작은, 중앙 상단)
        hl2_w = int(abd_w * 0.15)
        hl2_h = int(abd_h * 0.12)
        hl2_surf = pygame.Surface((hl2_w, hl2_h), pygame.SRCALPHA)
        pygame.draw.ellipse(hl2_surf, (*p["abdomen_light"], 70),
                           (0, 0, hl2_w, hl2_h))
        surface.blit(hl2_surf,
                    (abd_cx - hl2_w // 2 + int(0.2 * b),
                     abd_cy - hl2_h // 2 - int(0.9 * b)))

        # 복부 등 요철 텍스처 (미묘한 줄무늬)
        for i in range(3):
            ridge_y = abd_cy - int(0.3 * b) + int(i * 0.45 * b)
            ridge_w = int(abd_w * (0.5 - i * 0.1))
            ridge_surf = pygame.Surface((ridge_w, 2), pygame.SRCALPHA)
            pygame.draw.line(ridge_surf, (*p["abdomen_dark"][:3], 60),
                            (0, 0), (ridge_w, 0), 1)
            surface.blit(ridge_surf,
                        (abd_cx - ridge_w // 2, ridge_y))

        # 복부 테두리
        pygame.draw.ellipse(surface, p["body_edge"],
                           (abd_cx - abd_w // 2,
                            abd_cy - abd_h // 2,
                            abd_w, abd_h), max(1, int(0.07 * b)))

    # ------- 두흉부 (cephalothorax) — 앞쪽 작은 몸체 -------
    def _draw_cephalothorax(self, surface, cx, cy, b, p, squash_y, stretch_x):
        ceph_cx = cx
        ceph_cy = int(cy - 0.7 * b * squash_y)
        ceph_w = int(2.2 * b * stretch_x)
        ceph_h = int(1.5 * b * squash_y)

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
        # 키틴질 광택
        hl_r = max(2, int(0.30 * b))
        hl_surf = pygame.Surface((hl_r * 2, hl_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(hl_surf, (*p["body_light"], 60),
                          (hl_r, hl_r), hl_r)
        surface.blit(hl_surf,
                    (ceph_cx - hl_r - int(0.15 * b),
                     ceph_cy - hl_r - int(0.15 * b)))

        # 두흉부 중앙 홈 (fovea)
        fovea_len = int(0.4 * b)
        pygame.draw.line(surface, p["body_dark"],
                        (ceph_cx, ceph_cy - int(0.1 * b)),
                        (ceph_cx, ceph_cy + int(0.3 * b)),
                        max(1, int(0.04 * b)))

        # 테두리
        pygame.draw.ellipse(surface, p["body_edge"],
                           (ceph_cx - ceph_w // 2,
                            ceph_cy - ceph_h // 2,
                            ceph_w, ceph_h), max(1, int(0.05 * b)))

        # 두흉부-복부 연결부 (pedicel) — 좁은 허리
        ped_y = int(cy + 0.25 * b * squash_y)
        ped_w = int(0.55 * b)
        ped_h = int(0.5 * b * squash_y)
        pygame.draw.ellipse(surface, p["body_dark"],
                           (cx - ped_w // 2, ped_y - ped_h // 2,
                            ped_w, ped_h))

    # ------- 눈 8개 -------
    def _draw_eyes(self, surface, cx, cy, b, p, squash_y):
        ceph_cy = int(cy - 0.7 * b * squash_y)

        # 큰 주눈 2개 (중앙 앞쪽)
        for side in [-1, 1]:
            ex = cx + side * int(0.30 * b)
            ey = ceph_cy - int(0.22 * b * squash_y)
            er = max(3, int(0.22 * b))
            # 눈 본체 (검정)
            pygame.draw.circle(surface, p["eye_main"], (ex, ey), er)
            # 붉은 광택 (기존 초록 → 적색으로)
            pygame.draw.circle(surface, p["eye_glow"],
                              (ex, ey), max(2, er - 1))
            pygame.draw.circle(surface, p["eye_main"],
                              (ex, ey), max(1, er - 2))
            # 하이라이트
            sh_r = max(1, int(er * 0.35))
            pygame.draw.circle(surface, p["eye_shine"],
                              (ex - int(0.04 * b),
                               ey - int(0.04 * b)), sh_r)

        # 보조눈 6개 (작은, 주눈 주변 배치)
        secondary_positions = [
            (-0.52, -0.08),  # 왼쪽 위
            (0.52, -0.08),   # 오른쪽 위
            (-0.62, 0.10),   # 왼쪽 중
            (0.62, 0.10),    # 오른쪽 중
            (-0.40, 0.15),   # 왼쪽 아래
            (0.40, 0.15),    # 오른쪽 아래
        ]
        for sx, sy in secondary_positions:
            ex = cx + int(sx * b)
            ey = ceph_cy + int(sy * b * squash_y) - int(0.12 * b)
            er = max(2, int(0.09 * b))
            pygame.draw.circle(surface, p["eye_secondary"], (ex, ey), er)
            # 미세 빛 반사
            pygame.draw.circle(surface, (*p["eye_shine"][:3], 120),
                              (ex, ey - 1), max(1, er // 2))

    # ------- 독아 (chelicerae) — 선명한 빨간 독아 -------
    def _draw_chelicerae(self, surface, cx, cy, b, p, squash_y):
        ceph_cy = int(cy - 0.7 * b * squash_y)
        fang_base_y = ceph_cy + int(0.48 * b * squash_y)

        # 히트 시 독아 플래시 + 벌어짐
        spread = 0.0
        fang_flash = 0
        if self.is_hit:
            prog = self.hit_timer / self.hit_duration
            if prog < 0.25:
                spread = 0.18 * b * (prog / 0.25)
                fang_flash = int(200 * (1.0 - prog / 0.25))
            else:
                spread = 0.18 * b * max(0, 1.0 - (prog - 0.25) / 0.3)

        for side in [-1, 1]:
            # 기저부 (두꺼운 부분)
            base_x = cx + side * int(0.22 * b + spread)
            base_y = fang_base_y
            # 끝 (뾰족한 부분, 아래로 + 바깥으로 곡선)
            tip_x = base_x + side * int(0.18 * b)
            tip_y = base_y + int(0.60 * b)
            # 중간 곡선점
            mid_x = base_x + side * int(0.25 * b)
            mid_y = base_y + int(0.35 * b)

            fang_w = max(2, int(0.14 * b))
            # 그림자
            pygame.draw.line(surface, p["fang_dark"],
                            (base_x + 1, base_y + 1),
                            (mid_x + 1, mid_y + 1), fang_w + 1)
            pygame.draw.line(surface, p["fang_dark"],
                            (mid_x + 1, mid_y + 1),
                            (tip_x + 1, tip_y + 1), max(1, fang_w - 1))
            # 본체 — 빨간색 계열
            pygame.draw.line(surface, p["fang"],
                            (base_x, base_y), (mid_x, mid_y), fang_w)
            pygame.draw.line(surface, p["fang"],
                            (mid_x, mid_y), (tip_x, tip_y),
                            max(1, fang_w - 1))
            # 끝 밝은 빨간색
            pygame.draw.circle(surface, p["fang_tip"],
                              (tip_x, tip_y), max(2, int(0.07 * b)))

            # 히트 시 플래시
            if fang_flash > 0:
                fs = pygame.Surface((fang_w * 4, int(0.65 * b)), pygame.SRCALPHA)
                pygame.draw.line(fs, (255, 100, 80, fang_flash),
                                (fs.get_width() // 2, 0),
                                (fs.get_width() // 2, fs.get_height()),
                                fang_w + 2)
                surface.blit(fs, (base_x - fs.get_width() // 2, base_y))

    # ------- 다리 (뒤쪽 레이어 — 3,4쌍) -------
    def _draw_legs_back(self, surface, cx, cy, b, p, squash_y):
        self._draw_leg_pair(surface, cx, cy, b, p, squash_y, pair_idx=2)
        self._draw_leg_pair(surface, cx, cy, b, p, squash_y, pair_idx=3)

    # ------- 다리 (앞쪽 레이어 — 1,2쌍) -------
    def _draw_legs_front(self, surface, cx, cy, b, p, squash_y):
        self._draw_leg_pair(surface, cx, cy, b, p, squash_y, pair_idx=0)
        self._draw_leg_pair(surface, cx, cy, b, p, squash_y, pair_idx=1)

    def _draw_leg_pair(self, surface, cx, cy, b, p, squash_y, pair_idx):
        """한 쌍의 다리 (좌+우) 렌더링"""
        left_idx = pair_idx * 2
        right_idx = pair_idx * 2 + 1

        for leg_idx in [left_idx, right_idx]:
            side = -1 if leg_idx % 2 == 0 else 1
            self._draw_single_leg(surface, cx, cy, b, p, squash_y,
                                   leg_idx, side, pair_idx)

    def _draw_single_leg(self, surface, cx, cy, b, p, squash_y,
                          leg_idx, side, pair_idx):
        """단일 다리 렌더링 (3마디: coxa→femur→tibia) — 두꺼운 절지동물 다리"""
        base_angle = self._leg_base_angles[leg_idx]
        phase_offset = self._leg_phase_offsets[leg_idx]
        twitch = self._leg_twitch[leg_idx]

        # 걷기 움직임
        walk_anim = 0.0
        if self.direction != 0:
            walk_anim = _sin(self.step_phase + phase_offset) * 0.25
        walk_anim += twitch

        angle = base_angle + walk_anim

        # 다리 시작점 (두흉부 측면)
        ceph_cy = int(cy - 0.7 * b * squash_y)
        pair_y_offset = (pair_idx - 1.5) * 0.28
        hip_x = cx + side * int(0.95 * b)
        hip_y = int(ceph_cy + pair_y_offset * b * squash_y)

        # 다리 길이 — 앞쪽 다리가 가장 길고 뒤로 갈수록 짧아짐
        leg_length_mult = [1.25, 1.25, 1.1, 1.1, 1.0, 1.0, 0.88, 0.88]
        leg_len = 2.3 * b * leg_length_mult[leg_idx]

        # Coxa (1마디 — 짧고 두꺼운)
        coxa_len = leg_len * 0.18
        coxa_angle = angle * 0.6
        coxa_ex = hip_x + int(_sin(coxa_angle + side * 0.3) * coxa_len) * side
        coxa_ey = hip_y + int(_cos(coxa_angle) * coxa_len * 0.4 * squash_y)

        # Femur (2마디 — 가장 긴 마디, 위로 올라갔다 아래로)
        femur_len = leg_len * 0.42
        femur_angle = angle + side * 0.5
        # 위로 올라갔다가 옆으로 뻗음 (거미 특유의 높은 무릎)
        knee_x = coxa_ex + int(_sin(femur_angle) * femur_len) * side
        knee_y = coxa_ey - int(abs(_cos(femur_angle)) * femur_len * 0.75 * squash_y)
        # 걷기 시 무릎 높이 변화
        if self.direction != 0:
            lift = _sin(self.step_phase + phase_offset) * 0.35 * b
            if lift > 0:
                knee_y -= int(lift)

        # Tibia+Tarsus (3마디 — 아래로 내려감, 끝이 바닥에 닿음)
        tibia_len = leg_len * 0.45
        # 바닥에 닿는 느낌으로 아래로 쭉 내려감
        foot_x = knee_x + int(_sin(femur_angle * 0.5) * tibia_len * 0.45) * side
        foot_y = int(cy + 2.5 * b * squash_y)  # 바닥 근처 (더 넓게)
        # 걷기 시 발 위치 변화
        if self.direction != 0:
            step_lift = _sin(self.step_phase + phase_offset)
            if step_lift > 0:
                foot_y -= int(step_lift * 0.8 * b)
                foot_x += int(self.direction * step_lift * 0.3 * b)

        # 렌더링 — 더 두꺼운 다리
        leg_w = max(2, int(0.14 * b))
        joint_r = max(2, int(0.09 * b))

        # Coxa — 두꺼운 기저부
        pygame.draw.line(surface, p["leg_dark"],
                        (hip_x, hip_y), (coxa_ex, coxa_ey), leg_w + 2)
        pygame.draw.line(surface, p["leg"],
                        (hip_x, hip_y), (coxa_ex, coxa_ey), leg_w + 1)

        # Femur (무릎까지) — 굵은 마디
        pygame.draw.line(surface, p["leg_dark"],
                        (coxa_ex, coxa_ey), (knee_x, knee_y), leg_w + 2)
        pygame.draw.line(surface, p["leg"],
                        (coxa_ex, coxa_ey), (knee_x, knee_y), leg_w + 1)
        # femur 밝은 하이라이트
        pygame.draw.line(surface, p["leg_light"],
                        (coxa_ex, coxa_ey), (knee_x, knee_y),
                        max(1, leg_w - 1))

        # 무릎 관절 — 좀 더 크게
        pygame.draw.circle(surface, p["leg_dark"],
                          (knee_x, knee_y), joint_r + 1)
        pygame.draw.circle(surface, p["leg_joint"],
                          (knee_x, knee_y), joint_r)

        # Tibia (발까지) — 가늘어지는 다리
        pygame.draw.line(surface, p["leg_dark"],
                        (knee_x, knee_y), (foot_x, foot_y), leg_w + 1)
        pygame.draw.line(surface, p["leg_segment"],
                        (knee_x, knee_y), (foot_x, foot_y), leg_w)
        # tibia 하이라이트
        pygame.draw.line(surface, p["leg_light"],
                        (knee_x, knee_y), (foot_x, foot_y),
                        max(1, leg_w - 2))

        # 발끝 — 날카로운 발톱
        claw_len = int(0.15 * b)
        claw_x = foot_x + side * claw_len
        claw_y = foot_y + int(0.05 * b)
        pygame.draw.line(surface, p["leg_dark"],
                        (foot_x, foot_y), (claw_x, claw_y),
                        max(1, int(0.06 * b)))
        pygame.draw.circle(surface, p["leg_dark"],
                          (foot_x, foot_y), max(1, int(0.05 * b)))

        # 다리 가시/털 (각 마디에 2~3개)
        self._draw_leg_spines(surface, coxa_ex, coxa_ey,
                              knee_x, knee_y, foot_x, foot_y,
                              b, p, side, leg_idx)

    def _draw_leg_spines(self, surface, cx1, cy1, cx2, cy2, cx3, cy3,
                          b, p, side, leg_idx):
        """다리 마디별 가시/털"""
        spine_len = int(0.12 * b)
        spine_col = p["spine"]

        # femur 가시 (2개)
        for t in [0.3, 0.65]:
            sx = int(cx1 + (cx2 - cx1) * t)
            sy = int(cy1 + (cy2 - cy1) * t)
            angle_off = _sin(self.time * 2 + leg_idx) * 0.1
            s_ex = sx + int(_sin(angle_off + side * 0.8) * spine_len) * side
            s_ey = sy - int(abs(_cos(angle_off)) * spine_len * 0.6)
            pygame.draw.line(surface, spine_col,
                            (sx, sy), (s_ex, s_ey), 1)

        # tibia 가시 (2개)
        for t in [0.25, 0.55]:
            sx = int(cx2 + (cx3 - cx2) * t)
            sy = int(cy2 + (cy3 - cy2) * t)
            angle_off = _sin(self.time * 1.8 + leg_idx * 0.5) * 0.1
            s_ex = sx + int(_sin(angle_off + side * 0.6) * spine_len * 0.8) * side
            s_ey = sy - int(abs(_cos(angle_off)) * spine_len * 0.5)
            pygame.draw.line(surface, spine_col,
                            (sx, sy), (s_ex, s_ey), 1)

    # ------- 체모/가시 (spines on body) -------
    def _draw_spines(self, surface, cx, cy, b, p, squash_y):
        """몸체 위에 짧은 가시/털을 그림"""
        ceph_cy = int(cy - 0.7 * b * squash_y)
        abd_cy = int(cy + 1.5 * b * squash_y)

        hair_positions = [
            # 두흉부 가시
            (cx - int(0.45 * b), ceph_cy - int(0.15 * b), 0.16, -0.5),
            (cx + int(0.45 * b), ceph_cy - int(0.08 * b), 0.16, -0.6),
            (cx - int(0.65 * b), ceph_cy + int(0.10 * b), 0.13, -0.3),
            (cx + int(0.65 * b), ceph_cy + int(0.12 * b), 0.13, -0.4),
            # 복부 가시 (더 많이, 더 크게)
            (cx - int(0.9 * b), abd_cy - int(0.5 * b), 0.20, -0.4),
            (cx + int(0.9 * b), abd_cy - int(0.4 * b), 0.20, -0.5),
            (cx - int(0.4 * b), abd_cy - int(1.0 * b), 0.18, -0.7),
            (cx + int(0.4 * b), abd_cy - int(0.9 * b), 0.18, -0.6),
            (cx, abd_cy - int(0.6 * b), 0.15, -0.8),
            (cx - int(0.7 * b), abd_cy + int(0.1 * b), 0.16, -0.2),
            (cx + int(0.7 * b), abd_cy + int(0.0 * b), 0.16, -0.3),
            (cx - int(0.3 * b), abd_cy + int(0.6 * b), 0.14, 0.3),
            (cx + int(0.3 * b), abd_cy + int(0.5 * b), 0.14, 0.4),
            (cx, abd_cy + int(0.8 * b), 0.13, 0.5),
            # 추가 가시 (밀집)
            (cx - int(1.1 * b), abd_cy - int(0.1 * b), 0.15, -0.15),
            (cx + int(1.1 * b), abd_cy - int(0.2 * b), 0.15, -0.20),
        ]

        for hx, hy, length, angle in hair_positions:
            h_len = int(length * b)
            h_ex = hx + int(_sin(angle + _sin(self.time * 2.5 + hx * 0.1) * 0.08) * h_len)
            h_ey = hy + int(_cos(angle) * h_len)
            pygame.draw.line(surface, p["hair"],
                            (hx, hy), (h_ex, h_ey), 1)


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

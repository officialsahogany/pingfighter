"""
🧸 Teddy Bear Boss Sprite - 고퀄리티 프로시저럴 테디베어 보스 렌더링 (v6 Final)

- v4의 둥글고 귀여운 Ellipse 기반 체형 복원
- 2x SSAA 슈퍼샘플링 안티앨리어싱 (smoothscale)
- 얀데레 핑크 하트 눈 (v5에서 이식)
- 묵직한 거대 보스 모션 (50% 감속)
- 림 라이트 + 5단계 볼 홍조 그라데이션
- Lean/Head tilt 비활성화 (별도 히트 애니메이션 예정)
"""

import pygame
import math

_sin = math.sin
_cos = math.cos
_pi = math.pi
_tau = math.pi * 2

# SSAA 배율
_SSAA = 2


class TeddyBearBossSprite:
    """고퀄리티 테디베어 보스 프로시저럴 스프라이트 (2x SSAA)"""

    def __init__(self):
        self.time = 0.0

        # 이동 애니메이션 상태
        self.prev_x = None
        self.velocity = 0.0
        self.lean = 0.0
        self.lean_velocity = 0.0
        self.step_phase = 0.0
        self.body_bob = 0.0
        self.body_roll = 0.0
        self.arm_swing = 0.0
        self.head_tilt = 0.0
        self.ear_bounce = 0.0
        self.ribbon_flutter = 0.0
        self.move_dir = 0
        self.face_dir = 1.0
        self.face_dir_target = 0.0

        # 서피스 캐시
        self._surface_cache = {}
        self._ssaa_cache_key = None
        self._ssaa_cache_surf = None

    def _get_surface(self, w, h):
        w = max(4, ((w + 3) // 4) * 4)
        h = max(4, ((h + 3) // 4) * 4)
        key = (w, h)
        if key not in self._surface_cache:
            self._surface_cache[key] = pygame.Surface((w, h), pygame.SRCALPHA)
        else:
            self._surface_cache[key].fill((0, 0, 0, 0))
        return self._surface_cache[key]

    def update(self, boss_x, dt=1 / 60):
        """보스 위치 기반 애니메이션 업데이트 (묵직한 속도)"""
        self.time += dt

        if self.prev_x is not None:
            dx = boss_x - self.prev_x
            self.velocity = self.velocity * 0.75 + dx * 0.25
        self.prev_x = boss_x

        speed = abs(self.velocity)
        moving = speed > 0.3
        speed_ratio = min(1.0, speed / 10.0)

        # ★ 걸음 속도 50% 감속 — 묵직한 거대 보스
        if moving:
            self.move_dir = 1 if self.velocity > 0 else -1
            step_delta = (0.018 + speed_ratio * 0.035) * _tau
            self.step_phase = (self.step_phase + step_delta) % _tau
        else:
            self.step_phase *= 0.94
            if abs(self.step_phase) < 0.01:
                self.step_phase = 0.0

        # 관성 Lean 비활성화 (별도 히트 애니메이션 예정)
        self.lean = 0.0
        self.lean_velocity = 0.0

        # 바디 롤링 — 느린 주기
        if moving:
            self.body_roll = _sin(self.step_phase) * 2.0 * speed_ratio
        else:
            self.body_roll *= 0.92

        # ★ 바디 밥 — 느리고 묵직 (주파수 절반)
        if moving:
            self.body_bob = _sin(self.step_phase) * 2.0 * speed_ratio
        else:
            self.body_bob = _sin(self.time * 0.8) * 0.4

        # ★ 팔 흔들림 — 느린 진자 (주파수 절반, 진폭 약간 감소)
        if moving:
            self.arm_swing = _sin(self.step_phase) * 0.40 * speed_ratio
        else:
            self.arm_swing = _sin(self.time * 0.6) * 0.03

        # 머리 기울기 비활성화 (별도 히트 애니메이션 예정)
        self.head_tilt = 0.0

        # 귀 바운스
        if moving:
            self.ear_bounce = abs(_sin(self.step_phase)) * 2.0 * speed_ratio
        else:
            self.ear_bounce = _sin(self.time * 1.0) * 0.3

        # 리본 — 느린 펄럭임
        self.ribbon_flutter = _sin(self.time * 2.0 + self.step_phase) * 4.0

        # 얼굴 방향 — 느린 전환
        if moving:
            self.face_dir_target = float(self.move_dir)
        self.face_dir += (self.face_dir_target - self.face_dir) * 0.08

    def draw(self, screen, x, y, w, h):
        """2x SSAA 렌더링: 2배 서피스에 그린 후 smoothscale로 축소"""
        sw = w * _SSAA
        sh = h * _SSAA

        # SSAA 서피스 할당 (캐시)
        cache_key = (sw, sh)
        if self._ssaa_cache_key != cache_key:
            self._ssaa_cache_surf = pygame.Surface((sw, sh), pygame.SRCALPHA)
            self._ssaa_cache_key = cache_key
        hi_surf = self._ssaa_cache_surf
        hi_surf.fill((0, 0, 0, 0))

        # 2배 크기로 렌더링
        self._draw_internal(hi_surf, 0, 0, sw, sh)

        # smoothscale로 축소 → 안티앨리어싱
        lo_surf = pygame.transform.smoothscale(hi_surf, (w, h))
        screen.blit(lo_surf, (x, y))

    def _draw_internal(self, screen, x, y, w, h):
        """내부 렌더링 (SSAA 서피스 위에 그림)"""
        cx = x + w // 2
        cy = y + h // 2
        b = min(w, h) / 20.0

        lean_offset = int(self.lean * _SSAA)
        bob_offset = int(self.body_bob * _SSAA)
        roll_offset = self.body_roll * _SSAA
        fd = self.face_dir

        p = {
            "fur": (180, 130, 90),
            "fur_light": (215, 178, 140),
            "fur_lighter": (230, 200, 165),
            "fur_dark": (140, 95, 60),
            "fur_shadow": (95, 60, 35),
            "fur_rim": (240, 215, 185),
            "belly": (235, 218, 198),
            "belly_light": (245, 235, 220),
            "belly_shadow": (210, 190, 165),
            "pink": (255, 130, 170),
            "pink_light": (255, 170, 200),
            "pink_dark": (220, 90, 140),
            "pink_glow": (255, 180, 210),
            "nose_dark": (55, 35, 25),
            "nose_mid": (80, 55, 40),
            "nose_highlight": (120, 90, 70),
            "pad": (200, 160, 130),
            "pad_dark": (170, 130, 100),
            "mouth": (120, 75, 50),
        }

        torso_y = cy + bob_offset

        self._draw_ground_shadow(screen, cx + lean_offset, torso_y, b)
        self._draw_legs(screen, cx + lean_offset, torso_y, b, p, roll_offset)
        self._draw_body(screen, cx + lean_offset, torso_y, b, p, roll_offset)
        self._draw_arm(screen, cx + lean_offset, torso_y, b, p, is_back=True, roll=roll_offset)
        self._draw_head(screen, cx + lean_offset, torso_y + int(self.head_tilt * 0.3 * _SSAA), b, p, fd, roll_offset)
        self._draw_arm(screen, cx + lean_offset, torso_y, b, p, is_back=False, roll=roll_offset)

    # ──────────────────────── 그림자 ────────────────────────

    def _draw_ground_shadow(self, screen, cx, torso_y, b):
        shadow_y = torso_y + int(6.5 * b)
        shadow_rx = int(4.0 * b)
        shadow_ry = int(0.6 * b)
        shadow_surf = self._get_surface(shadow_rx * 2 + 4, shadow_ry * 2 + 4)
        scx, scy = shadow_rx + 2, shadow_ry + 2
        for ring in range(4):
            alpha = max(0, 40 - ring * 10)
            rx = max(3, shadow_rx - ring * int(0.35 * b))
            ry = max(2, shadow_ry - ring * int(0.08 * b))
            pygame.draw.ellipse(shadow_surf, (20, 10, 5, alpha),
                                (scx - rx, scy - ry, rx * 2, ry * 2))
        screen.blit(shadow_surf, (cx - scx, shadow_y - scy))

    # ──────────────────────── 다리 (Ellipse 기반) ────────────────────────

    def _draw_legs(self, screen, cx, torso_y, b, p, roll):
        leg_base_y = torso_y + int(3.0 * b)
        leg_w = int(2.4 * b)
        leg_h = int(3.2 * b)
        speed_factor = min(1.0, abs(self.velocity) / 8.0)

        for side in [-1, 1]:
            phase = self.step_phase + (0 if side == -1 else _pi)
            swing_x = _sin(phase) * 2.0 * b * speed_factor
            roll_y = int(roll * 0.3 * side)

            lx = cx + int(side * 1.8 * b) + int(roll * 0.4 * side) + int(swing_x)
            ly = leg_base_y + roll_y

            lift = max(0.0, _sin(phase)) * speed_factor
            ly -= int(lift * 0.8 * b)

            bend = lift
            upper_h = int(leg_h * (0.45 + bend * 0.1))
            lower_h = int(leg_h * (0.55 - bend * 0.1))
            knee_y = ly + upper_h

            # 윗다리
            pygame.draw.ellipse(screen, p["fur_shadow"],
                                (lx - leg_w // 2 + 1, ly + 1, leg_w + 2, upper_h + 2))
            pygame.draw.ellipse(screen, p["fur_dark"],
                                (lx - leg_w // 2, ly, leg_w, upper_h))
            inner_w = int(leg_w * 0.75)
            pygame.draw.ellipse(screen, p["fur"],
                                (lx - inner_w // 2, ly + int(0.1 * b), inner_w, int(upper_h * 0.85)))
            pygame.draw.ellipse(screen, p["fur_light"],
                                (lx - int(leg_w * 0.19) - int(0.15 * b), ly + int(0.15 * b),
                                 int(leg_w * 0.38), int(upper_h * 0.4)))

            # 아랫다리
            lower_w = int(leg_w * 0.9)
            pygame.draw.ellipse(screen, p["fur_dark"],
                                (lx - lower_w // 2, knee_y - int(0.2 * b), lower_w, lower_h))
            pygame.draw.ellipse(screen, p["fur"],
                                (lx - int(lower_w * 0.375), knee_y, int(lower_w * 0.75), int(lower_h * 0.8)))

            # 무릎
            pygame.draw.ellipse(screen, p["fur_dark"],
                                (lx - int(leg_w * 0.35), knee_y - int(0.2 * b),
                                 int(leg_w * 0.7), int(0.4 * b)))

            # 발바닥 패드
            pad_y = knee_y + int(lower_h * 0.55)
            pad_r = max(2, int(0.55 * b))
            pygame.draw.circle(screen, p["pad_dark"], (lx, pad_y), pad_r + 1)
            pygame.draw.circle(screen, p["pad"], (lx, pad_y), pad_r)
            pygame.draw.circle(screen, p["belly_light"], (lx - 1, pad_y - 1), max(1, pad_r // 2))
            for tx_off in [-0.5, 0, 0.5]:
                toe_x = lx + int(tx_off * 0.7 * b)
                toe_y = pad_y - int(0.55 * b)
                toe_r = max(1, int(0.24 * b))
                pygame.draw.circle(screen, p["pad_dark"], (toe_x, toe_y), toe_r + 1)
                pygame.draw.circle(screen, p["pad"], (toe_x, toe_y), toe_r)

    # ──────────────────────── 몸통 (Ellipse 기반) ────────────────────────

    def _draw_body(self, screen, cx, torso_y, b, p, roll):
        body_w = int(7.5 * b)
        body_h = int(5.5 * b)
        body_top = torso_y - int(0.5 * b)
        roll_x = int(roll * 0.5)
        bcx = cx + roll_x

        # 그림자
        pygame.draw.ellipse(screen, p["fur_shadow"],
                            (bcx - body_w // 2 + 2, body_top + 2, body_w, body_h))
        # 베이스
        pygame.draw.ellipse(screen, p["fur"],
                            (bcx - body_w // 2, body_top, body_w, body_h))

        # 다크 에지 (롤링 반영)
        edge_w = int(body_w * 0.2)
        edge_h = int(body_h * 0.7)
        la = max(0.6, min(1.4, 1.0 + roll / _SSAA * 0.025))
        ra = max(0.6, min(1.4, 1.0 - roll / _SSAA * 0.025))
        ld = tuple(max(0, min(255, int(c * la))) for c in p["fur_dark"])
        rd = tuple(max(0, min(255, int(c * ra))) for c in p["fur_dark"])
        pygame.draw.ellipse(screen, ld,
                            (bcx - body_w // 2 - int(0.1 * b), body_top + int(0.5 * b), edge_w, edge_h))
        pygame.draw.ellipse(screen, rd,
                            (bcx + body_w // 2 - edge_w + int(0.1 * b), body_top + int(0.5 * b), edge_w, edge_h))

        # 밝은 레이어
        light_w = int(body_w * 0.7)
        light_h = int(body_h * 0.65)
        pygame.draw.ellipse(screen, p["fur_light"],
                            (bcx - light_w // 2, body_top + int(0.4 * b), light_w, light_h))
        # 스펙큘러
        spec_w = int(body_w * 0.3)
        spec_h = int(body_h * 0.25)
        pygame.draw.ellipse(screen, p["fur_lighter"],
                            (bcx - spec_w // 2 - int(0.5 * b), body_top + int(0.7 * b), spec_w, spec_h))

        # ★ 림 라이트 (몸통 가장자리 밝은 테두리)
        rim_surf = self._get_surface(body_w + 4, body_h + 4)
        pygame.draw.ellipse(rim_surf, (*p["fur_rim"], 40),
                            (0, 0, body_w + 4, body_h + 4))
        inner_rim = pygame.Surface((body_w - int(0.6 * b), body_h - int(0.6 * b)), pygame.SRCALPHA)
        inner_rim.fill((0, 0, 0, 255))
        rim_surf.blit(inner_rim, (int(0.3 * b) + 2, int(0.3 * b) + 2),
                      special_flags=pygame.BLEND_RGBA_SUB)
        screen.blit(rim_surf, (bcx - body_w // 2 - 2, body_top - 2))

        # 배
        belly_w = int(4.5 * b)
        belly_h = int(3.5 * b)
        belly_top = body_top + int(1.0 * b)
        pygame.draw.ellipse(screen, p["belly_shadow"],
                            (bcx - belly_w // 2, belly_top + 1, belly_w, belly_h))
        pygame.draw.ellipse(screen, p["belly"],
                            (bcx - belly_w // 2, belly_top, belly_w, belly_h))
        pygame.draw.ellipse(screen, p["belly_light"],
                            (bcx - int(belly_w * 0.25) - int(0.3 * b), belly_top + int(0.3 * b),
                             int(belly_w * 0.5), int(belly_h * 0.4)))

        # 배꼽 하트
        heart_cx = bcx
        heart_cy = belly_top + int(belly_h * 0.55)
        hr = max(3, int(0.7 * b))
        glow_sz = hr * 4
        glow_surf = self._get_surface(glow_sz, glow_sz)
        pulse = (_sin(self.time * 1.5) + 1) * 0.5
        glow_alpha = int(25 + 20 * pulse)
        pygame.draw.circle(glow_surf, (*p["pink_glow"][:3], glow_alpha),
                          (glow_sz // 2, glow_sz // 2), hr * 2)
        screen.blit(glow_surf, (heart_cx - glow_sz // 2, heart_cy - glow_sz // 2),
                   special_flags=pygame.BLEND_ADD)

        pygame.draw.circle(screen, p["pink_dark"], (heart_cx - hr // 2, heart_cy - hr // 3), hr // 2 + 1)
        pygame.draw.circle(screen, p["pink_dark"], (heart_cx + hr // 2, heart_cy - hr // 3), hr // 2 + 1)
        pygame.draw.circle(screen, p["pink"], (heart_cx - hr // 2, heart_cy - hr // 3), hr // 2)
        pygame.draw.circle(screen, p["pink"], (heart_cx + hr // 2, heart_cy - hr // 3), hr // 2)
        pygame.draw.polygon(screen, p["pink"], [
            (heart_cx - hr, heart_cy - hr // 4),
            (heart_cx + hr, heart_cy - hr // 4),
            (heart_cx, heart_cy + hr)
        ])
        pygame.draw.circle(screen, p["pink_light"],
                          (heart_cx - hr // 3, heart_cy - hr // 2), max(1, hr // 4))

    # ──────────────────────── 팔 (Ellipse 기반) ────────────────────────

    def _draw_arm(self, screen, cx, torso_y, b, p, is_back, roll):
        arm_w = int(2.8 * b)
        arm_h = int(4.0 * b)
        side = -1 if is_back else 1

        shoulder_x = cx + int(side * 3.8 * b) + int(roll * 0.3 * side)
        shoulder_y = torso_y

        swing_angle = self.arm_swing * (-1 if is_back else 1)

        end_x = shoulder_x + int(_sin(swing_angle) * arm_h)
        end_y = shoulder_y + int(_cos(swing_angle) * arm_h)

        ax = (shoulder_x + end_x) // 2
        ay = (shoulder_y + end_y) // 2

        pygame.draw.ellipse(screen, p["fur_shadow"],
                            (ax - arm_w // 2 + 1, ay - arm_h // 2 + 1, arm_w + 2, arm_h + 2))
        pygame.draw.ellipse(screen, p["fur_dark"],
                            (ax - arm_w // 2, ay - arm_h // 2, arm_w, arm_h))
        inner_w = int(arm_w * 0.82)
        inner_h = int(arm_h * 0.88)
        pygame.draw.ellipse(screen, p["fur"],
                            (ax - inner_w // 2, ay - inner_h // 2 + int(0.15 * b), inner_w, inner_h))
        hl_w = int(arm_w * 0.4)
        hl_h = int(arm_h * 0.35)
        hl_x_off = int(-0.2 * b) if side < 0 else int(0.2 * b)
        pygame.draw.ellipse(screen, p["fur_light"],
                            (ax - hl_w // 2 + hl_x_off, ay - hl_h // 2 - int(0.3 * b), hl_w, hl_h))

        pad_r = max(2, int(0.45 * b))
        pygame.draw.circle(screen, p["pad_dark"], (end_x, end_y), pad_r + 1)
        pygame.draw.circle(screen, p["pad"], (end_x, end_y), pad_r)
        pygame.draw.circle(screen, p["belly_light"], (end_x - 1, end_y - 1), max(1, pad_r // 2))

    # ──────────────────────── 머리 ────────────────────────

    def _draw_head(self, screen, cx, torso_y, b, p, fd, roll):
        head_r = int(3.8 * b)
        head_cx = cx + int(roll * 0.3)
        head_cy = torso_y - int(3.0 * b)

        # ★ 얼굴 중심축만 이동 (내부 요소 변형 없음)
        face_shift = int(fd * 0.6 * b)

        # 머리 그림자
        pygame.draw.circle(screen, p["fur_shadow"], (head_cx + 2, head_cy + 2), head_r + 2)

        # 귀
        ear_bounce = self.ear_bounce * _SSAA
        for side in [-1, 1]:
            ear_cx = head_cx + int(side * 2.7 * b) + int(face_shift * 0.3)
            ear_cy = head_cy - int(2.5 * b) - int(ear_bounce * (0.5 if side == -1 else 0.3))
            ear_r = int(1.5 * b)

            pygame.draw.circle(screen, p["fur_shadow"], (ear_cx + 1, ear_cy + 1), ear_r + 2)
            pygame.draw.circle(screen, p["fur_dark"], (ear_cx, ear_cy), ear_r + 1)
            pygame.draw.circle(screen, p["fur"], (ear_cx, ear_cy), ear_r)
            pygame.draw.circle(screen, p["fur_light"],
                              (ear_cx - int(0.2 * b * side), ear_cy - int(0.2 * b)),
                              int(ear_r * 0.7))
            inner_r = int(ear_r * 0.6)
            pygame.draw.circle(screen, p["pink_dark"], (ear_cx, ear_cy + int(0.1 * b)), inner_r + 1)
            pygame.draw.circle(screen, p["pink"], (ear_cx, ear_cy + int(0.1 * b)), inner_r)
            pygame.draw.circle(screen, p["pink_light"],
                              (ear_cx - int(0.1 * b * side), ear_cy),
                              max(1, int(inner_r * 0.5)))

        # 머리 베이스
        pygame.draw.circle(screen, p["fur"], (head_cx, head_cy), head_r)

        # 머리 하단 음영
        pygame.draw.ellipse(screen, p["fur_dark"],
                            (head_cx - head_r, head_cy + int(0.5 * b), head_r * 2, int(2.0 * b)))

        # 머리 밝은 영역 (이마~상단, 눈 영역 침범 방지)
        pygame.draw.circle(screen, p["fur_light"],
                          (head_cx, head_cy - int(1.0 * b)), int(head_r * 0.55))

        # 머리 하이라이트
        pygame.draw.circle(screen, p["fur_lighter"],
                          (head_cx - int(0.8 * b), head_cy - int(1.3 * b)), int(head_r * 0.3))

        # 이마 글로시
        gw = int(2.5 * b)
        gh = int(1.2 * b)
        gloss_surf = self._get_surface(gw, gh)
        pygame.draw.ellipse(gloss_surf, (255, 255, 255, 25), (0, 0, gw, gh))
        screen.blit(gloss_surf, (head_cx - gw // 2, head_cy - int(2.2 * b)))

        # ★ 림 라이트 (머리 가장자리)
        rim_sz = head_r * 2 + 6
        rim_surf = self._get_surface(rim_sz, rim_sz)
        pygame.draw.circle(rim_surf, (*p["fur_rim"], 35),
                          (rim_sz // 2, rim_sz // 2), head_r + 2)
        inner_r_rim = head_r - int(0.3 * b)
        inner_rim = pygame.Surface((inner_r_rim * 2, inner_r_rim * 2), pygame.SRCALPHA)
        inner_rim.fill((0, 0, 0, 0))
        pygame.draw.circle(inner_rim, (0, 0, 0, 255),
                          (inner_r_rim, inner_r_rim), inner_r_rim)
        rim_surf.blit(inner_rim, (rim_sz // 2 - inner_r_rim, rim_sz // 2 - inner_r_rim),
                      special_flags=pygame.BLEND_RGBA_SUB)
        screen.blit(rim_surf, (head_cx - rim_sz // 2, head_cy - rim_sz // 2))

        # === 얼굴 (face_cx만 이동, 내부 요소는 고정 형태) ===
        face_cx = head_cx + face_shift
        face_cy = head_cy + int(0.3 * b)

        # ★ 눈 — 얀데레 핑크 하트 (v5에서 이식)
        for side in [-1, 1]:
            eye_cx = face_cx + int(side * 1.3 * b)
            eye_cy = face_cy - int(0.3 * b)

            hr = max(3, int(1.1 * b))  # 하트 반지름 (눈 전체 크기)

            # 하트 글로우 (배경 빛남)
            glow_r = int(hr * 2.2)
            glow_surf = self._get_surface(glow_r * 2, glow_r * 2)
            pulse = (_sin(self.time * 2.5) + 1) * 0.5
            glow_alpha = int(40 + 35 * pulse)
            pygame.draw.circle(glow_surf, (*p["pink_glow"][:3], glow_alpha),
                              (glow_r, glow_r), glow_r)
            screen.blit(glow_surf, (eye_cx - glow_r, eye_cy - glow_r),
                       special_flags=pygame.BLEND_ADD)

            # 하트 그림자 (약간 오프셋)
            lobe_r = int(hr * 0.55)
            sh_off = max(1, int(0.08 * b))
            pygame.draw.circle(screen, p["fur_shadow"],
                              (eye_cx - lobe_r + sh_off, eye_cy - int(hr * 0.15) + sh_off), lobe_r + 1)
            pygame.draw.circle(screen, p["fur_shadow"],
                              (eye_cx + lobe_r + sh_off, eye_cy - int(hr * 0.15) + sh_off), lobe_r + 1)
            pygame.draw.polygon(screen, p["fur_shadow"], [
                (eye_cx - hr + sh_off, eye_cy - int(hr * 0.05) + sh_off),
                (eye_cx + hr + sh_off, eye_cy - int(hr * 0.05) + sh_off),
                (eye_cx + sh_off, eye_cy + int(hr * 1.15) + sh_off)
            ])

            # 하트 다크 아웃라인
            outline = max(1, int(0.1 * b))
            pygame.draw.circle(screen, p["pink_dark"],
                              (eye_cx - lobe_r, eye_cy - int(hr * 0.15)), lobe_r + outline)
            pygame.draw.circle(screen, p["pink_dark"],
                              (eye_cx + lobe_r, eye_cy - int(hr * 0.15)), lobe_r + outline)
            pygame.draw.polygon(screen, p["pink_dark"], [
                (eye_cx - hr - outline, eye_cy - int(hr * 0.05)),
                (eye_cx + hr + outline, eye_cy - int(hr * 0.05)),
                (eye_cx, eye_cy + int(hr * 1.15) + outline)
            ])

            # 하트 본체 (원 2개 + 역삼각형)
            pygame.draw.circle(screen, p["pink"],
                              (eye_cx - lobe_r, eye_cy - int(hr * 0.15)), lobe_r)
            pygame.draw.circle(screen, p["pink"],
                              (eye_cx + lobe_r, eye_cy - int(hr * 0.15)), lobe_r)
            pygame.draw.polygon(screen, p["pink"], [
                (eye_cx - hr, eye_cy - int(hr * 0.05)),
                (eye_cx + hr, eye_cy - int(hr * 0.05)),
                (eye_cx, eye_cy + int(hr * 1.15))
            ])

            # 하트 밝은 레이어 (내부 상단)
            inner_lobe = int(lobe_r * 0.7)
            pygame.draw.circle(screen, p["pink_light"],
                              (eye_cx - lobe_r, eye_cy - int(hr * 0.3)), inner_lobe)
            pygame.draw.circle(screen, p["pink_light"],
                              (eye_cx + lobe_r, eye_cy - int(hr * 0.3)), inner_lobe)

            # 하이라이트 반짝 (좌상단)
            hl_r = max(1, int(hr * 0.22))
            pygame.draw.circle(screen, (255, 230, 240),
                              (eye_cx - int(hr * 0.4), eye_cy - int(hr * 0.4)), hl_r)

        # 코 (오밀조밀)
        nose_cx = face_cx
        nose_cy = face_cy + int(0.9 * b)
        nose_w = int(0.7 * b)
        nose_h = int(0.5 * b)
        pygame.draw.ellipse(screen, p["nose_dark"],
                            (nose_cx - nose_w // 2 + 1, nose_cy + 1, nose_w + 2, nose_h + 2))
        pygame.draw.ellipse(screen, p["nose_mid"],
                            (nose_cx - nose_w // 2, nose_cy, nose_w, nose_h))
        pygame.draw.ellipse(screen, p["nose_highlight"],
                            (nose_cx - nose_w // 4, nose_cy, nose_w // 2, int(nose_h * 0.5)))
        pygame.draw.circle(screen, (150, 120, 95),
                          (nose_cx - int(0.08 * b), nose_cy + int(0.08 * b)),
                          max(1, int(0.1 * b)))

        # 입 (W자, 코에 붙어서 오밀조밀)
        mouth_y = nose_cy + int(0.4 * b)
        mouth_w = int(0.9 * b)
        pygame.draw.arc(screen, p["mouth"],
                       (face_cx - mouth_w, mouth_y, mouth_w, int(0.4 * b)),
                       _pi, _tau, max(1, int(0.1 * b)))
        pygame.draw.arc(screen, p["mouth"],
                       (face_cx, mouth_y, mouth_w, int(0.4 * b)),
                       _pi, _tau, max(1, int(0.1 * b)))

        # ★ 볼 홍조 — 5단계 그라데이션
        for side in [-1, 1]:
            blush_cx = face_cx + int(side * 2.0 * b)
            blush_cy = face_cy + int(0.6 * b)
            blush_rx = int(1.1 * b)
            blush_ry = int(0.6 * b)
            blush_surf = self._get_surface(blush_rx * 2 + 4, blush_ry * 2 + 4)

            for layer in range(5):
                alpha = max(0, 55 - layer * 11)
                rx = max(2, blush_rx - layer * int(0.1 * b))
                ry = max(1, blush_ry - layer * int(0.05 * b))
                pygame.draw.ellipse(blush_surf, (255, 150, 170, alpha),
                                    (blush_rx + 2 - rx, blush_ry + 2 - ry, rx * 2, ry * 2))

            screen.blit(blush_surf, (blush_cx - blush_rx - 2, blush_cy - blush_ry - 2))

        # 리본
        ribbon_side = -1 if fd > 0.3 else 1
        self._draw_ribbon(screen, head_cx, head_cy, b, p, face_shift, ribbon_side)

    # ──────────────────────── 리본 ────────────────────────

    def _draw_ribbon(self, screen, head_cx, head_cy, b, p, face_shift, ribbon_side):
        ribbon_cx = head_cx + int(ribbon_side * 2.2 * b) + int(face_shift * 0.2)
        ribbon_cy = head_cy - int(2.8 * b)
        flutter = self.ribbon_flutter * _SSAA

        bow_w = int(1.4 * b)
        bow_h = int(0.9 * b)

        left_pts = [
            (ribbon_cx, ribbon_cy),
            (ribbon_cx - bow_w + int(flutter * 0.3), ribbon_cy - bow_h),
            (ribbon_cx - int(bow_w * 0.3), ribbon_cy),
            (ribbon_cx - bow_w - int(flutter * 0.2), ribbon_cy + bow_h),
        ]
        right_pts = [
            (ribbon_cx, ribbon_cy),
            (ribbon_cx + bow_w - int(flutter * 0.2), ribbon_cy - bow_h + int(flutter * 0.15)),
            (ribbon_cx + int(bow_w * 0.3), ribbon_cy),
            (ribbon_cx + bow_w + int(flutter * 0.3), ribbon_cy + bow_h - int(flutter * 0.1)),
        ]

        for pts in [left_pts, right_pts]:
            shadow = [(x + 2, y + 2) for x, y in pts]
            pygame.draw.polygon(screen, p["pink_dark"], shadow)
            pygame.draw.polygon(screen, p["pink"], pts)

        # 하이라이트
        for sign in [-1, 1]:
            hl = [
                (ribbon_cx, ribbon_cy),
                (ribbon_cx + int(sign * bow_w * 0.6), ribbon_cy - int(bow_h * 0.6)),
                (ribbon_cx + int(sign * bow_w * 0.2), ribbon_cy),
            ]
            pygame.draw.polygon(screen, p["pink_light"], hl)

        knot_r = max(2, int(0.3 * b))
        pygame.draw.circle(screen, p["pink_dark"], (ribbon_cx, ribbon_cy), knot_r + 1)
        pygame.draw.circle(screen, p["pink"], (ribbon_cx, ribbon_cy), knot_r)
        pygame.draw.circle(screen, p["pink_light"], (ribbon_cx - 1, ribbon_cy - 1), max(1, knot_r // 2))

        tail_len = int(1.5 * b)
        tail_f = int(_sin(self.time * 1.5) * 0.3 * b)
        for s, sx_off in [(-1, -int(0.15 * b)), (1, int(0.15 * b))]:
            tx = ribbon_cx + sx_off
            pts = [
                (tx, ribbon_cy + knot_r),
                (tx + int(s * 0.3 * b) + tail_f, ribbon_cy + knot_r + tail_len),
                (tx + int(s * 0.15 * b), ribbon_cy + knot_r + int(tail_len * 0.7)),
            ]
            pygame.draw.polygon(screen, p["pink"], pts)
            pygame.draw.line(screen, p["pink_light"], pts[0], pts[2], max(1, int(0.06 * b)))

    # ──────────────────────── 유틸리티 ────────────────────────

    def create_static_image(self, w=160, h=80):
        surf = pygame.Surface((w, h), pygame.SRCALPHA)
        self.draw(surf, 0, 0, w, h)
        return surf


_teddy_sprite_instance = None


def get_teddy_bear_sprite():
    global _teddy_sprite_instance
    if _teddy_sprite_instance is None:
        _teddy_sprite_instance = TeddyBearBossSprite()
    return _teddy_sprite_instance

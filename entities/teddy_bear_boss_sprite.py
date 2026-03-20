"""
Teddy Bear Boss Sprite v7 — Realistic Plush Teddy Bear

- 실제 봉제 곰인형의 비율과 질감을 프로시저럴로 재현
- 주둥이(마즐) 돌출, 유리 단추 눈(얀데레 하트 오버레이), 역삼각 코
- 봉제 이음새(seam) 라인, 솜 충전 볼록감, 패브릭 질감 노이즈
- 콩 모양 발바닥 패드, 솔기 디테일
- 3x SSAA 슈퍼샘플링
- 멘헤라 테마: 핑크 리본, 하트 눈, 깨진 하트 배 자수
"""

import pygame
import math

_sin = math.sin
_cos = math.cos
_pi = math.pi
_tau = math.pi * 2

# SSAA 배율 (3x로 업그레이드)
_SSAA = 3


class TeddyBearBossSprite:
    """리얼리스틱 봉제 곰인형 보스 스프라이트 (3x SSAA)"""

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

        if moving:
            self.move_dir = 1 if self.velocity > 0 else -1
            step_delta = (0.018 + speed_ratio * 0.035) * _tau
            self.step_phase = (self.step_phase + step_delta) % _tau
        else:
            self.step_phase *= 0.94
            if abs(self.step_phase) < 0.01:
                self.step_phase = 0.0

        self.lean = 0.0
        self.lean_velocity = 0.0

        if moving:
            self.body_roll = _sin(self.step_phase) * 2.0 * speed_ratio
        else:
            self.body_roll *= 0.92

        if moving:
            self.body_bob = _sin(self.step_phase) * 2.0 * speed_ratio
        else:
            self.body_bob = _sin(self.time * 0.8) * 0.4

        if moving:
            self.arm_swing = _sin(self.step_phase) * 0.40 * speed_ratio
        else:
            self.arm_swing = _sin(self.time * 0.6) * 0.03

        self.head_tilt = 0.0

        if moving:
            self.ear_bounce = abs(_sin(self.step_phase)) * 2.0 * speed_ratio
        else:
            self.ear_bounce = _sin(self.time * 1.0) * 0.3

        self.ribbon_flutter = _sin(self.time * 2.0 + self.step_phase) * 4.0

        if moving:
            self.face_dir_target = float(self.move_dir)
        self.face_dir += (self.face_dir_target - self.face_dir) * 0.08

    def draw(self, screen, x, y, w, h):
        """3x SSAA 렌더링"""
        sw = w * _SSAA
        sh = h * _SSAA

        cache_key = (sw, sh)
        if self._ssaa_cache_key != cache_key:
            self._ssaa_cache_surf = pygame.Surface((sw, sh), pygame.SRCALPHA)
            self._ssaa_cache_key = cache_key
        hi_surf = self._ssaa_cache_surf
        hi_surf.fill((0, 0, 0, 0))

        self._draw_internal(hi_surf, 0, 0, sw, sh)

        lo_surf = pygame.transform.smoothscale(hi_surf, (w, h))
        screen.blit(lo_surf, (x, y))

    # ═══════════════════════ 팔레트 ═══════════════════════

    @staticmethod
    def _palette():
        return {
            # 메인 퍼 (따뜻한 카라멜 브라운)
            "fur_base": (168, 120, 78),
            "fur_mid": (185, 140, 98),
            "fur_light": (210, 175, 135),
            "fur_highlight": (232, 210, 178),
            "fur_dark": (130, 88, 55),
            "fur_shadow": (90, 58, 32),
            "fur_deep": (65, 40, 22),
            "fur_rim": (235, 215, 190),
            # 머즐/배 (크림색 패브릭)
            "cream": (240, 225, 200),
            "cream_light": (250, 242, 228),
            "cream_shadow": (215, 195, 168),
            "cream_dark": (190, 168, 140),
            # 코 (가죽 질감)
            "nose_base": (42, 28, 18),
            "nose_mid": (65, 45, 30),
            "nose_shine": (95, 75, 58),
            "nose_gloss": (140, 120, 100),
            # 눈 (유리 단추)
            "eye_base": (15, 8, 5),
            "eye_ring": (45, 30, 20),
            "eye_shine": (255, 255, 255),
            # 멘헤라 핑크
            "pink": (255, 105, 150),
            "pink_light": (255, 160, 195),
            "pink_dark": (210, 70, 115),
            "pink_deep": (175, 45, 85),
            "pink_glow": (255, 180, 210),
            # 발바닥 패드
            "pad": (195, 155, 125),
            "pad_dark": (160, 120, 88),
            "pad_light": (220, 190, 160),
            # 이음새/스티치
            "stitch": (120, 80, 48),
            "stitch_light": (155, 115, 78),
            # 입
            "mouth": (100, 62, 38),
        }

    # ═══════════════════════ 내부 렌더링 ═══════════════════════

    def _draw_internal(self, screen, x, y, w, h):
        cx = x + w // 2
        cy = y + h // 2
        b = min(w, h) / 20.0
        S = _SSAA

        bob_offset = int(self.body_bob * S)
        roll_offset = self.body_roll * S
        fd = self.face_dir

        p = self._palette()

        torso_y = cy + bob_offset

        self._draw_ground_shadow(screen, cx, torso_y, b)
        self._draw_legs(screen, cx, torso_y, b, p, roll_offset)
        self._draw_body(screen, cx, torso_y, b, p, roll_offset)
        self._draw_arm(screen, cx, torso_y, b, p, is_back=True, roll=roll_offset)
        self._draw_head(screen, cx, torso_y, b, p, fd, roll_offset)
        self._draw_arm(screen, cx, torso_y, b, p, is_back=False, roll=roll_offset)

    # ═══════════════════════ 바닥 그림자 ═══════════════════════

    def _draw_ground_shadow(self, screen, cx, torso_y, b):
        shadow_y = torso_y + int(6.8 * b)
        rx = int(4.2 * b)
        ry = int(0.7 * b)
        surf = self._get_surface(rx * 2 + 8, ry * 2 + 8)
        scx, scy = rx + 4, ry + 4
        for ring in range(6):
            alpha = max(0, 50 - ring * 9)
            r_x = max(3, rx - ring * int(0.28 * b))
            r_y = max(2, ry - ring * int(0.06 * b))
            pygame.draw.ellipse(surf, (15, 8, 4, alpha),
                                (scx - r_x, scy - r_y, r_x * 2, r_y * 2))
        screen.blit(surf, (cx - scx, shadow_y - scy))

    # ═══════════════════════ 다리 ═══════════════════════

    def _draw_legs(self, screen, cx, torso_y, b, p, roll):
        leg_base_y = torso_y + int(2.8 * b)
        leg_w = int(2.6 * b)
        leg_h = int(3.5 * b)
        speed_factor = min(1.0, abs(self.velocity) / 8.0)

        for side in [-1, 1]:
            phase = self.step_phase + (0 if side == -1 else _pi)
            swing_x = _sin(phase) * 1.8 * b * speed_factor
            roll_y = int(roll * 0.3 * side)

            lx = cx + int(side * 2.0 * b) + int(roll * 0.4 * side) + int(swing_x)
            ly = leg_base_y + roll_y

            lift = max(0.0, _sin(phase)) * speed_factor
            ly -= int(lift * 0.8 * b)

            # 다리 전체 — 통통한 원통형
            # 그림자
            pygame.draw.ellipse(screen, p["fur_shadow"],
                                (lx - leg_w // 2 + 2, ly + 2, leg_w + 2, leg_h + 2))
            # 베이스
            pygame.draw.ellipse(screen, p["fur_dark"],
                                (lx - leg_w // 2, ly, leg_w, leg_h))
            # 메인 퍼
            inner = int(leg_w * 0.85)
            pygame.draw.ellipse(screen, p["fur_base"],
                                (lx - inner // 2, ly + int(0.1 * b), inner, int(leg_h * 0.92)))
            # 하이라이트
            hl_w = int(leg_w * 0.45)
            hl_h = int(leg_h * 0.5)
            pygame.draw.ellipse(screen, p["fur_mid"],
                                (lx - hl_w // 2 - int(0.15 * b * side), ly + int(0.15 * b),
                                 hl_w, hl_h))
            # 최상단 하이라이트
            pygame.draw.ellipse(screen, p["fur_light"],
                                (lx - int(hl_w * 0.35) - int(0.1 * b * side),
                                 ly + int(0.2 * b),
                                 int(hl_w * 0.7), int(hl_h * 0.45)))

            # 솔기(seam) — 다리 앞면 중앙 세로선
            seam_x = lx
            seam_top = ly + int(0.3 * b)
            seam_bot = ly + int(leg_h * 0.7)
            seam_w = max(1, int(0.06 * b))
            for seg_y in range(int(seam_top), int(seam_bot), max(2, int(0.25 * b))):
                dash_end = min(seg_y + max(1, int(0.12 * b)), int(seam_bot))
                pygame.draw.line(screen, p["stitch"],
                                 (seam_x, seg_y), (seam_x, dash_end), seam_w)

            # ── 발바닥 패드 (콩 모양) ──
            foot_y = ly + int(leg_h * 0.72)
            foot_w = int(leg_w * 1.1)
            foot_h = int(leg_h * 0.32)

            # 발 전체 (둥근 직사각형 근사)
            pygame.draw.ellipse(screen, p["fur_dark"],
                                (lx - foot_w // 2, foot_y, foot_w, foot_h))
            pygame.draw.ellipse(screen, p["fur_base"],
                                (lx - foot_w // 2 + 1, foot_y + 1, foot_w - 2, foot_h - 2))

            # 큰 패드 (중앙)
            main_pad_w = int(foot_w * 0.65)
            main_pad_h = int(foot_h * 0.6)
            pad_cx = lx
            pad_cy = foot_y + int(foot_h * 0.5)
            pygame.draw.ellipse(screen, p["pad_dark"],
                                (pad_cx - main_pad_w // 2 - 1, pad_cy - main_pad_h // 2 - 1,
                                 main_pad_w + 2, main_pad_h + 2))
            pygame.draw.ellipse(screen, p["pad"],
                                (pad_cx - main_pad_w // 2, pad_cy - main_pad_h // 2,
                                 main_pad_w, main_pad_h))
            # 패드 하이라이트
            pygame.draw.ellipse(screen, p["pad_light"],
                                (pad_cx - int(main_pad_w * 0.3), pad_cy - int(main_pad_h * 0.35),
                                 int(main_pad_w * 0.5), int(main_pad_h * 0.4)))

            # 발가락 패드 (3개)
            for ti, tx_off in enumerate([-0.32, 0.0, 0.32]):
                toe_x = lx + int(tx_off * foot_w * 0.7)
                toe_y = foot_y + int(foot_h * 0.12)
                toe_rx = max(2, int(0.28 * b))
                toe_ry = max(2, int(0.22 * b))
                pygame.draw.ellipse(screen, p["pad_dark"],
                                    (toe_x - toe_rx - 1, toe_y - toe_ry - 1,
                                     toe_rx * 2 + 2, toe_ry * 2 + 2))
                pygame.draw.ellipse(screen, p["pad"],
                                    (toe_x - toe_rx, toe_y - toe_ry,
                                     toe_rx * 2, toe_ry * 2))
                # 발가락 하이라이트
                pygame.draw.ellipse(screen, p["pad_light"],
                                    (toe_x - int(toe_rx * 0.4), toe_y - int(toe_ry * 0.5),
                                     int(toe_rx * 0.7), int(toe_ry * 0.6)))

    # ═══════════════════════ 몸통 ═══════════════════════

    def _draw_body(self, screen, cx, torso_y, b, p, roll):
        body_w = int(8.0 * b)
        body_h = int(6.0 * b)
        body_top = torso_y - int(1.0 * b)
        roll_x = int(roll * 0.5)
        bcx = cx + roll_x

        # ── 솜 충전 볼록감 표현 (다중 타원 겹침) ──
        # 깊은 그림자
        pygame.draw.ellipse(screen, p["fur_deep"],
                            (bcx - body_w // 2 + 3, body_top + 3, body_w, body_h))
        # 그림자
        pygame.draw.ellipse(screen, p["fur_shadow"],
                            (bcx - body_w // 2 + 1, body_top + 1, body_w, body_h))
        # 베이스 퍼
        pygame.draw.ellipse(screen, p["fur_base"],
                            (bcx - body_w // 2, body_top, body_w, body_h))

        # 좌우 암부 (롤링 반영한 음영)
        edge_w = int(body_w * 0.22)
        edge_h = int(body_h * 0.75)
        la = max(0.7, min(1.3, 1.0 + roll / _SSAA * 0.02))
        ra = max(0.7, min(1.3, 1.0 - roll / _SSAA * 0.02))
        ld = tuple(max(0, min(255, int(c * la))) for c in p["fur_dark"])
        rd = tuple(max(0, min(255, int(c * ra))) for c in p["fur_dark"])
        pygame.draw.ellipse(screen, ld,
                            (bcx - body_w // 2 - int(0.05 * b), body_top + int(0.6 * b),
                             edge_w, edge_h))
        pygame.draw.ellipse(screen, rd,
                            (bcx + body_w // 2 - edge_w + int(0.05 * b), body_top + int(0.6 * b),
                             edge_w, edge_h))

        # 중앙 밝은 레이어 (솜 볼록)
        light_w = int(body_w * 0.68)
        light_h = int(body_h * 0.62)
        pygame.draw.ellipse(screen, p["fur_mid"],
                            (bcx - light_w // 2, body_top + int(0.5 * b), light_w, light_h))
        # 최상부 하이라이트
        spec_w = int(body_w * 0.35)
        spec_h = int(body_h * 0.28)
        pygame.draw.ellipse(screen, p["fur_light"],
                            (bcx - spec_w // 2 - int(0.4 * b), body_top + int(0.8 * b),
                             spec_w, spec_h))
        # 피크 하이라이트 (광택)
        pk_w = int(body_w * 0.15)
        pk_h = int(body_h * 0.12)
        pygame.draw.ellipse(screen, p["fur_highlight"],
                            (bcx - pk_w // 2 - int(0.6 * b), body_top + int(1.0 * b),
                             pk_w, pk_h))

        # ── 림 라이트 ──
        rim_surf = self._get_surface(body_w + 8, body_h + 8)
        pygame.draw.ellipse(rim_surf, (*p["fur_rim"], 45),
                            (0, 0, body_w + 8, body_h + 8))
        inner_w = body_w - int(0.7 * b)
        inner_h = body_h - int(0.7 * b)
        inner_rim = pygame.Surface((inner_w, inner_h), pygame.SRCALPHA)
        inner_rim.fill((0, 0, 0, 255))
        rim_surf.blit(inner_rim, (int(0.35 * b) + 4, int(0.35 * b) + 4),
                      special_flags=pygame.BLEND_RGBA_SUB)
        screen.blit(rim_surf, (bcx - body_w // 2 - 4, body_top - 4))

        # ── 배 (크림색 패브릭 패치 — 타원형) ──
        belly_w = int(4.8 * b)
        belly_h = int(3.8 * b)
        belly_top = body_top + int(1.2 * b)
        belly_cx = bcx

        # 배 음영
        pygame.draw.ellipse(screen, p["cream_dark"],
                            (belly_cx - belly_w // 2 + 1, belly_top + 2,
                             belly_w, belly_h))
        # 배 베이스
        pygame.draw.ellipse(screen, p["cream"],
                            (belly_cx - belly_w // 2, belly_top, belly_w, belly_h))
        # 배 하이라이트 (솜 볼록)
        pygame.draw.ellipse(screen, p["cream_light"],
                            (belly_cx - int(belly_w * 0.3) - int(0.2 * b),
                             belly_top + int(0.3 * b),
                             int(belly_w * 0.5), int(belly_h * 0.45)))

        # 배-몸통 경계 스티치 (점선 타원)
        self._draw_stitch_ellipse(screen, belly_cx, belly_top + belly_h // 2,
                                  belly_w // 2, belly_h // 2, b, p)

        # ── 배꼽 하트 자수 (멘헤라 테마) ──
        heart_cx = belly_cx
        heart_cy = belly_top + int(belly_h * 0.52)
        hr = max(3, int(0.8 * b))

        # 하트 글로우
        glow_sz = hr * 5
        glow_surf = self._get_surface(glow_sz, glow_sz)
        pulse = (_sin(self.time * 1.5) + 1) * 0.5
        glow_alpha = int(22 + 18 * pulse)
        pygame.draw.circle(glow_surf, (*p["pink_glow"][:3], glow_alpha),
                           (glow_sz // 2, glow_sz // 2), int(hr * 2.2))
        screen.blit(glow_surf, (heart_cx - glow_sz // 2, heart_cy - glow_sz // 2),
                    special_flags=pygame.BLEND_ADD)

        # 자수 하트 (스티치 스타일)
        lobe_r = int(hr * 0.55)
        # 아웃라인
        self._draw_heart_shape(screen, heart_cx, heart_cy, hr, lobe_r, p["pink_dark"], 2)
        # 메인
        self._draw_heart_shape(screen, heart_cx, heart_cy, hr, lobe_r, p["pink"], 0)
        # 하이라이트
        self._draw_heart_shape(screen, heart_cx, heart_cy - int(hr * 0.15),
                               int(hr * 0.6), int(lobe_r * 0.5), p["pink_light"], 0)

        # 봉제 중앙 세로 솔기
        seam_top = body_top + int(0.4 * b)
        seam_bot = body_top + body_h - int(0.5 * b)
        seam_w = max(1, int(0.07 * b))
        for seg_y in range(int(seam_top), int(seam_bot), max(3, int(0.3 * b))):
            dy = min(seg_y + max(1, int(0.14 * b)), int(seam_bot))
            pygame.draw.line(screen, (*p["stitch"], 80),
                             (bcx, seg_y), (bcx, dy), seam_w)

    # ═══════════════════════ 팔 ═══════════════════════

    def _draw_arm(self, screen, cx, torso_y, b, p, is_back, roll):
        arm_w = int(2.8 * b)
        arm_h = int(4.2 * b)
        side = -1 if is_back else 1

        shoulder_x = cx + int(side * 4.0 * b) + int(roll * 0.3 * side)
        shoulder_y = torso_y - int(0.2 * b)

        swing_angle = self.arm_swing * (-1 if is_back else 1)

        end_x = shoulder_x + int(_sin(swing_angle) * arm_h)
        end_y = shoulder_y + int(_cos(swing_angle) * arm_h)

        ax = (shoulder_x + end_x) // 2
        ay = (shoulder_y + end_y) // 2

        # 그림자
        pygame.draw.ellipse(screen, p["fur_shadow"],
                            (ax - arm_w // 2 + 2, ay - arm_h // 2 + 2,
                             arm_w + 2, arm_h + 2))
        # 다크 에지
        pygame.draw.ellipse(screen, p["fur_dark"],
                            (ax - arm_w // 2, ay - arm_h // 2, arm_w, arm_h))
        # 메인 퍼
        inner_w = int(arm_w * 0.85)
        inner_h = int(arm_h * 0.90)
        pygame.draw.ellipse(screen, p["fur_base"],
                            (ax - inner_w // 2, ay - inner_h // 2 + int(0.1 * b),
                             inner_w, inner_h))
        # 하이라이트
        hl_w = int(arm_w * 0.45)
        hl_h = int(arm_h * 0.4)
        hl_x_off = int(-0.15 * b) if side < 0 else int(0.15 * b)
        pygame.draw.ellipse(screen, p["fur_mid"],
                            (ax - hl_w // 2 + hl_x_off, ay - hl_h // 2 - int(0.2 * b),
                             hl_w, hl_h))
        pygame.draw.ellipse(screen, p["fur_light"],
                            (ax - int(hl_w * 0.4) + hl_x_off, ay - int(hl_h * 0.35) - int(0.3 * b),
                             int(hl_w * 0.55), int(hl_h * 0.45)))

        # 팔 솔기 (세로)
        seam_w_v = max(1, int(0.06 * b))
        seam_t = ay - int(arm_h * 0.3)
        seam_b = ay + int(arm_h * 0.3)
        for sy in range(int(seam_t), int(seam_b), max(2, int(0.25 * b))):
            dy = min(sy + max(1, int(0.1 * b)), int(seam_b))
            pygame.draw.line(screen, (*p["stitch"], 60),
                             (ax, sy), (ax, dy), seam_w_v)

        # ── 손(발) 패드 ──
        pad_r = max(3, int(0.55 * b))
        # 그림자
        pygame.draw.circle(screen, p["fur_dark"], (end_x + 1, end_y + 1), pad_r + 2)
        # 베이스
        pygame.draw.circle(screen, p["fur_base"], (end_x, end_y), pad_r + 1)
        # 패드
        pygame.draw.circle(screen, p["pad_dark"], (end_x, end_y), pad_r)
        pygame.draw.circle(screen, p["pad"], (end_x, end_y), pad_r - 1)
        # 패드 하이라이트
        pygame.draw.circle(screen, p["pad_light"],
                           (end_x - int(0.1 * b), end_y - int(0.1 * b)),
                           max(1, pad_r // 2))

    # ═══════════════════════ 머리 ═══════════════════════

    def _draw_head(self, screen, cx, torso_y, b, p, fd, roll):
        head_rx = int(4.2 * b)
        head_ry = int(3.8 * b)
        head_cx = cx + int(roll * 0.3)
        head_cy = torso_y - int(3.5 * b)

        face_shift = int(fd * 0.6 * b)

        # ── 귀 (반원형, 리얼 봉제) ──
        ear_bounce = self.ear_bounce * _SSAA
        for side in [-1, 1]:
            ear_cx = head_cx + int(side * 3.0 * b) + int(face_shift * 0.25)
            ear_cy = head_cy - int(2.6 * b) - int(ear_bounce * (0.5 if side == -1 else 0.3))
            ear_rx = int(1.6 * b)
            ear_ry = int(1.8 * b)

            # 귀 그림자
            pygame.draw.ellipse(screen, p["fur_shadow"],
                                (ear_cx - ear_rx + 2, ear_cy - ear_ry + 2,
                                 ear_rx * 2, ear_ry * 2))
            # 귀 다크 테두리
            pygame.draw.ellipse(screen, p["fur_dark"],
                                (ear_cx - ear_rx, ear_cy - ear_ry,
                                 ear_rx * 2, ear_ry * 2))
            # 귀 메인
            inner_rx = int(ear_rx * 0.88)
            inner_ry = int(ear_ry * 0.88)
            pygame.draw.ellipse(screen, p["fur_base"],
                                (ear_cx - inner_rx, ear_cy - inner_ry + int(0.1 * b),
                                 inner_rx * 2, inner_ry * 2))
            # 귀 하이라이트
            pygame.draw.ellipse(screen, p["fur_mid"],
                                (ear_cx - int(ear_rx * 0.5) - int(0.15 * b * side),
                                 ear_cy - int(ear_ry * 0.6),
                                 int(ear_rx * 0.7), int(ear_ry * 0.6)))

            # 귀 안쪽 (핑크 — 멘헤라 테마)
            in_rx = int(ear_rx * 0.62)
            in_ry = int(ear_ry * 0.62)
            pygame.draw.ellipse(screen, p["pink_dark"],
                                (ear_cx - in_rx, ear_cy - in_ry + int(0.15 * b),
                                 in_rx * 2, in_ry * 2))
            pygame.draw.ellipse(screen, p["pink"],
                                (ear_cx - in_rx + 1, ear_cy - in_ry + int(0.2 * b),
                                 in_rx * 2 - 2, in_ry * 2 - 2))
            # 귀 안쪽 하이라이트
            pygame.draw.ellipse(screen, p["pink_light"],
                                (ear_cx - int(in_rx * 0.45) - int(0.08 * b * side),
                                 ear_cy - int(in_ry * 0.4),
                                 int(in_rx * 0.6), int(in_ry * 0.45)))

        # ── 머리 본체 (약간 세로로 긴 타원) ──
        # 깊은 그림자
        pygame.draw.ellipse(screen, p["fur_deep"],
                            (head_cx - head_rx + 3, head_cy - head_ry + 3,
                             head_rx * 2, head_ry * 2))
        # 그림자
        pygame.draw.ellipse(screen, p["fur_shadow"],
                            (head_cx - head_rx + 1, head_cy - head_ry + 1,
                             head_rx * 2, head_ry * 2))
        # 베이스
        pygame.draw.ellipse(screen, p["fur_base"],
                            (head_cx - head_rx, head_cy - head_ry,
                             head_rx * 2, head_ry * 2))

        # 하단 음영 (턱 아래)
        chin_h = int(1.8 * b)
        pygame.draw.ellipse(screen, p["fur_dark"],
                            (head_cx - head_rx + int(0.3 * b),
                             head_cy + int(0.8 * b),
                             head_rx * 2 - int(0.6 * b), chin_h))

        # 중앙 밝은 레이어
        pygame.draw.ellipse(screen, p["fur_mid"],
                            (head_cx - int(head_rx * 0.65), head_cy - int(head_ry * 0.7),
                             int(head_rx * 1.3), int(head_ry * 1.1)))
        # 이마 하이라이트
        pygame.draw.ellipse(screen, p["fur_light"],
                            (head_cx - int(head_rx * 0.4), head_cy - int(head_ry * 0.75),
                             int(head_rx * 0.8), int(head_ry * 0.5)))
        # 이마 피크 광택
        pygame.draw.ellipse(screen, p["fur_highlight"],
                            (head_cx - int(head_rx * 0.22) - int(0.4 * b),
                             head_cy - int(head_ry * 0.65),
                             int(head_rx * 0.35), int(head_ry * 0.22)))

        # 글로시 (이마 상단)
        gw = int(3.0 * b)
        gh = int(1.0 * b)
        gloss_surf = self._get_surface(gw, gh)
        pygame.draw.ellipse(gloss_surf, (255, 255, 255, 20), (0, 0, gw, gh))
        screen.blit(gloss_surf, (head_cx - gw // 2, head_cy - int(head_ry * 0.85)))

        # ── 림 라이트 ──
        rim_w = head_rx * 2 + 8
        rim_h = head_ry * 2 + 8
        rim_surf = self._get_surface(rim_w, rim_h)
        pygame.draw.ellipse(rim_surf, (*p["fur_rim"], 40),
                            (0, 0, rim_w, rim_h))
        inner_rw = head_rx * 2 - int(0.6 * b)
        inner_rh = head_ry * 2 - int(0.6 * b)
        inner_rim = pygame.Surface((inner_rw, inner_rh), pygame.SRCALPHA)
        inner_rim.fill((0, 0, 0, 255))
        rim_surf.blit(inner_rim, (int(0.3 * b) + 4, int(0.3 * b) + 4),
                      special_flags=pygame.BLEND_RGBA_SUB)
        screen.blit(rim_surf, (head_cx - rim_w // 2, head_cy - rim_h // 2))

        # ── 머리 중앙 세로 솔기 ──
        seam_top = head_cy - int(head_ry * 0.8)
        seam_bot = head_cy + int(head_ry * 0.15)
        seam_w = max(1, int(0.06 * b))
        for sy in range(int(seam_top), int(seam_bot), max(3, int(0.3 * b))):
            dy = min(sy + max(1, int(0.12 * b)), int(seam_bot))
            pygame.draw.line(screen, (*p["stitch"], 55),
                             (head_cx, sy), (head_cx, dy), seam_w)

        # === 얼굴 ===
        face_cx = head_cx + face_shift
        face_cy = head_cy + int(0.15 * b)

        # ── 머즐 (주둥이 — 크림색 돌출 타원) ──
        muzzle_w = int(3.0 * b)
        muzzle_h = int(2.2 * b)
        muzzle_cx = face_cx
        muzzle_cy = face_cy + int(0.8 * b)

        # 머즐 음영
        pygame.draw.ellipse(screen, p["cream_dark"],
                            (muzzle_cx - muzzle_w // 2 + 1, muzzle_cy - muzzle_h // 2 + 2,
                             muzzle_w, muzzle_h))
        # 머즐 베이스
        pygame.draw.ellipse(screen, p["cream"],
                            (muzzle_cx - muzzle_w // 2, muzzle_cy - muzzle_h // 2,
                             muzzle_w, muzzle_h))
        # 머즐 하이라이트
        pygame.draw.ellipse(screen, p["cream_light"],
                            (muzzle_cx - int(muzzle_w * 0.3) - int(0.15 * b),
                             muzzle_cy - int(muzzle_h * 0.35),
                             int(muzzle_w * 0.5), int(muzzle_h * 0.4)))

        # ── 코 (역삼각형 가죽 코) ──
        nose_cx = muzzle_cx
        nose_cy = muzzle_cy - int(0.2 * b)
        nose_w = int(1.1 * b)
        nose_h = int(0.75 * b)

        # 코 삼각형 포인트 계산
        nose_pts = [
            (nose_cx - nose_w // 2, nose_cy - nose_h // 3),
            (nose_cx + nose_w // 2, nose_cy - nose_h // 3),
            (nose_cx, nose_cy + int(nose_h * 0.65)),
        ]
        # 둥근 삼각형 근사 (삼각형 + 상단 원)
        # 그림자
        shadow_pts = [(x + 1, y + 2) for x, y in nose_pts]
        pygame.draw.polygon(screen, p["fur_shadow"], shadow_pts)
        # 베이스
        pygame.draw.polygon(screen, p["nose_base"], nose_pts)
        # 상단 둥글기 (원 2개)
        nose_top_r = max(2, int(nose_w * 0.32))
        pygame.draw.circle(screen, p["nose_base"],
                           (nose_cx - int(nose_w * 0.2), nose_cy - nose_h // 4), nose_top_r)
        pygame.draw.circle(screen, p["nose_base"],
                           (nose_cx + int(nose_w * 0.2), nose_cy - nose_h // 4), nose_top_r)
        # 코 하이라이트 (가죽 광택)
        pygame.draw.circle(screen, p["nose_mid"],
                           (nose_cx - int(nose_w * 0.15), nose_cy - nose_h // 5),
                           max(1, int(nose_top_r * 0.6)))
        pygame.draw.circle(screen, p["nose_shine"],
                           (nose_cx - int(nose_w * 0.15), nose_cy - int(nose_h * 0.3)),
                           max(1, int(nose_top_r * 0.35)))
        # 글로시 반짝임
        gloss_r = max(1, int(0.15 * b))
        pygame.draw.circle(screen, p["nose_gloss"],
                           (nose_cx - int(0.15 * b), nose_cy - int(0.15 * b)), gloss_r)

        # ── 입 (코에서 Y자로 내려가는 선) ──
        mouth_start_y = nose_cy + int(nose_h * 0.65)
        mouth_mid_y = muzzle_cy + int(0.35 * b)
        mouth_end_y = muzzle_cy + int(0.55 * b)
        mouth_lw = max(1, int(0.08 * b))

        # 코 아래 세로선
        pygame.draw.line(screen, p["mouth"],
                         (nose_cx, mouth_start_y), (nose_cx, mouth_mid_y), mouth_lw)
        # Y자 좌우 갈래
        mouth_spread = int(0.6 * b)
        pygame.draw.arc(screen, p["mouth"],
                        (nose_cx - mouth_spread, mouth_mid_y - int(0.15 * b),
                         mouth_spread, int(0.6 * b)),
                        _pi * 1.6, _tau, mouth_lw)
        pygame.draw.arc(screen, p["mouth"],
                        (nose_cx, mouth_mid_y - int(0.15 * b),
                         mouth_spread, int(0.6 * b)),
                        _pi, _pi * 1.4, mouth_lw)

        # ── 눈 (유리 단추 + 얀데레 하트 오버레이) ──
        for side_i in [-1, 1]:
            eye_cx = face_cx + int(side_i * 1.5 * b)
            eye_cy = face_cy - int(0.15 * b)

            # 유리 단추 눈 (베이스)
            eye_r = max(3, int(1.15 * b))

            # 눈 움푹 파인 홈 (봉제 인형 특유)
            socket_r = eye_r + max(1, int(0.2 * b))
            pygame.draw.circle(screen, p["fur_dark"], (eye_cx, eye_cy), socket_r)

            # 단추 테두리 (금속 링)
            pygame.draw.circle(screen, p["eye_ring"], (eye_cx, eye_cy), eye_r + max(1, int(0.1 * b)))

            # 단추 베이스 (검은 유리)
            pygame.draw.circle(screen, p["eye_base"], (eye_cx, eye_cy), eye_r)

            # ★ 멘헤라 하트 오버레이 ★
            hr = max(3, int(eye_r * 0.85))

            # 하트 글로우
            glow_r = int(hr * 2.5)
            glow_surf = self._get_surface(glow_r * 2, glow_r * 2)
            pulse = (_sin(self.time * 2.5) + 1) * 0.5
            glow_alpha = int(35 + 30 * pulse)
            pygame.draw.circle(glow_surf, (*p["pink_glow"][:3], glow_alpha),
                               (glow_r, glow_r), glow_r)
            screen.blit(glow_surf, (eye_cx - glow_r, eye_cy - glow_r),
                        special_flags=pygame.BLEND_ADD)

            # 하트 본체
            lobe_r = int(hr * 0.52)
            # 다크 아웃라인
            outline = max(1, int(0.08 * b))
            self._draw_heart_shape(screen, eye_cx, eye_cy, hr, lobe_r + outline,
                                   p["pink_dark"], outline)
            # 메인 핑크
            self._draw_heart_shape(screen, eye_cx, eye_cy, hr, lobe_r, p["pink"], 0)
            # 밝은 레이어
            self._draw_heart_shape(screen, eye_cx, eye_cy - int(hr * 0.12),
                                   int(hr * 0.65), int(lobe_r * 0.55),
                                   p["pink_light"], 0)

            # 하이라이트 반짝임 (유리 반사)
            hl_r = max(1, int(hr * 0.2))
            pygame.draw.circle(screen, (255, 240, 248),
                               (eye_cx - int(hr * 0.35), eye_cy - int(hr * 0.35)), hl_r)
            # 작은 서브 하이라이트
            sub_r = max(1, int(hr * 0.1))
            pygame.draw.circle(screen, (255, 220, 235),
                               (eye_cx + int(hr * 0.2), eye_cy + int(hr * 0.15)), sub_r)

            # 단추 구멍 (봉제 느낌 — 실 꿰맨 자국)
            hole_r = max(1, int(0.08 * b))
            stitch_col = (*p["pink_deep"], 120)
            for dx, dy in [(-0.25, -0.15), (0.25, -0.15), (-0.15, 0.25), (0.15, 0.25)]:
                hx = eye_cx + int(dx * hr)
                hy = eye_cy + int(dy * hr)
                hole_surf = self._get_surface(hole_r * 2 + 4, hole_r * 2 + 4)
                pygame.draw.circle(hole_surf, stitch_col,
                                   (hole_r + 2, hole_r + 2), hole_r)
                screen.blit(hole_surf, (hx - hole_r - 2, hy - hole_r - 2))

        # ── 볼 홍조 (7단계 소프트 그라데이션) ──
        for side_b in [-1, 1]:
            blush_cx = face_cx + int(side_b * 2.3 * b)
            blush_cy = face_cy + int(0.65 * b)
            blush_rx = int(1.2 * b)
            blush_ry = int(0.65 * b)
            blush_surf = self._get_surface(blush_rx * 2 + 8, blush_ry * 2 + 8)

            for layer in range(7):
                alpha = max(0, 50 - layer * 7)
                rx = max(2, blush_rx - layer * int(0.08 * b))
                ry = max(1, blush_ry - layer * int(0.04 * b))
                pygame.draw.ellipse(blush_surf, (255, 140, 165, alpha),
                                    (blush_rx + 4 - rx, blush_ry + 4 - ry,
                                     rx * 2, ry * 2))

            screen.blit(blush_surf, (blush_cx - blush_rx - 4, blush_cy - blush_ry - 4))

        # ── 리본 ──
        ribbon_side = -1 if fd > 0.3 else 1
        self._draw_ribbon(screen, head_cx, head_cy, head_ry, b, p, face_shift, ribbon_side)

    # ═══════════════════════ 리본 ═══════════════════════

    def _draw_ribbon(self, screen, head_cx, head_cy, head_ry, b, p, face_shift, ribbon_side):
        ribbon_cx = head_cx + int(ribbon_side * 2.6 * b) + int(face_shift * 0.2)
        ribbon_cy = head_cy - int(head_ry * 0.75)
        flutter = self.ribbon_flutter * _SSAA

        bow_w = int(1.6 * b)
        bow_h = int(1.0 * b)

        # 리본 날개 (좌우)
        left_pts = [
            (ribbon_cx, ribbon_cy),
            (ribbon_cx - bow_w + int(flutter * 0.3), ribbon_cy - bow_h),
            (ribbon_cx - int(bow_w * 0.35), ribbon_cy - int(bow_h * 0.1)),
            (ribbon_cx - bow_w - int(flutter * 0.2), ribbon_cy + bow_h),
        ]
        right_pts = [
            (ribbon_cx, ribbon_cy),
            (ribbon_cx + bow_w - int(flutter * 0.2), ribbon_cy - bow_h + int(flutter * 0.15)),
            (ribbon_cx + int(bow_w * 0.35), ribbon_cy - int(bow_h * 0.1)),
            (ribbon_cx + bow_w + int(flutter * 0.3), ribbon_cy + bow_h - int(flutter * 0.1)),
        ]

        for pts in [left_pts, right_pts]:
            # 그림자
            shadow = [(x + 2, y + 2) for x, y in pts]
            pygame.draw.polygon(screen, p["pink_deep"], shadow)
            # 메인
            pygame.draw.polygon(screen, p["pink"], pts)

        # 새틴 하이라이트
        for sign in [-1, 1]:
            hl = [
                (ribbon_cx, ribbon_cy),
                (ribbon_cx + int(sign * bow_w * 0.55), ribbon_cy - int(bow_h * 0.55)),
                (ribbon_cx + int(sign * bow_w * 0.15), ribbon_cy - int(bow_h * 0.05)),
            ]
            pygame.draw.polygon(screen, p["pink_light"], hl)
            # 추가 광택선
            hl2 = [
                (ribbon_cx + int(sign * bow_w * 0.1), ribbon_cy),
                (ribbon_cx + int(sign * bow_w * 0.45), ribbon_cy - int(bow_h * 0.35)),
                (ribbon_cx + int(sign * bow_w * 0.2), ribbon_cy - int(bow_h * 0.05)),
            ]
            hl2_surf = self._get_surface(int(bow_w * 2), int(bow_h * 2))
            local_pts = [(x - ribbon_cx + bow_w, y - ribbon_cy + bow_h) for x, y in hl2]
            pygame.draw.polygon(hl2_surf, (*p["pink_light"], 60), local_pts)
            screen.blit(hl2_surf, (ribbon_cx - bow_w, ribbon_cy - bow_h))

        # 매듭
        knot_r = max(3, int(0.35 * b))
        pygame.draw.circle(screen, p["pink_dark"], (ribbon_cx + 1, ribbon_cy + 1), knot_r + 1)
        pygame.draw.circle(screen, p["pink"], (ribbon_cx, ribbon_cy), knot_r)
        pygame.draw.circle(screen, p["pink_light"],
                           (ribbon_cx - int(0.06 * b), ribbon_cy - int(0.06 * b)),
                           max(1, knot_r // 2))

        # 꼬리 (하단으로 늘어지는 리본)
        tail_len = int(1.8 * b)
        tail_f = int(_sin(self.time * 1.5) * 0.35 * b)
        for s, sx_off in [(-1, -int(0.18 * b)), (1, int(0.18 * b))]:
            tx = ribbon_cx + sx_off
            pts = [
                (tx, ribbon_cy + knot_r),
                (tx + int(s * 0.35 * b) + tail_f, ribbon_cy + knot_r + tail_len),
                (tx + int(s * 0.12 * b) + int(tail_f * 0.5),
                 ribbon_cy + knot_r + int(tail_len * 0.6)),
                (tx + int(s * 0.05 * b), ribbon_cy + knot_r + int(tail_len * 0.3)),
            ]
            pygame.draw.polygon(screen, p["pink"], pts)
            # 꼬리 하이라이트
            pygame.draw.line(screen, p["pink_light"],
                             pts[0], pts[3], max(1, int(0.07 * b)))

    # ═══════════════════════ 유틸리티 ═══════════════════════

    def _draw_heart_shape(self, screen, cx, cy, hr, lobe_r, color, expand):
        """하트 형태 그리기 (원 2개 + 역삼각형)"""
        e = expand
        pygame.draw.circle(screen, color,
                           (cx - lobe_r, cy - int(hr * 0.15)), lobe_r + e)
        pygame.draw.circle(screen, color,
                           (cx + lobe_r, cy - int(hr * 0.15)), lobe_r + e)
        pygame.draw.polygon(screen, color, [
            (cx - hr - e, cy - int(hr * 0.05)),
            (cx + hr + e, cy - int(hr * 0.05)),
            (cx, cy + int(hr * 1.1) + e)
        ])

    def _draw_stitch_ellipse(self, screen, cx, cy, rx, ry, b, p):
        """타원형 점선 스티치 (봉제 이음새)"""
        stitch_col = (*p["stitch"], 65)
        stitch_w = max(1, int(0.06 * b))
        num_stitches = max(12, int(rx * 0.8))
        for i in range(num_stitches):
            if i % 2 == 1:
                continue
            angle1 = (i / num_stitches) * _tau
            angle2 = ((i + 0.7) / num_stitches) * _tau
            x1 = cx + int(rx * _cos(angle1))
            y1 = cy + int(ry * _sin(angle1))
            x2 = cx + int(rx * _cos(angle2))
            y2 = cy + int(ry * _sin(angle2))
            surf = self._get_surface(abs(x2 - x1) + 8, abs(y2 - y1) + 8)
            ox = min(x1, x2) - 4
            oy = min(y1, y2) - 4
            pygame.draw.line(surf, stitch_col,
                             (x1 - ox, y1 - oy), (x2 - ox, y2 - oy), stitch_w)
            screen.blit(surf, (ox, oy))

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

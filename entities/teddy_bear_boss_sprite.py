"""
🧸 Teddy Bear Boss Sprite - 고퀄리티 프로시저럴 테디베어 보스 렌더링
투기장 영웅(hero_paddles.py) 수준의 디테일한 캐릭터 렌더링 + 걷기 애니메이션

특징:
- 귀여운 씹덕(서브컬처) 스타일 디자인
- 크고 반짝이는 애니메이션 스타일 눈
- 다층 셰이딩 (그림자, 하이라이트, 스펙큘러)
- 다리 앞뒤 교차 걷기 애니메이션
- 어깨 축 진자 운동 팔 스윙
- 이동 방향 얼굴 반전 + 관성 Lean + 바디 롤링
"""

import pygame
import math

_sin = math.sin
_cos = math.cos
_pi = math.pi
_tau = math.pi * 2


class TeddyBearBossSprite:
    """고퀄리티 테디베어 보스 프로시저럴 스프라이트"""

    def __init__(self):
        self.time = 0.0

        # 이동 애니메이션 상태
        self.prev_x = None
        self.velocity = 0.0
        self.lean = 0.0            # 좌우 기울기 (관성 진자)
        self.lean_velocity = 0.0   # 기울기 각속도 (진자 물리)
        self.step_phase = 0.0      # 걷기 사이클 위상
        self.body_bob = 0.0        # 상하 바운스
        self.body_roll = 0.0       # 좌우 뒤뚱거림 (롤링)
        self.arm_swing = 0.0       # 팔 흔들림 각도 (라디안)
        self.head_tilt = 0.0       # 머리 기울기
        self.ear_bounce = 0.0      # 귀 바운스
        self.ribbon_flutter = 0.0  # 리본 펄럭임
        self.move_dir = 0          # 이동 방향 (-1, 0, 1)
        self.face_dir = 1          # 얼굴 방향 (부드러운 전환, -1~1)
        self.face_dir_target = 0   # 얼굴 방향 타겟

        # 서피스 캐시
        self._surface_cache = {}

    def _get_surface(self, w, h):
        w = max(4, ((w + 3) // 4) * 4)
        h = max(4, ((h + 3) // 4) * 4)
        key = (w, h)
        if key not in self._surface_cache:
            self._surface_cache[key] = pygame.Surface((w, h), pygame.SRCALPHA)
        else:
            self._surface_cache[key].fill((0, 0, 0, 0))
        return self._surface_cache[key]

    def update(self, boss_x, dt=1/60):
        """보스 위치 기반 애니메이션 업데이트"""
        self.time += dt

        if self.prev_x is not None:
            dx = boss_x - self.prev_x
            self.velocity = self.velocity * 0.7 + dx * 0.3
        self.prev_x = boss_x

        speed = abs(self.velocity)
        moving = speed > 0.3
        speed_ratio = min(1.0, speed / 10.0)

        if moving:
            self.move_dir = 1 if self.velocity > 0 else -1
            step_delta = (0.04 + speed_ratio * 0.08) * _tau
            self.step_phase = (self.step_phase + step_delta) % _tau
        else:
            self.step_phase *= 0.92
            if abs(self.step_phase) < 0.01:
                self.step_phase = 0.0

        # --- 관성 기반 Lean (감쇠 진자 운동) ---
        accel = self.velocity - (self.lean * 3.0)
        self.lean_velocity += accel * dt * 8.0
        self.lean_velocity *= 0.88
        self.lean += self.lean_velocity
        max_lean = 4.0
        self.lean = max(-max_lean, min(max_lean, self.lean))

        # --- 바디 롤링 (좌우 뒤뚱거림) ---
        if moving:
            self.body_roll = _sin(self.step_phase) * 2.5 * speed_ratio
        else:
            self.body_roll *= 0.9

        # 바디 밥 (걸을 때 통통 튀는 느낌)
        if moving:
            self.body_bob = _sin(self.step_phase * 2) * 2.5 * speed_ratio
        else:
            self.body_bob = _sin(self.time * 1.5) * 0.5

        # 팔 흔들림 (진자 각도 — 라디안)
        if moving:
            self.arm_swing = _sin(self.step_phase) * 0.55 * speed_ratio  # 최대 ~31도
        else:
            self.arm_swing = _sin(self.time * 1.2) * 0.05

        # 머리 기울기
        self.head_tilt = _sin(self.step_phase * 0.5) * 3.0 * speed_ratio if moving else _sin(self.time * 0.8) * 1.0

        # 귀 바운스
        self.ear_bounce = abs(_sin(self.step_phase * 2)) * 3.0 * speed_ratio if moving else _sin(self.time * 2) * 0.5

        # 리본 펄럭임
        self.ribbon_flutter = _sin(self.time * 4 + self.step_phase) * 5.0

        # --- 얼굴 방향 부드러운 전환 ---
        if moving:
            self.face_dir_target = self.move_dir
        self.face_dir += (self.face_dir_target - self.face_dir) * 0.12

    def draw(self, screen, x, y, w, h):
        """고퀄리티 테디베어 보스 렌더링"""
        cx = x + w // 2
        cy = y + h // 2
        b = min(w, h) / 20.0

        lean_offset = int(self.lean)
        bob_offset = int(self.body_bob)
        roll_offset = self.body_roll
        fd = self.face_dir

        # 색상 팔레트 (귀여운 서브컬처 테마)
        p = {
            "fur": (180, 130, 90),
            "fur_light": (215, 178, 140),
            "fur_lighter": (230, 200, 165),
            "fur_dark": (140, 95, 60),
            "fur_darker": (110, 72, 42),
            "fur_shadow": (95, 60, 35),
            "belly": (235, 218, 198),
            "belly_light": (245, 235, 220),
            "belly_shadow": (210, 190, 165),
            "pink": (255, 130, 170),
            "pink_light": (255, 170, 200),
            "pink_dark": (220, 90, 140),
            "pink_glow": (255, 180, 210),
            "eye_white": (255, 255, 255),
            "eye_iris": (80, 50, 30),
            "eye_iris_light": (120, 80, 55),
            "eye_pupil": (15, 10, 8),
            "eye_highlight": (255, 255, 255),
            "eye_highlight2": (255, 240, 245),
            "nose_dark": (55, 35, 25),
            "nose_mid": (80, 55, 40),
            "nose_highlight": (120, 90, 70),
            "pad": (200, 160, 130),
            "pad_dark": (170, 130, 100),
            "mouth": (120, 75, 50),
        }

        torso_y = cy + bob_offset

        # === 발밑 부드러운 그림자 ===
        self._draw_ground_shadow(screen, cx + lean_offset, torso_y, b)

        # === 다리 ===
        self._draw_legs(screen, cx + lean_offset, torso_y, b, p, roll_offset)

        # === 몸통 ===
        self._draw_body(screen, cx + lean_offset, torso_y, b, p, roll_offset)

        # === 팔 (뒤쪽) ===
        self._draw_arm(screen, cx + lean_offset, torso_y, b, p, is_back=True, roll=roll_offset)

        # === 머리 ===
        self._draw_head(screen, cx + lean_offset, torso_y + int(self.head_tilt * 0.3), b, p, fd, roll_offset)

        # === 팔 (앞쪽) ===
        self._draw_arm(screen, cx + lean_offset, torso_y, b, p, is_back=False, roll=roll_offset)

    def _draw_ground_shadow(self, screen, cx, torso_y, b):
        """발밑 부드러운 그림자"""
        shadow_y = torso_y + int(6.5 * b)
        shadow_rx = int(4.0 * b)
        shadow_ry = int(0.6 * b)
        shadow_surf = self._get_surface(shadow_rx * 2 + 4, shadow_ry * 2 + 4)
        scx, scy = shadow_rx + 2, shadow_ry + 2

        for ring in range(3):
            alpha = max(0, 35 - ring * 12)
            rx = max(3, shadow_rx - ring * int(0.4 * b))
            ry = max(2, shadow_ry - ring * int(0.1 * b))
            pygame.draw.ellipse(shadow_surf, (20, 10, 5, alpha),
                                (scx - rx, scy - ry, rx * 2, ry * 2))

        screen.blit(shadow_surf, (cx - scx, shadow_y - scy))

    def _draw_legs(self, screen, cx, torso_y, b, p, roll):
        """다리 — 앞뒤 교차 걷기 + 관절 굽힘 + 발바닥 패드"""
        leg_base_y = torso_y + int(3.0 * b)
        leg_w = int(2.4 * b)
        leg_h = int(3.2 * b)

        speed_factor = min(1.0, abs(self.velocity) / 8.0)

        for side in [-1, 1]:
            # 걷기 위상 (왼/오른 다리 반대)
            phase = self.step_phase + (0 if side == -1 else _pi)

            # ★ 핵심 수정: swing을 X좌표에 적용하여 앞뒤 교차 걷기
            swing_x = _sin(phase) * 2.0 * b * speed_factor

            # 롤링에 의한 좌우 기울기
            roll_y = int(roll * 0.3 * side)

            lx = cx + int(side * 1.8 * b) + int(roll * 0.4 * side) + int(swing_x)
            ly = leg_base_y + roll_y

            # 관절 굽힘: 다리가 앞에 있을 때(swing_x > 0) 무릎이 약간 올라감
            lift = abs(_sin(phase)) * speed_factor
            ly_lift = int(lift * 0.8 * b)  # 들어올려지는 높이
            ly -= ly_lift

            bend = lift
            upper_h = int(leg_h * (0.45 + bend * 0.1))
            lower_h = int(leg_h * (0.55 - bend * 0.1))
            knee_y = ly + upper_h

            # 윗다리 (허벅지)
            pygame.draw.ellipse(screen, p["fur_shadow"],
                                (lx - leg_w // 2 + 1, ly + 1, leg_w + 2, upper_h + 2))
            pygame.draw.ellipse(screen, p["fur_dark"],
                                (lx - leg_w // 2, ly, leg_w, upper_h))
            inner_w = int(leg_w * 0.75)
            pygame.draw.ellipse(screen, p["fur"],
                                (lx - inner_w // 2, ly + int(0.1 * b), inner_w, int(upper_h * 0.85)))
            hl_w = int(leg_w * 0.38)
            hl_h = int(upper_h * 0.4)
            pygame.draw.ellipse(screen, p["fur_light"],
                                (lx - hl_w // 2 - int(0.15 * b), ly + int(0.15 * b), hl_w, hl_h))

            # 아랫다리
            lower_w = int(leg_w * 0.9)
            pygame.draw.ellipse(screen, p["fur_dark"],
                                (lx - lower_w // 2, knee_y - int(0.2 * b), lower_w, lower_h))
            inner_lower_w = int(lower_w * 0.75)
            pygame.draw.ellipse(screen, p["fur"],
                                (lx - inner_lower_w // 2, knee_y, inner_lower_w, int(lower_h * 0.8)))

            # 무릎 관절
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

    def _draw_body(self, screen, cx, torso_y, b, p, roll):
        """몸통 — 다층 셰이딩, 배꼽 하트, 롤링 (스티칭 제거됨)"""
        body_w = int(7.5 * b)
        body_h = int(5.5 * b)
        body_top = torso_y - int(0.5 * b)
        roll_x = int(roll * 0.5)

        # 몸통 그림자
        pygame.draw.ellipse(screen, p["fur_shadow"],
                            (cx + roll_x - body_w // 2 + 2, body_top + 2, body_w, body_h))

        # 몸통 베이스
        pygame.draw.ellipse(screen, p["fur"],
                            (cx + roll_x - body_w // 2, body_top, body_w, body_h))

        # 몸통 다크 에지 (롤링 반영)
        edge_w = int(body_w * 0.2)
        edge_h = int(body_h * 0.7)
        left_alpha = max(0.6, min(1.4, 1.0 + roll * 0.05))
        right_alpha = max(0.6, min(1.4, 1.0 - roll * 0.05))
        left_dark = tuple(max(0, min(255, int(c * left_alpha))) for c in p["fur_dark"])
        right_dark = tuple(max(0, min(255, int(c * right_alpha))) for c in p["fur_dark"])
        pygame.draw.ellipse(screen, left_dark,
                            (cx + roll_x - body_w // 2 - int(0.1 * b), body_top + int(0.5 * b), edge_w, edge_h))
        pygame.draw.ellipse(screen, right_dark,
                            (cx + roll_x + body_w // 2 - edge_w + int(0.1 * b), body_top + int(0.5 * b), edge_w, edge_h))

        # 몸통 밝은 레이어
        light_w = int(body_w * 0.7)
        light_h = int(body_h * 0.65)
        pygame.draw.ellipse(screen, p["fur_light"],
                            (cx + roll_x - light_w // 2, body_top + int(0.4 * b), light_w, light_h))

        # 하이라이트 스펙큘러
        spec_w = int(body_w * 0.3)
        spec_h = int(body_h * 0.25)
        pygame.draw.ellipse(screen, p["fur_lighter"],
                            (cx + roll_x - spec_w // 2 - int(0.5 * b), body_top + int(0.7 * b), spec_w, spec_h))

        # 배 (밝은 타원)
        belly_w = int(4.5 * b)
        belly_h = int(3.5 * b)
        belly_top = body_top + int(1.0 * b)
        pygame.draw.ellipse(screen, p["belly_shadow"],
                            (cx + roll_x - belly_w // 2, belly_top + 1, belly_w, belly_h))
        pygame.draw.ellipse(screen, p["belly"],
                            (cx + roll_x - belly_w // 2, belly_top, belly_w, belly_h))
        belly_hl_w = int(belly_w * 0.5)
        belly_hl_h = int(belly_h * 0.4)
        pygame.draw.ellipse(screen, p["belly_light"],
                            (cx + roll_x - belly_hl_w // 2 - int(0.3 * b), belly_top + int(0.3 * b),
                             belly_hl_w, belly_hl_h))

        # 배꼽 하트 (글로우 펄스)
        heart_cx = cx + roll_x
        heart_cy = belly_top + int(belly_h * 0.55)
        hr = max(3, int(0.7 * b))
        glow_sz = hr * 4
        glow_surf = self._get_surface(glow_sz, glow_sz)
        pulse = (_sin(self.time * 2.5) + 1) * 0.5
        glow_alpha = int(30 + 25 * pulse)
        pygame.draw.circle(glow_surf, (*p["pink_glow"][:3], glow_alpha),
                          (glow_sz // 2, glow_sz // 2), hr * 2)
        screen.blit(glow_surf, (heart_cx - glow_sz // 2, heart_cy - glow_sz // 2),
                   special_flags=pygame.BLEND_ADD)

        # 하트 형태
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

    def _draw_arm(self, screen, cx, torso_y, b, p, is_back, roll):
        """팔 — 어깨 축 진자 운동 스윙 + 발바닥 패드"""
        arm_w = int(2.8 * b)
        arm_h = int(4.0 * b)

        side = -1 if is_back else 1

        # 어깨 피벗 위치 (몸통 상단 좌우)
        shoulder_x = cx + int(side * 3.8 * b) + int(roll * 0.3 * side)
        shoulder_y = torso_y + int(0.0 * b)

        # ★ 핵심 수정: 진자 운동 — 어깨를 축으로 팔이 앞뒤로 회전
        # 앞팔/뒷팔 반대 위상
        swing_angle = self.arm_swing * (1 if is_back else -1)

        # 진자 끝점 (어깨에서 arm_h 길이만큼 회전)
        end_x = shoulder_x + int(_sin(swing_angle) * arm_h)
        end_y = shoulder_y + int(_cos(swing_angle) * arm_h)

        # 팔 중심 좌표
        ax = (shoulder_x + end_x) // 2
        ay = (shoulder_y + end_y) // 2

        # 진자 궤적으로 인해 올라가는 높이 (코사인 차이)
        # swing_angle=0일 때 arm_h, 각도가 커지면 cos < 1 → 약간 올라감

        # 팔 그림자
        pygame.draw.ellipse(screen, p["fur_shadow"],
                            (ax - arm_w // 2 + 1, ay - arm_h // 2 + 1, arm_w + 2, arm_h + 2))
        # 팔 다크 레이어
        pygame.draw.ellipse(screen, p["fur_dark"],
                            (ax - arm_w // 2, ay - arm_h // 2, arm_w, arm_h))
        # 팔 메인
        inner_w = int(arm_w * 0.82)
        inner_h = int(arm_h * 0.88)
        pygame.draw.ellipse(screen, p["fur"],
                            (ax - inner_w // 2, ay - inner_h // 2 + int(0.15 * b), inner_w, inner_h))
        # 팔 하이라이트
        hl_w = int(arm_w * 0.4)
        hl_h = int(arm_h * 0.35)
        hl_x_off = int(-0.2 * b) if side < 0 else int(0.2 * b)
        pygame.draw.ellipse(screen, p["fur_light"],
                            (ax - hl_w // 2 + hl_x_off, ay - hl_h // 2 - int(0.3 * b), hl_w, hl_h))

        # 발바닥 패드 (팔 끝 = 진자 끝점)
        pad_r = max(2, int(0.45 * b))
        pygame.draw.circle(screen, p["pad_dark"], (end_x, end_y), pad_r + 1)
        pygame.draw.circle(screen, p["pad"], (end_x, end_y), pad_r)
        pygame.draw.circle(screen, p["belly_light"],
                          (end_x - 1, end_y - 1), max(1, pad_r // 2))

    def _draw_head(self, screen, cx, torso_y, b, p, fd, roll):
        """머리 — 귀, 큰 애니메이션 눈, 코, 입, 볼 홍조, 리본"""
        head_r = int(3.8 * b)
        head_cx = cx + int(roll * 0.3)
        head_cy = torso_y - int(3.0 * b)

        face_shift = int(fd * 0.6 * b)

        # 머리 그림자
        pygame.draw.circle(screen, p["fur_shadow"], (head_cx + 2, head_cy + 2), head_r + 2)

        # === 귀 ===
        ear_bounce = self.ear_bounce
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

        # 머리 다크 에지 (하단)
        pygame.draw.ellipse(screen, p["fur_dark"],
                            (head_cx - head_r, head_cy + int(0.5 * b), head_r * 2, int(2.0 * b)))

        # 머리 밝은 영역
        light_r = int(head_r * 0.78)
        pygame.draw.circle(screen, p["fur_light"], (head_cx, head_cy - int(0.3 * b)), light_r)

        # 머리 하이라이트
        spec_r = int(head_r * 0.4)
        pygame.draw.circle(screen, p["fur_lighter"],
                          (head_cx - int(0.8 * b), head_cy - int(1.0 * b)), spec_r)

        # 이마 글로시 하이라이트
        gloss_surf = self._get_surface(int(2.5 * b), int(1.2 * b))
        pygame.draw.ellipse(gloss_surf, (255, 255, 255, 25),
                            (0, 0, int(2.5 * b), int(1.2 * b)))
        screen.blit(gloss_surf, (head_cx - int(1.25 * b), head_cy - int(2.2 * b)))

        # === 얼굴 디테일 ===
        face_cx = head_cx + face_shift
        face_cy = head_cy + int(0.3 * b)

        # --- ★ 눈 (크고 반짝이는 애니메이션 스타일) ---
        for side in [-1, 1]:
            eye_spread = 1.3 + fd * side * 0.15
            eye_cx = face_cx + int(side * eye_spread * b)
            eye_cy = face_cy - int(0.3 * b)
            # 바라보는 쪽 눈이 약간 더 큼
            eye_scale = 1.0 + fd * side * 0.08

            # 눈 크기 (크고 둥근 타원)
            ew = int(1.3 * b * eye_scale)  # 가로
            eh = int(1.5 * b * eye_scale)  # 세로 (세로가 약간 더 큰 타원)

            # 눈 소켓 그림자 (부드러운 눈두덩이)
            pygame.draw.ellipse(screen, p["fur_dark"],
                                (eye_cx - ew - 1, eye_cy - eh - 1, ew * 2 + 2, eh * 2 + 2))

            # 흰자위 (커다란 흰색 타원)
            pygame.draw.ellipse(screen, p["eye_white"],
                                (eye_cx - ew, eye_cy - eh, ew * 2, eh * 2))

            # 흰자위 상단 음영 (눈꺼풀 그림자)
            eyelid_h = int(eh * 0.3)
            eyelid_surf = self._get_surface(ew * 2 + 4, eyelid_h + 4)
            pygame.draw.ellipse(eyelid_surf, (p["fur"][0], p["fur"][1], p["fur"][2], 50),
                                (2, 2, ew * 2, eyelid_h * 2))
            screen.blit(eyelid_surf, (eye_cx - ew - 2, eye_cy - eh - 2))

            # 홍채 (큰 원, 이동 방향으로 약간 쏠림)
            iris_r = int(0.75 * b * eye_scale)
            iris_shift_x = int(fd * 0.15 * b)  # 바라보는 방향으로 쏠림
            iris_cx = eye_cx + iris_shift_x
            iris_cy = eye_cy + int(0.1 * b)
            # 홍채 그라데이션 (바깥→안쪽 밝아짐)
            pygame.draw.circle(screen, p["eye_iris"], (iris_cx, iris_cy), iris_r)
            pygame.draw.circle(screen, p["eye_iris_light"],
                              (iris_cx, iris_cy - int(0.05 * b)), int(iris_r * 0.75))

            # 동공 (작은 검은 원)
            pupil_r = int(0.38 * b * eye_scale)
            pygame.draw.circle(screen, p["eye_pupil"], (iris_cx, iris_cy), pupil_r)

            # ★ 큰 하이라이트 1 (좌상단, 크고 밝은 원)
            hl1_r = max(2, int(0.35 * b * eye_scale))
            hl1_x = iris_cx - int(0.3 * b)
            hl1_y = iris_cy - int(0.35 * b)
            pygame.draw.circle(screen, p["eye_highlight"], (hl1_x, hl1_y), hl1_r)

            # ★ 하이라이트 2 (우하단, 중간 크기)
            hl2_r = max(1, int(0.18 * b * eye_scale))
            hl2_x = iris_cx + int(0.25 * b)
            hl2_y = iris_cy + int(0.2 * b)
            pygame.draw.circle(screen, p["eye_highlight2"], (hl2_x, hl2_y), hl2_r)

            # ★ 하이라이트 3 (미세한 작은 점, 반짝임)
            hl3_r = max(1, int(0.08 * b))
            hl3_x = iris_cx - int(0.1 * b)
            hl3_y = iris_cy + int(0.15 * b)
            pygame.draw.circle(screen, (255, 255, 255), (hl3_x, hl3_y), hl3_r)

        # --- 코 (오밀조밀하게 눈 바로 아래) ---
        nose_cx = face_cx
        nose_cy = face_cy + int(0.9 * b)  # 눈에 더 가깝게
        nose_w = int(0.7 * b)  # 약간 더 작게
        nose_h = int(0.5 * b)

        pygame.draw.ellipse(screen, p["nose_dark"],
                            (nose_cx - nose_w // 2 + 1, nose_cy + 1, nose_w + 2, nose_h + 2))
        pygame.draw.ellipse(screen, p["nose_mid"],
                            (nose_cx - nose_w // 2, nose_cy, nose_w, nose_h))
        pygame.draw.ellipse(screen, p["nose_highlight"],
                            (nose_cx - nose_w // 4, nose_cy, nose_w // 2, int(nose_h * 0.5)))
        # 코 광택 점
        pygame.draw.circle(screen, (150, 120, 95),
                          (nose_cx - int(0.08 * b), nose_cy + int(0.08 * b)),
                          max(1, int(0.1 * b)))

        # --- 입 (코 바로 아래, 오밀조밀 W자) ---
        mouth_y = nose_cy + int(0.4 * b)  # 코에 더 가깝게
        mouth_w = int(0.9 * b)  # 약간 더 작게
        arc_rect_l = (face_cx - mouth_w, mouth_y, mouth_w, int(0.4 * b))
        arc_rect_r = (face_cx, mouth_y, mouth_w, int(0.4 * b))
        pygame.draw.arc(screen, p["mouth"], arc_rect_l, _pi, _tau, max(1, int(0.1 * b)))
        pygame.draw.arc(screen, p["mouth"], arc_rect_r, _pi, _tau, max(1, int(0.1 * b)))

        # --- 볼 홍조 ---
        for side in [-1, 1]:
            blush_spread = 2.0 + fd * side * 0.15
            blush_cx = face_cx + int(side * blush_spread * b)
            blush_cy = face_cy + int(0.6 * b)
            blush_rx = int(1.0 * b)
            blush_ry = int(0.55 * b)
            blush_surf = self._get_surface(blush_rx * 2 + 4, blush_ry * 2 + 4)

            for layer in range(3):
                alpha = max(0, 50 - layer * 15)
                rx = max(2, blush_rx - layer * int(0.15 * b))
                ry = max(1, blush_ry - layer * int(0.08 * b))
                pygame.draw.ellipse(blush_surf, (255, 150, 170, alpha),
                                    (blush_rx + 2 - rx, blush_ry + 2 - ry, rx * 2, ry * 2))

            screen.blit(blush_surf, (blush_cx - blush_rx - 2, blush_cy - blush_ry - 2))

        # === 리본 ===
        ribbon_side = -1 if fd > 0.3 else 1
        self._draw_ribbon(screen, head_cx, head_cy, head_r, b, p, face_shift, ribbon_side)

    def _draw_ribbon(self, screen, head_cx, head_cy, head_r, b, p, face_shift, ribbon_side):
        """핑크 리본 — 펄럭이는 애니메이션, 다층 셰이딩"""
        ribbon_cx = head_cx + int(ribbon_side * 2.2 * b) + int(face_shift * 0.2)
        ribbon_cy = head_cy - int(2.8 * b)
        flutter = self.ribbon_flutter

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

        shadow_off = 2
        shadow_left = [(x + shadow_off, y + shadow_off) for x, y in left_pts]
        shadow_right = [(x + shadow_off, y + shadow_off) for x, y in right_pts]
        pygame.draw.polygon(screen, p["pink_dark"], shadow_left)
        pygame.draw.polygon(screen, p["pink_dark"], shadow_right)

        pygame.draw.polygon(screen, p["pink"], left_pts)
        pygame.draw.polygon(screen, p["pink"], right_pts)

        hl_left = [
            (ribbon_cx, ribbon_cy),
            (ribbon_cx - int(bow_w * 0.6) + int(flutter * 0.15), ribbon_cy - int(bow_h * 0.6)),
            (ribbon_cx - int(bow_w * 0.2), ribbon_cy),
        ]
        hl_right = [
            (ribbon_cx, ribbon_cy),
            (ribbon_cx + int(bow_w * 0.6) - int(flutter * 0.1), ribbon_cy - int(bow_h * 0.6)),
            (ribbon_cx + int(bow_w * 0.2), ribbon_cy),
        ]
        pygame.draw.polygon(screen, p["pink_light"], hl_left)
        pygame.draw.polygon(screen, p["pink_light"], hl_right)

        knot_r = max(2, int(0.3 * b))
        pygame.draw.circle(screen, p["pink_dark"], (ribbon_cx, ribbon_cy), knot_r + 1)
        pygame.draw.circle(screen, p["pink"], (ribbon_cx, ribbon_cy), knot_r)
        pygame.draw.circle(screen, p["pink_light"], (ribbon_cx - 1, ribbon_cy - 1), max(1, knot_r // 2))

        tail_len = int(1.5 * b)
        tail_flutter = int(_sin(self.time * 3) * 0.3 * b)
        for side, sx_off in [(-1, -int(0.15 * b)), (1, int(0.15 * b))]:
            tx = ribbon_cx + sx_off
            pts = [
                (tx, ribbon_cy + knot_r),
                (tx + int(side * 0.3 * b) + tail_flutter, ribbon_cy + knot_r + tail_len),
                (tx + int(side * 0.15 * b), ribbon_cy + knot_r + int(tail_len * 0.7)),
            ]
            pygame.draw.polygon(screen, p["pink"], pts)
            pygame.draw.line(screen, p["pink_light"], pts[0], pts[2], max(1, int(0.06 * b)))

    def create_static_image(self, w=160, h=80):
        """정적 이미지 생성 (폴백용)"""
        surf = pygame.Surface((w, h), pygame.SRCALPHA)
        self.draw(surf, 0, 0, w, h)
        return surf


# 싱글톤 인스턴스
_teddy_sprite_instance = None


def get_teddy_bear_sprite():
    """테디베어 보스 스프라이트 싱글톤 반환"""
    global _teddy_sprite_instance
    if _teddy_sprite_instance is None:
        _teddy_sprite_instance = TeddyBearBossSprite()
    return _teddy_sprite_instance

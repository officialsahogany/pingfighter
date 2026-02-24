# -*- coding: utf-8 -*-
"""
탈광대 (하회탈 광대) 프로시저럴 보스 스프라이트
투기장 영웅 스타일 고퀄리티 프로시저럴 렌더링
- 하회탈 + 색동저고리 + 부채
- 이동 애니메이션 (좌/우/아이들)
- 히트 애니메이션 (탈 벗겨짐 + 넉백)
- Stage1BossSprite 호환 인터페이스
"""

import pygame
import math

_sin = math.sin
_cos = math.cos


class TalkwangdaeBossSprite:
    """
    탈광대 프로시저럴 보스 스프라이트
    하회탈 쓴 광대 — 색동저고리, 부채, 과장된 광대 동작
    포도대장과 동일한 구조 (투기장 영웅 스타일)
    """

    def __init__(self):
        # 애니메이션 상태
        self.direction = 0       # -1: 왼쪽, 0: 정지, 1: 오른쪽
        self.prev_x = 0.0
        self.time = 0.0

        # 걷기 애니메이션
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
        self.hit_duration = 0.4
        self.hit_direction = 1
        self.hit_intensity = 0.0

        # 탈 벗겨짐 애니메이션
        self.mask_offset_y = 0.0
        self.mask_rotate = 0.0

        # 프레임 캐시
        self._surface_cache = {}

    def _get_surface(self, w, h):
        """크기별 SRCALPHA Surface 캐시 재사용"""
        key = (w, h)
        if key not in self._surface_cache:
            self._surface_cache[key] = pygame.Surface((w, h), pygame.SRCALPHA)
        else:
            self._surface_cache[key].fill((0, 0, 0, 0))
        return self._surface_cache[key]

    # ------------------------------------------------------------------
    # 인터페이스 메서드
    # ------------------------------------------------------------------

    def update(self, current_x, dt=1/60):
        """애니메이션 상태 업데이트"""
        self.time += dt
        dx = current_x - self.prev_x

        # 방향 전환 쿨다운
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

        # 속도 계산
        self.velocity = abs(dx) / max(dt, 0.001)

        # 걷기 — 광대스럽게 과장
        if self.direction != 0:
            speed_factor = min(self.velocity / 80.0, 2.0)
            self.step_phase += dt * 9.0 * max(speed_factor, 0.5)
            target_lean = self.direction * 0.18 * min(speed_factor, 1.0)
            self.lean += (target_lean - self.lean) * min(dt * 7.0, 1.0)
            self.body_bob = _sin(self.step_phase * 2) * 0.12 * speed_factor
        else:
            self.step_phase *= 0.95
            self.lean *= 0.92
            self.body_bob = _sin(self.time * 2.0) * 0.03  # 미세한 흔들림

        # 히트 애니메이션
        if self.is_hit:
            self.hit_timer += dt
            progress = self.hit_timer / self.hit_duration
            if progress >= 1.0:
                self.is_hit = False
                self.hit_timer = 0.0
                self.hit_intensity = 0.0
                self.mask_offset_y = 0.0
                self.mask_rotate = 0.0
            else:
                self.hit_intensity = max(0, 1.0 - progress * progress)
                # 탈 벗겨졌다 돌아오기
                if progress < 0.25:
                    t = progress / 0.25
                    self.mask_offset_y = -t * 2.0   # b 단위
                    self.mask_rotate = t * 20.0 * self.hit_direction
                elif progress < 0.55:
                    t = (progress - 0.25) / 0.30
                    self.mask_offset_y = -2.0 + t * 0.5
                    self.mask_rotate = 20.0 * self.hit_direction * (1 - t * 0.3)
                else:
                    t = (progress - 0.55) / 0.45
                    ease = t * t * (3 - 2 * t)
                    self.mask_offset_y = -1.5 * (1 - ease)
                    self.mask_rotate = 20.0 * self.hit_direction * (1 - ease) * 0.7

        self.prev_x = current_x

    def trigger_hit(self, ball_x, boss_x):
        """히트 애니메이션 트리거"""
        self.is_hit = True
        self.hit_timer = 0.0
        self.hit_intensity = 1.0
        self.hit_direction = 1 if ball_x > boss_x else -1

    def get_current_frame(self, scale_size=None):
        """현재 프레임 Surface 반환"""
        w, h = scale_size or (80, 160)
        w, h = max(20, int(w)), max(40, int(h))

        surface = pygame.Surface((w, h), pygame.SRCALPHA)
        b = w / 10.0
        cx = w // 2
        cy = int(h * 0.45)

        self._draw_character(surface, cx, cy, b, w, h)
        return surface

    def draw(self, surface, x, y, width=None, height=None, center=True):
        """화면에 그리기"""
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
    #  프로시저럴 렌더링 — 탈광대 캐릭터
    # ===================================================================

    def _draw_character(self, surface, cx, cy, b, w, h):
        """탈광대 전체 캐릭터 렌더링"""
        lean = self.lean
        body_bob = self.body_bob
        step = self.step_phase

        # 히트 시 밀리는 효과
        hit_push = 0.0
        hit_shake_x = 0
        hit_shake_y = 0
        hit_color_flash = 0.0
        if self.is_hit:
            hit_push = self.hit_intensity * 0.3
            hit_shake_x = int(_sin(self.time * 40) * self.hit_intensity * 2)
            hit_shake_y = int(_cos(self.time * 35) * self.hit_intensity * 1.5)
            hit_color_flash = self.hit_intensity * 0.4
            cy += int(hit_push * b * 2)

        lean_offset = int(lean * 2.0 * b) + hit_shake_x
        bob_offset = int(body_bob * 1.5 * b) + hit_shake_y
        torso_y = cy - int(1.2 * b) + bob_offset

        p = self._get_palette(hit_color_flash)

        # 레이어 순서
        self._draw_shadow(surface, cx, cy, b, lean_offset)
        self._draw_legs(surface, cx, cy, b, lean_offset, bob_offset, step, p)
        self._draw_robe(surface, cx, cy, b, lean_offset, torso_y, step, p)
        self._draw_torso(surface, cx, cy, b, lean_offset, torso_y, step, p)
        self._draw_arms(surface, cx, cy, b, lean_offset, torso_y, step, p)
        self._draw_neck(surface, cx, b, lean_offset, torso_y, p)
        self._draw_mask_head(surface, cx, b, lean_offset, torso_y, p)

    def _get_palette(self, flash=0.0):
        """탈광대 색상 팔레트"""
        def _f(base):
            return tuple(min(255, int(c + (255 - c) * flash)) for c in base)

        return {
            # 하회탈
            "mask_face": _f((245, 235, 215)),
            "mask_face_shadow": _f((220, 205, 185)),
            "mask_outline": _f((90, 70, 50)),
            "mask_cheek": _f((215, 85, 80)),
            "mask_cheek_light": _f((235, 120, 110)),
            "mask_eye": _f((30, 25, 20)),
            "mask_eye_white": _f((240, 235, 225)),
            "mask_nose": _f((170, 130, 90)),
            "mask_mouth": _f((175, 55, 50)),
            "mask_mouth_dark": _f((130, 35, 30)),
            "mask_string": _f((45, 35, 25)),
            # 색동저고리
            "saek_red": _f((200, 50, 50)),
            "saek_red_dark": _f((160, 35, 35)),
            "saek_blue": _f((50, 70, 170)),
            "saek_blue_dark": _f((35, 50, 130)),
            "saek_yellow": _f((225, 195, 50)),
            "saek_yellow_dark": _f((185, 155, 30)),
            "saek_green": _f((50, 150, 65)),
            "saek_green_dark": _f((35, 115, 45)),
            "saek_white": _f((235, 230, 220)),
            "saek_edge": _f((100, 80, 60)),
            # 고름 (매듭)
            "goreum": _f((200, 55, 55)),
            "goreum_shadow": _f((160, 40, 40)),
            # 허리띠
            "belt": _f((110, 80, 40)),
            "belt_buckle": _f((180, 155, 50)),
            # 바지
            "pants": _f((55, 55, 75)),
            "pants_dark": _f((38, 38, 55)),
            # 신발
            "shoe": _f((55, 42, 28)),
            "shoe_light": _f((78, 62, 42)),
            # 피부
            "skin": _f((230, 205, 175)),
            "skin_shadow": _f((195, 170, 140)),
            # 부채
            "fan_base": _f((195, 165, 115)),
            "fan_edge": _f((185, 55, 55)),
            "fan_rib": _f((140, 110, 70)),
            "fan_paper": _f((220, 200, 160)),
            # 탈끈 장식
            "tassel_red": _f((195, 50, 45)),
            "tassel_gold": _f((210, 180, 60)),
        }

    def _draw_shadow(self, surface, cx, cy, b, lean_offset):
        """바닥 그림자"""
        shadow_w = int(2.8 * b)
        shadow_h = int(0.6 * b)
        shadow_y = cy + int(3.2 * b)
        shadow_surf = self._get_surface(shadow_w, shadow_h)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40), (0, 0, shadow_w, shadow_h))
        surface.blit(shadow_surf, (cx - shadow_w // 2 + lean_offset // 2, shadow_y))

    def _draw_legs(self, surface, cx, cy, b, lean_offset, bob_offset, step, p):
        """다리 (바지 + 신발)"""
        leg_base_y = cy + int(2.4 * b) + bob_offset
        speed_factor = min(self.velocity / 80.0, 1.5) if self.direction != 0 else 0

        for side in [-1, 1]:
            phase_offset = 0 if side == -1 else math.pi
            # 광대스러운 과장된 다리 움직임
            leg_sway = _sin(step + phase_offset) * speed_factor * 0.5 * b
            leg_lift = max(0, _sin(step + phase_offset)) * speed_factor * 0.2 * b

            leg_x = cx + side * int(0.4 * b) + lean_offset + int(leg_sway)
            leg_y = leg_base_y - int(leg_lift)

            # 바지
            pygame.draw.rect(surface, p["pants"],
                             (int(leg_x - 0.28 * b), int(leg_y - 0.35 * b),
                              int(0.56 * b), int(0.85 * b)),
                             border_radius=max(1, int(0.1 * b)))
            # 바지 그림자
            pygame.draw.rect(surface, p["pants_dark"],
                             (int(leg_x - 0.28 * b), int(leg_y - 0.35 * b),
                              int(0.56 * b), int(0.85 * b)), 1,
                             border_radius=max(1, int(0.1 * b)))

            # 신발
            shoe_w = int(0.6 * b)
            shoe_h = int(0.28 * b)
            pygame.draw.ellipse(surface, p["shoe"],
                                (int(leg_x - shoe_w / 2), int(leg_y + 0.42 * b),
                                 shoe_w, shoe_h))
            pygame.draw.ellipse(surface, p["shoe_light"],
                                (int(leg_x - shoe_w / 2 + 1), int(leg_y + 0.42 * b + 1),
                                 shoe_w - 2, shoe_h - 2), 1)

    def _draw_robe(self, surface, cx, cy, b, lean_offset, torso_y, step, p):
        """색동저고리 하단 (치마/포) — 너풀거림"""
        hip_y = torso_y + int(1.6 * b)
        hem_y = cy + int(2.5 * b)

        speed_factor = min(self.velocity / 80.0, 1.5) if self.direction != 0 else 0
        sway = _sin(self.time * 2.5) * speed_factor * 0.15 * b
        inertia = -self.lean * 2.0 * b

        flutter_amp = speed_factor * 0.35 * b + 0.05 * b
        flutter_freq = 5.0 if self.direction != 0 else 1.8

        # 치마 폴리곤 (너풀거림 8정점)
        num_hem_pts = 8
        hem_left = cx - int(1.5 * b) + lean_offset + int(-sway + inertia * 0.3)
        hem_right = cx + int(1.5 * b) + lean_offset + int(sway + inertia * 0.3)

        robe_top = [
            (cx - int(1.1 * b) + lean_offset, hip_y),
            (cx + int(1.1 * b) + lean_offset, hip_y),
        ]

        robe_bottom = []
        for i in range(num_hem_pts):
            t = i / (num_hem_pts - 1)
            bx = hem_right + int((hem_left - hem_right) * t)
            wave = _sin(self.time * flutter_freq + t * math.pi * 2.5 + i * 0.7) * flutter_amp
            edge_factor = 1.0 + abs(t - 0.5) * 0.8
            by = hem_y + int(wave * edge_factor)
            robe_bottom.append((bx, by))

        robe_points = robe_top + robe_bottom

        # 색동 줄무늬 (5색으로 분할)
        stripe_colors = [
            p["saek_red"], p["saek_yellow"], p["saek_blue"],
            p["saek_green"], p["saek_white"],
        ]
        stripe_dark = [
            p["saek_red_dark"], p["saek_yellow_dark"], p["saek_blue_dark"],
            p["saek_green_dark"], p["saek_white"],
        ]

        # 전체 치마를 먼저 그림자로
        shadow_pts = [(x + 2, y + 2) for x, y in robe_points]
        pygame.draw.polygon(surface, (25, 20, 15), shadow_pts)

        # 색동 줄무늬로 분할 그리기
        num_stripes = len(stripe_colors)
        robe_w = int(2.2 * b)
        for si in range(num_stripes):
            st = si / num_stripes
            et = (si + 1) / num_stripes
            sw = _sin(self.time * flutter_freq * 0.5 + si * 0.9) * flutter_amp * 0.3

            s_left = cx + lean_offset + int((-1.1 + 2.2 * st) * b)
            s_right = cx + lean_offset + int((-1.1 + 2.2 * et) * b)

            # 치마 아래쪽은 넓어지므로 비율 계산
            h_left = hem_right + int((hem_left - hem_right) * st)
            h_right = hem_right + int((hem_left - hem_right) * et)
            h_wave_l = _sin(self.time * flutter_freq + st * math.pi * 2.5) * flutter_amp
            h_wave_r = _sin(self.time * flutter_freq + et * math.pi * 2.5) * flutter_amp

            stripe_pts = [
                (s_left, hip_y),
                (s_right, hip_y),
                (int(h_right + sw), int(hem_y + h_wave_r)),
                (int(h_left + sw), int(hem_y + h_wave_l)),
            ]
            pygame.draw.polygon(surface, stripe_colors[si], stripe_pts)
            pygame.draw.polygon(surface, stripe_dark[si], stripe_pts, 1)

        # 하단 물결 테두리
        for i in range(len(robe_bottom) - 1):
            pygame.draw.line(surface, p["saek_edge"],
                             robe_bottom[i], robe_bottom[i + 1], 1)

    def _draw_torso(self, surface, cx, cy, b, lean_offset, torso_y, step, p):
        """색동저고리 상체"""
        chest_w = int(2.4 * b)
        chest_h = int(1.8 * b)
        chest_rect = pygame.Rect(
            cx - chest_w // 2 + lean_offset,
            torso_y - int(0.2 * b),
            chest_w, chest_h
        )

        # 5색 색동 상체 (세로 줄무늬)
        stripe_colors = [
            p["saek_red"], p["saek_yellow"], p["saek_blue"],
            p["saek_green"], p["saek_white"],
        ]
        stripe_dark = [
            p["saek_red_dark"], p["saek_yellow_dark"], p["saek_blue_dark"],
            p["saek_green_dark"], p["saek_white"],
        ]

        # 그림자
        pygame.draw.rect(surface, (25, 20, 15),
                         chest_rect.move(2, 2), border_radius=int(0.3 * b))

        # 각 줄무늬
        sw = chest_w / len(stripe_colors)
        for i, (col, dark) in enumerate(zip(stripe_colors, stripe_dark)):
            wave = _sin(step * 0.5 + i * 0.8) * 1.0
            sr = pygame.Rect(
                int(chest_rect.left + i * sw + wave),
                chest_rect.top,
                int(sw) + 1,
                chest_h
            )
            sr = sr.clip(chest_rect)
            if sr.width > 0 and sr.height > 0:
                pygame.draw.rect(surface, col, sr)

        # 둥근 테두리
        pygame.draw.rect(surface, p["saek_edge"], chest_rect, 1,
                         border_radius=int(0.3 * b))

        # 고름 (V자 매듭)
        collar_top = chest_rect.top + int(0.1 * b)
        collar_mid = chest_rect.centery + int(0.2 * b)
        pygame.draw.line(surface, p["goreum"],
                         (chest_rect.centerx, collar_top),
                         (chest_rect.left + int(0.3 * b), collar_mid), 2)
        pygame.draw.line(surface, p["goreum"],
                         (chest_rect.centerx, collar_top),
                         (chest_rect.right - int(0.3 * b), collar_mid), 2)
        # 고름 리본 (매듭 아래로 늘어짐)
        knot_x = chest_rect.centerx
        knot_y = collar_top + int(0.1 * b)
        pygame.draw.circle(surface, p["goreum"], (knot_x, knot_y),
                           max(2, int(0.2 * b)))
        # 리본 좌우 늘어짐
        ribbon_sway = _sin(self.time * 2.0) * 0.1 * b
        for side in [-1, 1]:
            rx = knot_x + side * int(0.15 * b)
            pygame.draw.line(surface, p["goreum_shadow"],
                             (knot_x, knot_y + int(0.1 * b)),
                             (int(rx + ribbon_sway * side), int(knot_y + 0.6 * b)), 2)

        # 허리띠
        belt_y = chest_rect.bottom - int(0.1 * b)
        belt_rect = pygame.Rect(
            cx - int(1.2 * b) + lean_offset, belt_y,
            int(2.4 * b), int(0.45 * b)
        )
        pygame.draw.rect(surface, p["belt"], belt_rect, border_radius=2)
        pygame.draw.rect(surface, p["belt_buckle"],
                         (belt_rect.centerx - int(0.15 * b),
                          belt_rect.centery - int(0.1 * b),
                          int(0.3 * b), int(0.2 * b)),
                         border_radius=1)

    def _draw_arms(self, surface, cx, cy, b, lean_offset, torso_y, step, p):
        """양팔 (색동 소매 + 오른손 부채)"""
        speed_factor = min(self.velocity / 80.0, 1.5) if self.direction != 0 else 0
        flutter_amp = speed_factor * 0.25 * b + 0.04 * b
        flutter_freq = 5.0 if self.direction != 0 else 1.8

        for side in [-1, 1]:
            shoulder_x = cx + side * int(1.2 * b) + lean_offset
            shoulder_y = torso_y + int(0.1 * b)

            phase_offset = 0 if side == -1 else math.pi
            # 광대스러운 과장된 팔 움직임
            arm_swing = _sin(step + phase_offset) * speed_factor * 0.4

            # 히트 시 팔 벌어짐
            hit_spread = 0.0
            if self.is_hit and side == 1:
                hit_spread = self.hit_intensity * 0.4 * b

            elbow_x = shoulder_x + side * int(0.35 * b + hit_spread)
            elbow_y = shoulder_y + int(0.9 * b) + int(arm_swing * 0.2 * b)

            hand_x = elbow_x + side * int(0.28 * b + hit_spread * 0.5)
            hand_y = elbow_y + int(0.7 * b) + int(arm_swing * 0.3 * b)

            # 색동 소매 (상완) — 너풀거림
            sleeve_wave_l = _sin(self.time * flutter_freq + side * 1.5) * flutter_amp
            sleeve_wave_r = _sin(self.time * flutter_freq + side * 1.5 + 1.2) * flutter_amp
            # 좌팔: 파란소매, 우팔: 빨간소매
            sleeve_col = p["saek_blue"] if side == -1 else p["saek_red"]
            sleeve_dark = p["saek_blue_dark"] if side == -1 else p["saek_red_dark"]

            sleeve_pts = [
                (shoulder_x - int(0.3 * b), shoulder_y - int(0.1 * b)),
                (shoulder_x + int(0.3 * b), shoulder_y - int(0.1 * b)),
                (elbow_x + int(0.25 * b) + int(sleeve_wave_r), elbow_y),
                (elbow_x - int(0.25 * b) + int(sleeve_wave_l), elbow_y),
            ]
            pygame.draw.polygon(surface, sleeve_col, sleeve_pts)
            pygame.draw.polygon(surface, sleeve_dark, sleeve_pts, 1)

            # 소매 (하완)
            cuff_wave = _sin(self.time * flutter_freq * 1.2 + side * 2.0) * flutter_amp * 0.7
            # 하완: 노란소매/초록소매
            cuff_col = p["saek_yellow"] if side == -1 else p["saek_green"]
            forearm_pts = [
                (elbow_x - int(0.22 * b) + int(sleeve_wave_l * 0.5), elbow_y - int(0.05 * b)),
                (elbow_x + int(0.22 * b) + int(sleeve_wave_r * 0.5), elbow_y - int(0.05 * b)),
                (int(hand_x) + int(0.15 * b) + int(cuff_wave), int(hand_y)),
                (int(hand_x) - int(0.15 * b) + int(cuff_wave), int(hand_y)),
            ]
            pygame.draw.polygon(surface, cuff_col, forearm_pts)

            # 손
            hand_r = max(2, int(0.16 * b))
            pygame.draw.circle(surface, p["skin"], (int(hand_x), int(hand_y)), hand_r)
            pygame.draw.circle(surface, p["skin_shadow"],
                               (int(hand_x), int(hand_y)), hand_r, 1)

            # 오른손에 부채
            if side == 1:
                self._draw_fan(surface, hand_x, hand_y, b, p)

    def _draw_fan(self, surface, hx, hy, b, p):
        """부채 (오른손)"""
        # 부채 흔들림
        fan_angle_offset = _sin(self.time * 3.0) * 8.0
        if self.is_hit:
            fan_angle_offset += self.hit_intensity * 25.0 * self.hit_direction

        angle_base = math.radians(-50 + fan_angle_offset)
        fan_r = b * 2.2

        # 부채 부채꼴 (6개 살)
        num_ribs = 6
        spread = math.radians(65)
        start_angle = angle_base - spread / 2

        # 부채 면 폴리곤
        fan_points = [(int(hx), int(hy))]
        for i in range(num_ribs + 1):
            a = start_angle + spread * i / num_ribs
            fx = hx + _cos(a) * fan_r
            fy = hy + _sin(a) * fan_r
            fan_points.append((int(fx), int(fy)))

        if len(fan_points) >= 3:
            # 그림자
            shadow_pts = [(x + 1, y + 1) for x, y in fan_points]
            pygame.draw.polygon(surface, (80, 60, 40), shadow_pts)
            # 부채 면
            pygame.draw.polygon(surface, p["fan_paper"], fan_points)
            # 테두리
            pygame.draw.polygon(surface, p["fan_edge"], fan_points, max(1, int(b * 0.15)))

        # 부채살
        for i in range(num_ribs):
            a = start_angle + spread * i / (num_ribs - 1)
            fx = hx + _cos(a) * fan_r
            fy = hy + _sin(a) * fan_r
            pygame.draw.line(surface, p["fan_rib"], (int(hx), int(hy)), (int(fx), int(fy)), 1)

        # 부채 손잡이 (작은 원)
        pygame.draw.circle(surface, p["fan_rib"], (int(hx), int(hy)),
                           max(1, int(b * 0.12)))

    def _draw_neck(self, surface, cx, b, lean_offset, torso_y, p):
        """목"""
        neck_cx = cx + lean_offset
        neck_bot_y = torso_y - int(0.1 * b)
        neck_top_y = torso_y - int(0.45 * b)
        neck_w_bot = int(0.6 * b)
        neck_w_top = int(0.45 * b)

        neck_pts = [
            (neck_cx - neck_w_bot // 2, neck_bot_y),
            (neck_cx + neck_w_bot // 2, neck_bot_y),
            (neck_cx + neck_w_top // 2, neck_top_y),
            (neck_cx - neck_w_top // 2, neck_top_y),
        ]
        pygame.draw.polygon(surface, p["skin"], neck_pts)
        pygame.draw.line(surface, p["skin_shadow"],
                         (neck_cx + neck_w_top // 3, neck_top_y + 1),
                         (neck_cx + neck_w_bot // 3, neck_bot_y - 1), 1)

    def _draw_mask_head(self, surface, cx, b, lean_offset, torso_y, p):
        """하회탈 머리 (탈 벗겨짐 애니메이션 포함)"""
        head_cx = cx + lean_offset
        head_y = torso_y - int(2.0 * b)

        # 히트 시 탈 기울어짐/떠오름
        mask_y_off = self.mask_offset_y * b
        mask_rot = self.mask_rotate

        # 탈 크기 (얼굴 크기보다 약간 큼)
        mask_w = int(2.0 * b)
        mask_h = int(1.8 * b)

        mask_cx = head_cx
        mask_cy = head_y + int(mask_y_off)

        # === 탈 뒤의 실제 머리 (탈이 벗겨질 때만 보임) ===
        if self.is_hit and abs(self.mask_offset_y) > 0.3:
            real_head_rect = pygame.Rect(
                int(head_cx - mask_w * 0.4), int(head_y - mask_h * 0.3),
                int(mask_w * 0.8), int(mask_h * 0.8)
            )
            pygame.draw.ellipse(surface, p["skin"], real_head_rect)
            pygame.draw.ellipse(surface, p["skin_shadow"], real_head_rect, 1)
            # 실제 눈 (당황한 작은 점)
            for side in [-1, 1]:
                rx = head_cx + side * int(0.2 * b)
                ry = head_y
                pygame.draw.circle(surface, p["mask_eye"], (int(rx), int(ry)),
                                   max(1, int(0.06 * b)))

        # === 하회탈 본체 ===
        mask_rect = pygame.Rect(
            int(mask_cx - mask_w / 2), int(mask_cy - mask_h / 2),
            mask_w, mask_h
        )

        # 탈 그림자
        pygame.draw.ellipse(surface, (60, 50, 35, 80),
                            mask_rect.move(2, 2))
        # 탈 바탕 (둥근 흰 얼굴)
        pygame.draw.ellipse(surface, p["mask_face"], mask_rect)
        # 안쪽 밝은 영역
        inner_face = mask_rect.inflate(-int(0.2 * b), -int(0.15 * b))
        pygame.draw.ellipse(surface, (250, 242, 228), inner_face)
        # 탈 테두리
        pygame.draw.ellipse(surface, p["mask_outline"], mask_rect,
                            max(1, int(b * 0.12)))

        # === 눈 (반달 모양 — 웃는 눈) ===
        eye_y = mask_cy - int(0.15 * b)
        for side in [-1, 1]:
            ex = mask_cx + side * int(0.4 * b)
            # 눈 구멍 배경 (약간 어두운)
            pygame.draw.ellipse(surface, p["mask_eye_white"],
                                (int(ex - 0.2 * b), int(eye_y - 0.12 * b),
                                 int(0.4 * b), int(0.24 * b)))
            # 반달 눈 (위가 볼록한 호)
            arc_rect = pygame.Rect(
                int(ex - 0.28 * b), int(eye_y - 0.2 * b),
                int(0.56 * b), int(0.4 * b)
            )
            pygame.draw.arc(surface, p["mask_eye"], arc_rect,
                            math.radians(10), math.radians(170),
                            max(2, int(b * 0.12)))
            # 눈 아래 곡선 (웃는 느낌)
            pygame.draw.arc(surface, p["mask_eye"], arc_rect,
                            math.radians(210), math.radians(330),
                            max(1, int(b * 0.06)))

        # === 볼 (붉은 원) ===
        cheek_y = mask_cy + int(0.1 * b)
        for side in [-1, 1]:
            chx = mask_cx + side * int(0.5 * b)
            cheek_r = max(2, int(0.22 * b))
            # 그림자
            pygame.draw.circle(surface, p["mask_cheek"],
                               (int(chx), int(cheek_y)), cheek_r)
            # 하이라이트
            pygame.draw.circle(surface, p["mask_cheek_light"],
                               (int(chx - 0.04 * b), int(cheek_y - 0.04 * b)),
                               max(1, int(cheek_r * 0.5)))

        # === 코 (둥근 작은 코) ===
        nose_cx = mask_cx
        nose_cy = mask_cy + int(0.02 * b)
        nose_r = max(2, int(0.12 * b))
        pygame.draw.circle(surface, p["mask_nose"], (int(nose_cx), int(nose_cy)), nose_r)
        pygame.draw.circle(surface, p["mask_outline"],
                           (int(nose_cx), int(nose_cy)), nose_r, 1)
        # 콧구멍
        for side in [-1, 1]:
            pygame.draw.circle(surface, p["mask_outline"],
                               (int(nose_cx + side * 0.04 * b), int(nose_cy + 0.03 * b)),
                               max(1, int(0.03 * b)))

        # === 입 (활짝 웃는 입) ===
        mouth_cy = mask_cy + int(0.38 * b)
        mouth_w = int(0.6 * b)
        mouth_h = int(0.3 * b)
        mouth_rect = pygame.Rect(
            int(mask_cx - mouth_w / 2), int(mouth_cy - mouth_h / 2),
            mouth_w, mouth_h
        )
        # 입 배경 (벌린 입)
        pygame.draw.ellipse(surface, p["mask_mouth_dark"], mouth_rect)
        # 입술 아치
        pygame.draw.arc(surface, p["mask_mouth"],
                        mouth_rect.inflate(int(0.05 * b), int(0.05 * b)),
                        math.radians(200), math.radians(340),
                        max(2, int(b * 0.1)))
        # 이빨 힌트 (작은 흰 사각형)
        teeth_w = int(0.25 * b)
        teeth_h = int(0.06 * b)
        pygame.draw.rect(surface, (240, 235, 225),
                         (int(mask_cx - teeth_w / 2), int(mouth_cy - teeth_h),
                          teeth_w, teeth_h))

        # === 탈끈 (양쪽으로 늘어짐) ===
        for side in [-1, 1]:
            sx = mask_cx + side * int(mask_w / 2)
            sy = mask_cy
            ex = sx + side * int(0.5 * b)
            ey = sy + int(0.8 * b)
            mid_x = (sx + ex) // 2 + int(_sin(self.time * 1.5 + side) * 0.1 * b)
            mid_y = (sy + ey) // 2

            pygame.draw.line(surface, p["mask_string"],
                             (int(sx), int(sy)), (int(mid_x), int(mid_y)),
                             max(1, int(b * 0.08)))
            pygame.draw.line(surface, p["mask_string"],
                             (int(mid_x), int(mid_y)), (int(ex), int(ey)),
                             max(1, int(b * 0.08)))
            # 끈 끝 술 장식
            tassel_y = int(ey)
            pygame.draw.circle(surface, p["tassel_red"],
                               (int(ex), tassel_y),
                               max(1, int(0.08 * b)))
            pygame.draw.line(surface, p["tassel_gold"],
                             (int(ex), tassel_y),
                             (int(ex + _sin(self.time * 2.0 + side * 2) * 0.1 * b),
                              int(tassel_y + 0.15 * b)), 1)

        # === 히트 이펙트 (탈 주위 충격파) ===
        if self.is_hit and self.hit_intensity > 0.3:
            shock_r = int(mask_w * 0.7 * self.hit_intensity)
            shock_alpha = int(100 * self.hit_intensity)
            shock_surf = self._get_surface(shock_r * 2 + 2, shock_r * 2 + 2)
            pygame.draw.circle(shock_surf, (255, 220, 150, shock_alpha),
                               (shock_r + 1, shock_r + 1), shock_r, max(1, int(b * 0.2)))
            surface.blit(shock_surf,
                         (int(mask_cx - shock_r - 1), int(mask_cy - shock_r - 1)))


# ======================================================================
# 싱글톤
# ======================================================================

_talkwangdae_instance = None


def init_talkwangdae_boss_sprite():
    """탈광대 보스 스프라이트 초기화"""
    global _talkwangdae_instance
    try:
        _talkwangdae_instance = TalkwangdaeBossSprite()
        print("[Sprite] 탈광대 프로시저럴 스프라이트 초기화 완료")
        return _talkwangdae_instance
    except Exception as e:
        print(f"[Sprite] 탈광대 스프라이트 초기화 실패: {e}")
        _talkwangdae_instance = None
        return None


def get_talkwangdae_boss_sprite():
    """탈광대 보스 스프라이트 싱글톤 반환"""
    global _talkwangdae_instance
    if _talkwangdae_instance is None:
        init_talkwangdae_boss_sprite()
    return _talkwangdae_instance


def reset_talkwangdae_boss_sprite():
    """탈광대 보스 스프라이트 리셋"""
    global _talkwangdae_instance
    if _talkwangdae_instance:
        _talkwangdae_instance.direction = 0
        _talkwangdae_instance.is_hit = False
        _talkwangdae_instance.hit_timer = 0.0
        _talkwangdae_instance.time = 0.0
        _talkwangdae_instance.step_phase = 0.0
        _talkwangdae_instance.lean = 0.0
        _talkwangdae_instance.body_bob = 0.0
        _talkwangdae_instance.mask_offset_y = 0.0
        _talkwangdae_instance.mask_rotate = 0.0

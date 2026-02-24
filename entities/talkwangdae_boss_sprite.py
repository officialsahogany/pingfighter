# -*- coding: utf-8 -*-
"""
탈광대 (하회탈 광대) 프로시저럴 보스 스프라이트
- 하회탈 + 색동저고리 + 부채
- 과장된 흔들림 이동 애니메이션
- 히트 시 탈 벗겨졌다 돌아오는 모션
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

        # 탈 애니메이션 (히트 시 벗겨짐)
        self.mask_offset_y = 0.0   # 탈 Y 오프셋 (히트 시 위로)
        self.mask_rotate = 0.0     # 탈 회전 (히트 시)

        # 부채 애니메이션
        self.fan_angle = 0.0       # 부채 각도

        # 팔레트
        self._palette = {
            "mask_white": (245, 235, 220),
            "mask_cheek": (220, 80, 80),
            "mask_eye": (30, 30, 30),
            "mask_mouth": (180, 50, 50),
            "mask_outline": (60, 50, 40),
            "saekdong_red": (200, 50, 50),
            "saekdong_blue": (50, 80, 180),
            "saekdong_yellow": (230, 200, 50),
            "saekdong_green": (50, 160, 70),
            "saekdong_white": (240, 240, 230),
            "pants": (60, 60, 80),
            "skin": (220, 190, 150),
            "shoe": (80, 50, 30),
            "fan_main": (200, 170, 120),
            "fan_edge": (180, 50, 50),
            "fan_rib": (140, 110, 70),
            "hat_string": (30, 30, 30),
        }

    # ------------------------------------------------------------------
    # 인터페이스 메서드
    # ------------------------------------------------------------------

    def update(self, current_x, dt=1/60):
        """애니메이션 상태 업데이트"""
        self.time += dt
        dx = current_x - self.prev_x
        self.velocity = dx / dt if dt > 0 else 0
        self.prev_x = current_x

        # 방향 감지 (안정화)
        self.direction_change_cooldown = max(0, self.direction_change_cooldown - dt)
        self.movement_accumulator += dx
        if self.direction_change_cooldown <= 0:
            if abs(self.movement_accumulator) > self.direction_change_threshold:
                new_dir = 1 if self.movement_accumulator > 0 else -1
                if new_dir != self.direction:
                    self.direction = new_dir
                    self.direction_change_cooldown = 0.08
                self.movement_accumulator = 0.0
        if abs(dx) < 0.05:
            self.direction = 0
            self.movement_accumulator = 0.0

        # 걷기 — 과장된 흔들림 (광대스럽게)
        if self.direction != 0:
            speed_factor = min(abs(self.velocity) / 300, 1.0)
            self.step_phase += dt * (7.0 + speed_factor * 5.0)  # 빠른 걸음
            self.lean = _sin(self.step_phase * 0.7) * 0.12 * (1 + speed_factor)
            self.body_bob = _sin(self.step_phase * 1.4) * 4.0  # 큰 상하 흔들림
        else:
            self.step_phase += dt * 1.5  # 아이들 시 미세 흔들림
            self.lean *= 0.9
            self.body_bob *= 0.85

        # 부채 흔들림
        if self.direction != 0:
            self.fan_angle = _sin(self.time * 6.0) * 15.0
        else:
            self.fan_angle = _sin(self.time * 2.0) * 5.0

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
                self.hit_intensity = 1.0 - progress
                # 탈 벗겨졌다 돌아오기 (이징)
                if progress < 0.3:
                    # 벗겨지는 구간
                    t = progress / 0.3
                    self.mask_offset_y = -t * 18.0
                    self.mask_rotate = t * 25.0 * self.hit_direction
                elif progress < 0.6:
                    # 공중에 떠있는 구간
                    t = (progress - 0.3) / 0.3
                    self.mask_offset_y = -18.0 + t * 5.0  # 약간 내려오기 시작
                    self.mask_rotate = 25.0 * self.hit_direction * (1 - t * 0.3)
                else:
                    # 돌아오는 구간
                    t = (progress - 0.6) / 0.4
                    ease = t * t * (3 - 2 * t)  # smoothstep
                    self.mask_offset_y = -13.0 * (1 - ease)
                    self.mask_rotate = 25.0 * self.hit_direction * (1 - ease) * 0.7

    def trigger_hit(self, ball_x, boss_x):
        """히트 애니메이션 트리거"""
        self.is_hit = True
        self.hit_timer = 0.0
        self.hit_intensity = 1.0
        self.hit_direction = 1 if ball_x > boss_x else -1

    def get_current_frame(self, scale_size=None):
        """현재 프레임 Surface 반환"""
        w = scale_size[0] if scale_size else 96
        h = scale_size[1] if scale_size else 192
        surf = pygame.Surface((w, h), pygame.SRCALPHA)
        self._render(surf, w, h)
        return surf

    def draw(self, surface, x, y, width=None, height=None, center=True):
        """화면에 그리기"""
        w = width or 96
        h = height or 192
        frame = self.get_current_frame((w, h))
        if center:
            surface.blit(frame, (x - w // 2, y - h // 2))
        else:
            surface.blit(frame, (x, y))

    # ------------------------------------------------------------------
    # 프로시저럴 렌더링
    # ------------------------------------------------------------------

    def _render(self, surf, w, h):
        """전체 캐릭터 렌더링"""
        b = w / 10.0  # 기본 블록 단위
        cx = w / 2
        base_y = h * 0.85  # 발 위치
        bob = self.body_bob
        lean_px = self.lean * w * 0.3

        pal = self._palette
        step = self.step_phase

        # --- 다리 ---
        self._draw_legs(surf, cx, base_y, b, step, lean_px, pal)

        # --- 몸통 (색동저고리) ---
        body_top = base_y - b * 7.5 + bob
        self._draw_body(surf, cx + lean_px, body_top, b, pal, step)

        # --- 팔 ---
        self._draw_arms(surf, cx + lean_px, body_top, b, pal, step)

        # --- 머리 + 하회탈 ---
        head_y = body_top - b * 2.5
        self._draw_head(surf, cx + lean_px, head_y + self.mask_offset_y, b, pal)

    def _draw_legs(self, surf, cx, base_y, b, step, lean, pal):
        """다리"""
        leg_swing = _sin(step) * b * 1.8
        pants_c = pal["pants"]
        shoe_c = pal["shoe"]

        for side in (-1, 1):
            lx = cx + side * b * 1.2 + lean * 0.3
            swing = leg_swing * side
            knee_y = base_y - b * 3
            foot_y = base_y - b * 0.3

            # 바지
            pygame.draw.line(surf, pants_c,
                             (int(lx), int(base_y - b * 4.5)),
                             (int(lx + swing * 0.5), int(knee_y)), max(2, int(b * 0.9)))
            pygame.draw.line(surf, pants_c,
                             (int(lx + swing * 0.5), int(knee_y)),
                             (int(lx + swing), int(foot_y)), max(2, int(b * 0.8)))
            # 신발
            pygame.draw.circle(surf, shoe_c, (int(lx + swing), int(foot_y)), max(2, int(b * 0.6)))

    def _draw_body(self, surf, cx, top_y, b, pal, step):
        """색동저고리 몸통"""
        body_w = b * 4.0
        body_h = b * 5.0

        # 색동 줄무늬
        stripe_colors = [
            pal["saekdong_red"],
            pal["saekdong_yellow"],
            pal["saekdong_blue"],
            pal["saekdong_green"],
            pal["saekdong_white"],
        ]

        stripe_w = body_w / len(stripe_colors)
        for i, col in enumerate(stripe_colors):
            sx = cx - body_w / 2 + i * stripe_w
            # 약간의 너풀거림
            wave = _sin(step * 0.5 + i * 0.8) * 1.5
            points = [
                (sx + wave, top_y),
                (sx + stripe_w + wave, top_y),
                (sx + stripe_w + wave * 1.3 + 1, top_y + body_h),
                (sx + wave * 1.3 - 1, top_y + body_h),
            ]
            pygame.draw.polygon(surf, col, [(int(px), int(py)) for px, py in points])

        # 가운데 매듭 (고름)
        goreum_color = pal["saekdong_red"]
        pygame.draw.line(surf, goreum_color,
                         (int(cx), int(top_y + b * 0.5)),
                         (int(cx), int(top_y + b * 2.5)), max(2, int(b * 0.4)))
        # 매듭 리본
        pygame.draw.circle(surf, goreum_color,
                           (int(cx), int(top_y + b * 0.5)), max(2, int(b * 0.5)))

    def _draw_arms(self, surf, cx, top_y, b, pal, step):
        """팔 + 부채"""
        skin_c = pal["skin"]
        arm_swing = _sin(step) * b * 1.2

        for side in (-1, 1):
            ax = cx + side * b * 2.8
            shoulder_y = top_y + b * 0.8
            elbow_y = shoulder_y + b * 2.5
            hand_y = elbow_y + b * 2.0

            swing = arm_swing * side
            # 색동 소매
            sleeve_colors = [pal["saekdong_blue"], pal["saekdong_red"]]
            sleeve_c = sleeve_colors[0] if side == -1 else sleeve_colors[1]

            pygame.draw.line(surf, sleeve_c,
                             (int(ax), int(shoulder_y)),
                             (int(ax + swing * 0.4), int(elbow_y)), max(2, int(b * 0.9)))
            pygame.draw.line(surf, sleeve_c,
                             (int(ax + swing * 0.4), int(elbow_y)),
                             (int(ax + swing * 0.7), int(hand_y)), max(2, int(b * 0.7)))
            # 손
            pygame.draw.circle(surf, skin_c,
                               (int(ax + swing * 0.7), int(hand_y)), max(2, int(b * 0.5)))

            # 오른손에 부채
            if side == 1:
                self._draw_fan(surf, ax + swing * 0.7, hand_y, b, pal)

    def _draw_fan(self, surf, hx, hy, b, pal):
        """부채 그리기"""
        fan_c = pal["fan_main"]
        edge_c = pal["fan_edge"]
        rib_c = pal["fan_rib"]

        angle_base = math.radians(-60 + self.fan_angle)
        fan_r = b * 3.0

        # 부채 부채꼴 (5개 살)
        num_ribs = 5
        spread = math.radians(70)  # 부채 펼침 각도
        start_angle = angle_base - spread / 2

        # 부채 면
        fan_points = [(int(hx), int(hy))]
        for i in range(num_ribs + 1):
            a = start_angle + spread * i / num_ribs
            fx = hx + _cos(a) * fan_r
            fy = hy + _sin(a) * fan_r
            fan_points.append((int(fx), int(fy)))

        if len(fan_points) >= 3:
            pygame.draw.polygon(surf, fan_c, fan_points)
            # 테두리
            pygame.draw.polygon(surf, edge_c, fan_points, max(1, int(b * 0.2)))

        # 부채살
        for i in range(num_ribs):
            a = start_angle + spread * i / (num_ribs - 1)
            fx = hx + _cos(a) * fan_r
            fy = hy + _sin(a) * fan_r
            pygame.draw.line(surf, rib_c, (int(hx), int(hy)), (int(fx), int(fy)), 1)

    def _draw_head(self, surf, cx, head_y, b, pal):
        """하회탈 머리"""
        mask_rotate_rad = math.radians(self.mask_rotate)

        # 탈 크기
        mask_w = b * 4.2
        mask_h = b * 4.8

        # --- 하회탈 ---
        mask_cx = cx
        mask_cy = head_y

        # 탈 바탕 (둥근 흰 얼굴)
        pygame.draw.ellipse(surf, pal["mask_white"],
                            (int(mask_cx - mask_w / 2), int(mask_cy - mask_h / 2),
                             int(mask_w), int(mask_h)))
        # 탈 테두리
        pygame.draw.ellipse(surf, pal["mask_outline"],
                            (int(mask_cx - mask_w / 2), int(mask_cy - mask_h / 2),
                             int(mask_w), int(mask_h)), max(1, int(b * 0.2)))

        # 눈 (반달 모양 — 웃는 눈)
        eye_y = mask_cy - b * 0.6
        for side in (-1, 1):
            ex = mask_cx + side * b * 1.0
            # 반달 눈 (위가 볼록한 호)
            pygame.draw.arc(surf, pal["mask_eye"],
                            (int(ex - b * 0.7), int(eye_y - b * 0.5),
                             int(b * 1.4), int(b * 1.0)),
                            math.radians(0), math.radians(180), max(2, int(b * 0.25)))

        # 볼 (붉은 원)
        cheek_y = mask_cy + b * 0.3
        for side in (-1, 1):
            chx = mask_cx + side * b * 1.4
            pygame.draw.circle(surf, pal["mask_cheek"],
                               (int(chx), int(cheek_y)), max(2, int(b * 0.6)))

        # 코 (작은 삼각형)
        nose_y = mask_cy - b * 0.1
        nose_pts = [
            (int(mask_cx), int(nose_y - b * 0.4)),
            (int(mask_cx - b * 0.3), int(nose_y + b * 0.3)),
            (int(mask_cx + b * 0.3), int(nose_y + b * 0.3)),
        ]
        pygame.draw.polygon(surf, pal["mask_outline"], nose_pts)

        # 입 (활짝 웃는 곡선)
        mouth_y = mask_cy + b * 1.2
        pygame.draw.arc(surf, pal["mask_mouth"],
                        (int(mask_cx - b * 1.2), int(mouth_y - b * 0.8),
                         int(b * 2.4), int(b * 1.6)),
                        math.radians(200), math.radians(340),
                        max(2, int(b * 0.3)))

        # 탈끈 (양쪽)
        string_c = pal["hat_string"]
        for side in (-1, 1):
            sx = mask_cx + side * mask_w / 2
            pygame.draw.line(surf, string_c,
                             (int(sx), int(mask_cy)),
                             (int(sx + side * b * 1.5), int(mask_cy + b * 2.0)),
                             max(1, int(b * 0.15)))

        # 히트 이펙트 (탈 주위 충격파)
        if self.is_hit and self.hit_intensity > 0.3:
            shock_r = int(mask_w * 0.8 * self.hit_intensity)
            shock_alpha = int(120 * self.hit_intensity)
            shock_surf = pygame.Surface((shock_r * 2, shock_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(shock_surf, (255, 200, 100, shock_alpha),
                               (shock_r, shock_r), shock_r, max(1, int(b * 0.3)))
            surf.blit(shock_surf, (int(mask_cx - shock_r), int(mask_cy - shock_r)))


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
        _talkwangdae_instance.__init__()

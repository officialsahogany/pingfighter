"""
🧸 Stage 3 Boss Sprite Animation - 테디베어 느릿느릿 걷기 애니메이션
프로시저럴 렌더링 기반 좌우 이동 + 흔들기 애니메이션 (다른 보스의 3배 느림)
"""

import pygame
import math


def _smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


class TeddybearBossSprite:
    """🧸 테디베어 보스 프로시저럴 스프라이트 (느릿느릿 이동)"""

    def __init__(self, base_width=350, base_height=250):
        self.base_w = base_width
        self.base_h = base_height

        # 애니메이션 상태
        self.prev_x = 0.0
        self.direction = 0       # -1: 왼쪽, 0: 정지, 1: 오른쪽
        self.walk_phase = 0.0    # 걷기 위상 (0~2π)
        self.body_sway = 0.0     # 몸 좌우 흔들림
        self.arm_swing = 0.0     # 팔 흔들림
        self.bounce_y = 0.0      # 위아래 통통 바운스
        self.idle_breath = 0.0   # 정지 시 호흡 애니메이션

        # 히트 애니메이션
        self.is_hit = False
        self.hit_timer = 0.0
        self.hit_direction = 1

        # 방향 전환 안정화
        self.direction_cooldown = 0.0
        self.move_accum = 0.0

        # 3배 느린 애니메이션 속도
        self.walk_speed = 1.2     # 다른 보스는 약 3.0~4.0, 테디베어는 1.2
        self.idle_speed = 0.5     # 호흡 속도

        # 캐시
        self._cache = {}
        self._cache_key = None

    def update(self, current_x: float, dt: float = 1/60):
        """애니메이션 업데이트"""
        # 히트 애니메이션
        if self.is_hit:
            self.hit_timer -= dt
            if self.hit_timer <= 0:
                self.is_hit = False
            self.prev_x = current_x
            return

        dx = current_x - self.prev_x

        # 방향 전환 쿨다운
        if self.direction_cooldown > 0:
            self.direction_cooldown -= dt
        self.move_accum += dx

        if abs(dx) > 1.5:
            new_dir = 1 if dx > 0 else -1
            if new_dir != self.direction and self.direction_cooldown <= 0 and abs(self.move_accum) > 4.0:
                if (self.move_accum > 0 and new_dir == 1) or (self.move_accum < 0 and new_dir == -1):
                    self.direction = new_dir
                    self.direction_cooldown = 0.2
                    self.move_accum = 0

            # 느릿느릿 걷기 애니메이션 (3배 느림)
            self.walk_phase += self.walk_speed * dt * 2 * math.pi
            self.body_sway = math.sin(self.walk_phase) * 3.0           # 몸 좌우 3px
            self.arm_swing = math.sin(self.walk_phase) * 8.0           # 팔 흔들림 8px
            self.bounce_y = abs(math.sin(self.walk_phase * 0.5)) * 4.0  # 통통 바운스 4px
            self.idle_breath = 0.0
        else:
            if self.direction_cooldown <= 0 and abs(self.move_accum) < 3.0:
                self.direction = 0
            self.move_accum *= 0.8

            # 정지: 호흡 애니메이션
            self.idle_breath += self.idle_speed * dt * 2 * math.pi
            self.body_sway *= 0.9
            self.arm_swing *= 0.9
            self.bounce_y *= 0.85

        self.prev_x = current_x

    def trigger_hit(self, ball_cx, boss_cx):
        """피격 애니메이션"""
        self.is_hit = True
        self.hit_timer = 0.25
        self.hit_direction = -1 if ball_cx < boss_cx else 1

    def get_current_frame(self, scale_size: tuple = None) -> pygame.Surface:
        """현재 프레임 생성"""
        w, h = scale_size if scale_size else (self.base_w, self.base_h)
        if w < 10 or h < 10:
            s = pygame.Surface((max(10, w), max(10, h)), pygame.SRCALPHA)
            s.fill((181, 126, 63))
            return s
        return self._draw_teddy(w, h)

    def _draw_teddy(self, w, h):
        """고퀄리티 프로시저럴 테디베어 렌더링"""
        surf = pygame.Surface((w + 20, h + 20), pygame.SRCALPHA)
        ox, oy = 10, 10  # 여백 (회전/흔들림용)
        cx = w // 2 + ox
        _sin = math.sin

        # 흔들림/바운스 오프셋
        sway = self.body_sway
        bounce = -self.bounce_y
        arm_sw = self.arm_swing
        breath = _sin(self.idle_breath) * 2.0 if self.direction == 0 else 0
        # 히트 시 떨림
        hit_shake = 0
        if self.is_hit:
            hit_shake = int(_sin(self.hit_timer * 60) * 5) * self.hit_direction

        bx = cx + int(sway) + hit_shake  # body center x
        by = oy + int(bounce + breath)    # body y offset

        # ── 색상 팔레트 (고퀄리티) ──
        FUR_OUTLINE = (90, 58, 28)
        FUR_DARK = (139, 90, 43)
        FUR_MID = (170, 118, 58)
        FUR_MAIN = (191, 140, 78)
        FUR_LIGHT = (215, 172, 105)
        FUR_HIGHLIGHT = (235, 200, 140)
        FUR_BELLY = (240, 218, 180)
        FUR_BELLY_LIGHT = (250, 235, 205)
        NOSE_COL = (50, 30, 18)
        NOSE_SHINE = (80, 55, 35)
        EYE_COL = (25, 18, 10)
        EYE_OUTER = (45, 30, 18)
        EYE_SHINE = (255, 255, 255)
        EYE_SHINE2 = (200, 220, 255)
        MOUTH_COL = (90, 55, 28)
        CHEEK_COL = (255, 140, 140, 60)
        RIBBON_COL = (210, 40, 40)
        RIBBON_LIGHT = (240, 80, 80)
        RIBBON_DARK = (160, 25, 25)
        RIBBON_KNOT = (180, 30, 30)
        STITCH = (160, 110, 55, 150)
        PAW_PAD = (190, 140, 90)
        PAW_PAD_DARK = (160, 110, 65)

        # ── 그림자 (바닥) ──
        shadow_w = int(w * 0.50)
        shadow_h = int(h * 0.06)
        shadow_y = by + int(h * 0.92)
        shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 35), (0, 0, shadow_w, shadow_h))
        surf.blit(shadow_surf, (bx - shadow_w // 2, shadow_y))

        # ── 귀 (머리 뒤) ──
        ear_r = int(w * 0.095)
        ear_y = by + int(h * 0.10)
        ear_lx = bx - int(w * 0.20)
        ear_rx = bx + int(w * 0.20)
        for ex in [ear_lx, ear_rx]:
            pygame.draw.circle(surf, FUR_OUTLINE, (ex, ear_y), ear_r + 4)
            pygame.draw.circle(surf, FUR_DARK, (ex, ear_y), ear_r + 2)
            pygame.draw.circle(surf, FUR_MAIN, (ex, ear_y), ear_r)
            # 귀 안쪽 (분홍)
            inner_r = int(ear_r * 0.55)
            pygame.draw.circle(surf, (220, 170, 140), (ex, ear_y + 1), inner_r)
            pygame.draw.circle(surf, (235, 195, 165), (ex, ear_y - 1), int(inner_r * 0.7))

        # ── 몸통 ──
        body_w = int(w * 0.65)
        body_h = int(h * 0.48)
        body_cy = by + int(h * 0.54)
        body_rect = pygame.Rect(bx - body_w // 2, body_cy - body_h // 2, body_w, body_h)
        # 윤곽
        pygame.draw.ellipse(surf, FUR_OUTLINE, body_rect.inflate(8, 8))
        pygame.draw.ellipse(surf, FUR_DARK, body_rect.inflate(4, 4))
        pygame.draw.ellipse(surf, FUR_MAIN, body_rect)
        # 몸통 하이라이트 (상단 좌측)
        hl_rect = pygame.Rect(bx - body_w // 3, body_cy - body_h // 3, int(body_w * 0.4), int(body_h * 0.35))
        hl_surf = pygame.Surface((hl_rect.w, hl_rect.h), pygame.SRCALPHA)
        pygame.draw.ellipse(hl_surf, (*FUR_LIGHT, 80), (0, 0, hl_rect.w, hl_rect.h))
        surf.blit(hl_surf, hl_rect.topleft)
        # 배 (밝은 타원)
        belly_w = int(body_w * 0.52)
        belly_h = int(body_h * 0.60)
        belly_rect = pygame.Rect(bx - belly_w // 2, body_cy - belly_h // 3, belly_w, belly_h)
        pygame.draw.ellipse(surf, FUR_BELLY, belly_rect)
        # 배 하이라이트
        belly_hl = pygame.Rect(bx - belly_w // 3, belly_rect.y + 4, int(belly_w * 0.5), int(belly_h * 0.4))
        bl_surf = pygame.Surface((belly_hl.w, belly_hl.h), pygame.SRCALPHA)
        pygame.draw.ellipse(bl_surf, (*FUR_BELLY_LIGHT, 100), (0, 0, belly_hl.w, belly_hl.h))
        surf.blit(bl_surf, belly_hl.topleft)
        # 배 십자 스티치
        stitch_cx, stitch_cy = bx, body_cy + int(body_h * 0.05)
        st_len = int(belly_w * 0.20)
        pygame.draw.line(surf, STITCH, (stitch_cx - st_len, stitch_cy), (stitch_cx + st_len, stitch_cy), 2)
        pygame.draw.line(surf, STITCH, (stitch_cx, stitch_cy - st_len), (stitch_cx, stitch_cy + st_len), 2)

        # ── 팔 (좌우 - 걷기 흔들림) ──
        arm_w = int(w * 0.13)
        arm_h = int(h * 0.28)
        arm_base_y = by + int(h * 0.42)
        for side in [-1, 1]:
            a_swing = int(arm_sw * side * 0.6)
            ax = bx + side * (body_w // 2 + arm_w // 6)
            ay = arm_base_y + abs(a_swing) // 2
            arm_rect = pygame.Rect(ax - arm_w // 2, ay, arm_w, arm_h)
            pygame.draw.ellipse(surf, FUR_OUTLINE, arm_rect.inflate(5, 5))
            pygame.draw.ellipse(surf, FUR_DARK, arm_rect.inflate(2, 2))
            pygame.draw.ellipse(surf, FUR_MID, arm_rect)
            # 팔 하이라이트
            arm_hl = pygame.Rect(arm_rect.x + 3, arm_rect.y + 3, arm_rect.w // 2, arm_rect.h // 3)
            ah_surf = pygame.Surface((arm_hl.w, arm_hl.h), pygame.SRCALPHA)
            pygame.draw.ellipse(ah_surf, (*FUR_LIGHT, 70), (0, 0, arm_hl.w, arm_hl.h))
            surf.blit(ah_surf, arm_hl.topleft)
            # 발바닥 패드
            pad_r = int(arm_w * 0.30)
            pad_cy = arm_rect.bottom - pad_r - 2
            pygame.draw.circle(surf, PAW_PAD_DARK, (ax, pad_cy), pad_r + 2)
            pygame.draw.circle(surf, PAW_PAD, (ax, pad_cy), pad_r)
            # 작은 패드 3개
            for pi in range(-1, 2):
                pr = max(2, pad_r // 3)
                pygame.draw.circle(surf, PAW_PAD_DARK, (ax + pi * (pr + 2), pad_cy - pad_r - pr + 1), pr)

        # ── 다리 (좌우 - 걷기 오프셋) ──
        leg_w = int(w * 0.15)
        leg_h = int(h * 0.16)
        leg_base_y = by + int(h * 0.80)
        for side_idx, side in enumerate([-1, 1]):
            l_offset = int(_sin(self.walk_phase + side_idx * math.pi) * 4) if self.direction != 0 else 0
            lx = bx + side * int(w * 0.12)
            ly = leg_base_y + l_offset
            leg_rect = pygame.Rect(lx - leg_w // 2, ly, leg_w, leg_h)
            pygame.draw.ellipse(surf, FUR_OUTLINE, leg_rect.inflate(5, 5))
            pygame.draw.ellipse(surf, FUR_DARK, leg_rect.inflate(2, 2))
            pygame.draw.ellipse(surf, FUR_MID, leg_rect)
            # 발바닥 패드
            fpad_r = int(leg_w * 0.28)
            fpad_cy = leg_rect.centery + 2
            pygame.draw.circle(surf, PAW_PAD_DARK, (lx, fpad_cy), fpad_r + 1)
            pygame.draw.circle(surf, PAW_PAD, (lx, fpad_cy), fpad_r)
            for pi in range(-1, 2):
                pr = max(2, fpad_r // 3)
                pygame.draw.circle(surf, PAW_PAD_DARK, (lx + pi * (pr + 1), fpad_cy - fpad_r - pr + 2), pr)

        # ── 머리 ──
        head_r = int(w * 0.22)
        head_y = by + int(h * 0.24)
        # 머리 윤곽 + 그라디언트 느낌
        pygame.draw.circle(surf, FUR_OUTLINE, (bx, head_y), head_r + 5)
        pygame.draw.circle(surf, FUR_DARK, (bx, head_y), head_r + 3)
        pygame.draw.circle(surf, FUR_MAIN, (bx, head_y), head_r)
        # 머리 하이라이트 (상단 좌측 빛)
        hl_r = int(head_r * 0.55)
        hl_cx = bx - int(head_r * 0.2)
        hl_cy = head_y - int(head_r * 0.25)
        hl2_surf = pygame.Surface((hl_r * 2, hl_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(hl2_surf, (*FUR_HIGHLIGHT, 60), (hl_r, hl_r), hl_r)
        surf.blit(hl2_surf, (hl_cx - hl_r, hl_cy - hl_r))

        # 주둥이 영역 (밝은 타원)
        muzzle_w = int(head_r * 0.85)
        muzzle_h = int(head_r * 0.60)
        muzzle_cy = head_y + int(head_r * 0.18)
        muzzle_rect = pygame.Rect(bx - muzzle_w // 2, muzzle_cy - muzzle_h // 2, muzzle_w, muzzle_h)
        pygame.draw.ellipse(surf, FUR_BELLY, muzzle_rect)
        pygame.draw.ellipse(surf, FUR_BELLY_LIGHT, muzzle_rect.inflate(-6, -6))

        # ── 눈 (더 디테일하게) ──
        eye_off_x = int(head_r * 0.30)
        eye_y = head_y - int(head_r * 0.05)
        eye_r = int(head_r * 0.15)
        for side in [-1, 1]:
            ex = bx + side * eye_off_x
            # 눈 외곽
            pygame.draw.circle(surf, EYE_OUTER, (ex, eye_y), eye_r + 2)
            pygame.draw.circle(surf, EYE_COL, (ex, eye_y), eye_r)
            # 큰 하이라이트
            pygame.draw.circle(surf, EYE_SHINE, (ex - 2, eye_y - 3), max(3, eye_r // 2))
            # 작은 하이라이트 (하단 우측)
            pygame.draw.circle(surf, EYE_SHINE2, (ex + 2, eye_y + 2), max(1, eye_r // 4))
            # 속눈썹 (위)
            for li in range(-1, 2):
                lx1 = ex + li * (eye_r // 2)
                pygame.draw.line(surf, FUR_OUTLINE, (lx1, eye_y - eye_r - 1), (lx1 + li, eye_y - eye_r - 4), 2)

        # ── 눈썹 (약간 화난 표정) ──
        brow_y = eye_y - eye_r - 5
        for side in [-1, 1]:
            brow_x = bx + side * eye_off_x
            brow_inner = (brow_x - side * (eye_r - 2), brow_y + 2)
            brow_outer = (brow_x + side * (eye_r + 2), brow_y - 3)
            pygame.draw.line(surf, FUR_OUTLINE, brow_inner, brow_outer, 3)

        # ── 코 (타원 + 광택) ──
        nose_w = int(head_r * 0.20)
        nose_h = int(head_r * 0.14)
        nose_cy = muzzle_cy - int(muzzle_h * 0.15)
        nose_rect = pygame.Rect(bx - nose_w, nose_cy - nose_h // 2, nose_w * 2, nose_h)
        pygame.draw.ellipse(surf, NOSE_COL, nose_rect.inflate(3, 3))
        pygame.draw.ellipse(surf, NOSE_COL, nose_rect)
        # 코 광택
        nr = max(2, nose_w // 3)
        pygame.draw.circle(surf, NOSE_SHINE, (bx - nose_w // 2, nose_cy - nose_h // 4), nr)

        # ── 입 (Y 자 곰 입) ──
        mouth_top = nose_cy + nose_h // 2 + 1
        mouth_bot = mouth_top + int(head_r * 0.15)
        mouth_w = int(head_r * 0.18)
        pygame.draw.line(surf, MOUTH_COL, (bx, mouth_top), (bx, mouth_bot - 3), 2)
        pygame.draw.line(surf, MOUTH_COL, (bx, mouth_bot - 3), (bx - mouth_w, mouth_bot), 2)
        pygame.draw.line(surf, MOUTH_COL, (bx, mouth_bot - 3), (bx + mouth_w, mouth_bot), 2)

        # ── 볼터치 ──
        cheek_r = int(head_r * 0.12)
        cheek_y = muzzle_cy + int(muzzle_h * 0.1)
        cheek_surf2 = pygame.Surface((cheek_r * 2, cheek_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(cheek_surf2, CHEEK_COL, (cheek_r, cheek_r), cheek_r)
        for side in [-1, 1]:
            cx_cheek = bx + side * int(head_r * 0.45)
            surf.blit(cheek_surf2, (cx_cheek - cheek_r, cheek_y - cheek_r))

        # ── 리본 (목 - 고퀄리티) ──
        ribbon_cy = by + int(h * 0.37)
        rb_w = int(w * 0.07)
        rb_h = int(h * 0.05)
        for side in [-1, 1]:
            # 리본 날개
            pts = [
                (bx + side * rb_w * 2.2, ribbon_cy - rb_h * 1.2),
                (bx + side * 3, ribbon_cy),
                (bx + side * rb_w * 2.2, ribbon_cy + rb_h * 1.2),
            ]
            pygame.draw.polygon(surf, RIBBON_COL, pts)
            # 리본 주름 (하이라이트)
            pts2 = [
                (bx + side * rb_w * 1.5, ribbon_cy - rb_h * 0.6),
                (bx + side * rb_w * 0.5, ribbon_cy),
                (bx + side * rb_w * 1.5, ribbon_cy + rb_h * 0.2),
            ]
            pygame.draw.polygon(surf, RIBBON_LIGHT, pts2)
            # 리본 그림자
            pts3 = [
                (bx + side * rb_w * 2.2, ribbon_cy - rb_h * 1.2),
                (bx + side * rb_w * 1.2, ribbon_cy - rb_h * 0.3),
                (bx + side * rb_w * 2.2, ribbon_cy - rb_h * 0.2),
            ]
            pygame.draw.polygon(surf, RIBBON_DARK, pts3)
        # 매듭
        knot_r = int(rb_w * 0.55)
        pygame.draw.circle(surf, RIBBON_DARK, (bx, ribbon_cy), knot_r + 2)
        pygame.draw.circle(surf, RIBBON_COL, (bx, ribbon_cy), knot_r)
        # 매듭 하이라이트
        pygame.draw.circle(surf, RIBBON_LIGHT, (bx - 1, ribbon_cy - 2), max(1, knot_r // 2))

        # ── 머리 봉제선 (이마 중앙) ──
        stitch_y_start = head_y - int(head_r * 0.65)
        stitch_y_end = head_y - int(head_r * 0.20)
        stitch_len = stitch_y_end - stitch_y_start
        for i in range(0, stitch_len, 6):
            y1 = stitch_y_start + i
            y2 = min(stitch_y_start + i + 3, stitch_y_end)
            pygame.draw.line(surf, STITCH, (bx - 1, y1), (bx + 1, y2), 1)

        return surf

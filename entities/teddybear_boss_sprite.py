"""
🧸 Stage 3 Boss Sprite Animation - 테디베어 느릿느릿 걷기 애니메이션
프로시저럴 렌더링 기반 좌우 이동 + 흔들기 애니메이션 (다른 보스의 3배 느림)
고퀄리티 봉제인형 디자인: 버튼눈, 하트발바닥, 봉제선, 리본, 털 질감
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

    # ────────────────────────────────────────────
    #  헬퍼: 소프트 그라디언트 원/타원
    # ────────────────────────────────────────────
    @staticmethod
    def _draw_gradient_circle(surf, center, radius, color_inner, color_outer, steps=6):
        """중심에서 바깥으로 색이 변하는 소프트 원"""
        for i in range(steps, 0, -1):
            t = i / steps
            r = int(radius * t)
            c = tuple(int(color_outer[j] + (color_inner[j] - color_outer[j]) * (1 - t)) for j in range(3))
            alpha = color_inner[3] if len(color_inner) > 3 else 255
            if r > 0:
                tmp = pygame.Surface((r * 2, r * 2), pygame.SRCALPHA)
                pygame.draw.circle(tmp, (*c, alpha), (r, r), r)
                surf.blit(tmp, (center[0] - r, center[1] - r))

    @staticmethod
    def _draw_gradient_ellipse(surf, rect, color_inner, color_outer, steps=5):
        """중심에서 바깥으로 색이 변하는 소프트 타원"""
        cx, cy = rect.centerx, rect.centery
        for i in range(steps, 0, -1):
            t = i / steps
            w2 = int(rect.width * t)
            h2 = int(rect.height * t)
            c = tuple(int(color_outer[j] + (color_inner[j] - color_outer[j]) * (1 - t)) for j in range(3))
            if w2 > 0 and h2 > 0:
                r2 = pygame.Rect(cx - w2 // 2, cy - h2 // 2, w2, h2)
                pygame.draw.ellipse(surf, c, r2)

    @staticmethod
    def _draw_fur_lines(surf, cx, cy, radius, color, count=12, length_ratio=0.15):
        """방사형 털 질감 선"""
        for i in range(count):
            angle = (2 * math.pi / count) * i
            r_inner = radius * (1.0 - length_ratio)
            r_outer = radius * 1.02
            x1 = cx + int(r_inner * math.cos(angle))
            y1 = cy + int(r_inner * math.sin(angle))
            x2 = cx + int(r_outer * math.cos(angle))
            y2 = cy + int(r_outer * math.sin(angle))
            pygame.draw.line(surf, color, (x1, y1), (x2, y2), 1)

    def _draw_teddy(self, w, h):
        """최고 퀄리티 프로시저럴 테디베어 렌더링"""
        margin = 14
        surf = pygame.Surface((w + margin * 2, h + margin * 2), pygame.SRCALPHA)
        ox, oy = margin, margin
        cx = w // 2 + ox
        _sin = math.sin
        _cos = math.cos

        # 흔들림/바운스 오프셋
        sway = self.body_sway
        bounce = -self.bounce_y
        breath = _sin(self.idle_breath) * 2.0 if self.direction == 0 else 0
        hit_shake = 0
        if self.is_hit:
            hit_shake = int(_sin(self.hit_timer * 60) * 5) * self.hit_direction

        bx = cx + int(sway) + hit_shake
        by = oy + int(bounce + breath)

        # ══════════════════════════════════════════
        #  색상 팔레트 (프리미엄 봉제인형)
        # ══════════════════════════════════════════
        FUR_OUTLINE = (82, 52, 22)
        FUR_DARK = (130, 85, 38)
        FUR_MID = (162, 112, 52)
        FUR_MAIN = (188, 138, 72)
        FUR_LIGHT = (212, 168, 100)
        FUR_HIGHLIGHT = (232, 198, 140)
        FUR_RIM = (225, 190, 130, 90)       # 림 라이트

        BELLY_DARK = (225, 200, 158)
        BELLY_MAIN = (238, 218, 182)
        BELLY_LIGHT = (248, 235, 210)
        BELLY_GLOW = (255, 245, 228, 120)

        NOSE_DARK = (35, 20, 10)
        NOSE_MAIN = (50, 30, 15)
        NOSE_SHINE1 = (90, 65, 40)
        NOSE_SHINE2 = (130, 100, 70, 180)

        EYE_OUTER = (40, 26, 14)
        EYE_MAIN = (22, 15, 8)
        EYE_SHINE = (255, 255, 255)
        EYE_SHINE2 = (200, 220, 255, 200)
        EYE_THREAD = (110, 70, 35)

        MOUTH_COL = (85, 50, 25)

        CHEEK_COL = (255, 130, 130, 50)
        CHEEK_INNER = (255, 160, 160, 35)

        RIBBON_MAIN = (200, 35, 35)
        RIBBON_LIGHT = (235, 75, 75)
        RIBBON_DARK = (150, 20, 20)
        RIBBON_SHADOW = (120, 15, 15, 100)
        RIBBON_SATIN = (255, 120, 120, 80)

        STITCH_COL = (155, 105, 50, 160)
        STITCH_DARK = (120, 80, 35, 130)

        PAW_MAIN = (210, 168, 130)
        PAW_DARK = (180, 140, 100)
        PAW_LIGHT = (230, 195, 160)
        PAW_HEART = (225, 155, 140)
        PAW_HEART_DARK = (195, 125, 110)
        PAW_TOE = (215, 170, 145)
        PAW_TOE_DARK = (190, 145, 115)

        EAR_INNER = (220, 170, 145)
        EAR_INNER_LIGHT = (235, 195, 170)
        EAR_INNER_DEEP = (205, 155, 130)

        # ══════════════════════════════════════════
        #  1. 그림자 (바닥)
        # ══════════════════════════════════════════
        shadow_w = int(w * 0.52)
        shadow_h = int(h * 0.055)
        shadow_y = by + int(h * 0.93)
        shadow_surf = pygame.Surface((shadow_w + 10, shadow_h + 10), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 28), (5, 5, shadow_w, shadow_h))
        # 부드러운 그림자 외곽
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 12), (0, 0, shadow_w + 10, shadow_h + 10))
        surf.blit(shadow_surf, (bx - shadow_w // 2 - 5, shadow_y - 5))

        # ══════════════════════════════════════════
        #  2. 귀 (머리 뒤)
        # ══════════════════════════════════════════
        ear_r = int(w * 0.10)
        ear_y = by + int(h * 0.10)
        ear_lx = bx - int(w * 0.21)
        ear_rx = bx + int(w * 0.21)

        for ex in [ear_lx, ear_rx]:
            # 귀 털 질감 외곽
            self._draw_fur_lines(surf, ex, ear_y, ear_r + 5, FUR_DARK, count=16, length_ratio=0.12)
            # 귀 본체 (그라디언트)
            pygame.draw.circle(surf, FUR_OUTLINE, (ex, ear_y), ear_r + 5)
            pygame.draw.circle(surf, FUR_DARK, (ex, ear_y), ear_r + 3)
            self._draw_gradient_circle(surf, (ex, ear_y), ear_r, FUR_LIGHT, FUR_MAIN, steps=5)
            # 귀 안쪽 (다층)
            inner_r = int(ear_r * 0.58)
            pygame.draw.circle(surf, EAR_INNER_DEEP, (ex, ear_y + 1), inner_r + 1)
            self._draw_gradient_circle(surf, (ex, ear_y), inner_r, EAR_INNER_LIGHT, EAR_INNER, steps=4)
            # 귀 안쪽 하이라이트
            tiny_r = int(inner_r * 0.45)
            hl_s = pygame.Surface((tiny_r * 2, tiny_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(hl_s, (255, 220, 200, 50), (tiny_r, tiny_r), tiny_r)
            surf.blit(hl_s, (ex - tiny_r, ear_y - tiny_r - 2))

        # ══════════════════════════════════════════
        #  3. 몸통
        # ══════════════════════════════════════════
        body_w = int(w * 0.66)
        body_h = int(h * 0.48)
        body_cy = by + int(h * 0.55)
        body_rect = pygame.Rect(bx - body_w // 2, body_cy - body_h // 2, body_w, body_h)

        # 윤곽 + 그라디언트 몸통
        pygame.draw.ellipse(surf, FUR_OUTLINE, body_rect.inflate(10, 10))
        pygame.draw.ellipse(surf, FUR_DARK, body_rect.inflate(6, 6))
        self._draw_gradient_ellipse(surf, body_rect, FUR_LIGHT, FUR_MAIN, steps=6)

        # 몸통 털 질감 (가장자리 방사형 선)
        self._draw_fur_lines(surf, bx, body_cy, body_w // 2, (*FUR_MID, 80), count=24, length_ratio=0.08)

        # 몸통 상단 좌측 하이라이트 (빛 반사)
        hl_w = int(body_w * 0.35)
        hl_h = int(body_h * 0.30)
        hl_s = pygame.Surface((hl_w, hl_h), pygame.SRCALPHA)
        pygame.draw.ellipse(hl_s, (*FUR_HIGHLIGHT, 55), (0, 0, hl_w, hl_h))
        surf.blit(hl_s, (bx - body_w // 3, body_cy - body_h // 3))

        # 림 라이트 (우측 가장자리)
        rim_w = int(body_w * 0.15)
        rim_h = int(body_h * 0.6)
        rim_s = pygame.Surface((rim_w, rim_h), pygame.SRCALPHA)
        pygame.draw.ellipse(rim_s, FUR_RIM, (0, 0, rim_w, rim_h))
        surf.blit(rim_s, (bx + body_w // 2 - rim_w + 2, body_cy - rim_h // 2))

        # ── 배 (다층 그라디언트) ──
        belly_w = int(body_w * 0.54)
        belly_h = int(body_h * 0.62)
        belly_rect = pygame.Rect(bx - belly_w // 2, body_cy - belly_h // 3, belly_w, belly_h)
        pygame.draw.ellipse(surf, BELLY_DARK, belly_rect.inflate(4, 4))
        self._draw_gradient_ellipse(surf, belly_rect, BELLY_LIGHT, BELLY_MAIN, steps=5)
        # 배 중앙 글로우
        glow_w = int(belly_w * 0.5)
        glow_h = int(belly_h * 0.4)
        glow_s = pygame.Surface((glow_w, glow_h), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_s, BELLY_GLOW, (0, 0, glow_w, glow_h))
        surf.blit(glow_s, (bx - glow_w // 2, belly_rect.y + int(belly_h * 0.15)))

        # ── 배 십자 봉제선 (더 정교한 X자 스티치) ──
        stx, sty = bx, body_cy + int(body_h * 0.06)
        st_len = int(belly_w * 0.18)
        # X자 크로스 스티치
        for di in range(-st_len, st_len + 1, 5):
            # 대각선 스티치 패턴
            pygame.draw.line(surf, STITCH_COL, (stx + di, sty - 2), (stx + di + 3, sty + 2), 1)
        # 중심 십자
        pygame.draw.line(surf, STITCH_COL, (stx - st_len, sty), (stx + st_len, sty), 2)
        pygame.draw.line(surf, STITCH_COL, (stx, sty - st_len), (stx, sty + st_len), 2)
        # 스티치 구멍 점
        for sx in range(-st_len, st_len + 1, 6):
            pygame.draw.circle(surf, STITCH_DARK, (stx + sx, sty), 1)
        for sy in range(-st_len, st_len + 1, 6):
            pygame.draw.circle(surf, STITCH_DARK, (stx, sty + sy), 1)

        # ══════════════════════════════════════════
        #  4. 팔 (좌우 - 걷기 흔들림)
        # ══════════════════════════════════════════
        arm_w = int(w * 0.14)
        arm_h = int(h * 0.29)
        arm_base_y = by + int(h * 0.42)
        arm_sw = self.arm_swing

        for side in [-1, 1]:
            a_swing = int(arm_sw * side * 0.6)
            ax = bx + side * (body_w // 2 + arm_w // 6)
            ay = arm_base_y + abs(a_swing) // 2
            arm_rect = pygame.Rect(ax - arm_w // 2, ay, arm_w, arm_h)

            # 팔 본체 (그라디언트)
            pygame.draw.ellipse(surf, FUR_OUTLINE, arm_rect.inflate(6, 6))
            pygame.draw.ellipse(surf, FUR_DARK, arm_rect.inflate(3, 3))
            self._draw_gradient_ellipse(surf, arm_rect, FUR_LIGHT, FUR_MID, steps=4)

            # 팔 하이라이트
            ah_w = int(arm_rect.w * 0.45)
            ah_h = int(arm_rect.h * 0.30)
            ah_s = pygame.Surface((ah_w, ah_h), pygame.SRCALPHA)
            pygame.draw.ellipse(ah_s, (*FUR_HIGHLIGHT, 55), (0, 0, ah_w, ah_h))
            surf.blit(ah_s, (arm_rect.x + 3, arm_rect.y + 4))

            # 팔 봉제선 (세로)
            arm_stitch_x = ax
            arm_stitch_top = arm_rect.y + int(arm_rect.h * 0.2)
            arm_stitch_bot = arm_rect.y + int(arm_rect.h * 0.7)
            for sy in range(arm_stitch_top, arm_stitch_bot, 5):
                pygame.draw.line(surf, STITCH_COL, (arm_stitch_x - 1, sy), (arm_stitch_x + 1, sy + 2), 1)

            # ── 발바닥 (하트 모양 메인패드 + 토빈즈) ──
            pad_cy = arm_rect.bottom - int(arm_w * 0.35) - 2
            pad_r = int(arm_w * 0.32)

            # 발바닥 배경 (원)
            pygame.draw.circle(surf, PAW_DARK, (ax, pad_cy), pad_r + 3)
            pygame.draw.circle(surf, PAW_MAIN, (ax, pad_cy), pad_r + 1)

            # 하트 모양 메인 패드
            heart_size = int(pad_r * 0.85)
            hx, hy = ax, pad_cy + 1
            # 하트: 두 개의 원 + 아래 삼각형
            hr = int(heart_size * 0.45)
            pygame.draw.circle(surf, PAW_HEART_DARK, (hx - hr + 1, hy - hr // 3), hr + 1)
            pygame.draw.circle(surf, PAW_HEART_DARK, (hx + hr - 1, hy - hr // 3), hr + 1)
            pygame.draw.circle(surf, PAW_HEART, (hx - hr + 1, hy - hr // 3), hr)
            pygame.draw.circle(surf, PAW_HEART, (hx + hr - 1, hy - hr // 3), hr)
            # 하트 하단 삼각형
            tri_pts = [
                (hx - int(heart_size * 0.72), hy - 1),
                (hx + int(heart_size * 0.72), hy - 1),
                (hx, hy + int(heart_size * 0.75)),
            ]
            pygame.draw.polygon(surf, PAW_HEART, tri_pts)
            pygame.draw.polygon(surf, PAW_HEART_DARK, tri_pts, 1)
            # 하트 광택
            hl_s2 = pygame.Surface((hr, hr), pygame.SRCALPHA)
            pygame.draw.circle(hl_s2, (255, 200, 190, 70), (hr // 2, hr // 2), hr // 2)
            surf.blit(hl_s2, (hx - hr - 1, hy - hr))

            # 토빈즈 (작은 타원 패드 3개)
            for pi in range(-1, 2):
                toe_x = ax + pi * (pad_r // 2 + 1)
                toe_y = pad_cy - pad_r - int(pad_r * 0.25)
                toe_rx = max(3, int(pad_r * 0.32))
                toe_ry = max(2, int(pad_r * 0.25))
                pygame.draw.ellipse(surf, PAW_TOE_DARK, (toe_x - toe_rx - 1, toe_y - toe_ry - 1, toe_rx * 2 + 2, toe_ry * 2 + 2))
                pygame.draw.ellipse(surf, PAW_TOE, (toe_x - toe_rx, toe_y - toe_ry, toe_rx * 2, toe_ry * 2))
                # 토빈즈 광택
                tiny = max(1, toe_rx // 3)
                pygame.draw.circle(surf, (255, 230, 220, 80), (toe_x - 1, toe_y - 1), tiny)

        # ══════════════════════════════════════════
        #  5. 다리 (좌우 - 걷기 오프셋)
        # ══════════════════════════════════════════
        leg_w = int(w * 0.16)
        leg_h = int(h * 0.17)
        leg_base_y = by + int(h * 0.80)

        for side_idx, side in enumerate([-1, 1]):
            l_offset = int(_sin(self.walk_phase + side_idx * math.pi) * 4) if self.direction != 0 else 0
            lx = bx + side * int(w * 0.13)
            ly = leg_base_y + l_offset
            leg_rect = pygame.Rect(lx - leg_w // 2, ly, leg_w, leg_h)

            # 다리 본체
            pygame.draw.ellipse(surf, FUR_OUTLINE, leg_rect.inflate(6, 6))
            pygame.draw.ellipse(surf, FUR_DARK, leg_rect.inflate(3, 3))
            self._draw_gradient_ellipse(surf, leg_rect, FUR_LIGHT, FUR_MID, steps=4)

            # 다리 봉제선
            for sy in range(leg_rect.y + 4, leg_rect.bottom - 4, 5):
                pygame.draw.line(surf, STITCH_COL, (lx - 1, sy), (lx + 1, sy + 2), 1)

            # ── 발바닥 (다리용 - 하트 패드) ──
            fpad_cy = leg_rect.centery + 3
            fpad_r = int(leg_w * 0.30)

            pygame.draw.circle(surf, PAW_DARK, (lx, fpad_cy), fpad_r + 2)
            pygame.draw.circle(surf, PAW_MAIN, (lx, fpad_cy), fpad_r)

            # 미니 하트 패드
            mhr = int(fpad_r * 0.42)
            pygame.draw.circle(surf, PAW_HEART_DARK, (lx - mhr + 1, fpad_cy - 1), mhr)
            pygame.draw.circle(surf, PAW_HEART_DARK, (lx + mhr - 1, fpad_cy - 1), mhr)
            pygame.draw.circle(surf, PAW_HEART, (lx - mhr + 1, fpad_cy - 1), mhr - 1)
            pygame.draw.circle(surf, PAW_HEART, (lx + mhr - 1, fpad_cy - 1), mhr - 1)
            tri2 = [
                (lx - int(fpad_r * 0.65), fpad_cy),
                (lx + int(fpad_r * 0.65), fpad_cy),
                (lx, fpad_cy + int(fpad_r * 0.7)),
            ]
            pygame.draw.polygon(surf, PAW_HEART, tri2)

            # 토빈즈
            for pi in range(-1, 2):
                tx = lx + pi * (fpad_r // 2 + 1)
                ty = fpad_cy - fpad_r - int(fpad_r * 0.15)
                tr = max(2, int(fpad_r * 0.28))
                pygame.draw.circle(surf, PAW_TOE_DARK, (tx, ty), tr + 1)
                pygame.draw.circle(surf, PAW_TOE, (tx, ty), tr)

        # ══════════════════════════════════════════
        #  6. 머리
        # ══════════════════════════════════════════
        head_r = int(w * 0.23)
        head_y = by + int(h * 0.24)

        # 머리 외곽 + 그라디언트
        self._draw_fur_lines(surf, bx, head_y, head_r + 5, FUR_DARK, count=20, length_ratio=0.10)
        pygame.draw.circle(surf, FUR_OUTLINE, (bx, head_y), head_r + 6)
        pygame.draw.circle(surf, FUR_DARK, (bx, head_y), head_r + 3)
        self._draw_gradient_circle(surf, (bx, head_y), head_r, FUR_HIGHLIGHT, FUR_MAIN, steps=6)

        # 머리 상단 좌측 빛 반사
        hl_r = int(head_r * 0.50)
        hl_cx = bx - int(head_r * 0.22)
        hl_cy = head_y - int(head_r * 0.28)
        hl_s = pygame.Surface((hl_r * 2, hl_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(hl_s, (*FUR_HIGHLIGHT, 50), (hl_r, hl_r), hl_r)
        surf.blit(hl_s, (hl_cx - hl_r, hl_cy - hl_r))

        # 머리 림 라이트 (우측)
        rim_s2 = pygame.Surface((int(head_r * 0.4), int(head_r * 1.2)), pygame.SRCALPHA)
        pygame.draw.ellipse(rim_s2, FUR_RIM, rim_s2.get_rect())
        surf.blit(rim_s2, (bx + int(head_r * 0.55), head_y - int(head_r * 0.6)))

        # ── 머리 위 털 뭉치 (3개 작은 삼각형) ──
        tuft_y = head_y - head_r - 2
        for ti in range(-1, 2):
            tuft_x = bx + ti * int(head_r * 0.22)
            tuft_h2 = int(head_r * 0.15) + abs(ti) * 2
            pts = [
                (tuft_x - 3, tuft_y + 4),
                (tuft_x + 3, tuft_y + 4),
                (tuft_x + ti * 2, tuft_y - tuft_h2),
            ]
            pygame.draw.polygon(surf, FUR_MAIN, pts)
            pygame.draw.polygon(surf, FUR_DARK, pts, 1)

        # ══════════════════════════════════════════
        #  7. 주둥이 (밝은 타원)
        # ══════════════════════════════════════════
        muzzle_w = int(head_r * 0.90)
        muzzle_h = int(head_r * 0.62)
        muzzle_cy = head_y + int(head_r * 0.20)
        muzzle_rect = pygame.Rect(bx - muzzle_w // 2, muzzle_cy - muzzle_h // 2, muzzle_w, muzzle_h)
        pygame.draw.ellipse(surf, BELLY_DARK, muzzle_rect.inflate(4, 4))
        self._draw_gradient_ellipse(surf, muzzle_rect, BELLY_LIGHT, BELLY_MAIN, steps=4)
        # 주둥이 광택
        mg_w = int(muzzle_w * 0.4)
        mg_h = int(muzzle_h * 0.3)
        mg_s = pygame.Surface((mg_w, mg_h), pygame.SRCALPHA)
        pygame.draw.ellipse(mg_s, (255, 248, 235, 60), (0, 0, mg_w, mg_h))
        surf.blit(mg_s, (bx - mg_w // 2 - 3, muzzle_cy - muzzle_h // 3))

        # ══════════════════════════════════════════
        #  8. 버튼 눈 (실로 꿰맨 봉제인형 눈)
        # ══════════════════════════════════════════
        eye_off_x = int(head_r * 0.32)
        eye_y = head_y - int(head_r * 0.06)
        eye_r = int(head_r * 0.16)

        for side in [-1, 1]:
            ex = bx + side * eye_off_x

            # 버튼 눈 외곽 (약간 오목한 느낌)
            pygame.draw.circle(surf, EYE_OUTER, (ex, eye_y), eye_r + 3)
            pygame.draw.circle(surf, EYE_MAIN, (ex, eye_y), eye_r + 1)
            # 버튼 본체
            pygame.draw.circle(surf, (30, 20, 10), (ex, eye_y), eye_r)
            # 버튼 테두리 (살짝 밝은 링)
            pygame.draw.circle(surf, (55, 38, 20), (ex, eye_y), eye_r, 2)
            # 버튼 구멍 (X자 실)
            thread_len = max(2, eye_r // 2)
            # X자 바느질
            pygame.draw.line(surf, EYE_THREAD, (ex - thread_len, eye_y - thread_len),
                             (ex + thread_len, eye_y + thread_len), 2)
            pygame.draw.line(surf, EYE_THREAD, (ex + thread_len, eye_y - thread_len),
                             (ex - thread_len, eye_y + thread_len), 2)
            # 큰 하이라이트
            shine_r = max(2, int(eye_r * 0.38))
            pygame.draw.circle(surf, EYE_SHINE, (ex - 2, eye_y - 3), shine_r)
            # 작은 하이라이트 (하단)
            shine2_r = max(1, int(eye_r * 0.22))
            s2_s = pygame.Surface((shine2_r * 2, shine2_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(s2_s, EYE_SHINE2, (shine2_r, shine2_r), shine2_r)
            surf.blit(s2_s, (ex + 1 - shine2_r, eye_y + 2 - shine2_r))

            # 눈 위 실 꿰맨 자국 (3개 바느질 선)
            for li in range(-1, 2):
                stitch_x = ex + li * (eye_r // 2)
                # 실이 천을 통과하는 느낌
                pygame.draw.line(surf, EYE_THREAD,
                                 (stitch_x, eye_y - eye_r - 2),
                                 (stitch_x + li, eye_y - eye_r - 5), 2)
                pygame.draw.circle(surf, EYE_THREAD, (stitch_x, eye_y - eye_r - 2), 1)

        # ══════════════════════════════════════════
        #  9. 눈썹 (약간 화난 표정)
        # ══════════════════════════════════════════
        brow_y = eye_y - eye_r - 7
        for side in [-1, 1]:
            brow_x = bx + side * eye_off_x
            brow_inner = (brow_x - side * (eye_r - 1), brow_y + 3)
            brow_outer = (brow_x + side * (eye_r + 3), brow_y - 4)
            pygame.draw.line(surf, FUR_OUTLINE, brow_inner, brow_outer, 3)
            # 눈썹 그림자
            pygame.draw.line(surf, (*FUR_DARK, 100),
                             (brow_inner[0], brow_inner[1] + 1),
                             (brow_outer[0], brow_outer[1] + 1), 2)

        # ══════════════════════════════════════════
        #  10. 코 (광택 있는 삼각 타원)
        # ══════════════════════════════════════════
        nose_w = int(head_r * 0.22)
        nose_h = int(head_r * 0.15)
        nose_cy = muzzle_cy - int(muzzle_h * 0.14)
        nose_rect = pygame.Rect(bx - nose_w, nose_cy - nose_h // 2, nose_w * 2, nose_h)

        # 코 그림자
        pygame.draw.ellipse(surf, (30, 15, 5), nose_rect.inflate(5, 5))
        # 코 본체 (역삼각 느낌 - 약간 아래로)
        nose_pts = [
            (bx - nose_w, nose_cy - nose_h // 3),
            (bx + nose_w, nose_cy - nose_h // 3),
            (bx, nose_cy + nose_h // 2 + 2),
        ]
        pygame.draw.polygon(surf, NOSE_DARK, nose_pts)
        # 코 타원 오버레이
        pygame.draw.ellipse(surf, NOSE_MAIN, nose_rect)
        # 코 광택 (좌상단 큰 하이라이트)
        nr = max(2, nose_w // 3)
        self._draw_gradient_circle(surf, (bx - nose_w // 3, nose_cy - nose_h // 4),
                                   nr, NOSE_SHINE1, NOSE_MAIN, steps=3)
        # 코 작은 스페큘러 하이라이트
        tiny_shine = max(1, nose_w // 5)
        pygame.draw.circle(surf, (180, 150, 120, 160), (bx - nose_w // 3, nose_cy - nose_h // 4 - 1), tiny_shine)

        # ══════════════════════════════════════════
        #  11. 입 (Y자 곰 입 - 더 부드럽게)
        # ══════════════════════════════════════════
        mouth_top = nose_cy + nose_h // 2 + 2
        mouth_bot = mouth_top + int(head_r * 0.16)
        mouth_w = int(head_r * 0.20)

        # 입 메인 라인
        pygame.draw.line(surf, MOUTH_COL, (bx, mouth_top), (bx, mouth_bot - 2), 2)
        # 입 양쪽 곡선 (arc 대신 짧은 선분으로)
        for side in [-1, 1]:
            # 좌우 커브
            pts = []
            for t_i in range(6):
                t = t_i / 5.0
                mx = bx + side * int(mouth_w * t * 0.9)
                my = mouth_bot - 2 + int(3 * t * t)  # 약간 아래로 커브
                pts.append((mx, my))
            if len(pts) >= 2:
                pygame.draw.lines(surf, MOUTH_COL, False, pts, 2)

        # ══════════════════════════════════════════
        #  12. 볼터치 (소프트 블러시)
        # ══════════════════════════════════════════
        cheek_r = int(head_r * 0.14)
        cheek_y = muzzle_cy + int(muzzle_h * 0.12)

        for side in [-1, 1]:
            cx_cheek = bx + side * int(head_r * 0.48)
            # 외곽 글로우
            c_outer = pygame.Surface((cheek_r * 3, cheek_r * 3), pygame.SRCALPHA)
            pygame.draw.circle(c_outer, CHEEK_INNER, (cheek_r * 3 // 2, cheek_r * 3 // 2), cheek_r * 3 // 2)
            surf.blit(c_outer, (cx_cheek - cheek_r * 3 // 2, cheek_y - cheek_r * 3 // 2))
            # 내부 블러시
            c_inner = pygame.Surface((cheek_r * 2, cheek_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(c_inner, CHEEK_COL, (cheek_r, cheek_r), cheek_r)
            surf.blit(c_inner, (cx_cheek - cheek_r, cheek_y - cheek_r))

        # ══════════════════════════════════════════
        #  13. 리본 (목 - 새틴 리본 디테일)
        # ══════════════════════════════════════════
        ribbon_cy = by + int(h * 0.37)
        rb_w = int(w * 0.075)
        rb_h = int(h * 0.055)

        for side in [-1, 1]:
            # 리본 그림자
            sh_pts = [
                (bx + side * int(rb_w * 2.4), ribbon_cy - int(rb_h * 1.0) + 3),
                (bx + side * 4, ribbon_cy + 3),
                (bx + side * int(rb_w * 2.4), ribbon_cy + int(rb_h * 1.4) + 3),
            ]
            pygame.draw.polygon(surf, RIBBON_SHADOW, sh_pts)

            # 리본 날개 본체
            pts = [
                (bx + side * int(rb_w * 2.4), ribbon_cy - int(rb_h * 1.3)),
                (bx + side * 3, ribbon_cy),
                (bx + side * int(rb_w * 2.4), ribbon_cy + int(rb_h * 1.3)),
            ]
            pygame.draw.polygon(surf, RIBBON_MAIN, pts)
            pygame.draw.polygon(surf, RIBBON_DARK, pts, 2)

            # 리본 접힘 하이라이트 (새틴 광택)
            pts2 = [
                (bx + side * int(rb_w * 1.8), ribbon_cy - int(rb_h * 0.7)),
                (bx + side * int(rb_w * 0.6), ribbon_cy - int(rb_h * 0.1)),
                (bx + side * int(rb_w * 1.6), ribbon_cy + int(rb_h * 0.3)),
            ]
            pygame.draw.polygon(surf, RIBBON_LIGHT, pts2)

            # 새틴 스트라이프 (광택 줄)
            satin_s = pygame.Surface((abs(int(rb_w * 2.0)), abs(int(rb_h * 0.3)) + 1), pygame.SRCALPHA)
            satin_s.fill(RIBBON_SATIN)
            sx2 = min(bx + side * int(rb_w * 0.5), bx + side * int(rb_w * 2.2))
            surf.blit(satin_s, (sx2, ribbon_cy - int(rb_h * 0.15)))

            # 리본 가장자리 다크 라인
            pts3 = [
                (bx + side * int(rb_w * 2.4), ribbon_cy + int(rb_h * 1.3)),
                (bx + side * int(rb_w * 1.5), ribbon_cy + int(rb_h * 0.5)),
                (bx + side * int(rb_w * 2.4), ribbon_cy + int(rb_h * 0.5)),
            ]
            pygame.draw.polygon(surf, RIBBON_DARK, pts3)

        # 매듭 중앙
        knot_r = int(rb_w * 0.60)
        # 매듭 그림자
        pygame.draw.circle(surf, RIBBON_SHADOW, (bx, ribbon_cy + 2), knot_r + 3)
        # 매듭 본체
        pygame.draw.circle(surf, RIBBON_DARK, (bx, ribbon_cy), knot_r + 2)
        pygame.draw.circle(surf, RIBBON_MAIN, (bx, ribbon_cy), knot_r)
        # 매듭 하이라이트
        kh_r = max(1, knot_r // 2)
        pygame.draw.circle(surf, RIBBON_LIGHT, (bx - 1, ribbon_cy - 2), kh_r)
        # 매듭 접힘 라인
        pygame.draw.arc(surf, RIBBON_DARK, (bx - knot_r, ribbon_cy - knot_r, knot_r * 2, knot_r * 2),
                        0.3, 1.8, 1)

        # 리본 아래 늘어진 끈 (2개)
        tail_len = int(rb_h * 1.8)
        for side in [-1, 1]:
            tail_x = bx + side * int(rb_w * 0.3)
            tail_pts = [
                (tail_x, ribbon_cy + knot_r),
                (tail_x + side * 3, ribbon_cy + knot_r + tail_len // 2),
                (tail_x + side * 5, ribbon_cy + knot_r + tail_len),
            ]
            if len(tail_pts) >= 2:
                pygame.draw.lines(surf, RIBBON_MAIN, False, tail_pts, 2)
                # V자 끝
                end_x, end_y = tail_pts[-1]
                pygame.draw.line(surf, RIBBON_DARK, (end_x, end_y), (end_x - 2, end_y + 3), 2)
                pygame.draw.line(surf, RIBBON_DARK, (end_x, end_y), (end_x + 2, end_y + 3), 2)

        # ══════════════════════════════════════════
        #  14. 이마 봉제선 (더 정교한 봉제선)
        # ══════════════════════════════════════════
        stitch_y_start = head_y - int(head_r * 0.68)
        stitch_y_end = head_y - int(head_r * 0.15)
        stitch_len = stitch_y_end - stitch_y_start

        # 대시-스티치 패턴 (──·──·──)
        for i in range(0, stitch_len, 7):
            y1 = stitch_y_start + i
            y2 = min(stitch_y_start + i + 4, stitch_y_end)
            pygame.draw.line(surf, STITCH_COL, (bx - 2, y1), (bx + 2, y2), 2)
            # 바늘구멍 점
            if i % 14 == 0:
                pygame.draw.circle(surf, STITCH_DARK, (bx, y1), 1)

        # ══════════════════════════════════════════
        #  15. 몸통 양쪽 봉제선 (사이드 심)
        # ══════════════════════════════════════════
        for side in [-1, 1]:
            seam_x = bx + side * int(body_w * 0.42)
            seam_top = body_cy - int(body_h * 0.35)
            seam_bot = body_cy + int(body_h * 0.30)
            for sy in range(seam_top, seam_bot, 7):
                y1 = sy
                y2 = min(sy + 4, seam_bot)
                pygame.draw.line(surf, STITCH_COL, (seam_x, y1), (seam_x + side, y2), 1)

        return surf

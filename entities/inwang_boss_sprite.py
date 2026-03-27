# -*- coding: utf-8 -*-
"""
인왕 (금강역사) 프로시저럴 보스 스프라이트
사원 문지기 — 금강저를 든 수호신, 근육질의 금색 갑옷
- 이동 애니메이션 (좌/우/아이들)
- 히트 애니메이션
- Stage1BossSprite와 동일한 인터페이스
"""

import pygame
import math

_sin = math.sin
_cos = math.cos


class InwangBossSprite:
    """
    인왕 프로시저럴 보스 스프라이트
    금강역사 — 금색 갑옷, 금강저(vajra), 분노 표정, 근육질 체형
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
        self.hit_duration = 0.35
        self.hit_direction = 1
        self.hit_intensity = 0.0

        # 오른팔 좌표
        self._right_hand_x = 0
        self._right_hand_y = 0

        # 프레임 캐시
        self._cache_key = None
        self._cached_frame = None
        self._surface_cache = {}

    def _get_surface(self, w, h):
        """크기별 SRCALPHA Surface 캐시 재사용"""
        key = (w, h)
        if key not in self._surface_cache:
            self._surface_cache[key] = pygame.Surface((w, h), pygame.SRCALPHA)
        else:
            self._surface_cache[key].fill((0, 0, 0, 0))
        return self._surface_cache[key]

    def update(self, current_x, dt=1/60):
        """애니메이션 상태 업데이트"""
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
            self.step_phase += dt * 6.0 * max(speed_factor, 0.5)  # 느린 걸음
            self.lean = 0.0
            self.body_bob = _sin(self.step_phase * 2) * 0.06 * speed_factor
        else:
            self.step_phase *= 0.95
            self.lean = 0.0
            self.body_bob = _sin(self.time * 1.2) * 0.03  # 묵직한 호흡

        if self.is_hit:
            self.hit_timer += dt
            progress = self.hit_timer / self.hit_duration
            if progress >= 1.0:
                self.is_hit = False
                self.hit_timer = 0.0
                self.hit_intensity = 0.0
            else:
                self.hit_intensity = max(0, 1.0 - progress * progress)

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
    #  프로시저럴 렌더링 — 인왕 (금강역사)
    # ===================================================================

    def _draw_character(self, surface, cx, cy, b, w, h):
        """인왕 전체 캐릭터 렌더링"""

        lean = self.lean
        body_bob = self.body_bob
        step = self.step_phase

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

        self._draw_shadow(surface, cx, cy, b, lean_offset)
        self._draw_legs(surface, cx, cy, b, lean_offset, bob_offset, step, p)
        self._draw_skirt(surface, cx, cy, b, lean_offset, torso_y, step, p)
        self._draw_torso(surface, cx, cy, b, lean_offset, torso_y, p)
        self._draw_arms(surface, cx, cy, b, lean_offset, torso_y, step, p)
        self._draw_vajra(surface, cx, cy, b, lean_offset, torso_y, step, p)
        self._draw_neck(surface, cx, b, lean_offset, torso_y, p)
        self._draw_head(surface, cx, b, lean_offset, torso_y, p)
        self._draw_crown(surface, cx, b, lean_offset, torso_y, p)

    def _get_palette(self, flash=0.0):
        """인왕 색상 팔레트"""
        def _flash(base):
            return tuple(min(255, int(c + (255 - c) * flash)) for c in base)

        return {
            # 갑옷 (금색/황금)
            "armor": _flash((180, 150, 60)),
            "armor_light": _flash((220, 195, 80)),
            "armor_dark": _flash((140, 115, 40)),
            "armor_edge": _flash((240, 215, 100)),
            # 피부 (붉은 기운 — 분노한 수호신)
            "skin": _flash((210, 160, 130)),
            "skin_shadow": _flash((180, 130, 100)),
            "skin_highlight": _flash((235, 190, 160)),
            # 허리띠/치마
            "skirt": _flash((120, 50, 30)),
            "skirt_dark": _flash((90, 35, 20)),
            "skirt_gold": _flash((200, 170, 60)),
            # 금강저 (vajra)
            "vajra_gold": _flash((240, 210, 80)),
            "vajra_shaft": _flash((200, 175, 60)),
            "vajra_dark": _flash((160, 135, 40)),
            # 머리/왕관
            "crown": _flash((200, 170, 50)),
            "crown_jewel": _flash((180, 40, 40)),
            "hair": _flash((40, 30, 20)),
            "hair_highlight": _flash((65, 50, 35)),
            # 눈
            "eye_white": _flash((240, 240, 235)),
            "eye_iris": _flash((160, 50, 20)),   # 붉은 눈
            "eye_pupil": _flash((30, 10, 5)),
            "eyebrow": _flash((50, 35, 20)),
            # 신발
            "shoe": _flash((100, 70, 35)),
            "shoe_light": _flash((130, 95, 50)),
        }

    def _draw_shadow(self, surface, cx, cy, b, lean_offset):
        """바닥 그림자"""
        shadow_w = int(3.2 * b)  # 넓은 그림자 (근육질)
        shadow_h = int(0.7 * b)
        shadow_y = cy + int(3.2 * b)
        shadow_surf = self._get_surface(shadow_w, shadow_h)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 50), (0, 0, shadow_w, shadow_h))
        surface.blit(shadow_surf, (cx - shadow_w // 2 + lean_offset // 2, shadow_y))

    def _draw_legs(self, surface, cx, cy, b, lean_offset, bob_offset, step, p):
        """다리 (근육질 다리, 짧은 바지)"""
        leg_base_y = cy + int(2.4 * b) + bob_offset

        for side in (-1, 1):
            phase = step + (0 if side == -1 else math.pi)
            leg_swing = _sin(phase) * 0.3 * b

            leg_x = cx + int(side * 0.7 * b) + lean_offset
            leg_top = int(leg_base_y)
            leg_bottom = int(leg_base_y + 1.4 * b + leg_swing * 0.2)

            # 허벅지 (굵음)
            thigh_w = max(2, int(0.65 * b))
            pygame.draw.rect(surface, p["skin_shadow"],
                           (leg_x - thigh_w, leg_top, thigh_w * 2, int(0.7 * b)))
            # 종아리
            calf_w = max(2, int(0.5 * b))
            calf_top = leg_top + int(0.7 * b)
            pygame.draw.rect(surface, p["skin"],
                           (leg_x - calf_w, calf_top, calf_w * 2, int(0.7 * b)))

            # 신발
            shoe_y = leg_bottom
            shoe_w = max(3, int(0.7 * b))
            shoe_h = max(2, int(0.35 * b))
            pygame.draw.ellipse(surface, p["shoe"],
                              (leg_x - shoe_w // 2, shoe_y, shoe_w, shoe_h))
            pygame.draw.ellipse(surface, p["shoe_light"],
                              (leg_x - shoe_w // 3, shoe_y, shoe_w // 2, shoe_h // 2))

    def _draw_skirt(self, surface, cx, cy, b, lean_offset, torso_y, step, p):
        """전투 치마 (하의)"""
        skirt_top = torso_y + int(2.2 * b)
        skirt_bottom = cy + int(2.6 * b)
        skirt_w = int(2.2 * b)

        # 치마 본체
        points = [
            (cx - int(1.0 * b) + lean_offset, skirt_top),
            (cx + int(1.0 * b) + lean_offset, skirt_top),
            (cx + skirt_w // 2 + lean_offset, skirt_bottom),
            (cx - skirt_w // 2 + lean_offset, skirt_bottom),
        ]
        pygame.draw.polygon(surface, p["skirt"], points)

        # 금색 테두리
        border_y = skirt_top
        pygame.draw.line(surface, p["skirt_gold"],
                        (cx - int(1.0 * b) + lean_offset, border_y),
                        (cx + int(1.0 * b) + lean_offset, border_y), max(1, int(0.15 * b)))
        # 하단 테두리
        pygame.draw.line(surface, p["skirt_gold"],
                        (cx - skirt_w // 2 + lean_offset, skirt_bottom),
                        (cx + skirt_w // 2 + lean_offset, skirt_bottom), max(1, int(0.12 * b)))

    def _draw_torso(self, surface, cx, cy, b, lean_offset, torso_y, p):
        """상체 (금색 갑옷, 넓은 어깨)"""
        # 갑옷 본체 — 사다리꼴 (넓은 어깨)
        shoulder_w = int(2.4 * b)
        waist_w = int(1.8 * b)
        torso_h = int(2.2 * b)

        points = [
            (cx - shoulder_w // 2 + lean_offset, torso_y),
            (cx + shoulder_w // 2 + lean_offset, torso_y),
            (cx + waist_w // 2 + lean_offset, torso_y + torso_h),
            (cx - waist_w // 2 + lean_offset, torso_y + torso_h),
        ]
        pygame.draw.polygon(surface, p["armor"], points)

        # 갑옷 하이라이트 (가운데 세로 줄)
        center_line_x = cx + lean_offset
        pygame.draw.line(surface, p["armor_light"],
                        (center_line_x, torso_y + int(0.3 * b)),
                        (center_line_x, torso_y + torso_h - int(0.2 * b)),
                        max(1, int(0.2 * b)))

        # 어깨 장식 (어깨보호대)
        for side in (-1, 1):
            sx = cx + int(side * 1.1 * b) + lean_offset
            sy = torso_y + int(0.1 * b)
            pad_w = max(3, int(0.7 * b))
            pad_h = max(2, int(0.5 * b))
            pygame.draw.ellipse(surface, p["armor_light"],
                              (sx - pad_w // 2, sy, pad_w, pad_h))
            pygame.draw.ellipse(surface, p["armor_edge"],
                              (sx - pad_w // 2, sy, pad_w, pad_h), max(1, int(0.08 * b)))

        # 가슴 문양 (원형 금장)
        emblem_x = cx + lean_offset
        emblem_y = torso_y + int(1.0 * b)
        emblem_r = max(2, int(0.35 * b))
        pygame.draw.circle(surface, p["armor_edge"], (emblem_x, emblem_y), emblem_r)
        pygame.draw.circle(surface, p["armor_dark"], (emblem_x, emblem_y), emblem_r, max(1, int(0.06 * b)))

        # 허리띠
        belt_y = torso_y + torso_h - int(0.3 * b)
        belt_h = max(2, int(0.3 * b))
        pygame.draw.rect(surface, p["skirt_gold"],
                        (cx - waist_w // 2 + lean_offset, belt_y, waist_w, belt_h))

    def _draw_arms(self, surface, cx, cy, b, lean_offset, torso_y, step, p):
        """팔 (근육질, 맨살)"""
        for side in (-1, 1):
            shoulder_x = cx + int(side * 1.2 * b) + lean_offset
            shoulder_y = torso_y + int(0.4 * b)

            # 걷기 시 팔 흔들림
            arm_swing = _sin(step + (0 if side == -1 else math.pi)) * 0.25 * b

            # 상박 (피부)
            upper_end_x = shoulder_x + int(side * 0.3 * b)
            upper_end_y = shoulder_y + int(1.2 * b) + int(arm_swing * 0.3)
            arm_w = max(2, int(0.45 * b))
            pygame.draw.line(surface, p["skin"],
                           (shoulder_x, shoulder_y),
                           (upper_end_x, upper_end_y), arm_w)
            # 근육 하이라이트
            mid_arm_x = (shoulder_x + upper_end_x) // 2
            mid_arm_y = (shoulder_y + upper_end_y) // 2
            pygame.draw.circle(surface, p["skin_highlight"],
                             (mid_arm_x, mid_arm_y), max(1, int(0.2 * b)))

            # 하박
            lower_end_x = upper_end_x + int(side * 0.15 * b)
            lower_end_y = upper_end_y + int(1.0 * b) + int(arm_swing * 0.4)
            pygame.draw.line(surface, p["skin_shadow"],
                           (upper_end_x, upper_end_y),
                           (lower_end_x, lower_end_y), max(2, int(0.35 * b)))

            # 팔찌 (금색)
            bracelet_y = upper_end_y - int(0.1 * b)
            pygame.draw.circle(surface, p["armor_edge"],
                             (upper_end_x, bracelet_y), max(2, int(0.25 * b)), max(1, int(0.08 * b)))

            # 오른손 좌표 저장 (무기용)
            if side == 1:
                self._right_hand_x = lower_end_x
                self._right_hand_y = lower_end_y

    def _draw_vajra(self, surface, cx, cy, b, lean_offset, torso_y, step, p):
        """금강저 (vajra) — 오른손에 쥔 무기"""
        hand_x = self._right_hand_x
        hand_y = self._right_hand_y
        if hand_x == 0 and hand_y == 0:
            return

        # 금강저 길이
        vajra_len = int(1.8 * b)

        # 아이들 시 살짝 흔들림
        swing = _sin(self.time * 2.5) * 0.15

        # 시작점 (손), 끝점 (아래)
        end_x = hand_x + int(_sin(swing) * vajra_len * 0.3)
        end_y = hand_y + int(vajra_len * 0.8)

        # 자루
        shaft_w = max(2, int(0.18 * b))
        pygame.draw.line(surface, p["vajra_shaft"],
                        (hand_x, hand_y), (end_x, end_y), shaft_w)

        # 상단 장식 (다이아몬드 형태)
        top_size = max(2, int(0.3 * b))
        top_points = [
            (hand_x, hand_y - top_size),
            (hand_x + top_size // 2, hand_y),
            (hand_x, hand_y + top_size // 2),
            (hand_x - top_size // 2, hand_y),
        ]
        pygame.draw.polygon(surface, p["vajra_gold"], top_points)

        # 하단 장식
        bot_size = max(2, int(0.25 * b))
        bot_points = [
            (end_x, end_y - bot_size // 2),
            (end_x + bot_size // 2, end_y),
            (end_x, end_y + bot_size),
            (end_x - bot_size // 2, end_y),
        ]
        pygame.draw.polygon(surface, p["vajra_gold"], bot_points)

        # 중앙 보석
        mid_x = (hand_x + end_x) // 2
        mid_y = (hand_y + end_y) // 2
        pygame.draw.circle(surface, p["crown_jewel"],
                         (mid_x, mid_y), max(1, int(0.12 * b)))

    def _draw_neck(self, surface, cx, b, lean_offset, torso_y, p):
        """목 (굵은 목)"""
        neck_w = max(3, int(0.5 * b))
        neck_h = max(2, int(0.4 * b))
        neck_x = cx + lean_offset - neck_w // 2
        neck_y = torso_y - neck_h + int(0.1 * b)
        pygame.draw.rect(surface, p["skin"], (neck_x, neck_y, neck_w, neck_h))
        # 목 근육 라인
        pygame.draw.line(surface, p["skin_shadow"],
                        (neck_x + 1, neck_y), (neck_x + 1, neck_y + neck_h), 1)

    def _draw_head(self, surface, cx, b, lean_offset, torso_y, p):
        """머리 (분노한 얼굴)"""
        head_cx = cx + lean_offset
        head_cy = torso_y - int(0.8 * b)
        head_r = max(4, int(0.75 * b))

        # 머리 형태
        pygame.draw.circle(surface, p["skin"], (head_cx, head_cy), head_r)
        pygame.draw.circle(surface, p["skin_shadow"], (head_cx, head_cy), head_r, max(1, int(0.05 * b)))

        # 머리카락 (위쪽 반원)
        hair_rect = (head_cx - head_r, head_cy - head_r, head_r * 2, head_r)
        pygame.draw.ellipse(surface, p["hair"], hair_rect)

        # 눈 (분노 — 찡그린 표정)
        eye_y = head_cy - int(0.05 * b)
        for side in (-1, 1):
            ex = head_cx + int(side * 0.3 * b)
            # 흰자
            ew = max(2, int(0.25 * b))
            eh = max(1, int(0.15 * b))
            pygame.draw.ellipse(surface, p["eye_white"],
                              (ex - ew, eye_y - eh, ew * 2, eh * 2))
            # 홍채 (붉은색)
            ir = max(1, int(0.1 * b))
            pygame.draw.circle(surface, p["eye_iris"], (ex, eye_y), ir)
            # 동공
            pr = max(1, int(0.05 * b))
            pygame.draw.circle(surface, p["eye_pupil"], (ex, eye_y), pr)
            # 눈썹 (찡그림 — 안쪽이 올라감)
            brow_inner_x = head_cx + int(side * 0.12 * b)
            brow_outer_x = head_cx + int(side * 0.48 * b)
            brow_inner_y = eye_y - int(0.2 * b)
            brow_outer_y = eye_y - int(0.3 * b)
            pygame.draw.line(surface, p["eyebrow"],
                           (brow_inner_x, brow_inner_y),
                           (brow_outer_x, brow_outer_y), max(1, int(0.1 * b)))

        # 코
        nose_x = head_cx
        nose_y = head_cy + int(0.15 * b)
        pygame.draw.line(surface, p["skin_shadow"],
                        (nose_x, nose_y - int(0.1 * b)),
                        (nose_x, nose_y + int(0.1 * b)), max(1, int(0.06 * b)))

        # 입 (이를 드러낸 표정)
        mouth_y = head_cy + int(0.35 * b)
        mouth_w = int(0.35 * b)
        pygame.draw.line(surface, p["skin_shadow"],
                        (head_cx - mouth_w, mouth_y),
                        (head_cx + mouth_w, mouth_y), max(1, int(0.08 * b)))
        # 이빨
        for i in range(-2, 3):
            tooth_x = head_cx + int(i * 0.12 * b)
            pygame.draw.rect(surface, (240, 240, 230),
                           (tooth_x - 1, mouth_y - 1, max(1, int(0.08 * b)), max(1, int(0.06 * b))))

    def _draw_crown(self, surface, cx, b, lean_offset, torso_y, p):
        """보관 (수호신 왕관)"""
        head_cx = cx + lean_offset
        head_top_y = torso_y - int(1.55 * b)

        crown_w = int(1.2 * b)
        crown_h = int(0.5 * b)
        crown_base_y = head_top_y

        # 왕관 본체
        base_rect = (head_cx - crown_w // 2, crown_base_y, crown_w, crown_h)
        pygame.draw.rect(surface, p["crown"], base_rect)
        pygame.draw.rect(surface, p["armor_dark"], base_rect, max(1, int(0.06 * b)))

        # 왕관 꼭지 (삼각형 3개)
        spike_count = 3
        for i in range(spike_count):
            sx = head_cx - crown_w // 2 + int((i + 0.5) * crown_w / spike_count)
            spike_h = int(0.35 * b)
            spike_points = [
                (sx - int(0.12 * b), crown_base_y),
                (sx + int(0.12 * b), crown_base_y),
                (sx, crown_base_y - spike_h),
            ]
            pygame.draw.polygon(surface, p["crown"], spike_points)

        # 중앙 보석
        jewel_x = head_cx
        jewel_y = crown_base_y + crown_h // 2
        jewel_r = max(1, int(0.12 * b))
        pygame.draw.circle(surface, p["crown_jewel"], (jewel_x, jewel_y), jewel_r)
        pygame.draw.circle(surface, (255, 200, 200), (jewel_x - 1, jewel_y - 1), max(1, jewel_r // 2))


# ===================================================================
#  싱글톤 패턴 (Stage1BossSprite와 동일)
# ===================================================================

_inwang_instance = None


def init_inwang_boss_sprite():
    """인왕 보스 스프라이트 초기화"""
    global _inwang_instance
    try:
        _inwang_instance = InwangBossSprite()
        print("[Sprite] 인왕 프로시저럴 스프라이트 초기화 완료")
        return _inwang_instance
    except Exception as e:
        print(f"[Sprite] 인왕 스프라이트 초기화 실패: {e}")
        _inwang_instance = None
        return None


def get_inwang_boss_sprite():
    """인왕 보스 스프라이트 싱글톤 반환"""
    global _inwang_instance
    if _inwang_instance is None:
        init_inwang_boss_sprite()
    return _inwang_instance


def reset_inwang_boss_sprite():
    """인왕 보스 스프라이트 리셋"""
    global _inwang_instance
    if _inwang_instance:
        _inwang_instance.direction = 0
        _inwang_instance.is_hit = False
        _inwang_instance.hit_timer = 0.0
        _inwang_instance.time = 0.0
        _inwang_instance.step_phase = 0.0
        _inwang_instance.lean = 0.0
        _inwang_instance.body_bob = 0.0

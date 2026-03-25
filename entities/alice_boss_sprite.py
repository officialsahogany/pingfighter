"""
Alice Boss Sprite — 거울 나라의 앨리스 (Twisted Wonderland Girl)

- 파란 드레스 + 하얀 에이프런
- 금발 긴 머리 (리본 달린)
- 손에 든 거울 (반짝이는 애니메이션)
- 이동 시 드레스 흔들림 + 머리카락 나부낌
- 3x SSAA 슈퍼샘플링
"""

import pygame
import math
import random

_sin = math.sin
_cos = math.cos
_pi = math.pi
_tau = math.pi * 2

# SSAA 배율
_SSAA = 3


class AliceBossSprite:
    """거울 나라의 앨리스 보스 스프라이트"""

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
        self.move_dir = 0
        self.face_dir = 1.0
        self.face_dir_target = 0.0

        # 드레스 흔들림
        self.dress_sway = 0.0
        self.dress_sway_vel = 0.0

        # 머리카락 나부낌
        self.hair_sway = 0.0

        # 거울 반짝임
        self.mirror_sparkle = 0.0

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

    def update(self, boss_x, dt):
        """매 프레임 애니메이션 상태 업데이트"""
        self.time += dt

        # 이동 속도 추정
        if self.prev_x is not None:
            raw_vel = (boss_x - self.prev_x) / max(dt, 0.001)
            self.velocity += (raw_vel - self.velocity) * min(dt * 8, 1.0)
        self.prev_x = boss_x

        speed = abs(self.velocity)
        moving = speed > 5.0

        # 이동 방향
        if self.velocity > 10:
            self.move_dir = 1
            self.face_dir_target = 1.0
        elif self.velocity < -10:
            self.move_dir = -1
            self.face_dir_target = -1.0
        elif speed < 3:
            self.move_dir = 0

        # 얼굴 방향 부드러운 전환
        self.face_dir += (self.face_dir_target - self.face_dir) * min(dt * 6, 1.0)

        # 기울기 (관성)
        target_lean = self.velocity * 0.003
        target_lean = max(-0.15, min(0.15, target_lean))
        spring_k = 30.0
        damp = 8.0
        self.lean_velocity += (target_lean - self.lean) * spring_k * dt - self.lean_velocity * damp * dt
        self.lean += self.lean_velocity * dt

        # 걸음 위상
        if moving:
            self.step_phase += speed * dt * 0.025
        else:
            self.step_phase *= 0.9

        # 상체 흔들림 (미세하게)
        self.body_bob = _sin(self.step_phase * 2) * (0.3 if moving else 0.1)
        self.body_roll = _sin(self.step_phase) * (0.02 if moving else 0.005)

        # 팔 흔들림 (미세하게)
        self.arm_swing = _sin(self.step_phase * 2) * (0.15 if moving else 0.03)

        # 머리 기울기 (미세하게)
        self.head_tilt = _sin(self.time * 1.5) * 0.015 + self.lean * 0.15

        # 드레스 흔들림 (클램프)
        dress_target = max(-0.15, min(0.15, self.velocity * 0.002))
        self.dress_sway_vel += (dress_target - self.dress_sway) * 20 * dt - self.dress_sway_vel * 6 * dt
        self.dress_sway += self.dress_sway_vel * dt
        self.dress_sway = max(-0.2, min(0.2, self.dress_sway))

        # 머리카락 나부낌 (클램프)
        self.hair_sway = _sin(self.time * 2.5) * 0.04 + max(-0.06, min(0.06, self.velocity * 0.001))

        # 거울 반짝임
        self.mirror_sparkle = (_sin(self.time * 3.0) + 1.0) * 0.5

    def draw(self, surface, x, y, w, h):
        """프로시저럴 앨리스 렌더링 (SSAA)"""
        sw = w * _SSAA
        sh = h * _SSAA
        sf = self._get_surface(sw, sh)

        cx = sw // 2
        cy = sh // 2

        # 색상 정의
        dress_blue = (100, 150, 230)
        dress_dark = (70, 110, 190)
        apron_white = (240, 240, 250)
        skin = (255, 220, 195)
        skin_shadow = (230, 190, 165)
        hair_gold = (240, 200, 100)
        hair_dark = (200, 160, 60)
        ribbon_blue = (80, 130, 220)
        eye_blue = (60, 100, 200)
        black = (30, 25, 35)
        white = (255, 255, 255)
        pink = (255, 180, 190)
        mirror_frame = (180, 150, 100)
        mirror_glass = (200, 220, 255)

        # 스케일 팩터
        s = min(sw, sh) / 200.0

        # body bob 적용 (미세한 움직임)
        bob_y = int(self.body_bob * s * 1.5)

        # === 드레스 (하반신) ===
        dress_top_y = cy + int(8 * s) + bob_y
        dress_bot_y = cy + int(50 * s) + bob_y
        dress_w = int(40 * s)
        sway_px = int(self.dress_sway * s * 10)

        # 드레스 A라인 실루엣
        dress_points = [
            (cx - int(18 * s) + sway_px // 2, dress_top_y),
            (cx + int(18 * s) + sway_px // 2, dress_top_y),
            (cx + dress_w + sway_px, dress_bot_y),
            (cx - dress_w + sway_px, dress_bot_y),
        ]
        pygame.draw.polygon(sf, dress_blue, dress_points)
        # 드레스 음영
        shade_points = [
            (cx - int(10 * s) + sway_px // 2, dress_top_y + int(5 * s)),
            (cx + sway_px // 2, dress_top_y + int(3 * s)),
            (cx - int(5 * s) + sway_px, dress_bot_y),
            (cx - int(25 * s) + sway_px, dress_bot_y),
        ]
        pygame.draw.polygon(sf, dress_dark, shade_points)

        # === 에이프런 ===
        apron_points = [
            (cx - int(14 * s) + sway_px // 2, dress_top_y + int(2 * s)),
            (cx + int(14 * s) + sway_px // 2, dress_top_y + int(2 * s)),
            (cx + int(22 * s) + sway_px, dress_bot_y - int(3 * s)),
            (cx - int(22 * s) + sway_px, dress_bot_y - int(3 * s)),
        ]
        pygame.draw.polygon(sf, apron_white, apron_points)
        # 에이프런 레이스 (하단)
        for i in range(6):
            lx = cx - int(20 * s) + int(i * 8 * s) + sway_px
            ly = dress_bot_y - int(4 * s)
            pygame.draw.arc(sf, (220, 220, 235),
                            (lx, ly, int(8 * s), int(6 * s)),
                            _pi, _tau, max(1, int(s)))

        # === 다리 ===
        leg_y = dress_bot_y - int(2 * s)
        # 왼다리
        pygame.draw.ellipse(sf, skin_shadow,
                            (cx - int(12 * s) + sway_px, leg_y,
                             int(10 * s), int(14 * s)))
        # 오른다리
        pygame.draw.ellipse(sf, skin_shadow,
                            (cx + int(2 * s) + sway_px, leg_y,
                             int(10 * s), int(14 * s)))
        # 검은 신발
        pygame.draw.ellipse(sf, black,
                            (cx - int(14 * s) + sway_px, leg_y + int(10 * s),
                             int(12 * s), int(6 * s)))
        pygame.draw.ellipse(sf, black,
                            (cx + int(2 * s) + sway_px, leg_y + int(10 * s),
                             int(12 * s), int(6 * s)))

        # === 상체 ===
        body_top_y = cy - int(14 * s) + bob_y
        body_bot_y = dress_top_y + int(5 * s)
        pygame.draw.ellipse(sf, dress_blue,
                            (cx - int(18 * s), body_top_y,
                             int(36 * s), body_bot_y - body_top_y))
        # 에이프런 상단 (가슴받이)
        pygame.draw.rect(sf, apron_white,
                         (cx - int(10 * s), body_top_y + int(4 * s),
                          int(20 * s), int(16 * s)))

        # === 팔 ===
        arm_angle_l = self.arm_swing * 0.2
        arm_angle_r = -self.arm_swing * 0.2

        # 왼팔
        la_x = cx - int(22 * s)
        la_y = body_top_y + int(6 * s)
        la_h = int(28 * s)
        la_w = int(10 * s)
        # 드레스 소매
        pygame.draw.ellipse(sf, dress_blue,
                            (la_x, la_y + int(arm_angle_l * 10),
                             la_w, int(14 * s)))
        # 팔 (피부)
        pygame.draw.ellipse(sf, skin,
                            (la_x + int(1 * s), la_y + int(12 * s) + int(arm_angle_l * 10),
                             int(8 * s), int(14 * s)))

        # 오른팔 (거울 든 팔)
        ra_x = cx + int(12 * s)
        ra_y = body_top_y + int(6 * s)
        pygame.draw.ellipse(sf, dress_blue,
                            (ra_x, ra_y + int(arm_angle_r * 10),
                             la_w, int(14 * s)))
        pygame.draw.ellipse(sf, skin,
                            (ra_x + int(1 * s), ra_y + int(12 * s) + int(arm_angle_r * 10),
                             int(8 * s), int(14 * s)))

        # === 거울 (오른손에) ===
        mirror_x = ra_x + int(4 * s)
        mirror_y = ra_y + int(24 * s) + int(arm_angle_r * 10)
        mr = int(8 * s)
        # 거울 프레임
        pygame.draw.circle(sf, mirror_frame, (mirror_x, mirror_y), mr + int(2 * s))
        # 거울 유리
        pygame.draw.circle(sf, mirror_glass, (mirror_x, mirror_y), mr)
        # 반짝임 효과
        sparkle_alpha = int(100 + 155 * self.mirror_sparkle)
        sparkle_surf = pygame.Surface((mr * 2, mr * 2), pygame.SRCALPHA)
        pygame.draw.circle(sparkle_surf, (255, 255, 255, sparkle_alpha),
                           (mr, mr), mr // 2)
        sf.blit(sparkle_surf, (mirror_x - mr, mirror_y - mr))
        # 거울 손잡이
        pygame.draw.rect(sf, mirror_frame,
                         (mirror_x - int(2 * s), mirror_y + mr,
                          int(4 * s), int(8 * s)))

        # === 머리 ===
        head_cx = cx + int(self.head_tilt * s * 10)
        head_cy = cy - int(32 * s) + bob_y
        head_r = int(18 * s)

        # 뒷머리카락 (긴 금발)
        hair_sway_px = int(self.hair_sway * s * 15)
        hair_points_back = [
            (head_cx - int(20 * s), head_cy - int(5 * s)),
            (head_cx + int(20 * s), head_cy - int(5 * s)),
            (head_cx + int(22 * s) + hair_sway_px, cy + int(15 * s) + bob_y),
            (head_cx + int(8 * s) + hair_sway_px, cy + int(20 * s) + bob_y),
            (head_cx - int(8 * s) + hair_sway_px, cy + int(20 * s) + bob_y),
            (head_cx - int(22 * s) + hair_sway_px, cy + int(15 * s) + bob_y),
        ]
        pygame.draw.polygon(sf, hair_gold, hair_points_back)
        # 머리카락 음영
        for i in range(3):
            hx = head_cx - int(12 * s) + int(i * 10 * s) + hair_sway_px // 2
            pygame.draw.line(sf, hair_dark,
                             (hx, head_cy + int(5 * s)),
                             (hx + hair_sway_px, cy + int(18 * s) + bob_y),
                             max(1, int(s)))

        # 얼굴 (원)
        pygame.draw.circle(sf, skin, (head_cx, head_cy), head_r)
        # 얼굴 음영
        pygame.draw.circle(sf, skin_shadow, (head_cx + int(3 * s), head_cy + int(2 * s)),
                           head_r - int(3 * s))
        pygame.draw.circle(sf, skin, (head_cx, head_cy), head_r - int(2 * s))

        # 앞머리 (뱅)
        bang_points = [
            (head_cx - int(18 * s), head_cy - int(2 * s)),
            (head_cx - int(14 * s), head_cy - int(16 * s)),
            (head_cx - int(5 * s), head_cy - int(18 * s)),
            (head_cx, head_cy - int(19 * s)),
            (head_cx + int(5 * s), head_cy - int(18 * s)),
            (head_cx + int(14 * s), head_cy - int(16 * s)),
            (head_cx + int(18 * s), head_cy - int(2 * s)),
            (head_cx + int(10 * s), head_cy - int(6 * s)),
            (head_cx, head_cy - int(8 * s)),
            (head_cx - int(10 * s), head_cy - int(6 * s)),
        ]
        pygame.draw.polygon(sf, hair_gold, bang_points)

        # 눈 (큰 파란 눈)
        eye_y = head_cy + int(1 * s)
        for side in [-1, 1]:
            ex = head_cx + side * int(7 * s)
            # 흰자
            pygame.draw.ellipse(sf, white,
                                (ex - int(5 * s), eye_y - int(4 * s),
                                 int(10 * s), int(8 * s)))
            # 홍채
            pygame.draw.circle(sf, eye_blue, (ex, eye_y), int(3 * s))
            # 동공
            pygame.draw.circle(sf, black, (ex, eye_y), int(1.5 * s))
            # 하이라이트
            pygame.draw.circle(sf, white, (ex - int(1 * s), eye_y - int(1 * s)), int(1 * s))

        # 볼 홍조
        blush_s = pygame.Surface((int(10 * s), int(5 * s)), pygame.SRCALPHA)
        pygame.draw.ellipse(blush_s, (*pink, 90), (0, 0, int(10 * s), int(5 * s)))
        sf.blit(blush_s, (head_cx - int(15 * s), eye_y + int(3 * s)))
        sf.blit(blush_s, (head_cx + int(5 * s), eye_y + int(3 * s)))

        # 입 (작은 미소)
        mouth_y = head_cy + int(8 * s)
        pygame.draw.arc(sf, (200, 100, 100),
                        (head_cx - int(4 * s), mouth_y - int(2 * s),
                         int(8 * s), int(5 * s)),
                        _pi, _tau, max(1, int(1.5 * s)))

        # === 리본 (머리 위) ===
        ribbon_cx = head_cx + int(12 * s)
        ribbon_cy = head_cy - int(16 * s)
        # 리본 좌우 날개
        rb_size = int(7 * s)
        pygame.draw.polygon(sf, ribbon_blue, [
            (ribbon_cx, ribbon_cy),
            (ribbon_cx - rb_size, ribbon_cy - int(5 * s)),
            (ribbon_cx - int(3 * s), ribbon_cy),
            (ribbon_cx - rb_size, ribbon_cy + int(5 * s)),
        ])
        pygame.draw.polygon(sf, ribbon_blue, [
            (ribbon_cx, ribbon_cy),
            (ribbon_cx + rb_size, ribbon_cy - int(5 * s)),
            (ribbon_cx + int(3 * s), ribbon_cy),
            (ribbon_cx + rb_size, ribbon_cy + int(5 * s)),
        ])
        # 리본 중심
        pygame.draw.circle(sf, (60, 100, 200), (ribbon_cx, ribbon_cy), int(2 * s))

        # === SSAA 다운스케일 ===
        result = pygame.transform.smoothscale(sf, (w, h))
        surface.blit(result, (x, y))


# 싱글톤
_alice_sprite_instance = None


def get_alice_sprite():
    """앨리스 보스 스프라이트 싱글톤 반환"""
    global _alice_sprite_instance
    if _alice_sprite_instance is None:
        _alice_sprite_instance = AliceBossSprite()
    return _alice_sprite_instance


def init_alice_boss_sprite():
    """앨리스 보스 스프라이트 초기화 (재생성)"""
    global _alice_sprite_instance
    _alice_sprite_instance = AliceBossSprite()
    return _alice_sprite_instance

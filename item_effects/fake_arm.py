"""
훼이크암 (fake_arm) 패시브 아이템 효과.

다루기 어려운 교란형 의수 - 플레이어 패들이 공을 칠 때 일정 확률로
일반 반사각이 아니라 제한된 "훼이크" 각도 중 하나를 골라 공을 발사한다.
발동에 성공하면 같은 히트에 추가 획득 게이지(롤옵션)를 보상으로 쌓는다.

사용:
    from item_effects.fake_arm import (
        activate_fake_arm,
        deactivate_fake_arm,
        try_apply_fake_angle,
        configure_fake_arm,
        consume_pending_gauge_bonus_pct,
        reset_all,
    )

    # 활성화 / 비활성화
    activate_fake_arm()
    deactivate_fake_arm()

    # 패들 충돌 직후 (calculate_bounce 적용 후) 호출하면
    # 일정 확률로 ball_vel 을 in-place 로 바꿔 "훼이크 각도" 발사를 만든다.
    triggered = try_apply_fake_angle(ball_vel)

    # 게이지 충전 블록에서 같은 프레임 내에 대기 중인 보너스 %를 소비
    bonus_pct = consume_pending_gauge_bonus_pct()
"""

from __future__ import annotations

import math
import os
import random
from typing import List, Optional

import pygame


# 훼이크 각도 후보 (수직 위쪽을 0도로 보고, 좌(-) / 우(+) 방향).
# 자연 반사 결과와 명백히 다른 각도여야 "속았다" 라는 인상을 주므로
# 너무 약한 각은 피하고, 너무 가파른 각은 게임을 망치지 않도록 제한한다.
_FAKE_ANGLES_DEG: tuple = (-65, -55, -45, -30, 30, 45, 55, 65)

# 자연 반사 각도와 너무 가까우면 훼이크 효과가 안 보이므로
# "최소 변위(도)" 미만인 후보는 제외한다.
_MIN_DEVIATION_DEG = 22.0

# 발동 가시 이펙트 지속 시간 (프레임). 0.5초 = 60 FPS 기준 30프레임.
_FLASH_DURATION_FRAMES = 30

# 발동 시 공속 보너스 배율 — "훅 들어오는 한 방" 감을 만드는 고정값.
# 발동률이 8~15%로 드문 편이어서 고정 보너스로 충분.
_SPEED_BOOST_MULT = 1.12

# 발동 후 "휘어지는 커브" — 매 프레임 vx 에 이 가속도를 더한다.
# 지속 프레임 * 가속도 = 총 vx 변화량(=최대 +/-3.0). 공속 10 기준 30% 수준.
_CURVE_DURATION_FRAMES = 30
_CURVE_ACCEL_PX_PER_FRAME = 0.10


class FakeArm:
    """훼이크암 싱글톤 상태 컨테이너."""

    def __init__(self) -> None:
        self.active: bool = False
        # 발동 확률 (0.0 ~ 1.0). 기본값은 PASSIVE_OPTION_RANGES 의 최저값과 일치.
        self.trigger_chance: float = 0.08
        # 강화 보너스 (%). 발동확률에 곱해 적용한다.
        self.enhancement_bonus_pct: float = 0.0
        # 발동 시 추가로 얻는 게이지 보너스 비율 (%). PASSIVE_OPTION_RANGES 최저값과 일치.
        self.gauge_bonus_pct: float = 70.0
        # 직전 발동에서 대기 중인 게이지 보너스 % (같은 프레임 내 소비 대상).
        self.pending_gauge_bonus_pct: float = 0.0
        # 발동 가시 이펙트 상태 (가장 최근 발동 위치 + 카운트다운)
        self.flash_timer: int = 0
        self.flash_x: float = 0.0
        self.flash_y: float = 0.0
        # 커브 상태 (발동 후 매 프레임 vx 에 가속도 누적)
        self.curve_timer: int = 0
        self.curve_accel_x: float = 0.0
        self.debug: bool = os.environ.get("DEBUG_FAKE_ARM", "0") == "1"

    # ── 활성화 / 비활성화 ──
    def activate(self) -> None:
        self.active = True
        if self.debug:
            print(
                f"[FAKE_ARM] activate chance={self.effective_chance() * 100:.1f}%"
            )

    def deactivate(self) -> None:
        self.active = False
        self.flash_timer = 0
        self.curve_timer = 0
        self.curve_accel_x = 0.0
        self.pending_gauge_bonus_pct = 0.0

    # ── 설정 ──
    def set_trigger_chance(self, chance_pct: float) -> None:
        self.trigger_chance = max(0.0, min(1.0, chance_pct / 100.0))
        if self.debug:
            print(
                f"[FAKE_ARM] set chance={self.effective_chance() * 100:.1f}%"
            )

    def set_enhancement_bonus(self, pct: float) -> None:
        self.enhancement_bonus_pct = max(0.0, float(pct))

    def set_gauge_bonus_pct(self, pct: float) -> None:
        self.gauge_bonus_pct = max(0.0, float(pct))

    def effective_chance(self) -> float:
        boosted = self.trigger_chance * (1.0 + self.enhancement_bonus_pct / 100.0)
        return max(0.0, min(1.0, boosted))

    def consume_pending_gauge_bonus_pct(self) -> float:
        """대기 중인 추가 획득 게이지 % 를 반환하고 0 으로 초기화한다."""
        pending = self.pending_gauge_bonus_pct
        self.pending_gauge_bonus_pct = 0.0
        return pending

    # ── 핵심 동작 ──
    def try_apply_fake_angle(self, ball_vel: List[float],
                             paddle_rect: Optional[pygame.Rect] = None) -> bool:
        """패들 반사 직후의 ball_vel 을 in-place 로 훼이크 각도로 바꾼다.

        Args:
            ball_vel: 길이 2 의 리스트 [vx, vy]. 패들 반사가 끝난 직후 상태.
            paddle_rect: 발동 가시 이펙트를 띄울 위치 (보통 PLAYER 패들).
                         None 이면 이펙트 없이 반사각만 바꾼다.

        Returns:
            True  = 훼이크 발동, ball_vel 갱신됨
            False = 발동 안 함, ball_vel 그대로
        """
        if not self.active:
            return False
        if not isinstance(ball_vel, list) or len(ball_vel) < 2:
            return False

        speed = math.hypot(ball_vel[0], ball_vel[1])
        if speed < 0.5:
            return False

        if random.random() >= self.effective_chance():
            return False

        # 자연 반사 각도(위쪽 기준, 도 단위)
        natural_deg = math.degrees(math.atan2(ball_vel[0], -ball_vel[1]))

        # 자연 반사와 충분히 다른 후보만 허용
        candidates = [
            deg for deg in _FAKE_ANGLES_DEG
            if abs(deg - natural_deg) >= _MIN_DEVIATION_DEG
        ]
        if not candidates:
            candidates = list(_FAKE_ANGLES_DEG)

        chosen_deg = random.choice(candidates)
        rad = math.radians(chosen_deg)

        # 훼이크 각도 + 공속 보너스 (발동률이 낮으므로 임팩트를 고정 보너스로 보완)
        boosted = speed * _SPEED_BOOST_MULT
        ball_vel[0] = math.sin(rad) * boosted
        ball_vel[1] = -abs(math.cos(rad) * boosted)

        # 발동 가시 이펙트 시작 (0.5초 번쩍)
        if paddle_rect is not None:
            self.flash_x = float(paddle_rect.centerx)
            self.flash_y = float(paddle_rect.centery)
        self.flash_timer = _FLASH_DURATION_FRAMES

        # 커브 시작 — 공이 날아가는 동안 슬쩍 휘어지게 vx 가속도 누적
        # 방향은 랜덤 (훼이크 각도와 같은 쪽이든 반대쪽이든 상대를 한 번 더 속임)
        self.curve_timer = _CURVE_DURATION_FRAMES
        self.curve_accel_x = _CURVE_ACCEL_PX_PER_FRAME * random.choice((-1, 1))

        # 발동 보상 — 같은 프레임의 게이지 충전 블록에서 소비될 추가 획득 게이지 %
        self.pending_gauge_bonus_pct = self.gauge_bonus_pct

        if self.debug:
            print(
                f"[FAKE_ARM] FAKE! natural={natural_deg:+.1f}deg "
                f"-> fake={chosen_deg:+d}deg, speed={speed:.1f}->{boosted:.1f}, "
                f"curve_ax={self.curve_accel_x:+.2f}, "
                f"gauge_bonus=+{self.gauge_bonus_pct:.0f}%"
            )
        return True

    def apply_curve(self, ball_vel: List[float]) -> None:
        """매 프레임 호출 — 커브 타이머가 살아있으면 vx 에 가속도를 더한다."""
        if self.curve_timer <= 0:
            return
        if not isinstance(ball_vel, list) or len(ball_vel) < 2:
            return
        # 공이 위로 향하는 동안만 커브 적용 (플레이어→보스 구간).
        # 보스에 반사돼 vy 가 양수로 돌아서면 더 이상 휘게 하지 않음.
        if ball_vel[1] < 0:
            ball_vel[0] += self.curve_accel_x
        self.curve_timer -= 1

    def update(self) -> None:
        """매 프레임 호출되어 가시 이펙트 카운트다운을 진행."""
        if self.flash_timer > 0:
            self.flash_timer -= 1
        # 게이지 충전 블록이 같은 프레임에서 대기 값을 소비하지 못했을 경우,
        # 다음 프레임으로 이월되지 않도록 안전하게 초기화한다.
        if self.pending_gauge_bonus_pct > 0.0:
            self.pending_gauge_bonus_pct = 0.0

    def draw_effects(self, screen: pygame.Surface) -> None:
        """발동 가시 이펙트 (마젠타 글리치 번쩍) 를 렌더링."""
        if self.flash_timer <= 0:
            return

        # 0.0 (방금 발동) -> 1.0 (사라지기 직전)
        progress = 1.0 - (self.flash_timer / _FLASH_DURATION_FRAMES)
        # ease-out: 초반에 강하고 빠르게, 후반에 천천히 사라짐
        ease = 1.0 - (1.0 - progress) ** 2
        fade = max(0.0, 1.0 - progress)

        cx = int(self.flash_x)
        cy = int(self.flash_y)

        # 확장 링 (패들 주위로 빠르게 퍼짐)
        max_radius = 110
        ring_radius = int(12 + max_radius * ease)
        ring_thickness = max(2, int(7 * fade))

        # 그릴 영역 surface (BLEND_RGBA_ADD 용)
        size = max_radius * 2 + 24
        surf = pygame.Surface((size, size), pygame.SRCALPHA)
        scx, scy = size // 2, size // 2

        # 외곽 글로우 링 (반투명 큰 후광)
        glow_alpha = max(0, int(120 * fade))
        glow_radius = int(16 + (max_radius + 14) * ease)
        pygame.draw.circle(
            surf, (180, 60, 220, glow_alpha),
            (scx, scy), glow_radius, max(2, ring_thickness + 4),
        )

        # 메인 마젠타 링 (선명한 글리치 광채)
        ring_alpha = max(0, int(255 * fade))
        pygame.draw.circle(
            surf, (230, 90, 240, ring_alpha),
            (scx, scy), ring_radius, ring_thickness,
        )
        # 보조 시안 링 (글리치 색차이 — 약간 안쪽)
        cyan_alpha = max(0, int(180 * fade))
        pygame.draw.circle(
            surf, (90, 220, 255, cyan_alpha),
            (scx, scy), max(4, ring_radius - 6), max(1, ring_thickness - 2),
        )

        # 내부 핫 코어 (밝은 화이트-마젠타 플래시)
        core_radius = max(3, int(22 * fade))
        pygame.draw.circle(
            surf, (255, 220, 255, min(255, ring_alpha + 30)),
            (scx, scy), core_radius,
        )
        # 코어 중심 화이트 점 (강한 번쩍)
        white_radius = max(2, int(10 * fade))
        pygame.draw.circle(
            surf, (255, 255, 255, min(255, int(255 * fade))),
            (scx, scy), white_radius,
        )

        # 방사형 글리치 스파이크 (8방향 짧은 선)
        spike_alpha = max(0, int(220 * fade))
        spike_inner = ring_radius - 4
        spike_outer = ring_radius + int(16 * fade)
        for i in range(8):
            ang = i * (math.pi / 4) + ease * 0.4  # 살짝 회전감
            sx = scx + int(math.cos(ang) * spike_inner)
            sy = scy + int(math.sin(ang) * spike_inner)
            ex = scx + int(math.cos(ang) * spike_outer)
            ey = scy + int(math.sin(ang) * spike_outer)
            pygame.draw.line(
                surf, (240, 120, 250, spike_alpha),
                (sx, sy), (ex, ey), 2,
            )

        # 글리치 잔상 라인 (수평으로 튕긴 듯한 짧은 선)
        glitch_alpha = max(0, int(220 * fade))
        for offset in (-18, -10, -4, 4, 10, 18):
            line_len = int(40 + 30 * ease)
            pygame.draw.line(
                surf, (220, 90, 230, glitch_alpha),
                (scx - line_len, scy + offset),
                (scx + line_len, scy + offset), 1,
            )

        screen.blit(
            surf, (cx - scx, cy - scy),
            special_flags=pygame.BLEND_RGBA_ADD,
        )

    def reset(self) -> None:
        self.active = False
        self.trigger_chance = 0.08
        self.enhancement_bonus_pct = 0.0
        self.gauge_bonus_pct = 70.0
        self.pending_gauge_bonus_pct = 0.0
        self.flash_timer = 0
        self.curve_timer = 0
        self.curve_accel_x = 0.0


_instance: Optional[FakeArm] = None


def get_fake_arm_instance() -> FakeArm:
    global _instance
    if _instance is None:
        _instance = FakeArm()
    return _instance


def activate_fake_arm() -> None:
    get_fake_arm_instance().activate()


def deactivate_fake_arm() -> None:
    get_fake_arm_instance().deactivate()


def configure_fake_arm(chance_pct: Optional[float] = None) -> None:
    """롤 옵션 / 밸런스 값을 인스턴스에 반영."""
    inst = get_fake_arm_instance()
    if chance_pct is not None:
        inst.set_trigger_chance(chance_pct)


def set_trigger_chance(chance_pct: float) -> None:
    get_fake_arm_instance().set_trigger_chance(chance_pct)


def set_enhancement_bonus(pct: float) -> None:
    get_fake_arm_instance().set_enhancement_bonus(pct)


def set_gauge_bonus_pct(pct: float) -> None:
    get_fake_arm_instance().set_gauge_bonus_pct(pct)


def consume_pending_gauge_bonus_pct() -> float:
    return get_fake_arm_instance().consume_pending_gauge_bonus_pct()


def try_apply_fake_angle(ball_vel: List[float],
                         paddle_rect: Optional[pygame.Rect] = None) -> bool:
    return get_fake_arm_instance().try_apply_fake_angle(ball_vel, paddle_rect)


def update_fake_arm() -> None:
    get_fake_arm_instance().update()


def apply_fake_arm_curve(ball_vel: List[float]) -> None:
    get_fake_arm_instance().apply_curve(ball_vel)


def draw_fake_arm_effects(screen: pygame.Surface) -> None:
    get_fake_arm_instance().draw_effects(screen)


def reset_all() -> None:
    get_fake_arm_instance().reset()

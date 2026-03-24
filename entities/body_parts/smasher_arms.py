"""
SmasherLeftArmPart / SmasherRightArmPart — 스매셔 양팔 + 글러브 파츠.
Visual Polish: 3단 레이어링 + 관절 LED 블룸 + 리벳/머슬라인
"""

import math
import pygame
from entities.player_skeleton import (
    BodyPart, Joint, Skeleton,
    ORDER_L_ARM, ORDER_R_ARM, SLOT_L_ARM, SLOT_R_ARM,
)
from typing import Optional


def _draw_arm(surface: pygame.Surface, shoulder: tuple, elbow: tuple,
              wrist: tuple, palette: dict, b: int, phase: float, side: str,
              energy_core=None):
    """좌/우 공용 팔 렌더링 (3단 레이어 + LED + 리벳)."""

    # ── 상완: 3단 (그림자 → 베이스 → 하이라이트) ──
    pygame.draw.line(surface, (45, 55, 85), shoulder, elbow, b + 2)       # 그림자
    pygame.draw.line(surface, palette["arm_light"], shoulder, elbow, b)     # 베이스
    pygame.draw.line(surface, palette["armor_mid"], shoulder, elbow, b - 2) # 중간톤
    # 머슬라인 (상완 중앙 하이라이트)
    mid_upper = ((shoulder[0] + elbow[0]) // 2, (shoulder[1] + elbow[1]) // 2)
    pygame.draw.circle(surface, palette.get("trim", (190, 206, 236)), mid_upper, 1)

    # ── 전완: 3단 ──
    pygame.draw.line(surface, (45, 55, 85), elbow, wrist, b)              # 그림자
    pygame.draw.line(surface, palette["arm_light"], elbow, wrist, b - 1)   # 베이스
    pygame.draw.line(surface, palette["armor_mid"], elbow, wrist, b - 3)   # 중간톤

    # ── 관절 리벳 (팔꿈치) ──
    pygame.draw.circle(surface, (55, 65, 95), elbow, max(3, b // 2 + 1))  # 외곽
    pygame.draw.circle(surface, palette.get("trim", (190, 206, 236)),
                      elbow, max(2, b // 2))                               # 베이스
    pygame.draw.circle(surface, (220, 230, 245), elbow, max(1, b // 3))    # 하이라이트

    # ── 관절 LED 블룸 (팔꿈치, HP 연동) ──
    if energy_core:
        _led_speed = energy_core.get_pulse_speed()
        led_color = energy_core.get_core_color(palette.get("accent", (118, 214, 255)))
    else:
        _led_speed = 3.0
        led_color = palette.get("accent", (118, 214, 255))
    led_pulse = 0.5 + 0.5 * math.sin(phase * math.tau * _led_speed + (0 if side == "left" else math.pi))
    led_r = max(2, int(b * 0.25))
    glow_size = led_r * 4
    glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
    glow_alpha = int(40 * led_pulse)
    pygame.draw.circle(glow_surf, (*led_color, glow_alpha),
                      (glow_size // 2, glow_size // 2), glow_size // 2)
    surface.blit(glow_surf,
                (elbow[0] - glow_size // 2, elbow[1] - glow_size // 2),
                special_flags=pygame.BLEND_RGBA_ADD)
    # LED 코어
    core_alpha = int(180 + 75 * led_pulse)
    pygame.draw.circle(surface, (*led_color[:2], min(255, core_alpha)), elbow, led_r)

    # ── 글러브: 3단 ──
    gr = max(2, b // 2 + 1)
    pygame.draw.circle(surface, (140, 125, 108), (wrist[0] + 1, wrist[1] + 1), gr)  # 그림자
    pygame.draw.circle(surface, palette["glove"], wrist, gr)                          # 베이스
    pygame.draw.circle(surface, palette.get("glove_high", (220, 210, 195)),
                      (wrist[0] - 1, wrist[1] - 1), max(1, gr - 1))                 # 하이라이트
    # 너클 라인
    dx = 2 if side == "left" else -2
    pygame.draw.line(surface, palette.get("glove_detail", (156, 134, 110)),
                    (wrist[0] - dx, wrist[1] - 1),
                    (wrist[0] + dx, wrist[1] + 2), 1)


class SmasherLeftArmPart(BodyPart):

    def __init__(self, block: int = 9):
        super().__init__(slot=SLOT_L_ARM, draw_order=ORDER_L_ARM,
                         joint_a="l_shoulder", joint_b="l_wrist")
        self.block = block

    def _render(self, surface, joint_a, joint_b, palette, phase):
        elbow_joint = next((c for c in joint_a.children if c.name == "l_elbow"), None)
        if not elbow_joint:
            return
        _ec = getattr(getattr(self, '_skin_ref', None), '_vfx_energy_core', None)
        _draw_arm(surface, joint_a.world_int(), elbow_joint.world_int(),
                  joint_b.world_int() if joint_b else elbow_joint.world_int(),
                  palette, self.block, phase, "left", energy_core=_ec)


class SmasherRightArmPart(BodyPart):

    def __init__(self, block: int = 9):
        super().__init__(slot=SLOT_R_ARM, draw_order=ORDER_R_ARM,
                         joint_a="r_shoulder", joint_b="r_wrist")
        self.block = block

    def _render(self, surface, joint_a, joint_b, palette, phase):
        elbow_joint = next((c for c in joint_a.children if c.name == "r_elbow"), None)
        if not elbow_joint:
            return
        _ec = getattr(getattr(self, '_skin_ref', None), '_vfx_energy_core', None)
        _draw_arm(surface, joint_a.world_int(), elbow_joint.world_int(),
                  joint_b.world_int() if joint_b else elbow_joint.world_int(),
                  palette, self.block, phase, "right", energy_core=_ec)

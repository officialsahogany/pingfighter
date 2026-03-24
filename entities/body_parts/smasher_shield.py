"""
SmasherShieldPart — 스매셔 오각형 에너지 방패 파츠.

원본: pingfighter.py create_smasher_paddle_surface() 29842~29910줄
관절 바인딩: r_wrist (오른손목에 방패 부착)
"""

import math
import pygame
from entities.player_skeleton import (
    BodyPart, Joint, Skeleton, int_point,
    ORDER_SHIELD, SLOT_SHIELD,
)
from typing import Optional


def _regular_polygon_points(center: tuple[float, float], radius: float,
                            *, sides: int = 5,
                            rotation_deg: float = -90.0) -> list[tuple[float, float]]:
    """정다각형 꼭짓점 좌표 생성."""
    rotation = math.radians(rotation_deg)
    return [
        (
            center[0] + radius * math.cos(rotation + i * math.tau / sides),
            center[1] + radius * math.sin(rotation + i * math.tau / sides),
        )
        for i in range(sides)
    ]


class SmasherShieldPart(BodyPart):
    """스매셔 오각형 에너지 방패.

    r_wrist 관절 기준으로 오각형 레이어드 방패를 그린다.
    별도 Surface에 그린 후 wrist 위치에 블릿.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_SHIELD,
            draw_order=ORDER_SHIELD,
            joint_a="r_wrist",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        wx, wy = joint_a.world_int()

        shield_radius = max(9, int(1.7 * b))
        shield_surface = pygame.Surface(
            (shield_radius * 2, shield_radius * 2), pygame.SRCALPHA,
        )
        shield_center = (shield_radius, shield_radius)

        # ── 레이어드 오각형 (바깥→안쪽, 점점 불투명) ──
        layer_specs = (
            (1.05, 70),
            (0.85, 110),
            (0.65, 150),
            (0.45, 190),
        )
        for scale, alpha in layer_specs:
            points = [int_point(p) for p in
                      _regular_polygon_points(shield_center, shield_radius * scale)]
            glow_color = (
                palette["shield_glow"][0],
                palette["shield_glow"][1],
                palette["shield_glow"][2],
                min(255, alpha),
            )
            pygame.draw.polygon(shield_surface, glow_color, points)

        # ── 외곽선 ──
        outline_points = [int_point(p) for p in
                          _regular_polygon_points(shield_center, shield_radius * 1.05)]
        pygame.draw.polygon(
            shield_surface,
            (palette["shield_ring"][0], palette["shield_ring"][1],
             palette["shield_ring"][2], 230),
            outline_points, width=3,
        )

        # ── 코어 (작은 오각형) ──
        core_points = [int_point(p) for p in
                       _regular_polygon_points(shield_center, shield_radius * 0.38)]
        pygame.draw.polygon(
            shield_surface,
            (palette["shield_core"][0], palette["shield_core"][1],
             palette["shield_core"][2], 240),
            core_points,
        )

        # ── 하이라이트 라인 ──
        highlight_points = [int_point(p) for p in
                            _regular_polygon_points(shield_center, shield_radius * 0.9)]
        pygame.draw.lines(
            shield_surface,
            (palette["shield_core"][0], palette["shield_core"][1],
             palette["shield_core"][2], 120),
            True, highlight_points, 1,
        )

        # ── 블릿 (wrist 기준 오프셋) ──
        shield_offset_x = int(0.45 * b)
        shield_offset_y = -int(0.15 * b)
        shield_pos = (
            wx - shield_radius + shield_offset_x,
            wy - shield_radius + shield_offset_y,
        )
        surface.blit(shield_surface, shield_pos)
        surface.blit(shield_surface, shield_pos, special_flags=pygame.BLEND_ADD)

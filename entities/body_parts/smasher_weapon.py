"""
SmasherWeaponPart — 스매셔 탁구채 (핸들 + 라켓면 + 글로우) 파츠.

원본: pingfighter.py create_smasher_paddle_surface() 29783~29800줄
관절 바인딩: l_wrist (왼손목에 탁구채 부착)
"""

import math
import pygame
from entities.player_skeleton import (
    BodyPart, Joint, Skeleton,
    ORDER_WEAPON, SLOT_WEAPON,
)
from typing import Optional


class SmasherWeaponPart(BodyPart):
    """스매셔 기본 탁구채.

    l_wrist 관절 기준으로 핸들 + 원형 라켓면을 그린다.
    장비 교체 시 이 클래스를 다른 WeaponPart로 교체하면
    다른 모양의 라켓이 표시된다.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_WEAPON,
            draw_order=ORDER_WEAPON,
            joint_a="l_wrist",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        wx, wy = joint_a.world_int()

        # ── 핸들 (grip) ──
        handle_rect = pygame.Rect(
            wx - b // 2,
            wy - int(1.3 * b),
            int(0.9 * b), int(1.6 * b),
        )
        pygame.draw.rect(surface, palette["handle"], handle_rect)
        pygame.draw.rect(
            surface, palette["handle_core"],
            handle_rect.inflate(-max(1, b // 3), -max(1, b // 3)),
        )

        # ── 라켓면 (원형) ──
        paddle_center = (
            handle_rect.centerx - int(1.2 * b),
            handle_rect.top - int(0.4 * b),
        )
        paddle_radius = int(1.7 * b)

        pygame.draw.circle(surface, palette["paddle"], paddle_center, paddle_radius)
        pygame.draw.circle(
            surface, palette["paddle_core"],
            paddle_center, max(2, paddle_radius - 3),
        )

        # 라켓면 그림자 아크
        paddle_box = pygame.Rect(
            paddle_center[0] - paddle_radius,
            paddle_center[1] - paddle_radius,
            paddle_radius * 2, paddle_radius * 2,
        )
        pygame.draw.arc(
            surface, palette["paddle_shadow"],
            paddle_box, math.radians(200), math.radians(320), 3,
        )

        # ── 글로우 효과 ──
        paddle_glow = pygame.Surface(
            (paddle_radius * 2, paddle_radius * 2), pygame.SRCALPHA,
        )
        pygame.draw.circle(
            paddle_glow, (*palette["paddle_core"], 40),
            (paddle_radius, paddle_radius), paddle_radius,
        )
        surface.blit(
            paddle_glow, (paddle_box.left, paddle_box.top),
            special_flags=pygame.BLEND_RGBA_ADD,
        )

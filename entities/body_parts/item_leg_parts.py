"""
패시브 아이템 연동 다리 파츠 — 소울버스트.
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, SLOT_LEGS, ORDER_LEGS
from typing import Optional


class SoulBurstKneePart(BodyPart):
    """소울버스트 (soul_burst) — 무릎 부위.

    보라색 에너지 무릎 보호대.
    효과: 대쉬 토큰 없을 때 스페셜 게이지로 풀 대쉬.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_LEGS,
            draw_order=ORDER_LEGS,
            joint_a="l_knee",
            joint_b="r_knee",
        )
        self.block = block
        self._frame = 0

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        self._frame += 1

        for joint in [joint_a, joint_b]:
            if joint is None:
                continue
            kx, ky = joint.world_int()

            # 무릎 보호대 본체 (보라색)
            pad_w = int(1.8 * b)
            pad_h = int(1.4 * b)
            pad_rect = pygame.Rect(kx - pad_w // 2, ky - pad_h // 2, pad_w, pad_h)
            pygame.draw.rect(surface, (100, 50, 160), pad_rect, border_radius=3)
            # 내부 어두운 패널
            inner = pad_rect.inflate(-int(0.3 * b), -int(0.3 * b))
            pygame.draw.rect(surface, (70, 30, 120), inner, border_radius=2)

            # 중앙 에너지 코어 (보라빛 글로우)
            core_r = max(2, int(0.4 * b))
            glow_alpha = int(160 + 60 * math.sin(self._frame * 0.1))
            glow_color = (min(255, 180 + glow_alpha // 4), 120, 255)
            pygame.draw.circle(surface, glow_color, (kx, ky), core_r)
            pygame.draw.circle(surface, (255, 200, 255), (kx, ky), max(1, core_r // 2))

            # 외곽 테두리
            pygame.draw.rect(surface, (180, 120, 255), pad_rect, 1, border_radius=3)

"""
패시브 아이템 연동 등 파츠 — 충전가방.
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_BACK, SLOT_BACK
from typing import Optional


class ChargeBagPart(BodyPart):
    """충전가방 (chargebag).

    등에 매는 에너지 팩 + 케이블 + 충전 게이지.
    효과: 대시 충전 속도 증가.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_BACK,
            draw_order=ORDER_BACK,    # 몸통 뒤에 그려짐
            joint_a="torso",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, ty = joint_a.world_int()

        # ── 가방 본체 (torso 뒤쪽, 약간 오른쪽에 표시) ──
        # draw_order가 낮아서 몸통 뒤에 그려지지만,
        # 2D에서는 측면으로 삐져나온 부분만 보이도록 배치
        bag_w = int(1.4 * b)
        bag_h = int(1.8 * b)
        bag_x = cx + int(1.6 * b)  # 오른쪽 측면으로 삐져나옴
        bag_y = ty - int(0.2 * b)
        bag_rect = pygame.Rect(bag_x, bag_y, bag_w, bag_h)

        # 가방 본체 (초록-회색)
        pygame.draw.rect(surface, (50, 80, 50), bag_rect, border_radius=3)
        pygame.draw.rect(surface, (65, 100, 65), bag_rect.inflate(-2, -2), border_radius=2)

        # ── 스트랩 (어깨에서 가방으로) ──
        strap_top = (cx + int(1.0 * b), ty - int(0.8 * b))
        strap_btm = (bag_rect.left, bag_rect.top + int(0.3 * b))
        pygame.draw.line(surface, (40, 65, 40), strap_top, strap_btm, 2)

        # ── 에너지 셀 (2칸) ──
        cell_w = bag_w - 4
        cell_h = int(0.5 * b)
        for i in range(2):
            cell_rect = pygame.Rect(
                bag_rect.left + 2,
                bag_rect.top + int(0.3 * b) + i * (cell_h + 2),
                cell_w, cell_h,
            )
            # 셀 배경
            pygame.draw.rect(surface, (30, 50, 30), cell_rect, border_radius=1)
            # 충전 게이지 (phase로 충전 애니메이션)
            charge_level = (math.sin(phase * math.tau + i * math.pi) + 1) / 2  # 0~1
            fill_w = int(cell_w * charge_level)
            if fill_w > 0:
                fill_rect = pygame.Rect(cell_rect.left, cell_rect.top, fill_w, cell_h)
                # 충전량에 따라 초록→노랑
                g = int(180 + 60 * charge_level)
                r = int(80 + 120 * (1 - charge_level))
                pygame.draw.rect(surface, (r, min(255, g), 50), fill_rect, border_radius=1)

        # ── LED 인디케이터 ──
        led_y = bag_rect.bottom - int(0.3 * b)
        led_on = math.sin(phase * math.tau * 4) > 0
        led_color = (80, 255, 80) if led_on else (30, 80, 30)
        pygame.draw.circle(surface, led_color, (bag_rect.centerx, led_y), 2)

        # ── 케이블 (가방에서 아래로) ──
        cable_start = (bag_rect.centerx, bag_rect.bottom)
        cable_end = (bag_rect.centerx - int(0.3 * b), bag_rect.bottom + int(0.5 * b))
        pygame.draw.line(surface, (40, 65, 40), cable_start, cable_end, 2)

        # 테두리
        pygame.draw.rect(surface, (35, 60, 35), bag_rect, 1, border_radius=3)

"""
패시브 아이템 연동 등 파츠 — 충전가방, 판도라의 유산.
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


class PandoraLegacyPart(BodyPart):
    """판도라의 유산 (pandora_legacy).

    목에 거는 보라색 보석 펜던트 + 금색 체인.
    효과: 라운드 승리 시 3개 아이템 선택.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_BACK,
            draw_order=ORDER_BACK + 1,  # 충전가방보다 약간 앞에
            joint_a="torso",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, ty = joint_a.world_int()

        # ── 금색 체인 (목에서 가슴으로) ──
        chain_top_l = (cx - int(0.6 * b), ty - int(1.5 * b))
        chain_top_r = (cx + int(0.6 * b), ty - int(1.5 * b))
        pendant_pos = (cx, ty - int(0.3 * b))

        gold = (255, 215, 0)
        dark_gold = (200, 170, 0)
        pygame.draw.line(surface, gold, chain_top_l, pendant_pos, 1)
        pygame.draw.line(surface, gold, chain_top_r, pendant_pos, 1)

        # ── 보석 (보라색 다이아몬드형 보석) ──
        gem_size = int(0.7 * b)
        gx, gy = pendant_pos
        # 보석 본체
        gem_points = [
            (gx, gy - gem_size),        # 상단
            (gx + gem_size, gy),         # 우측
            (gx, gy + gem_size),         # 하단
            (gx - gem_size, gy),         # 좌측
        ]
        # 보석 빛남 효과 (phase 기반)
        glow_intensity = (math.sin(phase * math.tau * 2) + 1) / 2
        r = int(130 + 50 * glow_intensity)
        g_val = int(30 + 30 * glow_intensity)
        b_val = int(180 + 40 * glow_intensity)
        pygame.draw.polygon(surface, (r, g_val, b_val), gem_points)

        # 보석 하이라이트
        hl_points = [
            (gx, gy - gem_size + 2),
            (gx + gem_size // 2, gy),
            (gx, gy + 1),
            (gx - gem_size // 2, gy),
        ]
        pygame.draw.polygon(surface, (min(255, r + 40), min(255, g_val + 40), min(255, b_val + 30)), hl_points)

        # 금색 테두리
        pygame.draw.polygon(surface, dark_gold, gem_points, 1)

        # ── 금색 장식 ──
        pygame.draw.circle(surface, gold, (gx, gy - gem_size - 2), 2)
